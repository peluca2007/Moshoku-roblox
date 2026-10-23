-- Transações e fronteira remota puras; store, identidade e contexto injetados.
local Shared = game:GetService("ReplicatedStorage").Shared
local Conta = require(Shared.Regras.RunConta)
local Servico = {}
local Loot = require(Shared.Aparencia.Loot)
function Servico.payloadValido(pedido)
	if type(pedido) ~= "table" or getmetatable(pedido) ~= nil then return false end
	if type(pedido.requestId) ~= "string" or #pedido.requestId < 1 or #pedido.requestId > 64
		or not string.match(pedido.requestId, "^[%w_-]+$") then return false end
	if pedido.acao ~= "consultar" and pedido.acao ~= "comprar" and pedido.acao ~= "aberturaVista" then return false end
	if pedido.acao == "comprar" and (type(pedido.itemId) ~= "string" or not Conta.CATALOGO[pedido.itemId]) then return false end
	for k in pedido do
		if k ~= "acao" and k ~= "requestId" and not (k == "itemId" and pedido.acao == "comprar") then return false end
	end
	return true
end

function Servico.start(deps)
	deps = deps or {}
	local store = assert(deps.store, "Store da conta ausente.")
	local api = {}
	local function chave(userId) return "conta/" .. tostring(userId) end

	-- Aplica `f(conta) -> novaConta|nil, extra` de forma atômica no armazenamento. Devolve (conta, extra) ou (nil, motivo).
	local function mudar(userId, f)
		local extra, falhou
		local ok, resultado = pcall(store.atualizar, chave(userId), function(atual)
			extra, falhou = nil, nil -- UpdateAsync pode repetir a transformação.
			local conta = if atual == nil then Conta.nova() else atual
			if not Conta.valida(conta) then falhou = "Conta corrompida."; return nil end
			local nova, e = f(conta)
			if not nova then falhou = e; return nil end
			extra = e
			return nova
		end)
		if not ok then return nil, "Falha ao acessar a conta." end
		if falhou then return nil, falhou end
		return resultado, extra
	end

	function api.obter(userId)
		return mudar(userId, function(conta) return conta end)
	end

	-- Fim de run: soma moeda, conquistas e códice. Devolve (conta, { moeda, conquistas }).
	function api.registrarRun(userId, resumo, finalId)
		return mudar(userId, function(conta) return Conta.registrarRun(conta, resumo, finalId) end)
	end

	-- Marca a cena de abertura como vista (cliente avisa; idempotente, só liga o booleano).
	function api.marcarAberturaVista(userId)
		return mudar(userId, function(conta) return Conta.marcarAberturaVista(conta) end)
	end

	function api.comprar(userId, itemId, requestId, autorizado)
		return mudar(userId, function(conta)
			-- Recibo de sucesso persistido na MESMA transação do débito. O número de
			-- recibos é limitado pelos desbloqueios únicos do catálogo (sem repetição).
			local recibos = conta.comprasRequests or {}
			if requestId and recibos[requestId] then
				if recibos[requestId] ~= itemId then return nil, "requestId já usado com outro pedido." end
				return conta
			end
			if autorizado and not autorizado() then return nil, "Compra indisponível neste contexto." end
			local nova, motivo = Conta.comprar(conta, itemId)
			if not nova then return nil, motivo end
			if requestId then
				nova.comprasRequests = table.clone(recibos)
				nova.comprasRequests[requestId] = itemId
			end
			return nova
		end)
	end

	-- Apenas servidor: ID autoritativo do encontro. Recibo e posse na mesma transação,
	-- incluindo sorteios sem prêmio; retries do DataStore reutilizam os mesmos dados.
	function api.registrarLootChefe(userId, fonte, rng)
		if type(userId) ~= "number" or userId % 1 ~= 0 or userId <= 0 or type(fonte) ~= "string" or #fonte < 1 or #fonte > 160 then return nil, "Fonte inválida." end
		local chance, escolha = rng:NextNumber(), rng:NextNumber()
		return mudar(userId, function(conta)
			if table.find(conta.lootChefes or {}, fonte) then return conta end
			local fixo = {}
			function fixo:NextNumber() return chance end
			function fixo:NextInteger(a, b) return a + math.min(b - a, math.floor(escolha * (b - a + 1))) end
			local id = Loot.sortear(conta.cosmeticos or {}, fixo)
			local nova = table.clone(conta)
			nova.cosmeticos = table.clone(conta.cosmeticos or {})
			if id then nova.cosmeticos[id] = true end
			nova.lootChefes = table.clone(conta.lootChefes or {})
			table.insert(nova.lootChefes, fonte)
			if #nova.lootChefes > 128 then table.remove(nova.lootChefes, 1) end
			return nova, id
		end)
	end

	function api.registrarNoCodice(userId, categoria, id)
		return mudar(userId, function(conta) return Conta.registrarNoCodice(conta, categoria, id) end)
	end

	return api
end

-- Fronteira testável sem transporte. Identidade vem da conexão, nunca do payload.
-- Sem alcance espacial: é uma tela privada da conta; compra só entre runs.
function Servico.criarHandler(api, deps)
	local sessoes = {}
	local function resposta(id, ok, mensagem, conta)
		return { requestId = id, ok = ok, mensagem = mensagem, conta = conta, catalogo = Conta.CATALOGO }
	end
	local function processar(player, pedido)
		if not deps.autenticado(player) then return nil end
		if not Servico.payloadValido(pedido) then return nil end
		local uid, agora = player.UserId, deps.relogio()
		local s = sessoes[uid]
		if not s then s = { recibos = {}, quantidade = 0 }; sessoes[uid] = s end
		if s.ocupado then return resposta(pedido.requestId, false, "Aguarde a operação em andamento.") end
		if s.ultimo and agora - s.ultimo < 0.4 then return resposta(pedido.requestId, false, "Aguarde antes de tentar novamente.") end
		s.ultimo = agora
		local assinatura = pedido.acao .. "/" .. (pedido.itemId or "")
		local anterior = s.recibos[pedido.requestId]
		if anterior and anterior.assinatura ~= assinatura then return resposta(pedido.requestId, false, "requestId já usado com outro pedido.") end
		-- Não expulsa IDs antigos: impede que um replay volte a ser executável.
		if not anterior and s.quantidade >= 128 then return resposta(pedido.requestId, false, "Limite de pedidos da sessão atingido. Reconecte.") end
		s.ocupado = true
		local ok, conta, motivo = pcall(function()
			if anterior and not anterior.ok then return nil, anterior.mensagem end
			if anterior then return api.obter(uid) end
			if pedido.acao == "consultar" then return api.obter(uid) end
			if pedido.acao == "aberturaVista" then return api.marcarAberturaVista(uid) end
			local function autorizado() return deps.autenticado(player) and deps.entreRuns(player) end
			if not autorizado() then return nil, "Compras disponíveis apenas entre runs." end
			return api.comprar(uid, pedido.itemId, pedido.requestId, autorizado)
		end)
		s.ocupado = false
		if not ok then conta, motivo = nil, "Falha ao acessar a conta." end
		if not deps.autenticado(player) then return nil end
		if not anterior then
			s.quantidade += 1
			s.recibos[pedido.requestId] = { assinatura = assinatura, ok = conta ~= nil, mensagem = motivo }
		end
		return resposta(pedido.requestId, conta ~= nil, motivo, conta)
	end
	return processar, function(player) sessoes[player.UserId] = nil end
end

return Servico
