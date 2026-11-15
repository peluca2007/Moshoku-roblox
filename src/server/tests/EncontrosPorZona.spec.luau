local Encontros = require(game:GetService("ReplicatedStorage").Shared.EncontrosPorZona)

return {
	["catalogo identifica zonas e marcos permitidos"] = function(t)
		local ids = Encontros.listar()
		t.eq(#ids, 4)
		local clareira = Encontros.consultar("region/encounter/clearing")
		local bosque = Encontros.consultar("region/encounter/forest")
		t.eq(clareira.marco, "region/clareira-inicial/encontro/marco")
		t.eq(clareira.ameaca, "baixa")
		t.eq(bosque.zona, "region/clareira-inicial/bosque")
		t.eq(bosque.ameaca, "moderada")
		local sombria = Encontros.consultar("region/encounter/dark-forest")
		t.eq(sombria.marco, "region/floresta-sombria/encontro/marco")
		t.eq(sombria.ameaca, "alta")
		t.eq(sombria.elenco[1], "creature/lobo-cinzento")
		t.eq(Encontros.consultar("inventado"), nil)
	end,
	["paraRun do esgoto escala qualquer elenco valido de 1 a 4 jogadores"] = function(t)
		local area = "region/encounter/esgoto"
		for n = 1, 4 do
			local r = Encontros.paraRun({ no = "x", areaId = area, criaturas = { "creature/rato-gigante" } }, n)
			t.eq(#r.elenco, n)
			t.eq(r.elenco[1], "creature/rato-gigante")
			t.eq(r.peso, 0.5 * n)
			t.eq(r.orcamento, n)
			t.eq(next(r.papeis), nil)
		end
		local misto = Encontros.paraRun({ areaId = area, criaturas = { "creature/rato-gigante", "creature/lobo-cinzento" } }, 3)
		t.eq(#misto.elenco, 6)
		t.eq(misto.peso, 4.5)
		t.eq(Encontros.paraRun({ areaId = area, criaturas = { "creature/rato-gigante" } }, 5), nil)
		t.eq(Encontros.paraRun({ areaId = area, criaturas = {} }, 1), nil)
		t.eq(Encontros.paraRun({ areaId = area, criaturas = { "creature/inexistente" } }, 1), nil)
		t.eq(Encontros.paraRun({ areaId = area, criaturas = { "creature/treant-anciao" } }, 1), nil)
		t.eq(#Encontros.listar(), 4, "esgoto não entra no catálogo de zonas")
	end,
	["paraRun do esgoto aceita o chefe golem (padrao patamar 2 = peso 2 por jogador)"] = function(t)
		local chefe = { no = "esgoto-chefe", areaId = "region/encounter/esgoto", criaturas = { "creature/golem-de-pedra-menor" } }
		for n = 1, 4 do
			local r = Encontros.paraRun(chefe, n)
			t.ok(r ~= nil, "chefe recusado para " .. n)
			t.eq(#r.elenco, n)
			t.eq(r.elenco[1], "creature/golem-de-pedra-menor")
			t.eq(r.peso, 2 * n)
			t.eq(r.orcamento, n)
		end
		t.eq(Encontros.paraRun(chefe, 5), nil)
	end,
	["elenco escala por jogadores e nao expoe tabela interna"] = function(t)
		local um = Encontros.elegivel("region/encounter/clearing", 1)
		local quatro = Encontros.elegivel("region/encounter/clearing", 4)
		t.eq(#um.elenco, 1)
		t.eq(#quatro.elenco, 4)
		um.elenco[1] = "alterado"
		t.eq(Encontros.elegivel("region/encounter/clearing", 1).elenco[1], "creature/goblin-batedor")
		t.eq(#Encontros.elegivel("region/encounter/forest", 4).elenco, 4)
		t.eq(#Encontros.elegivel("region/encounter/dark-forest", 1).elenco, 2)
		t.eq(#Encontros.elegivel("region/encounter/dark-forest", 4).elenco, 8)
		t.eq(Encontros.elegivel("region/encounter/clearing", 1).elenco[1], "creature/goblin-batedor")
		t.eq(Encontros.elegivel("region/encounter/forest", 1).elenco[1], "creature/lobo-cinzento")
		t.eq(Encontros.elegivel("region/encounter/clearing", 0), nil)
		t.eq(Encontros.elegivel("region/encounter/clearing", 2.5), nil)
	end,
}
