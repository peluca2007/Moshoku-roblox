"""Kit de arte da interface (roda dentro do Blender, sem janela): molduras, botões, barras, aro e
espaço de equipamento em PNG transparente, desenhados por campos de distância em numpy (nítidos e
no tamanho certo para 9-slice no Roblox). Estilo "Pergaminho" (escolhido pelo Pedro em 14/11/2026 na
prancha de tools/blender/ui_estilos.py): papel envelhecido, tinta marrom e botão principal de lacre vermelho.

Uso:  python tools/blender_rodar.py tools/blender/ui_kit.py [--saida build/ui] [--escala 2]
Saída: <saida>/<nome>.png e <saida>/ui_kit.json (tamanho e SliceCenter de cada peça, em pixels
do PNG). O upload e os ids ficam em shared/UIArte (tools/ui_kit_upload.py).
"""
import json
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from lib import argumentos  # noqa: E402

OURO = np.array([201, 164, 92]) / 255
OURO_CLARO = np.array([246, 222, 158]) / 255
OURO_ESCURO = np.array([96, 70, 32]) / 255
PAPEL = np.array([226, 206, 164]) / 255
PAPEL_QUEIMADO = np.array([120, 82, 44]) / 255
TINTA = np.array([92, 60, 34]) / 255
LACRE = np.array([150, 40, 34]) / 255
LUZ = np.array([-0.45, -0.65, 0.62])  # de cima à esquerda (y cresce para baixo)
LUZ = LUZ / np.linalg.norm(LUZ)


# ------------------------------------------------------------------ utilidades

def grade(l, a):
    y, x = np.mgrid[0:a, 0:l].astype(np.float64)
    return x + 0.5, y + 0.5


def ret_arred(x, y, cx, cy, mx, my, r):
    """Distância com sinal a um retângulo arredondado (negativa dentro)."""
    qx = np.abs(x - cx) - (mx - r)
    qy = np.abs(y - cy) - (my - r)
    fora = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    dentro = np.minimum(np.maximum(qx, qy), 0)
    return fora + dentro - r


def losango(x, y, cx, cy, r):
    return (np.abs(x - cx) + np.abs(y - cy)) / np.sqrt(2) - r / np.sqrt(2)


def cobertura(d, suave=1.0):
    """Alfa antisserrilhado a partir da distância (1 dentro, 0 fora)."""
    return np.clip(0.5 - d / suave, 0, 1)


def borrar(a, raio):
    """Desfoque de caixa separável (duas passadas ≈ gaussiano)."""
    if raio <= 0:
        return a
    k = 2 * raio + 1
    for _ in range(2):
        for eixo in (0, 1):
            p = np.pad(a, [(raio, raio) if i == eixo else (0, 0) for i in range(a.ndim)], mode="edge")
            c = np.cumsum(p, axis=eixo)
            c = np.concatenate([np.zeros_like(np.take(c, [0], axis=eixo)), c], axis=eixo)
            n = a.shape[eixo]
            a = (np.take(c, range(k, k + n), axis=eixo) - np.take(c, range(0, n), axis=eixo)) / k
    return a


def ruido(l, a, semente, raio):
    rng = np.random.default_rng(semente)
    r = borrar(rng.standard_normal((a, l)), raio)
    return r / (np.abs(r).max() + 1e-9)


