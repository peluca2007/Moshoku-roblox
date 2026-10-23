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
    print(server('local S=game.ReplicatedStorage.Shared; local X=require(S.Regras.Execucao); local C=require(S.Livro.Catalogo); local F=require(S.FichaV2); local P=require(game.ServerScriptService.Server.Premontados); local linhas={}; for _,p in require(S.PersonagensProntos) do local f,e=F.validar(game.HttpService:JSONDecode(P[p.id]),C); assert(f,e); local bc=X.bc(f,p.arvore,C); local arma=require(S.Regras.Arma).daFicha(f,C); table.insert(linhas,p.id.." BC="..bc.." CA="..tostring(f.calculated.armorClass).." arma="..tostring(X.atributoDaArma(p.arvore,arma.atributo,f,C)+arma.bonusDeRank)); end; for _,m in require(S.Livro.Regras).moldesDeCriatura do table.insert(linhas,"patamar="..tostring(m.patamar).." CA="..m.ca.." resistencia="..math.ceil(m.bonusAtaque/2)) end; return table.concat(linhas,"\\n")'),flush=True)
finally:
    if iniciou:
        print(call('start_stop_play',is_start=False),flush=True)
        print(call('get_studio_state'),flush=True)
    c.close()
