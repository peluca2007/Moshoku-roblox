"""Regressão do HUD no Studio local; não toca a outra janela nem publica."""
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

def capture(name):
    cap = call("screen_capture", capture_id=name)
    match = re.search(r"\[imagem salva em (.*?)\]", cap)
    if match:
        shutil.copyfile(match[1], base / (name + Path(match[1]).suffix))

try:
    studios = json.loads(c.call("list_roblox_studios", {})["text"])["studios"]
    local = [s for s in studios if s["name"] == "Moshoku-Prototipo.rbxlx"]
    assert len(local) == 1, studios
    sid = local[0]["id"]
    assert "- Current Studio Mode: Edit" in call("get_studio_state").splitlines()
    items = studio_sync.collect()
    for start in range(0, len(items), 6):
        result = call("execute_luau", datamodel_type="Edit", code=studio_sync.chunk_code(items[start:start+6]))
        assert result.startswith("alterados:"), result
    print("Fontes sincronizadas", flush=True)
    print(call("start_stop_play", is_start=True), flush=True); iniciou = True
    time.sleep(8)
    print(call("execute_luau", datamodel_type="Server", code='local r=game.ServerScriptService.Server; local p,f=require(r.TestRunner).run(r.tests); assert(f==0); return p.." specs aprovados"'), flush=True)
    print(lua((base / "g2_cliente.luau").read_text(encoding="utf-8")), flush=True)
    capture("g2_fila_375")
    pos = json.loads(lua('local o=shared.G2.gui.Ordem; o.CanvasPosition=Vector2.zero; local p=o.AbsolutePosition; return game.HttpService:JSONEncode({p.X+8,p.Y+o.AbsoluteSize.Y-2})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="moveTo", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonDown", mouse_button="left"),
        dict(action="moveTo", x=round(pos[0]+150), y=round(pos[1])),
        dict(action="wait", wait_time_ms=200),
        dict(action="mouseButtonUp", mouse_button="left")])
    print(lua('task.wait(.4); shared.G2.check("arrasto real navega a fila",shared.G2.gui.Ordem.CanvasPosition.X>0); return "rolagem real"'), flush=True)
    print(lua('local r=shared.G2; r.snap.combat.active=false; r.atualizar(); r.check("fora do combate esconde fila",not r.gui.Ordem.Visible and r.gui.Prazo.Text==""); r.check("fora do combate limpa participantes",#r.gui.Ordem:GetChildren()==3); r.gui:Destroy(); r.menu.Visible=r.menuAnterior; return "simulacao encerrada"'), flush=True)
    print(lua('local remote=game.ReplicatedStorage.Mesa; shared.G2con=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then shared.G2real=d end end); remote:FireServer("escolherPersonagem",{id="bardo"}); task.wait(.5); remote:FireServer("iniciarTreino",{}); task.wait(2); local r=shared.G2; local s=shared.G2real; local g=game.Players.LocalPlayer.PlayerGui.HudJogo; r.check("treino real tem HUD ativo",s and s.combat.active and g.Ordem.Visible); r.check("ator real primeiro",g.Ordem[s.combat.turnId].LayoutOrder==1 and g.Ordem[s.combat.turnId].Vez.Text=="AGORA"); r.turno=s.combat.turn; return "treino real"'), flush=True)
    pos = json.loads(lua('local o=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Controles.EncerrarTurno; local p=o.AbsolutePosition+o.AbsoluteSize/2; return game.HttpService:JSONEncode({p.X,p.Y})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonUp", mouse_button="left", x=round(pos[0]), y=round(pos[1]))])
    time.sleep(2)
    print(lua('local r=shared.G2; local s=shared.G2real; local pg=game.Players.LocalPlayer.PlayerGui; local g=pg.HudJogo; r.check("clique real passa turno",s.combat.turn~=r.turno); r.check("fila acompanha turno real",g.Ordem[s.combat.turnId].LayoutOrder==1 and g.Ordem[s.combat.turnId].Vez.Text=="AGORA"); r.check("rodada real permanece visivel",string.find(g.Prazo.Text,"Rodada "..s.combat.round,1,true)~=nil); r.check("sem letreiro duplicado no turno",pg.MesaAvisos:FindFirstChild("Letreiro")==nil); return "turno conferido"'), flush=True)
    print(lua('task.wait(.5); local g=game.Players.LocalPlayer.PlayerGui.HudJogo; local linhas={}; for _,o in g.Ordem:GetChildren() do if o:IsA("Frame") then table.insert(linhas,o.Name.." ordem="..o.LayoutOrder.." x="..o.AbsolutePosition.X.." visivel="..tostring(o.Visible)) end end; return table.concat(linhas,"\\n")'), flush=True)
    capture("g2_treino_real")
    result = lua('game.ReplicatedStorage.Mesa:FireServer("sairPartida",{}); task.wait(.5); shared.G2con:Disconnect(); local r=shared.G2; return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")')
    print(result, flush=True)
    assert "FINAL 0" in result and "FALHA " not in result, result
    print("Console:", call("get_console_output"), flush=True)
finally:
    if iniciou:
        print(call("start_stop_play", is_start=False), flush=True)
        print(call("get_studio_state"), flush=True)
    c.close()
