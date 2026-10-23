local O = require(game:GetService("ReplicatedStorage").Shared.OrdemVisivel)
return {
	["comeca no ator atual e volta ao inicio sem mutar iniciativa"] = function(t)
		local ordem = { "a", "b", "c", "d" }
		local tokens = { { id = "a" }, { id = "b" }, { id = "c" }, { id = "d" } }
		local r = O.listar(ordem, "c", tokens)
		t.eq(#r, 4); t.eq(r[1], tokens[3]); t.eq(r[2].id, "d"); t.eq(r[3].id, "a"); t.eq(r[4].id, "b")
		t.eq(ordem[1], "a"); t.eq(ordem[3], "c")
	end,
	["ator oculto conserva a sequencia sem criar ficha secreta"] = function(t)
		local r = O.listar({ "a", "oculto", "c", "d" }, "oculto", { { id = "a" }, { id = "c" }, { id = "d" } })
		t.eq(#r, 3); t.eq(r[1].id, "c"); t.eq(r[2].id, "d"); t.eq(r[3].id, "a")
	end,
	["sem ator na ordem conserva inicio e remove duplicatas"] = function(t)
		local r = O.listar({ "a", "a", "b" }, "fora", { { id = "a" }, { id = "b" }, { id = "fora" } })
		t.eq(#r, 2); t.eq(r[1].id, "a"); t.eq(r[2].id, "b")
	end,
	["ordem vazia e fichas ausentes nao criam participantes"] = function(t)
		t.eq(#O.listar({}, nil, { { id = "a" } }), 0)
		t.eq(#O.listar({ "oculto" }, "oculto", {}), 0)
	end,
	["caidos permanecem como no snapshot sem prever eliminacao"] = function(t)
		local r = O.listar({ "a", "b" }, "a", { { id = "a", pv = 0, derrotado = true }, { id = "b" } })
		t.eq(#r, 2); t.eq(r[1].pv, 0)
	end,
}
