"""Clipes das criaturas Quaternius por PEÇA RÍGIDA (ANIM2).

Chamado por criaturas_quaternius.py (opção --clipes 1) enquanto o esqueleto do FBX ainda existe. Para cada animação
original (Idle, Walk, Attack, Death, Flying, Hit...) amostra a malha deformada em todos os quadros, ajusta por mínimos
quadrados (Kabsch) a transformação rígida de cada peça (Corpo, Cabeca, BracoE/D, PernaE/D, Cauda) em relação à pose de
repouso da peça e grava em src/shared/Animacoes/Criaturas/<Modulo>.luau.

Convenção do quadro: { t, qx, qy, qz, qw, dx, dy, dz } no espaço do modelo do Roblox (o mesmo dos pivôs de PivosModelos:
origem no centro da base, y para cima, frente = -Z). A peça vai de p para  R * (p - pivô) + pivô + d.  Rotação por
quatérnio (como Animacoes/Amostra), d em unidades do modelo (escala 1). O que o pacote não traz (levar golpe;
morrer da serpente) é sintetizado aqui e marcado em `origem`.
"""
import math
import os

import numpy as np
from mathutils import Matrix

# autoral (Blender, após T) -> Roblox: (x, y, z) -> (-x, z, y)  [ver criaturas.py::_Criatura.exportar]
M = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])

# Modulo -> { clipe: (sufixo da ação, laço) }. O prefixo da ação vem do próprio FBX (Rat_Idle -> "Idle").
LAÇO = True
CLIPES = {
    "RatoQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Correr": ("Run", LAÇO), "Atacar": ("Attack", False), "Morrer": ("Death", False)},
    "AranhaQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Atacar": ("Attack", False), "Morrer": ("Death", False)},
    "SerpenteQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Atacar": ("Attack", False)},
    "SapoQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Jump", LAÇO), "Atacar": ("Attack", False), "Morrer": ("Death", False)},
    "VespaQuaternius": {"Voar": ("Flying", LAÇO), "Atacar": ("Attack", False), "Morrer": ("Death", False)},
    "EsqueletoQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Running", LAÇO), "Atacar": ("Attack", False), "Morrer": ("Death", False)},
    "SlimeQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Atacar": ("Attack", False), "Morrer": ("Death", False)},
    "MorcegoQuaternius": {"Voar": ("Flying", LAÇO), "Atacar": ("Attack", False), "Atacar2": ("Attack2", False), "LevarGolpe": ("Hit", False), "Morrer": ("Death", False)},
    "DragaoQuaternius": {"Voar": ("Flying", LAÇO), "Atacar": ("Attack", False), "Atacar2": ("Attack2", False), "LevarGolpe": ("Hit", False), "Morrer": ("Death", False)},
    # MOD4: lobo (Animal Pack Vol.2: só Idle e Walking; Atacar, LevarGolpe e Morrer sintetizados) e goblin (Character Pack; o Defeat do pacote volta de pé, então Morrer é sintetizado)
    "LoboQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walking", LAÇO)},
    "GoblinQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Atacar": ("Punch", False),
                         "LevarGolpe": ("RecieveHit", False)},
    # MOD5: bandidos humanoides (mesmo esqueleto do goblin; Morrer sintetizado)
    "BandidoEspadaQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Atacar": ("Punch", False),
                         "LevarGolpe": ("RecieveHit", False)},
    "BandidoPorreteQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Atacar": ("Punch", False),
                         "LevarGolpe": ("RecieveHit", False)},
}
# Clipes que terminam no último quadro (não voltam ao repouso).
SEGURAR = {"Morrer"}
# Tolerâncias da redução de quadros: rotação (rad) e deslocamento (fração da altura do modelo).
TOL_ROT, TOL_POS = 0.006, 0.004
DESTINO = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))),
                       "src", "shared", "Animacoes", "Criaturas")


