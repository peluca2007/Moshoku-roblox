"""QA no terminal: roda cenários no Roblox Studio (Play) e imprime uma linha por verificação.

  python tools/qa/qa.py <cenário|todos> [--manter-play] [--sem-deps]

Saída: `OK   <cenário> · <verificação>` / `FALHA <cenário> · <verificação> — <detalhe> [captura]`,
no fim `RESULTADO: N ok, M falha(s)`; código de saída 1 se houver falha. Veja README.md.
"""
import subprocess
import sys
import time
import traceback

from qa_lib import QaTimeout, Qa, RAIZ, os
import qa_cenarios as C

# cenário -> (função, dependências na ordem). `todos` roda nesta ordem; `specs` usa Play próprio.
CENARIOS = {
    "inicio": (C.inicio, []),
    "porta_sem_arvore": (C.porta_sem_arvore, ["inicio"]),
    "primeira_arvore": (C.primeira_arvore, ["porta_sem_arvore"]),
    "esgoto_sala1": (C.esgoto_sala1, ["primeira_arvore"]),
    "luta": (C.luta, ["esgoto_sala1"]),
    "acampamento": (C.acampamento, ["luta"]),
    "voltar_e_retomar": (C.voltar_e_retomar, ["acampamento"]),
    "esgoto_completo": (C.esgoto_completo, ["voltar_e_retomar"]),
    "menu": (C.menu, ["inicio"]),
    "area_de_testes": (C.area_de_testes, ["inicio"]),
    "specs": (C.specs, []),
}
ORDEM = list(CENARIOS)


def com_deps(nome, sem_deps):
    if sem_deps:
        return [nome]
    saida = []

    def visita(n):
        for d in CENARIOS[n][1]:
            visita(d)
        if n not in saida:
            saida.append(n)
    visita(nome)
    return saida


def parar_play_antigo():
    """Garante o Studio em Edit antes de sincronizar/ligar o Play (sobra de execução anterior com --manter-play)."""
    try:
        q = Qa()
        if "Mode: Edit" not in q.chamar("get_studio_state", {}, 30, 2):
            q.play_parar()
            time.sleep(3)
        q.c.close()
    except Exception:
        pass


def principal(argv):
    args = [a for a in argv if not a.startswith("--")]
    manter, sem_deps = "--manter-play" in argv, "--sem-deps" in argv
    if len(args) != 1 or (args[0] != "todos" and args[0] not in CENARIOS):
        print("uso: qa.py <%s|todos> [--manter-play] [--sem-deps]" % "|".join(ORDEM))
        return 2
    plano = ORDEM if args[0] == "todos" else com_deps(args[0], sem_deps)
    # `specs` quer um Play limpo: roda por último e num Play próprio.
    plano = [n for n in plano if n != "specs"] + (["specs"] if "specs" in plano else [])
    if not sem_deps:
        parar_play_antigo()
        subprocess.run([sys.executable, os.path.join(RAIZ, "tools", "studio_sync.py")], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
    q = Qa()
    inicio = time.time()
    try:
        for nome in plano:
            q.cenario = nome
            if nome == "specs" and q.play:
                q.play_parar()
                time.sleep(3)
            q.ultima_foto = ""
            try:
                CENARIOS[nome][0](q)
            except QaTimeout as e:
                q.verificar("cenário completo", False, "FALHA (timeout): %s" % e)
            except Exception as e:  # nunca morrer com traceback: vira falha do próprio teste
                tb = traceback.extract_tb(e.__traceback__)[-1]
                q.verificar("cenário completo", False, "erro do teste: %s em %s:%d" % (e, os.path.basename(tb.filename), tb.lineno))
            q.erros_do_console()
    finally:
        if not manter:
            q.fechar()
        else:
            q.c.close()
    print("RESULTADO: %d ok, %d falha(s)  (%d s)" % (q.ok, q.falhas, time.time() - inicio), flush=True)
    return 1 if q.falhas else 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
