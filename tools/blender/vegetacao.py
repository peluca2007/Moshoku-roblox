"""Vegetação e props naturais: floresta sombria e campos/margens (V3 do Mundo V2).

Paleta de fim de tarde, saturação moderada: verdes-azulados escuros na floresta, verdes
quentes/oliva nos campos. Cada forma tem 2 tons por material, repartidos por grupo
(`Copa`/`CopaClara` etc.), porque o Roblox ignora cor de material/vértice do FBX.
Contrato igual ao de modelos.py: função `(semente, **opcoes) -> Modelo`, origem no chão
centrada (feita por `apoiar_no_chao`), faces para fora, menos de ~2.000 triângulos.
Opções lidas: `variante` (string) e `flores` (int); o resto vem da semente.
"""
import math
import random

import bmesh
from mathutils import Vector

import formas
from formas import dividir_tons, extruir, lamina, luz, tronco
from lib import Modelo

TAU = math.tau


def _inclinar(p, lean, altura):
    """Desloca um ponto para o 'lean' da árvore, crescendo com o quadrado da altura relativa."""
    f = (p[2] / altura) ** 2 if altura else 0.0
    return (p[0] + lean[0] * f, p[1] + lean[1] * f, p[2])


# ======================================================================================
# 1. FLORESTA SOMBRIA
# ======================================================================================
def _camada_abeto(bm, cx, cy, z0, raio, alt, n, rng, giro):
    """Uma camada de galhos de abeto: estrela de 2n pontas que pendem, anel médio mais alto
    e ponta no centro (perfil côncavo, fechada por baixo)."""
    ext, mid = [], []
    for k in range(2 * n):
        a = giro + k * math.pi / n
        longo = k % 2 == 0
        r = raio * (1.0 if longo else 0.7) * rng.uniform(0.8, 1.12)
        dz = -0.07 * alt if longo else 0.1 * alt
        ext.append(bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, z0 + dz + rng.uniform(-0.04, 0.04) * alt)))
        rm = raio * 0.48 * rng.uniform(0.85, 1.12)
        mid.append(bm.verts.new((cx + math.cos(a) * rm, cy + math.sin(a) * rm, z0 + alt * (0.46 + (0.06 if longo else 0.0)))))
    apice = bm.verts.new((cx + rng.uniform(-0.2, 0.2), cy + rng.uniform(-0.2, 0.2), z0 + alt))
    baixo = bm.verts.new((cx, cy, z0 + alt * 0.3))
    for k in range(2 * n):
        j = (k + 1) % (2 * n)
        bm.faces.new((ext[k], ext[j], mid[j], mid[k]))
        bm.faces.new((mid[k], mid[j], apice))
        bm.faces.new((baixo, ext[j], ext[k]))


