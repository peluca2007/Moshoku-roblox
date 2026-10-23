-- Vínculo autoritativo, CD de escape e disputa. Sem estado global.
local Combate = require(game:GetService("ReplicatedStorage").Shared.Regras.Combate)
local A = {}
function A.disputa(rng, forca, resistencia)
	local total = Combate.d20(rng).natural + forca
	local defesa = Combate.d20(rng).natural + resistencia
	return total > defesa, total, defesa
end
function A.escapar(rng, bonus, cd, desvantagem)
	return Combate.resistencia(rng, bonus, cd, false, desvantagem)
end
function A.valido(vinculo, fonte, alvo, distancia)
	return fonte ~= nil and alvo ~= nil and fonte.pv > 0 and alvo.pv > 0 and not fonte.derrotado
		and not alvo.derrotado and (vinculo.sustenta or distancia <= 1)
end
return A
