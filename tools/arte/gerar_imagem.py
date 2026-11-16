#!/usr/bin/env python3
"""Gera imagens localmente com stable-diffusion.cpp (Vulkan) + SDXL base 1.0.

Exemplos:
  python tools/arte/gerar_imagem.py --estilo icone_habilidade -p "espada cortando" -o saida.png
  python tools/arte/gerar_imagem.py -p "..." -n "..." -W 1024 -H 256 --passos 25 -s 7 -o x.png

Instalação e licenças: docs/ARTE.md. As ferramentas ficam fora do git, em build/ferramentas.
"""
import argparse
import os
import subprocess
import sys
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Em worktrees o build/ fica na raiz do repositório principal; MOSHOKU_FERRAMENTAS sobrescreve.
CANDIDATOS = [
    os.environ.get("MOSHOKU_FERRAMENTAS", ""),
    os.path.join(RAIZ, "build", "ferramentas"),
    os.path.normpath(os.path.join(RAIZ, "..", "..", "..", "build", "ferramentas")),
]


def achar_ferramentas():
    for c in CANDIDATOS:
        if c and os.path.isfile(os.path.join(c, "sdcpp", "sd-cli.exe")):
            return c
    sys.exit("sd-cli.exe não encontrado; veja docs/ARTE.md (instalação).")


NEGATIVO_BASE = (
    "text, letters, watermark, signature, logo, frame border, photo, 3d render, blurry, "
    "low quality, jpeg artifacts, deformed, extra limbs, cropped"
)

ESTILOS = {
    "painel_pincelada": {
        "prompt": (
            "{p}, wide horizontal banner background, dark charcoal and deep indigo ink wash, "
            "rough expressive dry brush strokes, torn painted edges, subtle gold leaf flecks, "
            "oil painting texture, dark fantasy game UI panel, empty center, no text, plain background"
        ),
        "negativo": NEGATIVO_BASE + ", characters, faces, bright colors, white background",
        "largura": 1024, "altura": 256, "passos": 25, "cfg": 6.5,
    },
    "icone_habilidade": {
        "prompt": (
            "{p}, single centered game ability icon, bold ink brush painting, "
            "dark fantasy, gold and crimson accents on near-black, high contrast, "
            "dramatic silhouette, painterly rough strokes, isolated on a solid pure black background"
        ),
        "negativo": NEGATIVO_BASE + ", multiple objects, busy background, realistic, white background, gray background",
        "largura": 512, "altura": 512, "passos": 25, "cfg": 7.0,
    },
    "retrato": {
        "prompt": (
            "{p}, character portrait bust, dark fantasy oil painting, expressive brush strokes, "
            "moody chiaroscuro lighting, muted palette with gold highlights, dark vignette background"
        ),
        "negativo": NEGATIVO_BASE + ", full body, bright background, cartoon",
        "largura": 768, "altura": 1024, "passos": 28, "cfg": 7.0,
    },
}


def main():
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--prompt", "-p", required=True)
    a.add_argument("--negativo", "-n", default=None)
    a.add_argument("--estilo", choices=sorted(ESTILOS), default=None)
    a.add_argument("-W", "--largura", type=int, default=None)
    a.add_argument("-H", "--altura", type=int, default=None)
    a.add_argument("--passos", type=int, default=None)
    a.add_argument("--cfg", type=float, default=None)
    a.add_argument("--semente", "-s", type=int, default=-1)
    a.add_argument("-o", "--saida", required=True)
    a.add_argument("--modelo", default=None)
    a = a.parse_args()

    est = ESTILOS.get(a.estilo, {})
    prompt = est["prompt"].format(p=a.prompt) if est else a.prompt
    negativo = a.negativo if a.negativo is not None else est.get("negativo", NEGATIVO_BASE)
    larg = a.largura or est.get("largura", 1024)
    alt = a.altura or est.get("altura", 1024)
    passos = a.passos or est.get("passos", 25)
    cfg = a.cfg or est.get("cfg", 7.0)

    f = achar_ferramentas()
    modelo = a.modelo or os.path.join(f, "modelos", "sd_xl_base_1.0.safetensors")
    vae = os.path.join(f, "modelos", "sdxl_vae_fp16_fix.safetensors")
    saida = os.path.abspath(a.saida)
    os.makedirs(os.path.dirname(saida), exist_ok=True)

    cmd = [os.path.join(f, "sdcpp", "sd-cli.exe"), "-m", modelo, "--vae", vae,
           "-p", prompt, "-n", negativo, "-W", str(larg), "-H", str(alt),
           "--steps", str(passos), "--cfg-scale", str(cfg), "-s", str(a.semente),
           "--vae-tiling", "--diffusion-fa", "-o", saida]
    t0 = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    dt = time.time() - t0
    if r.returncode != 0 or not os.path.isfile(saida):
        sys.stderr.write((r.stdout or "")[-2000:] + (r.stderr or "")[-2000:])
        sys.exit("falha ao gerar imagem (código %d)" % r.returncode)
    print("ok %s %dx%d passos=%d tempo=%.1fs" % (saida, larg, alt, passos, dt))


if __name__ == "__main__":
    main()
