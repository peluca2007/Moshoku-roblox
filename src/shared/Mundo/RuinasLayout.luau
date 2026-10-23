-- Ruínas do Vale em dados puros: solo, caminho de entrada, câmara do guardião e a lista
-- de peças (colunas, muros, arco, altar, lápides, vegetação). Passagem a pé pelo norte;
-- a viagem da run continua disponível até a integração do pacote de fluxo.
-- Coordenadas em studs no plano XZ; y=0 é o chão. Construtor: server/Mundo/Ruinas.
local Shared = game:GetService("ReplicatedStorage").Shared
local PropsLayout = require(Shared.Mundo.PropsLayout)
local Passagem = require(Shared.Mundo.PassagemLayout)

local RuinasLayout = {}

RuinasLayout.ID = "region/ruinas-do-vale"
RuinasLayout.SOLO = { x = 600, z = -200, sx = 240, sz = 200 } -- x 480..720, z -300..-100
RuinasLayout.NASCIMENTO = { x = 600, z = -114 }
RuinasLayout.CAMINHO = { x = 600, z = -172.5, sx = 8, sz = 125 } -- do arco (z=-110) à borda sul da câmara (z=-235)
RuinasLayout.CAMARA = { x = 600, z = -262, raio = 27 } -- praça circular com o altar do Selo
RuinasLayout.ARCO = { x = 600, z = -117 }
-- F6: centro geom?trico da grade 20?20 (36 studs), dentro da pra?a.
RuinasLayout.ARENA = { id = "region/encounter/ruinas", marco = "region/ruinas-do-vale/encontro/marco",
 x = 600, z = -262, passo = 1.8 }
-- Segmento livre entre as alamedas; mant?m dist?ncia da chegada e do altar.
RuinasLayout.PATRULHA = { { x = 600, z = -166 }, { x = 600, z = -192 } }


local function sorteador(semente)
	local estado = semente
	return function()
		estado = (estado * 1103515245 + 12345) % 2147483648
		return estado / 2147483648
	end
end

local function sobrepoe(a, b)
	return math.abs(a.x - b.x) < (a.sx + b.sx) / 2 and math.abs(a.z - b.z) < (a.sz + b.sz) / 2
end

