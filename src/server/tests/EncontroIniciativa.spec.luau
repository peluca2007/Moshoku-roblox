local Iniciativa = require(game:GetService("ReplicatedStorage").Shared.EncontroIniciativa)

local function rng(values)
	local indice = 0
	return {
		NextInteger = function(_, minimo, maximo)
			indice += 1
			local valor = values[indice]
			assert(valor and valor >= minimo and valor <= maximo, "sequência de RNG insuficiente ou inválida")
			return valor
		end,
	}
end

return {
	["rola d20 e desempata por bonus depois pela ordem recebida"] = function(t)
		local ordem, rolagens = Iniciativa.ordenar({
			{ id = "a", bonus = 2, advantage = false },
			{ id = "b", bonus = 4, advantage = false },
			{ id = "c", bonus = 4, advantage = false },
		}, rng({ 10, 8, 8 }))
		t.eq(ordem[1].id, "b")
		t.eq(ordem[2].id, "c")
		t.eq(ordem[3].id, "a")
		t.eq(rolagens[1].total, 12)
		t.eq(rolagens[2].actorId, "c")
	end,
	["vantagem usa o maior de dois d20 antes de somar bonus"] = function(t)
		local ordem, rolagens = Iniciativa.ordenar({
			{ id = "caçador", bonus = 3, advantage = true },
			{ id = "alvo", bonus = 0, advantage = false },
		}, rng({ 3, 18, 17 }))
		t.eq(ordem[1].id, "caçador")
		t.eq(rolagens[1].natural, 18)
		t.eq(rolagens[1].total, 21)
	end,
	["aceita Random nativo do servidor"] = function(t)
		if Random == nil then return end -- Luau CLI não fornece o tipo Roblox Random.
		local ordem, rolagens = Iniciativa.ordenar({
			{ id = "jogador", bonus = 0, advantage = false },
			{ id = "criatura", bonus = 0, advantage = false },
		}, Random.new(481516))
		t.eq(#ordem, 2)
		t.eq(#rolagens, 2)
	end,
	["recusa participante repetido bonus fora do intervalo e vantagem nao booleana"] = function(t)
		local ordem = Iniciativa.ordenar({
			{ id = "a", bonus = 0, advantage = false },
			{ id = "a", bonus = 0, advantage = false },
		}, rng({}))
		t.eq(ordem, nil)
		ordem = Iniciativa.ordenar({
			{ id = "a", bonus = 51, advantage = false },
			{ id = "b", bonus = 0, advantage = false },
		}, rng({}))
		t.eq(ordem, nil)
		ordem = Iniciativa.ordenar({
			{ id = "a", bonus = 0, advantage = "sim" },
			{ id = "b", bonus = 0, advantage = false },
		}, rng({}))
		t.eq(ordem, nil)
	end,
}
