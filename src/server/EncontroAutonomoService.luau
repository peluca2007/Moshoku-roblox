-- Coordena a transição versionada de turno para encontros fora da mesa legado.
-- A criação é somente servidor; o cliente pode pedir para encerrar a própria vez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncontrosPorZona = require(ReplicatedStorage.Shared.EncontrosPorZona)
local Turnos = require(ReplicatedStorage.Shared.EncontroTurnos)
local Iniciativa = require(ReplicatedStorage.Shared.EncontroIniciativa)
local GradeTatica = require(script.Parent.Mundo.GradeTatica)
local RegrasPatrulha = require(ReplicatedStorage.Shared.Regras.EncontroPatrulha)
local Elenco = require(ReplicatedStorage.Shared.EncontroAutonomoElenco)
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)
local Criaturas = require(ReplicatedStorage.Shared.Regras.Criaturas)
local CombateAutonomo = require(ReplicatedStorage.Shared.EncontroAutonomoCombate)
local HabilidadesAutonomas = require(ReplicatedStorage.Shared.EncontroAutonomoHabilidades)
local EstadoHabilidades = require(ReplicatedStorage.Shared.Regras.EstadoHabilidades)
local ItensAutonomos = require(ReplicatedStorage.Shared.EncontroAutonomoItens)
local Habilidades = require(ReplicatedStorage.Shared.Regras.Habilidades)
local Combate = require(ReplicatedStorage.Shared.Regras.Combate)
local Fogo = require(ReplicatedStorage.Shared.Regras.Fogo)
local Maestrias = require(ReplicatedStorage.Shared.Regras.Maestrias)
local Execucao = require(ReplicatedStorage.Shared.Regras.Execucao)
local MovimentoAutonomo = require(ReplicatedStorage.Shared.EncontroAutonomoMovimento)
local TerrenoAutonomo = require(ReplicatedStorage.Shared.EncontroAutonomoTerreno)
local DefesasAutonomas = require(ReplicatedStorage.Shared.EncontroAutonomoDefesas)
local Recompensa = require(ReplicatedStorage.Shared.Regras.RecompensaEncontro)

local EncontroAutonomoService = {}
local REMOTE_NAME = "EncontroAutonomo"
local INTERVALO_PEDIDO = 0.25
local INTERVALO_INICIO = 1
local PRAZO_TURNO = 60
local PRAZO_ENCONTRO_SEM_JOGADORES = 60
local CRIATURAS_DO_ENCONTRO_INICIAL = { "creature/goblin-batedor", "creature/lobo-cinzento" }
local instancia

local function idValido(valor)
	return type(valor) == "string" and #valor > 0 and #valor <= 96
end

local function copiar(valor, vistos)
	if type(valor) ~= "table" then return valor end
	vistos = vistos or {}
	if vistos[valor] then return vistos[valor] end
	local resultado = {}
	vistos[valor] = resultado
	for chave, item in valor do
		resultado[copiar(chave, vistos)] = copiar(item, vistos)
	end
	return resultado
end

local function prepararAtorBase(ator)
	local atorSalvo = copiar(ator)
	if atorSalvo.kind == "criatura" then
		-- Recompensa só pode vir do elenco montado no servidor, nunca do remoto.
		atorSalvo.recompensa = type(ator.recompensa) == "table" and copiar(ator.recompensa) or nil
	end
	atorSalvo.pvTemporarios = nil
	atorSalvo.condicoes = type(atorSalvo.condicoes) == "table" and atorSalvo.condicoes or {}
	if atorSalvo.kind == nil then
		atorSalvo.kind = if atorSalvo.userId ~= nil then "jogador" else "criatura"
	end
	if atorSalvo.kind ~= "jogador" and atorSalvo.kind ~= "criatura" then
		return nil, "Tipo de ator inválido."
	end
	atorSalvo.respira = if atorSalvo.kind == "jogador"
		then true else atorSalvo.respira == true
			or (type(atorSalvo.fichaCriatura) == "table" and atorSalvo.fichaCriatura.respira == true)
	if atorSalvo.kind == "jogador" and type(atorSalvo.ficha) == "table" then
		local calculado = atorSalvo.ficha.calculated
		if type(calculado) == "table" and type(calculado.maxima) == "table"
			and type(calculado.maxima.pv) == "number" and type(calculado.armorClass) == "number"
		then
			atorSalvo.pvMax, atorSalvo.ca = calculado.maxima.pv, calculado.armorClass
			atorSalvo.pv = calculado.maxima.pv
		end
		local maxima = if type(calculado) == "table" then calculado.maxima else nil
		local sessao = atorSalvo.ficha.session
		local atuais = if type(sessao) == "table" then sessao.current else nil
		atorSalvo.pmMax = if type(maxima) == "table" and type(maxima.pm) == "number" then maxima.pm else 0
		if type(maxima) == "table" and type(maxima.pv) == "number" then
			atorSalvo.pv = if type(atuais) == "table" and type(atuais.pv) == "number"
				then math.clamp(atuais.pv, 0, maxima.pv) else maxima.pv
		end
		atorSalvo.pm = if type(atuais) == "table" and type(atuais.pm) == "number"
			then math.clamp(atuais.pm, 0, atorSalvo.pmMax) else atorSalvo.pmMax
		atorSalvo.ptMax = if type(maxima) == "table" and type(maxima.pt) == "number" then maxima.pt else 0
		atorSalvo.ppMax = if type(maxima) == "table" and type(maxima.pp) == "number" then maxima.pp else 0
		atorSalvo.pt = if type(atuais) == "table" and type(atuais.pt) == "number"
			then math.clamp(atuais.pt, 0, atorSalvo.ptMax) else atorSalvo.ptMax
		atorSalvo.pp = if type(atuais) == "table" and type(atuais.pp) == "number"
			then math.clamp(atuais.pp, 0, atorSalvo.ppMax) else atorSalvo.ppMax
	elseif atorSalvo.kind == "criatura" and type(atorSalvo.fichaCriatura) == "table" then
		local fichaCriatura = atorSalvo.fichaCriatura
		if type(fichaCriatura.pvMax) == "number" and type(fichaCriatura.ca) == "number" then
			atorSalvo.pvMax, atorSalvo.ca = fichaCriatura.pvMax, fichaCriatura.ca
			atorSalvo.pv = fichaCriatura.pvMax
		end
		atorSalvo.pm, atorSalvo.pmMax = 0, 0
		if type(fichaCriatura.deslocamentoMetros) == "number" and fichaCriatura.deslocamentoMetros >= 0 then
			atorSalvo.movementCasas = math.floor(fichaCriatura.deslocamentoMetros / 1.5)
		end
	end
	return atorSalvo
end

local MURO_DE_CHAMAS = "ability/fogo/Principiante/muro-de-chamas"
local MURO_DE_TERRA = "ability/terra/Principiante/muro-de-terra"
local ANTEPARO_TEORICO = "ability/teorica/Principiante/anteparo-teorico"
local MAO_DE_TERRA = HabilidadesAutonomas.MAO_DE_TERRA
local ESCAPAR_MAO = HabilidadesAutonomas.ESCAPAR_MAO
local ARRASTAR_MAO = HabilidadesAutonomas.ARRASTAR_MAO
local SOLTAR_MAO = HabilidadesAutonomas.SOLTAR_MAO

local function bloqueadoPorObstaculoVisual(encontro, origemX, origemZ, destinoX, destinoZ)
	if type(origemX) ~= "number" or type(origemZ) ~= "number"
		or type(destinoX) ~= "number" or type(destinoZ) ~= "number"
	then return false end
	return not TerrenoAutonomo.visaoLivre(origemX, origemZ, destinoX, destinoZ,
		encontro.terrenoLista, encontro.dangers, encontro.estado.turn)
end

