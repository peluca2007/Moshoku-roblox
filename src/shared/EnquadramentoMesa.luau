-- Geometria da câmera inicial; usa somente participantes já visíveis no snapshot.
-- Não cria Instances, não acompanha movimentos e não decide regras.
local E = { INCLINACAO = .35 }

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
		-- Duas casas de respiro; ao menos oito casas para não colar num único peão.
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

function E.altura(limites, viewport, area, fov)
	local tangente = math.tan(math.rad(fov / 2))
	local cos = 1 / math.sqrt(1 + E.INCLINACAO ^ 2)
	local sin = E.INCLINACAO * cos
	local pixels = math.max(1, viewport.y)
	local centroX, centroY = (area.x1 + area.x2) / 2, (area.y1 + area.y2) / 2
	local desvioX = 2 * (centroX - viewport.x / 2) * tangente / pixels
	local desvioY = 2 * (centroY - viewport.y / 2) * tangente / pixels
	local horizontal = math.max(1, area.x2 - area.x1) * tangente / pixels * .88
	local vertical = math.max(1, area.y2 - area.y1) * tangente / pixels * .88
	local metadeZ = limites.profundidade / 2
	-- Inclui perspectiva no lado próximo e deslocamento causado pelo HUD.
	local distancia = math.max(
		(limites.largura / 2 + math.abs(desvioX) * sin * metadeZ) / horizontal,
		math.abs(cos + desvioY * sin) * metadeZ / vertical
	) + sin * metadeZ
	return distancia * cos
end

return E
