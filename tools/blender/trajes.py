"""Trajes únicos dos dois treinadores (V5b do Mundo V2): Ladino (Furtividade) e Mestra da Água.

Cada peça é um ACESSÓRIO que será soldado a uma parte do corpo R15 de 5 studs; a ORIGEM DO MODELO É O PONTO
DE ENCAIXE (`manter_origem`: o pipeline não recentra nem apoia no chão). Convenção autoral:
  Z para cima, o personagem olha para -Y, a mão direita dele fica em -X (como na vista frontal do Blender).
  O Roblox recebe (x, y, z) -> (-x, z, y): a frente do personagem vira -Z, as costas +Z, a direita +X.
`ENCAIXES` guarda, por peça, a parte do corpo e o CFrame de encaixe (offset em studs, em eixos do ROBLOX,
relativo ao CENTRO da parte). R15 simplificado de 5 studs (centros em studs, personagem de pé em y=0):
Head 4,6 (cubo ~1,2) | UpperTorso 3,2 (2 x 1,6 x 1) | LowerTorso 2,2 (2 x 0,4 x 1) | RightHand x=+1,5 y=1,55.
Sem espelhar_y (os trajes são assimétricos: o espelhamento inverteria direita e esquerda).
"""
import math
import random

from geom import caixa, catenaria, extruir, pano, pano_y, prisma, torno, torno_arco, tri, tronco  # noqa: F401
from lib import Modelo
from mathutils import Vector

PI = math.pi

# parte R15 -> centro no Roblox (x, y, z) do boneco de prévia
R15_CENTROS = {
    "Head": (0.0, 4.6, 0.0),
    "UpperTorso": (0.0, 3.2, 0.0),
    "LowerTorso": (0.0, 2.2, 0.0),
    "RightHand": (1.5, 1.55, 0.0),
}

# peça -> (parte do corpo, offset do encaixe em eixos do Roblox relativo ao centro da parte)
ENCAIXES = {
    "ladinocapuz": ("Head", (0.0, 0.0, 0.0)),
    "ladinocapa": ("UpperTorso", (0.0, 0.8, 0.5)),
    "ladinomascara": ("Head", (0.0, 0.0, 0.0)),
    "ladinocinto": ("LowerTorso", (0.0, 0.0, 0.0)),
    "mestratiara": ("Head", (0.0, 0.0, 0.0)),
    "mestramanto": ("UpperTorso", (0.0, 0.8, 0.5)),
    "mestracajado": ("RightHand", (0.0, -0.1, -0.3)),
    "mestraobi": ("LowerTorso", (0.0, 0.0, 0.0)),
}


def posicao_autoral(peca):
    """Onde a origem da peça cai no mundo AUTORAL (x, y, z) com o boneco de prévia na pose parada."""
    parte, (dx, dy, dz) = ENCAIXES[peca]
    cx, cy, cz = R15_CENTROS[parte]
    return (-(cx + dx), cz + dz, cy + dy)


# --------------------------------------------------------------------------------------
# utilidades
def _fan3d(bm, centro, yaw, R, esp, ribs=None, rib_esp=None, roll=0.0):
    """Leque de concha em pé: base estreita, arco de 140 graus; `yaw` gira em torno de Z (0 = voltado a -Y).
    Com `ribs` (bmesh) desenha nervuras salientes."""
    cx, cy, cz = centro
    direita = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    n = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
    cima = Vector((0.0, 0.0, 1.0))
    c = Vector(centro)

    cr, sr = math.cos(roll), math.sin(roll)

    def p(u, v, k=0.0):
        u, v = u * cr - v * sr, u * sr + v * cr
        return c + direita * u + cima * v + n * k
    pts = [(0.2 * R, 0.0)] + [(R * math.cos(math.radians(a)), R * math.sin(math.radians(a))) for a in range(20, 161, 20)] + [(-0.2 * R, 0.0)]
    extruir(bm, [[p(u, v, -esp / 2) for u, v in pts], [p(u, v, esp / 2) for u, v in pts]])
    if ribs is not None:
        e = rib_esp or esp * 1.6
        for a in (50, 75, 100, 125):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            la = 0.06 * R
            r0, r1 = 0.18 * R, 0.95 * R
            quad = [(r0 * ca - la * sa, r0 * sa + la * ca), (r1 * ca - la * sa, r1 * sa + la * ca),
                    (r1 * ca + la * sa, r1 * sa - la * ca), (r0 * ca + la * sa, r0 * sa - la * ca)]
            extruir(ribs, [[p(u, v, -e / 2) for u, v in quad], [p(u, v, e / 2) for u, v in quad]])


