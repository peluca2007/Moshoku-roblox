"""IMP1: capturas no meio do golpe (antecipação, impacto, pós). Requer Play em luta (qa.py esgoto_sala1 --manter-play).
  python tools/qa/impacto_fotos.py [rodada]
Salva em build/beleza/impacto/<rodada>_<n>.png."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ
from qa_jogo import acao_luta

rodada = sys.argv[1] if len(sys.argv) > 1 else "r1"
q = Qa()
q.cenario = "impacto"
destino = os.path.join(RAIZ, "build", "beleza", "impacto")
os.makedirs(destino, exist_ok=True)
r = acao_luta(q, "golpe")
t0 = time.time()
print("acao:", r)
for i in range(5):
    f = q.foto("%s_%d" % (rodada, i))
    print(i, round(time.time() - t0, 2), f)
    if f.startswith("build"):
        shutil.copyfile(os.path.join(RAIZ, f), os.path.join(destino, "%s_%d.png" % (rodada, i)))
q.c.close()
