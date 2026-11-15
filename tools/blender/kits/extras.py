"""Peças que nenhum kit baixado traz (canos, tocha, água, grade de piso, balcão, caneca, lareira, candelabro,
cajado). Feitas com as primitivas de tools/blender/lib.py na mesma paleta sóbria dos kits.
Cada função devolve (Modelo, opções do manifesto). Medidas em studs; casa do combate = 5 studs."""
import math

from lib import Modelo

PEDRA = (104, 106, 112)
PEDRA_ESC = (70, 72, 78)
FERRO = (74, 76, 82)
FERRO_CLARO = (122, 124, 130)
MADEIRA = (112, 82, 58)
MADEIRA_ESC = (82, 60, 44)
OURO = (176, 146, 78)
AGUA = (58, 96, 104)
LIMO = (70, 92, 64)
FOGO = (232, 150, 60)
CERAMICA = (150, 112, 84)


def _flange(bm, x, y, z, raio, eixo):
    Modelo.cilindro(bm, (x, y, z), raio + 0.18, 0.28, 10, eixo=eixo)


def cano(**_):
    m = Modelo("EsgotoCano")
    f = m.grupo("Ferro", FERRO, "Metal")
    Modelo.cilindro(f, (0, 0, 1.2), 0.7, 5.0, 12, eixo="X")
    for x in (-2.3, 0.0, 2.3):
        _flange(f, x, 0, 1.2, 0.7, "X")
    s = m.grupo("Suporte", PEDRA_ESC, "Slate")
    for x in (-1.2, 1.2):
        Modelo.caixa(s, (x, 0, 0.3), (0.5, 1.6, 0.6))
    l = m.grupo("Limo", LIMO, "Grass")
    Modelo.caixa(l, (0.9, 0.55, 0.62), (0.8, 0.3, 0.12))
    return m, {"categoria": "esgoto", "uso": "cano reto de uma casa (eixo X)", "orcamento": "prop"}


def cano_curva(**_):
    m = Modelo("EsgotoCanoCurva")
    f = m.grupo("Ferro", FERRO, "Metal")
    Modelo.cilindro(f, (-1.1, 0, 1.2), 0.7, 2.8, 12, eixo="X")
    Modelo.cilindro(f, (0, 1.1, 1.2), 0.7, 2.8, 12, eixo="Y")
    Modelo.esfera(f, (0, 0, 1.2), 0.9, subdiv=2)
    for x, y, e in ((-2.2, 0, "X"), (0, 2.2, "Y")):
        _flange(f, x, y, 1.2, 0.7, e)
    s = m.grupo("Suporte", PEDRA_ESC, "Slate")
    Modelo.caixa(s, (0, 0, 0.3), (1.2, 1.2, 0.6))
    return m, {"categoria": "esgoto", "uso": "cano em L (de -X para +Y)", "orcamento": "prop"}


def cano_parede(**_):
    m = Modelo("EsgotoCanoParede")
    f = m.grupo("Ferro", FERRO, "Metal")
    Modelo.cilindro(f, (0, 0, 2.5), 0.6, 5.0, 12, eixo="Z")
    for z in (0.3, 2.5, 4.7):
        _flange(f, 0, 0, z, 0.6, "Z")
    return m, {"categoria": "esgoto", "uso": "cano vertical de parede, 5 studs", "orcamento": "prop"}


def grade_piso(**_):
    m = Modelo("EsgotoGradePiso")
    b = m.grupo("Borda", PEDRA, "Slate")
    for x, y, w, d in ((0, 2.35, 5, 0.3), (0, -2.35, 5, 0.3), (2.35, 0, 0.3, 4.4), (-2.35, 0, 0.3, 4.4)):
        Modelo.caixa(b, (x, y, 0.08), (w, d, 0.16))
    fe = m.grupo("Ferro", FERRO, "Metal")
    for i in range(-3, 4):
        Modelo.caixa(fe, (i * 0.62, 0, 0.12), (0.18, 4.4, 0.16))
    Modelo.caixa(fe, (0, 0, 0.09), (4.4, 0.18, 0.12))
    return m, {"categoria": "esgoto", "uso": "grade de ralo no piso (uma casa)", "orcamento": "cenario"}


