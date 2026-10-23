"""UI real com estado injetado e emulador de dispositivo; não aparelho físico."""
import json, os, re, shutil, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8');base=Path(__file__).parent
sys.path.insert(0,str(base.parent));os.environ['MOSHOKU_TESTE_JOGADOR']='1';os.environ['LOCALAPPDATA']='C:/Users/pedro/AppData/Local'
from studio_mcp import Client
import studio_sync
c=Client();sid=None;iniciou=False;original=None;orientacao=None
def call(tool,**kw):
    r=c.call(tool,dict(studio_id=sid,**kw),timeout=60)
    if r.get('isError') or 'erro' in r: raise RuntimeError(r)
    return r['text']
def lua(code,dm='Client'): return call('execute_luau',code=code,datamodel_type=dm)
def key(k):
    call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code=k)]);time.sleep(.4)
def click(x,y):
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonClick',mouse_button='left',x=round(x),y=round(y))]);time.sleep(.5)
def election(name):
    pos=json.loads(lua('local b=shared.G16UI.gui.Eleicao.Opcoes.'+name+';local sc=b.Parent;sc.CanvasPosition=Vector2.new(0,math.max(0,b.AbsolutePosition.Y-sc.AbsolutePosition.Y+sc.CanvasPosition.Y-sc.AbsoluteSize.Y+b.AbsoluteSize.Y+10));task.wait(.2);local a=b.AbsolutePosition+b.AbsoluteSize/2;return game.HttpService:JSONEncode({a.X,a.Y})'))
    click(*pos)
def paper(name):
    pos=json.loads(lua('local g=shared.G16UI.pages.gui;local sc=g.Pagina;local b=sc:FindFirstChild("'+name+'") or g:FindFirstChild("'+name+'");local y=b.AbsolutePosition.Y-sc.AbsolutePosition.Y;if y<0 then sc.CanvasPosition+=Vector2.new(0,y) elseif y+b.AbsoluteSize.Y>sc.AbsoluteSize.Y then sc.CanvasPosition+=Vector2.new(0,y+b.AbsoluteSize.Y-sc.AbsoluteSize.Y) end;task.wait(.2);local a=b.AbsolutePosition+b.AbsoluteSize/2;local p=g.Adornee;local w=p.CFrame:PointToWorldSpace(Vector3.new(-(a.X/g.CanvasSize.X-.5)*p.Size.X,(.5-a.Y/g.CanvasSize.Y)*p.Size.Y,-p.Size.Z/2-.002));local q=workspace.CurrentCamera:WorldToViewportPoint(w);return game.HttpService:JSONEncode({q.X,q.Y-game:GetService("GuiService"):GetGuiInset().Y})'))
    click(*pos)