-- { x, z, familia, escala relativa, giro em graus }
function RuinasLayout.pecas()
	local c = RuinasLayout.CAMARA
	local sorteio = sorteador(20261016)
	local lista = {
		{ RuinasLayout.ARCO.x, RuinasLayout.ARCO.z, "arco", 1, 0 },
		{ c.x, c.z, "altar", 1, 0 },
	}
	-- alamedas de colunas ao longo do caminho; algumas caídas
	for i = 0, 5 do
		local z = -138 - i * 18
		for _, lado in ipairs({ -1, 1 }) do
			local quebrada = sorteio() < 0.4
			table.insert(lista, { 600 + lado * 11, z, if quebrada then "colunaquebrada" else "coluna", 1, math.floor(sorteio() * 360) })
		end
	end
	-- muros em ruínas nos flancos, com falhas
	for i = 0, 9 do
		local z = -132 - i * 9.3
		for _, lado in ipairs({ -1, 1 }) do
			if sorteio() < 0.72 then
				table.insert(lista, { 600 + lado * 27, z, "muro", 1, 90 })
			end
		end
	end
	-- círculo de colunas em volta da câmara, com dois vãos (entrada e uma quebra)
	for i = 0, 11 do
		local ang = i * math.pi * 2 / 12
		local x, z = c.x + math.cos(ang) * (c.raio - 3), c.z + math.sin(ang) * (c.raio - 3)
		if math.abs(z - (c.z + c.raio - 3)) > 4 or math.abs(x - c.x) > 6 then -- deixa o norte (entrada) aberto
			local quebrada = i % 4 == 1
			table.insert(lista, { math.floor(x * 10) / 10, math.floor(z * 10) / 10, if quebrada then "colunaquebrada" else "coluna", 1, i * 30 })
		end
	end
	-- lápides e vegetação espalhadas fora do caminho, da câmara e das peças
	local fixos = {}
	for _, p in ipairs(lista) do table.insert(fixos, PropsLayout.retangulo(p)) end
	local caminho = { x = RuinasLayout.CAMINHO.x, z = RuinasLayout.CAMINHO.z, sx = RuinasLayout.CAMINHO.sx + 6, sz = RuinasLayout.CAMINHO.sz }
	local camara = { x = c.x, z = c.z, sx = c.raio * 2 + 4, sz = c.raio * 2 + 4 }
	local solo = RuinasLayout.SOLO
	local familias = { "colunahera", "escada", "colunahera", "lapide", "arvoremorta", "arbusto", "lapide", "arvoremorta", "rocha", "toco" }
	local colocados, tentativas = 0, 0
	while colocados < 70 and tentativas < 1500 do
		tentativas += 1
		local x = solo.x + (sorteio() - 0.5) * (solo.sx - 14)
		local z = solo.z + (sorteio() - 0.5) * (solo.sz - 14)
		local familia = familias[math.floor(sorteio() * #familias) + 1]
		local prop = { math.floor(x * 10) / 10, math.floor(z * 10) / 10, familia, math.floor((0.9 + sorteio() * 0.6) * 100) / 100, math.floor(sorteio() * 360) }
		local ret = PropsLayout.retangulo(prop)
		local folga = math.sqrt(ret.sx^2 + ret.sz^2) / 2 + 2
		local livre = not sobrepoe(ret, caminho) and not sobrepoe(ret, camara)
			and Passagem.distancia(ret.x, ret.z) > folga
		if livre then
			for _, f in ipairs(fixos) do
				if sobrepoe({ x = ret.x, z = ret.z, sx = ret.sx + 2, sz = ret.sz + 2 }, f) then livre = false break end
			end
		end
		if livre then
			table.insert(lista, prop)
			table.insert(fixos, ret)
			colocados += 1
		end
	end
	return lista
end

-- Problemas do layout (vazio quando consistente).
function RuinasLayout.validar(): { string }
	local problemas = {}
	local solo = RuinasLayout.SOLO
	local caminho = { x = RuinasLayout.CAMINHO.x, z = RuinasLayout.CAMINHO.z, sx = RuinasLayout.CAMINHO.sx, sz = RuinasLayout.CAMINHO.sz }
	local c = RuinasLayout.CAMARA
	local praca = { x = c.x, z = c.z, sx = c.raio * 2, sz = c.raio * 2 }
	if math.abs(RuinasLayout.NASCIMENTO.x - solo.x) > solo.sx / 2 or math.abs(RuinasLayout.NASCIMENTO.z - solo.z) > solo.sz / 2 then
		table.insert(problemas, "nascimento fora do solo")
	end
	if math.abs(praca.z - solo.z) + praca.sz / 2 > solo.sz / 2 then table.insert(problemas, "camara fora do solo") end
	if math.abs(RuinasLayout.CAMINHO.z - RuinasLayout.CAMINHO.sz / 2 - (c.z + c.raio)) > 3 then
		table.insert(problemas, "caminho nao chega a camara")
	end
	for i, p in ipairs(RuinasLayout.pecas()) do
		local ret = PropsLayout.retangulo(p)
		local nome = p[3] .. "-" .. i
		if math.abs(ret.x - solo.x) + ret.sx / 2 > solo.sx / 2 or math.abs(ret.z - solo.z) + ret.sz / 2 > solo.sz / 2 then
			table.insert(problemas, nome .. " fora do solo")
		end
		if p[3] ~= "arco" and p[3] ~= "altar" and sobrepoe(ret, caminho) then table.insert(problemas, nome .. " no caminho") end
		if p[3] ~= "altar" and p[3] ~= "coluna" and p[3] ~= "colunaquebrada" and sobrepoe(ret, praca) then
			table.insert(problemas, nome .. " na camara")
		end
	end
	return problemas
end

return RuinasLayout
