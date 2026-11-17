"""Clipes Mixamo para criaturas humanoides de peças rígidas (REA4).

Pega o clipe já redirecionado ao R15 (dados de anim_mixamo.py), calcula a pose de cada peça do R15 pela cinemática
direta (anim_rig.fk) e converte para o formato por peça de Shared/Mundo/AnimacaoCriatura:
  pecas = { Corpo|Cabeca|BracoD|BracoE|PernaD|PernaE = { {t, qx, qy, qz, qw, dx, dy, dz}, ... } }
rotação em volta do pivô do grupo (Shared/Mundo/PivosModelos) + deslocamento, nos eixos do modelo (frente = -Z, como o R15).

Por padrão o movimento é relativo ao primeiro quadro (a guarda do pacote não é o repouso da criatura).
Mapa (cada grupo é UMA peça rígida, então o membro inteiro usa a média de orientação do segmento de cima e de baixo):
  Corpo = UpperTorso (junto da cintura), Cabeca = Head (pescoço), BracoX = X UpperArm/LowerArm (ombro),
  PernaX = X UpperLeg/LowerLeg (quadril). A peça `Arma` acompanha o braço da arma no próprio CriaturaAnimada.
O deslocamento (cintura/pescoço/ombro/quadril levados pela pose) é escalado por `escala` = altura do pescoço do modelo / 4.0
(o R15 tem o pescoço em y = 4,0).

Saída: src/shared/Animacoes/CriaturasMx/<Modulo>.luau = { modulo, clipes = { <Nome> = {...} } }, montado a partir do cache
build/anim/criaturas_mx/<Modulo>.json (fora do git), para regenerar um clipe sem perder os outros.
Licença/procedência: mesma do Mixamo (docs/ARTE.md); só os dados convertidos entram no repositório.
"""
import json
import math
import os
import re

from mathutils import Matrix, Quaternion, Vector

import anim_exportar as E
import anim_previa
import anim_rig as R

GRUPOS = {
    "Corpo": (("UpperTorso",), "Waist"),
    "Cabeca": (("Head",), "Neck"),
    "BracoD": (("RightUpperArm", "RightLowerArm"), "RightShoulder"),
    "BracoE": (("LeftUpperArm", "LeftLowerArm"), "LeftShoulder"),
    "PernaD": (("RightUpperLeg", "RightLowerLeg"), "RightHip"),
    "PernaE": (("LeftUpperLeg", "LeftLowerLeg"), "LeftHip"),
}
PASTA_MX = os.path.join(E.RAIZ, "src", "shared", "Animacoes", "CriaturasMx")
PASTA_CACHE = os.path.join(E.RAIZ, "build", "anim", "criaturas_mx")
PIVOS = os.path.join(E.RAIZ, "src", "shared", "Mundo", "PivosModelos.luau")
TOL_GRAUS = 0.6
TOL_POS = 0.006


def escala_do_modelo(modulo):
    """Altura do pescoço do modelo (PivosModelos.Cabeca[y]) dividida por 4,0 (pescoço do R15)."""
    txt = open(PIVOS, encoding="utf-8").read()
    m = re.search(r'\["%s"\] = \{.*?Cabeca = \{ *(-?[\d.]+), *(-?[\d.]+)' % re.escape(modulo), txt)
    if not m:
        raise SystemExit("modelo sem pivô de Cabeca em PivosModelos: " + modulo)
    return float(m.group(2)) / 4.0


def _media(q1, q2):
    if q1.dot(q2) < 0:
        q2 = Quaternion((-q2.w, -q2.x, -q2.y, -q2.z))
    return q1.slerp(q2, 0.5)


