"""Sincroniza e testa apenas o Studio local Moshoku-Prototipo.rbxlx em Edit."""
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

def press(path):
    pos = json.loads(lua("local o=" + path + "; local p=o.AbsolutePosition+o.AbsoluteSize/2; return game.HttpService:JSONEncode({p.X,p.Y})"))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonUp", mouse_button="left", x=round(pos[0]), y=round(pos[1]))])
    time.sleep(.4)

try:
    studios = json.loads(c.call("list_roblox_studios", {})["text"])["studios"]
    local = [s for s in studios if s["name"] == "Moshoku-Prototipo.rbxlx"]
    assert len(local) == 1, studios
    sid = local[0]["id"]
    assert "- Current Studio Mode: Edit" in call("get_studio_state").splitlines()
    items = studio_sync.collect()
    for start in range(0, len(items), 6):
        result = call("execute_luau", datamodel_type="Edit", code=studio_sync.chunk_code(items[start:start+6]))
        if not result.startswith("alterados:"):
            raise RuntimeError(result)
    print("Fontes sincronizadas", flush=True)
    print(call("start_stop_play", is_start=True), flush=True); iniciou = True
    time.sleep(8)
    result = call("execute_luau", datamodel_type="Server", code='local r=game.ServerScriptService.Server; local p,f=require(r.TestRunner).run(r.tests); assert(f==0); return p.." specs aprovados"')
    print(result, flush=True); assert "specs aprovados" in result
    print(lua((base / "g1_cliente.luau").read_text(encoding="utf-8")), flush=True)
    root = "game.Players.LocalPlayer.PlayerGui.G1BarraTeste.Barra"
    press(root + ".Grupos.Apoio")
    print(lua('local r=shared.G1; r.check("clique abre apoio", r.barraGui.Barra.Cartas["Carta_mesa/esconder"].Visible); return "apoio"'), flush=True)
    press(root + '.Cartas["Carta_mesa/esconder"]')
    print(lua('local r=shared.G1; r.check("clique arma apoio", r.state.mira() and r.state.mira().habilidadeId=="mesa/esconder"); return "mira"'), flush=True)
    press(root + ".Grupos.Tudo")
    print(lua('local r=shared.G1; r.check("trocar grupo cancela mira",r.state.mira()==nil); local b=r.barraGui.Barra; b.UISizeConstraint.MaxSize=Vector2.new(375,math.huge); task.wait(.3); r.check("grade compacta tem duas colunas",b.Cartas.UIGridLayout.CellSize.X.Scale==.5); for _,o in b.Controles:GetChildren() do if o:IsA("TextButton") and o.Visible then r.check(o.Name.." toque >=44",o.AbsoluteSize.Y>=44); r.check(o.Name.." texto cabe",o.TextFits) end end; return "375px"'), flush=True)
    cap = call("screen_capture", capture_id="g1_barra_375")
    match = re.search(r"\[imagem salva em (.*?)\]", cap)
    if match:
        shutil.copyfile(match[1], base / ("g1_barra_375" + Path(match[1]).suffix))
    lua('local r=shared.G1; r.barraGui:Destroy(); r.ritmo:Destroy(); return "limpo"')
    print(lua('local r=game.ReplicatedStorage.Mesa; shared.G1real={}; shared.G1con=r.OnClientEvent:Connect(function(k,d) if k=="snapshot" then shared.G1real.s=d elseif k=="efeito" then shared.G1real.e=d end end); r:FireServer("escolherPersonagem",{id="bardo"}); task.wait(.4); r:FireServer("iniciarTreino",{}); task.wait(2); return "treino real"'), flush=True)
    real = "game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra"
    print(lua('local b=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra; shared.G1.check("barra dentro da janela",b.AbsolutePosition.X>=0 and b.AbsolutePosition.X+b.AbsoluteSize.X<=workspace.CurrentCamera.ViewportSize.X); return "limites"'), flush=True)
    press(real + ".Grupos.Apoio")
    press(real + '.Cartas["Carta_mesa/dissonancia"]')
    press(real + '.Cartas["Carta_mesa/dissonancia"]')
    print(lua('local r=shared.G1; local e=shared.G1real.e; r.check("cancao por clique recebe confirmacao real",e and e.habilidadeId=="mesa/dissonancia"); local f=game.Players.LocalPlayer.PlayerGui.RitmoCombate.Faixa; r.check("vinheta real anuncia cancao",f.Visible and f.Titulo.Text=="CANÇÃO: DISSONÂNCIA"); local a=shared.G1real.s.jogo.acoes; r.check("cancao real cobra uma Acao",a.usadas==1); return "acao real confirmada"'), flush=True)
    cap = call("screen_capture", capture_id="g1_cancao_real")
    match = re.search(r"\[imagem salva em (.*?)\]", cap)
    if match:
        shutil.copyfile(match[1], base / ("g1_cancao_real" + Path(match[1]).suffix))
    lua('game.ReplicatedStorage.Mesa:FireServer("sairPartida",{}); task.wait(.5); shared.G1con:Disconnect(); return "saiu do treino real"')
    print(lua((base / "g1_gestos.luau").read_text(encoding="utf-8")), flush=True)
    for _ in range(12):
        time.sleep(3)
        result = lua('local r=shared.G1; return r.pronto and ("FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")) or "aguardando gestos"')
        if "FINAL " in result:
            print(result, flush=True)
            assert "FINAL 0" in result and "FALHA " not in result
            break
    else:
        raise TimeoutError("gestos")
    print("Console:", call("get_console_output"), flush=True)
finally:
    if iniciou:
        print(call("start_stop_play", is_start=False), flush=True)
        print(call("get_studio_state"), flush=True)
    c.close()
