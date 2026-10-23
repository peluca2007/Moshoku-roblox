local Shared = game:GetService("ReplicatedStorage").Shared
local T = require(Shared.Regras.RunTreinadores)
local Forca = require(Shared.Regras.RunArvoresForca)
local Layout = require(Shared.Mundo.TreinadoresLayout)

local function fixo(n) return { NextInteger = function() return n end } end
local function sequencia(...)
	local valores, i = { ... }, 0
	return { NextInteger = function(_, lo, hi)
		i += 1
		return math.clamp(valores[(i - 1) % #valores + 1], lo, hi)
	end }
end

local function idsDaVila(lista)
	local ids = {}
	for _, npc in lista do ids[npc.id] = npc.arvore end
	return ids
end

return {
	["catalogo segue elegivel e treinadores fixos tem dias provisoriamente iguais"] = function(t)
		for id in Forca.ARVORES do
			t.ok(T.titulo(id) ~= nil, id)
			t.eq(T.diasDeTreino(id), 1, id)
	end
		t.eq(T.diasDeTreino("inexistente"), nil)
		t.eq(T.diasDeTreino("agua"), 1)
	end,
	["listagem padrao contem somente os dois treinadores fixos e pontos de layout"] = function(t)
		t.eq(T.SOMENTE_FIXOS, true)
		local sorteio = T.sortear(fixo(1))
		t.eq(sorteio.vila[1], "furtividade-e-armadilhas")
		t.eq(sorteio.vila[2], "agua")
		t.eq(sorteio.taverna, nil)
		local lista = T.listar({ vila = { "cura", "fogo", "vento" }, taverna = "agua" })
		t.eq(#lista, 2)
		t.eq(lista[1].id, "vila-1"); t.eq(lista[1].arvore, "furtividade-e-armadilhas")
		t.eq(lista[1].ponto.x, Layout.LADINO.x); t.eq(lista[1].ponto.z, Layout.LADINO.z)
		t.eq(lista[2].id, "vila-2"); t.eq(lista[2].arvore, "agua")
		local mestra = Layout.mestra()
		t.eq(lista[2].ponto.x, mestra.x); t.eq(lista[2].ponto.z, mestra.z)
	end,
	["sorteio legado continua disponivel explicitamente com vila distinta e taverna"] = function(t)
		for _, rng in { fixo(1), sequencia(5, 2, 7, 1), sequencia(99, 3, 50) } do
			local r = T.sortearAleatorio(rng, { chanceTaverna = 0 })
			t.ok(r ~= nil)
			t.eq(#r.vila, 3)
			t.eq(r.taverna, nil)
			t.eq(T.validarSorteio(r), true)
			local vistos = {}
			for _, id in r.vila do
				t.ok(Forca.elegivel(id), id)
				t.ok(not T.raro(id), "raro na vila: " .. id)
				t.ok(not vistos[id], "repetido: " .. id)
				vistos[id] = true
			end
			-- Saves antigos são aceitos, mas a listagem fixa ignora aquele sorteio.
			local fixos = idsDaVila(T.listar(r))
			t.eq(fixos["vila-1"], "furtividade-e-armadilhas")
			t.eq(fixos["vila-2"], "agua")
		end
	end,
	["sorteio legado taverna respeita chance elegibilidade e duplicatas"] = function(t)
		local r = T.sortearAleatorio(fixo(1), { chanceTaverna = 100 })
		t.ok(r.taverna ~= nil)
		t.ok(T.raro(r.taverna), r.taverna)
		for _, id in r.vila do t.eq(id ~= r.taverna, true) end
		t.eq(T.sortearAleatorio(fixo(1), { chanceTaverna = 0 }).taverna, nil)
		t.eq(T.sortearAleatorio(fixo(100), { chanceTaverna = 25 }).taverna, nil)
	end,
	["sorteio legado filtra liberacoes da conta e recusa quantidade impossivel"] = function(t)
		local todasComuns = {}
		for _, c in T.candidatos() do if not c.soTaverna then todasComuns[c.id] = true end end
		local semRaros = T.sortearAleatorio(fixo(1), { chanceTaverna = 100, liberadas = todasComuns })
		t.eq(semRaros.taverna, nil)
		local comAgua = table.clone(todasComuns); comAgua["agua"] = true
		local r = T.sortearAleatorio(fixo(1), { chanceTaverna = 100, liberadas = comAgua })
		t.eq(r.taverna, "agua")
		local poucas = T.sortearAleatorio(fixo(1), { liberadas = { fogo = true } })
		t.eq(poucas, nil)
		local impossivel, motivo = T.sortearAleatorio(fixo(1), { quantidade = 99 })
		t.eq(impossivel, nil); t.ok(motivo ~= nil)
	end,
}
