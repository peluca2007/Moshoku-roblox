"""ARTE2: peças pintadas do HUD da luta, desenhadas por código (Pillow + numpy, sem IA, semente fixa).

Gera PNGs com transparência em build/arte/hud/ (escala 2x do tamanho de desenho):
  faixa_{normal,foco,bloqueada}.png   carta de habilidade (9-slice: cantos fixos, ver CORTES)
  botao_{normal,foco,bloqueado,principal}.png   botão de comando curto (9-slice)
  tecla_disco.png, tecla_losango.png  rótulo de tecla (F, R, G, V) e custo
  mancha_retrato.png, mancha_cartao.png   tinta atrás do retrato e do cartão do grupo
  anel_ativo.png                      anel dourado fino para o personagem ativo no chão
  prancha.png                         contato de todas as peças sobre fundo de teste
Cada borda é irregular (cerdas e falhas de tinta), com leve inclinação e fio dourado em um lado.
Uso: python tools/arte/pinceladas.py
"""
import json
import os

import numpy as np
from PIL import Image, ImageFilter

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA = os.path.join(RAIZ, "build", "arte", "hud")

TINTA = (11, 14, 25)
TINTA_FOCO = (21, 26, 44)
TINTA_BLOQ = (20, 20, 24)
OURO = (214, 176, 98)
OURO_VIVO = (247, 213, 130)
OURO_APAGADO = (150, 128, 84)
CINZA = (96, 96, 104)

# SliceCenter (x0, y0, x1, y1) em pixels do PNG, para o módulo shared/UIArteLuta
CORTES = {
    "faixa": (64, 36, 576, 76),
    "botao": (52, 34, 268, 78),
    "mancha_cartao": (90, 60, 422, 132),
}


def _suave(t):
    return t * t * (3 - 2 * t)


def ruido(n, escala, rng):
    """Ruído de valor 1D (0..1), nós a cada `escala` pixels."""
    k = int(n / escala) + 3
    v = rng.random(k)
    x = np.arange(n) / escala
    i = x.astype(int)
    f = _suave(x - i)
    return v[i] * (1 - f) + v[i + 1] * f


def fbm(n, rng, escalas=((60, 1.0), (18, 0.55), (6, 0.3), (2, 0.18))):
    s = np.zeros(n)
    tot = 0
    for e, p in escalas:
        s += ruido(n, e, rng) * p
        tot += p
    return s / tot * 2 - 1  # -1..1


def cerdas(n, rng, forca):
    """Comprimento irregular por linha: faixas finas, com poucas cerdas bem longas."""
    r = rng.random(n) ** 3
    k = np.array([0.25, 0.5, 0.25])
    return np.convolve(r, k, mode="same") * forca


def bordas(w, h, rng, margem, amp, incl=0.0, cerda=1.0):
    """Posições das 4 bordas: esquerda/direita por linha, topo/base por coluna."""
    esq = margem + amp * 2.2 * fbm(h, rng) + cerdas(h, rng, amp * 4.5 * cerda)
    dire = (w - margem) + amp * 2.2 * fbm(h, rng) - cerdas(h, rng, amp * 4.5 * cerda)
    xs = np.arange(w) / w - 0.5
    topo = margem + amp * 1.2 * fbm(w, rng) + incl * xs + cerdas(w, rng, amp * 0.8 * cerda)
    base = (h - margem) + amp * 1.2 * fbm(w, rng) + incl * xs - cerdas(w, rng, amp * 0.8 * cerda)
    return esq, dire, topo, base


def renderizar(w, h, b):
    esq, dire, topo, base = b
    ys = np.arange(h)[:, None]
    xs = np.arange(w)[None, :]
    a = np.clip(xs - esq[:, None] + 0.5, 0, 1) * np.clip(dire[:, None] - xs + 0.5, 0, 1)
    a *= np.clip(ys - topo[None, :] + 0.5, 0, 1) * np.clip(base[None, :] - ys + 0.5, 0, 1)
    return a


