"""Prédios da vila (taverna, forja, dojo, casas). Cada função devolve um Modelo.

Convenção: a frente (porta) é modelada em -Y e `espelhar_y` a leva para +Y do Blender,
que no Roblox é +Z local, o lado da porta que `VilaLayout` espera (angulo/porta).
"""
import math
import random

from lib import Modelo

# Paletas das casas: (parede, telhado, persiana, madeira)
PALETAS = [
    ((228, 212, 178), (158, 72, 52), (64, 104, 80), (84, 60, 40)),
    ((214, 220, 222), (92, 76, 70), (150, 56, 48), (70, 52, 38)),
    ((236, 222, 190), (70, 96, 112), (172, 120, 52), (92, 66, 44)),
    ((206, 196, 176), (128, 84, 58), (60, 88, 120), (78, 56, 40)),
]


def _janela(m, x, y, z, w, h, eixo="x", persianas=True, lado=-1):
    """Janela em parede perpendicular a Y (eixo x) ou a X (eixo y), com caixilho e persianas."""
    vidro, mad, pers = m.grupos["Janela"]["bm"], m.grupos["Estrutura"]["bm"], m.grupos["Persiana"]["bm"]
    if eixo == "x":
        Modelo.caixa(vidro, (x, y, z), (w, 0.14, h))
        Modelo.caixa(mad, (x, y + lado * 0.05, z), (w + 0.35, 0.1, 0.13))
        Modelo.caixa(mad, (x, y + lado * 0.05, z), (0.13, 0.1, h + 0.35))
        Modelo.caixa(mad, (x, y + lado * 0.05, z - h / 2 - 0.1), (w + 0.7, 0.28, 0.16))
        if persianas:
            for s in (-1, 1):
                Modelo.caixa(pers, (x + s * (w / 2 + 0.34), y + lado * 0.05, z), (0.5, 0.1, h + 0.1))
    else:
        Modelo.caixa(vidro, (x, y, z), (0.14, w, h))
        Modelo.caixa(mad, (x + lado * 0.05, y, z), (0.1, w + 0.35, 0.13))
        Modelo.caixa(mad, (x + lado * 0.05, y, z), (0.1, 0.13, h + 0.35))


def _grupos_base(m, parede=(228, 212, 178), telhado=(158, 72, 52), persiana=(64, 104, 80), madeira=(84, 60, 40)):
    m.grupo("Pedra", (126, 124, 118), "Slate")
    m.grupo("Parede", parede, "SmoothPlastic")
    m.grupo("Estrutura", madeira, "WoodPlanks")
    m.grupo("Telhado", telhado, "Slate")
    m.grupo("Porta", (108, 74, 44), "WoodPlanks")
    m.grupo("Janela", (150, 190, 214), "SmoothPlastic")
    m.grupo("Persiana", persiana, "WoodPlanks")


