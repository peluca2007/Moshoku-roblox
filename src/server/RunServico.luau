-- Servidor da run (R5b/R5c): liga RunSessao (regras puras) ao armazenamento real, aos remotos e aos jogadores.
-- Por enquanto há UMA run por servidor, para todos os jogadores presentes (até 4); o servidor por grupo
-- com teleporte exige place publicado (PLANO §12). Servidor autoritativo: o cliente só envia intenção.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Sessao = require(Shared.Regras.RunSessao)
local Criacao = require(Shared.Regras.RunCriacao)
local Conta = require(Shared.Regras.RunConta)
local Prontos = require(Shared.PersonagensProntos)
local RestricaoDeCriacao = require(Shared.Regras.RestricaoDeCriacao)
local Abertura = require(Shared.Regras.AberturaRun)
local EventosV1 = require(Shared.Mundo.ViagemEventosV1)
local CatalogoAparencia = require(Shared.Aparencia.Catalogo)

local Servico = {}

Servico.REMOTE = "RunJogo"
local INTERVALO = 0.4

local Relogio = require(Shared.Regras.RunRelogio)

-- Expedição (DIRECAO §4): quem votar em opção do hub "entrar-*"/"retomar-*" precisa estar perto da porta.
local function ehOpcaoDePorta(opcao)
	return string.sub(opcao, 1, 7) == "entrar-" or string.sub(opcao, 1, 8) == "retomar-"
end

function Servico.payloadValido(pedido)
	if type(pedido) ~= "table" or getmetatable(pedido) ~= nil or type(pedido.acao) ~= "string" then return false end
	local permitidos = { acao = true }
	if pedido.acao == "consultar" then
	elseif pedido.acao == "iniciar" then
		permitidos.modo = true
		local ok = false
		for _, m in Criacao.MODOS do
			if pedido.modo == m then ok = true end
		end
		if pedido.modo ~= nil and not ok then return false end
	elseif pedido.acao == "lutar" then
		-- sem campos: reinicia a luta pendente
	elseif pedido.acao == "descansar" then
		-- sem campos: descanso do acampamento da área (o servidor decide custo, limite e recuperação)
	elseif pedido.acao == "escolherArvore" then
		permitidos.arvore = true
		if type(pedido.arvore) ~= "string" or #pedido.arvore > 64 then return false end
	elseif pedido.acao == "votar" then
		permitidos.opcao = true
		if type(pedido.opcao) ~= "string" or #pedido.opcao > 64 then return false end
	else
		return false
	end
	for chave in pedido do
		if not permitidos[chave] then return false end
	end
	return true
end

-- Armazenamento: DataStore no jogo publicado; memória no Studio com place não publicado (como PersistenciaDeEstudio).
local function armazenamento()
	if require(script.Parent.PersistenciaDeEstudio).memoriaAtiva() then
		local dados = {}
		return function(chave, dado) dados[chave] = dado end, function(chave) return dados[chave] end
	end
	local store = DataStoreService:GetDataStore("RunsSalvas")
	return function(chave, dado) store:SetAsync(chave, dado) end, function(chave) return store:GetAsync(chave) end
end

