"""Casas de variação da vila (V5a): sobrado com sacada de madeira e casinha de telhado de palha.

Mesmo estilo, escala e convenção de predios.py: paleta de parede/telhado/persiana/madeira por semente, base
de pedra, vigas aparentes, frente (porta) modelada em -Y com `espelhar_y` (no Roblox a frente fica em +Z
local), marcador `Fumaca` na chaminé (o exportador transforma em Smoke). Medidas em studs.
"""
import math
import random

from geom import caixa, prisma, segmento_anel, torno, tri, tronco  # noqa: F401
from lib import Modelo
from predios import PALETAS, _grupos_base, _janela
from vila import _flor, _g, _grupos_flores

PI = math.pi


def _chamine(m, x, y, z0, z1, g_pedra, rng):
    """Chaminé de pedra de z0 a z1 com boca em degrau e marcador de fumaça."""
    caixa(g_pedra, (x, y, (z0 + z1) / 2), (1.5, 1.6, z1 - z0))
    caixa(g_pedra, (x, y, z1 + 0.1), (1.9, 2.0, 0.3))
    caixa(g_pedra, (x, y, z1 + 0.45), (1.4, 1.5, 0.4))
    caixa(m.grupo("Fumaca", (200, 200, 200), "SmoothPlastic"), (x, y, z1 + 1.0), (0.4, 0.4, 0.4))


