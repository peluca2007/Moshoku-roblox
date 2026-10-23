"""Peças do AVATAR "quadradão" (16/10): cabelos, barbas, traços de raça, roupas básicas e o espelho de vila.

Todas as peças são ACESSÓRIOS do boneco R15 de cubos (ver `trajes.py`): a ORIGEM É O PONTO DE ENCAIXE
(`manter_origem`), sem `espelhar_y`. Convenção autoral: Z para cima, o personagem olha para -Y (a mão direita dele fica
em -X); o Roblox recebe (x, y, z) -> (-x, z, y). Linguagem visual BLOCADA/voxel: só caixas retas, degraus no lugar de
curvas, sem malha orgânica lisa. Cada peça tem grupos de cor claros (o Roblox recolore por grupo).

Unidades e proporções do boneco (studs, personagem de pé em y=0 no Roblox / z=0 aqui):
  Head   centro (0, 4.6, 0)  cubo de 1,2 (meia-aresta H = 0,6)   UpperTorso centro y=3,2  (2 x 1,6 x 1)
  LowerTorso centro y=2,2 (2 x 0,4 x 1)   mãos x=+-1,5 y=1,55 (1 x 0,3 x 1)   pernas x=+-0,5 (1 x 2 x 1)
O ROSTO (olhos, sobrancelhas, nariz, boca) é de outra peça: `shared/Aparencia/Catalogo.luau:ROSTO` (cabeça de referência
2 x 1 x 1, escalada aqui para 1,2). Alturas na cabeça de 1,2, z=0 no centro, frente em y=-0,6: olhos +0,14 (de -0,02 a +0,30),
sobrancelhas +0,41 (+-0,03), nariz -0,10 (de -0,15 a 0,0), boca -0,34 (de -0,46 a -0,21); x dos olhos +-0,27, boca até +-0,15.
Por isso:
  * nenhuma peça cobre o rosto entre z=-0,48 (abaixo da boca) e z=+0,44 (acima das sobrancelhas), salvo bigode/presas;
  * a linha do cabelo na frente fica em z >= 0,44 (mechas longas da franja) e, em geral, em 0,48.
Convenção das tabelas de encaixe: `ENCAIXES[peca] = [(parte, offset)]`, offset em eixos do ROBLOX relativo ao centro da
parte (mesmo contrato de `trajes.ENCAIXES`). Peças simétricas (botas, luvas) valem para os dois lados.
"""
import math
import random

import bmesh
import bpy

from geom import caixa, prisma  # noqa: F401
from lib import Modelo

PI = math.pi

# parte R15 -> centro no Roblox (x, y, z) do boneco de prévia
CENTROS = {
    "Head": (0.0, 4.6, 0.0),
    "UpperTorso": (0.0, 3.2, 0.0),
    "LowerTorso": (0.0, 2.2, 0.0),
    "RightHand": (1.5, 1.55, 0.0),
    "LeftHand": (-1.5, 1.55, 0.0),
    "RightFoot": (0.5, 0.15, 0.0),
    "LeftFoot": (-0.5, 0.15, 0.0),
}

# peça -> [(parte, offset em eixos do Roblox relativo ao centro da parte)]
ENCAIXES = {}


def _enc(peca, *encaixes):
    ENCAIXES[peca] = list(encaixes)


# --------------------------------------------------------------------------------------
# utilidades
def bl(bm, x, y, z, rot=(0.0, 0.0, 0.0)):
    """Caixa por extensões (x0, x1), (y0, y1), (z0, z1) em qualquer ordem."""
    x0, x1 = sorted(x)
    y0, y1 = sorted(y)
    z0, z1 = sorted(z)
    caixa(bm, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), rot)


def sim(bm, x, y, z):
    """Caixa e sua simétrica em x (as peças simétricas nascem aos pares)."""
    bl(bm, x, y, z)
    bl(bm, (-x[0], -x[1]), y, z)


def degraus(bm, passos, simetrico=True):
    """Lista de (x0, x1, y0, y1, z0, z1): uma caixa por degrau (e a espelhada em x)."""
    for x0, x1, y0, y1, z0, z1 in passos:
        if simetrico:
            sim(bm, (x0, x1), (y0, y1), (z0, z1))
        else:
            bl(bm, (x0, x1), (y0, y1), (z0, z1))


def losango(bm, cx, cz, larguras, alt_linha, y0, y1):
    """Losango em degraus (rombo voxel) no plano XZ; uma linha por entrada de `larguras`, de cima para baixo."""
    n = len(larguras)
    for i, w in enumerate(larguras):
        z1 = cz + alt_linha * n / 2 - i * alt_linha
        bl(bm, (cx - w / 2, cx + w / 2), (y0, y1), (z1 - alt_linha, z1))


def _rastro(bm, segs, largura=True):
    """Segmentos ao longo de +Y: (y0, y1, zc, w, h[, xc]) -> caixa centrada em x=xc (padrão 0)."""
    for y0, y1, zc, w, h, *xc in segs:
        xc = xc[0] if xc else 0.0
        bl(bm, (xc - w / 2, xc + w / 2), (y0, y1), (zc - h / 2, zc + h / 2))


class _Modelo(Modelo):
    """Modelo de caixas SOLTAS: cada caixa já nasce com as normais para fora (`caixa` com escala positiva), então não se
    funde vértices nem se recalculam normais (o `remove_doubles` + `recalc_face_normals` de `Modelo.finalizar` une as caixas
    que dividem arestas e vira normais de peças voxel sobrepostas). Com `espelhar_y` as faces são invertidas de volta."""

    def finalizar(self):
        objetos = []
        for nome in [n for n, g in self.grupos.items() if not g["bm"].faces]:
            self.grupos.pop(nome)["bm"].free()
        for nome, g in self.grupos.items():
            bm = g["bm"]
            if self.espelhar_y:
                for v in bm.verts:
                    v.co.y = -v.co.y
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            for f in bm.faces:
                f.smooth = False
            malha = bpy.data.meshes.new(nome)
            bm.to_mesh(malha)
            bm.free()
            objeto = bpy.data.objects.new(nome, malha)
            bpy.context.scene.collection.objects.link(objeto)
            objeto.color = (*[c / 255.0 for c in g["cor"]], 1.0)
            objetos.append(objeto)
        return objetos


def _modelo(nome):
    m = _Modelo(nome)
    m.manter_origem = True
    return m


PELE = (238, 192, 152)
PELE_SOMBRA = (214, 164, 124)


# ======================================================================================
# 1. CABELOS (Head, origem = centro da cabeça). Grupos: Cabelo (cor escolhida) e CabeloSombra (tom mais escuro)
def _cabelo(nome):
    m = _modelo(nome)
    c = m.grupo("Cabelo", (86, 58, 36), "SmoothPlastic")
    s = m.grupo("CabeloSombra", (58, 38, 24), "SmoothPlastic")
    return m, c, s


E = 0.69  # meia-largura externa da calota de cabelo (a cabeça tem 0,6)


def _casco(c, s, linha=0.48, lado=0.24, nuca=-0.32, topo=True, degrau=True):
    """Calota base: topo em dois degraus (z 0,57..0,73 e 0,73..0,84), testa, laterais e nuca. `linha` = z da borda da testa;
    `lado` = z da borda das costeletas; `nuca` = z da borda de trás. Não encosta no rosto (z de 0,44 para baixo fica livre)."""
    if topo:
        bl(c, (-E, E), (-E, E), (0.57, 0.73))
        if degrau:
            bl(c, (-0.6, 0.6), (-0.6, 0.6), (0.73, 0.84))
    bl(c, (-E, E), (-E - 0.01, -0.57), (linha, 0.73))  # testa
    sim(c, (0.57, E), (-0.57, E), (lado, 0.73))  # laterais
    bl(c, (-E, E), (0.57, E), (nuca + 0.12, 0.73))  # costas
    bl(s, (-E, E), (0.57, E + 0.005), (nuca, nuca + 0.12))  # barra escura da nuca
    sim(s, (0.575, E + 0.005), (-0.3, E), (lado, lado + 0.06))  # barra escura sobre a orelha
    bl(s, (-E, E), (-E - 0.015, -0.57), (linha, linha + 0.06))  # sombra da linha do cabelo


