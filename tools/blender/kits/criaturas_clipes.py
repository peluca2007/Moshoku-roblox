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
    # MOD6: golem (Golem Knight: walk, attack_light, heavy_hit; sem idle nem morte) e treant (Forest Monster: Idle, Walk, Attack, Dying)
    "UrsoQuaternius": {},  # sem esqueleto: Respirar, Andar, Atacar, LevarGolpe e Morrer sintetizados
    "GolemQuaternius": {"Atacar": ("light", False), "Atacar2": ("hit", False)},
    "TreantQuaternius": {"Respirar": ("Idle", LAÇO), "Andar": ("Walk", LAÇO), "Atacar": ("Attack1", False), "Atacar2": ("Attack2", False)},
}
# Clipes que terminam no último quadro (não voltam ao repouso).
SEGURAR = {"Morrer"}
# MOD7: instante do impacto (s) quando o detector de pico falha (treant: movimento por mãos/galhos): (módulo, clipe) -> tempo.
IMPACTO_FIXO = {("TreantQuaternius", "Atacar"): 0.9, ("TreantQuaternius", "Atacar2"): 1.0}
# MOD6: clipes do pacote curtos demais para a luta (golem: 6 quadros) são esticados no tempo: (módulo, clipe) -> fator.
LENTO = {("GolemQuaternius", "Atacar"): 2.6, ("GolemQuaternius", "Atacar2"): 1.6}
# MOD6: humanoides com morte em 3 fases (joelhos, tombo girando, assentamento) em vez do tombo rígido.
ANDAR_SINTETICO = {"UrsoQuaternius", "GolemQuaternius"}
MORTE_HUMANOIDE = {"GoblinQuaternius", "BandidoEspadaQuaternius", "BandidoPorreteQuaternius"}
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


def respirar(pivos_r, altura):
    """Espera sintetizada (pacote sem Idle): o corpo sobe e desce de leve em laço de 3 s, a cabeça acompanha atrasada."""
    dur, fps = 3.0, 24
    tempos = [i / fps for i in range(int(round(dur * fps)) + 1)]

    def fn(t):
        return rot("x", 0.012 * math.sin(2 * math.pi * t / dur)), np.array([0.0, 0.012 * altura * math.sin(2 * math.pi * t / dur), 0.0])

    def extra(parte, t):
        return rot("x", -0.02 * math.sin(2 * math.pi * (t / dur - 0.15))) if parte == "Cabeca" else np.eye(3)

    return tempos, sintetizar(pivos_r, tempos, fn, extra), dur


def _chave_hierarquia(pivos_r, tempos, fn_mundo, fn_local, pais):
    """Animação de peças encadeadas (coxa -> canela): `fn_local(parte, t)` devolve a rotação local da peça em volta do próprio
    pivô; a peça com pai herda a transformação do pai: p' = Rpai (Rs (p - k) + k - h) + h. `fn_mundo(t)` = (R, tv) do corpo todo."""
    dados = {p: ([], []) for p in pivos_r}
    for t in tempos:
        Rw, tw = fn_mundo(t)
        for parte, pv in pivos_r.items():
            Rs = fn_local(parte, t)
            pai = pais.get(parte)
            if pai:
                h = pivos_r[pai]
                Ru = fn_local(pai, t)
                Rl = Ru @ Rs
                bl = Ru @ (pv - Rs @ pv - h) + h
            else:
                Rl = Rs
                bl = pv - Rs @ pv
            Rt = Rw @ Rl
            b = Rw @ bl + tw
            dados[parte][0].append(quat_de(Rt))
            dados[parte][1].append(Rt @ pv + b - pv)
    return {p: (alinhar(q), np.array(d)) for p, (q, d) in dados.items()}


