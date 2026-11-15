"""Roupas do jogo para o corpo R15 padrão (PERS1): camisa/calça CLÁSSICAS pintadas por script (molde 585 x 559) +
peças RÍGIDAS (MeshPart soldada a uma parte do R15) para o que precisa de volume: cinto, bolsa, canos de bota, capuz,
capa, chapéu, saia do manto.

Conjuntos: "aventureiro" (iniciante), "ladino" (Furtividade), "mago". Cada conjunto = {camisa, calca, pecas, cores}.
O molde é pintado em sRGB (0..1), linha 0 = TOPO da imagem (como o PNG que o Roblox recebe).
"""
import math

import bmesh
import bpy
from mathutils import Vector

import comum as C
import roblox_r15 as R

W, H = R.W_MOLDE, R.H_MOLDE


def _c(rgb):
    return tuple(x / 255.0 for x in rgb)


class Molde:
    def __init__(self, semente=1):
        import numpy as np
        self.np = np
        self.rng = np.random.default_rng(semente)
        self.Y, self.X = np.mgrid[0:H, 0:W].astype(np.float32)
        self.rgba = np.zeros((H, W, 4), dtype=np.float32)

    # ---------- coberturas (pixels) ----------
    def _rect(self, r):
        x, y, w, h = r
        np = self.np
        m = np.zeros((H, W), dtype=np.float32)
        m[y:y + h, x:x + w] = 1.0
        return m

    def _loc(self, r, u, v):
        x, y, w, h = r
        return x + u * w, y + v * h

    def traco(self, r, pts_uv, larg_px, suave=1.0):
        """Linha poligonal em coordenadas locais (u, v) da região; larg_px = largura em pixels (escalar ou lista)."""
        np = self.np
        pts = [self._loc(r, u, v) for u, v in pts_uv]
        ls = larg_px if isinstance(larg_px, (list, tuple)) else [larg_px] * len(pts)
        melhor = np.full((H, W), 1e9, dtype=np.float32)
        for (ax, ay), (bx, by), wa, wb in zip(pts[:-1], pts[1:], ls[:-1], ls[1:]):
            vx, vy = bx - ax, by - ay
            l2 = vx * vx + vy * vy + 1e-9
            t = np.clip(((self.X - ax) * vx + (self.Y - ay) * vy) / l2, 0, 1)
            d = np.sqrt((self.X - ax - t * vx) ** 2 + (self.Y - ay - t * vy) ** 2) - (wa + (wb - wa) * t) / 2
            melhor = np.minimum(melhor, d)
        return np.clip(0.5 - melhor / suave, 0, 1) * self._rect(r)

    def elipse(self, r, u, v, ru, rv):
        np = self.np
        cx, cy = self._loc(r, u, v)
        _, _, w, h = r
        d = np.sqrt(((self.X - cx) / (ru * w)) ** 2 + ((self.Y - cy) / (rv * h)) ** 2)
        return np.clip((1 - d) * min(ru * w, rv * h) + 0.5, 0, 1) * self._rect(r)

    def faixa(self, r, v0, v1, u0=0.0, u1=1.0):
        """Retângulo local (u0..u1, v0..v1) com borda suave de 1 px."""
        np = self.np
        x, y, w, h = r
        a = np.clip(self.X - (x + u0 * w) + 0.5, 0, 1) * np.clip((x + u1 * w) - self.X + 0.5, 0, 1)
        b = np.clip(self.Y - (y + v0 * h) + 0.5, 0, 1) * np.clip((y + v1 * h) - self.Y + 0.5, 0, 1)
        return a * b * self._rect(r)

    def poligono(self, r, pts_uv):
        """Polígono convexo ou não (regra par-ímpar), em u, v locais."""
        np = self.np
        pts = [self._loc(r, u, v) for u, v in pts_uv]
        dentro = np.zeros((H, W), dtype=bool)
        n = len(pts)
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            cond = ((y1 > self.Y) != (y2 > self.Y))
            xi = (x2 - x1) * (self.Y - y1) / ((y2 - y1) + 1e-9) + x1
            dentro ^= cond & (self.X < xi)
        return dentro.astype(np.float32) * self._rect(r)

    # ---------- tinta ----------
    def pintar(self, cob, cor, alfa=1.0):
        a = (cob * alfa)[..., None]
        c = self.np.array(_c(cor), dtype=self.np.float32)
        self.rgba[..., :3] = c * a + self.rgba[..., :3] * (1 - a)
        self.rgba[..., 3:] = a + self.rgba[..., 3:] * (1 - a)

    def multiplicar(self, cob, fator):
        """Escurece (fator < 1) ou clareia (> 1) o que já foi pintado, onde houver tinta."""
        k = 1 + (fator - 1) * cob[..., None]
        self.rgba[..., :3] = self.np.clip(self.rgba[..., :3] * k, 0, 1)

    def tecido(self, r, cor, v0=0.0, v1=1.0, u0=0.0, u1=1.0, grao=0.06, mancha=0.07, gradiente=0.16):
        """Pano: cor base + grão fino + manchas largas + degradê vertical (claro em cima)."""
        np = self.np
        cob = self.faixa(r, v0, v1, u0, u1)
        self.pintar(cob, cor)
        x, y, w, h = r
        fino = self.rng.normal(0, 1, (H, W)).astype(np.float32)
        largo = self.rng.normal(0, 1, (H // 8 + 2, W // 8 + 2)).astype(np.float32)
        largo = np.kron(largo, np.ones((8, 8), dtype=np.float32))[:H, :W]
        largo = (largo + np.roll(largo, 4, 0) + np.roll(largo, 4, 1) + np.roll(np.roll(largo, 4, 0), 4, 1)) / 4
        vv = np.clip((self.Y - (y + v0 * h)) / max(1.0, (v1 - v0) * h), 0, 1)
        k = 1 + grao * fino * 0.5 + mancha * largo * 0.5 + gradiente * (0.5 - vv)
        self.rgba[..., :3] = np.where(cob[..., None] > 0, np.clip(self.rgba[..., :3] * (1 + (k[..., None] - 1) * cob[..., None]), 0, 1),
                                      self.rgba[..., :3])

    def dobra(self, r, pts_uv, larg=6.0, forca=0.75):
        """Vinco: sombra suave + filete de luz ao lado (desenho de pano dobrado)."""
        sombra = self.traco(r, pts_uv, larg, suave=larg * 0.7)
        self.multiplicar(sombra, forca)
        luz = self.traco(r, [(u + 0.03, v - 0.01) for u, v in pts_uv], larg * 0.5, suave=larg * 0.5)
        self.multiplicar(luz * (1 - sombra), 1.12)

    def costura(self, r, pts_uv, cor, passo=6, larg=1.4, alfa=0.85):
        np = self.np
        cob = self.traco(r, pts_uv, larg, suave=0.8)
        tracejado = ((self.X + self.Y) % passo < passo * 0.55).astype(np.float32)
        self.pintar(cob * tracejado, cor, alfa)

    def borda(self, r, v0, v1, cor, u0=0.0, u1=1.0, linha=None):
        """Faixa de acabamento (barra, punho, cós) com filetes nas bordas."""
        self.tecido(r, cor, v0, v1, u0, u1, grao=0.04, mancha=0.03, gradiente=0.1)
        esc = tuple(int(c * 0.55) for c in cor)
        _, _, _, h = r
        e = 1.5 / h
        self.pintar(self.faixa(r, v0, v0 + e, u0, u1), linha or esc, 0.8)
        self.pintar(self.faixa(r, v1 - e, v1, u0, u1), linha or esc, 0.8)

    def ao_bordas(self, r, forca=0.82, largura=0.12, horizontal=True, vertical=False):
        """Oclusão pintada nas bordas da região (onde as peças se encostam)."""
        np = self.np
        x, y, w, h = r
        m = self._rect(r)
        k = np.zeros((H, W), dtype=np.float32)
        if vertical:
            du = np.minimum(self.X - x, x + w - self.X) / (w * largura)
            k = np.maximum(k, np.clip(1 - du, 0, 1))
        if horizontal:
            dv = np.minimum(self.Y - y, y + h - self.Y) / (h * largura)
            k = np.maximum(k, np.clip(1 - dv, 0, 1) * 0.6)
        self.multiplicar(k * m * (self.rgba[..., 3] > 0), forca)

    # ---------- saída ----------
    def imagem(self, nome):
        np = self.np
        lin = np.where(self.rgba[..., :3] <= 0.04045, self.rgba[..., :3] / 12.92, ((self.rgba[..., :3] + 0.055) / 1.055) ** 2.4)
        px = np.concatenate([lin, self.rgba[..., 3:]], axis=2)[::-1]
        img = bpy.data.images.new(nome, W, H, alpha=True, float_buffer=True)
        img.colorspace_settings.name = "Linear Rec.709"
        img.pixels.foreach_set(px.astype(np.float32).ravel())
        img.pack()
        return img

    def salvar(self, caminho):
        np = self.np
        img = bpy.data.images.new("_png", W, H, alpha=True)
        img.pixels.foreach_set(self.rgba[::-1].astype(np.float32).ravel())
        img.filepath_raw = caminho
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)


T, MD, ME = R.TRONCO, R.MEMBRO_D, R.MEMBRO_E
LADOS4 = ("F", "B", "R", "L")
# faixas de cada peça R15 na altura das regiões (fração de 0 = topo)
V_BRACO = (0.0, 1.10 / 2.55, 2.23 / 2.55, 1.0)  # UpperArm | LowerArm | Hand
V_PERNA = (0.0, 0.4, 0.85, 1.0)                  # UpperLeg | LowerLeg | Foot
V_TRONCO = (0.0, 0.8, 1.0)                       # UpperTorso | LowerTorso


def _membros():
    for regs in (MD, ME):
        for f in LADOS4:
            yield regs, f, regs[f]


# ====================================================================================== conjuntos: CAMISAS
def camisa_aventureiro(cores):
    m = Molde(11)
    linho, couro, alca = cores["camisa"], cores["colete"], cores["couro"]
    # mangas de linho arregaçadas até o meio do antebraço (o resto é pele: alfa 0)
    for regs, f, r in _membros():
        m.tecido(r, linho, 0.0, 0.62)
        m.borda(r, 0.56, 0.63, tuple(int(c * 0.9) for c in linho))  # dobra da manga arregaçada
        m.dobra(r, [(0.1, 0.36), (0.5, 0.40), (0.9, 0.35)], 5, 0.8)
        m.dobra(r, [(0.15, 0.47), (0.6, 0.5), (0.95, 0.46)], 4, 0.82)
        m.dobra(r, [(0.2, 0.12), (0.7, 0.16)], 4, 0.88)
    for regs in (MD, ME):
        m.tecido(regs["U"], linho)
    # tronco: túnica de linho + colete de couro aberto na frente com cordão
    for f in LADOS4 + ("U",):
        m.tecido(T[f], linho)
    for f in ("B", "R", "L", "U"):
        m.tecido(T[f], couro, 0.0, 0.8 if f != "U" else 1.0, grao=0.05, mancha=0.12)
    F = T["F"]
    for u0, u1 in ((0.0, 0.36), (0.64, 1.0)):
        m.tecido(F, couro, 0.0, 0.8, u0, u1, grao=0.05, mancha=0.12)
    m.costura(F, [(0.33, 0.02), (0.33, 0.78)], (220, 196, 150))
    m.costura(F, [(0.67, 0.02), (0.67, 0.78)], (220, 196, 150))
    m.pintar(m.traco(F, [(0.36, 0.0), (0.36, 0.8)], 2.2), tuple(int(c * 0.5) for c in couro))
    m.pintar(m.traco(F, [(0.64, 0.0), (0.64, 0.8)], 2.2), tuple(int(c * 0.5) for c in couro))
    # decote em V com cordão cruzado
    m.pintar(m.poligono(F, [(0.42, 0.0), (0.58, 0.0), (0.5, 0.22)]), cores["pele"])
    m.multiplicar(m.traco(F, [(0.42, 0.0), (0.5, 0.22), (0.58, 0.0)], 3, 2), 0.75)
    for i in range(4):
        v = 0.06 + i * 0.05
        m.pintar(m.traco(F, [(0.44, v), (0.56, v + 0.04)], 1.6), (90, 64, 40))
        m.pintar(m.traco(F, [(0.56, v), (0.44, v + 0.04)], 1.6), (90, 64, 40))
    # alça da bolsa em diagonal (ombro direito -> quadril esquerdo), com costura
    m.pintar(m.traco(F, [(0.08, 0.0), (0.95, 0.78)], 14), alca)
    m.costura(F, [(0.1, 0.02), (0.95, 0.76)], (205, 170, 120), passo=5)
    m.multiplicar(m.traco(F, [(0.14, 0.0), (1.0, 0.77)], 3, 3), 0.7)
    m.pintar(m.traco(T["B"], [(0.92, 0.0), (0.05, 0.78)], 14), alca)
    # vincos do linho na cintura e barra da túnica (LowerTorso)
    for f in LADOS4:
        m.dobra(T[f], [(0.2, 0.84), (0.25, 0.98)], 4, 0.8)
        m.dobra(T[f], [(0.55, 0.83), (0.5, 0.98)], 4, 0.8)
        m.dobra(T[f], [(0.85, 0.84), (0.8, 0.98)], 4, 0.82)
        m.ao_bordas(T[f], 0.85, 0.08)
    for f in ("F", "B"):
        m.dobra(T[f], [(0.12, 0.45), (0.25, 0.7)], 5, 0.85)
        m.dobra(T[f], [(0.88, 0.45), (0.75, 0.7)], 5, 0.85)
    return m


def calca_aventureiro(cores):
    m = Molde(12)
    calca, bota = cores["calca"], cores["bota"]
    for regs, f, r in _membros():
        m.tecido(r, calca, 0.0, 0.6)
        m.tecido(r, bota, 0.6, 1.0, grao=0.04, mancha=0.1)
        m.borda(r, 0.58, 0.66, tuple(int(c * 1.15) for c in bota))  # cano dobrado da bota
        m.dobra(r, [(0.1, 0.36), (0.5, 0.42), (0.9, 0.37)], 5, 0.78)  # joelho
        m.dobra(r, [(0.2, 0.5), (0.8, 0.54)], 4, 0.8)
        m.dobra(r, [(0.3, 0.1), (0.4, 0.3)], 4, 0.86)
        if f == "F":
            # remendo no joelho e cadarço da bota
            m.pintar(m.faixa(r, 0.3, 0.44, 0.22, 0.78), tuple(int(c * 1.12) for c in calca))
            m.costura(r, [(0.22, 0.3), (0.78, 0.3), (0.78, 0.44), (0.22, 0.44), (0.22, 0.3)], (60, 44, 30), passo=4)
            for i in range(3):
                v = 0.69 + i * 0.045
                m.pintar(m.traco(r, [(0.35, v), (0.65, v + 0.025)], 1.6), (178, 150, 110))
                m.pintar(m.traco(r, [(0.65, v), (0.35, v + 0.025)], 1.6), (178, 150, 110))
        m.pintar(m.faixa(r, 0.96, 1.0), (36, 28, 22))  # sola
        m.ao_bordas(r, 0.86, 0.06)
    for regs in (MD, ME):
        m.tecido(regs["D"], (36, 28, 22))
        m.tecido(regs["U"], calca)
    for f in LADOS4:
        m.tecido(T[f], calca, 0.78, 1.0)
    return m


def camisa_ladino(cores):
    m = Molde(21)
    gibao, sub, faixa = cores["camisa"], cores["colete"], cores["couro"]
    for regs, f, r in _membros():
        m.tecido(r, sub, 0.0, 0.9)
        # faixas de couro enroladas no antebraço (luva sem dedos na mão)
        for i in range(5):
            v = 0.48 + i * 0.075
            m.pintar(m.traco(r, [(0.0, v), (1.0, v + 0.05)], 7), faixa)
            m.multiplicar(m.traco(r, [(0.0, v + 0.03), (1.0, v + 0.08)], 1.5, 1), 0.6)
        m.tecido(r, faixa, 0.875, 0.94, grao=0.04)
        m.dobra(r, [(0.1, 0.18), (0.5, 0.23), (0.9, 0.18)], 4, 0.8)
        m.dobra(r, [(0.15, 0.34), (0.6, 0.39), (0.95, 0.35)], 5, 0.78)
        m.ao_bordas(r, 0.85, 0.06)
    for regs in (MD, ME):
        m.tecido(regs["U"], sub)
    for f in LADOS4 + ("U",):
        m.tecido(T[f], gibao, grao=0.05, mancha=0.12)
    F = T["F"]
    # aba trespassada (fecho na diagonal) com três tiras afiveladas
    m.multiplicar(m.traco(F, [(0.62, 0.0), (0.4, 0.8)], 4, 3), 0.55)
    m.costura(F, [(0.58, 0.0), (0.36, 0.8)], (120, 120, 120), passo=5)
    for i, v in enumerate((0.18, 0.4, 0.62)):
        u = 0.6 - v * 0.27
        m.pintar(m.faixa(F, v, v + 0.06, u - 0.16, u + 0.16), faixa)
        m.pintar(m.faixa(F, v - 0.005, v + 0.065, u + 0.02, u + 0.08), (170, 160, 140))
        m.pintar(m.faixa(F, v + 0.012, v + 0.048, u + 0.035, u + 0.065), faixa)
    # gola alta
    for f in LADOS4:
        m.borda(T[f], 0.0, 0.07, tuple(int(c * 0.8) for c in gibao))
        m.costura(T[f], [(0.0, 0.76), (1.0, 0.76)], (110, 110, 110))
        m.dobra(T[f], [(0.2, 0.84), (0.3, 0.98)], 4, 0.8)
        m.dobra(T[f], [(0.75, 0.84), (0.7, 0.98)], 4, 0.8)
        m.ao_bordas(T[f], 0.85, 0.08)
    m.costura(T["B"], [(0.5, 0.08), (0.5, 0.76)], (110, 110, 110))
    m.dobra(T["B"], [(0.15, 0.3), (0.35, 0.55)], 5, 0.85)
    m.dobra(T["B"], [(0.85, 0.3), (0.65, 0.55)], 5, 0.85)
    return m


def calca_ladino(cores):
    m = Molde(22)
    calca, bota, tira = cores["calca"], cores["bota"], cores["couro"]
    for regs, f, r in _membros():
        m.tecido(r, calca, 0.0, 0.5)
        m.tecido(r, bota, 0.5, 1.0, grao=0.04, mancha=0.08)
        for i in range(3):  # tiras da bota macia
            v = 0.56 + i * 0.1
            m.pintar(m.traco(r, [(0.0, v), (1.0, v + 0.04)], 5), tira)
        m.pintar(m.faixa(r, 0.12, 0.17), tira)  # correia da coxa
        m.dobra(r, [(0.1, 0.32), (0.5, 0.38), (0.9, 0.33)], 5, 0.78)
        m.dobra(r, [(0.3, 0.05), (0.45, 0.28)], 4, 0.85)
        m.pintar(m.faixa(r, 0.96, 1.0), (28, 24, 22))
        m.ao_bordas(r, 0.86, 0.06)
        if f == "R" and regs is MD:
            m.pintar(m.faixa(r, 0.17, 0.3, 0.2, 0.8), tira)  # bolsinha na coxa
            m.costura(r, [(0.2, 0.2), (0.8, 0.2)], (150, 140, 120), passo=4)
    for regs in (MD, ME):
        m.tecido(regs["D"], (28, 24, 22))
        m.tecido(regs["U"], calca)
    for f in LADOS4:
        m.tecido(T[f], calca, 0.78, 1.0)
    return m


def camisa_mago(cores):
    m = Molde(31)
    manto, ouro, forro = cores["camisa"], cores["ouro"], cores["colete"]
    for regs, f, r in _membros():
        m.tecido(r, manto, 0.0, 0.875)
        m.borda(r, 0.78, 0.875, ouro)
        for i in range(4):
            u = 0.12 + i * 0.25
            m.pintar(m.elipse(r, u, 0.826, 0.06, 0.018), tuple(int(c * 0.6) for c in ouro))
        m.dobra(r, [(0.2, 0.15), (0.3, 0.4)], 5, 0.82)
        m.dobra(r, [(0.7, 0.25), (0.75, 0.6)], 5, 0.8)
        m.dobra(r, [(0.1, 0.5), (0.5, 0.55), (0.9, 0.5)], 5, 0.8)
        m.ao_bordas(r, 0.85, 0.05)
    for regs in (MD, ME):
        m.tecido(regs["U"], manto)
    for f in LADOS4 + ("U",):
        m.tecido(T[f], manto)
    F = T["F"]
    # gola em V dourada e faixa central bordada
    m.pintar(m.poligono(F, [(0.3, 0.0), (0.7, 0.0), (0.5, 0.34)]), forro)
    m.pintar(m.traco(F, [(0.28, 0.0), (0.5, 0.36), (0.72, 0.0)], 9), ouro)
    m.pintar(m.faixa(F, 0.34, 1.0, 0.43, 0.57), ouro)
    m.multiplicar(m.faixa(F, 0.34, 1.0, 0.43, 0.445) + m.faixa(F, 0.34, 1.0, 0.555, 0.57), 0.6)
    for i in range(6):  # losangos bordados (runas)
        v = 0.42 + i * 0.1
        m.pintar(m.poligono(F, [(0.5, v - 0.035), (0.535, v), (0.5, v + 0.035), (0.465, v)]), tuple(int(c * 0.45) for c in manto))
    for f in ("F", "B"):
        m.dobra(T[f], [(0.15, 0.4), (0.2, 0.75)], 6, 0.82)
        m.dobra(T[f], [(0.85, 0.4), (0.8, 0.75)], 6, 0.82)
    m.pintar(m.traco(T["B"], [(0.2, 0.0), (0.5, 0.12), (0.8, 0.0)], 7), ouro)
    for f in LADOS4:
        m.ao_bordas(T[f], 0.85, 0.06)
    return m


def calca_mago(cores):
    m = Molde(32)
    calca, sapato = cores["calca"], cores["bota"]
    for regs, f, r in _membros():
        m.tecido(r, calca, 0.0, 0.85)
        m.tecido(r, sapato, 0.85, 1.0, grao=0.03)
        m.dobra(r, [(0.2, 0.4), (0.8, 0.45)], 5, 0.8)
        m.ao_bordas(r, 0.86, 0.06)
    for regs in (MD, ME):
        m.tecido(regs["D"], (30, 26, 24))
        m.tecido(regs["U"], calca)
    for f in LADOS4:
        m.tecido(T[f], calca, 0.78, 1.0)
    return m


# ====================================================================================== peças rígidas
def _bm():
    return bmesh.new()


def cinto(b, z=2.2, peca="cinto", bolsa=True):
    bm = _bm()
    C.aro(bm, (0, 0, z), 1.035, 0.535, 0.035, 0.1, n=28, expo_caminho=10, expo=6, lados=5)
    b.add("LowerTorso", "couro", bm, peca, suave=True)
    f = _bm()
    C.caixa(f, (0.0, -0.575, z), (0.24, 0.05, 0.2))
    bmesh.ops.bevel(f, geom=list(f.edges), offset=0.015, segments=1, affect="EDGES")
    b.add("LowerTorso", "metal", f, peca, suave=False)
    if bolsa:
        p = _bm()
        C.caixa(p, (0.72, -0.5, z - 0.17), (0.34, 0.2, 0.36))
        bmesh.ops.bevel(p, geom=list(p.edges), offset=0.05, segments=2, affect="EDGES")
        C.caixa(p, (0.72, -0.6, z - 0.06), (0.36, 0.06, 0.18))  # aba
        b.add("LowerTorso", "couro_escuro", p, peca, suave=False)


def canos_bota(b, z, cor="bota", hx=0.535, peca="botas", altura=0.09):
    for L in ("Right", "Left"):
        x = C.LADO_X[L] * 0.5
        bm = _bm()
        C.aro(bm, (x, 0, z), hx, hx, 0.04, altura, n=32, expo_caminho=10, expo=6, lados=6)
        b.add(L + "LowerLeg", cor, bm, peca, suave=True)


def bolsa_lateral(b):
    bm = _bm()
    C.caixa(bm, (-1.08, 0.05, 2.05), (0.18, 0.5, 0.42))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.06, segments=2, affect="EDGES")
    C.caixa(bm, (-1.12, 0.05, 2.2), (0.12, 0.52, 0.16))
    b.add("LowerTorso", "couro", bm, "bolsa", suave=False)