def cabelo_curto(semente, **_):
    """Curto liso: calota de dois degraus, testa rente e uma risca assimétrica (pela semente). ~1,4 x 1,4 x 0,8."""
    rng = random.Random(semente * 5 + 1)
    m, c, s = _cabelo("CabeloCurto")
    _casco(c, s)
    x0 = rng.choice((-0.25, 0.0, 0.25))
    bl(s, (x0 - 0.03, x0 + 0.03), (-0.6, 0.0), (0.84, 0.855))  # risca
    return m


def cabelo_espetado(semente, **_):
    """Curto espetado: calota baixa e 9 espetos em degraus, que se inclinam para fora do centro. ~1,5 x 1,5 x 1,3."""
    rng = random.Random(semente * 7 + 2)
    m, c, s = _cabelo("CabeloEspetado")
    _casco(c, s, degrau=False)
    for gx in (-1, 0, 1):
        for gy in (-1, 0, 1):
            n = 3 if (gx == 0 and gy == 0) else rng.choice((2, 3, 3, 4))
            for i in range(n):
                w = max(0.26 - 0.07 * i, 0.08)
                bl((s if i == n - 1 and n > 2 else c), (gx * 0.4 + gx * 0.035 * i - w / 2, gx * 0.4 + gx * 0.035 * i + w / 2),
                   (gy * 0.4 + gy * 0.035 * i - w / 2, gy * 0.4 + gy * 0.035 * i + w / 2), (0.73 + 0.13 * i, 0.73 + 0.13 * (i + 1)))
    return m


def cabelo_franja(semente, **_):
    """Franja longa: calota com a testa em oito mechas de comprimento desigual (a mais longa para o lado) e uma
    costeleta que desce sobre a orelha. ~1,4 x 1,4 x 0,8."""
    rng = random.Random(semente * 11 + 3)
    m, c, s = _cabelo("CabeloFranja")
    _casco(c, s, linha=0.56)
    lado_longo = rng.choice((-1, 1))
    n = 8
    larg = 1.34 / n
    for i in range(n):
        x0 = -0.67 + i * larg
        t = i / (n - 1) if lado_longo > 0 else 1 - i / (n - 1)
        fundo = 0.56 - 0.22 * t - 0.02 * ((i * 3) % 3)  # >= 0,34 na mecha mais longa (cobre a sobrancelha desse lado)
        fundo = max(fundo, 0.34)
        bl(c, (x0, x0 + larg), (-0.71, -0.57), (fundo + 0.07, 0.70))
        bl(s, (x0, x0 + larg), (-0.715, -0.57), (fundo, fundo + 0.07))
    bl(c, (lado_longo * 0.57, lado_longo * 0.69), (-0.57, -0.05), (0.02, 0.24))  # costeleta longa
    bl(s, (lado_longo * 0.575, lado_longo * 0.695), (-0.57, -0.05), (0.02, 0.07))
    return m


def cabelo_rabo(semente, **_):
    """Rabo de cavalo alto: calota curta, laço (grupo `Fita`) atrás e rabo em seis degraus que cai até a nuca das
    costas (z -0,70). ~1,4 x 1,4 (rabo vai até y=1,05) x 1,5."""
    rng = random.Random(semente * 3 + 4)
    m, c, s = _cabelo("CabeloRabo")
    fita = m.grupo("Fita", (176, 52, 56), "SmoothPlastic")
    _casco(c, s, nuca=0.0)
    bl(fita, (-0.2, 0.2), (0.68, 0.84), (0.26, 0.44))
    sw = rng.choice((-0.03, 0.0, 0.03))  # leve balanço lateral do rabo
    seg = [(0.72, 0.98, 0.00, 0.36, 0.36), (0.78, 1.04, -0.32, 0.02, 0.38), (0.80, 1.06, -0.56, -0.30, 0.34), (0.78, 1.00, -0.72, -0.54, 0.26)]
    for i, (y0, y1, z0, z1, w) in enumerate(seg):
        bl(c if i < 3 else s, (-w / 2 + sw * i, w / 2 + sw * i), (y0, y1), (z0, z1))
    return m


def cabelo_coque(semente, **_):
    """Coque no alto: calota com um nó de três camadas (quadrado, maior, quadrado) preso por uma fita. ~1,4 x 1,4 x 1,4."""
    m, c, s = _cabelo("CabeloCoque")
    fita = m.grupo("Fita", (176, 52, 56), "SmoothPlastic")
    _casco(c, s)
    cy = 0.12
    bl(c, (-0.2, 0.2), (cy - 0.2, cy + 0.2), (0.83, 0.98))
    bl(c, (-0.3, 0.3), (cy - 0.3, cy + 0.3), (0.98, 1.22))
    bl(s, (-0.3, 0.3), (cy - 0.3, cy + 0.3), (1.22, 1.28))
    bl(c, (-0.2, 0.2), (cy - 0.2, cy + 0.2), (1.28, 1.38))
    bl(fita, (-0.34, 0.34), (cy - 0.34, cy + 0.34), (0.94, 1.01))
    return m


def cabelo_longo(semente, **_):
    """Longo liso: calota, cortina que desce pelas costas até z -1,8 (borda inferior em degraus, pontas em `CabeloSombra`)
    e mechas dos dois lados do rosto até o ombro (z -0,55). Fica atrás do tronco (y > 0,56). ~1,6 x 0,9 x 2,6."""
    rng = random.Random(semente * 13 + 5)
    m, c, s = _cabelo("CabeloLongo")
    _casco(c, s, nuca=-0.1)
    n = 6
    larg = 1.62 / n
    for i in range(n):
        x0 = -0.81 + i * larg
        fundo = -1.8 + rng.choice((0.0, 0.1, 0.2, 0.3)) + (0.15 if i in (0, n - 1) else 0.0)
        bl(c, (x0, x0 + larg), (0.57, 0.84), (fundo + 0.35, 0.60))
        bl(s, (x0, x0 + larg), (0.57, 0.845), (fundo, fundo + 0.35))
    sim(c, (0.58, 0.76), (-0.46, -0.24), (-0.30, 0.24))
    sim(s, (0.585, 0.765), (-0.46, -0.24), (-0.55, -0.30))
    return m


def cabelo_moicano(semente, **_):
    """Moicano: laterais raspadas (casca fina em `CabeloSombra`) e uma crista central em degraus de 0,26 de largura,
    mais alta no meio, que desce pela nuca. ~0,5 x 1,4 x 1,3."""
    rng = random.Random(semente * 17 + 6)
    m, c, s = _cabelo("CabeloMoicano")
    bl(s, (-0.615, 0.615), (-0.615, 0.615), (0.60, 0.62))  # raspado: casca de 0,015 acima do crânio
    sim(s, (0.60, 0.62), (-0.55, 0.615), (0.15, 0.60))
    bl(s, (-0.615, 0.615), (0.60, 0.62), (-0.1, 0.60))
    bl(s, (-0.6, 0.6), (-0.62, -0.60), (0.48, 0.60))
    seg = [(-0.66, -0.38, 0.88), (-0.38, -0.10, 1.04), (-0.10, 0.20, 1.18), (0.20, 0.46, 1.06), (0.46, 0.74, 0.92)]
    for y0, y1, topo in seg:
        topo += rng.choice((-0.04, 0.0, 0.04))
        bl(c, (-0.13, 0.13), (y0, y1), (0.60, topo))
        bl(s, (-0.16, 0.16), (y0, y1), (0.60, 0.74))
        bl(c, (-0.08, 0.08), (y0 + 0.05, y1 - 0.05), (topo, topo + 0.08))
    bl(c, (-0.13, 0.13), (0.60, 0.74), (-0.30, 0.60))  # desce pela nuca
    return m


def cabelo_laterais(semente, **_):
    """Careca com laterais: topo calvo e uma faixa de cabelo em ferradura (laterais e nuca, z -0,02..0,40). ~1,4 x 1,4 x 0,5."""
    m, c, s = _cabelo("CabeloLaterais")
    sim(c, (0.57, 0.69), (-0.34, 0.68), (-0.02, 0.40))
    bl(c, (-0.69, 0.69), (0.57, 0.69), (-0.02, 0.40))
    sim(s, (0.575, 0.695), (-0.34, 0.69), (-0.02, 0.06))
    bl(s, (-0.695, 0.695), (0.575, 0.695), (-0.02, 0.06))
    sim(s, (0.575, 0.695), (-0.34, 0.69), (0.34, 0.40))
    return m


