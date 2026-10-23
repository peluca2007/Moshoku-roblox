local BattleController = {}
function BattleController.start()
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local remote=RS:WaitForChild("RPG")
local camera=workspace.CurrentCamera
local CameraController=require(script.Parent.CameraController)
local active=false
local arenaOrigin=nil
local gui=Instance.new("ScreenGui")
gui.Name="RPGInterface"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.Size=UDim2.new(0.94,0,0,160); panel.Position=UDim2.new(0.03,0,1,-175)
panel.BackgroundColor3=Color3.fromRGB(23,34,38); panel.Parent=gui
local text=Instance.new("TextLabel")
text.Size=UDim2.new(1,-20,0,92); text.Position=UDim2.fromOffset(10,4)
text.BackgroundTransparency=1; text.TextColor3=Color3.fromRGB(235,229,207)
text.TextSize=17; text.TextWrapped=true; text.Font=Enum.Font.Gotham; text.Parent=panel
text.Text="PROTÓTIPO RPG • Caminhe com WASD.\nEntre no campo verde escuro para encontros aleatórios ou use o treino no ponto inicial."
local buttons={}
for i,entry in ipairs({{"Espada","attack"},{"Magia","spell"},{"Defender","guard"},{"Passar","end"},{"Sair","flee"}}) do
 local b=Instance.new("TextButton")
 b.Size=UDim2.new(0.19,0,0,44); b.Position=UDim2.new((i-1)*0.2+0.005,0,0,105)
 b.BackgroundColor3=Color3.fromRGB(66,95,92); b.TextColor3=Color3.new(1,1,1)
 b.Text=entry[1]; b.TextSize=15; b.Visible=false; b.Parent=panel
 b.Activated:Connect(function() if active then remote:FireServer(entry[2]) end end)
 table.insert(buttons,b)
end
remote.OnClientEvent:Connect(function(state)
 active=state.active
 arenaOrigin=state.active and state.origin or nil
 for _,b in buttons do b.Visible=active end
 if active then
  UIS.MouseBehavior=Enum.MouseBehavior.Default
  CameraController.battle(camera,state.origin)
  text.Text=string.format("PV %d/30 • Mana %d/12 • Ação %d/3 • %s: %d PV\n%s\nClique numa casa em linha reta para mover (1 ponto/casa). Espada: alcance 1; magia: 5; ataque: 2 pontos.",state.hp,state.mp,state.pa,state.enemy,state.enemyHp,state.message)
 else
  CameraController.explore(camera,player.Character)
  text.Text=state.message.."\nExplore o campo ou volte ao treino. Novo encontro disponível após 8 segundos."
 end
end)
local function selectTile(position)
 if not active or not arenaOrigin then return end
 -- GetMouseLocation/TouchTap fornecem coordenadas da janela. ViewportPointToRay
 -- usa a mesma origem, evitando deslocamento da barra superior do Roblox.
 local ray=camera:ViewportPointToRay(position.X,position.Y)
 -- Interseção com o plano do tabuleiro: personagens e espaços entre as
 -- peças não bloqueiam a seleção. O servidor continua validando o destino.
 if math.abs(ray.Direction.Y)<0.00001 then return end
 local distance=(arenaOrigin.Y+0.5-ray.Origin.Y)/ray.Direction.Y
 if distance<=0 then return end
 local point=ray.Origin+ray.Direction*distance
 local x=math.floor((point.X-arenaOrigin.X)/6+4.5)
 local z=math.floor((point.Z-arenaOrigin.Z)/6+4.5)
 if x>=1 and x<=7 and z>=1 and z<=7 then
  remote:FireServer("move",x,z)
 end
end
UIS.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then selectTile(UIS:GetMouseLocation()) end
end)
UIS.TouchTap:Connect(function(positions,processed) if not processed and positions[1] then selectTile(positions[1]) end end)

end
return BattleController