def casa(semente):
    rng = random.Random(semente * 3 + 1)
    pal = PALETAS[(semente - 1) % len(PALETAS)]
    m = Modelo(f"Casa{semente}")
    m.espelhar_y = True
    _grupos_base(m, *pal)
    L, P, H = 11.0 + rng.random() * 2.0, 8.5 + rng.random() * 1.2, 4.0 + rng.random() * 0.5
    base = 0.6
    g = {n: v["bm"] for n, v in m.grupos.items()}
    Modelo.caixa(g["Pedra"], (0, 0, base / 2), (L + 0.8, P + 0.8, base))
    Modelo.caixa(g["Parede"], (0, 0, base + H / 2), (L, P, H))
    zt = base + H
    for sx in (-1, 1):
        for sy in (-1, 1):
            Modelo.caixa(g["Estrutura"], (sx * L / 2, sy * P / 2, base + H / 2), (0.5, 0.5, H + 0.1))
    for sy in (-1, 1):
        Modelo.caixa(g["Estrutura"], (0, sy * (P / 2 + 0.04), zt - 0.2), (L + 0.5, 0.3, 0.4))
        Modelo.caixa(g["Estrutura"], (0, sy * (P / 2 + 0.04), base + H * 0.5), (L, 0.22, 0.28))
        for x in (-L / 4, L / 4):
            Modelo.caixa(g["Estrutura"], (x, sy * (P / 2 + 0.04), base + H / 2), (0.28, 0.22, H))
    for sx in (-1, 1):
        Modelo.caixa(g["Estrutura"], (sx * (L / 2 + 0.04), 0, zt - 0.2), (0.3, P + 0.5, 0.4))
    alt = 3.4 + rng.random() * 0.6
    Modelo.telhado(g["Telhado"], (0, 0, zt), L + 1.8, P + 1.8, alt)
    Modelo.caixa(g["Telhado"], (0, 0, zt + alt), (L + 1.9, 0.5, 0.3))
    lado = rng.choice((-1, 1))
    Modelo.caixa(g["Pedra"], (lado * L * 0.28, P * 0.12, zt + alt * 0.9), (1.1, 1.1, 5.0))
    Modelo.caixa(g["Pedra"], (lado * L * 0.28, P * 0.12, zt + alt * 0.9 + 2.6), (1.4, 1.4, 0.3))
    Modelo.caixa(m.grupo("Fumaca", (200, 200, 200), "SmoothPlastic"), (lado * L * 0.28, P * 0.12, zt + alt * 0.9 + 3.0), (0.4, 0.4, 0.4))
    yf = -P / 2
    Modelo.caixa(g["Estrutura"], (0, yf - 0.05, base + 1.45), (1.9, 0.3, 2.9))
    Modelo.caixa(g["Porta"], (0, yf - 0.16, base + 1.3), (1.4, 0.12, 2.6))
    Modelo.caixa(g["Pedra"], (0, yf - 0.9, base * 0.5), (2.4, 1.2, base))
    for x in (-L / 4 - 1.0, L / 4 + 1.0):
        _janela(m, x, yf - 0.05, base + 2.4, 1.5, 1.4)
    for sx in (-1, 1):
        _janela(m, sx * (L / 2 + 0.04), 0, base + 2.4, 1.4, 1.4, eixo="y", lado=sx)
    for x in (-L / 4, L / 4):
        _janela(m, x, P / 2 + 0.04, base + 2.4, 1.4, 1.3, lado=1)
    return m


