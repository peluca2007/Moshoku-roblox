-- CEN4: relevo do esgoto em malha (KayKit Dungeon Remastered, CC0; tools/blender/kits/catalogo.py, módulos Modelos/EsgotoKK*).
-- Paredes de tijolo (fileira de baixo, 12 studs), pilares do chão ao teto, lajes no piso fora do tabuleiro e entulho.
-- Tudo ancorado, sem colisão nem consulta (câmera e mouse atravessam) e sem sombra própria. Sem os módulos enviados,
-- `disponivel()` é falso e o cenário de peças retas (CEN1–CEN3) continua como estava.
local Montar = require(script.Parent.MontarModelo)
local EsgotoPecas = require(script.Parent.EsgotoPecas)

local EsgotoMalhas = {}

local FILAS = 3
local TOM_ESGOTO = Color3.fromRGB(52, 78, 78)
local MODULOS = { "EsgotoKKParede", "EsgotoKKParedeQuebrada", "EsgotoKKPilar", "EsgotoKKPiso", "EsgotoKKPisoPedras", "EsgotoKKEntulho" }

function EsgotoMalhas.disponivel()
	for _, nome in MODULOS do
		if not Montar.existe(nome) then return false end
	end
	return true
end

-- Monta um módulo em `cf` (base no chão) e fecha as peças para o cenário. `escala` uniforme.
local function colocar(pasta, nome, cf, escala)
	local ok, modelo = pcall(Montar.montar, nome, pasta, cf, escala or 1)
	if not ok or not modelo then return nil end
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
			p.MaterialVariant = ""
			-- Pedra bege do pacote -> cinza-esverdeado do esgoto (a luz-chave quente e a Atmosphere da CEN3 fazem o resto).
			p.Color = p.Color:Lerp(TOM_ESGOTO, 0.82):Lerp(Color3.new(0, 0, 0), 0.08)
		end
	end
	return modelo
end

-- Fileira de baixo de uma parede: módulos de 12 studs lado a lado em cada trecho (`fatias` = {x0, x1} locais), com um
-- módulo quebrado de vez em quando. Frame local `L`: parede em z = -meia, lado de dentro olhando para +z, espessura 4.
function EsgotoMalhas.parede(pasta, L, meia, fatias, semente)
	local r = Random.new(semente)
	for _, f in fatias do
		local larg = f[2] - f[1]
		local n = math.max(1, math.floor(larg / 12 + 0.5))
		local esc = larg / (n * 12)
		for i = 1, n do
			local x = f[1] + larg * (i - 0.5) / n
			-- 3 fileiras de 12 studs (36 = altura do teto): sem laje lisa por cima; módulos quebrados de vez em quando.
			for fila = 0, FILAS - 1 do
				local nome = if r:NextNumber() < 0.14 then "EsgotoKKParedeQuebrada" else "EsgotoKKParede"
				colocar(pasta, nome, L(x, 12 * esc * fila, -meia + 2 + 1.5 * esc) * CFrame.Angles(0, math.pi, 0), esc)
			end
		end
		-- Pilares do chão ao teto, um a cada ~40 studs de trecho, um pouco à frente da parede.
		local npil = math.max(1, math.floor(larg / 40))
		for k = 1, npil do
			local px = f[1] + larg * (k - 0.5) / npil
			colocar(pasta, "EsgotoKKPilar", L(px, 0, -meia + 2 + 5.4), 1)
		end
	end
end

-- Lajes no piso fora do tabuleiro (|x| ou |z| > 50, até a parede) e entulho junto às paredes.
function EsgotoMalhas.piso(pasta, origem, meia)
	local r = Random.new(23)
	local base = CFrame.new(origem.X, -0.55, origem.Z)
	local largura = meia - 50 -- faixa entre o tabuleiro e a parede
	-- Chão de base sob as lajes: tapa os vãos escuros entre as lajes hexagonais (topo em y = 0).
	local fundo = Color3.fromRGB(40, 56, 56)
	for _, f in { { 0, meia + 50 / 2, 2 * meia + 8, largura + 4 }, { 0, -(meia + 50 / 2), 2 * meia + 8, largura + 4 } } do
		EsgotoPecas.peca(pasta, "BaseLajes", Vector3.new(f[3], 0.6, f[4]), CFrame.new(origem.X + f[1], -0.26, origem.Z + (f[2] > 0 and 50 + largura / 2 or -(50 + largura / 2))), fundo, Enum.Material.Slate)
	end
	for _, sx in { 1, -1 } do
		EsgotoPecas.peca(pasta, "BaseLajes", Vector3.new(largura + 4, 0.6, 100), CFrame.new(origem.X + sx * (50 + largura / 2), -0.26, origem.Z), fundo, Enum.Material.Slate)
	end
	local lado = largura / 2
	local function laje(x, z, tam)
		local nome = if r:NextNumber() < 0.12 then "EsgotoKKPisoPedras" else "EsgotoKKPiso"
		colocar(pasta, nome, base * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(r:NextInteger(0, 3) * 90), 0), tam / 16)
	end
	-- faixas norte e sul (largura total) e leste e oeste (só entre as duas)
	local nx = math.floor((2 * meia) / lado + 0.5)
	local tx = (2 * meia) / nx
	for i = 1, nx do
		local x = -meia + tx * (i - 0.5)
		for j = 1, 2 do
			local z = 50 + lado * (j - 0.5)
			laje(x, z, lado) laje(x, -z, lado)
		end
	end
	local nz = math.floor(100 / lado + 0.5)
	local tz = 100 / nz
	for i = 1, nz do
		local z = -50 + tz * (i - 0.5)
		for j = 1, 2 do
			local x = 50 + lado * (j - 0.5)
			laje(x, z, lado) laje(-x, z, lado)
		end
	end
	-- entulho nos cantos e junto às paredes
	for _ = 1, 14 do
		local ang = r:NextNumber(0, math.pi * 2)
		local raio = r:NextNumber(58, meia - 6)
		local x, z = math.cos(ang) * raio, math.sin(ang) * raio
		if math.abs(x) > 52 or math.abs(z) > 52 then
			colocar(pasta, "EsgotoKKEntulho", CFrame.new(origem.X + x, 0, origem.Z + z) * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0), r:NextNumber(0.7, 1.3))
		end
	end
end

return EsgotoMalhas
