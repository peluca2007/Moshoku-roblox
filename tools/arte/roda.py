"""RODA2: cunhas pintadas da roda de ações da luta (Pillow + numpy, sem IA, semente fixa).

Gera em build/arte/hud/: cunha_normal.png, cunha_foco.png, cunha_bloqueada.png (600x600, escala 2x de 300 px).
Cada imagem é UM setor de anel de 116 graus apontando para cima, centrado na imagem; a roda usa a mesma imagem
três vezes, girada 0/120/240 graus em volta do centro. Anel entre RAIO_INTERNO e RAIO_EXTERNO (px do PNG),
borda dourada de pincelada (cerdas, pressão variável, falhas); o foco ganha brilho dourado por fora.
Uso: python tools/arte/roda.py   (depois enviar com upload_image e atualizar os ids em shared/UIArteLuta)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
import pinceladas as pi  # noqa: E402

TAM = 600
RAIO_EXTERNO = 292
RAIO_INTERNO = 124
META_ANGULO = 58.0  # graus de cada lado do centro (116 no total; o vão entre cunhas é de 4)

ESTADOS = {
    "normal": dict(tinta=(12, 14, 24), topo=(28, 30, 46), ouro=pi.OURO, forca=0.95, brilho=0.0),
    "foco": dict(tinta=(30, 34, 56), topo=(62, 54, 44), ouro=pi.OURO_VIVO, forca=1.0, brilho=0.8),
    "bloqueada": dict(tinta=(20, 20, 24), topo=(30, 30, 34), ouro=pi.OURO_APAGADO, forca=0.6, brilho=0.0),
}


def cunha(estado, seed):
    e = ESTADOS[estado]
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:TAM, 0:TAM].astype(float)
    dx, dy = xs - (TAM - 1) / 2, ys - (TAM - 1) / 2
    r = np.sqrt(dx * dx + dy * dy)
    teta = np.degrees(np.arctan2(dx, -dy))  # 0 = para cima, positivo no sentido horário
    n = 2048
    ruido = pi.fbm(n, rng, ((300, 1.0), (60, 0.6), (14, 0.35), (4, 0.2)))
    idx = ((teta + 180) / 360 * n).astype(int) % n
    idr = (r * 1.7).astype(int) % n
    # distância (px) às quatro bordas, cada uma com a sua irregularidade de pincelada
    d_ext = RAIO_EXTERNO + 2.2 * ruido[idx] - r
    d_int = r - (RAIO_INTERNO + 2.6 * ruido[(idx + 700) % n])
    d_ang = (META_ANGULO + 0.25 * ruido[idr]) - np.abs(teta)
    d_ang = d_ang * np.radians(1) * np.maximum(r, 1)
    d = np.minimum(np.minimum(d_ext, d_int), d_ang)
    alfa = np.clip(d + 0.5, 0, 1) * 0.93
    # borda dourada: largura variável e falhas de tinta
    larg = 4.0 + 3.2 * np.clip(ruido[(idx * 3 + idr) % n] * 0.5 + 0.55, 0, 1)
    borda = np.clip(d + 0.5, 0, 1) - np.clip(d - larg + 0.5, 0, 1)
    falha = np.clip((pi.ruido(n, 90, rng)[(idx + idr) % n] - 0.08) / 0.12, 0, 1)
    risca = 1 - 0.45 * np.clip((rng.random(n) - 0.82) * 5, 0, 1)[(idx + idr) % n]
    # preenchimento: tinta que clareia em direção à borda externa, com textura de pincel
    t = np.clip((r - RAIO_INTERNO) / (RAIO_EXTERNO - RAIO_INTERNO), 0, 1)
    tex = 1 + 0.04 * ruido[(idx * 5 + idr * 3) % n]
    base = np.array(e["tinta"], float)[None, None, :] * (1 - t[..., None] * 0.5) + np.array(e["topo"], float)[None, None, :] * (t[..., None] * 0.5)
    rgb = base * tex[..., None]
    rgb, alfa = pi.sobre(rgb, alfa, e["ouro"], borda * falha * risca * e["forca"])
    img = pi.para_imagem(rgb, alfa)
    if e["brilho"] > 0:
        halo = np.clip(1 - np.abs(d - 3) / 16, 0, 1) * (d > -14)
        brilho = pi.para_imagem(np.dstack([np.full((TAM, TAM), c, float) for c in pi.OURO_VIVO]), halo * e["brilho"] * 0.55)
        brilho = brilho.filter(ImageFilter.GaussianBlur(6))
        brilho.alpha_composite(img)
        img = brilho
    return img


def main():
    saida = pi.SAIDA
    os.makedirs(saida, exist_ok=True)
    for i, estado in enumerate(ESTADOS):
        cunha(estado, 700 + i).save(os.path.join(saida, "cunha_%s.png" % estado))
    fundo = Image.new("RGBA", (1800, 600), (70, 78, 66, 255))
    for i, estado in enumerate(ESTADOS):
        fundo.alpha_composite(Image.open(os.path.join(saida, "cunha_%s.png" % estado)), (i * 600, 0))
    fundo.save(os.path.join(saida, "prancha_roda.png"))


if __name__ == "__main__":
    main()