def capuz(b):
    """Capuz (Head): casca sobre a cabeça com abertura do rosto e ponta caída nas costas."""
    S = R.cabeca_se()

    def filtro(az, el):
        if el < -62:
            return False
        if abs(az) < 58 and -70 < el < 46:
            return False
        return True

    def deform(p):
        az, el = R._azel(p)
        q = Vector(p)
        if abs(az) > 120 and el > -10:
            q.y += 0.32 * max(0, (el + 10) / 80) ** 1.5 * min(1, (abs(az) - 120) / 50)
            q.z -= 0.08 * max(0, (el + 10) / 80)
        if el < -30:
            k = (-30 - el) / 40
            q.x *= 1 + 0.25 * k
            q.y = q.y * (1 + 0.15 * k) + 0.05 * k
        return q
    bm = _bm()
    C.elipsoide(bm, (0, 0, 4.6), (1, 1, 1), seg=28, aneis=16, filtro=filtro,
                deform=lambda p: deform(S(*R._azel(p), 1.13)))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm = C.solidificar(bm, 0.06)
    b.add("Head", "capuz", bm, "capuz", suave=True)


def capelete(b, cor="capuz", peca="capelete"):
    """Capinha sobre os ombros (UpperTorso), aberta na frente em V raso."""
    bm = _bm()
    sec = [(Vector((0, 0.02, 4.12)), 0.52, 0.42), (Vector((0, 0.02, 4.0)), 0.86, 0.6),
           (Vector((0, 0.02, 3.8)), 1.08, 0.64), (Vector((0, 0.04, 3.5)), 1.13, 0.67)]
    C.tubo_espesso(bm, sec, 0.05, up=(0, -1, 0), lados=28, expo=3.2)
    b.add("UpperTorso", cor, bm, peca, suave=True)


