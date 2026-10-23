local FichaImport = require(game:GetService("ReplicatedStorage").Shared.FichaImport)

local ATTRIBUTES = { "forca", "agilidade", "vigor", "intelecto", "espirito" }

local function code()
	return {
		mesa = 1,
		nome = "Aria",
		pv = 30,
		pvMax = 34,
		mana = 12,
		manaMax = 16,
		atributos = { forca = 1, agilidade = 3, vigor = 2, intelecto = 0, espirito = 4 },
		ca = 13,
		deslocamento = 9,
		iniciativa = 3,
		vantagemIniciativa = false,
	}
end

local function accepted(t, value)
	local result, failure, warnings = FichaImport.parse(value)
	t.ok(result, tostring(failure))
	t.eq(failure, nil)
	t.eq(type(warnings), "table")
	return result, warnings
end

local function refused(t, value)
	local result, failure, warnings = FichaImport.parse(value)
	t.eq(result, nil)
	t.ok(type(failure) == "string" and #failure > 0)
	t.eq(type(warnings), "table")
	t.eq(#warnings, 0)
end

return {
	["código válido produz dados achatados sem recalcular regras"] = function(t)
		local result, warnings = accepted(t, code())
		t.eq(result.name, "Aria")
		t.eq(result.pv, 30)
		t.eq(result.pvMax, 34)
		t.eq(result.mana, 12)
		t.eq(result.manaMax, 16)
		t.eq(result.sheet.forca, 1)
		t.eq(result.sheet.ca, 13)
		t.eq(result.sheet.deslocamento, 9)
		t.eq(result.sheet.iniciativa, 3)
		t.eq(result.sheet.vantagemIniciativa, false)
		t.eq(result.sheet.atributos, nil)
		t.eq(#warnings, 0)
	end,

	["aceita limites inclusivos de todos os números"] = function(t)
		for _, high in { false, true } do
			local value = code()
			value.pv = if high then 9999 else 0
			value.pvMax = value.pv
			value.mana = value.pv
			value.manaMax = value.pv
			for _, field in ATTRIBUTES do
				value.atributos[field] = if high then 50 else -20
			end
			value.ca = if high then 99 else 0
			value.deslocamento = if high then 999 else 0
			value.iniciativa = if high then 50 else -50
			value.vantagemIniciativa = high
			local result, warnings = accepted(t, value)
			t.eq(result.pv, value.pv)
			t.eq(result.sheet.forca, value.atributos.forca)
			t.eq(result.sheet.vantagemIniciativa, high)
			t.eq(#warnings, 0)
		end
	end,

	["recusa valores fora dos limites e inteiros fracionários"] = function(t)
		for _, field in { "pv", "pvMax", "mana", "manaMax" } do
			for _, invalid in { -1, 10000, 0.5 } do
				local value = code()
				value[field] = invalid
				refused(t, value)
			end
		end
		for _, field in ATTRIBUTES do
			for _, invalid in { -21, 51, 0.5 } do
				local value = code()
				value.atributos[field] = invalid
				refused(t, value)
			end
		end
		for _, field in { "ca", "iniciativa" } do
			local invalids = if field == "ca" then { -1, 100, 0.5 } else { -51, 51, 0.5 }
			for _, invalid in invalids do
				local value = code()
				value[field] = invalid
				refused(t, value)
			end
		end
	end,

	["reduz atuais acima dos máximos com avisos sem modificar a entrada"] = function(t)
		local value = code()
		value.pv = 9999
		value.mana = 9999
		local result, warnings = accepted(t, value)
		t.eq(result.pv, 34)
		t.eq(result.mana, 16)
		t.eq(#warnings, 2)
		t.ok(string.find(warnings[1], "PV", 1, true))
		t.ok(string.find(warnings[2], "Mana", 1, true))
		t.eq(value.pv, 9999)
		t.eq(value.mana, 9999)
		value.pvMax, value.manaMax = 0, 0
		result, warnings = accepted(t, value)
		t.eq(result.pv, 0)
		t.eq(result.mana, 0)
		t.eq(#warnings, 2)
	end,

	["deslocamento aceita décimos e recusa precisão extra"] = function(t)
		for _, movement in { 0, 0.1, 0.7, 8.2, 9.1, 999 } do
			local value = code()
			value.deslocamento = movement
			local result, warnings = accepted(t, value)
			t.eq(result.sheet.deslocamento, movement)
			t.eq(#warnings, 0)
		end
		for _, movement in { -0.1, 999.1, 0.01, 9.15, 9.1001, math.huge, -math.huge, 0 / 0 } do
			local value = code()
			value.deslocamento = movement
			refused(t, value)
		end
	end,

	["nome usa caracteres UTF-8 e exige texto válido"] = function(t)
		for _, name in { "A", string.rep("ã", 32), "Ação Ébria Ígnea Óssea Úmida ãõ" } do
			local value = code()
			value.nome = name
			local result = accepted(t, value)
			t.eq(result.name, name)
		end
		for _, name in { "", "   ", string.rep("ã", 33), "Nome" .. string.char(255) } do
			local value = code()
			value.nome = name
			refused(t, value)
		end
	end,

	["recusa entrada que não é tabela e mesa diferente de um"] = function(t)
		for _, value in { false, 1, "json", function() end } do
			refused(t, value)
		end
		refused(t, nil)
		for _, version in { 0, 2, -1, "1", true, {}, 0 / 0 } do
			local value = code()
			value.mesa = version
			refused(t, value)
		end
		local value = code()
		value.mesa = nil
		refused(t, value)
	end,

	["campos obrigatórios ausentes são recusados"] = function(t)
		for _, field in { "nome", "pv", "pvMax", "mana", "manaMax", "atributos",
			"ca", "deslocamento", "iniciativa", "vantagemIniciativa" } do
			local value = code()
			value[field] = nil
			refused(t, value)
		end
		for _, field in ATTRIBUTES do
			local value = code()
			value.atributos[field] = nil
			refused(t, value)
		end
	end,

	["tipos errados e números não finitos são recusados"] = function(t)
		for _, field in { "pv", "pvMax", "mana", "manaMax", "ca", "deslocamento", "iniciativa" } do
			for _, invalid in { "1", false, {}, function() end, math.huge, -math.huge, 0 / 0 } do
				local value = code()
				value[field] = invalid
				refused(t, value)
			end
		end
		for _, field in ATTRIBUTES do
			for _, invalid in { "1", false, {}, math.huge, 0 / 0 } do
				local value = code()
				value.atributos[field] = invalid
				refused(t, value)
			end
		end
		for _, invalid in { false, 1, {} } do
			local value = code()
			value.nome = invalid
			refused(t, value)
		end
		for _, invalid in { "false", 0, {} } do
			local value = code()
			value.vantagemIniciativa = invalid
			refused(t, value)
		end
		for _, invalid in { "atributos", 1, false } do
			local value = code()
			value.atributos = invalid
			refused(t, value)
		end
	end,

	["campos extras são ignorados e tabelas devolvidas são independentes"] = function(t)
		local value = code()
		value.extra = { segredo = true }
		value.sheet = { forca = 999 }
		value.atributos.extra = "ignorado"
		local result, warnings = accepted(t, value)
		t.eq(result.extra, nil)
		t.eq(result.sheet.extra, nil)
		t.eq(result.sheet.forca, 1)
		t.eq(#warnings, 0)
		result.sheet.forca = 10
		t.eq(value.atributos.forca, 1)
		local second = accepted(t, value)
		t.eq(second.sheet.forca, 1)
	end,

	["parseSheet é reutilizável e devolve cópia sem campos extras"] = function(t)
		local imported = accepted(t, code())
		imported.sheet.extra = "ignorado"
		local sheet, failure = FichaImport.parseSheet(imported.sheet)
		t.ok(sheet)
		t.eq(failure, nil)
		t.eq(sheet.extra, nil)
		sheet.ca = 1
		t.eq(imported.sheet.ca, 13)
		for _, value in { false, "sheet", 10, {} } do
			local invalid, err = FichaImport.parseSheet(value)
			t.eq(invalid, nil)
			t.ok(type(err) == "string")
		end
		t.eq(FichaImport.parseSheet(nil), nil)
	end,
}