def abeto(semente, **_):
    """Abeto alto e escuro (3 variantes pela semente: 1 esguio ~31, 2 largo ~38, 3 altíssimo ~45)."""
    rng = random.Random(semente * 31 + 2)
    v = (semente - 1) % 3
    m = Modelo(f"AbetoSombrio{semente}")
    m.grupo("Tronco", (70, 54, 42), "Wood")
    m.grupo("Copa", (24, 56, 50), "Grass")
    m.grupo("CopaClara", (46, 84, 62), "Grass")
    alt = (31.0, 38.0, 45.0)[v] + rng.uniform(-1.0, 1.0)
    raio = (5.4, 7.0, 6.2)[v]
    n_cam = (11, 12, 14)[v]
    base_copa = (3.4, 4.4, 5.2)[v]
    lean = (rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2))
    copa = bmesh.new()
    topo_util = alt - base_copa
    pulos = {rng.randrange(3, n_cam - 3)} if v == 1 else set()  # falha no meio: silhueta irregular
    for i in range(n_cam):
        if i in pulos:
            continue
        f = i / n_cam
        z0 = base_copa + topo_util * (f ** 0.95) * 0.9
        proximo = base_copa + topo_util * (((i + 1) / n_cam) ** 0.95) * 0.9
        h = max(3.4, (proximo - z0) * 2.9)
        r = raio * (1.0 - f) ** 0.82 * rng.uniform(0.9, 1.08) + 0.55
        cx, cy, _z = _inclinar((0, 0, z0), lean, alt)
        _camada_abeto(copa, cx, cy, z0, r, h, rng.randint(6, 8), rng, rng.random() * TAU)
    # ponta
    z0 = base_copa + topo_util * 0.9
    cx, cy, _z = _inclinar((0, 0, z0), lean, alt)
    if v != 2:
        _camada_abeto(copa, cx, cy, z0, 1.5, alt - z0, 6, rng, rng.random() * TAU)
    else:
        _camada_abeto(copa, cx, cy, z0 - 0.5, 1.9, alt * 0.9 - z0 + 0.5, 6, rng, rng.random() * TAU)
    dividir_tons(m, copa, "CopaClara", "Copa", lambda f: luz(f, 0.5))
    # tronco: raiz alargada, fuste cônico com a inclinação e tocos de galhos secos
    g = m.grupos["Tronco"]["bm"]
    topo_t = alt * (0.94 if v != 2 else 1.02)
    pts, rs = [], []
    for k in range(7):
        z = topo_t * k / 6
        pts.append(_inclinar((0, 0, z), lean, alt))
        rs.append(max(1.15 * (1.0 - k / 6) ** 0.8 + 0.1, 0.1) * (1.35 if k == 0 else 1.0))
    tronco(g, pts, rs, 7, rng, 0.07, ponta=True)
    for _ in range(4):
        a = rng.random() * TAU
        Modelo.ramo(g, (math.cos(a) * 0.8, math.sin(a) * 0.8, 0.9), (math.cos(a) * 2.1, math.sin(a) * 2.1, 0.08), 0.42, 0.12, 5)
    for _ in range(rng.randint(4, 6)):
        z = rng.uniform(0.7, 0.98) * base_copa
        a = rng.random() * TAU
        p = _inclinar((0, 0, z), lean, alt)
        Modelo.ramo(g, (p[0], p[1], z), (p[0] + math.cos(a) * 1.5, p[1] + math.sin(a) * 1.5, z + rng.uniform(-0.3, 0.7)), 0.17, 0.05, 4)
    return m


