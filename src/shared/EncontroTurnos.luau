-- Estado puro de ordem e avanço de turnos para a fatia autônoma J2.
-- A ordem é entregue pelo serviço autoritativo; este módulo não inventa iniciativa.
local EncontroTurnos = {}
-- Livro, Cap. 4 §4: todo combatente recebe 3 Ações por turno.
local ACOES_POR_TURNO = 3

local function copiarEstado(estado)
	return {
		encounterId = estado.encounterId,
		version = estado.version,
		turn = estado.turn,
		phase = estado.phase,
		order = table.clone(estado.order),
		currentIndex = estado.currentIndex,
		actionsRemaining = estado.actionsRemaining,
		lastRequest = estado.lastRequest and table.clone(estado.lastRequest) or nil,
		lastAction = estado.lastAction and table.clone(estado.lastAction) or nil,
	}
end

local function textoValido(valor, maximo)
	return type(valor) == "string" and #valor > 0 and #valor <= maximo
end

function EncontroTurnos.criar(encounterId, ordem)
	if not textoValido(encounterId, 96) then
		return nil, "ID do encontro inválido."
	end
	if type(ordem) ~= "table" or #ordem < 2 or #ordem > 16 then
		return nil, "A ordem precisa conter de 2 a 16 participantes."
	end

	local vistos = {}
	local ordemCopia = table.create(#ordem)
	for indice, actorId in ipairs(ordem) do
		if not textoValido(actorId, 96) or vistos[actorId] then
			return nil, "A ordem contém participante inválido ou repetido."
		end
		vistos[actorId] = true
		ordemCopia[indice] = actorId
	end

	return {
		encounterId = encounterId,
		version = 1,
		turn = 1,
		phase = "active",
		order = ordemCopia,
		currentIndex = 1,
		actionsRemaining = ACOES_POR_TURNO,
		lastRequest = nil,
		lastAction = nil,
	}
end

function EncontroTurnos.consultar(estado)
	if type(estado) ~= "table" or type(estado.order) ~= "table" then
		return nil
	end
	return {
		encounterId = estado.encounterId,
		version = estado.version,
		turn = estado.turn,
		phase = estado.phase,
		currentActorId = estado.order[estado.currentIndex],
		actionsRemaining = estado.actionsRemaining,
	}
end

-- Reserva uma Ação para uma resolução do servidor (ataque/habilidade/mover).
-- A regra não interpreta a ação; o chamador deve validar e aplicar o efeito
-- dentro da mesma transação antes de publicar o novo estado.
function EncontroTurnos.consumirAcao(estado, pedido)
	if type(estado) ~= "table" or type(estado.order) ~= "table" or #estado.order < 1 then
		return nil, nil, "Estado do encontro inválido."
	end
	if type(pedido) ~= "table"
		or not textoValido(pedido.actorId, 96)
		or not textoValido(pedido.requestId, 96)
		or (pedido.action ~= nil and not textoValido(pedido.action, 96))
		or (pedido.targetId ~= nil and not textoValido(pedido.targetId, 96))
		or (pedido.actionsCost ~= nil and (type(pedido.actionsCost) ~= "number"
			or pedido.actionsCost % 1 ~= 0 or pedido.actionsCost < 0 or pedido.actionsCost > ACOES_POR_TURNO))
		or type(pedido.expectedVersion) ~= "number"
		or pedido.expectedVersion % 1 ~= 0
	then
		return nil, nil, "Pedido de ação inválido."
	end
	local ultimo = estado.lastAction
	if ultimo and ultimo.requestId == pedido.requestId then
		if ultimo.actorId == pedido.actorId and ultimo.expectedVersion == pedido.expectedVersion
			and ultimo.action == (pedido.action or "spend-action") and ultimo.targetId == pedido.targetId
			and ultimo.actionsCost == (pedido.actionsCost or 1)
		then
			return copiarEstado(estado), table.clone(ultimo.receipt), "Pedido já aplicado."
		end
		return nil, nil, "ID de pedido já usado com outro conteúdo."
	end
	if #estado.order < 2 then return nil, nil, "O encontro não tem mais atores ativos." end
	if estado.phase ~= "active" then return nil, nil, "O encontro não está ativo." end
	if pedido.expectedVersion ~= estado.version then return nil, nil, "Versão desatualizada." end
	if pedido.actorId ~= estado.order[estado.currentIndex] then return nil, nil, "Não é a vez deste participante." end
	local custoAcoes = pedido.actionsCost or 1
	if type(estado.actionsRemaining) ~= "number" or estado.actionsRemaining < custoAcoes then
		return nil, nil, if custoAcoes == 1 then "Sem Ações restantes neste turno." else "Ações insuficientes neste turno."
	end

	local novo = copiarEstado(estado)
	local recibo = {
		encounterId = estado.encounterId,
		version = estado.version + 1,
		turn = estado.turn,
		actorId = pedido.actorId,
		action = pedido.action or "spend-action",
		actionsRemaining = estado.actionsRemaining - custoAcoes,
	}
	if pedido.targetId then recibo.targetId = pedido.targetId end
	if custoAcoes > 1 then recibo.actionsSpent = custoAcoes end
	if type(pedido.result) == "table" then recibo.result = table.clone(pedido.result) end
	novo.version = recibo.version
	novo.actionsRemaining = recibo.actionsRemaining
	novo.lastAction = {
		requestId = pedido.requestId,
		actorId = pedido.actorId,
		expectedVersion = pedido.expectedVersion,
		action = pedido.action or "spend-action",
		targetId = pedido.targetId,
		actionsCost = custoAcoes,
		receipt = recibo,
	}
	return novo, recibo
end

-- Retira um ator derrotado dentro da mesma versão da ação que o derrotou.
-- Não cria recibo próprio nem avança o turno; serve apenas para manter a fila
-- ativa consistente antes de publicar a transação já versionada.
function EncontroTurnos.removerDerrotado(estado, actorId)
	if type(estado) ~= "table" or type(estado.order) ~= "table"
		or type(actorId) ~= "string"
	then
		return nil, "Ator derrotado inválido."
	end
	local indice = table.find(estado.order, actorId)
	if not indice then return nil, "Ator derrotado não está na fila ativa." end
	local novo = copiarEstado(estado)
	table.remove(novo.order, indice)
	if indice < novo.currentIndex then novo.currentIndex -= 1 end
	if indice == estado.currentIndex and #novo.order > 0 and novo.currentIndex > #novo.order then
		novo.currentIndex = 1
	end
	if #novo.order <= 1 then novo.phase = "victory" end
	return novo
end

function EncontroTurnos.concluir(estado, resultado)
	if type(estado) ~= "table" or type(estado.order) ~= "table"
		or (resultado ~= "victory" and resultado ~= "defeat")
	then
		return nil, "Resultado do encontro inválido."
	end
	local novo = copiarEstado(estado)
	novo.phase = resultado
	return novo
end

function EncontroTurnos.encerrarTurno(estado, pedido)
	if type(estado) ~= "table" or type(estado.order) ~= "table" or #estado.order < 2 then
		return nil, nil, "Estado do encontro inválido."
	end
	if type(pedido) ~= "table"
		or not textoValido(pedido.actorId, 96)
		or not textoValido(pedido.requestId, 96)
		or type(pedido.expectedVersion) ~= "number"
		or pedido.expectedVersion % 1 ~= 0
	then
		return nil, nil, "Pedido de turno inválido."
	end

	local ultimo = estado.lastRequest
	if ultimo and ultimo.requestId == pedido.requestId then
		if ultimo.actorId == pedido.actorId and ultimo.expectedVersion == pedido.expectedVersion then
			return copiarEstado(estado), table.clone(ultimo.receipt), "Pedido já aplicado."
		end
		return nil, nil, "ID de pedido já usado com outro conteúdo."
	end
	if estado.phase ~= "active" then
		return nil, nil, "O encontro não está ativo."
	end
	if pedido.expectedVersion ~= estado.version then
		return nil, nil, "Versão desatualizada."
	end
	if pedido.actorId ~= estado.order[estado.currentIndex] then
		return nil, nil, "Não é a vez deste participante."
	end

	local novo = copiarEstado(estado)
	local proximoIndice = estado.currentIndex % #estado.order + 1
	local proximaRodada = estado.turn + (proximoIndice == 1 and 1 or 0)
	local recibo = {
		encounterId = estado.encounterId,
		version = estado.version + 1,
		turn = proximaRodada,
		actorId = pedido.actorId,
		action = "end-turn",
		nextActorId = estado.order[proximoIndice],
	}

	novo.version = recibo.version
	novo.turn = proximaRodada
	novo.currentIndex = proximoIndice
	novo.actionsRemaining = ACOES_POR_TURNO
	novo.lastAction = nil
	novo.lastRequest = {
		requestId = pedido.requestId,
		actorId = pedido.actorId,
		expectedVersion = pedido.expectedVersion,
		receipt = recibo,
	}
	return novo, recibo
end

-- Abandonar é saída de jogador da luta (contrato legado), sem gastar Ações.
-- O servidor autentica UserId e aplica PV/estado derrotado antes de publicar.
function EncontroTurnos.desistir(estado, pedido)
	if type(estado) ~= "table" or type(estado.order) ~= "table" or #estado.order < 2 then
		return nil, nil, "Estado do encontro inválido."
	end
	if type(pedido) ~= "table"
		or not textoValido(pedido.actorId, 96)
		or not textoValido(pedido.requestId, 96)
		or type(pedido.expectedVersion) ~= "number"
		or pedido.expectedVersion % 1 ~= 0
	then
		return nil, nil, "Pedido de desistência inválido."
	end
	local function reconhecerRepeticao(anterior)
		if anterior and anterior.requestId == pedido.requestId then
			if anterior.action == "abandon-encounter"
				and anterior.actorId == pedido.actorId
				and anterior.expectedVersion == pedido.expectedVersion
			then
				return copiarEstado(estado), table.clone(anterior.receipt), "Pedido já aplicado."
			end
			return nil, nil, "ID de pedido já usado com outro conteúdo."
		end
		return false
	end
	local repeticao, reciboAnterior, erroAnterior = reconhecerRepeticao(estado.lastAction)
	if repeticao ~= false then return repeticao, reciboAnterior, erroAnterior end
	repeticao, reciboAnterior, erroAnterior = reconhecerRepeticao(estado.lastRequest)
	if repeticao ~= false then return repeticao, reciboAnterior, erroAnterior end
	if estado.phase ~= "active" then return nil, nil, "O encontro não está ativo." end
	if pedido.expectedVersion ~= estado.version then return nil, nil, "Versão desatualizada." end
	local indice = table.find(estado.order, pedido.actorId)
	if not indice then return nil, nil, "Participante não está na fila ativa." end

	local novo = copiarEstado(estado)
	local eraVezDoAtor = indice == estado.currentIndex
	table.remove(novo.order, indice)
	if eraVezDoAtor then
		if indice > #novo.order then
			novo.currentIndex = 1
			if #novo.order > 0 then novo.turn += 1 end
		else
			novo.currentIndex = indice
		end
		novo.actionsRemaining = ACOES_POR_TURNO
		novo.lastAction = nil
	elseif indice < novo.currentIndex then
		novo.currentIndex -= 1
	end

	local recibo = {
		encounterId = estado.encounterId,
		version = estado.version + 1,
		turn = novo.turn,
		actorId = pedido.actorId,
		action = "abandon-encounter",
		nextActorId = novo.order[novo.currentIndex],
	}
	novo.version = recibo.version
	novo.lastRequest = {
		requestId = pedido.requestId,
		actorId = pedido.actorId,
		expectedVersion = pedido.expectedVersion,
		action = "abandon-encounter",
		receipt = recibo,
	}
	return novo, recibo
end

return EncontroTurnos
