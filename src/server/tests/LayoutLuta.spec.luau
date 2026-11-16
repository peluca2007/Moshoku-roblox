-- HUD2: layout puro do HUD da luta (losango de comandos, lista, cartões, coluna da ordem e topo).
local L = require(game:GetService("ReplicatedStorage").Shared.Regras.LayoutLuta)
local LARGURAS = { 800, 1024, 1280, 1920 }
local ALTURAS = { 600, 720, 1080 }

local function dentro(r, vx, vy)
	return r.x >= 0 and r.y >= 0 and r.x + r.w <= vx and r.y + r.h <= vy
end

local function cada_tela(f)
	for _, vx in LARGURAS do
		for _, vy in ALTURAS do
			f(vx, vy)
		end
	end
end

-- Todas as peças visíveis ao mesmo tempo (pior caso): nome => retângulo absoluto.
local function pecas(vx, vy, cartoes, turnos, extras)
	local lo = L.losango(vx, vy)
	local topo = L.topo(vx)
	local lista = {
		losango = lo, lista = L.lista(vx, vy, L.LISTA_MAX_LINHAS, true), chefe = L.chefe(vx), dia = L.diaFaixa(vx),
		anuncio = topo.anuncio, resultado = topo.resultado, rodada = topo.rodada,
	}
	for i, r in L.extras(vx, vy, extras) do lista["extra" .. i] = r end
	for i, r in L.cartoes(vx, vy, cartoes, 1) do lista["cartao" .. i] = r end
	for i, r in L.ordemColuna(vx, vy, turnos).rects do lista["ordem" .. i] = r end
	return lista
end