def carvalho_antigo(semente, **_):
    """Carvalho velho e retorcido: tronco grosso torcido, raízes que afloram, galhos
    horizontais e copa larga e baixa em almofadas oliva (2 variantes pela semente)."""
    rng = random.Random(semente * 29 + 7)
    m = Modelo(f"CarvalhoAntigo{semente}")
    m.grupo("Tronco", (82, 64, 50), "Wood")
    m.grupo("Musgo", (66, 90, 46), "Grass")
    m.grupo("Oco", (30, 24, 20), "Slate")
    m.grupo("Copa", (62, 82, 44), "Grass")
    m.grupo("CopaClara", (112, 130, 58), "Grass")
    if semente % 2 == 0:
        m.grupo("CopaOcre", (128, 98, 46), "Grass")
    sentido = 1 if semente % 2 else -1
    giro0 = rng.random() * TAU
    altura = 5.6 + rng.random() * 1.2
    g = m.grupos["Tronco"]["bm"]
    pts, rs = [], []
    for k in range(6):
        t = k / 5
        a = giro0 + sentido * t * 2.4
        d = 1.4 * math.sin(t * math.pi * 0.9) * (0.7 + 0.3 * rng.random())
        pts.append((math.cos(a) * d, math.sin(a) * d, altura * t))
        rs.append((2.7, 2.1, 1.8, 1.7, 1.55, 1.35)[k])
    tronco(g, pts, rs, 8, rng, 0.1, torcao=sentido * 0.35)
    topo = Vector(pts[-1])
    # raízes que afloram
    musgo = m.grupos["Musgo"]["bm"]
    for i in range(5):
        a = giro0 + i * TAU / 5 + rng.uniform(-0.3, 0.3)
        c, s = math.cos(a), math.sin(a)
        tronco(g, [(c * 0.4, s * 0.4, 2.4), (c * 1.7, s * 1.7, 1.55), (c * 3.0, s * 3.0, 0.7), (c * 4.3, s * 4.3, 0.05)],
               [0.85, 0.62, 0.4, 0.16], 5, rng, 0.1, ponta=False)
        Modelo.esfera(musgo, (c * 2.2, s * 2.2, 1.35), 0.7, (1.2, 0.9, 0.3), 1, 0.12, rng)
    Modelo.esfera(musgo, (math.cos(giro0) * 1.2, math.sin(giro0) * 1.2, 2.9), 0.9, (0.7, 1.0, 1.4), 1, 0.15, rng)
    # oco no tronco (achatado ao longo de X: fica na face +X)
    px, py, pz = pts[2]
    Modelo.esfera(m.grupos["Oco"]["bm"], (px + 1.45, py, pz - 0.2), 1.0, (0.28, 0.75, 1.25), 1, 0.1, rng)
    # galhos principais e almofadas da copa
    copa = bmesh.new()
    ocre = bmesh.new()
    n_galhos = rng.randint(4, 5)
    for i in range(n_galhos):
        a = giro0 + sentido * 0.9 + i * TAU / n_galhos + rng.uniform(-0.35, 0.35)
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = topo - Vector((0, 0, rng.uniform(0.3, 1.4)))
        p1 = p0 + d * rng.uniform(2.4, 3.2) + Vector((0, 0, rng.uniform(1.6, 2.6)))
        a2 = a + rng.uniform(-0.5, 0.5)
        d2 = Vector((math.cos(a2), math.sin(a2), 0))
        p2 = p1 + d2 * rng.uniform(2.8, 3.8) + Vector((0, 0, rng.uniform(0.0, 0.9)))
        p3 = p2 + d2 * rng.uniform(1.8, 2.6) + Vector((0, 0, rng.uniform(0.8, 1.8)))
        tronco(g, [p0, p1, p2, p3], [1.2, 0.9, 0.62, 0.3], 6, rng, 0.08)
        # almofadas encostadas umas nas outras ao longo do galho: copa contínua, não bolas soltas
        ao_longo = [(p1.lerp(p2, 0.3), 3.0), (p1.lerp(p2, 0.85), 3.5), (p2.lerp(p3, 0.6), 3.4), (p3, 2.7)]
        for ponto, raio in ao_longo:
            r = raio * rng.uniform(0.9, 1.12)
            alvo = ocre if (semente % 2 == 0 and ponto is not ao_longo[0][0] and rng.random() < 0.28) else copa
            Modelo.esfera(alvo, (ponto.x + rng.uniform(-0.5, 0.5), ponto.y + rng.uniform(-0.5, 0.5), ponto.z + 1.7), r, (1.0, 1.0, 0.7), 2 if r > 3.2 else 1, 0.22, rng)
    for i in range(7):  # tufos pendentes na borda: silhueta irregular
        a = rng.random() * TAU
        d = rng.uniform(5.0, 8.0)
        Modelo.esfera(copa, (topo.x + math.cos(a) * d, topo.y + math.sin(a) * d, topo.z + rng.uniform(0.4, 1.6)), rng.uniform(1.3, 2.0), (1.0, 1.0, 0.75), 1, 0.22, rng)
    for dx, dy, dz, r in ((0, 0, 3.1, 4.0), (rng.uniform(-2.0, 2.0), rng.uniform(-2.0, 2.0), 4.6, 3.0)):
        Modelo.esfera(copa, (topo.x + dx, topo.y + dy, topo.z + dz), r, (1.0, 1.0, 0.68), 1, 0.2, rng)
    dividir_tons(m, copa, "CopaClara", "Copa", lambda f: luz(f, 0.38))
    if semente % 2 == 0:
        dividir_tons(m, ocre, "CopaOcre", "CopaOcre", lambda f: True)
    else:
        ocre.free()
    return m


def _fronde(bm, base, az, comp, incl, curva, larg, rng, pares=7):
    """Fronde pinada: nervura em arco (lâmina fina) e folíolos em pares, cada um um tetraedro
    achatado (4 triângulos). Comprimento dos folíolos cai até a ponta."""
    dh = Vector((math.cos(az), math.sin(az), 0))
    lado = Vector((-math.sin(az), math.cos(az), 0))
    lamina(bm, base, az, comp, 0.2, incl, curva, segs=pares + 1, grossura=0.07)
    pos, th, passo = Vector(base), incl, comp / (pares + 1)
    for i in range(1, pares + 1):
        # integra a nervura até o nó i (mesma curva de `lamina`, com 5 segmentos aproximados)
        tang = dh * math.sin(th) + formas.CIMA * math.cos(th)
        pos = pos + tang * passo
        pos.z = max(pos.z, 0.04)
        th += curva / (pares + 1)
        t = i / (pares + 1)
        tang = dh * math.sin(th) + formas.CIMA * math.cos(th)
        n = lado.cross(tang).normalized()
        comp_f = larg * (1.0 - t) ** 0.55 * rng.uniform(0.9, 1.1)
        for s in (-1, 1):
            a = pos - tang * 0.28
            b = pos + tang * 0.28
            c = pos + n * 0.06
            ponta = pos + lado * s * comp_f + tang * comp_f * 0.55 - formas.CIMA * comp_f * 0.12
            ponta.z = max(ponta.z, 0.04)
            va, vb, vc, vp = (bm.verts.new(p) for p in (a, b, c, ponta))
            for f in ((va, vb, vc), (va, vb, vp), (vb, vc, vp), (vc, va, vp)):
                bm.faces.new(f)