def capa(b, cor="capa", comprimento=2.75, largura=1.05, peca="capa"):
    linhas = []
    nl, nc = 9, 9
    for i in range(nl):
        t = i / (nl - 1)
        z = 3.98 - t * comprimento
        lw = largura + 0.28 * t
        lin = []
        for j in range(nc):
            s = -1 + 2 * j / (nc - 1)
            x = s * lw
            onda = 0.05 * math.sin(s * math.pi * 2.5 + 0.6) * t
            y = 0.56 + 0.12 * t + 0.1 * s * s * (0.4 + t) + onda
            if t < 0.12:
                y = 0.5 + 0.06 * s * s  # presa nos ombros
            lin.append((x, y, z))
        linhas.append(lin)
    bm = _bm()
    C.placa(bm, linhas, 0.05)
    b.add("UpperTorso", cor, bm, peca, suave=True)
    # fecho: duas presilhas nos ombros
    f = _bm()
    for s in (-1, 1):
        C.caixa(f, (s * 0.72, -0.05, 3.98), (0.2, 1.1, 0.06))
    b.add("UpperTorso", "couro", f, peca, suave=False)


def mascara(b):
    """Lenço sobre nariz e boca (Head)."""
    S = R.cabeca_se()
    bm = _bm()
    C.elipsoide(bm, (0, 0, 4.6), (1, 1, 1), seg=28, aneis=16,
                filtro=lambda az, el: -64 < el < -8 and abs(az) < 110 or (-64 < el < -8 and abs(az) >= 110),
                deform=lambda p: S(*R._azel(p), 1.05))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm = C.solidificar(bm, 0.04)
    b.add("Head", "mascara", bm, "mascara", suave=True)


