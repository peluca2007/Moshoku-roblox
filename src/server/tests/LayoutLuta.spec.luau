-- LUTA-B: layout puro do HUD mínimo da luta.
local L = require(game:GetService("ReplicatedStorage").Shared.Regras.LayoutLuta)
local TELAS = { { 800, 450 }, { 1024, 576 }, { 1280, 720 }, { 1920, 1080 } }

local function dentro(r, vx, vy)
	return r.x >= 0 and r.y >= 0 and r.x + r.w <= vx and r.y + r.h <= vy
end

return {
	["topo: anúncio, resultado e ordem empilham sem cruzar e sem tocar a faixa do dia"] = function(t)
		for _, tela in TELAS do
			local vx = tela[1]
			local topo, dia = L.topo(vx), L.diaFaixa(vx)
			t.ok(not L.intersecta(topo.anuncio, topo.resultado) and not L.intersecta(topo.resultado, topo.ordem), "pilha " .. vx)
			for nome, r in topo do
				t.ok(dentro(r, vx, 9999), nome .. " fora da tela a " .. vx)
				t.ok(not L.intersecta(r, dia), nome .. " cruza a faixa do dia a " .. vx)
			end
			t.ok(topo.ordem.y + topo.ordem.h < L.ABAIXO_DO_TOPO, "topo passa do limite")
		end
	end,
	["ordem: sempre mostra alguém e nunca passa da fileira"] = function(t)
		for _, tela in TELAS do
			local w = L.topo(tela[1]).ordem.w
			for total = 1, 12 do
				local n = L.ordemCabe(w, total)
				t.ok(n >= 1 and n <= total, "n " .. n)
				local usados = n + (if n < total then 1 else 0)
				t.ok(usados * L.ORDEM_CHIP + (usados - 1) * L.ESPACO <= w + L.ORDEM_CHIP, "fileira estoura")
			end
		end
	end,
	["menu: reserva no canto inferior esquerdo e ancorado ao lado do personagem"] = function(t)
		for _, tela in TELAS do
			local vx, vy = tela[1], tela[2]
			local fixo = L.menu(vx, vy, nil, 5)
			t.ok(not fixo.ancorado and fixo.x == L.MARGEM and fixo.y + fixo.h == vy - L.MARGEM)
			t.ok(dentro(fixo, vx, vy))
			for _, p in { { x = vx / 2, y = vy / 2 }, { x = vx - 5, y = vy / 2 }, { x = 20, y = vy - 10 } } do
				local m = L.menu(vx, vy, p, 5)
				t.ok(m.ancorado and dentro(m, vx, vy) and m.y >= L.ABAIXO_DO_TOPO, "menu ancorado fora")
			end
			-- personagem fora da tela: cai na reserva
			t.ok(not L.menu(vx, vy, { x = -50, y = 100 }, 5).ancorado)
		end
	end,
	["menu e lista não passam de 1/3 da altura a 720 px e a lista fica ao lado do menu"] = function(t)
		local vx, vy = 1280, 720
		local m = L.menu(vx, vy, nil, 5)
		local l = L.lista(vx, vy, m, 7)
		t.ok(m.h <= vy / 2 and l.h <= vy / 2, "listas altas")
		t.ok(not L.intersecta(m, l) and dentro(l, vx, vy))
		t.eq(l.h, L.alturaLista(L.LISTA_MAX_LINHAS))
	end,
	["cartões: empilham no canto inferior direito sem cruzar a reserva do menu"] = function(t)
		for _, tela in TELAS do
			local vx, vy = tela[1], tela[2]
			local cs = L.cartoes(vx, vy, 4)
			local menu = L.menu(vx, vy, nil, 5)
			for i, c in cs do
				t.ok(dentro(c, vx, vy) or i == 1, "cartão fora")
				t.ok(not L.intersecta(c, menu), "cartão cruza o menu")
				if i > 1 then t.ok(not L.intersecta(c, cs[i - 1])) end
			end
			t.ok(cs[4].y + cs[4].h == vy - L.MARGEM)
		end
	end,
	["intersecta: encostar não é cruzar"] = function(t)
		t.ok(not L.intersecta({ x = 0, y = 0, w = 10, h = 10 }, { x = 10, y = 0, w = 10, h = 10 }))
		t.ok(L.intersecta({ x = 0, y = 0, w = 10, h = 10 }, { x = 9, y = 9, w = 10, h = 10 }))
	end,
}
