-- Server: onde está o avatar do jogador, em casas.
local Protocol = require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)
local player = game:GetService("Players"):GetPlayers()[1]
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not root then return "sem personagem" end
local x, z = Protocol.cellAt(root.Position)
return string.format("casa=%s,%s ancorado=%s y=%.1f", tostring(x), tostring(z), tostring(root.Anchored), root.Position.Y)
