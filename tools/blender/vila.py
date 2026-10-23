"""Decoração da vila (V5a do Mundo V2): chafariz, bandeirolas, estandarte, banco, canteiro, jardineira,
varal, pilha de lenha, poço e barracas de mercado.

Contrato igual ao de modelos.py: `(semente, **opcoes) -> Modelo`, origem no chão centrada, faces para
fora, grupos de cor (o Roblox repinta por grupo), < ~2.500 triângulos. Medidas em studs (avatar = 5).
Convenção de frente: peças com frente definida (banco, jardineira, estandarte, barracas, varal) são
modeladas com a frente em -Y e `espelhar_y = True`, como predios.py: no Roblox a frente fica em +Z local.
"""
import math
import random

import formas
from geom import bloco_radial, caixa, catenaria, pano, prisma, lamina_radial, segmento_anel, torno, tri, tronco, extruir  # noqa: F401
from lib import Modelo
from mathutils import Vector

TAU = math.tau
PI = math.pi

MADEIRA = (128, 92, 60)
MADEIRA_ESCURA = (92, 66, 44)
PEDRA = (126, 124, 118)
PEDRA_CLARA = (164, 160, 148)
CORDA = (176, 148, 100)


def _g(m, nome, cor, material="Plastic"):
    return m.grupo(nome, cor, material)


def _flor(m, base, alt, grupo, rng, tamanho=0.3):
    """Flor low-poly: talo fino, corola de seis pétalas (cone achatado) e miolo amarelo."""
    bx, by, bz = base
    topo = (bx + rng.uniform(-0.1, 0.1), by + rng.uniform(-0.1, 0.1), bz + alt)
    Modelo.ramo(m.grupos["Talo"]["bm"], base, topo, 0.05, 0.04, 4)
    Modelo.cilindro(m.grupos[grupo]["bm"], (topo[0], topo[1], topo[2] + 0.04), tamanho, 0.16, 6, tamanho * 0.5, tampas=True, giro_z=rng.random())
    Modelo.cilindro(m.grupos["Miolo"]["bm"], (topo[0], topo[1], topo[2] + 0.15), 0.11, 0.08, 5, 0.08, tampas=True)


def _grupos_flores(m):
    _g(m, "Talo", (70, 120, 58), "Grass")
    _g(m, "Folhas", (52, 112, 56), "Grass")
    _g(m, "FolhasClaras", (112, 168, 74), "Grass")
    _g(m, "Flor1", (214, 84, 112), "Plastic")
    _g(m, "Flor2", (238, 206, 92), "Plastic")
    _g(m, "Flor3", (156, 116, 206), "Plastic")
    _g(m, "Miolo", (244, 204, 84), "Plastic")


# ======================================================================================
def chafariz(semente, **_):
    """Chafariz de pedra para a praça: plataforma e bacia de 12 lados com muro de blocos alternados, coluna,
    taça superior, esguicho e cortinas de água (~10,4 x 10,4 x 7,6). Grupo `Agua` = superfícies e jatos de água."""
    rng = random.Random(semente * 7 + 3)
    m = Modelo("Chafariz")
    pedra = _g(m, "Pedra", PEDRA, "Slate")
    clara = _g(m, "PedraClara", PEDRA_CLARA, "Slate")
    musgo = _g(m, "Musgo", (84, 122, 60), "Grass")
    agua = _g(m, "Agua", (92, 176, 204), "Glass")
    N, g0 = 12, PI / 12
    # plataforma, piso e água da bacia
    torno(pedra, [(0, 0), (5.2, 0), (5.2, 0.4), (0, 0.4)], N, g0)
    torno(pedra, [(0, 0.4), (4.3, 0.4), (4.3, 0.9), (0, 0.9)], N, g0)
    torno(agua, [(0, 0.8), (4.1, 0.8), (4.1, 1.3), (0, 1.3)], N, g0)
    # muro da bacia: 12 blocos alternados com tampas em tom oposto
    for k in range(N):
        ang = k * TAU / N
        a, b = (pedra, clara) if k % 2 == 0 else (clara, pedra)
        segmento_anel(a, 3.85, 4.65, ang, 0.4, 1.7, N)
        segmento_anel(b, 3.7, 4.85, ang, 1.7, 1.94, N)
    # quatro pilaretes com bola, nos pontos cardeais
    for k in range(0, N, 3):
        ang = k * TAU / N
        bloco_radial(pedra, 4.3, ang, 0.85, 0.85, 2.54, 1.2)
        px, py = 4.3 * math.cos(ang), 4.3 * math.sin(ang)
        Modelo.esfera(clara, (px, py, 3.3), 0.52, (1, 1, 1.0), 1)
    # coluna central e taça
    torno(pedra, [(0, 0.9), (1.6, 0.9), (1.6, 1.25), (1.15, 1.55), (0.9, 1.9), (0.9, 3.0), (1.25, 3.15), (1.25, 3.45), (0, 3.45)], N, g0)
    torno(clara, [(0, 3.4), (0.8, 3.4), (2.55, 4.15), (2.85, 4.55), (2.85, 4.8), (2.4, 4.8), (2.4, 4.5), (0, 3.98)], N, g0)
    torno(agua, [(0, 4.3), (2.39, 4.3), (2.39, 4.64), (0, 4.64)], N, g0)
    # haste, botão e jato
    torno(clara, [(0, 4.3), (0.45, 4.3), (0.32, 5.3), (0.55, 5.45), (0.55, 5.75), (0.3, 6.0), (0, 6.2)], 8)
    torno(agua, [(0, 6.0), (0.22, 6.0), (0.17, 7.0), (0.06, 7.45), (0, 7.6)], 6)
    # arcos curtos do jato à taça e lâminas de água que transbordam da taça para a bacia
    for k in range(6):
        ang = k * TAU / 6 + 0.2
        pts = []
        for i in range(7):
            t = i / 6
            r = 1.5 * t
            z = 7.0 + 0.5 * 4 * t * (1 - t) - 2.2 * t
            pts.append((r * math.cos(ang), r * math.sin(ang), z))
        tronco(agua, pts, [0.07] * 7, 4)
    for k in range(12):
        ang = k * TAU / 12 + PI / 12
        lamina_radial(agua, ang, 2.9, 4.55, 3.2, 1.25, 0.42, 0.07)
    # musgo nas tampas
    for ang in (0.5, 2.2, 3.7, 5.1):
        Modelo.esfera(musgo, (4.3 * math.cos(ang), 4.3 * math.sin(ang), 1.98), 0.5, (1.4, 0.8, 0.25), 1, 0.1, rng)
    Modelo.esfera(musgo, (2.9, 0.0, 1.05), 0.45, (0.5, 1.0, 1.0), 1, 0.1, rng)
    return m