def samambaia(semente, **_):
    """Samambaia em tufo: frondes pinadas em arco, as de dentro eretas e as de fora tombadas (2 variantes)."""
    rng = random.Random(semente * 37 + 5)
    v = (semente - 1) % 2
    m = Modelo(f"Samambaia{semente}")
    m.grupo("Folhas", (54, 92, 48), "Grass")
    m.grupo("FolhasClaras", (98, 134, 60), "Grass")
    n = (9, 12)[v]
    comp = (3.3, 4.0)[v]
    escuro, claro = bmesh.new(), bmesh.new()
    for i in range(n):
        interna = i % 3 == 0
        az = i * TAU / n + rng.uniform(-0.25, 0.25)
        c = comp * (0.65 if interna else rng.uniform(0.9, 1.1))
        incl = rng.uniform(0.1, 0.4) if interna else rng.uniform(0.4, 0.85)
        curva = rng.uniform(0.8, 1.2) if interna else rng.uniform(1.1, 1.6)
        alvo = claro if rng.random() < 0.4 else escuro
        _fronde(alvo, (math.cos(az) * 0.12, math.sin(az) * 0.12, 0.0), az, c, incl, curva, (1.1, 1.3)[v] * (0.8 if interna else 1.0), rng)
    for bm_, g in ((escuro, "Folhas"), (claro, "FolhasClaras")):
        formas.orientar(bm_)
        formas.anexar(m.grupos[g]["bm"], bm_)
        bm_.free()
    return m


def cogumelos(semente, variante="comum", **_):
    """Aglomerado de cogumelos. variante='luminoso': chapéus em grupo próprio 'ChapeuLuz' (Neon)."""
    rng = random.Random(semente * 41 + 3)
    lum = variante == "luminoso"
    m = Modelo(f"Cogumelos{'Luz' if lum else ''}{semente}")
    haste = m.grupo("Haste", (166, 184, 172) if lum else (214, 198, 166), "SmoothPlastic")
    m.grupo("Lamina", (52, 104, 116) if lum else (226, 208, 174), "SmoothPlastic")
    m.grupo("Musgo", (62, 88, 48), "Grass")
    if lum:
        m.grupo("ChapeuLuz", (92, 220, 204), "Neon")
    else:
        m.grupo("Chapeu", (122, 56, 44), "SmoothPlastic")
        m.grupo("ChapeuClaro", (170, 88, 58), "SmoothPlastic")
        m.grupo("Pintas", (236, 226, 200), "SmoothPlastic")
    tamanhos = [1.35, 0.95, 0.85, 0.7, 0.55, 0.42, 0.34]
    posicoes = [(0, 0)]
    for i in range(1, len(tamanhos)):
        a = i * 2.4 + rng.uniform(-0.4, 0.4)
        d = 1.15 + 0.35 * i * rng.uniform(0.6, 1.0) * 0.5
        posicoes.append((math.cos(a) * d, math.sin(a) * d))
    for tam, (x, y) in zip(tamanhos, posicoes):
        h = tam * rng.uniform(1.15, 1.6)
        lx, ly = rng.uniform(-0.25, 0.25) * tam, rng.uniform(-0.25, 0.25) * tam
        tronco(haste, [(x, y, 0), (x + lx * 0.5, y + ly * 0.5, h * 0.5), (x + lx, y + ly, h)], [tam * 0.26, tam * 0.2, tam * 0.17], 6)
        cap = bmesh.new()
        r = tam * 0.82
        cz = h - 0.04
        Modelo.esfera(cap, (x + lx, y + ly, cz), r, (1.0, 1.0, 0.6), 1, 0.06, rng, corte_z=cz)
        sob, resto = formas.dividir(cap, lambda f: f.normal.z < -0.6)
        cap.free()
        formas.anexar(m.grupos["Lamina"]["bm"], sob)
        sob.free()
        if lum:
            formas.anexar(m.grupos["ChapeuLuz"]["bm"], resto)
            resto.free()
        else:
            topo, lado = formas.dividir(resto, lambda f: f.normal.z > 0.55)
            resto.free()
            formas.anexar(m.grupos["ChapeuClaro"]["bm"], topo)
            formas.anexar(m.grupos["Chapeu"]["bm"], lado)
            topo.free()
            lado.free()
            if tam > 0.8:
                for _ in range(3):
                    phi, th = rng.uniform(0.35, 0.95), rng.random() * TAU
                    Modelo.esfera(m.grupos["Pintas"]["bm"], (x + lx + r * math.sin(phi) * math.cos(th), y + ly + r * math.sin(phi) * math.sin(th),
                                                             cz + r * 0.6 * math.cos(phi) * 0.95), r * 0.13, (1, 1, 0.55), 0)
    for cx, cy, r in ((-0.6, 0.4, 0.95), (0.9, -0.5, 0.7)):
        Modelo.esfera(m.grupos["Musgo"]["bm"], (cx, cy, 0.0), r, (1.3, 1.0, 0.3), 1, 0.3, rng, corte_z=0.0)
    return m


