-- Casos de apresentação reais no cliente; não simulam uma segunda conexão.
local r=shared.G14
local client=game.Players.LocalPlayer.PlayerScripts.Client
local B=require(client.SalaBracos)
local pasta=Instance.new("Folder");pasta.Name="G14BracosTeste";pasta.Parent=workspace
local char=Instance.new("Model");char.Name="R15Parcial";char.Parent=pasta
local function p(nome,pos)
 local o=Instance.new("Part");o.Name=nome;o.Size=Vector3.new(.5,1,.5);o.CFrame=CFrame.new(pos);o.Anchored=true;o.Parent=char;return o
end
local u=p("RightUpperArm",Vector3.new(0,5,0));local l=p("RightLowerArm",Vector3.new(0,4,0))
local b=B.new(char,pasta,true)
local ok=pcall(b.atualizar,Vector3.new(1,3,-2),Vector3.new(-1,3,-2),1)
r.check("rig parcial sem erro",ok and pasta.Bracos_R15Parcial:FindFirstChild("RightUpperArm")==nil)
local h=p("RightHand",Vector3.new(0,3,0));b.atualizar(Vector3.new(1,3,-2),Vector3.new(-1,3,-2),1)
r.check("mao tardia monta braco",pasta.Bracos_R15Parcial:FindFirstChild("RightHand")~=nil and h.LocalTransparencyModifier==1)
l:Destroy();ok=pcall(b.atualizar,Vector3.new(1,3,-2),Vector3.new(-1,3,-2),1)
r.check("remocao parcial restaura",ok and h.LocalTransparencyModifier==0);b.destruir();char:Destroy()
local r6=Instance.new("Model");r6.Name="R6Teste";r6.Parent=pasta;char=r6;local arm=p("Right Arm",Vector3.new(0,3,0));b=B.new(r6,pasta,false);b.atualizar(Vector3.new(1,3,-2),Vector3.new(-1,3,-2),1)
r.check("alcance R6",arm.LocalTransparencyModifier==1);b.destruir();r.check("restaura R6",arm.LocalTransparencyModifier==0);r6:Destroy()
local real=game.Players.LocalPlayer.Character;local a=real.Archivable;real.Archivable=true;local outro=real:Clone();real.Archivable=a;outro.Name="OutroJogadorTeste"
for _,d in outro:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored=true;d.LocalTransparencyModifier=0 end end
outro.Parent=pasta;outro:PivotTo(CFrame.new(260,5,-8))
local corpo=require(client.SalaCorpo).new(pasta,function() return {{UserId=999,Character=outro}} end)
corpo.atualizar({maos={[999]="mago-de-fogo"}},1,nil)
r.check("gesto remoto com papel",pasta:FindFirstChild("PapelDoJogador999")~=nil and outro.RightHand.LocalTransparencyModifier==1)
corpo.atualizar({maos={}},1,nil);r.check("soltar remoto limpa papel",pasta:FindFirstChild("PapelDoJogador999")==nil and outro.RightHand.LocalTransparencyModifier==0)
corpo.restaurar();r.check("restaurar limpa bracos",pasta:FindFirstChild("Bracos_OutroJogadorTeste")==nil);pasta:Destroy()
return "Braços: parcial, R6 e apresentação remota"
