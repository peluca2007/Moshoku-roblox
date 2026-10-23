"""Roda um script do Blender sem janela.

Uso:  python tools/blender_rodar.py tools/blender/rocha.py [--opcao valor ...]
Os argumentos depois do script vão ao script (sys.argv após "--").
Localiza o Blender por, nesta ordem: variável MOSHOKU_BLENDER, blender.exe no PATH, ou o
blender.exe mais novo extraído em ~/Downloads (pacote portátil).
"""
import glob
import os
import shutil
import subprocess
import sys


def achar_blender():
    env = os.environ.get("MOSHOKU_BLENDER")
    if env and os.path.isfile(env):
        return env
    no_path = shutil.which("blender")
    if no_path:
        return no_path
    padroes = [
        os.path.expanduser(r"~/Downloads/blender-*/**/blender.exe"),
        r"C:\Program Files\Blender Foundation\Blender*\blender.exe",
    ]
    achados = []
    for padrao in padroes:
        achados += glob.glob(padrao, recursive=True)
    return max(achados, key=os.path.getmtime) if achados else None


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    exe = achar_blender()
    if not exe:
        sys.exit("Blender não encontrado. Defina MOSHOKU_BLENDER com o caminho do blender.exe.")
    script = os.path.abspath(sys.argv[1])
    comando = [exe, "--background", "--factory-startup", "--python", script, "--"] + sys.argv[2:]
    sys.exit(subprocess.call(comando))


if __name__ == "__main__":
    main()
