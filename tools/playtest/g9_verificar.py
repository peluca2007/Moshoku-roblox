"""Bardo: projeção, cliques reais de recolher/abrir e canção em Treino."""
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
    pos = json.loads(lua('local o=' + path + '; local p=o.AbsolutePosition+o.AbsoluteSize/2; return game.HttpService:JSONEncode({p.X,p.Y})'))
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
local R={falhas=0,linhas={}};shared.G9=R
function R.check(n,ok) table.insert(R.linhas,(if ok then "OK " else "FALHA ")..n);if not ok then R.falhas+=1 end end
local remote=game.ReplicatedStorage.Mesa
R.con=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then R.snap=d elseif k=="efeito" then R.efeito=d end end)
remote:FireServer("escolherPersonagem",{id="bardo"});task.wait(.5)
remote:FireServer("iniciarTreino",{});task.wait(2)
local g=game.Players.LocalPlayer.PlayerGui.ApoioBardo;local p=g.Painel
R.check("painel real abre para Bardo",p.Visible)
R.check("canção inativa e usos explicitos",string.find(p.Estado.Text,"Sem canção",1,true)~=nil and string.find(p.Estado.Text,"Inspiração",1,true)~=nil)
R.check("painel dentro da janela",p.AbsolutePosition.X>=0 and p.AbsolutePosition.Y+p.AbsoluteSize.Y<=workspace.CurrentCamera.ViewportSize.Y)
return "Treino real"
'''), flush=True)
    root = "game.Players.LocalPlayer.PlayerGui"
    print(lua('local r=shared.G9;local p=game.Players.LocalPlayer.PlayerGui.ApoioBardo.Painel;r.check("abre compacto por padrao",not p.Efeitos.Visible);return "campo"'), flush=True)
    press(root + ".ApoioBardo.Painel.Alternar")
    print(lua('local r=shared.G9;local g=game.Players.LocalPlayer.PlayerGui.ApoioBardo;r.check("detalhes acima das acoes",g.Painel.Efeitos.Visible and g.DisplayOrder>game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.DisplayOrder);return "aberto"'), flush=True)
    press(root + ".ApoioBardo.Painel.Alternar")
    print(lua('local r=shared.G9;local p=game.Players.LocalPlayer.PlayerGui.ApoioBardo.Painel;r.check("recolher por clique real",not p.Efeitos.Visible);r.check("resumo continua visivel",p.Estado.Visible and p.AbsoluteSize.Y==110);return "recolhido"'), flush=True)
    print(lua('local r=shared.G9;game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=r.snap.combat.turnId,habilidadeId="mesa/marcha"});task.wait(.5);local p=game.Players.LocalPlayer.PlayerGui.ApoioBardo.Painel;r.check("Marcha confirmada pelo servidor",r.efeito and r.efeito.habilidadeId=="mesa/marcha");r.check("resumo atualiza recolhido",string.find(p.Estado.Text,"Marcha",1,true)~=nil and not p.Efeitos.Visible);r.check("acao real cobrada",r.snap.jogo.acoes.usadas==1);return "Marcha"'), flush=True)
    press(root + ".ApoioBardo.Painel.Alternar")
    print(lua('local r=shared.G9;local p=game.Players.LocalPlayer.PlayerGui.ApoioBardo.Painel;r.check("abrir por clique real",p.Efeitos.Visible);r.check("beneficiados e combinacoes legiveis",string.find(p.Efeitos.Resumo.Text,"QUEM RECEBE APOIO",1,true)~=nil and string.find(p.Efeitos.Resumo.Text,"Trocar substitui",1,true)~=nil);return "detalhes"'), flush=True)
    # Bancada isolada verifica atualização sem salto e destruição com callback pendente.
    print(lua('''
local r=shared.G9;local view=require(game.Players.LocalPlayer.PlayerScripts.Client.BardoView)
local callback;local g=view.start({onSnapshot=function(fn) callback=fn end});g.Name="ApoioBardoBancada"
r.gui=g;callback(r.snap);task.wait(.3)
local p=g.Painel;p.Efeitos.Visible=true;p.Efeitos.CanvasPosition=Vector2.new(0,30);task.wait(.1);local antes=p.Efeitos.CanvasPosition
callback(r.snap);r.check("snapshot igual preserva rolagem",p.Efeitos.CanvasPosition==antes)
g:Destroy();r.check("snapshot apos destruir nao falha",pcall(callback,r.snap))
return "bancada limpa"
'''), flush=True)
    shot = call("screen_capture", capture_id="g9_bardo")
    match = re.search(r"\[imagem salva em (.*?)\]", shot)
    if match:
        shutil.copyfile(match[1], base / ("g9_bardo" + Path(match[1]).suffix))
    print(lua('local r=shared.G9;game.ReplicatedStorage.Mesa:FireServer("sairPartida",{});task.wait(.5);r.check("sair oculta apoio",not game.Players.LocalPlayer.PlayerGui.ApoioBardo.Painel.Visible);r.con:Disconnect();return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'), flush=True)
    result = lua('return shared.G9.falhas')
    assert result.strip() == "0", result
    print("Console:", call("get_console_output"), flush=True)
finally:
    if iniciou:
        print(call("start_stop_play", is_start=False), flush=True)
        print(call("get_studio_state"), flush=True)
    c.close()