def adaga_cinto(b):
    bm = _bm()
    C.caixa(bm, (0.55, 0.62, 2.0), (0.14, 0.08, 0.6))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.025, segments=1, affect="EDGES")
    b.add("LowerTorso", "couro_escuro", bm, "adaga", suave=False)
    m = _bm()
    C.sweep(m, [(Vector((0.55, 0.62, 2.32)), 0.035, 0.035), (Vector((0.55, 0.62, 2.55)), 0.035, 0.035)], lados=6)
    C.caixa(m, (0.55, 0.62, 2.31), (0.26, 0.06, 0.05))
    b.add("LowerTorso", "metal", m, "adaga", suave=False)


def chapeu_mago(b):
    bm = _bm()
    # aba larga e um pouco caída
    sec = [(Vector((0, 0.02, 5.06)), 1.24, 1.18), (Vector((0, 0.02, 5.14)), 1.02, 0.97), (Vector((0, 0.0, 5.22)), 0.8, 0.78)]
    C.tubo_espesso(bm, sec, 0.04, up=(0, -1, 0), lados=32, expo=2.2)
    copa = [(Vector((0, 0.0, 5.16)), 0.78, 0.76), (Vector((0, 0.04, 5.62)), 0.56, 0.54), (Vector((0, 0.16, 6.0)), 0.36, 0.35),
            (Vector((0, 0.38, 6.34)), 0.2, 0.19), (Vector((0, 0.7, 6.46)), 0.09, 0.09), (Vector((0, 0.9, 6.34)), 0.0, 0.0)]
    C.sweep(bm, copa, up=(0, -1, 0), lados=20, expo=2.2)
    b.add("Head", "chapeu", bm, "chapeu", suave=True)
    f = _bm()
    C.aro(f, (0, 0.0, 5.26), 0.77, 0.75, 0.025, 0.07, n=32, expo_caminho=2.2, expo=4, lados=6)
    b.add("Head", "ouro", f, "chapeu", suave=True)


