local Shared = game:GetService("ReplicatedStorage").Shared
local CriacaoPersonagem = require(Shared.Regras.CriacaoPersonagem)

local function catalogo()
	local porId = {
		["race/humano"] = { id = "race/humano", kind = "race", data = {
			id = "humano", tier = "comum", attributeChoices = 1, bonusSkillChoices = 1,
		} },
		["background/plebeu"] = { id = "background/plebeu", kind = "background", data = { id = "plebeu" } },
		["background/miko"] = { id = "background/miko", kind = "background", data = {
			id = "miko", requiresSubtable = "miko", bonusSkillChoices = 1,
		} },
		["subtable-entry/miko/forca-sobre-humana"] = { id = "subtable-entry/miko/forca-sobre-humana", kind = "subtable-entry", data = {
			id = "forca-sobre-humana", subtableId = "miko",
		} },
		["subtable-entry/olho/previsao"] = { id = "subtable-entry/olho/previsao", kind = "subtable-entry", data = {
			id = "previsao", subtableId = "olho",
		} },
		["tree/agua"] = { id = "tree/agua", kind = "tree", data = {
			id = "agua", subgroup = "Magia Ofensiva", category = "magia", grantedSkills = { choose = { count = 1, from = { "Medicina", "Percepção" } } },
			ranks = { "rank/agua/Principiante" },
		} },
		["rank/agua/Principiante"] = { id = "rank/agua/Principiante", kind = "rank", data = {
			treeId = "agua", rank = "Principiante", hpDiceFormula = "1d6+1",
		} },
		["weapon-group/espadas"] = { id = "weapon-group/espadas", kind = "weapon-group", data = { id = "espadas" } },
		["weapon-group/desarmado-e-improvisado"] = { id = "weapon-group/desarmado-e-improvisado", kind = "weapon-group", data = { id = "desarmado-e-improvisado" } },
		["skill/medicina"] = { id = "skill/medicina", kind = "skill", data = { name = "Medicina", attribute = "intelecto" } },
		["skill/percepcao"] = { id = "skill/percepcao", kind = "skill", data = { name = "Percepção", attribute = "espirito" } },
		["skill/oficios"] = { id = "skill/oficios", kind = "skill", data = { name = "Ofícios", attribute = "intelecto" } },
	}
	return {
		POR_ID = porId,
		POR_ESPECIE = { skill = { porId["skill/medicina"], porId["skill/percepcao"], porId["skill/oficios"] } },
	}
end

local function base()
	return { forca = 2, agilidade = 0, vigor = 0, intelecto = 0, espirito = 0 }
end

local function construcao()
	return {
		raceId = "race/humano",
		backgroundId = "background/miko",
		subtableEntryId = "subtable-entry/miko/forca-sobre-humana",
		attributeBase = base(),
		raceAttributeChoices = { "agilidade" },
		startingTreeId = "tree/agua",
		treeSkillChoiceIds = { "skill/medicina" },
		freeSkillChoiceIds = { "skill/percepcao", "skill/oficios" },
	}
end

