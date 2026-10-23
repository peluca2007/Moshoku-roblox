local Dice = require(game:GetService("ReplicatedStorage").Shared.Dice)

local function sequence(values)
	local index = 0
	return {
		NextInteger = function(_, low, high)
			index += 1
			local value = values[index]
			assert(value ~= nil and value >= low and value <= high, "RNG recebeu uma chamada inesperada")
			return value
		end,
		calls = function() return index end,
	}
end

local function roll(formula, values, mode)
	local spec, failure = Dice.parse(formula)
	assert(spec, failure)
	local rng = sequence(values)
	return Dice.roll(rng, spec, mode), rng
end

return {
	["fórmulas aceitas e limites inclusivos"] = function(t)
		for _, formula in { "d20", "1d20+4", "2d6+3", "1d8+1d6-1", " 2D6 + 3 ", "50d1000+50d2+1000", "1d2-1000", "1d20+2000-1000", "d2+1+1+1+1+1+1+1+1+1", "d2" .. string.rep(" ", 58) } do
			local spec, err = Dice.parse(formula)
			t.ok(spec ~= nil, formula .. ": " .. tostring(err))
			t.eq(err, nil)
		end
	end,
	["recusa sintaxe malformada e limites excedidos"] = function(t)
		for _, formula in { "", " ", "abc", "20", "0d6", "d1", "d0", "1.5d6", "d6.5", "d6+0.5", "d6++1", "d6--1", "d6+", "d6-", "d6/2", "d6*2", "d6foo", "51d6", "d1001", "50d6+50d6+d6", "d6+1001", "d6-1001", "d6+1+1+1+1+1+1+1+1+1+1", "d6" .. string.rep(" ", 59), "d6+999999999999999999999999999999" } do
			local spec, err = Dice.parse(formula)
			t.eq(spec, nil, formula)
			t.ok(type(err) == "string" and #err > 0, formula)
		end
		for _, value in { false, 5, {}, function() end } do
			local spec, err = Dice.parse(value)
			t.eq(spec, nil)
			t.ok(type(err) == "string")
		end
		t.eq(Dice.parse(nil), nil)
	end,
	["soma cada dado e modificadores de fórmulas compostas"] = function(t)
		local result, rng = roll("1d8+2d6-1", { 8, 3, 4 })
		t.eq(result.total, 14)
		t.eq(rng.calls(), 3)
		t.eq(result.natural, nil)
		t.ok(string.find(result.text, "[3, 4]", 1, true) ~= nil)
		t.ok(string.find(result.text, "modificador -1", 1, true) ~= nil)
	end,
	["vantagem mantém maior e desvantagem mantém menor"] = function(t)
		local a, arng = roll("d20+4", { 7, 17 }, "vantagem")
		local b, brng = roll("d20+4", { 7, 17 }, "desvantagem")
		t.eq(a.natural, 17); t.eq(a.total, 21); t.eq(arng.calls(), 2)
		t.eq(b.natural, 7); t.eq(b.total, 11); t.eq(brng.calls(), 2)
		t.ok(string.find(a.text, "vantagem", 1, true) ~= nil)
	end,
	["absolutas rolam três e crítico usa o dado escolhido"] = function(t)
		local a, arng = roll("d20-3", { 1, 12, 20 }, "vantagemAbsoluta")
		local b, brng = roll("d20+1000", { 20, 12, 1 }, "desvantagemAbsoluta")
		t.eq(arng.calls(), 3); t.eq(a.total, 17); t.eq(a.critical, "sucesso")
		t.eq(brng.calls(), 3); t.eq(b.total, 1001); t.eq(b.critical, "falha")
		local c = roll("d20", { 1, 12 }, "vantagem")
		t.eq(c.critical, nil)
		local d = roll("d20", { 20, 12 }, "desvantagem")
		t.eq(d.critical, nil)
	end,
	["normal rola uma vez e reconhece 1 e 20 naturais"] = function(t)
		local a, rng = roll("d20+4", { 20 })
		t.eq(rng.calls(), 1); t.eq(a.total, 24); t.eq(a.critical, "sucesso")
		local b = roll("d20-4", { 1 }, "normal")
		t.eq(b.total, -3); t.eq(b.critical, "falha")
	end,
	["modo ignorado não consome dados extras nem cria crítico"] = function(t)
		for _, formula in { "2d20", "d20+d20", "2d6" } do
			local values = if formula == "2d6" then { 6, 1 } else { 20, 1 }
			local result, rng = roll(formula, values, "vantagemAbsoluta")
			t.eq(result.total, if formula == "2d6" then 7 else 21); t.eq(result.natural, nil); t.eq(result.critical, nil)
			t.eq(rng.calls(), 2)
			t.ok(string.find(result.text, "(modo ignorado)", 1, true) ~= nil)
		end
	end,
	["um d20 com dados adicionais aplica o modo só ao d20"] = function(t)
		local result, rng = roll("d20+d6+4", { 7, 17, 6 }, "vantagem")
		t.eq(result.natural, 17); t.eq(result.total, 27); t.eq(rng.calls(), 3)
		local ignored, ignoredRng = roll("d20+2d20+d6", { 20, 1, 10, 6 }, "vantagemAbsoluta")
		t.eq(ignored.natural, nil); t.eq(ignored.total, 37); t.eq(ignoredRng.calls(), 4)
		t.ok(string.find(ignored.text, "modo ignorado", 1, true) ~= nil)
	end,
	["d20 subtraído ignora modo e não gera natural nem crítico"] = function(t)
		local normal, normalRng = roll("10-d20", { 20 })
		t.eq(normal.total, -10); t.eq(normal.natural, nil); t.eq(normal.critical, nil); t.eq(normalRng.calls(), 1)
		local mode, modeRng = roll("10-d20", { 1 }, "vantagem")
		t.eq(mode.total, 9); t.eq(mode.natural, nil); t.eq(mode.critical, nil); t.eq(modeRng.calls(), 1)
		t.ok(string.find(mode.text, "(modo ignorado)", 1, true) ~= nil)
	end,
}
