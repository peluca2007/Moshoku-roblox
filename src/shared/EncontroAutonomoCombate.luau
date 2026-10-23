-- Primeiro recorte do combate J2: ataque básico corpo a corpo de jogador
-- contra criatura. Puro, sem Instances/remotos; RNG e catálogo são injetados.
local Shared = game:GetService("ReplicatedStorage").Shared
local Combate = require(Shared.Regras.Combate)
local Arma = require(Shared.Regras.Arma)
local Execucao = require(Shared.Regras.Execucao)
local Defeitos = require(Shared.Regras.RunDefeitos)

local EncontroAutonomoCombate = {}

local function inteiro(valor)
	return type(valor) == "number" and valor % 1 == 0
end

local function mecanicaCego(catalogo)
	local entrada = catalogo and catalogo.POR_ID and catalogo.POR_ID["condition/cego"]
	return entrada and entrada.data and entrada.data.mecanica or {}
end

local function condicaoAtiva(ator, id)
	return type(ator.condicoes) == "table" and ator.condicoes[id] ~= nil and ator.condicoes[id] ~= false
end

-- Gancho privado de servidor, sem I/O: erro/retorno inválido recusa a entrada
-- em vez de permitir que a falha remova silenciosamente as penalidades.
function EncontroAutonomoCombate.consultarDefeitos(provedor, userId)
	if not inteiro(userId) or userId <= 0 or userId == math.huge or type(provedor) ~= "function" then
		return nil, "Provedor ou jogador inválido."
	end
	local thread = coroutine.create(provedor)
	local ok, ids = coroutine.resume(thread, userId)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		return nil, "Provedor de defeitos deve ser síncrono."
	end
	if not ok then return nil, "Defeitos do jogador indisponíveis." end
	return Defeitos.validarCombate(ids)
end

-- Não altera a ficha pessoal/persistida. Sempre recalcula da base canônica,
-- inclusive se receber um ator já preparado: Manco nunca é subtraído duas vezes.
function EncontroAutonomoCombate.prepararDefeitos(ator, ids)
	local validos, erro = Defeitos.validarCombate(ids)
	if not validos then return nil, erro end
	if type(ator) ~= "table" or ator.kind ~= "jogador" then return nil, "Ator inválido para defeitos." end
	local copia = table.clone(ator)
	copia.defeitos = validos
	copia.defectEffects = Defeitos.efeitos(validos)
	copia.defectMovement = nil
	local metros = ator.ficha and ator.ficha.calculated and ator.ficha.calculated.movementMeters
	if metros ~= nil or copia.defectEffects.deslocamentoMenos > 0 then
		local movimento, falha = Defeitos.deslocamentoCombate(validos, metros)
		if not movimento then return nil, falha end
		copia.movementCasas = movimento.movementCasas
		copia.movementMeters = movimento.movementMeters
		if movimento.reductionMeters > 0 then copia.defectMovement = movimento end
	end
	return copia
end