# ======================================================================================
PALETAS_PANO = {
    1: ((192, 60, 52), (232, 186, 74), (238, 226, 196)),
    2: ((54, 112, 172), (70, 176, 176), (240, 238, 228)),
    3: ((64, 134, 80), (232, 198, 74), (152, 54, 86)),
}


def _pal(semente):
    return PALETAS_PANO[(semente - 1) % 3 + 1]


def _mastro(m, x, alt, base=True):
    mastro, pedra, ouro = m.grupos["Mastro"]["bm"], m.grupos["Pedra"]["bm"], m.grupos["Ouro"]["bm"]
    if base:
        caixa(pedra, (x, 0, 0.3), (1.3, 1.3, 0.6))
        Modelo.cilindro(pedra, (x, 0, 0.75), 0.55, 0.3, 6, 0.42, tampas=True)
    tronco(mastro, [(x, 0, 0.7), (x, 0, alt * 0.5), (x, 0, alt)], [0.36, 0.28, 0.2], 6)
    Modelo.cilindro(ouro, (x, 0, alt * 0.62), 0.33, 0.14, 6, 0.33, tampas=True)
    Modelo.esfera(ouro, (x, 0, alt + 0.2), 0.27, (1, 1, 1.15), 1)


def bandeirolas(semente, **_):
    """Cordão de bandeirinhas triangulares entre dois postes (vão de 16 studs, eixo X, poste a 8,6 de altura)
    com galhardetes nos topos. A `semente` 1, 2 ou 3 escolhe a combinação de cores (Pano1..Pano3)."""
    rng = random.Random(semente)
    pal = _pal(semente)
    m = Modelo(f"Bandeirolas{semente}")
    _g(m, "Mastro", MADEIRA_ESCURA, "Wood")
    _g(m, "Pedra", PEDRA, "Slate")
    _g(m, "Ouro", (214, 172, 72), "Metal")
    corda = _g(m, "Corda", CORDA, "Fabric")
    for i, c in enumerate(pal):
        _g(m, f"Pano{i + 1}", c, "Fabric")
    vao, zc, flecha = 16.0, 8.1, 1.6
    for s in (-1, 1):
        x = s * vao / 2
        _mastro(m, x, 8.8)
        tronco(m.grupos["Mastro"]["bm"], [(x, 0, 7.95), (x - s * 0.5, 0, 8.05), (x - s * 0.9, 0, 8.1)], [0.1, 0.09, 0.08], 4)
        # galhardete no topo, voando para dentro
        tri(m.grupos["Pano1"]["bm"], (x - s * 0.18, 0, 8.7), (x - s * 0.18, 0, 8.28), (x - s * 2.2, 0.28 * s, 8.62), (0, 0.05, 0))
    ponto_a, ponto_b = (-vao / 2 + 0.9, 0, zc), (vao / 2 - 0.9, 0, zc)
    tronco(corda, catenaria(ponto_a, ponto_b, flecha, 24), [0.065] * 25, 4)
    n = 17
    comp = ponto_b[0] - ponto_a[0]

    def z_cordao(x):
        t = (x - ponto_a[0]) / comp
        return zc - flecha * 4 * t * (1 - t)
    for i in range(n):
        xi = ponto_a[0] + comp * (i + 0.5) / n
        w = 0.4
        queda = 1.15 + rng.uniform(-0.08, 0.1)
        flut = 0.14 * math.sin(i * 2.1 + semente)
        a, b = (xi - w, 0, z_cordao(xi - w) - 0.03), (xi + w, 0, z_cordao(xi + w) - 0.03)
        ponta = (xi + rng.uniform(-0.06, 0.06), flut, z_cordao(xi) - queda)
        tri(m.grupos[f"Pano{i % 3 + 1}"]["bm"], a, b, ponta, (0, 0.05, 0))
    return m


