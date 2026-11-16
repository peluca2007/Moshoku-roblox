"""Captura sequências de quadros de cada clipe de combate na luta aberta (Play ligado, ex.: qa.py esgoto_sala1 --manter-play).
Toca o clipe pelo atributo LutaClipeTeste (AnimacaoLuta) e captura N quadros seguidos; salva build/beleza/anim/<clipe>_<n>.jpg
e monta prancha.jpg (uma linha por clipe). Uso: python tools/qa/anim_quadros.py [clipe ...]"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qa_lib import Qa, RAIZ  # noqa: E402

SAIDA = os.path.join(RAIZ, "build", "beleza", "anim")
CLIPES = ["PosturaCombate", "CorteLeve", "CortePesado", "Estocada", "DisparoArco", "Conjurar", "ReacaoGolpe", "Esquiva", "Queda", "Vitoria"]


def main(clipes, n=6):
    from PIL import Image
    os.makedirs(SAIDA, exist_ok=True)
    q = Qa()
    q.cenario = "anim"
    linhas = []
    for clipe in clipes:
        dur = float(q.lua_cliente("return tostring(require(game.ReplicatedStorage.Shared.Animacoes.Catalogo).CLIPES.%s.duracao)" % clipe))
        q.lua_cliente("workspace:SetAttribute('LutaClipeManual', true) workspace:SetAttribute('LutaClipeTempo', 0) "
                      "workspace:SetAttribute('LutaClipeTeste', '%s') return 'ok'" % clipe)
        time.sleep(0.6)
        t0 = time.time()
        imgs = []
        for i in range(n):
            q.lua_cliente("workspace:SetAttribute('LutaClipeTempo', %.3f) return 'ok'" % (dur * i / (n - 1)))
            time.sleep(0.25)
            p = q.foto("%s_%d" % (clipe, i))
            imgs.append(Image.open(os.path.join(RAIZ, p)).convert("RGB"))
        print(clipe, "%.1f s para %d quadros" % (time.time() - t0, n))
        q.lua_cliente("workspace:SetAttribute('LutaClipeTeste', nil) workspace:SetAttribute('LutaClipeManual', nil) return 'ok'")
        w, h = imgs[0].size
        # recorte central (o personagem), reduzido
        cx0, cy0, cx1, cy1 = int(w * 0.25), int(h * 0.15), int(w * 0.75), int(h * 0.85)
        linha = []
        for i, im in enumerate(imgs):
            im.save(os.path.join(SAIDA, "%s_%d.jpg" % (clipe, i)), quality=80)
            linha.append(im.crop((cx0, cy0, cx1, cy1)).resize((300, int(300 * (cy1 - cy0) / (cx1 - cx0)))))
        linhas.append(linha)
        time.sleep(1.5)
    lw, lh = linhas[0][0].size
    prancha = Image.new("RGB", (lw * n, lh * len(linhas)))
    for r, linha in enumerate(linhas):
        for c, im in enumerate(linha):
            prancha.paste(im, (c * lw, r * lh))
    prancha.save(os.path.join(SAIDA, "prancha.jpg"), quality=80)
    print("prancha:", os.path.join(SAIDA, "prancha.jpg"))


if __name__ == "__main__":
    main(sys.argv[1:] or CLIPES)