def cabelo_cachos(semente, **_):
    """Cachos blocados: nuvem de cubos (0,28..0,36) em torno do crânio, mais altos no alto, sem tocar o rosto. ~1,9 x 1,9 x 1,0."""
    rng = random.Random(semente * 19 + 7)
    m, c, s = _cabelo("CabeloCachos")
    bl(c, (-0.6, 0.6), (-0.6, 0.6), (0.52, 0.64))  # base sob os cubos
    grade = (-0.5, -0.17, 0.17, 0.5)
    for ix, gx in enumerate(grade):
        for iy, gy in enumerate(grade):
            for k, (zc, t) in enumerate(((0.74, 0.34), (1.0, 0.3))):
                if k == 1 and (ix in (0, 3) or iy in (0, 3)):
                    continue
                d = rng.uniform(-0.03, 0.03)
                bl(s if (ix + iy + k) % 3 == 0 else c, (gx - t / 2 + d, gx + t / 2 + d), (gy - t / 2 - d, gy + t / 2 - d), (zc - t / 2, zc + t / 2))
    for gy in (-0.3, 0.0, 0.3, 0.55):
        for sg in (-1, 1):
            for zc in (0.2, 0.48):
                if zc == 0.2 and gy < -0.05:
                    continue
                t = rng.uniform(0.28, 0.34)
                bl(s if (zc == 0.2) else c, (sg * 0.57, sg * (0.57 + t)), (gy - t / 2, gy + t / 2), (zc - t / 2, zc + t / 2))
    for gx in (-0.45, -0.15, 0.15, 0.45):
        for zc in (0.0, 0.3, 0.56):
            t = rng.uniform(0.28, 0.34)
            bl(c if zc > 0.1 else s, (gx - t / 2, gx + t / 2), (0.57, 0.57 + t), (zc - t / 2, zc + t / 2))
    for gx in (-0.45, -0.15, 0.15, 0.45):
        t = 0.3
        bl(c, (gx - t / 2, gx + t / 2), (-0.66, -0.57), (0.48, 0.58))  # testa
    return m


# ======================================================================================
# 2. BARBAS E BIGODE (Head). Grupos: Barba / BarbaSombra
def _barba(nome):
    m = _modelo(nome)
    return m, m.grupo("Barba", (86, 58, 36), "SmoothPlastic"), m.grupo("BarbaSombra", (58, 38, 24), "SmoothPlastic")


def barba_cavanhaque(semente, **_):
    """Cavanhaque: toco no queixo (abaixo da boca) com ponta, e fios finos no canto da boca. ~0,8 x 0,2 x 0,5."""
    m, b, s = _barba("BarbaCavanhaque")
    bl(b, (-0.2, 0.2), (-0.67, -0.58), (-0.60, -0.48))
    bl(s, (-0.12, 0.12), (-0.71, -0.58), (-0.80, -0.60))
    bl(b, (-0.08, 0.08), (-0.73, -0.67), (-0.84, -0.78))
    sim(b, (0.28, 0.34), (-0.65, -0.58), (-0.46, -0.26))
    return m


def barba_curta(semente, **_):
    """Barba cheia curta: maxilar em U (queixo e bochechas até as costeletas), vazada em volta da boca. ~1,4 x 0,9 x 0.65."""
    m, b, s = _barba("BarbaCurta")
    bl(b, (-0.62, 0.62), (-0.67, -0.58), (-0.60, -0.48))  # queixo
    bl(s, (-0.62, 0.62), (-0.675, -0.58), (-0.60, -0.54))  # base mais escura
    sim(b, (0.34, 0.63), (-0.67, -0.58), (-0.48, -0.12))  # bochechas à frente
    sim(b, (0.58, 0.66), (-0.58, 0.30), (-0.60, -0.04))  # maxilar lateral até a costeleta
    sim(s, (0.585, 0.665), (-0.58, 0.30), (-0.60, -0.54))
    bl(b, (-0.62, 0.62), (-0.67, 0.0), (-0.66, -0.60))  # sob o queixo (fora do tronco: y < -0,56 nos primeiros 0,1)
    return m


def barba_trancada(semente, **_):
    """Barba longa trançada (anão): barba cheia mais comprida, duas tranças blocadas de degraus alternados com fitas e
    contas de metal, que caem até o peito (z -2,0), à frente da túnica (y < -0,58). ~1,4 x 0,8 x 2,0."""
    rng = random.Random(semente * 23 + 8)
    m, b, s = _barba("BarbaTrancada")
    fio = m.grupo("Fita", (176, 52, 56), "SmoothPlastic")
    metal = m.grupo("Metal", (214, 172, 70), "Metal")
    bl(b, (-0.62, 0.62), (-0.67, -0.58), (-0.60, -0.48))
    sim(b, (0.34, 0.63), (-0.67, -0.58), (-0.48, -0.12))
    sim(b, (0.58, 0.66), (-0.58, 0.30), (-0.60, -0.04))
    # massa sob o queixo, à frente do peito
    bl(b, (-0.5, 0.5), (-0.80, -0.58), (-0.98, -0.60))
    bl(s, (-0.42, 0.42), (-0.84, -0.80), (-0.96, -0.66))
    for sg in (-1, 1):
        xc = sg * 0.24
        for i in range(9):
            z1 = -0.98 - 0.115 * i
            desl = (0.045 if i % 2 else -0.045)
            bl(b if i % 2 else s, (xc - 0.13 + desl, xc + 0.13 + desl), (-0.85, -0.60), (z1 - 0.115, z1))
        bl(fio, (xc - 0.15, xc + 0.15), (-0.87, -0.58), (-2.08, -1.98))
        bl(b, (xc - 0.07, xc + 0.07), (-0.78, -0.62), (-2.18, -2.08))
        bl(metal, (xc - 0.15, xc + 0.15), (-0.88, -0.58), (-1.30, -1.24))
    return m


def bigode(semente, **_):
    """Bigode: faixa entre o nariz e a boca (z -0,30..-0,19) com pontas em degraus que caem nos cantos (z até -0,46). ~0,9 x 0,2 x 0,3."""
    m, b, s = _barba("Bigode")
    bl(b, (-0.36, 0.36), (-0.70, -0.60), (-0.30, -0.19))
    bl(s, (-0.06, 0.06), (-0.70, -0.60), (-0.30, -0.19))
    sim(b, (0.30, 0.42), (-0.68, -0.60), (-0.38, -0.26))
    sim(s, (0.36, 0.46), (-0.66, -0.60), (-0.46, -0.36))
    return m


# ======================================================================================
# 3. TRAÇOS DE RAÇA
def _pele(nome):
    m = _modelo(nome)
    return m, m.grupo("Pele", PELE, "SmoothPlastic"), m.grupo("PeleSombra", PELE_SOMBRA, "SmoothPlastic")


def orelhas_elfo(semente, **_):
    """Orelhas pontudas de elfo (Head): quatro degraus para fora e para cima, com o fundo interno mais escuro.
    Pontas em x = +-1,14, z até 0,64. Grupos `Pele`/`PeleSombra`."""
    m, p, s = _pele("OrelhasElfo")
    passos = [(0.57, 0.74, -0.16, 0.30, -0.20, 0.26), (0.74, 0.90, -0.12, 0.26, -0.06, 0.36),
              (0.90, 1.04, -0.08, 0.20, 0.12, 0.50), (1.04, 1.14, -0.04, 0.14, 0.32, 0.64)]
    degraus(p, passos)
    for x0, x1, y0, y1, z0, z1 in passos[:3]:
        sim(s, (x0 + 0.02, x1), (y0 - 0.012, y0 + 0.03), (z0 + 0.05, z1 - 0.06))
    return m


def orelhas_elfo_longas(semente, **_):
    """Orelhas longas de elfo (Head): seis degraus, pontas em x = +-1,46 e z até 1,06. Grupos `Pele`/`PeleSombra`."""
    m, p, s = _pele("OrelhasElfoLongas")
    passos = [(0.57, 0.76, -0.16, 0.30, -0.22, 0.26), (0.76, 0.94, -0.12, 0.28, -0.08, 0.38), (0.94, 1.10, -0.10, 0.24, 0.10, 0.54),
              (1.10, 1.24, -0.06, 0.20, 0.30, 0.72), (1.24, 1.36, -0.03, 0.16, 0.50, 0.90), (1.36, 1.46, 0.0, 0.12, 0.70, 1.06)]
    degraus(p, passos)
    for x0, x1, y0, y1, z0, z1 in passos[:4]:
        sim(s, (x0 + 0.02, x1), (y0 - 0.012, y0 + 0.03), (z0 + 0.05, z1 - 0.06))
    return m


