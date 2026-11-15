"""Corpo R15 PADRÃO do Roblox (blocado clássico) para a prévia da PERS1, com UV dos moldes clássicos de camisa/calça.

Medidas = boneco de blocos R15 de tools/blender/anim_rig.py (o mesmo do jogo hoje): cabeça 1,2 com centro em y=4,6,
UpperTorso 2 x 1,6 x 1, LowerTorso 2 x 0,4 x 1, braços 1 x (1,10 + 1,13 + 0,32), pernas 1 x (0,8 + 0,9 + 0,3).
Coordenadas AUTORAIS (Z para cima, frente em -Y, direita do personagem em -X); o Roblox recebe (x, y, z) -> (-x, z, y).

UV das roupas clássicas (Shirt/Pants, molde 585 x 559): cada face das peças do tronco, braços e pernas cai na região do
molde do R6 correspondente, dividida em faixas pela altura de cada peça R15 (UpperArm em cima, LowerArm no meio, Hand
embaixo). É uma aproximação de como o Roblox projeta o molde no R15 — serve para a prévia; o PNG gerado segue o molde.
"""
import math

import bmesh
from mathutils import Matrix, Vector

import anim_rig
import comum as C

W_MOLDE, H_MOLDE = 585, 559
# regiões do molde (x, y, largura, altura) em pixels, origem no canto superior esquerdo — a CONFERIR com o
# template oficial antes do primeiro envio (create.roblox.com/docs/art/accessories/classic-clothing).
TRONCO = {"U": (231, 8, 128, 64), "F": (231, 74, 128, 128), "R": (165, 74, 64, 128), "L": (361, 74, 64, 128),
          "B": (427, 74, 128, 128), "D": (231, 204, 128, 64)}
MEMBRO_D = {"R": (19, 355, 64, 128), "B": (85, 355, 64, 128), "L": (151, 355, 64, 128), "F": (217, 355, 64, 128),
            "U": (217, 289, 64, 64), "D": (217, 485, 64, 64)}
MEMBRO_E = {"F": (308, 355, 64, 128), "L": (374, 355, 64, 128), "B": (440, 355, 64, 128), "R": (506, 355, 64, 128),
            "U": (308, 289, 64, 64), "D": (308, 485, 64, 64)}


def _a(p):
    """Roblox -> autoral."""
    return Vector((-p[0], p[2], p[1]))


def rig():
    pivos = {j: _a(v[2]) for j, v in anim_rig.JUNTAS.items()}
    pecas = {n: (_a(c), Vector(t)) for n, (c, t) in anim_rig.PECAS.items()}  # tamanho em (x, y_roblox, z_roblox)
    return {"pivos": pivos, "pecas": pecas,
            "mao_centro": {"Right": pecas["RightHand"][0], "Left": pecas["LeftHand"][0]}}