def estandarte(semente, **_):
    """Estandarte vertical num poste de 9 studs com travessa, bola dourada e faixa ondulada em ponta, emblema
    de losango nas duas faces e borda (~3,6 x 1,4 x 9,6). Frente em -Y (+Z no Roblox). Semente 1-3 escolhe a cor."""
    cores = {1: ((150, 40, 64), (216, 172, 72)), 2: ((46, 94, 154), (238, 228, 196)), 3: ((58, 114, 76), (216, 172, 72))}[(semente - 1) % 3 + 1]
    m = Modelo(f"Estandarte{semente}")
    m.espelhar_y = True
    mastro = _g(m, "Mastro", MADEIRA_ESCURA, "Wood")
    _g(m, "Pedra", PEDRA, "Slate")
    ouro = _g(m, "Ouro", (214, 172, 72), "Metal")
    pan = _g(m, "Pano", cores[0], "Fabric")
    borda = _g(m, "Borda", cores[1], "Fabric")
    emb = _g(m, "Emblema", cores[1], "Fabric")
    ped = m.grupos["Pedra"]["bm"]
    caixa(ped, (0, 0, 0.3), (1.7, 1.7, 0.6))
    caixa(ped, (0, 0, 0.85), (1.2, 1.2, 0.5))
    tronco(mastro, [(0, 0, 1.0), (0, 0, 5.0), (0, 0, 9.0)], [0.3, 0.26, 0.2], 6)
    caixa(mastro, (0, 0, 8.25), (3.5, 0.26, 0.26))
    for s in (-1, 1):
        Modelo.esfera(ouro, (s * 1.78, 0, 8.25), 0.24, subdiv=1)
    Modelo.ramo(ouro, (0, 0, 8.95), (0, 0, 10.0), 0.2, 0.01, 6)
    # faixa: largura 2,6 que vira bico, ondulada
    zs = [8.0 - 0.45 * i for i in range(11)]  # 8,0 .. 3,5
    W, ztaper, zfim = 2.5, 5.6, 2.9
    YB = -0.42  # a faixa pende à frente do poste, presa à travessa por quatro argolas

    def larg(z):
        return W if z >= ztaper else max(W * (z - zfim) / (ztaper - zfim), 0.05)
    pano(pan, 0, larg, zs, YB, 0.08, 0.2, 0.3, 1.1, ponta=zfim, k_amp=0.45)
    pano(borda, 0, larg, zs, YB, 0.14, 0.2, 0.3, 1.1, u=(-0.5, -0.5 + 0.1), ponta=None, k_amp=0.45)
    pano(borda, 0, larg, zs, YB, 0.14, 0.2, 0.3, 1.1, u=(0.5 - 0.1, 0.5), ponta=None, k_amp=0.45)
    # faixa superior (bainha) e emblema de losango
    pano(borda, 0, W, [8.0, 7.7, 7.45], YB, 0.16, 0.0)
    for x in (-0.95, 0.0, 0.95):
        caixa(borda, (x, YB / 2, 8.1), (0.36, abs(YB) + 0.2, 0.34))
    zc = 6.35
    zs_e = [zc + 0.95 - 0.32 * i for i in range(7)]
    pano(emb, 0, lambda z: max(1.15 * (1 - abs(z - zc) / 0.95), 0.05), zs_e, YB, 0.2, 0.2, 0.3, 1.1, k_amp=0.45)
    return m


# ======================================================================================
def banco(semente, **_):
    """Banco de praça: apoios laterais de pedra com braços e bolas, assento de quatro tábuas e encosto
    inclinado de três (~5,6 x 2,0 x 3,5). Frente em -Y (+Z no Roblox)."""
    m = Modelo("Banco")
    m.espelhar_y = True
    pedra = _g(m, "Pedra", PEDRA, "Slate")
    clara = _g(m, "PedraClara", PEDRA_CLARA, "Slate")
    mad = _g(m, "Madeira", (148, 106, 66), "WoodPlanks")
    esc = _g(m, "MadeiraEscura", (112, 80, 52), "WoodPlanks")
    ferro = _g(m, "Ferro", (54, 52, 54), "Metal")
    for s in (-1, 1):
        x = s * 2.45
        caixa(pedra, (x, 0, 0.17), (0.95, 1.95, 0.34))
        caixa(pedra, (x, -0.72, 1.4), (0.75, 0.52, 2.2))
        caixa(pedra, (x, 0.72, 1.75), (0.75, 0.52, 2.9))
        caixa(pedra, (x, 0.0, 1.0), (0.6, 1.0, 0.4))
        caixa(clara, (x, -0.2, 2.62), (0.85, 1.85, 0.26))
        Modelo.esfera(clara, (x, 0.72, 3.45), 0.45, subdiv=1)
        Modelo.esfera(clara, (x, -0.72, 2.75), 0.34, subdiv=1)
    for i, y in enumerate((-0.68, -0.22, 0.24, 0.7)):
        caixa(mad if i % 2 == 0 else esc, (0, y, 1.62), (4.9, 0.4, 0.2))
    inc = math.radians(-12)
    for i, z in enumerate((2.3, 2.78, 3.26)):
        caixa(mad if i % 2 == 0 else esc, (0, 0.78 + (z - 2.3) * 0.2, z), (4.9, 0.17, 0.4), (inc, 0, 0))
    for s in (-1, 1):
        caixa(ferro, (s * 2.1, -0.5, 1.5), (0.14, 0.2, 0.14))
        caixa(ferro, (s * 2.1, 0.5, 1.5), (0.14, 0.2, 0.14))
    return m


def canteiro(semente, **_):
    """Canteiro elevado de flores: moldura de madeira (tábuas em dois tons, quatro postes), terra, folhagem e
    flores de três cores (~5,2 x 3,2 x 2,8)."""
    rng = random.Random(semente * 9 + 4)
    m = Modelo("Canteiro")
    mad = _g(m, "Madeira", (146, 104, 66), "WoodPlanks")
    esc = _g(m, "MadeiraEscura", (100, 72, 46), "WoodPlanks")
    terra = _g(m, "Terra", (86, 64, 46), "Ground")
    _grupos_flores(m)
    L, W = 5.0, 3.0
    for i, z in enumerate((0.31, 0.93)):
        alvo = mad if i == 0 else esc
        for s in (-1, 1):
            caixa(alvo, (0, s * (W / 2 - 0.14), z), (L, 0.28, 0.62))
            caixa(alvo, (s * (L / 2 - 0.14), 0, z), (0.28, W - 0.56, 0.62))
    for sx in (-1, 1):
        for sy in (-1, 1):
            caixa(esc, (sx * (L / 2 - 0.2), sy * (W / 2 - 0.2), 0.75), (0.42, 0.42, 1.5))
            caixa(mad, (sx * (L / 2 - 0.2), sy * (W / 2 - 0.2), 1.57), (0.56, 0.56, 0.14))
    caixa(terra, (0, 0, 0.55), (L - 0.56, W - 0.56, 1.1))
    for x, y in ((-1.4, 0.2), (0.3, -0.3), (1.5, 0.35)):
        Modelo.esfera(terra, (x, y, 1.05), 0.9, (1.5, 1.0, 0.3), 1, 0.12, rng)
    cx = (-1.8, -0.9, 0.0, 0.9, 1.8)
    cy = (-0.75, 0.0, 0.75)
    grupos_flor = ("Flor1", "Flor2", "Flor3")
    n_flor = 0
    for ix, x in enumerate(cx):
        for iy, y in enumerate(cy):
            px, py = x + rng.uniform(-0.2, 0.2), y + rng.uniform(-0.15, 0.15)
            if (ix + iy * 2) % 3 == 0:
                alvo = m.grupos["FolhasClaras" if rng.random() < 0.4 else "Folhas"]["bm"]
                Modelo.esfera(alvo, (px, py, 1.25), 0.5 + rng.random() * 0.2, (1, 1, 0.85), 1, 0.15, rng, corte_z=1.0)
            else:
                for _k in range(2):
                    _flor(m, (px + _k * rng.uniform(0.25, 0.4), py + _k * rng.uniform(-0.3, 0.3), 1.1), 0.7 + rng.random() * 0.7, grupos_flor[n_flor % 3], rng)
                    n_flor += 1
    return m


