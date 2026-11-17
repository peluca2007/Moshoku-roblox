-- HAB8: destaques do golpe (combo do Golpe Contínuo, Dano Furtivo e triplo do Primeiro Golpe), puro.
local D = require(game:GetService("ReplicatedStorage").Shared.DestaquesGolpe)

return {
	["sem dados de destaque, nada"] = function(t)
		t.eq(#D.listar({ acertou = true, dano = 5 }), 0)
		t.eq(#D.listar(nil), 0)
		t.eq(D.prefixo({ { acertou = true, dano = 3 } }), "")
	end,
	["triplo do Primeiro Golpe é forte e mostra o total do furtivo"] = function(t)
		local l = D.listar({ acertou = true, furtivo = { dados = 3, total = 11, triplo = true } })
		t.eq(#l, 1)
		t.eq(l[1].chave, "furtivo-triplo")
		t.ok(l[1].forte)
		t.eq(l[1].texto, "FURTIVO ×3  +11")
	end,
	["combo e furtivo comum juntos; erro não destaca"] = function(t)
		local l = D.listar({ acertou = true, combo = 4, furtivo = { dados = 1, total = 4, triplo = false } })
		t.eq(#l, 2)
		t.eq(l[2].texto, "COMBO!", "bônus de acerto não aparece como número")
		t.eq(D.prefixo({ { acertou = true, combo = 4 }, { acertou = true, combo = 4 } }), "Combo", "não repete")
		t.eq(#D.listar({ acertou = false, combo = 4 }), 0)
	end,
}
