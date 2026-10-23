"""Props da vila (V3 do Mundo V2): lampião, carroça, caixotes, ponte em arco, paliçada e portão.

Contrato igual ao de modelos.py: função `(semente, **opcoes) -> Modelo`, origem no chão
centrada, faces para fora, grupos de cor (o Roblox repinta por grupo). Medidas em studs;
o avatar tem ~5 studs de altura. Sem espelhamento: eixo longo em X, "frente" em +X quando
fizer sentido (carroça: o timão aponta para +X; portão: o lado de dentro é +Y).
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector

import formas
from formas import extruir, tronco
from lib import Modelo

TAU = math.tau


def _rz(x, y, ang):
    """Gira (x, y) em torno da origem por `ang` (rad, em Z)."""
    c, s = math.cos(ang), math.sin(ang)
    return x * c - y * s, x * s + y * c


def _caixa(bm, centro, tam, eixo="Z", ang=0.0):
    """Caixa girada em torno do próprio centro por `ang` no eixo X, Y ou Z."""
    m = Matrix.Translation(Vector(centro)) @ Matrix.Rotation(ang, 4, eixo) @ Matrix.Diagonal(Vector((*tam, 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


# ======================================================================================
def lampiao(semente, **_):
    """Poste de lampião de ferro sobre base de pedra: lanterna no topo e outra pendurada no braço (~8,4 studs)."""
    rng = random.Random(semente)
    m = Modelo("Lampiao")
    pedra = m.grupo("Pedra", (124, 120, 112), "Slate")
    ferro = m.grupo("Ferro", (52, 48, 50), "Metal")
    vidro = m.grupo("Luz", (255, 196, 112), "Neon")
    # base: bloco de pedra em degrau, com anel de transição
    Modelo.caixa(pedra, (0, 0, 0.45), (1.9, 1.9, 0.9))
    Modelo.cilindro(pedra, (0, 0, 1.1), 0.8, 0.45, 8, 0.55, tampas=True)
    # fuste com anéis
    Modelo.cilindro(ferro, (0, 0, 3.8), 0.3, 5.4, 8, 0.2, tampas=False)
    for z, r in ((1.55, 0.44), (3.0, 0.34), (6.2, 0.4)):
        Modelo.cilindro(ferro, (0, 0, z), r, 0.2, 8, r, tampas=True)
    Modelo.cilindro(ferro, (0, 0, 6.45), 0.62, 0.24, 8, 0.5, tampas=True)
    # lanterna no topo: vidro, quatro montantes, tampa piramidal e pináculo
    def lanterna(x, z, escala=1.0):
        s = escala
        Modelo.caixa(vidro, (x, 0, z), (0.78 * s, 0.78 * s, 1.1 * s))
        for sx in (-1, 1):
            for sy in (-1, 1):
                Modelo.caixa(ferro, (x + sx * 0.42 * s, sy * 0.42 * s, z), (0.13 * s, 0.13 * s, 1.2 * s))
        Modelo.caixa(ferro, (x, 0, z - 0.62 * s), (1.0 * s, 1.0 * s, 0.14 * s))
        Modelo.cilindro(ferro, (x, 0, z + 0.9 * s), 0.78 * s, 0.62 * s, 4, 0.1 * s, tampas=True, giro_z=math.pi / 4)
        Modelo.cilindro(ferro, (x, 0, z + 1.3 * s), 0.1 * s, 0.35 * s, 6, 0.12 * s, tampas=True)
    lanterna(0, 7.05)
    # braço curvo com a segunda lanterna pendurada por uma corrente
    tronco(ferro, [(0, 0, 5.2), (0.55, 0, 5.75), (1.25, 0, 5.95), (1.95, 0, 5.8)], [0.15, 0.12, 0.1, 0.09], 5)
    Modelo.ramo(ferro, (0.55, 0, 5.5), (1.15, 0, 5.8), 0.06, 0.06, 4)
    Modelo.cilindro(ferro, (1.95, 0, 5.5), 0.03, 0.55, 4, None, tampas=False)
    lanterna(1.95, 4.75, 0.65)
    return m


def _roda(bm_aro, bm_raio, bm_cubo, x, y, raio, larg):
    """Roda de carroça no plano XZ: aro (12 segmentos), cubo e seis raios."""
    n = 12
    aneis = []
    for k in range(n):
        a = k * TAU / n
        c, s = math.cos(a), math.sin(a)
        aneis.append([Vector((x + c * raio, y + larg / 2, raio + s * raio)), Vector((x + c * raio, y - larg / 2, raio + s * raio)),
                      Vector((x + c * (raio - 0.28), y - larg / 2, raio + s * (raio - 0.28))), Vector((x + c * (raio - 0.28), y + larg / 2, raio + s * (raio - 0.28)))])
    vs = [[bm_aro.verts.new(p) for p in an] for an in aneis]
    for k in range(n):
        j = (k + 1) % n
        for q in range(4):
            r = (q + 1) % 4
            bm_aro.faces.new((vs[k][q], vs[k][r], vs[j][r], vs[j][q]))
    Modelo.cilindro(bm_cubo, (x, y, raio), 0.42, larg + 0.25, 8, 0.38, "Y", tampas=True)
    for k in range(3):
        _caixa(bm_raio, (x, y, raio), (2 * (raio - 0.2), 0.2, 0.2), "Y", k * math.pi / 3)


def carroca(semente, **_):
    """Carroça de madeira com cesto de tábuas, duas rodas de raios, timão para +X, carga de sacos e barril (~9 x 4,6 x 3,7)."""
    rng = random.Random(semente * 3 + 1)
    m = Modelo("Carroca")
    tabuas = m.grupo("Tabuas", (132, 96, 62), "WoodPlanks")
    madeira = m.grupo("Madeira", (88, 62, 42), "Wood")
    ferro = m.grupo("Ferro", (58, 54, 54), "Metal")
    saco = m.grupo("Saco", (190, 170, 128), "Fabric")
    palha = m.grupo("Palha", (190, 164, 92), "Grass")
    R = 1.5
    zf = 1.6  # altura do piso
    # piso, laterais e traseira
    Modelo.caixa(tabuas, (0, 0, zf), (5.2, 3.3, 0.26))
    for sy in (-1, 1):
        for z in (zf + 0.45, zf + 1.05):
            Modelo.caixa(tabuas, (0, sy * 1.6, z), (5.2, 0.16, 0.5))
    Modelo.caixa(tabuas, (-2.5, 0, zf + 0.75), (0.16, 3.3, 1.3))
    # frente do cesto mais baixa (tábua única) e banco do condutor
    Modelo.caixa(tabuas, (2.5, 0, zf + 0.5), (0.16, 3.3, 0.8))
    Modelo.caixa(madeira, (1.35, 0, zf + 1.4), (1.1, 3.0, 0.2))
    for sy in (-1, 1):
        Modelo.caixa(madeira, (1.35, sy * 1.35, zf + 0.95), (0.25, 0.25, 0.8))
    # estacas
    for x in (-2.5, -0.85, 0.85, 2.5):
        for sy in (-1, 1):
            Modelo.caixa(madeira, (x, sy * 1.68, zf + 0.78), (0.26, 0.2, 1.42))
    # vigas do chassi e eixo
    for sy in (-1, 1):
        Modelo.caixa(madeira, (0, sy * 1.1, zf - 0.28), (5.4, 0.3, 0.3))
    Modelo.caixa(ferro, (-0.5, 0, R), (0.24, 4.3, 0.24))
    for sy in (-1, 1):
        _roda(m.grupos["Madeira"]["bm"], m.grupos["Madeira"]["bm"], ferro, -0.5, sy * 2.05, R, 0.42)
    # timão: duas varas que sobem em direção a +X, travessa na ponta
    for sy in (-1, 1):
        tronco(madeira, [(2.4, sy * 0.85, zf - 0.28), (4.2, sy * 0.7, zf - 0.55), (6.0, sy * 0.55, zf - 0.55)], [0.19, 0.16, 0.12], 5)
    Modelo.caixa(madeira, (5.8, 0, zf - 0.55), (0.22, 1.5, 0.22))
    Modelo.ramo(ferro, (6.1, -0.3, zf - 0.55), (6.1, 0.3, zf - 0.55), 0.12, 0.12, 6)
    # carga: palha, sacos e barril
    Modelo.esfera(palha, (-0.8, 0.0, zf + 0.35), 1.1, (1.5, 1.2, 0.3), 1, 0.12, rng)
    for x, y, g in ((-1.9, -0.85, 0.2), (-1.6, 0.9, -0.3), (-0.6, 0.1, 0.5)):
        Modelo.esfera(saco, (x, y, zf + 0.78), 0.72, (1.0, 0.8, 0.95), 1, 0.12, rng)
        Modelo.cilindro(saco, (x, y, zf + 1.45), 0.2, 0.28, 5, 0.1, tampas=True)
    Modelo.cilindro(tabuas, (0.3, -0.7, zf + 0.9), 0.62, 1.35, 10, 0.62, tampas=True)
    for dz in (-0.4, 0.45):
        Modelo.cilindro(ferro, (0.3, -0.7, zf + 0.9 + dz), 0.655, 0.12, 10, 0.655, tampas=True)
    return m


def _caixote(m, centro, tam, giro, rng):
    """Caixote de carga: corpo de tábuas, quatro montantes, travessas nas bordas e duas diagonais."""
    corpo, quadro = m.grupos["Tabuas"]["bm"], m.grupos["Quadro"]["bm"]
    cx, cy, cz = centro
    sx, sy, sz = tam

    def pos(x, y, z):
        px, py = _rz(x, y, giro)
        return (cx + px, cy + py, cz + z)
    Modelo.caixa(corpo, (cx, cy, cz), (sx * 0.94, sy * 0.94, sz * 0.94), giro)
    t = 0.2
    for ux in (-1, 1):
        for uy in (-1, 1):
            Modelo.caixa(quadro, pos(ux * (sx / 2 - t / 2 + 0.03), uy * (sy / 2 - t / 2 + 0.03), 0), (t, t, sz + 0.06), giro)
    for uz in (-1, 1):
        for uy in (-1, 1):
            Modelo.caixa(quadro, pos(0, uy * (sy / 2 + 0.02), uz * (sz / 2 - t / 2)), (sx, 0.14, t), giro)
        for ux in (-1, 1):
            Modelo.caixa(quadro, pos(ux * (sx / 2 + 0.02), 0, uz * (sz / 2 - t / 2)), (0.14, sy, t), giro)
    diag = math.atan2(sz, sx) * rng.choice((-1, 1))
    for uy in (-1, 1):
        px, py = _rz(0, uy * (sy / 2 + 0.05), giro)
        _caixa(quadro, (cx + px, cy + py, cz), (math.hypot(sx, sz) * 0.8, 0.1, 0.16), "Y", diag)


def caixotes(semente, **_):
    """Pilha de caixotes (6) em pirâmide com um barril e dois sacos ao lado (~7 x 4 x 4,7)."""
    rng = random.Random(semente * 5 + 2)
    m = Modelo("Caixotes")
    m.grupo("Tabuas", (146, 106, 66), "WoodPlanks")
    m.grupo("Quadro", (94, 66, 42), "Wood")
    m.grupo("Ferro", (58, 54, 54), "Metal")
    m.grupo("Saco", (190, 170, 128), "Fabric")
    s = 1.9
    for i, x in enumerate((-2.0, 0.0, 2.0)):
        _caixote(m, (x + rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), s / 2), (s, s, s), rng.uniform(-0.1, 0.1), rng)
    for x in (-1.0, 1.0):
        _caixote(m, (x + rng.uniform(-0.08, 0.08), rng.uniform(-0.1, 0.1), s * 1.5 + 0.02), (s, s, s), rng.uniform(-0.12, 0.12), rng)
    _caixote(m, (0.1, 0.0, s * 2.5 + 0.04), (s * 0.92, s * 0.92, s * 0.92), 0.32, rng)
    # barril ao lado e sacos
    q = m.grupos["Quadro"]["bm"]
    Modelo.cilindro(q, (3.9, 0.9, 0.85), 0.78, 1.7, 10, 0.78, tampas=True)
    for dz in (-0.45, 0.5):
        Modelo.cilindro(m.grupos["Ferro"]["bm"], (3.9, 0.9, 0.85 + dz), 0.82, 0.12, 10, 0.82, tampas=True)
    for x, y in ((-3.9, 0.6), (-3.5, -0.6)):
        Modelo.esfera(m.grupos["Saco"]["bm"], (x, y, 0.62), 0.78, (1.0, 0.82, 0.85), 1, 0.12, rng, corte_z=0.0)
        Modelo.cilindro(m.grupos["Saco"]["bm"], (x, y, 1.2), 0.22, 0.3, 5, 0.12, tampas=True)
    return m


def ponte(semente, **_):
    """Ponte de madeira em arco: vão de 16 studs (eixo X), largura 8 (Y), com cabeceiras de pedra,
    vigas curvas, guarda-corpo e degraus de pedra nas pontas (~22 x 9 x 6,5)."""
    rng = random.Random(semente)
    m = Modelo("Ponte")
    pedra = m.grupo("Pedra", (124, 120, 112), "Slate")
    m.grupo("Tabua", (138, 100, 64), "WoodPlanks")
    m.grupo("TabuaEscura", (112, 80, 52), "WoodPlanks")
    viga = m.grupo("Viga", (84, 60, 42), "Wood")
    m.grupo("Corda", (176, 148, 100), "Fabric")
    vao, larg, z0, flecha = 16.0, 8.0, 1.5, 2.6

    def zc(x):
        return z0 + flecha * (1.0 - (x / (vao / 2)) ** 2)

    def tangente(x):
        return -2.0 * flecha * x / (vao / 2) ** 2
    # cabeceiras e degraus de pedra
    for s in (-1, 1):
        Modelo.caixa(pedra, (s * (vao / 2 + 1.5), 0, (z0 - 0.15) / 2), (3.0, larg + 0.8, z0 - 0.15))
        Modelo.caixa(pedra, (s * (vao / 2 + 3.4), 0, 0.35), (1.3, larg - 0.8, 0.7))
        for sy in (-1, 1):
            Modelo.caixa(pedra, (s * (vao / 2 + 1.5), sy * (larg / 2 + 0.2), z0 + 0.55), (3.2, 0.7, 1.1))
    # tabuado
    n = 17
    for i in range(n):
        x = -vao / 2 + (i + 0.5) * vao / n
        alvo = m.grupos["Tabua" if i % 2 == 0 else "TabuaEscura"]["bm"]
        _caixa(alvo, (x, rng.uniform(-0.06, 0.06), zc(x)), (vao / n * 0.94 / math.cos(math.atan(tangente(x))), larg, 0.3),
               "Y", -math.atan(tangente(x)))
    # vigas curvas sob o tabuado (4) e travessas
    xs = [-vao / 2 + k * vao / 8 for k in range(9)]
    for y in (-3.2, -1.1, 1.1, 3.2):
        tronco(viga, [(x, y, zc(x) - 0.62) for x in xs], [0.34] * 9, 4, giro=math.pi / 4)
    for x in xs[1:-1:2]:
        Modelo.caixa(viga, (x, 0, zc(x) - 0.62), (0.3, larg - 0.5, 0.3))
    # guarda-corpo: montantes a cada 2 studs, corrimão e barra baixa seguindo o arco
    pontos = [-8.0, -6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0, 8.0]
    for sy in (-1, 1):
        y = sy * (larg / 2 - 0.25)
        for x in pontos:
            Modelo.caixa(viga, (x, y, zc(x) + 0.15 + 0.75), (0.28, 0.28, 1.7))
        tronco(viga, [(x, y, zc(x) + 1.7) for x in xs], [0.15] * 9, 4, giro=math.pi / 4)
        tronco(viga, [(x, y, zc(x) + 0.85) for x in xs], [0.11] * 9, 4, giro=math.pi / 4)
    # nós de corda nos montantes das pontas
    for x in (-8.0, 0.0, 8.0):
        for sy in (-1, 1):
            Modelo.cilindro(m.grupos["Corda"]["bm"], (x, sy * (larg / 2 - 0.25), zc(x) + 1.35), 0.2, 0.16, 6, 0.2, tampas=True)
    return m


def palicada(semente, **_):
    """Segmento reto de paliçada de toras com pontas afiadas, 8 studs de largura e ~7 de altura.
    Encaixa pelas pontas (X); a frente é -Y, as travessas ficam atrás (+Y)."""
    rng = random.Random(semente * 7 + 4)
    m = Modelo("Palicada")
    m.grupo("Tora", (106, 78, 52), "Wood")
    m.grupo("ToraClara", (128, 96, 64), "Wood")
    m.grupo("Ponta", (178, 142, 98), "Wood")
    m.grupo("Madeira", (80, 58, 40), "WoodPlanks")
    m.grupo("Corda", (176, 148, 100), "Fabric")
    m.grupo("Terra", (82, 66, 50), "Ground")
    n = 9
    esp = 0.9
    for i in range(n):
        x = (i - (n - 1) / 2) * esp
        h = rng.choice((6.0, 6.6, 7.2, 7.6, 6.3, 7.0))
        tx, ty = rng.uniform(-0.1, 0.1), rng.uniform(-0.08, 0.08)
        alvo = m.grupos["Tora" if i % 2 == 0 else "ToraClara"]["bm"]
        topo = (x + tx, ty, h)
        Modelo.ramo(alvo, (x, 0, 0), topo, 0.5, 0.45, 7)
        Modelo.ramo(m.grupos["Ponta"]["bm"], topo, (topo[0] + tx * 0.4, topo[1], h + 1.25), 0.45, 0.04, 7)
    for z in (1.9, 4.4):
        Modelo.caixa(m.grupos["Madeira"]["bm"], (0, 0.62, z), (n * esp + 0.1, 0.24, 0.36))
        for i in range(0, n, 2):
            Modelo.caixa(m.grupos["Corda"]["bm"], ((i - (n - 1) / 2) * esp, 0.5, z), (0.2, 0.9, 0.5))
    for x in (-3.4, -0.9, 1.7, 3.5):
        Modelo.esfera(m.grupos["Terra"]["bm"], (x, -0.1, 0.0), 0.9, (1.4, 1.0, 0.45), 1, 0.12, rng, corte_z=0.0)
    return m


def portao(semente, **_):
    """Portão da vila: dois pilares de madeira sobre bases de pedra, verga com telhadinho, lanterna e
    duas folhas abertas para +Y (largura 8, vão 5,9, altura ~10,6). Combina com a paliçada de 8 studs."""
    rng = random.Random(semente)
    m = Modelo("Portao")
    pedra = m.grupo("Pedra", (124, 120, 112), "Slate")
    madeira = m.grupo("Madeira", (92, 66, 44), "Wood")
    m.grupo("Tabuas", (132, 96, 62), "WoodPlanks")
    ferro = m.grupo("Ferro", (58, 54, 54), "Metal")
    telhado = m.grupo("Telhado", (150, 78, 56), "Slate")
    m.grupo("Luz", (255, 196, 112), "Neon")
    xp = 3.55
    for s in (-1, 1):
        Modelo.caixa(pedra, (s * xp, 0, 0.45), (2.0, 2.0, 0.9))
        Modelo.caixa(madeira, (s * xp, 0, 0.9 + 4.5), (1.3, 1.3, 9.0))
        Modelo.caixa(ferro, (s * xp, 0, 1.6), (1.46, 1.46, 0.22))
        Modelo.caixa(ferro, (s * xp, 0, 6.2), (1.46, 1.46, 0.22))
        Modelo.caixa(madeira, (s * xp, 0, 9.95), (1.6, 1.6, 0.24))
        # escoras diagonais
        _caixa(madeira, (s * (xp - 1.1), 0, 7.2), (0.28, 0.4, 2.4), "Y", s * 0.7)
    Modelo.caixa(madeira, (0, 0, 8.4), (8.0, 1.2, 1.1))
    Modelo.caixa(madeira, (0, 0, 7.55), (6.0, 0.9, 0.5))
    Modelo.caixa(madeira, (0, 0, 9.2), (9.0, 1.5, 0.35))
    Modelo.telhado(telhado, (0, 0, 9.4), 10.4, 3.2, 1.9)
    Modelo.caixa(telhado, (0, 0, 11.35), (10.5, 0.3, 0.26))
    # lanterna pendurada
    Modelo.cilindro(ferro, (0, -0.1, 6.85), 0.03, 0.9, 4, None, tampas=False)
    Modelo.caixa(m.grupos["Luz"]["bm"], (0, -0.1, 6.15), (0.5, 0.5, 0.7))
    Modelo.caixa(ferro, (0, -0.1, 6.55), (0.62, 0.62, 0.12))
    Modelo.caixa(ferro, (0, -0.1, 5.78), (0.62, 0.62, 0.12))
    # folhas abertas (~75 graus) para o lado de dentro (+Y)
    phi = math.radians(75)
    for s in (-1, 1):
        hx = s * (xp - 0.65)
        ang = phi if s < 0 else math.pi - phi
        dx, dy = math.cos(ang), math.sin(ang)
        nx, ny = -dy, dx
        for k in range(5):
            u = 0.3 + k * 0.58
            Modelo.caixa(m.grupos["Tabuas"]["bm"], (hx + dx * u, dy * u, 3.55), (0.54, 0.34, 6.2), ang)
        for z in (1.4, 5.7):
            Modelo.caixa(ferro, (hx + dx * 1.5 + nx * 0.22, dy * 1.5 + ny * 0.22, z), (3.0, 0.14, 0.4), ang)
        Modelo.caixa(madeira, (hx + dx * 1.5, dy * 1.5, 0.45), (3.0, 0.4, 0.3), ang)
        Modelo.caixa(madeira, (hx + dx * 1.5, dy * 1.5, 6.65), (3.0, 0.4, 0.3), ang)
    return m


GERADORES = {
    "lampiao": lampiao,
    "carroca": carroca,
    "caixotes": caixotes,
    "ponte": ponte,
    "palicada": palicada,
    "portao": portao,
}