def agua(**_):
    m = Modelo("EsgotoAgua")
    a = m.grupo("Agua", AGUA, "SmoothPlastic")
    Modelo.caixa(a, (0, 0, 0.1), (5, 5, 0.2))
    l = m.grupo("Limo", LIMO, "Grass")
    for x, y, r in ((-1.4, 1.2, 0.5), (1.1, -1.5, 0.4), (0.4, 1.7, 0.3)):
        Modelo.cilindro(l, (x, y, 0.22), r, 0.04, 8)
    return m, {"categoria": "esgoto", "uso": "canal de água de uma casa (definir Transparency/Reflectance no Studio)", "orcamento": "cenario"}


def tocha(**_):
    m = Modelo("EsgotoTocha")
    s = m.grupo("Suporte", FERRO, "Metal")
    Modelo.caixa(s, (0, -0.15, 3.0), (0.9, 0.3, 0.9))  # placa na parede (parede em +Y... fica em y=0.0)
    Modelo.cilindro(s, (0, -0.9, 3.0), 0.3, 1.3, 8, eixo="Y")
    Modelo.cilindro(s, (0, -1.4, 3.35), 0.55, 0.8, 8, raio_topo=0.7)
    mad = m.grupo("Madeira", MADEIRA_ESC, "Wood")
    Modelo.cilindro(mad, (0, -1.4, 3.8), 0.28, 1.1, 6)
    ch = m.grupo("Chama", FOGO, "Neon")
    Modelo.cilindro(ch, (0, -1.4, 4.65), 0.34, 0.8, 6, raio_topo=0.02)
    mm = m
    mm.manter_origem = True
    return m, {"categoria": "esgoto", "uso": "tocha de parede; encostar o dorso (y=0) na parede, a tocha avança para -Y. Chama: Neon + PointLight", "orcamento": "prop", "pivo": "parede"}


def candelabro(**_):
    m = Modelo("TavernaCandelabro")
    f = m.grupo("Ferro", FERRO, "Metal")
    Modelo.cilindro(f, (0, 0, 0.1), 0.6, 0.2, 10)
    Modelo.cilindro(f, (0, 0, 1.1), 0.12, 2.0, 6)
    Modelo.caixa(f, (0, 0, 2.0), (2.2, 0.16, 0.16))
    for x in (-1.1, 0, 1.1):
        Modelo.cilindro(f, (x, 0, 2.15), 0.2, 0.2, 8)
    v = m.grupo("Vela", (214, 204, 178), "SmoothPlastic")
    for x in (-1.1, 0, 1.1):
        Modelo.cilindro(v, (x, 0, 2.6), 0.12, 0.7, 6)
    c = m.grupo("Chama", FOGO, "Neon")
    for x in (-1.1, 0, 1.1):
        Modelo.cilindro(c, (x, 0, 3.08), 0.09, 0.26, 6, raio_topo=0.01)
    return m, {"categoria": "taverna", "uso": "candelabro de piso, 3 velas", "orcamento": "prop"}


def caneca(**_):
    m = Modelo("TavernaCaneca")
    c = m.grupo("Ceramica", CERAMICA, "Slate")
    Modelo.cilindro(c, (0, 0, 0.45), 0.4, 0.9, 10, raio_topo=0.36)
    Modelo.caixa(c, (0.48, 0, 0.45), (0.14, 0.12, 0.5))
    Modelo.caixa(c, (0.4, 0, 0.7), (0.3, 0.12, 0.12))
    Modelo.caixa(c, (0.4, 0, 0.2), (0.3, 0.12, 0.12))
    cerv = m.grupo("Cerveja", (176, 132, 60), "SmoothPlastic")
    Modelo.cilindro(cerv, (0, 0, 0.9), 0.35, 0.04, 10)
    return m, {"categoria": "taverna", "uso": "caneca", "orcamento": "prop"}