# ---------------------------------------------------------------- ajuste rígido
def ajustar(P, Q, pivo):
    """R, d tais que Q ~ R (P - pivo) + pivo + d (Kabsch; P, Q n x 3, autoral)."""
    cp, cq = P.mean(axis=0), Q.mean(axis=0)
    H = (P - cp).T @ (Q - cq)
    U, S, Vt = np.linalg.svd(H)
    s = np.diag([1.0, 1.0, np.sign(np.linalg.det(Vt.T @ U.T))])
    R = Vt.T @ s @ U.T
    d = cq - (R @ (cp - pivo) + pivo)
    return R, d


def quat_roblox(Rb):
    """Rotação autoral -> quatérnio (x, y, z, w) no Roblox."""
    Rr = M @ Rb @ M.T
    q = Matrix(Rr.tolist()).to_quaternion()
    return np.array([q.x, q.y, q.z, q.w])


def alinhar(quats):
    """Sinais contínuos (q e -q são a mesma rotação; o Amostra faz slerp pelo caminho curto de qualquer jeito)."""
    for i in range(1, len(quats)):
        if np.dot(quats[i], quats[i - 1]) < 0:
            quats[i] = -quats[i]
    return quats


def ang(a, b):
    return 2 * math.acos(min(1.0, abs(float(np.dot(a, b)))))


def slerp(a, b, u):
    if np.dot(a, b) < 0:
        b = -b
    d = min(1.0, float(np.dot(a, b)))
    if d > 0.9995:
        r = a * (1 - u) + b * u
    else:
        t = math.acos(d)
        r = (a * math.sin((1 - u) * t) + b * math.sin(u * t)) / math.sin(t)
    return r / np.linalg.norm(r)


def reduzir(tempos, quats, desl, escala, obrigatorios):
    """Remove quadros que a interpolação entre os vizinhos mantidos reproduz dentro da tolerância (Douglas-Peucker)."""
    n = len(tempos)
    manter = {0, n - 1} | set(obrigatorios)
    pilha = []
    ordem = sorted(manter)
    for a, b in zip(ordem, ordem[1:]):
        pilha.append((a, b))
    while pilha:
        a, b = pilha.pop()
        pior, onde = 0.0, None
        for i in range(a + 1, b):
            u = (tempos[i] - tempos[a]) / (tempos[b] - tempos[a])
            er = ang(quats[i], slerp(quats[a], quats[b], u)) / TOL_ROT
            ep = float(np.linalg.norm(desl[i] - (desl[a] * (1 - u) + desl[b] * u))) / (TOL_POS * escala)
            e = max(er, ep)
            if e > pior:
                pior, onde = e, i
        if onde is not None and pior > 1.0:
            manter.add(onde)
            pilha += [(a, onde), (onde, b)]
    return sorted(manter)


# ---------------------------------------------------------------- amostragem das ações originais
def amostrar_acao(bpy, arm, acao, malhas, verts, T, pivos, nomes_acao_fps):
    """Quadro a quadro: { parte: (quats[n], desl[n]) } no Roblox, t em segundos a partir de 0."""
    arm.animation_data_create().action = acao
    ini, fim = int(round(acao.frame_range[0])), int(round(acao.frame_range[1]))
    fps = bpy.context.scene.render.fps
    saida = {p: ([], []) for p in verts}
    tempos = []
    for f in range(ini, fim + 1):
        bpy.context.scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        pos = []
        for o in malhas:
            oe = o.evaluated_get(dg)
            me = oe.to_mesh()
            a = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", a)
            a = a.reshape(-1, 3)
            mw = np.array(oe.matrix_world)
            pos.append(T(a @ mw[:3, :3].T + mw[:3, 3]))
            oe.to_mesh_clear()
        tempos.append((f - ini) / fps)
        for parte, idx in verts.items():
            Q = np.array([pos[mi][vi] for mi, vi in idx])
            R, d = ajustar(repouso[parte], Q, np.array(pivos[parte]))
            saida[parte][0].append(quat_roblox(R))
            saida[parte][1].append(M @ d)
    return tempos, {p: (alinhar(q), np.array(d)) for p, (q, d) in saida.items()}, fps