def _pelo(nome):
    m = _modelo(nome)
    return (m, m.grupo("Pelo", (176, 128, 78), "SmoothPlastic"), m.grupo("PeloInterno", (230, 186, 150), "SmoothPlastic"),
            m.grupo("PeloPonta", (96, 64, 40), "SmoothPlastic"))


def orelhas_fera_felina(semente, **_):
    """Orelhas de fera felinas (Head): duas pirâmides de degraus sobre os cantos do alto da cabeça, com miolo claro.
    Base em z 0,55 (afundada no cabelo), ponta em z 1,20. Grupos `Pelo`/`PeloInterno`/`PeloPonta`."""
    m, p, i, t = _pelo("OrelhasFeraFelina")
    xc, yc = 0.38, 0.14
    camadas = [(0.44, 0.32, 0.55, 0.82), (0.32, 0.24, 0.82, 0.98), (0.20, 0.16, 0.98, 1.12), (0.10, 0.10, 1.12, 1.20)]
    for k, (w, d, z0, z1) in enumerate(camadas):
        for sg in (-1, 1):
            bl(t if k == 3 else p, (sg * (xc - w / 2), sg * (xc + w / 2)), (yc - d / 2, yc + d / 2), (z0, z1))
            if k < 3:
                bl(i, (sg * (xc - w * 0.3), sg * (xc + w * 0.3)), (yc - d / 2 - 0.012, yc - d / 2 + 0.03), (z0 + 0.04, z1 - 0.02))
    return m


def orelhas_fera_canina(semente, **_):
    """Orelhas de fera caninas/lupinas (Head): mais altas e estreitas, inclinadas para fora, com a ponta escura.
    Base em z 0,55, ponta em z 1,56. Grupos `Pelo`/`PeloInterno`/`PeloPonta`."""
    m, p, i, t = _pelo("OrelhasFeraCanina")
    camadas = [(0.36, 0.26, 0.36, 0.55, 0.85), (0.30, 0.22, 0.39, 0.85, 1.10), (0.24, 0.18, 0.43, 1.10, 1.30), (0.16, 0.12, 0.48, 1.30, 1.44)]
    yc = 0.12
    for k, (w, d, xc, z0, z1) in enumerate(camadas):
        for sg in (-1, 1):
            bl(p, (sg * (xc - w / 2), sg * (xc + w / 2)), (yc - d / 2, yc + d / 2), (z0, z1))
            if k < 3:
                bl(i, (sg * (xc - w * 0.28), sg * (xc + w * 0.28)), (yc - d / 2 - 0.012, yc - d / 2 + 0.03), (z0 + 0.04, z1 - 0.02))
    for sg in (-1, 1):
        bl(t, (sg * (0.52 - 0.05), sg * (0.52 + 0.05)), (yc - 0.04, yc + 0.04), (1.44, 1.58))
    return m


def cauda_fera(semente, **_):
    """Cauda de fera felpuda (LowerTorso, costas): sai da base da coluna (y=0,5), engrossa e sobe em curva de raposa
    com a ponta clara. Fica abaixo da mochila (z <= 0,4) até y=1,15. ~0,7 x 2,2 x 1,5. Grupos `Pelo`/`PeloPonta`."""
    m = _modelo("CaudaFera")
    p = m.grupo("Pelo", (176, 128, 78), "SmoothPlastic")
    t = m.grupo("PeloPonta", (240, 228, 208), "SmoothPlastic")
    _rastro(p, [(0.45, 0.80, 0.0, 0.40, 0.40), (0.80, 1.15, 0.06, 0.52, 0.52), (1.15, 1.50, 0.22, 0.64, 0.56),
                (1.50, 1.85, 0.42, 0.70, 0.60), (1.85, 2.20, 0.68, 0.64, 0.60)])
    _rastro(t, [(2.15, 2.50, 0.98, 0.50, 0.56), (2.40, 2.65, 1.20, 0.30, 0.40)])
    return m


def _chifre(nome):
    m = _modelo(nome)
    return m, m.grupo("Chifre", (58, 42, 50), "SmoothPlastic"), m.grupo("ChifrePonta", (214, 96, 70), "SmoothPlastic")


def chifres_demonio_retos(semente, **_):
    """Chifres pequenos de demônio, curvados para trás (Head): quatro degraus a partir dos cantos do alto, ponta em brasa.
    Base em z 0,55, ponta em z 1,28. Grupos `Chifre`/`ChifrePonta`."""
    m, c, t = _chifre("ChifresDemonioRetos")
    passos = [(0.25, 0.47, -0.02, 0.20, 0.55, 0.80), (0.27, 0.45, 0.04, 0.22, 0.80, 1.00), (0.29, 0.43, 0.10, 0.24, 1.00, 1.16)]
    degraus(c, passos)
    sim(t, (0.31, 0.41), (0.16, 0.26), (1.16, 1.28))
    return m


def chifres_demonio_curvos(semente, **_):
    """Chifres de carneiro de demônio (Head): saem dos lados da testa, descem em gancho para fora e voltam para cima
    e para dentro. Largura total ~2,3 (x até +-1,14), z de 0,3 a 1,10. Grupos `Chifre`/`ChifrePonta`."""
    m, c, t = _chifre("ChifresDemonioCurvos")
    passos = [(0.57, 0.82, -0.08, 0.30, 0.28, 0.58), (0.80, 1.02, -0.08, 0.30, 0.32, 0.64), (0.96, 1.16, -0.05, 0.27, 0.48, 0.80),
              (1.00, 1.16, -0.03, 0.25, 0.78, 1.00), (0.88, 1.06, 0.0, 0.22, 0.92, 1.08)]
    degraus(c, passos)
    sim(t, (0.76, 0.94), (0.04, 0.24), (1.0, 1.14))
    return m


def chifres_dragao(semente, **_):
    """Chifres e cristas de dragão (Head): dois chifres longos varridos para trás (seis degraus, até y=1,66 e z=1,48),
    espinhos nas bochechas apontados para trás e crista central de cinco espinhos. Grupos `Chifre`/`Escama`."""
    m = _modelo("ChifresDragao")
    c = m.grupo("Chifre", (214, 200, 168), "SmoothPlastic")
    e = m.grupo("Escama", (84, 130, 96), "SmoothPlastic")
    degraus(c, [(0.20, 0.52, 0.0, 0.40, 0.55, 0.84), (0.22, 0.50, 0.32, 0.70, 0.70, 1.00), (0.24, 0.48, 0.62, 0.98, 0.86, 1.14),
                (0.26, 0.46, 0.90, 1.24, 1.02, 1.26), (0.28, 0.44, 1.16, 1.46, 1.18, 1.38), (0.30, 0.42, 1.40, 1.66, 1.32, 1.48)])
    degraus(e, [(0.58, 0.72, 0.10, 0.42, -0.22, 0.0), (0.60, 0.70, 0.40, 0.70, -0.20, -0.04), (0.62, 0.70, 0.68, 0.88, -0.18, -0.08)])
    for y0, y1, topo in ((-0.35, -0.15, 0.78), (0.0, 0.2, 0.90), (0.25, 0.45, 1.0), (0.5, 0.7, 0.90), (0.75, 0.95, 0.78)):
        bl(e, (-0.07, 0.07), (y0, y1), (0.55, topo))
    return m


