local Shared = game:GetService("ReplicatedStorage").Shared
local Cone = require(Shared.Regras.VisaoCone)

return {
	["aceita alvo dentro do angulo e alcance"] = function(t)
		t.ok(Cone.dentro({ x = 0, z = 0 }, { x = 0, z = 1 }, { x = 2, z = 8 }, 10, 60))
	end,
	["rejeita alvo fora do angulo ou alcance"] = function(t)
		t.eq(Cone.dentro({ x = 0, z = 0 }, { x = 0, z = 1 }, { x = 8, z = 2 }, 10, 60), false)
		t.eq(Cone.dentro({ x = 0, z = 0 }, { x = 0, z = 1 }, { x = 0, z = 11 }, 10, 180), false)
	end,
	["oclusao usa callback injetado e agachado reduz alcance"] = function(t)
		local chamada = false
		local parede = Cone.detecta({ x = 0, z = 0 }, { x = 0, z = 1 }, { x = 0, z = 5 }, 20, 100, function()
			chamada = true
			return false
		end)
		t.eq(parede, false, "parede oculta alvo")
		t.ok(chamada, "oclusao consultada apenas depois da geometria")
		t.eq(Cone.detecta({ x = 0, z = 0 }, { x = 0, z = 1 }, { x = 0, z = 5 }, 6, 100, function() return true end), true,
			"agachado usa alcance menor, alvo ainda perto")
		t.eq(Cone.detecta({ x = 0, z = 0 }, { x = 0, z = 1 }, { x = 0, z = 8 }, 6, 100, function() return true end), false,
			"alvo distante do alcance reduzido")
	end,
}