repouso = {}  # parte -> pontos de repouso (n x 3), preenchido por gerar()


def impacto(dados, tempos):
    """Instante do golpe: o avanço máximo (para -Z) de Cabeca e Corpo, somados com os braços da frente."""
    pontos = np.zeros(len(tempos))
    for parte in ("Cabeca", "Corpo", "BracoE", "BracoD"):
        if parte in dados:
            pontos += -dados[parte][1][:, 2] * (1.0 if parte in ("Cabeca", "Corpo") else 0.5)
    return float(tempos[int(np.argmax(pontos))])


def fechar_laco(tempos, dados, escala, fps):
    """Se o último quadro repete o primeiro, descarta-o (duração = n-1 quadros); senão acrescenta o primeiro no fim."""
    quase = all(ang(q[-1], q[0]) < 0.03 and np.linalg.norm(d[-1] - d[0]) < 0.02 * escala for q, d in dados.values())
    if quase:
        tempos = tempos[:-1]
        dados = {p: (q[:-1], d[:-1]) for p, (q, d) in dados.items()}
        dur = tempos[-1] + 1.0 / fps
    else:
        dur = tempos[-1] + 1.0 / fps
    tempos = list(tempos) + [dur]
    dados = {p: (np.vstack([q, q[:1]]), np.vstack([d, d[:1]])) for p, (q, d) in dados.items()}
    return tempos, dados, dur


# ---------------------------------------------------------------- clipes sintetizados
def quat_de(R):
    q = Matrix(R.tolist()).to_quaternion()
    return np.array([q.x, q.y, q.z, q.w])


def rot(eixo, a):
    c, s = math.cos(a), math.sin(a)
    if eixo == "x":
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if eixo == "y":
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def suave(k):
    k = min(max(k, 0.0), 1.0)
    return k * k * (3 - 2 * k)


def sintetizar(pivos_r, tempos, fn, extra=None):
    """Transformação do modelo todo em volta da origem (centro da base no chão): fn(t) -> (R, tv). Cada peça gira em
    volta do próprio pivô: d = R pv + tv - pv. `extra(parte, t)` devolve uma rotação local em volta do pivô (cabeça)."""
    dados = {}
    for parte, pv in pivos_r.items():
        qs, ds = [], []
        for t in tempos:
            R, tv = fn(t)
            loc = extra(parte, t) if extra else np.eye(3)
            qs.append(quat_de(R @ loc))
            ds.append(R @ pv + tv - pv)
        dados[parte] = (alinhar(qs), np.array(ds))
    return dados


def levar_golpe(pivos_r, altura):
    """Recuo curto (o pacote não traz para a maioria): o corpo se inclina para trás (+Z) e volta; a cabeça balança mais."""
    dur, fps = 0.42, 24
    tempos = [i / fps for i in range(int(round(dur * fps)) + 1)]

    def env(t):
        k = t / dur
        return suave(k / 0.3) if k < 0.3 else 1 - suave((k - 0.3) / 0.7)

    def fn(t):
        e = env(t)
        return rot("x", 0.22 * e), np.array([0.0, 0.0, 0.12 * altura * e])

    def extra(parte, t):
        return rot("x", 0.3 * env(t)) if parte == "Cabeca" else np.eye(3)

    return tempos, sintetizar(pivos_r, tempos, fn, extra), dur