return {
	["aceita construção válida e mantém IDs canônicos completos"] = function(t)
		local original = construcao()
		local resultado, erro = CriacaoPersonagem.validar(original, catalogo())
		t.eq(erro, nil)
		t.eq(resultado.raceId, "race/humano")
		t.eq(resultado.raceChosen, true)
		t.eq(resultado.backgroundId, "background/miko")
		t.eq(resultado.backgroundChosen, true)
		t.eq(resultado.subtableEntryId, "subtable-entry/miko/forca-sobre-humana")
		t.eq(resultado.startingTreeId, "tree/agua")
		t.eq(resultado.unlockedRankIds[1], "rank/agua/Principiante")
		t.eq(resultado.pontosAprimoramento.iniciais, 3)
		t.eq(resultado.pontosAprimoramento.custoEscolhaRaca, 1)
		t.eq(resultado.pontosAprimoramento.restantes, 2)
		t.eq(resultado.treeSkillChoiceIds[1], "skill/medicina")
		t.eq(#resultado.weaponGroupIds, 1)
		t.eq(resultado.weaponGroupIds[1], "weapon-group/desarmado-e-improvisado")
		t.eq(#resultado.skillIds, 2)
		t.eq(resultado.attributeBase.forca, 2)
		resultado.attributeBase.forca = 0
		t.eq(original.attributeBase.forca, 2, "resultado não deve compartilhar a tabela recebida")
	end,
	["prévia calcula atributos e perícias a partir da construção aceita"] = function(t)
		local previ = CriacaoPersonagem.calcular(construcao(), catalogo())
		t.eq(previ.atributos.forca, 2)
		t.eq(previ.atributos.agilidade, 1)
		t.eq(previ.atributos.vigor, 0)
		local medicina = previ.pericias[1]
		t.ok(medicina)
		t.eq(medicina.trained, true)
		t.eq(medicina.bonus, 0)
		t.eq(previ.estatisticas.maxima.pv, 22)
		t.eq(previ.estatisticas.maxima.pm, 12)
		t.eq(previ.estatisticas.maxima.pt, 0)
		t.eq(previ.estatisticas.maxima.pp, 0)
		t.eq(previ.estatisticas.armorClass, 11)
		t.eq(previ.estatisticas.movementMeters, 9)
		t.eq(previ.pontosAprimoramento.restantes, 2)
		t.eq(previ.kitInicial.subgrupo, "Magia Ofensiva")
		t.eq(previ.kitInicial.itens[1].name, "Cajado / Foco Arcano")
		t.eq(previ.inventarioInicial[1].name, "Cajado / Foco Arcano")
		t.eq(previ.inventarioInicial[1].sourceLocalId, "kit-inicial-01")
		t.eq(previ.inventarioInicial[1].baseDie, "d6")
		t.eq(previ.inventarioInicial[1].equipped, false, "kit não equipa automaticamente")
	end,
	["subgrupo sem kit catalogado nao pode criar ficha jogavel"] = function(t)
		local cat = catalogo()
		cat.POR_ID["tree/agua"].data.subgroup = "árvore-sem-kit"
		local previ, erro = CriacaoPersonagem.calcular(construcao(), cat)
		t.eq(previ, nil)
		t.eq(erro, "Esta árvore ainda não tem um kit inicial jogável.")
	end,
	["grupos de arma vêm da árvore e viram IDs canônicos"] = function(t)
		local cat = catalogo()
		cat.POR_ID["tree/agua"].data.proficiencies = { gruposDeArma = { "espadas" } }
		local resultado, erro = CriacaoPersonagem.validar(construcao(), cat)
		t.eq(erro, nil)
		t.eq(resultado.weaponGroupIds[1], "weapon-group/desarmado-e-improvisado")
		t.eq(resultado.weaponGroupIds[2], "weapon-group/espadas")
		cat.POR_ID["tree/agua"].data.proficiencies.gruposDeArma = { "grupo-ausente" }
		resultado, erro = CriacaoPersonagem.validar(construcao(), cat)
		t.eq(resultado, nil)
		t.ok(string.find(erro, "Grupo de arma"))
	end,
	["custo da raça escolhida segue o tier e antecedente não soma custo"] = function(t)
		local c = construcao()
		local cat = catalogo()
		local raca = cat.POR_ID["race/humano"]
		for tier, custo in pairs({ comum = 1, incomum = 1, rara = 2, lendaria = 3, mitica = 3 }) do
			raca.data.tier = tier
			local resultado, erro = CriacaoPersonagem.validar(c, cat)
			t.eq(erro, nil)
			t.eq(resultado.pontosAprimoramento.custoEscolhaRaca, custo)
			t.eq(resultado.pontosAprimoramento.restantes, 3 - custo)
		end
	end,
	["recusa raça cujo catálogo não define tier de escolha"] = function(t)
		local cat = catalogo()
		cat.POR_ID["race/humano"].data.tier = "desconhecido"
		local resultado, erro = CriacaoPersonagem.validar(construcao(), cat)
		t.eq(resultado, nil)
		t.ok(string.find(erro, "tier de custo"))
	end,
	["recusa orçamento de atributos incompleto"] = function(t)
		local c = construcao()
		c.attributeBase.forca = 1
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "pontos de atributo"))
	end,
	["recusa repetir o mesmo defeito do point-buy"] = function(t)
		local c = construcao()
		c.attributeBase = { forca = -1, agilidade = -1, vigor = 4, intelecto = 0, espirito = 0 }
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "defeito"))
	end,
	["subtabela precisa pertencer ao antecedente selecionado"] = function(t)
		local c = construcao()
		c.subtableEntryId = "subtable-entry/olho/previsao"
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "incompatível"))
	end,
	["escolha de perícia precisa existir entre as opções da árvore"] = function(t)
		local c = construcao()
		c.treeSkillChoiceIds = { "skill/oficios" }
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "não disponível"))
	end,
	["escolhas gratuitas e de árvore não podem duplicar perícias"] = function(t)
		local c = construcao()
		c.freeSkillChoiceIds = { "skill/percepcao", "skill/percepcao" }
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "perícia de raça"))
		c = construcao()
		c.treeSkillChoiceIds = { "skill/medicina", "skill/medicina" }
		resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "perícia inválidas"))
	end,
	["escolha livre não duplica perícia concedida pela árvore"] = function(t)
		local c = construcao()
		c.freeSkillChoiceIds = { "skill/medicina", "skill/oficios" }
		c.treeSkillChoiceIds = { "skill/medicina" }
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "já é concedida"))
		for _, origem in { "race/humano", "background/miko" } do
			c = construcao()
			c.freeSkillChoiceIds = { "skill/oficios", "skill/percepcao" }
			local cat = catalogo()
			cat.POR_ID[origem].data.fixedSkills = { "Ofícios" }
			resultado, erro = CriacaoPersonagem.validar(c, cat)
			t.eq(resultado, nil)
			t.ok(string.find(erro, "já é concedida"))
		end
	end,
	["quantidade racial e escolha de árvore precisam estar completas"] = function(t)
		local c = construcao()
		c.raceAttributeChoices = {}
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "escolhas de atributo"))
		c = construcao()
		c.freeSkillChoiceIds = { "skill/percepcao" }
		resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "perícia de raça"))
	end,
	["recusa campos extras e antecedente que exige seleção sem subentrada"] = function(t)
		local c = construcao()
		c.ownerUserId = 123
		local resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "campo desconhecido"))
		c = construcao()
		c.subtableEntryId = nil
		resultado, erro = CriacaoPersonagem.validar(c, catalogo())
		t.eq(resultado, nil)
		t.ok(string.find(erro, "subtabela"))
	end,
}