def saia_manto(b):
    bm = _bm()
    sec = [(Vector((0, 0, 2.42)), 1.04, 0.54), (Vector((0, 0.0, 2.0)), 1.1, 0.62), (Vector((0, 0.02, 1.2)), 1.22, 0.76),
           (Vector((0, 0.03, 0.55)), 1.3, 0.84)]
    C.tubo_espesso(bm, sec, 0.05, up=(0, -1, 0), lados=28, expo=3.0)
    b.add("LowerTorso", "camisa", bm, "saia_manto", suave=True)
    f = _bm()
    C.aro(f, (0, 0.03, 0.62), 1.3, 0.84, 0.03, 0.07, n=28, expo_caminho=3.0, expo=4, lados=5)
    b.add("LowerTorso", "ouro", f, "saia_manto", suave=True)
    s = _bm()
    C.aro(s, (0, 0, 2.25), 1.07, 0.57, 0.04, 0.12, n=28, expo_caminho=8, expo=5, lados=5)
    C.sweep(s, [(Vector((-0.45, -0.62, 2.18)), 0.1, 0.025), (Vector((-0.5, -0.68, 1.7)), 0.09, 0.025),
                (Vector((-0.52, -0.72, 1.3)), 0.11, 0.025)], up=(0, -1, 0), lados=6, expo=4)
    b.add("LowerTorso", "faixa", s, "saia_manto", suave=True)


