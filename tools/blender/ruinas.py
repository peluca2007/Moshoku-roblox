"""Peças das Ruínas do Vale: coluna, coluna quebrada, muro, arco, altar do Selo, lápide.
Pedra clara desgastada com musgo; só o altar tem runa brilhante (grupo Luz, material Neon)."""
import math
import random

import bmesh
from mathutils import Vector

import formas
from lib import Modelo

PEDRA = (150, 146, 138)
PEDRA_ESCURA = (112, 108, 104)
MUSGO = (72, 108, 62)


def _grupos(m, luz=False):
    m.grupo("Pedra", PEDRA, "Slate")
    m.grupo("PedraEscura", PEDRA_ESCURA, "Slate")
    m.grupo("Musgo", MUSGO, "Grass")
    if luz:
        m.grupo("Luz", (150, 120, 255), "Neon")
    return {n: v["bm"] for n, v in m.grupos.items()}


def _musgo(g, rng, x0, x1, y0, y1, z, n=3, raio=0.45):
    for _ in range(n):
        Modelo.esfera(g["Musgo"], (rng.uniform(x0, x1), rng.uniform(y0, y1), z + rng.uniform(0, 0.1)), raio * rng.uniform(0.7, 1.2),
                      (1.2, 1, 0.3), 1, 0.1, rng)


def coluna(semente):
    rng = random.Random(semente * 5 + 2)
    m = Modelo(f"Coluna{semente}")
    g = _grupos(m)
    h = 6.2 + rng.random() * 1.6
    Modelo.caixa(g["PedraEscura"], (0, 0, 0.35), (2.2, 2.2, 0.7))
    Modelo.cilindro(g["Pedra"], (0, 0, 0.7 + h / 2), 0.78, h, 8, 0.7, tampas=False)
    for z in (0.7 + h * 0.3, 0.7 + h * 0.62):
        Modelo.cilindro(g["PedraEscura"], (0, 0, z), 0.86, 0.22, 8, 0.86, tampas=False)
    Modelo.caixa(g["PedraEscura"], (0, 0, 0.7 + h + 0.25), (1.9, 1.9, 0.5))
    Modelo.caixa(g["Pedra"], (0, 0, 0.7 + h + 0.65), (2.4, 2.4, 0.3))
    _musgo(g, rng, -0.8, 0.8, -0.8, 0.8, 0.7, 4)
    return m


def coluna_quebrada(semente):
    rng = random.Random(semente * 7 + 3)
    m = Modelo(f"ColunaQuebrada{semente}")
    g = _grupos(m)
    h = 2.0 + rng.random() * 2.2
    Modelo.caixa(g["PedraEscura"], (0, 0, 0.35), (2.2, 2.2, 0.7))
    Modelo.cilindro(g["Pedra"], (0, 0, 0.7 + h / 2), 0.78, h, 8, 0.74, tampas=True)
    # tambores caídos ao lado
    for i in range(rng.randint(2, 3)):
        a = rng.random() * math.tau
        Modelo.cilindro(g["Pedra"], (math.cos(a) * (2.4 + i * 0.5), math.sin(a) * (2.4 + i * 0.5), 0.72), 0.74, 1.5 + rng.random(), 8, 0.74,
                        "X" if rng.random() < 0.5 else "Y", giro_z=a)
    Modelo.esfera(g["Pedra"], (1.0, -1.0, 0.3), 0.5, (1.3, 1, 0.6), 1, 0.2, rng, corte_z=0.0)
    _musgo(g, rng, -1.0, 1.0, -1.0, 1.0, 0.7 + h, 3)
    return m


def muro(semente):
    rng = random.Random(semente * 11 + 1)
    m = Modelo(f"Muro{semente}")
    g = _grupos(m)
    L = 8.0
    n = 8
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        h = rng.choice((3.6, 3.0, 2.2, 1.6, 3.4, 2.6)) if i not in (0, n - 1) else 3.8
        Modelo.caixa(g["Pedra" if rng.random() < 0.7 else "PedraEscura"], (x, 0, h / 2), (L / n + 0.02, 1.1, h))
        if rng.random() < 0.5:
            Modelo.caixa(g["PedraEscura"], (x, 0, h + 0.12), (L / n * 0.7, 0.9, 0.24), rng.uniform(-0.2, 0.2))
    Modelo.caixa(g["PedraEscura"], (0, 0, 0.2), (L + 0.3, 1.4, 0.4))
    _musgo(g, rng, -L / 2, L / 2, -0.4, 0.4, 1.6, 5, 0.5)
    return m


