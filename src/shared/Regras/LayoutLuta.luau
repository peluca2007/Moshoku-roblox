-- LUTA-B: geometria pura do HUD mínimo da luta (o cenário aparece; nada de painel grande).
-- Só números em pixels de tela (o UIScale de `aplicarEscala` age por cima); nenhuma Instance.
--   topo (centro): anúncio ("Ren usa Ataque básico."), resultado ("5 de dano") e a fileira da ordem;
--   canto superior direito: a faixa do dia/sala vira texto pequeno (reserva `diaFaixa`);
--   menu de ação: lista curta ao lado de quem age (reserva fixa no canto inferior esquerdo);
--   lista de habilidades: segunda lista ao lado do menu;
--   cartões dos personagens: canto inferior direito, empilhados.
local L = {}

L.MARGEM = 12
L.GAP = 8
L.MENU_LARGURA = 176
L.LINHA = 44 -- toque mínimo
L.ESPACO = 4
L.LISTA_LARGURA = 264
L.LISTA_MAX_LINHAS = 6
L.CARTAO_LARGURA = 250
L.CARTAO_ALTURA = 92
L.ANUNCIO_Y, L.ANUNCIO_H = 12, 26
L.RESULTADO_H = 22
L.ORDEM_H = 24
L.ORDEM_CHIP = 96
L.LATERAL = 170 -- reserva de cada lado do topo (dia/sala à direita)
L.TOPO_MAX = 560
L.DIA_LARGURA, L.DIA_ALTURA = 160, 24
L.ABAIXO_DO_TOPO = 96 -- nada flutuante sobe acima disto (anúncio, resultado e ordem ocupam 12..88)

export type Retangulo = { x: number, y: number, w: number, h: number }

local function limitar(v: number, a: number, b: number): number
	return math.max(a, math.min(v, math.max(a, b)))
end

function L.intersecta(a: Retangulo, b: Retangulo): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Pilha central do topo: anúncio, resultado e ordem dos turnos.
function L.topo(vx: number): { anuncio: Retangulo, resultado: Retangulo, ordem: Retangulo }
	local w = math.max(200, math.min(L.TOPO_MAX, vx - 2 * (L.MARGEM + L.LATERAL)))
	local x = (vx - w) / 2
	local y = L.ANUNCIO_Y
	local anuncio = { x = x, y = y, w = w, h = L.ANUNCIO_H }
	y += L.ANUNCIO_H
	local resultado = { x = x, y = y, w = w, h = L.RESULTADO_H }
	y += L.RESULTADO_H + L.ESPACO
	return { anuncio = anuncio, resultado = resultado, ordem = { x = x, y = y, w = w, h = L.ORDEM_H } }
end

-- Quantos nomes da ordem cabem na fileira (o resto vira "+N").
function L.ordemCabe(larguraFileira: number, total: number): number
	local cabem = math.max(1, math.floor((larguraFileira + L.ESPACO) / (L.ORDEM_CHIP + L.ESPACO)))
	if total <= cabem then return total end
	return math.max(1, cabem - 1)
end

-- Faixa do dia/sala, pequena, no canto superior direito.
function L.diaFaixa(vx: number): Retangulo
	return { x = vx - L.MARGEM - L.DIA_LARGURA, y = L.MARGEM, w = L.DIA_LARGURA, h = L.DIA_ALTURA }
end

function L.alturaLista(linhas: number): number
	return linhas * L.LINHA + (linhas - 1) * L.ESPACO
end

-- Menu de ação: ao lado do ponto de tela de quem age (se estiver na tela) ou no canto inferior esquerdo.
function L.menu(vx: number, vy: number, ponto: { x: number, y: number }?, linhas: number): Retangulo & { ancorado: boolean }
	local w, h = L.MENU_LARGURA, L.alturaLista(math.max(1, linhas))
	local naTela = ponto ~= nil and ponto.x > 0 and ponto.x < vx and ponto.y > L.ABAIXO_DO_TOPO and ponto.y < vy
	if not naTela then
		return { x = L.MARGEM, y = vy - L.MARGEM - h, w = w, h = h, ancorado = false }
	end
	local x = ponto.x + 56
	if x + w > vx - L.MARGEM then x = ponto.x - 56 - w end
	return {
		x = limitar(x, L.MARGEM, vx - L.MARGEM - w), y = limitar(ponto.y - h / 2, L.ABAIXO_DO_TOPO, vy - L.MARGEM - h),
		w = w, h = h, ancorado = true,
	}
end

-- Segunda lista (habilidades), colada ao menu, do lado onde houver espaço.
function L.lista(vx: number, vy: number, menu: Retangulo, linhas: number): Retangulo
	local n = math.max(1, math.min(linhas, L.LISTA_MAX_LINHAS))
	local w, h = L.LISTA_LARGURA, L.alturaLista(n)
	local x = menu.x + menu.w + L.GAP
	if x + w > vx - L.MARGEM then x = menu.x - L.GAP - w end
	return { x = limitar(x, L.MARGEM, vx - L.MARGEM - w), y = limitar(menu.y + menu.h - h, L.ABAIXO_DO_TOPO, vy - L.MARGEM - h), w = w, h = h }
end

-- Cartões dos personagens do grupo, empilhados no canto inferior direito (o primeiro fica por cima).
function L.cartoes(vx: number, vy: number, n: number): { Retangulo }
	local lista = {}
	for i = 1, n do
		local deBaixo = n - i
		lista[i] = {
			x = vx - L.MARGEM - L.CARTAO_LARGURA,
			y = vy - L.MARGEM - L.CARTAO_ALTURA - deBaixo * (L.CARTAO_ALTURA + L.ESPACO),
			w = L.CARTAO_LARGURA, h = L.CARTAO_ALTURA,
		}
	end
	return lista
end

return L
