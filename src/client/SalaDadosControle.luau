-- Apresentação local durante posse; física e resultado continuam no servidor.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Mao=require(game:GetService("ReplicatedStorage").Shared.SalaDadosMao)
local C={}
function C.new(state)
 local player=Players.LocalPlayer;local mao,ativo=nil,false;local ultimo=0;local copia=nil;local original=nil;local ocultos={};local api={}
 local function restaurar()
  if copia then copia:Destroy();copia=nil end
  for p,v in ocultos do if p.Parent then if p:IsA("BasePart") then p.LocalTransparencyModifier=v else p.Enabled=v end end end
  table.clear(ocultos);original=nil
 end
 local function soltar() state.send("salaCarregar",{soltar=true});return true end
 local gui=Instance.new("ScreenGui");gui.Name="SalaSoltura";gui.ResetOnSpawn=false;gui.DisplayOrder=30;gui.Enabled=false;gui.Parent=player:WaitForChild("PlayerGui")
 local sair=Instance.new("TextButton");sair.Name="Soltar";sair.AnchorPoint=Vector2.new(.5,1);sair.Position=UDim2.new(.5,0,1,-100);sair.Size=UDim2.fromOffset(230,54);sair.Text="Pule ou toque para se soltar";sair.Font=Enum.Font.Garamond;sair.TextSize=21;sair.TextColor3=Color3.fromRGB(245,228,190);sair.BackgroundColor3=Color3.fromRGB(43,60,54);sair.Parent=gui;sair.Activated:Connect(soltar)
 local canto=Instance.new("UICorner");canto.CornerRadius=UDim.new(0,8);canto.Parent=sair
 function api.lancar(forca,largar)
  if mao~="dados-brotos" then return false end
  local v=workspace.CurrentCamera.CFrame.LookVector
  state.send("salaDadosLancar",{direcao={x=v.X,y=v.Y,z=v.Z},forca=forca,soltar=largar==true});return true
 end
 function api.ocupado() return mao~=nil end
 function api.interagir(objeto)
  if not ativo or mao or not objeto then return false end
  local acao=objeto:GetAttribute("SalaObjeto")
  if acao=="dados" then state.send("salaDadosPegar",{});return true end
  if acao=="jogador" then state.send("salaCarregar",{userId=objeto:GetAttribute("SalaJogador")});return true end
  return false
 end
 function api.soltar() if mao and mao:sub(1,8)=="jogador:" then return soltar() end;return api.lancar(0,true) end
 UIS.InputBegan:Connect(function(input,processed)
  if processed or UIS:GetFocusedTextBox() then return end
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if input.KeyCode==Enum.KeyCode.Q or input.KeyCode==Enum.KeyCode.ButtonB then
   if root and root:GetAttribute("CarregadoPor") then soltar() elseif ativo then api.soltar() end
  end
 end)
 UIS.JumpRequest:Connect(function() local r=player.Character and player.Character:FindFirstChild("HumanoidRootPart");if r and r:GetAttribute("CarregadoPor") then soltar() end end)
 function api.atualizar(sala,ligado,dt)
  ativo=ligado==true;mao=sala and (sala.maos[player.UserId] or sala.maos[tostring(player.UserId)])
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  gui.Enabled=root~=nil and root:GetAttribute("CarregadoPor")~=nil
  local folder=workspace:FindFirstChild("SalaDadosFisicos");local meus=folder and folder:FindFirstChild("Dados_"..player.UserId)
  local segurando=mao=="dados-brotos" and meus and meus:GetAttribute("EmMaos")
  if not segurando or original~=meus then restaurar() end
  if segurando then
   local camera=workspace.CurrentCamera;local aspecto=camera.ViewportSize.X/math.max(camera.ViewportSize.Y,1);local escala=Mao.escala(aspecto,camera.FieldOfView)
   if not copia then
    original=meus;copia=Instance.new("Model");copia.Name="SalaDadosEmMaos"
    for i=1,3 do local p=meus:FindFirstChild("Dado"..i);if p then local c=p:Clone();c.Anchored=true;c.CanCollide=false;c.CanQuery=false;c.CanTouch=false;c.CastShadow=false;c.Parent=copia end end
    copia.Parent=workspace
    for _,p in meus:GetDescendants() do
     if p:IsA("BasePart") then ocultos[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1
     elseif p:IsA("SurfaceGui") then ocultos[p]=p.Enabled;p.Enabled=false end
    end
    for i=1,3 do local d=copia:FindFirstChild("Dado"..i);if d then d.CFrame=camera.CFrame*CFrame.new(Mao.x(i)*escala,Mao.y*escala,-1.6) end end
   end
   for i=1,3 do local d=copia:FindFirstChild("Dado"..i);if d then
    local alvo=camera.CFrame*CFrame.new(Mao.x(i)*escala,Mao.y*escala,-1.6)*CFrame.Angles(.2*i,.1*i,.1*i)
    d.Size=Vector3.one*.48*escala;d.CFrame=d.CFrame:Lerp(alvo,1-math.exp(-(dt or 1/60)*24))
   end end
  end
  if os.clock()-ultimo<.2 then return end;ultimo=os.clock()
  for _,other in Players:GetPlayers() do local part=other.Character and other.Character:FindFirstChild("HumanoidRootPart");if other~=player and part then part:SetAttribute("SalaObjeto","jogador");part:SetAttribute("SalaJogador",other.UserId) end end
 end
 return api
end
return C
