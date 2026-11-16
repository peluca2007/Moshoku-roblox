#!/usr/bin/env python3
"""Torna transparente o fundo de uma imagem (Pillow, sem outras dependências).

Modos:
  escuro (padrão): luminância baixa vira transparente; o alfa cresce suavemente entre --min e --max
          (bom para tinta/ícones sobre fundo escuro).
  cor:    fundo = cor do canto (ou --cor R,G,B); alfa pela distância à cor entre --min e --max.
  borda:  como "cor", mas só remove o que se conecta às bordas (preserva áreas internas).

Uso: python tools/arte/remover_fundo.py entrada.png saida.png [--modo escuro] [--min 18] [--max 60]
"""
import argparse
from collections import deque

from PIL import Image, ImageFilter


def alfa_suave(v, lo, hi):
    if v <= lo:
        return 0
    if v >= hi:
        return 255
    return int(255 * (v - lo) / (hi - lo))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--modo", choices=["escuro", "cor", "borda"], default="escuro")
    p.add_argument("--cor", default=None, help="R,G,B do fundo (padrão: canto superior esquerdo)")
    p.add_argument("--min", type=int, default=18)
    p.add_argument("--max", type=int, default=60)
    a = p.parse_args()

    img = Image.open(a.entrada).convert("RGB")
    w, h = img.size
    px = img.load()
    alfa = Image.new("L", (w, h), 255)
    ap = alfa.load()

    if a.modo == "escuro":
        for y in range(h):
            for x in range(w):
                ap[x, y] = alfa_suave(max(px[x, y]), a.min, a.max)
    else:
        ref = tuple(int(v) for v in a.cor.split(",")) if a.cor else px[0, 0]

        def dist(x, y):
            r, g, b = px[x, y]
            return max(abs(r - ref[0]), abs(g - ref[1]), abs(b - ref[2]))

        if a.modo == "cor":
            for y in range(h):
                for x in range(w):
                    ap[x, y] = alfa_suave(dist(x, y), a.min, a.max)
        else:
            visto = bytearray(w * h)
            fila = deque()
            for x in range(w):
                fila.extend([(x, 0), (x, h - 1)])
            for y in range(h):
                fila.extend([(0, y), (w - 1, y)])
            while fila:
                x, y = fila.popleft()
                if x < 0 or y < 0 or x >= w or y >= h or visto[y * w + x]:
                    continue
                if dist(x, y) > a.max:
                    continue
                visto[y * w + x] = 1
                ap[x, y] = alfa_suave(dist(x, y), a.min, a.max)
                fila.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
            alfa = alfa.filter(ImageFilter.GaussianBlur(0.8))

    out = img.convert("RGBA")
    out.putalpha(alfa)
    out.save(a.saida)
    print("ok", a.saida)


if __name__ == "__main__":
    main()
