-- SOMENTE STUDIO: precisa do objeto Random real do Roblox (userdata), que os specs com RNG falso
-- (tabela) nunca exercitam. Regressão: todo ataque era recusado por "Dependências de combate indisponíveis".
local Shared = game:GetService("ReplicatedStorage").Shared
local Combate = require(Shared.EncontroAutonomoCombate)
local Habilidades = require(Shared.EncontroAutonomoHabilidades)

local CATALOGO = { POR_ID = {} }
local RECUSA = "Dependências de combate indisponíveis."

local function naoRecusaPorRng(...)
	local resultado, erro = ...
	return erro ~= RECUSA
end

return {
	["Random real passa na validacao de rng dos ataques"] = function(t)
		local rng = Random.new(7)
		t.eq(typeof(rng), "Random")
		local a, b = { kind = "jogador" }, { kind = "criatura" }
		t.ok(naoRecusaPorRng(Combate.atacarBasico(rng, a, b, CATALOGO)), "atacarBasico")
		t.ok(naoRecusaPorRng(Combate.atacarDistancia(rng, a, b, CATALOGO)), "atacarDistancia")
		t.ok(naoRecusaPorRng(Combate.atacarBarreira(rng, a, b, CATALOGO, false)), "atacarBarreira")
	end,
	["rng ausente ou invalido continua recusado"] = function(t)
		local a, b = { kind = "jogador" }, { kind = "criatura" }
		local _, e1 = Combate.atacarBasico(nil, a, b, CATALOGO)
		local _, e2 = Combate.atacarBasico({}, a, b, CATALOGO)
		local _, e3 = Combate.atacarBasico("x", a, b, CATALOGO)
		t.eq(e1, RECUSA)
		t.eq(e2, RECUSA)
		t.eq(e3, RECUSA)
		t.ok(Habilidades ~= nil)
	end,
}