return {
	["nenhuma peça sai da tela nem cruza outra, de 800x600 a 1920x1080"] = function(t)
		cada_tela(function(vx, vy)
			local lista = pecas(vx, vy, 4, 12, 5)
			local nomes = {}
			for nome, r in lista do
				table.insert(nomes, nome)
				t.ok(dentro(r, vx, vy), nome .. " fora da tela " .. vx .. "x" .. vy)
			end
			table.sort(nomes)
			for i = 1, #nomes do
				for j = i + 1, #nomes do
					t.ok(not L.intersecta(lista[nomes[i]], lista[nomes[j]]), nomes[i] .. " cruza " .. nomes[j] .. " a " .. vx .. "x" .. vy)
				end
			end
		end)
	end,
	["nada flutuante sobe acima do limite do topo"] = function(t)
		cada_tela(function(vx, vy)
			local topo = L.topo(vx)
			t.ok(topo.rodada.y + topo.rodada.h < L.ABAIXO_DO_TOPO, "topo passa do limite")
			t.ok(L.lista(vx, vy, L.LISTA_MAX_LINHAS, true).y >= L.ABAIXO_DO_TOPO, "lista sobe demais " .. vx .. "x" .. vy)
			local extras = L.extras(vx, vy, 5)
			t.ok(extras[5].y >= L.ABAIXO_DO_TOPO, "extras sobem demais " .. vx .. "x" .. vy)
		end)
	end,
	["losango: quatro vértices dentro do quadrado, sem tocar, com alvo de toque >= 44"] = function(t)
		cada_tela(function(vx, vy)
			local lo = L.losango(vx, vy)
			t.eq(lo.x + lo.w, vx - L.MARGEM)
			t.eq(lo.y + lo.h, vy - L.MARGEM)
			local nomes = { "habilidades", "atacar", "andar", "encerrar" }
			for i, nome in nomes do
				local v = lo.vertices[nome]
				t.ok(v.x >= 0 and v.y >= 0 and v.x + v.w <= lo.w and v.y + v.h <= lo.h, nome .. " fora do quadrado")
				t.ok(v.w >= 44 and v.h >= 44, nome .. " pequeno para toque")
				for j = i + 1, #nomes do
					t.ok(not L.intersecta(v, lo.vertices[nomes[j]]), nome .. " cruza " .. nomes[j])
				end
			end
			-- o losango é simétrico: topo/base no meio, esquerda/direita na altura do meio
			t.eq(lo.vertices.habilidades.x, lo.vertices.encerrar.x)
			t.eq(lo.vertices.atacar.y, lo.vertices.andar.y)
		end)
	end,
	["lista: fica à esquerda do losango, com a base alinhada, e cresce com as linhas"] = function(t)
		cada_tela(function(vx, vy)
			local lo = L.losango(vx, vy)
			local pequena = L.lista(vx, vy, 1, false)
			local cheia = L.lista(vx, vy, 99, true)
			t.ok(pequena.x + pequena.w <= lo.x, "lista cruza o losango")
			t.eq(pequena.y + pequena.h, vy - L.MARGEM)
			t.eq(cheia.y + cheia.h, vy - L.MARGEM)
			t.ok(cheia.h > pequena.h and cheia.w <= L.LISTA_LARGURA)
			t.eq(cheia.h, L.alturaLista(L.LISTA_MAX_LINHAS) + L.LINHA + L.ESPACO)
			t.ok(cheia.x >= L.CARTAO_X + L.CARTAO_LARGURA, "lista invade os cartões")
		end)
	end,
	["extras: pilha acima do losango, o 1 mais perto, sem cruzar"] = function(t)
		cada_tela(function(vx, vy)
			local lo = L.losango(vx, vy)
			local e = L.extras(vx, vy, 5)
			t.ok(e[1].y + e[1].h <= lo.y, "extra 1 cruza o losango")
			t.ok(e[1].y > e[2].y and e[2].y > e[3].y)
			for i = 2, 5 do t.ok(not L.intersecta(e[i], e[i - 1])) end
			t.eq(#L.extras(vx, vy, 0), 0)
		end)
	end,
	["cartões: empilham no canto inferior esquerdo e o ativo é mais alto"] = function(t)
		cada_tela(function(vx, vy)
			for n = 1, 4 do
				for ativo = 1, n do
					local cs = L.cartoes(vx, vy, n, ativo)
					t.eq(#cs, n)
					t.eq(cs[n].y + cs[n].h, vy - L.MARGEM)
					for i, c in cs do
						t.ok(dentro(c, vx, vy) and c.x >= L.MARGEM + L.ORDEM_ATIVO, "cartão fora ou sobre a coluna")
						t.eq(c.h, if i == ativo then L.CARTAO_ATIVO else L.CARTAO_ALTURA)
						if i > 1 then t.ok(not L.intersecta(c, cs[i - 1])) end
					end
				end
			end
			t.eq(#L.cartoes(vx, vy, 9, 1), L.MAX_CARTOES)
		end)
	end,
	["ordem: o primeiro é maior; se não cabem todos, o último espaço é o +N"] = function(t)
		cada_tela(function(vx, vy)
			for total = 1, 14 do
				local o = L.ordemColuna(vx, vy, total)
				t.ok(o.mostrados >= 1 and o.mostrados <= total, "mostrados " .. o.mostrados)
				t.eq(o.mostrados + o.resto, total)
				t.eq(#o.rects, o.mostrados + (if o.resto > 0 then 1 else 0))
				t.eq(o.rects[1].w, L.ORDEM_ATIVO)
				for i, r in o.rects do
					t.ok(dentro(r, vx, vy) and r.y + r.h <= vy - L.MARGEM, "retrato fora da coluna")
					if i > 1 then t.ok(not L.intersecta(r, o.rects[i - 1])) end
					if i > 2 then t.eq(r.w, L.ORDEM_ITEM) end
				end
			end
		end)
	end,
	["topo: pilha sem cruzar nem tocar a faixa do dia; chefe logo abaixo"] = function(t)
		for _, vx in LARGURAS do
			local topo, dia = L.topo(vx), L.diaFaixa(vx)
			t.ok(not L.intersecta(topo.anuncio, topo.resultado) and not L.intersecta(topo.resultado, topo.rodada))
			for nome, r in topo do
				t.ok(dentro(r, vx, 9999), nome .. " fora da tela a " .. vx)
				t.ok(not L.intersecta(r, dia), nome .. " cruza a faixa do dia a " .. vx)
			end
			local c = L.chefe(vx)
			t.ok(c.y >= topo.rodada.y + topo.rodada.h and dentro(c, vx, 9999))
		end
	end,
	["cartão fora da luta fica no canto superior direito"] = function(t)
		for _, vx in LARGURAS do
			local c = L.cartaoFora(vx)
			t.ok(dentro(c, vx, 9999) and not L.intersecta(c, L.diaFaixa(vx)))
		end
	end,
	["intersecta: encostar não é cruzar"] = function(t)
		t.ok(not L.intersecta({ x = 0, y = 0, w = 10, h = 10 }, { x = 10, y = 0, w = 10, h = 10 }))
		t.ok(L.intersecta({ x = 0, y = 0, w = 10, h = 10 }, { x = 9, y = 9, w = 10, h = 10 }))
	end,
}
