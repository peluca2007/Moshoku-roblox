local Shared = game:GetService("ReplicatedStorage").Shared
local P = require(Shared.Mundo.PropsLayout)
local FlorestaLayout = require(Shared.Mundo.FlorestaLayout)

return {
	["os adereços da vila nao colidem com nada fixo nem entre si"] = function(t)
		local problemas = P.validar()
		t.eq(#problemas, 0, table.concat(problemas, "; "))
	end,
	["toda familia usada existe e tem base positiva"] = function(t)
		for _, prop in P.VILA do
			t.ok(P.FAMILIAS[prop[3]] ~= nil, "familia " .. tostring(prop[3]))
		end
		for nome, f in P.FAMILIAS do
			t.ok(f.base[1] > 0 and f.base[2] > 0 and f.escala > 0, nome)
		end
	end,
	["a floresta e deterministica e gera adereços suficientes"] = function(t)
		local a, b = P.floresta(), P.floresta()
		t.eq(#a, #b)
		t.ok(#a >= 30, "poucos adereços: " .. #a)
		for i, prop in a do
			t.eq(prop[1], b[i][1])
			t.eq(prop[2], b[i][2])
		end
	end,
	["adereços da floresta ficam fora da trilha, da clareira e das arvores"] = function(t)
		local solo = FlorestaLayout.SOLO
		for i, prop in P.floresta() do
			local ret = P.retangulo(prop)
			local nome = prop[3] .. "-" .. i
			t.ok(FlorestaLayout.contem(solo, ret), nome .. " fora do solo")
			t.ok(not FlorestaLayout.sobrepoe(ret, FlorestaLayout.TRILHA), nome .. " na trilha")
			t.ok(not FlorestaLayout.sobrepoe(ret, FlorestaLayout.CLAREIRA), nome .. " na clareira")
			for j, arvore in (if prop[3] == "abeto" or prop[3] == "carvalhoantigo" then {} else FlorestaLayout.ARVORES) do
				t.ok(not FlorestaLayout.sobrepoe(ret, {x=arvore[1],z=arvore[2],sx=2.5,sz=2.5}), nome .. " na arvore " .. j)
			end
		end
	end,
}
