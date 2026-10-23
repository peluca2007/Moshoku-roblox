-- Recorte explícito de técnicas cujo contrato completo existe no J2.
-- Não libera automaticamente cartas da mesa: desarme, Caído, investidas e
-- reações ainda exigem seus próprios fluxos de equipamento/movimento/IA.
local Shared = game:GetService("ReplicatedStorage").Shared
local Arvores = require(Shared.Regras.ArvoresPrincipiante)
local Arma = require(Shared.Regras.Arma)
local Execucao = require(Shared.Regras.Execucao)
local Habilidades = require(Shared.Regras.Habilidades)
local Combate = require(Shared.Regras.Combate)

local Tecnicas = {}
Tecnicas.GOLPE_CONTINUO = "ability/deus-da-espada/Principiante/golpe-continuo"
local RANK = "rank/deus-da-espada/Principiante"
local mecanica = table.clone(Arvores.MECANICAS[Tecnicas.GOLPE_CONTINUO])
mecanica.alcanceCasas = 1
table.freeze(mecanica)

local function inteiro(valor)
	return type(valor) == "number" and valor == valor and valor % 1 == 0
end

function Tecnicas.mecanica(id)
	return if id == Tecnicas.GOLPE_CONTINUO then mecanica else nil
end

function Tecnicas.disponiveis(ator)
	local ficha = type(ator) == "table" and ator.kind == "jogador" and ator.ficha
	local c = type(ficha) == "table" and ficha.construction
	if type(c) == "table" and type(c.unlockedRankIds) == "table" and type(c.purchasedIds) == "table"
		and table.find(c.unlockedRankIds, RANK) and table.find(c.purchasedIds, Tecnicas.GOLPE_CONTINUO)
	then return { Tecnicas.GOLPE_CONTINUO } end
	return {}
end

-- A disponibilidade indica conhecimento; recursos/arma/estado são revalidados
-- na execução. Não há arma de referência silenciosa para uma técnica de arma.
function Tecnicas.usar(rng, id, atacante, alvo, catalogo)
	local mec = Tecnicas.mecanica(id)
	if not mec or not table.find(Tecnicas.disponiveis(atacante), id) then
		return nil, "A ficha não conhece esta técnica."
	end
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table" or type(catalogo.POR_ESPECIE) ~= "table"
	then return nil, "Dependências da técnica indisponíveis." end
	if type(alvo) ~= "table" or alvo.kind ~= "criatura" or type(alvo.fichaCriatura) ~= "table"
		or alvo.defeated == true or not inteiro(alvo.pv) or alvo.pv <= 0 or not inteiro(alvo.ca) or alvo.ca < 0
		or not inteiro(atacante.pv) or atacante.pv <= 0 or not inteiro(atacante.pvMax)
		or not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
	then return nil, "Estado ou alvo da técnica inválido." end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia ~= 1 then return nil, "A técnica exige uma criatura adjacente." end
	if not inteiro(atacante.pt or 0) or (atacante.pt or 0) < mec.pt
		or not inteiro(atacante.pm or 0) or (atacante.pm or 0) < mec.pm
	then return nil, "PT ou PM insuficientes para a técnica." end
	local ficha = atacante.ficha
	if type(ficha.calculated) ~= "table" or type(ficha.calculated.attributes) ~= "table" then
		return nil, "Ficha incompleta para a técnica."
	end
	local estados, condicoes = atacante.estadosDeCombate or {}, atacante.condicoes or {}
	if condicoes.inconsciente or condicoes.incapacitado or condicoes.paralisado
		or estados.desarmado or estados.bracoInutil
	then return nil, "O estado atual impede o uso da arma." end
	local arma = Arma.daFicha(ficha, catalogo, false)
	if arma.aviso or arma.desarmado then return nil, "Equipe uma única arma corpo a corpo válida para a técnica." end
	local arvore = Execucao.arvoreDe(id)
	local bonus = Execucao.atributoDaArma(arvore, arma.atributo, ficha, catalogo) + arma.bonusDeRank
	local regras = {}
	for _, entrada in ipairs(catalogo.POR_ESPECIE.condition or {}) do
		if type(entrada.data) == "table" and type(entrada.data.mecanica) == "table" then
			regras[entrada.data.id] = entrada.data.mecanica
		end
	end
	local efeitos = Habilidades.resolver(rng, mec, {
		id = atacante.id, bc = Execucao.bc(ficha, arvore, catalogo),
		pv = atacante.pv, pvMax = atacante.pvMax, condicoes = condicoes,
		atributos = ficha.calculated.attributes, bonusDeRank = Execucao.bonusDeRankDa(ficha, arvore),
		arma = { dado = arma.dado, bonus = bonus }, jaAcertou = atacante.jaAcertouNestaVez == true,
	}, { { id = alvo.id, ca = alvo.ca, condicoes = alvo.condicoes or {},
		patamar = alvo.fichaCriatura.patamar or 0,
		resistencias = alvo.fichaCriatura.resistencias or {}, imunidades = alvo.fichaCriatura.imunidades or {},
		resistencia = function() return math.ceil((alvo.fichaCriatura.bonusAtaque or 0) / 2) end,
	} }, regras)
	local efeito = efeitos[1]
	local dano = efeito.dano
	local causado = dano and dano.total or 0
	return { actorId = atacante.id, targetId = alvo.id, action = "use-ability", abilityId = id,
		actionsCost = mec.acoes, pmCost = mec.pm, ptCost = mec.pt, weapon = arma.nome, distance = distancia,
		attack = efeito.ataque, damage = dano, damageDealt = causado,
		targetPv = math.max(0, alvo.pv - causado), targetDefeated = causado >= alvo.pv,
		applies = efeito.aplica or {}, states = efeito.estados or {}, notes = efeito.notas or {},
	}, nil
end

return Tecnicas
