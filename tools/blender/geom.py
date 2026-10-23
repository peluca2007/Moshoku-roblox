"""Primitivas geométricas compartilhadas por vila.py e trajes.py (roda dentro do Blender).

Todas as formas são FECHADAS (o `recalc_face_normals` do `Modelo.finalizar` orienta as faces
para fora). Convenção dos modelos autorais: Z para cima, frente em -Y (como predios.py); o
Roblox recebe (x, y, z) -> (-x, z, y) sem `espelhar_y`, e com `espelhar_y` a frente vai a +Z.
"""
import math

import bmesh
from mathutils import Matrix, Vector

from formas import extruir, tronco  # noqa: F401  (tronco é reexportado)
from lib import Modelo  # noqa: F401

TAU = math.tau


def caixa(bm, centro, tam, rot=(0.0, 0.0, 0.0)):
    """Caixa com rotação (rx, ry, rz) em radianos, aplicada nessa ordem em torno do próprio centro."""
    m = (Matrix.Translation(Vector(centro)) @ Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y")
         @ Matrix.Rotation(rot[0], 4, "X") @ Matrix.Diagonal(Vector((*tam, 1.0))))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def torno(bm, perfil, lados=12, giro=0.0, centro=(0.0, 0.0, 0.0)):
    """Sólido de revolução em torno do eixo Z. `perfil` é um polígono FECHADO de pontos (raio, z)
    (o último liga ao primeiro); pontos com raio 0 ficam no eixo. Serve para bacias, colunas, potes."""
    angs = [giro + k * TAU / lados for k in range(lados)]
    cx, cy, cz = centro
    aneis = []
    for r, z in perfil:
        if r < 1e-6:
            v = bm.verts.new((cx, cy, cz + z))
            aneis.append([v] * lados)
        else:
            aneis.append([bm.verts.new((cx + r * math.cos(a), cy + r * math.sin(a), cz + z)) for a in angs])
    n = len(perfil)
    for i in range(n):
        j = (i + 1) % n
        for k in range(lados):
            k2 = (k + 1) % lados
            quad = [aneis[i][k], aneis[i][k2], aneis[j][k2], aneis[j][k]]
            unicos = []
            for v in quad:
                if v not in unicos:
                    unicos.append(v)
            if len(unicos) >= 3:
                try:
                    bm.faces.new(unicos)
                except ValueError:
                    pass


def prisma(bm, pontos, eixo, a0, a1):
    """Prisma de base CONVEXA. `pontos` são (u, v) no plano perpendicular a `eixo` e o prisma vai de
    a0 a a1 ao longo dele: eixo Z -> (x, y); eixo Y -> (x, z); eixo X -> (y, z)."""
    def p3(u, v, t):
        if eixo == "Z":
            return Vector((u, v, t))
        if eixo == "Y":
            return Vector((u, t, v))
        return Vector((t, u, v))
    extruir(bm, [[p3(u, v, a0) for u, v in pontos], [p3(u, v, a1) for u, v in pontos]])


def tri(bm, p1, p2, p3, grosso):
    """Lâmina triangular (bandeirinha, vela) com espessura `grosso` (vetor) a partir do triângulo."""
    g = Vector(grosso)
    a, b, c = Vector(p1), Vector(p2), Vector(p3)
    extruir(bm, [[a, b, c], [a + g, b + g, c + g]])


def catenaria(a, b, flecha, n):
    """n+1 pontos de a a b com a curva de um cordão frouxo (flecha = queda no meio)."""
    a, b = Vector(a), Vector(b)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.z -= flecha * 4.0 * t * (1.0 - t)
        pts.append(p)
    return pts


def pano_y(z, topo, y, amp=0.0, fase=0.0, freq=1.0, k_amp=1.0, abre=0.0):
    """Deslocamento em Y do tecido na altura z (ondulação nula no topo + abertura linear para baixo)."""
    env = min(1.0, (topo - z) * k_amp)
    return y + amp * math.sin(freq * (topo - z) + fase) * env + abre * (topo - z)


