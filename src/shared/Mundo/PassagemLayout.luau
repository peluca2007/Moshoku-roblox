-- W1a: geometria pura compartilhada por Terrain e pelo scatter das ruínas.
-- Sai da trilha da sala em x=200 (antes do halo plano da sala, x>=220), desce ao sul e contorna a sala por fora.
local P = {
	largura = 16,
	polilinha = {
		{ x = 200, z = -5 }, { x = 200, z = -44 },
		{ x = 300, z = -52 }, { x = 380, z = -40 },
		{ x = 460, z = -68 }, { x = 540, z = -64 },
		{ x = 600, z = -100 }, { x = 600, z = -114 },
	},
	clareiras = {
		{ id = "passagem-oeste", x = 300, z = -52, raio = 14 },
		{ id = "passagem-central", x = 380, z = -40, raio = 14 },
		{ id = "passagem-leste", x = 460, z = -68, raio = 14 },
	},
	mirante = { id = "mirante-do-vale", x = 548, z = -76, raio = 10, alvo = { x = 600, z = -200 } },
	placas = {
		{ id = "entrada-oeste", x = 186, z = -24, raio = 4, texto = "Ruínas do Vale →", giro = 90 },
		{ id = "entrada-ruinas", x = 612, z = -98, raio = 4, texto = "← Vila do Caminho", giro = -90 },
	},
}

local function distanciaSegmento(x, z, a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local u = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((x - a.x - u * dx)^2 + (z - a.z - u * dz)^2)
end

function P.distancia(x, z)
	local d = math.huge
	for i = 2, #P.polilinha do
		d = math.min(d, distanciaSegmento(x, z, P.polilinha[i - 1], P.polilinha[i]) - P.largura / 2)
	end
	for _, c in ipairs(P.clareiras) do d = math.min(d, math.sqrt((x - c.x)^2 + (z - c.z)^2) - c.raio) end
	local c = P.mirante
	d = math.min(d, math.sqrt((x - c.x)^2 + (z - c.z)^2) - c.raio)
	for _, p in ipairs(P.placas) do d = math.min(d, math.sqrt((x - p.x)^2 + (z - p.z)^2) - p.raio) end
	-- Ruído de ponto flutuante nas bordas (ex. 1e-15) conta como dentro.
	if d < 1e-8 then return 0 end
	return d
end

function P.contem(x, z) return P.distancia(x, z) <= 1e-8 end

return P
