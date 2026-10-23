-- Manchas de chão (grama mais clara/escura, terra, folhagem caída, musgo) que quebram a
-- monotonia do solo plano. Dados puros: posição, raio e tipo, sem Instances. As manchas
-- ficam fora de vias, praça, prédios, clareira e árvores (spec MundoChaoLayout).
local Shared = game:GetService("ReplicatedStorage").Shared
local VilaLayout = require(Shared.Mundo.VilaLayout)
local FlorestaLayout = require(Shared.Mundo.FlorestaLayout)
local RuinasLayout = require(Shared.Mundo.RuinasLayout)
local RegiaoLayout = require(Shared.Mundo.RegiaoLayout)

local ChaoLayout = {}

-- cor RGB, material (nome de Enum.Material) e espessura de cada tipo.
ChaoLayout.TIPOS = {
	gramaClara = { cor = { 112, 152, 76 }, material = "Grass" },
	gramaEscura = { cor = { 66, 106, 56 }, material = "Grass" },
	terra = { cor = { 112, 100, 72 }, material = "Ground" },
	folhas = { cor = { 108, 94, 58 }, material = "Ground" },
	musgo = { cor = { 70, 112, 62 }, material = "Grass" },
	samambaia = { cor = { 52, 102, 60 }, material = "Grass" },
	lajes = { cor = { 126, 122, 116 }, material = "Slate" },
	musgoVelho = { cor = { 74, 100, 70 }, material = "Grass" },
}

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

local function gerar(semente, solo, proibidas, tipos, quantidade, raioMin, raioMax, aceita)
	local sorteio = sorteador(semente)
	local lista, tentativas = {}, 0
	while #lista < quantidade and tentativas < quantidade * 40 do
		tentativas += 1
		local raio = raioMin + sorteio() * (raioMax - raioMin)
		local x = solo.x + (sorteio() - 0.5) * (solo.sx - raio * 2 - 4)
		local z = solo.z + (sorteio() - 0.5) * (solo.sz - raio * 2 - 4)
		local ret = { x = x, z = z, sx = raio * 2, sz = raio * 2 }
		local livre = true
		for _, p in ipairs(proibidas) do
			if sobrepoe(ret, p) then livre = false break end
		end
		if livre and aceita and not aceita(x, z, raio) then livre = false end
		if livre then
			local tipo = tipos[math.floor(sorteio() * #tipos) + 1]
			table.insert(lista, { math.floor(x * 10) / 10, math.floor(z * 10) / 10, math.floor(raio * 10) / 10, tipo, #lista % 4 })
		end
	end
	return lista
end

-- { x, z, raio, tipo, camada } — `camada` (0-3) separa a altura para evitar z-fighting.
function ChaoLayout.vila()
	local proibidas = {
		VilaLayout.PRACA, VilaLayout.POCO,
		{ x = VilaLayout.ESTRADA.x, z = VilaLayout.ESTRADA.z, sx = VilaLayout.ESTRADA.sx + 3, sz = VilaLayout.ESTRADA.sz },
		{ x = VilaLayout.TRILHA_FLORESTA.x, z = VilaLayout.TRILHA_FLORESTA.z, sx = VilaLayout.TRILHA_FLORESTA.sx + 3, sz = VilaLayout.TRILHA_FLORESTA.sz },
	}
	for _, e in ipairs(VilaLayout.EDIFICIOS) do
		local o = VilaLayout.ocupacao(e)
		table.insert(proibidas, { x = o.x, z = o.z, sx = o.sx + 3, sz = o.sz + 3 })
	end
	for _, b in ipairs(VilaLayout.BARRACAS) do
		table.insert(proibidas, { x = b.x, z = b.z, sx = b.sx + 3, sz = b.sz + 3 })
	end
	local solo = { x = VilaLayout.SOLO.x, z = VilaLayout.SOLO.z, sx = VilaLayout.SOLO.sx, sz = VilaLayout.SOLO.sz }
	return gerar(61, solo, proibidas, { "gramaClara", "gramaEscura", "gramaClara", "gramaEscura", "terra" }, 54, 3, 8)
end

function ChaoLayout.floresta()
	local proibidas = {
		{ x = FlorestaLayout.TRILHA.x, z = FlorestaLayout.TRILHA.z, sx = FlorestaLayout.TRILHA.sx + 3, sz = FlorestaLayout.TRILHA.sz },
		{ x = FlorestaLayout.CLAREIRA.x, z = FlorestaLayout.CLAREIRA.z, sx = FlorestaLayout.CLAREIRA.sx + 6, sz = FlorestaLayout.CLAREIRA.sz + 6 },
	}
	return gerar(73, FlorestaLayout.SOLO, proibidas, { "folhas", "musgo", "samambaia", "gramaEscura", "folhas", "terra" }, 90, 3, 9)
end

-- Região inicial: o critério vem de RegiaoLayout.proibido (trilhas giradas, arenas, acampamento, árvores).
function ChaoLayout.regiao()
	return gerar(97, RegiaoLayout.CAMPO, {}, { "gramaClara", "gramaEscura", "gramaClara", "terra", "gramaEscura" }, 70, 3, 9,
		function(x, z, raio) return not RegiaoLayout.proibido(x, z, raio) end)
end

function ChaoLayout.ruinas()
	local c = RuinasLayout.CAMINHO
	local k = RuinasLayout.CAMARA
	local proibidas = {
		{ x = c.x, z = c.z, sx = c.sx + 3, sz = c.sz },
		{ x = k.x, z = k.z, sx = k.raio * 2 + 3, sz = k.raio * 2 + 3 },
	}
	return gerar(83, RuinasLayout.SOLO, proibidas, { "lajes", "musgoVelho", "gramaEscura", "lajes", "folhas", "musgoVelho" }, 80, 3, 9)
end

-- Problemas de sobreposição com o que ficou de fora (vazio quando consistente).
function ChaoLayout.validar(): { string }
	local problemas = {}
	for rotulo, lista in { vila = ChaoLayout.vila(), floresta = ChaoLayout.floresta(), ruinas = ChaoLayout.ruinas() } do
		for i, m in ipairs(lista) do
			local ret = { x = m[1], z = m[2], sx = m[3] * 2, sz = m[3] * 2 }
			if rotulo == "vila" then
				if sobrepoe(ret, VilaLayout.PRACA) or sobrepoe(ret, VilaLayout.ESTRADA) or sobrepoe(ret, VilaLayout.TRILHA_FLORESTA) then
					table.insert(problemas, "vila " .. i .. " sobre via ou praca")
				end
				for _, e in ipairs(VilaLayout.EDIFICIOS) do
					if sobrepoe(ret, VilaLayout.ocupacao(e)) then table.insert(problemas, "vila " .. i .. " sobre " .. e.id) end
				end
			elseif rotulo == "ruinas" then
				if sobrepoe(ret, RuinasLayout.CAMINHO) or sobrepoe(ret, { x = RuinasLayout.CAMARA.x, z = RuinasLayout.CAMARA.z, sx = RuinasLayout.CAMARA.raio * 2, sz = RuinasLayout.CAMARA.raio * 2 }) then
					table.insert(problemas, "ruinas " .. i .. " sobre caminho ou camara")
				end
			else
				if sobrepoe(ret, FlorestaLayout.TRILHA) or sobrepoe(ret, FlorestaLayout.CLAREIRA) then
					table.insert(problemas, "floresta " .. i .. " sobre trilha ou clareira")
				end
			end
		end
	end
	return problemas
end

return ChaoLayout
