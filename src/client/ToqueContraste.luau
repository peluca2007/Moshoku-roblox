-- Decoração opcional do JumpButton localizado como no exemplo público do Creator Hub.
-- Sem PlayerModule, substituição de imagem, controles ou interceptação de toque.
local T = require(script.Parent.UI.Tema)
local V = {}
function V.start(gui, playerGui)
 if not game:GetService("UserInputService").TouchEnabled then return end
 local function decorar(b)
  if b.Name~="JumpButton" or not b:IsA("ImageButton") or b:FindFirstChild("ContornoMoshoku") then return end
  local aro=Instance.new("Frame")
  aro.Name,aro.Size,aro.BackgroundTransparency,aro.Active="ContornoMoshoku",UDim2.fromScale(1,1),1,false
  aro.ZIndex=b.ZIndex; aro.Parent=b
  local canto=Instance.new("UICorner"); canto.CornerRadius=UDim.new(1,0); canto.Parent=aro
  local sombra=Instance.new("UIStroke"); sombra.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
  sombra.Color,sombra.Thickness,sombra.Transparency,sombra.Parent=T.cores.sombra,5,0.15,aro
  local fio=aro:Clone(); fio.Name="FioMoshoku"; fio.Parent=aro
  local borda=fio:FindFirstChildOfClass("UIStroke"); borda.Color,borda.Thickness,borda.Transparency=T.cores.texto,1.5,0
 end
 for _,b in playerGui:GetDescendants() do decorar(b) end
 local c=playerGui.DescendantAdded:Connect(decorar)
 gui.Destroying:Once(function() c:Disconnect() end)
end
return V
