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
    items=studio_sync.collect()
    for start in range(0,len(items),6): call("execute_luau",datamodel_type="Edit",code=studio_sync.chunk_code(items[start:start+6]))
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(8)
    print(lua('local R={};shared.G6Pose=R;game.ReplicatedStorage.Mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then R.snap=d end end);game.ReplicatedStorage.Mesa:FireServer("escolherPersonagem",{id="ladina"});task.wait(.5);game.ReplicatedStorage.Mesa:FireServer("iniciarTreino",{});task.wait(2);R.id=R.snap.combat.turnId;game.ReplicatedStorage.Mesa:FireServer("conditionAdd",{id=R.id,condition="caido"});task.wait(1);return "caido"'),flush=True)
    code='local c=game.Players:GetPlayers()[1].Character;local root=c.HumanoidRootPart;local out={"root "..tostring(root.CFrame.UpVector)}; for _,o in c:GetDescendants() do if o:IsA("Motor6D") and o.Part0==root then table.insert(out,o:GetFullName().." C0 "..tostring(o.C0.UpVector).." C1 "..tostring(o.C1.UpVector).." T "..tostring(o.Transform.UpVector).." part1 "..tostring(o.Part1.CFrame.UpVector)) end end;for _,o in c:GetDescendants() do if o:IsA("AnimationConstraint") and o.Attachment0 and o.Attachment0.Parent==root then table.insert(out,o:GetFullName().." A0 "..tostring(o.Attachment0.CFrame.UpVector).." P1 "..tostring(o.Attachment1.Parent.CFrame.UpVector)) end end;return table.concat(out," | ")'
    print('Server',server(code),flush=True);print('Client',lua(code),flush=True)
    key('M')
    print(lua('for _,g in game.Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui") then g.Enabled=false end end;task.delay(.3,function() local p=game.Players.LocalPlayer.Character.HumanoidRootPart.Position;local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=CFrame.lookAt(p+Vector3.new(10,13,14),p);c.FieldOfView=45 end);return "camera"'),flush=True);time.sleep(.8);capture('g6_pose_detalhe')
finally:
    if iniciou:
        print(call('get_console_output'),flush=True);print(call('start_stop_play',is_start=False),flush=True)
    c.close()
