"""Cliques reais na barra de cartas: escolhe um personagem, começa o Treino pelo
remoto e usa cartas pela INTERFACE (clique na carta; clique na ficha alvo em 3D,
ou segundo clique para confirmar). Confere o registro de cada uso.
Uso: python tools/playtest/cartas_ui.py [personagem carta:modo ...]"""
import json, sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client
sys.stdout.reconfigure(encoding="utf-8")

ROTEIROS = {
    "ladina": [("mesa/esconder", "confirmar"), ("mesa/ataque-basico", "boneco")],
    "bardo": [("mesa/dissonancia", "confirmar"), ("mesa/insulto", "boneco")],
    "tatico": [("mesa/apontar", "boneco"), ("mesa/ataque-basico", "boneco")],
    "duelista-da-agua": [("mesa/defender", "confirmar"), ("ability/deus-da-agua-corpo/Principiante/provocar", "boneco")],
    "mago-de-fogo": [("ability/fogo/Principiante/bola-de-fogo", "boneco")],
}
c = Client()
falhas = 0


def luau(code):
    r = c.call("execute_luau", {"studio_id": sid, "datamodel_type": "Client", "code": code})
    return r.get("text", "")


def clicar_xy(x, y):
    c.call("user_mouse_input", {"studio_id": sid, "datamodel_type": "Client", "actions": [
        {"action": "moveTo", "x": x, "y": y}, {"action": "mouseButtonDown", "mouse_button": "left"},
        {"action": "wait", "wait_time_ms": 120}, {"action": "mouseButtonUp", "mouse_button": "left"},
        {"action": "wait", "wait_time_ms": 900}]})


def xy(json_text):
    t = json_text
    return json.loads(t[t.find("{"):t.rfind("}") + 1])


PREP = """
local remote=game.ReplicatedStorage.Mesa
shared.UI={logs={}}
if not shared.UIcon then shared.UIcon=remote.OnClientEvent:Connect(function(k,d)
  if k=='snapshot' then shared.UIsnap=d elseif k=='log' then table.insert(shared.UI.logs,d.text) end end) end
remote:FireServer('combatEnd',{}) task.wait(.5)
remote:FireServer('escolherPersonagem',{id='%s'}) task.wait(.5)
remote:FireServer('iniciarTreino',{}) task.wait(2)
local s=shared.UIsnap; local me
for _,t in s.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId and t.habilidades then me=t end end
local b; for _,t in s.tokens do if t.name:find('Boneco') then b=t; break end end
remote:FireServer('move',{id=me.id,x=b.x,z=b.z+1}) task.wait(.6)
shared.UI.alvo=b.id
return 'ok'"""

CARTA = """
local id='%s'
local c=game.Players.LocalPlayer.PlayerGui:FindFirstChild('Carta_'..id,true) or game.Players.LocalPlayer.PlayerGui:FindFirstChild('Carta_'..(id:match('[^/]+$')),true)
if not c then return '{"erro":"sem carta"}' end
local r=c:FindFirstAncestorOfClass('ScrollingFrame')
if r then local rel=c.AbsolutePosition-r.AbsolutePosition+r.CanvasPosition; r.CanvasPosition=Vector2.new(math.max(0,rel.X-20),math.max(0,rel.Y-20)); task.wait(.3) end
local p=c.AbsolutePosition+c.AbsoluteSize/2
return game.HttpService:JSONEncode({x=p.X,y=p.Y})"""

ALVO = """
local m=workspace:FindFirstChild('MesaFichasLocais'):FindFirstChild(shared.UI.alvo)
local parte=m and (m.PrimaryPart or m:FindFirstChildWhichIsA('BasePart',true))
if not parte then return '{"erro":"sem modelo"}' end
local v,ok=workspace.CurrentCamera:WorldToScreenPoint(parte.Position)
return game.HttpService:JSONEncode({x=v.X,y=v.Y,ok=ok})"""

