-- Recebe estado/recibos do encontro autônomo e envia intenção sem escolher ator.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local State = {}
local remote: RemoteEvent? = nil
local estadoAtual = nil
local aguardando = false
local retornoPendente = nil
local habilidadeEmMira = nil
local filaAtual = { jogadores = {}, liderUserId = nil }
local listeners = { estado = {}, recibo = {}, recusado = {}, retorno = {}, fila = {} }

local function emitir(tipo, dado)
	for _, callback in listeners[tipo] do
		task.spawn(callback, dado)
	end
end

function State.start()
	if remote then return end
	remote = ReplicatedStorage:WaitForChild("EncontroAutonomo") :: RemoteEvent
	remote.OnClientEvent:Connect(function(tipo, dado)
		if tipo == "estado" and type(dado) == "table"
			and type(dado.encounterId) == "string"
			and type(dado.version) == "number"
		then
			estadoAtual = dado
			aguardando = false
			emitir("estado", dado)
		elseif tipo == "recibo" and type(dado) == "table" then
			aguardando = false
			emitir("recibo", dado)
		elseif tipo == "recusado" and type(dado) == "table" then
			aguardando = false
			habilidadeEmMira = nil
			retornoPendente = nil
			if type(dado.estado) == "table" then
				estadoAtual = dado.estado
				emitir("estado", estadoAtual)
			end
			emitir("recusado", dado.mensagem)
		elseif tipo == "retornado" and type(dado) == "table"
			and retornoPendente == dado.encounterId
		then
			retornoPendente = nil
			estadoAtual = nil
			aguardando = false
		elseif tipo == "fila" and type(dado) == "table" and type(dado.jogadores) == "table" then
			filaAtual = dado
			aguardando = false
			emitir("fila", filaAtual)
		end
	end)
	-- O servidor só devolve estado se este UserId ainda pertencer a um encontro
	-- mantido nesta sessão. Não bloqueia o fluxo de início quando não há encontro.
	remote:FireServer({
		command = "reconnect-autonomous",
		requestId = HttpService:GenerateGUID(false),
	})
end

function State.onEstado(callback)
	table.insert(listeners.estado, callback)
	if estadoAtual then task.spawn(callback, estadoAtual) end
end

function State.onRecibo(callback)
	table.insert(listeners.recibo, callback)
end

function State.onRecusado(callback)
	table.insert(listeners.recusado, callback)
end

function State.onRetorno(callback)
	table.insert(listeners.retorno, callback)
end

function State.onFila(callback)
	table.insert(listeners.fila, callback)
	task.spawn(callback, filaAtual)
end

function State.fila()
	return filaAtual
end

function State.avisarRetorno()
	local atual = estadoAtual
	if not remote or not atual or (atual.phase ~= "victory" and atual.phase ~= "defeat" and atual.phase ~= "fled") or aguardando then
		return false
	end
	retornoPendente = atual.encounterId
	aguardando = true
	remote:FireServer({
		command = "return-autonomous",
		encounterId = atual.encounterId,
		requestId = HttpService:GenerateGUID(false),
	})
	estadoAtual = nil
	emitir("retorno")
	return true
end

function State.estado()
	return estadoAtual
end

local function solicitarInicio(comando)
	if not remote or aguardando or (estadoAtual and estadoAtual.phase == "active") then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = comando,
		requestId = HttpService:GenerateGUID(false),
	})
	return true
end

function State.iniciar()
	return solicitarInicio("start-autonomous")
end

function State.alterarFila(entrar)
	if not remote or aguardando or (estadoAtual and estadoAtual.phase == "active") then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = if entrar then "join-autonomous-queue" else "leave-autonomous-queue",
		requestId = HttpService:GenerateGUID(false),
	})
	return true
end

function State.fugir()
	local atual = estadoAtual
	if not remote or aguardando or not atual or atual.phase ~= "active"
		or not atual.isMyTurn or (atual.actionsRemaining or 0) < 1 then return false end
	aguardando = true
	remote:FireServer({ command = "flee-encounter", encounterId = atual.encounterId,
		expectedVersion = atual.version, requestId = HttpService:GenerateGUID(false) })
	return true
