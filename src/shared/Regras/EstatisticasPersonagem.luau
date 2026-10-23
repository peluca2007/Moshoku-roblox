-- Estatísticas derivadas para personagem novo (J1, rank inicial).
-- Espelha os seletores do site usando apenas a construção validada e catálogo.
-- Sem Instances, estado de combate, equipamento, talentos comprados ou overrides.
local EstatisticasPersonagem = {}
local Dice = require(game:GetService("ReplicatedStorage").Shared.Dice)

local PV_BASE = 14
local BONUS_RANK = { Principiante = 1, ["Intermediário"] = 2, ["Avançado"] = 3, Santo = 4, Rei = 5, Imperador = 6, Deus = 7 }
local ATRIBUTO_POR_ARVORE_UTILIDADE = {
	["furtividade-e-armadilhas"] = "agilidade",
	["bardo-e-interacao"] = "espirito",
	["navegacao-e-lideranca"] = "intelecto",
}

local function porId(catalogo, id, especie)
	local entrada = type(id) == "string" and catalogo.POR_ID[id]
	if entrada and (not especie or entrada.kind == especie) then
		return entrada
	end
	return nil
end

local function bonusFixo(entrada, chave): number
	return entrada and entrada.data and entrada.data.bonuses and entrada.data.bonuses[chave] or 0
end

local function mediaDoDado(formula: string): number?
	local spec = Dice.parse(formula)
	if not spec then
		return nil
	end
	local media = spec.modifier
	for _, termo in spec.terms do
		media += termo.sign * termo.count * (termo.sides + 1) / 2
	end
	return math.floor(media + 0.5)
end

local function fatorVigor(vigor: number): number
	if vigor <= -2 then
		return 0.4
	elseif vigor == -1 then
		return 0.75
	end
	return math.floor((1 + 0.2 * vigor) * 100 + 0.5) / 100
end

-- Retorna nil e mensagem se a definição de rank não tiver dados suficientes.
function EstatisticasPersonagem.calcular(construcao, catalogo, atributos)
	local raca = porId(catalogo, construcao.raceId, "race")
	local antecedente = porId(catalogo, construcao.backgroundId, "background")
	local subtabela = porId(catalogo, construcao.subtableEntryId, "subtable-entry")
	local rankInicial = porId(catalogo, (construcao.unlockedRankIds or {})[1], "rank")
	local arvore = rankInicial and porId(catalogo, "tree/" .. tostring(rankInicial.data.treeId), "tree")
	local semArvore = construcao.startingTreeId == nil and #(construcao.unlockedRankIds or {}) == 0
	if not raca or not antecedente or (not semArvore and (not rankInicial or not arvore)) then
		return nil, "Catálogo incompleto para calcular as estatísticas iniciais."
	end

	-- Sem ?rvore n?o h? dado de PV nem recurso de rank: s? o piso can?nico 14.
	local mediaPv = if semArvore then 0 else mediaDoDado(rankInicial.data.hpDiceFormula)
	if not mediaPv then
		return nil, "Rank inicial sem fórmula de PV válida."
	end

	local vigor = atributos.vigor or 0
	local pv = math.floor((PV_BASE + mediaPv * 1.67) * fatorVigor(vigor))
		+ bonusFixo(raca, "maxHp") + bonusFixo(antecedente, "maxHp") + bonusFixo(subtabela, "maxHp")

	local bonusRank = if rankInicial then BONUS_RANK[rankInicial.data.rank] or 0 else 0
	local pm = 0
	if arvore and arvore.data.category == "magia" then
		local espirito = atributos.espirito or 0
		local bonusEscalar = bonusFixo(raca, "mpPerMagicRank")
			+ bonusFixo(antecedente, "mpPerMagicRank") + bonusFixo(subtabela, "mpPerMagicRank")
		pm = math.max(espirito, 4) * bonusRank + 8 + bonusEscalar * bonusRank
			+ bonusFixo(raca, "maxMp") + bonusFixo(antecedente, "maxMp") + bonusFixo(subtabela, "maxMp")
	end

	local pt = 0
	if arvore and arvore.data.category == "corpo" then
		pt = math.max((atributos.vigor or 0) + (atributos.espirito or 0), 0) + (rankInicial.data.ptGained or 1)
	end

	local pp = 0
	if arvore and arvore.data.category == "utilidade" then
		local atributoChave = ATRIBUTO_POR_ARVORE_UTILIDADE[arvore.data.id]
		if not atributoChave then
			return nil, "Árvore de Utilidade sem atributo-chave definido para PP."
		end
		local segundo = if atributoChave == "intelecto" then bonusRank else (atributos[atributoChave] or 0)
		pp = math.max((atributos.intelecto or 0) + segundo, 1)
	end

	local bonusCA = bonusFixo(raca, "armorClass") + bonusFixo(antecedente, "armorClass")
		+ bonusFixo(subtabela, "armorClass")
	if arvore and arvore.data.id == "deus-da-espada" then
		bonusCA -= 2
	end

	return {
		maxima = { pv = pv, pm = pm, pt = pt, pp = pp },
		armorClass = 10 + (atributos.agilidade or 0) + bonusCA,
		movementMeters = 9,
		initiative = {
			bonus = atributos.agilidade or 0,
			advantage = antecedente.data.grantsInitiativeAdvantage == true,
		},
	}, nil
end

return EstatisticasPersonagem
