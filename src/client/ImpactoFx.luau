-- IMP1: faíscas no ponto de contato e rastro da arma durante o golpe. Peças locais (nascem em `pai`, que é o
-- modelo da cena e morre com ela). Texturas nativas do Roblox (rbxasset), nenhum asset enviado.
local Shared = game:GetService("ReplicatedStorage").Shared
local Curvas = require(Shared.ImpactoCurvas)
local FX = require(script.Parent.MenuEfeitos)

local M = {}
local TEX_BRILHO = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FUMACA = "rbxasset://textures/particles/smoke_main.dds"

-- Faíscas e clarão no ponto. `direcao`: de quem bateu para quem apanhou (as faíscas voam para o lado de quem bateu).
function M.faiscas(pai: Instance, ponto: Vector3, cor: Color3, dano: number?, critico: boolean?, direcao: Vector3?)
	if FX.reduzidos then return end
	local base = Instance.new("Part")
	base.Name, base.Anchored, base.CanCollide, base.CanTouch, base.CanQuery = "Faiscas", true, false, false, false
	base.Transparency, base.Size, base.CastShadow = 1, Vector3.one * 0.2, false
	local dir = direcao or Vector3.yAxis
	local plano = Vector3.new(dir.X, 0, dir.Z)
	base.CFrame = CFrame.lookAt(ponto, ponto - (if plano.Magnitude > 1e-3 then plano.Unit else Vector3.zAxis) + Vector3.new(0, 0.6, 0))
	base.Parent = pai
	local at = Instance.new("Attachment")
	at.Parent = base
	local quente = cor:Lerp(Color3.new(1, 1, 1), 0.55)

	local f = Instance.new("ParticleEmitter")
	f.Name, f.Texture, f.Rate, f.Enabled = "Faisca", TEX_BRILHO, 0, false
	f.LightEmission, f.LockedToPart = 1, false
	f.Color = ColorSequence.new(Color3.new(1, 1, 1), quente)
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if critico then 0.9 else 0.6), NumberSequenceKeypoint.new(1, 0) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	f.Lifetime = NumberRange.new(0.25, if critico then 0.65 else 0.45)
	f.Speed = NumberRange.new(14, if critico then 44 else 32)
	f.Acceleration = Vector3.new(0, -38, 0)
	f.Drag = 3
	f.EmissionDirection = Enum.NormalId.Front
	f.SpreadAngle = Vector2.new(70, 70)
	f.Rotation = NumberRange.new(0, 360)
	f.Parent = at

	local clarao = Instance.new("ParticleEmitter")
	clarao.Name, clarao.Texture, clarao.Rate, clarao.Enabled = "Clarao", TEX_BRILHO, 0, false
	clarao.LightEmission, clarao.LockedToPart = 1, true
	clarao.Color = ColorSequence.new(quente)
	clarao.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, if critico then 9 else 6) })
	clarao.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	clarao.Lifetime = NumberRange.new(0.12, 0.18)
	clarao.Speed = NumberRange.new(0)
	clarao.Parent = at

	local poeira = Instance.new("ParticleEmitter")
	poeira.Name, poeira.Texture, poeira.Rate, poeira.Enabled = "Poeira", TEX_FUMACA, 0, false
	poeira.Color = ColorSequence.new(Color3.fromRGB(150, 140, 125))
	poeira.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.5) })
	poeira.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	poeira.Lifetime = NumberRange.new(0.4, 0.7)
	poeira.Speed = NumberRange.new(3, 8)
	poeira.SpreadAngle = Vector2.new(180, 180)
	poeira.Parent = at

	f:Emit(Curvas.faiscas(dano, critico))
	clarao:Emit(1)
	poeira:Emit(if critico then 6 else 3)
	return base
end

-- Rastro na arma do fantasma `modelo`: acha a maior peça soldada (lâmina/cabo) e liga um Trail entre as pontas.
-- Devolve uma função que liga/desliga o rastro (ele some sozinho depois do `Lifetime`).
function M.rastro(modelo: Instance, cor: Color3): ((boolean?) -> ())?
	if FX.reduzidos then return nil end
	local melhor: BasePart? = nil
	local maior = 0
	for _, o in modelo:GetDescendants() do
		if o:IsA("Weld") and o.Part1 and o.Part1.Parent == modelo and o.Part1.Name ~= "HumanoidRootPart" then
			local p = o.Part1
			local m = math.max(p.Size.X, p.Size.Y, p.Size.Z)
			if m > maior and m >= 1.4 and m <= 4.5 and not p:FindFirstChildWhichIsA("Trail") then
				melhor, maior = p, m
			end
		end
	end
	if not melhor then return nil end
	local eixo = if melhor.Size.Y >= melhor.Size.X and melhor.Size.Y >= melhor.Size.Z then Vector3.yAxis
		elseif melhor.Size.Z >= melhor.Size.X then Vector3.zAxis else Vector3.xAxis
	local meia = maior / 2
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "RastroPonta", "RastroBase"
	a0.Position, a1.Position = eixo * meia, -eixo * meia * 0.15
	a0.Parent, a1.Parent = melhor, melhor
	local t = Instance.new("Trail")
	t.Name = "RastroDaArma"
	t.Attachment0, t.Attachment1 = a0, a1
	t.Lifetime, t.LightEmission, t.FaceCamera = 0.22, 0.9, true
	t.MinLength = 0.05
	t.Color = ColorSequence.new(Color3.new(1, 1, 1), cor)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	t.Enabled = false
	t.Parent = melhor
	return function(ligado: boolean?)
		if t.Parent then t.Enabled = ligado == true end
	end
end

return M
