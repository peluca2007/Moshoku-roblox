"""MOD3: criaturas CC0 do Quaternius -> Blender -> pivôs em PivosModelos -> (opcional) Roblox.

Uso:
  python tools/criaturas_quaternius.py                 converte tudo (Blender), grava os pivôs e a prancha
  python tools/criaturas_quaternius.py --so Rato       só os módulos cujo nome contém o texto
  python tools/criaturas_quaternius.py --enviar        também envia cada FBX (Open Cloud) e registra em tools/blender/assets.json
  python tools/criaturas_quaternius.py --studio        também roda o passo do Studio (LoadAsset + exportar Modelos/*.luau)

Sem `--enviar` o jogo continua com os modelos de blocos (ModelosCriaturas.escolher cai no antigo quando o módulo novo
não existe em server/Mundo/Modelos). Saída intermediária em build/criaturas (fora do git).
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gerar_modelo  # noqa: E402

SAIDA = os.path.join(os.environ.get("MOSHOKU_BUILD") or os.path.join(ROOT, "build"), "criaturas")
AUTOR = "Quaternius (CC0)"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--so", default="")
    ap.add_argument("--enviar", action="store_true")
    ap.add_argument("--studio", action="store_true")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = [sys.executable, os.path.join(ROOT, "tools", "blender_rodar.py"),
           os.path.join(ROOT, "tools", "blender", "kits", "criaturas_quaternius.py")]
    if args.so:
        cmd += ["--so", args.so]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    resumo = [l for l in r.stdout.splitlines() if l.startswith("RESUMO")]
    print("\n".join(resumo) or r.stdout[-1500:] + r.stderr[-800:])
    if r.returncode != 0:
        sys.exit(1)
    for nome in sorted(n for n in os.listdir(SAIDA) if n.endswith("Quaternius.json")):
        modulo = nome[:-5]
        if args.so and args.so.lower() not in modulo.lower():
            continue
        with open(os.path.join(SAIDA, nome), encoding="utf-8") as f:
            dados = json.load(f)
        gerar_modelo.gravar_pivos(modulo, dados["pivos"])
        if args.studio or args.enviar:
            fbx = os.path.join(SAIDA, modulo + ".fbx")
            sub = [sys.executable, os.path.join(ROOT, "tools", "gerar_modelo.py"), "criatura-externa", modulo,
                   "--fbx", fbx, "--autor", AUTOR]
            if not args.studio:  # só envia e registra
                registro = gerar_modelo.carregar_registro()
                asset = gerar_modelo.roblox_upload.enviar(fbx, "Moshoku " + modulo)
                registro[modulo] = {"asset": asset, "sha256": gerar_modelo.sha(fbx), "modelo": "criatura-externa", "semente": "1"}
                with open(gerar_modelo.REGISTRO, "w", encoding="utf-8") as f:
                    json.dump(registro, f, ensure_ascii=False, indent=1, sort_keys=True)
                print(f"[{modulo}] enviado: asset {asset}")
            else:
                subprocess.run(sub, check=True)


if __name__ == "__main__":
    main()
