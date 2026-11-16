"""IMP1/IMP2: capturas no meio do golpe. Requer Play em luta (qa.py esgoto_sala1 --manter-play).
  python tools/qa/impacto_fotos.py <normal|critico|criatura|parede> [rodada] [escala]
Salva em build/beleza/impacto/<rodada>_<modo>_<n>.png (escala = EscalaDeTempoDasCenas, ex. 2 para câmera lenta)."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ
from qa_jogo import acao_luta

modo = sys.argv[1] if len(sys.argv) > 1 else "normal"
rodada = sys.argv[2] if len(sys.argv) > 2 else "r2"
escala = sys.argv[3] if len(sys.argv) > 3 else "1"
q = Qa()
q.cenario = "impacto"
destino = os.path.join(RAIZ, "build", "beleza", "impacto")
os.makedirs(destino, exist_ok=True)


def fotos(n, prefixo):
    t0 = time.time()
    acertou = False
    for i in range(n):
        f = q.foto("%s_%s_%d" % (rodada, prefixo, i))
        txt = q.lua_cliente("local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('AnuncioLuta') local o={} if g then for _,d in g:GetDescendants() do if d:IsA('TextLabel') and d.Visible and d.Text~='' then table.insert(o,d.Text) end end end return table.concat(o,' / ')")
        print(prefixo, i, round(time.time() - t0, 2), f, "|", txt)
        acertou = acertou or "de dano" in txt
        if f.startswith("build"):
            shutil.copyfile(os.path.join(RAIZ, f), os.path.join(destino, "%s_%s_%d.png" % (rodada, prefixo, i)))
    return acertou


q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', %s) workspace:SetAttribute('QaCritico', %s) return 'ok'" % (
    escala, "true" if modo == "critico" else "nil"))
try:
    if modo in ("normal", "critico"):
        for tentativa in range(5):  # o golpe pode errar: repete até acertar (o recibo de acerto traz "de dano")
            print("acao:", acao_luta(q, "golpe"))
            if fotos(6, modo):
                break
    elif modo == "criatura":
        print("golpe:", acao_luta(q, "golpe"))
        time.sleep(3)
        # encerra o turno do jogador: a criatura ataca
        print(q.lua_cliente("""local r=game.ReplicatedStorage:WaitForChild('Mesa') local snap
local c=r.OnClientEvent:Connect(function(k,d) if k=='snapshot' then snap=d end end) r:FireServer('requestSnapshot')
local t0=os.clock() while not snap and os.clock()-t0<5 do task.wait(0.1) end c:Disconnect()
if snap and snap.combat.active then r:FireServer('nextTurn',{expectedTurn=snap.combat.turn}) return 'turno encerrado' end return 'sem luta'"""))
        fotos(8, "criatura")
    elif modo == "parede":
        print(q.lua_arquivo_parede() if hasattr(q, "lua_arquivo_parede") else "use parede_teste.luau")
finally:
    q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', nil) workspace:SetAttribute('QaCritico', nil) return 'ok'")
    q.c.close()
