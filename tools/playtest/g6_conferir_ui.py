"""G6: campos de visão e consulta de habilidade por mouse no treino real."""
import json
from pathlib import Path
import re
import shutil
import sys
import time
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client
import studio_sync

base = Path(__file__).parent
c = Client()
sid, iniciou = None, False

def call(tool, **args):
    r = c.call(tool, dict(studio_id=sid, **args))
    if r.get("isError") or "erro" in r:
        raise RuntimeError(r)
    return r["text"]

def lua(code):
    return call("execute_luau", datamodel_type="Client", code=code)

def server(code):
    return call("execute_luau", datamodel_type="Server", code=code)

def check(code):
    print(lua('local r=shared.G6; local g=game.Players.LocalPlayer.PlayerGui.Arvores; local p=g:FindFirstChild("Pagina",true); '+code), flush=True)

def key(name):
    call("user_keyboard_input", datamodel_type="Client", actions=[dict(action="keyPress", key_code=name)])
    time.sleep(.2)

def press(path):
    pos = json.loads(lua('local o='+path+'; local a=o.Parent; while a and not a:IsA("ScrollingFrame") do a=a.Parent end; if a then local y=o.AbsolutePosition.Y-a.AbsolutePosition.Y; if y<0 or o.AbsoluteSize.Y>a.AbsoluteSize.Y then a.CanvasPosition+=Vector2.new(0,y) elseif y+o.AbsoluteSize.Y>a.AbsoluteSize.Y then a.CanvasPosition+=Vector2.new(0,y+o.AbsoluteSize.Y-a.AbsoluteSize.Y) end end; task.wait(.2); local p=o.AbsolutePosition+o.AbsoluteSize/2; if a then p=Vector2.new(p.X,(math.max(o.AbsolutePosition.Y,a.AbsolutePosition.Y)+math.min(o.AbsolutePosition.Y+o.AbsoluteSize.Y,a.AbsolutePosition.Y+a.AbsoluteSize.Y))/2) end; return game.HttpService:JSONEncode({p.X,p.Y})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonUp", mouse_button="left", x=round(pos[0]), y=round(pos[1]))])
    time.sleep(.2)

def capture(name):
    match = re.search(r"\[imagem salva em (.*?)\]", call("screen_capture", capture_id=name))
    if match:
        shutil.copyfile(match[1], base / (name + Path(match[1]).suffix))

try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios'];sid=next(s['id'] for s in studios if s['name']=='Moshoku-Prototipo.rbxlx')
    assert '- Current Studio Mode: Edit' in call('get_studio_state').splitlines()
    items = studio_sync.collect()
    for start in range(0, len(items), 6):
        call('execute_luau', datamodel_type='Edit', code=studio_sync.chunk_code(items[start:start+6]))
    print('Fontes sincronizadas', flush=True)
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(8)
    print(lua('local R={};shared.G6Foto=R;game.ReplicatedStorage.Mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then R.snap=d end end);game.ReplicatedStorage.Mesa:FireServer("escolherPersonagem",{id="ladina"});task.wait(.5);game.ReplicatedStorage.Mesa:FireServer("iniciarTreino",{});task.wait(2);return "Ladina"'),flush=True)
    root='game.Players.LocalPlayer.PlayerGui'
    press(root+'.AcoesDoTurno.Barra.Grupos.Apoio')
    press(root+'.AcoesDoTurno.Barra.Cartas:FindFirstChild("Carta_mesa/esconder")')
    key('M')
    print(lua('assert(#workspace.VisaoFurtivaLocal:GetChildren()>0);local r=shared.G6Foto;r.guis={};for _,g in game.Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui") then r.guis[g]=g.Enabled;g.Enabled=false end end;task.delay(.3,function()local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=CFrame.lookAt(Vector3.new(5,76,48),Vector3.new(0,1,0));c.FieldOfView=55 end);return "Visao sem custo"'),flush=True)
    time.sleep(.8);capture('g6_campos_de_visao')
    print(lua('local r=shared.G6Foto;for g,v in r.guis do g.Enabled=v end;game.ReplicatedStorage.Mesa:FireServer("sairPartida",{});task.wait(1.8);game.ReplicatedStorage.Mesa:FireServer("escolherPersonagem",{id="guerreiro-do-norte"});task.wait(.5);game.ReplicatedStorage.Mesa:FireServer("iniciarTreino",{});task.wait(2);return "Norte"'),flush=True)
    press(root+'.AcoesDoTurno.Barra.Grupos.Golpes')
    pos=json.loads(lua('local o=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Cartas:FindFirstChild("Carta_arremesso-de-espada");assert(o);local a=o.Parent;a.CanvasPosition=Vector2.new(0,math.max(0,o.AbsolutePosition.Y-a.AbsolutePosition.Y+a.CanvasPosition.Y));task.wait(.2);local p=o.AbsolutePosition+Vector2.new(30,24);return game.HttpService:JSONEncode({p.X,p.Y})'))
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='moveTo',x=round(pos[0]),y=round(pos[1]))]);time.sleep(.6)
    print(lua('local g=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno;local t=g.TooltipAcao;assert(t.Visible);assert(t.AbsoluteSize.Y>250,"Consulta longa deve expandir: "..t.AbsoluteSize.Y);assert(t.Conteudo.AbsoluteCanvasSize.Y>t.Conteudo.AbsoluteWindowSize.Y,"Consulta longa deve permitir rolagem");local s=t.Conteudo.Texto.Text;assert(string.find(s,"Dano:",1,true));assert(string.find(s,"Seu acerto: d20 +3",1,true),s);assert(string.match(s,"1d%d+"),s);assert(shared.G6Foto.snap.jogo.acoes.usadas==0);return s'),flush=True)
    capture('g6_arremesso_hover')
    print(lua('game.ReplicatedStorage.Mesa:FireServer("sairPartida",{});task.wait(1);return "Consulta com dano e acerto da ficha: OK"'),flush=True)
finally:
    if iniciou:
        print(call('get_console_output'),flush=True);print(call('start_stop_play',is_start=False),flush=True);print(call('get_studio_state'),flush=True)
    c.close()
