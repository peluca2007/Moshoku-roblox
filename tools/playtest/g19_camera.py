"""Enquadramento no start, pan preservado e reinício; desktop/emulador, não aparelho real."""
import json, os, re, shutil, sys, time, uuid
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE.parent))
os.environ["MOSHOKU_TESTE_JOGADOR"]="1"
from studio_mcp import Client
from studio_sync import long_string
c=Client();sid=None;started=False;fixture=False;original=None;orientation=None
run_id=str(uuid.uuid4());checks=[];serial=0
mode=sys.argv[1] if len(sys.argv)>1 else "desktop"

def call(tool,**args):
    timeout=args.pop("_timeout",60)
    result=c.call(tool,dict(studio_id=sid,**args),timeout=timeout)
    if result.get("isError") or "erro" in result:raise RuntimeError(result)
    return result["text"]
def lua(code,dm="Client"):return call("execute_luau",datamodel_type=dm,code=code)
def check(name,value):
    checks.append(bool(value));print(("OK " if value else "FALHA ")+name,flush=True)
def measure():
    global serial
    serial+=1
    lua('game.Players.LocalPlayer.PlayerScripts.G19Camera:SetAttribute("Medir",'+str(serial)+');return "medir"')
    time.sleep(.25)
    r=json.loads(lua('return game.Players.LocalPlayer.PlayerScripts.G19Camera:GetAttribute("Medida")'))
    assert r["serial"]==serial
    print("MEDIDA",json.dumps(r,ensure_ascii=False),flush=True)
    return r
def key(code,hold=150):
    print(call("user_keyboard_input",datamodel_type="Client",actions=[dict(action="keyDown",key_code=code),dict(action="wait",wait_time_ms=hold),dict(action="keyUp",key_code=code)]),flush=True)
    time.sleep(.8)
def start_match():
    lua('local r=game.ReplicatedStorage.Mesa;r:FireServer("escolherPersonagem",{id="mago-de-fogo",arma=require(game.ReplicatedStorage.Shared.PersonagensProntos)[1].armas[1].id});task.wait(.4);r:FireServer("salaConfigurar",{modo="treino",nivel=1,monstros=false});task.wait(.4);r:FireServer("salaPronto",{ativo=true});task.wait(.4);r:FireServer("salaIniciar",{});return "inicio solicitado"')
    deadline=time.time()+15
    while time.time()<deadline:
        r=json.loads(lua('return game.Players.LocalPlayer.PlayerScripts.G19Camera:GetAttribute("Estado")'))
        if r["combat"] and r["table"]:break
        time.sleep(.25)
    assert r["combat"] and r["table"],r
    time.sleep(1.2)
def framing(r,label):
    a=r["area"];cx=(a["x1"]+a["x2"])/2;cy=(a["y1"]+a["y2"])/2
    check(label+" centralizado sem painel fantasma",not r["panel"] and abs(r["center"][0]-cx)<3 and abs(r["center"][1]-cy)<3)
    check(label+" centros dos participantes dentro da area util",len(r["pieces"])==4 and all(p["on"] and a["x1"]+8<p["x"]<a["x2"]-8 and a["y1"]+8<p["y"]<a["y2"]-8 for p in r["pieces"]))
    card=r["card"]
    check(label+" cartao nao cobre centros dos participantes",not card["visible"] or all(not(card["x"]<=p["x"]<=card["x"]+card["w"] and card["y"]<=p["y"]<=card["y"]+card["h"]) for p in r["pieces"]))
    check(label+" quatro cantos da regiao cabem sem HUD",len(r["corners"])==4 and all(p["on"] and a["x1"]<=p["x"]<=a["x2"] and a["y1"]<=p["y"]<=a["y2"] for p in r["corners"]))
    check(label+" corte escuro revelou partida",not r["fade"] and r["transition"]["frames"]>0 and r["transition"]["escuro"] and r["transition"]["fora"]==0 and r["transition"]["maxY"]<14)