def tora_musgo(semente, **_):
    """Tronco caído e musgoso: ponta quebrada com farpas, ponta de raízes, cogumelos de tronco."""
    rng = random.Random(semente * 43 + 9)
    m = Modelo(f"ToraMusgo{semente}")
    casca = m.grupo("Casca", (84, 64, 48), "Wood")
    cerne = m.grupo("Cerne", (182, 150, 104), "Wood")
    m.grupo("Musgo", (66, 94, 48), "Grass")
    m.grupo("MusgoClaro", (104, 132, 64), "Grass")
    m.grupo("Prateleira", (196, 156, 100), "Wood")
    comp = 9.0 + rng.random() * 1.2
    raio = 1.25
    pts, rs = [], []
    for k in range(5):
        t = k / 4
        pts.append((-comp / 2 + comp * t, math.sin(t * math.pi) * 0.25 * rng.choice((-1, 1)) * 0.5, raio + 0.1 - 0.12 * math.sin(t * math.pi)))
        rs.append(raio * (1.1 - 0.22 * t))
    tronco(casca, pts, rs, 9, rng, 0.05)
    # ponta quebrada (+X): disco de cerne e farpas
    xe = pts[-1][0]
    Modelo.cilindro(cerne, (xe + 0.02, pts[-1][1], pts[-1][2]), rs[-1] * 0.86, 0.06, 9, None, "X", tampas=True)
    for i in range(4):
        a = i * TAU / 4 + rng.uniform(-0.3, 0.3)
        base = (xe - 0.1, pts[-1][1] + math.cos(a) * rs[-1] * 0.75, pts[-1][2] + math.sin(a) * rs[-1] * 0.75)
        Modelo.ramo(cerne, base, (xe + rng.uniform(0.4, 1.0), base[1] * 0.9, base[2] * 0.95 + rng.uniform(0.0, 0.4)), 0.3, 0.05, 4)
    # ponta das raízes (-X): bola de raízes sem terra
    x0 = pts[0][0]
    Modelo.cilindro(casca, (x0 - 0.2, pts[0][1], pts[0][2]), rs[0] * 1.15, 0.8, 9, rs[0] * 0.95, "X", tampas=True)
    for i in range(6):
        a = i * TAU / 6 + rng.uniform(-0.3, 0.3)
        y1, z1 = math.cos(a), math.sin(a)
        tronco(casca, [(x0 - 0.2, y1 * 0.8, pts[0][2] + z1 * 0.8), (x0 - 1.0, y1 * 1.7, max(pts[0][2] + z1 * 1.5, 0.45)),
                       (x0 - 1.7, y1 * 2.2, max(pts[0][2] + z1 * 1.8 + 0.2, 0.5))], [0.72, 0.5, 0.14], 5, rng, 0.1)
    # galhos curtos
    for _ in range(2):
        x = rng.uniform(-comp * 0.15, comp * 0.3)
        lado = rng.choice((-1, 1))
        Modelo.ramo(casca, (x, lado * 0.5, raio * 1.6), (x + rng.uniform(-0.6, 0.6), lado * 1.4, raio * 1.6 + rng.uniform(1.2, 2.2)), 0.3, 0.08, 5)
    # musgo em duas tonalidades por cima
    mus = bmesh.new()
    for i in range(7):
        x = -comp * 0.42 + i * comp * 0.13 + rng.uniform(-0.3, 0.3)
        Modelo.esfera(mus, (x, rng.uniform(-0.3, 0.3), raio * 2.0 - 0.28), rng.uniform(0.6, 1.0), (1.5, 0.95, 0.38), 1, 0.15, rng)
    dividir_tons(m, mus, "MusgoClaro", "Musgo", lambda f: luz(f, 0.6))
    for lado in (-1, 1):
        Modelo.esfera(m.grupos["Prateleira"]["bm"], (rng.uniform(-1, 2), lado * raio * 0.95, raio * 1.1), 0.5, (1.0, 0.9, 0.22), 1, 0.08, rng)
    return m