def arco(semente):
    m = Modelo("Arco")
    g = _grupos(m, luz=True)
    rng = random.Random(semente)
    W, H = 7.0, 7.6
    for s in (-1, 1):
        Modelo.caixa(g["PedraEscura"], (s * W / 2, 0, 0.4), (2.0, 2.0, 0.8))
        Modelo.cilindro(g["Pedra"], (s * W / 2, 0, 0.8 + (H - 0.8) / 2), 0.7, H - 0.8, 8, 0.64, tampas=False)
        Modelo.caixa(g["PedraEscura"], (s * W / 2, 0, H + 0.2), (1.9, 1.9, 0.5))
    # verga quebrada: só um lado inteiro, o outro tem pedra caída
    Modelo.caixa(g["Pedra"], (-W * 0.18, 0, H + 0.75), (W * 0.74, 1.5, 1.0))
    Modelo.caixa(g["PedraEscura"], (-W * 0.18, 0, H + 1.5), (W * 0.5, 1.1, 0.5))
    Modelo.caixa(g["Pedra"], (W * 0.38, 0, H + 0.4), (1.5, 1.4, 0.6), 0.1)
    for _ in range(3):
        Modelo.esfera(g["Pedra"], (rng.uniform(1.0, 3.2), rng.uniform(-2.2, -1.2), 0.45), 0.6, (1.2, 1, 0.7), 1, 0.2, rng, corte_z=0.0)
    Modelo.caixa(g["Luz"], (0, 0.95, H + 0.75), (1.0, 0.06, 0.5))  # runa sobre a verga
    _musgo(g, rng, -W / 2, W / 2, -0.8, 0.8, H + 1.0, 4)
    return m


def altar(semente):
    m = Modelo("Altar")
    g = _grupos(m, luz=True)
    rng = random.Random(semente)
    Modelo.cilindro(g["PedraEscura"], (0, 0, 0.3), 4.6, 0.6, 12, 4.2, tampas=True)
    Modelo.cilindro(g["Pedra"], (0, 0, 0.75), 3.4, 0.5, 12, 3.1, tampas=True)
    Modelo.cilindro(g["Pedra"], (0, 0, 1.6), 1.1, 1.3, 8, 0.9, tampas=True)
    Modelo.cilindro(g["PedraEscura"], (0, 0, 2.4), 1.4, 0.35, 8, 1.4, tampas=True)
    Modelo.esfera(g["Luz"], (0, 0, 3.2), 0.5, (1, 1, 1), 1, 0.0)
    for i in range(6):
        a = i * math.tau / 6
        Modelo.caixa(g["Luz"], (math.cos(a) * 3.8, math.sin(a) * 3.8, 0.72), (0.9, 0.16, 0.06), a)
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        Modelo.cilindro(g["Pedra"], (math.cos(a) * 4.9, math.sin(a) * 4.9, 1.6), 0.5, 3.2 - (i % 2) * 1.2, 7, 0.46, tampas=True)
    _musgo(g, rng, -3, 3, -3, 3, 0.95, 5, 0.6)
    return m


def lapide(semente):
    rng = random.Random(semente * 3 + 8)
    m = Modelo(f"Lapide{semente}")
    g = _grupos(m)
    h = 1.8 + rng.random() * 0.8
    Modelo.caixa(g["Pedra"], (0, 0, h / 2), (1.3, 0.35, h), rng.uniform(-0.2, 0.2))
    Modelo.caixa(g["PedraEscura"], (0, 0, 0.14), (1.9, 0.9, 0.28))
    Modelo.cilindro(g["Pedra"], (0, 0, h), 0.65, 0.35, 8, 0.55, "Y", tampas=True)
    _musgo(g, rng, -0.5, 0.5, -0.2, 0.2, h, 2, 0.35)
    return m


def _hera_grupos(m):
    m.grupo("Hera", (58, 92, 48), "Grass")
    m.grupo("HeraClara", (104, 138, 62), "Grass")
    m.grupo("Caule", (74, 62, 48), "Wood")