try:
    sid=next(s["id"] for s in json.loads(c.call("list_roblox_studios",{})["text"])["studios"] if "MoshokuRPGMesa" in s["name"])
    assert "Mode: Edit" in call("get_studio_state"),"Play externo preservado"
    assert mode in ("desktop","portrait","landscape")
    original=lua('return game:GetService("StudioDeviceSimulatorService"):GetDeviceAsync()',"Edit")
    orientation=lua('return game:GetService("StudioDeviceSimulatorService"):GetOrientationAsync().Name',"Edit")
    if mode=="desktop":lua('game:GetService("StudioDeviceSimulatorService"):StopSimulationAsync();return "desktop"',"Edit")
    else:
        orient="Portrait" if mode=="portrait" else "LandscapeLeft"
        lua('local s=game:GetService("StudioDeviceSimulatorService");s:SetDeviceAsync("iphone_7");s:SetOrientationAsync(Enum.ScreenOrientation.'+orient+');return "emulador"',"Edit")
    assert lua('return tostring(game.StarterPlayer.StarterPlayerScripts:FindFirstChild("G19Camera")==nil and workspace:GetAttribute("MoshokuTesteMestre")==nil)',"Edit").strip()=="true"
    fixture=True
    lua('local f=Instance.new("LocalScript");f.Name="G19Camera";f:SetAttribute("Execucao",'+json.dumps(run_id)+');f.Source='+long_string((BASE/"g19_camera.luau").read_text(encoding="utf-8"))+';f.Parent=game.StarterPlayer.StarterPlayerScripts;return "fixture"',"Edit")
    assert "Mode: Edit" in call("get_studio_state")
    started=True;print(call("start_stop_play",is_start=True),flush=True)
    if mode!="desktop":
        lua('game.Players.LocalPlayer.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.'+orient+';game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.'+orient+');return "orientacao do cliente"')
    print(lua('local f=game.Players.LocalPlayer.PlayerScripts:WaitForChild("G19Camera",20);local deadline=os.clock()+20;local r;repeat task.wait(.2);local v=f:GetAttribute("Estado");r=v and game.HttpService:JSONDecode(v) until (r and r.ready and r.seated) or os.clock()>deadline;assert(r and r.ready and r.seated and r.master==r.me,"precondicao sala falhou");game.TextChatService.ChatWindowConfiguration.Enabled=false;return "sala pronta"'),flush=True)
    start_match();first=measure();framing(first,"start")
    if mode=="desktop":check("aproximacao substitui altura fixa148",first["position"][1]<115)
    else:check("viewport emulado correto",first["vp"]==([374,666] if mode=="portrait" else [666,374]))
    match=re.search(r'\[imagem salva em (.*?)\]',call("screen_capture",capture_id="g19_start_"+mode))
    if match:shutil.copyfile(match[1],BASE/("g19_start_"+mode+Path(match[1]).suffix))
    if mode!="desktop":
        check("resumo compacto preserva recursos sem cartao grande",not first["card"]["visible"] and first["summary"] and all(s in first["resources"] for s in ("PV","PM","PT")))
        n=first["summaryName"];d=first["deadline"]
        check("nome e prazo sem sobreposicao",n["x"]+n["w"]/2<=d["x"]-d["w"]/2)
        b=first["menu"]
        check("MENU tocavel sem cobrir resumo",b["w"]>=44 and b["h"]>=44 and b["x"]-b["w"]/2>=d["x"]+d["w"]/2+8)
    if mode=="landscape":
        tray=first["tray"];b=tray["button"]
        check("barra inicial recolhida com recursos e acoes",not tray["open"] and tray["height"]<=70 and b["visible"] and b["h"]>=44 and all(s in b["text"] for s in ("ações","PV","PM","PT")))
        def click(b):
            print(call("user_mouse_input",datamodel_type="Client",actions=[dict(action="mouseButtonClick",mouse_button="left",x=round(b["x"]),y=round(b["y"]))]),flush=True)
            time.sleep(.5)
        click(b);opened=measure()
        check("clique nativo abre acoes na tela",opened["tray"]["open"] and opened["tray"]["y"]>=0)
        candidates=[b for b in opened["tray"]["cards"] if b["y"]>0 and b["y"]+b["h"]/2<opened["vp"][1]-36]
        assert candidates,"sem carta disponivel no viewport"
        click(candidates[0]);aim=measure()
        check("escolher carta recolhe e mantem cancelar acessivel",aim["mira"] and not aim["tray"]["open"] and aim["tray"]["extras"] and aim["tray"]["cancel"]["visible"] and aim["tray"]["cancel"]["y"]<aim["vp"][1]-36)
        click(aim["tray"]["cancel"]);cancelled=measure()
        check("cancelar nativo libera tabuleiro sem gastar acoes",not cancelled["mira"] and not cancelled["tray"]["open"] and cancelled["actions"]==first["actions"])
    if mode!="desktop":
        lua('local r=game.HttpService:JSONDecode(game.Players.LocalPlayer.PlayerScripts.G19Camera:GetAttribute("Medida"));game.ReplicatedStorage.Mesa:FireServer("nextTurn",{expectedId=r.turnId,expectedTurn=r.turn});return "passar vez real"')
        other=measure()
        check("passagem de turno recebida e resumo permanece compacto",other["turnId"]!=first["turnId"] and other["summary"] and not other["card"]["visible"])
        # O treino avança bonecos automaticamente; só mede a janela da primeira troca.
        a=other["area"]
        check("troca de turno nao cobre centros",all(p["on"] and a["y1"]<p["y"]<a["y2"] for p in other["pieces"]))
        b=other["menu"]
        print(call("user_mouse_input",datamodel_type="Client",actions=[dict(action="mouseButtonDown",mouse_button="left",x=round(b["x"]),y=round(b["y"])),dict(action="wait",wait_time_ms=200),dict(action="mouseButtonUp",mouse_button="left")]),flush=True)
        time.sleep(.3);opened_menu=measure()
        check("MENU compacto abre por clique nativo",opened_menu["menuOpen"] and opened_menu["menuClicks"]==other["menuClicks"]+1)
    if mode=="desktop":
        key("W",400);panned=measure()
        check("pan manual recebido e altera enquadramento",any(e["key"]=="W" and not e["processed"] for e in panned["keys"]) and abs(panned["center"][1]-first["center"][1])>15)
        lua('game.ReplicatedStorage.Mesa:FireServer("requestSnapshot",{});return "snapshot"');time.sleep(.5)
        stable=measure();check("snapshot nao recentraliza pan manual",abs(stable["center"][1]-panned["center"][1])<2)
        before_m=sum(e["key"]=="M" for e in stable["keys"])
        key("M");off=measure()
        after_m=[e for e in off["keys"] if e["key"]=="M"]
        check("primeiro M entregue sai da camera de mesa",not off["table"] and len(after_m)==before_m+1 and not after_m[-1]["processed"])
        key("M");back=measure()
        after_m=[e for e in back["keys"] if e["key"]=="M"]
        check("segundo M entregue preserva pan manual",back["table"] and len(after_m)==before_m+2 and not after_m[-1]["processed"] and abs(back["center"][1]-panned["center"][1])<2)
        lua('game.ReplicatedStorage.Mesa:FireServer("sairPartida",{});return "sair"');time.sleep(1.5)
        print(lua('local f=game.Players.LocalPlayer.PlayerScripts.G19Camera;local deadline=os.clock()+15;local r;repeat task.wait(.2);r=game.HttpService:JSONDecode(f:GetAttribute("Estado")) until (not r.combat and r.seated) or os.clock()>deadline;assert(not r.combat and r.seated,"retorno sala falhou");return "voltou sentado"'),flush=True)
        start_match();again=measure();framing(again,"reinicio")
        check("nova partida descarta pan anterior e tem transicao propria",abs(again["center"][1]-first["center"][1])<3 and again["transition"]["inicio"]!=first["transition"]["inicio"])
    print("FINAL",sum(not x for x in checks),"falhas /",len(checks),"checks",mode,flush=True)
    assert all(checks)
    try:print(call("get_console_output",_timeout=12),flush=True)
    except TimeoutError as e:print("LIMITACAO leitura Output:",str(e),flush=True)
finally:
    try:
        try:
            if started and "Mode: Edit" not in call("get_studio_state"):print(call("start_stop_play",is_start=False),flush=True)
        finally:
            if fixture and "Mode: Edit" in call("get_studio_state"):
                print(lua('local f=game.StarterPlayer.StarterPlayerScripts:FindFirstChild("G19Camera");if f and f:GetAttribute("Execucao")=='+json.dumps(run_id)+' then f:Destroy() end;return "fixture propria removida"',"Edit"),flush=True)
    finally:
        try:
            if original is not None and "Mode: Edit" in call("get_studio_state"):
                restore='local s=game:GetService("StudioDeviceSimulatorService");s:StopSimulationAsync();'
                if original!="default":restore+='s:SetDeviceAsync('+json.dumps(original)+');s:SetOrientationAsync(Enum.ScreenOrientation['+json.dumps(orientation)+']);'
                print(lua(restore+'return s:GetDeviceAsync()',"Edit"),flush=True)
        finally:c.close()
