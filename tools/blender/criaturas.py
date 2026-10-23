"""CRIATURAS do mundo aberto (17/10): inimigos "quadradões" na mesma linguagem do avatar (voxel/blocado, rosto em blocos).

Convenção autoral (igual a avatar.py): Z para cima, a criatura olha para -Y, a "direita" dela (BracoD/PernaD) fica em -X e a
"esquerda" (BracoE/PernaE) em +X; o Roblox recebe (x, y, z) -> (-x, z, y) sem `espelhar_y` (frente = -Z do Roblox, a direita
dela em +X, como no R15). O modelo é apoiado no chão (z = 0) e centrado em x/y pelo `apoiar_no_chao`.

NOMES DOS GRUPOS: cada grupo vira uma MeshPart com UMA cor, então o nome é "<Parte>_<Cor>" (ex.: `Cabeca_Pele`,
`BracoD_Pelo`, `Cabeca_Brilho`). `<Parte>` é o grupo de TRANSFORMAÇÃO para animar por código; `<Cor>` define cor e material
(`Brilho` = Neon). Partes possíveis (nomes exatos): Corpo, Cabeca, BracoE, BracoD, PernaE, PernaD, Cauda, Arma. Em
quadrúpedes BracoE/BracoD são as patas dianteiras e PernaE/PernaD as traseiras. O `.json` gravado ao lado do FBX ganha a
chave `pivos`: {Parte: [x, y, z]} em coordenadas do ROBLOX com a origem no CENTRO DA BASE (x/z centrados, y = 0 no chão); a
caixa do modelo vai de y = 0 a y = altura, então o centro da caixa é (0, altura/2, 0). Gire a parte em volta do pivô:
CFrame = pivô * rotação * pivô:Inverse() * CFrameOriginal (eixo X do Roblox = balançar para frente/trás; eixo Z = abrir).
`Arma` acompanha o braço que a segura (pivô = ponto da empunhadura).
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector

from avatar import _Modelo, bl, sim  # noqa: F401  (_Modelo: caixas soltas sem remove_doubles)
from geom import caixa  # noqa: F401

PI = math.pi


# --------------------------------------------------------------------------------------
# infraestrutura
class _Criatura(_Modelo):
    """Modelo de caixas por grupo `<Parte>_<Cor>` com pivôs de animação convertidos para o Roblox no export."""

    def __init__(self, nome, paleta):
        super().__init__(nome)
        self.paleta = paleta
        self.pivos_autorais = {}
        self._desloc = (0.0, 0.0, 0.0)

    def g(self, parte, cor):
        """bmesh do grupo `<Parte>_<Cor>` (cria com a cor/material da paleta)."""
        rgb, mat = self.paleta[cor]
        return self.grupo(f"{parte}_{cor}", rgb, mat)

    def pivo(self, parte, x, y, z):
        self.pivos_autorais[parte] = (x, y, z)

    def apoiar_no_chao(self, objetos):
        from mathutils import Vector as V
        minimo = min((o.matrix_world @ V(c))[2] for o in objetos for c in o.bound_box)
        xs = [(o.matrix_world @ V(c))[0] for o in objetos for c in o.bound_box]
        ys = [(o.matrix_world @ V(c))[1] for o in objetos for c in o.bound_box]
        self._desloc = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, minimo)
        super().apoiar_no_chao(objetos)

    def exportar(self, objetos, saida, previa=""):
        super().exportar(objetos, saida, previa)
        import json
        lateral = saida.rsplit(".", 1)[0] + ".json"
        dx, dy, dz = self._desloc
        pivos = {p: [round(-(x - dx), 3), round(z - dz, 3), round(y - dy, 3)] for p, (x, y, z) in self.pivos_autorais.items()}
        with open(lateral, encoding="utf-8") as f:
            dados = json.load(f)
        dados["pivos"] = pivos
        dados["nota"] = "grupos '<Parte>_<Cor>'; pivos em coordenadas Roblox, origem no centro da base (y=0 no chão)"
        with open(lateral, "w", encoding="utf-8") as f:
            json.dump(dados, f, ensure_ascii=False, indent=1)


def _eixos(v):
    z = Vector(v).normalized()
    cima = Vector((0, 0, 1)) if abs(z.z) < 0.98 else Vector((0, 1, 0))
    x = cima.cross(z).normalized()
    return x, z.cross(x), z


def haste(bm, a, b, w, d=None, ext=0.0):
    """Barra de seção retangular de `a` a `b` (w na horizontal, d na vertical da barra), para membros e armas inclinados."""
    a, b = Vector(a), Vector(b)
    v = b - a
    x, y, z = _eixos(v)
    rot = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z))).to_4x4()
    m = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal(Vector((w, d or w, v.length + ext, 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def dir_membro(frente, lado=0.0):
    """Direção de um segmento: frente = 0 pendurado, 90 para a frente (-Y), 180 para cima; lado > 0 afasta para +X."""
    f, l = math.radians(frente), math.radians(lado)
    return Vector((math.sin(l), -math.sin(f), -math.cos(f))).normalized()


def cadeia(bm, pivo, segs, extra=0.5):
    """Membro articulado: lista de (comprimento, largura, frente, lado[, profundidade]). Devolve (fim, direção do último)."""
    p = Vector(pivo)
    v = Vector((0, 0, -1))
    for comp, w, frente, lado, *d in segs:
        v = dir_membro(frente, lado)
        haste(bm, p - v * w * extra, p + v * comp, w, d[0] if d else None)
        p = p + v * comp
    return p, v


def cubo(bm, c, t):
    """Cubo/caixa centrado em c com tamanho t (número ou tripla)."""
    t = (t, t, t) if isinstance(t, (int, float)) else t
    caixa(bm, c, t)


def olho(m, parte, x, y, z, t, cor="Olho", pupila="Pupila", dir=-1, alt=None):
    """Olho de blocos na face `y` (dir = -1: a face olha para -Y): globo + pupila menor à frente."""
    alt = alt or t
    bl(m.g(parte, cor), (x - t / 2, x + t / 2), (y, y + dir * 0.08), (z - alt / 2, z + alt / 2))
    bl(m.g(parte, pupila), (x - t * 0.25, x + t * 0.25), (y + dir * 0.08, y + dir * 0.14), (z - alt * 0.28, z + alt * 0.28))


def tris(modelo):
    return sum(max(len(f.verts) - 2, 1) for g in modelo.grupos.values() for f in g["bm"].faces)


# ======================================================================================
# 1. GOBLIN BATEDOR (~4 studs): variante "faca" (verde, trapos marrons) e "arco" (oliva, lenço vermelho, arco curto)
def goblin(semente, variante="faca", **_):
    arco = variante == "arco"
    pele, pele_e = ((128, 140, 64), (96, 106, 46)) if arco else ((106, 156, 74), (78, 120, 52))
    trapo, trapo_e = ((150, 66, 50), (104, 44, 36)) if arco else ((128, 98, 64), (88, 66, 44))
    pal = {"Pele": (pele, "SmoothPlastic"), "PeleEscura": (pele_e, "SmoothPlastic"), "Trapo": (trapo, "Fabric"),
           "TrapoEscuro": (trapo_e, "Fabric"), "Couro": ((86, 60, 40), "Fabric"), "Dente": ((238, 228, 190), "SmoothPlastic"),
           "Olho": ((244, 214, 70), "SmoothPlastic"), "Pupila": ((28, 22, 24), "SmoothPlastic"),
           "Metal": ((186, 190, 196), "Metal"), "Madeira": ((132, 92, 56), "Wood"), "Corda": ((210, 198, 160), "Fabric"),
           "Rosa": ((190, 110, 96), "SmoothPlastic")}
    m = _Criatura("GoblinArco" if arco else "GoblinFaca", pal)

    # Corpo: tronco curvado, tanga de trapos com barra rasgada, cinto com bolsinha
    bl(m.g("Corpo", "Pele"), (-0.62, 0.62), (-0.38, 0.40), (1.2, 2.36))
    bl(m.g("Corpo", "PeleEscura"), (-0.46, 0.46), (-0.40, -0.37), (1.7, 2.2))  # peito/costelas
    for z in (1.95, 2.1):
        bl(m.g("Corpo", "PeleEscura"), (-0.34, 0.34), (-0.405, -0.37), (z, z + 0.04))
    bl(m.g("Corpo", "Trapo"), (-0.67, 0.67), (-0.43, 0.44), (1.25, 1.9))  # camisa de trapo curta
    for x0, x1, zb in ((-0.67, -0.35, 0.95), (-0.25, 0.1, 1.1), (0.2, 0.67, 0.98)):  # barra rasgada
        bl(m.g("Corpo", "Trapo"), (x0, x1), (-0.43, 0.44), (zb, 1.25))
    bl(m.g("Corpo", "TrapoEscuro"), (-0.69, 0.69), (-0.45, 0.46), (1.7, 1.78))  # faixa
    bl(m.g("Corpo", "Couro"), (-0.7, 0.7), (-0.46, 0.47), (1.32, 1.48))  # cinto
    bl(m.g("Corpo", "Metal"), (-0.12, 0.12), (-0.49, -0.46), (1.33, 1.47))
    bl(m.g("Corpo", "Couro"), (0.36, 0.66), (-0.62, -0.46), (0.98, 1.34))  # bolsinha
    bl(m.g("Corpo", "TrapoEscuro"), (-0.5, 0.5), (0.40, 0.46), (1.2, 2.3))  # trapo de trás
    m.pivo("Corpo", 0, 0.0, 1.2)

    # Pernas finas, joelhos dobrados, pés grandes (esquerda um passo à frente)
    for nome, sx, dy in (("PernaD", -1, 0.08), ("PernaE", 1, -0.16)):
        x = sx * 0.34
        bl(m.g(nome, "Pele"), (x - 0.2, x + 0.2), (dy - 0.2, dy + 0.2), (0.3, 1.25))
        bl(m.g(nome, "PeleEscura"), (x - 0.22, x + 0.22), (dy - 0.22, dy + 0.22), (0.58, 0.68))  # joelho
        bl(m.g(nome, "TrapoEscuro"), (x - 0.24, x + 0.24), (dy - 0.24, dy + 0.24), (0.98, 1.2))  # tira de pano
        bl(m.g(nome, "PeleEscura"), (x - 0.3, x + 0.3), (dy - 0.78, dy + 0.3), (0.0, 0.3))  # pé grande
        for dx in (-0.2, 0.0, 0.2):  # dedos
            bl(m.g(nome, "Dente"), (x + dx - 0.05, x + dx + 0.05), (dy - 0.84, dy - 0.78), (0.04, 0.16))
        m.pivo(nome, x, dy, 1.22)

    # Cabeça grande com orelhas enormes, nariz longo, olhos amarelos, presas
    c = "Cabeca"
    bl(m.g(c, "Pele"), (-0.75, 0.75), (-0.78, 0.68), (2.3, 3.8))
    bl(m.g(c, "PeleEscura"), (-0.62, 0.62), (0.66, 0.72), (2.5, 3.6))  # nuca
    for sg in (-1, 1):  # orelhas em degraus, subindo para fora
        bl(m.g(c, "Pele"), (sg * 0.75, sg * 1.25), (-0.18, 0.22), (2.95, 3.3))
        bl(m.g(c, "Pele"), (sg * 1.25, sg * 1.8), (-0.12, 0.18), (3.15, 3.55))
        bl(m.g(c, "Pele"), (sg * 1.8, sg * 2.25), (-0.08, 0.14), (3.4, 3.85))
        bl(m.g(c, "Rosa"), (sg * 0.85, sg * 1.2), (-0.22, -0.18), (3.0, 3.22))  # miolo da orelha
        bl(m.g(c, "Rosa"), (sg * 1.3, sg * 1.7), (-0.16, -0.12), (3.2, 3.46))
        bl(m.g(c, "PeleEscura"), (sg * 2.05, sg * 2.23), (-0.1, 0.16), (3.72, 3.9))  # ponta
    olho(m, c, 0.36, -0.78, 3.28, 0.32)
    olho(m, c, -0.36, -0.78, 3.28, 0.32)
    for sg in (-1, 1):  # sobrancelhas franzidas
        bl(m.g(c, "PeleEscura"), (sg * 0.12, sg * 0.72), (-0.84, -0.78), (3.5, 3.62))
        bl(m.g(c, "PeleEscura"), (sg * 0.12, sg * 0.36), (-0.84, -0.78), (3.42, 3.5))
    bl(m.g(c, "Pele"), (-0.17, 0.17), (-1.1, -0.78), (2.82, 3.14))  # nariz longo e curvo
    bl(m.g(c, "Pele"), (-0.17, 0.17), (-1.36, -1.1), (2.66, 2.98))
    bl(m.g(c, "PeleEscura"), (-0.2, 0.2), (-1.4, -1.34), (2.64, 2.72))
    bl(m.g(c, "PeleEscura"), (-0.54, 0.54), (-0.82, -0.78), (2.5, 2.64))  # boca
    for x in (-0.36, 0.36):  # presas inferiores
        bl(m.g(c, "Dente"), (x - 0.07, x + 0.07), (-0.85, -0.79), (2.6, 2.88))
    for x in (-0.14, 0.14):
        bl(m.g(c, "Dente"), (x - 0.05, x + 0.05), (-0.83, -0.79), (2.55, 2.68))
    if arco:  # lenço vermelho na testa, nó atrás
        bl(m.g(c, "Trapo"), (-0.8, 0.8), (-0.83, 0.74), (3.58, 3.74))
        bl(m.g(c, "TrapoEscuro"), (-0.18, 0.18), (0.72, 0.98), (3.35, 3.66))
        bl(m.g(c, "TrapoEscuro"), (-0.1, 0.1), (0.94, 1.08), (3.2, 3.5))
    else:  # tufo de cabelo e cicatriz
        bl(m.g(c, "PeleEscura"), (-0.18, 0.18), (-0.1, 0.3), (3.8, 4.05))
        bl(m.g(c, "PeleEscura"), (-0.28, -0.1), (-0.1, 0.2), (4.0, 4.14))
        bl(m.g(c, "Trapo"), (0.34, 0.6), (-0.84, -0.78), (3.0, 3.1))  # cicatriz
    m.pivo(c, 0, 0.0, 2.35)

    # Braços finos; mão direita com a faca / arco na esquerda
    if arco:
        ponta_d, dd = cadeia(m.g("BracoD", "Pele"), (-0.9, 0.0, 2.22), [(0.85, 0.34, 20, -12), (0.8, 0.3, 105, 0)])
        ponta_e, de = cadeia(m.g("BracoE", "Pele"), (0.9, 0.0, 2.22), [(0.85, 0.34, 15, 8), (0.8, 0.3, 40, 4)])
    else:
        ponta_d, dd = cadeia(m.g("BracoD", "Pele"), (-0.9, 0.0, 2.22), [(0.8, 0.34, 28, -10), (0.8, 0.3, 100, 0)])
        ponta_e, de = cadeia(m.g("BracoE", "Pele"), (0.9, 0.0, 2.22), [(0.8, 0.34, -14, 12), (0.75, 0.3, 40, 6)])
    for nome, p, d in (("BracoD", ponta_d, dd), ("BracoE", ponta_e, de)):
        cubo(m.g(nome, "PeleEscura"), p, 0.4)
    bl(m.g("BracoD", "Trapo"), (-1.16, -0.64), (-0.26, 0.26), (1.7, 2.3))  # ombreira de trapo
    bl(m.g("BracoE", "Trapo"), (0.64, 1.16), (-0.26, 0.26), (1.9, 2.3))
    m.pivo("BracoD", -0.9, 0.0, 2.22)
    m.pivo("BracoE", 0.9, 0.0, 2.22)
    if arco:
        # arco curto na mão esquerda, vertical à frente, e uma flecha na direita
        h = ponta_e
        a = m.g("Arma", "Madeira")
        haste(a, (h.x, h.y, h.z - 0.35), (h.x, h.y - 0.1, h.z + 0.2), 0.16)
        haste(a, (h.x, h.y - 0.1, h.z + 0.2), (h.x, h.y - 0.45, h.z + 0.85), 0.14)
        haste(a, (h.x, h.y - 0.45, h.z + 0.85), (h.x, h.y - 0.7, h.z + 1.4), 0.12)
        haste(a, (h.x, h.y, h.z - 0.35), (h.x, h.y - 0.1, h.z - 0.9), 0.16)
        haste(a, (h.x, h.y - 0.1, h.z - 0.9), (h.x, h.y - 0.45, h.z - 1.5), 0.14)
        haste(a, (h.x, h.y - 0.45, h.z - 1.5), (h.x, h.y - 0.7, h.z - 2.0), 0.12)
        haste(m.g("Arma", "Corda"), (h.x, h.y - 0.7, h.z + 1.4), (h.x, h.y - 0.7, h.z - 2.0), 0.04)
        hd = ponta_d
        haste(m.g("Arma", "Madeira"), hd - dd * 0.3, hd + dd * 1.5, 0.08)  # flecha na mão direita
        haste(m.g("Arma", "Metal"), hd + dd * 1.45, hd + dd * 1.85, 0.2, 0.06)
        haste(m.g("Arma", "Corda"), hd - dd * 0.3, hd - dd * 0.05, 0.16, 0.04)
        m.pivo("Arma", h.x, h.y, h.z)
    else:
        h = ponta_d
        # faca curva: cabo de couro, guarda e lâmina larga (apontando para frente e um pouco para cima)
        haste(m.g("Arma", "Couro"), h - dd * 0.2, h + dd * 0.4, 0.17)
        haste(m.g("Arma", "Metal"), h + dd * 0.4, h + dd * 0.5, 0.12, 0.5)
        pa = h + dd * 0.5
        haste(m.g("Arma", "Metal"), pa, pa + dd * 0.85, 0.1, 0.34)
        haste(m.g("Arma", "Metal"), pa + dd * 0.85, pa + dd * 1.2 + Vector((0, 0, 0.12)), 0.08, 0.2)
        m.pivo("Arma", h.x, h.y, h.z)
    return m


# ======================================================================================
# 2. LOBO CINZENTO (~5 studs de comprimento, quadrúpede; patas dianteiras = BracoE/BracoD, traseiras = PernaE/PernaD)
def lobo(semente, **_):
    pal = {"Pelo": ((120, 124, 130), "Fabric"), "PeloEscuro": ((78, 82, 92), "Fabric"), "PeloClaro": ((190, 190, 186), "Fabric"),
           "Olho": ((246, 200, 40), "SmoothPlastic"), "Pupila": ((24, 22, 26), "SmoothPlastic"),
           "Nariz": ((30, 28, 32), "SmoothPlastic"), "Dente": ((240, 234, 216), "SmoothPlastic"),
           "Boca": ((120, 44, 52), "SmoothPlastic"), "Garra": ((54, 50, 52), "SmoothPlastic")}
    m = _Criatura("LoboCinzento", pal)

    # Corpo em degraus de pelo: ventre claro, flancos, dorso escuro, crina eriçada nos ombros
    bl(m.g("Corpo", "Pelo"), (-0.75, 0.75), (-1.1, 1.3), (1.6, 2.8))
    bl(m.g("Corpo", "PeloClaro"), (-0.6, 0.6), (-0.95, 1.1), (1.5, 1.62))
    bl(m.g("Corpo", "Pelo"), (-0.5, 0.5), (-1.0, 1.15), (2.8, 3.0))
    bl(m.g("Corpo", "PeloEscuro"), (-0.3, 0.3), (-0.9, 1.0), (3.0, 3.15))
    bl(m.g("Corpo", "PeloEscuro"), (-0.42, 0.42), (-1.15, -0.1), (3.0, 3.38))  # crina
    bl(m.g("Corpo", "PeloEscuro"), (-0.26, 0.26), (-1.1, -0.3), (3.38, 3.55))
    for y in (0.0, 0.5, 1.0):  # tufos nos flancos (degraus pendurados)
        sim(m.g("Corpo", "PeloEscuro"), (0.75, 0.87), (y, y + 0.35), (1.9, 2.5))
    sim(m.g("Corpo", "PeloEscuro"), (0.75, 0.87), (-1.0, -0.45), (2.0, 2.7))
    for i, y in enumerate((-0.6, -0.2, 0.2, 0.6, 1.0)):  # espinhaço eriçado em dentes
        bl(m.g("Corpo", "PeloEscuro"), (-0.12, 0.12), (y, y + 0.2), (3.15, 3.3 + 0.1 * (i % 2)))
    bl(m.g("Corpo", "PeloClaro"), (-0.45, 0.45), (-1.4, -0.9), (1.95, 3.0))  # peito/pescoço claro
    bl(m.g("Corpo", "Pelo"), (-0.5, 0.5), (-1.7, -1.1), (2.0, 3.0))  # pescoço
    m.pivo("Corpo", 0, 0.1, 2.2)

    # Patas dianteiras (BracoE/BracoD) e traseiras (PernaE/PernaD)
    for sg, bn, pn in ((1, "BracoE", "PernaE"), (-1, "BracoD", "PernaD")):
        x = sg * 0.5
        bl(m.g(bn, "Pelo"), (x - 0.2, x + 0.2), (-1.2, -0.76), (0.3, 1.75))
        bl(m.g(bn, "PeloClaro"), (x - 0.21, x + 0.21), (-1.22, -0.78), (0.0, 0.5))
        bl(m.g(bn, "Garra"), (x - 0.19, x + 0.19), (-1.4, -1.2), (0.0, 0.14))
        m.pivo(bn, x, -0.98, 1.75)
        # traseira: coxa grossa, canela recuada, pé
        bl(m.g(pn, "Pelo"), (x - 0.24, x + 0.24), (0.7, 1.5), (1.1, 2.4))
        bl(m.g(pn, "PeloEscuro"), (x + sg * 0.24, x + sg * 0.3), (0.8, 1.4), (1.5, 2.2))
        bl(m.g(pn, "Pelo"), (x - 0.18, x + 0.18), (1.1, 1.5), (0.35, 1.2))
        bl(m.g(pn, "PeloClaro"), (x - 0.2, x + 0.2), (0.7, 1.5), (0.0, 0.36))
        bl(m.g(pn, "Garra"), (x - 0.18, x + 0.18), (0.55, 0.7), (0.0, 0.14))
        m.pivo(pn, x, 1.1, 2.3)

    # Cabeça baixa e à frente, focinho comprido, orelhas pontudas, olhos amarelos, dentes
    c = "Cabeca"
    bl(m.g(c, "Pelo"), (-0.5, 0.5), (-2.45, -1.6), (2.35, 3.35))  # crânio
    bl(m.g(c, "PeloEscuro"), (-0.3, 0.3), (-2.4, -1.65), (3.35, 3.46))
    bl(m.g(c, "PeloClaro"), (-0.34, 0.34), (-3.05, -2.45), (2.45, 2.9))  # focinho
    bl(m.g(c, "PeloClaro"), (-0.46, 0.46), (-2.47, -2.1), (2.3, 2.5))  # bochechas
    bl(m.g(c, "Nariz"), (-0.17, 0.17), (-3.14, -3.05), (2.72, 2.98))
    bl(m.g(c, "Boca"), (-0.3, 0.3), (-2.96, -2.45), (2.38, 2.46))  # boca entreaberta
    bl(m.g(c, "PeloClaro"), (-0.27, 0.27), (-2.9, -2.45), (2.24, 2.38))  # mandíbula
    for sg in (-1, 1):
        for y in (-2.9, -2.65):
            bl(m.g(c, "Dente"), (sg * 0.22 - 0.05, sg * 0.22 + 0.05), (y - 0.05, y + 0.05), (2.3, 2.46))  # presas
        bl(m.g(c, "Dente"), (sg * 0.3 - 0.05, sg * 0.3 + 0.05), (-2.5, -2.4), (2.3, 2.5))
    olho(m, c, 0.3, -2.45, 3.0, 0.2, dir=-1)
    olho(m, c, -0.3, -2.45, 3.0, 0.2, dir=-1)
    for sg in (-1, 1):  # sobrancelha escura (olhar feroz)
        bl(m.g(c, "PeloEscuro"), (sg * 0.16, sg * 0.46), (-2.5, -2.44), (3.14, 3.24))
        bl(m.g(c, "PeloEscuro"), (sg * 0.28, sg * 0.5), (-2.5, -2.44), (3.05, 3.14))
        bl(m.g(c, "Pelo"), (sg * 0.2, sg * 0.5), (-1.9, -1.55), (3.35, 3.65))  # orelha
        bl(m.g(c, "PeloEscuro"), (sg * 0.26, sg * 0.46), (-1.85, -1.65), (3.65, 3.92))
        bl(m.g(c, "PeloEscuro"), (sg * 0.32, sg * 0.4), (-1.83, -1.7), (3.92, 4.02))
        bl(m.g(c, "PeloClaro"), (sg * 0.5, sg * 0.64), (-2.2, -1.7), (2.35, 3.1))  # costeletas
    m.pivo(c, 0, -1.65, 2.75)

    # Cauda volumosa caída
    bl(m.g("Cauda", "Pelo"), (-0.27, 0.27), (1.3, 1.95), (2.15, 2.75))
    bl(m.g("Cauda", "Pelo"), (-0.33, 0.33), (1.85, 2.5), (1.65, 2.5))
    bl(m.g("Cauda", "PeloEscuro"), (-0.25, 0.25), (2.3, 2.85), (1.1, 1.95))
    bl(m.g("Cauda", "PeloClaro"), (-0.12, 0.12), (2.42, 2.62), (1.0, 1.1))
    m.pivo("Cauda", 0, 1.3, 2.45)
    return m


# ======================================================================================
# 3. URSO DE PRESAS VERMELHAS (~8 studs de comprimento, corcunda de 5,6): quadrúpede grande
def urso(semente, **_):
    pal = {"Pelo": ((104, 74, 50), "Fabric"), "PeloEscuro": ((66, 46, 34), "Fabric"), "PeloClaro": ((158, 122, 88), "Fabric"),
           "Presa": ((200, 38, 40), "SmoothPlastic"), "Sangue": ((130, 26, 30), "SmoothPlastic"),
           "Dente": ((236, 228, 206), "SmoothPlastic"), "Boca": ((96, 24, 34), "SmoothPlastic"),
           "Olho": ((236, 150, 40), "SmoothPlastic"), "Pupila": ((30, 18, 18), "SmoothPlastic"),
           "Nariz": ((30, 24, 26), "SmoothPlastic"), "Garra": ((228, 218, 192), "SmoothPlastic")}
    m = _Criatura("UrsoPresasVermelhas", pal)

    # Corpo massivo com corcunda nos ombros, degraus de pelo, mancha clara no peito
    bl(m.g("Corpo", "Pelo"), (-1.7, 1.7), (-2.1, 2.7), (2.2, 4.7))
    bl(m.g("Corpo", "Pelo"), (-1.45, 1.45), (-2.2, 0.6), (4.7, 5.5))  # corcunda
    bl(m.g("Corpo", "PeloEscuro"), (-1.0, 1.0), (-2.0, 0.3), (5.5, 5.85))
    bl(m.g("Corpo", "PeloEscuro"), (-0.6, 0.6), (-1.7, 0.0), (5.85, 6.05))
    for i, y in enumerate((-1.5, -1.0, -0.5, 0.0, 0.7, 1.4, 2.1)):  # pelos eriçados na espinha
        bl(m.g("Corpo", "PeloEscuro"), (-0.25, 0.25), (y, y + 0.4), (6.0 if y < 0.3 else 5.0, (6.3 if y < 0.3 else 5.4) + 0.15 * (i % 2)))
    bl(m.g("Corpo", "PeloEscuro"), (-1.2, 1.2), (0.6, 2.5), (4.7, 5.0))  # dorso
    bl(m.g("Corpo", "PeloEscuro"), (-0.7, 0.7), (0.8, 2.3), (5.0, 5.2))
    bl(m.g("Corpo", "PeloClaro"), (-1.0, 1.0), (-2.2, -1.9), (2.8, 4.4))  # peito claro
    bl(m.g("Corpo", "PeloClaro"), (-0.8, 0.8), (-2.25, -2.2), (3.2, 4.0))
    sim(m.g("Corpo", "PeloEscuro"), (1.7, 1.95), (-1.6, 2.2), (2.5, 4.4))  # flancos
    sim(m.g("Corpo", "PeloEscuro"), (1.95, 2.1), (-1.0, 1.6), (2.7, 4.0))
    bl(m.g("Corpo", "PeloEscuro"), (-1.3, 1.3), (-1.6, 2.2), (1.9, 2.2))  # barriga
    bl(m.g("Corpo", "Sangue"), (-0.6, 0.0), (-2.27, -2.2), (3.0, 3.5))  # sujeira de sangue no peito
    m.pivo("Corpo", 0, 0.2, 3.5)

    for sg, bn, pn in ((1, "BracoE", "PernaE"), (-1, "BracoD", "PernaD")):
        x = sg * 1.15
        # dianteira: braço grosso, pata larga, garras claras
        bl(m.g(bn, "Pelo"), (x - 0.65, x + 0.65), (-2.15, -0.85), (0.6, 2.4))
        bl(m.g(bn, "PeloEscuro"), (x - 0.7, x + 0.7), (-2.2, -0.8), (0.0, 0.7))
        bl(m.g(bn, "PeloEscuro"), (x + sg * 0.65, x + sg * 0.75), (-1.8, -1.0), (0.9, 2.2))
        for dx in (-0.4, 0.0, 0.4):
            bl(m.g(bn, "Garra"), (x + dx - 0.1, x + dx + 0.1), (-2.55, -2.2), (0.0, 0.3))
        m.pivo(bn, x, -1.5, 2.4)
        # traseira
        xb = sg * 1.2
        bl(m.g(pn, "Pelo"), (xb - 0.7, xb + 0.7), (1.0, 2.8), (1.0, 3.2))
        bl(m.g(pn, "PeloEscuro"), (xb + sg * 0.7, xb + sg * 0.8), (1.2, 2.6), (1.4, 3.0))
        bl(m.g(pn, "PeloEscuro"), (xb - 0.62, xb + 0.62), (1.2, 2.8), (0.0, 1.1))
        for dx in (-0.35, 0.0, 0.35):
            bl(m.g(pn, "Garra"), (xb + dx - 0.1, xb + dx + 0.1), (0.75, 1.2), (0.0, 0.3))
        m.pivo(pn, xb, 1.9, 3.1)

    # Cabeça: crânio, focinho, nariz, orelhas redondas, mandíbula aberta com presas vermelhas
    c = "Cabeca"
    bl(m.g(c, "Pelo"), (-1.1, 1.1), (-4.1, -2.1), (3.3, 5.1))  # crânio
    bl(m.g(c, "PeloEscuro"), (-0.6, 0.6), (-3.9, -2.4), (5.1, 5.3))
    bl(m.g(c, "PeloClaro"), (-0.62, 0.62), (-5.0, -4.1), (3.5, 4.4))  # focinho
    bl(m.g(c, "PeloClaro"), (-0.75, 0.75), (-4.15, -3.6), (3.35, 3.55))  # lábios
    bl(m.g(c, "Nariz"), (-0.35, 0.35), (-5.12, -5.0), (3.95, 4.4))
    bl(m.g(c, "Boca"), (-0.55, 0.55), (-4.95, -3.7), (3.1, 3.5))  # boca aberta
    bl(m.g(c, "PeloClaro"), (-0.55, 0.55), (-4.8, -3.7), (2.65, 3.1))  # mandíbula
    bl(m.g(c, "Sangue"), (-0.6, 0.6), (-5.02, -4.1), (3.4, 3.6))  # sangue na boca
    bl(m.g(c, "Sangue"), (-0.5, 0.5), (-4.85, -4.2), (2.62, 2.7))
    for sg in (-1, 1):
        bl(m.g(c, "Presa"), (sg * 0.4 - 0.15, sg * 0.4 + 0.15), (-4.95, -4.65), (2.95, 3.65))  # presas de cima
        bl(m.g(c, "Presa"), (sg * 0.28 - 0.12, sg * 0.28 + 0.12), (-4.9, -4.66), (3.15, 3.62))  # presas de baixo
        for y in (-4.4, -4.0):
            bl(m.g(c, "Dente"), (sg * 0.45 - 0.07, sg * 0.45 + 0.07), (y - 0.08, y + 0.08), (3.3, 3.6))
        bl(m.g(c, "Pelo"), (sg * 0.75, sg * 1.35), (-3.3, -2.6), (4.9, 5.5))  # orelha redonda
        bl(m.g(c, "PeloEscuro"), (sg * 0.85, sg * 1.25), (-3.1, -2.8), (5.0, 5.4))
        bl(m.g(c, "PeloEscuro"), (sg * 0.2, sg * 0.95), (-4.17, -4.1), (4.55, 4.7))  # sobrancelha
        bl(m.g(c, "PeloEscuro"), (sg * 0.3, sg * 1.1), (-4.17, -4.1), (4.45, 4.55))
    olho(m, c, 0.62, -4.1, 4.3, 0.34, cor="Olho")
    olho(m, c, -0.62, -4.1, 4.3, 0.34, cor="Olho")
    m.pivo(c, 0, -2.2, 4.1)

    bl(m.g("Cauda", "PeloEscuro"), (-0.4, 0.4), (2.7, 3.2), (3.5, 4.2))  # toco de cauda
    m.pivo("Cauda", 0, 2.7, 3.8)
    return m


# ======================================================================================
# 4. BANDIDO DE ESTRADA (humanoide como o avatar; variante "porrete" ou "espada")
def bandido(semente, variante="porrete", **_):
    pal = {"Pele": ((226, 178, 138), "SmoothPlastic"), "Capuz": ((70, 62, 56), "Fabric"), "CapuzEscuro": ((46, 40, 38), "Fabric"),
           "Lenco": ((150, 44, 40), "Fabric"), "Couro": ((110, 76, 48), "Fabric"), "CouroEscuro": ((70, 50, 36), "Fabric"),
           "Pano": ((98, 98, 84), "Fabric"), "Calca": ((78, 70, 64), "Fabric"), "Metal": ((186, 190, 196), "Metal"),
           "MetalEscuro": ((110, 114, 122), "Metal"), "Madeira": ((128, 90, 54), "Wood"), "Branco": ((244, 244, 240), "SmoothPlastic"),
           "Pupila": ((28, 22, 24), "SmoothPlastic"), "PeleEscura": ((140, 92, 70), "SmoothPlastic")}
    m = _Criatura("BandidoEstrada", pal)
    # pernas (como o avatar: 1 x 1 x 2), botas e joelheiras
    for nome, sg in (("PernaD", -1), ("PernaE", 1)):
        x = sg * 0.5
        bl(m.g(nome, "Calca"), (x - 0.5, x + 0.5), (-0.5, 0.5), (0.55, 2.02))
        bl(m.g(nome, "CouroEscuro"), (x - 0.54, x + 0.54), (-0.54, 0.54), (0.0, 0.7))  # bota
        bl(m.g(nome, "CouroEscuro"), (x - 0.5, x + 0.5), (-0.76, -0.54), (0.0, 0.3))
        bl(m.g(nome, "Couro"), (x - 0.56, x + 0.56), (-0.56, 0.56), (0.7, 0.86))  # barra dobrada
        bl(m.g(nome, "Couro"), (x - 0.3, x + 0.3), (-0.55, -0.5), (1.1, 1.45))  # joelheira
        m.pivo(nome, x, 0.0, 2.0)
    # tronco: cinto, gibão de couro por cima da camisa, alça e bolsa
    bl(m.g("Corpo", "CouroEscuro"), (-1.02, 1.02), (-0.52, 0.52), (2.0, 2.42))
    bl(m.g("Corpo", "Metal"), (-0.18, 0.18), (-0.58, -0.52), (2.06, 2.36))
    bl(m.g("Corpo", "Pano"), (-1.0, 1.0), (-0.5, 0.5), (2.4, 4.0))
    bl(m.g("Corpo", "Couro"), (-1.04, 1.04), (-0.54, 0.54), (2.42, 3.6))
    bl(m.g("Corpo", "CouroEscuro"), (-0.08, 0.08), (-0.58, -0.54), (2.42, 3.6))  # costura central
    bl(m.g("Corpo", "CouroEscuro"), (-1.05, 1.05), (-0.55, 0.55), (3.5, 3.62))
    bl(m.g("Corpo", "Couro"), (-0.35, 0.5), (-0.7, -0.54), (2.05, 2.55))  # bolsa
    bl(m.g("Corpo", "CouroEscuro"), (-0.35, 0.5), (-0.72, -0.64), (2.35, 2.55))
    bl(m.g("Corpo", "CouroEscuro"), (-1.06, 0.2), (-0.56, -0.5), (3.0, 3.12))  # bandoleira
    bl(m.g("Corpo", "Pano"), (-0.9, 0.9), (0.5, 0.62), (2.4, 3.9))  # capa curta nas costas
    bl(m.g("Corpo", "CapuzEscuro"), (-0.8, 0.8), (0.58, 0.7), (2.5, 3.9))
    m.pivo("Corpo", 0, 0.0, 2.0)
    # cabeça: capuz com aba, lenço no rosto, olhos de bloco franzidos
    c = "Cabeca"
    bl(m.g(c, "Pele"), (-0.6, 0.6), (-0.6, 0.6), (4.0, 5.2))
    bl(m.g(c, "Lenco"), (-0.66, 0.66), (-0.67, 0.64), (4.0, 4.5))  # lenço cobrindo boca e nariz
    bl(m.g(c, "Lenco"), (-0.2, 0.2), (0.64, 0.95), (4.1, 4.4))  # ponta do nó
    bl(m.g(c, "CapuzEscuro"), (-0.3, 0.3), (0.9, 1.1), (3.9, 4.2))
    bl(m.g(c, "Capuz"), (-0.74, 0.74), (-0.7, 0.8), (5.1, 5.4))  # topo
    bl(m.g(c, "Capuz"), (-0.6, 0.6), (-0.55, 0.7), (5.4, 5.58))
    bl(m.g(c, "Capuz"), (-0.735, 0.735), (-0.76, -0.55), (5.1, 5.4))  # aba da testa
    bl(m.g(c, "CapuzEscuro"), (-0.62, 0.62), (-0.765, -0.7), (5.12, 5.2))  # sombra sob a aba
    for sg in (-1, 1):
        bl(m.g(c, "Capuz"), (sg * 0.6, sg * 0.735), (-0.7, 0.8), (4.0, 5.1))  # laterais
    bl(m.g(c, "Capuz"), (-0.73, 0.73), (0.6, 0.795), (4.0, 5.38))  # costas
    bl(m.g(c, "Capuz"), (-0.4, 0.4), (0.78, 1.05), (4.2, 5.1))  # ponta
    # olhos (alturas do catálogo do avatar), irritados
    for sg in (-1, 1):
        bl(m.g(c, "Branco"), (sg * 0.27 - 0.09, sg * 0.27 + 0.09), (-0.65, -0.61), (4.66, 4.84))
        bl(m.g(c, "Pupila"), (sg * 0.27 - 0.05, sg * 0.27 + 0.05), (-0.67, -0.65), (4.69, 4.81))
        bl(m.g(c, "CapuzEscuro"), (sg * 0.1, sg * 0.4), (-0.67, -0.61), (4.88, 4.96))  # sobrancelha franzida
        bl(m.g(c, "CapuzEscuro"), (sg * 0.28, sg * 0.4), (-0.67, -0.61), (4.82, 4.88))
    bl(m.g(c, "PeleEscura"), (0.12, 0.4), (-0.64, -0.6), (4.5, 4.58))  # cicatriz no rosto
    m.pivo(c, 0, 0.0, 4.0)
    # braços de 1 x 1 (como o avatar), antebraço com braçadeira; direito levanta a arma, esquerdo guarda
    pd, dd = cadeia(m.g("BracoD", "Couro"), (-1.5, 0.0, 3.85), [(1.0, 0.95, 28, -22), (1.05, 0.9, 100, -14)])
    pe, de = cadeia(m.g("BracoE", "Couro"), (1.5, 0.0, 3.85), [(0.95, 0.95, 12, 10), (1.0, 0.9, 62, 8)])
    for nome, p, d in (("BracoD", pd, dd), ("BracoE", pe, de)):
        cubo(m.g(nome, "Pele"), p, 0.7)
        haste(m.g(nome, "CouroEscuro"), p - d * 0.9, p - d * 0.45, 0.98, 0.95)  # braçadeira
    bl(m.g("BracoD", "CouroEscuro"), (-2.05, -0.95), (-0.55, 0.55), (3.75, 4.1))  # ombreira
    bl(m.g("BracoE", "CouroEscuro"), (0.95, 2.05), (-0.55, 0.55), (3.75, 4.1))
    m.pivo("BracoD", -1.5, 0.0, 3.85)
    m.pivo("BracoE", 1.5, 0.0, 3.85)
    h = pd
    if variante == "espada":
        ar = Vector((-0.2, 0.08, 0.97)).normalized()  # a arma sobe, inclinada para fora e para trás (apoiada no ombro)
        haste(m.g("Arma", "CouroEscuro"), h - ar * 0.45, h + ar * 0.3, 0.22)
        haste(m.g("Arma", "Metal"), h + ar * 0.3, h + ar * 0.42, 0.22, 1.0)  # guarda
        haste(m.g("Arma", "Metal"), h + ar * 0.42, h + ar * 2.5, 0.14, 0.46)  # lâmina larga
        haste(m.g("Arma", "MetalEscuro"), h + ar * 0.5, h + ar * 2.45, 0.16, 0.1)  # fio escuro
    else:
        ar = Vector((-0.2, 0.08, 0.97)).normalized()  # o porrete sobe, inclinado para fora e para trás (apoiado no ombro)
        haste(m.g("Arma", "Madeira"), h - ar * 0.5, h + ar * 1.2, 0.34)  # cabo grosso
        haste(m.g("Arma", "Madeira"), h + ar * 1.2, h + ar * 2.4, 0.66)  # cabeça pesada
        for t in (1.45, 1.95):  # pregos
            for off in ((0.34, 0, 0), (-0.34, 0, 0), (0, 0.34, 0), (0, -0.34, 0)):
                cubo(m.g("Arma", "Metal"), h + ar * t + Vector(off), 0.15)
        haste(m.g("Arma", "CouroEscuro"), h - ar * 0.15, h + ar * 0.3, 0.42)  # empunhadura
    m.pivo("Arma", h.x, h.y, h.z)
    return m


# ======================================================================================
# 5a. RATO GIGANTE (pequeno, ~3,5 com a cauda)
def rato(semente, **_):
    pal = {"Pelo": ((112, 98, 86), "Fabric"), "PeloEscuro": ((72, 62, 56), "Fabric"), "Rosa": ((218, 150, 150), "SmoothPlastic"),
           "Olho": ((190, 36, 40), "SmoothPlastic"), "Pupila": ((24, 18, 20), "SmoothPlastic"),
           "Dente": ((240, 232, 200), "SmoothPlastic"), "Bigode": ((226, 220, 210), "SmoothPlastic"), "Garra": ((70, 58, 54), "SmoothPlastic")}
    m = _Criatura("RatoGigante", pal)
    bl(m.g("Corpo", "Pelo"), (-0.55, 0.55), (-0.5, 1.25), (0.5, 1.4))
    bl(m.g("Corpo", "Pelo"), (-0.62, 0.62), (-0.6, 0.35), (0.55, 1.55))  # ombros arqueados
    bl(m.g("Corpo", "PeloEscuro"), (-0.3, 0.3), (-0.4, 1.1), (1.4, 1.55))  # dorso
    bl(m.g("Corpo", "PeloEscuro"), (-0.18, 0.18), (-0.5, 0.2), (1.55, 1.68))
    bl(m.g("Corpo", "Rosa"), (-0.4, 0.4), (-0.3, 1.0), (0.44, 0.52))  # barriga
    for y in (0.2, 0.7):  # tufos
        sim(m.g("Corpo", "PeloEscuro"), (0.55, 0.65), (y, y + 0.3), (0.7, 1.2))
    m.pivo("Corpo", 0, 0.4, 0.9)
    for sg, bn, pn in ((1, "BracoE", "PernaE"), (-1, "BracoD", "PernaD")):
        x = sg * 0.4
        bl(m.g(bn, "Pelo"), (x - 0.16, x + 0.16), (-0.5, -0.1), (0.15, 0.9))
        bl(m.g(bn, "Rosa"), (x - 0.18, x + 0.18), (-0.8, -0.1), (0.0, 0.18))
        m.pivo(bn, x, -0.3, 0.9)
        bl(m.g(pn, "Pelo"), (x - 0.2, x + 0.2), (0.7, 1.2), (0.2, 1.0))
        bl(m.g(pn, "Rosa"), (x - 0.2, x + 0.2), (0.45, 1.25), (0.0, 0.2))
        m.pivo(pn, x, 0.95, 1.0)
    c = "Cabeca"
    bl(m.g(c, "Pelo"), (-0.42, 0.42), (-1.35, -0.55), (0.55, 1.4))
    bl(m.g(c, "Pelo"), (-0.28, 0.28), (-1.9, -1.35), (0.6, 1.1))  # focinho
    bl(m.g(c, "PeloEscuro"), (-0.14, 0.14), (-2.15, -1.9), (0.66, 0.96))
    bl(m.g(c, "Rosa"), (-0.12, 0.12), (-2.28, -2.15), (0.7, 0.9))  # nariz
    bl(m.g(c, "Dente"), (-0.1, 0.1), (-1.98, -1.84), (0.4, 0.66))  # dentes de roedor
    olho(m, c, 0.2, -1.35, 1.1, 0.2, dir=-1)
    olho(m, c, -0.2, -1.35, 1.1, 0.2, dir=-1)
    for sg in (-1, 1):
        bl(m.g(c, "Pelo"), (sg * 0.42, sg * 0.57), (-1.0, -0.55), (1.0, 1.85))  # orelhas grandes
        bl(m.g(c, "Rosa"), (sg * 0.57, sg * 0.62), (-0.95, -0.62), (1.08, 1.75))
        bl(m.g(c, "PeloEscuro"), (sg * 0.42, sg * 0.57), (-0.9, -0.65), (1.85, 1.95))
        for dz, dy in ((0.0, 0.0), (0.12, -0.1), (-0.12, 0.1)):  # bigodes
            haste(m.g(c, "Bigode"), (sg * 0.2, -1.95 + dy, 0.8 + dz), (sg * 0.62, -1.8 + dy * 2, 0.84 + dz * 1.6), 0.035)
    m.pivo(c, 0, -0.55, 0.95)
    # cauda longa, fina e rosada, em curva
    pts = [(0, 1.2, 0.95), (0.12, 1.75, 0.8), (0.4, 2.3, 0.62), (0.8, 2.75, 0.45), (1.3, 3.0, 0.3), (1.85, 3.05, 0.2)]
    for i in range(len(pts) - 1):
        haste(m.g("Cauda", "Rosa"), pts[i], pts[i + 1], 0.2 - i * 0.02, ext=0.04)
    m.pivo("Cauda", 0, 1.2, 0.95)
    return m


# ======================================================================================
# 5b. ARANHA DA FLORESTA (8 pernas; PernaE = as 4 de +X, PernaD = as 4 de -X)
def aranha(semente, **_):
    pal = {"Corpo": ((58, 54, 42), "Fabric"), "Marca": ((196, 168, 56), "Fabric"), "Escuro": ((34, 32, 28), "Fabric"),
           "Perna": ((74, 66, 50), "Fabric"), "Junta": ((196, 190, 150), "Fabric"), "Olho": ((220, 48, 40), "SmoothPlastic"),
           "Presa": ((226, 220, 190), "SmoothPlastic"), "Veneno": ((120, 190, 70), "SmoothPlastic")}
    m = _Criatura("AranhaFloresta", pal)
    # abdome grande em degraus com ampulheta amarela, cefalotórax menor
    c = "Corpo"
    bl(m.g(c, "Corpo"), (-1.1, 1.1), (0.55, 2.85), (0.95, 2.15))
    bl(m.g(c, "Corpo"), (-0.85, 0.85), (0.7, 2.7), (2.15, 2.5))
    bl(m.g(c, "Corpo"), (-0.65, 0.65), (0.55, 3.05), (1.1, 1.95))
    bl(m.g(c, "Escuro"), (-0.5, 0.5), (3.0, 3.3), (1.2, 1.75))  # fiandeira
    bl(m.g(c, "Marca"), (-0.38, 0.38), (0.95, 1.7), (2.5, 2.54))  # ampulheta do dorso (vista de cima)
    bl(m.g(c, "Marca"), (-0.22, 0.22), (1.7, 2.45), (2.5, 2.54))
    bl(m.g(c, "Marca"), (-0.6, 0.6), (1.7, 2.0), (2.5, 2.54))
    bl(m.g(c, "Marca"), (-0.14, 0.14), (0.75, 2.65), (2.5, 2.56))
    for sg in (-1, 1):
        bl(m.g(c, "Marca"), (sg * 1.1, sg * 1.14), (1.0, 2.6), (1.3, 1.8))  # listras laterais
    bl(m.g(c, "Corpo"), (-0.62, 0.62), (-0.75, 0.6), (0.95, 1.75))  # cefalotórax
    bl(m.g(c, "Escuro"), (-0.4, 0.4), (-0.8, -0.1), (1.75, 1.9))
    bl(m.g(c, "Corpo"), (-0.3, 0.3), (0.5, 0.75), (1.2, 1.6))  # cintura
    m.pivo(c, 0, 0.5, 1.4)
    # cabeça (olhos, presas)
    h = "Cabeca"
    bl(m.g(h, "Escuro"), (-0.52, 0.52), (-0.98, -0.72), (1.0, 1.7))
    for x, z in ((-0.36, 1.5), (0.36, 1.5), (-0.14, 1.52), (0.14, 1.52)):
        bl(m.g(h, "Olho"), (x - 0.09, x + 0.09), (-1.06, -0.98), (z - 0.09, z + 0.09))
    for x, z in ((-0.5, 1.25), (0.5, 1.25), (-0.24, 1.3), (0.24, 1.3)):
        bl(m.g(h, "Olho"), (x - 0.06, x + 0.06), (-1.03, -0.98), (z - 0.06, z + 0.06))
    for sg in (-1, 1):  # quelíceras
        bl(m.g(h, "Presa"), (sg * 0.3 - 0.12, sg * 0.3 + 0.12), (-1.15, -0.95), (0.55, 1.1))
        bl(m.g(h, "Veneno"), (sg * 0.3 - 0.05, sg * 0.3 + 0.05), (-1.2, -1.12), (0.5, 0.6))
        bl(m.g(h, "Escuro"), (sg * 0.75, sg * 0.9), (-0.95, -0.55), (0.9, 1.3))  # palpos
    m.pivo(h, 0, -0.7, 1.3)
    # pernas: 4 pares; cada uma sai do cefalotórax, sobe, e desce para fora até o chão
    azim = (22, 62, 105, 150)  # ângulo a partir de -Y (para a frente) até o lado
    ys = (-0.55, -0.3, 0.0, 0.3)
    for sg, nome in ((1, "PernaE"), (-1, "PernaD")):
        for a, y0 in zip(azim, ys):
            ar = math.radians(a)
            u = Vector((sg * math.sin(ar), -math.cos(ar), 0))
            p0 = Vector((sg * 0.5, y0, 1.35))
            p1 = p0 + u * 0.75 + Vector((0, 0, 0.8))
            p2 = p1 + u * 0.9 + Vector((0, 0, 0.2))
            p3 = p2 + u * 0.6 - Vector((0, 0, 1.7))
            p4 = p3 + u * 0.35 - Vector((0, 0, 0.5))
            haste(m.g(nome, "Perna"), p0, p1, 0.3, ext=0.1)
            haste(m.g(nome, "Perna"), p1, p2, 0.26, ext=0.1)
            cubo(m.g(nome, "Junta"), p2, 0.34)
            haste(m.g(nome, "Perna"), p2, p3, 0.22, ext=0.06)
            haste(m.g(nome, "Escuro"), p3, p4, 0.16, ext=0.04)
        m.pivo(nome, sg * 0.5, -0.1, 1.35)
    return m


# ======================================================================================
# 6. TREANT ANCIÃO (chefe, ~18 studs): árvore viva, rosto em casca, braços-galho, musgo, olhos verdes brilhantes
def treant(semente, **_):
    rng = random.Random(semente * 31 + 7)
    pal = {"Casca": ((96, 68, 46), "Wood"), "CascaEscura": ((58, 42, 32), "Wood"), "CascaClara": ((140, 106, 70), "Wood"),
           "Musgo": ((84, 130, 56), "Grass"), "MusgoEscuro": ((54, 92, 44), "Grass"), "Folha": ((50, 108, 52), "Grass"),
           "FolhaClara": ((112, 168, 70), "Grass"), "Boca": ((22, 16, 14), "SmoothPlastic"), "Brilho": ((120, 255, 110), "Neon"),
           "Dente": ((200, 184, 140), "Wood")}
    m = _Criatura("TreantAncdiao".replace("diao", "iao"), pal)

    def folhas(parte, c, caixa_xyz, n, t0=0.9, t1=1.7):
        """Aglomerado de cubos de folha (verde escuro e claro) dentro da caixa (±x, ±y, ±z) em torno de c."""
        for _ in range(n):
            t = rng.uniform(t0, t1)
            p = (c[0] + rng.uniform(-caixa_xyz[0], caixa_xyz[0]), c[1] + rng.uniform(-caixa_xyz[1], caixa_xyz[1]),
                 c[2] + rng.uniform(-caixa_xyz[2], caixa_xyz[2]))
            cubo(m.g(parte, "FolhaClara" if rng.random() < 0.35 else "Folha"), p, (t, t, t * 0.9))

    # Pernas-raiz: pé largo com dedos de raiz, canela e coxa grossas
    for nome, sg in (("PernaD", -1), ("PernaE", 1)):
        x = sg * 2.0
        bl(m.g(nome, "Casca"), (x - 1.15, x + 1.15), (-1.15, 1.15), (1.3, 5.6))
        bl(m.g(nome, "CascaEscura"), (x - 1.2, x + 1.2), (-0.2, 0.2), (1.5, 5.5))  # veio
        bl(m.g(nome, "CascaClara"), (x - 1.0, x + 1.0), (-1.2, -1.1), (2.0, 5.3))  # estria
        bl(m.g(nome, "Casca"), (x - 1.8, x + 1.8), (-1.9, 1.7), (0.0, 1.4))  # pé
        for dx in (-1.1, 0.0, 1.1):
            bl(m.g(nome, "CascaEscura"), (x + dx - 0.4, x + dx + 0.4), (-3.2, -1.9), (0.0, 0.7))  # dedos de raiz
            bl(m.g(nome, "Casca"), (x + dx - 0.3, x + dx + 0.3), (-3.5, -3.1), (0.0, 0.45))
        bl(m.g(nome, "CascaEscura"), (x + sg * 1.0, x + sg * 2.1), (-0.8, 1.2), (0.0, 0.9))  # raiz lateral
        bl(m.g(nome, "Musgo"), (x - 1.3, x + 0.9), (-1.2, 0.4), (4.8, 5.5))  # musgo no joelho/coxa
        bl(m.g(nome, "Musgo"), (x - 0.4, x + 1.2), (-1.9, -0.9), (1.4, 1.8))  # musgo no pé
        m.pivo(nome, x, 0.0, 5.5)

    # Tronco em três degraus largos, estrias de casca, nós, musgo nos ombros, veios de seiva brilhante
    c = "Corpo"
    bl(m.g(c, "Casca"), (-3.4, 3.4), (-2.6, 2.6), (5.0, 6.6))
    bl(m.g(c, "Casca"), (-3.0, 3.0), (-2.3, 2.3), (6.6, 9.4))
    bl(m.g(c, "Casca"), (-3.7, 3.7), (-2.7, 2.7), (9.4, 12.4))
    for x in (-2.4, -1.2, 0.0, 1.2, 2.4):  # estrias verticais (frente e costas)
        h = rng.uniform(0.8, 1.0)
        bl(m.g(c, "CascaEscura"), (x - 0.25, x + 0.25), (-2.85, -2.6), (5.2, 5.2 + 6.5 * h))
        bl(m.g(c, "CascaClara"), (x + 0.45, x + 0.75), (-2.8, -2.6), (7.0, 8.4))
        bl(m.g(c, "CascaEscura"), (x - 0.25, x + 0.25), (2.6, 2.85), (5.4, 5.4 + 6.2 * h))
    for z in (6.6, 9.4):  # cintas entre os degraus
        bl(m.g(c, "CascaEscura"), (-3.1, 3.1), (-2.5, 2.5), (z - 0.2, z + 0.2))
    bl(m.g(c, "CascaClara"), (-1.4, -0.3), (-2.9, -2.6), (10.0, 11.4))  # nó do peito
    bl(m.g(c, "CascaEscura"), (-1.5, -0.2), (-2.95, -2.85), (10.1, 11.3))
    for x, z0, z1 in ((0.55, 9.8, 11.7), (1.0, 8.2, 10.4), (-0.1, 7.2, 9.5)):  # veios de seiva brilhante
        bl(m.g(c, "Brilho"), (x - 0.1, x + 0.1), (-2.88, -2.72), (z0, z1))
    for sg in (-1, 1):  # musgo grosso nos ombros e toco de galho quebrado nas laterais
        bl(m.g(c, "Musgo"), (sg * 1.2, sg * 3.8), (-2.2, 2.2), (12.4, 13.2))
        bl(m.g(c, "MusgoEscuro"), (sg * 1.8, sg * 3.4), (-1.6, 1.8), (13.2, 13.7))
        bl(m.g(c, "CascaEscura"), (sg * 3.0, sg * 3.9), (1.0, 1.9), (7.5, 8.3))
        bl(m.g(c, "Casca"), (sg * 3.7, sg * 4.6), (1.1, 1.8), (7.7, 8.1))
    bl(m.g(c, "Musgo"), (-2.4, -0.4), (2.6, 3.0), (7.6, 10.2))  # musgo nas costas
    bl(m.g(c, "MusgoEscuro"), (1.0, 2.6), (2.6, 3.0), (6.0, 8.8))
    m.pivo(c, 0, 0.0, 5.2)

    # Cabeça: face de casca (testa pesada, nariz-nó, boca escura com dentes de lascas), barba de musgo e copa de folhas
    h = "Cabeca"
    bl(m.g(h, "Casca"), (-2.4, 2.4), (-2.4, 2.2), (12.2, 15.3))
    bl(m.g(h, "CascaEscura"), (-2.5, 2.5), (-2.45, 2.25), (12.2, 12.5))
    bl(m.g(h, "CascaClara"), (-2.0, 2.0), (-2.5, -2.4), (14.9, 15.3))  # testa clara
    for sg in (-1, 1):
        bl(m.g(h, "CascaEscura"), (sg * 0.3, sg * 2.2), (-2.75, -2.4), (14.8, 15.2))  # sobrancelha grossa
        bl(m.g(h, "CascaEscura"), (sg * 0.3, sg * 1.3), (-2.75, -2.4), (14.4, 14.8))  # (inclina para o centro: franzido)
        bl(m.g(h, "Brilho"), (sg * 1.55 - 0.5, sg * 1.55 + 0.5), (-2.6, -2.4), (13.55, 14.4))  # olhos de luz verde
        bl(m.g(h, "CascaEscura"), (sg * 1.55 - 0.65, sg * 1.55 + 0.65), (-2.62, -2.4), (13.4, 13.55))  # pálpebra de baixo
        bl(m.g(h, "CascaEscura"), (sg * 2.4, sg * 2.7), (-1.6, 1.4), (12.6, 15.0))  # costelas laterais da cara
    bl(m.g(h, "Casca"), (-0.6, 0.6), (-3.2, -2.4), (12.9, 14.2))  # nariz-nó
    bl(m.g(h, "CascaClara"), (-0.45, 0.45), (-3.25, -3.2), (13.0, 14.0))
    bl(m.g(h, "Boca"), (-1.5, 1.5), (-2.65, -2.38), (12.35, 12.95))  # boca escura
    for x in (-1.1, -0.35, 0.4, 1.0):
        bl(m.g(h, "Dente"), (x - 0.18, x + 0.18), (-2.66, -2.5), (12.7, 13.0))  # dentes de lasca (cima)
    for x in (-0.8, 0.0, 0.8):
        bl(m.g(h, "Dente"), (x - 0.16, x + 0.16), (-2.66, -2.5), (12.35, 12.6))
    bl(m.g(h, "Musgo"), (-1.6, 1.6), (-2.75, -2.2), (11.5, 12.3))  # barba de musgo
    bl(m.g(h, "MusgoEscuro"), (-1.0, 1.0), (-2.7, -2.3), (10.6, 11.5))
    bl(m.g(h, "Musgo"), (-0.4, 0.4), (-2.6, -2.4), (9.8, 10.6))
    # copa: três degraus de folhas, galhos que sobem pelos lados da cabeça
    bl(m.g(h, "Casca"), (-2.2, 2.2), (-2.2, 2.0), (15.3, 15.9))
    for sg in (-1, 1):
        haste(m.g(h, "Casca"), (sg * 2.2, 0.0, 14.0), (sg * 3.7, 0.0, 16.6), 0.9)
        haste(m.g(h, "Casca"), (sg * 3.7, 0.0, 16.6), (sg * 3.2, -0.3, 18.4), 0.6)
    folhas(h, (0, 0, 16.5), (2.9, 2.6, 0.5), 26, 1.1, 1.9)
    folhas(h, (0, 0, 17.6), (2.2, 2.0, 0.4), 18, 1.1, 1.8)
    folhas(h, (0, 0, 18.5), (1.3, 1.2, 0.3), 8, 1.0, 1.6)
    for sg in (-1, 1):
        folhas(h, (sg * 3.7, 0, 16.9), (0.9, 0.9, 0.6), 7, 0.9, 1.5)
        folhas(h, (sg * 3.2, -0.3, 18.6), (0.6, 0.6, 0.4), 4, 0.8, 1.2)
    m.pivo(h, 0, 0.0, 12.2)

    # Braços-galho: ombro grosso, antebraço que se afina, mão de três galhos-dedo; o direito se ergue, o esquerdo pende
    for nome, sg, f1, f2 in (("BracoD", -1, 22, 105), ("BracoE", 1, 12, 58)):
        piv = (sg * 4.2, 0.0, 11.4)
        bl(m.g(nome, "Casca"), (sg * 4.2 - 1.3, sg * 4.2 + 1.3), (-1.3, 1.3), (10.4, 12.4))  # ombro
        bl(m.g(nome, "Musgo"), (sg * 4.2 - 1.2, sg * 4.2 + 1.2), (-1.0, 1.2), (12.4, 12.8))
        cotovelo, v1 = cadeia(m.g(nome, "Casca"), piv, [(3.8, 2.0, f1, sg * 36, 2.0)])
        cubo(m.g(nome, "CascaEscura"), cotovelo, 1.9)
        cubo(m.g(nome, "Musgo"), cotovelo + Vector((0, 0, 0.9)), (1.5, 1.4, 0.7))
        mao, v2 = cadeia(m.g(nome, "Casca"), cotovelo, [(3.9, 1.5, f2, sg * 14, 1.5)])
        haste(m.g(nome, "CascaEscura"), cotovelo, cotovelo + v2 * 3.9, 0.35, 1.0)  # veio escuro
        cubo(m.g(nome, "CascaEscura"), mao, 1.2)
        # galhos-dedo (três) e folhas nas pontas
        for ang_f, ang_l in ((-30, -26), (0, 0), (30, 26)):
            d = (v2 + Vector((sg * math.sin(math.radians(ang_l)) * 0.7, 0.0, 0.0))).normalized()
            d = Vector((d.x, d.y, d.z + math.sin(math.radians(ang_f)) * 0.5)).normalized()
            haste(m.g(nome, "CascaEscura"), mao, mao + d * 2.2, 0.55, 0.5)
            haste(m.g(nome, "Casca"), mao + d * 2.1, mao + d * 3.0, 0.32, 0.3)
            folhas(nome, mao + d * 3.1, (0.2, 0.2, 0.2), 1, 0.7, 0.9)
        # galho lateral com folhas no antebraço
        p = cotovelo + v2 * 2.0
        haste(m.g(nome, "Casca"), p, p + Vector((sg * 0.9, -0.2, 1.7)), 0.5)
        folhas(nome, p + Vector((sg * 1.0, -0.2, 2.0)), (0.5, 0.5, 0.3), 4, 0.7, 1.1)
        p0 = cotovelo - v1 * 1.2
        haste(m.g(nome, "Casca"), p0, p0 + Vector((sg * 1.2, 0.3, 1.3)), 0.45)
        folhas(nome, p0 + Vector((sg * 1.3, 0.3, 1.6)), (0.5, 0.5, 0.3), 3, 0.7, 1.0)
        m.pivo(nome, piv[0], piv[1], piv[2])
    return m


# ======================================================================================
# 7. GOLEM DE PEDRA MENOR (~9 studs): blocos de pedra, runas âmbar brilhantes, musgo
def golem(semente, **_):
    pal = {"Pedra": ((124, 126, 122), "Slate"), "PedraEscura": ((84, 88, 90), "Slate"), "PedraClara": ((168, 168, 156), "Slate"),
           "Musgo": ((84, 120, 58), "Grass"), "Brilho": ((255, 160, 50), "Neon"), "Fenda": ((30, 30, 34), "Slate")}
    m = _Criatura("GolemPedraMenor", pal)

    def runa(parte, cx, cz, y, tipo, esc=1.0):
        """Glifo de runa em degraus no plano XZ (a face é y; o glifo sai 0,12 para -Y)."""
        b = m.g(parte, "Brilho")
        e = 0.16 * esc
        if tipo == 1:  # losango com haste
            bl(b, (cx - e / 2, cx + e / 2), (y - 0.12, y), (cz + 0.5 * esc, cz + 0.66 * esc))
            bl(b, (cx - 0.3 * esc, cx + 0.3 * esc), (y - 0.12, y), (cz + 0.18 * esc, cz + 0.18 * esc + e))
            bl(b, (cx - 0.3 * esc, cx - 0.3 * esc + e), (y - 0.12, y), (cz - 0.5 * esc, cz + 0.34 * esc))
            bl(b, (cx + 0.3 * esc - e, cx + 0.3 * esc), (y - 0.12, y), (cz - 0.5 * esc, cz + 0.34 * esc))
            bl(b, (cx - e / 2, cx + e / 2), (y - 0.12, y), (cz - 0.66 * esc, cz - 0.5 * esc))
        else:  # "Z" quebrado
            bl(b, (cx - 0.3 * esc, cx + 0.3 * esc), (y - 0.12, y), (cz + 0.4 * esc, cz + 0.4 * esc + e))
            bl(b, (cx - 0.3 * esc, cx + 0.3 * esc), (y - 0.12, y), (cz - 0.4 * esc - e, cz - 0.4 * esc))
            bl(b, (cx - e / 2, cx + e / 2), (y - 0.12, y), (cz - 0.4 * esc, cz + 0.4 * esc))

    # Pernas: pé largo, canela, joelheira, coxa
    for nome, sg in (("PernaD", -1), ("PernaE", 1)):
        x = sg * 1.55
        bl(m.g(nome, "PedraEscura"), (x - 1.35, x + 1.35), (-2.2, 1.6), (0.0, 0.9))  # pé
        bl(m.g(nome, "Pedra"), (x - 1.0, x + 1.0), (-1.0, 1.0), (0.9, 2.3))  # canela
        bl(m.g(nome, "PedraClara"), (x - 1.15, x + 1.15), (-1.15, 1.15), (2.3, 2.7))  # joelheira
        bl(m.g(nome, "Pedra"), (x - 1.2, x + 1.2), (-1.25, 1.25), (2.7, 3.9))  # coxa
        bl(m.g(nome, "PedraEscura"), (x - 1.3, x + 1.3), (-1.3, 1.3), (3.7, 3.9))
        bl(m.g(nome, "Brilho"), (x - 0.35, x + 0.35), (-1.12, -1.0), (1.3, 1.45))  # runa na canela
        bl(m.g(nome, "Brilho"), (x - 0.08, x + 0.08), (-1.12, -1.0), (1.05, 1.7))
        bl(m.g(nome, "Musgo"), (x - 1.0, x + 0.6), (-2.1, -0.6), (0.9, 1.25))  # musgo no pé
        m.pivo(nome, x, 0.0, 3.8)

    # Tronco enorme: pélvis, tórax em placas, ombros pesados, costas rachadas, runa no peito
    c = "Corpo"
    bl(m.g(c, "PedraEscura"), (-2.3, 2.3), (-1.6, 1.6), (3.8, 4.7))
    bl(m.g(c, "Pedra"), (-2.8, 2.8), (-2.0, 2.0), (4.7, 7.6))
    bl(m.g(c, "PedraClara"), (-2.6, 2.6), (-2.15, -2.0), (5.4, 7.0))  # placa do peito
    bl(m.g(c, "PedraEscura"), (-3.0, 3.0), (-1.7, 1.8), (7.0, 7.6))  # ombros
    bl(m.g(c, "PedraEscura"), (-2.9, 2.9), (-2.05, 2.05), (4.6, 4.9))  # cinto
    for x in (-1.6, 0.0, 1.6):
        bl(m.g(c, "Fenda"), (x - 0.04, x + 0.04), (-2.12, -2.05), (4.8, 5.3))  # fendas
    bl(m.g(c, "Pedra"), (-1.0, 1.0), (-2.3, -2.15), (5.6, 6.8))  # relevo central
    runa(c, 0.0, 6.2, -2.3, 1, 1.3)
    for sg in (-1, 1):
        bl(m.g(c, "Brilho"), (sg * 1.9 - 0.08, sg * 1.9 + 0.08), (-2.27, -2.15), (5.5, 6.9))
    bl(m.g(c, "Fenda"), (0.8, 0.9), (2.0, 2.1), (4.9, 7.4))  # rachaduras nas costas
    bl(m.g(c, "Fenda"), (0.9, 1.7), (2.0, 2.1), (6.0, 6.1))
    bl(m.g(c, "Brilho"), (-1.4, -0.4), (2.0, 2.12), (5.7, 5.85))
    bl(m.g(c, "Brilho"), (-0.9, -0.75), (2.0, 2.12), (5.7, 6.9))
    bl(m.g(c, "Musgo"), (-2.6, -0.8), (-1.8, 1.6), (7.6, 7.95))  # musgo nos ombros
    bl(m.g(c, "Musgo"), (1.2, 2.3), (-1.0, 1.8), (7.6, 7.85))
    bl(m.g(c, "Musgo"), (-2.8, -1.7), (1.9, 2.15), (4.9, 6.2))  # musgo nas costas
    m.pivo(c, 0, 0.0, 3.8)

    # Cabeça pequena e encaixada entre os ombros: testa pesada, olhos-fenda brilhantes, grade vertical no lugar da boca
    h = "Cabeca"
    bl(m.g(h, "Pedra"), (-1.25, 1.25), (-1.5, 1.1), (7.5, 9.4))
    bl(m.g(h, "PedraClara"), (-1.4, 1.4), (-1.65, 1.2), (8.9, 9.5))  # testa pesada
    bl(m.g(h, "PedraEscura"), (-0.9, 0.9), (-1.5, 0.9), (9.5, 9.85))  # crista
    bl(m.g(h, "PedraEscura"), (-1.35, 1.35), (-1.55, 1.15), (7.4, 7.8))  # queixo
    for sg in (-1, 1):
        bl(m.g(h, "Fenda"), (sg * 0.2, sg * 1.05), (-1.52, -1.48), (8.28, 8.62))  # órbita escura
        bl(m.g(h, "Brilho"), (sg * 0.3, sg * 0.95), (-1.56, -1.5), (8.36, 8.54))  # olho fenda
        bl(m.g(h, "PedraEscura"), (sg * 0.15, sg * 1.25), (-1.72, -1.5), (8.68, 9.0))  # sobrancelha
        bl(m.g(h, "Pedra"), (sg * 1.25, sg * 1.5), (-0.9, 0.7), (7.8, 9.1))  # lateral
    for x in (-0.6, -0.2, 0.2, 0.6):
        bl(m.g(h, "Fenda"), (x - 0.06, x + 0.06), (-1.58, -1.5), (7.55, 8.05))  # grade
    bl(m.g(h, "Brilho"), (-0.12, 0.12), (-1.72, -1.62), (9.2, 9.42))  # gema na testa
    bl(m.g(h, "Musgo"), (-0.8, 1.0), (-0.3, 1.0), (9.85, 10.0))
    m.pivo(h, 0, 0.0, 7.6)

    # Braços massivos: ombreira, braço, antebraço pesado com runas, punho grande
    for nome, sg, f1, f2 in (("BracoD", -1, 6, 34), ("BracoE", 1, 3, 22)):
        piv = (sg * 3.9, 0.0, 7.0)
        bl(m.g(nome, "PedraEscura"), (sg * 3.9 - 1.35, sg * 3.9 + 1.35), (-1.35, 1.35), (6.9, 8.2))  # ombreira
        bl(m.g(nome, "PedraClara"), (sg * 3.9 - 1.0, sg * 3.9 + 1.0), (-1.0, 1.0), (8.2, 8.45))
        for k in (-0.7, 0.0, 0.7):  # lascas de pedra eriçadas na ombreira
            bl(m.g(nome, "PedraEscura"), (sg * 3.9 + k - 0.18, sg * 3.9 + k + 0.18), (-0.4, 0.4), (8.45, 8.9 + 0.3 * abs(k)))
        cot, v1 = cadeia(m.g(nome, "Pedra"), piv, [(2.5, 2.0, f1, sg * 3, 2.0)])
        cubo(m.g(nome, "PedraClara"), cot, 2.3)
        punho, v2 = cadeia(m.g(nome, "Pedra"), cot, [(2.6, 2.3, f2, sg * 12, 2.3)])
        haste(m.g(nome, "Brilho"), cot + v2 * 0.7, cot + v2 * 1.8, 0.14, 2.35)  # faixa de runa no antebraço
        haste(m.g(nome, "PedraEscura"), cot + v2 * 0.3, cot + v2 * 0.55, 2.45, 2.45)
        cubo(m.g(nome, "PedraEscura"), punho + v2 * 0.2, (2.6, 2.7, 2.5))  # punho
        for k in (-0.8, 0.0, 0.8):
            cubo(m.g(nome, "Fenda"), punho + v2 * 0.2 + Vector((k, -1.35, 0.2)), (0.1, 0.1, 1.0))
        bl(m.g(nome, "Musgo"), (sg * 3.9 - 1.0, sg * 3.9 + 0.2), (0.0, 1.1), (8.45, 8.7))
        m.pivo(nome, piv[0], piv[1], piv[2])
    return m


GERADORES = {"goblin": goblin, "lobo": lobo, "urso": urso, "bandido": bandido, "rato": rato, "aranha": aranha,
             "treant": treant, "golem": golem}
