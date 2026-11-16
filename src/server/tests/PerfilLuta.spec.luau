-- Retoque de luz da luta: puro, devolve perfil novo e só aumenta contraste/névoa/brilho.
local Perfis = require(game:GetService("ReplicatedStorage").Shared.Mundo.AmbientePerfis)
local PerfilLuta = require(game:GetService("ReplicatedStorage").Shared.Mundo.PerfilLuta)

return {
	["retoque não altera o perfil original e mexe nas chaves esperadas"] = function(t)
		for nome, base in Perfis.PERFIS do
			local antes = base.ccContraste
			local luta = PerfilLuta.aplicar(base)
			t.ok(luta ~= base and base.ccContraste == antes, "perfil original intacto " .. nome)
			t.ok(luta.ccContraste > base.ccContraste and luta.atmDensidade > base.atmDensidade, "contraste/névoa " .. nome)
			t.ok(luta.bloomIntensidade >= 0.75 and luta.dofLonge >= 0.45, "bloom/desfoque " .. nome)
			t.ok(luta.skybox == base.skybox and luta.clock == base.clock, "céu e hora preservados " .. nome)
		end
	end,
}
