-- Decoração da região inicial (acampamento e campo) em dados puros. O terreno, as trilhas, a
-- clareira, o bosque e as árvores vêm de server/RegiaoInicial (dono: J4); aqui só se descreve
-- onde pôr barracas, fardos, placa, vegetação e manchas de chão SEM tocar em nada disso.
-- Os retângulos de trilha/arena abaixo repetem os números de RegiaoInicial e são vigiados
-- por spec (MundoRegiaoLayout). Coordenadas em studs no plano XZ; y=0 é o chão.
local Shared = game:GetService("ReplicatedStorage").Shared
local PropsLayout = require(Shared.Mundo.PropsLayout)

local RegiaoLayout = {}

RegiaoLayout.CAMPO = { x = 0, z = 0, sx = 240, sz = 240 }
RegiaoLayout.FOGUEIRA = { x = -4, z = -31 }
-- { centro x, centro z, largura, comprimento, giro em graus (Orientation Y) }
RegiaoLayout.TRILHAS = {
	{ 174, 0, 110, 14, 0 }, { 81, 20.5, 14, 92, 118 }, { -9, 53, 66, 8, 0 }, { 50, -15.5, 14, 145, -102.5 },
}
RegiaoLayout.ARENAS = { { 42, 41, 48, 54 }, { -42, 53, 48, 54 } }
RegiaoLayout.ARVORES = {
	{ -105, -60, 1.2 }, { -108, -22, 1 }, { -105, 23, 1.1 }, { -109, 67, 1.3 }, { -75, 105, 1 }, { -34, 108, 1.2 },
	{ 12, 108, 1.1 }, { 57, 106, 1.3 }, { 100, 100, 1.2 }, { 108, 64, 1 }, { 104, 20, 1.3 }, { 108, -24, 1.1 },
	{ 103, -69, 1.2 }, { 68, -106, 1 }, { 25, -108, 1.3 }, { -24, -108, 1.1 }, { -66, -105, 1.2 },
	{ -83, 47, 0.85 }, { 75, 70, 0.9 }, { 78, -62, 0.85 }, { -70, -10, 0.8 },
}
-- Zona do acampamento que o scatter nunca invade (as peças fixas abaixo ocupam o centro dela).
RegiaoLayout.ACAMPAMENTO = { x = -18, z = -30, sx = 54, sz = 44 }
RegiaoLayout.ENTRADA = { x = 110, z = 0 }

-- { x, z, familia, escala relativa, giro em graus }
RegiaoLayout.PECAS = {
	{ -14, -47, "tenda", 1, 0 }, { -30, -47, "tenda", 1, 0 }, { -6, -14, "tenda", 1, 180 },
	{ -34, -30, "fardo", 1, 90 }, { -34, -24, "fardo", 1, 70 },
	{ 4, -40, "placa", 1, 200 },
	{ -22, -40, "barril", 1, 0 }, { -20, -43.4, "barril", 1, 40 },
	{ -4, -31, "tripe", 1, 0 }, -- sobre a fogueira (peça decorativa, sem colisão relevante)
}

-- Ponto no retângulo girado (centro, tamanho, giro em graus) com folga `margem`.
function RegiaoLayout.dentroDaTrilha(x: number, z: number, trilha: { number }, margem: number): boolean
	local dx, dz = x - trilha[1], z - trilha[2]
	local a = math.rad(trilha[5])
	local xl = dx * math.cos(a) - dz * math.sin(a)
	local zl = dx * math.sin(a) + dz * math.cos(a)
	return math.abs(xl) <= trilha[3] / 2 + margem and math.abs(zl) <= trilha[4] / 2 + margem
end

-- Vale para qualquer ponto: está em algo que a decoração de campo não deve cobrir?
function RegiaoLayout.proibido(x: number, z: number, margem: number): boolean
	local c = RegiaoLayout.CAMPO
	if math.abs(x - c.x) > c.sx / 2 - 10 or math.abs(z - c.z) > c.sz / 2 - 10 then return true end
	for _, t in ipairs(RegiaoLayout.TRILHAS) do
		if RegiaoLayout.dentroDaTrilha(x, z, t, margem) then return true end
	end
	for _, a in ipairs(RegiaoLayout.ARENAS) do
		if math.abs(x - a[1]) <= a[3] / 2 + margem and math.abs(z - a[2]) <= a[4] / 2 + margem then return true end
	end
	local k = RegiaoLayout.ACAMPAMENTO
	if math.abs(x - k.x) <= k.sx / 2 + margem and math.abs(z - k.z) <= k.sz / 2 + margem then return true end
	for _, t in ipairs(RegiaoLayout.ARVORES) do
		local r = 5.5 * t[3] + margem
		if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 <= r * r then return true end
	end
	local e = RegiaoLayout.ENTRADA
	return math.abs(x - e.x) <= 14 + margem and math.abs(z - e.z) <= 14 + margem
end

local function sorteador(semente)
	local estado = semente
	return function()
		estado = (estado * 1103515245 + 12345) % 2147483648
		return estado / 2147483648
	end
end

