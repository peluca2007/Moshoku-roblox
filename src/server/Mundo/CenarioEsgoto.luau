-- Cenário fechado do esgoto (CEN1): paredes de pedra com arcos e túneis, abóbada, canos, grades, água parada,
-- tochas e feixes de luz. Só peças do Roblox com materiais (sem ativo externo). Não mexe na grade: tudo
-- fora do tabuleiro ou plano e sem colisão/consulta. ArenaCenario chama `montar` ao construir a arena.
-- Coordenadas locais de cada parede: o lado de dentro olha para +z; `girar` (graus) espalha as quatro.
local EsgotoPecas = require(script.Parent.EsgotoPecas)
local EsgotoArcos = require(script.Parent.EsgotoArcos)
local EsgotoAgua = require(script.Parent.EsgotoAgua)
local EsgotoTochas = require(script.Parent.EsgotoTochas)
local EsgotoSujeira = require(script.Parent.EsgotoSujeira)

local CenarioEsgoto = {}

local MEIA = 86 -- metade do vão interno (o tabuleiro ocupa ±50)
local ALTURA_TETO = 36
CenarioEsgoto.ALTURA_TETO = ALTURA_TETO

local PEDRA, PEDRA_ESCURA, MUSGO = EsgotoPecas.PEDRA, EsgotoPecas.PEDRA_ESCURA, EsgotoPecas.MUSGO
local FERRO, FERRUGEM, AGUA, VAZIO = EsgotoPecas.FERRO, EsgotoPecas.FERRUGEM, EsgotoPecas.AGUA, EsgotoPecas.VAZIO
local peca, luz = EsgotoPecas.peca, EsgotoPecas.luz

-- Vãos (arcos) de cada parede, por x local, e posição das tochas.
local PAREDES = {
	{ girar = 0, arcos = { -40, 40 }, tochas = { -16, 16 }, grade = 0, sombra = true },
	{ girar = 180, arcos = { 0 }, tochas = { -34, 34 }, grade = -52, sombra = true },
	{ girar = 90, arcos = { 0 }, tochas = { -26, 26 }, grade = 50 },
	{ girar = -90, arcos = { -30, 30 }, tochas = { 0 }, grade = 0 },
}