function EncontroAutonomoCombate.testeComDefeitos(rng, ids, teste, bonus, cd, vantagem, desvantagem)
	local fontes, erro = Defeitos.fontesDeDesvantagem(ids, teste)
	if not fontes then return nil, erro end
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or not inteiro(bonus) or math.abs(bonus) > 50 or not inteiro(cd) or math.abs(cd) > 100
	then return nil, "Teste de combate inválido." end
	local resultado = Combate.resistencia(rng, bonus, cd, vantagem, desvantagem == true or #fontes > 0)
	resultado.defects = fontes
	return resultado
end

-- Adaptador para o teste de Vigor do Sopro. O resolvedor canônico continua
-- decidindo dados, imunidades e condições. A condição interna existe só nesta
-- chamada: não entra no estado, na ficha, no catálogo global ou no snapshot.
function EncontroAutonomoCombate.soproComDefeitos(resolver, rng, atacante, atores, targetId, bloqueadas, perigos, turno, catalogo)
	local preparados, fontesPorId = {}, {}
	for _, ator in ipairs(atores) do
		local fontes, erro = Defeitos.fontesDeDesvantagem(ator.defeitos or {}, "Vigor")
		if not fontes then return nil, erro end
		local copia = ator
		if ator.kind == "jogador" and #fontes > 0 then
			copia = table.clone(ator)
			copia.condicoes = table.clone(ator.condicoes or {})
			copia.condicoes["j2-defeito-vigor"] = 1
			fontesPorId[ator.id] = fontes
		end
		table.insert(preparados, copia)
	end
	if type(catalogo) ~= "table" or type(catalogo.POR_ESPECIE) ~= "table" then
		return nil, "Catálogo de condições indisponível."
	end
	local regras = table.clone(catalogo)
	regras.POR_ESPECIE = table.clone(catalogo.POR_ESPECIE)
	regras.POR_ESPECIE.condition = table.clone(catalogo.POR_ESPECIE.condition or {})
	table.insert(regras.POR_ESPECIE.condition, { data = { id = "j2-defeito-vigor",
		mecanica = { desvantagemEmTestes = true } } })
	local resultado, erro = resolver(rng, atacante, preparados, targetId, bloqueadas, perigos, turno, regras)
	if not resultado then return nil, erro end
	for _, efeito in ipairs(resultado.targets or {}) do
		if efeito.resistance and fontesPorId[efeito.actorId] then
			efeito.resistance.defects = fontesPorId[efeito.actorId]
			table.insert(efeito.notes, "Frágil: Desvantagem no teste de Vigor")
		end
	end
	return resultado
end

function EncontroAutonomoCombate.atacarBasico(rng, atacante, alvo, catalogo)
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then
		return nil, "Dependências de combate indisponíveis."
	end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador"
		or type(atacante.ficha) ~= "table" or type(alvo) ~= "table" or alvo.kind ~= "criatura"
		or type(alvo.fichaCriatura) ~= "table"
	then
		return nil, "Atacante ou alvo não suportado por este ataque."
	end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
		or not inteiro(atacante.pv) or atacante.pv <= 0
		or not inteiro(alvo.pv) or alvo.pv <= 0
		or not inteiro(alvo.ca) or alvo.ca < 0
	then
		return nil, "Estado de combate inválido."
	end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia ~= 1 then
		return nil, "Ataque básico exige criatura adjacente."
	end

	local ficha = atacante.ficha
	if type(ficha.construction) ~= "table" or type(ficha.calculated) ~= "table"
		or type(ficha.calculated.attributes) ~= "table"
	then
		return nil, "Ficha do atacante incompleta."
	end
	local arma = Arma.daFicha(ficha, catalogo, false)
	local arvore = Execucao.arvoreDeCorpo(ficha, catalogo)
	local atributo = Execucao.atributoDaArma(arvore, arma.atributo, ficha, catalogo)
	local bonus = atributo + arma.bonusDeRank
	local cego = mecanicaCego(catalogo)
	local ataque = Combate.ataque(rng, bonus, alvo.ca,
		cego.vantagemParaQuemAtaca == true and condicaoAtiva(alvo, "cego"),
		cego.desvantagemEmAtaques == true and condicaoAtiva(atacante, "cego"))
	local dano, fixo = nil, atributo + arma.bonusDeRank
	if ataque.acertou then
		local formula, bonusDado = Arma.formula(arma.dado)
		fixo += bonusDado
		dano = Combate.dano(rng, { formula }, fixo, ataque.critico)
	end
	local causado = if dano then dano.total else 0
	return {
		actorId = atacante.id,
		targetId = alvo.id,
		action = "basic-attack",
		weapon = arma.nome,
		distance = distancia,
		attack = ataque,
		damage = dano,
		damageDealt = causado,
		targetPv = math.max(0, alvo.pv - causado),
		targetDefeated = causado >= alvo.pv,
	}, nil
end

-- Disparo usa o contrato existente de mesa/ataque-a-distancia: uma Ação,
-- arma de distância (ou referência d6), alcance máximo de 12 casas.
function EncontroAutonomoCombate.atacarDistancia(rng, atacante, alvo, catalogo)
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then
		return nil, "Dependências de combate indisponíveis."
	end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador"
		or type(atacante.ficha) ~= "table" or type(alvo) ~= "table" or alvo.kind ~= "criatura"
		or type(alvo.fichaCriatura) ~= "table"
	then
		return nil, "Atacante ou alvo não suportado por este ataque."
	end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
		or not inteiro(atacante.pv) or atacante.pv <= 0
		or not inteiro(alvo.pv) or alvo.pv <= 0
		or not inteiro(alvo.ca) or alvo.ca < 0
	then
		return nil, "Estado de combate inválido."
	end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia > 12 then return nil, "Disparo exige criatura a até 12 casas." end
	local ficha = atacante.ficha
	if type(ficha.construction) ~= "table" or type(ficha.calculated) ~= "table"
		or type(ficha.calculated.attributes) ~= "table"
	then
		return nil, "Ficha do atacante incompleta."
	end
	local arma = Arma.daFicha(ficha, catalogo, true)
	local arvore = Execucao.arvoreDeCorpo(ficha, catalogo)
	local atributo = Execucao.atributoDaArma(arvore, arma.atributo, ficha, catalogo)
	local bonus = atributo + arma.bonusDeRank
	local cego = mecanicaCego(catalogo)
	local ataque = Combate.ataque(rng, bonus, alvo.ca,
		cego.vantagemParaQuemAtaca == true and condicaoAtiva(alvo, "cego"),
		cego.desvantagemEmAtaques == true and condicaoAtiva(atacante, "cego"))
	local dano, fixo = nil, atributo + arma.bonusDeRank
	if ataque.acertou then
		local formula, bonusDado = Arma.formula(arma.dado)
		fixo += bonusDado
		dano = Combate.dano(rng, { formula }, fixo, ataque.critico)
	end
	local causado = if dano then dano.total else 0
	return {
		actorId = atacante.id,
		targetId = alvo.id,
		action = "ranged-attack",
		weapon = arma.nome,
		distance = distancia,
		attack = ataque,
		damage = dano,
		damageDealt = causado,
		targetPv = math.max(0, alvo.pv - causado),
		targetDefeated = causado >= alvo.pv,
	}, nil
end

-- Barreiras não têm CA nem fazem Disputa: o golpe/disparo causa o dano normal
-- da arma automaticamente e nunca recebe crítico.
function EncontroAutonomoCombate.atacarBarreira(rng, atacante, barreira, catalogo, aDistancia)
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then return nil, "Dependências de combate indisponíveis." end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or type(barreira) ~= "table" or type(barreira.id) ~= "string"
		or not inteiro(barreira.x) or not inteiro(barreira.z) or not inteiro(barreira.pv) or barreira.pv <= 0
	then return nil, "Atacante ou barreira inválidos." end
	local distancia = Combate.distancia(atacante.x, atacante.z, barreira.x, barreira.z)
	if aDistancia then
		if distancia > 12 then return nil, "A barreira está fora do alcance do disparo." end
	elseif distancia ~= 1 then
		return nil, "Ataque básico exige uma barreira adjacente."
	end
	local ficha = atacante.ficha
	if type(ficha.construction) ~= "table" or type(ficha.calculated) ~= "table"
		or type(ficha.calculated.attributes) ~= "table"
	then return nil, "Ficha do atacante incompleta." end
	local arma = Arma.daFicha(ficha, catalogo, aDistancia == true)
	local arvore = Execucao.arvoreDeCorpo(ficha, catalogo)
	local atributo = Execucao.atributoDaArma(arvore, arma.atributo, ficha, catalogo)
	local formula, bonusDado = Arma.formula(arma.dado)
	local dano = Combate.dano(rng, { formula }, atributo + arma.bonusDeRank + bonusDado, false)
	return {
		actorId = atacante.id,
		targetId = "parede:" .. barreira.id,
		action = if aDistancia then "ranged-attack" else "basic-attack",
		weapon = arma.nome,
		barrierAbility = barreira.abilityId,
		distance = distancia,
		damage = dano,
		damageDealt = dano.total,
		targetPv = math.max(0, barreira.pv - dano.total),
		targetDefeated = dano.total >= barreira.pv,
		automatic = true,
		critical = false,
	}, nil
end

-- IA mínima baseada no Apêndice G: um ataque por vez contra o personagem mais
-- próximo, usando dano por turno como valor fixo (adaptação já usada no Modo Luta).
function EncontroAutonomoCombate.atacarCriatura(rng, atacante, alvo, catalogo)
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(atacante) ~= "table" or atacante.kind ~= "criatura"
		or type(atacante.fichaCriatura) ~= "table" or type(alvo) ~= "table" or alvo.kind ~= "jogador"
	then
		return nil, "Atacante ou alvo não suportado pela IA."
	end
	local ficha = atacante.fichaCriatura
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
		or not inteiro(atacante.pv) or atacante.pv <= 0
		or not inteiro(alvo.pv) or alvo.pv <= 0
		or not inteiro(alvo.ca) or alvo.ca < 0
		or not inteiro(ficha.bonusAtaque) or not inteiro(ficha.danoPorTurno) or ficha.danoPorTurno < 0
	then
		return nil, "Estado de combate da criatura inválido."
	end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia ~= 1 then return nil, "A criatura não está adjacente ao alvo." end
	local cego = mecanicaCego(catalogo)
	local ataque = Combate.ataque(rng, ficha.bonusAtaque, alvo.ca,
		cego.vantagemParaQuemAtaca == true and condicaoAtiva(alvo, "cego"),
		cego.desvantagemEmAtaques == true and condicaoAtiva(atacante, "cego"))
	local causado = if ataque.acertou then ficha.danoPorTurno else 0
	return {
		actorId = atacante.id,
		targetId = alvo.id,
		action = "creature-attack",
		distance = distancia,
		attack = ataque,
		damageDealt = causado,
		targetPv = math.max(0, alvo.pv - causado),
		targetDowned = causado >= alvo.pv,
	}, nil
end

return EncontroAutonomoCombate