def _gota(bm, centro, esc=1.0, lados=6):
    """Gota d'água (corpo redondo, ponta para cima), com a base em `centro`."""
    perfil = [(0, 0), (0.1 * esc, 0.07 * esc), (0.16 * esc, 0.22 * esc), (0.12 * esc, 0.36 * esc), (0, 0.66 * esc)]
    torno(bm, perfil, lados, centro=centro)


def _pos_elipse(a, r, z, esc):
    return Vector((esc[0] * r * math.cos(a), esc[1] * r * math.sin(a), z))


def _adaga(m, p0, d, giro_cabo=0.0):
    """Adaga embainhada: pomo, cabo enrolado, guarda, um pedaço de lâmina e bainha de couro até a ponta.
    `p0` = topo do cabo; `d` = direção unitária (XZ) da ponta."""
    d = Vector(d).normalized()
    p0 = Vector(p0)
    vinho, cabo, aco, couro, ferro = (m.grupos[n]["bm"] for n in ("Vinho", "Cabo", "Aco", "Couro", "Ferro"))
    Modelo.esfera(vinho, p0, 0.11, subdiv=1)
    Modelo.ramo(cabo, p0, p0 + d * 0.5, 0.075, 0.075, 6)
    perp = Vector((-d.z, 0.0, d.x))
    guarda = p0 + d * 0.55
    ang = math.atan2(-perp.z, perp.x)
    caixa(ferro, guarda, (0.46, 0.12, 0.1), (0, ang, 0))
    Modelo.ramo(aco, p0 + d * 0.58, p0 + d * 0.9, 0.06, 0.055, 4)
    Modelo.ramo(couro, p0 + d * 0.88, p0 + d * 1.95, 0.13, 0.075, 6)
    Modelo.ramo(ferro, p0 + d * 0.86, p0 + d * 1.0, 0.145, 0.145, 6)
    Modelo.ramo(ferro, p0 + d * 1.9, p0 + d * 2.0, 0.08, 0.03, 5)


def _bolsa(m, centro, tam, flap=True):
    """Bolsinha de couro: corpo, aba com botão."""
    couro, couro2, ferro = m.grupos["Couro"]["bm"], m.grupos["CouroEscuro"]["bm"], m.grupos["Ferro"]["bm"]
    x, y, z = centro
    sx, sy, sz = tam
    caixa(couro, (x, y, z), (sx, sy, sz))
    if flap:
        caixa(couro2, (x, y - 0.02, z + sz * 0.34), (sx + 0.04, sy + 0.04, sz * 0.38))
        caixa(ferro, (x, y - sy / 2 - 0.05, z + sz * 0.16), (0.1, 0.06, 0.1))