def raizes_expostas(semente, **_):
    """Toco com raízes grossas que afloram de um monte de terra, com musgo (para sub-bosque)."""
    rng = random.Random(semente * 47 + 1)
    m = Modelo(f"RaizesExpostas{semente}")
    casca = m.grupo("Casca", (80, 62, 48), "Wood")
    terra = m.grupo("Terra", (64, 50, 40), "Ground")
    musgo = m.grupo("Musgo", (68, 94, 48), "Grass")
    cerne = m.grupo("Cerne", (176, 146, 104), "Wood")
    Modelo.esfera(terra, (0, 0, 0), 3.4, (1.1, 1.0, 0.3), 1, 0.12, rng, corte_z=0.0)
    h = 2.6 + rng.random() * 0.8
    tronco(casca, [(0, 0, 0.6), (0.1, 0.0, h * 0.5), (-0.1, 0.1, h)], [1.9, 1.35, 1.2], 8, rng, 0.1)
    Modelo.cilindro(cerne, (-0.1, 0.1, h + 0.02), 1.04, 0.06, 8, None, "Z", tampas=True)
    n = 6
    for i in range(n):
        a = i * TAU / n + rng.uniform(-0.25, 0.25)
        c, s = math.cos(a), math.sin(a)
        long = rng.uniform(3.4, 4.6)
        tronco(casca, [(c * 0.8, s * 0.8, 1.7), (c * long * 0.38, s * long * 0.38, 1.7 + rng.uniform(0, 0.3)), (c * long * 0.72, s * long * 0.72, 0.75),
                       (c * long, s * long, 0.08)], [1.15, 0.9, 0.55, 0.2], 6, rng, 0.1)
        if rng.random() < 0.6:
            Modelo.esfera(musgo, (c * long * 0.4, s * long * 0.4, 2.2), 0.6, (1.2, 0.9, 0.3), 1, 0.12, rng)
    Modelo.esfera(musgo, (0.2, -0.1, h + 0.12), 0.9, (1.1, 0.9, 0.3), 1, 0.12, rng)
    return m


# ======================================================================================
# 2. CAMPOS E MARGENS
# ======================================================================================
def tufo_grama(semente, **_):
    """Tufo de grama alta: lâminas que tombam para fora; a ponta é mais clara (2 variantes)."""
    rng = random.Random(semente * 53 + 6)
    v = (semente - 1) % 2
    m = Modelo(f"TufoGrama{semente}")
    m.grupo("Folhas", (80, 112, 50), "Grass")
    m.grupo("FolhasClaras", (140, 164, 76), "Grass")
    if v == 1:
        m.grupo("Palha", (190, 168, 98), "Grass")
    corpo = bmesh.new()
    n = (28, 34)[v]
    alt = (3.0, 3.6)[v]
    raio = (0.9, 1.5)[v]
    for i in range(n):
        az = rng.random() * TAU
        d = rng.random() * raio
        c = alt * rng.uniform(0.55, 1.0)
        lamina(corpo, (math.cos(az) * d, math.sin(az) * d, 0), az + rng.uniform(-0.3, 0.3), c, rng.uniform(0.5, 0.75),
               rng.uniform(0.05, 0.35) + d * 0.3, rng.uniform(0.3, 0.9), segs=3, grossura=0.05)
    dividir_tons(m, corpo, "FolhasClaras", "Folhas", lambda f: f.calc_center_median().z > alt * 0.42)
    if v == 1:
        palha = m.grupos["Palha"]["bm"]
        for i in range(6):
            az = rng.random() * TAU
            d = rng.random() * raio * 0.7
            x, y = math.cos(az) * d, math.sin(az) * d
            h = alt * rng.uniform(1.05, 1.4)
            tronco(palha, [(x, y, 0), (x + math.cos(az) * 0.3, y + math.sin(az) * 0.3, h * 0.55), (x + math.cos(az) * 0.55, y + math.sin(az) * 0.55, h)],
                   [0.05, 0.04, 0.03], 3)
            Modelo.esfera(palha, (x + math.cos(az) * 0.55, y + math.sin(az) * 0.55, h), 0.17, (0.6, 0.6, 1.9), 0)
    return m


