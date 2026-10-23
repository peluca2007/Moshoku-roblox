-- Integra o Dojo persistido a Hanzo e ao encontro J2; decisões e recompensas ficam no servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Dojo = require(ReplicatedStorage.Shared.Regras.Dojo)
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)

local Service = {}
local REMOTE = "Dojo"
local MESTRE = { patamar = "Avançado" } -- Hanzo é NPC do protótipo, sem patente na fonte do livro.

function Service.payloadValido(pedido)
	if type(pedido) ~= "table" or getmetatable(pedido) ~= nil or type(pedido.acao) ~= "string" then return false end
	if pedido.acao == "consultar" or pedido.acao == "iniciar" then
		for chave in pedido do if chave ~= "acao" then return false end end
		return true
	end
	if pedido.acao ~= "escolher" or (pedido.porta ~= "travado" and pedido.porta ~= "livre" and pedido.porta ~= "marca") then return false end
	for chave in pedido do if chave ~= "acao" and chave ~= "porta" then return false end end
	return true
end

local function copiar(valor)
	if type(valor) ~= "table" then return valor end
	local r = {}
	for k, v in valor do r[k] = copiar(v) end
	return r
end

function Service.start(deps)
	local remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE
	remote.Parent = ReplicatedStorage
	local pendentes, ultimo = {}, {}
	local function enviar(player, tipo, dado) remote:FireClient(player, tipo, dado) end
	local function perto(player)
		local npc = workspace:FindFirstChild("Vila")
		local npcs = npc and npc:FindFirstChild("Npcs")
		local hanzo = npcs and npcs:FindFirstChild("Mestre Hanzo")
		local raizNpc = hanzo and hanzo:FindFirstChild("HumanoidRootPart")
		local char = player.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		return raizNpc and raiz and hum and hum.Health > 0
			and (raiz.Position - raizNpc.Position).Magnitude <= 10
	end
	local function contexto(player)
		return player and player.Parent == Players and not deps.emCombate(player)
			and not deps.encontro.emEncontroAtivo() and perto(player)
	end
	local function dados(player)
		local perfil = deps.consultar(player)
		if not perfil then return nil, "Crie ou carregue uma ficha pessoal antes de treinar." end
		local estado = perfil.dojo or Dojo.novoEstado()
		local arvore = perfil.construcao and perfil.construcao.startingTreeId
		local entrada = type(arvore) == "string" and Catalogo.POR_ID[arvore]
		local nome = entrada and entrada.data and entrada.data.name or arvore
		local patamar = "Principiante"
		local pode, motivo = Dojo.podeIniciar(estado, nome or "", MESTRE, patamar)
		return { estado = estado, arvore = nome, podeIniciar = pode ~= nil, motivo = motivo,
			recompensa = Dojo.recompensa(patamar), mestre = MESTRE.patamar }
	end
	local function responder(player)
		if not contexto(player) then enviar(player, "dojo", { erro = "Aproxime-se de Hanzo fora de combate." }); return end
		local estado, erro = dados(player)
		if not estado then enviar(player, "dojo", { erro = erro }); return end
		local pendente = pendentes[player.UserId]
		estado.podeEscolher = pendente ~= nil and pendente.concluida == true
		enviar(player, "dojo", estado)
	end
	remote.OnServerEvent:Connect(function(player, pedido)
		if not Service.payloadValido(pedido) then return end
		if not contexto(player) then enviar(player, "dojo", { erro = "Aproxime-se de Hanzo fora de combate." }); return end
		local agora = os.clock()
		if ultimo[player.UserId] and agora - ultimo[player.UserId] < 0.5 then return end
		ultimo[player.UserId] = agora
		if pedido.acao == "consultar" then responder(player); return end
		local info, erro = dados(player)
		if not info then enviar(player, "dojo", { erro = erro }); return end
		if pedido.acao == "iniciar" then
			if pendentes[player.UserId] then enviar(player, "dojo", { erro = "Finalize a escolha da provação anterior." }); return end
			if not info.podeIniciar then enviar(player, "dojo", { erro = info.motivo }); return end
			local id, falha = deps.encontro.criarProvaDojo(player)
			if not id then enviar(player, "dojo", { erro = falha or "Não foi possível iniciar a provação." }); return end
			pendentes[player.UserId] = { encounterId = id, arvore = info.arvore }
			enviar(player, "dojo", { iniciada = true })
			return
		end
		local pendente = pendentes[player.UserId]
		if not pendente or not pendente.concluida then enviar(player, "dojo", { erro = "Conclua a provação antes de escolher." }); return end
		local novo, ganho, motivo = Dojo.concluir(info.estado, pendente.arvore, MESTRE, "Principiante", pedido.porta)
		if not novo then enviar(player, "dojo", { erro = motivo }); return end
		local salvou, falha = deps.atualizar(player, novo)
		if not salvou then enviar(player, "dojo", { erro = falha }); return end
		pendentes[player.UserId] = nil
		enviar(player, "dojo", { concluida = true, ganho = ganho, estado = novo, paLivreGuardado = ganho.livre })
	end)
	Players.PlayerRemoving:Connect(function(player) pendentes[player.UserId], ultimo[player.UserId] = nil, nil end)
	return {
		abrir = responder,
		encerrado = function(encontro, estado)
			local participante
			for _, ator in (encontro.ordemInicial or {}) do
				local candidato = encontro.atoresPorId and encontro.atoresPorId[ator]
				if candidato and candidato.userId then participante = candidato; break end
			end
			local userId = participante and participante.userId
			local pendente = userId and pendentes[userId]
			if pendente and pendente.encounterId == estado.encounterId then
				pendente.concluida = estado.phase == "victory"
				local jogador = Players:GetPlayerByUserId(userId)
				if jogador then enviar(jogador, "dojo", { podeEscolher = pendente.concluida,
					erro = if pendente.concluida then nil else "A provação falhou; tente novamente." }) end
			end
		end,
	}
end

return Service
