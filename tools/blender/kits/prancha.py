"""Monta a prancha de conferência das criaturas (PNG por modelo -> um JPG). Uso: python tools/blender/kits/prancha.py <pasta_png> <saida.jpg> [colunas]

Roda no Python comum (precisa de Pillow). Cada célula leva o nome do modelo.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

pasta, saida = sys.argv[1], sys.argv[2]
colunas = int(sys.argv[3]) if len(sys.argv) > 3 else 3
arquivos = sorted(glob.glob(os.path.join(pasta, "*.png")))
arquivos = [a for a in arquivos if os.path.basename(a) != "prancha.png"]
w, h = 427, 341
linhas = (len(arquivos) + colunas - 1) // colunas
folha = Image.new("RGB", (w * colunas, h * linhas), (30, 30, 30))
for i, a in enumerate(arquivos):
    im = Image.open(a).convert("RGB").resize((w, h))
    ImageDraw.Draw(im).text((8, 6), os.path.splitext(os.path.basename(a))[0], fill=(0, 0, 0))
    folha.paste(im, ((i % colunas) * w, (i // colunas) * h))
os.makedirs(os.path.dirname(os.path.abspath(saida)), exist_ok=True)
folha.save(saida, quality=85)
print(saida, len(arquivos))