PALETAS_FLORES = [
    ((152, 112, 188), (232, 226, 206)),  # lilás e branco
    ((232, 192, 74), (218, 124, 54)),    # amarelo e laranja
    ((198, 74, 70), (236, 232, 218)),    # papoula e branco
]


def flores_silvestres(semente, **_):
    """Canteiro de flores silvestres; a semente (1..3) escolhe a combinação de cores."""
    rng = random.Random(semente * 59 + 8)
    a_cor, b_cor = PALETAS_FLORES[(semente - 1) % 3]
    m = Modelo(f"Flores{semente}")
    m.grupo("Folhas", (62, 100, 48), "Grass")
    m.grupo("FolhasClaras", (110, 144, 66), "Grass")
    m.grupo("Haste", (74, 112, 54), "Grass")
    m.grupo("Petalas", a_cor, "SmoothPlastic")
    m.grupo("PetalasB", b_cor, "SmoothPlastic")
    m.grupo("Miolo", (226, 170, 52) if semente != 2 else (120, 78, 40), "SmoothPlastic")
    base = bmesh.new()
    for i in range(16):
        az = rng.random() * TAU
        d = rng.random() * 2.0
        lamina(base, (math.cos(az) * d, math.sin(az) * d, 0), az + rng.uniform(-0.3, 0.3), rng.uniform(1.0, 1.7), rng.uniform(0.3, 0.44),
               rng.uniform(0.1, 0.5), rng.uniform(0.6, 1.1), segs=3, grossura=0.05)
    dividir_tons(m, base, "FolhasClaras", "Folhas", lambda f: f.calc_center_median().z > 0.75)
    for i in range(15):
        az = rng.random() * TAU
        d = math.sqrt(rng.random()) * 2.1
        x, y = math.cos(az) * d, math.sin(az) * d
        h = rng.uniform(1.2, 2.5)
        ta = rng.random() * TAU
        tx, ty = x + math.cos(ta) * 0.3, y + math.sin(ta) * 0.3
        tronco(m.grupos["Haste"]["bm"], [(x, y, 0), ((x + tx) / 2, (y + ty) / 2, h * 0.5), (tx, ty, h)], [0.06, 0.05, 0.045], 3)
        alvo = m.grupos["Petalas" if rng.random() < 0.62 else "PetalasB"]["bm"]
        tam = rng.uniform(0.4, 0.55)
        if rng.random() < 0.18:  # botão fechado
            Modelo.esfera(alvo, (tx, ty, h + 0.1), tam * 0.5, (1, 1, 1.4), 0)
        else:
            Modelo.cilindro(alvo, (tx, ty, h + 0.05), tam, 0.16, 6, tam * 0.35, "Z", tampas=True, giro_z=rng.random())
            Modelo.cilindro(m.grupos["Miolo"]["bm"], (tx, ty, h + 0.17), tam * 0.38, 0.14, 5, tam * 0.2, "Z", tampas=True)
    return m


