-- Estado injetado; os módulos e os alvos clicados são os de produção.
local p=game.Players.LocalPlayer
local r={linhas={},falhas=0,envios={},logs={}};shared.G18=r
game.UserInputService.InputBegan:Connect(function(i) r.ultimoInput={tipo=tostring(i.UserInputType),pos=tostring(i.Position)} end)
function r.check(n,v) table.insert(r.linhas,(if v then "OK " else "FALHA ")..n);if not v then r.falhas+=1 end end
r.sala={mestre=p.UserId,modo="luta",nivel=1,monstros=true,copias={},maos={},ofertas={},pessoas={{id=p.UserId,nome=p.Name,admitido=true,pronto=true,equipe=0},{id=999,nome="Amigo de bancada",admitido=true,equipe=0,ficha="mago-de-fogo",pronto=true}},versao=1}
r.snap={salaConceitual=r.sala,combat={active=false},you={admin=true}}
local state={send=function(cmd,d) table.insert(r.envios,{cmd=cmd,d=d}) end,onSnapshot=function() end,onLog=function(fn) table.insert(r.logs,fn) end}
local pasta=Instance.new("Folder");pasta.Name="G18UIObjetos";pasta.Parent=workspace
local entrada={GetLastInputType=function() return if r.gamepad then Enum.UserInputType.Gamepad1 else game.UserInputService:GetLastInputType() end,LastInputTypeChanged=game.UserInputService.LastInputTypeChanged}
r.pages=require(p.PlayerScripts.Client.SalaPaginas).start(pasta,state,entrada);r.pages.gui.Name="G18Consulta"
r.clicados={}
local function observar(b) if b:IsA("TextButton") then b.Activated:Connect(function() table.insert(r.clicados,b.Name) end) end end
r.pages.gui.DescendantAdded:Connect(observar);for _,b in r.pages.gui:GetDescendants() do observar(b) end
function r.update() r.pages.atualizar(r.snap) end
r.update();r.pages.abrir("mestre")
local cf=workspace.CurrentCamera.CFrame;r.cf=cf
game:GetService("RunService"):BindToRenderStep("G18UIBancada",Enum.RenderPriority.Camera.Value+12,function(dt)
 local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=cf
 r.pages.posicionar(c,dt);game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default;game:GetService("UserInputService").MouseIconEnabled=true
end)
function r.medidas(rotulo)
 local g=r.pages.gui;local p=g.Adornee;local c=workspace.CurrentCamera;local v=c.ViewportSize
 local a=c:WorldToViewportPoint(p.CFrame:PointToWorldSpace(Vector3.new(-p.Size.X/2,-p.Size.Y/2,0)))
 local b=c:WorldToViewportPoint(p.CFrame:PointToWorldSpace(Vector3.new(p.Size.X/2,p.Size.Y/2,0)))
 local w,h=math.abs(a.X-b.X),math.abs(a.Y-b.Y)
 r.check(rotulo.." papel dentro da tela",math.min(a.X,b.X)>=0 and math.max(a.X,b.X)<=v.X and math.min(a.Y,b.Y)>=0 and math.max(a.Y,b.Y)<=v.Y)
 r.check(rotulo.." alvo fechar >=48px",g.GuardarPapel.AbsoluteSize.Y*h/g.CanvasSize.Y>=48)
 local aba=g.Pagina.Abas.Aba_sessao
 r.check(rotulo.." aba >=44px nos dois eixos",aba.AbsoluteSize.X*w/g.CanvasSize.X>=44 and aba.AbsoluteSize.Y*h/g.CanvasSize.Y>=48)
 r.check(rotulo.." texto >=16px",aba.TextSize*h/g.CanvasSize.Y>=16)
 return tostring(v).." canvas="..tostring(g.CanvasSize).." papel="..tostring(p.Size)
end
return "bancada G18 criada"