def jardineira(semente, **_):
    """Jardineira de janela (4,4 x 1,1 x 1,9): caixa de madeira com cintas, folhagem, flores e hera caída na
    frente (-Y); as duas mãos-francesas apoiam na parede, no lado +Y (encosto). A base da caixa fica a 0,6 do pé do modelo."""
    rng = random.Random(semente * 3 + 2)
    m = Modelo("Jardineira")
    m.espelhar_y = True
    mad = _g(m, "Madeira", (146, 104, 66), "WoodPlanks")
    esc = _g(m, "MadeiraEscura", (100, 72, 46), "WoodPlanks")
    ferro = _g(m, "Ferro", (54, 52, 54), "Metal")
    terra = _g(m, "Terra", (86, 64, 46), "Ground")
    _grupos_flores(m)
    L, P, H, z0 = 4.2, 0.95, 0.9, 0.6
    caixa(esc, (0, 0, z0 + 0.06), (L, P, 0.12))
    caixa(mad, (0, -P / 2 + 0.06, z0 + H * 0.25 + 0.06), (L, 0.12, H * 0.5))
    caixa(esc, (0, -P / 2 + 0.06, z0 + H * 0.75 + 0.02), (L, 0.12, H * 0.46))
    caixa(mad, (0, P / 2 - 0.06, z0 + H / 2), (L, 0.12, H))
    for s in (-1, 1):
        caixa(mad, (s * (L / 2 - 0.07), 0, z0 + H / 2), (0.14, P, H))
        caixa(ferro, (s * 1.2, -P / 2 - 0.02, z0 + H / 2), (0.16, 0.06, H + 0.04))
        # mão-francesa: viga horizontal na parede e escora diagonal
        caixa(esc, (s * 1.5, 0.0, z0 - 0.1), (0.16, P + 0.1, 0.16))
        caixa(esc, (s * 1.5, P / 2 + 0.05, z0 - 0.3), (0.16, 0.16, 0.6))
        caixa(esc, (s * 1.5, 0.2, z0 - 0.3), (0.14, 0.14, 0.9), (math.radians(40), 0, 0))
    caixa(terra, (0, 0, z0 + H - 0.14), (L - 0.4, P - 0.3, 0.3))
    for i in range(5):
        x = -1.7 + i * 0.85 + rng.uniform(-0.12, 0.12)
        alvo = m.grupos["FolhasClaras" if i % 2 else "Folhas"]["bm"]
        Modelo.esfera(alvo, (x, rng.uniform(-0.05, 0.1), z0 + H + 0.05), 0.4 + rng.random() * 0.12, (1, 1, 0.8), 1, 0.15, rng, corte_z=z0 + H - 0.2)
    for i in range(8):
        x = -1.8 + i * 0.52 + rng.uniform(-0.1, 0.1)
        _flor(m, (x, rng.uniform(-0.1, 0.15), z0 + H - 0.1), 0.65 + rng.random() * 0.5, ("Flor1", "Flor2", "Flor3")[i % 3], rng, 0.27)
    # hera caída pela frente: talo e folhas achatadas em dois verdes
    for x in (-1.6, -0.5, 0.8, 1.7):
        pts = [(x, -0.3, z0 + H), (x + 0.04, -P / 2 - 0.14, z0 + H - 0.1), (x - 0.06, -P / 2 - 0.2, z0 + H - 0.55), (x + 0.04, -P / 2 - 0.16, z0 + 0.12)]
        tronco(m.grupos["Talo"]["bm"], pts, [0.05, 0.05, 0.045, 0.04], 4)
        for i, t in enumerate((0.2, 0.4, 0.6, 0.8, 0.98)):
            seg = min(int(t * 3), 2)
            f = t * 3 - seg
            p = [pts[seg][k] * (1 - f) + pts[seg + 1][k] * f for k in range(3)]
            alvo = m.grupos["Folhas" if i % 2 else "FolhasClaras"]["bm"]
            Modelo.esfera(alvo, (p[0] + (0.12 if i % 2 else -0.12), p[1] - 0.06, p[2]), 0.2, (1.0, 0.55, 1.15), 0)
    return m


# ======================================================================================
def _peca_roupa(m, tipo, grupo, x, y, zt):
    """Peça pendurada pelo topo em (x, y, zt): camisa, calça, vestido ou meia. Fina em Y, de frente para -Y."""
    g = m.grupos[grupo]["bm"]
    peg = m.grupos["Pregador"]["bm"]
    e = 0.09
    if tipo == "camisa":
        caixa(g, (x, y, zt - 0.62), (0.95, e, 1.15))
        for s in (-1, 1):
            caixa(g, (x + s * 0.68, y, zt - 0.3), (0.62, e, 0.3), (0, s * 0.55, 0))
    elif tipo == "calca":
        caixa(g, (x, y, zt - 0.22), (0.92, e, 0.44))
        for s in (-1, 1):
            caixa(g, (x + s * 0.23, y, zt - 0.88), (0.42, e, 1.2), (0, s * 0.05, 0))
    elif tipo == "vestido":
        prisma(g, [(x - 0.32, zt), (x + 0.32, zt), (x + 0.78, zt - 1.9), (x - 0.78, zt - 1.9)], "Y", y - e / 2, y + e / 2)
        for s in (-1, 1):
            caixa(g, (x + s * 0.22, y, zt + 0.14), (0.12, e, 0.4))
    elif tipo == "meia":
        caixa(g, (x, y, zt - 0.38), (0.3, e, 0.75))
        caixa(g, (x + 0.08, y, zt - 0.8), (0.42, e, 0.28))
    largura = {"camisa": 0.3, "calca": 0.3, "vestido": 0.24, "meia": 0.1}[tipo]
    for s in (-1, 1):
        caixa(peg, (x + s * largura, y, zt + 0.02), (0.1, 0.16, 0.34))


