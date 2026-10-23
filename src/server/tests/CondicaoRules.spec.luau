local Shared = game:GetService("ReplicatedStorage").Shared
local Rules = require(Shared.CondicaoRules)
local Catalog = require(Shared.Condicoes)

local function find(list, id)
	for _, item in list do
		if item.id == id then return item end
	end
	return nil
end

local function fixture()
	local entries = {
		{ id = "dose", nome = "Dose", acumulavel = true, teto = 3, vira = "atordoado" },
		{ id = "atordoado", nome = "Atordoado", acumulavel = false },
		{ id = "quebrantado", nome = "Quebrantado", acumulavel = true },
	}
	local catalog = { LISTA = entries, POR_ID = {}, TETO_PADRAO = 7 }
	for _, entry in entries do catalog.POR_ID[entry.id] = entry end
	for index = 1, 12 do
		local entry = { id = "c" .. index, nome = "Condição " .. index, acumulavel = false }
		table.insert(catalog.LISTA, entry)
		catalog.POR_ID[entry.id] = entry
	end
	return catalog
end

return {
	["adiciona sem mutar lista nem entradas e mantém ordem"] = function(t)
		local original = { { id = "caido", stacks = 1, note = "Até levantar" } }
		local result, failure, messages = Rules.add(original, Catalog, "cego")
		t.eq(failure, nil)
		t.eq(#result, 2)
		t.eq(result[1].id, "caido")
		t.eq(result[2].id, "cego")
		t.eq(result[2].stacks, 1)
		t.eq(#original, 1)
		result[1].note = "Mudou"
		t.eq(original[1].note, "Até levantar")
		t.eq(#messages, 0)
	end,

	["não acumulável troca nota apenas quando informada"] = function(t)
		local original = { { id = "caido", stacks = 1, note = "Antes" } }
		local result, failure = Rules.add(original, Catalog, "caido")
		t.eq(failure, nil)
		t.eq(#result, 1)
		t.eq(result[1].note, "Antes")
		result = Rules.add(original, Catalog, "caido", 1, "")
		t.eq(result[1].note, "")
		t.eq(original[1].note, "Antes")
		result, failure = Rules.add(original, Catalog, "caido", 2)
		t.eq(result, nil)
		t.ok(failure)
	end,

	["acumulável soma e limita ao teto do catálogo recebido"] = function(t)
		local catalog = fixture()
		local original = { { id = "quebrantado", stacks = 2 } }
		local result, failure = Rules.add(original, catalog, "quebrantado", 3)
		t.eq(failure, nil)
		t.eq(result[1].stacks, 5)
		local messages
		result, failure, messages = Rules.add(result, catalog, "quebrantado", 20)
		t.eq(failure, nil)
		t.eq(result[1].stacks, 7)
		t.ok(#messages > 0)
		t.eq(original[1].stacks, 2)
		catalog.TETO_PADRAO = 14
		result = Rules.add({}, catalog, "quebrantado", 20)
		t.eq(result[1].stacks, 14)
	end,

	["dose transforma ao alcançar ou ultrapassar o teto"] = function(t)
		for _, amount in { 1, 20 } do
			local original = { { id = "dose", stacks = 2, note = "Veneno" } }
			local result, failure, messages = Rules.add(original, Catalog, "dose", amount)
			t.eq(failure, nil)
			t.eq(find(result, "dose"), nil)
			t.eq(find(result, "atordoado").stacks, 1)
			t.eq(find(result, "atordoado").note, "Veneno")
			t.eq(original[1].stacks, 2)
			t.ok(string.find(messages[1], "Atordoado", 1, true))
		end
	end,

	["transformação não duplica destino e conserva nota sem nova nota"] = function(t)
		local original = {
			{ id = "atordoado", stacks = 1, note = "Anterior" },
			{ id = "dose", stacks = 2 },
		}
		local result, failure = Rules.add(original, Catalog, "dose")
		t.eq(failure, nil)
		t.eq(#result, 1)
		t.eq(result[1].note, "Anterior")
		result = Rules.add(original, Catalog, "dose", 1, "Colapso")
		t.eq(result[1].note, "Colapso")
	end,

	["limite é aplicado ao resultado final da transformação"] = function(t)
		local catalog = fixture()
		local original = { { id = "dose", stacks = 2 } }
		for index = 1, 11 do table.insert(original, { id = "c" .. index, stacks = 1 }) end
		local result, failure = Rules.add(original, catalog, "dose")
		t.eq(failure, nil)
		t.eq(#result, 12)
		t.ok(find(result, "atordoado"))
		result, failure = Rules.add(original, catalog, "c12")
		t.eq(result, nil)
		t.ok(failure)
		t.eq(#original, 12)
		t.ok(find(original, "dose"))
	end,

	["transformação inválida ou cíclica cancela tudo"] = function(t)
		local catalog = fixture()
		catalog.POR_ID.dose.vira = "ausente"
		local original = { { id = "dose", stacks = 2 } }
		local result, failure, messages = Rules.add(original, catalog, "dose")
		t.eq(result, nil)
		t.ok(failure)
		t.eq(#messages, 0)
		t.eq(original[1].stacks, 2)
		catalog.POR_ID.dose.vira = "dose"
		result, failure = Rules.add(original, catalog, "dose", 3)
		t.eq(result, nil)
		t.ok(failure)
	end,

	["remove acúmulos ou condição inteira sem mutar"] = function(t)
		local original = {
			{ id = "quebrantado", stacks = 5, note = "Fonte" },
			{ id = "cego", stacks = 1 },
		}
		local result, failure = Rules.remove(original, Catalog, "quebrantado", 2)
		t.eq(failure, nil)
		t.eq(result[1].stacks, 3)
		t.eq(result[1].note, "Fonte")
		t.eq(original[1].stacks, 5)
		result = Rules.remove(original, Catalog, "quebrantado", 20)
		t.eq(#result, 1)
		t.eq(result[1].id, "cego")
		result = Rules.remove(original, Catalog, "quebrantado")
		t.eq(#result, 1)
		result = Rules.remove(original, Catalog, "caido")
		t.eq(#result, 2)
		t.ok(result[1] ~= original[1])
	end,

	["id desconhecido e tipos de acúmulos inválidos são recusados"] = function(t)
		for _, method in { Rules.add, Rules.remove } do
			local result, failure = method({}, Catalog, "não-existe")
			t.eq(result, nil)
			t.ok(failure)
			for _, value in { 0, -1, 21, 1.5, "1", false, math.huge, 0 / 0 } do
				result, failure = method({}, Catalog, "dose", value)
				t.eq(result, nil)
				t.ok(failure)
			end
		end
	end,

	["nota aceita sessenta caracteres e recusa tipos ou UTF-8 inválidos"] = function(t)
		local note = string.rep("ã", 60)
		local result, failure = Rules.add({}, Catalog, "caido", nil, note)
		t.eq(failure, nil)
		t.eq(result[1].note, note)
		for _, invalid in { string.rep("ã", 61), string.char(255), false, 10, {} } do
			result, failure = Rules.add({}, Catalog, "caido", nil, invalid)
			t.eq(result, nil)
			t.ok(failure)
		end
	end,

	["validate descarta inválidos e preserva primeira ocorrência válida"] = function(t)
		local raw = {
			{ id = "desconhecido", stacks = 1 },
			{ id = "dose", stacks = 0 },
			{ id = "dose", stacks = 2, extra = true },
			{ id = "dose", stacks = 1 },
			{ id = "cego", stacks = 2 },
			{ id = "caido", stacks = 1, note = string.rep("x", 61) },
			{ id = "atordoado", stacks = 1 },
		}
		local result, warnings = Rules.validate(raw, Catalog)
		t.eq(#result, 2)
		t.eq(result[1].id, "dose")
		t.eq(result[1].stacks, 2)
		t.eq(result[1].extra, nil)
		t.eq(result[2].id, "atordoado")
		t.eq(#warnings, 5)
		t.eq(raw[3].extra, true)
		result[1].stacks = 1
		t.eq(raw[3].stacks, 2)
	end,

	["validate não inventa transformação durante leitura"] = function(t)
		local result, warnings = Rules.validate({ { id = "dose", stacks = 3 } }, Catalog)
		t.eq(#warnings, 0)
		t.eq(result[1].id, "dose")
		t.eq(result[1].stacks, 3)
	end,

	["validate trata ausentes, tipos, lacunas, extras e excesso"] = function(t)
		local result, warnings = Rules.validate(nil, Catalog)
		t.eq(#result, 0)
		t.eq(#warnings, 0)
		for _, raw in { false, 10, "lista" } do
			result, warnings = Rules.validate(raw, Catalog)
			t.eq(#result, 0)
			t.ok(#warnings > 0)
		end
		result, warnings = Rules.validate({
			[3] = { id = "cego", stacks = 1 },
			[1] = { id = "caido", stacks = 1 },
			extra = { id = "dose", stacks = 1 },
		}, Catalog)
		t.eq(result[1].id, "caido")
		t.eq(result[2].id, "cego")
		t.eq(#warnings, 2)
		local catalog = fixture()
		local raw = {}
		for index = 1, 12 do table.insert(raw, { id = "c" .. index, stacks = 1 }) end
		table.insert(raw, { id = "quebrantado", stacks = 1 })
		result, warnings = Rules.validate(raw, catalog)
		t.eq(#result, 12)
		t.eq(#warnings, 1)
	end,

	["comandos recusam lista atual inválida sem saneamento silencioso"] = function(t)
		local original = { { id = "caido", stacks = 2 } }
		for _, method in { Rules.add, Rules.remove } do
			local result, failure = method(original, Catalog, "cego")
			t.eq(result, nil)
			t.ok(failure)
			t.eq(original[1].stacks, 2)
		end
	end,

	["labels usam nomes do catálogo e acúmulos sem revelar notas"] = function(t)
		local labels = Rules.labels({
			{ id = "caido", stacks = 1, note = "Segredo" },
			{ id = "dose", stacks = 2 },
		}, Catalog)
		t.eq(labels[1], "Caído")
		t.eq(labels[2], "Dose ×2")
		t.eq(#labels, 2)
	end,
}
