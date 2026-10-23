local FichaV2 = require(game:GetService("ReplicatedStorage").Shared.FichaV2)

-- Envelope mínimo no formato do exportador ficha-v2/1 (ficha fictícia).
local function envelope()
	return {
		mesa = 2,
		envelopeVersion = 2,
		exporterVersion = "ficha-v2/1",
		compatibility = "master-approved-snapshot",
		sourceCharacterId = "char_teste",
		name = " Aria ",
		constructionComplete = true,
		omissions = {},
		warnings = { "Proficiências livres são texto do jogador" },
		construction = {
			raceId = "race/humano",
			raceChosen = true,
			backgroundId = "background/plebeu",
			backgroundChosen = true,
			attributeBase = { forca = 0, agilidade = 1, vigor = 0, intelecto = 2, espirito = 0 },
			raceAttributeChoices = { "intelecto" },
			racialUpgradeIds = {},
			saveAdvantages = { "vigor" },
			startingTreeId = "tree/agua",
			unlockedRankIds = { "rank/agua/Principiante", "rank/agua/Intermedi%C3%A1rio" },
			purchasedIds = { "ability/agua/Principiante/bola-de-agua", "talent/agua/Principiante/condutor-de-gelo" },
			combinedSpellIds = {},
			skillIds = { "skill/arcanismo" },
			treeSkillChoiceIds = {},
			proficiencyTexts = { "Cartografia de rios" },
			weaponGroupIds = {},
			bonusHp = 0,
			bonusMp = 0,
			gold = 15,
			inventory = {
				{ sourceLocalId = "item_1", name = "Cajado", type = "geral", equipped = true, description = "Leve.\nCom runas." },
			},
			overrides = {},
		},
		calculated = {
			attributes = { forca = 0, agilidade = 1, vigor = 0, intelecto = 3, espirito = 0 },
			maxima = { pv = 22, pm = 12, pt = 0, pp = 0 },
			armorClass = 11,
			movementMeters = 7.5,
			initiative = { bonus = 1, advantage = false },
			highestRankBonus = 2,
			skills = { { skillId = "skill/arcanismo", bonus = 5, trained = true } },
			actionContexts = {},
			paSpent = 4,
		},
		session = {
			current = { pv = 20, pm = 12, pt = 0, pp = 0 },
			conditions = { { conditionId = "condition/apontado", stacks = 1, note = "pelo arqueiro" } },
			shortRests = 0,
			manualEffects = {},
		},
	}
end

local CATALOGO = { POR_ID = {} }
for id, kind in {
	["race/humano"] = "race",
	["background/plebeu"] = "background",
	["tree/agua"] = "tree",
	["rank/agua/Principiante"] = "rank",
	["rank/agua/Intermedi%C3%A1rio"] = "rank",
	["ability/agua/Principiante/bola-de-agua"] = "ability",
	["talent/agua/Principiante/condutor-de-gelo"] = "talent",
	["skill/arcanismo"] = "skill",
	["condition/apontado"] = "condition",
} do
	CATALOGO.POR_ID[id] = { id = id, kind = kind }
end