def juncos(semente, **_):
    """Junco e taboa para margem d'água: folhas longas e espigas marrons."""
    rng = random.Random(semente * 61 + 4)
    m = Modelo(f"Juncos{semente}")
    m.grupo("Folhas", (70, 100, 56), "Grass")
    m.grupo("FolhasClaras", (126, 148, 78), "Grass")
    m.grupo("Haste", (96, 120, 62), "Grass")
    m.grupo("Espiga", (102, 68, 44), "Slate")
    corpo = bmesh.new()
    for i in range(rng.randint(13, 16)):
        az = rng.random() * TAU
        d = math.sqrt(rng.random()) * 1.5
        lamina(corpo, (math.cos(az) * d, math.sin(az) * d, 0), az + rng.uniform(-0.4, 0.4), rng.uniform(2.6, 5.0), rng.uniform(0.22, 0.34),
               rng.uniform(0.04, 0.22), rng.uniform(0.35, 0.9), segs=4, grossura=0.05)
    dividir_tons(m, corpo, "FolhasClaras", "Folhas", lambda f: f.calc_center_median().z > 2.8)
    for i in range(rng.randint(4, 6)):
        az = rng.random() * TAU
        d = math.sqrt(rng.random()) * 1.1
        x, y = math.cos(az) * d, math.sin(az) * d
        h = rng.uniform(3.6, 5.2)
        ta = rng.random() * TAU
        lx, ly = math.cos(ta) * 0.35, math.sin(ta) * 0.35
        tronco(m.grupos["Haste"]["bm"], [(x, y, 0), (x + lx * 0.4, y + ly * 0.4, h * 0.5), (x + lx, y + ly, h)], [0.075, 0.06, 0.05], 4)
        Modelo.cilindro(m.grupos["Espiga"]["bm"], (x + lx, y + ly, h - 0.55), 0.21, 1.1, 6, 0.17, "Z", tampas=True)
        Modelo.cilindro(m.grupos["Espiga"]["bm"], (x + lx, y + ly, h + 0.3), 0.03, 0.5, 4, 0.0, "Z", tampas=False)
    return m


def rochedo(semente, **_):
    """Rochedo grande e musgoso, facetado (2 variantes: 1 massa larga, 2 laje alta inclinada)."""
    rng = random.Random(semente * 67 + 2)
    v = (semente - 1) % 2
    m = Modelo(f"Rochedo{semente}")
    m.grupo("Pedra", (108, 104, 98), "Slate")
    m.grupo("PedraClara", (150, 142, 128), "Slate")
    m.grupo("Musgo", (74, 104, 52), "Grass")
    pedra = bmesh.new()
    if v == 0:
        formas.bloco(pedra, (0, 0, 2.7), (9.5, 7.5, 5.8), rng, 0.25, (0.04, 0.0), 0.3, 0.07, 0.35, 3)
        formas.bloco(pedra, (-3.5, 2.3, 1.9), (5.0, 4.5, 4.0), rng, 0.8, (0.0, 0.1), 0.35, 0.06, 0.35, 2)
        formas.bloco(pedra, (3.9, -2.1, 1.6), (4.2, 4.0, 3.4), rng, -0.5, (0.1, 0.0), 0.3, 0.06, 0.35, 2)
        formas.bloco(pedra, (1.0, -4.0, 0.9), (3.0, 2.4, 1.9), rng, 0.2, (0.0, 0.0), 0.2, 0.05, 0.35, 2)
    else:
        formas.bloco(pedra, (0, 0, 4.0), (5.6, 4.6, 8.4), rng, 0.4, (0.06, -0.1), 0.5, 0.07, 0.3, 3)
        formas.bloco(pedra, (3.6, 1.2, 2.3), (4.6, 4.0, 4.6), rng, -0.6, (0.0, 0.12), 0.4, 0.06, 0.35, 2)
        formas.bloco(pedra, (-3.2, -1.6, 1.6), (4.0, 3.6, 3.2), rng, 0.9, (0.1, 0.0), 0.3, 0.06, 0.35, 2)
        formas.bloco(pedra, (1.0, -3.4, 0.8), (3.0, 2.2, 1.7), rng, 0.2, (0.0, 0.0), 0.2, 0.05, 0.35, 2)
    topo = max(vv.co.z for vv in pedra.verts)
    musgo, resto = formas.dividir(pedra, lambda f: f.normal.z > 0.62 and f.calc_center_median().z > topo * 0.3)
    pedra.free()
    clara, escura = formas.dividir(resto, lambda f: f.normal.z > 0.2)
    resto.free()
    formas.anexar(m.grupos["Musgo"]["bm"], musgo)
    formas.anexar(m.grupos["PedraClara"]["bm"], clara)
    formas.anexar(m.grupos["Pedra"]["bm"], escura)
    for b in (musgo, clara, escura):
        b.free()
    return m


GERADORES = {
    "abeto": abeto,
    "carvalhoantigo": carvalho_antigo,
    "samambaia": samambaia,
    "cogumelos": cogumelos,
    "toramusgo": tora_musgo,
    "raizes": raizes_expostas,
    "tufo": tufo_grama,
    "flores": flores_silvestres,
    "juncos": juncos,
    "rochedo": rochedo,
}