local function parede(pasta, base, cfg, tem)
	local function L(x, y, z) return base * CFrame.new(x, y, z) end
	local variante = tem and "EsgotoPedra" or nil
	local fatias = {}
	-- Fatias de parede entre os arcos (vão de 22 de largura, 17 de altura).
	local cursor = -MEIA - 4
	local arcos = table.clone(cfg.arcos)
	table.sort(arcos)
	for _, ax in arcos do
		table.insert(fatias, { cursor, ax - 11 })
		cursor = ax + 11
	end
	table.insert(fatias, { cursor, MEIA + 4 })
	for i, f in fatias do
		local larg = f[2] - f[1]
		peca(pasta, "Parede", Vector3.new(larg, ALTURA_TETO, 4), L((f[1] + f[2]) / 2, ALTURA_TETO / 2, -MEIA),
			(i % 2 == 0) and PEDRA or PEDRA_ESCURA, Enum.Material.Plastic, { variante = variante })
		-- Pilastra a cada ~28 studs, saliente, de tom diferente: quebra o paredão liso.
		local passo = math.max(1, math.floor(larg / 28))
		for k = 1, passo do
			local px = f[1] + larg * (k - 0.5) / passo
			peca(pasta, "Pilastra", Vector3.new(4.5, ALTURA_TETO - 3, 2.4), L(px, (ALTURA_TETO - 3) / 2, -MEIA + 3),
				PEDRA, Enum.Material.Slate)
			peca(pasta, "Base", Vector3.new(6.5, 3, 3.4), L(px, 1.5, -MEIA + 3.2), PEDRA_ESCURA, Enum.Material.Slate)
		end
		-- Limo escorrendo do alto.
		local lx = f[1] + larg * 0.3
		peca(pasta, "Limo", Vector3.new(3.4, 9 + (i * 5) % 7, 0.2), L(lx, ALTURA_TETO - 5, -MEIA + 2.15), MUSGO, Enum.Material.Grass, { Transparency = 0.15 })
	end
	for _, ax in arcos do
		EsgotoArcos.vao(pasta, L, ax, MEIA, ALTURA_TETO)
		-- Túnel: chão, laterais, teto e fundo escuros, com um fio de água e luz verde ao longe.
		local fundo = 34
		peca(pasta, "TunelChao", Vector3.new(22, 1, fundo), L(ax, -0.5, -MEIA - fundo / 2), PEDRA_ESCURA, Enum.Material.Slate)
		EsgotoAgua.canal(pasta, "TunelAgua", Vector3.new(7, 0.15, fundo), L(ax, 0.1, -MEIA - fundo / 2))
		peca(pasta, "TunelParede", Vector3.new(1, 30, fundo), L(ax - 11.5, 15, -MEIA - fundo / 2), VAZIO, Enum.Material.Slate)
		peca(pasta, "TunelParede", Vector3.new(1, 30, fundo), L(ax + 11.5, 15, -MEIA - fundo / 2), VAZIO, Enum.Material.Slate)
		peca(pasta, "TunelTeto", Vector3.new(24, 1, fundo), L(ax, 29.5, -MEIA - fundo / 2), VAZIO, Enum.Material.Slate)
		peca(pasta, "TunelFundo", Vector3.new(24, 30, 1), L(ax, 15, -MEIA - fundo), Color3.fromRGB(5, 8, 7), Enum.Material.SmoothPlastic)
		luz(peca(pasta, "TunelLuz", Vector3.new(1, 1, 1), L(ax, 8, -MEIA - fundo + 6), VAZIO, Enum.Material.SmoothPlastic, { Transparency = 1 }),
			Color3.fromRGB(70, 120, 100), 0.5, 22)
		-- Água que sai do túnel e vira canaleta no chão do salão (fora do tabuleiro: z < -50).
		EsgotoAgua.canal(pasta, "Canaleta", Vector3.new(7, 0.14, MEIA - 50 + 2), L(ax, 0.09, -MEIA + (MEIA - 50) / 2 + 1))
		peca(pasta, "MargemCanaleta", Vector3.new(9.4, 0.1, MEIA - 50 + 2), L(ax, 0.05, -MEIA + (MEIA - 50) / 2 + 1), MUSGO, Enum.Material.Grass)
	end
	-- Canos horizontais com suportes e manchas de ferrugem.
	for h, y in { 26, 30.5 } do
		local c = peca(pasta, "Cano", Vector3.new(2 * MEIA, 2.2, 2.2), L(0, y, -MEIA + 3.4), (h == 1) and FERRO or FERRUGEM, Enum.Material.Metal)
		c.Shape = Enum.PartType.Cylinder
		for sx = -MEIA + 12, MEIA - 12, 24 do
			peca(pasta, "Suporte", Vector3.new(1, 3.6, 1.4), L(sx + h * 6, y, -MEIA + 2.6), FERRO, Enum.Material.Metal)
		end
	end
	-- Grade na parede com água caindo (uma por parede, quando pedida).
	if cfg.grade then
		local gx = cfg.grade
		peca(pasta, "GradeMoldura", Vector3.new(11, 7, 0.8), L(gx, 12, -MEIA + 2.4), FERRO, Enum.Material.Metal)
		peca(pasta, "GradeFundo", Vector3.new(9.4, 5.4, 0.4), L(gx, 12, -MEIA + 2.1), VAZIO, Enum.Material.SmoothPlastic)
		for b = -4, 4, 2 do
			peca(pasta, "GradeBarra", Vector3.new(0.5, 5.6, 0.5), L(gx + b, 12, -MEIA + 2.9), FERRO, Enum.Material.Metal)
		end
		peca(pasta, "Queda", Vector3.new(6, 11, 0.3), L(gx, 5.4, -MEIA + 3.2), Color3.fromRGB(140, 190, 170), Enum.Material.Glass, { Transparency = 0.6 })
		EsgotoAgua.canal(pasta, "Respingo", Vector3.new(9, 0.12, 9), L(gx, 0.08, -MEIA + 7))
	end
	-- Tochas: chama com partículas e luz que oscila no cliente.
	for k, tx in cfg.tochas do
		EsgotoTochas.montar(pasta, L, MEIA, tx, (cfg.girar + 360) % 360 + k * 7, cfg.sombra and k == 1)
	end
	EsgotoSujeira.parede(pasta, L, MEIA, fatias, 100 + (cfg.girar + 360) % 360)
