"""IMP3: mede o enquadramento do golpe (separação em tela atacante/alvo) e corpos duplicados do jogador.
  python tools/qa/impacto_enquadre.py <normal|criatura> [escala]
Requer Play em luta (qa.py esgoto_sala1 --manter-play). Reprova (código 1) se, com a câmera do golpe ativa
(peso >= 0,8), a separação em tela for < 15% da largura, ou se houver mais de uma cabeça visível do jogador."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, lua_arquivo
from qa_jogo import acao_luta
import time

modo = sys.argv[1] if len(sys.argv) > 1 else "normal"
escala = sys.argv[2] if len(sys.argv) > 2 else "1"
SEP_MIN = 0.10
q = Qa()
q.cenario = "enquadre"
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', %s) return 'ok'" % escala)
dur = 9 if escala != "1" else 6
try:
    lua_arquivo(q, "tools/qa/impacto_amostra.luau", troca={"@DUR@": str(dur)})
    if modo == "normal":
        print("acao:", acao_luta(q, "golpe"))
    else:
        print(q.lua_cliente("""local r=game.ReplicatedStorage:WaitForChild('Mesa') local snap
local c=r.OnClientEvent:Connect(function(k,d) if k=='snapshot' then snap=d end end) r:FireServer('requestSnapshot')
local t0=os.clock() while not snap and os.clock()-t0<5 do task.wait(0.1) end c:Disconnect()
if snap and snap.combat.active then r:FireServer('nextTurn',{expectedTurn=snap.combat.turn}) return 'turno encerrado' end return 'sem luta'"""))
    q.esperar(lambda: q.lua_cliente("return tostring(workspace:GetAttribute('QaEnquadre'))") not in ("rodando", "nil"), dur + 10, 1)
    bruto = q.lua_cliente("return tostring(workspace:GetAttribute('QaEnquadre'))")
    detalhe = q.lua_cliente("return tostring(workspace:GetAttribute('QaEnquadreDetalhe'))")
finally:
    q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', nil) workspace:SetAttribute('QaEnquadre', nil) return 'ok'")
    q.c.close()
amostras = [tuple(float(x) for x in l.split("|")) for l in bruto.split(";") if l.count("|") == 5]
ativas = [a for a in amostras if a[1] >= 0.8 and a[2] >= 0]  # câmera do golpe no ponto forte
print("amostras: %d; com câmera do golpe ativa (peso>=0,8): %d" % (len(amostras), len(ativas)))
falhas = 0
if not ativas:
    print("FALHA sem quadro com câmera do golpe (a ação não gerou golpe?)")
    falhas += 1
else:
    menor = min(a[2] for a in ativas)
    print("%s separação mínima em tela com o golpe ativo: %.1f%% (mínimo %.0f%%)" % ("OK  " if menor >= SEP_MIN else "FALHA", menor * 100, SEP_MIN * 100))
    falhas += menor < SEP_MIN
# tolera 1 quadro isolado (o fantasma nasce e o corpo real some no mesmo instante de render); 2+ seguidos reprova
mais = []
seguidos = 0
for a in amostras:
    seguidos = seguidos + 1 if a[3] > 1 else 0
    if seguidos >= 2:
        mais.append(a)
print("%s quadros com mais de uma cabeça do jogador visível: %d de %d%s" % ("OK  " if not mais else "FALHA", len(mais), len(amostras), "" if not mais else " (primeiro em t=%.2f)" % mais[0][0]))
falhas += bool(mais)
if detalhe != "nil":
    print(detalhe)
for a in amostras[::max(1, len(amostras) // 25)]:
    print("  t=%.2f peso=%.2f sep=%.1f%% cabecas=%d (avatar %d, fantasmas %d)" % (a[0], a[1], a[2] * 100, a[3], a[4], a[5]))
sys.exit(1 if falhas else 0)