def encolher(b, d, rng, ruido_extra=0.6):
    esq, dire, topo, base = b
    j = lambda n: ruido_extra * fbm(n, rng)  # noqa: E731
    return esq + d + j(len(esq)), dire - d + j(len(dire)), topo + d + j(len(topo)), base - d + j(len(base))


def falhas(w, h, b, rng, forca=1.0):
    """Falhas de tinta seca: riscos horizontais mais fortes perto das pontas esquerda/direita."""
    esq, dire, _, _ = b
    xs = np.arange(w)[None, :]
    dist = np.minimum(xs - esq[:, None], dire[:, None] - xs)
    queda = np.exp(-np.maximum(dist, 0) / (w * 0.10))
    risco = np.convolve(rng.random(h), [0.3, 0.4, 0.3], mode="same")
    modula = 0.45 + 0.55 * (fbm(w, rng) * 0.5 + 0.5)
    d = risco[:, None] * modula[None, :] * queda * forca
    vazio = np.clip((d - 0.42) / 0.12, 0, 1)
    return 1 - 0.85 * vazio


def sobre(base_rgb, base_a, cor, a):
    """Composição 'over' de uma camada de cor lisa sobre (rgb, alfa) em float."""
    cor = np.array(cor, dtype=float)[None, None, :]
    sa = a[..., None]
    ba = base_a[..., None]
    saida_a = sa + ba * (1 - sa)
    rgb = np.where(saida_a > 1e-6, (cor * sa + base_rgb * ba * (1 - sa)) / np.maximum(saida_a, 1e-6), base_rgb)
    return rgb, saida_a[..., 0]


def para_imagem(rgb, a):
    img = np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 1) * 255]).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def tira(w, h, estado, seed, margem=12, amp=1.6, incl=3.0, grosso_borda=None):
    """Faixa/botão retangular pintado. estado: normal | foco | bloqueada | principal."""
    rng = np.random.default_rng(seed)
    b = bordas(w, h, rng, margem, amp, incl)
    mascara = renderizar(w, h, b)
    tinta = {"normal": TINTA, "foco": TINTA_FOCO, "bloqueada": TINTA_BLOQ, "principal": TINTA_FOCO}[estado]
    alfa_base = {"normal": 0.88, "foco": 0.93, "bloqueada": 0.62, "principal": 0.93}[estado]
    # tinta com variação de tom e falhas nas pontas
    vari = 1 + 0.18 * (fbm(h, rng)[:, None] * 0.6 + fbm(w, rng)[None, :] * 0.4)
    rgb = np.dstack([np.full((h, w), c, float) for c in tinta]) * vari[..., None]
    alfa = mascara * alfa_base * falhas(w, h, b, rng, 1.0)
    # borda: anel entre o contorno e uma versão encolhida
    largura = grosso_borda or {"normal": 2.2, "foco": 4.6, "bloqueada": 1.8, "principal": 3.6}[estado]
    interna = renderizar(w, h, encolher(b, largura, rng))
    anel = np.clip(mascara - interna, 0, 1)
    seco = falhas(w, h, b, rng, 1.4)
    cor_anel = {"normal": OURO_APAGADO, "foco": OURO_VIVO, "bloqueada": CINZA, "principal": OURO}[estado]
    forca_anel = {"normal": 0.55, "foco": 0.98, "bloqueada": 0.3, "principal": 0.9}[estado]
    # a borda é mais viva em trechos (pressão do pincel)
    pressao = 0.65 + 0.35 * (fbm(w, rng)[None, :] * 0.5 + 0.5)
    rgb, alfa = sobre(rgb, alfa, cor_anel, anel * forca_anel * seco * pressao)
    # fio dourado fino: um lado (a base), acompanha a inclinação
    if estado != "bloqueada":
        esq, dire, topo, base = b
        ys = np.arange(h)[:, None]
        xs = np.arange(w)[None, :]
        centro = base[None, :] - 7.5
        fio = np.clip(1.25 - np.abs(ys - centro), 0, 1)
        corte = np.clip((xs - esq[:, None] - w * 0.06) / 6, 0, 1) * np.clip((dire[:, None] - w * 0.06 - xs) / 6, 0, 1)
        quebra = np.clip((ruido(w, 14, rng)[None, :] - 0.18) / 0.1, 0, 1)
        fio = fio * corte * quebra * (0.85 if estado != "foco" else 1.0)
        rgb, alfa = sobre(rgb, alfa, OURO if estado != "foco" else OURO_VIVO, fio * mascara)
    img = para_imagem(rgb, alfa)
    if estado in ("foco", "principal"):
        brilho = para_imagem(np.dstack([np.full((h, w), c, float) for c in OURO_VIVO]), anel * 0.9)
        brilho = brilho.filter(ImageFilter.GaussianBlur(5))
        base_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        base_img.alpha_composite(brilho)
        # reduz o alfa do brilho
        r, g, bb, a = base_img.split()
        base_img = Image.merge("RGBA", (r, g, bb, a.point(lambda v: int(v * 0.55))))
        base_img.alpha_composite(img)
        img = base_img
    return img


