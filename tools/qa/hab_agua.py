"""HAB2: capturas das magias de Água em palco isolado (Play ativo, sem luta). Requer Studio em Play.
  python tools/qa/hab_agua.py <respingo|bola-de-agua|flecha-de-agua|impacto-de-gelo|todas> [--erro] [--crit]
Salva em build/beleza/hab2/<magia>_<instante>.png. Cada foto usa CenaTempoFixo = instante da cena (determinístico),
então conjuração, projétil e impacto são pegos sem depender de relógio; a câmera lenta real da flecha se mede em
tempo real (hab_agua_lenta.py)."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ

MAGIAS = {
    "respingo": [("conjuracao", 0.3), ("projetil", 0.52), ("impacto", 0.78), ("molhado", 1.7)],
    "bola-de-agua": [("conjuracao", 0.6), ("projetil", 1.15), ("impacto", 1.5), ("molhado", 2.6)],
    "flecha-de-agua": [("conjuracao", 0.6), ("projetil", 0.98), ("impacto", 1.25), ("molhado", 2.4)],
    "impacto-de-gelo": [("conjuracao", 0.55), ("projetil", 0.95), ("impacto", 1.1), ("estilhaco", 1.8)],
}
q = Qa()
q.cenario = "hab_agua"
destino = os.path.join(RAIZ, "build", "beleza", "hab2")
os.makedirs(destino, exist_ok=True)
args = [a for a in sys.argv[1:] if not a.startswith("--")]
erro, crit = "--erro" in sys.argv, "--crit" in sys.argv
alvo = args[0] if args else "todas"
lista = list(MAGIAS) if alvo == "todas" else [alvo]


def luau(modo, ident="", acertou="true", critico="false"):
    codigo = open(os.path.join(RAIZ, "tools", "qa", "hab_agua.luau"), encoding="utf-8").read()
    for a, b in {"@MODO@": modo, "@ID@": ident, "@ACERTOU@": acertou, "@CRIT@": critico}.items():
        codigo = codigo.replace(a, b)
    return q.lua_cliente(codigo)


def fixo(t):
    q.lua_cliente("workspace:SetAttribute('CenaTempoFixo', %s) return 'ok'" % ("nil" if t is None else t))


try:
    print(luau("montar"))
    time.sleep(1.5)
    for nome in lista:
        ident = "ability/agua/Principiante/" + nome
        for rotulo, t in MAGIAS[nome]:
            fixo(t)
            print(luau("lancar", ident, "false" if erro else "true", "true" if crit else "false"))
            time.sleep(0.7)
            f = q.foto("%s_%s" % (nome, rotulo))
            print(nome, rotulo, t, f)
            if f.startswith("build"):
                sufixo = ("_erro" if erro else "") + ("_crit" if crit else "")
                shutil.copyfile(os.path.join(RAIZ, f), os.path.join(destino, "%s%s_%s.png" % (nome, sufixo, rotulo)))
            fixo(None)
            time.sleep(4.5)  # a cena termina sozinha; a próxima nasce limpa
finally:
    try:
        luau("limpar")
    finally:
        q.c.close()