def cauda_dragao(semente, **_):
    """Cauda de dragão (LowerTorso, costas): grossa na base (1,0), afina em sete degraus com leve S em x e cai até z -0,8 com a
    ponta levantada em lâmina; espinhos no dorso e barriga clara. Comprimento 4,3. Abaixo da mochila (topo <= 0,35) no começo.
    Grupos `Escama`/`EscamaClara`/`Espinho`."""
    m = _modelo("CaudaDragao")
    e = m.grupo("Escama", (84, 130, 96), "SmoothPlastic")
    cl = m.grupo("EscamaClara", (214, 200, 150), "SmoothPlastic")
    sp = m.grupo("Espinho", (214, 200, 168), "SmoothPlastic")
    segs = [(0.45, 1.05, -0.05, 1.00, 0.70, 0.0), (1.05, 1.65, -0.15, 0.86, 0.64, 0.0), (1.65, 2.25, -0.30, 0.72, 0.56, 0.12),
            (2.25, 2.85, -0.50, 0.60, 0.48, 0.28), (2.85, 3.40, -0.70, 0.48, 0.40, 0.32), (3.40, 3.90, -0.78, 0.38, 0.34, 0.22),
            (3.90, 4.30, -0.70, 0.28, 0.28, 0.06)]
    _rastro(e, segs)
    for y0, y1, zc, w, h, xc in segs:
        bl(cl, (xc - w * 0.35, xc + w * 0.35), (y0, y1), (zc - h / 2 - 0.012, zc - h / 2 + 0.12))
        top = zc + h / 2
        bl(sp, (xc - 0.07, xc + 0.07), ((y0 + y1) / 2 - 0.12, (y0 + y1) / 2 + 0.12), (top - 0.02, top + 0.14 + 0.05 * h))
    bl(sp, (-0.04, 0.12), (4.2, 4.5), (-0.78, -0.50))
    bl(sp, (0.0, 0.1), (4.42, 4.66), (-0.68, -0.44))
    return m


def cauda_superd(semente, **_):
    """Cauda bifurcada do superd (LowerTorso, costas): haste que sobe e se divide em duas lanças bem afastadas, cada uma com
    ponta de osso (o livro: "cauda bifurcada que vira lança tridente"). Comprimento 4,1, abertura 1,6. Grupos `Cauda`/`Lanca`."""
    m = _modelo("CaudaSuperd")
    c = m.grupo("Cauda", (70, 62, 84), "SmoothPlastic")
    l = m.grupo("Lanca", (226, 216, 190), "SmoothPlastic")
    _rastro(c, [(0.45, 1.00, 0.0, 0.44, 0.44), (1.00, 1.55, 0.15, 0.40, 0.40), (1.55, 2.10, 0.35, 0.36, 0.36), (2.10, 2.60, 0.55, 0.36, 0.34)])
    for sg in (-1, 1):
        for (y0, y1, xc, zc, w) in ((2.50, 2.95, 0.22, 0.64, 0.28), (2.88, 3.33, 0.46, 0.80, 0.26), (3.26, 3.71, 0.66, 0.92, 0.24)):
            bl(c, (sg * (xc - w / 2), sg * (xc + w / 2)), (y0, y1), (zc - w / 2, zc + w / 2))
        bl(l, (sg * 0.58, sg * 0.82), (3.64, 4.0), (0.82, 1.04))
        bl(l, (sg * 0.64, sg * 0.76), (3.98, 4.3), (0.88, 0.98))
    bl(c, (-0.12, 0.12), (2.50, 2.72), (0.52, 0.80))  # raiz da forquilha
    return m


def cabelo_trancado(semente, **_):
    """Cabelo trançado: calota com a nuca alta e duas tranças grossas blocadas (degraus que alternam 0,05 para o lado) que
    caem pelas costas até z -1,5, presas por fitas no meio e na ponta. Ficam atrás do tronco (y > 0,56). ~1,6 x 1,0 x 2,3."""
    rng = random.Random(semente * 31 + 10)
    m, c, s = _cabelo("CabeloTrancado")
    fita = m.grupo("Fita", (176, 52, 56), "SmoothPlastic")
    _casco(c, s, nuca=0.0)
    for sg in (-1, 1):
        xc = sg * 0.32
        bl(c, (xc - 0.16, xc + 0.16), (0.57, 0.80), (-0.1, 0.30))  # raiz
        for i in range(7):
            z1 = -0.1 - 0.2 * i
            desl = 0.05 if i % 2 else -0.05
            bl(c if i % 2 else s, (xc - 0.15 + desl, xc + 0.15 + desl), (0.60, 0.88), (z1 - 0.2, z1))
        bl(fita, (xc - 0.17, xc + 0.17), (0.58, 0.90), (-0.64, -0.56))
        bl(fita, (xc - 0.17, xc + 0.17), (0.58, 0.90), (-1.52, -1.44))
        bl(c, (xc - 0.08, xc + 0.08), (0.64, 0.84), (-1.66, -1.52))
    return m


def chifres_ogro(semente, **_):
    """Chifres de ogro (Head, opcionais): dois chifres grossos e rombudos que saem do alto da testa e abrem para fora em
    três degraus, ponta cega mais clara. Largura total ~1,6, z de 0,55 a 1,16. Grupos `Chifre`/`ChifrePonta`."""
    m = _modelo("ChifresOgro")
    c = m.grupo("Chifre", (150, 134, 104), "SmoothPlastic")
    t = m.grupo("ChifrePonta", (214, 200, 160), "SmoothPlastic")
    degraus(c, [(0.26, 0.58, -0.06, 0.26, 0.55, 0.82), (0.40, 0.68, -0.04, 0.24, 0.82, 1.02)])
    sim(t, (0.54, 0.78), (-0.02, 0.22), (1.0, 1.16))
    return m


def asas_celestial(semente, **_):
    """Asas do celestial (UpperTorso, costas): duas asas blocadas semiabertas e varridas para trás. Osso em quatro degraus
    do ombro (x 0,3, z 0,3) à ponta (x 2,75, z 1,24); sete colunas de penas que descem do osso, mais compridas no meio
    (até 2,7), em dois tons (cobertura, pontas claras). Ficam atrás do tronco (y > 0,58) e longe dos braços.
    ~5,5 x 1,1 x 3,6. Grupos `Asa`/`AsaClara`/`AsaOsso`."""
    m = _modelo("AsasCelestial")
    a = m.grupo("Asa", (240, 238, 230), "SmoothPlastic")
    cl = m.grupo("AsaClara", (255, 252, 240), "SmoothPlastic")
    osso = m.grupo("AsaOsso", (214, 196, 150), "SmoothPlastic")
    ossos = [(0.30, 0.95, 0.30, 0.62), (0.90, 1.55, 0.52, 0.84), (1.50, 2.15, 0.74, 1.04), (2.10, 2.75, 0.96, 1.24)]
    comp = [1.3, 1.7, 2.1, 2.5, 2.7, 2.5, 2.0]
    for sg in (-1, 1):
        for i, (x0, x1, z0, z1) in enumerate(ossos):
            bl(osso, (sg * x0, sg * x1), (0.58 + 0.12 * i, 0.80 + 0.12 * i), (z0, z1))
        for i, L in enumerate(comp):
            x0 = 0.35 + 0.36 * i
            topo = 0.55 + (x0 - 0.3) * 0.27
            y0 = 0.60 + 0.12 * (x0 / 0.65)
            xs = (sg * x0, sg * (x0 + 0.38))
            bl(a, xs, (y0, y0 + 0.18), (topo - L * 0.62, topo))
            bl(cl, xs, (y0 + 0.02, y0 + 0.2), (topo - L, topo - L * 0.62))
            bl(cl, xs, (y0 - 0.04, y0), (topo - 0.55, topo - 0.05))  # cobertura à frente (profundidade)
    return m


def aureola(semente, **_):
    """Auréola flutuante do celestial: anel octogonal blocado (8 faixas) 0,35 acima da cabeça, em z 0,98..1,10, raio
    externo ~0,78, material Neon. Grupo `Aureola`."""
    m = _modelo("Aureola")
    a = m.grupo("Aureola", (255, 226, 130), "Neon")
    apot, larg = 0.62, 0.22
    comp = 2 * (apot + larg / 2) * math.tan(PI / 8)
    for k in range(8):
        ang = k * PI / 4
        cx, cy = apot * math.cos(ang), apot * math.sin(ang) + 0.04
        caixa(a, (cx, cy, 1.04), (larg, comp, 0.12), (0, 0, ang))
    return m


