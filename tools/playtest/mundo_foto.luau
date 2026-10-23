-- (Mundo aberto, 17/10) Cliente (execute_luau): câmera de fotografia. Fixa a câmera do jogo olhando para um ponto
-- (BindToRenderStep em prioridade Last, depois da CameraMundo) até chamar _G.FOTO_FIM(). Edite POS/ALVO; use
-- tools/restaurar_studio.ps1 antes de screen_capture. A CameraMundo reassume sozinha depois do FOTO_FIM.
local POS = Vector3.new(606, 6.5, -186)
local ALVO = Vector3.new(599.5, 3.0, -196.0)
local RS = game:GetService("RunService")
pcall(function() RS:UnbindFromRenderStep("FotoMundo") end)
RS:BindToRenderStep("FotoMundo", Enum.RenderPriority.Last.Value, function()
	local c = workspace.CurrentCamera
	c.CameraType = Enum.CameraType.Scriptable
	c.CFrame = CFrame.lookAt(POS, ALVO)
end)
_G.FOTO_FIM = function() pcall(function() RS:UnbindFromRenderStep("FotoMundo") end) end
-- Esconde a interface por cima (devolve com _G.FOTO_FIM): nunca enumere os descendentes da ScreenGui EncontroAutonomo em combate.
local pg = game.Players.LocalPlayer.PlayerGui
local nomes = { "EncontroAutonomo", "RelogioRun", "AvisosJogo", "HudJogo" }
for _, n in nomes do local g = pg:FindFirstChild(n) if g then g.Enabled = false end end
local fim = _G.FOTO_FIM
_G.FOTO_FIM = function()
	fim()
	for _, n in nomes do local g = pg:FindFirstChild(n) if g then g.Enabled = true end end
end
return "camera de foto ligada"
