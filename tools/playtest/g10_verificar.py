"""Polimento: cartas proporcionais e recusas visíveis com cliques reais."""
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

c = Client()
sid, iniciou = None, False
base = Path(__file__).parent

def call(tool, **args):
    r = c.call(tool, dict(studio_id=sid, **args), timeout=60)
    if r.get("isError") or "erro" in r:
        raise RuntimeError(r)
    return r["text"]

def lua(code):
    return call("execute_luau", datamodel_type="Client", code=code)

def press(path):
    pos = json.loads(lua('local o=' + path + '; local a=o.Parent; while a and not a:IsA("ScrollingFrame") do a=a.Parent end; if a then local y=o.AbsolutePosition.Y-a.AbsolutePosition.Y; if y<0 then a.CanvasPosition+=Vector2.new(0,y) elseif y+o.AbsoluteSize.Y>a.AbsoluteSize.Y then a.CanvasPosition+=Vector2.new(0,y+o.AbsoluteSize.Y-a.AbsoluteSize.Y) end; task.wait(.2) end; local p=o.AbsolutePosition+o.AbsoluteSize/2; return game.HttpService:JSONEncode({p.X,p.Y})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonUp", mouse_button="left", x=round(pos[0]), y=round(pos[1]))])
    time.sleep(.2)

try:
    studios = json.loads(c.call("list_roblox_studios", {}, timeout=60)["text"])["studios"]
    sid = next(s["id"] for s in studios if s["name"] == "Moshoku-Prototipo.rbxlx")
    assert "- Current Studio Mode: Edit" in call("get_studio_state").splitlines()
    items = studio_sync.collect()
    for start in range(0, len(items), 6):
        assert call("execute_luau", datamodel_type="Edit", code=studio_sync.chunk_code(items[start:start+6])).startswith("alterados:")
    print(call("start_stop_play", is_start=True), flush=True)
    iniciou = True
    time.sleep(8)
    result = call("execute_luau", datamodel_type="Server", code='local r=game.ServerScriptService.Server; local p,f=require(r.TestRunner).run(r.tests); return p.." specs / "..f.." falhas"')
    print(result, flush=True)
    assert " / 0 falhas" in result
    print(lua('''
local R={falhas=0,linhas={}};shared.G10=R
function R.check(n,ok) table.insert(R.linhas,(if ok then "OK " else "FALHA ")..n);if not ok then R.falhas+=1 end end
local remote=game.ReplicatedStorage.Mesa
R.con=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then R.snap=d elseif k=="log" and d.tone=="erro" then R.erro=d.text end end)
remote:FireServer("escolherPersonagem",{id="bardo"});task.wait(.5);remote:FireServer("iniciarTreino",{});task.wait(2)
local g=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno;local b=g.Barra
R.check("barra real visivel",b.Visible)
R.check("poucos golpes ocupam uma linha",b.Cartas.AbsoluteSize.Y==92)
R.check("mais campo visivel",b.AbsoluteSize.Y<320)
return "Treino real"
'''), flush=True)
    root="game.Players.LocalPlayer.PlayerGui"
    press(root+".AcoesDoTurno.Barra.Grupos.Apoio")
    print(lua('local r=shared.G10;local b=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra;r.check("apoio continua rolavel",b.Cartas.AbsoluteCanvasSize.Y>b.Cartas.AbsoluteSize.Y);return "apoio"'),flush=True)
    press(root+'.AcoesDoTurno.Barra.Cartas["Carta_mesa/dissonancia"]')
    press(root+".AcoesDoTurno.Barra.Controles.ConfirmarAcao")
    print(lua('local r=shared.G10;r.check("confirmacao de cancao preservada",r.snap.jogo.acoes.usadas==1);local remote=game.ReplicatedStorage.Mesa;remote:FireServer("move",{id=r.snap.combat.turnId,x=999,z=999,andar=true});task.wait(.5);local g=game.Players.LocalPlayer.PlayerGui.AvisosJogo;r.check("recusa real visivel",r.erro~=nil and g.Recusa.Visible and g.Recusa.Mensagem.Text==r.erro);r.check("recusa nao gasta acao",r.snap.jogo.acoes.usadas==1);r.check("aviso dentro da janela",g.Recusa.AbsolutePosition.X>=0 and g.Recusa.AbsolutePosition.Y+g.Recusa.AbsoluteSize.Y<=workspace.CurrentCamera.ViewportSize.Y);return "recusa real"'),flush=True)
    shot=call("screen_capture",capture_id="g10_recusa")
    match=re.search(r"\[imagem salva em (.*?)\]",shot)
    if match: shutil.copyfile(match[1],base/("g10_recusa"+Path(match[1]).suffix))
    press(root+".AvisosJogo.Recusa.Fechar")
    print(lua('shared.G10.check("fechar aviso por clique real",not game.Players.LocalPlayer.PlayerGui.AvisosJogo.Recusa.Visible);return "fechado"'),flush=True)
    print(lua('''
local r=shared.G10;local callback
r.gui=require(game.Players.LocalPlayer.PlayerScripts.Client.AvisosJogo).start({onLog=function(fn) callback=fn end})
r.gui.Name="AvisosJogoBancada";r.callback=callback
callback({tone="sistema",text="Informação"});r.check("logs normais nao abrem aviso",not r.gui.Recusa.Visible)
callback({tone="erro",text=""});r.check("erro vazio ignorado",not r.gui.Recusa.Visible)
callback({tone="erro",text="Primeira recusa"});return "primeiro timer"
'''),flush=True)
    time.sleep(4)
    print(lua('local r=shared.G10;r.callback({tone="erro",text="Segunda recusa: escolha uma casa dentro do tabuleiro."});return "novo aviso"'),flush=True)
    time.sleep(3.5)
    print(lua('local r=shared.G10;r.check("timer velho nao esconde aviso novo",r.gui.Recusa.Visible and string.find(r.gui.Recusa.Mensagem.Text,"Segunda",1,true)~=nil);r.callback({tone="erro",text=string.rep("Descrição longa com acentos: ação fora do alcance. ",8)});task.wait(.3);r.check("mensagem longa cresce sem cortar",r.gui.Recusa.Mensagem.TextFits and r.gui.Recusa.AbsoluteSize.Y>64);return "texto longo"'),flush=True)
    press(root+".AvisosJogoBancada.Recusa.Fechar")
    print(lua('local r=shared.G10;r.check("fecho manual da bancada",not r.gui.Recusa.Visible);r.callback({tone="erro",text="Temporário"});return "expiracao"'),flush=True)
    time.sleep(7.5)
    print(lua('local r=shared.G10;r.check("expira apos tempo de leitura",not r.gui.Recusa.Visible);r.gui:Destroy();r.check("callback apos destruir seguro",pcall(r.callback,{tone="erro",text="Não reaparece"}));game.ReplicatedStorage.Mesa:FireServer("sairPartida",{});task.wait(.5);r.con:Disconnect();return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'),flush=True)
    assert lua('return shared.G10.falhas').strip()=="0"
    print("Console:",call("get_console_output"),flush=True)
finally:
    if iniciou:
        print(call("start_stop_play",is_start=False),flush=True)
        print(call("get_studio_state"),flush=True)
    c.close()