def forma_radial(tam, seed, tipo, tinta, anel_cor, anel_larg=3.0, amp=0.07, raio=0.42, brilho=False):
    """Disco ou losango de tinta com borda irregular e anel dourado entrecortado."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:tam, 0:tam].astype(float)
    cx = cy = (tam - 1) / 2
    dx, dy = xs - cx, ys - cy
    ang = np.arctan2(dy, dx)
    idx = ((ang + np.pi) / (2 * np.pi) * 720).astype(int) % 720
    ond = fbm(720, rng)
    # fecha o ruído em círculo (junta o início ao fim)
    fade = np.linspace(0, 1, 720)
    ond = ond * (1 - fade) + np.roll(ond, 360) * fade * 0
    r_alvo = tam * raio * (1 + amp * ond[idx])
    d = np.sqrt(dx * dx + dy * dy) if tipo == "disco" else (np.abs(dx) + np.abs(dy)) * 0.78
    a = np.clip(r_alvo - d + 0.5, 0, 1)
    interna = np.clip(r_alvo - anel_larg - d + 0.5, 0, 1)
    anel = np.clip(a - interna, 0, 1)
    quebra = np.clip((ruido(720, 40, rng)[idx] - 0.12) / 0.1, 0, 1)
    rgb = np.dstack([np.full((tam, tam), c, float) for c in tinta])
    alfa = a * 0.92
    rgb, alfa = sobre(rgb, alfa, anel_cor, anel * quebra * 0.95)
    return para_imagem(rgb, alfa)


def mancha(w, h, seed):
    """Mancha de tinta grande (retrato): massa escura com borda de pincelada em todos os lados."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    dx, dy = (xs - cx) / (w / 2), (ys - cy) / (h / 2)
    ang = np.arctan2(dy, dx)
    idx = ((ang + np.pi) / (2 * np.pi) * 720).astype(int) % 720
    r = 0.86 + 0.09 * fbm(720, rng, ((90, 1.0), (30, 0.6), (8, 0.3)))
    d = np.maximum(np.abs(dx) ** 3.2 + np.abs(dy) ** 3.2, 0) ** (1 / 3.2)  # quase retângulo arredondado
    a = np.clip((r[idx] - d) * min(w, h) * 0.5 + 0.5, 0, 1)
    interna = np.clip((r[idx] - 0.045 - d) * min(w, h) * 0.5 + 0.5, 0, 1)
    anel = np.clip(a - interna, 0, 1)
    risco = np.convolve(rng.random(h), [0.3, 0.4, 0.3], mode="same")[:, None] * (0.5 + 0.5 * (fbm(w, rng) * 0.5 + 0.5))[None, :]
    falha = 1 - 0.8 * np.clip((risco * np.clip(d - 0.55, 0, 1) * 2.4 - 0.4) / 0.12, 0, 1)
    rgb = np.dstack([np.full((h, w), c, float) for c in TINTA]) * (1 + 0.15 * fbm(w, rng)[None, :, None])
    alfa = a * 0.9 * falha
    quebra = np.clip((ruido(720, 40, rng)[idx] - 0.2) / 0.1, 0, 1)
    rgb, alfa = sobre(rgb, alfa, OURO_APAGADO, anel * quebra * 0.7 * falha)
    return para_imagem(rgb, alfa)


