"""HAB1: capturas das habilidades de espada/ladino em palco isolado (Play ativo, sem luta). Requer Studio em Play.
  python tools/qa/hab_espada.py <primeiro-golpe|corte-de-braco|golpe-continuo|investida-espada|todas> [escala] [--crit]
Cada habilidade roda em câmera lenta de QA (EscalaDeTempoDasCenas, padrão 5) e é fotografada a cada ~0,5 s
(antecipação, contato, recuperação). Salva em build/beleza/hab1/<habilidade>_<n>.png."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ

IDS = {
    "primeiro-golpe": ("ability/furtividade-e-armadilhas/Principiante/primeiro-golpe", 5),
    "corte-de-braco": ("ability/deus-da-espada/Principiante/corte-de-braco", 5),
    "golpe-continuo": ("ability/deus-da-espada/Principiante/golpe-continuo", 5),
    "investida-espada": ("ability/deus-da-espada/Principiante/investida-espada", 16),
}
args = [a for a in sys.argv[1:] if not a.startswith("--")]
alvo = args[0] if args else "todas"
escala = args[1] if len(args) > 1 else "5"
crit = "--crit" in sys.argv
lista = list(IDS) if alvo == "todas" else [alvo]
q = Qa()
q.cenario = "hab_espada"
destino = os.path.join(RAIZ, "build", "beleza", "hab1")
os.makedirs(destino, exist_ok=True)


def luau(modo, ident="", dist=5):
    codigo = open(os.path.join(RAIZ, "tools", "qa", "hab_espada.luau"), encoding="utf-8").read()
    for a, b in {"@MODO@": modo, "@ID@": ident, "@CRIT@": "true" if crit else "false", "@DIST@": str(dist)}.items():
        codigo = codigo.replace(a, b)
    return q.lua_cliente(codigo)


try:
    for nome in lista:
        ident, dist = IDS[nome]
        print(luau("montar", ident, dist))
        time.sleep(1.5)
        q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', %s) return 'ok'" % escala)
        print(luau("lancar", ident, dist))
        for i in range(10):
            f = q.foto("%s_%d" % (nome, i))
            print(nome, i, f)
            if f.startswith("build"):
                shutil.copyfile(os.path.join(RAIZ, f), os.path.join(destino, "%s%s%s_%d.png" % (nome, "_crit" if crit else "", "_rt" if escala == "1" else "", i)))
        time.sleep(2)
        print(luau("limpar", ident, dist))
finally:
    q.c.close()
