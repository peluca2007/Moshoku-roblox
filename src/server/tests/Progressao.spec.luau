local Shared = game:GetService("ReplicatedStorage").Shared
local Progressao = require(Shared.Regras.Progressao)

-- Catálogo mínimo no formato gerado (fictício).
local function catalogo()
	local por = {}
	local function add(id, kind, data, sourceId)
		por[id] = { id = id, kind = kind, data = data, sourceId = sourceId }
	end
	add("tree/fogo", "tree", { id = "fogo", name = "Magia de Fogo", category = "magia" })
	add("tree/agua", "tree", { id = "agua", name = "Magia de Água", category = "magia" })
	add("tree/espada", "tree", { id = "espada", name = "Espada", category = "corpo" })
	add("rank/fogo/Principiante", "rank", { treeId = "fogo", rank = "Principiante", abilities = { "ability/fogo/Principiante/brasa", "ability/fogo/Principiante/bola" } })
	add("rank/fogo/Intermedi%C3%A1rio", "rank", { treeId = "fogo", rank = "Intermediário", abilities = {} })
	add("rank/fogo/Avan%C3%A7ado", "rank", { treeId = "fogo", rank = "Avançado", abilities = {} })
	add("rank/agua/Principiante", "rank", { treeId = "agua", rank = "Principiante", abilities = {} })
	add("ability/fogo/Principiante/brasa", "ability", { treeId = "fogo", rank = "Principiante", name = "Brasa", paCost = 0 }, "brasa")
	add("ability/fogo/Principiante/bola", "ability", { treeId = "fogo", rank = "Principiante", name = "Bola", paCost = 2 }, "bola")
	add("ability/fogo/Principiante/a", "ability", { treeId = "fogo", rank = "Principiante", name = "A", paCost = 1 }, "a")
	add("ability/fogo/Principiante/b", "ability", { treeId = "fogo", rank = "Principiante", name = "B", paCost = 1, requires = { "a" } }, "b")
	add("talent/fogo/Principiante/t", "talent", { treeId = "fogo", rank = "Principiante", name = "T", paCost = 1 }, "t")
	add("ability/fogo/Principiante/ponte", "ability", { treeId = "fogo", rank = "Principiante", name = "Ponte", paCost = 1, requiresRank = { rank = "Principiante", treeId = "agua" } }, "ponte")
	add("ability/fogo/Principiante/qualquer", "ability", { treeId = "fogo", rank = "Principiante", name = "Q", paCost = 1, requiresRank = { rank = "Principiante", categoria = "corpo" } }, "qualquer")
	local abilities = {}
	for _, e in por do
		if e.kind == "ability" then
			table.insert(abilities, e)
		end
	end
	return { POR_ID = por, POR_ESPECIE = { ability = abilities } }
end

local function construcao(ranks, compras)
	return { unlockedRankIds = ranks or {}, purchasedIds = compras or {} }
end

return {
	["id do rank com percent-encoding, como o site"] = function(t)
		t.eq(Progressao.idDoRank("fogo", "Intermediário"), "rank/fogo/Intermedi%C3%A1rio")
		t.eq(Progressao.idDoRank("fogo", "Principiante"), "rank/fogo/Principiante")
	end,
	["abrir: Principiante sem requisito; Intermediário pede o anterior e 3 conhecimentos"] = function(t)
		local cat = catalogo()
		t.ok((Progressao.podeAbrir(construcao(), cat, "fogo", "Principiante")))
		local ok, motivo = Progressao.podeAbrir(construcao(), cat, "fogo", "Intermediário")
		t.eq(ok, false)
		t.ok(string.find(motivo, "Principiante", 1, true), motivo)
		local c = construcao({ "rank/fogo/Principiante" }, { "ability/fogo/Principiante/bola", "ability/fogo/Principiante/a" })
		ok, motivo = Progressao.podeAbrir(c, cat, "fogo", "Intermediário")
		t.eq(ok, false)
		t.ok(string.find(motivo, "3 conhecimento", 1, true), motivo)
		table.insert(c.purchasedIds, "talent/fogo/Principiante/t")
		t.ok((Progressao.podeAbrir(c, cat, "fogo", "Intermediário")), "talento conta como conhecimento")
	end,
	["teto: acima do Intermediário fica para depois"] = function(t)
		local c = construcao({ "rank/fogo/Principiante", "rank/fogo/Intermedi%C3%A1rio" })
		local ok, motivo = Progressao.podeAbrir(c, catalogo(), "fogo", "Avançado")
		t.eq(ok, false)
		t.ok(string.find(motivo, "Intermediário", 1, true), motivo)
	end,
	["comprar: rank aberto, sem repetir, carta de 0 PA vem com o rank"] = function(t)
		local cat = catalogo()
		t.eq((Progressao.podeComprar(construcao(), cat, "ability/fogo/Principiante/bola")), false)
		local c = construcao({ "rank/fogo/Principiante" })
		t.ok((Progressao.podeComprar(c, cat, "ability/fogo/Principiante/bola")))
		local ok, motivo = Progressao.podeComprar(c, cat, "ability/fogo/Principiante/brasa")
		t.eq(ok, false)
		t.ok(string.find(motivo, "Vem com o rank", 1, true), motivo)
		table.insert(c.purchasedIds, "ability/fogo/Principiante/bola")
		t.eq((Progressao.podeComprar(c, cat, "ability/fogo/Principiante/bola")), false)
	end,
	["requires da mesma árvore e requiresRank em outra árvore ou categoria"] = function(t)
		local cat = catalogo()
		local c = construcao({ "rank/fogo/Principiante" })
		local ok, motivo = Progressao.podeComprar(c, cat, "ability/fogo/Principiante/b")
		t.eq(ok, false)
		t.ok(string.find(motivo, '"A"', 1, true), motivo)
		table.insert(c.purchasedIds, "ability/fogo/Principiante/a")
		t.ok((Progressao.podeComprar(c, cat, "ability/fogo/Principiante/b")))
		ok, motivo = Progressao.podeComprar(c, cat, "ability/fogo/Principiante/ponte")
		t.eq(ok, false)
		t.ok(string.find(motivo, "Magia de Água", 1, true), motivo)
		table.insert(c.unlockedRankIds, "rank/agua/Principiante")
		t.ok((Progressao.podeComprar(c, cat, "ability/fogo/Principiante/ponte")))
		t.eq((Progressao.podeComprar(c, cat, "ability/fogo/Principiante/qualquer")), false, "categoria corpo ainda não aberta")
	end,
	["conhecidas: compras mais as cartas gratuitas dos ranks abertos"] = function(t)
		local c = construcao({ "rank/fogo/Principiante" }, { "ability/fogo/Principiante/bola" })
		local lista = Progressao.conhecidas(c, catalogo())
		t.eq(#lista, 2)
		t.ok(table.find(lista, "ability/fogo/Principiante/brasa"))
		t.eq(Progressao.maiorRank(c, "fogo"), "Principiante")
		t.eq(Progressao.maiorRank(c, "agua"), nil)
	end,
}
