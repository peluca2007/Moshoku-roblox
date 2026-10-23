-- Bancada local explícita; cliques reais nos módulos, estado da sala injetado.
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local p=Players.LocalPlayer;local r={linhas={},falhas=0,envios={},callbacks={},logs={}};shared.G16UI=r
function r.check(n,v) table.insert(r.linhas,(if v then "OK " else "FALHA ")..n);if not v then r.falhas+=1 end end
local sala={mestre=p.UserId,modo="luta",nivel=1,monstros=false,copias={},maos={},ofertas={},pessoas={{id=p.UserId,nome=p.Name,admitido=true,equipe=0},{id=999,nome="Amigo de bancada",admitido=true,equipe=0}},versao=1}
r.sala=sala;r.snap={salaConceitual=sala,combat={active=false},you={admin=true}}
local state={send=function(cmd,d) table.insert(r.envios,{cmd=cmd,d=d}) end,onSnapshot=function(fn) table.insert(r.callbacks,fn) end,onLog=function(fn) table.insert(r.logs,fn) end}
function r.update() if r.pages then r.pages.atualizar(r.snap) end;for _,fn in r.callbacks do fn(r.snap) end end
function r.recusar() for _,fn in r.logs do fn({tone="erro",text="recusa de bancada"}) end end
local pasta=Instance.new("Folder");pasta.Name="G16UIObjetos";pasta.Parent=workspace
r.pages=require(p.PlayerScripts.Client.SalaPaginas).start(pasta,state);r.update()
local gui=Instance.new("ScreenGui");gui.Name="G16Eleicao";gui.DisplayOrder=40;gui.ResetOnSpawn=false;gui.Parent=p.PlayerGui
r.eleicao=require(p.PlayerScripts.Client.SalaEleicaoView).new(gui,state);r.gui=gui
local cf=workspace.CurrentCamera.CFrame
game:GetService("RunService"):BindToRenderStep("G16UIBancada",Enum.RenderPriority.Camera.Value+12,function(dt)
	local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=cf
	r.pages.posicionar(c,dt);r.eleicao.redimensionar();game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default;game:GetService("UserInputService").MouseIconEnabled=true
end)
function r.convite(fase)
	r.e={fase=fase or "convite",fim=workspace:GetServerTimeNow()+12,rodada=0,candidatos={},dados={}}
	if fase=="rolagem" then r.e.candidatos[p.UserId]=true;r.e.rodada=1 end
	r.eleicao.atualizar(r.e,true)
end
r.convite()
return "bancada criada"