# ======================================================================================
# LADINO (Furtividade): cinza-carvão, couro escuro, detalhe vinho
def ladino_capuz(semente, **_):
    """Capuz fundo de cinza-carvão com forro vinho, bico caído atrás, gola que cobre os ombros e bordas rasgadas.
    Aberto na frente (-Y). Origem = centro da Head. Cabe numa caixa de ~3,2 x 3,3 x 3,0 studs."""
    rng = random.Random(semente * 3 + 1)
    m = Modelo("LadinoCapuz")
    m.manter_origem = True
    tec = m.grupo("Capuz", (58, 58, 66), "Fabric")
    tec2 = m.grupo("CapuzClaro", (82, 82, 92), "Fabric")
    forro = m.grupo("Forro", (118, 34, 58), "Fabric")
    a0, a1 = math.radians(-35), math.radians(215)
    esc = (1.0, 0.95)
    IN = [(0.0, 0.98), (0.3, 0.93), (0.62, 0.74), (0.84, 0.42), (0.9, 0.0), (0.86, -0.6)]
    OUT = [(1.02, -0.6), (1.06, 0.0), (0.98, 0.45), (0.72, 0.85), (0.38, 1.08), (0.0, 1.15)]
    torno_arco(tec, OUT + IN, a0, a1, 10, esc)
    # forro vinho colado por dentro
    LIN = [(max(r - 0.07, 0.0), z - 0.05) for r, z in IN]
    torno_arco(forro, [(r * 0.985, z) for r, z in IN] + LIN[::-1], a0 + math.radians(2), a1 - math.radians(2), 10, esc)
    # gola sobre os ombros (mais larga, mais rasa em Y)
    GOLA = [(0.94, -0.42), (1.2, -0.62), (1.42, -1.0), (1.5, -1.5), (1.34, -1.5), (1.22, -1.1), (1.04, -0.72), (0.9, -0.52)]
    esc_g = (1.22, 0.78)
    a0g, a1g = math.radians(-12), math.radians(192)  # a gola cobre ombros e costas e deixa o peito livre
    torno_arco(tec2, GOLA, a0g, a1g, 9, esc_g)
    # bico caído atrás
    # rabo do capuz: cai pelas costas em ponta
    Modelo.ramo(tec, (0, 0.8, 0.75), (0, 1.2, 0.3), 0.3, 0.24, 6)
    Modelo.ramo(tec, (0, 1.18, 0.34), (0, 1.3, -0.55), 0.24, 0.02, 6)
    # bainha rasgada da gola: dentes irregulares
    n = 10
    arco = a1g - a0g
    for i in range(n):
        a = a0g + (i + 0.5) * arco / n
        da = arco / (2 * n)
        comp = 0.22 + 0.34 * ((i * 5 + 2) % 4) / 3
        ri = 1.34
        p1, p2 = _pos_elipse(a - da, ri, -1.47, esc_g), _pos_elipse(a + da, ri, -1.47, esc_g)
        p3 = _pos_elipse(a + rng.uniform(-0.04, 0.04), ri + 0.05, -1.47 - comp, esc_g)
        radial = Vector((esc_g[0] * math.cos(a), esc_g[1] * math.sin(a), 0.0)).normalized() * 0.16
        tri(tec2 if i % 2 else tec, p1, p2, p3, radial)
    return m


def ladino_capa(semente, **_):
    """Capa curta até a cintura: cinza-carvão com barra e debrum vinho, ondulada, abrindo para trás, hem rasgado.
    Origem = topo das costas da UpperTorso (centro do pescoço, rente à face de trás). ~2,8 x 0,9 x 2,3 studs."""
    rng = random.Random(semente * 5 + 2)
    m = Modelo("LadinoCapa")
    m.manter_origem = True
    capa = m.grupo("Capa", (58, 58, 66), "Fabric")
    vin = m.grupo("Vinho", (122, 34, 56), "Fabric")
    ferro = m.grupo("Ferro", (64, 62, 66), "Metal")
    nz = 7
    z_fim = -1.95
    zs = [z_fim * i / nz for i in range(nz + 1)]
    larg = lambda z: 2.3 + 0.5 * (z / z_fim)
    kw = dict(amp=0.1, fase=0.6, freq=1.5, k_amp=1.0, abre=0.09)
    y0 = 0.1
    pano(capa, 0.0, larg, zs, y0, 0.07, **kw)
    pano(vin, 0.0, larg, zs, y0 + 0.0, 0.11, u=(-0.5, -0.5 + 0.045), **kw)
    pano(vin, 0.0, larg, zs, y0 + 0.0, 0.11, u=(0.5 - 0.045, 0.5), **kw)
    pano(vin, 0.0, larg, [0.0, -0.26, -0.5], y0, 0.11, **kw)
    # bainha rasgada: dentes
    n = 8
    w = larg(z_fim)
    yb = pano_y(z_fim, 0.0, y0, kw["amp"], kw["fase"], kw["freq"], kw["k_amp"], kw["abre"])
    for i in range(n):
        x0 = -w / 2 + i * w / n
        comp = 0.18 + 0.4 * ((i * 3 + 1) % 4) / 3
        tri(vin if i % 3 == 0 else capa, (x0, yb, z_fim + 0.02), (x0 + w / n, yb, z_fim + 0.02),
            (x0 + w / n * 0.5 + rng.uniform(-0.06, 0.06), yb + 0.05, z_fim - comp), (0, 0.08, 0))
    # presilha de ferro e cordão na nuca
    caixa(ferro, (0, 0.04, -0.08), (0.46, 0.12, 0.22))
    caixa(vin, (0, 0.03, -0.08), (0.22, 0.14, 0.12))
    return m


