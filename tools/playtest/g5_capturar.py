"""Árvores: specs de serviço isolado e UI/execução no treino real."""
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
    print(lua('local r=shared.G5; local g=game.Players.LocalPlayer.PlayerGui.Arvores; local p=g:FindFirstChild("Pagina",true); '+code), flush=True)

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
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios']
    sid=next(s['id'] for s in studios if s['name']=='Moshoku-Prototipo.rbxlx')
    assert '- Current Studio Mode: Edit' in call('get_studio_state').splitlines()
    print(call('start_stop_play',is_start=True),flush=True); iniciou=True
    time.sleep(8)
    print(lua('local r={}; shared.G5Foto=r; local remote=game.ReplicatedStorage.Mesa; r.con=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then r.snap=d end end); remote:FireServer("escolherPersonagem",{id="mago-de-fogo"}); task.wait(.5); remote:FireServer("iniciarTreino",{}); task.wait(2); local s=r.snap; assert(s and s.combat.active); local me; for _,t in s.tokens do if t.id==s.combat.turnId then me=t end end; remote:FireServer("usarHabilidade",{tokenId=me.id,habilidadeId="ability/fogo/Principiante/fagulha",x=me.x+2,z=me.z-1}); task.wait(.8); assert(#r.snap.jogo.muros==1); local m=workspace.MurosDeFogo:FindFirstChild(r.snap.jogo.muros[1].id); assert(m and m.Chama.Size.Y<1); for _,g in game.Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui") and (g.Name=="AcoesDoTurno" or g.Name=="MesaPanel" or g.Name=="Hud") then g.Enabled=false end end; local pos=m.Chama.Position; task.delay(.25,function() local cam=workspace.CurrentCamera; cam.CameraType=Enum.CameraType.Scriptable; cam.CFrame=CFrame.lookAt(pos+Vector3.new(12,15,18),pos+Vector3.new(0,1,0)); cam.FieldOfView=45 end); return "Braseiro real preparado, apenas camera e HUD ajustados para captura"'),flush=True)
    key('M') # sair da câmera de mesa para a captura aproximada
    print(lua('local z=shared.G5Foto.snap.jogo.muros[1]; local pos=workspace.MurosDeFogo:FindFirstChild(z.id).Chama.Position; task.delay(.25,function() local cam=workspace.CurrentCamera; cam.CameraType=Enum.CameraType.Scriptable; cam.CFrame=CFrame.lookAt(pos+Vector3.new(12,15,18),pos+Vector3.new(0,1,0)); cam.FieldOfView=45 end); return "camera aproximada"'),flush=True)
    time.sleep(1)
    capture('g5_braseiro_detalhe')
    print('Console:',call('get_console_output'),flush=True)
finally:
    if iniciou:
        print(call('start_stop_play',is_start=False),flush=True)
        print(call('get_studio_state'),flush=True)
    c.close()
