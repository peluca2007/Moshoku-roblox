-- HUD2: geometria pura do HUD da luta (estrutura inspirada em RPGs de turnos por comandos; arte nossa).
-- Só números em pixels de tela (o UIScale de `aplicarEscala` age por cima, ancorado nos cantos);
-- nenhuma Instance. Mapa da tela:
--   topo central: nome da habilidade (anúncio), resultado e a linha da rodada/prazo; chefe logo abaixo;
--   canto inferior direito: RODA de ações (RODA1: três fatias Golpear/Habilidades/Ações em volta do botão
--     Encerrar turno, mais o gatilho "Roda" embaixo) e, acima dela, a pilha de comandos extras (Confirmar, Cancelar);
--   à esquerda da roda: lista vertical de habilidades (com as abas Golpes/Apoio/Tudo no topo);
--   canto inferior esquerdo: cartões do grupo, à direita da coluna da ordem dos turnos;
--   coluna esquerda: ordem dos turnos (retratos; quem age no topo e maior);
--   canto superior direito: faixa do dia/sala (reserva `diaFaixa`).
local L = {}

L.MARGEM = 12
L.GAP = 8
L.ESPACO = 4
L.LINHA = 44 -- toque mínimo
-- Roda de ações: quadrado RODA x RODA no canto. Três fatias redondas (topo, baixo-esquerda, baixo-direita)
-- à distância RODA_RAIO do centro, o botão Encerrar turno no centro e o gatilho (abre/fecha) na base.
L.RODA = 264
L.FATIA = 88
L.RODA_RAIO = 90
L.HUB = 76
L.GATILHO_W, L.GATILHO_H = 132, 38
L.EXTRA_W, L.EXTRA_H = 176, 38
-- Lista de habilidades (à esquerda da roda).
L.LISTA_LARGURA = 330
L.LISTA_LINHA = 54
L.LISTA_MAX_LINHAS = 5
-- Coluna da ordem dos turnos (retratos).
L.ORDEM_ATIVO, L.ORDEM_ITEM, L.ORDEM_GAP = 68, 48, 6
L.ORDEM_Y = 52 -- abaixo dos ícones do topo do Roblox
-- Cartões do grupo.
L.CARTAO_X = L.MARGEM + L.ORDEM_ATIVO + L.GAP
L.CARTAO_LARGURA = 216
L.CARTAO_ALTURA, L.CARTAO_ATIVO = 76, 96
L.MAX_CARTOES = 4
-- Topo.
L.ANUNCIO_Y, L.ANUNCIO_H = 12, 64
L.RESULTADO_H = 28
L.RODADA_H = 20
L.CHEFE_LARGURA, L.CHEFE_ALTURA = 360, 84
L.LATERAL = 170 -- reserva de cada lado do topo (dia/sala à direita)
L.TOPO_MAX = 560
L.DIA_LARGURA, L.DIA_ALTURA = 160, 24
L.ABAIXO_DO_TOPO = 130 -- nada flutuante sobe acima disto (anúncio, resultado e rodada ocupam 12..128)

export type Retangulo = { x: number, y: number, w: number, h: number }

local function limitar(v: number, a: number, b: number): number
	return math.max(a, math.min(v, math.max(a, b)))
end

function L.intersecta(a: Retangulo, b: Retangulo): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Pilha central do topo: nome da habilidade, resultado e a linha da rodada/prazo.
function L.topo(vx: number): { anuncio: Retangulo, resultado: Retangulo, rodada: Retangulo }
	local w = math.max(200, math.min(L.TOPO_MAX, vx - 2 * (L.MARGEM + L.LATERAL)))
	local x = (vx - w) / 2
	local y = L.ANUNCIO_Y
	local anuncio = { x = x, y = y, w = w, h = L.ANUNCIO_H }
	y += L.ANUNCIO_H
	local resultado = { x = x, y = y, w = w, h = L.RESULTADO_H }
	y += L.RESULTADO_H + L.ESPACO
	return { anuncio = anuncio, resultado = resultado, rodada = { x = x, y = y, w = w, h = L.RODADA_H } }
end

-- Chefe: logo abaixo da pilha do topo, centrado.
function L.chefe(vx: number): Retangulo
	local topo = L.topo(vx)
	local w = math.min(L.CHEFE_LARGURA, topo.rodada.w)
	return { x = (vx - w) / 2, y = topo.rodada.y + topo.rodada.h + L.GAP, w = w, h = L.CHEFE_ALTURA }
end

-- Faixa do dia/sala, pequena, no canto superior direito.
function L.diaFaixa(vx: number): Retangulo
	return { x = vx - L.MARGEM - L.DIA_LARGURA, y = L.MARGEM, w = L.DIA_LARGURA, h = L.DIA_ALTURA }
end

function L.alturaLista(linhas: number): number
	return linhas * L.LISTA_LINHA + (linhas - 1) * L.ESPACO
end