return {
	["aceita o envelope do exportador e apara o nome"] = function(t)
		local corpo, falha, avisos = FichaV2.validar(envelope(), CATALOGO)
		t.ok(corpo, falha)
		t.eq(corpo.name, "Aria")
		t.eq(#avisos, 0)
		t.eq(corpo.constructionComplete, true)
		t.eq(corpo.calculated.movementMeters, 7.5)
		t.eq(corpo.construction.inventory[1].description, "Leve.\nCom runas.")
		t.eq(corpo.mesa, nil, "o corpo não guarda o cabeçalho de transporte")
	end,
	["recusa campo desconhecido em qualquer nível"] = function(t)
		local e = envelope()
		e.construction.inventory[1].preco = 10
		local corpo, falha = FichaV2.validar(e, CATALOGO)
		t.eq(corpo, nil)
		t.ok(string.find(falha, "preco", 1, true), falha)
		e = envelope()
		e.extra = true
		t.eq((FichaV2.validar(e, CATALOGO)), nil)
	end,
	["recusa versão, modo e exportador desconhecidos"] = function(t)
		for campo, valor in { mesa = 1, envelopeVersion = 3, compatibility = "rpg", exporterVersion = "outro/1" } do
			local e = envelope()
			e[campo] = valor
			t.eq((FichaV2.validar(e, CATALOGO)), nil, campo)
		end
	end,
	["recusa números fora do limite ou fracionários"] = function(t)
		local casos = {
			function(e) e.calculated.armorClass = 100 end,
			function(e) e.calculated.maxima.pv = 1.5 end,
			function(e) e.calculated.attributes.forca = 51 end,
			function(e) e.calculated.movementMeters = 7.55 end,
			function(e) e.construction.gold = -1 end,
			function(e) e.session.conditions[1].stacks = 0 end,
		}
		for indice, alterar in casos do
			local e = envelope()
			alterar(e)
			t.eq((FichaV2.validar(e, CATALOGO)), nil, "caso " .. indice)
		end
	end,
	["recusa ID malformado, de outra espécie ou repetido"] = function(t)
		local casos = {
			function(e) e.construction.raceId = "humano" end,
			function(e) e.construction.raceId = "background/plebeu" end,
			function(e) e.construction.purchasedIds = { "skill/arcanismo" } end,
			function(e) e.construction.skillIds = { "skill/arcanismo", "skill/arcanismo" } end,
			function(e) e.construction.raceId = "race//humano" end,
		}
		for indice, alterar in casos do
			local e = envelope()
			alterar(e)
			t.eq((FichaV2.validar(e, CATALOGO)), nil, "caso " .. indice)
		end
	end,
	["ID bem formado fora do catálogo vira aviso e construção incompleta"] = function(t)
		local e = envelope()
		table.insert(e.construction.purchasedIds, "ability/agua/Principiante/nova-tecnica")
		local corpo, falha, avisos = FichaV2.validar(e, CATALOGO)
		t.ok(corpo, falha)
		t.eq(corpo.constructionComplete, false)
		t.eq(#avisos, 1)
		t.ok(string.find(avisos[1], "nova-tecnica", 1, true))
	end,
	["sem catálogo valida só o formato"] = function(t)
		local e = envelope()
		e.construction.raceId = "race/elfo-lunar"
		local corpo = FichaV2.validar(e, nil)
		t.ok(corpo)
		t.eq(corpo.constructionComplete, true)
	end,
	["recursos atuais acima do máximo são reduzidos com aviso"] = function(t)
		local e = envelope()
		e.session.current.pv = 30
		local corpo, _, avisos = FichaV2.validar(e, CATALOGO)
		t.eq(corpo.session.current.pv, 22)
		t.eq(#avisos, 1)
	end,
	["recusa textos inválidos e lista com lacuna"] = function(t)
		local casos = {
			function(e) e.name = "   " end,
			function(e) e.name = string.rep("a", 33) end,
			function(e) e.construction.proficiencyTexts = { "linha\nquebrada" } end,
			function(e) e.construction.inventory[1].name = "a\0b" end,
			function(e) e.session.conditions[1].note = string.rep("n", 61) end,
			function(e) e.construction.skillIds = { [1] = "skill/arcanismo", [3] = "skill/arcanismo" } end,
			function(e) e.calculated.actionContexts = { { action = "x" } } end,
		}
		for indice, alterar in casos do
			local e = envelope()
			alterar(e)
			t.eq((FichaV2.validar(e, CATALOGO)), nil, "caso " .. indice)
		end
	end,
	["corpo salvo revalida sem o cabeçalho e recusa o envelope cru"] = function(t)
		local corpo = FichaV2.validar(envelope(), CATALOGO)
		local denovo, falha = FichaV2.validarCorpo(corpo, CATALOGO)
		t.ok(denovo, falha)
		t.eq(denovo.name, "Aria")
		t.eq((FichaV2.validarCorpo(envelope(), CATALOGO)), nil)
	end,
	["lista os textos do jogador para o filtro"] = function(t)
		local corpo = FichaV2.validar(envelope(), CATALOGO)
		local refs = FichaV2.textos(corpo)
		-- nome, 1 proficiência, nome e descrição do item, nota, 1 aviso do site
		t.eq(#refs, 6)
		for _, ref in refs do
			ref[1][ref[2]] = "#"
		end
		t.eq(corpo.name, "#")
		t.eq(corpo.construction.inventory[1].description, "#")
		t.eq(corpo.session.conditions[1].note, "#")
	end,
	["deriva os campos da mesa"] = function(t)
		local corpo = FichaV2.validar(envelope(), CATALOGO)
		local mesa = FichaV2.paraMesa(corpo)
		t.eq(mesa.pvMax, 22)
		t.eq(mesa.mana, 12)
		t.eq(mesa.sheet.intelecto, 3)
		t.eq(mesa.sheet.deslocamento, 7.5)
		t.eq(mesa.conditions[1].id, "apontado")
		t.eq(mesa.conditions[1].note, "pelo arqueiro")
	end,
}