def andar_quadrupede(pivos_r, altura):
    """Passo de quadrúpede (urso): pernas em 2 segmentos (coxa `BracoD`/`PernaE`..., canela `...Baixo`), diagonais em oposição
    (BracoE+PernaD / BracoD+PernaE), joelho dobra na fase de balanço, peso no ombro (corpo mergulha no apoio das patas da
    frente e a cabeça acompanha). Laço de 1,2 s."""
    dur, fps = 1.2, 24
    tempos = [i / fps for i in range(int(round(dur * fps)) + 1)]
    pais = {p: p[:-5] for p in pivos_r if p.endswith("Baixo") and p[:-5] in pivos_r}

    def fase(parte):
        base = parte[:-5] if parte.endswith("Baixo") else parte
        return {"BracoE": 0.0, "PernaD": 0.0, "BracoD": math.pi, "PernaE": math.pi}.get(base)

    def mundo(t):
        w = 2 * math.pi * t / dur
        return rot("x", -0.035 * math.cos(2 * w)) @ rot("z", 0.03 * math.sin(w)), np.array([0.0, -0.03 * altura * abs(math.sin(w)) + 0.012 * altura, 0.0])

    def local(parte, t):
        w = 2 * math.pi * t / dur
        f = fase(parte)
        if f is None:
            return rot("x", 0.06 * math.sin(2 * w - 0.8)) if parte == "Cabeca" else np.eye(3)
        if parte.endswith("Baixo"):
            return rot("x", -0.85 * max(0.0, math.cos(w + f + 0.3)))  # dobra o joelho ao levar a pata para a frente
        return rot("x", 0.5 * math.sin(w + f))

    return tempos, _chave_hierarquia(pivos_r, tempos, mundo, local, pais), dur


def andar_pesado(pivos_r, altura):
    """Passo pesado do golem (bípede de pedra): ciclo lento de 1,5 s, tronco balançando para o lado do apoio, braços em oposição
    às pernas e impacto no chão (o corpo afunda no instante em que o pé pousa e a cabeça solavanca)."""
    dur, fps = 1.5, 24
    tempos = [i / fps for i in range(int(round(dur * fps)) + 1)]

    def mundo(t):
        w = 2 * math.pi * t / dur
        impacto = abs(math.sin(w)) ** 0.5  # 0 quando um pé pousa, 1 no meio do passo
        return rot("z", 0.06 * math.sin(w)) @ rot("x", 0.02 * math.cos(2 * w)), np.array([0.0, 0.04 * altura * (impacto - 1), 0.0])

    def local(parte, t):
        w = 2 * math.pi * t / dur
        if parte == "PernaD": return rot("x", 0.36 * math.sin(w))
        if parte == "PernaE": return rot("x", -0.36 * math.sin(w))
        if parte == "BracoD": return rot("x", -0.2 * math.sin(w)) @ rot("z", -0.04)
        if parte == "BracoE": return rot("x", 0.2 * math.sin(w)) @ rot("z", 0.04)
        if parte == "Cabeca": return rot("x", -0.07 * math.cos(2 * w)) @ rot("y", -0.05 * math.sin(w))
        return np.eye(3)

    return tempos, _chave_hierarquia(pivos_r, tempos, mundo, local, {}), dur


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


