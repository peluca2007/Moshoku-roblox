"""Formas orgânicas extras para vegetação e props (roda dentro do Blender, sem janela).

Complementa `lib.Modelo` com: lâminas (folhas de grama, frondes), troncos curvos, blocos
rochosos facetados e divisão de uma malha em dois tons (luz/sombra) por critério de face.
Toda forma gerada é FECHADA (tampas), para o `recalc_face_normals` do `finalizar` orientar
as faces para fora sem surpresa.
"""
import math

import bmesh
from mathutils import Vector

from lib import Modelo

CIMA = Vector((0, 0, 1))


def anexar(destino, origem):
    """Copia vértices e faces de `origem` para `destino` (ambos bmesh)."""
    origem.verts.index_update()
    mapa = {}
    for v in origem.verts:
        mapa[v.index] = destino.verts.new(v.co)
    for f in origem.faces:
        try:
            destino.faces.new([mapa[v.index] for v in f.verts])
        except ValueError:
            pass


def extruir(bm, aneis, ponta=None):
    """Liga uma lista de anéis (listas de Vector com a mesma contagem) em um sólido fechado.
    Com `ponta` o último anel converge a esse ponto; sem ele, é fechado por uma tampa."""
    vs = [[bm.verts.new(p) for p in anel] for anel in aneis]
    n = len(vs[0])
    for i in range(len(vs) - 1):
        for j in range(n):
            k = (j + 1) % n
            bm.faces.new((vs[i][j], vs[i][k], vs[i + 1][k], vs[i + 1][j]))
    bm.faces.new(vs[0][::-1])
    if ponta is None:
        bm.faces.new(vs[-1])
    else:
        pv = bm.verts.new(ponta)
        for j in range(n):
            bm.faces.new((vs[-1][j], vs[-1][(j + 1) % n], pv))


def lamina(bm, base, azimute, comprimento, largura, incl, curva, segs=3, grossura=0.08, perfil=3, serrilha=0.0, chao=0.04):
    """Lâmina que se curva (folha de grama, fronde, folha de taboa).
    `incl`: ângulo inicial com a vertical (rad); `curva`: quanto o ângulo cresce até a ponta
    (positivo = tomba para fora); `serrilha`: reentrâncias alternadas na borda (folíolos)."""
    dh = Vector((math.cos(azimute), math.sin(azimute), 0))
    lado = Vector((-math.sin(azimute), math.cos(azimute), 0))
    pos = Vector(base)
    passo = comprimento / segs
    th = incl
    aneis = []
    for i in range(segs):
        t = i / segs
        tang = dh * math.sin(th) + CIMA * math.cos(th)
        n = lado.cross(tang).normalized()
        w = largura * 0.5 * (1.0 - t) ** 0.75
        if serrilha and i % 2 == 1:
            w *= 1.0 - serrilha
        g = grossura * (1.0 - t * 0.5)
        if perfil == 3:
            anel = [pos - lado * w, pos + lado * w, pos + n * g]
        else:
            anel = [pos + n * g, pos + lado * w, pos - n * g * 0.5, pos - lado * w]
        aneis.append(anel)
        pos = pos + tang * passo
        pos.z = max(pos.z, chao)
        th += curva / segs
    extruir(bm, aneis, pos)


def tronco(bm, pontos, raios, lados=7, rng=None, ruido=0.0, ponta=False, giro=0.0, torcao=0.0):
    """Sólido ao longo de uma trajetória: um anel perpendicular à tangente em cada ponto.
    `ruido` desloca os vértices (casca irregular); `torcao` gira cada anel (tronco retorcido);
    `ponta` fecha o fim em um ponto."""
    pts = [Vector(p) for p in pontos]
    aneis = []
    for i, p in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        tang = (b - a)
        m = tang.to_track_quat("Z", "Y").to_matrix()
        ex, ey = m.col[0], m.col[1]
        anel = []
        for k in range(lados):
            ang = giro + i * torcao + k * math.tau / lados
            r = raios[i] * (1.0 + (rng.uniform(-ruido, ruido) if rng and ruido else 0.0))
            anel.append(p + ex * math.cos(ang) * r + ey * math.sin(ang) * r)
        aneis.append(anel)
    if ponta:
        extruir(bm, aneis, pts[-1] + (pts[-1] - pts[-2]).normalized() * raios[-1])
    else:
        extruir(bm, aneis)


def bloco(bm, centro, dim, rng, giro=0.0, inclina=(0.0, 0.0), afunila=0.3, jit=0.12, esfericidade=0.35, cortes=1):
    """Bloco rochoso facetado: cubo subdividido, arredondado em parte, afunilado para cima e
    deformado; mantém as faces planas (visual de pedra, não de bolha)."""
    t = bmesh.new()
    bmesh.ops.create_cube(t, size=1.0)
    bmesh.ops.subdivide_edges(t, edges=t.edges[:], cuts=cortes, use_grid_fill=True)
    cz, sz = math.cos(giro), math.sin(giro)
    for v in t.verts:
        p = Vector(v.co)
        alvo = p.normalized() * 0.62
        p = p.lerp(alvo, esfericidade)
        s = 1.0 - afunila * (p.z + 0.5)
        p.x *= s
        p.y *= s
        p += Vector((rng.uniform(-jit, jit), rng.uniform(-jit, jit), rng.uniform(-jit, jit)))
        p = Vector((p.x * dim[0], p.y * dim[1], p.z * dim[2]))
        # inclinação (em torno de X e Y) e giro em Z
        ix, iy = inclina
        y1 = p.y * math.cos(ix) - p.z * math.sin(ix)
        z1 = p.y * math.sin(ix) + p.z * math.cos(ix)
        x2 = p.x * math.cos(iy) + z1 * math.sin(iy)
        z2 = -p.x * math.sin(iy) + z1 * math.cos(iy)
        x3 = x2 * cz - y1 * sz
        y3 = x2 * sz + y1 * cz
        v.co = Vector((centro[0] + x3, centro[1] + y3, centro[2] + z2))
    anexar(bm, t)
    t.free()


def orientar(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def dividir(bm, criterio):
    """Orienta as faces e separa `bm` em (cumprem `criterio`, demais), com índices em dia."""
    orientar(bm)
    bm.verts.index_update()
    return Modelo.dividir_faces(bm, criterio)


def dividir_tons(modelo, bm, claro, escuro, criterio):
    """Orienta `bm` e o reparte entre dois grupos já criados: faces que cumprem
    `criterio(face)` vão a `claro`, as demais a `escuro`. Anexa ao que o grupo já tiver."""
    a, b = dividir(bm, criterio)
    anexar(modelo.grupos[claro]["bm"], a)
    anexar(modelo.grupos[escuro]["bm"], b)
    a.free()
    b.free()
    bm.free()


def luz(face, limiar=0.45):
    """Critério de tom: face voltada para cima (iluminada pelo sol alto)."""
    return face.normal.z > limiar


def triangulos(modelo):
    """Contagem de triângulos dos grupos (antes de `finalizar`)."""
    return sum(max(len(f.verts) - 2, 1) for g in modelo.grupos.values() for f in g["bm"].faces)
