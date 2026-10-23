local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Mundo.ChaoLayout)
local R = require(Shared.Mundo.RegiaoLayout)

return {
	["manchas de chao nao cobrem vias, praca, predios nem clareira"] = function(t)
		local problemas = C.validar()
		t.eq(#problemas, 0, table.concat(problemas, "; "))
	end,
	["a geracao e deterministica e atinge a quantidade pedida"] = function(t)
		local a, b = C.floresta(), C.floresta()
		t.eq(#a, #b)
		t.ok(#a >= 70, "poucas manchas na floresta: " .. #a)
		t.ok(#C.vila() >= 30, "poucas manchas na vila: " .. #C.vila())
		t.ok(#C.ruinas() >= 50, "poucas manchas nas ruinas: " .. #C.ruinas())
		for i, m in a do
			t.eq(m[1], b[i][1])
			t.eq(m[2], b[i][2])
		end
	end,
	["manchas da regiao inicial ficam fora de trilhas, arenas, acampamento e arvores"] = function(t)
		local lista = C.regiao()
		t.ok(#lista >= 40, "poucas manchas na regiao: " .. #lista)
		for i, m in lista do
			t.ok(not R.proibido(m[1], m[2], m[3] - 0.3), "mancha " .. i .. " em area proibida") -- 0,3: tolera o arredondamento dos dados
		end
	end,
	["todo tipo usado existe e a camada fica entre 0 e 3"] = function(t)
		for _, lista in { C.vila(), C.floresta(), C.ruinas(), C.regiao() } do
			for _, m in lista do
				t.ok(C.TIPOS[m[4]] ~= nil, tostring(m[4]))
				t.ok(m[5] >= 0 and m[5] <= 3)
				t.ok(m[3] > 0)
			end
		end
	end,
}
