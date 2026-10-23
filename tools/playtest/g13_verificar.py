"""G13: sala real, papel 3D por input real e início via mestre."""
import json, os, re, shutil, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
os.environ['MOSHOKU_TESTE_JOGADOR']='1'
from studio_mcp import Client
import studio_sync
c=Client();sid=None;iniciou=False;base=Path(__file__).parent
def call(tool,**kw):
    r=c.call(tool,dict(studio_id=sid,**kw),timeout=60)
    if r.get('isError') or 'erro' in r: raise RuntimeError(r)
    return r['text']
def lua(code,dm='Client'):return call('execute_luau',datamodel_type=dm,code=code)
def key(k):
    call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code=k)])
    time.sleep(.45)
def shot(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m:shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
def aim(path):
    lua('shared.G13.alvo='+path+';shared.G13.aim=true;return "mira"');time.sleep(.7);key('E');lua('shared.G13.aim=false;return "fim mira"');time.sleep(.4)
def paper_button(name):
    code='''local g=game.Players.LocalPlayer.PlayerGui.SalaPapelInterface;local sc=g.Pagina;local b=sc["%s"];local y=b.AbsolutePosition.Y-sc.AbsolutePosition.Y;if y<0 then sc.CanvasPosition+=Vector2.new(0,y) elseif y+b.AbsoluteSize.Y>sc.AbsoluteSize.Y then sc.CanvasPosition+=Vector2.new(0,y+b.AbsoluteSize.Y-sc.AbsoluteSize.Y) end;task.wait(.2);local a=b.AbsolutePosition+b.AbsoluteSize/2;local u=a.X/g.CanvasSize.X;local v=a.Y/g.CanvasSize.Y;local p=g.Adornee;local w=p.CFrame:PointToWorldSpace(Vector3.new(-(u-.5)*p.Size.X,(.5-v)*p.Size.Y,-p.Size.Z/2-.002));local q=workspace.CurrentCamera:WorldToViewportPoint(w);return game.HttpService:JSONEncode({q.X,q.Y-game:GetService("GuiService"):GetGuiInset().Y})'''%name
    pos=json.loads(lua(code))
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonDown',mouse_button='left',x=round(pos[0]),y=round(pos[1])),dict(action='mouseButtonUp',mouse_button='left',x=round(pos[0]),y=round(pos[1]))]);time.sleep(.65)
    print('CLICK',name,pos,flush=True)
try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios'];sid=next(s['id'] for s in studios if s['name']=='Moshoku-Prototipo.rbxlx')
    assert 'Mode: Edit' in call('get_studio_state')
    lua('workspace:SetAttribute("MoshokuTesteMestre",nil);return "Edit"','Edit')
    items=studio_sync.collect()
    for i in range(0,len(items),6):assert lua(studio_sync.chunk_code(items[i:i+6]),'Edit').startswith('alterados:')
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(10)
    result=lua('local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);return p.." specs / "..f.." falhas"','Server');print(result,flush=True)
    if ' / 0 falhas' not in result:print(call('get_console_output'),flush=True);raise AssertionError(result)
    print(lua('''local r={falhas=0,linhas={}};shared.G13=r;function r.check(n,v) table.insert(r.linhas,(if v then "OK " else "FALHA ")..n);if not v then r.falhas+=1 end end;r.con=game.ReplicatedStorage.Mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then r.snap=d elseif k=="log" and d.tone=="erro" then r.erro=d.text end end);game.ReplicatedStorage.Mesa:FireServer("requestSnapshot",{});task.wait(.5);local p=game.Players.LocalPlayer;local s=r.snap;r.check("primeiro mestre",s.you.master and s.salaConceitual.mestre==p.UserId);r.check("seis vagas incluindo mestre",#s.salaConceitual.pessoas==1 and s.salaConceitual.pessoas[1].lugar==1);r.check("dez cadeiras",workspace.SalaRPG:FindFirstChild("Lugar10")~=nil);r.check("primeira pessoa",p.CameraMode==Enum.CameraMode.LockFirstPerson);r.check("avatar sentado",p.Character.Humanoid.SeatPart==workspace.SalaRPG.Lugar1);r.check("menu antigo fechado",not p.PlayerGui.InicioJogo.Enabled);game:GetService("RunService"):BindToRenderStep("G13MiraTeste",Enum.RenderPriority.Camera.Value+4,function() if r.aim then game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.LockCenter;local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=CFrame.lookAt(c.CFrame.Position,r.alvo.Position) end end);return "Sala iniciada"'''),flush=True)
    shot('g13_sala')
    aim('workspace.SalaObjetosLocais.PilhaDeFichas')
    print(lua('local r=shared.G13;local g=game.Players.LocalPlayer.PlayerGui.SalaPapelInterface;r.check("papel fisico aberto",g.Enabled and g.Adornee.Name=="PapelEmMaos");return "Papel"'),flush=True)
    shot('g13_ficha')
    paper_button('VirarPagina')
    print(lua('local r=shared.G13;local achou=false;for _,l in game.Players.LocalPlayer.PlayerGui.SalaPapelInterface.Pagina:GetChildren() do if l:IsA("TextLabel") and l.Text:find("PA gastos",1,true) then achou=true end end;r.check("pagina atributos",achou);return "Pagina"'),flush=True)
    paper_button('FichaSeguinte');paper_button('FichaAnterior');paper_button('AssumirFicha')
    print(lua('local r=shared.G13;r.check("ficha confirmada servidor",r.snap.salaConceitual.pessoas[1].ficha=="mago-de-fogo");return "Escolha"'),flush=True)
    paper_button('GuardarPapel')
    aim('workspace.SalaRPG.EscudoMestre')
    shot('g13_caderno')
    for modo in ['duelo','treino','luta']:
        paper_button('Modo')
        print(lua('shared.G13.check("modo '+modo+' confirmado",shared.G13.snap.salaConceitual.modo=="'+modo+'");return shared.G13.erro or "Modo confirmado"'),flush=True)
    print(lua('local r=shared.G13;r.check("modos pelo caderno",r.snap.salaConceitual.modo=="luta");return "Modo"'),flush=True)
    paper_button('LancarDados')
    time.sleep(.65);shot('g13_transicao');time.sleep(4)
    print(lua('local r=shared.G13;r.check("partida real iniciou",r.snap.combat.active);r.check("camera tabuleiro",game.Players.LocalPlayer.CameraMode==Enum.CameraMode.Classic);r.check("sala oculta no jogo",not game.Players.LocalPlayer.PlayerGui.SalaConceitual.Enabled);local n=0;for _,t in r.snap.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId then n+=1 end end;r.check("personagem montado",n==1);game.ReplicatedStorage.Mesa:FireServer("combatEnd",{});task.wait(1);r.check("volta primeira pessoa",game.Players.LocalPlayer.CameraMode==Enum.CameraMode.LockFirstPerson);return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'),flush=True)
    print(call('get_console_output'),flush=True)
    assert lua('return shared.G13.falhas').strip()=='0'
finally:
    if iniciou:print(call('start_stop_play',is_start=False),flush=True);print(call('get_studio_state'),flush=True)
    c.close()
