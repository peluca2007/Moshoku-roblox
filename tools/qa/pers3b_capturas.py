"""PERS3b: capturas da criação (prévia com o corpo novo, uma vista por raça) para conferência visual.
Uso: python tools/qa/pers3b_capturas.py   (Studio em Edit com src sincronizado; roda o Play sozinho)"""
import time
import pers3b_lib as L
from qa_jogo import criar_personagem, CRIACAO

q = L.Qa(); q.cenario = "pers3b"
try:
    try:
        q.play_parar(); time.sleep(3)
    except Exception:
        pass
    criar_personagem(q)
    time.sleep(4)
    fotos = []
    for r in ("humano", "elfo", "anao", "raca-fera", "hobbit", "oceano"):
        q.clique(CRIACAO + "Area.Raca.Racas.Raca_" + r); time.sleep(4)
        fotos.append(L.vista(q, "raca_" + r, ang=20, dist=7.5, ty=0.2, alt=0.3))
    L.montagem(fotos, "build/qa/pers3b/racas.png", (350, 0, 1060, 605))
    fotos = [L.vista(q, "rosto_%d" % a, ang=a, dist=3.2, ty=1.6) for a in (0, 40)]
    L.montagem(fotos, "build/qa/pers3b/rosto.png", (300, 0, 1100, 605))
finally:
    q.c.close()