function EncontroAutonomoService.start(deps)
	if deps == nil and instancia then return instancia end
	deps = deps or {}
	local remote = deps.remote
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = REMOTE_NAME
		remote.Parent = ReplicatedStorage
	end
	local localizarJogador = deps.localizarJogador or function(userId)
		return Players:GetPlayerByUserId(userId)
	end
	local jogadorConectado = deps.conectado or function(player)
		return player.Parent == Players and Players:GetPlayerByUserId(player.UserId) == player
	end
	local novoId = deps.novoId or function()
		return game:GetService("HttpService"):GenerateGUID(false)
	end
	local agora = deps.agora or os.clock
	local tempoServidor = deps.tempoServidor or function() return workspace:GetServerTimeNow() end
	local agendarPrazo = deps.agendarPrazo or task.delay
	local cancelarPrazo = deps.cancelarPrazo or task.cancel
	local avaliarTerminal
	local workspaceAtual = deps.workspace or workspace
	local catalogo = deps.catalogo or Catalogo
	local linhaDeVisao = deps.linhaDeVisao or function(character, marcoEncontro)
		local raiz = character and character:FindFirstChild("HumanoidRootPart")
		if not raiz or not raiz:IsA("BasePart") then return false end
		local parametros = RaycastParams.new()
		parametros.FilterType = Enum.RaycastFilterType.Exclude
		parametros.FilterDescendantsInstances = { character }
		parametros.IgnoreWater = true
		local resultado = workspaceAtual:Raycast(
			raiz.Position,
			marcoEncontro.Position - raiz.Position,
			parametros
		)
		-- O ray termina no marco. Qualquer outra peça atingida é uma obstrução.
		return resultado ~= nil and resultado.Instance == marcoEncontro
	end
	local podeIniciarNaRegiao = deps.podeIniciarNaRegiao or function(player, encounterId)
		local personagem = player.Character
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local marcoEncontro
		local promptEncontro
		if idValido(encounterId) and EncontrosPorZona.consultar(encounterId) ~= nil then
			for _, item in ipairs(workspaceAtual:GetDescendants()) do
				if item:IsA("BasePart") and item:GetAttribute("EncounterId") == encounterId
					and item:GetAttribute("AreaRole") == "encounter-trigger"
				then
					marcoEncontro = item
					promptEncontro = item:FindFirstChildWhichIsA("ProximityPrompt")
					break
				end
			end
		end
		if not humanoide or humanoide.Health <= 0 or not raiz or not raiz:IsA("BasePart")
			or not marcoEncontro or not marcoEncontro:IsA("BasePart")
			or not promptEncontro or not promptEncontro.Enabled
			or type(promptEncontro.MaxActivationDistance) ~= "number"
			or promptEncontro.MaxActivationDistance < 0
		then
			return false
		end
		if promptEncontro.RequiresLineOfSight then
			local ok, visivel = pcall(linhaDeVisao, personagem, marcoEncontro)
			if not ok or visivel ~= true then return false end
		end
		return (raiz.Position - marcoEncontro.Position).Magnitude <= promptEncontro.MaxActivationDistance
	end
	local rng = deps.rng or Random.new()
	local corpoPessoal = deps.corpoPessoal
	-- Sem run ativa, o provedor deve devolver {}. Capturado por ator na entrada;
	-- o remoto nunca recebe IDs de defeitos nem autoriza a troca do provedor.
	local defeitosDe = deps.defeitosDe or function() return {} end
	local function prepararAtor(ator)
		local preparado, erro = prepararAtorBase(ator)
		if not preparado or preparado.kind ~= "jogador" then return preparado, erro end
		local ids, falha = CombateAutonomo.consultarDefeitos(defeitosDe, preparado.userId)
		if not ids then return nil, falha end
		return CombateAutonomo.prepararDefeitos(preparado, ids)
	end
	local consumirItemPessoal = deps.consumirItemPessoal
	local recompensarEncontro = deps.recompensarEncontro
	local combateLegadoAtivo = deps.emCombate or function() return false end
	local miniaturas = deps.miniaturas
	local avatares = deps.avatares
	local patrulhas = {}
 local cacadas
 local tempoMundo = function() return ReplicatedStorage:GetAttribute("RunTempoDecorrido") or 0 end
	local inicioPatrulhaEmCurso
	local ultimaTentativaPatrulha = -math.huge
	local emitir = deps.emitir or function(player, tipo, dados)
		remote:FireClient(player, tipo, dados)
	end
	local encontros, ultimosPedidos, ultimosInicios, ultimosRetornos, ultimasMudancasFila, ultimasReconexoes = {}, {}, {}, {}, {}, {}
	local filaAutonoma, posicaoNaFila = {}, {}
	local entradasReservadas = {}
	local function jogadorOcupado(userId, ignorarReserva)
		if entradasReservadas[userId] and entradasReservadas[userId] ~= ignorarReserva then return true end
		for _, encontro in encontros do
			if encontro.atoresPorJogador[userId] then return true end
		end
		return false
	end
	local function emitirAosParticipantes(encontro, tipo, dados)
		if tipo == "recibo" and type(dados) == "table" and type(dados.version) == "number"
		then
			local chaveRecibo = tostring(dados.version)
			if encontro.recibosTransmitidos[chaveRecibo] then return end
			encontro.recibosTransmitidos[chaveRecibo] = true
			table.insert(encontro.ordemRecibosTransmitidos, chaveRecibo)
			if #encontro.ordemRecibosTransmitidos > 128 then
				local removido = table.remove(encontro.ordemRecibosTransmitidos, 1)
				encontro.recibosTransmitidos[removido] = nil
			end
		end
		for userId in encontro.atoresPorJogador do
			local player = localizarJogador(userId)
			if player and not encontro.retornaram[userId] then emitir(player, tipo, dados) end
		end
	end

	local executarIA
	local expirarPrazo

	local function limparPrazo(encontro)
		local prazo = encontro.prazo
		encontro.prazo = nil
		if prazo and prazo.handle ~= nil then pcall(cancelarPrazo, prazo.handle) end
	end

	local function limparPrazoSemJogadores(encontro)
		local prazo = encontro.prazoSemJogadores
		encontro.prazoSemJogadores = nil
		if prazo and prazo.handle ~= nil then pcall(cancelarPrazo, prazo.handle) end
	end

	local function limparEncontro(encounterId, encontro)
		limparPrazo(encontro)
		limparPrazoSemJogadores(encontro)
		encontros[encounterId] = nil
		for userId, reserva in entradasReservadas do
			if reserva.encontro == encontro then entradasReservadas[userId] = nil end
		end
		if miniaturas and type(miniaturas.limpar) == "function" then
			pcall(miniaturas.limpar, encounterId)
		end
		if avatares and type(avatares.limpar) == "function" then
			pcall(avatares.limpar, encounterId)
		end
		if encontro.arenaPatrulha then
			encontro.arenaPatrulha.pasta:Destroy()
			if encontro.arenaPatrulha.patrulha then encontro.arenaPatrulha.patrulha.ocupar(false) end
		end
	end

	local function haJogadorConectado(encontro, ignorarUserId)
		for userId, actorId in encontro.atoresPorJogador do
			local ator = encontro.atoresPorId[actorId]
			if encontro.retornaram[userId] or (encontro.estado.phase == "active" and ator and ator.fled) then continue end
			local player = if userId == ignorarUserId then nil else localizarJogador(userId)
			if player then
				local ok, conectado = pcall(jogadorConectado, player)
				if ok and conectado == true then return true end
			end
		end
		return false
	end

	local function atualizarPrazoSemJogadores(encounterId, encontro, ignorarUserId)
		if encontros[encounterId] ~= encontro then return end
		if haJogadorConectado(encontro, ignorarUserId) then
			limparPrazoSemJogadores(encontro)
			return
		end
		if encontro.prazoSemJogadores then return end
		local prazo = { expiraEm = agora() + PRAZO_ENCONTRO_SEM_JOGADORES }
		encontro.prazoSemJogadores = prazo
		local function verificar()
			if encontros[encounterId] ~= encontro or encontro.prazoSemJogadores ~= prazo then return end
			if haJogadorConectado(encontro) then
				limparPrazoSemJogadores(encontro)
				return
			end
			local restante = prazo.expiraEm - agora()
			if restante > 0 then
				prazo.handle = agendarPrazo(restante, verificar)
				return
			end
			prazo.handle = nil
			limparEncontro(encounterId, encontro)
		end
		prazo.handle = agendarPrazo(PRAZO_ENCONTRO_SEM_JOGADORES, verificar)
	end

	local function atualizarPrazo(encontro)
		local estado = encontro.estado
		local actorId = estado.order[estado.currentIndex]
		if estado.phase ~= "active" or encontro.jogadorPorAtor[actorId] == nil then
			limparPrazo(encontro)
			return
		end
		local anterior = encontro.prazo
		if anterior and anterior.actorId == actorId and anterior.turn == estado.turn then return end
		limparPrazo(encontro)
		local prazo = { actorId = actorId, turn = estado.turn,
			expiraEm = agora() + PRAZO_TURNO, deadline = tempoServidor() + PRAZO_TURNO }
		encontro.prazo = prazo
		prazo.handle = agendarPrazo(PRAZO_TURNO, function() expirarPrazo(encontro, prazo) end)
	end

	local function celulasDificeisAtivas(encontro)
		local resultado, vistos = {}, {}
		if encontro.estado.phase ~= "active" then return resultado end
		for _, zona in ipairs(encontro.zonasDificeis or {}) do
			if encontro.estado.turn < zona.expiresTurn then
				for _, celula in ipairs(zona.cells or {}) do
					local id = tostring(celula.x) .. ":" .. tostring(celula.z)
					if not vistos[id] then
						vistos[id] = true
						table.insert(resultado, { x = celula.x, z = celula.z })
					end
				end
			end
		end
		table.sort(resultado, function(a, b) return a.x == b.x and a.z < b.z or a.x < b.x end)
		return resultado
	end

	local function celulasBloqueadasAtivas(encontro)
		local resultado = table.clone(encontro.terreno)
		for _, celula in ipairs(TerrenoAutonomo.celulasBloqueantes(encontro.dangers, encontro.estado.turn)) do
			resultado[tostring(celula.x) .. ":" .. tostring(celula.z)] = true
		end
		return resultado
	end

	local function listaDeCelulas(chaves)
		local resultado = {}
		for chave in chaves do
			local x, z = string.match(chave, "^(%d+):(%d+)$")
			if x and z then table.insert(resultado, { x = tonumber(x), z = tonumber(z) }) end
		end
		table.sort(resultado, function(a, b) return a.x == b.x and a.z < b.z or a.x < b.x end)
		return resultado
	end

	local function paraResolucao(encontro, ator, reduzirIgneo)
		if not ator then return ator end
		local emNevoa = TerrenoAutonomo.atorNaNevoa(ator.x, ator.z, encontro.dangers, encontro.estado.turn)
		if not emNevoa and reduzirIgneo ~= true then
			return ator
		end
	local resultado = table.clone(ator)
		if emNevoa then
			resultado.condicoes = table.clone(ator.condicoes or {})
			resultado.condicoes.cego = true
		end
		if reduzirIgneo == true then resultado.reduzIgneo = true end
	return resultado
	end

	local function soltarVinculoMao(encontro, targetId)
		local vinculo = encontro.vinculosMao[targetId]
		if not vinculo then return nil end
		local alvo = encontro.atoresPorId[targetId]
		if alvo then
			for condicao, propria in pairs(vinculo.condicoes) do
				if propria then
					alvo.condicoes[condicao] = nil
					if alvo.condicoesAteProximaVez then alvo.condicoesAteProximaVez[condicao] = nil end
				end
			end
		end
		encontro.vinculosMao[targetId] = nil
		return vinculo
	end

	local function limparVinculosMaoInvalidos(encontro)
		for targetId, vinculo in pairs(encontro.vinculosMao or {}) do
			local fonte = encontro.atoresPorId[vinculo.sourceId]
			local condicoes = fonte and fonte.condicoes or {}
			if not fonte or fonte.defeated == true or fonte.downed == true or (fonte.pv or 0) <= 0
				or condicoes.caido == true or condicoes.inconsciente == true or condicoes.incapacitado == true
			then soltarVinculoMao(encontro, targetId) end
		end
	end

	local function estadoPara(encontro, userId)
		limparVinculosMaoInvalidos(encontro)
		local estado = Turnos.consultar(encontro.estado)
		if not estado then return nil end
		estado.turnDeadline = encontro.prazo and encontro.prazo.deadline or nil
		estado.currentActorName = encontro.nomesPorAtor[estado.currentActorId]
		estado.isMyTurn = encontro.atoresPorJogador[userId] == estado.currentActorId
		estado.descansoAutomatico = encontro.descansoAutomatico == true
		local dadosRecompensa = encontro.recompensaPorJogador and encontro.recompensaPorJogador[userId]
		if dadosRecompensa then
			estado.ouroGanho = dadosRecompensa.ganho
			estado.ouroTotal = dadosRecompensa.total
			estado.paGanho = dadosRecompensa.pa or 0
		end
		estado.dangers = if encontro.estado.phase == "active" then copiar(encontro.dangers or {}) else {}
		estado.bindings = if encontro.estado.phase == "active" then copiar(encontro.vinculosMao or {}) else {}
		local bloqueadas = celulasBloqueadasAtivas(encontro)
		estado.blockedCells = listaDeCelulas(bloqueadas)
		estado.difficultCells = celulasDificeisAtivas(encontro)
		estado.controlledActorId = encontro.atoresPorJogador[userId]
		local atorControlado = encontro.atoresPorId[estado.controlledActorId]
		if atorControlado and atorControlado.fled then
			estado.phase, estado.isMyTurn, estado.turnDeadline = "fled", false, nil
			estado.descansoAutomatico = false
			estado.fleeResult = copiar(atorControlado.fleeResult)
		end
		estado.availableAbilities = HabilidadesAutonomas.disponiveis(atorControlado)
		for targetId, vinculo in pairs(encontro.vinculosMao or {}) do
			if targetId == estado.controlledActorId then table.insert(estado.availableAbilities, ESCAPAR_MAO) end
			if vinculo.sourceId == estado.controlledActorId then
				table.insert(estado.availableAbilities, ARRASTAR_MAO)
				table.insert(estado.availableAbilities, SOLTAR_MAO)
			end
		end
		estado.availableItems = ItensAutonomos.disponiveis(atorControlado)
		local usosNoTurno = encontro.habilidadesUsadas[estado.controlledActorId]
		if usosNoTurno then
			for habilidadeId, turnoUsado in usosNoTurno do
				local indice = table.find(estado.availableAbilities, habilidadeId)
				if turnoUsado == estado.turn and indice then table.remove(estado.availableAbilities, indice) end
			end
		end
		estado.initiativeRolls = encontro.rolagensIniciativa
		estado.actors = {}
	for _, actorId in ipairs(encontro.ordemInicial) do
		local ator = encontro.atoresPorId[actorId]
		if ator and ator.fled then continue end
		table.insert(estado.actors, {
			id = ator.id, name = ator.name, kind = ator.kind,
			pv = ator.pv, pvMax = ator.pvMax, ca = ator.ca,
			pvTemporarios = ator.pvTemporarios and ator.pvTemporarios.valor or 0,
			pm = ator.pm or 0, pmMax = ator.pmMax or 0,
			pt = ator.pt or 0, ptMax = ator.ptMax or 0,
			pp = ator.pp or 0, ppMax = ator.ppMax or 0,
			conditions = table.clone(ator.condicoes or {}),
			respira = ator.respira == true,
			states = copiar(ator.estadosDeCombate or {}),
			defenderReduction = ator.defenderReduction,
			x = ator.x, z = ator.z, movementCasas = ator.movementCasas,
			defects = copiar(ator.defeitos or {}), defectEffects = copiar(ator.defectEffects),
			defectMovement = copiar(ator.defectMovement),
			defeated = ator.defeated == true, downed = ator.downed == true,
		})
	end
	return estado
	end

	local function enviarEstado(encontro)
		if (encontro.estado.phase == "victory" or encontro.estado.phase == "defeat" or encontro.estado.phase == "fled")
			and not encontro.terminalNotificado then
			encontro.terminalNotificado = true
   if encontro.estado.phase == "victory" and encontro.arenaPatrulha
    and encontro.arenaPatrulha.patrulha and encontro.arenaPatrulha.patrulha.derrotada then
    encontro.arenaPatrulha.patrulha.derrotada()
   end
			if encontro.estado.phase == "victory" and type(recompensarEncontro) == "function" then
				local criaturas = {}
				for _, id in ipairs(encontro.ordemInicial) do
					local ator = encontro.atoresPorId[id]
					if ator and ator.fled then continue end
					if ator and ator.kind == "criatura" and ator.recompensa then table.insert(criaturas, ator.recompensa) end
				end
				local recompensa = Recompensa.gerar(criaturas, function() return rng:NextNumber() end)
				-- Sem inventário de espólio no J2: tralhas/partes são liquidadas
				-- na guilda a 100%; equipamento sorteado fica apenas registrado.
				local moedasPagas = recompensa.moedas
				for _, tralha in ipairs(recompensa.tralhas or {}) do
					if type(tralha.preco) == "number" and tralha.preco > 0 then
						moedasPagas += math.floor(tralha.preco)
					end
				end
				encontro.recompensaPorJogador = {}
				for userId, actorId in encontro.atoresPorJogador do
					local ator = encontro.atoresPorId[actorId]
					if ator and ator.fled then continue end
					if ator and not ator.fled and type(ator.pv) == "number" and ator.pv > 0 and ator.defeated ~= true then
						local player = localizarJogador(userId)
						if player then
							local marcoRecompensa = if encontro.arenaPatrulha then
								(encontro.arenaPatrulha.marcoRecompensa or "region/encounter/clearing") else encontro.areaId
							local patrulhaId = encontro.arenaPatrulha and encontro.arenaPatrulha.patrulhaId
       local bonus, pa = 0, 0
       if cacadas and patrulhaId then bonus, pa = cacadas.bonus(player, patrulhaId) end
       local pago = moedasPagas + bonus
       local ok, sucesso, total = pcall(recompensarEncontro, player, encontro.estado.encounterId, pago, marcoRecompensa, pa)
       if ok and sucesso then
        encontro.recompensaPorJogador[userId] = { ganho = pago, total = total, pa = pa }
        if cacadas and patrulhaId and bonus > 0 then cacadas.concluir(player, patrulhaId, encontro.estado.encounterId) end
       end
						end
					end
				end
			end
			if type(deps.aoEncerrar) == "function" then
				pcall(deps.aoEncerrar, encontro, Turnos.consultar(encontro.estado))
			end
		end
		limparVinculosMaoInvalidos(encontro)
		atualizarPrazo(encontro)
		if not encontro.descansoAutomatico
			and (encontro.estado.phase == "victory" or encontro.estado.phase == "defeat")
		then
			for userId, atorId in encontro.atoresPorJogador do
				local ator = encontro.atoresPorId[atorId]
				if ator and ator.fled then continue end
				local ficha = ator and ator.ficha
				local maxima = ficha and ficha.calculated and ficha.calculated.maxima
				if ator and not ator.fled and type(maxima) == "table" then
					ator.pv = if type(maxima.pv) == "number" then maxima.pv else ator.pv
					ator.pm = if type(maxima.pm) == "number" then maxima.pm else ator.pm
					ator.pt = if type(maxima.pt) == "number" then maxima.pt else ator.pt
					ator.pp = if type(maxima.pp) == "number" then maxima.pp else ator.pp
					ator.downed = false
					ator.defenderReduction = nil
					ator.condicoes = {}
					local sessao = ficha.session
					if type(sessao) == "table" then
						sessao.current = copiar(maxima)
						sessao.conditions = {}
					end
				end
			end
			for _, ator in pairs(encontro.atoresPorId) do ator.pvTemporarios = nil end
			table.clear(encontro.vinculosMao or {})
			encontro.descansoAutomatico = true
		end
		if miniaturas and type(miniaturas.render) == "function" then
			local atoresVisuais = {}
			for _, actorId in ipairs(encontro.ordemInicial) do
				local ator = encontro.atoresPorId[actorId]
				if ator and ator.fled then continue end
				table.insert(atoresVisuais, {
					id = ator.id, name = ator.name, kind = ator.kind,
					userId = ator.userId, criaturaId = ator.criaturaId,
					pv = ator.pv, pvMax = ator.pvMax, x = ator.x, z = ator.z,
					downed = ator.downed == true, defeated = ator.defeated == true,
				})
			end
			pcall(miniaturas.render, encontro.estado.encounterId, atoresVisuais,
				encontro.estado.order[encontro.estado.currentIndex], encontro.estado.phase, encontro.areaId,
				encontro.estado.lastAction)
		end
		if avatares and type(avatares.sincronizar) == "function" then
			local atoresDosJogadores = {}
			for _, actorId in ipairs(encontro.ordemInicial) do
				local ator = encontro.atoresPorId[actorId]
				if ator and ator.fled then continue end
				if ator and ator.kind == "jogador" and not ator.fled then
					table.insert(atoresDosJogadores, { userId = ator.userId, x = ator.x, z = ator.z, kind = ator.kind })
				end
			end
			pcall(avatares.sincronizar, encontro.estado.encounterId, atoresDosJogadores, encontro.estado.phase, encontro.areaId)
		end
		for userId in encontro.atoresPorJogador do
			local player = localizarJogador(userId)
			if player and not encontro.retornaram[userId] then emitir(player, "estado", estadoPara(encontro, userId)) end
		end
	end

	local function encontroFinalizado(encontro)
		return encontro.estado.phase == "victory" or encontro.estado.phase == "defeat" or encontro.estado.phase == "fled"
	end

	local function limparEncontroSeTodosRetornaram(encounterId, encontro)
		if not encontroFinalizado(encontro) then return false end
		for userId in encontro.atoresPorJogador do
			if localizarJogador(userId) and not encontro.retornaram[userId] then
				return false
			end
		end
		limparEncontro(encounterId, encontro)
		return true
	end

	local function emitirFila()
		local fila = {}
		for _, userId in ipairs(filaAutonoma) do
			local player = localizarJogador(userId)
			if player then
				table.insert(fila, { userId = userId, nome = player.DisplayName })
			end
		end
		local estadoFila = { jogadores = fila, liderUserId = if #fila > 0 then fila[1].userId else nil }
		for _, entry in ipairs(fila) do
			local player = localizarJogador(entry.userId)
			if player then emitir(player, "fila", estadoFila) end
		end
	end

	local function retirarDaFila(userId)
		local indice = posicaoNaFila[userId]
		if not indice then return false end
		table.remove(filaAutonoma, indice)
		posicaoNaFila[userId] = nil
		for i = indice, #filaAutonoma do posicaoNaFila[filaAutonoma[i]] = i end
		return true
	end

	local api = {}
	-- Ligação tardia para RunServico (J2 é inicializado antes da run).
	-- Afeta somente novas admissões; não altera encontros já iniciados.
 function api.definirCacadas(servico) cacadas = servico end
 function api.definirRelogioMundo(provedor) tempoMundo = provedor end

	function api.definirProvedorDefeitos(provedor)
		if type(provedor) ~= "function" then return false, "Provedor inválido." end
		defeitosDe = provedor
		return true
	end
	local enviarRecusa

	-- Pontos internos para os sinais do ciclo de vida e para verificar o prazo sem grupo.
	function api.notificarConexao(player)
		if player == nil or type(player.UserId) ~= "number" then return end
		for encounterId, encontro in encontros do
			if encontro.atoresPorJogador[player.UserId] then
				atualizarPrazoSemJogadores(encounterId, encontro)
			end
		end
	end

	function api.notificarDesconexao(player)
		if player == nil or type(player.UserId) ~= "number" then return end
		for encounterId, encontro in encontros do
			if encontro.atoresPorJogador[player.UserId] then
				if encontroFinalizado(encontro) then
					encontro.retornaram[player.UserId] = true
					limparEncontroSeTodosRetornaram(encounterId, encontro)
				else
					atualizarPrazoSemJogadores(encounterId, encontro, player.UserId)
				end
			end
		end
	end

	-- Só um chamador de servidor fornece a ordem e quem controla cada ator.
	-- ator = { id: string, userId: number? }; userId ausente reserva controle ao servidor.
	function api.criar(atores, rolagensIniciativa, areaId, arenaPatrulha)
		if type(atores) ~= "table" or #atores < 2 or #atores > 16 then
			return nil, "O encontro precisa ter de 2 a 16 atores."
		end
		local ordem, vistos, atoresPorJogador, jogadorPorAtor, nomesPorAtor, atoresPorId = {}, {}, {}, {}, {}, {}
		for _, ator in ipairs(atores) do
			if type(ator) ~= "table" or not idValido(ator.id) or vistos[ator.id] then
				return nil, "A lista de atores é inválida."
			end
			vistos[ator.id] = true
			table.insert(ordem, ator.id)
			local atorSalvo, erroAtor = prepararAtor(ator)
			if not atorSalvo then return nil, erroAtor end
			atoresPorId[ator.id] = atorSalvo
			if ator.name ~= nil and (type(ator.name) ~= "string" or #ator.name == 0 or #ator.name > 48) then
				return nil, "Nome de ator inválido."
			end
			nomesPorAtor[ator.id] = ator.name or (if ator.userId then "Jogador" else "Criatura")
			if ator.userId ~= nil then
				if type(ator.userId) ~= "number" or ator.userId % 1 ~= 0 or ator.userId <= 0
					or atoresPorJogador[ator.userId] or jogadorOcupado(ator.userId) or not localizarJogador(ator.userId)
				then
					return nil, "Cada jogador precisa estar conectado e controlar um único ator."
				end
				atoresPorJogador[ator.userId] = ator.id
				jogadorPorAtor[ator.id] = ator.userId
			end
		end
		local quantidadeJogadores = 0
		for _ in atoresPorJogador do quantidadeJogadores += 1 end
		if quantidadeJogadores > 4 then return nil, "Limite de quatro jogadores por encontro." end
		if next(atoresPorJogador) == nil then
			return nil, "O encontro precisa ter ao menos um jogador conectado."
		end

  -- Revalida depois de consultar fichas (dependencia pode ceder a execucao).
  if arenaPatrulha and (next(encontros) ~= nil
   or type(arenaPatrulha.validarInicio) ~= "function" or not arenaPatrulha.validarInicio()) then
   return nil, "O contexto da patrulha mudou antes de iniciar."
  end
		local encounterId = novoId()
		if not idValido(encounterId) or encontros[encounterId] then
			return nil, "Não foi possível gerar um ID de encontro único."
		end
		local estado, erro = Turnos.criar(encounterId, ordem)
		if not estado then return nil, erro end
		local encontro = {
			arenaPatrulha = arenaPatrulha,
			estado = estado,
			areaId = areaId or "region/encounter/clearing",
			terreno = TerrenoAutonomo.chaves(areaId or "region/encounter/clearing", arenaPatrulha and arenaPatrulha.bloqueadas),
			terrenoLista = TerrenoAutonomo.celulas(areaId or "region/encounter/clearing", arenaPatrulha and arenaPatrulha.bloqueadas),
			ordemInicial = table.clone(ordem),
			atoresPorJogador = atoresPorJogador,
			jogadorPorAtor = jogadorPorAtor,
			nomesPorAtor = nomesPorAtor,
			atoresPorId = atoresPorId,
			rolagensIniciativa = rolagensIniciativa,
			retornaram = {},
			recibosTransmitidos = {},
			ordemRecibosTransmitidos = {},
			desistenciasAplicadas = {},
			ordemDesistenciasAplicadas = {},
			fugasAplicadas = {},
			ordemFugasAplicadas = {},
			habilidadesUsadas = {},
			ultimaRodadaVacuadaPorAlvo = {},
			vinculosMao = {},
			dangers = {},
			zonasDificeis = {},
			danoSequencia = 0,
		}
		encontros[encounterId] = encontro
		enviarEstado(encontro)
		return encounterId, Turnos.consultar(estado)
	end

	-- Atalho autoritativo: a lista e os bônus são fornecidos por código servidor.
	function api.criarComIniciativa(atores, areaId, arenaPatrulha, adiarIA)
		local ordem, rolagens, erro = Iniciativa.ordenar(atores, rng)
		if not ordem then return nil, erro end
		local ordemRolada, desprevenidos = {}, {}
		for _, ator in ipairs(ordem) do table.insert(ordemRolada, ator.id) end
		if arenaPatrulha and arenaPatrulha.surpreendente then
			local lados = {}
			for _, ator in ipairs(ordem) do
				local entrada = table.clone(ator)
				entrada.lado = ator.kind or (if ator.userId then "jogador" else "criatura")
				table.insert(lados, entrada)
			end
			local lado = if arenaPatrulha.surpreendente == "jogadores" then "criatura" else "jogador"
			ordem, desprevenidos = RegrasPatrulha.ordemComSurpresa(lados, lado)
			for _, ator in ipairs(ordem) do
				if desprevenidos[ator.id] then
					ator.condicoes = copiar(ator.condicoes or {})
					desprevenidos[ator.id] = { anterior = ator.condicoes.desprevenido }
					ator.condicoes.desprevenido = true
				end
			end
		end
		local encounterId, estado = api.criar(ordem, rolagens, areaId, arenaPatrulha)
		if encounterId and next(desprevenidos) then
			local encontro = encontros[encounterId]
			encontro.ordemSemSurpresa = ordemRolada
			encontro.surpreendidos = desprevenidos
		end
		if encounterId and executarIA then
			-- RunServico precisa registrar o ID antes de receber um terminal da IA.
			if adiarIA then task.defer(executarIA, encounterId) else executarIA(encounterId) end
			estado = api.estado(encounterId)
		end
		return encounterId, estado, rolagens
	end

	local SEM_ESPACO = "Sem espaco seguro para iniciar o encontro neste ponto." -- também usado por iniciarPorPatrulha
	-- Monta o grupo com corpos validados da sessão pessoal e criaturas canônicas.
	-- Chamada apenas de servidor; não aceita corpo, bônus ou proprietário em remoto.
	local function montarGrupo(jogadores, idsCriaturas, papeis, areaId, formacaoId)
		return Elenco.montar(jogadores, idsCriaturas, {
			areaId = areaId, formacaoId = formacaoId,
			conectado = jogadorConectado,
			corpoPessoal = corpoPessoal or function()
				return nil, "Personagem próprio indisponível nesta sessão."
			end,
			criatura = function(creatureId, indice)
				local entrada = catalogo.POR_ID[creatureId]
				if not entrada or entrada.kind ~= "creature" then return nil end
				if papeis and papeis[indice] then
					entrada = table.clone(entrada)
					entrada.data = table.clone(entrada.data)
					entrada.data.papel = papeis[indice]
				end
				return Criaturas.ficha(entrada)
			end,
		})
	end

	function api.criarParaGrupo(jogadores, idsCriaturas, areaId, arenaPatrulha)
		local atores, erro = montarGrupo(jogadores, idsCriaturas, nil, areaId, arenaPatrulha and arenaPatrulha.marcoRecompensa)
		if not atores then return nil, erro end
		
  if arenaPatrulha then
   for _, ator in ipairs(atores) do
    local atuais = ator.ficha and ator.ficha.session and ator.ficha.session.current
    if atuais and type(atuais.pv) == "number" and atuais.pv <= 0 then
     return nil, "Personagem sem PV nao pode entrar na patrulha."
    end
   end
  end
  if arenaPatrulha and not TerrenoAutonomo.posicoesIniciaisLivres(atores, arenaPatrulha.bloqueadas) then
   return nil, SEM_ESPACO
  end
  return api.criarComIniciativa(atores, areaId, arenaPatrulha)
	end

	-- Somente servidor: história fornece o elenco, nunca posição/prompt do jogador.
	function api.criarEncontroDaRun(jogadores, luta)
		if next(encontros) ~= nil then return nil, "Já existe um encontro neste servidor; termine e retorne antes de lutar." end
		if type(jogadores) ~= "table" then return nil, "O grupo da run é inválido." end
		local composicao, erro = EncontrosPorZona.paraRun(luta, #jogadores)
		if not composicao then return nil, erro end
		local function validarGrupo()
			for _, player in ipairs(jogadores) do
				if not jogadorConectado(player) or localizarJogador(player.UserId) ~= player then
					return false, "Um jogador da run está desconectado."
				end
				local character = player.Character
				local humanoide = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not humanoide or humanoide.Health <= 0 or not root or not root:IsA("BasePart") then
					return false, "Todos os jogadores precisam estar vivos e com avatar carregado."
				end
				if combateLegadoAtivo(player) then return false, "Um jogador está em outra partida." end
			end
			return true
		end
		-- Elenco valida lista densa, duplicatas e ficha de TODOS antes de criar estado.
		local atores, falha = montarGrupo(jogadores, composicao.elenco, composicao.papeis, luta.areaId)
		if not atores then return nil, falha end
		local valido, motivo = validarGrupo()
		if not valido then return nil, motivo end
		for _, ator in ipairs(atores) do
			if ator.kind == "jogador" then
				local preparado, erro = prepararAtor(ator)
				if not preparado then return nil, erro end
				if (preparado.pv or 0) <= 0 then return nil, "Um personagem da run está sem PV na ficha pessoal." end
			end
		end
		if next(encontros) ~= nil then return nil, "Já existe um encontro neste servidor." end
		if not TerrenoAutonomo.posicoesIniciaisLivres(atores, TerrenoAutonomo.celulas(luta.areaId)) then
			return nil, "A arena não tem casas iniciais livres para o grupo."
		end
		local id, resultado = api.criarComIniciativa(atores, luta.areaId, nil, true)
		if not id then return nil, resultado end
		for _, player in ipairs(jogadores) do retirarDaFila(player.UserId) end
		emitirFila()
		return id
	end

	local function posicaoElegivel(player, encontro, reserva)
		if not player or not jogadorConectado(player) or localizarJogador(player.UserId) ~= player
			or posicaoNaFila[player.UserId] or combateLegadoAtivo(player)
			or jogadorOcupado(player.UserId, reserva) then return nil end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0
			or not char:IsDescendantOf(workspaceAtual)
			or (reserva and reserva.character ~= char) then return nil end
		local arena = encontro.arenaPatrulha
		local casa = arena and GradeTatica.casaNaPosicao(arena.centro, root.Position)
		if not casa or RegrasPatrulha.situacaoNaGrade(casa.distanciaMetros, 15,
			GradeTatica.RAIO_ENTRADA_METROS) == "fora" then return nil end
		return casa
	end

	-- A ficha deve estar carregada: nunca aguarda I/O dentro da troca de rodada.
	-- O mesmo Elenco e a mesma preparação de recursos atendem grupo e entrada.
	local function montarEntrada(player)
		local thread = coroutine.create(function()
			local atores = montarGrupo({ player }, { "creature/goblin-batedor" })
			return atores and prepararAtor(atores[1])
		end)
		local ok, ator = coroutine.resume(thread)
		if coroutine.status(thread) ~= "dead" then coroutine.close(thread); return nil end
		if not ok or not ator or type(ator.pv) ~= "number" or ator.pv <= 0
			or ator.defeated or not idValido(ator.name) or #ator.name > 48 then return nil end
		return ator
	end

	local function vagasNoEncontro(encontro)
		local total = 0
		-- Reserva a identidade até a limpeza, inclusive fugitivos/retornados.
		for _ in encontro.atoresPorJogador do total += 1 end
		for _, reserva in entradasReservadas do
			if reserva.encontro == encontro then total += 1 end
		end
		return 4 - total
	end

	-- Somente servidor; a observação não aceita posição/identidade do cliente.
	function api.observarEntradasPatrulha()
		for userId, reserva in entradasReservadas do
			if reserva.encontro.estado.phase ~= "active"
				or encontros[reserva.encontro.estado.encounterId] ~= reserva.encontro
				or not posicaoElegivel(reserva.player, reserva.encontro, reserva) then
				entradasReservadas[userId] = nil
			end
		end
		local jogadores = table.clone((deps.jogadoresPatrulha or function() return Players:GetPlayers() end)())
		table.sort(jogadores, function(a, b) return a.UserId < b.UserId end)
		for _, encontro in encontros do
			if encontro.estado.phase ~= "active" or not encontro.arenaPatrulha
				or typeof(encontro.arenaPatrulha.centro) ~= "Vector3" then continue end
			for _, player in ipairs(jogadores) do
				if vagasNoEncontro(encontro) <= 0 then break end
				local casa = posicaoElegivel(player, encontro)
				if not casa then continue end
				local versao = encontro.estado.version
				local ator = montarEntrada(player)
				if ator and encontro.estado.version == versao and encontro.estado.phase == "active"
					and posicaoElegivel(player, encontro) and vagasNoEncontro(encontro) > 0 then
					entradasReservadas[player.UserId] = { player = player, character = player.Character,
						encontro = encontro, rodada = encontro.estado.turn + 1, casa = casa }
				end
			end
		end
	end

	local function admitirEntradas(encontro, novoEstado, recibo)
		if novoEstado.phase ~= "active" or novoEstado.turn <= encontro.estado.turn then return end
		local candidatos = {}
		for userId, reserva in entradasReservadas do
			if reserva.encontro == encontro and reserva.rodada <= novoEstado.turn then table.insert(candidatos, userId) end
		end
		table.sort(candidatos)
		local admitidos = {}
		for _, userId in ipairs(candidatos) do
			local reserva = entradasReservadas[userId]
			local casa = posicaoElegivel(reserva.player, encontro, reserva)
			local ator = casa and montarEntrada(reserva.player)
			-- montarEntrada rejeita qualquer dependência que ceda execução; ainda
			-- revalida a identidade e o Character na fronteira de confirmação.
			if ator and posicaoElegivel(reserva.player, encontro, reserva) then
				local ocupantes = {}
				for _, id in ipairs(encontro.ordemInicial) do table.insert(ocupantes, encontro.atoresPorId[id]) end
				local bloqueadas = TerrenoAutonomo.celulas(encontro.areaId, encontro.arenaPatrulha.bloqueadas)
				for _, celula in ipairs(TerrenoAutonomo.celulasBloqueantes(encontro.dangers, novoEstado.turn)) do
					table.insert(bloqueadas, celula)
				end
				local borda = TerrenoAutonomo.bordaLivre(reserva.casa.x, reserva.casa.z, ocupantes, bloqueadas)
				if borda then
					-- Reutiliza RB-13 com dados antigos fixos; somente o novo ator
					-- consome RNG. Empates estáveis mantêm os antigos antes do novo.
					local lista, naturais, detalhesPorId = {}, {}, {}
					for _, detalhe in ipairs(encontro.rolagensIniciativa or {}) do
						table.insert(lista, { id = detalhe.actorId, bonus = detalhe.bonus, advantage = false })
						table.insert(naturais, detalhe.natural)
						detalhesPorId[detalhe.actorId] = detalhe
					end
					if #lista > 0 then
						table.insert(lista, { id = ator.id, bonus = ator.bonus, advantage = ator.advantage })
						local indice = 0
						local ordem, detalhes = Iniciativa.ordenar(lista, { NextInteger = function(_, minimo, maximo)
							indice += 1
							return naturais[indice] or rng:NextInteger(minimo, maximo)
						end })
						if ordem then
							ator.x, ator.z = borda.x, borda.z
							encontro.atoresPorId[ator.id], encontro.nomesPorAtor[ator.id] = ator, ator.name
							encontro.atoresPorJogador[userId], encontro.jogadorPorAtor[ator.id] = ator.id, userId
							table.insert(encontro.ordemInicial, ator.id)
							local ativos = {}
							for _, entrada in ipairs(ordem) do
								local antigo = encontro.atoresPorId[entrada.id]
								if entrada.id == ator.id or (table.find(novoEstado.order, entrada.id) and not antigo.fled) then
									table.insert(ativos, entrada.id)
								end
							end
							for i, detalhe in ipairs(detalhes) do detalhes[i] = detalhesPorId[detalhe.actorId] or detalhe end
							encontro.rolagensIniciativa = detalhes
							encontro.ordemSemSurpresa = nil
							novoEstado.order, novoEstado.currentIndex = ativos, 1
							recibo.nextActorId = ativos[1]
							table.insert(admitidos, { actorId = ator.id, name = ator.name, x = ator.x, z = ator.z })
						end
					end
				end
			end
			entradasReservadas[userId] = nil
		end
		if #admitidos > 0 then
			recibo.result = recibo.result or {}
			recibo.result.joinedActors = admitidos
		end
	end

	-- Encontro solo do Dojo. Reaproveita ficha J1, criatura do bestiário,
	-- iniciativa e o mesmo resolvedor J2; não introduz regra de combate.
	function api.criarProvaDojo(player)
		if not jogadorConectado(player) or combateLegadoAtivo(player) then
			return nil, "Termine a partida atual antes de iniciar a provação."
		end
		for _, encontro in encontros do
			if encontro.estado.phase == "active" then return nil, "Já existe um encontro ativo." end
		end
		local atores, erro = Elenco.montar({ player }, {
			"creature/lobo-cinzento", "creature/lobo-cinzento",
		}, {
			conectado = jogadorConectado,
			corpoPessoal = corpoPessoal or function() return nil end,
			criatura = function(creatureId)
				local entrada = catalogo.POR_ID[creatureId]
				if not entrada or entrada.kind ~= "creature" then return nil end
				return Criaturas.ficha(entrada)
			end,
		})
		if not atores then return nil, erro end
		-- A montagem compartilhada pede elenco de expedição (2 criaturas); a provação
		-- conserva somente um oponente, sem alterar o contrato daquele módulo.
		table.remove(atores, #atores)
		return api.criarComIniciativa(atores, "region/encounter/clearing")
	end

	function api.solicitarFila(player, pedido)
		if player == nil or type(pedido) ~= "table"
			or (pedido.command ~= "join-autonomous-queue" and pedido.command ~= "leave-autonomous-queue")
			or not idValido(pedido.requestId)
		then
			enviarRecusa(player, nil, "Pedido de grupo inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "requestId" then
				enviarRecusa(player, nil, "O pedido de grupo contém campos não permitidos.")
				return false
			end
		end
		local entrar = pedido.command == "join-autonomous-queue"
		if not jogadorConectado(player) then return false end
		local anterior = ultimasMudancasFila[player.UserId]
		if anterior and anterior.requestId == pedido.requestId and anterior.command == pedido.command then
			emitirFila()
			if not posicaoNaFila[player.UserId] then emitir(player, "fila", { jogadores = {}, liderUserId = nil }) end
			return true
		end
		if anterior and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, nil, "Aguarde antes de alterar o grupo.")
			return false
		end
		ultimasMudancasFila[player.UserId] = { requestId = pedido.requestId, command = pedido.command, at = agora() }
		if entrar then
			if entradasReservadas[player.UserId] then
				enviarRecusa(player, nil, "Entrada no encontro da patrulha já reservada.")
				return false
			end
			local ok, emCombate = pcall(combateLegadoAtivo, player)
			if not ok or emCombate == true then
				enviarRecusa(player, nil, "Termine a partida atual antes de entrar no grupo autônomo.")
				return false
			end
			for _, encontro in encontros do
				if encontro.atoresPorJogador[player.UserId] and encontro.estado.phase == "active" then
					enviarRecusa(player, encontro, "Você já participa de um encontro autônomo.")
					return false
				end
			end
			if not posicaoNaFila[player.UserId] then
				if #filaAutonoma >= 4 then
					enviarRecusa(player, nil, "O grupo autônomo já tem quatro jogadores.")
					return false
				end
				local okFicha, ficha = pcall(corpoPessoal or function() return nil end, player)
				if not okFicha or type(ficha) ~= "table" then
					enviarRecusa(player, nil, "Crie sua ficha pessoal antes de entrar no grupo.")
					return false
				end
				table.insert(filaAutonoma, player.UserId)
				posicaoNaFila[player.UserId] = #filaAutonoma
			end
		else
			retirarDaFila(player.UserId)
		end
		emitirFila()
		if not posicaoNaFila[player.UserId] then emitir(player, "fila", { jogadores = {}, liderUserId = nil }) end
		return true
	end

	function api.solicitarInicio(player, pedido)
		local comandoValido = type(pedido) == "table"
			and (pedido.command == "start-autonomous" or pedido.command == "start-world-encounter")
		if player == nil or not comandoValido
			or not idValido(pedido.requestId)
		then
			enviarRecusa(player, nil, "Pedido de início inválido.")
			return false
		end
		local conectadoOk, estaConectado = pcall(jogadorConectado, player)
		if not conectadoOk or not estaConectado then return false end
		for chave in pedido do
			if chave ~= "command" and chave ~= "requestId"
				and not (pedido.command == "start-world-encounter" and chave == "areaId")
			then
				enviarRecusa(player, nil, "O pedido de início contém campos não permitidos.")
				return false
			end
		end
		local anterior = ultimosInicios[player.UserId]
		if anterior and anterior.requestId == pedido.requestId and anterior.command == pedido.command then
			local encontroAnterior = encontros[anterior.encounterId]
			if encontroAnterior then
				emitir(player, "estado", estadoPara(encontroAnterior, player.UserId))
				return true, anterior.encounterId
			end
			enviarRecusa(player, nil, "Este pedido de início já foi encerrado.")
			return false
		elseif anterior and anterior.requestId == pedido.requestId then
			enviarRecusa(player, nil, "ID de início já usado com outro comando.")
			return false
		end
		if anterior and agora() - anterior.at < INTERVALO_INICIO then
			enviarRecusa(player, nil, "Aguarde antes de iniciar outro encontro.")
			return false
		end
		if inicioPatrulhaEmCurso then return false end
		for _ in encontros do
			enviarRecusa(player, nil, "A arena está ocupada. Se seu encontro anterior terminou, use return-autonomous com o encounterId do estado terminal antes de iniciar outra luta.")
			return false
		end
		if pedido.command == "start-world-encounter" then
			if not idValido(pedido.areaId) or not EncontrosPorZona.consultar(pedido.areaId) then
				enviarRecusa(player, nil, "Escolha um marco válido do mundo para iniciar o encontro.")
				return false
			end
			local pertoOk, perto = pcall(podeIniciarNaRegiao, player, pedido.areaId)
			if not pertoOk or not perto then
				enviarRecusa(player, nil, "Chegue ao marco indicado para iniciar este encontro.")
				return false
			end
		end
		-- Tentativas recusadas por marco/alcance não reservam requestId nem cooldown;
		-- só uma intenção que passou a validação de contexto pode consumir a janela.
		ultimosInicios[player.UserId] = { requestId = pedido.requestId, command = pedido.command, at = agora() }

		local ok, emCombate = pcall(combateLegadoAtivo, player)
		if not ok or emCombate == true then
			enviarRecusa(player, nil, "Termine a partida atual antes de iniciar um encontro autônomo.")
			return false
		end
		for encounterId, encontro in encontros do
			if encontro.atoresPorJogador[player.UserId] and encontro.estado.phase == "active" then
				enviarRecusa(player, encontro, "Você já participa de um encontro autônomo.")
				return false
			end
		end

		local grupo = if posicaoNaFila[player.UserId] == 1 then table.clone(filaAutonoma) else { player.UserId }
		if posicaoNaFila[player.UserId] and posicaoNaFila[player.UserId] ~= 1 then
			enviarRecusa(player, nil, "Só quem iniciou o grupo pode começar a expedição.")
			return false
		end
		if #grupo == 1 and grupo[1] ~= player.UserId then
			grupo = { player.UserId }
		end
		local jogadoresGrupo = {}
		for _, userId in ipairs(grupo) do
			local membro = localizarJogador(userId)
			if not membro then
				enviarRecusa(player, nil, "Um integrante do grupo se desconectou; atualize o grupo.")
				return false
			end
			if pedido.command == "start-world-encounter" and membro.UserId ~= player.UserId then
				local pertoOk, perto = pcall(podeIniciarNaRegiao, membro, pedido.areaId)
				if not pertoOk or perto ~= true then
					ultimosInicios[player.UserId] = anterior
					enviarRecusa(player, nil, "O grupo precisa se reunir no mesmo marco antes de iniciar.")
					return false
				end
			end
			local okCombate, membroEmCombate = pcall(combateLegadoAtivo, membro)
			local jaAtivo = false
			for _, existente in encontros do
				if existente.atoresPorJogador[userId] and existente.estado.phase == "active" then jaAtivo = true; break end
			end
			if not okCombate or membroEmCombate == true or jaAtivo then
				enviarRecusa(player, nil, "Um integrante do grupo está em outra partida.")
				return false
			end
			table.insert(jogadoresGrupo, membro)
		end
		local elenco = CRIATURAS_DO_ENCONTRO_INICIAL
		if pedido.command == "start-world-encounter" then
			local zona = EncontrosPorZona.elegivel(pedido.areaId, #jogadoresGrupo)
			if not zona then
				enviarRecusa(player, nil, "Este marco não está elegível para o tamanho do grupo.")
				return false
			end
			elenco = zona.elenco
		end
		local encounterId, estadoOuErro = api.criarParaGrupo(jogadoresGrupo, elenco,
			if pedido.command == "start-world-encounter" then pedido.areaId else nil)
		if not encounterId then
			enviarRecusa(player, nil, estadoOuErro or "Não foi possível iniciar o encontro.")
			return false
		end
		ultimosInicios[player.UserId] = {
			requestId = pedido.requestId,
			command = pedido.command,
			at = ultimosInicios[player.UserId].at,
			encounterId = encounterId,
		}
		local membrosQueEsperavam = table.clone(filaAutonoma)
		for _, userId in ipairs(grupo) do retirarDaFila(userId) end
		emitirFila()
		for _, userId in ipairs(membrosQueEsperavam) do
			local membro = localizarJogador(userId)
			if membro then emitir(membro, "fila", { jogadores = {}, liderUserId = nil }) end
		end
		return true, encounterId
	end

	function api.solicitarRetorno(player, pedido)
		if player == nil or type(pedido) ~= "table"
			or pedido.command ~= "return-autonomous"
			or not idValido(pedido.encounterId) or not idValido(pedido.requestId)
		then
			enviarRecusa(player, nil, "Pedido de retorno inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId" then
				enviarRecusa(player, nil, "O pedido de retorno contém campos não permitidos.")
				return false
			end
		end
		local anterior = ultimosRetornos[player.UserId]
		if anterior and anterior.requestId == pedido.requestId and anterior.encounterId == pedido.encounterId then
			emitir(player, "retornado", { encounterId = pedido.encounterId })
			return true
		end
		local encontro = encontros[pedido.encounterId]
		if not encontro or not encontro.atoresPorJogador[player.UserId] then
			enviarRecusa(player, nil, "Encontro indisponível.")
			return false
		end
		local ator = encontro.atoresPorId[encontro.atoresPorJogador[player.UserId]]
		if not encontroFinalizado(encontro) and not (ator and ator.fled) then
			enviarRecusa(player, encontro, "O encontro ainda está em andamento.")
			return false
		end
		encontro.retornaram[player.UserId] = true
		ultimosRetornos[player.UserId] = { encounterId = pedido.encounterId, requestId = pedido.requestId }
		emitir(player, "retornado", { encounterId = pedido.encounterId })
		limparEncontroSeTodosRetornaram(pedido.encounterId, encontro)
		return true
	end

	function api.solicitarReconexao(player, pedido)
		if player == nil or type(player.UserId) ~= "number" or not jogadorConectado(player) or type(pedido) ~= "table"
			or pedido.command ~= "reconnect-autonomous" or not idValido(pedido.requestId)
		then
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "requestId" then return false end
		end
		local anterior = ultimasReconexoes[player.UserId]
		if anterior and agora() - anterior < INTERVALO_PEDIDO then return false end
		ultimasReconexoes[player.UserId] = agora()
		api.notificarConexao(player)
		for _, encontro in encontros do
			local atorId = encontro.atoresPorJogador[player.UserId]
			if atorId and not (encontro.retornaram and encontro.retornaram[player.UserId]) then
				local estado = estadoPara(encontro, player.UserId)
				if estado then emitir(player, "estado", estado); return true end
			end
		end
		return false
	end

	-- API somente servidor para os resolvedores futuros; cada leitura recebe cópia.
	function api.atores(encounterId)
		local encontro = encontros[encounterId]
		if not encontro then return nil end
		local lista = {}
		for _, actorId in ipairs(encontro.ordemInicial) do
			table.insert(lista, copiar(encontro.atoresPorId[actorId]))
		end
		return lista
	end

	function api.estado(encounterId)
		local encontro = encontros[encounterId]
		return if encontro then Turnos.consultar(encontro.estado) else nil
	end

	function api.emEncontroAtivo()
		for _, encontro in encontros do
			if encontro.estado.phase == "active" then return true end
		end
		return false
	end

	enviarRecusa = function(player, encontro, mensagem)
		if player then
			local estado = if encontro then estadoPara(encontro, player.UserId) else nil
			emitir(player, "recusado", {
				mensagem = mensagem,
				estado = estado,
			})
		end
	end

	local function atualizarDuracoesDeCondicao(encontro, atorEncerradoId, proximoAtorId, proximaRodada)
		local expiradas = {}
		for _, atorId in ipairs(encontro.ordemInicial) do
			local ator = encontro.atoresPorId[atorId]
			if ator and ator.fled then continue end
			local duracoes = ator and ator.condicoesAteProximaVez
			if type(duracoes) == "table" then
				for condicao, duracao in duracoes do
					local expirou = duracao == true and atorId == atorEncerradoId
					if type(duracao) == "table" then
						if type(duracao.rodadaFim) == "number" then
							expirou = proximaRodada >= duracao.rodadaFim
						elseif duracao.gatilho == atorEncerradoId and duracao.estado == "ativa" then
							expirou = true
						elseif duracao.gatilho == proximoAtorId and duracao.estado == "aplicada" then
							duracao.estado = "ativa"
						end
					end
					if expirou then
						if ator.condicoes[condicao] ~= nil then
							ator.condicoes[condicao] = nil
							table.insert(expiradas, condicao)
						end
						duracoes[condicao] = nil
					end
				end
			end
		end
		return expiradas
	end

	local function atualizarDuracoesDeEstado(encontro, atorEncerradoId, proximoAtorId, proximaRodada)
		local expirados = {}
		for _, atorId in ipairs(encontro.ordemInicial) do
			local ator = encontro.atoresPorId[atorId]
			if ator and ator.fled then continue end
			for nome, estado in (ator and ator.estadosDeCombate or {}) do
				local duracao = estado.duracao
				local expirou = false
				if type(duracao) == "table" then
					if type(duracao.rodadaFim) == "number" then
						expirou = proximaRodada >= duracao.rodadaFim
					elseif duracao.gatilho == atorEncerradoId and duracao.estado == "ativa" then
						expirou = true
					elseif duracao.gatilho == proximoAtorId and duracao.estado == "aplicada" then
						duracao.estado = "ativa"
					end
				end
				if expirou then
					ator.estadosDeCombate[nome] = nil
					table.insert(expirados, nome)
				end
			end
		end
		return expirados
	end

	local function atualizarPvTemporarios(encontro, turno)
		local expirados = {}
		for _, atorId in ipairs(encontro.ordemInicial) do
			local ator = encontro.atoresPorId[atorId]
			if ator and ator.fled then continue end
			if ator and ator.pvTemporarios then
				local estado, expirou = DefesasAutonomas.expirarPvTemporarios(ator.pvTemporarios, turno)
				if expirou then
					table.insert(expirados, { actorId = ator.id, actorName = ator.name or "Participante" })
				end
				ator.pvTemporarios = estado
			end
		end
		return expirados
	end

	local aplicarDanoTemporario
	local function aplicarFim(encontro, atorId, expectedVersion, requestId)
		api.observarEntradasPatrulha()
		local novoEstado, recibo, erro = Turnos.encerrarTurno(encontro.estado, {
			actorId = atorId,
			expectedVersion = expectedVersion,
			requestId = requestId,
		})
		if not novoEstado then return nil, erro end
		-- A prioridade de surpresa vale só na primeira rodada. Restaura RB-13
		-- antes de processar efeitos do próximo ator, preservando só os vivos.
		if encontro.ordemSemSurpresa and recibo.turn > 1 then
			local ordem = {}
			for _, id in ipairs(encontro.ordemSemSurpresa) do
				if table.find(novoEstado.order, id) then table.insert(ordem, id) end
			end
			novoEstado.order, novoEstado.currentIndex = ordem, 1
			recibo.nextActorId = ordem[1]
			encontro.ordemSemSurpresa = nil
		end
		if erro == nil then admitirEntradas(encontro, novoEstado, recibo) end
		-- Desprevenido por surpresa cessa quando o alvo começa a agir; não
		-- remove uma condição preexistente em fichas (somente o marcador R2b).
		if encontro.surpreendidos and encontro.surpreendidos[recibo.nextActorId] then
			local proximo = encontro.atoresPorId[recibo.nextActorId]
			proximo.condicoes.desprevenido = encontro.surpreendidos[recibo.nextActorId].anterior
			encontro.surpreendidos[recibo.nextActorId] = nil
		end
		local atorQueEncerra = encontro.atoresPorId[atorId]
		if atorQueEncerra then atorQueEncerra.fimUltimoTurno = encontro.danoSequencia end
		local alvoInicio = encontro.atoresPorId[recibo.nextActorId]
		local pvTemporariosExpirados = atualizarPvTemporarios(encontro, recibo.turn)
		if recibo.turn ~= encontro.estado.turn then
			for indice = #encontro.dangers, 1, -1 do
				if recibo.turn >= encontro.dangers[indice].expiresTurn then table.remove(encontro.dangers, indice) end
			end
			for indice = #(encontro.zonasDificeis or {}), 1, -1 do
				if recibo.turn >= encontro.zonasDificeis[indice].expiresTurn then table.remove(encontro.zonasDificeis, indice) end
			end
		end
		if alvoInicio then
			alvoInicio.defenderReduction = nil
			alvoInicio.jaAcertouNestaVez = nil
		end
		if alvoInicio and (alvoInicio.condicoes or {})[Fogo.EM_CHAMAS] and (alvoInicio.pv or 0) > 0 then
			local fichaCriatura = alvoInicio.fichaCriatura or {}
			local efeito = Habilidades.danoDeCondicao(rng, Fogo.DANO_EM_CHAMAS, Fogo.TIPO, {
				id = alvoInicio.id,
				condicoes = alvoInicio.condicoes,
				resistencias = fichaCriatura.resistencias or {},
				imunidades = fichaCriatura.imunidades or {},
				resistencia = function() return 0 end,
			})
			local dano = efeito.dano and efeito.dano.total or 0
			local danoAplicado = aplicarDanoTemporario(alvoInicio, dano, recibo.turn)
			if not danoAplicado then return nil, "Não foi possível aplicar o dano de Em Chamas." end
			efeito.dano.pvTemporariosAbsorvidos = danoAplicado.danoAbsorvido
			if dano > 0 then
				encontro.danoSequencia += 1
				alvoInicio.ultimoDano = encontro.danoSequencia
			end
			alvoInicio.defeated = alvoInicio.kind == "criatura" and alvoInicio.pv <= 0
			alvoInicio.downed = alvoInicio.kind == "jogador" and alvoInicio.pv <= 0
			recibo.result = recibo.result or {}
			recibo.result.turnStartDamage = { actorId = alvoInicio.id, damage = efeito.dano,
				condition = Fogo.EM_CHAMAS, defeated = alvoInicio.defeated == true,
				targetPv = alvoInicio.pv, targetDowned = alvoInicio.downed == true,
				targetPvTemporarios = alvoInicio.pvTemporarios and alvoInicio.pvTemporarios.valor or 0 }
			novoEstado.lastRequest.receipt = recibo
			if alvoInicio.defeated then
				local semAlvo, erroRemocao = Turnos.removerDerrotado(novoEstado, alvoInicio.id)
				if semAlvo then novoEstado = semAlvo else return nil, erroRemocao end
			end
			novoEstado = avaliarTerminal(encontro, novoEstado)
		end
		local expiradas = atualizarDuracoesDeCondicao(encontro, atorId, recibo.nextActorId, recibo.turn)
		local estadosExpirados = atualizarDuracoesDeEstado(encontro, atorId, recibo.nextActorId, recibo.turn)
		if #expiradas > 0 or #estadosExpirados > 0 then
			recibo.result = type(recibo.result) == "table" and recibo.result or {}
			if #expiradas > 0 then recibo.result.expiredConditions = expiradas end
			if #estadosExpirados > 0 then recibo.result.expiredStates = estadosExpirados end
			novoEstado.lastRequest.receipt = recibo
		end
		if #pvTemporariosExpirados > 0 then
			recibo.result = type(recibo.result) == "table" and recibo.result or {}
			recibo.result.expiredTemporaryHp = pvTemporariosExpirados
			novoEstado.lastRequest.receipt = recibo
		end
		encontro.estado = novoEstado
		return recibo
	end

	-- O token identifica a vez lógica, enquanto a transição usa a versão atual.
	-- Uma ação pode versionar o estado sem renovar o prazo dessa mesma vez.
	expirarPrazo = function(encontro, prazo)
		local estado = encontro.estado
		if encontros[estado.encounterId] ~= encontro or encontro.prazo ~= prazo
			or estado.phase ~= "active" or estado.turn ~= prazo.turn
			or estado.order[estado.currentIndex] ~= prazo.actorId
		then return end
		local restante = prazo.expiraEm - agora()
		if restante > 0 then
			prazo.handle = agendarPrazo(restante, function() expirarPrazo(encontro, prazo) end)
			return
		end
		-- O callback já está executando; não tenta cancelar a própria coroutine.
		prazo.handle = nil
		local requestId = "prazo:" .. tostring(estado.version) .. ":" .. tostring(prazo.turn)
		local nomeAtor = encontro.nomesPorAtor[prazo.actorId]
		local recibo = aplicarFim(encontro, prazo.actorId, estado.version, requestId)
		if not recibo then return end
		limparPrazo(encontro)
		recibo.result = type(recibo.result) == "table" and recibo.result or {}
		recibo.result.turnTimedOut = true
		recibo.result.turnTimedOutActorName = nomeAtor
		if encontro.estado.lastRequest then encontro.estado.lastRequest.receipt = recibo end
		emitirAosParticipantes(encontro, "recibo", recibo)
		if executarIA then executarIA(estado.encounterId) end
		enviarEstado(encontro)
	end

	local function registrarDano(encontro, alvo, dano)
		if type(dano) ~= "number" or dano <= 0 then return end
		encontro.danoSequencia += 1
		alvo.ultimoDano = encontro.danoSequencia
	end

	aplicarDanoTemporario = function(alvo, dano, turno)
		local resultado = DefesasAutonomas.aplicarDano(alvo.pv, alvo.pvTemporarios, dano, turno)
		if not resultado then return nil end
		alvo.pv, alvo.pvTemporarios = resultado.pv, resultado.pvTemporarios
		return resultado
	end

	local function ajustarResultadoPorPvTemporarios(alvo, resultado, turno)
		if type(resultado.damageDealt) ~= "number" then return true end
		local aplicado = aplicarDanoTemporario(alvo, resultado.damageDealt, turno)
		if not aplicado then return false end
		resultado.targetPv = aplicado.pv
		resultado.targetDefeated = alvo.kind == "criatura" and aplicado.pv <= 0
		resultado.targetDowned = alvo.kind == "jogador" and aplicado.pv <= 0
		resultado.pvTemporariosAbsorvidos = aplicado.danoAbsorvido
		resultado.targetPvTemporarios = alvo.pvTemporarios and alvo.pvTemporarios.valor or 0
		return true
	end

	local function percorrerZonas(encontro, ator, rota)
		local acionadas, final, casasPercorridas = {}, { x = ator.x, z = ator.z }, 0
		local murosAcionados = {}
		for _, casa in ipairs(rota or {}) do
			casasPercorridas += 1
			final = casa
			ator.x, ator.z = casa.x, casa.z
			for _, zona in ipairs(encontro.dangers) do
				if zona.x ~= casa.x or zona.z ~= casa.z then continue end
				if zona.wallId and murosAcionados[zona.wallId] then continue end
				if zona.wallId then murosAcionados[zona.wallId] = true end
				local mecanica = Fogo.MECANICAS[zona.abilityId]
				if not mecanica then continue end
				local efeito = Habilidades.atravessar(rng,
					mecanica, {
						id = ator.id, condicoes = ator.condicoes or {},
						resistencias = ator.fichaCriatura and ator.fichaCriatura.resistencias or {},
						imunidades = ator.fichaCriatura and ator.fichaCriatura.imunidades or {},
						resistencia = function() return 0 end,
					})
				local dano = efeito.dano and efeito.dano.total or 0
				local danoAplicado = aplicarDanoTemporario(ator, dano, encontro.estado.turn)
				if not danoAplicado then break end
				efeito.dano.pvTemporariosAbsorvidos = danoAplicado.danoAbsorvido
				for _, condicao in ipairs(efeito.aplica or {}) do ator.condicoes[condicao] = true end
				registrarDano(encontro, ator, dano)
				ator.defeated = ator.kind == "criatura" and ator.pv <= 0 or ator.defeated
				ator.downed = ator.kind == "jogador" and ator.pv <= 0
				table.insert(acionadas, { zoneId = zona.id, abilityId = zona.abilityId,
					x = casa.x, z = casa.z, damage = efeito.dano, applies = efeito.aplica or {} })
				if ator.pv <= 0 then break end
			end
			if type(ator.pv) == "number" and ator.pv <= 0 then break end
		end
		return final, acionadas, casasPercorridas
	end

	local function grupoDerrotado(encontro)
		local encontrouJogador = false
		for _, id in ipairs(encontro.ordemInicial) do
			local ator = encontro.atoresPorId[id]
			if ator and ator.fled then continue end
			if ator.kind == "jogador" then
				encontrouJogador = true
				-- Ficha ausente é estado não verificado, não derrota.
				if type(ator.pv) ~= "number" or ator.pv > 0 then return false end
			end
		end
		return encontrouJogador
	end

	avaliarTerminal = function(encontro, estadoCandidato)
		if grupoDerrotado(encontro) then return Turnos.concluir(estadoCandidato, "defeat") end
		if estadoCandidato.phase ~= "active" then return estadoCandidato end
		local encontrouCriatura = false
		for _, id in ipairs(encontro.ordemInicial) do
			local ator = encontro.atoresPorId[id]
			if ator and ator.fled then continue end
			if ator.kind == "criatura" then
				encontrouCriatura = true
				if ator.defeated ~= true and (type(ator.pv) ~= "number" or ator.pv > 0) then
					return estadoCandidato
				end
			end
		end
		if encontrouCriatura then return Turnos.concluir(estadoCandidato, "victory") end
		return estadoCandidato
	end

	local function aplicarDeslocamentoForcado(encontro, estadoCandidato, ator, rota, resultado, removerCriaturaDerrotada)
		local casaFinal, zonasAcionadas, casasPercorridas = percorrerZonas(encontro, ator,
			if type(ator.pv) == "number" and ator.pv <= 0 then {} else rota)
		resultado.to = { x = casaFinal.x, z = casaFinal.z }
		resultado.houses = casasPercorridas
		resultado.hazardsTriggered = zonasAcionadas
		if removerCriaturaDerrotada and ator.kind == "criatura" and ator.defeated then
			soltarVinculoMao(encontro, ator.id)
			local semAtor, erroRemocao = Turnos.removerDerrotado(estadoCandidato, ator.id)
			if not semAtor then return nil, erroRemocao end
			estadoCandidato = semAtor
		end
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		return estadoCandidato
	end

	-- Reservado ao resolvedor server-side: consome 1 das 3 Ações da vez atual.
	-- Intenções de combate ainda não são expostas por remoto neste recorte.
	function api.consumirAcaoInterno(encounterId, actorId, expectedVersion, requestId)
		local encontro = encontros[encounterId]
		if not encontro or not idValido(actorId) or not idValido(requestId)
			or type(expectedVersion) ~= "number" or expectedVersion % 1 ~= 0
		then
			return nil, "Pedido de ação inválido."
		end
		local novoEstado, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId,
			expectedVersion = expectedVersion,
			requestId = requestId,
		})
		if not novoEstado then return nil, erro end
		encontro.estado = novoEstado
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return recibo
	end

	local function barreiraAtiva(encontro, wallId, x, z)
		for _, zona in ipairs(encontro.dangers or {}) do
			if (zona.abilityId == MURO_DE_TERRA or zona.abilityId == ANTEPARO_TEORICO) and zona.wallId == wallId
				and zona.expiresTurn > encontro.estado.turn and (x == nil or (zona.x == x and zona.z == z))
			then
				return { id = wallId, abilityId = zona.abilityId, x = zona.x, z = zona.z, pv = zona.pv }
			end
		end
		return nil
	end

	local function barreiraMirada(encontro, targetId)
		local wallId, x, z = string.match(targetId, "^parede:(.+):(%d+):(%d+)$")
		if not wallId then return nil end
		return barreiraAtiva(encontro, wallId, tonumber(x), tonumber(z))
	end

	local function barreiraNaLinha(encontro, atacante, alvo)
		local linha = Combate.linha(atacante.x, atacante.z, alvo.x, alvo.z)
		for _, casa in ipairs(linha) do
			for _, zona in ipairs(encontro.dangers or {}) do
				if (zona.abilityId == MURO_DE_TERRA or zona.abilityId == ANTEPARO_TEORICO)
					and zona.x == casa[1] and zona.z == casa[2]
					and zona.expiresTurn > encontro.estado.turn
				then
					if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, casa[1], casa[2]) then
						return nil
					end
					return barreiraAtiva(encontro, zona.wallId, casa[1], casa[2])
				end
			end
		end
		return nil
	end

	local function aplicarDanoBarreira(encontro, zona, resultado)
		local restantes = {}
		for _, celula in ipairs(encontro.dangers) do
			if celula.wallId == zona.id then
				if not resultado.targetDefeated then
					celula.pv = resultado.targetPv
					table.insert(restantes, celula)
				end
			else
				table.insert(restantes, celula)
			end
		end
		encontro.dangers = restantes
		resultado.barrierDestroyed = resultado.targetDefeated
		resultado.barrierPv = resultado.targetPv
	end

	local function resolverControleMao(encontro, actorId, expectedVersion, requestId, abilityId)
		local mecanica = HabilidadesAutonomas.mecanica(abilityId)
		local action = "ability:" .. abilityId
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId, expectedVersion = expectedVersion, requestId = requestId,
			action = action, targetId = actorId, actionsCost = mecanica.acoes,
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local ator = encontro.atoresPorId[actorId]
		local resultado
		if abilityId == ESCAPAR_MAO then
			local vinculo = encontro.vinculosMao[actorId]
			if not vinculo then return nil, "Você não está preso por Mão de Terra." end
			resultado, erro = HabilidadesAutonomas.escaparMao(rng, ator, vinculo, catalogo)
			if resultado and resultado.escaped then soltarVinculoMao(encontro, actorId) end
		elseif abilityId == SOLTAR_MAO then
			local alvoId
			for id, vinculo in pairs(encontro.vinculosMao) do
				if vinculo.sourceId == actorId then alvoId = id; break end
			end
			if not alvoId then return nil, "Você não sustenta Mão de Terra." end
			local vinculo = soltarVinculoMao(encontro, alvoId)
			resultado = { actorId = actorId, targetId = alvoId, action = "use-ability", abilityId = abilityId,
				actionsCost = 0, released = true, removedConditions = copiar(vinculo.condicoes) }
		else
			local targetId, vinculo
			for id, atual in pairs(encontro.vinculosMao) do
				if atual.sourceId == actorId then targetId, vinculo = id, atual; break end
			end
			local alvo = targetId and encontro.atoresPorId[targetId]
			if not alvo or not vinculo then return nil, "Você não sustenta Mão de Terra." end
			local ocupantes = {}
			for _, id in ipairs(encontro.estado.order) do table.insert(ocupantes, encontro.atoresPorId[id]) end
			local destino, erroMovimento = MovimentoAutonomo.aproximar(alvo.x, alvo.z, ocupantes, { ator }, 2,
				celulasBloqueadasAtivas(encontro), TerrenoAutonomo.chavesDe(celulasDificeisAtivas(encontro)))
			if not destino then return nil, erroMovimento or "Não há caminho livre para arrastar." end
			local origem = { x = alvo.x, z = alvo.z }
			resultado = { actorId = actorId, targetId = targetId, action = "use-ability", abilityId = abilityId,
				actionsCost = 1, from = origem, movementCost = destino.custoMovimento or destino.casas }
			estadoCandidato, erro = aplicarDeslocamentoForcado(encontro, estadoCandidato, alvo, destino.rota, resultado, true)
			if not estadoCandidato then return nil, erro end
		end
		if not resultado then return nil, erro end
		recibo.result = resultado
		estadoCandidato.lastAction.receipt = recibo
		encontro.estado = estadoCandidato
		return recibo
	end

	local function resolverAtaqueBasico(encontro, actorId, expectedVersion, requestId, targetId)
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId,
			expectedVersion = expectedVersion,
			requestId = requestId,
			action = "basic-attack",
			targetId = targetId,
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local atacante = encontro.atoresPorId[actorId]
		local alvo = encontro.atoresPorId[targetId]
		if alvo and alvo.fled then return nil, "Alvo saiu do encontro." end
		local parede = barreiraMirada(encontro, targetId)
		if parede then
			if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, parede.x, parede.z) then
				return nil, "Um obstáculo bloqueia a linha de visão até o muro."
			end
			local resultado, falha = CombateAutonomo.atacarBarreira(rng, atacante, parede, catalogo, false)
			if not resultado then return nil, falha end
			recibo.result = resultado
			estadoCandidato.lastAction.receipt = recibo
			aplicarDanoBarreira(encontro, parede, resultado)
			encontro.estado = estadoCandidato
			return recibo
		end
		if not alvo then return nil, "Alvo indisponível." end
		local paredeNaLinha = barreiraNaLinha(encontro, atacante, alvo)
		if paredeNaLinha then
			local resultado, falha = CombateAutonomo.atacarBarreira(rng, atacante, paredeNaLinha, catalogo, false)
			if not resultado then return nil, falha end
			recibo.result = resultado
			estadoCandidato.lastAction.receipt = recibo
			aplicarDanoBarreira(encontro, paredeNaLinha, resultado)
			encontro.estado = estadoCandidato
			return recibo
		end
		if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, alvo.x, alvo.z) then
			return nil, "Um obstáculo bloqueia a linha de visão."
		end
		local resultado, falha = CombateAutonomo.atacarBasico(rng,
			paraResolucao(encontro, atacante), paraResolucao(encontro, alvo), catalogo)
		if not resultado then return nil, falha end
		if not ajustarResultadoPorPvTemporarios(alvo, resultado, encontro.estado.turn) then
			return nil, "Não foi possível aplicar a defesa de PV temporários."
		end
		recibo.result = resultado
		estadoCandidato.lastAction.receipt = recibo
		registrarDano(encontro, alvo, resultado.damageDealt)
		if resultado.attack and resultado.attack.acertou then atacante.jaAcertouNestaVez = true end
		alvo.defeated = resultado.targetDefeated
		if resultado.targetDefeated then soltarVinculoMao(encontro, targetId) end
		if resultado.targetDefeated then
			local semAlvo, erroRemocao = Turnos.removerDerrotado(estadoCandidato, targetId)
			if not semAlvo then return nil, erroRemocao end
			estadoCandidato = semAlvo
		end
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		encontro.estado = estadoCandidato
		return recibo
	end

	local function resolverDisparo(encontro, actorId, expectedVersion, requestId, targetId)
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId, expectedVersion = expectedVersion, requestId = requestId,
			action = "ranged-attack", targetId = targetId,
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local atacante, alvo = encontro.atoresPorId[actorId], encontro.atoresPorId[targetId]
		if alvo and alvo.fled then return nil, "Alvo saiu do encontro." end
		local parede = barreiraMirada(encontro, targetId)
		if parede then
			if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, parede.x, parede.z) then
				return nil, "Um obstáculo bloqueia a linha de visão até o muro."
			end
			local resultado, falha = CombateAutonomo.atacarBarreira(rng, atacante, parede, catalogo, true)
			if not resultado then return nil, falha end
			recibo.result = resultado
			estadoCandidato.lastAction.receipt = recibo
			aplicarDanoBarreira(encontro, parede, resultado)
			encontro.estado = estadoCandidato
			return recibo
		end
		if not alvo then return nil, "Alvo indisponível." end
		local paredeNaLinha = barreiraNaLinha(encontro, atacante, alvo)
		if paredeNaLinha then
			local resultado, falha = CombateAutonomo.atacarBarreira(rng, atacante, paredeNaLinha, catalogo, true)
			if not resultado then return nil, falha end
			recibo.result = resultado
			estadoCandidato.lastAction.receipt = recibo
			aplicarDanoBarreira(encontro, paredeNaLinha, resultado)
			encontro.estado = estadoCandidato
			return recibo
		end
		if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, alvo.x, alvo.z) then
			return nil, "Um obstáculo bloqueia a linha de visão."
		end
		local resultado, falha = CombateAutonomo.atacarDistancia(rng,
			paraResolucao(encontro, atacante), paraResolucao(encontro, alvo), catalogo)
		if not resultado then return nil, falha end
		if not ajustarResultadoPorPvTemporarios(alvo, resultado, encontro.estado.turn) then
			return nil, "Não foi possível aplicar a defesa de PV temporários."
		end
		recibo.result = resultado
		estadoCandidato.lastAction.receipt = recibo
		registrarDano(encontro, alvo, resultado.damageDealt)
		if resultado.attack and resultado.attack.acertou then atacante.jaAcertouNestaVez = true end
		alvo.defeated = resultado.targetDefeated
		if resultado.targetDefeated then soltarVinculoMao(encontro, targetId) end
		if resultado.targetDefeated then
			local semAlvo, erroRemocao = Turnos.removerDerrotado(estadoCandidato, targetId)
			if not semAlvo then return nil, erroRemocao end
			estadoCandidato = semAlvo
		end
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		encontro.estado = estadoCandidato
		return recibo
	end

	local function resolverHabilidade(encontro, actorId, expectedVersion, requestId, abilityId, targetId)
		local mecanica = HabilidadesAutonomas.mecanica(abilityId)
		if not mecanica then return nil, "Habilidade não implementada neste encontro." end
		if abilityId == ESCAPAR_MAO or abilityId == ARRASTAR_MAO or abilityId == SOLTAR_MAO then
			return resolverControleMao(encontro, actorId, expectedVersion, requestId, abilityId)
		end
		if mecanica.exigeArmaGelo then
			local estado = (encontro.atoresPorId[actorId].estadosDeCombate or {}).armaGelo
			if type(estado) ~= "table" or estado.valor ~= true then
				return nil, "Conjure a Lâmina de Gelo antes de atacar com ela."
			end
		end
		local action = "ability:" .. abilityId
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId,
			expectedVersion = expectedVersion,
			requestId = requestId,
			action = action,
			targetId = targetId,
			actionsCost = mecanica.acoes,
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local usos = encontro.habilidadesUsadas[actorId]
		if mecanica.umaVezPorTurno and usos and usos[abilityId] == encontro.estado.turn then
			return nil, "Esta habilidade só pode ser usada uma vez por turno."
		end
		if abilityId == HabilidadesAutonomas.VACUO_LOCALIZADO then
			local alvoVacuado = encontro.atoresPorId[targetId]
			if not alvoVacuado or alvoVacuado.kind ~= "criatura" or alvoVacuado.defeated == true
				or type(alvoVacuado.pv) ~= "number" or alvoVacuado.pv <= 0
				or alvoVacuado.respira ~= true
			then return nil, "Vácuo Localizado só afeta criaturas vivas que respiram." end
			local ultimaRodada = encontro.ultimaRodadaVacuadaPorAlvo[targetId]
			if type(ultimaRodada) == "number" and encontro.estado.turn - ultimaRodada <= 1 then
				return nil, "Esse alvo não pode ser afetado em rodadas consecutivas."
			end
		end
		local atacante, alvo = encontro.atoresPorId[actorId], encontro.atoresPorId[targetId]
		if alvo and alvo.fled then return nil, "Alvo saiu do encontro." end
		local resultado, falha
		if abilityId == "ability/fogo/Principiante/fagulha" then
			local x, z = string.match(targetId or "", "^casa:(%d+):(%d+)$")
			if not x then return nil, "Fagulha exige a seleção de uma casa." end
			if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, tonumber(x), tonumber(z)) then
				return nil, "Um obstáculo bloqueia a linha de visão até a casa."
			end
			resultado, falha = HabilidadesAutonomas.criarFagulha(atacante, tonumber(x), tonumber(z))
		elseif abilityId == "mesa/defender" then
			if not atacante or atacante.kind ~= "jogador" or alvo ~= atacante or type(atacante.ficha) ~= "table"
				or type(atacante.pv) ~= "number" or atacante.pv <= 0
			then
				return nil, "Defender exige um personagem vivo e só protege a própria ficha."
			end
			local ficha = atacante.ficha
			local atributos = ficha.calculated and ficha.calculated.attributes
			if type(atributos) ~= "table" then return nil, "Ficha incompleta para Defender." end
			local corpo = Execucao.arvoreDeCorpo(ficha, catalogo)
			local rankCorpo = if corpo then Execucao.bonusDeRankDa(ficha, corpo) else 0
			local reducao = Maestrias.reducaoDefender(atributos.vigor or 0, rankCorpo)
			atacante.defenderReduction = reducao
			resultado = { actorId = actorId, targetId = actorId, action = "use-ability", abilityId = abilityId,
				actionsCost = mecanica.acoes, pmCost = mecanica.pm, defenderReduction = reducao }
		elseif abilityId == "ability/cura/Principiante/cura" then
			resultado, falha = HabilidadesAutonomas.usarCura(rng, atacante, alvo, catalogo)
		elseif abilityId == HabilidadesAutonomas.VIGOR_EMPRESTADO then
			resultado, falha = HabilidadesAutonomas.usarVigorEmprestado(rng, atacante, alvo, catalogo)
		elseif abilityId == HabilidadesAutonomas.LAMINA_DE_GELO then
			if targetId ~= actorId then return nil, "Lâmina de Gelo deve ser conjurada em si mesmo." end
			resultado, falha = HabilidadesAutonomas.conjurarLaminaDeGelo(atacante)
			if resultado then
				resultado.weaponState = {
					valor = true,
					duracao = { rodadaFim = encontro.estado.turn + resultado.weaponDurationRounds },
				}
				resultado.weaponExpiresTurn = encontro.estado.turn + resultado.weaponDurationRounds
			end
		elseif abilityId == "ability/fogo/Principiante/clarao" then
			local centroX, centroZ = HabilidadesAutonomas.coordenadasAlvoClarao(targetId)
			local bloqueadas = listaDeCelulas(celulasBloqueadasAtivas(encontro))
			local previsao = if centroX then HabilidadesAutonomas.preverClarao(atacante, centroX, centroZ,
				bloqueadas, encontro.dangers, encontro.estado.turn) else nil
			if not previsao or previsao.targetId ~= targetId then
				return nil, "Clarão exige uma casa visível como centro."
			end
			local atores = {}
			for _, id in ipairs(encontro.ordemInicial) do
				local candidato = encontro.atoresPorId[id]
				if candidato.fled then continue end
				if candidato.id == actorId or not bloqueadoPorObstaculoVisual(encontro,
					atacante.x, atacante.z, candidato.x, candidato.z)
				then table.insert(atores, candidato) end
			end
			resultado, falha = HabilidadesAutonomas.usarClarao(rng, atacante, atores, catalogo, centroX, centroZ)
		elseif abilityId == HabilidadesAutonomas.ATOLEIRO then
			if targetId ~= HabilidadesAutonomas.ALVO_ATOLEIRO then return nil, "Atoleiro é centrado no conjurador." end
			local atores = {}
			for _, id in ipairs(encontro.ordemInicial) do
				local ator = encontro.atoresPorId[id]
				if not ator.fled then table.insert(atores, ator) end
			end
			resultado, falha = HabilidadesAutonomas.usarAtoleiro(rng, atacante, atores, catalogo)
		elseif abilityId == HabilidadesAutonomas.LANCA_DE_PEDRA then
			local ids = HabilidadesAutonomas.decodificarLista(targetId)
			if not ids then return nil, "Lança de Pedra exige uma lista canônica de uma a três criaturas." end
			local alvos = {}
			for _, id in ipairs(ids) do
				local candidato = encontro.atoresPorId[id]
				if not candidato or candidato.kind ~= "criatura" or candidato.defeated == true
					or type(candidato.pv) ~= "number" or candidato.pv <= 0
				then return nil, "A lista contém uma criatura indisponível." end
				if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, candidato.x, candidato.z) then
					return nil, "Um obstáculo bloqueia a linha de visão até um dos alvos."
				end
				table.insert(alvos, candidato)
			end
			resultado, falha = HabilidadesAutonomas.usarLancaDePedra(rng, atacante, alvos, catalogo)
		elseif abilityId == HabilidadesAutonomas.MURO_DE_CHAMAS then
			resultado, falha = HabilidadesAutonomas.criarMuro(atacante, targetId)
		elseif abilityId == HabilidadesAutonomas.MURO_DE_TERRA then
			resultado, falha = HabilidadesAutonomas.criarMuroDeTerra(atacante, targetId,
				listaDeCelulas(celulasBloqueadasAtivas(encontro)), encontro.dangers, encontro.estado.turn)
		elseif abilityId == HabilidadesAutonomas.ANTEPARO_TEORICO then
			resultado, falha = HabilidadesAutonomas.criarAnteparo(atacante, targetId,
				listaDeCelulas(celulasBloqueadasAtivas(encontro)), encontro.dangers, encontro.estado.turn)
		elseif abilityId == HabilidadesAutonomas.ESCUDO_DE_AGUA then
			resultado, falha = HabilidadesAutonomas.criarEscudoDeAgua(atacante, targetId,
				listaDeCelulas(celulasBloqueadasAtivas(encontro)), encontro.dangers, encontro.estado.turn)
		elseif abilityId == HabilidadesAutonomas.NEVOA_DENSA then
			if targetId ~= actorId then return nil, "Névoa Densa é centrada no conjurador." end
			resultado, falha = HabilidadesAutonomas.criarNevoaDensa(atacante)
		elseif abilityId == HabilidadesAutonomas.SOPRO_DE_POEIRA then
			local atores = {}
			for _, id in ipairs(encontro.ordemInicial) do
				local ator = encontro.atoresPorId[id]
				if not ator.fled then table.insert(atores, ator) end
			end
			resultado, falha = CombateAutonomo.soproComDefeitos(HabilidadesAutonomas.usarSoproDePoeira, rng, atacante, atores, targetId,
				listaDeCelulas(celulasBloqueadasAtivas(encontro)), encontro.dangers, encontro.estado.turn, catalogo)
		elseif abilityId == HabilidadesAutonomas.PASSO_DE_VENTO then
			local atores = {}
			for _, id in ipairs(encontro.estado.order) do
				local ator = encontro.atoresPorId[id]
				if ator and ator.fled then continue end
				if ator then table.insert(atores, ator) end
			end
			resultado, falha = HabilidadesAutonomas.criarPassoDeVento(atacante, targetId, atores,
				celulasBloqueadasAtivas(encontro))
		elseif abilityId == MAO_DE_TERRA then
			if encontro.vinculosMao[targetId] then return nil, "Esse alvo já está preso por um vínculo." end
			for _, vinculo in pairs(encontro.vinculosMao) do
				if vinculo.sourceId == actorId then return nil, "Solte Mão de Terra antes de prender outro alvo." end
			end
			if not alvo then return nil, "Mão de Terra exige alvo único." end
			if bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, alvo.x, alvo.z) then
				return nil, "Um obstáculo bloqueia a linha de visão até o alvo."
			end
			resultado, falha = HabilidadesAutonomas.usarMaoDeTerra(rng, atacante, alvo, catalogo)
		else
			if alvo and bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, alvo.x, alvo.z) then
				return nil, "Um obstáculo bloqueia a linha de visão."
			end
			local cruzaEscudoAgua = alvo ~= nil and TerrenoAutonomo.reduzIgneoNaLinha(
				atacante.x, atacante.z, alvo.x, alvo.z, encontro.dangers, encontro.estado.turn)
			resultado, falha = HabilidadesAutonomas.usar(rng, abilityId,
				paraResolucao(encontro, atacante), paraResolucao(encontro, alvo, cruzaEscudoAgua), catalogo)
		end
		if not resultado then return nil, falha end
		if abilityId == HabilidadesAutonomas.VACUO_LOCALIZADO then
			-- A restrição limita tentativas válidas no alvo, mesmo quando ele resiste.
			encontro.ultimaRodadaVacuadaPorAlvo[targetId] = encontro.estado.turn
		end
		if abilityId == HabilidadesAutonomas.PASSO_DE_VENTO then
			atacante.x, atacante.z = resultado.to.x, resultado.to.z
		end
		if abilityId == MAO_DE_TERRA and table.find(resultado.applies or {}, "agarrado") then
			local alvoAtual = encontro.atoresPorId[targetId]
			local propriedades = {}
			for _, condicao in ipairs(resultado.applies) do propriedades[condicao] = alvoAtual.condicoes[condicao] == nil end
			encontro.vinculosMao[targetId] = { sourceId = actorId, cd = resultado.bindingDc, condicoes = propriedades }
		end
		if abilityId == HabilidadesAutonomas.ATOLEIRO then
			local zona = resultado.zone
			zona.expiresTurn = encontro.estado.turn + zona.durationRounds
			table.insert(encontro.zonasDificeis, { id = requestId, expiresTurn = zona.expiresTurn, cells = copiar(zona.cells) })
		end
		if abilityId == HabilidadesAutonomas.LANCA_DE_PEDRA then
			for _, efeito in ipairs(resultado.targets) do
				if efeito.targetDefeated then
					local removido, erroRemocao = Turnos.removerDerrotado(estadoCandidato, efeito.targetId)
					if not removido then return nil, erroRemocao end
					estadoCandidato = removido
				end
			end
		end
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		local empurraoConfirmado = (type(resultado.attack) == "table" and resultado.attack.acertou == true)
			or (type(resultado.resistance) == "table" and resultado.resistance.passou == false)
		if type(resultado.pushHouses) == "number" and resultado.pushHouses > 0 and alvo and empurraoConfirmado
		then
			local dx, dz = alvo.x - atacante.x, alvo.z - atacante.z
			local passoX = if dx == 0 then 0 elseif dx > 0 then 1 else -1
			local passoZ = if dz == 0 then 0 elseif dz > 0 then 1 else -1
			local origem = { x = alvo.x, z = alvo.z }
			local rota = {}
			local cursorX, cursorZ = alvo.x, alvo.z
			local bloqueadas = celulasBloqueadasAtivas(encontro)
			for _ = 1, math.min(resultado.pushHouses, 20) do
			local proximoX, proximoZ = cursorX + passoX, cursorZ + passoZ
				if proximoX < 1 or proximoX > 20 or proximoZ < 1 or proximoZ > 20 then break end
				local ocupado = false
				for _, outroId in ipairs(encontro.estado.order) do
					local outro = encontro.atoresPorId[outroId]
					if outro and outro.id ~= alvo.id and outro.x == proximoX and outro.z == proximoZ then
						ocupado = true
						break
					end
				end
				if ocupado or bloqueadas[tostring(proximoX) .. ":" .. tostring(proximoZ)] == true then break end
				table.insert(rota, { x = proximoX, z = proximoZ })
				cursorX, cursorZ = proximoX, proximoZ
			end
			resultado.push = { from = origem }
			resultado._forcedRoute = rota
		end
		if abilityId == "ability/fogo/Principiante/fagulha" then
			local zona = { id = requestId, x = resultado.x, z = resultado.z,
				expiresTurn = encontro.estado.turn + resultado.durationRounds, abilityId = abilityId }
			table.insert(encontro.dangers, zona)
			resultado.zone = copiar(zona)
		elseif abilityId == "ability/cura/Principiante/cura" then
			resultado.freshWound = EstadoHabilidades.feridaFresca(alvo, atacante, 0)
		elseif abilityId == HabilidadesAutonomas.MURO_DE_CHAMAS or abilityId == HabilidadesAutonomas.MURO_DE_TERRA
			or abilityId == HabilidadesAutonomas.ANTEPARO_TEORICO
		then
			local wallId = requestId
			local muro = { id = wallId, wallId = wallId, abilityId = abilityId,
				expiresTurn = encontro.estado.turn + resultado.durationRounds, cells = copiar(resultado.cells),
				pv = resultado.zonePv }
			for indice, casa in ipairs(resultado.cells) do
				table.insert(encontro.dangers, { id = wallId .. ":" .. tostring(indice), wallId = wallId,
					abilityId = abilityId, expiresTurn = muro.expiresTurn, pv = muro.pv, pvMax = muro.pv,
					x = casa.x, z = casa.z })
			end
			resultado.zone = muro
		elseif abilityId == HabilidadesAutonomas.ESCUDO_DE_AGUA then
			local zona = { id = requestId, abilityId = abilityId,
				expiresTurn = encontro.estado.turn + resultado.durationRounds,
				coverage = resultado.coverage, reduzIgneo = resultado.reduzIgneo == true,
				cells = copiar(resultado.cells) }
			for indice, casa in ipairs(resultado.cells) do
				table.insert(encontro.dangers, { id = requestId .. ":" .. tostring(indice), abilityId = abilityId,
					expiresTurn = zona.expiresTurn, coverage = zona.coverage, reduzIgneo = zona.reduzIgneo,
					x = casa.x, z = casa.z })
			end
			resultado.zone = zona
		elseif abilityId == HabilidadesAutonomas.NEVOA_DENSA then
			local zona = { id = requestId, abilityId = abilityId,
				expiresTurn = encontro.estado.turn + resultado.durationRounds, cells = copiar(resultado.cells) }
			for indice, casa in ipairs(resultado.cells) do
				table.insert(encontro.dangers, { id = requestId .. ":" .. tostring(indice), abilityId = abilityId,
					expiresTurn = zona.expiresTurn, x = casa.x, z = casa.z })
			end
			resultado.zone = zona
		end
		recibo.result = resultado
		estadoCandidato.lastAction.receipt = recibo
		if abilityId == "ability/fogo/Principiante/clarao" or abilityId == HabilidadesAutonomas.LANCA_DE_PEDRA
			or abilityId == HabilidadesAutonomas.ATOLEIRO or abilityId == HabilidadesAutonomas.SOPRO_DE_POEIRA then
			for _, efeito in ipairs(resultado.targets or {}) do
				local atingido = encontro.atoresPorId[efeito.actorId]
				if atingido then
					if abilityId == HabilidadesAutonomas.LANCA_DE_PEDRA then
						if not ajustarResultadoPorPvTemporarios(atingido, efeito, encontro.estado.turn) then
							return nil, "Não foi possível aplicar a defesa de PV temporários."
						end
						atingido.defeated = efeito.targetDefeated
						registrarDano(encontro, atingido, efeito.damageDealt)
					end
					for _, condicao in ipairs(efeito.applies or {}) do
						atingido.condicoes[condicao] = true
						atingido.condicoesAteProximaVez = atingido.condicoesAteProximaVez or {}
					atingido.condicoesAteProximaVez[condicao] = if abilityId == HabilidadesAutonomas.LANCA_DE_PEDRA
						or abilityId == HabilidadesAutonomas.ATOLEIRO or abilityId == HabilidadesAutonomas.SOPRO_DE_POEIRA
							then { gatilho = atingido.id, estado = "aplicada" } else true
					end
				end
			end
		else
			if type(resultado.damageDealt) == "number"
				and not ajustarResultadoPorPvTemporarios(alvo, resultado, encontro.estado.turn)
			then return nil, "Não foi possível aplicar a defesa de PV temporários." end
			if type(resultado.targetPv) == "number" then alvo.pv = resultado.targetPv end
			registrarDano(encontro, alvo, resultado.damageDealt)
			if resultado.targetDefeated ~= nil then alvo.defeated = resultado.targetDefeated end
			if resultado.targetDowned ~= nil then alvo.downed = resultado.targetDowned end
		end
		if resultado._forcedRoute then
			local deslocamento = resultado.push
			local rotaForcada = resultado._forcedRoute
			resultado._forcedRoute = nil
			estadoCandidato, erro = aplicarDeslocamentoForcado(encontro, estadoCandidato, alvo, rotaForcada, deslocamento)
			if not estadoCandidato then return nil, erro end
			resultado.push.to = deslocamento.to
			resultado.push.houses = deslocamento.houses
			resultado.hazardsTriggered = deslocamento.hazardsTriggered
			resultado.targetPv = alvo.pv
			resultado.targetDefeated = alvo.defeated == true
			resultado.targetDowned = alvo.downed == true
		end
		atacante.pm = math.max(0, (atacante.pm or 0) - resultado.pmCost)
		if resultado.ptCost then atacante.pt = (atacante.pt or 0) - resultado.ptCost end
		if resultado.attack and resultado.attack.acertou then atacante.jaAcertouNestaVez = true end
		if abilityId == HabilidadesAutonomas.VIGOR_EMPRESTADO then
			local estadoTemp, alterado = DefesasAutonomas.concederPvTemporarios(alvo.pvTemporarios,
				resultado.pvTemporariosConcedidos or 0, encontro.estado.turn, mecanica.duracaoRodadas)
			if not estadoTemp and (resultado.pvTemporariosConcedidos or 0) > 0 then
				return nil, "Não foi possível conceder PV temporários."
			end
			alvo.pvTemporarios = estadoTemp
			resultado.pvTemporariosAtual = estadoTemp and estadoTemp.valor or 0
			resultado.pvTemporariosExpiraNoTurno = estadoTemp and estadoTemp.expiraNoTurno or nil
			resultado.pvTemporariosAtualizado = alterado == true
		end
		if abilityId ~= "ability/fogo/Principiante/clarao" and abilityId ~= HabilidadesAutonomas.LANCA_DE_PEDRA
			and abilityId ~= HabilidadesAutonomas.ATOLEIRO and abilityId ~= HabilidadesAutonomas.SOPRO_DE_POEIRA
			and abilityId ~= HabilidadesAutonomas.MURO_DE_CHAMAS then
			for _, condicao in ipairs(resultado.applies or {}) do
				alvo.condicoes[condicao] = true
				if type(mecanica.duracao) == "table" then
					alvo.condicoesAteProximaVez = alvo.condicoesAteProximaVez or {}
					local duracao = mecanica.duracao
					if type(duracao.rodadas) == "number" then
						alvo.condicoesAteProximaVez[condicao] = {
							rodadaFim = encontro.estado.turn + duracao.rodadas,
						}
					elseif duracao.de == "alvo" or duracao.de == "conjurador" then
						alvo.condicoesAteProximaVez[condicao] = {
							gatilho = if duracao.de == "conjurador" then actorId else targetId,
							estado = "aplicada",
						}
					end
				end
			end
		end
		if abilityId == HabilidadesAutonomas.LAMINA_DE_GELO then
			atacante.estadosDeCombate = atacante.estadosDeCombate or {}
			atacante.estadosDeCombate.armaGelo = copiar(resultado.weaponState)
		end
		for _, estado in ipairs(resultado.states or {}) do
			if type(estado) == "table" and type(estado.nome) == "string" then
				alvo.estadosDeCombate = alvo.estadosDeCombate or {}
				local duracao = estado.duracao or {}
				local tracker = {}
				if type(duracao.rodadas) == "number" then
					tracker.rodadaFim = encontro.estado.turn + duracao.rodadas
				elseif duracao.de == "alvo" or duracao.de == "conjurador" then
					tracker.gatilho = if duracao.de == "conjurador" then actorId else targetId
					tracker.estado = "aplicada"
				end
				alvo.estadosDeCombate[estado.nome] = { valor = estado.valor, duracao = tracker }
			end
		end
		if abilityId ~= "ability/fogo/Principiante/clarao" and abilityId ~= HabilidadesAutonomas.SOPRO_DE_POEIRA and resultado.targetDefeated then
			soltarVinculoMao(encontro, targetId)
			local semAlvo, erroRemocao = Turnos.removerDerrotado(estadoCandidato, targetId)
			if not semAlvo then return nil, erroRemocao end
			estadoCandidato = semAlvo
		end
		if mecanica.umaVezPorTurno then
			usos = usos or {}
			usos[abilityId] = encontro.estado.turn
			encontro.habilidadesUsadas[actorId] = usos
		end
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		encontro.estado = estadoCandidato
		return recibo
	end

	local function resolverItem(encontro, actorId, expectedVersion, requestId, itemId, targetId)
		if itemId ~= ItensAutonomos.pocaoMenorId() then return nil, "Item não implementado neste encontro." end
		local action = "item:" .. itemId
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId, expectedVersion = expectedVersion, requestId = requestId,
			action = action, targetId = targetId, actionsCost = 1,
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local atacante, alvo = encontro.atoresPorId[actorId], encontro.atoresPorId[targetId]
		if alvo and alvo.fled then return nil, "Alvo saiu do encontro." end
		local resultado, falha = ItensAutonomos.usar(rng, itemId, atacante, alvo)
		if not resultado then return nil, falha end
		local inventario = atacante.ficha.construction.inventory
		local indiceConsumido
		for indice, item in ipairs(inventario) do
			if item.sourceLocalId == resultado.inventorySourceLocalId then
				indiceConsumido = indice
				break
			end
		end
		if not indiceConsumido then return nil, "O item mudou durante a ação." end
		if consumirItemPessoal then
			local player = localizarJogador(atacante.userId)
			local ok, consumido = pcall(consumirItemPessoal, player, itemId, resultado.inventorySourceLocalId)
			if not ok or consumido ~= true then return nil, "O item não está mais no inventário da sessão." end
		end
		table.remove(inventario, indiceConsumido)
		resultado.inventorySourceLocalId = nil
		recibo.result = resultado
		estadoCandidato.lastAction.receipt = recibo
		alvo.pv, alvo.downed = resultado.targetPv, resultado.targetDowned
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		encontro.estado = estadoCandidato
		return recibo
	end

	local function resolverMovimento(encontro, actorId, expectedVersion, requestId, x, z)
		local atacante = encontro.atoresPorId[actorId]
		if not atacante or atacante.kind ~= "jogador" then return nil, "Só personagens de jogador podem solicitar movimento." end
		if atacante.pv ~= nil and (type(atacante.pv) ~= "number" or atacante.pv <= 0) then
			return nil, "Personagem sem PV não pode se mover."
		end
		local alvoId = "casa:" .. tostring(x) .. ":" .. tostring(z)
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId,
			expectedVersion = expectedVersion,
			requestId = requestId,
			action = "move",
			targetId = alvoId,
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local ocupantes = {}
		for _, id in ipairs(encontro.estado.order) do
			if id ~= actorId then table.insert(ocupantes, encontro.atoresPorId[id]) end
		end
		local origemX, origemZ = atacante.x, atacante.z
		local movimento, falha = MovimentoAutonomo.validar(
			origemX, origemZ, x, z, ocupantes,
			math.max(0, (atacante.movementCasas or 0)
				- (((atacante.estadosDeCombate or {}).reduzMovimento or {}).valor or 0)),
			celulasBloqueadasAtivas(encontro), TerrenoAutonomo.chavesDe(celulasDificeisAtivas(encontro))
		)
		if not movimento then return nil, falha end
		local casaFinal, zonasAcionadas, casasPercorridas = percorrerZonas(encontro, atacante, movimento.rota)
		recibo.result = {
			fromX = origemX, fromZ = origemZ, toX = casaFinal.x, toZ = casaFinal.z,
			requestedToX = x, requestedToZ = z, casas = casasPercorridas,
			custoMovimento = movimento.custoMovimento or casasPercorridas,
			hazardsTriggered = zonasAcionadas,
			defectMovement = copiar(atacante.defectMovement),
		}
		estadoCandidato.lastAction.receipt = recibo
		if atacante.kind == "criatura" and atacante.defeated then
			local semAtor, erroRemocao = Turnos.removerDerrotado(estadoCandidato, actorId)
			if not semAtor then return nil, erroRemocao end
			estadoCandidato = semAtor
		end
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		encontro.estado = estadoCandidato
		return recibo
	end

	function api.solicitarMovimento(player, pedido)
		if player == nil or type(pedido) ~= "table"
			or not idValido(pedido.encounterId) or not idValido(pedido.requestId)
			or type(pedido.expectedVersion) ~= "number" or pedido.expectedVersion % 1 ~= 0
			or type(pedido.x) ~= "number" or pedido.x % 1 ~= 0
			or type(pedido.z) ~= "number" or pedido.z % 1 ~= 0
		then
			enviarRecusa(player, nil, "Pedido de movimento inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId"
				and chave ~= "expectedVersion" and chave ~= "x" and chave ~= "z"
			then
				enviarRecusa(player, nil, "O pedido de movimento contém campos não permitidos.")
				return false
			end
		end
		local alvoId = "casa:" .. tostring(pedido.x) .. ":" .. tostring(pedido.z)

		local anterior = ultimosPedidos[player.UserId]
		local repeticaoExata = anterior and anterior.encounterId == pedido.encounterId
			and anterior.requestId == pedido.requestId and anterior.expectedVersion == pedido.expectedVersion
			and anterior.command == "move" and anterior.targetId == alvoId
		if anterior and not repeticaoExata and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontros[pedido.encounterId], "Aguarde um instante antes de repetir.")
			return false
		end
		ultimosPedidos[player.UserId] = {
			encounterId = pedido.encounterId, requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion, command = "move", targetId = alvoId, at = agora(),
		}
		local encontro = encontros[pedido.encounterId]
		if not encontro then enviarRecusa(player, nil, "Encontro indisponível."); return false end
		local actorId = encontro.atoresPorJogador[player.UserId]
		if not actorId then enviarRecusa(player, encontro, "Você não participa deste encontro."); return false end
		local recibo, erro = resolverMovimento(encontro, actorId, pedido.expectedVersion, pedido.requestId, pedido.x, pedido.z)
		if not recibo then enviarRecusa(player, encontro, erro); return false end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return true, recibo
	end

	function api.atacarBasicoInterno(encounterId, actorId, expectedVersion, requestId, targetId)
		local encontro = encontros[encounterId]
		if not encontro or not idValido(actorId) or not idValido(requestId) or not idValido(targetId)
			or type(expectedVersion) ~= "number" or expectedVersion % 1 ~= 0
		then
			return nil, "Pedido de ataque inválido."
		end
		local recibo, erro = resolverAtaqueBasico(encontro, actorId, expectedVersion, requestId, targetId)
		if not recibo then return nil, erro end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return recibo
	end

	function api.solicitarAtaqueBasico(player, pedido)
		if player == nil or type(pedido) ~= "table"
			or not idValido(pedido.encounterId) or not idValido(pedido.requestId)
			or not idValido(pedido.targetId)
			or type(pedido.expectedVersion) ~= "number" or pedido.expectedVersion % 1 ~= 0
		then
			enviarRecusa(player, nil, "Pedido de ataque inválido.")
			return false
		end
		local anterior = ultimosPedidos[player.UserId]
		local repeticaoExata = anterior
			and anterior.encounterId == pedido.encounterId
			and anterior.requestId == pedido.requestId
			and anterior.expectedVersion == pedido.expectedVersion
			and anterior.command == "basic-attack"
			and anterior.targetId == pedido.targetId
		if anterior and not repeticaoExata and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontros[pedido.encounterId], "Aguarde um instante antes de repetir.")
			return false
		end
		ultimosPedidos[player.UserId] = {
			encounterId = pedido.encounterId, requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion, command = "basic-attack",
			targetId = pedido.targetId, at = agora(),
		}
		local encontro = encontros[pedido.encounterId]
		if not encontro then enviarRecusa(player, nil, "Encontro indisponível."); return false end
		local actorId = encontro.atoresPorJogador[player.UserId]
		if not actorId then enviarRecusa(player, encontro, "Você não participa deste encontro."); return false end
		local recibo, erro = resolverAtaqueBasico(encontro, actorId, pedido.expectedVersion, pedido.requestId, pedido.targetId)
		if not recibo then enviarRecusa(player, encontro, erro); return false end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return true, recibo
	end

	function api.solicitarDisparo(player, pedido)
		if player == nil or type(pedido) ~= "table" or pedido.command ~= "ranged-attack"
			or not idValido(pedido.encounterId) or not idValido(pedido.requestId) or not idValido(pedido.targetId)
			or type(pedido.expectedVersion) ~= "number" or pedido.expectedVersion % 1 ~= 0
		then
			enviarRecusa(player, nil, "Pedido de disparo inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId"
				and chave ~= "targetId" and chave ~= "expectedVersion"
			then
				enviarRecusa(player, nil, "O pedido de disparo contém campos não permitidos.")
				return false
			end
		end
		local anterior = ultimosPedidos[player.UserId]
		local repeticaoExata = anterior and anterior.encounterId == pedido.encounterId
			and anterior.requestId == pedido.requestId and anterior.expectedVersion == pedido.expectedVersion
			and anterior.command == "ranged-attack" and anterior.targetId == pedido.targetId
		if anterior and not repeticaoExata and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontros[pedido.encounterId], "Aguarde um instante antes de repetir.")
			return false
		end
		ultimosPedidos[player.UserId] = {
			encounterId = pedido.encounterId, requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion, command = "ranged-attack", targetId = pedido.targetId, at = agora(),
		}
		local encontro = encontros[pedido.encounterId]
		if not encontro then enviarRecusa(player, nil, "Encontro indisponível."); return false end
		local actorId = encontro.atoresPorJogador[player.UserId]
		if not actorId then enviarRecusa(player, encontro, "Você não participa deste encontro."); return false end
		local recibo, erro = resolverDisparo(encontro, actorId, pedido.expectedVersion, pedido.requestId, pedido.targetId)
		if not recibo then enviarRecusa(player, encontro, erro); return false end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return true, recibo
	end

	function api.solicitarHabilidade(player, pedido)
		if player == nil or type(pedido) ~= "table"
			or pedido.command ~= "use-ability"
			or not idValido(pedido.encounterId) or not idValido(pedido.requestId)
			or not idValido(pedido.abilityId) or not idValido(pedido.targetId)
			or type(pedido.expectedVersion) ~= "number" or pedido.expectedVersion % 1 ~= 0
		then
			enviarRecusa(player, nil, "Pedido de habilidade inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId"
				and chave ~= "abilityId" and chave ~= "targetId" and chave ~= "expectedVersion"
			then
				enviarRecusa(player, nil, "O pedido de habilidade contém campos não permitidos.")
				return false
			end
		end
		local anterior = ultimosPedidos[player.UserId]
		local repeticaoExata = anterior
			and anterior.encounterId == pedido.encounterId
			and anterior.requestId == pedido.requestId
			and anterior.expectedVersion == pedido.expectedVersion
			and anterior.command == "use-ability"
			and anterior.abilityId == pedido.abilityId
			and anterior.targetId == pedido.targetId
		if anterior and not repeticaoExata and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontros[pedido.encounterId], "Aguarde um instante antes de repetir.")
			return false
		end
		ultimosPedidos[player.UserId] = {
			encounterId = pedido.encounterId, requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion, command = "use-ability",
			abilityId = pedido.abilityId, targetId = pedido.targetId, at = agora(),
		}
		local encontro = encontros[pedido.encounterId]
		if not encontro then enviarRecusa(player, nil, "Encontro indisponível."); return false end
		local actorId = encontro.atoresPorJogador[player.UserId]
		if not actorId then enviarRecusa(player, encontro, "Você não participa deste encontro."); return false end
		local recibo, erro = resolverHabilidade(
			encontro, actorId, pedido.expectedVersion, pedido.requestId, pedido.abilityId, pedido.targetId
		)
		if not recibo then enviarRecusa(player, encontro, erro); return false end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return true, recibo
	end

	function api.solicitarItem(player, pedido)
		if player == nil or type(pedido) ~= "table" or pedido.command ~= "use-item"
			or not idValido(pedido.encounterId) or not idValido(pedido.requestId)
			or not idValido(pedido.itemId) or not idValido(pedido.targetId)
			or type(pedido.expectedVersion) ~= "number" or pedido.expectedVersion % 1 ~= 0
		then
			enviarRecusa(player, nil, "Pedido de item inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId"
				and chave ~= "itemId" and chave ~= "targetId" and chave ~= "expectedVersion"
			then
				enviarRecusa(player, nil, "O pedido de item contém campos não permitidos.")
				return false
			end
		end
		local anterior = ultimosPedidos[player.UserId]
		local repeticaoExata = anterior and anterior.encounterId == pedido.encounterId
			and anterior.requestId == pedido.requestId and anterior.expectedVersion == pedido.expectedVersion
			and anterior.command == "use-item" and anterior.itemId == pedido.itemId and anterior.targetId == pedido.targetId
		if anterior and not repeticaoExata and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontros[pedido.encounterId], "Aguarde um instante antes de repetir.")
			return false
		end
		ultimosPedidos[player.UserId] = {
			encounterId = pedido.encounterId, requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion, command = "use-item",
			itemId = pedido.itemId, targetId = pedido.targetId, at = agora(),
		}
		local encontro = encontros[pedido.encounterId]
		if not encontro then enviarRecusa(player, nil, "Encontro indisponível."); return false end
		local actorId = encontro.atoresPorJogador[player.UserId]
		if not actorId then enviarRecusa(player, encontro, "Você não participa deste encontro."); return false end
		local recibo, erro = resolverItem(
			encontro, actorId, pedido.expectedVersion, pedido.requestId, pedido.itemId, pedido.targetId
		)
		if not recibo then enviarRecusa(player, encontro, erro); return false end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return true, recibo
	end

	-- R2c: transação servidor; a regra pura recebe só números da ficha/catálogo.
	function api.solicitarFuga(player, pedido)
		if player == nil or type(player.UserId) ~= "number" or not jogadorConectado(player)
			or localizarJogador(player.UserId) ~= player or type(pedido) ~= "table"
			or pedido.command ~= "flee-encounter" or not idValido(pedido.encounterId)
			or not idValido(pedido.requestId) or type(pedido.expectedVersion) ~= "number"
			or pedido.expectedVersion % 1 ~= 0 then
			enviarRecusa(player, nil, "Pedido de fuga inválido."); return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId" and chave ~= "expectedVersion" then
				enviarRecusa(player, nil, "O pedido de fuga contém campos não permitidos."); return false
			end
		end
		local encontro = encontros[pedido.encounterId]
		if not encontro then enviarRecusa(player, nil, "Encontro indisponível."); return false end
		local actorId = encontro.atoresPorJogador[player.UserId]
		local ator = actorId and encontro.atoresPorId[actorId]
		if not ator then enviarRecusa(player, encontro, "Você não participa deste encontro."); return false end
		if encontro.desistenciasAplicadas[pedido.requestId] then
			enviarRecusa(player, encontro, "ID de pedido já usado com outro conteúdo."); return false
		end
		local aplicada = encontro.fugasAplicadas[pedido.requestId]
		if aplicada then
			if aplicada.userId ~= player.UserId or aplicada.expectedVersion ~= pedido.expectedVersion then
				enviarRecusa(player, encontro, "ID de pedido já usado com outro conteúdo."); return false
			end
			-- Replay privado: confirma sem repetir a emissóo ao grupo ou rolar novamente.
			emitir(player, "recibo", copiar(aplicada.receipt))
			if not encontro.retornaram[player.UserId] then emitir(player, "estado", estadoPara(encontro, player.UserId)) end
			return true, copiar(aplicada.receipt)
		end
		local anterior = ultimosPedidos[player.UserId]
		if anterior and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontro, "Aguarde um instante antes de repetir."); return false
		end
		if ator.fled or encontro.estado.phase ~= "active" or type(ator.pv) ~= "number"
			or ator.pv <= 0 or ator.defeated == true then
			enviarRecusa(player, encontro, "Você não pode fugir deste encontro agora."); return false
		end
		-- PLANO §12: a intenção só vale na borda tática confirmada pelo servidor.
		if type(ator.x) ~= "number" or type(ator.z) ~= "number"
			or (ator.x ~= 1 and ator.x ~= 20 and ator.z ~= 1 and ator.z ~= 20) then
			enviarRecusa(player, encontro, "Chegue à borda da grade para fugir."); return false
		end
		local calculado = ator.ficha and ator.ficha.calculated
		local bonus
		for _, pericia in calculado and calculado.skills or {} do
			local entrada = catalogo.POR_ID[pericia.skillId]
			if entrada and entrada.kind == "skill" and entrada.data.name == "Atletismo" then bonus = pericia.bonus; break end
		end
		-- Fichas antigas sem lista: Força é o valor base de Atletismo (sem treino).
		if bonus == nil then bonus = calculado and calculado.attributes and calculado.attributes.forca end
		local deslocamento = ator.movementMeters or (calculado and calculado.movementMeters)
		local perseguidores = {}
		for _, id in encontro.estado.order do
			local criatura = encontro.atoresPorId[id]
			if criatura.kind == "criatura" and (criatura.pv or 0) > 0 and not criatura.defeated then
				local entrada = criatura.fichaCriatura and catalogo.POR_ID[criatura.fichaCriatura.catalogId]
				local metros = entrada and entrada.kind == "creature" and entrada.data.deslocamento
				if type(metros) ~= "number" or metros ~= metros or metros < 0 or metros == math.huge then
					enviarRecusa(player, encontro, "Deslocamento canônico da criatura indisponível."); return false
				end
				table.insert(perseguidores, metros)
			end
		end
		if type(bonus) ~= "number" or bonus % 1 ~= 0 or bonus < -50 or bonus > 50
			or type(deslocamento) ~= "number" or deslocamento ~= deslocamento or deslocamento < 0 or deslocamento > 30
			or #perseguidores == 0 then
			enviarRecusa(player, encontro, "Ficha ou perseguidores indisponíveis para fuga."); return false
		end
		local candidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId, expectedVersion = pedido.expectedVersion,
			requestId = pedido.requestId, action = "flee-encounter",
		})
		if not candidato or erro == "Pedido já aplicado." then
			enviarRecusa(player, encontro, erro or "Pedido de fuga indisponível."); return false
		end
		local resultado = RegrasPatrulha.fuga(rng, bonus, deslocamento, perseguidores)
		if not resultado then enviarRecusa(player, encontro, "Não foi possível testar a fuga."); return false end
		resultado.defectMovement = copiar(ator.defectMovement)
		ultimosPedidos[player.UserId] = { encounterId = pedido.encounterId, requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion, command = "flee-encounter", at = agora() }
		encontro.estado = candidato
		if not resultado.fugiu then
			-- Reutiliza todos os efeitos e a restauração da ordem de surpresa do fim normal.
			local fim = aplicarFim(encontro, actorId, candidato.version, "fuga-fim:" .. tostring(candidato.version))
			recibo.version, recibo.turn, recibo.nextActorId = fim.version, fim.turn, fim.nextActorId
			resultado.turnEnd = fim.result
			resultado.joinedActors = fim.result and fim.result.joinedActors
		else
			-- Avança a vez antes de retirar o ator para executar efeitos de início uma vez.
			ator.fled = true
			local ficouVivo = false
			for _, id in encontro.estado.order do
				local outro = encontro.atoresPorId[id]
				if outro.kind == "jogador" and not outro.fled and (outro.pv or 0) > 0 and not outro.defeated then ficouVivo = true end
			end
			if ficouVivo then
				local fim = aplicarFim(encontro, actorId, candidato.version, "fuga-fim:" .. tostring(candidato.version))
				recibo.version, recibo.turn, recibo.nextActorId = fim.version, fim.turn, fim.nextActorId
				resultado.turnEnd = fim.result
				resultado.joinedActors = fim.result and fim.result.joinedActors
				-- Uma admissão na troca de rodada já filtra os fugitivos ao
				-- ordenar RB-13; sem admissão ainda é preciso retirar este ator.
				if table.find(encontro.estado.order, actorId) then
					encontro.estado = Turnos.removerDerrotado(encontro.estado, actorId)
				end
			else
				encontro.estado = Turnos.removerDerrotado(encontro.estado, actorId)
				encontro.estado.phase = "fled"
				resultado.encounterEnded = "fled"
			end
			-- Nenhuma projeção da ficha que saiu continua ancorada. A API existente
			-- restaura o conjunto; enviarEstado reprojeta só quem permanece na luta.
			if avatares and type(avatares.limpar) == "function" then avatares.limpar(pedido.encounterId) end
			soltarVinculoMao(encontro, actorId)
			for id, vinculo in pairs(encontro.vinculosMao) do
				if vinculo.sourceId == actorId then soltarVinculoMao(encontro, id) end
			end
		end
		ator.fleeResult = copiar(resultado)
		atualizarPrazoSemJogadores(pedido.encounterId, encontro)
		recibo.action, recibo.result = "flee-encounter", resultado
		recibo.actionsSpent = 1
		encontro.fugasAplicadas[pedido.requestId] = { userId = player.UserId,
			expectedVersion = pedido.expectedVersion, receipt = copiar(recibo) }
		table.insert(encontro.ordemFugasAplicadas, pedido.requestId)
		if #encontro.ordemFugasAplicadas > 128 then
			encontro.fugasAplicadas[table.remove(encontro.ordemFugasAplicadas, 1)] = nil
		end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		if executarIA then executarIA(pedido.encounterId) end
		enviarEstado(encontro)
		return true, copiar(recibo)
	end

	function api.solicitarDesistencia(player, pedido)
		if player == nil or type(player.UserId) ~= "number" or not jogadorConectado(player)
			or type(pedido) ~= "table" or pedido.command ~= "abandon-encounter"
			or not idValido(pedido.encounterId) or not idValido(pedido.requestId)
			or type(pedido.expectedVersion) ~= "number" or pedido.expectedVersion % 1 ~= 0
		then
			enviarRecusa(player, nil, "Pedido de desistência inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId" and chave ~= "expectedVersion" then
				enviarRecusa(player, nil, "O pedido de desistência contém campos não permitidos.")
				return false
			end
		end
		local encontro = encontros[pedido.encounterId]
		if not encontro then enviarRecusa(player, nil, "Encontro indisponível."); return false end
		local actorId = encontro.atoresPorJogador[player.UserId]
		local ator = actorId and encontro.atoresPorId[actorId]
		if not ator then enviarRecusa(player, encontro, "Você não participa deste encontro."); return false end
		if encontro.fugasAplicadas[pedido.requestId] then
			enviarRecusa(player, encontro, "ID de pedido já usado com outro conteúdo."); return false
		end
		local desistenciaAnterior = encontro.desistenciasAplicadas[pedido.requestId]
		if desistenciaAnterior then
			if desistenciaAnterior.userId ~= player.UserId
				or desistenciaAnterior.expectedVersion ~= pedido.expectedVersion
			then
				enviarRecusa(player, encontro, "ID de pedido já usado com outro conteúdo.")
				return false
			end
			emitirAosParticipantes(encontro, "recibo", desistenciaAnterior.receipt)
			enviarEstado(encontro)
			return true, table.clone(desistenciaAnterior.receipt)
		end
		local anterior = ultimosPedidos[player.UserId]
		local repeticaoExata = anterior and anterior.encounterId == pedido.encounterId
			and anterior.requestId == pedido.requestId and anterior.expectedVersion == pedido.expectedVersion
			and anterior.command == "abandon-encounter"
		if anterior and not repeticaoExata and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontro, "Aguarde um instante antes de repetir.")
			return false
		end
		api.observarEntradasPatrulha()
		local estadoCandidato, recibo, erro = Turnos.desistir(encontro.estado, {
			actorId = actorId,
			expectedVersion = pedido.expectedVersion,
			requestId = pedido.requestId,
		})
		if not estadoCandidato then enviarRecusa(player, encontro, erro); return false end
		if erro ~= "Pedido já aplicado."
			and (encontro.estado.phase ~= "active" or type(ator.pv) ~= "number" or ator.pv <= 0
				or ator.defeated == true)
		then
			enviarRecusa(player, encontro, "Você não pode desistir deste encontro agora.")
			return false
		end
		ultimosPedidos[player.UserId] = {
			encounterId = pedido.encounterId, requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion, command = "abandon-encounter", at = agora(),
		}
		if erro ~= "Pedido já aplicado." then
			ator.pv, ator.downed, ator.defeated = 0, true, true
			local sessao = ator.ficha and ator.ficha.session
			if type(sessao) == "table" and type(sessao.current) == "table" then
				sessao.current.pv = 0
			end
			local phaseBefore = estadoCandidato.phase
			estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
			if estadoCandidato.phase ~= phaseBefore then
				recibo.result = { encounterEnded = estadoCandidato.phase }
			end
			admitirEntradas(encontro, estadoCandidato, recibo)
			encontro.estado = estadoCandidato
		end
		encontro.desistenciasAplicadas[pedido.requestId] = {
			userId = player.UserId,
			expectedVersion = pedido.expectedVersion,
			receipt = table.clone(recibo),
		}
		table.insert(encontro.ordemDesistenciasAplicadas, pedido.requestId)
		if #encontro.ordemDesistenciasAplicadas > 128 then
			local removido = table.remove(encontro.ordemDesistenciasAplicadas, 1)
			encontro.desistenciasAplicadas[removido] = nil
		end
		emitirAosParticipantes(encontro, "recibo", recibo)
		if erro ~= "Pedido já aplicado." and executarIA then executarIA(pedido.encounterId) end
		enviarEstado(encontro)
		return true, recibo
	end

	function api.solicitarFimTurno(player, pedido)
		if player == nil or type(pedido) ~= "table"
			or not idValido(pedido.encounterId)
			or not idValido(pedido.requestId)
			or type(pedido.expectedVersion) ~= "number"
			or pedido.expectedVersion % 1 ~= 0
		then
			enviarRecusa(player, nil, "Pedido de turno inválido.")
			return false
		end

		if pedido.command ~= nil and pedido.command ~= "end-turn" then
			enviarRecusa(player, nil, "Comando de turno inválido.")
			return false
		end
		for chave in pedido do
			if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId" and chave ~= "expectedVersion" and chave ~= "actorId" then
				enviarRecusa(player, nil, "O pedido de turno contém campos não permitidos.")
				return false
			end
		end
		local anterior = ultimosPedidos[player.UserId]
		local repeticaoExata = anterior
			and anterior.encounterId == pedido.encounterId
			and anterior.requestId == pedido.requestId
			and anterior.expectedVersion == pedido.expectedVersion
			and anterior.command == "end-turn"
		if anterior and not repeticaoExata and agora() - anterior.at < INTERVALO_PEDIDO then
			enviarRecusa(player, encontros[pedido.encounterId], "Aguarde um instante antes de repetir.")
			return false
		end
		ultimosPedidos[player.UserId] = {
			encounterId = pedido.encounterId,
			requestId = pedido.requestId,
			expectedVersion = pedido.expectedVersion,
			command = "end-turn",
			at = agora(),
		}
		local encontro = encontros[pedido.encounterId]
		if not encontro then
			enviarRecusa(player, nil, "Encontro indisponível.")
			return false
		end
		local atorId = encontro.atoresPorJogador[player.UserId]
		if not atorId then
			enviarRecusa(player, encontro, "Você não participa deste encontro.")
			return false
		end
		local recibo, erro = aplicarFim(encontro, atorId, pedido.expectedVersion, pedido.requestId)
		if not recibo then
			enviarRecusa(player, encontro, erro)
			return false
		end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		if executarIA then executarIA(pedido.encounterId) end
		return true, recibo
	end

	-- Para IA/controlador de servidor; não existe rota remota para este método.
	function api.encerrarTurnoInterno(encounterId, actorId, expectedVersion, requestId)
		local encontro = encontros[encounterId]
		if not encontro or not idValido(actorId) or encontro.jogadorPorAtor[actorId] ~= nil then
			return nil, "Ator interno inválido."
		end
		local recibo, erro = aplicarFim(encontro, actorId, expectedVersion, requestId)
		if not recibo then return nil, erro end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return recibo
	end

	local function resolverAtaqueCriatura(encontro, actorId, requestId)
		local atacante = encontro.atoresPorId[actorId]
		local candidatos = {}
		for _, alvoId in ipairs(encontro.ordemInicial) do
			local alvo = encontro.atoresPorId[alvoId]
			if alvo.kind == "jogador" and not alvo.fled and type(alvo.pv) == "number" and alvo.pv > 0
				and type(alvo.x) == "number" and type(alvo.z) == "number"
				and math.max(math.abs(atacante.x - alvo.x), math.abs(atacante.z - alvo.z)) == 1
				and not bloqueadoPorObstaculoVisual(encontro, atacante.x, atacante.z, alvo.x, alvo.z)
			then
				table.insert(candidatos, alvo)
			end
		end
		table.sort(candidatos, function(a, b)
			local da = math.max(math.abs(atacante.x - a.x), math.abs(atacante.z - a.z))
			local db = math.max(math.abs(atacante.x - b.x), math.abs(atacante.z - b.z))
			if da ~= db then return da < db end
			if a.pv ~= b.pv then return a.pv < b.pv end
			return a.id < b.id
		end)
		local alvo = candidatos[1]
		if not alvo then return nil, "Nenhum personagem vivo está adjacente." end
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId,
			expectedVersion = encontro.estado.version,
			requestId = requestId,
			action = "creature-attack",
			targetId = alvo.id,
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local cobertura = TerrenoAutonomo.coberturaNaLinha(atacante.x, atacante.z, alvo.x, alvo.z,
			encontro.dangers, encontro.estado.turn)
		local alvoComCobertura = alvo
		if cobertura > 0 then
			alvoComCobertura = table.clone(alvo)
			alvoComCobertura.ca = (alvo.ca or 0) + cobertura
		end
		local atorAtacante = paraResolucao(encontro, atacante)
		local atorAlvo = paraResolucao(encontro, alvoComCobertura)
		local resultado, falha = CombateAutonomo.atacarCriatura(rng, atorAtacante, atorAlvo, catalogo)
		if not resultado then return nil, falha end
		if cobertura > 0 then resultado.coverageBonus = cobertura end
		local defesa = alvo.defenderReduction
		if resultado.attack.acertou and type(defesa) == "number" and defesa > 0 and resultado.damageDealt > 0 then
			local reduzido = math.min(defesa, resultado.damageDealt)
			resultado.damageDealt -= reduzido
			resultado.targetPv = math.max(0, alvo.pv - resultado.damageDealt)
			resultado.targetDowned = resultado.targetPv <= 0
			resultado.defenderReductionApplied = reduzido
		end
		if not ajustarResultadoPorPvTemporarios(alvo, resultado, encontro.estado.turn) then
			return nil, "Não foi possível aplicar a defesa de PV temporários."
		end
		recibo.result = resultado
		estadoCandidato.lastAction.receipt = recibo
		registrarDano(encontro, alvo, resultado.damageDealt)
		alvo.downed = resultado.targetDowned
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		encontro.estado = estadoCandidato
		return recibo
	end

	local function resolverMovimentoCriatura(encontro, actorId, requestId)
		local atacante = encontro.atoresPorId[actorId]
		if not atacante or atacante.kind ~= "criatura" then return nil, "Ator de IA inválido." end
		local alvos, ocupantes = {}, {}
		-- A fila ativa já exclui criaturas derrotadas; corpos removidos não bloqueiam a grade.
		for _, alvoId in ipairs(encontro.estado.order) do
			local alvo = encontro.atoresPorId[alvoId]
			if alvo then
				table.insert(ocupantes, alvo)
				if alvo.kind == "jogador" and not alvo.fled and type(alvo.pv) == "number" and alvo.pv > 0 then
					table.insert(alvos, alvo)
				end
			end
		end
		local destino, falha = MovimentoAutonomo.aproximar(
			atacante.x, atacante.z, ocupantes, alvos,
			math.max(0, (atacante.movementCasas or 0)
				- (((atacante.estadosDeCombate or {}).reduzMovimento or {}).valor or 0)),
			celulasBloqueadasAtivas(encontro), TerrenoAutonomo.chavesDe(celulasDificeisAtivas(encontro))
		)
		if not destino then return nil, falha end
		local estadoCandidato, recibo, erro = Turnos.consumirAcao(encontro.estado, {
			actorId = actorId,
			expectedVersion = encontro.estado.version,
			requestId = requestId,
			action = "creature-move",
		})
		if not estadoCandidato then return nil, erro end
		if erro == "Pedido já aplicado." then return recibo end
		local origem = { x = atacante.x, z = atacante.z }
		local casaFinal, zonasAcionadas, casasPercorridas = percorrerZonas(encontro, atacante, destino.rota)
		recibo.result = {
			actorId = actorId,
			action = "creature-move",
			from = origem,
			to = { x = casaFinal.x, z = casaFinal.z },
			houses = casasPercorridas,
			movementCost = destino.custoMovimento or casasPercorridas,
			hazardsTriggered = zonasAcionadas,
		}
		estadoCandidato.lastAction.receipt = recibo
		if atacante.defeated then
			local semAtor, erroRemocao = Turnos.removerDerrotado(estadoCandidato, actorId)
			if not semAtor then return nil, erroRemocao end
			estadoCandidato = semAtor
		end
		estadoCandidato = avaliarTerminal(encontro, estadoCandidato)
		encontro.estado = estadoCandidato
		return recibo
	end

	function api.ataqueCriaturaInterno(encounterId, actorId, requestId)
		local encontro = encontros[encounterId]
		if not encontro or not idValido(actorId) or not idValido(requestId)
			or encontro.jogadorPorAtor[actorId] ~= nil
		then
			return nil, "Ator de IA inválido."
		end
		local recibo, erro = resolverAtaqueCriatura(encontro, actorId, requestId)
		if not recibo then return nil, erro end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return recibo
	end

	function api.moverCriaturaInterno(encounterId, actorId, requestId)
		local encontro = encontros[encounterId]
		if not encontro or not idValido(actorId) or not idValido(requestId)
			or encontro.jogadorPorAtor[actorId] ~= nil
			or encontro.estado.order[encontro.estado.currentIndex] ~= actorId
		then
			return nil, "Ator de IA inválido ou fora da vez."
		end
		local recibo, erro = resolverMovimentoCriatura(encontro, actorId, requestId)
		if not recibo then return nil, erro end
		emitirAosParticipantes(encontro, "recibo", recibo)
		enviarEstado(encontro)
		return recibo
	end

	executarIA = function(encounterId)
		local encontro = encontros[encounterId]
		if not encontro then return end
		for _ = 1, 16 do
			if encontro.estado.phase ~= "active" then return end
			if grupoDerrotado(encontro) then
				encontro.estado = avaliarTerminal(encontro, encontro.estado)
				enviarEstado(encontro)
				return
			end
			local actorId = encontro.estado.order[encontro.estado.currentIndex]
			local ator = encontro.atoresPorId[actorId]
			if ator and ator.fled then continue end
			if not ator or ator.kind ~= "criatura" then return end
			if encontro.vinculosMao[actorId] and encontro.estado.actionsRemaining > 0 then
				local escapeId = "ia-escape:" .. string.sub(encounterId, 1, 24) .. ":" .. tostring(encontro.estado.version)
				local reciboEscape = resolverControleMao(encontro, actorId, encontro.estado.version, escapeId, ESCAPAR_MAO)
				if reciboEscape then
					emitirAosParticipantes(encontro, "recibo", reciboEscape)
					enviarEstado(encontro)
				end
			end
			if encontro.estado.phase ~= "active" or encontro.estado.order[encontro.estado.currentIndex] ~= actorId then return end
			local requestId = "ia:" .. string.sub(encounterId, 1, 32) .. ":" .. tostring(encontro.estado.version)
			local recibo = api.ataqueCriaturaInterno(encounterId, actorId, requestId)
			if not recibo then
				if encontro.estado.phase ~= "active" then return end
				local movimentoId = "ia-move:" .. string.sub(encounterId, 1, 28) .. ":" .. tostring(encontro.estado.version)
				api.moverCriaturaInterno(encounterId, actorId, movimentoId)
				if encontro.estado.phase ~= "active" or encontro.estado.order[encontro.estado.currentIndex] ~= actorId then return end
				local ataqueId = "ia-apos-mover:" .. string.sub(encounterId, 1, 24) .. ":" .. tostring(encontro.estado.version)
				api.ataqueCriaturaInterno(encounterId, actorId, ataqueId)
			end
			if encontro.estado.phase ~= "active" then return end
			if encontro.estado.order[encontro.estado.currentIndex] ~= actorId then return end
			local turnoId = encontro.estado.version
			local fimId = "ia-fim:" .. string.sub(encounterId, 1, 30) .. ":" .. tostring(turnoId)
			local _, erro = api.encerrarTurnoInterno(encounterId, actorId, turnoId, fimId)
			if erro then return end
		end
	end


 -- Somente callback servidor da patrulha registrada; nao e comando remoto.
 -- O contato inicia o encontro; novas identidades entram só na rodada seguinte.
 -- 17/10: o ponto de contato pode ter obstáculo/ladeira nas casas iniciais ("Sem espaco seguro"): a patrulha
 -- perseguia para sempre sem lutar. Tenta o ponto do contato e, se faltar espaço, centros vizinhos.
 -- Estrada da região inicial (x=0): casas iniciais sempre livres, medido em Play de 17/10 para z de -60 a -140.
 local CENTROS_ESTRADA_Z = { -70, -80, -100, -110, -120, -130 }
 local DESLOCAMENTOS_ARENA = {
  Vector3.zero, Vector3.new(7, 0, 0), Vector3.new(-7, 0, 0), Vector3.new(0, 0, 7), Vector3.new(0, 0, -7),
  Vector3.new(12, 0, 0), Vector3.new(-12, 0, 0), Vector3.new(0, 0, 12), Vector3.new(0, 0, -12),
  Vector3.new(9, 0, 9), Vector3.new(-9, 0, 9), Vector3.new(9, 0, -9), Vector3.new(-9, 0, -9),
 }
 function api.iniciarPorPatrulha(player, origem)
  local patrulha = origem
  if not patrulhas[patrulha] or patrulha.alvo() ~= player
   or inicioPatrulhaEmCurso or next(encontros) ~= nil then return false end
  local tempo = agora()
  if tempo - ultimaTentativaPatrulha < INTERVALO_INICIO then return false end
  ultimaTentativaPatrulha = tempo
  local function elegivel()
   if not player or not jogadorConectado(player) or localizarJogador(player.UserId) ~= player
    or combateLegadoAtivo(player) or posicaoNaFila[player.UserId] then return false end
   local char = player.Character
   local root = char and char:FindFirstChild("HumanoidRootPart")
   local hum = char and char:FindFirstChildOfClass("Humanoid")
   return root and root:IsA("BasePart") and hum and hum.Health > 0
    and patrulha.corpo:IsDescendantOf(workspaceAtual)
    and (root.Position - patrulha.corpo.Position).Magnitude <= 5
    and patrulha.visivel(player)
  end
  if not elegivel() then return false end
  -- Modo História (PLANO §13): a luta vai para a arena regional da mesa; o J2 no terreno só sem a ponte.
  if deps.lutaNaArena then
   local definicao = patrulhas[patrulha]
   if type(definicao) ~= "table" then
    definicao = { nome = "Patrulha", marco = definicao,
     zona = if definicao == "region/encounter/ruinas" then "region/ruinas-do-vale" else "region/clareira-inicial" }
   end
   inicioPatrulhaEmCurso = true
   local okArena, comecou = pcall(deps.lutaNaArena, player, patrulha, definicao)
   inicioPatrulhaEmCurso = nil
   if not okArena then warn("[Patrulha] Arena recusada: " .. tostring(comecou)) end
   return okArena and comecou == true
  end
  inicioPatrulhaEmCurso = true
  local contato = patrulha.contextoContato and patrulha.contextoContato(player)
  local arena
  local ok, encounterId = pcall(function()
   local ignorar = { patrulha.modelo }
   for _, p in ipairs((deps.jogadoresPatrulha or function() return Players:GetPlayers() end)()) do
    if p.Character then table.insert(ignorar, p.Character) end
   end
   local function tentarEm(posicao)
   arena = require(script.Parent.RegiaoInicial).criarArenaPatrulha(workspaceAtual, posicao, ignorar)
   arena.patrulha = patrulha
   local definicao = patrulhas[patrulha]
   arena.marcoRecompensa = if type(definicao) == "table" then definicao.marco else definicao
   arena.patrulhaId = if type(definicao) == "table" then definicao.id else nil
   if not elegivel() or next(encontros) ~= nil then return nil end
   local grupo = { player }
   local contexto = { arenaPatrulha = arena }
   local proximos = table.clone((deps.jogadoresPatrulha or function() return Players:GetPlayers() end)())
   table.sort(proximos, function(a, b) return a.UserId < b.UserId end)
   for _, outro in ipairs(proximos) do
    if #grupo >= 4 then break end
    if outro == player then continue end
    local casa = posicaoElegivel(outro, contexto)
    if casa and RegrasPatrulha.situacaoNaGrade(casa.distanciaMetros, 15,
     GradeTatica.RAIO_ENTRADA_METROS) == "dentro" and montarEntrada(outro) then
     table.insert(grupo, outro)
    end
   end
   arena.validarInicio = function()
    if not elegivel() then return false end
    for _, outro in ipairs(grupo) do
     if outro == player then continue end
     local casa = posicaoElegivel(outro, contexto)
     if not casa or casa.distanciaMetros > GradeTatica.RAIO_ENTRADA_METROS then return false end
    end
    return true
   end
   arena.surpreendente = if contato then RegrasPatrulha.surpresa(
    contato.visto, contato.iniciouPeloJogador, false, false) else nil
   -- Uma silhueta representa a patrulha: nas Ruinas, ameaca baixa (0,5 por
   -- jogador) reutiliza o orcamento de goblins lacaios do catalogo da clareira.
   local criaturas = if arena.patrulhaId then EncontrosPorZona.elencoPatrulha(arena.patrulhaId, #grupo)
    elseif arena.marcoRecompensa == "region/encounter/ruinas"
    then EncontrosPorZona.elegivel("region/encounter/clearing", #grupo).elenco
    else { "creature/goblin-batedor" }
   return api.criarParaGrupo(grupo, criaturas, arena.areaId, arena)
   end
   local base, motivo = patrulha.corpo.Position, nil
   local candidatos = {}
   for _, deslocamento in ipairs(DESLOCAMENTOS_ARENA) do table.insert(candidatos, base + deslocamento) end
   -- Campo inicial: fora da estrada o terreno/props bloqueiam tudo (goblin do campo: 399 de 400 casas).
   local extras = {}
   for _, z in ipairs(CENTROS_ESTRADA_Z) do
    local ponto = Vector3.new(0, base.Y, z)
    if (Vector3.new(ponto.X - base.X, 0, ponto.Z - base.Z)).Magnitude <= 60 then table.insert(extras, ponto) end
   end
   table.sort(extras, function(a, b) return (a - base).Magnitude < (b - base).Magnitude end)
   for _, ponto in ipairs(extras) do table.insert(candidatos, ponto) end
   for _, centro in ipairs(candidatos) do
    if arena then arena.pasta:Destroy(); arena = nil end
    local id, falha = tentarEm(centro)
    if id then return id end
    motivo = falha
    if falha ~= SEM_ESPACO then break end
   end
   return nil, motivo
  end)
  inicioPatrulhaEmCurso = nil
  if not ok or not encounterId then
   if arena then arena.pasta:Destroy() end
   if not ok then warn("[Patrulha] Inicio recusado: " .. tostring(encounterId)) end
   return false
  end
  return true, encounterId
 end

	if remote.OnServerEvent then
		remote.OnServerEvent:Connect(function(player, pedido)
			if type(pedido) == "table" and pedido.command == "reconnect-autonomous" then
				api.solicitarReconexao(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "start-autonomous" then
				api.solicitarInicio(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "return-autonomous" then
				api.solicitarRetorno(player, pedido)
			elseif type(pedido) == "table"
				and (pedido.command == "join-autonomous-queue" or pedido.command == "leave-autonomous-queue")
			then
				api.solicitarFila(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "move" then
				api.solicitarMovimento(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "basic-attack" then
				api.solicitarAtaqueBasico(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "ranged-attack" then
				api.solicitarDisparo(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "use-ability" then
				api.solicitarHabilidade(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "use-item" then
				api.solicitarItem(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "flee-encounter" then
				api.solicitarFuga(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "abandon-encounter" then
				api.solicitarDesistencia(player, pedido)
			elseif type(pedido) == "table" and pedido.command == "end-turn" then
				local camposPermitidos = true
				for chave in pedido do
					if chave ~= "command" and chave ~= "encounterId" and chave ~= "requestId" and chave ~= "expectedVersion" then
						camposPermitidos = false
						break
					end
				end
				if camposPermitidos then
					api.solicitarFimTurno(player, pedido)
				else
					enviarRecusa(player, nil, "O pedido de turno contém campos não permitidos.")
				end
			else
				enviarRecusa(player, nil, "Comando de encontro desconhecido.")
			end
		end)
	end
	for _, item in ipairs(workspaceAtual:GetDescendants()) do
		local areaId = item:GetAttribute("EncounterId")
		if item:IsA("BasePart") and item:GetAttribute("AreaRole") == "encounter-trigger"
			and idValido(areaId) and EncontrosPorZona.consultar(areaId) ~= nil
		then
			local promptEncontro = item:FindFirstChildWhichIsA("ProximityPrompt")
			if promptEncontro then
				promptEncontro.Triggered:Connect(function(player)
					api.solicitarInicio(player, {
						command = "start-world-encounter",
						requestId = novoId(),
						areaId = areaId,
					})
				end)
			end
		end
	end
	local heartbeatEntradas = deps.heartbeatEntradas or (if deps.remote == nil then game:GetService("RunService").Heartbeat else nil)
	if heartbeatEntradas then
		local ultimo, observando = -math.huge, false
		heartbeatEntradas:Connect(function()
			if observando or agora() - ultimo < 0.25 or next(encontros) == nil then return end
			ultimo, observando = agora(), true
			local ok, erro = pcall(api.observarEntradasPatrulha)
			observando = false
			if not ok then warn("[Patrulha] Entrada tardia: " .. tostring(erro)) end
		end)
	end

 if deps.remote == nil or deps.heartbeatPatrulha or deps.criarPatrulha or deps.criarPatrulhaRuinas then
  local config = {
   workspace = workspaceAtual, agora = agora, tempoMundo = function() return tempoMundo() end,
   reaparecerSegundos = EncontrosPorZona.REAPARECER_SEGUNDOS,
   jogadores = deps.jogadoresPatrulha or function() return Players:GetPlayers() end,
   ocupado = function() return next(encontros) ~= nil or inicioPatrulhaEmCurso == true
    or (deps.lutaNaArenaAtiva ~= nil and deps.lutaNaArenaAtiva() == true) end,
   elegivel = function(player)
    if not jogadorConectado(player) or combateLegadoAtivo(player) or posicaoNaFila[player.UserId] then return false end
    local ficha = corpoPessoal and corpoPessoal(player)
    local atuais = ficha and ficha.session and ficha.session.current
    return ficha ~= nil and (not atuais or not atuais.pv or atuais.pv > 0)
   end,
   encontrar = function(player, origem) return api.iniciarPorPatrulha(player, origem) end,
   heartbeat = deps.heartbeatPatrulha or game:GetService("RunService").Heartbeat,
  }
  if deps.remote == nil then
   local adapter = require(script.Parent.Mundo.PatrulhaVisivel)
   local pasta = Instance.new("Folder")
   pasta.Name, pasta.Parent = "Patrulhas do mundo", workspaceAtual
   for _, d in ipairs(EncontrosPorZona.patrulhas()) do
    local c = table.clone(config)
    c.regiao, c.nome, c.modelo, c.criatura = pasta, d.nome, d.modelo, d.criatura
    c.reaparecimento = function(derrotar)
     if cacadas then return cacadas.reaparecimento(d.id, derrotar) end
     return nil, nil
    end
    c.pontos = {Vector3.new(d.x-d.raio,1.5,d.z-d.raio),Vector3.new(d.x+d.raio,1.5,d.z-d.raio),
     Vector3.new(d.x+d.raio,1.5,d.z+d.raio),Vector3.new(d.x-d.raio,1.5,d.z+d.raio)}
    local nova = adapter.criar(c)
    if nova then patrulhas[nova] = d end
   end
  end
  local patrulha = (deps.criarPatrulha or require(script.Parent.RegiaoInicial).iniciarPatrulha)(config)
  if patrulha then patrulhas[patrulha] = "region/encounter/clearing" end
  -- Testes existentes podem substituir apenas a clareira; produ??o registra ambas.
  if not deps.criarPatrulha or deps.criarPatrulhaRuinas then
   local ruinas = (deps.criarPatrulhaRuinas or require(script.Parent.Mundo.Ruinas).iniciarPatrulha)(config)
   if ruinas then patrulhas[ruinas] = "region/encounter/ruinas" end
  end
 end
	if Players.PlayerRemoving and deps.localizarJogador == nil then
		Players.PlayerRemoving:Connect(function(player)
			if retirarDaFila(player.UserId) then emitirFila() end
			api.notificarDesconexao(player)
			ultimosPedidos[player.UserId] = nil
			ultimasReconexoes[player.UserId] = nil
			ultimosInicios[player.UserId] = nil
			ultimosRetornos[player.UserId] = nil
			ultimasMudancasFila[player.UserId] = nil
		end)
		Players.PlayerAdded:Connect(function(player)
			api.notificarConexao(player)
		end)
	end
	if deps.remote == nil and deps.localizarJogador == nil and deps.emitir == nil then
		instancia = api
	end
	return api
end

function EncontroAutonomoService.obter()
	return instancia
end

return EncontroAutonomoService