def barbatanas_oceano(semente, **_):
    """Barbatanas e guelras laterais do oceano (Head): em cada lado, leque de três espinhos presos à têmpora (x até 1,2) e
    três fendas de guelra na bochecha. Grupos `Barbatana`/`BarbatanaClara`/`Guelra`."""
    m = _modelo("BarbatanasOceano")
    f = m.grupo("Barbatana", (52, 150, 176), "SmoothPlastic")
    cl = m.grupo("BarbatanaClara", (150, 214, 226), "SmoothPlastic")
    g = m.grupo("Guelra", (30, 74, 96), "SmoothPlastic")
    sim(f, (0.58, 0.72), (0.0, 0.60), (-0.25, 0.60))
    sim(cl, (0.72, 0.90), (0.10, 0.90), (-0.15, 0.50))
    sim(f, (0.90, 1.20), (0.50, 1.00), (0.30, 0.62))
    sim(f, (0.90, 1.20), (0.75, 1.30), (0.04, 0.30))
    sim(f, (0.90, 1.20), (0.50, 0.95), (-0.30, -0.08))
    for z in (-0.04, -0.16, -0.28):
        sim(g, (0.598, 0.62), (-0.36, -0.14), (z - 0.025, z + 0.025))
    return m


def presas_ogro(semente, **_):
    """Presas inferiores do ogro (Head, boca da face frontal): duas presas que nascem do lábio (z -0,44) e sobem à frente
    do nariz (z -0,02), ligeiramente para fora. Largura 0,7, projeção de 0,14 sobre a face. Grupo `Presa`."""
    m = _modelo("PresasOgro")
    p = m.grupo("Presa", (232, 224, 196), "SmoothPlastic")
    sim(p, (0.17, 0.35), (-0.67, -0.58), (-0.44, -0.28))
    sim(p, (0.19, 0.33), (-0.70, -0.60), (-0.28, -0.12))
    sim(p, (0.21, 0.31), (-0.72, -0.64), (-0.12, -0.02))
    return m


def joia_testa(semente, **_):
    """Joia na testa (migurd: o "olho" telepático; serve também de marca de superd): losango de cinco linhas em moldura
    dourada, 0,12 acima da testa, centrado em z 0,49 (entre as sobrancelhas; Neon). Grupos `Joia`/`Moldura`."""
    m = _modelo("JoiaTesta")
    mol = m.grupo("Moldura", (214, 172, 70), "Metal")
    j = m.grupo("Joia", (110, 200, 240), "Neon")
    losango(mol, 0.0, 0.49, [0.09, 0.2, 0.3, 0.2, 0.09], 0.042, -0.69, -0.58)
    losango(j, 0.0, 0.49, [0.04, 0.12, 0.2, 0.12, 0.04], 0.038, -0.725, -0.69)
    return m


# ======================================================================================
# 4. ROUPAS BÁSICAS
LINHO = (178, 160, 122)
LINHO_CLARO = (206, 192, 156)
LINHO_ESCURO = (112, 98, 76)
COURO = (110, 76, 48)
COURO_ESCURO = (78, 54, 36)


def tunica_basica(semente, **_):
    """Túnica simples (UpperTorso, origem = centro): tubo de linho de x +-1,03 por y +-0,57 que cobre o tronco e desce até
    1,5 abaixo do centro (cobre a LowerTorso e 0,3 das coxas), com sobreposição de ombro, cordão no peito e bainha clara.
    Sem mangas (as mangas ficariam presas ao tronco e atravessariam o braço). Grupos `Pano`/`PanoClaro`/`PanoEscuro`."""
    m = _modelo("TunicaBasica")
    p = m.grupo("Pano", LINHO, "Fabric")
    cl = m.grupo("PanoClaro", LINHO_CLARO, "Fabric")
    es = m.grupo("PanoEscuro", LINHO_ESCURO, "Fabric")
    bl(p, (-1.03, 1.03), (-0.57, 0.57), (-1.5, 0.83))
    bl(cl, (-1.035, 1.035), (-0.575, 0.575), (0.50, 0.83))  # sobreposição de ombro
    bl(cl, (-1.06, 1.06), (-0.60, 0.60), (-1.5, -1.38))  # bainha
    bl(es, (-0.06, 0.06), (-0.605, -0.57), (-0.1, 0.83))  # abertura do peito
    for z in (0.58, 0.40, 0.22):
        bl(es, (-0.2, 0.2), (-0.605, -0.57), (z - 0.03, z + 0.03))
    bl(es, (-1.04, 1.04), (-0.58, 0.58), (-0.02, 0.04))  # costura na cintura (a faixa de couro cobre o centro)
    for sg in (-1, 1):
        bl(es, (sg * 0.90, sg * 1.04), (-0.58, 0.58), (0.40, 0.46))  # costura do cavado
    return m


def capuz_basico(semente, **_):
    """Capuz simples de lã (Head, origem = centro da cabeça): coifa em três degraus, aberta na frente (aba só acima de
    z 0,52), laterais e costas, ponta caída atrás e uma gola curta só nos ombros e nas costas. Não cobre z entre -0,48 e
    0,52 na frente. ~2,1 x 1,8 x 1,6. Grupos `Pano`/`PanoClaro` (debrum)/`PanoEscuro` (forro)."""
    m = _modelo("CapuzBasico")
    p = m.grupo("Pano", (116, 106, 86), "Fabric")
    cl = m.grupo("PanoClaro", (146, 134, 108), "Fabric")
    es = m.grupo("PanoEscuro", (82, 74, 60), "Fabric")
    bl(p, (-0.76, 0.76), (-0.70, 0.82), (0.58, 0.72))  # topo, degrau 1
    bl(p, (-0.68, 0.68), (-0.62, 0.76), (0.72, 0.82))  # degrau 2
    bl(p, (-0.52, 0.52), (-0.45, 0.66), (0.82, 0.88))  # degrau 3
    bl(p, (-0.76, 0.76), (-0.72, -0.58), (0.52, 0.72))  # aba da testa
    sim(p, (0.60, 0.76), (-0.72, 0.82), (-0.45, 0.72))  # laterais
    bl(p, (-0.76, 0.76), (0.60, 0.82), (-0.5, 0.72))  # costas
    bl(es, (-0.76, 0.76), (-0.725, -0.58), (0.52, 0.56))  # forro à mostra sob a aba
    sim(cl, (0.60, 0.76), (-0.725, -0.66), (-0.45, 0.52))  # debrum do rosto
    bl(cl, (-0.76, 0.76), (-0.725, -0.66), (0.56, 0.62))
    # gola nos ombros e nas costas (sobre a túnica, que termina em z -0,57)
    sim(p, (0.60, 1.05), (-0.58, 0.62), (-0.57, -0.34))
    bl(p, (-1.05, 1.05), (0.58, 0.80), (-0.76, -0.34))
    bl(cl, (-1.05, 1.05), (0.58, 0.80), (-0.76, -0.70))
    # ponta caída
    bl(p, (-0.24, 0.24), (0.82, 0.96), (-0.2, 0.46))
    bl(p, (-0.18, 0.18), (0.96, 1.08), (-0.52, 0.0))
    return m


def cinto_basico(semente, **_):
    """Cinto de couro com bolsinha (LowerTorso, origem = centro): faixa de x +-1,05 por y +-0,62 e 0,3 de altura, fivela de
    metal e ponta pendente na frente, bolsinha com aba e botão presa ao quadril direito (em -X autoral), alça nas costas.
    Bolsinha avança até y = -0,88. Grupos `Couro`/`CouroEscuro`/`Metal`."""
    m = _modelo("CintoBasico")
    c = m.grupo("Couro", COURO, "Fabric")
    ce = m.grupo("CouroEscuro", COURO_ESCURO, "Fabric")
    me = m.grupo("Metal", (190, 170, 110), "Metal")
    bl(c, (-1.05, 1.05), (-0.62, 0.62), (-0.15, 0.15))
    bl(ce, (-1.055, 1.055), (-0.625, 0.625), (0.10, 0.15))  # borda de cima
    bl(me, (-0.17, 0.17), (-0.68, -0.62), (-0.12, 0.12))
    bl(ce, (-0.09, 0.09), (-0.70, -0.66), (-0.06, 0.06))
    bl(c, (0.17, 0.27), (-0.66, -0.60), (-0.46, 0.10))  # ponta que pende
    bl(ce, (0.17, 0.27), (-0.66, -0.60), (-0.48, -0.40))
    # bolsinha no quadril direito (-X autoral)
    bl(c, (-0.95, -0.50), (-0.88, -0.62), (-0.62, -0.20))
    bl(ce, (-0.97, -0.48), (-0.90, -0.60), (-0.38, -0.14))  # aba
    bl(me, (-0.78, -0.66), (-0.93, -0.88), (-0.30, -0.22))  # botão
    bl(ce, (-0.84, -0.60), (-0.64, -0.60), (-0.20, 0.12))  # alça
    bl(ce, (-0.2, 0.2), (0.60, 0.66), (-0.1, 0.1))  # alça de trás (para a mochila)
    return m