def ladino_mascara(semente, **_):
    """Máscara de pano que cobre do nariz ao queixo, com nariz alto, abas laterais e laço atrás.
    Origem = centro da Head (frente em -Y). ~1,5 x 1,5 x 0,9 studs."""
    m = Modelo("LadinoMascara")
    m.manter_origem = True
    pano_ = m.grupo("Pano", (46, 46, 54), "Fabric")
    vin = m.grupo("Vinho", (122, 34, 56), "Fabric")
    # placa inferior e ponta do nariz
    prisma(pano_, [(-0.64, 0.0), (0.64, 0.0), (0.62, -0.38), (0.0, -0.68), (-0.62, -0.38)], "Y", -0.7, -0.62)
    prisma(pano_, [(-0.26, -0.01), (0.26, -0.01), (0.0, 0.26)], "Y", -0.68, -0.6)
    # abas laterais que contornam as bochechas
    for s in (-1, 1):
        caixa(pano_, (s * 0.65, -0.34, -0.2), (0.1, 0.62, 0.46))
        caixa(pano_, (s * 0.65, 0.12, 0.0), (0.1, 0.4, 0.14))
    # cinta atrás da cabeça e laço com pontas
    caixa(pano_, (0, 0.66, 0.0), (1.4, 0.1, 0.14))
    caixa(vin, (0, 0.72, 0.0), (0.26, 0.16, 0.2))
    tri(vin, (0.1, 0.74, 0.07), (0.1, 0.74, -0.07), (0.62, 0.82, -0.36), (0.07, 0, 0))
    tri(vin, (-0.1, 0.74, 0.07), (-0.1, 0.74, -0.07), (-0.56, 0.84, -0.5), (0.07, 0, 0))
    # costura vinho no meio da máscara
    caixa(vin, (0, -0.72, -0.28), (0.07, 0.06, 0.62))
    return m


def ladino_cinto(semente, **_):
    """Cinto de couro com fivela, duas adagas nos quadris (bainhas descendo pela frente das coxas), duas bolsinhas
    na frente, uma bolsa maior e uma faixa vinho atrás. Origem = centro da LowerTorso. ~2,3 x 1,5 x 2,4 studs."""
    m = Modelo("LadinoCinto")
    m.manter_origem = True
    m.grupo("Couro", (78, 54, 40), "Fabric")
    m.grupo("CouroEscuro", (64, 46, 38), "Fabric")
    m.grupo("Ferro", (92, 92, 98), "Metal")
    m.grupo("Aco", (196, 202, 210), "Metal")
    m.grupo("Cabo", (36, 30, 34), "Fabric")
    vin = m.grupo("Vinho", (122, 34, 56), "Fabric")
    g = {n: v["bm"] for n, v in m.grupos.items()}
    caixa(g["Couro"], (0, 0, 0.06), (2.16, 1.16, 0.34))
    caixa(g["CouroEscuro"], (0, 0, 0.06), (2.2, 1.2, 0.08))
    caixa(g["Ferro"], (0, -0.6, 0.06), (0.5, 0.08, 0.36))
    caixa(vin, (0, -0.64, 0.06), (0.22, 0.05, 0.2))
    # adagas nos quadris, à frente dos braços
    _adaga(m, (0.98, -0.68, 0.42), (0.18, 0, -1.0))
    _adaga(m, (-0.98, -0.68, 0.42), (-0.18, 0, -1.0))
    for s in (-1, 1):
        caixa(g["CouroEscuro"], (s * 0.98, -0.62, 0.1), (0.22, 0.16, 0.42))  # passador da bainha
    # bolsinhas na frente
    _bolsa(m, (0.56, -0.7, -0.12), (0.4, 0.28, 0.44))
    _bolsa(m, (-0.58, -0.68, -0.08), (0.34, 0.26, 0.38))
    # bolsa maior e faixa atrás
    _bolsa(m, (0.0, 0.68, -0.28), (0.9, 0.34, 0.7))
    caixa(g["CouroEscuro"], (0, 0.62, 0.1), (0.14, 0.12, 0.3))
    tri(vin, (-0.7, 0.62, 0.2), (-0.34, 0.62, 0.2), (-0.52, 0.64, -1.35), (0, 0.08, 0))
    tri(vin, (-0.34, 0.62, 0.2), (-0.7, 0.62, 0.2), (-0.88, 0.7, -1.0), (0, 0.08, 0))
    return m