def _caixa_chanfrada(c, t, chanfro=0.05):
    bm = bmesh.new()
    m = Matrix.Translation(c) @ Matrix.Diagonal((t.x, t.y, t.z, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    if chanfro > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=chanfro, segments=2, profile=0.5, affect="EDGES")
    return bm


# faixas (topo, base) em fração da altura da região, por peça
FAIXAS = {"UpperTorso": (0.0, 0.8), "LowerTorso": (0.8, 1.0),
          "UpperArm": (0.0, 1.10 / 2.55), "LowerArm": (1.10 / 2.55, 2.23 / 2.55), "Hand": (2.23 / 2.55, 1.0),
          "UpperLeg": (0.0, 0.4), "LowerLeg": (0.4, 0.85), "Foot": (0.85, 1.0)}


def _uv_molde(bm, parte, mn, mx):
    """UV de cada face na região do molde pela direção dominante da normal."""
    if parte in ("UpperTorso", "LowerTorso"):
        regs, chave = TRONCO, parte
    else:
        lado = "Right" if parte.startswith("Right") else "Left"
        regs = MEMBRO_D if lado == "Right" else MEMBRO_E
        chave = parte[len(lado):]
    f0, f1 = FAIXAS[chave]
    uv = bm.loops.layers.uv.verify()
    tam = mx - mn
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        if ax == 0:
            face = "R" if n.x < 0 else "L"
        elif ax == 1:
            face = "F" if n.y < 0 else "B"
        else:
            face = "U" if n.z > 0 else "D"
        x, y, w, h = regs[face]
        for l in f.loops:
            p = l.vert.co
            rx, ry, rz = ((p.x - mn.x) / tam.x, (p.y - mn.y) / tam.y, (p.z - mn.z) / tam.z)
            if face == "F":
                u, v = rx, 1 - rz
            elif face == "B":
                u, v = 1 - rx, 1 - rz
            elif face == "R":
                u, v = 1 - ry, 1 - rz
            elif face == "L":
                u, v = ry, 1 - rz
            elif face == "U":
                u, v = rx, ry
            else:
                u, v = rx, 1 - ry
            if face in ("F", "B", "R", "L"):
                v = f0 + (f1 - f0) * v
                px, py = x + u * w, y + v * h
            else:
                px, py = x + u * w, y + v * h
            l[uv].uv = (px / W_MOLDE, 1 - py / H_MOLDE)


def cabeca_se(c=(0, 0, 4.6), meia=0.6, expo=8.0):
    """Superfície da cabeça (superelipsoide quase cúbico, como a cabeça blocada): (az, el, k) -> ponto."""
    c = Vector(c)

    def S(az, el, k=1.0):
        a, e = math.radians(az), math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        t = 1.0 / (sum((abs(d[i]) / meia) ** expo for i in range(3)) ** (1.0 / expo))
        return c + d * t * k
    return S


def corpo(cores, rosto_tela=None):
    """Boneco R15 padrão: 15 caixas chanfradas (papel "corpo": pele + camisa/calça por textura) e cabeça com rosto."""
    r = rig()
    b = C.Boneco(r, cores, "r15")
    b.facetado = True
    for nome, (c, t) in r["pecas"].items():
        if nome in ("HumanoidRootPart", "Head"):
            continue
        tam = Vector((t.x, t.z, t.y))
        bm = _caixa_chanfrada(c, tam, 0.045 if "Hand" not in nome and "Foot" not in nome else 0.04)
        C.normais_fora(bm)
        _uv_molde(bm, nome, c - tam / 2, c + tam / 2)
        b.add(nome, "corpo", bm, suave=False)
    # cabeça: superelipsoide (cantos arredondados como a cabeça blocada) + pescoço escondido no tronco
    S = cabeca_se()
    bm = bmesh.new()
    C.elipsoide(bm, (0, 0, 4.6), (0.6, 0.6, 0.6), seg=24, aneis=14, deform=lambda p: S(*_azel(p), 1.0))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    C.normais_fora(bm)
    _uv_rosto(bm)
    b.add("Head", "rosto", bm, suave=True)
    pesc = bmesh.new()
    C.sweep(pesc, [(Vector((0, 0, 3.85)), 0.32, 0.3), (Vector((0, 0, 4.2)), 0.32, 0.3)], up=(0, -1, 0), lados=12, expo=3)
    b.add("Head", "pele", pesc, suave=True)
    b.uv_rosto = (-0.6, 0.6, 4.0, 5.2)
    return b


def _uv_rosto(bm, x0=-0.6, x1=0.6, z0=4.0, z1=5.2):
    """Projeção frontal só nas faces voltadas para a frente; as demais apontam para um texel transparente (pele)."""
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        frente = f.normal.y < -0.25
        for l in f.loops:
            co = l.vert.co
            l[uv].uv = ((co.x - x0) / (x1 - x0), (co.z - z0) / (z1 - z0)) if frente else (0.002, 0.002)


def _azel(p):
    d = Vector(p) - Vector((0, 0, 4.6))
    if d.length < 1e-9:
        return 0.0, 0.0
    d.normalize()
    el = math.degrees(math.asin(max(-1, min(1, d.z))))
    az = math.degrees(math.atan2(d.x, -d.y))
    return az, el


def tela_rosto(cor_olho=(92, 55, 32), cor_sobrancelha=(60, 40, 30), estilo="neutro"):
    """Rosto pintado (Decal/SurfaceAppearance da cabeça): olhos, sobrancelhas, boca nas alturas do catálogo atual."""
    t = C.Tela(-0.6, 0.6, 4.0, 5.2, n=512)
    for lado in (-1, 1):
        C.olho_amendoado(t, lado * 0.25, 4.72, 0.24, 0.17, cor_olho, lado, delineado=0.032, inclinacao=4)
        ang = -10 if estilo == "bravo" else -3
        C.sobrancelha(t, lado * 0.25, 4.93, 0.26, 0.05, cor_sobrancelha, lado, arco=0.02, angulo=ang)
    C.boca(t, 0.0, 4.36, 0.2, 0.025 if estilo != "bravo" else -0.01, grossura=0.03)
    # sombra suave do nariz
    t.pintar(t.traco([(0.0, 4.55), (0.03, 4.47)], [0.02, 0.03]), (150, 90, 70), 0.35)
    return t
