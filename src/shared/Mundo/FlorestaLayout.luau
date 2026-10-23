-- Dados geométricos puros da Floresta Sombria, ao sul da vila.
local FlorestaLayout = {}

FlorestaLayout.ID = "region/floresta-sombria"
FlorestaLayout.SOLO = { x = 0, z = -450, sx = 220, sz = 300 } -- z=-600..-300
FlorestaLayout.TRILHA = { x = 0, z = -403, sx = 10, sz = 106 } -- continua da vila até a clareira
FlorestaLayout.CLAREIRA = { x = 0, z = -485, sx = 58, sz = 58 }
FlorestaLayout.MARCO = { x = 0, z = -485 }

-- Mata em malha 9.5 studs, jitter limitado: distância mínima entre vizinhos >=8.
-- Nas bordas todos os candidatos; perto da trilha remove alternados. Copas se sobrepõem.
FlorestaLayout.ARVORES = {}
FlorestaLayout.PASSO_ARVORES = 9.5
local function sobrepoe(a, b)
	return math.abs(a.x-b.x) < (a.sx+b.sx)/2 and math.abs(a.z-b.z) < (a.sz+b.sz)/2
end
for ix = 0, 19 do
	for iz = 0, 28 do
		local h = (ix * 73856093 + iz * 19349663 + 416) % 65521
		local x = -90.25 + ix * FlorestaLayout.PASSO_ARVORES + (h % 15 - 7) / 10
		local z = -316 - iz * FlorestaLayout.PASSO_ARVORES + (math.floor(h/15) % 15 - 7) / 10
		local f = if h % 5 == 0 then "carvalhoantigo" else "abeto"
		local escala = 0.88 + (h % 9) / 100
		local giro = (h % 4) * 90
		local d = (if f == "abeto" then 14.354 else 21.765) * escala
		local ret = { x=x, z=z, sx=d, sz=d }
		local trilha = FlorestaLayout.TRILHA
		local clareira = FlorestaLayout.CLAREIRA
		local livre = not sobrepoe(ret, { x=trilha.x, z=trilha.z, sx=trilha.sx+12, sz=trilha.sz+12 })
			and not sobrepoe(ret, { x=clareira.x, z=clareira.z, sx=clareira.sx+16, sz=clareira.sz+16 })
		if math.abs(x) < 40 and h % 3 == 0 then livre = false end
		if livre then table.insert(FlorestaLayout.ARVORES, { x,z,escala,f,giro }) end
	end
end

FlorestaLayout.OBSTACULOS = { { x = 6, z = 8 }, { x = 6, z = 9 }, { x = 15, z = 12 }, { x = 15, z = 13 } }

function FlorestaLayout.sobrepoe(a, b)
	return math.abs(a.x - b.x) < (a.sx + b.sx) / 2 and math.abs(a.z - b.z) < (a.sz + b.sz) / 2
end

function FlorestaLayout.contem(fora, dentro)
	return math.abs(dentro.x - fora.x) + dentro.sx / 2 <= fora.sx / 2
		and math.abs(dentro.z - fora.z) + dentro.sz / 2 <= fora.sz / 2
end

function FlorestaLayout.arvoreRetangulo(arvore, indice)
	local raio = (if arvore[4] == "abeto" then 14.354 else 21.765) * arvore[3] / 2
	return { id = "arvore-" .. indice, x = arvore[1], z = arvore[2], sx = raio * 2, sz = raio * 2 }
end

function FlorestaLayout.validar(vila, regiao)
	local problemas = {}
	if FlorestaLayout.sobrepoe(FlorestaLayout.SOLO, vila) then table.insert(problemas, "solo sobrepoe vila") end
	if FlorestaLayout.sobrepoe(FlorestaLayout.SOLO, regiao) then table.insert(problemas, "solo sobrepoe regiao") end
	for _, ret in ipairs({ FlorestaLayout.TRILHA, FlorestaLayout.CLAREIRA }) do
		if not FlorestaLayout.contem(FlorestaLayout.SOLO, ret) then table.insert(problemas, "area fora do solo") end
	end
	if FlorestaLayout.TRILHA.z + FlorestaLayout.TRILHA.sz / 2 ~= -350 then
		table.insert(problemas, "trilha nao conecta com a trilha da vila")
	end
	if FlorestaLayout.TRILHA.z - FlorestaLayout.TRILHA.sz / 2 ~= FlorestaLayout.CLAREIRA.z + FlorestaLayout.CLAREIRA.sz / 2 then
		table.insert(problemas, "trilha nao chega a clareira")
	end
	local corredor = FlorestaLayout.TRILHA
	local arena = FlorestaLayout.CLAREIRA
	for i, arvore in ipairs(FlorestaLayout.ARVORES) do
		local ret = FlorestaLayout.arvoreRetangulo(arvore, i)
		if not FlorestaLayout.contem(FlorestaLayout.SOLO, ret) then table.insert(problemas, ret.id .. " fora do solo") end
		if FlorestaLayout.sobrepoe(ret, corredor) or FlorestaLayout.sobrepoe(ret, arena) then
			table.insert(problemas, ret.id .. " bloqueia trilha ou clareira")
		end
	end
	return problemas
end

return FlorestaLayout
