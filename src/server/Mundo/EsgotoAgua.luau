-- Água do esgoto (CEN2): canais, poças e queda com camadas de textura que rolam e gotejamento.
-- O servidor só monta e marca (CollectionService); client/EsgotoAnimacao anima (offset das texturas, gotas).
-- Textura: partícula nativa (sem ativo externo); duas camadas em velocidades e direções diferentes
-- dão a ideia de correnteza e de brilho na superfície.
local CollectionService = game:GetService("CollectionService")
local EsgotoPecas = require(script.Parent.EsgotoPecas)
local peca = EsgotoPecas.peca

local EsgotoAgua = {}

EsgotoAgua.TAG_AGUA = "EsgotoAgua"
EsgotoAgua.TAG_GOTA = "EsgotoGota"
local TEXTURA = "rbxasset://textures/particles/smoke_main.dds"

local function camadas(parte, face, camadasDef)
	for i, c in camadasDef do
		local t = Instance.new("Texture")
		t.Name = "Fluxo" .. i
		t.Texture = TEXTURA
		t.Face = face
		t.Color3 = c.cor
		t.Transparency = c.transparencia
		t.StudsPerTileU, t.StudsPerTileV = c.tile, c.tile
		t:SetAttribute("VelU", c.velU)
		t:SetAttribute("VelV", c.velV)
		t.Parent = parte
	end
	CollectionService:AddTag(parte, EsgotoAgua.TAG_AGUA)
end

local CORRENTEZA = {
	{ cor = Color3.fromRGB(150, 210, 190), transparencia = 0.55, tile = 9, velU = 0.35, velV = 2.4 },
	{ cor = Color3.fromRGB(70, 120, 110), transparencia = 0.65, tile = 6, velU = -0.5, velV = 1.5 },
}
local PARADA = {
	{ cor = Color3.fromRGB(120, 175, 160), transparencia = 0.65, tile = 8, velU = 0.18, velV = 0.12 },
	{ cor = Color3.fromRGB(70, 120, 110), transparencia = 0.72, tile = 5, velU = -0.15, velV = 0.2 },
}

-- Faixa de água corrente (comprimento em Z local da peça); `cf` é o centro.
function EsgotoAgua.canal(pasta, nome, tamanho, cf)
	local p = peca(pasta, nome, tamanho, cf, EsgotoPecas.AGUA, Enum.Material.SmoothPlastic, { Reflectance = 0.3 })
	camadas(p, Enum.NormalId.Top, CORRENTEZA)
	return p
end

-- Poça redonda no chão (cilindro deitado: o eixo X do cilindro aponta para cima).
function EsgotoAgua.poca(pasta, centro, diametroA, diametroB, giro)
	local p = peca(pasta, "Poca", Vector3.new(0.02, diametroA, diametroB), CFrame.new(centro) * CFrame.Angles(0, giro, math.rad(90)),
		EsgotoPecas.AGUA, Enum.Material.SmoothPlastic, { Reflectance = 0.3 })
	p.Shape = Enum.PartType.Cylinder
	camadas(p, Enum.NormalId.Right, PARADA)
	return p
end

-- Gotejamento: ponto no teto com um emissor de gota (cai até `queda` studs) e outro de respingo no chão.
-- O cliente dispara os dois em sequência (EsgotoAnimacao), então a gota e o respingo coincidem.
function EsgotoAgua.goteira(pasta, ponto, queda)
	local origem = peca(pasta, "Goteira", Vector3.new(0.4, 0.4, 0.4), CFrame.new(ponto), EsgotoPecas.VAZIO, Enum.Material.SmoothPlastic,
		{ Transparency = 1, CastShadow = false })
	local gota = Instance.new("ParticleEmitter")
	gota.Name = "Gota"
	gota.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	gota.Color = ColorSequence.new(Color3.fromRGB(170, 215, 205))
	gota.Size = NumberSequence.new(0.35, 0.3)
	gota.Transparency = NumberSequence.new(0.2)
	gota.Lifetime = NumberRange.new(math.sqrt(2 * queda / 90))
	gota.Speed = NumberRange.new(0)
	gota.Acceleration = Vector3.new(0, -90, 0)
	gota.Rate = 0
	gota.LightEmission = 0.4
	gota.Parent = origem
	local chao = Instance.new("Attachment")
	chao.Name = "Chao"
	chao.Position = Vector3.new(0, -queda, 0)
	chao.Parent = origem
	local respingo = Instance.new("ParticleEmitter")
	respingo.Name = "Respingo"
	respingo.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	respingo.Color = ColorSequence.new(Color3.fromRGB(170, 215, 205))
	respingo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
	respingo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	respingo.Lifetime = NumberRange.new(0.35, 0.6)
	respingo.Speed = NumberRange.new(3, 6)
	respingo.SpreadAngle = Vector2.new(50, 50)
	respingo.Acceleration = Vector3.new(0, -26, 0)
	respingo.Rate = 0
	respingo.LightEmission = 0.4
	respingo.Parent = chao
	CollectionService:AddTag(origem, EsgotoAgua.TAG_GOTA)
	return origem
end

return EsgotoAgua
