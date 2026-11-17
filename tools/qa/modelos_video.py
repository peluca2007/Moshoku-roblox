"""MOD7: vídeo (com foco, ffmpeg) de cada criatura modelada no Studio: parado, andando, ataque, dano e morte.
Uso: python tools/qa/modelos_video.py [rotulo ...]   Rótulos: bandido_espada bandido_porrete goblin urso treant golem
Palco do `anim_criaturas` (CriaturaAnimada, a mesma classe da luta). Pede o lock build/qa/STUDIO_EM_USO.txt (crie com MOD7).
Saída: build/beleza/mod7/<rotulo>.mp4"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_criaturas as A  # noqa: E402
from gravar import Gravador  # noqa: E402
from qa_lib import Qa, RAIZ  # noqa: E402

SAIDA = os.path.join(RAIZ, "build", "beleza", "mod7")
ITENS = {"bandido_espada": ("creature/bandido-de-estrada", 1), "bandido_porrete": ("creature/bandido-de-estrada", 0),
         "goblin": ("creature/goblin-batedor", 0), "urso": ("creature/urso-de-presas-vermelhas", 0),
         "treant": ("creature/treant-anciao", 0), "golem": ("creature/golem-de-pedra-menor", 0)}
SERVIDOR = A.SERVIDOR.replace("MC.escolher(id, 1, MM.existe)", 'MC.escolher(id, workspace:GetAttribute("AnimVar") or 1, MM.existe)')
ROTEIRO = [("parado", 1.5), ("andando", 2.0), ("ataque", 1.9), ("dano", 1.4), ("morte", 2.6)]


def main(nomes):
    os.makedirs(SAIDA, exist_ok=True)
    q = Qa()
    q.cenario = "mod6"
    q.play_ligar()
    time.sleep(8)
    q.lua_servidor(SERVIDOR)
    q.lua_cliente(A.CLIENTE)
    for rotulo in nomes:
        cid, var = ITENS[rotulo]
        q.lua_servidor("workspace:SetAttribute('AnimId','creature/rato-gigante') return 'ok'")
        time.sleep(2)
        q.lua_servidor("workspace:SetAttribute('AnimId','%s') workspace:SetAttribute('AnimVar',%d) workspace:SetAttribute('AnimEst','parado') return 'ok'" % (cid, var))
        time.sleep(3)
        with Gravador(os.path.join(SAIDA, rotulo + ".mp4"), segundos=sum(t for _, t in ROTEIRO) + 2.5):
            for est, t in ROTEIRO:
                q.lua_servidor("workspace:SetAttribute('AnimReset',true) workspace:SetAttribute('AnimEst','%s') return 'ok'" % est)
                time.sleep(t)
        print("gravado", rotulo)
    q.lua_cliente("pcall(function() game:GetService('RunService'):UnbindFromRenderStep('AnimCam') end) return 'ok'")
    q.play_parar()
    q.c.close()


if __name__ == "__main__":
    main(sys.argv[1:] or list(ITENS))
