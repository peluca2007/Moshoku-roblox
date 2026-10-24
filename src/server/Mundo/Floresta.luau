-- Constrói a Floresta Sombria; encontros continuam sob autoridade do serviço J2.
local Layout = require(game:GetService("ReplicatedStorage").Shared.Mundo.FlorestaLayout)
local Props = require(script.Parent.Props)
local PropsLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.PropsLayout)

local Floresta = {}
local NOME = "FlorestaSombria"
local VERDE_ESCURO = Color3.fromRGB(31, 68, 46)

local function parte(pai, nome, tamanho, posicao, cor, material)
	local item = Instance.new("Part")
	item.Name, item.Size, item.Position = nome, tamanho, posicao
	item.Color, item.Material = cor, material or Enum.Material.Grass
	item.Anchored = true
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.Parent = pai
	return item
end

local function marco(item, id, papel)
	item:SetAttribute("AreaId", id)
	item:SetAttribute("AreaRole", papel)
	return item
end

function Floresta.start(deps)
	deps = deps or {}
	local raiz = deps.workspace or workspace
	local existente = raiz:FindFirstChild(NOME)
	if existente then return existente end

	local floresta = Instance.new("Model")
	floresta.Name = NOME
	marco(floresta, Layout.ID, "region")

	Props.criar(floresta, PropsLayout.floresta())

	local clareira = Instance.new("Folder")
	clareira.Name = "Clareira de combate"
	marco(clareira, Layout.ID .. "/encontro", "encounter-area")
	clareira.Parent = floresta
	local marcoEncontro = parte(clareira, "Marco da Floresta Sombria", Vector3.new(3, 5, 3),
		Vector3.new(Layout.MARCO.x, 2.5, Layout.MARCO.z), Color3.fromRGB(112, 110, 102), Enum.Material.Slate)
	marco(marcoEncontro, Layout.ID .. "/encontro/marco", "encounter-trigger")
	marcoEncontro:SetAttribute("EncounterId", "region/encounter/dark-forest")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "Investigar", "Investigar", "Floresta Sombria"
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.4, 12, true
	prompt.Parent = marcoEncontro
	floresta.Parent = raiz
	return floresta
end

return Floresta