-- Roda de ações no canto inferior direito. Retângulos de fatias, hub e gatilho em coordenadas relativas ao quadrado.
function L.roda(vx: number, vy: number): Retangulo & { fatias: { golpear: Retangulo, habilidades: Retangulo, acoes: Retangulo }, hub: Retangulo, gatilho: Retangulo }
	local s, d, r, h = L.RODA, L.FATIA, L.RODA_RAIO, L.HUB
	local cx, cy = s / 2, r + d / 2 -- a fatia de cima encosta no topo do quadrado
	local function fatia(graus: number): Retangulo
		local rad = math.rad(graus)
		return { x = cx + r * math.cos(rad) - d / 2, y = cy + r * math.sin(rad) - d / 2, w = d, h = d }
	end
	return {
		x = vx - L.MARGEM - s, y = vy - L.MARGEM - s, w = s, h = s,
		fatias = { golpear = fatia(150), habilidades = fatia(-90), acoes = fatia(30) },
		hub = { x = cx - h / 2, y = cy - h / 2, w = h, h = h },
		gatilho = { x = (s - L.GATILHO_W) / 2, y = s - L.GATILHO_H, w = L.GATILHO_W, h = L.GATILHO_H },
	}
end

-- Comandos extras (Confirmar, Cancelar mira): pilha acima da roda, alinhada à direita;
-- o item 1 fica mais perto da roda.
function L.extras(vx: number, vy: number, n: number): { Retangulo }
	local lo = L.roda(vx, vy)
	local lista = {}
	for i = 1, n do
		lista[i] = { x = lo.x + lo.w - L.EXTRA_W, y = lo.y - L.GAP - i * L.EXTRA_H - (i - 1) * L.ESPACO, w = L.EXTRA_W, h = L.EXTRA_H }
	end
	return lista
end

-- Lista de habilidades à esquerda da roda, com a base alinhada à dela. Estreita-se para não tocar
-- os cartões do grupo em telas pequenas.
function L.lista(vx: number, vy: number, linhas: number, comAbas: boolean): Retangulo
	local lo = L.roda(vx, vy)
	local direita = lo.x - L.GAP
	local esquerda = L.CARTAO_X + L.CARTAO_LARGURA + L.GAP
	local w = math.max(120, math.min(L.LISTA_LARGURA, direita - esquerda))
	local n = math.max(1, math.min(linhas, L.LISTA_MAX_LINHAS))
	local h = L.alturaLista(n) + (if comAbas then L.LINHA + L.ESPACO else 0)
	return { x = direita - w, y = vy - L.MARGEM - h, w = w, h = h }
end

-- Coluna da ordem dos turnos, à esquerda. O primeiro (quem age) é maior. Se não couberem todos, o
-- último espaço vira "+N" (`resto`). Devolve os retângulos na ordem (inclui o do "+N", se houver).
function L.ordemColuna(vx: number, vy: number, total: number): { rects: { Retangulo }, mostrados: number, resto: number }
	local disponivel = vy - L.ORDEM_Y - L.MARGEM
	local capacidade = 1
	if disponivel >= L.ORDEM_ATIVO then
		capacidade = 1 + math.floor((disponivel - L.ORDEM_ATIVO) / (L.ORDEM_ITEM + L.ORDEM_GAP))
	end
	local mostrados = total
	local resto = 0
	if total > capacidade then
		mostrados = math.max(1, capacidade - 1)
		resto = total - mostrados
	end
	local rects = {}
	local y = L.ORDEM_Y
	for i = 1, mostrados + (if resto > 0 then 1 else 0) do
		local lado = if i == 1 then L.ORDEM_ATIVO else L.ORDEM_ITEM
		table.insert(rects, { x = L.MARGEM + (L.ORDEM_ATIVO - lado) / 2, y = y, w = lado, h = lado })
		y += lado + L.ORDEM_GAP
	end
	return { rects = rects, mostrados = mostrados, resto = resto }
end

-- Cartões do grupo, empilhados no canto inferior esquerdo (o primeiro por cima). O cartão de quem age
-- (`ativo`, índice) é mais alto. Coordenadas absolutas.
function L.cartoes(vx: number, vy: number, n: number, ativo: number?): { Retangulo }
	n = math.min(n, L.MAX_CARTOES)
	local alturas, soma = {}, 0
	for i = 1, n do
		alturas[i] = if i == ativo then L.CARTAO_ATIVO else L.CARTAO_ALTURA
		soma += alturas[i]
	end
	soma += math.max(0, n - 1) * L.ESPACO
	local lista, y = {}, vy - L.MARGEM - soma
	for i = 1, n do
		lista[i] = { x = L.CARTAO_X, y = y, w = L.CARTAO_LARGURA, h = alturas[i] }
		y += alturas[i] + L.ESPACO
	end
	return lista
end

-- Cartão do próprio personagem fora da luta (canto superior direito, abaixo da faixa do dia).
function L.cartaoFora(vx: number): Retangulo
	return { x = vx - L.MARGEM - L.CARTAO_LARGURA, y = 144, w = L.CARTAO_LARGURA, h = L.CARTAO_ATIVO }
end

return L
