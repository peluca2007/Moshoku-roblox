#!/usr/bin/env python3
"""Gera as amostras de ARTE1 em build/arte/amostras/ (2 painéis, 3 ícones) e mede o tempo."""
import os
import subprocess
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
sys.path.insert(0, AQUI)
from gerar_imagem import achar_ferramentas  # noqa: E402

# build/arte fica junto das ferramentas (raiz principal, mesmo em worktrees)
SAIDA = os.path.join(os.path.dirname(achar_ferramentas()), "arte", "amostras")

ITENS = [
    ("painel_pincelada", "painel_a", 11, "dark ink painted panel for a skill card, heavy diagonal brush strokes"),
    ("painel_pincelada", "painel_b", 22, "dark ink painted panel, swirling charcoal brush and thin gold dust streaks"),
    ("icone_habilidade", "icone_golpe", 3, "a sword slash, katana strike arc"),
    ("icone_habilidade", "icone_esquiva", 4, "a figure leaping aside, motion trails, dodge"),
    ("icone_habilidade", "icone_defender", 5, "a round shield with brush-painted emblem, defense"),
]


def main():
    os.makedirs(SAIDA, exist_ok=True)
    for estilo, nome, semente, prompt in ITENS:
        png = os.path.join(SAIDA, nome + ".png")
        t0 = time.time()
        subprocess.run([sys.executable, os.path.join(AQUI, "gerar_imagem.py"), "--estilo", estilo,
                        "-p", prompt, "-s", str(semente), "-o", png], check=True)
        print("%s: %.1fs" % (nome, time.time() - t0))
        if nome.startswith("icone"):
            subprocess.run([sys.executable, os.path.join(AQUI, "remover_fundo.py"), png,
                            os.path.join(SAIDA, nome + "_transparente.png")], check=True)


if __name__ == "__main__":
    main()
