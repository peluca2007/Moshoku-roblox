"""Exporta os clipes de animação de combate como tabelas Luau (ANIM1) e renderiza a prévia de cada um.

Uso (sem janela; Blender 5.4 achado por tools/blender_rodar.py):
  python tools/blender_rodar.py tools/blender/anim_exportar.py [--clipes CorteLeve,Queda] [--sem-previa]
         [--ual build/externos/ual/<arquivo>.glb --mapa tools/animacao/ual_clipes.json] [--teste-ual CorteLeve]
Saídas: src/shared/Animacoes/Clipes/<Clipe>.luau, src/shared/Animacoes/Catalogo.luau (índice) e
build/anim/previa/<Clipe>.png (folha de contato montada a partir dos DADOS exportados).

Fonte dos dados: poses-chave escritas por script (anim_clipes.py). Com --ual, os clipes listados no mapa JSON vêm
da Universal Animation Library (anim_ual.py, redirecionada para o R15); os demais continuam posados por script.
Formato de cada clipe (o que o tocador lê): { nome, origem, fps, duracao, laco, segurar?, marcos = {nome = t},
  juntas = { <Motor6D> = { {t, qx, qy, qz, qw}, ... } }, raiz = { {t, x, y, z}, ... } }
Quatérnio = rotação do Motor6D.Transform (eixos da Part0, o que entra direto em CFrame.new(0,0,0,qx,qy,qz,qw));
raiz = translação do Transform da junta Root (studs, eixos do HumanoidRootPart).
"""
import json
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from mathutils import Quaternion, Vector  # noqa: E402

import anim_clipes  # noqa: E402
import anim_curvas as C  # noqa: E402
import anim_pose as AP  # noqa: E402
import anim_rig as R  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(AQUI))
PASTA_CLIPES = os.path.join(RAIZ, "src", "shared", "Animacoes", "Clipes")
CATALOGO = os.path.join(RAIZ, "src", "shared", "Animacoes", "Catalogo.luau")
PASTA_PREVIA = os.path.join(RAIZ, "build", "anim", "previa")
FPS = 30
TOL_ROT = 0.35  # graus
TOL_POS = 0.004  # studs
ORDEM = ["PosturaCombate", "CorteLeve", "CortePesado", "Estocada", "DisparoArco", "Conjurar", "Canalizar",
         "ReacaoGolpe", "Esquiva", "Bloqueio", "Queda", "Vitoria"]


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"clipes": None, "previa": True, "ual": None, "mapa": None, "quadros": 8, "teste_ual": None}
    i = 0
    while i < len(a):
        if a[i] == "--clipes":
            o["clipes"] = a[i + 1].split(",")
            i += 1
        elif a[i] == "--sem-previa":
            o["previa"] = False
        elif a[i] == "--ual":
            o["ual"] = a[i + 1]
            i += 1
        elif a[i] == "--mapa":
            o["mapa"] = a[i + 1]
            i += 1
        elif a[i] == "--teste-ual":
            o["teste_ual"] = a[i + 1]
            i += 1
        elif a[i] == "--quadros":
            o["quadros"] = int(a[i + 1])
            i += 1
        i += 1
    return o


def completar(canais, modos):
    """Completa os canais de uma chave nos dois modos (FK e IK) de cada membro. A chave é resolvida no modo em que foi
    escrita (braço com `maoX` = IK; pernas com `quadrilD` = FK) e a pose resolvida preenche o outro modo; o canal
    `pesoIK_<membro>` guarda o modo de origem. Assim a POSTURA (escrita em FK nos braços) entra num clipe de braço em IK
    (arco) e é reproduzida exatamente na primeira e na última chave."""
    c = {n: AP.canal(n, v) for n, v in canais.items()}
    natural = {"pernas": "fk" if "quadrilD" in c else "ik"}
    for X in AP.LADOS:
        natural["braco" + X] = "ik" if ("mao" + X) in c else "fk"
        natural["ref_mao" + X] = modos.get("ref_mao" + X, "mundo")
    pose, _ = AP.resolver(c, natural)
    m = R.fk(pose)
    for X, L in AP.LADOS.items():
        if natural["braco" + X] == "fk":
            pulso = R.pivo_mundo(m, L + "Wrist")
            c["mao" + X] = pulso - AP.ponto_ref(m, natural["ref_mao" + X])
            polo = R.pivo_mundo(m, L + "Elbow") - (R.pivo_mundo(m, L + "Shoulder") + pulso) / 2
            if polo.length > 1e-3:
                c["polo" + X] = polo.normalized()
        else:
            for canal_, junta in (("ombro", "Shoulder"), ("cotovelo", "Elbow"), ("pulso", "Wrist")):
                c[canal_ + X] = pose[L + junta][0].copy()
        c["pesoIK_braco" + X] = Vector((1.0 if natural["braco" + X] == "ik" else 0.0, 0, 0))
        if natural["pernas"] == "ik":
            for canal_, junta in (("quadril", "Hip"), ("joelho", "Knee"), ("tornozelo", "Ankle")):
                c[canal_ + X] = pose[L + junta][0].copy()
        else:
            pe = m[L + "Foot"]
            c["pe" + X] = pe @ Vector((0, -R.ALTURA_PE / 2, 0))
            c["pe" + X + "_rot"] = pe.to_quaternion()
            tornozelo = R.pivo_mundo(m, L + "Ankle")
            polo = R.pivo_mundo(m, L + "Knee") - (R.pivo_mundo(m, L + "Hip") + tornozelo) / 2
            if polo.length > 1e-3:
                c["joelho" + X + "_polo"] = polo.normalized()
    c["pesoIK_pernas"] = Vector((1.0 if natural["pernas"] == "ik" else 0.0, 0, 0))
    return c