def varal(semente, **_):
    """Varal entre dois postes com travessa (vão de 13 studs, eixo X): dois cordões com camisas, calça, vestido,
    meias e um lençol ondulado; cesto de roupa no chão (~14,6 x 3,4 x 6,6). Frente em -Y (+Z no Roblox)."""
    rng = random.Random(semente * 5 + 1)
    m = Modelo("Varal")
    m.espelhar_y = True
    mastro = _g(m, "Mastro", MADEIRA_ESCURA, "Wood")
    _g(m, "Pedra", PEDRA, "Slate")
    corda = _g(m, "Corda", CORDA, "Fabric")
    _g(m, "Pregador", (150, 108, 68), "Wood")
    _g(m, "RoupaA", (66, 112, 170), "Fabric")
    _g(m, "RoupaB", (182, 66, 62), "Fabric")
    _g(m, "RoupaC", (236, 228, 204), "Fabric")
    _g(m, "RoupaD", (112, 100, 72), "Fabric")
    _g(m, "RoupaE", (224, 176, 70), "Fabric")
    _g(m, "RoupaF", (96, 146, 88), "Fabric")
    cesto = _g(m, "Cesto", (190, 158, 96), "Fabric")
    vao, fl, yc = 13.0, 0.8, 0.7
    for s in (-1, 1):
        x = s * vao / 2
        caixa(m.grupos["Pedra"]["bm"], (x, 0, 0.25), (1.2, 1.2, 0.5))
        tronco(mastro, [(x, 0, 0.5), (x, 0, 3.2), (x, 0, 6.5)], [0.3, 0.25, 0.2], 6)
        caixa(mastro, (x, 0, 6.2), (0.36, 2.1, 0.3))
    for lado in (-1, 1):
        a = (-vao / 2, lado * yc, 6.2)
        b = (vao / 2, lado * yc, 6.2)
        tronco(corda, catenaria(a, b, fl, 26), [0.05] * 27, 4)

    def zc(x):
        t = (x + vao / 2) / vao
        return 6.2 - fl * 4 * t * (1 - t) - 0.02
    y_f = -yc
    pecas = [("camisa", "RoupaA", -4.8), ("camisa", "RoupaB", -3.0), ("calca", "RoupaD", -1.2), ("vestido", "RoupaE", 0.8),
             ("camisa", "RoupaF", 2.7), ("meia", "RoupaB", 4.4), ("meia", "RoupaA", 4.9)]
    for tipo, grupo, x in pecas:
        _peca_roupa(m, tipo, grupo, x, y_f, zc(x))
    # lençol atrás, ondulado, e uma camisa
    zl = zc(-2.2)
    zs = [zl - 0.3 * i for i in range(9)]
    pano(m.grupos["RoupaC"]["bm"], -2.2, 3.6, zs, yc, 0.07, 0.16, 0.5, 1.4, k_amp=0.8)
    for x in (-3.8, -0.6):
        caixa(m.grupos["Pregador"]["bm"], (x, yc, zc(x) + 0.02), (0.1, 0.16, 0.34))
    _peca_roupa(m, "camisa", "RoupaB", 3.4, yc, zc(3.4))
    # cesto com roupa
    Modelo.cilindro(cesto, (4.4, -1.9, 0.5), 0.8, 1.0, 9, 0.95, tampas=False)
    Modelo.cilindro(cesto, (4.4, -1.9, 0.04), 0.78, 0.08, 9, 0.78, tampas=True)
    Modelo.cilindro(cesto, (4.4, -1.9, 1.0), 0.97, 0.12, 9, 0.97, tampas=False)
    Modelo.esfera(m.grupos["RoupaC"]["bm"], (4.35, -1.85, 1.0), 0.75, (1.0, 0.9, 0.65), 1, 0.15, rng, corte_z=0.8)
    Modelo.esfera(m.grupos["RoupaE"]["bm"], (4.65, -2.1, 1.15), 0.4, (1.0, 0.8, 0.6), 1, 0.15, rng, corte_z=0.9)
    return m