def morte_humanoide(pivos_r, pts_partes):
    """MOD6/MOD7: morte com peso em 3 fases, 1,75 s (o Defeat do pacote volta de pé). 1) os joelhos cedem (corpo desce, pernas dobram para
    a frente, cabeça cai), 2) o tronco tomba para trás girando em torno do eixo, com o braço da arma jogado para fora,
    3) assenta no chão com um quique amortecido. Cada peça gira em volta do próprio pivô; o chão é respeitado por peça."""
    dur, fps = 1.75, 24
    tempos = [i / fps for i in range(int(round(dur * fps)) + 1)]
    todos = np.concatenate(list(pts_partes.values()))
    altura = float(todos[:, 1].max() - todos[:, 1].min())

    def fases(t):
        cede = suave(t / 0.42)                                   # 0..1: joelhos
        tomba = suave((t - 0.30) / 0.82) ** 1.6 if t > 0.30 else 0.0   # 0..1: queda (acelera)
        q = max(t - 1.10, 0.0)
        quique = 0.07 * math.exp(-q * 7) * math.sin(q * 20) if q > 0 else 0.0
        return cede, tomba, quique

    def mundo(t):
        cede, tomba, quique = fases(t)
        R = rot("z", 0.35 * tomba) @ rot("y", 0.55 * tomba) @ rot("x", (1.50 + quique) * tomba)
        return R, np.array([0.0, -0.2 * altura * cede, 0.0])

    def local(parte, t):
        cede, tomba, quique = fases(t)
        if parte.startswith("Perna"):
            return rot("x", 0.55 * cede * (1 - 0.5 * tomba)) @ rot("z", (0.14 if parte == "PernaD" else -0.14) * tomba)
        if parte == "Cabeca":
            return rot("x", -0.35 * cede + 0.55 * tomba) @ rot("z", 0.25 * tomba)
        if parte.startswith("Braco"):
            lado = 1 if parte == "BracoD" else -1
            return rot("z", lado * 1.0 * tomba) @ rot("x", -0.5 * cede + 0.4 * tomba)
        return rot("x", -0.18 * cede)  # Corpo: o tronco se curva para a frente ao ceder

    dados = {p: ([], []) for p in pivos_r}
    for t in tempos:
        R, tv = mundo(t)
        # transformação por peça: p' = R (L (p - pv) + pv) + tv
        xs = {}
        for parte, pv in pivos_r.items():
            L = local(parte, t)
            xs[parte] = (R @ L, R @ (pv - L @ pv) + tv)  # p' = Rt p + b
        subida = max(0.0, -min(float(((pts_partes[p] @ Rt.T) + b)[:, 1].min()) for p, (Rt, b) in xs.items()))
        for parte, pv in pivos_r.items():
            Rt, b = xs[parte]
            dados[parte][0].append(quat_de(Rt))
            dados[parte][1].append(Rt @ pv + b + np.array([0.0, subida, 0.0]) - pv)
    return tempos, {p: (alinhar(q), np.array(d)) for p, (q, d) in dados.items()}, dur


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
    arm = max((o for o in bpy.data.objects if o.type == "ARMATURE"), key=lambda o: len(o.data.bones), default=None)
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
        fator = LENTO.get((modulo, nome), 1.0)
        if fator != 1.0:
            tempos, fps = [t * fator for t in tempos], fps / fator
        marco = {}
        if nome.startswith("Atacar"):
            marco["impacto"] = IMPACTO_FIXO.get((modulo, nome)) or impacto({p: (None, d) for p, (q, d) in dados.items()}, tempos)
        if laco:
            tempos, dados, dur = fechar_laco(tempos, dados, altura, fps)
        else:
            dur = tempos[-1]
        saida[nome] = montar(nome, "pacote:" + acao.name.split("|")[-1], tempos, dados, dur, fps, laco, marco, altura)
    if "Respirar" not in saida and "Voar" not in saida:
        tempos, dados, dur = respirar(pivos_r, altura)
        saida["Respirar"] = montar("Respirar", "sintetizado", tempos, dados, dur, 24, True, {}, altura)
    if "Andar" not in saida and modulo in ANDAR_SINTETICO:
        tempos, dados, dur = (andar_pesado if modulo == "GolemQuaternius" else andar_quadrupede)(pivos_r, altura)
        saida["Andar"] = montar("Andar", "sintetizado", tempos, dados, dur, 24, True, {}, altura)
    if "Atacar" not in saida:
        tempos, dados, dur, t_imp = mordida(pivos_r, altura)
        saida["Atacar"] = montar("Atacar", "sintetizado", tempos, dados, dur, 24, False, {"impacto": t_imp}, altura)
    if "LevarGolpe" not in saida:
        tempos, dados, dur = levar_golpe(pivos_r, altura)
        saida["LevarGolpe"] = montar("LevarGolpe", "sintetizado", tempos, dados, dur, 24, False, {}, altura)
    if "Morrer" not in saida and modulo in MORTE_HUMANOIDE:
        pts_r = {p: (M @ (v - d0).T).T for p, v in repouso.items()}
        tempos, dados, dur = morte_humanoide(pivos_r, pts_r)
        saida["Morrer"] = montar("Morrer", "sintetizado:humanoide", tempos, dados, dur, 24, False, {}, altura)
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