LISTA = """
local RS=game.ReplicatedStorage
local X=require(RS.Shared.Regras.Execucao)
local s=shared.UIsnap; local me
for _,t in s.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId and t.habilidades then me=t end end
local out={}
for _,id in me.habilidades do
  local m=X.MECANICAS[id]
  if m and not X.INDISPONIVEIS[id] and m.tipo~='formula' then
    local alvo=m.alvo or 'unico'; local modo='ficha'
    if alvo=='lista' or alvo=='disparos' then modo='lista'
    elseif m.tipo=='zona' then modo=(m.forma=='esferaNoConjurador') and 'confirmar' or 'casa'
    elseif m.tipo=='deslocamento' then modo='casa'
    elseif m.tipo=='utilidade' then modo=m.alvoCasa and 'casa' or 'confirmar'
    elseif m.tipo=='especial' or m.tipo=='invocacao' then modo=(m.alcanceCasas and alvo~='si') and 'ficha' or 'confirmar'
    elseif alvo=='si' or alvo=='esferaNoConjurador' or alvo=='adjacentes' then modo='confirmar'
    elseif alvo=='esferaNaCasa' or alvo=='cone' then modo='casa' end
    if m.soAliados then modo=modo=='ficha' and 'aliado' or modo end
    table.insert(out,id..'='..modo)
  end
end
return table.concat(out,';')"""

if len(sys.argv) > 1 and sys.argv[1] == "todas":
    ids = [l.split('"')[1] for l in open(Path(__file__).resolve().parents[2] / "src/shared/PersonagensProntos.luau", encoding="utf8") if l.strip().startswith('{ id = "')]
    ROTEIROS = {pid: None for pid in ids}

try:
    sid = c.studio_id()
    c.call("start_stop_play", {"studio_id": sid, "is_start": True})
    time.sleep(8)
    for pid, cartas in ROTEIROS.items():
        luau(PREP % pid)
        # G1: a barra abre em Golpes; a varredura precisa também das cartas de Apoio.
        grupo = xy(luau("local b=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Grupos.Tudo; local p=b.AbsolutePosition+b.AbsoluteSize/2; return game.HttpService:JSONEncode({x=p.X,y=p.Y})"))
        clicar_xy(grupo["x"], grupo["y"])
        if cartas is None:
            luau("local r=game.ReplicatedStorage.Mesa; local s=shared.UIsnap; local me; for _,t in s.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId and t.habilidades then me=t end end; r:FireServer('createToken',{name='Aliado',kind='jogador',pvMax=30,ownerUserId=0,x=me.x+1,z=me.z}); task.wait(.8); for _,t in shared.UIsnap.tokens do if t.name=='Aliado' then shared.UI.aliado=t.id end end; return 'ok'")
            texto = luau(LISTA)
            texto = texto[texto.find(next((x for x in texto if x.isalpha()), "")):] if texto else ""
            cartas = []
            for par in texto.strip().strip('"').split(";"):
                if "=" in par:
                    a, b = par.split("=", 1)
                    if b in ("ficha", "confirmar", "aliado"):
                        cartas.append((a.strip(), b.strip()))
        for carta, modo in cartas:
            # renova a vez e as Ações a cada carta (treino: o boneco passa sozinho)
            luau("local r=game.ReplicatedStorage.Mesa; local s=shared.UIsnap; if s.jogo and s.jogo.acoes and s.jogo.acoes.usadas>0 then r:FireServer('nextTurn',{expectedTurn=s.combat.turn}); task.wait(1.6) end; return 'ok'")
            luau("table.clear(shared.UI.logs)")
            pc = xy(luau(CARTA % carta))
            if "erro" in pc:
                print("FALHA", pid, carta, pc["erro"]); falhas += 1; continue
            clicar_xy(pc["x"], pc["y"])
            if modo == "confirmar":
                clicar_xy(pc["x"], pc["y"])
            else:
                pa = xy(luau(ALVO.replace("shared.UI.alvo", "shared.UI.aliado" if modo == "aliado" else "shared.UI.alvo")))
                if "erro" in pa or not pa.get("ok"):
                    print("FALHA", pid, carta, "alvo fora da tela", pa); falhas += 1; continue
                clicar_xy(pa["x"], pa["y"])
            time.sleep(1.2)
            logs = luau("return table.concat(shared.UI.logs,' / ')")
            usou = logs.strip() not in ("", '""')
            print(("OK    " if usou else "FALHA ") + pid + " " + carta + " :: " + logs[:220])
            falhas += 0 if usou else 1
finally:
    try:
        saida = c.call("get_console_output", {"studio_id": sid}).get("text", "")
        erros = [l for l in saida.splitlines() if ("Script" in l and ("error" in l.lower() or ":" in l and "attempt" in l)) or "attempt to" in l or "Stack Begin" in l or "[Mesa] erro" in l]
        print("CONSOLE: %d linha(s) de erro" % len(erros))
        for l in erros[:40]: print("  ", l[:240])
        c.call("start_stop_play", {"studio_id": sid, "is_start": False})
    except Exception:
        pass
    c.close()
print("RESULTADO:", "tudo ok" if falhas == 0 else f"{falhas} falha(s)")
