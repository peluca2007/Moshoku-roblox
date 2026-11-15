-- Geometria da câmera de luta (LUTA-A). Pura: só números, sem Instances, sem regra.
-- O BoardView passa os pontos dos combatentes vivos (centro das casas, em studs, relativos à origem
-- do tabuleiro), quem age, o giro (yaw), o campo de visão e a área livre da tela (sem o HUD); recebe o
-- ponto de foco e a distância da câmera.
--
-- Convenções: yaw = 0 olha para -Z (câmera do lado +Z do foco, como a mesa antiga); yaw > 0 gira a câmera
-- para a direita em volta do foco (a frente vira para -X). `pitch` em graus abaixo da horizontal.
-- Tamanho mínimo do personagem: uma figura de `altura` studs ocupa pelo menos FRACAO_1x1 da altura da tela
-- numa luta 1x1 e nunca menos de FRACAO_CHEIA numa luta cheia; se a caixa dos vivos não couber com esse
-- tamanho, a câmera para no limite e segue quem age, puxando para o centro do grupo só o que cabe.
local E = {
	INCLINACAO = 50, -- graus abaixo da horizontal
	ALTURA_FIGURA = 5.2, -- studs (avatar R15 em pé)
	FRACAO_1x1 = 1 / 8, -- piso numa luta 1x1 (pedido: >= 1/8)
	FRACAO_CHEIA = 1 / 11, -- piso em luta cheia (pedido: >= 1/12)
	FRACAO_MAX = 1 / 6, -- mais perto que isso, nunca
	MARGEM = 0.86, -- fração da área livre usada pela caixa
}

-- Participantes visíveis no snapshot (ordem do combate), em casas. Mantido para a câmera inicial antiga
-- e para o playtest g19.
function E.limites(tokens, ordem, board)
	local participantes = {}
	for _, id in ordem do participantes[id] = true end
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, token in tokens do
		if not participantes[token.id] or type(token.x) ~= "number" or type(token.z) ~= "number" then continue end
		minX, minZ = math.min(minX, token.x), math.min(minZ, token.z)
		maxX, maxZ = math.max(maxX, token.x), math.max(maxZ, token.z)
	end
	local function eixo(minimo, maximo, tamanho)
		if minimo == math.huge then return 0, tamanho end
		local inicio, fim = math.max(0, minimo - 3), math.min(tamanho, maximo + 2)
		local largura = math.min(tamanho, math.max(8, fim - inicio))
		inicio = math.clamp((inicio + fim - largura) / 2, 0, tamanho - largura)
		return inicio, inicio + largura
	end
	local x1, x2 = eixo(minX, maxX, board.width)
	local z1, z2 = eixo(minZ, maxZ, board.height)
	return {
		x = ((x1 + x2) / 2 - board.width / 2) * board.cell,
		z = ((z1 + z2) / 2 - board.height / 2) * board.cell,
		largura = (x2 - x1) * board.cell, profundidade = (z2 - z1) * board.cell,
	}
end

-- Combatentes vivos da ordem do combate, como pontos {x, z, id} em studs relativos à origem do tabuleiro
-- (centro da casa, como MesaProtocol.cellCenter). Derrotados, com 0 PV e ocultos ficam de fora.
function E.vivos(tokens, ordem, board)
	local participantes = {}
	for _, id in ordem or {} do participantes[id] = true end
	local pontos = {}
	for _, token in tokens or {} do
		if participantes[token.id] and type(token.x) == "number" and type(token.z) == "number"
			and not token.derrotado and not token.hidden and (token.pv == nil or token.pv > 0) then
			table.insert(pontos, {
				id = token.id,
				inimigo = token.criatura ~= nil,
				x = (token.x - 0.5 - board.width / 2) * board.cell,
				z = (token.z - 0.5 - board.height / 2) * board.cell,
			})
		end
	end
	return pontos
end

-- Giro inicial da luta: a câmera olha de lado para a linha entre o grupo e os inimigos (ÂNGULO_LATERAL
-- graus entre a direção da câmera e essa linha), para quem está atrás não ficar escondido por quem está
-- na frente. aliados/inimigos: listas de pontos {x, z}. Sem os dois lados, devolve 0.
E.ANGULO_LATERAL = 75
function E.yawLateral(aliados, inimigos): number
	local function centro(lista)
		local sx, sz = 0, 0
		for _, p in lista do sx += p.x; sz += p.z end
		return sx / #lista, sz / #lista
	end
	if #aliados == 0 or #inimigos == 0 then return 0 end
	local ax, az = centro(aliados)
	local ix, iz = centro(inimigos)
	local dx, dz = ix - ax, iz - az
	if dx * dx + dz * dz < 1e-6 then return 0 end
	-- direção horizontal da câmera = linha grupo->inimigos girada ÂNGULO_LATERAL (grupo fica à esquerda)
	local a = math.rad(E.ANGULO_LATERAL)
	local hx = dx * math.cos(a) + dz * math.sin(a)
	local hz = -dx * math.sin(a) + dz * math.cos(a)
	return math.atan2(-hx, -hz)
end

-- Base da câmera para (yaw, pitch): frente (da câmera para o foco), direita e cima da tela.
function E.base(yaw: number, pitchGraus: number)
	local p = math.rad(pitchGraus)
	local hx, hz = -math.sin(yaw), -math.cos(yaw) -- direção horizontal para onde a câmera olha
	local frente = { x = hx * math.cos(p), y = -math.sin(p), z = hz * math.cos(p) }
	local direita = { x = -hz, y = 0, z = hx }
	local cima = { x = hx * math.sin(p), y = math.cos(p), z = hz * math.sin(p) }
	return frente, direita, cima