def amostrar_script(clipe):
    """Poses-chave -> lista de (t, pose {junta: (q, t)}) a 30 fps, com IK resolvida em cada quadro."""
    modos = clipe.get("modos", {})
    chaves = [(t, completar(canais, modos), tensao) for t, canais, tensao in clipe["chaves"]]
    nomes = set()
    for _, canais, _ in chaves:
        nomes |= set(canais)
    canais_t = {}
    for nome in nomes:
        tempos, valores, tens = [], [], []
        for t, canais, tensao in chaves:
            tempos.append(t)
            valores.append(canais[nome] if nome in canais else AP.padrao(nome))
            tens.append(tensao)
        canais_t[nome] = (tempos, C._alinhar(valores), tens)
    dur = clipe["duracao"]
    n = int(math.ceil(dur * FPS - 1e-9))
    quadros, pior_ik = [], 0.0
    for k in range(n + 1):
        t = min(k / FPS, dur)
        c = {nome: C.hermite(tp, vl, ts, t, clipe.get("laco", False)) for nome, (tp, vl, ts) in canais_t.items()}
        pose, erro = AP.resolver(c, clipe.get("modos", {}))
        pior_ik = max(pior_ik, erro)
        quadros.append((t, pose))
    return quadros, pior_ik


def para_dados(nome, clipe, quadros, origem):
    tempos = [t for t, _ in quadros]
    juntas = {}
    for junta in R.NOMES_JUNTAS:
        serie = []
        for _, pose in quadros:
            q = pose.get(junta, (R.IDENT, None))[0].normalized()
            if serie and serie[-1].dot(q) < 0:
                q = Quaternion((-q.w, -q.x, -q.y, -q.z))
            elif not serie and q.w < 0:
                q = Quaternion((-q.w, -q.x, -q.y, -q.z))
            serie.append(q)
        manter = C.reduzir(tempos, serie, TOL_ROT, True)
        juntas[junta] = [[tempos[i], serie[i].x, serie[i].y, serie[i].z, serie[i].w] for i in manter]
    raiz = [Vector(pose["Root"][1] if pose["Root"][1] is not None else (0, 0, 0)) for _, pose in quadros]
    manter = C.reduzir(tempos, raiz, TOL_POS, False)
    return {
        "nome": nome, "origem": origem, "fps": FPS, "duracao": clipe["duracao"], "laco": bool(clipe.get("laco")),
        "segurar": bool(clipe.get("segurar")),
        "marcos": dict(clipe.get("marcos", {})),
        "juntas": juntas, "raiz": [[tempos[i], *raiz[i]] for i in manter],
    }


def _n(x, casas=4):
    s = f"{x:.{casas}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def escrever_luau(dados, caminho, nota):
    linhas = [
        "-- Gerado por tools/blender/anim_exportar.py (ANIM1). Não editar à mão: mude a fonte e regenere.",
        "-- " + nota,
        "-- Formato: ver src/shared/Animacoes/Amostra.luau. Quatérnio {t, qx, qy, qz, qw} = Motor6D.Transform.",
        "return {",
        f'\tnome = "{dados["nome"]}",',
        f'\torigem = "{dados["origem"]}",',
        f"\tfps = {dados['fps']},",
        f"\tduracao = {_n(dados['duracao'])},",
        f"\tlaco = {'true' if dados['laco'] else 'false'},",
    ] + (["\tsegurar = true, -- fica no último quadro até o tocador parar"] if dados.get("segurar") else []) + [
        "\tmarcos = { " + ", ".join(f"{k} = {_n(v)}" for k, v in sorted(dados["marcos"].items())) + (" }," if dados["marcos"] else "},"),
        "\tjuntas = {",
    ]
    for junta in R.NOMES_JUNTAS:
        chaves = dados["juntas"][junta]
        linhas.append(f"\t\t{junta} = {{")
        for i in range(0, len(chaves), 4):
            linhas.append("\t\t\t" + " ".join("{" + ", ".join(_n(v) for v in ch) + "}," for ch in chaves[i:i + 4]))
        linhas.append("\t\t},")
    linhas.append("\t},")
    linhas.append("\traiz = {")
    for i in range(0, len(dados["raiz"]), 4):
        linhas.append("\t\t" + " ".join("{" + ", ".join(_n(v) for v in ch) + "}," for ch in dados["raiz"][i:i + 4]))
    linhas.append("\t},")
    linhas.append("}")
    with open(caminho, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas) + "\n")