end

-- Chão: remendos de materiais e cores diferentes, musgo e poças; quebra a repetição do EsgotoPedra.
local function chao(pasta, origem)
	local r = Random.new(11)
	local materiais = { Enum.Material.Cobblestone, Enum.Material.Concrete, Enum.Material.Pebble, Enum.Material.Mud, Enum.Material.Slate }
	local function remendo(nome, cx, cz, w, d, topo, cor, material, extra)
		return peca(pasta, nome, Vector3.new(w, 0.02, d), CFrame.new(origem.X + cx, topo, origem.Z + cz) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), cor, material, extra)
	end
	local function cinza(v) return Color3.fromRGB(v * 0.92, v, v * 0.94) end
	-- Dentro do tabuleiro (topo em y=1): remendos baixos, longe de linhas.
	for i = 1, 12 do
		local w, d = r:NextNumber(6, 16), r:NextNumber(6, 16)
		remendo("Remendo", r:NextNumber(-40, 40), r:NextNumber(-40, 40), w, d, 1.011 + i * 0.0003, cinza(r:NextInteger(46, 92)), materiais[r:NextInteger(1, #materiais)])
	end
	for i = 1, 6 do
		remendo("Musgo", r:NextNumber(-44, 44), r:NextNumber(-44, 44), r:NextNumber(4, 10), r:NextNumber(4, 9), 1.0125 + i * 0.0003, MUSGO:Lerp(PEDRA, r:NextNumber(0, 0.4)), Enum.Material.Grass)
	end
	-- Poças de água parada (textura que desliza) e uma goteira do teto sobre as cinco primeiras.
	for i = 1, 9 do
		local d = r:NextNumber(5, 12)
		local centro = Vector3.new(origem.X + r:NextNumber(-38, 38), 1.0115 + i * 0.0003, origem.Z + r:NextNumber(-38, 38))
		EsgotoAgua.poca(pasta, centro, d, d * r:NextNumber(0.6, 1), r:NextNumber(0, math.pi))
		if i <= 5 then EsgotoAgua.goteira(pasta, Vector3.new(centro.X, ALTURA_TETO - 0.3, centro.Z), ALTURA_TETO - 1.3) end
	end
	-- Fora do tabuleiro (topo em y=0): remendos grandes e mais musgo junto às paredes.
	for i = 1, 8 do
		local ang = r:NextNumber(0, math.pi * 2)
		local raio = r:NextNumber(60, 80)
		remendo("RemendoFora", math.cos(ang) * raio, math.sin(ang) * raio, r:NextNumber(8, 18), r:NextNumber(8, 18), 0.03 + i * 0.001, cinza(r:NextInteger(40, 80)), materiais[r:NextInteger(1, #materiais)])
	end
	for i = 1, 7 do
		local ang = r:NextNumber(0, math.pi * 2)
		local raio = r:NextNumber(62, 82)
		remendo("MusgoFora", math.cos(ang) * raio, math.sin(ang) * raio, r:NextNumber(5, 11), r:NextNumber(5, 11), 0.05 + i * 0.001, MUSGO, Enum.Material.Grass)
	end
	EsgotoSujeira.cantos(pasta, origem, MEIA)
end

-- Abóbada: laje escura sobre tudo + nervuras curvas (a câmera do jogo fica abaixo dela, y~26).
local function teto(pasta, origem)
	local o = CFrame.new(origem.X, 0, origem.Z)
	peca(pasta, "Teto", Vector3.new(2 * MEIA + 12, 2, 2 * MEIA + 12), o * CFrame.new(0, ALTURA_TETO + 1, 0), Color3.fromRGB(58, 64, 62), Enum.Material.Slate)
	EsgotoArcos.nervuras(pasta, origem, MEIA, ALTURA_TETO, { -50, 0, 50 })
end

-- Feixes de luz que entram por grades do teto: grade escura, feixe translúcido e SpotLight para o chão.
local function feixes(pasta, origem)
	-- Luz-chave quente sobre a área de luta, vinda de um vão no teto, com sombra: dá forma a personagens e chão.
	local fonte = peca(pasta, "LuzChave", Vector3.new(1, 1, 1), CFrame.new(origem.X + 6, ALTURA_TETO - 3, origem.Z + 6), VAZIO, Enum.Material.SmoothPlastic, { Transparency = 1 })
	local chave = Instance.new("SpotLight")
	chave.Color, chave.Brightness, chave.Range, chave.Angle, chave.Face, chave.Shadows = Color3.fromRGB(255, 190, 125), 2, 80, 62, Enum.NormalId.Bottom, true
	chave.Parent = fonte
	for _, f in { { -22, -18 }, { 28, 22 } } do
		local x, z = origem.X + f[1], origem.Z + f[2]
		peca(pasta, "GradeTeto", Vector3.new(9, 0.6, 9), CFrame.new(x, ALTURA_TETO - 0.4, z), VAZIO, Enum.Material.Metal)
		for b = -3, 3, 2 do
			peca(pasta, "GradeTetoBarra", Vector3.new(0.5, 0.5, 9.4), CFrame.new(x + b, ALTURA_TETO - 0.9, z), FERRO, Enum.Material.Metal)
		end
		-- Poeira iluminada no lugar da placa translúcida: partículas suaves num volume invisível sob a grade.
		local volume = peca(pasta, "Feixe", Vector3.new(6, ALTURA_TETO - 4, 6), CFrame.new(x + 3, (ALTURA_TETO - 4) / 2 + 1.5, z + 3),
			VAZIO, Enum.Material.SmoothPlastic, { Transparency = 1, CastShadow = false })
		local poeira = Instance.new("ParticleEmitter")
		poeira.Texture = "rbxasset://textures/particles/smoke_main.dds"
		poeira.Shape = Enum.ParticleEmitterShape.Box
		poeira.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		poeira.Color = ColorSequence.new(Color3.fromRGB(190, 225, 210))
		poeira.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 6) })
		poeira.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.93), NumberSequenceKeypoint.new(0.7, 0.93), NumberSequenceKeypoint.new(1, 1) })
		poeira.Lifetime = NumberRange.new(7, 10)
		poeira.Rate = 5
		poeira.Speed = NumberRange.new(0.2, 0.6)
		poeira.Acceleration = Vector3.new(0, -0.3, 0)
		poeira.LightEmission = 0.7
		poeira.LightInfluence = 0
		poeira.RotSpeed = NumberRange.new(-6, 6)
		poeira.Parent = volume
		poeira:Emit(20)
		local spot = Instance.new("SpotLight")
		spot.Color, spot.Brightness, spot.Range, spot.Angle, spot.Face, spot.Shadows = Color3.fromRGB(200, 232, 220), 7, 70, 32, Enum.NormalId.Bottom, false
		spot.Parent = peca(pasta, "FeixeLuz", Vector3.new(1, 1, 1), CFrame.new(x, ALTURA_TETO - 1, z), VAZIO, Enum.Material.SmoothPlastic, { Transparency = 1 })
	end