def mordida(pivos_r, altura):
    """Bote sintetizado (lobo: o pacote só traz Idle e Walking): recua o corpo, salta para a frente (-Z) com a cabeça
    baixa no instante do impacto (marco) e volta. Quadrúpede: o corpo inclina para a frente, a cabeça avança mais."""
    dur, fps = 15 / 24, 24
    tempos = [i / fps for i in range(int(round(dur * fps)) + 1)]
    t_imp = 0.30

    def env(t):  # -0.35 (recuo) em 0.12 s, 1 no impacto, 0 no fim
        if t < 0.12:
            return -0.35 * suave(t / 0.12)
        if t < t_imp:
            return -0.35 + 1.35 * suave((t - 0.12) / (t_imp - 0.12))
        return 1 - suave((t - t_imp) / (dur - t_imp))

    def fn(t):
        e = env(t)
        return rot("x", -0.16 * e), np.array([0.0, 0.0, -0.30 * altura * e])

    def extra(parte, t):
        return rot("x", -0.42 * env(t)) if parte == "Cabeca" else (rot("x", 0.3 * env(t)) if parte == "Cauda" else np.eye(3))

    return tempos, sintetizar(pivos_r, tempos, fn, extra), dur, t_imp


def tombar(pivos_r, pontos_r):
    """Morte sintetizada (serpente: o pacote não traz): tomba de lado em 0,6 s e fica, apoiada no chão."""
    dur, fps = 0.6, 24
    tempos = [i / fps for i in range(int(round(dur * fps)) + 1)]

    def fn(t):
        R = rot("z", 1.45 * suave(t / dur))
        subida = -float((pontos_r @ R.T)[:, 1].min())  # nenhum ponto abaixo do chão
        return R, np.array([0.0, max(subida, 0.0), 0.0])

    return tempos, sintetizar(pivos_r, tempos, fn), dur