def relevo(altura, forca=1.0):
    """Sombreamento difuso + brilho especular de um mapa de altura (0..1)."""
    gy, gx = np.gradient(altura * forca)
    n = np.stack([-gx, -gy, np.ones_like(gx)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    difuso = np.clip((n * LUZ).sum(-1), 0, 1)
    meio = LUZ + np.array([0, 0, 1.0])
    meio /= np.linalg.norm(meio)
    especular = np.clip((n * meio).sum(-1), 0, 1) ** 40
    return difuso, especular


def metal(altura, forca, base=OURO, claro=OURO_CLARO, escuro=OURO_ESCURO):
    """Rampa escuro → base → claro pela luz, mais reflexo largo e brilho estreito (ouro polido)."""
    gy, gx = np.gradient(altura * forca)
    n = np.stack([-gx, -gy, np.ones_like(gx)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    difuso = np.clip((n * LUZ).sum(-1), 0, 1)
    meio = LUZ + np.array([0, 0, 1.0])
    meio /= np.linalg.norm(meio)
    ndh = np.clip((n * meio).sum(-1), 0, 1)
    v = np.clip((difuso - 0.25) / 0.6, 0, 1)[..., None]
    cor = np.where(v < 0.5, escuro + (base - escuro) * (v * 2), base + (claro - base) * ((v - 0.5) * 2) * 0.6)
    cor = cor + (claro - cor) * (ndh ** 12 * 0.35 + ndh ** 80 * 0.9)[..., None]
    return np.clip(cor, 0, 1)


class Tela:
    def __init__(self, l, a):
        self.l, self.a = l, a
        self.rgb = np.zeros((a, l, 3))
        self.alfa = np.zeros((a, l))

    def pintar(self, cor, alfa):
        """Compõe por cima (operador over). `cor` (a,l,3) ou (3,), `alfa` (a,l)."""
        cor = np.broadcast_to(cor, (self.a, self.l, 3))
        a = np.clip(alfa, 0, 1)
        saida = a + self.alfa * (1 - a)
        rgb = (cor * a[..., None] + self.rgb * (self.alfa * (1 - a))[..., None])
        self.rgb = np.where(saida[..., None] > 1e-6, rgb / np.maximum(saida, 1e-6)[..., None], 0)
        self.alfa = saida

    def salvar(self, caminho):
        img = bpy.data.images.new(os.path.basename(caminho), self.l, self.a, alpha=True)
        px = np.dstack([self.rgb, self.alfa])[::-1].astype(np.float32)  # Blender guarda de baixo para cima
        img.pixels.foreach_set(px.ravel())
        img.filepath_raw = caminho
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)


# ------------------------------------------------------------------ peças

def moldura(t, x, y, d_borda, largura, forca, sombra_interna=True):
    """Faixa de ouro em relevo ao longo da borda de `d_borda` (distância ao contorno externo)."""
    meio = -largura / 2
    banda = np.abs(d_borda - meio) - largura / 2
    perfil = np.clip(1 - (np.abs(d_borda - meio) / (largura / 2)) ** 2, 0, 1)
    sulco = np.exp(-((d_borda - meio) ** 2) / (2 * (largura * 0.09) ** 2))
    altura = np.sqrt(perfil) - 0.35 * sulco
    t.pintar(metal(altura, forca), cobertura(banda))
    if sombra_interna:
        interno = d_borda + largura  # < 0 dentro da faixa
        t.pintar(np.zeros(3), cobertura(interno, 1.0) * np.exp(np.minimum(interno, 0) / (largura * 0.9)) * 0.55)


def papel(t, x, y, d, semente, esc, base=PAPEL, queima=0.35):
    """Papel envelhecido: grão fino, manchas largas e bordas escurecidas."""
    cor = base + ruido(t.l, t.a, semente, max(1, int(1.5 * esc)))[..., None] * 0.035
    cor = cor + ruido(t.l, t.a, semente + 1, 10 * esc)[..., None] * 0.055
    borda = np.exp(np.minimum(d, 0) / (7 * esc))[..., None]
    cor = cor * (1 - borda * queima) + PAPEL_QUEIMADO * borda * queima
    t.pintar(np.clip(cor, 0, 1), cobertura(d))


def filete(t, d, recuo, largura, alfa=0.85, cor=TINTA):
    """Linha de tinta paralela à borda, `recuo` px para dentro."""
    t.pintar(cor, cobertura(np.abs(d + recuo) - largura) * alfa)


def florao(t, x, y, cx, cy, r, cor=TINTA):
    """Pequeno losango de tinta (ornamento de canto e de divisor)."""
    t.pintar(cor, cobertura(losango(x, y, cx, cy, r)) * 0.9)


def painel(esc):
    L = 256 * esc
    t = Tela(L, L)
    x, y = grade(L, L)
    m, r, banda = 6 * esc, 7 * esc, 9 * esc
    d = ret_arred(x, y, L / 2, L / 2, L / 2 - m, L / 2 - m, r)
    t.pintar(np.zeros(3), cobertura(ret_arred(x, y, L / 2, L / 2 + 2 * esc, L / 2 - m + 2 * esc, L / 2 - m + 2 * esc, r), 6 * esc) * 0.5)
    papel(t, x, y, d, 11, esc)
    t.pintar(TINTA, cobertura(np.abs(d) - 0.6 * esc) * 0.7)
    filete(t, d, banda, 0.75 * esc)
    filete(t, d, banda + 3.5 * esc, 0.35 * esc, alfa=0.45)
    for cx in (m + banda, L - m - banda):
        for cy in (m + banda, L - m - banda):
            t.pintar(PAPEL * 0.97, cobertura(losango(x, y, cx, cy, 6.5 * esc)))
            florao(t, x, y, cx, cy, 4.5 * esc, cor=LACRE * 0.8)
    corte = (m + banda + 22 * esc)
    return t, {"tamanho": [L, L], "corte": [corte, corte, L - corte, L - corte]}


def botao(esc, principal=False, ativo=False):
    Lx, Ly = 256 * esc, 88 * esc
    t = Tela(Lx, Ly)
    x, y = grade(Lx, Ly)
    m, r, banda = 4 * esc, 7 * esc, 4 * esc
    d = ret_arred(x, y, Lx / 2, Ly / 2, Lx / 2 - m, Ly / 2 - m, r)
    t.pintar(np.zeros(3), cobertura(ret_arred(x, y, Lx / 2, Ly / 2 + 2 * esc, Lx / 2 - m, Ly / 2 - m, r), 4 * esc) * 0.4)
    if principal:
        # Lacre de cera vermelha: almofada com brilho e filete claro.
        almofada = np.clip(-d / (9 * esc), 0, 1) ** 0.7
        cor = metal(almofada, 3.2 * esc, base=LACRE, claro=np.array([226, 120, 98]) / 255, escuro=np.array([72, 16, 14]) / 255)
        cor = cor + ruido(Lx, Ly, 5, 2 * esc)[..., None] * 0.02
        t.pintar(np.clip(cor, 0, 1), cobertura(d))
        t.pintar(np.array([70, 14, 12]) / 255, cobertura(np.abs(d) - 0.7 * esc) * 0.9)
        filete(t, d, 5 * esc, 0.4 * esc, alfa=0.35, cor=np.array([250, 214, 190]) / 255)
    else:
        base = np.array([198, 172, 126]) / 255 if ativo else np.array([214, 192, 148]) / 255
        papel(t, x, y, d, 21, esc, base=base, queima=0.28 if ativo else 0.2)
        if ativo:
            t.pintar(np.zeros(3), cobertura(d) * np.clip(1 - (y - m) / (Ly * 0.3), 0, 1) * 0.12)
        t.pintar(TINTA, cobertura(np.abs(d) - (1.1 if ativo else 0.6) * esc) * 0.9)
        if ativo:
            filete(t, d, 3.5 * esc, 0.35 * esc, alfa=0.5, cor=LACRE * 0.8)
    c = m + banda + 12 * esc
    return t, {"tamanho": [Lx, Ly], "corte": [c, c, Lx - c, Ly - c]}


def barra_fundo(esc):
    Lx, Ly = 256 * esc, 32 * esc
    t = Tela(Lx, Ly)
    x, y = grade(Lx, Ly)
    m, r, banda = 2 * esc, 9 * esc, 3 * esc
    d = ret_arred(x, y, Lx / 2, Ly / 2, Lx / 2 - m, Ly / 2 - m, r)
    t.pintar(np.array([104, 78, 50]) / 255, cobertura(d))
    sombra = np.clip(1 - (y - m) / (Ly * 0.5), 0, 1) * 0.45
    t.pintar(np.zeros(3), cobertura(d + banda) * sombra)
    t.pintar(TINTA * 0.8, cobertura(np.abs(d + 0.8 * esc) - 0.8 * esc))
    c = m + banda + 8 * esc
    return t, {"tamanho": [Lx, Ly], "corte": [c, c, Lx - c, Ly - c]}


def barra_cheia(esc):
    """Branca com volume; a cor vem do ImageColor3 (PV verde, PM azul, PT ouro)."""
    Lx, Ly = 256 * esc, 32 * esc
    t = Tela(Lx, Ly)
    x, y = grade(Lx, Ly)
    m, r = 5 * esc, 6 * esc
    d = ret_arred(x, y, Lx / 2, Ly / 2, Lx / 2 - m, Ly / 2 - m, r)
    f = (y - m) / (Ly - 2 * m)
    luz = 0.82 + 0.18 * np.clip(1 - f * 1.6, 0, 1) - 0.2 * np.clip(f - 0.55, 0, 1) * 2
    brilho = np.exp(-((f - 0.25) ** 2) / 0.006) * 0.2
    cor = np.clip(luz + brilho, 0, 1)[..., None] * np.ones(3)
    t.pintar(cor, cobertura(d))
    c = m + 7 * esc
    return t, {"tamanho": [Lx, Ly], "corte": [c, c, Lx - c, Ly - c]}


def aro(esc):
    """Moldura de retrato: disco de papel mais escuro com dois anéis de tinta."""
    L = 256 * esc
    t = Tela(L, L)
    x, y = grade(L, L)
    c = L / 2
    raio = c - 8 * esc
    d = np.hypot(x - c, y - c) - raio
    t.pintar(np.zeros(3), cobertura(np.hypot(x - c, y - c - 3 * esc) - raio, 6 * esc) * 0.45)
    papel(t, x, y, d, 31, esc, base=np.array([204, 180, 136]) / 255, queima=0.45)
    t.pintar(TINTA, cobertura(np.abs(d + 1.5 * esc) - 1.5 * esc))
    filete(t, d, 8 * esc, 0.5 * esc, alfa=0.6)
    for ang in (0, 90, 180, 270):
        a = np.radians(ang)
        florao(t, x, y, c + np.cos(a) * (raio - 1.5 * esc), c + np.sin(a) * (raio - 1.5 * esc), 5 * esc, cor=LACRE * 0.8)
    return t, {"tamanho": [L, L], "corte": None}


def espaco(esc):
    """Casa de equipamento/inventário: papel mais escuro, rebaixado, com borda de tinta."""
    L = 128 * esc
    t = Tela(L, L)
    x, y = grade(L, L)
    m, r = 4 * esc, 6 * esc
    d = ret_arred(x, y, L / 2, L / 2, L / 2 - m, L / 2 - m, r)
    papel(t, x, y, d, 41, esc, base=np.array([190, 164, 118]) / 255, queima=0.15)
    t.pintar(np.zeros(3), cobertura(d) * np.clip(1 + d / (9 * esc), 0, 1) * 0.22)
    t.pintar(TINTA, cobertura(np.abs(d) - 0.7 * esc) * 0.9)
    c = 30 * esc
    return t, {"tamanho": [L, L], "corte": [c, c, L - c, L - c]}


def divisor(esc):
    Lx, Ly = 512 * esc, 24 * esc
    t = Tela(Lx, Ly)
    x, y = grade(Lx, Ly)
    cy = Ly / 2
    fade = np.clip(1 - np.abs(x - Lx / 2) / (Lx / 2), 0, 1) ** 0.7
    linha = np.abs(y - cy) - 0.7 * esc
    t.pintar(TINTA, cobertura(linha) * fade * 0.85)
    florao(t, x, y, Lx / 2, cy, 7 * esc, cor=LACRE * 0.85)
    for dx in (-20, 20):
        florao(t, x, y, Lx / 2 + dx * esc, cy, 3.5 * esc)
    return t, {"tamanho": [Lx, Ly], "corte": None}


PECAS = {
    "painel": painel,
    "botao": lambda e: botao(e),
    "botao_ativo": lambda e: botao(e, ativo=True),
    "botao_principal": lambda e: botao(e, principal=True),
    "barra_fundo": barra_fundo,
    "barra_cheia": barra_cheia,
    "aro": aro,
    "espaco": espaco,
    "divisor": divisor,
}


# ------------------------------------------------------------------ prévia (só para conferir o estilo)

def fatiar(t, corte, l, a):
    """Estica uma peça 9-slice para l x a (vizinho mais próximo, só para a prévia)."""
    x0, y0, x1, y1 = [int(v) for v in corte]
    L, A = t.l, t.a

    def eixo(n, c0, c1, total):
        meio = np.linspace(c0, c1 - 1, max(n - c0 - (total - c1), 1)).astype(int)
        return np.concatenate([np.arange(c0), meio, np.arange(c1, total)])[:n]
    ix, iy = eixo(l, x0, x1, L), eixo(a, y0, y1, A)
    nova = Tela(l, a)
    nova.rgb, nova.alfa = t.rgb[np.ix_(iy, ix)], t.alfa[np.ix_(iy, ix)]
    return nova


def colar(dest, peca, x, y, tinta=None, alfa=1.0):
    h, w = peca.a, peca.l
    camada_rgb = np.zeros_like(dest.rgb)
    camada_a = np.zeros_like(dest.alfa)
    camada_rgb[y:y + h, x:x + w] = peca.rgb * (tinta if tinta is not None else 1)
    camada_a[y:y + h, x:x + w] = peca.alfa * alfa
    dest.pintar(camada_rgb, camada_a)


def previa(pecas, caminho):
    W, H = 1280, 720
    t = Tela(W, H)
    x, y = grade(W, H)
    mundo = np.array([62, 84, 52]) / 255 + ruido(W, H, 3, 18)[..., None] * 0.12 + ruido(W, H, 4, 4)[..., None] * 0.05
    t.pintar(np.clip(mundo, 0, 1), np.ones((H, W)))

    def peca(nome, l, a):
        p, info = pecas[nome]
        return fatiar(p, info["corte"], l, a) if info["corte"] else p
    # cartão do jogador (baixo à esquerda)
    colar(t, peca("painel", 420, 150), 20, H - 170)
    aro_p = pecas["aro"][0]
    idx = np.linspace(0, aro_p.l - 1, 120).astype(int)
    menor = Tela(120, 120); menor.rgb, menor.alfa = aro_p.rgb[np.ix_(idx, idx)], aro_p.alfa[np.ix_(idx, idx)]
    colar(t, menor, 34, H - 155)
    for i, cor in enumerate(([0.35, 0.78, 0.5], [0.35, 0.55, 0.95], [0.95, 0.78, 0.35])):
        colar(t, peca("barra_fundo", 250, 26), 168, H - 140 + i * 36)
        colar(t, peca("barra_cheia", int(250 * (0.85 - i * 0.2)), 26), 168, H - 140 + i * 36, tinta=np.array(cor))
    # janela de personagem
    colar(t, peca("painel", 640, 470), 420, 60)
    for i, nome in enumerate(("botao_ativo", "botao", "botao")):
        colar(t, peca(nome, 180, 50), 450 + i * 196, 90)
    colar(t, peca("divisor", 580, 24), 450, 160)
    for i in range(4):
        e = pecas["espaco"][0]
        colar(t, e, 460 + (i % 2) * 140, 200 + (i // 2) * 140)
    colar(t, peca("botao_principal", 240, 60), 760, 440)
    t.salvar(caminho)


def main():
    op = argumentos({"saida": "build/ui", "escala": 2, "so": "", "previa": 0})
    saida = os.path.abspath(op["saida"])
    os.makedirs(saida, exist_ok=True)
    indice = {}
    caminho_indice = os.path.join(saida, "ui_kit.json")
    if os.path.exists(caminho_indice):
        with open(caminho_indice, encoding="utf-8") as f:
            indice = json.load(f)
    for nome, fazer in PECAS.items():
        if op["so"] and nome not in op["so"].split(","):
            continue
        t, info = fazer(op["escala"])
        arquivo = os.path.join(saida, nome + ".png")
        t.salvar(arquivo)
        info["escala"] = op["escala"]
        indice[nome] = info
        print("[ui_kit]", nome, info["tamanho"])
    with open(caminho_indice, "w", encoding="utf-8") as f:
        json.dump(indice, f, indent=1, ensure_ascii=False)
    if op["previa"]:
        pecas = {n: f(1) for n, f in PECAS.items()}
        previa(pecas, os.path.join(saida, "previa.png"))
        print("[ui_kit] previa.png")


if __name__ == "__main__":
    main()
