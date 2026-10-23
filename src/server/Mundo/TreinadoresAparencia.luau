-- Trajes visuais opcionais exportados de tools/blender/trajes.py.
-- As peças são dados, nunca scripts; se um modelo não foi importado, ele é ignorado.
local Encaixe = require(script.Parent.EncaixeCosmetico)

local Aparencia = {}
local Catalogo = require(game:GetService("ReplicatedStorage").Shared.Aparencia.Catalogo)
local Shared = game:GetService("ReplicatedStorage").Shared
local Dados = require(Shared.Mundo.TreinadoresAparenciaDados)
Aparencia.TRAJES = {}
for arvore, ids in Dados.TRAJES do
 local trajes = {}
 for _, id in ids do
  local p = Catalogo.PECAS[id]
  local o = p.encaixe.offset
  table.insert(trajes, {modulo=p.modulo, parte=p.encaixe.parte, offset=CFrame.new(o.x,o.y,o.z)})
 end
 Aparencia.TRAJES[arvore] = trajes
end

local Visual = require(Shared.Aparencia.Visual)

-- Compatibilidade para callers que já possuem uma descrição.
function Aparencia.descrever(descricao: HumanoidDescription, arvore: string)
	local perfil = Dados.POR_ARVORE[arvore]
	if not perfil then return end
	local base = Visual.descrever(perfil.aparencia, perfil.raceId)
	for _, campo in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
		"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale",
		"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face", "Shirt", "Pants", "GraphicTShirt" } do
		descricao[campo] = base[campo]
	end
	base:Destroy()
end

function Aparencia.aplicar(corpo: Model, arvore: string)
	local perfil = Dados.POR_ARVORE[arvore]
	if perfil then
		Visual.decorar(corpo, perfil.aparencia, perfil.raceId)
		corpo:SetAttribute("PoseOficio", perfil.pose)
	end
	for _, traje in Aparencia.TRAJES[arvore] or {} do
		Encaixe.montar(corpo, traje)
	end

	if arvore == "agua" then
		for _, nome in { "LeftHand", "RightHand" } do
			local mao = corpo:FindFirstChild(nome)
			if mao then
				local particulas = Instance.new("ParticleEmitter")
				particulas.Name = "AguaSutil"
				particulas.Rate = 3
				particulas.Lifetime = NumberRange.new(0.5, 0.9)
				particulas.Speed = NumberRange.new(0.2, 0.6)
				particulas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				particulas.Color = ColorSequence.new(Color3.fromRGB(75, 181, 234))
				particulas.Size = NumberSequence.new(0.12)
				particulas.Transparency = NumberSequence.new(0.4, 1)
				particulas.LightEmission = 0.4
				particulas.SpreadAngle = Vector2.new(30, 30)
				particulas.Parent = mao
			end
		end
	end
end

return Aparencia