def escrever_catalogo(nomes):
    linhas = [
        "-- Gerado por tools/blender/anim_exportar.py (ANIM1). Índice dos clipes de animação por dados.",
        "-- Catalogo.CLIPES[nome] = tabela do clipe; Catalogo.NOMES = ordem estável. Ver tools/animacao/README.md.",
        'local Shared = game:GetService("ReplicatedStorage").Shared',
        "",
        "local CLIPES = {",
    ]
    for nome in nomes:
        linhas.append(f"\t{nome} = require(Shared.Animacoes.Clipes.{nome}),")
    linhas += ["}", "", "return {", "\tCLIPES = CLIPES,", "\tNOMES = { " + ", ".join(f'"{n}"' for n in nomes) + " },", "}"]
    with open(CATALOGO, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas) + "\n")


def main():
    o = args()
    if o["teste_ual"]:
        # ida e volta pelo redirecionamento da UAL num esqueleto sintético em T-pose (não grava nada)
        import anim_ual
        clipe = anim_clipes.CLIPES[o["teste_ual"]]
        quadros, _ = amostrar_script(clipe)
        dados = para_dados(o["teste_ual"], clipe, quadros, "script")
        erro_rot, erro_raiz, erro_tpose = anim_ual.testar_ida_e_volta(dados, FPS)
        print(f"TESTE UAL {o['teste_ual']}: erro de rotação {erro_rot:.3f} graus, erro da raiz {erro_raiz:.4f} studs, "
              f"T-pose -> braços abertos com erro de {erro_tpose:.2f} graus")
        return
    os.makedirs(PASTA_CLIPES, exist_ok=True)
    ual = {}
    if o["ual"]:
        import anim_ual
        with open(o["mapa"], encoding="utf-8") as f:
            mapa = json.load(f)
        ual = anim_ual.exportar(o["ual"], mapa, FPS)
    nomes = [n for n in ORDEM if n in anim_clipes.CLIPES or n in ual]
    escolhidos = o["clipes"] or nomes
    relatorio = []
    for nome in escolhidos:
        clipe = anim_clipes.CLIPES.get(nome)
        if nome in ual:
            quadros, info = ual[nome]
            base = dict(clipe or {}, **info)
            dados = para_dados(nome, base, quadros, "ual")
            nota = "Origem: Universal Animation Library (Quaternius, CC0), redirecionada para o R15; ver tools/animacao/FONTES.md."
            arma, pior_ik = base.get("arma"), 0.0
        else:
            quadros, pior_ik = amostrar_script(clipe)
            dados = para_dados(nome, clipe, quadros, "script")
            nota = "Origem: poses-chave posadas por script em tools/blender/anim_clipes.py."
            arma = clipe.get("arma")
        escrever_luau(dados, os.path.join(PASTA_CLIPES, nome + ".luau"), nota)
        n_chaves = sum(len(v) for v in dados["juntas"].values()) + len(dados["raiz"])
        linha = f"[{nome}] dur={dados['duracao']} chaves={n_chaves} ik={pior_ik:.4f}"
        if o["previa"]:
            import anim_previa
            c = anim_previa.conferir(dados, _pontos_arma(arma))
            linha += f" pe_min={c['pe_min'][0]:.3f}@{c['pe_min'][1]:.2f} penetra={c['penetra'][0]:.3f}@{c['penetra'][1]:.2f} {c['penetra'][2]}"
            png = anim_previa.folha(nome, dados, arma, PASTA_PREVIA, o["quadros"])
            linha += " -> " + os.path.relpath(png, RAIZ)
        print(linha)
        relatorio.append(linha)
    todos = [n for n in ORDEM if os.path.exists(os.path.join(PASTA_CLIPES, n + ".luau"))]
    escrever_catalogo(todos)
    print("catálogo:", ", ".join(todos))


def _pontos_arma(arma):
    if arma == "espada":
        return [("RightHand", Vector((0, 0, -0.6 - 0.35 * k))) for k in range(8)]
    return []


if __name__ == "__main__":
    main()