def botas_basicas(semente, **_):
    """Bota de couro simples, UMA peça simétrica para os dois pés (origem = centro do pé R15, 0,15 acima do chão): cano até
    0,9 de altura com barra dobrada, bico, sola e salto. É o que espera `Catalogo.RoupaBotas1` (LeftFoot e RightFoot, offset 0): a sola fica em z = -0,15. ~1,1 x 1,4 x 0,92.
    Grupos `Couro`/`CouroEscuro`/`Sola`/`Cordao`."""
    m = _modelo("BotasBasicas")
    c = m.grupo("Couro", COURO, "Fabric")
    ce = m.grupo("CouroEscuro", COURO_ESCURO, "Fabric")
    so = m.grupo("Sola", (50, 38, 30), "SmoothPlastic")
    co = m.grupo("Cordao", (206, 192, 156), "Fabric")
    bl(c, (-0.52, 0.52), (-0.54, 0.54), (-0.03, 0.63))  # cano
    bl(ce, (-0.55, 0.55), (-0.57, 0.57), (0.57, 0.77))  # barra dobrada
    bl(ce, (-0.50, 0.50), (-0.78, -0.50), (-0.03, 0.25))  # bico
    bl(c, (-0.46, 0.46), (-0.72, -0.50), (0.25, 0.31))
    bl(so, (-0.54, 0.54), (-0.82, 0.58), (-0.15, -0.03))  # sola
    bl(so, (-0.54, 0.54), (0.30, 0.58), (-0.15, 0.05))  # salto
    for z in (0.15, 0.31, 0.47):
        bl(co, (-0.28, 0.28), (-0.575, -0.54), (z - 0.03, z + 0.03))
    bl(ce, (-0.08, 0.08), (-0.58, -0.54), (0.09, 0.55))
    return m


def luvas_basicas(semente, **_):
    """Luva de couro simples, UMA peça simétrica para as duas mãos (origem = centro da mão): cobre a mão (1 x 0,3 x 1) com
    folga de 0,03, punho de 0,28 sobre o antebraço e costuras dos dedos na frente. ~1,1 x 1,1 x 0,7.
    Grupos `Couro`/`CouroEscuro`/`PunhoClaro`."""
    m = _modelo("LuvasBasicas")
    c = m.grupo("Couro", COURO, "Fabric")
    ce = m.grupo("CouroEscuro", COURO_ESCURO, "Fabric")
    pu = m.grupo("PunhoClaro", (150, 112, 74), "Fabric")
    bl(c, (-0.53, 0.53), (-0.53, 0.53), (-0.20, 0.18))  # mão
    bl(pu, (-0.55, 0.55), (-0.55, 0.55), (0.14, 0.42))  # punho
    bl(ce, (-0.55, 0.55), (-0.55, 0.55), (0.12, 0.17))
    bl(ce, (-0.50, 0.50), (-0.55, -0.50), (-0.23, -0.16))  # ponta dos dedos
    for x in (-0.25, 0.0, 0.25):
        bl(ce, (x - 0.02, x + 0.02), (-0.545, -0.52), (-0.18, 0.10))  # costura entre os dedos
    return m


def mochila_basica(semente, **_):
    """Mochila pequena (UpperTorso, costas): corpo de 1,24 x 0,55 x 1,12, aba, bolsos laterais, rolo de pano em cima e
    alças que passam pelos ombros (fora da cabeça, x > 0,62) e descem pelo peito. Fundo em z -0,62 (cauda por baixo).
    ~1,8 x 1,35 x 1,9. Grupos `Couro`/`CouroEscuro`/`Pano`/`Metal`."""
    m = _modelo("MochilaBasica")
    c = m.grupo("Couro", COURO, "Fabric")
    ce = m.grupo("CouroEscuro", COURO_ESCURO, "Fabric")
    pa = m.grupo("Pano", (150, 74, 62), "Fabric")
    me = m.grupo("Metal", (190, 170, 110), "Metal")
    bl(c, (-0.62, 0.62), (0.56, 1.10), (-0.62, 0.50))
    bl(ce, (-0.64, 0.64), (0.55, 1.12), (-0.62, -0.42))  # fundo reforçado
    bl(ce, (-0.66, 0.66), (0.56, 1.16), (0.18, 0.56))  # aba
    bl(ce, (-0.50, 0.50), (1.10, 1.16), (-0.18, 0.20))  # lingueta
    bl(me, (-0.09, 0.09), (1.15, 1.21), (-0.12, 0.0))
    sim(c, (0.62, 0.80), (0.62, 1.00), (-0.55, -0.04))  # bolsos laterais
    sim(ce, (0.62, 0.81), (0.62, 1.00), (-0.20, -0.12))
    bl(pa, (-0.55, 0.55), (0.62, 1.04), (0.56, 0.84))  # rolo de pano
    bl(ce, (-0.58, 0.58), (0.60, 0.66), (0.56, 0.84))
    for y in (0.72, 0.92):
        bl(ce, (-0.56, 0.56), (y, y + 0.05), (0.56, 0.84))
    # alças
    sim(ce, (0.64, 0.90), (-0.50, 0.62), (0.83, 0.93))  # sobre o ombro
    sim(ce, (0.64, 0.90), (-0.64, -0.57), (-0.4, 0.93))  # desce pelo peito
    sim(ce, (0.64, 0.90), (0.50, 0.62), (0.20, 0.93))  # volta para a mochila
    bl(ce, (-0.9, 0.9), (-0.68, -0.60), (0.04, 0.12))  # peitoral
    return m