def coluna_hera(semente):
    """Coluna antiga tomada por hera: caule em hélice, folhas em almofadas e cipós pendentes.
    Variante 1: coluna inteira com capitel rachado; variante 2: quebrada no meio, com tambor caído."""
    rng = random.Random(semente * 9 + 5)
    v = (semente - 1) % 2
    m = Modelo(f"ColunaHera{semente}")
    g = _grupos(m)
    _hera_grupos(m)
    h = (7.4, 4.6)[v] + rng.random() * 0.8
    Modelo.caixa(g["PedraEscura"], (0, 0, 0.35), (2.4, 2.4, 0.7))
    Modelo.cilindro(g["Pedra"], (0, 0, 0.7 + h / 2), 0.8, h, 8, 0.72, tampas=True)
    for z in (0.7 + h * 0.3, 0.7 + h * 0.62):
        if z < 0.7 + h - 0.3:
            Modelo.cilindro(g["PedraEscura"], (0, 0, z), 0.88, 0.22, 8, 0.88, tampas=True)
    if v == 0:
        Modelo.caixa(g["PedraEscura"], (0, 0, 0.7 + h + 0.25), (1.9, 1.9, 0.5))
        Modelo.caixa(g["Pedra"], (0.1, 0, 0.7 + h + 0.65), (2.4, 2.4, 0.3), 0.15)
        Modelo.caixa(g["Pedra"], (1.3, 0.9, 0.5), (1.1, 0.9, 0.9), 0.5)  # lasca caída
    else:
        for i in range(2):
            a = 0.8 + i * 2.4
            Modelo.cilindro(g["Pedra"], (math.cos(a) * 2.6, math.sin(a) * 2.6, 0.8), 0.78, 1.6 + i * 0.5, 8, 0.78, "X" if i else "Y", giro_z=a)
        for k in range(3):
            a = 0.5 + k * 1.9
            Modelo.esfera(g["Pedra"], (math.cos(a) * 1.6, math.sin(a) * 1.6 - 0.8, 0.3), 0.55, (1.2, 1, 0.7), 1, 0.2, rng, corte_z=0.0)
    # hera: caule em hélice em volta do fuste e manchas de folhas coladas à pedra
    caule, folhas = m.grupos["Caule"]["bm"], bmesh.new()
    topo = 0.7 + h * 0.93
    pts, rs = [], []
    for k in range(13):
        t = k / 12
        a = t * 2.3 * math.tau + semente
        rr = 0.83 + 0.05 * math.sin(t * 9)
        pts.append((math.cos(a) * rr, math.sin(a) * rr, 0.75 + (topo - 0.75) * t))
        rs.append(0.17 * (1.0 - 0.4 * t))
        if k % 3 != 2:
            aa = a + rng.uniform(-0.2, 0.2)
            formas.bloco(folhas, (math.cos(aa) * (rr + 0.08), math.sin(aa) * (rr + 0.08), pts[-1][2] + rng.uniform(-0.2, 0.3)),
                         (0.3, rng.uniform(0.6, 1.0), rng.uniform(0.45, 0.8)), rng, aa, (0.0, 0.0), 0.0, 0.1, 0.45, 1)
    formas.tronco(caule, pts, rs, 4, giro=math.pi / 4)
    for k in range(4):  # cipós que pendem do topo
        a = rng.random() * math.tau
        x, y = math.cos(a) * 0.95, math.sin(a) * 0.95
        z1 = topo - rng.uniform(0.2, 1.0)
        formas.tronco(caule, [(x, y, z1), (x * 1.12, y * 1.12, z1 - 1.0), (x * 1.18, y * 1.18, z1 - 2.0)], [0.08, 0.07, 0.05], 4, ponta=True)
        formas.bloco(folhas, (x * 1.15, y * 1.15, z1 - 1.5), (0.3, 0.4, 1.1), rng, a, (0.0, 0.0), 0.3, 0.1, 0.45, 1)
    # ponta do fuste coberta
    Modelo.esfera(folhas, (0.1, 0.0, 0.7 + h + (0.1 if v == 0 else 0.0)), 0.75, (1.15, 1.0, 0.45), 1, 0.2, rng)
    formas.dividir_tons(m, folhas, "HeraClara", "Hera", lambda f: formas.luz(f, 0.35))
    _musgo(g, rng, -1.0, 1.0, -1.0, 1.0, 0.7, 3)
    return m