# ======================================================================================
def lenha(semente, **_):
    """Pilha de lenha com cobertura de telhado: quatro fileiras de toras (pontas claras na frente), estacas,
    telhadinho de duas águas, e um toco com machado ao lado (~8,4 x 3,6 x 4,2). Frente em -Y (+Z no Roblox)."""
    rng = random.Random(semente * 11 + 6)
    m = Modelo("Lenha")
    m.espelhar_y = True
    c1 = _g(m, "Casca", (100, 72, 48), "Wood")
    c2 = _g(m, "CascaClara", (126, 94, 62), "Wood")
    cerne = _g(m, "Cerne", (224, 192, 146), "Wood")
    mad = _g(m, "Madeira", (118, 84, 54), "WoodPlanks")
    esc = _g(m, "MadeiraEscura", (80, 58, 40), "Wood")
    tel = _g(m, "Telhado", (150, 78, 56), "Slate")
    ferro = _g(m, "Ferro", (60, 58, 60), "Metal")
    comp, r = 2.4, 0.34
    for i in range(4):
        n = 6 if i % 2 == 0 else 5
        z = r + i * r * 1.72
        for j in range(n):
            x = (j - (n - 1) / 2) * r * 2.06
            rr = r * rng.uniform(0.92, 1.06)
            ln = comp + rng.uniform(-0.18, 0.12)
            yy = rng.uniform(-0.1, 0.1)
            Modelo.cilindro(c1 if (i + j) % 2 == 0 else c2, (x, yy, z), rr, ln, 6, eixo="Y", tampas=True, giro_z=rng.random())
            Modelo.cilindro(cerne, (x, yy - ln / 2 - 0.015, z), rr * 0.8, 0.05, 6, eixo="Y", tampas=True)
    # estacas e cobertura
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = 3.4 if sy > 0 else 3.0
            caixa(esc, (sx * 2.55, sy * 1.35, h / 2), (0.3, 0.3, h))
    for sy in (-1, 1):
        caixa(esc, (0, sy * 1.35, 3.15 if sy > 0 else 2.85), (5.4, 0.28, 0.28))
    Modelo.telhado(tel, (0, 0, 3.2), 6.0, 4.0, 1.25)
    caixa(tel, (0, 0, 4.45), (6.1, 0.4, 0.2))
    tel2 = _g(m, "TelhadoClaro", (184, 98, 68), "Slate")
    for sy in (-1, 1):
        for t in (0.3, 0.62):
            caixa(tel2, (0, sy * 2.0 * (1 - t) * 1.0, 3.2 + 1.25 * t + 0.08), (6.05, 0.14, 0.12), (-sy * math.atan(1.25 / 2.0), 0, 0))
    for sx in (-1, 1):
        caixa(mad, (sx * 2.98, 0, 3.3), (0.2, 4.0, 0.2))
    # toco com machado
    Modelo.cilindro(c1, (4.2, -0.9, 0.5), 0.78, 1.0, 8, 0.7, tampas=False)
    Modelo.cilindro(cerne, (4.2, -0.9, 1.01), 0.68, 0.05, 8, None, tampas=True)
    Modelo.ramo(mad, (4.1, -0.9, 1.0), (3.75, -0.9, 2.3), 0.07, 0.06, 5)
    caixa(ferro, (3.75, -0.98, 2.25), (0.5, 0.1, 0.38), (0, math.radians(-14), 0))
    for k, (x, y, a) in enumerate(((3.6, -2.3, 0.7), (4.4, -2.2, -0.4))):
        Modelo.cilindro(c2 if k else c1, (x, y, 0.25), 0.25, 1.3, 6, eixo="X", tampas=True, giro_z=a)
    return m


# ======================================================================================
def poco(semente, **_):
    """Poço charmoso: muro de pedra de dez lados em duas fiadas e borda clara, água, dois postes com roldana,
    manivela e balde, telhadinho de telhas vermelhas com franja, lanterna e flores (~7,4 x 6,6 x 7).
    Simétrico em X; a franja e a lanterna ficam em -Y (+Z no Roblox)."""
    rng = random.Random(semente * 13 + 2)
    m = Modelo("Poco")
    m.espelhar_y = True
    pedra = _g(m, "Pedra", PEDRA, "Slate")
    clara = _g(m, "PedraClara", PEDRA_CLARA, "Slate")
    musgo = _g(m, "Musgo", (84, 122, 60), "Grass")
    agua = _g(m, "Agua", (92, 176, 204), "Glass")
    mad = _g(m, "Madeira", (118, 84, 54), "Wood")
    esc = _g(m, "MadeiraEscura", (84, 60, 42), "Wood")
    tel = _g(m, "Telhado", (160, 76, 56), "Slate")
    tel2 = _g(m, "TelhadoClaro", (196, 108, 72), "Slate")
    ferro = _g(m, "Ferro", (58, 56, 58), "Metal")
    corda = _g(m, "Corda", CORDA, "Fabric")
    luz = _g(m, "Luz", (255, 196, 112), "Neon")
    _grupos_flores(m)
    N = 10
    torno(clara, [(0, 0), (3.3, 0), (3.3, 0.22), (0, 0.22)], N)
    torno(agua, [(0, 0.9), (1.2, 0.9), (1.2, 1.12), (0, 1.12)], N)
    for k in range(N):
        a = k * TAU / N
        d, e = (pedra, clara) if k % 2 == 0 else (clara, pedra)
        segmento_anel(d, 1.15, 2.0, a, 0.22, 1.05, N)
        segmento_anel(e, 1.15, 2.0, a + PI / N, 1.05, 1.9, N)
        segmento_anel(clara if k % 2 else pedra, 1.0, 2.15, a, 1.9, 2.1, N)
    for ang in (0.4, 2.3, 4.1):
        Modelo.esfera(musgo, (2.0 * math.cos(ang), 2.0 * math.sin(ang), 2.12), 0.4, (1.3, 0.8, 0.25), 1, 0.1, rng)
    # postes, travessa, roldana e manivela (o eixo da roldana corre em X)
    for s in (-1, 1):
        x = s * 2.55
        caixa(esc, (x, 0, 2.4), (0.42, 0.42, 4.4))
        caixa(esc, (x, 0, 4.7), (0.55, 0.55, 0.16))
        caixa(esc, (x, -0.55, 3.9), (0.2, 0.8, 0.2), (math.radians(35), 0, 0))
        caixa(esc, (x, 0.55, 3.9), (0.2, 0.8, 0.2), (math.radians(-35), 0, 0))
    caixa(esc, (0, 0, 4.45), (5.7, 0.38, 0.34))
    Modelo.cilindro(mad, (0, 0, 3.5), 0.3, 4.6, 8, eixo="X", tampas=True)
    Modelo.cilindro(mad, (-0.9, 0, 3.5), 0.4, 0.12, 8, eixo="X")
    Modelo.cilindro(mad, (0.9, 0, 3.5), 0.4, 0.12, 8, eixo="X")
    Modelo.ramo(ferro, (2.35, 0, 3.5), (2.8, 0, 3.5), 0.06, 0.06, 4)
    Modelo.ramo(ferro, (2.8, 0, 3.5), (2.8, 0, 2.85), 0.06, 0.06, 4)
    Modelo.ramo(ferro, (2.8, 0, 2.85), (3.15, 0, 2.85), 0.1, 0.1, 5)
    tronco(corda, [(0, 0, 3.25), (0, 0, 2.7), (0, 0, 2.25)], [0.045] * 3, 4)
    # balde
    Modelo.cilindro(mad, (0, 0, 1.8), 0.5, 0.75, 8, 0.4, tampas=True)
    for dz in (-0.2, 0.2):
        Modelo.cilindro(ferro, (0, 0, 1.8 + dz), 0.5 - (0.06 if dz < 0 else -0.02), 0.07, 8, None, tampas=True)
    tronco(ferro, [(-0.45, 0, 2.15), (0, 0, 2.55), (0.45, 0, 2.15)], [0.035] * 3, 4)
    # telhadinho: duas águas com cumeeira e franja escalonada nas beiradas
    Modelo.telhado(tel, (0, 0, 4.6), 6.4, 4.6, 1.9)
    caixa(tel2, (0, 0, 6.52), (6.5, 0.45, 0.28))
    for sx in (-1, 1):
        Modelo.ramo(esc, (sx * 3.25, 0, 6.4), (sx * 3.85, 0, 6.95), 0.12, 0.03, 5)
    for i in range(8):
        x = -2.8 + i * 0.8
        for sy in (-1, 1):
            tri(tel2 if i % 2 == 0 else tel, (x - 0.4, sy * 2.3, 4.62), (x + 0.4, sy * 2.3, 4.62), (x, sy * 2.3, 4.12), (0, -sy * 0.06, 0))
    # lanterna pendurada na frente do telhado
    tronco(ferro, [(0, -1.0, 4.45), (0, -1.0, 4.1)], [0.03, 0.03], 4)
    caixa(luz, (0, -1.0, 3.8), (0.4, 0.4, 0.5))
    caixa(ferro, (0, -1.0, 4.1), (0.5, 0.5, 0.1))
    caixa(ferro, (0, -1.0, 3.5), (0.5, 0.5, 0.08))
    # tufos de flores no chão, junto aos postes
    for sx in (-1, 1):
        for k in range(2):
            Modelo.esfera(m.grupos["Folhas" if k else "FolhasClaras"]["bm"], (sx * (2.7 + k * 0.2), -1.4 + k * 0.9, 0.5), 0.45, (1, 1, 0.8), 1, 0.15, rng, corte_z=0.2)
        for k in range(3):
            _flor(m, (sx * (2.5 + rng.uniform(0, 0.6)), -1.2 + rng.uniform(-0.2, 0.8), 0.2), 0.7 + rng.random() * 0.5, ("Flor1", "Flor2", "Flor3")[(k + (sx > 0)) % 3], rng, 0.26)
    return m