# ======================================================================================
# 5. ESPELHO DE VILA (prop; origem no chão, centrada; frente em -Y autoral com espelhar_y como predios.py)
def espelho_vila(semente, **_):
    """Espelho de pé grande e arara de roupas (vila; personalização do avatar). Espelho com moldura de madeira entalhada
    (coroa em degraus, rombos nos montantes, cantoneiras e florão de ouro), vidro em recesso e pés largos; ao lado, arara
    de madeira com quatro peças penduradas, prateleira com botas e pano dobrado. Frente em +Z no Roblox (`espelhar_y`).
    ~5,9 x 1,8 x 7,1 studs. Grupos `Madeira`/`MadeiraEscura`/`Ouro`/`Vidro`/`Cabide`/`PanoA..D`/`Couro`."""
    rng = random.Random(semente * 29 + 9)
    m = _Modelo("EspelhoVila")
    m.espelhar_y = True
    mad = m.grupo("Madeira", (134, 94, 58), "Wood")
    esc = m.grupo("MadeiraEscura", (92, 62, 40), "Wood")
    ouro = m.grupo("Ouro", (214, 172, 70), "Metal")
    vid = m.grupo("Vidro", (176, 214, 228), "Glass")
    cab = m.grupo("Cabide", (104, 76, 50), "Wood")
    pa = [m.grupo(f"Pano{k}", cor, "Fabric") for k, cor in zip("ABCD", ((160, 66, 60), (62, 96, 146), (194, 168, 100), (78, 120, 82)))]
    cou = m.grupo("Couro", COURO, "Fabric")
    xm = -1.35
    # ----- espelho
    for sg in (-1, 1):
        bl(mad, (xm + sg * 1.15, xm + sg * 1.62), (-0.28, 0.28), (0.3, 5.8))  # montantes
        bl(esc, (xm + sg * 1.62, xm + sg * 1.67), (-0.2, 0.2), (0.3, 5.8))
        bl(esc, (xm + sg * 1.12, xm + sg * 1.2), (-0.2, 0.2), (1.0, 5.8))  # filete interno
        bl(esc, (xm + sg * 1.18, xm + sg * 1.7), (-0.9, 0.9), (0.0, 0.3))  # pés
        bl(mad, (xm + sg * 1.28, xm + sg * 1.6), (-0.9, 0.9), (0.3, 0.45))
        bl(ouro, (xm + sg * 1.3, xm + sg * 1.5), (-0.2, 0.2), (5.78, 5.96))  # remate do montante
    bl(mad, (xm - 1.15, xm + 1.15), (-0.28, 0.28), (0.45, 1.0))  # travessa de baixo (entre os montantes: sem faces coplanares)
    bl(mad, (xm - 1.15, xm + 1.15), (-0.28, 0.28), (5.8, 6.25))  # travessa de cima
    bl(esc, (xm - 1.15, xm + 1.15), (-0.2, 0.2), (0.98, 1.04))
    bl(esc, (xm - 1.15, xm + 1.15), (-0.2, 0.2), (5.76, 5.82))
    # vidro e fundo
    bl(vid, (xm - 1.15, xm + 1.15), (-0.11, -0.05), (1.0, 5.8))
    bl(esc, (xm - 1.15, xm + 1.15), (-0.05, 0.28), (1.0, 5.8))
    # coroa em degraus
    bl(mad, (xm - 1.62, xm + 1.62), (-0.28, 0.28), (6.25, 6.5))
    bl(mad, (xm - 1.2, xm + 1.2), (-0.28, 0.28), (6.5, 6.72))
    bl(mad, (xm - 0.75, xm + 0.75), (-0.28, 0.28), (6.72, 6.9))
    bl(esc, (xm - 0.35, xm + 0.35), (-0.3, 0.28), (6.88, 6.98))
    losango(ouro, xm, 6.55, [0.12, 0.28, 0.12], 0.1, -0.34, -0.26)  # florão central da coroa
    losango(ouro, xm, 6.0, [0.10, 0.24, 0.40, 0.24, 0.10], 0.07, -0.34, -0.26)  # medalhão da travessa
    # entalhes: rombos nos montantes e dentes na travessa de baixo
    for sg in (-1, 1):
        for z in (1.6, 2.7, 3.8, 4.9):
            losango(esc, xm + sg * 1.385, z, [0.1, 0.22, 0.1], 0.1, -0.34, -0.28)
        # cantoneiras (cantos do vidro)
        for z0 in (1.0, 5.5):
            bl(esc, (xm + sg * 0.92, xm + sg * 1.15), (-0.24, -0.1), (z0, z0 + 0.3))
    for i in range(4):
        bl(esc, (xm - 1.2 + i * 0.6, xm - 0.92 + i * 0.6), (-0.32, -0.28), (0.5, 0.96))
    # ----- arara
    xr = 1.75
    for sg in (-1, 1):
        bl(mad, (xr + sg * 1.0, xr + sg * 1.2), (-0.1, 0.1), (0.2, 5.6))
        bl(esc, (xr + sg * 0.9, xr + sg * 1.3), (-0.8, 0.8), (0.0, 0.2))
        bl(ouro, (xr + sg * 1.02, xr + sg * 1.18), (-0.12, 0.12), (5.6, 5.76))
    bl(cab, (xr - 1.1, xr + 1.1), (-0.07, 0.07), (5.0, 5.14))  # barra
    bl(mad, (xr - 1.2, xr + 1.2), (-0.55, 0.55), (0.9, 1.0))  # prateleira
    bl(esc, (xr - 1.2, xr + 1.2), (-0.55, -0.5), (0.7, 1.0))
    # roupas penduradas: túnica, manto longo, colete, capa curta
    pecas = [(-0.78, 0.5, 1.4, 0, 0.8), (-0.26, 0.4, 2.6, 1, 0.7), (0.28, 0.42, 1.0, 2, 0.8), (0.8, 0.46, 1.9, 3, 0.74)]
    for xo, larg, alt, k, prof in pecas:
        cx = xr + xo
        bl(cab, (cx - 0.3, cx + 0.3), (-0.04, 0.04), (4.88, 4.98))  # cabide
        bl(cab, (cx - 0.04, cx + 0.04), (-0.04, 0.04), (4.98, 5.1))
        top = 4.9
        bl(pa[k], (cx - larg / 2 - 0.12, cx + larg / 2 + 0.12), (-prof * 0.2, prof * 0.2), (top - 0.35, top - 0.05))  # ombros
        bl(pa[k], (cx - larg / 2, cx + larg / 2), (-prof * 0.16, prof * 0.16), (top - alt, top - 0.35))  # corpo
        bl(pa[k], (cx - larg / 2 - 0.1, cx + larg / 2 + 0.1), (-prof * 0.18, prof * 0.18), (top - alt, top - alt + 0.1))  # barra
    for sg in (-1, 1):
        bl(cou, (xr + sg * 0.45 - 0.2, xr + sg * 0.45 + 0.2), (-0.2, 0.28), (1.0, 1.55))  # bota na prateleira
        bl(cou, (xr + sg * 0.45 - 0.2, xr + sg * 0.45 + 0.2), (-0.38, -0.2), (1.0, 1.18))
    bl(pa[2], (xr - 0.35, xr + 0.35), (-0.4, 0.4), (0.2, 0.9))
    bl(pa[1], (xr - 0.3, xr + 0.3), (-0.38, 0.38), (0.55, 0.7))
    return m


GERADORES = {
    "cabelocurto": cabelo_curto, "cabeloespetado": cabelo_espetado, "cabelofranja": cabelo_franja, "cabelorabo": cabelo_rabo,
    "cabelococo": cabelo_coque, "cabelolongo": cabelo_longo, "cabelomoicano": cabelo_moicano, "cabelolaterais": cabelo_laterais,
    "cabelocachos": cabelo_cachos,
    "barbacavanhaque": barba_cavanhaque, "barbacurta": barba_curta, "barbatrancada": barba_trancada, "bigode": bigode,
    "orelhaselfo": orelhas_elfo, "orelhaselfolongas": orelhas_elfo_longas,
    "orelhasferafelina": orelhas_fera_felina, "orelhasferacanina": orelhas_fera_canina, "caudafera": cauda_fera,
    "chifresdemonioretos": chifres_demonio_retos, "chifresdemoniocurvos": chifres_demonio_curvos,
    "chifresdragao": chifres_dragao, "caudadragao": cauda_dragao, "caudasuperd": cauda_superd,
    "aureola": aureola, "cabelotrancado": cabelo_trancado, "chifresogro": chifres_ogro, "asascelestial": asas_celestial, "barbatanasoceano": barbatanas_oceano, "presasogro": presas_ogro, "joiatesta": joia_testa,
    "tunicabasica": tunica_basica, "capuzbasico": capuz_basico, "cintobasico": cinto_basico, "botasbasicas": botas_basicas,
    "luvasbasicas": luvas_basicas, "mochilabasica": mochila_basica, "espelhovila": espelho_vila,
}

for _p in ("cabelocurto", "cabeloespetado", "cabelofranja", "cabelorabo", "cabelococo", "cabelolongo", "cabelomoicano", "cabelolaterais",
           "cabelocachos", "barbacavanhaque", "barbacurta", "barbatrancada", "bigode", "orelhaselfo", "orelhaselfolongas",
           "orelhasferafelina", "orelhasferacanina", "chifresdemonioretos", "chifresdemoniocurvos", "chifresdragao",
           "aureola", "barbatanasoceano", "presasogro", "joiatesta", "capuzbasico", "cabelotrancado", "chifresogro"):
    _enc(_p, ("Head", (0.0, 0.0, 0.0)))
for _p in ("caudafera", "caudadragao", "caudasuperd", "cintobasico"):
    _enc(_p, ("LowerTorso", (0.0, 0.0, 0.0)))
for _p in ("tunicabasica", "mochilabasica", "asascelestial"):
    _enc(_p, ("UpperTorso", (0.0, 0.0, 0.0)))
_enc("botasbasicas", ("LeftFoot", (0.0, 0.0, 0.0)), ("RightFoot", (0.0, 0.0, 0.0)))
_enc("luvasbasicas", ("LeftHand", (0.0, 0.0, 0.0)), ("RightHand", (0.0, 0.0, 0.0)))


def posicoes_autorais(peca):
    """Onde a origem da peça cai no mundo AUTORAL (x, y, z) com o boneco de prévia: uma posição por encaixe."""
    saida = []
    for parte, (dx, dy, dz) in ENCAIXES[peca]:
        cx, cy, cz = CENTROS[parte]
        saida.append((-(cx + dx), cz + dz, cy + dy))
    return saida
