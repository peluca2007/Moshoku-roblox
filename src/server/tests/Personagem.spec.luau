local Shared = game:GetService("ReplicatedStorage").Shared
local P = require(Shared.Aparencia.Personagem)
local C = require(Shared.Aparencia.Catalogo)

return {
	["conjunto de roupa vem do traje raro, senao aventureiro"] = function(t)
		t.eq(P.conjuntoDe({ roupas = {} }), "aventureiro")
		t.eq(P.conjuntoDe({ roupas = { cabeca = "LadinoCapuz" } }), "ladino")
		t.eq(P.conjuntoDe({ roupas = { costas = "MestraManto", pes = "RoupaBotas1" } }), "mago")
	end,
	["moldes enviados e conjunto desconhecido cai no aventureiro"] = function(t)
		local c, l = P.moldes("ladino")
		t.ok(c ~= nil and l ~= nil)
		t.eq(P.moldes("inexistente"), (P.moldes("aventureiro")))
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
	["PERS3: estilo do rosto pintado vem das escolhas de blocos"] = function(t)
		t.eq(P.estiloDoRosto({ olhos = "OlhoQuadrado", sobrancelhas = "SobrancelhaReta", boca = "BocaReta" }), "neutro")
		t.eq(P.estiloDoRosto({ olhos = "OlhoFeliz", sobrancelhas = "SobrancelhaReta", boca = "BocaSorriso" }), "alegre")
		t.eq(P.estiloDoRosto({ olhos = "OlhoFeliz", sobrancelhas = "SobrancelhaSeria", boca = "BocaSorriso" }), "serio")
		t.eq(P.estiloDoRosto(nil), "neutro")
	end,
	["PERS3: sem rosto enviado cai nos blocos; com id devolve o decal da cor do olho"] = function(t)
		local rosto = { olhos = "OlhoQuadrado", sobrancelhas = "SobrancelhaReta", boca = "BocaReta" }
		t.eq(P.rostoDecal(rosto, "OlhoAzul"), nil)
		P.ROSTOS.neutro.OlhoAzul = "rbxassetid://1"
		t.eq(P.rostoDecal(rosto, "OlhoAzul"), "rbxassetid://1")
		t.eq(P.rostoDecal(rosto, "OlhoVerde"), nil)
		P.ROSTOS.neutro.OlhoAzul = nil
	end,
	["PERS3: malha preferida quando existe; reserva de blocos senao; peca nova so existe em malha"] = function(t)
		local tudo = function() return true end
		local nada = function() return false end
		local curto = C.CABELOS.CabeloCurto1
		t.eq(P.moduloDe(curto, tudo), "CabeloCurto2")
		t.eq(P.moduloDe(curto, nada), "CabeloCurto1")
		t.eq(P.moduloDe(C.CABELOS.CabeloNenhum, tudo), nil)
		t.eq(P.moduloDe(C.PECAS.RoupaOmbreira1, nada), nil)
		t.eq(P.moduloDe(C.PECAS.RoupaOmbreira1, tudo), "RoupaOmbreira1")
	end,
	["PERS3: catalogo tem 8 cabelos, 3 barbas e pecas novas validas"] = function(t)
		local n = 0
		for id in C.CABELOS do if id ~= "CabeloNenhum" then n += 1 end end
		t.eq(n, 8)
		local b = 0
		for id in C.BARBAS do if id ~= "BarbaNenhum" then b += 1 end end
		t.eq(b, 3)
		for id, item in { C.CABELOS, C.BARBAS } and C.CABELOS do
			t.ok(item.modulo ~= nil or id == "CabeloNenhum", "reserva de " .. id)
		end
		t.eq(C.PECAS.RoupaCapaCurta1.slot, "costas")
		t.eq(C.PECAS.RoupaOmbreira1.slot, "ombro")
		t.eq(C.PECAS.OrelhasElficas.tinge, "pele")
	end,
}
