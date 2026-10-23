-- Cada consulta possui um motivo; somente a última liberação devolve o movimento.
local Players=game:GetService("Players")
local StarterPlayer=game:GetService("StarterPlayer")
local Movimento=require(game:GetService("ReplicatedStorage").Shared.MovimentoPersonagem)
local B={}
function B.new(obter,obterPadroes)
	return Movimento.new(obter,obterPadroes or function() return Movimento.padroes(StarterPlayer) end)
end
local player=Players.LocalPlayer
local definir,atualizar=Movimento.new(function()
	return player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end,function()
	local padroes=Movimento.padroes(StarterPlayer)
	if player and player:GetAttribute("ProvacaoAgachado") then padroes.WalkSpeed=math.min(7,padroes.WalkSpeed) end
	return padroes
end)
B.definir=definir
-- O bloqueio continua válido se o personagem renascer com uma consulta aberta.
if player then player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid")
	atualizar()
end) end
return B