def pano(bm, xc, larg, zs, y, esp, amp=0.0, fase=0.0, freq=1.0, u=(-0.5, 0.5), ponta=None, k_amp=1.0, abre=0.0, topo=None):
    """Tecido que desce em `zs` (lista decrescente de z), de largura `larg` e centro `xc` (números ou f(z)),
    com ondulação em Y de amplitude `amp` (nula no topo), abertura linear `abre` (afasta para +Y ao descer) e
    espessura `esp`. `u` recorta uma faixa da largura (-0.5..0.5): usada para bordas.
    `ponta` fecha em z um bico no centro. `topo` (padrão zs[0]) é a altura em que a ondulação é nula."""
    topo = zs[0] if topo is None else topo
    aneis = []
    for z in zs:
        w = larg(z) if callable(larg) else larg
        cx = xc(z) if callable(xc) else xc
        yy = pano_y(z, topo, y, amp, fase, freq, k_amp, abre)
        xa, xb = cx + w * u[0], cx + w * u[1]
        aneis.append([Vector((xa, yy - esp / 2, z)), Vector((xb, yy - esp / 2, z)),
                      Vector((xb, yy + esp / 2, z)), Vector((xa, yy + esp / 2, z))])
    if ponta is None:
        extruir(bm, aneis)
    else:
        cx = xc(ponta) if callable(xc) else xc
        extruir(bm, aneis, Vector((cx, pano_y(ponta, topo, y, amp, fase, freq, k_amp, abre), ponta)))


def torno_arco(bm, perfil, a0, a1, passos, esc=(1.0, 1.0), centro=(0.0, 0.0, 0.0)):
    """Como `torno`, mas só entre os ângulos a0 e a1 (rad), com tampas planas nas pontas (capuz, gola, manto
    aberto na frente). `perfil` é um polígono fechado de (raio, z); `esc` escala X e Y (elipse)."""
    cx, cy, cz = centro
    aneis = []
    for i in range(passos + 1):
        a = a0 + (a1 - a0) * i / passos
        ca, sa = math.cos(a), math.sin(a)
        aneis.append([bm.verts.new((cx + esc[0] * r * ca, cy + esc[1] * r * sa, cz + z)) for r, z in perfil])
    n = len(perfil)
    for i in range(passos):
        for j in range(n):
            k = (j + 1) % n
            bm.faces.new((aneis[i][j], aneis[i][k], aneis[i + 1][k], aneis[i + 1][j]))
    bm.faces.new(aneis[0][::-1])
    bm.faces.new(aneis[-1])


def ring_xy(r, z, n, giro=0.0, centro=(0.0, 0.0)):
    return [Vector((centro[0] + r * math.cos(giro + k * TAU / n), centro[1] + r * math.sin(giro + k * TAU / n), z)) for k in range(n)]


def bloco_radial(bm, raio_apotema, ang, comp, esp, z, altura, giro_extra=0.0, centro=(0.0, 0.0)):
    """Caixa tangente a um círculo: no ângulo `ang`, à distância `raio_apotema` do centro (paredes de poço,
    bacias de chafariz). `comp` é o comprimento tangencial, `esp` a espessura radial."""
    x = centro[0] + raio_apotema * math.cos(ang)
    y = centro[1] + raio_apotema * math.sin(ang)
    caixa(bm, (x, y, z), (esp, comp, altura), (0.0, 0.0, ang + giro_extra))


def segmento_anel(bm, ap_int, ap_ext, ang, z0, z1, n):
    """Trecho de um anel poligonal de `n` lados (como paredes de bacia e poço): trapézio entre as apótemas
    `ap_int` e `ap_ext`, centrado no ângulo `ang`, de z0 a z1. Os n trechos fecham o anel sem frestas."""
    meio = math.pi / n
    ri, re = ap_int / math.cos(meio), ap_ext / math.cos(meio)
    a0, a1 = ang - meio, ang + meio
    pts = [(ri * math.cos(a0), ri * math.sin(a0)), (re * math.cos(a0), re * math.sin(a0)),
           (re * math.cos(a1), re * math.sin(a1)), (ri * math.cos(a1), ri * math.sin(a1))]
    prisma(bm, pts, "Z", z0, z1)


def lamina_radial(bm, ang, r0, z0, r1, z1, larg, esp):
    """Lâmina fina (queda d'água, escora) do ponto (raio r0, z0) ao ponto (raio r1, z1) no ângulo `ang`."""
    rad = Vector((math.cos(ang), math.sin(ang), 0.0))
    tan = Vector((-math.sin(ang), math.cos(ang), 0.0))

    def anel(r, z):
        p = rad * r + Vector((0, 0, z))
        return [p - tan * larg / 2 - rad * esp / 2, p + tan * larg / 2 - rad * esp / 2,
                p + tan * larg / 2 + rad * esp / 2, p - tan * larg / 2 + rad * esp / 2]
    extruir(bm, [anel(r0, z0), anel(r1, z1)])