end

local function dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end

-- Fração da altura da tela ocupada por uma figura em pé de `altura` studs vista a `distancia`.
function E.fracaoFigura(distancia: number, fov: number, pitchGraus: number?, altura: number?)
	local h = (altura or E.ALTURA_FIGURA) * math.cos(math.rad(pitchGraus or E.INCLINACAO))
	return h / (2 * math.max(distancia, 1e-3) * math.tan(math.rad(fov / 2)))
end

-- Distância em que a figura ocupa `fracao` da altura da tela.
function E.distanciaParaFracao(fracao: number, fov: number, pitchGraus: number?, altura: number?)
	local h = (altura or E.ALTURA_FIGURA) * math.cos(math.rad(pitchGraus or E.INCLINACAO))
	return h / (2 * fracao * math.tan(math.rad(fov / 2)))
end

-- Plano da câmera.
-- o = { pontos = {{x,z}}, ator = {x,z}?, yaw, pitch?, fov, viewport = {x,y}, area = {x1,y1,x2,y2}, altura? }
-- Devolve { foco = {x, y, z} (relativo à origem do tabuleiro), distancia, cabe, fracao }.
function E.plano(o)
	local pitch = o.pitch or E.INCLINACAO
	local altura = o.altura or E.ALTURA_FIGURA
	local fov = o.fov or 70
	local pontos = o.pontos or {}
	if #pontos == 0 and o.ator then pontos = { o.ator } end
	local frente, direita, cima = E.base(o.yaw or 0, pitch)
	local vpY = math.max(1, o.viewport.y)
	local tanPorPixel = math.tan(math.rad(fov / 2)) / (vpY / 2)
	local area = o.area
	local tx = math.max(40, area.x2 - area.x1) / 2 * tanPorPixel * E.MARGEM
	local ty = math.max(40, area.y2 - area.y1) / 2 * tanPorPixel * E.MARGEM

	-- Caixa dos vivos no chão.
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, p in pontos do
		minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
		minZ, maxZ = math.min(minZ, p.z), math.max(maxZ, p.z)
	end
	if minX == math.huge then minX, maxX, minZ, maxZ = 0, 0, 0, 0 end
	local yFoco = altura * 0.45

	-- Distância mínima para todos os pontos (pés e cabeça, meia casa de folga) caberem na área livre.
	local function distanciaParaCaber(cx: number, cz: number)
		local d = 0
		for _, p in pontos do
			for _, dy in { 0, altura } do
				for _, lado in { -1, 1 } do
					local v = { x = p.x - cx + direita.x * lado * 1.6, y = dy - yFoco, z = p.z - cz + direita.z * lado * 1.6 }
					local x, y, prof = dot(v, direita), dot(v, cima), dot(v, frente)
					d = math.max(d, math.abs(x) / tx - prof, math.abs(y) / ty - prof)
				end
			end
		end
		return d
	end

	local n = #pontos
	local mistura = math.clamp((n - 2) / 4, 0, 1) -- 2 vivos = 1x1; 6 ou mais = luta cheia
	local fracaoMin = E.FRACAO_1x1 + (E.FRACAO_CHEIA - E.FRACAO_1x1) * mistura
	local dMax = E.distanciaParaFracao(fracaoMin, fov, pitch, altura)
	local dMin = E.distanciaParaFracao(E.FRACAO_MAX, fov, pitch, altura)

	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local d = distanciaParaCaber(cx, cz)
	local cabe = d <= dMax
	if not cabe and o.ator then
		-- Não cabe: fica no limite e segue quem age; puxa para o centro do grupo só uma parte da
		-- área visível (35%), para quem age ficar perto do meio da área livre.
		d = dMax
		local ox, oz = cx - o.ator.x, cz - o.ator.z
		local meiaLargura = tx * d * 0.35
		local meiaProfundidade = ty * d / math.max(0.3, math.sin(math.rad(pitch))) * 0.35
		local hx, hz = -math.sin(o.yaw or 0), -math.cos(o.yaw or 0)
		local lat = math.clamp(ox * direita.x + oz * direita.z, -meiaLargura, meiaLargura)
		local fun = math.clamp(ox * hx + oz * hz, -meiaProfundidade, meiaProfundidade)
		cx = o.ator.x + direita.x * lat + hx * fun
		cz = o.ator.z + direita.z * lat + hz * fun
	end
	d = math.clamp(d, dMin, dMax)
	return {
		foco = { x = cx, y = yFoco, z = cz },
		distancia = d,
		cabe = cabe,
		fracao = E.fracaoFigura(d, fov, pitch, altura),
	}
end

-- Visível na tela? (para a spec e para depuração) Devolve as coordenadas normalizadas [-1, 1] do ponto
-- {x, y, z} na área livre, dada a câmera de `plano`.
function E.projetar(plano, ponto, o)
	local frente, direita, cima = E.base(o.yaw or 0, o.pitch or E.INCLINACAO)
	local fov = o.fov or 70
	local vpY = math.max(1, o.viewport.y)
	local tanPorPixel = math.tan(math.rad(fov / 2)) / (vpY / 2)
	local area = o.area
	local tx = (area.x2 - area.x1) / 2 * tanPorPixel
	local ty = (area.y2 - area.y1) / 2 * tanPorPixel
	local v = { x = ponto.x - plano.foco.x, y = ponto.y - plano.foco.y, z = ponto.z - plano.foco.z }
	local prof = plano.distancia + dot(v, frente)
	return dot(v, direita) / (prof * tx), dot(v, cima) / (prof * ty)
end

return E
