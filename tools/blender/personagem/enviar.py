"""PERS3: gera e envia as peças em malha e os rostos pela rota do Studio (sem chave; Studio aberto em Edit com MCP ligado).

Uso (na raiz do projeto, com o Studio livre):
    set MOSHOKU_VIA_STUDIO=1            (PowerShell: $env:MOSHOKU_VIA_STUDIO = "1")
    python tools/blender/personagem/enviar.py [--so NomeDoModulo] [--sem-rostos] [--sem-pecas]

1. Blender: `exportar.py` -> build/personagem/pecas/*.fbx|json e build/personagem/rostos/*.png (a pasta `build` precisa
   estar entre as aprovadas para upload do Assistant, como na PERS2b);
2. cada peça: `tools/gerar_modelo.py personagem <Modulo> --fbx ...` (envia, repinta no Studio, grava
   src/server/Mundo/Modelos/<Modulo>.luau);
3. cada rosto: Decal pela Open Cloud; os ids de Decal ficam em build/personagem/rostos/ids.json. O que o Shirt/Pants/Decal
   do jogo usa é o id da IMAGEM do Decal (InsertService:LoadAsset -> Decal.Texture), como em PERS2b: converter e preencher
   `Personagem.ROSTOS[estilo][OlhoXxx]` em src/shared/Aparencia/Personagem.luau.
"""
import json
import os
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pecas as P  # noqa: E402


def rodar(args):
    r = subprocess.run([sys.executable] + args, cwd=RAIZ)
    if r.returncode != 0:
        sys.exit(f"falhou: {' '.join(args)}")


def main():
    a = sys.argv[1:]
    so = a[a.index("--so") + 1] if "--so" in a else ""
    os.environ["MOSHOKU_VIA_STUDIO"] = "1"
    rodar(["tools/blender_rodar.py", "tools/blender/personagem/exportar.py", "--rostos", "0" if "--sem-rostos" in a else "1"]
          + (["--so", so] if so else []))
    if "--sem-pecas" not in a:
        for modulo in P.TODAS:
            if so and so != modulo:
                continue
            rodar(["tools/gerar_modelo.py", "personagem", modulo, "--fbx", f"build/personagem/pecas/{modulo}.fbx",
                   "--autor", "Blender (tools/blender/personagem)"])
    if "--sem-rostos" not in a and not so:
        ids = {}
        pasta = os.path.join(RAIZ, "build", "personagem", "rostos")
        for nome in sorted(os.listdir(pasta)):
            if not nome.endswith(".png"):
                continue
            r = subprocess.run([sys.executable, "tools/roblox_upload.py", os.path.join(pasta, nome), "--tipo", "Decal",
                                "--nome", "Moshoku " + nome[:-4]], cwd=RAIZ, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"rosto {nome}: {r.stdout[-300:]}{r.stderr[-300:]}")
            ids[nome[:-4]] = json.loads(r.stdout.strip().splitlines()[-1])["assetId"]
            print(nome, ids[nome[:-4]])
        with open(os.path.join(pasta, "ids.json"), "w", encoding="utf-8") as f:
            json.dump(ids, f, indent=1)


main()
