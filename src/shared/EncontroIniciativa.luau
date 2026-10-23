-- Ordena a iniciativa automática conforme RB-13; RNG e roster vêm do servidor.
local Dice = require(game:GetService("ReplicatedStorage").Shared.Dice)

local EncontroIniciativa = {}
local D20 = Dice.parse("1d20")

function EncontroIniciativa.ordenar(atores, rng)
	local rngAcessivel, nextInteger = pcall(function() return rng.NextInteger end)
	if type(atores) ~= "table" or #atores < 2 or #atores > 16
		or not rngAcessivel or type(nextInteger) ~= "function"
	then
		return nil, nil, "Lista de iniciativa inválida."
	end
	local vistos = {}
	for _, ator in ipairs(atores) do
		if type(ator) ~= "table"
			or type(ator.id) ~= "string" or #ator.id == 0 or #ator.id > 96 or vistos[ator.id]
			or type(ator.bonus) ~= "number" or ator.bonus % 1 ~= 0 or ator.bonus < -50 or ator.bonus > 50
			or type(ator.advantage) ~= "boolean"
		then
			return nil, nil, "Participante ou bônus de iniciativa inválido."
		end
		vistos[ator.id] = true
	end
	-- Recusa a lista inteira antes de consumir qualquer resultado aleatório.
	local rolls = {}
	for indice, ator in ipairs(atores) do
		local resultado = Dice.roll(rng, D20, if ator.advantage then "vantagem" else "normal")
		table.insert(rolls, {
			actor = table.clone(ator),
			bonus = ator.bonus,
			natural = resultado.natural,
			total = resultado.total + ator.bonus,
			text = resultado.text,
			index = indice,
		})
	end
	table.sort(rolls, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		if a.bonus ~= b.bonus then return a.bonus > b.bonus end
		return a.index < b.index
	end)
	local ordem, detalhes = {}, {}
	for _, resultado in ipairs(rolls) do
		table.insert(ordem, resultado.actor)
		table.insert(detalhes, {
			actorId = resultado.actor.id,
			bonus = resultado.bonus,
			natural = resultado.natural,
			total = resultado.total,
			text = resultado.text,
		})
	end
	return ordem, detalhes
end

return EncontroIniciativa