def converter(dados, escala, delta=True, volta=0.0):
    """dados = clipe R15 (com raiz já erguida) -> {"duracao", "marcos", "laco", "segurar", "pecas"}."""
    dur = dados["duracao"]
    n = max(2, int(math.ceil(dur * E.FPS - 1e-9)))
    ts = [min(k * dur / n, dur) for k in range(n + 1)]
    pecas = {g: [] for g in GRUPOS}
    for t in ts:
        mundo = anim_previa.posar(dados, t)
        for g, (partes, junta) in GRUPOS.items():
            q = mundo[partes[0]].to_quaternion()
            for p in partes[1:]:
                q = _media(q, mundo[p].to_quaternion())
            pivo = Vector(R.JUNTAS[junta][2])
            m = mundo[partes[0]]
            # ponto do pivô, preso à peça mãe da junta, depois da pose: M_peça @ (pivô - centro da peça em repouso)
            pos = m @ (pivo - Vector(R.PECAS[partes[0]][0]))
            d = (pos - pivo) * escala
            pecas[g].append((t, q.normalized(), d))
    # Delta do primeiro quadro: o clipe do Mixamo começa na postura de guarda do pacote, que não é a da criatura. O que
    # vale é o MOVIMENTO (reação, esquiva, queda) somado ao repouso da criatura: q_rel = q * q0^-1, d_rel = d - d0.
    if delta:
        for g, quadros in pecas.items():
            _, q0, d0 = quadros[0]
            inv = q0.inverted()
            pecas[g] = [(t, (q @ inv).normalized(), d - d0) for t, q, d in quadros]
    # volta: a fração final da duração leva o delta de volta ao repouso (esquiva/reação que termina fora do lugar),
    # para o clipe acabar na pose da criatura sem estalo.
    if volta > 0:
        for g, quadros in pecas.items():
            novo = []
            for t, q, d in quadros:
                u = (t / dur - (1 - volta)) / volta
                if u > 0:
                    k = 1 - u * u * (3 - 2 * min(u, 1))
                    q = Quaternion().slerp(q, k)
                    d = d * k
                novo.append((t, q, d))
            pecas[g] = novo
    saida = {}
    for g, quadros in pecas.items():
        ts_g = [t for t, _, _ in quadros]
        qs = []
        for _, q, _ in quadros:
            if qs and qs[-1].dot(q) < 0:
                q = Quaternion((-q.w, -q.x, -q.y, -q.z))
            qs.append(q)
        ds = [d for _, _, d in quadros]
        manter = {0, len(ts_g) - 1}
        # redução gulosa: mantém o quadro se a interpolação dos vizinhos mantidos errar mais que a tolerância
        ult = 0
        for i in range(1, len(ts_g) - 1):
            ok = True
            for j in range(ult + 1, i + 1):
                u = (ts_g[j] - ts_g[ult]) / (ts_g[i + 1] - ts_g[ult])
                qi = qs[ult].slerp(qs[i + 1], u)
                di = ds[ult].lerp(ds[i + 1], u)
                if math.degrees(qi.rotation_difference(qs[j]).angle) > TOL_GRAUS or (di - ds[j]).length > TOL_POS:
                    ok = False
                    break
            if not ok:
                manter.add(i)
                ult = i
        saida[g] = [[round(ts_g[i], 4), *(round(v, 4) for v in (qs[i].x, qs[i].y, qs[i].z, qs[i].w)),
                     *(round(v, 4) for v in ds[i])] for i in sorted(manter)]
    return {"duracao": dados["duracao"], "laco": bool(dados.get("laco")), "segurar": bool(dados.get("segurar")),
            "marcos": dict(dados.get("marcos", {})), "pecas": saida}


def gravar(modulo, nome, clipe, origem):
    os.makedirs(PASTA_CACHE, exist_ok=True)
    os.makedirs(PASTA_MX, exist_ok=True)
    cache = os.path.join(PASTA_CACHE, modulo + ".json")
    todos = json.load(open(cache, encoding="utf-8")) if os.path.exists(cache) else {}
    clipe["origem"] = origem
    todos[nome] = clipe
    with open(cache, "w", encoding="utf-8") as f:
        json.dump(todos, f, indent=1)
    linhas = [
        "-- Gerado por tools/blender/anim_criatura_mx.py (REA4). Não editar à mão: regenere com anim_mixamo.py --criatura.",
        "-- Origem: Mixamo (Adobe) redirecionado ao R15 e convertido para peças rígidas; FBX cru não redistribuído (docs/ARTE.md).",
        "-- Formato: Shared/Mundo/AnimacaoCriatura (quadro { t, qx, qy, qz, qw, dx, dy, dz }); mesclado aos clipes do módulo.",
        "return {", f'\tmodulo = "{modulo}",', "\tclipes = {"]
    for cn in sorted(todos):
        c = todos[cn]
        linhas.append(f"\t\t{cn} = {{")
        linhas.append(f'\t\t\torigem = "{c["origem"]}", fps = 30, duracao = {c["duracao"]:.4f}, laco = {"true" if c["laco"] else "false"}, '
                      f'segurar = {"true" if c["segurar"] else "false"},')
        marcos = ", ".join(f"{k} = {v}" for k, v in sorted(c["marcos"].items()))
        linhas.append(f"\t\t\tmarcos = {{ {marcos} }},")
        linhas.append("\t\t\tpecas = {")
        for g, ch in sorted(c["pecas"].items()):
            linhas.append(f"\t\t\t\t{g} = {{")
            for i in range(0, len(ch), 3):
                linhas.append("\t\t\t\t\t" + ", ".join("{" + ", ".join(f"{v:g}" for v in q) + "}" for q in ch[i:i + 3]) + ",")
            linhas.append("\t\t\t\t},")
        linhas.append("\t\t\t},")
        linhas.append("\t\t},")
    linhas += ["\t},", "}", ""]
    with open(os.path.join(PASTA_MX, modulo + ".luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas))
