-- Tochas do esgoto (CEN2): suporte, cabo, miolo da chama, partículas de fogo, brasas e fumaça.
-- O brilho da luz oscila no cliente (EsgotoAnimacao, tag EsgotoTocha), com ruído e não seno regular.
local CollectionService = game:GetService("CollectionService")
local EsgotoPecas = require(script.Parent.EsgotoPecas)
local peca = EsgotoPecas.peca

local EsgotoTochas = {}
EsgotoTochas.TAG = "EsgotoTocha"

local function emissor(pai, nome, textura, props)
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture = nome, textura
	for k, v in props do (e :: any)[k] = v end
	e.Parent = pai
	return e
end

-- `L` posiciona no frame da parede; `x` é a posição ao longo dela.
function EsgotoTochas.montar(pasta, L, meia, x, semente)
	local FERRO = EsgotoPecas.FERRO
	peca(pasta, "TochaSuporte", Vector3.new(0.7, 0.7, 2.4), L(x, 13, -meia + 3.4), FERRO, Enum.Material.Metal)
	peca(pasta, "TochaAro", Vector3.new(2.2, 0.5, 2.2), L(x, 15.9, -meia + 4.4), FERRO, Enum.Material.Metal)
	peca(pasta, "TochaCabo", Vector3.new(0.9, 3, 0.9), L(x, 14.4, -meia + 4.4), Color3.fromRGB(70, 46, 28), Enum.Material.Wood)
	local chama = peca(pasta, "Tocha", Vector3.new(1.1, 1.5, 1.1), L(x, 16.6, -meia + 4.4), Color3.fromRGB(255, 120, 40), Enum.Material.Neon,
		{ Shape = Enum.PartType.Ball, CastShadow = false })
	local luz = EsgotoPecas.luz(chama, Color3.fromRGB(255, 154, 78), 2.6, 38)
	luz:SetAttribute("BrilhoBase", luz.Brightness)
	luz:SetAttribute("AlcanceBase", luz.Range)
	chama:SetAttribute("Semente", semente)
	local fogo = "rbxasset://textures/particles/fire_main.dds"
	local brilho = "rbxasset://textures/particles/sparkles_main.dds"
	emissor(chama, "Chama", fogo, {
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(220, 70, 20)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.2), NumberSequenceKeypoint.new(0.5, 2.4), NumberSequenceKeypoint.new(1, 0.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9), Rate = 40, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(14, 14),
		Acceleration = Vector3.new(0, 4, 0), LightEmission = 1, RotSpeed = NumberRange.new(-60, 60),
	})
	emissor(chama, "Brasa", brilho, {
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 70)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.04) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.4, 3), Rate = 6, Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 2.5, 0), LightEmission = 1,
	})
	emissor(chama, "Fumaca", "rbxasset://textures/particles/smoke_main.dds", {
		Color = ColorSequence.new(Color3.fromRGB(40, 40, 40)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2, 3.2), Rate = 2.5, Speed = NumberRange.new(2.5, 4), SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 1.5, 0), LightInfluence = 0.5, RotSpeed = NumberRange.new(-20, 20),
	})
	CollectionService:AddTag(chama, EsgotoTochas.TAG)
	return chama
end

return EsgotoTochas
