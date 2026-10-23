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