# ======================================================================================
# MESTRA DA ÁGUA: azul profundo, turquesa, branco-espuma, detalhe dourado
def mestra_tiara(semente, **_):
    """Tiara dourada com conchas e gotas: faixa em U que contorna a testa, concha grande no centro, conchas
    menores nas têmporas, gota alta no meio, gotas pendentes e pérolas. Origem = centro da Head; frente em -Y."""
    m = Modelo("MestraTiara")
    m.manter_origem = True
    ouro = m.grupo("Ouro", (222, 178, 76), "Metal")
    con = m.grupo("Concha", (246, 238, 228), "SmoothPlastic")
    nerv = m.grupo("ConchaNervura", (226, 196, 184), "SmoothPlastic")
    gota = m.grupo("Gota", (96, 210, 226), "Glass")
    per = m.grupo("Perola", (252, 252, 250), "SmoothPlastic")
    z = 0.42
    caixa(ouro, (0, -0.67, z), (1.4, 0.09, 0.16))
    for s in (-1, 1):
        caixa(ouro, (s * 0.67, -0.2, z), (0.09, 1.0, 0.16))
        caixa(ouro, (s * 0.67, 0.38, z), (0.09, 0.3, 0.12))
        Modelo.esfera(ouro, (s * 0.67, -0.67, z), 0.1, subdiv=0)
    caixa(ouro, (0, 0.66, z), (1.4, 0.07, 0.1))
    _fan3d(con, (0, -0.72, z - 0.02), 0.0, 0.44, 0.07, nerv)
    for s in (-1, 1):
        _fan3d(con, (s * 0.5, -0.71, z + 0.0), 0.0, 0.3, 0.06, nerv)
        _fan3d(con, (s * 0.7, -0.45, z + 0.0), s * (-PI / 2) * 1.0, 0.28, 0.06, nerv)
    _gota(gota, (0, -0.74, z + 0.34), 1.0, 6)
    for s in (-1, 1):
        _gota(gota, (s * 0.32, -0.7, z + 0.1), 0.55, 6)
    for x in (-0.18, 0.18):
        Modelo.esfera(per, (x, -0.76, z - 0.12), 0.07, subdiv=0)
    for s in (-1, 1):
        Modelo.esfera(per, (s * 0.38, -0.74, z - 0.1), 0.08, subdiv=0)
    # gotas pendentes (de cabeça para baixo, como brincos de testa)
    for x in (-0.5, 0.0, 0.5):
        Modelo.ramo(ouro, (x, -0.7, z - 0.07), (x, -0.7, z - 0.17), 0.015, 0.015, 4)
    return m