def balcao(**_):
    m = Modelo("TavernaBalcao")
    mad = m.grupo("Madeira", MADEIRA, "Wood")
    Modelo.caixa(mad, (0, 0, 1.8), (10.0, 2.4, 3.6))
    esc = m.grupo("MadeiraEscura", MADEIRA_ESC, "Wood")
    Modelo.caixa(esc, (0, 0, 3.7), (10.4, 2.8, 0.25))  # tampo
    Modelo.caixa(esc, (0, -1.25, 0.2), (10.0, 0.15, 0.4))  # rodapé
    for x in (-3.3, 0.0, 3.3):
        Modelo.caixa(esc, (x, -1.22, 1.9), (2.6, 0.08, 2.4))  # almofadas da frente
    f = m.grupo("Ferro", FERRO, "Metal")
    Modelo.caixa(f, (0, -1.28, 0.55), (10.0, 0.1, 0.1))  # apoio de pé
    return m, {"categoria": "taverna", "uso": "balcão de 2 casas de comprimento (eixo X); frente em -Y", "orcamento": "prop"}


def mesa_longa(**_):
    m = Modelo("TavernaMesaLonga")
    mad = m.grupo("Madeira", MADEIRA, "Wood")
    Modelo.caixa(mad, (0, 0, 2.6), (8.0, 2.6, 0.3))
    esc = m.grupo("MadeiraEscura", MADEIRA_ESC, "Wood")
    for x in (-3.4, 3.4):
        for y in (-0.9, 0.9):
            Modelo.caixa(esc, (x, y, 1.25), (0.4, 0.4, 2.5))
    Modelo.caixa(esc, (0, 0, 0.9), (6.8, 0.25, 0.25))
    return m, {"categoria": "taverna", "uso": "mesa longa de taverna", "orcamento": "prop"}


def lareira(**_):
    m = Modelo("TavernaLareira")
    p = m.grupo("Pedra", PEDRA, "Slate")
    # caixas sem vértices em comum (folga de 0,02): evita normais invertidas na fusão de vértices
    Modelo.caixa(p, (-1.9, 0, 2.16), (1.4, 2.0, 3.68))
    Modelo.caixa(p, (1.9, 0, 2.16), (1.4, 2.0, 3.68))
    Modelo.caixa(p, (0, 0, 4.65), (5.2, 2.0, 1.2))
    Modelo.caixa(p, (0, 0.5, 6.47), (2.4, 1.2, 2.4))  # chaminé
    Modelo.caixa(p, (0, 0, 0.15), (5.2, 2.4, 0.3))  # soleira
    pe = m.grupo("PedraEscura", PEDRA_ESC, "Slate")
    Modelo.caixa(pe, (0, 0.8, 1.8), (2.4, 0.4, 3.6))  # fundo
    lenha = m.grupo("Lenha", MADEIRA_ESC, "Wood")
    for y, g in ((-0.2, 0.2), (0.3, -0.3)):
        Modelo.cilindro(lenha, (0, y, 0.55), 0.28, 2.0, 6, eixo="X", giro_z=g)
    br = m.grupo("Brasa", FOGO, "Neon")
    Modelo.cilindro(br, (0, 0.05, 1.0), 0.6, 0.9, 6, raio_topo=0.05)
    return m, {"categoria": "taverna", "uso": "lareira de parede, frente em -Y (encostar o dorso em y=+1). Brasa: Neon + PointLight", "orcamento": "prop"}


def cajado(**_):
    m = Modelo("Cajado")
    mad = m.grupo("Madeira", MADEIRA, "Wood")
    Modelo.cilindro(mad, (0, -2.0, 0), 0.13, 5.2, 6, eixo="Y")  # haste ao longo de Y; ponta em -Y
    for ang in (0, 1.57, 3.14, 4.71):  # garras segurando a gema
        Modelo.caixa(mad, (math.cos(ang) * 0.34, -4.9, math.sin(ang) * 0.34), (0.1, 0.6, 0.1), giro_z=0)
    g = m.grupo("Gema", (92, 140, 176), "Glass")
    Modelo.esfera(g, (0, -5.0, 0), 0.32, subdiv=1)
    fe = m.grupo("Ferro", FERRO, "Metal")
    Modelo.cilindro(fe, (0, 0.55, 0), 0.17, 0.3, 6, eixo="Y")
    Modelo.cilindro(fe, (0, -4.55, 0), 0.2, 0.2, 6, eixo="Y")
    m.manter_origem = True
    return m, {"categoria": "armas", "uso": "cajado (pivô na mão, ponta em -Y)", "orcamento": "arma", "pivo": "punho"}


EXTRAS = [cano, cano_curva, cano_parede, grade_piso, agua, tocha, candelabro, caneca, balcao, mesa_longa, lareira, cajado]