def taverna(semente=1):
    m = Modelo("Taverna")
    m.espelhar_y = True
    _grupos_base(m, (232, 216, 184), (140, 62, 48), (150, 56, 48), (78, 54, 38))
    m.grupo("Luz", (255, 214, 130), "Neon")
    m.grupo("Sinal", (196, 154, 84), "WoodPlanks")
    m.grupo("Ferro", (52, 52, 58), "Metal")
    g = {n: v["bm"] for n, v in m.grupos.items()}
    L, P = 20.0, 14.0
    H1, H2, base = 4.2, 3.4, 0.6
    Modelo.caixa(g["Pedra"], (0, 0, base / 2), (L + 1.0, P + 1.0, base))
    Modelo.caixa(g["Parede"], (0, 0, base + H1 / 2), (L, P, H1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            Modelo.caixa(g["Pedra"], (sx * (L / 2), sy * (P / 2), base + H1 / 2), (1.1, 1.1, H1 + 0.1))
    # andar superior em balanço
    z2 = base + H1
    Modelo.caixa(g["Estrutura"], (0, 0, z2 + 0.15), (L + 1.4, P + 1.4, 0.3))
    Modelo.caixa(g["Parede"], (0, 0, z2 + 0.3 + H2 / 2), (L + 1.0, P + 1.0, H2))
    zt = z2 + 0.3 + H2
    for sx in (-1, 1):
        for sy in (-1, 1):
            Modelo.caixa(g["Estrutura"], (sx * (L / 2 + 0.5), sy * (P / 2 + 0.5), z2 + 0.3 + H2 / 2), (0.5, 0.5, H2))
    for sy in (-1, 1):
        for x in (-L / 2 + 3.2, -L / 6, L / 6, L / 2 - 3.2):
            Modelo.caixa(g["Estrutura"], (x, sy * (P / 2 + 0.55), z2 + 0.3 + H2 / 2), (0.3, 0.2, H2))
        Modelo.caixa(g["Estrutura"], (0, sy * (P / 2 + 0.55), zt - 0.2), (L + 1.4, 0.3, 0.4))
        Modelo.caixa(g["Estrutura"], (0, sy * (P / 2 + 0.55), z2 + 0.3 + H2 * 0.5), (L + 1.0, 0.2, 0.24))
    # telhado principal e duas águas-furtadas
    alt = 4.6
    Modelo.telhado(g["Telhado"], (0, 0, zt), L + 3.6, P + 3.2, alt)
    Modelo.caixa(g["Telhado"], (0, 0, zt + alt), (L + 3.7, 0.55, 0.32))
    for x in (-L / 4, L / 4):
        Modelo.caixa(g["Parede"], (x, -(P / 2 - 0.6), zt + 1.7), (3.0, 2.2, 2.6))
        Modelo.telhado(g["Telhado"], (x, -(P / 2 - 0.6) - 0.1, zt + 3.0), 3.8, 3.2, 1.9)
        Modelo.caixa(g["Janela"], (x, -(P / 2 - 0.6) - 1.14, zt + 1.7), (1.3, 0.12, 1.4))
    # chaminé de pedra
    Modelo.caixa(g["Pedra"], (-L * 0.32, P * 0.15, zt + 3.4), (1.5, 1.5, 7.0))
    Modelo.caixa(g["Pedra"], (-L * 0.32, P * 0.15, zt + 7.0), (1.9, 1.9, 0.4))
    Modelo.caixa(m.grupo("Fumaca", (200, 200, 200), "SmoothPlastic"), (-L * 0.32, P * 0.15, zt + 7.6), (0.4, 0.4, 0.4))
    # frente
    yf = -(P / 2)
    Modelo.caixa(g["Estrutura"], (0, yf - 0.05, base + 1.9), (3.3, 0.34, 3.8))
    Modelo.caixa(g["Porta"], (-0.78, yf - 0.2, base + 1.7), (1.4, 0.14, 3.4))
    Modelo.caixa(g["Porta"], (0.78, yf - 0.2, base + 1.7), (1.4, 0.14, 3.4))
    Modelo.caixa(g["Pedra"], (0, yf - 1.1, base * 0.5), (4.4, 1.6, base))
    Modelo.caixa(g["Pedra"], (0, yf - 1.9, base * 0.25), (5.2, 1.6, base * 0.5))
    for s in (-1, 1):
        Modelo.caixa(g["Ferro"], (s * 2.6, yf - 0.28, base + 3.1), (0.14, 0.5, 0.14))
        Modelo.caixa(g["Luz"], (s * 2.6, yf - 0.55, base + 2.8), (0.45, 0.45, 0.65))
        Modelo.caixa(g["Ferro"], (s * 2.6, yf - 0.55, base + 3.2), (0.55, 0.55, 0.1))
    for x in (-7.0, -4.2, 4.2, 7.0):
        _janela(m, x, yf - 0.05, base + 2.7, 1.5, 1.6)
    for x in (-7.2, -2.4, 2.4, 7.2):
        _janela(m, x, yf - 0.55, z2 + 0.3 + H2 / 2, 1.4, 1.5)
    for sx in (-1, 1):
        _janela(m, sx * (L / 2 + 0.04), 0, base + 2.7, 1.5, 1.6, eixo="y", lado=sx)
        _janela(m, sx * (L / 2 + 0.55), 0, z2 + 0.3 + H2 / 2, 1.5, 1.5, eixo="y", lado=sx)
    for x in (-5, 5):
        _janela(m, x, P / 2 + 0.04, base + 2.7, 1.5, 1.6, lado=1)
    # placa pendurada
    Modelo.caixa(g["Ferro"], (-8.6, yf - 1.0, z2 - 0.4), (0.14, 2.2, 0.14))
    Modelo.caixa(g["Ferro"], (-8.6, yf - 1.95, z2 - 0.55), (0.1, 0.1, 0.5))
    Modelo.caixa(g["Sinal"], (-8.6, yf - 1.95, z2 - 1.35), (0.14, 1.9, 1.2))
    Modelo.caixa(g["Ferro"], (-8.6, yf - 1.95, z2 - 1.35), (0.18, 1.1, 0.4))
    return m


def forja(semente=1):
    m = Modelo("Forja")
    m.espelhar_y = True
    m.grupo("Pedra", (118, 116, 112), "Slate")
    m.grupo("Estrutura", (74, 54, 38), "WoodPlanks")
    m.grupo("Telhado", (72, 74, 88), "Slate")
    m.grupo("Ferro", (46, 46, 52), "Metal")
    m.grupo("Brasa", (255, 120, 40), "Neon")
    m.grupo("Chao", (96, 90, 82), "Slate")
    m.grupo("Madeira", (118, 84, 54), "WoodPlanks")
    g = {n: v["bm"] for n, v in m.grupos.items()}
    L, P, H = 16.0, 12.0, 3.8
    Modelo.caixa(g["Chao"], (0, 0, 0.15), (L + 1.0, P + 1.0, 0.3))
    # paredes de pedra em U: fundos e laterais; a frente fica aberta
    Modelo.caixa(g["Pedra"], (0, P / 2 - 0.5, 0.3 + H / 2), (L, 1.0, H))
    for sx in (-1, 1):
        Modelo.caixa(g["Pedra"], (sx * (L / 2 - 0.5), 0, 0.3 + H / 2), (1.0, P, H))
        Modelo.caixa(g["Pedra"], (sx * (L / 2 - 0.5), -P / 2 + 1.2, 0.3 + H + 0.15), (1.2, 2.4, 0.3))
    # postes e viga da frente
    for x in (-L / 2 + 0.9, -L / 6, L / 6, L / 2 - 0.9):
        Modelo.caixa(g["Estrutura"], (x, -P / 2 + 0.5, 0.3 + H / 2), (0.55, 0.55, H))
    Modelo.caixa(g["Estrutura"], (0, -P / 2 + 0.5, 0.3 + H - 0.2), (L, 0.5, 0.5))
    zt = 0.3 + H
    Modelo.telhado_4_aguas(g["Telhado"], (0, 0, zt), L + 3.0, P + 3.0, 3.4)
    # forno e chaminé alta
    Modelo.caixa(g["Pedra"], (-3.4, 3.2, 0.3 + 0.9), (3.6, 2.6, 1.8))
    Modelo.caixa(g["Brasa"], (-3.4, 3.2, 0.3 + 1.85), (2.6, 1.7, 0.16))
    Modelo.caixa(g["Pedra"], (-3.4, 4.3, 0.3 + 4.6), (2.2, 1.6, 8.0))
    Modelo.caixa(g["Pedra"], (-3.4, 4.3, 0.3 + 8.7), (2.6, 2.0, 0.4))
    Modelo.caixa(m.grupo("Fumaca", (200, 200, 200), "SmoothPlastic"), (-3.4, 4.3, 0.3 + 9.3), (0.4, 0.4, 0.4))
    # bigorna
    Modelo.cilindro(g["Madeira"], (2.8, 0.2, 0.3 + 0.55), 0.55, 1.1, 8)
    Modelo.caixa(g["Ferro"], (2.8, 0.2, 0.3 + 1.3), (1.9, 0.7, 0.45))
    Modelo.caixa(g["Ferro"], (3.95, 0.2, 0.3 + 1.28), (0.8, 0.4, 0.3))
    Modelo.caixa(g["Ferro"], (2.8, 0.2, 0.3 + 1.0), (0.7, 0.5, 0.4))
    # barril d'água, mó e prateleira de armas
    Modelo.cilindro(g["Madeira"], (5.2, 3.6, 0.3 + 0.8), 0.8, 1.6, 9, 0.7)
    Modelo.caixa(g["Estrutura"], (-6.2, -0.6, 0.3 + 0.7), (0.4, 1.8, 1.4))
    Modelo.cilindro(g["Pedra"], (-6.2, -0.6, 0.3 + 1.2), 0.85, 0.35, 12, eixo="X")
    for i, y in enumerate((-1.5, 0, 1.5)):
        Modelo.caixa(g["Ferro"], (-1.0 + i * 1.3, P / 2 - 1.15, 0.3 + 2.2), (0.12, 0.08, 1.7))
        Modelo.caixa(g["Madeira"], (-1.0 + i * 1.3, P / 2 - 1.15, 0.3 + 1.4), (0.12, 0.08, 0.5))
    Modelo.caixa(g["Estrutura"], (0.3, P / 2 - 1.12, 0.3 + 2.9), (4.6, 0.12, 0.14))
    # lenha empilhada junto à parede lateral e cabo de ferramentas
    for fila in range(3):
        for i in range(4 - fila):
            Modelo.cilindro(g["Madeira"], (-L / 2 - 0.9, -1.2 + i * 0.62 + fila * 0.31, 0.3 + 0.3 + fila * 0.52), 0.3, 2.6, 7, eixo="X")
    # placa de bigorna pendurada na viga da frente
    Modelo.caixa(g["Ferro"], (5.4, -P / 2 - 0.5, 0.3 + H - 0.15), (0.12, 1.4, 0.12))
    Modelo.caixa(g["Ferro"], (5.4, -P / 2 - 1.1, 0.3 + H - 1.1), (0.1, 0.1, 1.0))
    Modelo.caixa(g["Madeira"], (5.4, -P / 2 - 1.1, 0.3 + H - 1.7), (0.12, 1.7, 1.0))
    Modelo.caixa(g["Ferro"], (5.4, -P / 2 - 1.1, 0.3 + H - 1.6), (0.16, 1.1, 0.34))
    Modelo.caixa(g["Ferro"], (5.4, -P / 2 - 1.1, 0.3 + H - 1.95), (0.16, 0.5, 0.3))
    # degrau de entrada e tocha acesa ao lado
    Modelo.caixa(g["Chao"], (0, -P / 2 - 0.9, 0.12), (6.0, 1.4, 0.24))
    Modelo.caixa(g["Estrutura"], (-L / 2 + 0.9, -P / 2 - 0.2, 0.3 + 1.6), (0.14, 0.14, 0.9))
    Modelo.caixa(g["Brasa"], (-L / 2 + 0.9, -P / 2 - 0.2, 0.3 + 2.2), (0.3, 0.3, 0.3))
    return m


def dojo(semente=1):
    m = Modelo("Dojo")
    m.espelhar_y = True
    m.grupo("Plataforma", (110, 80, 54), "WoodPlanks")
    m.grupo("Pedra", (132, 130, 124), "Slate")
    m.grupo("Papel", (240, 232, 208), "SmoothPlastic")
    m.grupo("Estrutura", (58, 42, 34), "WoodPlanks")
    m.grupo("Telhado", (58, 66, 88), "Slate")
    m.grupo("Pano", (168, 44, 44), "Fabric")
    m.grupo("Luz", (255, 206, 120), "Neon")
    m.grupo("Ouro", (204, 164, 66), "Metal")
    m.grupo("Porta", (96, 66, 42), "WoodPlanks")
    g = {n: v["bm"] for n, v in m.grupos.items()}
    L, P = 18.0, 16.0
    h0, H1 = 1.0, 3.6
    Modelo.caixa(g["Pedra"], (0, 0, 0.35), (L + 2.6, P + 2.6, 0.7))
    Modelo.caixa(g["Plataforma"], (0, 0, 0.7 + 0.15), (L + 1.8, P + 1.8, 0.3))
    z0 = h0
    Modelo.caixa(g["Papel"], (0, 0, z0 + H1 / 2), (L, P, H1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            Modelo.caixa(g["Estrutura"], (sx * L / 2, sy * P / 2, z0 + H1 / 2), (0.6, 0.6, H1 + 0.2))
    for sy in (-1, 1):
        for i in range(1, 6):
            Modelo.caixa(g["Estrutura"], (-L / 2 + i * L / 6, sy * (P / 2 + 0.03), z0 + H1 / 2), (0.22, 0.14, H1))
        for z in (z0 + 0.3, z0 + H1 * 0.55, z0 + H1 - 0.2):
            Modelo.caixa(g["Estrutura"], (0, sy * (P / 2 + 0.03), z), (L, 0.16, 0.24))
    for sx in (-1, 1):
        for i in range(1, 5):
            Modelo.caixa(g["Estrutura"], (sx * (L / 2 + 0.03), -P / 2 + i * P / 5, z0 + H1 / 2), (0.14, 0.22, H1))
        for z in (z0 + 0.3, z0 + H1 * 0.55, z0 + H1 - 0.2):
            Modelo.caixa(g["Estrutura"], (sx * (L / 2 + 0.03), 0, z), (0.16, P, 0.24))
    # telhado de dois níveis (quatro águas)
    z1 = z0 + H1
    Modelo.telhado_4_aguas(g["Telhado"], (0, 0, z1), L + 5.0, P + 5.0, 3.0)
    Modelo.caixa(g["Papel"], (0, 0, z1 + 3.0 + 1.0), (L - 5.0, P - 5.0, 2.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            Modelo.caixa(g["Estrutura"], (sx * (L - 5.0) / 2, sy * (P - 5.0) / 2, z1 + 4.0), (0.4, 0.4, 2.1))
    Modelo.telhado_4_aguas(g["Telhado"], (0, 0, z1 + 5.0), L - 1.0, P - 1.5, 3.2)
    Modelo.cilindro(g["Ouro"], (0, 0, z1 + 8.4), 0.12, 1.4, 6, 0.0, tampas=False)
    # entrada: portas de correr, panos vermelhos, lanternas de pedra
    yf = -P / 2
    Modelo.caixa(g["Estrutura"], (0, yf - 0.06, z0 + 1.6), (4.6, 0.3, 3.2))
    Modelo.caixa(g["Porta"], (-1.05, yf - 0.2, z0 + 1.45), (2.0, 0.14, 2.9))
    Modelo.caixa(g["Porta"], (1.05, yf - 0.2, z0 + 1.45), (2.0, 0.14, 2.9))
    for x in (-4.4, 4.4):
        Modelo.caixa(g["Pano"], (x, yf - 0.16, z0 + 2.2), (0.95, 0.08, 2.6))
    Modelo.caixa(g["Pedra"], (0, yf - 1.3, 0.55), (5.6, 1.4, 0.3))
    Modelo.caixa(g["Pedra"], (0, yf - 2.1, 0.3), (6.4, 1.4, 0.3))
    for x in (-3.6, 3.6):
        Modelo.caixa(g["Pedra"], (x, yf - 2.1, 0.8), (0.8, 0.8, 0.5))
        Modelo.caixa(g["Pedra"], (x, yf - 2.1, 1.4), (0.35, 0.35, 0.8))
        Modelo.caixa(g["Luz"], (x, yf - 2.1, 2.0), (0.7, 0.7, 0.6))
        Modelo.caixa(g["Pedra"], (x, yf - 2.1, 2.45), (1.0, 1.0, 0.25))
    # janelas de papel no alto
    return m


def barraca(semente=1):
    """Estande de mercado: balcão, quatro postes, toldo listrado e mercadorias."""
    rng = random.Random(semente)
    m = Modelo(f"Barraca{semente}")
    m.espelhar_y = True
    m.grupo("Madeira", (118, 84, 54), "WoodPlanks")
    m.grupo("PanoA", (176, 56, 48), "Fabric")
    m.grupo("PanoB", (236, 224, 196), "Fabric")
    m.grupo("Frutas", (196, 52, 44), "SmoothPlastic")
    m.grupo("Sacos", (198, 170, 118), "Fabric")
    m.grupo("Caixas", (150, 108, 68), "WoodPlanks")
    g = {n: v["bm"] for n, v in m.grupos.items()}
    W, D, H = 8.0, 6.0, 4.4
    Modelo.caixa(g["Madeira"], (0, -D / 2 + 0.9, 0.55), (W - 0.6, 1.2, 1.1))  # balcão
    Modelo.caixa(g["Madeira"], (0, -D / 2 + 0.9, 1.15), (W - 0.2, 1.5, 0.16))  # tampo
    for sx in (-1, 1):
        for sy in (-1, 1):
            Modelo.caixa(g["Madeira"], (sx * (W / 2 - 0.2), sy * (D / 2 - 0.2), H / 2), (0.3, 0.3, H))
    Modelo.caixa(g["Madeira"], (0, D / 2 - 0.2, H / 2), (W - 0.2, 0.2, H * 0.9))  # fundo
    Modelo.caixa(g["Madeira"], (0, D / 2 - 0.7, 2.0), (W - 0.6, 0.9, 0.14))  # prateleira
    # toldo de faixas alternadas, mais baixo na frente
    n = 8
    larg = (W + 0.8) / n
    for i in range(n):
        x = -(W + 0.8) / 2 + larg * (i + 0.5)
        Modelo.telhado(g["PanoA" if i % 2 == 0 else "PanoB"], (x, 0, H), larg, D + 1.4, 1.1)
    # mercadorias: frutas no balcão, sacos e caixas atrás
    for i in range(7):
        Modelo.esfera(g["Frutas"], (-2.6 + i * 0.75 + rng.uniform(-0.1, 0.1), -D / 2 + 0.9 + rng.uniform(-0.3, 0.3), 1.4), 0.26, subdiv=1)
    for x, y in ((-2.4, 1.1), (2.3, 1.3)):
        Modelo.esfera(g["Sacos"], (x, y, 0.55), 0.7, (1, 0.9, 0.8), 1, 0.08, rng, corte_z=0.0)
    for x, y, a in ((0.4, 1.6, 0.2), (1.6, 1.0, -0.15)):
        Modelo.caixa(g["Caixas"], (x, y, 0.5), (1.0, 1.0, 1.0), a)
    Modelo.caixa(g["Caixas"], (0.9, 1.4, 1.5), (0.8, 0.8, 0.8), 0.4)
    return m


# ---------- acampamento ----------
TENDAS = [((196, 178, 142), (92, 60, 40)), ((150, 98, 72), (70, 52, 40)), ((108, 128, 150), (84, 62, 44))]


def tenda(semente):
    """Tenda A-frame: lona, abertura escura na frente, mastros e estacas."""
    rng = random.Random(semente * 5 + 3)
    lona_cor, madeira_cor = TENDAS[(semente - 1) % len(TENDAS)]
    m = Modelo(f"Tenda{semente}")
    m.espelhar_y = True
    lona = m.grupo("Lona", lona_cor, "Fabric")
    interior = m.grupo("Interior", (44, 36, 30), "Fabric")
    madeira = m.grupo("Madeira", madeira_cor, "Wood")
    W, L, H = 4.6 + rng.random() * 0.6, 5.6 + rng.random() * 0.8, 3.4 + rng.random() * 0.4
    Modelo.prisma_y(lona, (0, 0, 0), W, L, H)
    # abertura: prisma escuro menor, um pouco à frente da testa (frente = -Y no modelo)
    Modelo.prisma_y(interior, (0, -L / 2 - 0.03, 0), W * 0.52, 0.12, H * 0.62)
    for s in (-1, 1):  # mastros da frente e faixa de cumeeira
        Modelo.ramo(madeira, (s * W * 0.26, -L / 2 - 0.12, 0), (s * W * 0.06, -L / 2 - 0.12, H * 0.98), 0.1, 0.08, 6)
    Modelo.cilindro(madeira, (0, 0, H + 0.02), 0.09, L + 0.5, 6, eixo="Y")
    for sx in (-1, 1):
        for sy in (-1, 1):
            Modelo.ramo(madeira, (sx * (W / 2 + 0.7), sy * L * 0.42, 0.0), (sx * (W / 2 + 0.2), sy * L * 0.42, 0.45), 0.07, 0.05, 5)
    return m


def fardo(semente):
    m = Modelo("Fardo")
    m.espelhar_y = False
    feno = m.grupo("Feno", (214, 184, 98), "Fabric")
    corda = m.grupo("Corda", (120, 90, 60), "Fabric")
    Modelo.cilindro(feno, (0, 0, 0.95), 0.95, 1.8, 10, eixo="X")
    for x in (-0.55, 0.55):
        Modelo.cilindro(corda, (x, 0, 0.95), 0.99, 0.12, 10, eixo="X")
    Modelo.cilindro(feno, (0, 1.9, 0.95), 0.95, 1.8, 10, eixo="X")
    for x in (-0.55, 0.55):
        Modelo.cilindro(corda, (x, 1.9, 0.95), 0.99, 0.12, 10, eixo="X")
    return m


def placa(semente):
    """Poste com duas tábuas-seta apontando em sentidos opostos."""
    m = Modelo("Placa")
    madeira = m.grupo("Madeira", (92, 66, 44), "Wood")
    tabua = m.grupo("Tabua", (186, 150, 98), "WoodPlanks")
    Modelo.cilindro(madeira, (0, 0, 1.6), 0.16, 3.2, 6)
    for z, sx, giro in ((2.7, 1, 0.12), (2.15, -1, -0.1)):
        Modelo.caixa(tabua, (sx * 0.75, 0, z), (1.5, 0.12, 0.44), giro)
        Modelo.caixa(tabua, (sx * 1.58, 0, z + giro * 0.8), (0.5, 0.12, 0.44), giro + sx * 0.7)
    return m


def tripe(semente):
    """Tripé de varas com caldeirão de ferro pendurado."""
    rng = random.Random(semente)
    m = Modelo("Tripe")
    madeira = m.grupo("Madeira", (98, 70, 46), "Wood")
    ferro = m.grupo("Ferro", (46, 46, 52), "Metal")
    topo = (0, 0, 3.4)
    for i in range(3):
        a = i * math.tau / 3 + 0.3
        Modelo.ramo(madeira, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0), topo, 0.1, 0.07, 5)
    Modelo.ramo(ferro, (0, 0, 3.4), (0, 0, 2.35), 0.03, 0.03, 4)
    Modelo.esfera(ferro, (0, 0, 1.85), 0.62, (1, 1, 0.8), 2, 0.0, corte_z=1.7)
    Modelo.cilindro(ferro, (0, 0, 2.4), 0.5, 0.12, 12, 0.5)
    return m
