local Shared = game:GetService("ReplicatedStorage").Shared
local MesaSave = require(Shared.MesaSave)
local Protocol = require(Shared.MesaProtocol)

local function token(number)
	return {
		id = "t" .. number, name = "Ficha " .. number, kind = "npc", ownerUserId = 0,
		x = (number - 1) % Protocol.BOARD.width + 1,
		z = math.floor((number - 1) / Protocol.BOARD.width) + 1,
		pv = 7, pvMax = 10, mana = 2, manaMax = 4,
		hidden = false, showStats = true,
		color = Color3.fromRGB(70, 120, 200), version = 0,
	}
end

local function state(count)
	count = count or 2
	local tokens = {}
	for index = 1, count do table.insert(tokens, token(index)) end
	return {
		nextId = count, tokens = tokens,
		combat = { active = false, round = 0, order = {}, turnIndex = 0, turn = 0 },
	}
end

local function sheet()
	return {
		forca = 1, agilidade = 3, vigor = 2, intelecto = 0, espirito = 4,
		ca = 13, deslocamento = 9.1, iniciativa = 3, vantagemIniciativa = true,
	}
end

-- Corpo de ficha v2 já aceito (formato de FichaV2.validar), fictício e mínimo.
local function ficha2()
	local atributos = { forca = 0, agilidade = 1, vigor = 0, intelecto = 3, espirito = 0 }
	return {
		exporterVersion = "ficha-v2/1", sourceCharacterId = "char_teste", name = "Aria",
		constructionComplete = true, omissions = {}, warnings = { "Aviso do site" },
		construction = {
			raceChosen = false, backgroundChosen = false, attributeBase = table.clone(atributos),
			raceAttributeChoices = {}, racialUpgradeIds = {}, saveAdvantages = {},
			unlockedRankIds = { "rank/agua/Principiante" }, purchasedIds = { "ability/agua/Principiante/bola-de-agua" },
			combinedSpellIds = {}, skillIds = {}, treeSkillChoiceIds = {}, proficiencyTexts = { "Remo" },
			weaponGroupIds = {}, bonusHp = 0, bonusMp = 0, gold = 3,
			inventory = { { sourceLocalId = "i1", name = "Corda", type = "geral", equipped = false } },
			overrides = {},
		},
		calculated = {
			attributes = table.clone(atributos), maxima = { pv = 22, pm = 12, pt = 0, pp = 0 },
			armorClass = 11, movementMeters = 7.5, initiative = { bonus = 1, advantage = false },
			highestRankBonus = 2, skills = {}, actionContexts = {}, paSpent = 2,
		},
		session = {
			current = { pv = 20, pm = 12, pt = 0, pp = 0 },
			conditions = { { conditionId = "condition/apontado", stacks = 1, note = "torre" } },
			manualEffects = {},
		},
	}
end

local function same(t, actual, expected, path)
	path = path or "raiz"
	t.eq(type(actual), type(expected), path)
	if type(expected) ~= "table" then t.eq(actual, expected, path); return end
	for key, value in expected do same(t, actual[key], value, path .. "." .. tostring(key)) end
	for key in actual do t.ok(expected[key] ~= nil, path .. ": campo extra " .. tostring(key)) end
end

local function plain(t, value)
	local kind = typeof(value)
	t.ok(kind == "table" or kind == "string" or kind == "number" or kind == "boolean",
		"Tipo incompatível com DataStore: " .. kind)
	if kind == "table" then
		for key, child in value do
			t.ok(type(key) == "string" or type(key) == "number")
			plain(t, child)
		end
	end
end