# ---------------------------------------------------------------- Luau
def _n(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def escrever(modulo, clipes, escala):
    os.makedirs(DESTINO, exist_ok=True)
    linhas = [
        "-- Gerado por tools/blender/kits/criaturas_clipes.py (ANIM2). Não editar à mão: regenere com",
        "--   python tools/blender_rodar.py tools/blender/kits/criaturas_quaternius.py --clipes 1 --so <Nome>",
        "-- Origem: animações do pacote Quaternius (CC0), amostradas por peça rígida (Kabsch). Formato em",
        "-- Shared/Mundo/AnimacaoCriatura.luau: quadro { t, qx, qy, qz, qw, dx, dy, dz }, rotação em volta do pivô + deslocamento.",
        "return {",
        f'\tmodulo = "{modulo}",',
        "\tclipes = {",
    ]
    for nome, c in clipes.items():
        linhas.append(f"\t\t{nome} = {{")
        linhas.append(f'\t\t\torigem = "{c["origem"]}", fps = {_n(c["fps"])}, duracao = {_n(c["duracao"])}, laco = {"true" if c["laco"] else "false"}, segurar = {"true" if c["segurar"] else "false"},')
        marcos = ", ".join(f"{k} = {_n(v)}" for k, v in c["marcos"].items())
        linhas.append(f"\t\t\tmarcos = {{ {marcos} }},")
        linhas.append("\t\t\tpecas = {")
        for parte, chaves in c["pecas"].items():
            linhas.append(f"\t\t\t\t{parte} = {{")
            linha = []
            for ch in chaves:
                linha.append("{" + ", ".join(_n(v) for v in ch) + "}")
                if len(linha) == 3:
                    linhas.append("\t\t\t\t\t" + ", ".join(linha) + ",")
                    linha = []
            if linha:
                linhas.append("\t\t\t\t\t" + ", ".join(linha) + ",")
            linhas.append("\t\t\t\t},")
        linhas.append("\t\t\t},")
        linhas.append("\t\t},")
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DESTINO, modulo + ".luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas))


def escrever_catalogo():
    mods = sorted(os.path.splitext(f)[0] for f in os.listdir(DESTINO) if f.endswith(".luau") and f != "Catalogo.luau")
    linhas = [
        "-- Gerado por tools/blender/kits/criaturas_clipes.py (ANIM2). Índice dos clipes por criatura: Catalogo[modulo] = dados.",
        "local Shared = game:GetService(\"ReplicatedStorage\").Shared",
        "",
        "return {",
    ]
    for m in mods:
        linhas.append(f"\t{m} = require(Shared.Animacoes.Criaturas.{m}),")
    linhas += ["}", ""]
    with open(os.path.join(DESTINO, "Catalogo.luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas))


# ---------------------------------------------------------------- entrada
def gerar(bpy, modulo, malhas, partes_verts, pts_repouso, T, pivos_aut, desloc):
    """malhas/partes_verts/pts_repouso: do conversor (índices de vértice por parte); T: Blender -> autoral;
    pivos_aut: parte -> (x, y, z) autoral; desloc: (dx, dy, dz) do apoiar_no_chao."""
    if modulo not in CLIPES:
        return
    global repouso
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    verts = {p: sorted(v) for p, v in partes_verts.items() if p in pivos_aut}
    repouso = {p: np.array([pts_repouso[mi][vi] for mi, vi in idx]) for p, idx in verts.items()}
    pivos = {p: np.array(pivos_aut[p]) for p in verts}
    d0 = np.array(desloc)
    pivos_r = {p: M @ (pivos[p] - d0) for p in verts}
    todos = np.concatenate(list(repouso.values()))
    altura = float(todos[:, 2].max() - todos[:, 2].min())
    saida = {}
    for nome, (sufixo, laco) in CLIPES[modulo].items():
        acao = next((a for a in bpy.data.actions if a.name.split("|")[-1].split("_", 1)[-1] == sufixo), None)
        if acao is None:
            print(f"CLIPE {modulo}.{nome}: ação {sufixo} ausente, ignorado")
            continue
        tempos, dados, fps = amostrar_acao(bpy, arm, acao, malhas, verts, T, pivos, None)
        marco = {}
        if nome.startswith("Atacar"):
            marco["impacto"] = impacto({p: (None, d) for p, (q, d) in dados.items()}, tempos)
        if laco:
            tempos, dados, dur = fechar_laco(tempos, dados, altura, fps)
        else:
            dur = tempos[-1]
        saida[nome] = montar(nome, "pacote:" + acao.name.split("|")[-1], tempos, dados, dur, fps, laco, marco, altura)
    if "Atacar" not in saida:
        tempos, dados, dur, t_imp = mordida(pivos_r, altura)
        saida["Atacar"] = montar("Atacar", "sintetizado", tempos, dados, dur, 24, False, {"impacto": t_imp}, altura)
    if "LevarGolpe" not in saida:
        tempos, dados, dur = levar_golpe(pivos_r, altura)
        saida["LevarGolpe"] = montar("LevarGolpe", "sintetizado", tempos, dados, dur, 24, False, {}, altura)
    if "Morrer" not in saida:
        tempos, dados, dur = tombar(pivos_r, (M @ (todos - d0).T).T)
        saida["Morrer"] = montar("Morrer", "sintetizado", tempos, dados, dur, 24, False, {}, altura)
    escrever(modulo, saida, altura)
    escrever_catalogo()
    tot = sum(len(ch) for c in saida.values() for ch in c["pecas"].values())
    print(f"CLIPES {modulo}: {', '.join(f'{k}={v['duracao']:.2f}s' for k, v in saida.items())}; {tot} quadros; impacto {[round(v['marcos'].get('impacto', 0), 2) for v in saida.values() if 'impacto' in v['marcos']]}")


def montar(nome, origem, tempos, dados, dur, fps, laco, marcos, altura):
    obrig = [int(np.argmin([abs(t - m) for t in tempos])) for m in marcos.values()]
    pecas = {}
    for parte, (q, d) in dados.items():
        manter = reduzir(tempos, q, d, altura, obrig)
        pecas[parte] = [[tempos[i], *q[i], *d[i]] for i in manter]
    return {"origem": origem, "fps": fps, "duracao": dur, "laco": laco, "segurar": nome in SEGURAR,
            "marcos": {**marcos, **({"fim": dur} if not laco else {})}, "pecas": pecas}
