"""Monta uma prancha (grade) com os quadros de uma habilidade. Uso: python tools/qa/prancha.py <prefixo> <saida.png> [colunas]
Lê build/beleza/hab1/<prefixo>_0..N.png."""
import glob, os, re, sys
from PIL import Image, ImageDraw
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
pref, saida = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
arqs = sorted(glob.glob(os.path.join(RAIZ, "build", "beleza", "hab1", pref + "_[0-9]*.png")), key=lambda p: int(re.search(r"_(\d+)\.png$", p).group(1)))
ims = [Image.open(a).convert("RGB") for a in arqs]
w, h = 470, 202
rows = (len(ims) + cols - 1) // cols
folha = Image.new("RGB", (cols * w, rows * h), (12, 12, 16))
for i, im in enumerate(ims):
    # recorta o miolo (a ação) e reduz
    iw, ih = im.size
    c = im.crop((int(iw * 0.25), int(ih * 0.2), int(iw * 0.75), int(ih * 0.85))).resize((w, h))
    d = ImageDraw.Draw(c)
    d.text((6, 4), str(i), fill=(255, 220, 120))
    folha.paste(c, ((i % cols) * w, (i // cols) * h))
folha.save(saida)
print(saida, len(ims))