end

function State.desistir()
	local atual = estadoAtual
	local actorId = atual and atual.controlledActorId
	if not remote or aguardando or not atual or atual.phase ~= "active" or type(actorId) ~= "string" then
		return false
	end
	local ator
	for _, candidato in atual.actors or {} do
		if candidato.id == actorId then ator = candidato; break end
	end
	if not ator or type(ator.pv) ~= "number" or ator.pv <= 0 or ator.defeated == true then return false end
	aguardando = true
	remote:FireServer({
		command = "abandon-encounter",
		encounterId = atual.encounterId,
		expectedVersion = atual.version,
		requestId = HttpService:GenerateGUID(false),
	})
	return true
end

function State.encerrarTurno()
	if not remote or aguardando or not estadoAtual or not estadoAtual.isMyTurn then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = "end-turn",
		encounterId = estadoAtual.encounterId,
		expectedVersion = estadoAtual.version,
		requestId = HttpService:GenerateGUID(false),
	})
	return true
end

function State.atacar(targetId)
	if not remote or aguardando or not estadoAtual or not estadoAtual.isMyTurn
		or estadoAtual.actionsRemaining <= 0 or type(targetId) ~= "string"
	then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = "basic-attack",
		encounterId = estadoAtual.encounterId,
		expectedVersion = estadoAtual.version,
		requestId = HttpService:GenerateGUID(false),
		targetId = targetId,
	})
	return true
end

function State.disparar(targetId)
	if not remote or aguardando or not estadoAtual or not estadoAtual.isMyTurn
		or estadoAtual.actionsRemaining <= 0 or type(targetId) ~= "string"
	then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = "ranged-attack",
		encounterId = estadoAtual.encounterId,
		expectedVersion = estadoAtual.version,
		requestId = HttpService:GenerateGUID(false),
		targetId = targetId,
	})
	return true
end

function State.usarHabilidade(abilityId, targetId)
	local acaoLivre = abilityId == "mesa/mao-de-terra-soltar"
	if not remote or aguardando or not estadoAtual or not estadoAtual.isMyTurn
		or (estadoAtual.actionsRemaining <= 0 and not acaoLivre) or type(abilityId) ~= "string" or type(targetId) ~= "string"
		or not table.find(estadoAtual.availableAbilities or {}, abilityId)
	then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = "use-ability",
		encounterId = estadoAtual.encounterId,
		expectedVersion = estadoAtual.version,
		requestId = HttpService:GenerateGUID(false),
		abilityId = abilityId,
		targetId = targetId,
	})
	habilidadeEmMira = nil
	return true
end

function State.iniciarMira(abilityId)
	if not estadoAtual or not estadoAtual.isMyTurn or aguardando
		or not table.find(estadoAtual.availableAbilities or {}, abilityId)
	then return false end
	habilidadeEmMira = if habilidadeEmMira == abilityId then nil else abilityId
	return true
end

function State.habilidadeEmMira()
	return habilidadeEmMira
end

function State.usarItem(itemId, targetId)
	if not remote or aguardando or not estadoAtual or not estadoAtual.isMyTurn
		or estadoAtual.actionsRemaining <= 0 or type(itemId) ~= "string" or type(targetId) ~= "string"
		or not table.find(estadoAtual.availableItems or {}, itemId)
	then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = "use-item",
		encounterId = estadoAtual.encounterId,
		expectedVersion = estadoAtual.version,
		requestId = HttpService:GenerateGUID(false),
		itemId = itemId,
		targetId = targetId,
	})
	return true
end

function State.mover(x, z)
	if not remote or aguardando or not estadoAtual or not estadoAtual.isMyTurn
		or estadoAtual.actionsRemaining <= 0
		or type(x) ~= "number" or x % 1 ~= 0 or type(z) ~= "number" or z % 1 ~= 0
	then
		return false
	end
	aguardando = true
	remote:FireServer({
		command = "move",
		encounterId = estadoAtual.encounterId,
		expectedVersion = estadoAtual.version,
		requestId = HttpService:GenerateGUID(false),
		x = x,
		z = z,
	})
	return true
end

return State
