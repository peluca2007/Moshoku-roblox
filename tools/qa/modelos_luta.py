"""MOD5: repete `qa.py esgoto_sala1 --manter-play` até a sala 1 sortear o bandido (ou o goblin) e fotografa a luta.
Uso: python tools/qa/modelos_luta.py [bandido|goblin] [tentativas]   -> build/beleza/mod5/luta_<alvo>_<n>.png"""
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qa_lib import Qa, RAIZ  # noqa: E402

alvo = sys.argv[1] if len(sys.argv) > 1 else "bandido"
tent = int(sys.argv[2]) if len(sys.argv) > 2 else 8
dest = os.path.join(RAIZ, "build", "beleza", "mod5")
os.makedirs(dest, exist_ok=True)
for n in range(tent):
    subprocess.run([sys.executable, os.path.join(RAIZ, "tools", "qa", "qa.py"), "esgoto_sala1", "--manter-play"], capture_output=True)
    q = Qa()
    q.cenario = "mod5"
    nomes = q.lua_servidor("local t={} for _,m in workspace.CorposDeCriatura:GetChildren() do table.insert(t,m.Name) end return table.concat(t,',')")
    print(n, nomes)
    if alvo.lower() in str(nomes).lower():
        time.sleep(4)
        for i in range(3):
            f = q.foto("luta_%s_%d" % (alvo, i))
            if f.startswith("build"):
                shutil.copyfile(os.path.join(RAIZ, f), os.path.join(dest, "luta_%s_%d.png" % (alvo, i)))
            time.sleep(1.5)
        q.play_parar()
        break
    q.play_parar()
q.c.close()
