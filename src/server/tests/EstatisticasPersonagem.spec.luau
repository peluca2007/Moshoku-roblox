local Shared = game:GetService("ReplicatedStorage").Shared
local EstatisticasPersonagem = require(Shared.Regras.EstatisticasPersonagem)

local function catalogo(categoria, arvoreId, dados)
	local porId = {
		["race/humano"] = { id = "race/humano", kind = "race", data = { bonuses = dados.raca or {} } },
		["background/plebeu"] = { id = "background/plebeu", kind = "background", data = { bonuses = dados.antecedente or {}, grantsInitiativeAdvantage = dados.vantagem == true } },
		["tree/" .. arvoreId] = { id = "tree/" .. arvoreId, kind = "tree", data = { id = arvoreId, category = categoria } },
		["rank/" .. arvoreId .. "/Principiante"] = { id = "rank/" .. arvoreId .. "/Principiante", kind = "rank", data = {
			treeId = arvoreId, rank = "Principiante", hpDiceFormula = dados.dadoPv or "1d6+1", ptGained = dados.ptGained,
		} },
	}
	if dados.subtabela then
		porId["subtable-entry/teste/bonus"] = { id = "subtable-entry/teste/bonus", kind = "subtable-entry", data = { bonuses = dados.subtabela } }
	end
	return { POR_ID = porId }
end

local construcao = {
	raceId = "race/humano", backgroundId = "background/plebeu",
	subtableEntryId = "subtable-entry/teste/bonus",
	unlockedRankIds = { "rank/teste/Principiante" },
}

local function calcular(categoria, arvoreId, dados, atributos)
	local copia = table.clone(construcao)
	copia.unlockedRankIds = { "rank/" .. arvoreId .. "/Principiante" }
	return EstatisticasPersonagem.calcular(copia, catalogo(categoria, arvoreId, dados), atributos)
end

return {
	["PV usa média do dado inicial e bônus fixos ficam fora do fator de Vigor"] = function(t)
		local resultado = calcular("magia", "teste", { raca = { maxHp = 3 }, antecedente = { maxHp = 2 } }, { vigor = -1 })
		t.eq(resultado.maxima.pv, 21) -- floor((14 + 1.67 × 5) × .75) + 5
	end,
	["PM só existe com magia e soma bônus escalares iniciais"] = function(t)
		local resultado = calcular("magia", "teste", {
			raca = { mpPerMagicRank = 2 }, antecedente = { mpPerMagicRank = 1 }, subtabela = { mpPerMagicRank = 3 },
		}, { espirito = -2 })
		t.eq(resultado.maxima.pm, 18)
		resultado = calcular("corpo", "deus-da-espada", {}, {})
		t.eq(resultado.maxima.pm, 0)
	end,
	["PT usa o mínimo do par de atributos e o crescimento declarado"] = function(t)
		local resultado = calcular("corpo", "teste", { ptGained = 2 }, { vigor = -2, espirito = -1 })
		t.eq(resultado.maxima.pt, 2)
	end,
	["PP, CA, deslocamento e iniciativa respeitam categoria e antecedentes"] = function(t)
		local resultado = calcular("utilidade", "furtividade-e-armadilhas", { raca = { armorClass = 1 }, antecedente = { armorClass = 2 }, vantagem = true }, { intelecto = 1, agilidade = 2 })
		t.eq(resultado.maxima.pp, 3)
		t.eq(resultado.armorClass, 15)
		t.eq(resultado.movementMeters, 9)
		t.eq(resultado.initiative.bonus, 2)
		t.eq(resultado.initiative.advantage, true)
	end,
}