def anel_chao(tam, seed):
    """Anel fino dourado de pincelada: pressão variável, falhas e um brilho suave por baixo."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:tam, 0:tam].astype(float)
    cx = cy = (tam - 1) / 2
    dx, dy = xs - cx, ys - cy
    ang = np.arctan2(dy, dx)
    n = 1440
    idx = ((ang + np.pi) / (2 * np.pi) * n).astype(int) % n
    raio = tam * 0.4 * (1 + 0.012 * fbm(n, rng, ((200, 1.0), (50, 0.5))))
    larg = 3.0 + 4.2 * np.clip(fbm(n, rng, ((300, 1.0), (60, 0.5))) * 0.5 + 0.55, 0, 1)
    d = np.abs(np.sqrt(dx * dx + dy * dy) - raio[idx])
    a = np.clip(larg[idx] / 2 - d + 0.5, 0, 1)
    # um trecho do traço quase some (fim e começo da pincelada)
    quebra = np.clip((ruido(n, 90, rng)[idx] - 0.1) / 0.12, 0, 1)
    risca = 1 - 0.5 * np.clip((rng.random(n) - 0.8) * 5, 0, 1)[idx]
    anel = a * quebra * risca
    rgb = np.dstack([np.full((tam, tam), c, float) for c in OURO_VIVO])
    img = para_imagem(rgb, anel * 0.96)
    brilho = para_imagem(rgb, a * 0.8).filter(ImageFilter.GaussianBlur(7))
    r, g, bb, al = brilho.split()
    brilho = Image.merge("RGBA", (r, g, bb, al.point(lambda v: int(v * 0.45))))
    brilho.alpha_composite(img)
    return brilho


def main():
    os.makedirs(SAIDA, exist_ok=True)
    pecas = {}
    for i, estado in enumerate(("normal", "foco", "bloqueada")):
        pecas["faixa_" + estado] = tira(640, 112, estado, 100 + i)
    for i, (estado, nome) in enumerate((("normal", "normal"), ("foco", "foco"), ("bloqueada", "bloqueado"), ("principal", "principal"))):
        pecas["botao_" + nome] = tira(320, 112, estado, 200 + i, margem=12, amp=1.5)
    pecas["tecla_disco"] = forma_radial(64, 301, "disco", TINTA, OURO_VIVO, 3.0, 0.05, 0.43)
    pecas["tecla_losango"] = forma_radial(64, 302, "losango", TINTA, OURO_VIVO, 3.0, 0.04, 0.45)
    pecas["mancha_retrato"] = mancha(256, 256, 401)
    pecas["mancha_cartao"] = mancha(512, 192, 402)
    pecas["anel_ativo"] = anel_chao(512, 501)
    medidas = {}
    for nome, img in pecas.items():
        img.save(os.path.join(SAIDA, nome + ".png"))
        medidas[nome] = list(img.size)
    json.dump({"tamanhos": medidas, "cortes": CORTES}, open(os.path.join(SAIDA, "pecas.json"), "w"), indent=1)
    # prancha de contato sobre um fundo de teste
    prancha = Image.new("RGBA", (1300, 900), (70, 78, 66, 255))
    x = y = 20
    for nome, img in pecas.items():
        if x + img.width > 1280:
            x, y = 20, y + 130
        prancha.alpha_composite(img, (x, y))
        x += img.width + 20
    prancha.convert("RGB").save(os.path.join(SAIDA, "prancha.png"))
    print("ok", len(pecas), "peças em", SAIDA)


if __name__ == "__main__":
    main()
