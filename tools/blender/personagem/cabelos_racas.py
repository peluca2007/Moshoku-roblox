"""Cabelos PRÓPRIOS recoloríveis (uma cor por MeshPart: o jogo pinta com MeshPart.Color) e traços de raça, para a cabeça
blocada do R15 padrão (superelipsoide de meia-aresta 0,6 com centro em z=4,6). Todas as peças são do Head.

Cabelo = calota (casca com espessura, linha do cabelo por (azimute, elevação)) + mechas varridas sobre a superfície.
Azimute 0 = frente (-Y), +90 = esquerda do personagem (+X); elevação +90 = topo.
"""
import math

import bmesh
from mathutils import Matrix, Vector

import comum as C
import roblox_r15 as R

S = R.cabeca_se()
CENTRO = Vector((0, 0, 4.6))


def _interp(tab, x):
    x = abs(x)
    for (x0, y0), (x1, y1) in zip(tab[:-1], tab[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return tab[-1][1]


def calota(linha, k=1.07, esp=0.07):
    """Casca do cabelo: mantém as faces acima da linha do cabelo el_min(az) (tabela [(az, el)])."""
    bm = bmesh.new()
    C.elipsoide(bm, CENTRO, (1, 1, 1), seg=24, aneis=14, filtro=lambda az, el: el > _interp(linha, az),
                deform=lambda p: S(*R._azel(p), k))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return C.solidificar(bm, esp)


def mecha(bm, pontos, larg, esp, lados=5, expo=2.2):
    """Mecha sobre a cabeça: pontos (az, el, k) ou Vector; larg/esp por ponto (a ponta pode ser 0)."""
    pts = [S(*p) if isinstance(p, tuple) else Vector(p) for p in pontos]
    sec = [(p, w, h) for p, w, h in zip(pts, larg, esp)]
    radial = [(p - CENTRO).normalized() for p in pts]
    C.sweep(bm, sec, up=lambda i: radial[i], lados=lados, expo=expo)


def franja(bm, azs, el0=74, el1=26, desvio=-14, k0=1.07, k1=1.14, w=0.15):
    for a in azs:
        mecha(bm, [(a + desvio * 0.2, el0, k0), (a + desvio * 0.6, (el0 + el1) / 2 + 4, k1), (a + desvio, el1, k1 - 0.02),
                   (a + desvio * 1.2, el1 - 10, k1 - 0.05)],
              [w * 0.9, w, w * 0.7, 0.0], [0.05, 0.07, 0.05, 0.0])


def cabelo_curto(b, papel="cabelo"):
    bm = calota([(0, 40), (35, 34), (60, 4), (100, -8), (130, -30), (180, -36)])
    m = bmesh.new()
    franja(m, (-40, -22, -4, 14, 32), desvio=-16)
    for s in (-1, 1):  # costeletas e laterais
        mecha(m, [(s * 72, 40, 1.08), (s * 78, 10, 1.1), (s * 80, -14, 1.07), (s * 82, -24, 1.03)],
              [0.16, 0.16, 0.1, 0.0], [0.05, 0.06, 0.04, 0.0])
        for a in (110, 140):
            mecha(m, [(s * a, 60, 1.07), (s * (a + 6), 20, 1.12), (s * (a + 8), -18, 1.1), (s * (a + 8), -32, 1.05)],
                  [0.18, 0.2, 0.14, 0.0], [0.05, 0.07, 0.05, 0.0])
    for a in (-30, 0, 30, 180):  # volume no topo varrido para a frente
        mecha(m, [(a + 180, 50, 1.07), (a * 0.5 + 180, 82, 1.14), (a, 70, 1.15), (a - 8, 52, 1.12)],
              [0.18, 0.22, 0.2, 0.0], [0.05, 0.08, 0.07, 0.0])
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_curto", suave=True)


def cabelo_longo(b, papel="cabelo"):
    bm = calota([(0, 46), (30, 40), (55, -10), (100, -40), (140, -55), (180, -60)])
    m = bmesh.new()
    # risca no meio: mechas que descem dos dois lados emoldurando o rosto
    for s in (-1, 1):
        for i, a in enumerate((8, 22)):
            mecha(m, [(s * a, 78, 1.07), (s * (a + 22), 50, 1.13), (s * (a + 46), 10, 1.14), (s * (a + 52), -30, 1.12),
                      S(s * (a + 54), -48, 1.1) + Vector((0, 0.05, -0.55)), S(s * (a + 54), -48, 1.1) + Vector((0, 0.1, -0.85))],
                  [0.15, 0.17, 0.17, 0.16, 0.12, 0.0], [0.05, 0.07, 0.07, 0.07, 0.05, 0.0])
    # cortina de trás até o meio das costas
    for a in (100, 125, 150, 180, 210, 235, 260):
        a = a if a <= 180 else a - 360
        base = S(a, -55, 1.1)
        mecha(m, [(a * 0.6, 84, 1.06), (a, 45, 1.13), (a, 0, 1.15), (a, -40, 1.14), base + Vector((0, 0.08, -0.5)),
                  base + Vector((0, 0.12, -1.0)), base + Vector((0, 0.1, -1.25))],
              [0.17, 0.2, 0.22, 0.21, 0.19, 0.14, 0.0], [0.05, 0.07, 0.08, 0.08, 0.07, 0.05, 0.0])
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_longo", suave=True)


def cabelo_rabo(b, papel="cabelo"):
    bm = calota([(0, 48), (40, 30), (70, -8), (110, -24), (150, -40), (180, -44)], k=1.06, esp=0.06)
    m = bmesh.new()
    for a in (-30, -10, 10, 30):  # penteado para trás
        mecha(m, [(a * 0.6, 50, 1.07), (a * 0.8, 75, 1.11), (180 - a * 1.5, 70, 1.1), (180 - a * 2, 35, 1.07)],
              [0.14, 0.17, 0.14, 0.0], [0.04, 0.06, 0.05, 0.0])
    base = S(180, 22, 1.05)
    C.aro(m, base + Vector((0, 0.08, 0)), 0.16, 0.16, 0.06, 0.05, n=16, expo_caminho=2, expo=3, lados=6)
    rabo = [(base + Vector((0, 0.02, 0)), 0.16, 0.16), (base + Vector((0, 0.24, -0.04)), 0.19, 0.18),
            (base + Vector((0, 0.42, -0.42)), 0.17, 0.16), (base + Vector((0, 0.38, -0.95)), 0.12, 0.11),
            (base + Vector((0, 0.3, -1.3)), 0.0, 0.0)]
    C.sweep(m, rabo, up=(0, -1, 0), lados=10, expo=2.0)
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_rabo", suave=True)


def cabelo_espetado(b, papel="cabelo"):
    bm = calota([(0, 44), (40, 36), (60, 0), (110, -10), (150, -32), (180, -36)])
    m = bmesh.new()
    for az, el, comp in ((0, 62, 0.42), (-30, 58, 0.38), (30, 58, 0.38), (-60, 52, 0.34), (60, 52, 0.34), (-15, 80, 0.45),
                         (15, 80, 0.45), (180, 70, 0.42), (140, 62, 0.4), (-140, 62, 0.4), (100, 55, 0.36), (-100, 55, 0.36),
                         (180, 35, 0.34)):
        p0 = S(az, el, 1.04)
        n = (p0 - CENTRO).normalized()
        dirv = (n + Vector((0, 0.45, 0.5))).normalized()
        sec = [(p0, 0.17, 0.12), (p0 + dirv * comp * 0.5, 0.11, 0.08), (p0 + dirv * comp, 0.0, 0.0)]
        C.sweep(m, sec, up=lambda i: n, lados=5, expo=2.0)
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_espetado", suave=True)


def cabelo_avatar_exemplo(b, papel="cabelo_avatar"):
    """Exemplo do que vem do avatar do jogador: cabelo de catálogo bagunçado, com TEXTURA própria de fios (na prévia, o
    veio procedural faz o papel do TextureID) — não é recolorível por MeshPart.Color sem perder a textura."""
    bm = calota([(0, 40), (40, 30), (70, -4), (120, -26), (180, -40)], k=1.07)
    m = bmesh.new()
    import random
    rng = random.Random(4)
    for a in (-48, -30, -12, 6, 24, 42):
        d = rng.uniform(-10, 10)
        mecha(m, [(a, 80, 1.07), (a + d, 52, 1.16), (a + d * 1.6, 30, 1.15), (a + d * 2, 18, 1.1)],
              [0.15, 0.19, 0.13, 0.0], [0.05, 0.09, 0.06, 0.0])
    for s in (-1, 1):
        for a in (70, 95, 120, 145, 170):
            d = rng.uniform(-8, 8)
            mecha(m, [(s * a, 70, 1.07), (s * (a + d), 30, 1.16), (s * (a + d), -10, 1.15), (s * (a + d * 1.5), -34, 1.08)],
                  [0.17, 0.21, 0.16, 0.0], [0.05, 0.09, 0.07, 0.0])
    for a in (-150, -90, -30, 30, 90, 150):  # topo bagunçado
        mecha(m, [(a, 62, 1.08), (a + 40, 84, 1.17), (a + 100, 70, 1.15)], [0.18, 0.2, 0.0], [0.06, 0.09, 0.0])
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_avatar", suave=True)


CABELOS = {"curto": cabelo_curto, "longo": cabelo_longo, "rabo": cabelo_rabo, "espetado": cabelo_espetado,
           "avatar": cabelo_avatar_exemplo}


def cabelo_masculino(b, papel="cabelo"):
    """Curto masculino: laterais baixas, topo com volume e franja curta para o lado."""
    bm = calota([(0, 36), (35, 28), (60, -2), (100, -14), (130, -34), (180, -40)], k=1.06, esp=0.07)
    m = bmesh.new()
    franja(m, (-36, -18, 0, 18, 36), el0=78, el1=40, desvio=-10, w=0.17)
    for s in (-1, 1):
        mecha(m, [(s * 76, 36, 1.07), (s * 80, 6, 1.08), (s * 84, -16, 1.04)], [0.16, 0.13, 0.0], [0.05, 0.05, 0.0])
    for a in (-40, -10, 20, 50, 180):
        mecha(m, [(a + 160, 56, 1.07), (a * 0.5 + 160, 84, 1.15), (a, 76, 1.16), (a - 10, 58, 1.1)],
              [0.2, 0.24, 0.2, 0.0], [0.06, 0.09, 0.07, 0.0])
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_masculino", suave=True)


def cabelo_bob(b, papel="cabelo"):
    """Médio (na altura do queixo), franja reta."""
    bm = calota([(0, 50), (30, 40), (60, -6), (100, -26), (150, -34), (180, -36)])
    m = bmesh.new()
    franja(m, (-42, -24, -6, 12, 30, 46), el0=80, el1=34, desvio=0, w=0.16)
    for a in (70, 95, 120, 145, 170, 200, 225, 250, 275, 290):
        a = a if a <= 180 else a - 360
        for s in ((1,) if abs(a) == a else (1,)):
            pass
        mecha(m, [(a * 0.6, 80, 1.07), (a, 40, 1.13), (a, -5, 1.15), (a, -34, 1.12), S(a, -48, 1.04) + Vector((0, 0.04, -0.25))],
              [0.2, 0.22, 0.22, 0.2, 0.0], [0.06, 0.08, 0.08, 0.07, 0.0])
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_bob", suave=True)


def cabelo_trancas(b, papel="cabelo"):
    """Duas tranças caindo pelos ombros, repartido ao meio."""
    bm = calota([(0, 46), (30, 38), (60, 0), (100, -20), (140, -30), (180, -34)], k=1.06)
    m = bmesh.new()
    franja(m, (-34, -18, 18, 34), el0=78, el1=44, desvio=-18, w=0.15)
    for s in (-1, 1):
        mecha(m, [(s * 70, 40, 1.07), (s * 80, 6, 1.1), (s * 86, -22, 1.08)], [0.17, 0.15, 0.0], [0.05, 0.06, 0.0])
        x, y = s * 0.72, -0.12
        for i in range(6):  # gomos da trança: elipsoides alternados
            z = 4.1 - i * 0.3
            for d in (-1, 1):
                bmesh.ops.create_icosphere(m, subdivisions=1, radius=0.17 - i * 0.012,
                                           matrix=Matrix.Translation((x + d * 0.045, y, z)) @ Matrix.Diagonal((0.9, 0.9, 1.25, 1)))
        C.sweep(m, [(Vector((x, y, 4.45)), 0.14, 0.12), (Vector((x, y, 4.2)), 0.16, 0.14)], up=(0, -1, 0), lados=6)
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_trancas", suave=True)


def cabelo_coque(b, papel="cabelo"):
    """Preso: penteado para trás e coque no alto."""
    bm = calota([(0, 50), (40, 34), (70, -6), (110, -22), (150, -36), (180, -40)], k=1.06, esp=0.06)
    m = bmesh.new()
    for a in (-34, -12, 12, 34):
        mecha(m, [(a * 0.6, 50, 1.07), (a * 0.8, 76, 1.1), (180 - a, 80, 1.1)], [0.14, 0.16, 0.0], [0.04, 0.06, 0.0])
    topo = S(180, 66, 1.05) + Vector((0, 0.02, 0.1))
    bmesh.ops.create_icosphere(m, subdivisions=2, radius=0.3, matrix=Matrix.Translation(topo + Vector((0, 0.12, 0.22))) @ Matrix.Diagonal((1, 1, 0.85, 1)))
    C.aro(m, topo + Vector((0, 0.08, 0.05)), 0.26, 0.26, 0.05, 0.05, n=14, expo_caminho=2, expo=3, lados=6)
    C.juntar(bm, m)
    m.free()
    b.add("Head", papel, bm, "cabelo_coque", suave=True)


CABELOS.update({"masculino": cabelo_masculino, "bob": cabelo_bob, "trancas": cabelo_trancas, "coque": cabelo_coque})


# ====================================================================================== traços de raça
def orelhas_elfo(b):
    bm = bmesh.new()
    for s in (-1, 1):
        base = Vector((s * 0.6, 0.06, 4.6))
        pts = [base + Vector((-s * 0.04, 0, -0.04)), base + Vector((s * 0.1, 0.04, 0.06)), base + Vector((s * 0.3, 0.12, 0.24)),
               base + Vector((s * 0.5, 0.2, 0.44))]
        C.sweep(bm, [(pts[0], 0.13, 0.05), (pts[1], 0.15, 0.05), (pts[2], 0.09, 0.035), (pts[3], 0.0, 0.0)],
                up=(s, 0.2, 0), lados=8, expo=2.0)
    b.add("Head", "pele", bm, "orelhas_elfo", suave=True)


def orelhas_fera(b, papel="cabelo"):
    """Orelhas felinas (raça-fera) nos cantos de cima da cabeça, por cima do cabelo."""
    bm, dentro = bmesh.new(), bmesh.new()
    for s in (-1, 1):
        base = Vector((s * 0.4, 0.08, 5.12))
        topo = base + Vector((s * 0.2, 0.04, 0.66))
        C.sweep(bm, [(base + Vector((0, 0, -0.08)), 0.27, 0.1), (base, 0.27, 0.1), (base + (topo - base) * 0.5, 0.17, 0.08),
                     (topo, 0.0, 0.0)], up=(0, -1, 0), lados=6, expo=2.0)
        b0 = base + Vector((0, -0.09, 0.07))
        C.sweep(dentro, [(b0, 0.17, 0.03), (b0 + (topo - base) * 0.45, 0.1, 0.025), (b0 + (topo - base) * 0.8, 0.0, 0.0)],
                up=(0, -1, 0), lados=6, expo=2.0)
    b.add("Head", papel, bm, "orelhas_fera", suave=False)
    b.add("Head", "pele_interna", dentro, "orelhas_fera", suave=False)


def barba_ana(b, papel="barba"):
    bm = bmesh.new()
    # massa: das bochechas até o peito, cobrindo o queixo (a boca fica sob o bigode)
    sec = [(Vector((0, -0.6, 4.42)), 0.5, 0.06), (Vector((0, -0.66, 4.28)), 0.6, 0.12), (Vector((0, -0.72, 4.02)), 0.6, 0.16),
           (Vector((0, -0.74, 3.74)), 0.5, 0.15), (Vector((0, -0.72, 3.5)), 0.3, 0.12), (Vector((0, -0.7, 3.38)), 0.0, 0.0)]
    C.sweep(bm, sec, up=(0, -1, 0), lados=12, expo=2.6)
    for s in (-1, 1):  # costeletas ligando à orelha
        mecha(bm, [(s * 88, 6, 1.02), (s * 78, -22, 1.08), (s * 58, -42, 1.1), (s * 40, -50, 1.1)],
              [0.14, 0.16, 0.18, 0.16], [0.05, 0.07, 0.08, 0.06])
        # bigode
        C.sweep(bm, [(Vector((s * 0.03, -0.66, 4.47)), 0.07, 0.05), (Vector((s * 0.22, -0.69, 4.42)), 0.09, 0.06),
                     (Vector((s * 0.38, -0.68, 4.3)), 0.06, 0.05), (Vector((s * 0.44, -0.66, 4.16)), 0.0, 0.0)],
                up=(0, -1, 0), lados=8)
    # duas tranças com contas
    for s in (-1, 1):
        x = s * 0.17
        for i in range(4):
            z = 3.48 - i * 0.17
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.1 - i * 0.01,
                                       matrix=Matrix.Translation((x, -0.7, z)) @ Matrix.Diagonal((1, 0.8, 1.15, 1)))
    b.add("Head", papel, bm, "barba_ana", suave=True)
    contas = bmesh.new()
    for s in (-1, 1):
        C.aro(contas, (s * 0.17, -0.7, 3.4), 0.085, 0.07, 0.025, 0.035, n=12, expo_caminho=2, expo=3, lados=5)
    b.add("Head", "metal", contas, "barba_ana", suave=True)


def barba_curta(b, papel="barba"):
    """Barba rente: contorno do queixo, costeletas e bigode."""
    bm = bmesh.new()
    for s in (-1, 1):
        mecha(bm, [(s * 86, 4, 1.02), (s * 80, -20, 1.07), (s * 58, -40, 1.09), (s * 30, -50, 1.09), (s * 6, -52, 1.08)],
              [0.12, 0.15, 0.17, 0.17, 0.12], [0.04, 0.05, 0.06, 0.06, 0.05])
        C.sweep(bm, [(Vector((s * 0.03, -0.66, 4.45)), 0.08, 0.05), (Vector((s * 0.2, -0.68, 4.41)), 0.09, 0.05),
                     (Vector((s * 0.36, -0.67, 4.32)), 0.0, 0.0)], up=(0, -1, 0), lados=6)
    C.sweep(bm, [(Vector((0, -0.6, 4.2)), 0.4, 0.05), (Vector((0, -0.66, 4.05)), 0.42, 0.07), (Vector((0, -0.64, 3.95)), 0.0, 0.0)],
            up=(0, -1, 0), lados=10, expo=2.4)
    b.add("Head", papel, bm, "barba_curta", suave=True)


def barba_cavanhaque(b, papel="barba"):
    """Cavanhaque com bigode fino."""
    bm = bmesh.new()
    C.sweep(bm, [(Vector((0, -0.62, 4.24)), 0.2, 0.05), (Vector((0, -0.67, 4.08)), 0.22, 0.08), (Vector((0, -0.66, 3.86)), 0.15, 0.08),
                 (Vector((0, -0.62, 3.7)), 0.0, 0.0)], up=(0, -1, 0), lados=10, expo=2.4)
    for s in (-1, 1):
        C.sweep(bm, [(Vector((s * 0.03, -0.66, 4.46)), 0.07, 0.045), (Vector((s * 0.2, -0.68, 4.43)), 0.08, 0.05),
                     (Vector((s * 0.38, -0.66, 4.34)), 0.0, 0.0)], up=(0, -1, 0), lados=6)
    b.add("Head", papel, bm, "barba_cavanhaque", suave=True)


BARBAS = {"curta": barba_curta, "cavanhaque": barba_cavanhaque, "longa": barba_ana}


RACAS = {"elfo": orelhas_elfo, "ana": barba_ana, "fera": orelhas_fera}
