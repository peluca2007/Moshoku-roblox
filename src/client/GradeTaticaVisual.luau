-- Opacidade somente local. Nenhuma posição, destino ou regra é alterada.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local T = require(script.Parent.UI.Tema)
local V = {}
local function seguro(id) return (tostring(id):gsub("[^%w%-_]", "_")) end
function V.start(gui, state)
 local player = Players.LocalPlayer
 local grades, pecas, tweens = {}, {}, {}
 local atual, centroX, centroZ
 local function registrar(item)
  if item:IsA("Folder") and item:GetAttribute("GradeCentro") then grades[item]=true end
 end
 for _,item in workspace:GetDescendants() do registrar(item) end
 local adicionado=workspace.DescendantAdded:Connect(registrar)
 local function atualizar()
  centroX,centroZ=nil,nil
  -- O snapshot fornece ID/posições táticas; a réplica visual fornece a posição mundial.
  -- Não consultar o Character: durante retorno/teleporte ele pode estar fora da arena.
  if atual and atual.phase=="active" and player:GetAttribute("InterfaceCombate") then
   local pasta=workspace:FindFirstChild("MiniaturasJ2_"..seguro(atual.encounterId))
   for _,ator in atual.actors or {} do
    local token=pasta and pasta:FindFirstChild("Ator_"..seguro(ator.id))
    if token and token:IsA("BasePart") and type(ator.x)=="number" and type(ator.z)=="number" then
     centroX=token.Position.X-(ator.x-10.5)*1.8
     centroZ=token.Position.Z-(ator.z-10.5)*1.8
     break
    end
   end
  end
  for pasta in grades do
   if not pasta.Parent then grades[pasta]=nil; continue end
   local centro=pasta:GetAttribute("GradeCentro")
   local ativa=T.gradeAtiva(centro.X,centro.Z,centroX,centroZ)
   for _,p in pasta:GetChildren() do
    if not p:IsA("BasePart") then continue end
    local alvo=T.gradeLocal(p.Transparency,p:GetAttribute("GridX")~=nil,ativa)
    if pecas[p]~=alvo then
     local nova=pecas[p]==nil
     pecas[p]=alvo
     if tweens[p] then tweens[p]:Cancel() end
     if nova then p.LocalTransparencyModifier=alvo
     else local tween=TweenService:Create(p,TweenInfo.new(0.18),{LocalTransparencyModifier=alvo}); tweens[p]=tween; tween:Play() end
    end
   end
  end
  for p in pecas do if not p.Parent then pecas[p]=nil; tweens[p]=nil end end
 end
 state.onEstado(function(s) atual=s; atualizar() end)
 state.onRetorno(function() atual=nil; atualizar() end)
 local atributo=player:GetAttributeChangedSignal("InterfaceCombate"):Connect(atualizar)
 local tempo=0
 local pulso=RunService.Heartbeat:Connect(function(dt) tempo+=dt; if tempo>=0.2 then tempo=0; atualizar() end end)
 gui.Destroying:Once(function()
  adicionado:Disconnect(); atributo:Disconnect(); pulso:Disconnect()
  for p in pecas do if tweens[p] then tweens[p]:Cancel() end; if p.Parent then p.LocalTransparencyModifier=0 end end
 end)
 atualizar()
end
return V
