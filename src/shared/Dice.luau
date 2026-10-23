-- Motor puro. Limites e modos combinados em docs/MESA.md e docs/TAREFAS.md.
-- Spec é produzido por parse; RNG injetado permite reproduzir os testes.
local Dice = {}

export type Term = { count: number, sides: number, sign: number }
export type Spec = { formula: string, terms: { Term }, modifier: number }
export type Rng = { NextInteger: (any, number, number) -> number }

local labels = {
	normal = "normal",
	vantagem = "vantagem",
	desvantagem = "desvantagem",
	vantagemAbsoluta = "vantagem absoluta",
	desvantagemAbsoluta = "desvantagem absoluta",
}

function Dice.parse(text: any): (Spec?, string?)
	if type(text) ~= "string" then
		return nil, "A fórmula precisa ser um texto."
	end
	if #text > 60 then
		return nil, "A fórmula pode ter até 60 caracteres."
	end
	local formula = string.lower((string.gsub(text, "%s", "")))
	if formula == "" then
		return nil, "Informe uma fórmula, por exemplo 1d20+4."
	end
	local terms, modifier, totalDice, termCount = {}, 0, 0, 0
	local position = 1
	while position <= #formula do
		local sign = 1
		local first = string.sub(formula, position, position)
		if first == "+" or first == "-" then
			sign = if first == "-" then -1 else 1
			position += 1
		elseif termCount > 0 then
			return nil, "Separe os termos com + ou -."
		end
		local finish = position
		while finish <= #formula and not string.find("+-", string.sub(formula, finish, finish), 1, true) do
			finish += 1
		end
		local atom = string.sub(formula, position, finish - 1)
		termCount += 1
		if termCount > 10 then
			return nil, "Use no máximo 10 termos na fórmula."
		end
		local countText, sidesText = string.match(atom, "^(%d*)d(%d+)$")
		if countText then
			local count = if countText == "" then 1 else tonumber(countText)
			local sides = tonumber(sidesText)
			if not count or count < 1 or count > 50 then
				return nil, "Cada termo precisa ter entre 1 e 50 dados."
			end
			if not sides or sides < 2 or sides > 1000 then
				return nil, "Cada dado precisa ter entre 2 e 1000 faces."
			end
			totalDice += count
			if totalDice > 100 then
				return nil, "Use no máximo 100 dados no total."
			end
			table.insert(terms, { count = count, sides = sides, sign = sign })
		elseif string.match(atom, "^%d+$") then
			local value = tonumber(atom)
			-- Números maiores que inteiros exatos não são modificadores válidos.
			if not value or value > 2 ^ 53 - 1 then
				return nil, "Modificador inválido."
			end
			modifier += sign * value
			if math.abs(modifier) > 2 ^ 53 - 1 then
				return nil, "Modificador fora do intervalo de inteiros exatos."
			end
		else
			return nil, "Fórmula inválida. Use dados e inteiros, por exemplo 1d8+1d6-1."
		end
		position = finish
	end
	-- Sinal final não é um termo; a iteração acima precisa rejeitá-lo.
	if string.match(formula, "[+-]$") then
		return nil, "A fórmula não pode terminar com + ou -."
	end
	if #terms == 0 then
		return nil, "A fórmula precisa conter pelo menos um dado."
	end
	if math.abs(modifier) > 1000 then
		return nil, "O modificador total precisa ficar entre -1000 e 1000."
	end
	return { formula = formula, terms = terms, modifier = modifier }, nil
end

function Dice.roll(rng: Rng, spec: Spec, mode: string?)
	local selectedMode = if mode and labels[mode] then mode else "normal"
	-- Modo e natural só valem para um único d20 somado: em "10-d20", vantagem
	-- pioraria o total e o 20 viraria crítico num dado subtraído (D-5).
	local d20Count, positiveD20 = 0, false
	for _, term in spec.terms do
		if term.sides == 20 then
			d20Count += term.count
			positiveD20 = term.sign > 0
		end
	end
	local singleD20 = d20Count == 1 and positiveD20
	local useMode = singleD20 and selectedMode ~= "normal"
	local total, natural = spec.modifier, nil
	local details = {}
	for _, term in spec.terms do
		local values, subtotal = {}, 0
		if useMode and term.sides == 20 then
			local count = if selectedMode == "vantagemAbsoluta" or selectedMode == "desvantagemAbsoluta" then 3 else 2
			for _ = 1, count do
				table.insert(values, rng:NextInteger(1, 20))
			end
			local high = selectedMode == "vantagem" or selectedMode == "vantagemAbsoluta"
			subtotal = values[1]
			for _, value in values do
				subtotal = if high then math.max(subtotal, value) else math.min(subtotal, value)
			end
		else
			for _ = 1, term.count do
				local value = rng:NextInteger(1, term.sides)
				table.insert(values, value)
				subtotal += value
			end
		end
		if singleD20 and term.sides == 20 then
			natural = subtotal
		end
		total += term.sign * subtotal
		local strings = {}
		for _, value in values do
			table.insert(strings, tostring(value))
		end
		local detail = string.format("%sd%d: [%s]", if term.sign < 0 then "-" .. term.count else tostring(term.count), term.sides, table.concat(strings, ", "))
		if useMode and term.sides == 20 then
			detail ..= " → " .. subtotal
		end
		table.insert(details, detail)
	end
	local suffix = ""
	if useMode then
		suffix = " (" .. labels[selectedMode] .. ")"
	elseif selectedMode ~= "normal" then
		suffix = " (modo ignorado)"
	end
	local fixed = if spec.modifier ~= 0 then string.format("; modificador %+d", spec.modifier) else ""
	return {
		total = total,
		text = string.format("%s%s: %s%s = %d", spec.formula, suffix, table.concat(details, "; "), fixed, total),
		natural = natural,
		critical = if natural == 20 then "sucesso" elseif natural == 1 then "falha" else nil,
	}
end

return Dice
