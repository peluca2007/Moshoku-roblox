local Shared = game:GetService("ReplicatedStorage").Shared
local Forca = require(Shared.Regras.RunArvoresForca)
local Sorteios = require(Shared.Regras.RunSorteios)

-- Gerador falso: devolve sempre o menor valor pedido (determinístico).
local primeiro = { NextInteger = function(_, lo) return lo end }

local function contar(categoria)
	local n = 0
	for _, a in Forca.ARVORES do
		if a.categoria == categoria then n += 1 end
	end
	return n
end

return {
	["cobre as 19 arvores do livro: 8 magia, 8 corpo, 3 utilidade"] = function(t)
		local total = 0
		for _ in Forca.ARVORES do total += 1 end
		t.eq(total, 19)
		t.eq(contar("magia"), 8)
		t.eq(contar("corpo"), 8)
		t.eq(contar("utilidade"), 3)
	end,
	["pontuacao segue a formula documentada (agua e cura medidas a mao)"] = function(t)
		t.eq(Forca.pontuacao(Forca.ARVORES["agua"]), 14.5) -- 5 ataques*2 + 1 protecao*1,5 + 3 controles
		t.eq(Forca.pontuacao(Forca.ARVORES["cura"]), 9.5) -- 4 curas*2 + 1 protecao*1,5
		t.eq(Forca.forca("agua"), 10)
		t.eq(Forca.forca("cura"), 6)
		t.eq(Forca.forca("inexistente"), nil)
	end,
	["forca fica entre 1 e 10 e arvore indeterminada recebe a nota neutra"] = function(t)
		for id, a in Forca.ARVORES do
			local f = Forca.forca(id)
			t.ok(f >= 1 and f <= 10, id)
			if a.indeterminada then t.eq(f, Forca.NEUTRA, id) end
		end
		t.ok(Forca.forca("agua") > Forca.forca("cura"), "mais forte vale mais")
		t.ok(Forca.forca("cura") > Forca.forca("teorica"))
	end,
	["executaveis nunca passam do total e contagens por funcao sao inteiras"] = function(t)
		for id, a in Forca.ARVORES do
			t.ok(a.exec >= 0 and a.exec <= a.total, id)
			for _, k in { "a", "c", "b", "k", "m", "u", "p", "r", "o" } do
				t.ok(a[k] >= 0 and a[k] % 1 == 0, id .. "." .. k)
			end
		end
	end,
	["elegibilidade exige acao no combate de hoje"] = function(t)
		-- Sem nenhuma habilidade portada ou com 1 executavel entre 5: nao entram na oferta.
		t.eq(Forca.elegivel("vendaval"), false)
		t.eq(Forca.elegivel("punho-de-fogo"), false)
		t.eq(Forca.elegivel("deus-da-agua-corpo"), false)
		t.eq(Forca.elegivel("teorica"), false)
		t.eq(Forca.elegivel("arquearia"), false)
		-- Utilidade/invocacao: uma habilidade executavel basta; Navegacao entra pelo valor na run (Explorador).
		t.eq(Forca.elegivel("furtividade-e-armadilhas"), true)
		t.eq(Forca.elegivel("invocacao"), true)
		t.eq(Forca.elegivel("navegacao-e-lideranca"), true)
		t.eq(Forca.elegivel("agua"), true)
		t.eq(Forca.elegivel("inexistente"), false)
	end,
	["candidatas alimenta Sorteios.ofertaDeArvores sem repetir e respeitando a composicao"] = function(t)
		local candidatas = Forca.candidatas()
		for _, c in candidatas do t.ok(Forca.elegivel(c.id), c.id) end
		local oferta = Sorteios.ofertaDeArvores(candidatas, primeiro)
		t.ok(oferta ~= nil, "oferta")
		t.eq(#oferta, 6)
		local vistos = {}
		for _, id in oferta do
			t.ok(not vistos[id], "repetida: " .. id)
			vistos[id] = true
			t.ok(Forca.ARVORES[id] ~= nil, id)
		end
	end,
}
