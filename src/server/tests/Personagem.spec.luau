local Shared = game:GetService("ReplicatedStorage").Shared
local P = require(Shared.Aparencia.Personagem)
local C = require(Shared.Aparencia.Catalogo)

return {
	["conjunto de roupa vem do traje raro, senao aventureiro"] = function(t)
		t.eq(P.conjuntoDe({ roupas = {} }), "aventureiro")
		t.eq(P.conjuntoDe({ roupas = { cabeca = "LadinoCapuz" } }), "ladino")
		t.eq(P.conjuntoDe({ roupas = { costas = "MestraManto", pes = "RoupaBotas1" } }), "mago")
	end,
	["moldes vazios dao fallback sem erro"] = function(t)
		local c, l = P.moldes("ladino")
		t.ok(c == nil and l == nil)
		t.ok(P.moldes("inexistente") == nil)
	end,
	["rosto numa cabeca cubica reproduz as medidas antigas"] = function(t)
		local m = P.medidasCabeca(Vector3.new(1, 1, 1))
		local tam, pos = P.blocoDoRosto(C.ROSTO.olhos.OlhoQuadrado[1], m, 1)
		t.ok(math.abs(pos.Z - -0.525) < 1e-6, "z antigo")
		t.ok(math.abs(pos.X - -0.225) < 1e-6, "x antigo")
		t.ok(math.abs(tam.X - 0.15) < 1e-6)
	end,
	["rosto acompanha a frente real da cabeca redonda"] = function(t)
		local m = P.medidasCabeca(Vector3.new(2, 1, 1), Vector3.new(1.25, 1.25, 1.25))
		t.ok(math.abs(m.profundidade - 1.25) < 1e-6 and math.abs(m.altura - 1.25) < 1e-6)
		local _, pos = P.blocoDoRosto(C.ROSTO.boca.BocaReta[1], m, 1)
		t.ok(pos.Z < -m.profundidade / 2, "bloco fora da malha")
	end,
	["estrategia de cabelo por classe"] = function(t)
		t.eq(P.estrategiaCabelo("SpecialMesh", false), "vertex")
		t.eq(P.estrategiaCabelo("MeshPart", false), "cor")
		t.eq(P.estrategiaCabelo("MeshPart", true), "nenhuma")
		t.eq(P.estrategiaCabelo("Part", false), "nenhuma")
	end,
}
