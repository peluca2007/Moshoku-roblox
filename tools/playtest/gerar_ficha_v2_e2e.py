"""Gera tools/playtest/ficha_v2_e2e.luau a partir do modelo e da ficha fictícia.

Uso: python tools/playtest/gerar_ficha_v2_e2e.py
(regenere a ficha antes, se preciso: powershell -File tools/fixtures/ficha-v2-aria.ps1)
"""
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
modelo = open(os.path.join(AQUI, "ficha_v2_e2e.modelo.luau"), encoding="utf-8").read()
ficha = open(os.path.join(RAIZ, "tools", "fixtures", "ficha-v2-aria.json"), encoding="utf-8").read().strip()
assert "]==]" not in ficha
saida = modelo.replace("--FIXTURE--", ficha, 1)
open(os.path.join(AQUI, "ficha_v2_e2e.luau"), "w", encoding="utf-8", newline="\n").write(saida)
print("ficha_v2_e2e.luau gerado")