def escada_quebrada(semente):
    """Escada de pedra quebrada subindo para +X: degraus rachados e deslocados, balaustrada esquerda
    parcial, a direita desabada em blocos, musgo e ervas (~11 x 8 x 4,6)."""
    rng = random.Random(semente * 13 + 7)
    m = Modelo("EscadaQuebrada")
    g = _grupos(m)
    n, run, rise, larg = 8, 1.5, 0.58, 7.0
    for i in range(n):
        x = i * run
        topo = (i + 1) * rise
        alvo = g["Pedra" if i % 2 == 0 else "PedraEscura"]
        # cada degrau são 2 ou 3 lajes com altura e giro um pouco diferentes: pedra assentada e rachada
        cortes = [-larg / 2, -larg / 2 + larg * rng.uniform(0.3, 0.45), larg / 2 - larg * rng.uniform(0.3, 0.45), larg / 2]
        if i in (3, 6):
            cortes = [-larg / 2, 0.0, larg / 2]
        for a0, a1 in zip(cortes[:-1], cortes[1:]):
            queda = rng.choice((0.0, 0.0, 0.12, 0.3)) if i < n - 1 else 0.35
            giro = rng.uniform(-0.06, 0.06) if queda < 0.2 else rng.uniform(0.06, 0.16)
            if i == 7 and a1 == larg / 2:
                a1 -= 1.6  # o último perdeu o canto
            Modelo.caixa(alvo, (x + rng.uniform(-0.05, 0.05), (a0 + a1) / 2, (topo - queda) / 2), (run, a1 - a0 - 0.04, topo - queda), giro)
    # balaustrada esquerda (-Y): sobe em degraus e desaba no meio
    for i in range(6):
        x = i * run
        topo = (i + 1) * rise + 1.1 - (0.4 if i == 4 else 0.0)
        Modelo.caixa(g["Pedra"], (x, -larg / 2 - 0.4, topo / 2), (run, 0.8, topo))
        Modelo.caixa(g["PedraEscura"], (x, -larg / 2 - 0.4, topo + 0.12), (run * 0.96, 1.0, 0.24))
    # balaustrada direita desabada: só o começo e blocos caídos
    for i in range(2):
        x = i * run
        topo = (i + 1) * rise + 1.1
        Modelo.caixa(g["Pedra"], (x, larg / 2 + 0.4, topo / 2), (run, 0.8, topo))
        Modelo.caixa(g["PedraEscura"], (x, larg / 2 + 0.4, topo + 0.12), (run * 0.96, 1.0, 0.24))
    pedras = bmesh.new()
    for i in range(6):
        formas.bloco(pedras, (rng.uniform(2.6, 8.0), larg / 2 + rng.uniform(0.9, 2.6), 0.5), (rng.uniform(1.0, 1.7), rng.uniform(0.9, 1.4), rng.uniform(0.8, 1.2)),
                     rng, rng.random() * 3, (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2)), 0.1, 0.05, 0.2, 1)
    formas.orientar(pedras)
    formas.anexar(g["Pedra"], pedras)
    pedras.free()
    for i in (1, 2, 4, 5, 7):
        _musgo(g, rng, i * run - 0.5, i * run + 0.5, -larg / 2 + 0.3, larg / 2 - 0.3, (i + 1) * rise, 2, 0.5)
    _musgo(g, rng, 1.0, 7.0, -larg / 2 - 0.4, -larg / 2 - 0.4, 3.0, 3, 0.45)
    return m


GERADORES = {
    "coluna": lambda semente, **_: coluna(semente),
    "colunaquebrada": lambda semente, **_: coluna_quebrada(semente),
    "muro": lambda semente, **_: muro(semente),
    "arco": lambda semente, **_: arco(semente),
    "altar": lambda semente, **_: altar(semente),
    "lapide": lambda semente, **_: lapide(semente),
    "colunahera": lambda semente, **_: coluna_hera(semente),
    "escada": lambda semente, **_: escada_quebrada(semente),
}