end

-- Névoa baixa e esverdeada: poucos emissores largos e lentos junto ao chão.
local function nevoa(pasta, origem)
	for _, p in { { -30, 30 }, { 34, -34 }, { 0, 0 }, { -50, -40 }, { 50, 44 } } do
		local e = peca(pasta, "Nevoa", Vector3.new(30, 1, 30), CFrame.new(origem.X + p[1], 2.5, origem.Z + p[2]), VAZIO, Enum.Material.SmoothPlastic, { Transparency = 1 })
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(120, 160, 140))
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) })
		pe.Size = NumberSequence.new(18, 26)
		pe.Lifetime = NumberRange.new(9, 13)
		pe.Rate = 1.4
		pe.Speed = NumberRange.new(0.4, 1)
		pe.RotSpeed = NumberRange.new(-4, 4)
		pe.LightEmission = 0
		pe.LightInfluence = 0.6
		pe.Parent = e
		pe:Emit(3)
	end
end

function CenarioEsgoto.montar(raiz, origem, temVariante)
	local pasta = Instance.new("Folder")
	pasta.Name = "Cenario"
	for _, cfg in PAREDES do
		parede(pasta, CFrame.new(origem.X, 0, origem.Z) * CFrame.Angles(0, math.rad(cfg.girar), 0), cfg, temVariante)
	end
	chao(pasta, origem)
	teto(pasta, origem)
	feixes(pasta, origem)
	nevoa(pasta, origem)
	pasta.Parent = raiz
	return pasta
end

return CenarioEsgoto
