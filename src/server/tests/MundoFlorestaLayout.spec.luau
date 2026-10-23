local Shared = game:GetService("ReplicatedStorage").Shared
local Floresta = require(Shared.Mundo.FlorestaLayout)
local Vila = require(Shared.Mundo.VilaLayout)

return {
	["floresta nao sobrepoe regiao nem vila e percurso conecta as bordas"] = function(t)
		local regioInicial = { x = 0, z = 0, sx = 240, sz = 240 }
		local problemas = Floresta.validar(Vila.SOLO, regioInicial)
		t.eq(#problemas, 0, table.concat(problemas, "; "))
		t.eq(Vila.SOLO.z - Vila.SOLO.sz / 2, -300)
		t.eq(Vila.TRILHA_FLORESTA.z + Vila.TRILHA_FLORESTA.sz / 2, -300)
		t.eq(Floresta.TRILHA.z + Floresta.TRILHA.sz / 2, -350)
		t.eq(Floresta.TRILHA.z - Floresta.TRILHA.sz / 2, Floresta.CLAREIRA.z + Floresta.CLAREIRA.sz / 2)
	end,
	["arvoredo denso respeita corredor e clareira"] = function(t)
		t.ok(#Floresta.ARVORES >= 30)
		for indice, arvore in ipairs(Floresta.ARVORES) do
			local ret = Floresta.arvoreRetangulo(arvore, indice)
			t.ok(Floresta.contem(Floresta.SOLO, ret), ret.id)
			t.ok(not Floresta.sobrepoe(ret, Floresta.TRILHA), ret.id .. " bloqueia trilha")
			t.ok(not Floresta.sobrepoe(ret, Floresta.CLAREIRA), ret.id .. " bloqueia clareira")
		end
	end,
}
