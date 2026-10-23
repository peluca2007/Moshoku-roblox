-- Rig R15 e animação cosmética; posição/visão continuam autoritativas no serviço.
local Players=game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Layout=require(Shared.Mundo.PatioLadinoLayout)
local G={}
function G.criar(pai,indice)
 local d=Instance.new("HumanoidDescription")
 d.HeadColor=Color3.fromRGB(190,145,110)
 d.TorsoColor=Color3.fromRGB(100,34,48)
 d.LeftArmColor,d.RightArmColor=d.TorsoColor,d.TorsoColor
 d.LeftLegColor,d.RightLegColor=Color3.fromRGB(34,32,39),Color3.fromRGB(34,32,39)
 local ok,m=pcall(Players.CreateHumanoidModelFromDescription,Players,d,Enum.HumanoidRigType.R15)
 d:Destroy()
 if not ok then warn("[Pátio] R15 indisponível: "..tostring(m)); return nil end
 if not pai.Parent then m:Destroy(); return nil end
 for _,p in m:GetDescendants() do if p:IsA("LuaSourceContainer") then p:Destroy() end end
 local h=m:FindFirstChildOfClass("Humanoid")
 local raiz=m:FindFirstChild("HumanoidRootPart")
 if not h or not raiz then m:Destroy(); return nil end
 m.Name="Guarda "..indice; m.PrimaryPart=raiz
 m:SetAttribute("RotaLadino",indice)
 h.DisplayName="Vigia"; h.NameDisplayDistance=22; h.WalkSpeed=Layout.VELOCIDADE
 h.AutoRotate=false
 for _,p in m:GetDescendants() do if p:IsA("BasePart") then
  p.Anchored=p==raiz; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
 end end
 local function adereco(nome,alvo,offset,tamanho,material,cor)
  local p=Instance.new("Part")
  p.Name=nome; p.Size=tamanho; p.Material=material; p.Color=cor
  p.CFrame=alvo.CFrame*offset
  p.CanCollide,p.CanQuery,p.CanTouch,p.Massless=false,false,false,true
  p.Parent=m
  local w=Instance.new("WeldConstraint",p); w.Part0,w.Part1=alvo,p
  return p
 end
 local metal=Color3.fromRGB(112,119,127)
 adereco("Elmo",m.Head,CFrame.new(0,.42,0),Vector3.new(1.28,.55,1.28),Enum.Material.Metal,metal)
 adereco("Nasal do elmo",m.Head,CFrame.new(0,.02,-.64),Vector3.new(.16,.65,.12),Enum.Material.Metal,metal)
 adereco("Haste da lança",m.RightHand,CFrame.new(0,.8,-.25),Vector3.new(.14,5,.14),Enum.Material.Wood,Color3.fromRGB(87,60,38))
 adereco("Ponta da lança",m.RightHand,CFrame.new(0,3.45,-.25),Vector3.new(.32,.6,.2),Enum.Material.Metal,metal)
 local altura=h.HipHeight+raiz.Size.Y/2
 m.Parent=pai
 local g={modelo=m,parte=raiz,cabeca=m.Head,indice=indice,altura=altura,tempo=0}
 G.atualizar(g,0)
 local animador=h:FindFirstChildOfClass("Animator") or Instance.new("Animator",h)
 local anim=Instance.new("Animation"); anim.AnimationId="rbxassetid://507777826"
 local carregou,faixa=pcall(function() return animador:LoadAnimation(anim) end)
 anim:Destroy()
 if carregou and faixa then
  faixa.Looped=true; faixa.Priority=Enum.AnimationPriority.Movement; faixa:Play(.2,1,.5)
 end
 return g
end
function G.atualizar(g,dt)
 g.tempo+=dt
 local p,f=Layout.guarda(g.indice,g.tempo)
 local pos=Vector3.new(p.x,g.altura,p.z)
 g.modelo:PivotTo(CFrame.lookAt(pos,pos+Vector3.new(f.x,0,f.z)))
end
return G
