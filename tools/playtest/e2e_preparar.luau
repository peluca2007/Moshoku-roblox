-- Studio Play e2e setup for selected encounter.
-- Studio-only profile uses in-memory persistence.
-- Set ENCONTRO to clearing, forest, or dark-forest.
local ENCONTRO = "region/encounter/clearing" -- clearing | forest | dark-forest
task.wait(12)
local RS = game:GetService("ReplicatedStorage")
local mesa = RS:WaitForChild("Mesa")
local p = game.Players.LocalPlayer
mesa:FireServer("personagemPessoalCriar", {
	requestId = "e2e-" .. tostring(os.clock()), nome = "Aria da Chuva", raceId = "race/humano", backgroundId = "background/plebeu",
	startingTreeId = "tree/agua", attributeBase = { forca = 2, agilidade = 0, vigor = 0, intelecto = 0, espirito = 0 },
	raceAttributeChoices = { "agilidade" },
	freeSkillChoiceIds = { "skill/atletismo", "skill/acrobacia", "skill/furtividade", "skill/ladinagem" },
	treeSkillChoiceIds = { "skill/percepcao" },
})
task.wait(3)
mesa:FireServer("personagemPessoalEquiparArma", { sourceLocalId = "kit-inicial-01", requestId = "arma-" .. tostring(os.clock()) })
task.wait(3)
local marco
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("EncounterId") == ENCONTRO then marco = d end
end
p.Character.HumanoidRootPart.CFrame = CFrame.new(marco.Position + Vector3.new(0, 3, 4))
task.wait(1.5)
local prompt = marco:FindFirstChildOfClass("ProximityPrompt")
prompt:InputHoldBegin()
task.wait(12)
prompt:InputHoldEnd()
task.wait(3)
return "iniciado " .. ENCONTRO