def mangas_sino(b):
    for L in ("Right", "Left"):
        x = C.LADO_X[L] * 1.5
        bm = _bm()
        sec = [(Vector((x, 0, 2.35)), 0.53, 0.53), (Vector((x, 0, 2.0)), 0.58, 0.58), (Vector((x, 0.03, 1.66)), 0.7, 0.7)]
        C.tubo_espesso(bm, sec, 0.04, up=(0, -1, 0), lados=24, expo=4)
        b.add(L + "LowerArm", "camisa", bm, "mangas", suave=True)
        f = _bm()
        C.aro(f, (x, 0.03, 1.69), 0.7, 0.7, 0.03, 0.05, n=32, expo_caminho=4, expo=4, lados=6)
        b.add(L + "LowerArm", "ouro", f, "mangas", suave=True)


def cajado(b, pose, pos, rot_z):
    """Cajado na mão direita (apresentação; arma não conta no orçamento do corpo)."""
    import math as _m
    from mathutils import Matrix
    rig = b.rig
    D = C.deltas(rig, pose)
    sw, sd, sh = b.escala
    G = Matrix.Rotation(_m.radians(rot_z), 4, "Z") @ Matrix.Diagonal((sw, sd, sh, 1))
    mao = rig["mao_centro"]["Right"]
    bm = _bm()
    C.sweep(bm, [(mao + Vector((0, 0.0, -1.3)), 0.06, 0.06), (mao + Vector((0, 0, 1.2)), 0.075, 0.075),
                 (mao + Vector((0, -0.1, 1.55)), 0.11, 0.11), (mao + Vector((0, 0.05, 1.8)), 0.06, 0.06)],
            up=(0, -1, 0), lados=8)
    cr = _bm()
    c = mao + Vector((0, -0.02, 1.72))
    bmesh.ops.create_icosphere(cr, subdivisions=1, radius=0.17, matrix=Matrix.Translation(c) @ Matrix.Diagonal((0.8, 0.8, 1.5, 1)))
    o1 = C.objetos_avulsos(bm, "cajado", (96, 66, 42), "madeira", suave=True, matriz=G @ D["RightHand"])
    o2 = C.objetos_avulsos(cr, "cristal", (120, 200, 255), "olho_brilho", suave=False, matriz=G @ D["RightHand"])
    bm.free()
    cr.free()
    return [o1, o2]