def mestra_manto(semente, **_):
    """Manto longo até os pés: azul profundo, barra turquesa ondulada com cristas de espuma, ombreiras de concha
    e corrente dourada com gota sobre o peito. Origem = topo das costas da UpperTorso (como a capa do ladino);
    desce 4 studs. ~4,4 x 1,6 x 4,6 studs."""
    m = Modelo("MestraManto")
    m.manter_origem = True
    man = m.grupo("Manto", (30, 62, 142), "Fabric")
    bar = m.grupo("Barra", (52, 182, 190), "Fabric")
    esp = m.grupo("Espuma", (242, 248, 250), "SmoothPlastic")
    ouro = m.grupo("Ouro", (222, 178, 76), "Metal")
    con = m.grupo("Concha", (246, 238, 228), "SmoothPlastic")
    nerv = m.grupo("ConchaNervura", (226, 196, 184), "SmoothPlastic")
    gota = m.grupo("Gota", (96, 210, 226), "Glass")
    N = 9
    base_fim = -3.7  # o piso fica 4,0 abaixo da origem: com a ondulação (+-0,25) a barra chega ao chão sem afundar
    W = lambda z: 2.3 + 1.5 * (z / base_fim)
    for i in range(N):
        f = (i + 0.5) / N - 0.5
        z_fim = base_fim + 0.25 * math.sin(i * 1.7 + 0.5)
        z_barra = z_fim + 0.7
        xc = (lambda f_: (lambda z: f_ * W(z)))(f)
        wi = (lambda z: W(z) / N * 1.04)
        kw = dict(amp=0.16, fase=i * 0.45, freq=1.1, k_amp=0.9, abre=0.05, topo=0.0)
        n1 = 5
        zs1 = [z_barra * k / n1 for k in range(n1 + 1)]
        pano(man, xc, wi, zs1, 0.1, 0.07, **kw)
        n2 = 3
        zs2 = [z_barra + (z_fim - z_barra) * k / n2 for k in range(n2 + 1)]
        pano(bar, xc, wi, zs2, 0.1, 0.075, **kw)
        # crista de espuma no topo da barra
        yy = pano_y(z_barra, 0.0, 0.1, kw["amp"], kw["fase"], kw["freq"], kw["k_amp"], kw["abre"])
        xw = f * W(z_barra)
        tri(esp, (xw - W(z_barra) / N * 0.5, yy + 0.04, z_barra - 0.02), (xw + W(z_barra) / N * 0.5, yy + 0.04, z_barra - 0.02),
            (xw + (0.18 if i % 2 else -0.18), yy + 0.05, z_barra + (0.42 if i % 2 else 0.3)), (0, 0.05, 0))
    # gola dourada nas costas e ombreiras de concha
    pano(ouro, 0.0, 2.3, [0.0, -0.18, -0.36], 0.09, 0.11, amp=0.0, abre=0.0)
    for s in (-1, 1):
        _fan3d(con, (s * 1.3, -0.5, -0.08), 0.0, 0.44, 0.08, nerv, roll=-s * 0.6)
        Modelo.esfera(ouro, (s * 1.3, -0.5, -0.06), 0.13, subdiv=1)
    # corrente dourada sobre o peito com gota pendente (a frente do torso fica em y=-1)
    pts = catenaria((-1.18, -1.06, 0.02), (1.18, -1.06, 0.02), 0.5, 10)
    tronco(ouro, pts, [0.045] * len(pts), 4)
    _gota(gota, (0, -1.1, -0.62), 0.9, 6)
    Modelo.esfera(ouro, (0, -1.08, -0.45), 0.09, subdiv=1)
    return m