def casa_sacada(semente, **_):
    """Sobrado de dois andares (~13,4 x 11,6 x 12): base de pedra, vigas aparentes, sacada de madeira com guarda-corpo,
    portinhola francesa, vasos de flor, escada de pedra, chaminé de pedra na lateral e telhado de duas águas.
    Porta no térreo sob a sacada (frente em -Y, +Z no Roblox)."""
    rng = random.Random(semente * 5 + 2)
    pal = PALETAS[(semente + 1) % len(PALETAS)]
    m = Modelo(f"CasaSacada{semente}")
    m.espelhar_y = True
    _grupos_base(m, *pal)
    m.grupo("Luz", (255, 214, 130), "Neon")
    m.grupo("Ferro", (54, 52, 58), "Metal")
    m.grupo("Barro", (176, 104, 72), "SmoothPlastic")
    _grupos_flores(m)
    g = {n: v["bm"] for n, v in m.grupos.items()}
    L, P = 12.2, 9.0
    H1, H2, base = 3.8, 3.4, 0.6
    z2 = base + H1
    zt = z2 + H2
    # térreo e andar de cima
    caixa(g["Pedra"], (0, 0, base / 2), (L + 0.8, P + 0.8, base))
    caixa(g["Parede"], (0, 0, base + H1 / 2), (L, P, H1))
    caixa(g["Estrutura"], (0, 0, z2), (L + 0.5, P + 0.5, 0.3))
    caixa(g["Parede"], (0, 0, z2 + H2 / 2), (L - 0.1, P - 0.1, H2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            caixa(g["Estrutura"], (sx * L / 2, sy * P / 2, base + H1 / 2), (0.5, 0.5, H1 + 0.1))
            caixa(g["Estrutura"], (sx * (L / 2 - 0.05), sy * (P / 2 - 0.05), z2 + H2 / 2), (0.46, 0.46, H2))
    for sy in (-1, 1):
        for x in (-L / 4 - 0.5, L / 4 + 0.5):
            caixa(g["Estrutura"], (x, sy * (P / 2 + 0.04), base + H1 / 2), (0.26, 0.22, H1))
            caixa(g["Estrutura"], (x, sy * (P / 2 + 0.0), z2 + H2 / 2), (0.26, 0.2, H2))
        caixa(g["Estrutura"], (0, sy * (P / 2 + 0.04), base + H1 * 0.5), (L, 0.2, 0.26))
        caixa(g["Estrutura"], (0, sy * (P / 2 + 0.0), z2 + H2 * 0.5), (L - 0.2, 0.2, 0.26))
        caixa(g["Estrutura"], (0, sy * (P / 2 + 0.0), zt - 0.18), (L + 0.3, 0.3, 0.36))
    for sx in (-1, 1):
        caixa(g["Estrutura"], (sx * (L / 2 + 0.04), 0, zt - 0.18), (0.3, P + 0.3, 0.36))
    # telhado e cumeeira
    alt = 3.8
    Modelo.telhado(g["Telhado"], (0, 0, zt), L + 2.0, P + 2.0, alt)
    caixa(g["Telhado"], (0, 0, zt + alt), (L + 2.1, 0.55, 0.3))
    # chaminé de pedra encostada na lateral
    lado = 1 if semente % 2 else -1
    _chamine(m, lado * (L / 2 + 0.7), 0.6, 0.0, zt + alt + 0.9, g["Pedra"], rng)
    # frente térrea: porta com moldura, escada, janelas, lanterna
    yf = -P / 2
    caixa(g["Estrutura"], (0, yf - 0.05, base + 1.5), (2.0, 0.3, 3.0))
    caixa(g["Porta"], (0, yf - 0.17, base + 1.35), (1.5, 0.12, 2.7))
    caixa(g["Ferro"], (0.45, yf - 0.28, base + 1.3), (0.12, 0.1, 0.12))
    caixa(g["Pedra"], (0, yf - 0.9, base * 0.5), (2.8, 1.2, base))
    caixa(g["Pedra"], (0, yf - 1.7, base * 0.25), (3.4, 1.0, base * 0.5))
    for x in (-L / 4 - 1.2, L / 4 + 1.2):
        _janela(m, x, yf - 0.05, base + 2.4, 1.5, 1.5)
    for s in (-1, 1):
        caixa(g["Ferro"], (s * 1.5, yf - 0.4, base + 3.0), (0.12, 0.45, 0.12))
        caixa(g["Luz"], (s * 1.5, yf - 0.62, base + 2.72), (0.34, 0.34, 0.5))
        caixa(g["Ferro"], (s * 1.5, yf - 0.62, base + 3.03), (0.44, 0.44, 0.08))
    # sacada: laje de tábuas sobre vigas, dois postes com mãos-francesas e guarda-corpo
    prof = 2.5
    larg_s = 8.6
    ys = yf - prof / 2
    caixa(g["Estrutura"], (0, ys, z2 + 0.1), (larg_s, prof, 0.22))
    for i in range(6):
        caixa(g["Porta"], (0, yf - 0.2 - i * (prof - 0.3) / 5, z2 + 0.215), (larg_s - 0.1, 0.04, 0.02))
    for x in (-larg_s / 2 + 0.35, 0, larg_s / 2 - 0.35):
        caixa(g["Estrutura"], (x, ys, z2 - 0.28), (0.3, prof, 0.4))
    for sx in (-1, 1):
        xp = sx * (larg_s / 2 - 0.35)
        caixa(g["Estrutura"], (xp, yf - prof + 0.3, (z2 + 0.0) / 2), (0.42, 0.42, z2))
        caixa(g["Pedra"], (xp, yf - prof + 0.3, 0.22), (0.9, 0.9, 0.44))
        caixa(g["Estrutura"], (xp, yf - prof + 0.9, z2 - 0.6), (0.2, 1.3, 0.2), (math.radians(-35) * 1.0, 0, 0))
    zr = z2 + 0.21
    # guarda-corpo: frente e duas laterais
    yfrente = yf - prof + 0.15
    for s in (-1, 1):
        xs = s * (larg_s / 2 - 0.15)
        caixa(g["Estrutura"], (xs, ys + 0.15, zr + 1.25), (0.22, prof - 0.3, 0.2))
        caixa(g["Estrutura"], (xs, ys + 0.15, zr + 0.45), (0.14, prof - 0.3, 0.14))
        caixa(g["Estrutura"], (xs, yfrente, zr + 0.65), (0.3, 0.3, 1.3))
        for k in (1, 2, 3):
            caixa(g["Persiana"], (xs, yfrente + k * (prof - 0.3) / 4, zr + 0.65), (0.14, 0.14, 1.0))
    caixa(g["Estrutura"], (0, yfrente, zr + 1.25), (larg_s, 0.22, 0.2))
    caixa(g["Estrutura"], (0, yfrente, zr + 0.45), (larg_s, 0.14, 0.14))
    nb = 11
    for i in range(nb):
        x = -larg_s / 2 + 0.45 + i * (larg_s - 0.9) / (nb - 1)
        caixa(g["Persiana"], (x, yfrente, zr + 0.68), (0.15, 0.15, 1.0))
    # andar de cima: portinhola francesa e janelas laterais
    zc2 = z2 + 1.55
    caixa(g["Estrutura"], (0, yf - 0.03, zc2 + 0.1), (2.3, 0.28, 3.1))
    caixa(g["Janela"], (0, yf - 0.2, zc2 + 0.25), (1.8, 0.1, 2.6))
    caixa(g["Estrutura"], (0, yf - 0.27, zc2 + 0.25), (0.12, 0.1, 2.7))
    for dz in (-0.4, 0.4, 1.0):
        caixa(g["Estrutura"], (0, yf - 0.27, zc2 + 0.25 + dz), (1.9, 0.1, 0.1))
    for x in (-L / 4 - 1.3, L / 4 + 1.3):
        _janela(m, x, yf - 0.02, z2 + 1.8, 1.5, 1.5)
    # vasos de flor na sacada
    for x in (-3.4, -1.4, 1.6, 3.4):
        caixa(g["Barro"], (x, yf - prof + 0.9, zr + 0.25), (0.5, 0.5, 0.5))
        Modelo.esfera(g["Folhas"], (x, yf - prof + 0.9, zr + 0.62), 0.38, (1, 1, 0.8), 1, 0.1, rng, corte_z=zr + 0.5)
        _flor(m, (x, yf - prof + 0.9, zr + 0.55), 0.5 + rng.random() * 0.3, ("Flor1", "Flor2", "Flor3")[rng.randrange(3)], rng, 0.24)
    # laterais e fundos
    for sx in (-1, 1):
        if sx == lado:
            _janela(m, sx * (L / 2 + 0.04), -2.8, base + 2.4, 1.3, 1.4, eixo="y", lado=sx)
        else:
            _janela(m, sx * (L / 2 + 0.04), 0, base + 2.4, 1.4, 1.4, eixo="y", lado=sx)
        _janela(m, sx * (L / 2 + 0.04), 0, z2 + 1.8, 1.4, 1.4, eixo="y", lado=sx)
    for x in (-L / 4, L / 4):
        _janela(m, x, P / 2 + 0.04, base + 2.4, 1.4, 1.3, lado=1)
        _janela(m, x, P / 2 + 0.04, z2 + 1.8, 1.4, 1.3, lado=1)
    return m


def casa_palha(semente, **_):
    """Casinha de telhado de palha (~11 x 9,6 x 6): paredes de reboco sobre base de pedra, vigas aparentes, porta com
    pórtico, barril, janela com persianas, chaminé de pedra com fumaça e telhado em feixes de palha de duas águas
    com cumeeira cruzada. Mesma escala das casas de predios.py; frente em -Y (+Z no Roblox)."""
    rng = random.Random(semente * 7 + 3)
    pal = PALETAS[(semente + 2) % len(PALETAS)]
    m = Modelo(f"CasaPalha{semente}")
    m.espelhar_y = True
    _grupos_base(m, *pal)
    m.grupo("Luz", (255, 214, 130), "Neon")
    m.grupo("Ferro", (54, 52, 58), "Metal")
    m.grupo("Palha", (196, 160, 92), "Grass")
    m.grupo("PalhaClara", (216, 184, 112), "Grass")
    m.grupo("PalhaEscura", (150, 118, 70), "Grass")
    g = {n: v["bm"] for n, v in m.grupos.items()}
    L, P, H, base = 8.6, 7.2, 3.4, 0.7
    zt = base + H
    caixa(g["Pedra"], (0, 0, base / 2), (L + 0.8, P + 0.8, base))
    caixa(g["Parede"], (0, 0, base + H / 2), (L, P, H))
    for sx in (-1, 1):
        for sy in (-1, 1):
            caixa(g["Estrutura"], (sx * L / 2, sy * P / 2, base + H / 2), (0.46, 0.46, H + 0.1))
    for sy in (-1, 1):
        caixa(g["Estrutura"], (0, sy * (P / 2 + 0.03), zt - 0.2), (L + 0.4, 0.26, 0.4))
        caixa(g["Estrutura"], (0, sy * (P / 2 + 0.03), base + 0.2), (L, 0.2, 0.3))
        for x in (-L / 4 - 0.3, L / 4 + 0.3):
            caixa(g["Estrutura"], (x, sy * (P / 2 + 0.03), base + H / 2), (0.22, 0.2, H))
    for sx in (-1, 1):
        caixa(g["Estrutura"], (sx * (L / 2 + 0.03), 0, zt - 0.2), (0.26, P + 0.4, 0.4))
    # telhado de palha: feixes que descem da cumeeira aos beirais, em duas tonalidades, sobre um miolo escuro
    alt = 3.7
    beiral = 1.0
    d = P / 2 + beiral
    comp = L + 1.8
    prisma(g["PalhaEscura"], [(-d * 0.88, zt - 0.1), (d * 0.88, zt - 0.1), (0.0, zt + alt * 0.96)], "X", -comp / 2 + 0.15, comp / 2 - 0.15)
    n = int(comp / 0.72)
    for i in range(n):
        x = -comp / 2 + (i + 0.5) * comp / n
        for s in (-1, 1):
            alvo = g["Palha"] if (i + (s > 0)) % 2 == 0 else g["PalhaClara"]
            eave = (x, s * (d + 0.15), zt - 0.45 + rng.uniform(-0.05, 0.05))
            meio = (x, s * d * 0.5, zt + alt * 0.5 + 0.25)
            topo = (x, s * 0.1, zt + alt - 0.05)
            tronco(alvo, [eave, meio, topo], [0.5, 0.44, 0.36], 5)
    Modelo.cilindro(g["PalhaEscura"], (0, 0, zt + alt + 0.15), 0.58, comp + 0.5, 6, 0.58, "X", tampas=True)
    for sx in (-1, 1):
        x = sx * (comp / 2 + 0.2)
        for t in (-1, 1):
            Modelo.ramo(g["Estrutura"], (x, -t * 0.5, zt + alt + 1.0), (x, t * 0.8, zt + alt - 0.5), 0.1, 0.08, 5)
    # chaminé de pedra no fundo
    lado = 1 if semente % 2 else -1
    caixa(g["Pedra"], (lado * (L / 2 - 1.4), P / 2 - 0.2, (zt + alt + 0.6) / 2 + 0.2), (1.4, 1.5, zt + alt + 0.4))
    caixa(g["Pedra"], (lado * (L / 2 - 1.4), P / 2 - 0.2, zt + alt + 0.65), (1.8, 1.9, 0.3))
    caixa(m.grupo("Fumaca", (200, 200, 200), "SmoothPlastic"), (lado * (L / 2 - 1.4), P / 2 - 0.2, zt + alt + 1.2), (0.4, 0.4, 0.4))
    # frente: porta com moldura e pedras de entrada, janela com persianas, lanterna e barril
    yf = -P / 2
    caixa(g["Estrutura"], (-0.9, yf - 0.05, base + 1.45), (1.9, 0.3, 2.9))
    caixa(g["Porta"], (-0.9, yf - 0.17, base + 1.3), (1.4, 0.12, 2.6))
    caixa(g["Ferro"], (-0.5, yf - 0.28, base + 1.3), (0.1, 0.1, 0.1))
    caixa(g["Pedra"], (-0.9, yf - 0.8, base * 0.5), (2.4, 1.1, base))
    caixa(g["Pedra"], (-0.9, yf - 1.5, base * 0.25), (3.0, 0.9, base * 0.5))
    _janela(m, 2.2, yf - 0.05, base + 2.0, 1.5, 1.4)
    caixa(g["Estrutura"], (2.2, yf - 0.55, base + 1.2), (1.9, 0.5, 0.18))
    for x in (1.6, 2.2, 2.8):
        Modelo.esfera(m.grupos["Palha"]["bm"], (x, yf - 0.55, base + 1.5), 0.2, (1, 1, 0.8), 0)
    caixa(g["Ferro"], (-2.2, yf - 0.36, base + 3.0), (0.12, 0.45, 0.12))
    caixa(g["Luz"], (-2.2, yf - 0.6, base + 2.72), (0.34, 0.34, 0.5))
    caixa(g["Ferro"], (-2.2, yf - 0.6, base + 3.03), (0.44, 0.44, 0.08))
    Modelo.cilindro(g["Estrutura"], (3.7, yf - 0.9, base + 0.55), 0.55, 1.1, 8, 0.5, tampas=True)
    for dz in (-0.3, 0.3):
        Modelo.cilindro(g["Ferro"], (3.7, yf - 0.9, base + 0.55 + dz), 0.57, 0.08, 8, 0.57, tampas=True)
    for sx in (-1, 1):
        _janela(m, sx * (L / 2 + 0.04), 0, base + 2.0, 1.4, 1.3, eixo="y", lado=sx)
    _janela(m, 0, P / 2 + 0.04, base + 2.0, 1.4, 1.3, lado=1)
    return m


GERADORES = {
    "casasacada": casa_sacada,
    "casapalha": casa_palha,
}