# ======================================================================================
def mercado(semente, variante="listrado", **_):
    """Barraca de mercado nova (~9 x 7,6 x 5,2) sobre piso de tábuas, toldo inclinado com franja recortada,
    balcão com saia de tecido, prateleiras, lanterna e placa. `variante` `listrado`: toldo em listras vermelho e
    creme, cestos de frutas e caixas. `liso`: toldo azul-petróleo com franja mostarda, potes de barro e rolos de
    tecido. Frente em -Y (+Z no Roblox)."""
    rng = random.Random(semente * 17 + 1)
    liso = variante == "liso"
    m = Modelo("MercadoLiso" if liso else "MercadoListrado")
    m.espelhar_y = True
    mad = _g(m, "Madeira", (136, 98, 62), "WoodPlanks")
    esc = _g(m, "MadeiraEscura", (96, 68, 44), "Wood")
    pa = _g(m, "PanoA", (58, 112, 138) if liso else (192, 60, 52), "Fabric")
    pb = _g(m, "PanoB", (232, 206, 142) if liso else (238, 226, 196), "Fabric")
    ferro = _g(m, "Ferro", (58, 56, 58), "Metal")
    luz = _g(m, "Luz", (255, 196, 112), "Neon")
    W, D = 8.4, 6.4
    zf, zb = 4.1, 5.1  # altura do toldo na frente e atrás
    yf, yb = -D / 2 - 1.2, D / 2 + 0.2
    caixa(esc, (0, 0, 0.1), (W + 0.6, D + 0.6, 0.2))
    caixa(mad, (0, 0, 0.23), (W + 0.2, D + 0.2, 0.06))
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = zf if sy < 0 else zb - 0.2
            caixa(esc, (sx * (W / 2 - 0.2), sy * (D / 2 - 0.25), h / 2 + 0.1), (0.36, 0.36, h))
    caixa(esc, (0, -D / 2 + 0.25, zf - 0.15), (W, 0.34, 0.34))
    caixa(esc, (0, D / 2 - 0.25, zb - 0.15), (W, 0.34, 0.34))
    # toldo: faixas inclinadas e franja recortada
    n = 9
    larg = (W + 0.8) / n
    inc = math.atan((zb - zf) / (yb - yf))
    lng = math.hypot(yb - yf, zb - zf)
    for i in range(n):
        x = -(W + 0.8) / 2 + larg * (i + 0.5)
        if liso:
            alvo = pb if i in (0, n - 1) else pa
        else:
            alvo = pa if i % 2 == 0 else pb
        caixa(alvo, (x, (yf + yb) / 2, (zf + zb) / 2 + 0.07), (larg * 0.999, lng, 0.14), (inc, 0, 0))
        franja = (pa if i % 2 == 0 else pb) if not liso else (pb if i % 2 == 0 else pa)
        tri(franja, (x - larg / 2, yf + 0.02, zf - 0.05), (x + larg / 2, yf + 0.02, zf - 0.05), (x, yf + 0.02, zf - 0.8), (0, 0.07, 0))
    caixa(esc, (0, yf + 0.1, zf - 0.0), (W + 1.0, 0.12, 0.14))
    # balcão com tampo e saia de tecido
    yc = -D / 2 + 1.1
    caixa(mad, (0, yc, 0.7), (W - 0.8, 1.5, 1.0))
    caixa(esc, (0, yc, 1.25), (W - 0.4, 1.8, 0.14))
    zs = [1.1 - 0.22 * i for i in range(4)]
    pano(pa if not liso else pb, 0, W - 1.0, zs, yc - 0.82, 0.06, 0.07, 0.4, 2.2, k_amp=1.5)
    # fundo e prateleiras
    caixa(mad, (0, D / 2 - 0.15, 2.6), (W - 0.5, 0.12, 4.6))
    for i, x in enumerate((-3.0, -1.0, 1.0, 3.0)):
        caixa(esc if i % 2 else mad, (x, D / 2 - 0.22, 2.6), (1.9, 0.08, 4.4))
    for z in (1.6, 2.7):
        caixa(mad, (0, D / 2 - 0.65, z), (W - 0.8, 0.8, 0.14))
    # placa pendurada, lanterna
    for dx in (-0.6, 0.6):
        tronco(ferro, [(2.6 + dx, yf + 0.1, zf - 0.02), (2.6 + dx, yf + 0.1, zf - 0.55)], [0.025, 0.025], 4)
    caixa(mad, (2.6, yf + 0.1, zf - 0.95), (1.7, 0.12, 0.8))
    caixa(esc, (2.6, yf + 0.1, zf - 0.95), (1.85, 0.1, 0.18))
    tronco(ferro, [(-3.2, yf + 0.3, zf - 0.02), (-3.2, yf + 0.3, zf - 0.6)], [0.03, 0.03], 4)
    caixa(luz, (-3.2, yf + 0.3, zf - 1.0), (0.4, 0.4, 0.55))
    caixa(ferro, (-3.2, yf + 0.3, zf - 0.68), (0.5, 0.5, 0.1))
    caixa(ferro, (-3.2, yf + 0.3, zf - 1.3), (0.5, 0.5, 0.08))
    if not liso:
        fa = _g(m, "FrutasA", (200, 54, 46), "SmoothPlastic")
        fb = _g(m, "FrutasB", (234, 150, 52), "SmoothPlastic")
        fc = _g(m, "FrutasC", (132, 172, 66), "SmoothPlastic")
        cesto = _g(m, "Cesto", (190, 158, 96), "Fabric")
        saco = _g(m, "Saco", (198, 172, 122), "Fabric")
        caixa_c = _g(m, "Caixas", (150, 108, 68), "WoodPlanks")
        Modelo.esfera(fa, (2.6, yf + 0.0, zf - 0.95), 0.27, (1, 0.35, 1), 1)  # maçã pintada na placa
        for k, (x, g) in enumerate(((-2.5, fa), (0.0, fb), (2.5, fc))):
            Modelo.cilindro(cesto, (x, yc, 1.52), 0.72, 0.42, 8, 0.82, tampas=True)
            base = 1.74
            for a in range(6):
                ang = a * TAU / 6 + 0.3
                Modelo.esfera(g, (x + 0.38 * math.cos(ang), yc + 0.38 * math.sin(ang), base + 0.12), 0.27, subdiv=0)
            for a in range(3):
                ang = a * TAU / 3 + 0.9
                Modelo.esfera(g, (x + 0.2 * math.cos(ang), yc + 0.2 * math.sin(ang), base + 0.42), 0.27, subdiv=0)
            Modelo.esfera(g, (x, yc, base + 0.66), 0.27, subdiv=0)
        for x, g in ((-3.0, fa), (3.0, fb)):
            caixa(caixa_c, (x, D / 2 - 1.4, 0.7), (1.3, 1.3, 0.9), (0, 0, 0.15 if x < 0 else -0.2))
            for a in range(5):
                ang = a * TAU / 5
                Modelo.esfera(g, (x + 0.35 * math.cos(ang), D / 2 - 1.4 + 0.35 * math.sin(ang), 1.2), 0.26, subdiv=0)
        for x in (-2.0, 2.0):
            Modelo.esfera(saco, (x, D / 2 - 1.0, 0.55), 0.62, (1.0, 0.9, 0.85), 1, 0.1, rng, corte_z=0.2)
        for k in range(3):
            caixa(caixa_c, (-3.2 + k * 3.2, D / 2 - 0.65, 2.0), (0.8, 0.5, 0.5), (0, 0, rng.uniform(-0.15, 0.15)))
    else:
        barro = _g(m, "Barro", (176, 104, 72), "SmoothPlastic")
        barro2 = _g(m, "BarroAzul", (82, 116, 150), "SmoothPlastic")
        t1 = _g(m, "Tecido1", (170, 56, 74), "Fabric")
        t2 = _g(m, "Tecido2", (232, 196, 84), "Fabric")
        t3 = _g(m, "Tecido3", (76, 140, 110), "Fabric")
        jarro = [(0, 0), (0.34, 0), (0.5, 0.3), (0.46, 0.55), (0.28, 0.72), (0.3, 0.84), (0, 0.84)]
        for k, x in enumerate((-3.0, -1.8, -0.6, 0.6, 1.8, 3.0)):
            esc_j = 0.8 + 0.18 * ((k * 5) % 3)
            torno((barro if k % 2 == 0 else barro2), [(r * esc_j, z * esc_j) for r, z in jarro], 8, centro=(x, yc + rng.uniform(-0.2, 0.2), 1.32))
        torno(barro2, [(r * 1.6, z * 1.5) for r, z in jarro], 8, centro=(-3.4, D / 2 - 1.3, 0.2))
        for k, x in enumerate((-3.0, -1.5, 0.0, 1.5, 3.0)):
            torno(barro if k % 2 else barro2, [(r * 0.9, z * 0.9) for r, z in jarro], 8, centro=(x, D / 2 - 0.65, 1.67))
        for k, g in enumerate((t1, t2, t3, t2, t1)):
            Modelo.cilindro(g, (-3.0 + k * 1.5, D / 2 - 0.65, 3.0), 0.28, 1.3, 8, eixo="X", tampas=True)
        for k, g in enumerate((t3, t1, t2)):
            Modelo.cilindro(g, (2.7, D / 2 - 1.4, 0.3 + k * 0.5), 0.26, 1.7, 8, eixo="X", tampas=True)
        Modelo.esfera(barro, (2.6, yf + 0.0, zf - 0.95), 0.28, (1, 0.3, 1.0), 1)  # pote pintado na placa
    return m


GERADORES = {
    "chafariz": chafariz,
    "bandeirolas": bandeirolas,
    "estandarte": estandarte,
    "banco": banco,
    "canteiro": canteiro,
    "jardineira": jardineira,
    "varal": varal,
    "lenha": lenha,
    "poco": poco,
    "mercado": mercado,
}