def shot(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m:shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios'];sid=next(s['id'] for s in studios if 'MoshokuRPGMesa' in s['name'])
    assert 'Mode: Edit' in call('get_studio_state'),'Play alheio preservado'
    for i in range(0,len(items:=studio_sync.collect()),6): assert lua(studio_sync.chunk_code(items[i:i+6]),'Edit').startswith('alterados:')
    original=lua('return game:GetService("StudioDeviceSimulatorService"):GetDeviceAsync()','Edit');orientacao=lua('return game:GetService("StudioDeviceSimulatorService"):GetOrientationAsync().Name','Edit')
    print(lua('game:GetService("StudioDeviceSimulatorService"):SetDeviceAsync("iphone_7");game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.Portrait);return "iPhone7"','Edit'),flush=True)
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(9)
    print(lua('game.Players.LocalPlayer.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.Portrait;game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.Portrait);return "retrato"'),flush=True);time.sleep(1)
    click(190,200)
    print(lua('local u=game:GetService("UserInputService");return tostring(u:GetLastInputType()).." touch="..tostring(u.TouchEnabled).." key="..tostring(u.KeyboardEnabled)'),flush=True)
    print(lua('local p=game.Players.LocalPlayer;local r={};for _,g in p.PlayerGui:GetChildren() do if g:IsA("ScreenGui") then for _,f in g:GetChildren() do if f:IsA("GuiObject") and f.Visible and g.Enabled and f.BackgroundTransparency<1 then table.insert(r,{n=f:GetFullName(),p=tostring(f.AbsolutePosition),s=tostring(f.AbsoluteSize),cor=tostring(f.BackgroundColor3)}) end end end end;return game.HttpService:JSONEncode(r)'),flush=True)
    lua('game.ReplicatedStorage.Mesa:FireServer("salaDadosPegar",{});return "pega"');time.sleep(.8)
    print(lua('local g=game.Players.LocalPlayer.PlayerGui.SalaMaoDicas;local f=g.Comandos;local v=workspace.CurrentCamera.ViewportSize;assert(g.Enabled and f.AbsolutePosition.X>=0 and f.AbsolutePosition.Y>=0 and f.AbsolutePosition.X+f.AbsoluteSize.X<=v.X and f.AbsolutePosition.Y+f.AbsoluteSize.Y<=v.Y);return "painel cabe "..tostring(v).." "..tostring(f.AbsolutePosition).." "..tostring(f.AbsoluteSize).." acaoativa="..tostring(f.Acoes.Arremessar.Active)'),flush=True);shot('g17_toque_retrato')
    pos=json.loads(lua('local b=game.Players.LocalPlayer.PlayerGui.SalaMaoDicas.Comandos.Acoes.Arremessar;local a=b.AbsolutePosition+b.AbsoluteSize/2;return game.HttpService:JSONEncode({a.X,a.Y})'));click(*pos)
    print(lua('assert(workspace:FindFirstChild("SalaDadosEmMaos")==nil);return "toque arremessa"'),flush=True)
    print(call('screen_capture',capture_id='g17_camera_fornecida',camera_position=[250,7,-14],look_at_position=[250,4,0])[:200],flush=True)
    print(lua('game.Players.LocalPlayer.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeLeft;game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft);return "paisagem"'),flush=True);time.sleep(1)
    key('F');time.sleep(3);click(190,200);lua('game.ReplicatedStorage.Mesa:FireServer("salaPapel",{id="mago-de-fogo"});return "ficha"');time.sleep(.8)
    print(lua('local f=game.Players.LocalPlayer.PlayerGui.SalaMaoDicas.Comandos;local v=workspace.CurrentCamera.ViewportSize;print("G17UI",tostring(v),tostring(f.AbsolutePosition),tostring(f.AbsoluteSize),tostring(f.Acoes.AbsoluteCanvasSize),tostring(f.Acoes.AbsoluteSize),tostring(f.Parent.Enabled),tostring(game:GetService("UserInputService"):GetLastInputType()));assert(f.AbsolutePosition.X>=0 and f.AbsolutePosition.Y>=0 and f.AbsolutePosition.X+f.AbsoluteSize.X<=v.X and f.AbsolutePosition.Y+f.AbsoluteSize.Y<=v.Y);assert(f.Acoes.AbsoluteCanvasSize.Y>f.Acoes.AbsoluteSize.Y,"rolagem");return "ficha cabe e rola "..tostring(v)'),flush=True);shot('g17_toque_paisagem')
    print(lua('local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);assert(f==0);return p.." specs / "..f.." falhas"','Server'),flush=True)
    print(lua('local c=workspace.CurrentCamera;return "camera="..tostring(c.CFrame).." sujeito="..tostring(c.CameraSubject).." sala="..tostring(workspace:FindFirstChild("SalaRPG"))'),flush=True)
except Exception:
    try: print(call('get_console_output'),flush=True)
    except Exception: pass
    raise
finally:
    try:
        if iniciou:print(call('start_stop_play',is_start=False),flush=True)
    finally:
        try:
            if original is not None:
                restore='local s=game:GetService("StudioDeviceSimulatorService");s:StopSimulationAsync();'
                if original!='default':restore+='s:SetDeviceAsync('+json.dumps(original)+');s:SetOrientationAsync(Enum.ScreenOrientation['+json.dumps(orientacao)+']);'
                print(lua(restore+'return s:GetDeviceAsync()','Edit'),flush=True)
        finally:c.close()
