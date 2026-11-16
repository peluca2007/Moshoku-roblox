"""ARTE2: baixa ícones do game-icons.net (repositório game-icons/icons, CC BY 3.0), converte em
branco com transparência e monta um atlas (build/arte/hud/icones.png + icones.json).

Os SVG baixados ficam em build/arte/gameicons/ (pasta própria). O Roblox tinge o atlas por ImageColor3.
Uso: python tools/arte/icones_gameicons.py
Autores: Lorc, Delapouite, Skoll, Willdabeast, Carl Olsen, Zeromancer, sbed (ver docs/ARTE.md).
"""
import json
import math
import os
import re
import urllib.request

import resvg_py
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SVG = os.path.join(RAIZ, "build", "arte", "gameicons")
SAIDA = os.path.join(RAIZ, "build", "arte", "hud")
BASE = "https://raw.githubusercontent.com/game-icons/icons/master/"
CELULA = 128

# nome do ícone no jogo -> "autor/arquivo" do repositório
ICONES = {
    "atacar": "delapouite/sword-brandish", "habilidades": "delapouite/bolt-spell-cast", "andar": "lorc/walking-boot",
    "encerrar": "lorc/hourglass", "desarmar": "skoll/drop-weapon", "esquivar": "lorc/dodging",
    "defender": "willdabeast/round-shield", "ajudar": "delapouite/shaking-hands", "esconder": "lorc/hidden",
    "golpe-baixo": "lorc/backstab", "disparo": "delapouite/bow-arrow", "quebrar-escudo": "lorc/broken-shield",
    "levantar": "lorc/muscle-up", "marcar": "delapouite/eye-target", "golpe": "lorc/sword-clash",
    "soco": "lorc/fist", "fogo": "carl-olsen/flame", "agua": "sbed/water-drop", "gelo": "lorc/ice-spear",
    "terra": "delapouite/stone-pile", "vento": "lorc/tornado", "raio": "lorc/lightning-helix",
    "cura": "zeromancer/heart-plus", "veneno": "lorc/poison-bottle", "musica": "delapouite/musical-notes",
    "invocacao": "lorc/magic-portal", "teorica": "delapouite/spell-book", "flecha": "lorc/arrow-flights",
    "apoio": "lorc/sunbeams", "guarda": "delapouite/shield-bash", "lamina": "lorc/flying-dagger",
    "magia": "lorc/magic-swirl", "runa": "lorc/rune-stone", "sangue": "lorc/bleeding-wound",
    "caveira": "lorc/skull-crossed-bones", "chamas": "lorc/fire-ray", "golem": "delapouite/rock-golem",
    "muralha": "delapouite/stone-wall", "onda": "lorc/wave-crest", "luz": "lorc/cross-flare",
    "alvo": "lorc/archery-target", "grito": "lorc/wolf-howl", "vazio": "lorc/wind-hole",
    "espiral": "lorc/spiral-bloom", "fogueira": "lorc/fire-bowl", "curativo": "delapouite/hand-bandage",
}


def baixar(rel):
    destino = os.path.join(SVG, rel.replace("/", "__") + ".svg")
    if not os.path.exists(destino):
        pedido = urllib.request.Request(BASE + rel + ".svg", headers={"User-Agent": "moshoku-arte"})
        with urllib.request.urlopen(pedido, timeout=30) as r:
            open(destino, "wb").write(r.read())
    return destino


def renderizar(caminho):
    svg = open(caminho, encoding="utf-8").read()
    svg = re.sub(r'<path d="M0 0h512v512H0z"\s*/>', "", svg)  # tira o fundo preto
    svg = svg.replace("<svg ", '<svg fill="#fff" ', 1) if 'fill="#fff"' not in svg else svg
    png = bytes(resvg_py.svg_to_bytes(svg_string=svg, width=CELULA - 12, height=CELULA - 12))
    import io
    ic = Image.open(io.BytesIO(png)).convert("RGBA")
    # tudo branco, só o alfa importa
    r, g, b, a = ic.split()
    branco = Image.new("L", ic.size, 255)
    return Image.merge("RGBA", (branco, branco, branco, a))


def main():
    os.makedirs(SVG, exist_ok=True)
    os.makedirs(SAIDA, exist_ok=True)
    nomes = sorted(ICONES)
    colunas = 8
    linhas = math.ceil(len(nomes) / colunas)
    atlas = Image.new("RGBA", (colunas * CELULA, linhas * CELULA), (0, 0, 0, 0))
    indice = {}
    for i, nome in enumerate(nomes):
        ic = renderizar(baixar(ICONES[nome]))
        x, y = (i % colunas) * CELULA, (i // colunas) * CELULA
        atlas.alpha_composite(ic, (x + 6, y + 6))
        indice[nome] = {"x": x, "y": y, "fonte": ICONES[nome]}
    atlas.save(os.path.join(SAIDA, "icones.png"))
    json.dump({"celula": CELULA, "largura": atlas.width, "altura": atlas.height, "icones": indice},
              open(os.path.join(SAIDA, "icones.json"), "w", encoding="utf-8"), indent=1)
    print("atlas", atlas.size, len(nomes), "ícones")


if __name__ == "__main__":
    main()
