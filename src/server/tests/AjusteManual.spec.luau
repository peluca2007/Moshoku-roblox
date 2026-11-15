local A = require(game:GetService("ReplicatedStorage").Shared.Regras.AjusteManual)

return {
	["jogador sem mestre não ajusta PV na luta do mundo nem no PvP"] = function(t)
		local ok, motivo = A.permitido({ mestre = false, admin = false, encontro = { modo = "luta", mundo = true } })
		t.eq(ok, false); t.eq(motivo, A.MOTIVO)
		t.eq((A.permitido({ mestre = false, admin = false, encontro = { modo = "duelo", mundo = false } })), false)
	end,
	["modo mesa (sem encontro de jogo) e luta da sala seguem permitidos"] = function(t)
		t.eq((A.permitido({ mestre = false, admin = false, encontro = nil })), true)
		t.eq((A.permitido({ mestre = false, admin = false, encontro = { modo = "luta", mundo = false } })), true)
	end,
	["mestre e administrador continuam arbitrando"] = function(t)
		t.eq((A.permitido({ mestre = true, admin = false, encontro = { modo = "luta", mundo = true } })), true)
		t.eq((A.permitido({ mestre = false, admin = true, encontro = { modo = "luta", mundo = true } })), true)
	end,
	["contexto inválido é recusado"] = function(t)
		t.eq((A.permitido(nil)), false)
	end,
}