# ====================================================================================== conjuntos
CORES_BASE = {"metal": (176, 168, 150), "couro_escuro": (66, 46, 32), "ouro": (204, 168, 84), "faixa": (150, 40, 44)}

CONJUNTOS = {
    "aventureiro": {
        "nome": "Aventureiro iniciante",
        "cores": {"camisa": (222, 206, 168), "colete": (122, 80, 48), "couro": (92, 62, 40), "calca": (92, 84, 62),
                  "bota": (74, 50, 34)},
        "camisa": camisa_aventureiro, "calca": calca_aventureiro,
        "pecas": [lambda b: cinto(b, z=2.22), lambda b: canos_bota(b, 0.63, "bota"), bolsa_lateral],
        "arma": "espada",
    },
    "ladino": {
        "nome": "Ladino (Furtividade)",
        "cores": {"camisa": (52, 54, 58), "colete": (64, 72, 64), "couro": (70, 52, 40), "calca": (44, 44, 50),
                  "bota": (56, 44, 38), "capuz": (58, 66, 60), "mascara": (40, 42, 46)},
        "camisa": camisa_ladino, "calca": calca_ladino,
        "pecas": [capuz, capelete, mascara, lambda b: cinto(b, z=2.22, bolsa=False), adaga_cinto,
                  lambda b: canos_bota(b, 0.9, "bota", altura=0.06)],
        "arma": "espada",
    },
    "mago": {
        "nome": "Mago",
        "cores": {"camisa": (52, 66, 128), "colete": (150, 36, 46), "calca": (44, 46, 66), "bota": (84, 56, 38),
                  "chapeu": (46, 58, 112), "couro": (92, 62, 40)},
        "camisa": camisa_mago, "calca": calca_mago,
        "pecas": [chapeu_mago, saia_manto, mangas_sino],
        "arma": "cajado",
    },
}
