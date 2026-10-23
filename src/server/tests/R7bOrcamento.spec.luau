local Zonas = require(game:GetService("ReplicatedStorage").Shared.EncontrosPorZona)
local function luta()
	return { no = "chefe-floresta", titulo = "Guardi?o", areaId = "region/encounter/dark-forest",
		criaturas = { "creature/urso-de-presas-vermelhas" } }
end
return {
	["solo usa Urso lacaio equilibrado em vez de padrao mortal"] = function(t)
		local r = Zonas.paraRun(luta(), 1)
		t.eq(r.elenco[1], "creature/urso-de-presas-vermelhas")
		t.eq(r.papeis[1], "lacaio")
		t.eq(r.peso, 1)
		t.eq(r.razao, 1)
	end,
	["grupos dois a quatro permanecem na faixa Dificil do livro"] = function(t)
		local pesos = { [2] = 2.5, [3] = 3.5, [4] = 5 }
		for n = 2, 4 do
			local r = Zonas.paraRun(luta(), n)
			t.eq(r.elenco[1], "creature/urso-de-presas-vermelhas")
			t.eq(r.papeis[1], nil)
			t.eq(r.peso, pesos[n])
			t.ok(r.razao > 1 and r.razao <= 1.25)
			local soma = 0
			for _, id in r.elenco do
				soma += if id == "creature/urso-de-presas-vermelhas" then 2
					elseif id == "creature/lobo-cinzento" then 1 else 0.5
			end
			t.eq(soma, r.peso)
		end
	end,
	["recusa grupos areas e criaturas sem contrato seguro"] = function(t)
		for _, n in { 0, 5, 1.5, math.huge, 0/0 } do t.eq(Zonas.paraRun(luta(), n), nil) end
		local v = luta(); v.areaId = "inventada"; t.eq(Zonas.paraRun(v, 1), nil)
		v = luta(); v.criaturas[2] = v.criaturas[1]; t.eq(Zonas.paraRun(v, 1), nil)
		v = luta(); v.criaturas.extra = true; t.eq(Zonas.paraRun(v, 1), nil)
		v = luta(); v.criaturas[1] = "creature/golem-de-pedra-menor"; t.eq(Zonas.paraRun(v, 1), nil)
		t.eq(Zonas.paraRun(nil, 1), nil)
	end,
	["bando das ruinas: dois goblins lacaios por jogador, Equilibrado"] = function(t)
		local v = { no = "chefe-ruinas", titulo = "Bando", areaId = "region/encounter/ruinas", criaturas = { "creature/goblin-batedor" } }
		for n = 1, 4 do
			local r = Zonas.paraRun(v, n)
			t.eq(#r.elenco, n * 2)
			t.eq(r.peso, n) -- 2n lacaios * 0,5
			t.eq(r.razao, 1)
			for _, id in r.elenco do t.eq(id, "creature/goblin-batedor") end
		end
		t.eq(Zonas.paraRun(v, 5), nil)
	end,
	["resultado nao altera base nem compartilha listas"] = function(t)
		local v = luta(); local a = Zonas.paraRun(v, 1)
		a.elenco[1] = "alterado"; a.papeis[1] = "chefe"
		local b = Zonas.paraRun(v, 1)
		t.eq(b.elenco[1], v.criaturas[1]); t.eq(b.papeis[1], "lacaio")
		v.areaId = "region/encounter/forest"; t.ok(Zonas.paraRun(v, 1))
	end,
}
