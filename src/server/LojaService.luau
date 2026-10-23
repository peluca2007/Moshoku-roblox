-- Loja pessoal J1: categorias e preços sempre vêm do catálogo no servidor.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loja = require(ReplicatedStorage.Shared.Regras.Loja)
local Itens = require(ReplicatedStorage.Shared.Livro.Dados.Itens)

local LojaService = {}
local VITRINES = {
	taverneira = { npc = "Dona Brisa", categorias = { pocao = true, aventura = true, tralha = true } },
	ferreiro = { npc = "Mestre Torr", categorias = { arma = true, armadura = true } },
}

function LojaService.start(deps)
	local handlers, remote = deps.handlers, deps.remote
	local abertas, ultima, pedidos = {}, {}, {}
	local relogio = deps.relogio or os.clock
	local function jogadorPerto(player, npcId)
		local vitrine = VITRINES[npcId]
		local personagem = player.Character
		local raizJogador = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		local raizN
		if deps.obterNpcRaiz then raizN = deps.obterNpcRaiz(npcId)
		else
			local npcs = workspace:FindFirstChild("Vila") and workspace.Vila:FindFirstChild("Npcs")
			local modelo = npcs and npcs:FindFirstChild(vitrine and vitrine.npc)
			raizN = modelo and modelo:FindFirstChild("HumanoidRootPart")
		end
		return vitrine ~= nil and raizJogador ~= nil and humanoide ~= nil and humanoide.Health > 0
			and raizN ~= nil and (raizJogador.Position - raizN.Position).Magnitude <= 10
			and not deps.emCombate()
	end
	local function estado(player, npcId)
		if not jogadorPerto(player, npcId) then return false end
		local perfil = deps.consultar(player)
		if not perfil then return false end
		local vitrine, prateleira, vendaveis = VITRINES[npcId], {}, {}
		local dadosItens = {}
		for _, registro in ipairs(Itens) do table.insert(dadosItens, registro.data) end
		for _, entrada in ipairs(Loja.listar(dadosItens, "F")) do
			if vitrine.categorias[entrada.category] then
				local catalogoId = "item/" .. entrada.id
				table.insert(prateleira, { id = catalogoId, name = entrada.name, description = entrada.description, price = entrada.price, type = entrada.type, category = entrada.category })
			end
		end
		local porNome = {}
		for _, registro in ipairs(Itens) do
			local d = registro.data
			if vitrine.categorias[d.category] then porNome[d.name .. "|" .. d.type] = registro end
		end
		for _, owned in ipairs(perfil.inventarioInicial or {}) do
			local record = porNome[owned.name .. "|" .. owned.type]
			if record then
				local preco = Loja.valorDeVenda(record.data)
				if preco and not owned.equipped and perfil.armaInicialSourceLocalId ~= owned.sourceLocalId then
					table.insert(vendaveis, { sourceLocalId = owned.sourceLocalId, name = owned.name, price = preco })
				end
			end
		end
		return { npcId = npcId, nome = vitrine.npc, ouro = perfil.ouro or 0, prateleira = prateleira, inventario = vendaveis }
	end
	local function enviar(player, npcId)
		local dados = estado(player, npcId)
		if not dados then return false end
		abertas[player.UserId] = npcId
		remote:FireClient(player, "loja", dados)
		return true
	end
	local function limitar(player, npcId)
		if abertas[player.UserId] ~= npcId or not jogadorPerto(player, npcId) then return "Aproxime-se do lojista antes de negociar." end
		local agora = relogio()
		if ultima[player.UserId] and agora - ultima[player.UserId] < 0.5 then return "Aguarde antes de negociar novamente." end
		ultima[player.UserId] = agora
		return nil
	end
	local function replay(player, requestId, assinatura)
		local cache = pedidos[player.UserId]
		local anterior = cache and cache.porId[requestId]
		if not anterior then return nil, false end
		if anterior.assinatura ~= assinatura then return "ID de pedido já usado com outra operação.", true end
		return nil, true
	end
	local function lembrar(player, requestId, assinatura)
		local cache = pedidos[player.UserId]
		if not cache then cache = { fila = {}, porId = {} }; pedidos[player.UserId] = cache end
		cache.porId[requestId] = { assinatura = assinatura }
		table.insert(cache.fila, requestId)
		if #cache.fila > 32 then cache.porId[table.remove(cache.fila, 1)] = nil end
	end
	local function payloadValido(payload, permitidos)
		if type(payload) ~= "table" or getmetatable(payload) ~= nil then return false end
		for k in payload do if not permitidos[k] then return false end end
		return true
	end
	function LojaService.abrir(player, npcId)
		if not VITRINES[npcId] then return false end
		return enviar(player, npcId)
	end
	handlers.lojaListar = function(player, payload)
		if not payloadValido(payload, { npcId = true }) or type(payload.npcId) ~= "string" then return "Consulta de loja inválida." end
		if abertas[player.UserId] ~= payload.npcId and not VITRINES[payload.npcId] then return "Lojista inválido." end
		if not jogadorPerto(player, payload.npcId) then return "Aproxime-se do lojista." end
		if not enviar(player, payload.npcId) then return "Ficha pessoal indisponível." end
		return nil
	end
	handlers.lojaComprar = function(player, payload)
		if not payloadValido(payload, { npcId = true, itemId = true, requestId = true })
			or type(payload.npcId) ~= "string" or type(payload.itemId) ~= "string"
			or type(payload.requestId) ~= "string" or #payload.requestId < 1 or #payload.requestId > 96 then return "Pedido de compra inválido." end
		local assinatura = "comprar|" .. payload.npcId .. "|" .. payload.itemId
		if abertas[player.UserId] ~= payload.npcId or not jogadorPerto(player, payload.npcId) then return "Aproxime-se do lojista antes de negociar." end
		local repetido, existe = replay(player, payload.requestId, assinatura)
		if existe then if not repetido then enviar(player, payload.npcId) end; return repetido end
		local erro = limitar(player, payload.npcId); if erro then return erro end
		local vitrine = VITRINES[payload.npcId]
		local item
		for _, record in ipairs(Itens) do if record.id == payload.itemId then item = record.data; break end end
		if not vitrine or not item or not vitrine.categorias[item.category] or not Loja.naPrateleira(item, "F") then return "Este item não está na prateleira." end
		local ok, motivo = deps.comprar(player, payload.itemId, "loja:" .. HttpService:GenerateGUID(false))
		if not ok then return motivo or "Compra não concluída." end
		lembrar(player, payload.requestId, assinatura)
		enviar(player, payload.npcId)
		return nil
	end
	handlers.lojaVender = function(player, payload)
		if not payloadValido(payload, { npcId = true, sourceLocalId = true, requestId = true })
			or type(payload.npcId) ~= "string" or type(payload.sourceLocalId) ~= "string"
			or #payload.sourceLocalId < 1 or #payload.sourceLocalId > 96
			or type(payload.requestId) ~= "string" or #payload.requestId < 1 or #payload.requestId > 96 then return "Pedido de venda inválido." end
		local assinatura = "vender|" .. payload.npcId .. "|" .. payload.sourceLocalId
		if abertas[player.UserId] ~= payload.npcId or not jogadorPerto(player, payload.npcId) then return "Aproxime-se do lojista antes de negociar." end
		local repetido, existe = replay(player, payload.requestId, assinatura)
		if existe then if not repetido then enviar(player, payload.npcId) end; return repetido end
		local erro = limitar(player, payload.npcId); if erro then return erro end
		local vitrine = VITRINES[payload.npcId]
		if not vitrine then return "Lojista inválido." end
		local ok, motivo = deps.vender(player, payload.sourceLocalId, vitrine.categorias)
		if not ok then return motivo or "Venda não concluída." end
		lembrar(player, payload.requestId, assinatura)
		enviar(player, payload.npcId)
		return nil
	end
	Players.PlayerRemoving:Connect(function(player) abertas[player.UserId], ultima[player.UserId], pedidos[player.UserId] = nil, nil, nil end)
	return table.freeze({ abrir = LojaService.abrir })
end

return LojaService