-- deps = { emEncontro = function() -> bool, ehExplorador = function(userId) -> bool (opcional),
--          conta = ContaServico (opcional; sem ela o fim da run não paga a conta),
--          iniciarLuta = function(jogadores, luta) -> encounterId | nil, erro   (luta = { no, criaturas, areaId }; monta o encontro J2 do nó),
--          historiaDaSemente, area, objetivo = expedição gerada (ver RunSessao); mundoAberto fica sempre falso,
--          portaPerto = function(player) -> bool   (avatar a até ~20 studs da porta; lido no servidor),
--          pontoDaPorta = function() -> Vector3|nil  (onde reunir o grupo ao entrar na área),
--          restaurarDescanso = function(player) -> ok, erro   (recupera PV/PM/PT da ficha pessoal; mesmo caminho do descanso da mesa),
--          recompensarArea = function(player, idPagamento, ouro, areaId) -> ok   (crédito idempotente por idPagamento) }
function Servico.start(deps)
	deps = deps or {}
	local remote = Instance.new("RemoteEvent")
	remote.Name = Servico.REMOTE
	remote.Parent = ReplicatedStorage
	local guardar, carregar = armazenamento()
	local sessao
	local observadores, processando = {}, false
	local ultimo = {}
	local lutaAtiva -- encounterId do encontro J2 da luta pendente (nil = ainda não começou)
	local function novaSessao()
		return Sessao.new({
			rng = Random.new(), guardar = guardar, carregar = carregar, mundoAberto = false,
			historiaDaSemente = deps.historiaDaSemente, area = deps.area, objetivo = deps.objetivo,
			ehExplorador = deps.ehExplorador, prontos = Prontos, eventos = EventosV1,
   fichaDe = function(userId)
    local player = Players:GetPlayerByUserId(userId)
    return player and deps.corpoPessoal and deps.corpoPessoal(player) or nil
   end,
		})
	end
	local function enviar(player, dado) remote:FireClient(player, "run", dado) end
	local function nomeDe(userId)
		local p = Players:GetPlayerByUserId(userId)
		return p and p.DisplayName or tostring(userId)
	end
	local function visaoPara(player)
		local v = sessao and sessao:visao(player.UserId)
		if not v then return { semRun = true } end
		for _, m in v.grupo do m.nome = nomeDe(m.userId) end
		return v
	end
	-- Só dias do prazo (a expedição não tem relógio em tempo real).
	local function publicarRelogio()
		if not sessao or not sessao.run then return end
		local r = sessao.run
		ReplicatedStorage:SetAttribute("RunDia", Relogio.visao(r, true).dia)
		ReplicatedStorage:SetAttribute("RunDiasRestantes", math.max(0, r.objetivo.prazoFinal - r.dia))
	end
	-- Dentro da área o grupo fica ancorado perto da porta (ninguém passeia pela cidade); no hub e no fim da run, solto.
	-- Só soltamos o que ancoramos aqui; a luta do mundo guarda/restaura o próprio estado.
	local ancorados = {} -- userId -> HumanoidRootPart
	local function raizDe(player)
		local personagem = player and player.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		return if raiz and raiz:IsA("BasePart") then raiz else nil
	end
	local function sincronizarAncoras()
		local no = sessao and sessao.run and not sessao.run.fim and sessao.historia.nos[sessao.run.galho]
		local naArea = no ~= nil and no ~= false and no.area ~= nil
		local alvo = if naArea and deps.pontoDaPorta then deps.pontoDaPorta() else nil
		local indice = 0
		if naArea then
			for userId, membro in sessao.run.jogadores do
				local raiz = raizDe(Players:GetPlayerByUserId(userId))
				if membro.presente and raiz then
					indice += 1
					if ancorados[userId] ~= raiz then
						if alvo then raiz.CFrame = CFrame.new(alvo.X + (indice - 2.5) * 3, 3, alvo.Z + 6) end
						raiz.Anchored = true
						ancorados[userId] = raiz
					elseif not raiz.Anchored then
						raiz.Anchored = true
					end
				end
			end
		end
		for userId, raiz in ancorados do
			local membro = naArea and sessao.run.jogadores[userId] or nil
			if not (membro and membro.presente) then
				if raiz.Parent then raiz.Anchored = false end
				ancorados[userId] = nil
			end
		end
	end
	local function transmitir()
		publicarRelogio()
		if not (deps.emEncontro and deps.emEncontro()) then pcall(sincronizarAncoras) end
		for _, fn in observadores do fn(sessao) end
		for _, p in Players:GetPlayers() do enviar(p, visaoPara(p)) end
	end
	local function recusa(player, motivo) enviar(player, { erro = motivo }) end
	-- Fim da run (final ou queda): paga a conta de cada jogador UMA vez (marca antes de pagar: um servidor
	-- reiniciado nunca paga duas vezes; se o pagamento falhar, fica o aviso no log).
	local function fecharConta()
		if not (deps.conta and sessao and sessao.run and sessao.run.fim) or sessao.contaRegistrada then return end
		if not sessao:marcarContaRegistrada() then return end
		for userId in sessao.run.jogadores do
			local resumo, finalId = sessao:resumo(userId)
			local conta, ganhos = deps.conta.registrarRun(userId, resumo, finalId)
			local jogador = Players:GetPlayerByUserId(userId)
			if not conta then
				warn("[Run] Conta não paga para " .. tostring(userId) .. ": " .. tostring(ganhos))
			elseif jogador then
				remote:FireClient(jogador, "conta", { ganho = ganhos.moeda, total = conta.moeda, conquistas = ganhos.conquistas })
			end
		end
	end

	-- Luta pendente do nó atual e ainda sem encontro: o servidor monta o J2 com todos os membros presentes e vivos
	-- (sem checar distância: o grupo já está dentro da área).
	local function iniciarLutaPendente(solicitante)
		local luta = sessao and sessao:lutaPendente()
		if not luta or lutaAtiva then return end
		local function apto(player)
			local membro = sessao.run.jogadores[player.UserId]
			local raiz = raizDe(player)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			return membro ~= nil and membro.presente and not membro.caido and raiz ~= nil and hum ~= nil and hum.Health > 0
		end
		if solicitante and not apto(solicitante) then recusa(solicitante, "Você não pode lutar agora."); return end
		if not deps.iniciarLuta then
			if solicitante then recusa(solicitante, "A luta ainda não está disponível neste servidor.") end
			return
		end
		local grupo = {}
		for userId in sessao.run.jogadores do
			local jogador = Players:GetPlayerByUserId(userId)
			if jogador and apto(jogador) then table.insert(grupo, jogador) end
		end
		table.sort(grupo, function(a, b) return a.UserId < b.UserId end)
		if #grupo == 0 then return end
		local id, motivo = deps.iniciarLuta(grupo, luta)
		if not id then
			if solicitante then recusa(solicitante, motivo or "Não foi possível começar a luta.") end
			return
		end
		lutaAtiva = id
	end

	-- Área concluída (flag do gerador): ouro da área a cada membro presente UMA vez por run
	-- (idempotente pelo id de pagamento, que a ficha guarda) e aviso ao cliente.
	local pagosDaArea = {} -- idPagamento/userId
	local function concluirArea()
		local area = deps.area
		if not (area and sessao and sessao.run and sessao.run.flags["expedicao/" .. area.id .. "/concluida"]) then return end
		local idPagamento = "expedicao-" .. area.id .. "-" .. tostring(sessao.run.semente)
		for userId, membro in sessao.run.jogadores do
			local chave = idPagamento .. "/" .. userId
			local jogador = Players:GetPlayerByUserId(userId)
			if jogador and membro.presente and not pagosDaArea[chave] and deps.recompensarArea then
				local ok, pago = pcall(deps.recompensarArea, jogador, idPagamento, area.recompensa.ouro, area.id)
				if ok and pago then
					pagosDaArea[chave] = true
					remote:FireClient(jogador, "expedicaoConcluida", { area = area.id, ouro = area.recompensa.ouro })
				else
					warn("[Run] Recompensa da área não creditada para " .. tostring(userId) .. ": " .. tostring(pago))
				end
			end
		end
	end

	-- Com a run ativa, o personagem pessoal só nasce com a árvore que a run deu (PersonagemSessao consulta isto).
	RestricaoDeCriacao.definir(function(player)
		local run = sessao and sessao.run
		local plano = run and not run.fim and sessao.planos[player.UserId]
		if sessao and sessao.ocupada then return nil, "Aguarde o salvamento da run." end
		if not plano then return nil end
		if plano.modo == "zero" then
			if plano.escolhida then return plano.escolhida end
			return nil, "Escolha sua árvore inicial no painel RUN antes de criar o personagem."
		elseif plano.modo == "pronto" then
			return plano.arvore
		end
		if plano.escolhida then return plano.escolhida end
		-- P2: sem árvore ainda; a ficha nasce sem ela e o mestre da vila ensina a primeira.
		return nil, nil, true
	end)

	local function processar(player, pedido)
		if not Servico.payloadValido(pedido) then return end
		local agora = os.clock()
		if ultimo[player.UserId] and agora - ultimo[player.UserId] < INTERVALO then return end
		ultimo[player.UserId] = agora
		if deps.emEncontro and deps.emEncontro() and pedido.acao ~= "consultar" then
			recusa(player, "Termine o encontro antes de mexer na run.")
			return
		end
		if pedido.acao == "consultar" then
			if not sessao then
				local tentativa = novaSessao()
				if tentativa:retomar("u" .. player.UserId) then sessao = tentativa; transmitir() end
			end
			enviar(player, visaoPara(player))
			concluirArea()
		elseif pedido.acao == "iniciar" then
			if sessao and sessao.run and not sessao.run.fim then recusa(player, "Já existe uma run em andamento."); return end
			local lista, modos = {}, {}
			for _, p in ipairs(Players:GetPlayers()) do
				if #lista < 4 then table.insert(lista, { userId = p.UserId, nome = p.DisplayName }); modos[p.UserId] = "semArvore" end
			end
			local liberadas
			if deps.conta then
				local conta, erro = deps.conta.obter(player.UserId)
				if not conta then recusa(player, erro or "Conta indisponível."); return end
				liberadas = Conta.treinadoresLiberados(conta)
				-- P2: até a primeira run acabar, o jogo escolhe o modo (sem árvore); depois o pedido vale.
				modos[player.UserId] = Abertura.modo(conta, pedido.modo)
			else
				modos[player.UserId] = pedido.modo or "semArvore"
			end
			if player.Parent ~= Players then return end
			local nova = novaSessao()
			local ok, motivo = nova:iniciar("u" .. player.UserId, lista, modos, liberadas)
			if not ok then recusa(player, motivo); return end
			sessao = nova
			transmitir()
			-- A expedição começa na entrada norte da vila, com o objetivo "Fale com um mestre".
			local nascimento = Abertura.nascimento()
			for userId in nova.run.jogadores do
				local jogador = Players:GetPlayerByUserId(userId)
				local personagem = jogador and jogador.Character
				if personagem then
					personagem:PivotTo(CFrame.lookAt(Vector3.new(nascimento.x, nascimento.y, nascimento.z), Vector3.new(nascimento.x, nascimento.y, nascimento.z - 10)))
				end
			end
		elseif not sessao then
			recusa(player, "Não há run em andamento.")
		elseif pedido.acao == "lutar" then
			iniciarLutaPendente(player)
			transmitir()
		elseif pedido.acao == "escolherArvore" then
			local ok, motivo = sessao:escolherArvore(player.UserId, pedido.arvore)
			if not ok then recusa(player, motivo); return end
			transmitir()
		elseif pedido.acao == "descansar" then
			local ok, motivo = sessao:descansarNoAcampamento(player.UserId)
			if not ok then recusa(player, motivo or "Descanso indisponível."); return end
			-- A ficha de cada presente recupera PV/PM/PT pelo mesmo caminho do descanso da mesa.
			if deps.restaurarDescanso then
				for userId, membro in sessao.run.jogadores do
					local jogador = Players:GetPlayerByUserId(userId)
					if jogador and membro.presente and not membro.caido then
						local chamou, restaurou, erro = pcall(deps.restaurarDescanso, jogador)
						if not (chamou and restaurou) then
							warn("[Run] Descanso não restaurou a ficha de " .. tostring(userId) .. ": " .. tostring(if chamou then erro else restaurou))
						end
					end
				end
			end
			transmitir()
		elseif pedido.acao == "votar" then
			-- Entrar/retomar a expedição só vale perto da porta; o resto da votação é livre de lugar.
			local no = sessao.historia.nos[sessao.run.galho]
			if ehOpcaoDePorta(pedido.opcao) and no and no.tipo == "hub" and not (deps.portaPerto and deps.portaPerto(player)) then
				recusa(player, "Chegue perto da porta do esgoto."); return
			end
			-- Sem ficha de luta (personagem ainda sem caminho de poder, ou caído) a sala não teria como
			-- começar e o grupo ficaria preso dentro da área: recusar antes de gastar o dia.
			if ehOpcaoDePorta(pedido.opcao) and no and no.tipo == "hub" and deps.prontoParaLutar then
				for userId, membro in sessao.run.jogadores do
					local jogador = Players:GetPlayerByUserId(userId)
					if jogador and membro.presente and not membro.caido then
						local pronto, motivo = deps.prontoParaLutar(jogador)
						if not pronto then
							recusa(player, (if jogador == player then "Você" else jogador.DisplayName) .. " ainda não pode lutar: " .. (motivo or "aprenda um caminho com um mestre da vila."))
							return
						end
					end
				end
			end
			local ok, resultado = sessao:votar(player.UserId, pedido.opcao)
			if not ok then recusa(player, resultado); return end
			transmitir()
			iniciarLutaPendente(player)
			fecharConta()
			concluirArea()
		end
	end
	remote.OnServerEvent:Connect(function(player, pedido)
		if processando or (sessao and sessao.ocupada) then recusa(player, "Aguarde a operação da run."); return end
		processando = true
		local ok, erro = pcall(processar, player, pedido)
		processando = false
		if not ok then warn("[Run] " .. tostring(erro)); recusa(player, "Falha ao processar a run.") end
	end)

	Players.PlayerRemoving:Connect(function(player)
		while processando or (sessao and sessao.ocupada) do task.wait() end
		ultimo[player.UserId] = nil
		if sessao and sessao.run and sessao.run.jogadores[player.UserId] and not sessao.run.fim then
			sessao:ausentar(player.UserId)
			transmitir()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		while processando or (sessao and sessao.ocupada) do task.wait() end
		if sessao and sessao.run and sessao.run.jogadores[player.UserId] and not sessao.run.fim then
			sessao:retornar(player.UserId)
		end
		if sessao then enviar(player, visaoPara(player)) end
	end)

 -- Checkpoint de save a cada 15 s (protege contra queda do servidor entre votos).
 task.spawn(function()
  while true do
   task.wait(15)
   if not processando and sessao and sessao.run and not sessao.run.fim and not sessao.ocupada then
    processando = true
    pcall(function() sessao:_salvar() end)
    processando = false
   end
  end
 end)
 -- Respawn do avatar dentro da área: reancora.
 local function aoNascer(player)
  player.CharacterAdded:Connect(function()
   task.wait(1)
   if not processando and not (deps.emEncontro and deps.emEncontro()) then pcall(sincronizarAncoras) end
  end)
 end
 Players.PlayerAdded:Connect(aoNascer)
 for _, p in Players:GetPlayers() do aoNascer(p) end
 game:BindToClose(function()
  if sessao and sessao.run and not sessao.ocupada then sessao:_salvar() end
 end)

	return {
		-- Para testes/ferramentas: estado atual da sessão (nil sem run).
		sessao = function() return sessao end,
		transmitir = transmitir,
  podeDescansar = function(player)
   if not sessao or not sessao.run or sessao.run.fim then return true end
   if processando or not sessao or (deps.emEncontro and deps.emEncontro()) then return false, "Run indisponível." end
   return sessao:podeDescansar(player.UserId)
  end,
  -- Chamado pelo serviço de descanso após validar lugar, alcance, combate e cooldown.
  descansar = function(player,tipo)
   if not sessao or not sessao.run or sessao.run.fim then return true end
   if processando or not sessao or (deps.emEncontro and deps.emEncontro()) then return false, "Run indisponível." end
   processando = true
   local ok, erro = sessao:descansar(player.UserId,tipo)
   processando = false
   if ok then publicarRelogio(); transmitir() end
   return ok, erro
  end,
		ocupado = function() return processando or (sessao and sessao.ocupada) end,
		observar = function(fn) table.insert(observadores, fn); fn(sessao) end,
		-- Chamado quando QUALQUER encontro J2 termina; só interessa o da luta do chefe da run.
		encerrado = function(encontro, estado)
			if not sessao or not sessao.run or sessao.run.fim or type(estado) ~= "table" then return end
			if not lutaAtiva or estado.encounterId ~= lutaAtiva then
				-- Encontro comum (patrulha, marco) durante a run: derrota derruba quem lutou; o grupo todo caído encerra a run.
				if estado.phase == "defeat" and type(encontro) == "table" and type(encontro.atoresPorJogador) == "table" then
					for userId in encontro.atoresPorJogador do
						if sessao.run.jogadores[userId] then sessao:cair(userId, true) end
					end
					transmitir()
					fecharConta()
				end
				return
			end
			local fonteLoot = lutaAtiva
			lutaAtiva = nil
			local fase = estado.phase
			local resultado = if fase == "victory" then "victory" elseif fase == "defeat" then "defeat" else "fled"
			local ok, motivo = sessao:lutaTerminou(resultado)
			if not ok then warn("[Run] Desfecho da luta não aplicado: " .. tostring(motivo)) end
			if ok and fase == "victory" and deps.conta and deps.conta.registrarLootChefe then
				-- Só participantes da luta; observadores não recebem uma rolagem.
				local premiados = {}
				for userId, atorId in encontro.atoresPorJogador or {} do
					local ator = encontro.atoresPorId and encontro.atoresPorId[atorId]
					if not (ator and ator.fled) then table.insert(premiados, userId) end
				end
				-- Persistência não segura o processamento do encontro nem lê a sessão após I/O.
				task.defer(function()
					for _, userId in premiados do
						local conta, peca = deps.conta.registrarLootChefe(userId, fonteLoot, Random.new())
						if not conta then warn("[Aparencia] Falha ao persistir loot do chefe: " .. tostring(peca)) end
						local jogador = Players:GetPlayerByUserId(userId)
						if conta and peca and jogador then
							local item = CatalogoAparencia.PECAS[peca]
							remote:FireClient(jogador, "lootRaro", { peca = peca, nome = item.nome, raridade = item.raridade })
						end
					end
				end)
			end
			-- A luta já acabou: solta/ancora conforme o nó (transmitir pula a sincronização se o encontro ainda consta ativo).
			pcall(sincronizarAncoras)
			transmitir()
			fecharConta()
		end,
	}
end

return Servico