local function roundtrip(t, original)
	local encoded = MesaSave.encode(original)
	plain(t, encoded)
	local restored, warnings = MesaSave.decode(encoded)
	t.ok(restored)
	t.eq(#warnings, 0)
	same(t, MesaSave.encode(restored), encoded)
	return restored, encoded
end

return {
	["ida e volta preserva fichas, ordem e combate"] = function(t)
		local original = state()
		original.tokens[1].ownerUserId = -1
		original.tokens[1].hidden = true
		original.tokens[2].version = 3
		original.combat = { active = true, round = 3, order = { "t2", "t1" }, turnIndex = 2, turn = 8 }
		local restored, encoded = roundtrip(t, original)
		t.eq(encoded.color, nil)
		t.eq(encoded.tokens[1].color.r, 70)
		t.eq(encoded.tokens[1].color.g, 120)
		t.eq(encoded.tokens[1].color.b, 200)
		t.eq(restored.tokens[1].version, 0)
		t.eq(restored.tokens[2].version, 3)
		t.eq(restored.tokens[1].hidden, true)
		t.eq(restored.tokens[1].ownerUserId, -1)
		t.eq(restored.tokens[1].color, Color3.fromRGB(70, 120, 200))
		t.eq(restored.combat.order[1], "t2")
		t.eq(restored.combat.turnIndex, 2)
	end,

	["ficha inválida é descartada com aviso sem descartar as outras"] = function(t)
		for _, field in { "id", "name", "kind", "ownerUserId", "x", "z", "pv", "pvMax",
			"mana", "manaMax", "hidden", "showStats", "color", "version" } do
			local encoded = MesaSave.encode(state())
			encoded.tokens[1][field] = nil
			local restored, warnings = MesaSave.decode(encoded)
			t.ok(restored, field)
			t.eq(#restored.tokens, 1, field)
			t.eq(restored.tokens[1].id, "t2", field)
			t.ok(#warnings > 0, field)
		end
		local encoded = MesaSave.encode(state())
		encoded.tokens[1].color.r = 256
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(#restored.tokens, 1)
		t.ok(#warnings > 0)
		encoded = MesaSave.encode(state())
		encoded.tokens[1].version = -1
		restored, warnings = MesaSave.decode(encoded)
		t.eq(#restored.tokens, 1)
		t.ok(#warnings > 0)
	end,

	["nomes usam caracteres e recusam UTF-8 inválido"] = function(t)
		for _, name in { "Ação Ébria Ígnea Óssea Úmida ãõ", string.rep("ã", Protocol.LIMITS.name) } do
			local original = state(1)
			original.tokens[1].name = name
			local restored = roundtrip(t, original)
			t.eq(restored.tokens[1].name, name)
		end
		for _, name in { string.rep("ã", 33), "Nome" .. string.char(255), "", "   " } do
			local encoded = MesaSave.encode(state(1))
			encoded.tokens[1].name = name
			local restored, warnings = MesaSave.decode(encoded)
			t.eq(#restored.tokens, 0)
			t.ok(#warnings > 0)
		end
	end,

	["id repetido preserva a primeira ficha"] = function(t)
		local encoded = MesaSave.encode(state(3))
		encoded.tokens[2].id = "t1"
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(#restored.tokens, 2)
		t.eq(restored.tokens[1].name, "Ficha 1")
		t.eq(restored.tokens[2].id, "t3")
		t.eq(#warnings, 1)
		t.ok(string.find(warnings[1], "id repetido", 1, true))
	end,

	["casas compartilhadas preservam fichas visíveis e ocultas"] = function(t)
		for _, hidden in { false, true } do
			local original = state()
			original.tokens[2].x = original.tokens[1].x
			original.tokens[2].z = original.tokens[1].z
			original.tokens[2].hidden = hidden
			original.combat = { active = true, round = 1, order = { "t1", "t2" }, turnIndex = 1, turn = 1 }
			local restored = roundtrip(t, original)
			t.eq(#restored.tokens, 2)
			t.eq(restored.tokens[2].hidden, hidden)
			t.eq(restored.combat.active, true)
		end
	end,

	["lista acima do limite é truncada com aviso"] = function(t)
		local restored, warnings = MesaSave.decode(MesaSave.encode(state(Protocol.LIMITS.tokens + 1)))
		t.eq(#restored.tokens, Protocol.LIMITS.tokens)
		t.eq(restored.tokens[#restored.tokens].id, "t" .. Protocol.LIMITS.tokens)
		t.eq(#warnings, 1)
		t.ok(string.find(warnings[1], "truncada", 1, true))
	end,

	["nextId é recalculado e valores maiores são preservados"] = function(t)
		for _, value in { -1, 0, 1, 0.5, math.huge } do
			local encoded = MesaSave.encode(state())
			encoded.nextId = value
			local restored, warnings = MesaSave.decode(encoded)
			t.eq(restored.nextId, 2)
			t.ok(#warnings > 0)
		end
		local encoded = MesaSave.encode(state())
		encoded.nextId = nil
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(restored.nextId, 2)
		t.ok(#warnings > 0)
		encoded.nextId = 50
		restored, warnings = MesaSave.decode(encoded)
		t.eq(restored.nextId, 50)
		t.eq(#warnings, 0)
	end,

	["combate inconsistente é encerrado com aviso"] = function(t)
		for _, combat in {
			{ active = true, round = 1, order = { "t99" }, turnIndex = 1, turn = 1 },
			{ active = true, round = 1, order = { "t1" }, turnIndex = 2, turn = 1 },
			{ active = true, round = 1, order = { "t1", "t1" }, turnIndex = 1, turn = 1 },
			{ active = true, round = 1, order = {}, turnIndex = 0, turn = 1 },
			{ active = true, round = 0, order = { "t1" }, turnIndex = 1, turn = 1 },
		} do
			local encoded = MesaSave.encode(state())
			encoded.combat = combat
			local restored, warnings = MesaSave.decode(encoded)
			t.eq(restored.combat.active, false)
			t.eq(#restored.combat.order, 0)
			t.eq(restored.combat.turnIndex, 0)
			t.eq(#warnings, 1)
		end
	end,

	["schema mais novo é recusado"] = function(t)
		local encoded = MesaSave.encode(state())
		encoded.schema = MesaSave.SCHEMA + 1
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(restored, nil)
		t.eq(#warnings, 1)
		t.ok(string.find(warnings[1], "versão mais nova", 1, true))
	end,

	["entrada e estrutura inutilizáveis são recusadas"] = function(t)
		for _, value in { false, 10, "mesa", {}, { schema = 1 }, { schema = 1, tokens = false } } do
			local restored, warnings = MesaSave.decode(value)
			t.eq(restored, nil)
			t.ok(#warnings > 0)
		end
		local restored, warnings = MesaSave.decode(nil)
		t.eq(restored, nil)
		t.ok(#warnings > 0)
	end,

	["encode é estável, independente e quantiza a cor"] = function(t)
		local original = state()
		original.tokens[1].color = Color3.new(0.123, 0.456, 0.789)
		local first = MesaSave.encode(original)
		local second = MesaSave.encode(original)
		same(t, first, second)
		local restored, warnings = MesaSave.decode(first)
		t.eq(#warnings, 0)
		same(t, MesaSave.encode(restored), first)
		first.tokens[1].name = "Alterada"
		t.eq(original.tokens[1].name, "Ficha 1")
		t.eq(second.tokens[1].name, "Ficha 1")
		second.combat.order[1] = "t1"
		t.eq(#original.combat.order, 0)
	end,

	["lacunas preservam ordem e fichas posteriores"] = function(t)
		local encoded = MesaSave.encode(state())
		encoded.tokens[3] = encoded.tokens[2]
		encoded.tokens[2] = nil
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(#restored.tokens, 2)
		t.eq(restored.tokens[2].id, "t2")
		t.eq(#warnings, 1)
	end,

	["registros antigos sem campos opcionais continuam válidos"] = function(t)
		local encoded = MesaSave.encode(state())
		encoded.map = nil
		for _, item in encoded.tokens do item.conditions = nil end
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(encoded.schema, 1)
		t.eq(restored.tokens[1].sheet, nil)
		t.eq(#restored.tokens[1].conditions, 0)
		same(t, restored.map, { terrain = {}, fog = {} })
		t.eq(#warnings, 0)
		local canonical = MesaSave.encode(restored)
		local again, nextWarnings = MesaSave.decode(canonical)
		t.eq(#nextWarnings, 0)
		same(t, MesaSave.encode(again), canonical)
	end,

	["ficha v2 aprovada sobrevive ao salvar e carregar; inválida sai com aviso"] = function(t)
		local original = state()
		original.tokens[1].ficha2 = ficha2()
		local restored = roundtrip(t, original)
		same(t, restored.tokens[1].ficha2, ficha2())
		t.eq(restored.tokens[2].ficha2, nil)
		local encoded = MesaSave.encode(original)
		encoded.tokens[1].ficha2.calculated.armorClass = 100
		local again, warnings = MesaSave.decode(encoded)
		t.eq(again.tokens[1].ficha2, nil)
		t.eq(again.tokens[1].name, "Ficha 1")
		t.eq(#warnings, 1)
		original.tokens[1].ficha2.extra = true
		t.fails(function() MesaSave.encode(original) end)
	end,

	["sheet preserva limites, décimos e falso"] = function(t)
		for _, high in { false, true } do
			local original, imported = state(), sheet()
			for _, field in { "forca", "agilidade", "vigor", "intelecto", "espirito" } do
				imported[field] = if high then 50 else -20
			end
			imported.ca = if high then 99 else 0
			imported.deslocamento = if high then 999 else 0.7
			imported.iniciativa = if high then 50 else -50
			imported.vantagemIniciativa = high
			original.tokens[1].sheet = imported
			local restored = roundtrip(t, original)
			same(t, restored.tokens[1].sheet, imported)
			t.eq(restored.tokens[2].sheet, nil)
		end
	end,

	["sheet inválido mantém ficha e combate com aviso"] = function(t)
		for _, field in { "forca", "agilidade", "vigor", "intelecto", "espirito",
			"ca", "deslocamento", "iniciativa", "vantagemIniciativa" } do
			local encoded = MesaSave.encode(state())
			encoded.tokens[1].sheet = sheet()
			encoded.tokens[1].sheet[field] = nil
			encoded.combat = { active = true, round = 1, order = { "t1", "t2" }, turnIndex = 1, turn = 1 }
			local restored, warnings = MesaSave.decode(encoded)
			t.eq(#restored.tokens, 2, field)
			t.eq(restored.tokens[1].sheet, nil, field)
			t.eq(restored.combat.active, true, field)
			t.eq(#warnings, 1, field)
		end
		for _, invalid in { false, "sheet", 10, {} } do
			local encoded = MesaSave.encode(state())
			encoded.tokens[1].sheet = invalid
			local restored, warnings = MesaSave.decode(encoded)
			t.eq(#restored.tokens, 2)
			t.eq(restored.tokens[1].sheet, nil)
			t.eq(#warnings, 1)
		end
	end,

	["sheet fora dos limites usa validação da importação"] = function(t)
		for _, case in {
			{ "forca", -21 }, { "agilidade", 51 }, { "vigor", 0.5 },
			{ "intelecto", "0" }, { "espirito", math.huge },
			{ "ca", -1 }, { "ca", 100 }, { "ca", 0.5 },
			{ "deslocamento", -0.1 }, { "deslocamento", 999.1 },
			{ "deslocamento", 9.15 }, { "deslocamento", 0 / 0 },
			{ "iniciativa", -51 }, { "iniciativa", 51 }, { "iniciativa", 0.5 },
			{ "vantagemIniciativa", "false" },
		} do
			local encoded = MesaSave.encode(state())
			encoded.tokens[1].sheet = sheet()
			encoded.tokens[1].sheet[case[1]] = case[2]
			local restored, warnings = MesaSave.decode(encoded)
			t.eq(#restored.tokens, 2)
			t.eq(restored.tokens[1].sheet, nil)
			t.eq(#warnings, 1)
		end
	end,

	["sheet é copiado e extras são ignorados"] = function(t)
		local original = state()
		original.tokens[1].sheet = sheet()
		original.tokens[1].sheet.extra = { ignored = true }
		local encoded = MesaSave.encode(original)
		t.eq(encoded.tokens[1].sheet.extra, nil)
		encoded.tokens[1].sheet.extra = "ignorado"
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(#warnings, 0)
		t.eq(restored.tokens[1].sheet.extra, nil)
		restored.tokens[1].sheet.forca = 20
		t.eq(encoded.tokens[1].sheet.forca, 1)
		t.eq(original.tokens[1].sheet.forca, 1)
		encoded.tokens[1].sheet.ca = 1
		t.eq(original.tokens[1].sheet.ca, 13)
	end,

	["encode não apaga sheet inválido silenciosamente"] = function(t)
		local original = state()
		original.tokens[1].sheet = sheet()
		original.tokens[1].sheet.ca = 100
		t.fails(function() MesaSave.encode(original) end)
	end,

	["condições preservam ordem, notas UTF-8 e acúmulos"] = function(t)
		local original = state()
		original.tokens[1].conditions = {
			{ id = "caido", stacks = 1, note = string.rep("ã", 60) },
			{ id = "dose", stacks = 2 },
			{ id = "quebrantado", stacks = 7, note = "" },
		}
		local restored, encoded = roundtrip(t, original)
		same(t, restored.tokens[1].conditions, original.tokens[1].conditions)
		restored.tokens[1].conditions[1].note = "Outra"
		t.eq(encoded.tokens[1].conditions[1].note, string.rep("ã", 60))
		t.eq(original.tokens[1].conditions[1].note, string.rep("ã", 60))
	end,

	["condições inválidas são descartadas sem perder ficha ou combate"] = function(t)
		local encoded = MesaSave.encode(state())
		encoded.tokens[1].conditions = {
			{ id = "desconhecido", stacks = 1 },
			{ id = "dose", stacks = 4 },
			{ id = "caido", stacks = 1, note = string.char(255) },
			{ id = "cego", stacks = 1 },
			{ id = "cego", stacks = 1 },
		}
		encoded.combat = { active = true, round = 1, order = { "t1", "t2" }, turnIndex = 1, turn = 1 }
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(#restored.tokens, 2)
		t.eq(restored.combat.active, true)
		t.eq(#restored.tokens[1].conditions, 1)
		t.eq(restored.tokens[1].conditions[1].id, "cego")
		t.eq(#warnings, 4)
		encoded.tokens[1].conditions = false
		restored, warnings = MesaSave.decode(encoded)
		t.eq(#restored.tokens[1].conditions, 0)
		t.eq(#restored.tokens, 2)
		t.eq(#warnings, 1)
	end,

	["encode recusa condições inválidas sem mutar"] = function(t)
		local original = state()
		original.tokens[1].conditions = { { id = "ausente", stacks = 1 } }
		t.fails(function() MesaSave.encode(original) end)
		t.eq(original.tokens[1].conditions[1].id, "ausente")
	end,

	["mapa usa listas determinísticas e preserva todas as casas"] = function(t)
		local original = state()
		original.map = {
			terrain = { ["20,20"] = "agua", ["1,2"] = "dificil", ["1,1"] = "parede" },
			fog = { ["20,20"] = true, ["1,1"] = true },
		}
		local restored, encoded = roundtrip(t, original)
		t.eq(encoded.map.terrain[1].x, 1)
		t.eq(encoded.map.terrain[1].z, 1)
		t.eq(encoded.map.terrain[2].z, 2)
		t.eq(encoded.map.terrain[3].x, 20)
		same(t, restored.map, original.map)
		restored.map.terrain["1,1"] = "agua"
		t.eq(original.map.terrain["1,1"], "parede")
		t.eq(encoded.map.terrain[1].kind, "parede")
	end,

	["névoa de todo o tabuleiro sobrevive ao salvamento"] = function(t)
		local original = state()
		original.map = { terrain = {}, fog = {} }
		for x = 1, Protocol.BOARD.width do
			for z = 1, Protocol.BOARD.height do original.map.fog[x .. "," .. z] = true end
		end
		local restored, encoded = roundtrip(t, original)
		t.eq(#encoded.map.fog, 400)
		same(t, restored.map, original.map)
	end,

	["mapa inválido descarta só entradas ruins com aviso"] = function(t)
		local encoded = MesaSave.encode(state())
		encoded.map = {
			terrain = {
				{ x = 1, z = 1, kind = "parede" },
				{ x = 0, z = 1, kind = "agua" },
				{ x = 2, z = 2, kind = "lava" },
				{ x = 1, z = 1, kind = "agua" },
				{ x = 20, z = 20, kind = "dificil" },
			},
			fog = {
				{ x = 1, z = 1 }, { x = 21, z = 1 },
				{ x = 1.5, z = 2 }, { x = 1, z = 1 },
			},
		}
		local restored, warnings = MesaSave.decode(encoded)
		t.eq(#restored.tokens, 2)
		t.eq(restored.map.terrain["1,1"], "parede")
		t.eq(restored.map.terrain["20,20"], "dificil")
		t.eq(restored.map.terrain["2,2"], nil)
		t.eq(restored.map.fog["1,1"], true)
		t.eq(#warnings, 6)
	end,

	["mapa trata tipos errados, lacunas e chaves extras"] = function(t)
		local encoded = MesaSave.encode(state())
		encoded.map = false
		local restored, warnings = MesaSave.decode(encoded)
		same(t, restored.map, { terrain = {}, fog = {} })
		t.eq(#warnings, 1)
		encoded.map = { terrain = false, fog = {
			[2] = { x = 2, z = 3 }, extra = { x = 3, z = 4 },
		} }
		restored, warnings = MesaSave.decode(encoded)
		t.eq(restored.map.fog["2,3"], true)
		t.eq(restored.map.fog["3,4"], nil)
		t.eq(#warnings, 3)
	end,

	["encode recusa casas não canônicas, terrenos e névoa inválidos"] = function(t)
		for _, map in {
			{ terrain = { ["01,1"] = "parede" } },
			{ terrain = { ["0,1"] = "parede" } },
			{ terrain = { ["1,1"] = "lava" } },
			{ fog = { ["1,1"] = false } },
			{ fog = false },
		} do
			local original = state()
			original.map = map
			t.fails(function() MesaSave.encode(original) end)
		end
	end,
}