def mestra_cajado(semente, **_):
    """Cajado alto (7,2 studs) com cabo de couro azul, anéis dourados, copa de três garras e orbe de água no topo
    (grupo `Orbe`, Neon/vidro), conchas e três gotas em órbita. Vertical: o eixo Z autoral é o Y do Roblox. Origem = a
    pegada da mão direita (a ponta de baixo fica 1,4 abaixo, no chão; o orbe, ~5 acima). 1,6 x 7,2 x 1,6 studs."""
    m = Modelo("MestraCajado")
    m.manter_origem = True
    mad = m.grupo("Madeira", (164, 130, 92), "Wood")
    cou = m.grupo("Couro", (40, 84, 132), "Fabric")
    ouro = m.grupo("Ouro", (222, 178, 76), "Metal")
    orbe = m.grupo("Orbe", (110, 226, 240), "Neon")
    con = m.grupo("Concha", (246, 238, 228), "SmoothPlastic")
    nerv = m.grupo("ConchaNervura", (226, 196, 184), "SmoothPlastic")
    gota = m.grupo("Gota", (96, 210, 226), "Glass")
    tronco(mad, [(0, 0, -1.4), (0, 0, 1.4), (0, 0, 4.1)], [0.1, 0.11, 0.1], 6)
    Modelo.cilindro(cou, (0, 0, 0.0), 0.15, 0.75, 6, 0.15, tampas=True)
    for z in (-0.42, 0.42):
        Modelo.cilindro(ouro, (0, 0, z), 0.18, 0.08, 6, 0.18, tampas=True)
    for z in (1.9, 3.3):
        Modelo.cilindro(ouro, (0, 0, z), 0.17, 0.12, 6, 0.17, tampas=True)
    Modelo.ramo(ouro, (0, 0, -1.4), (0, 0, -1.05), 0.02, 0.14, 6)
    # copa de garras
    Modelo.cilindro(ouro, (0, 0, 4.15), 0.3, 0.26, 6, 0.2, tampas=True)
    for k in range(3):
        a = k * 2 * PI / 3 + 0.3
        pts = [(0.2 * math.cos(a), 0.2 * math.sin(a), 4.25), (0.52 * math.cos(a), 0.52 * math.sin(a), 4.65),
               (0.66 * math.cos(a), 0.66 * math.sin(a), 5.2), (0.38 * math.cos(a), 0.38 * math.sin(a), 5.75)]
        tronco(ouro, pts, [0.075, 0.07, 0.06, 0.04], 4, ponta=True)
    Modelo.esfera(orbe, (0, 0, 4.95), 0.5, subdiv=2)
    # conchas decorativas na base da copa (de cada lado)
    for s in (-1, 1):
        _fan3d(con, (s * 0.35, 0.0, 4.22), (-PI / 2 if s > 0 else PI / 2) * 1.0, 0.32, 0.06, nerv)
    for k in range(3):
        a = k * 2 * PI / 3 + 1.2
        _gota(gota, (0.85 * math.cos(a), 0.85 * math.sin(a), 4.5 + 0.35 * k), 0.5, 5)
    return m


def mestra_obi(semente, **_):
    """Faixa obi turquesa com debrum dourado, concha-fivela na frente e nó grande atrás com duas voltas e duas
    pontas em bico que caem até os joelhos. Origem = centro da LowerTorso. ~2,3 x 1,6 x 2,2 studs."""
    m = Modelo("MestraObi")
    m.manter_origem = True
    faixa = m.grupo("Faixa", (52, 182, 190), "Fabric")
    esc = m.grupo("FaixaEscura", (32, 138, 160), "Fabric")
    ouro = m.grupo("Ouro", (222, 178, 76), "Metal")
    nerv = m.grupo("ConchaNervura", (200, 150, 54), "Metal")
    z0, h = 0.1, 0.52
    caixa(faixa, (0, 0, z0), (2.14, 1.14, h))
    for dz in (-h / 2, h / 2):
        caixa(ouro, (0, 0, z0 + dz), (2.18, 1.18, 0.06))
    _fan3d(ouro, (0, -0.62, z0 - 0.2), 0.0, 0.42, 0.08, nerv)
    # nó atrás: centro, duas voltas e duas pontas
    caixa(esc, (0, 0.7, z0), (0.52, 0.3, 0.6))
    caixa(ouro, (0, 0.7, z0), (0.58, 0.18, 0.1))
    for s in (-1, 1):
        caixa(faixa, (s * 0.62, 0.74, z0 + 0.34), (0.9, 0.14, 0.44), (0, -s * 0.5, 0))
        caixa(esc, (s * 0.62, 0.8, z0 + 0.34), (0.5, 0.1, 0.24), (0, -s * 0.5, 0))
    prisma(faixa, [(-0.2 - 0.12, z0 - 0.2), (0.2 - 0.12, z0 - 0.2), (0.22 - 0.2, -1.05), (-0.12 - 0.2, -1.45), (-0.22 - 0.2, -1.0)], "Y", 0.66, 0.76)
    prisma(esc, [(-0.2 + 0.3, z0 - 0.2), (0.2 + 0.3, z0 - 0.2), (0.24 + 0.42, -0.85), (0.4, -1.2), (-0.2 + 0.4, -0.9)], "Y", 0.7, 0.8)
    return m


GERADORES = {
    "ladinocapuz": ladino_capuz,
    "ladinocapa": ladino_capa,
    "ladinomascara": ladino_mascara,
    "ladinocinto": ladino_cinto,
    "mestratiara": mestra_tiara,
    "mestramanto": mestra_manto,
    "mestracajado": mestra_cajado,
    "mestraobi": mestra_obi,
}
