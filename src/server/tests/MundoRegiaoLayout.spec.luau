local Shared = game:GetService("ReplicatedStorage").Shared
local R = require(Shared.Mundo.RegiaoLayout)
local P = require(Shared.Mundo.PropsLayout)

return {
	["pecas do acampamento ficam na zona, fora das trilhas e das pecas fixas"] = function(t)
		local problemas = R.validar()
		t.eq(#problemas, 0, table.concat(problemas, "; "))
	end,
	["o campo e deterministico, denso e longe de trilhas, arenas, acampamento e arvores"] = function(t)
		local a, b = R.campo(), R.campo()
		t.eq(#a, #b)
		t.ok(#a >= 60, "poucas pecas no campo: " .. #a)
		for i, prop in a do
			t.eq(prop[1], b[i][1])
			t.eq(prop[2], b[i][2])
			t.ok(not R.proibido(prop[1], prop[2], 0), "peca " .. i .. " em area proibida")
		end
	end,
	["dentroDaTrilha usa o giro: o centro da trilha do acampamento esta dentro, um ponto longe nao"] = function(t)
		local trilha = R.TRILHAS[4]
		t.ok(R.dentroDaTrilha(trilha[1], trilha[2], trilha, 0))
		t.ok(not R.dentroDaTrilha(0, 90, trilha, 0))
		-- ponta oeste da trilha (junto ao acampamento): ~(-20.8, -31.2)
		t.ok(R.dentroDaTrilha(-20, -31, trilha, 0))
	end,
	["familias do acampamento existem com modelos e base positiva"] = function(t)
		for _, p in R.PECAS do
			local f = P.FAMILIAS[p[3]]
			t.ok(f ~= nil and #f.modelos >= 1 and f.base[1] > 0, tostring(p[3]))
		end
	end,
}