-- Vegetação, pedras e troncos espalhados pelo campo, longe de trilhas, arenas, acampamento e árvores.
function RegiaoLayout.campo(): { { any } }
	local sorteio = sorteador(20261016)
	local lista, rets, tentativas = {}, {}, 0
	local familias = { "arbusto", "arbusto", "arbusto", "rocha", "arbusto", "tora", "rocha", "toco", "arbusto" }
	while #lista < 90 and tentativas < 4000 do
		tentativas += 1
		local x, z = (sorteio() - 0.5) * 220, (sorteio() - 0.5) * 220
		local familia = familias[math.floor(sorteio() * #familias) + 1]
		local prop = { math.floor(x * 10) / 10, math.floor(z * 10) / 10, familia, math.floor((0.85 + sorteio() * 0.5) * 100) / 100, math.floor(sorteio() * 360) }
		local ret = PropsLayout.retangulo(prop)
		local raio = math.max(ret.sx, ret.sz) / 2
		if not RegiaoLayout.proibido(prop[1], prop[2], raio + 1) then
			local livre = true
			for _, outro in ipairs(rets) do
				if math.abs(ret.x - outro.x) < (ret.sx + outro.sx) / 2 + 3 and math.abs(ret.z - outro.z) < (ret.sz + outro.sz) / 2 + 3 then
					livre = false
					break
				end
			end
			if livre then
				table.insert(lista, prop)
				table.insert(rets, ret)
			end
		end
	end
	local novos = 0
	for tentativa = 1, 5000 do
		if novos >= 160 then break end
		local x, z = (sorteio()-0.5)*210, (sorteio()-0.5)*210
		local f = if tentativa % 19 == 0 and math.abs(x) > 85 then "rochedo" elseif novos % 2 == 0 then "flores" else "tufo"
		local p = {x,z,f,0.65+sorteio()*0.25,math.floor(sorteio()*360)}
		local r = PropsLayout.retangulo(p)
		local livre = not RegiaoLayout.proibido(x,z,math.max(r.sx,r.sz)/2+1)
		for _, o in ipairs(rets) do
			if math.abs(r.x-o.x)<(r.sx+o.sx)/2+1 and math.abs(r.z-o.z)<(r.sz+o.sz)/2+1 then livre=false break end
		end
		if livre then table.insert(lista,p); table.insert(rets,r); novos+=1 end
	end
	local rochedos=0
	for _,x in ipairs({-94,94}) do
		for z=-90,90,12 do
			local p={x,z,"rochedo",0.7,0}
			local r=PropsLayout.retangulo(p)
			local livre=rochedos<3 and not RegiaoLayout.proibido(x,z,math.max(r.sx,r.sz)/2+1)
			for _,o in ipairs(rets) do
				if math.abs(r.x-o.x)<(r.sx+o.sx)/2+1 and math.abs(r.z-o.z)<(r.sz+o.sz)/2+1 then livre=false break end
			end
			if livre then table.insert(lista,p);table.insert(rets,r);rochedos+=1 end
		end
	end
	return lista
end

-- Problemas (vazio quando consistente): peças do acampamento dentro da zona, fora das trilhas
-- e sem sobrepor as peças fixas que RegiaoInicial já constrói.
function RegiaoLayout.validar(): { string }
	local problemas = {}
	local k = RegiaoLayout.ACAMPAMENTO
	-- Peças fixas de RegiaoInicial no acampamento (centro, tamanho x/z).
	local fixos = {
		{ -19, -31, 12, 10 }, { -4, -40, 7, 1.5 }, { -4, -22, 7, 1.5 }, { -28, -30, 4, 2 }, { -26, -35, 2.5, 2 }, { -30, -38, 0.5, 0.5 },
	}
	for i, p in ipairs(RegiaoLayout.PECAS) do
		local ret = PropsLayout.retangulo(p)
		local nome = p[3] .. "-" .. i
		if math.abs(ret.x - k.x) + ret.sx / 2 > k.sx / 2 or math.abs(ret.z - k.z) + ret.sz / 2 > k.sz / 2 then
			table.insert(problemas, nome .. " fora da zona do acampamento")
		end
		if p[3] ~= "tripe" then
			for _, t in ipairs(RegiaoLayout.TRILHAS) do
				if RegiaoLayout.dentroDaTrilha(ret.x, ret.z, t, math.max(ret.sx, ret.sz) / 2) then table.insert(problemas, nome .. " na trilha") end
			end
			for j, f in ipairs(fixos) do
				if math.abs(ret.x - f[1]) < (ret.sx + f[3]) / 2 and math.abs(ret.z - f[2]) < (ret.sz + f[4]) / 2 then
					table.insert(problemas, nome .. " sobrepoe peca fixa " .. j)
				end
			end
		end
		for j = 1, i - 1 do
			local o = PropsLayout.retangulo(RegiaoLayout.PECAS[j])
			if RegiaoLayout.PECAS[j][3] ~= "tripe" and p[3] ~= "tripe" and math.abs(ret.x - o.x) < (ret.sx + o.sx) / 2 and math.abs(ret.z - o.z) < (ret.sz + o.sz) / 2 then
				table.insert(problemas, nome .. " sobrepoe peca " .. j)
			end
		end
	end
	return problemas
end

return RegiaoLayout
