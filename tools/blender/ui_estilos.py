"""Prancha de estilos de interface para o Pedro escolher a direção (roda dentro do Blender, sem janela).
Mesma cena em quatro estilos: cartão do jogador, atalhos e a janela de personagem (abas, espaços de
equipamento, linhas de status e botão principal). Texto aparece como traços, só para dar a forma.

Uso:  python tools/blender_rodar.py tools/blender/ui_estilos.py [--saida build/ui/estilos]
Saída: <saida>/<estilo>.png e <saida>/prancha.png (2 x 2).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from lib import argumentos  # noqa: E402
from ui_kit import Tela, borrar, cobertura, grade, metal, moldura, ret_arred, ruido  # noqa: E402

W, H = 1280, 720


def rgb(*c):
    return np.array(c, dtype=float) / 255


def mundo(t):
    base = rgb(70, 92, 58)
    cor = base + ruido(W, H, 3, 22)[..., None] * 0.14 + ruido(W, H, 4, 5)[..., None] * 0.05
    caminho = np.exp(-((grade(W, H)[0] - 640 - 120 * np.sin(grade(W, H)[1] / 160)) ** 2) / (2 * 70 ** 2))
    cor = cor * (1 - caminho[..., None] * 0.5) + rgb(128, 104, 74) * caminho[..., None] * 0.5
    t.pintar(np.clip(cor, 0, 1), np.ones((H, W)))


def rect_d(x0, y0, w, h, r):
    x, y = grade(W, H)
    return ret_arred(x, y, x0 + w / 2, y0 + h / 2, w / 2, h / 2, r)


def traco(t, x0, y0, w, h, cor, alfa=0.9):
    t.pintar(cor, cobertura(rect_d(x0, y0, w, h, h / 2)) * alfa)


def circulo_d(cx, cy, r):
    x, y = grade(W, H)
    return np.hypot(x - cx, y - cy) - r


# ------------------------------------------------------------------ estilos

class Estilo:
    nome = ""
    texto = rgb(230, 225, 210)
    texto2 = rgb(150, 145, 135)
    titulo = rgb(230, 225, 210)
    barras = (rgb(80, 190, 120), rgb(80, 130, 220), rgb(220, 180, 80))

    def painel(self, t, x0, y0, w, h): ...
    def botao(self, t, x0, y0, w, h, tipo): ...  # tipo: normal | ativo | principal
    def espaco(self, t, x0, y0, s): ...
    def barra(self, t, x0, y0, w, h, valor, cor): ...
    def retrato(self, t, cx, cy, r): ...


def sombra(t, d, raio, forca):
    t.pintar(np.zeros(3), np.clip(1 - np.maximum(d, 0) / raio, 0, 1) ** 2 * forca * (d > -2))


class Elegante(Estilo):
    """Escuro e fino, ouro só em filetes (linha de Baldur's Gate 3)."""
    nome = "1 · Elegante escuro"
    titulo = rgb(222, 196, 140)
    ouro = rgb(176, 146, 92)

    def painel(self, t, x0, y0, w, h):
        d = rect_d(x0, y0, w, h, 4)
        sombra(t, rect_d(x0, y0 + 6, w, h, 4), 18, 0.5)
        t.pintar(rgb(12, 12, 15) + ruido(W, H, 7, 2)[..., None] * 0.01, cobertura(d) * 0.92)
        t.pintar(self.ouro, cobertura(np.abs(d) - 0.8))
        t.pintar(self.ouro, cobertura(np.abs(d + 5) - 0.5) * 0.35)
        for cx, cy, sx, sy in ((x0, y0, 1, 1), (x0 + w, y0, -1, 1), (x0, y0 + h, 1, -1), (x0 + w, y0 + h, -1, -1)):
            x, y = grade(W, H)
            braco = np.minimum(np.maximum(np.abs(y - (cy + sy * 2)) - 1.2, (x - cx) * sx - 22), np.maximum(np.abs(x - (cx + sx * 2)) - 1.2, (y - cy) * sy - 22))
            dentro = ((x - cx) * sx >= -1) & ((y - cy) * sy >= -1)
            t.pintar(rgb(222, 196, 140), cobertura(braco) * dentro)

    def botao(self, t, x0, y0, w, h, tipo):
        d = rect_d(x0, y0, w, h, 3)
        fundo = {"normal": rgb(20, 20, 24), "ativo": rgb(34, 30, 24), "principal": rgb(70, 24, 24)}[tipo]
        t.pintar(fundo, cobertura(d) * 0.95)
        t.pintar(self.ouro if tipo != "normal" else rgb(90, 80, 64), cobertura(np.abs(d) - 0.6))
        traco(t, x0 + w / 2 - w * 0.22, y0 + h / 2 - 3, w * 0.44, 6, self.titulo if tipo != "normal" else self.texto2)

    def espaco(self, t, x0, y0, s):
        d = rect_d(x0, y0, s, s, 2)
        t.pintar(rgb(6, 6, 8), cobertura(d) * 0.9)
        t.pintar(rgb(90, 80, 64), cobertura(np.abs(d) - 0.5))

    def barra(self, t, x0, y0, w, h, valor, cor):
        t.pintar(rgb(8, 8, 10), cobertura(rect_d(x0, y0, w, h, 1)) * 0.9)
        t.pintar(cor * 0.85, cobertura(rect_d(x0 + 1, y0 + 1, (w - 2) * valor, h - 2, 1)))

    def retrato(self, t, cx, cy, r):
        d = circulo_d(cx, cy, r)
        t.pintar(rgb(14, 14, 18), cobertura(d))
        t.pintar(self.ouro, cobertura(np.abs(d) - 0.9))
        t.pintar(self.ouro, cobertura(np.abs(d + 5) - 0.5) * 0.4)


class Pergaminho(Estilo):
    """Papel envelhecido e tinta marrom, botão de lacre vermelho (cara de livro de RPG)."""
    nome = "2 · Pergaminho"
    texto = rgb(70, 48, 30)
    texto2 = rgb(120, 94, 66)
    titulo = rgb(96, 36, 26)

    def papel(self, t, d, semente, base=rgb(226, 206, 164)):
        cor = base + ruido(W, H, semente, 3)[..., None] * 0.04 + ruido(W, H, semente + 1, 20)[..., None] * 0.06
        borda = np.exp(np.minimum(d, 0) / 14)[..., None]
        cor = cor * (1 - borda * 0.35) + rgb(120, 82, 44) * borda * 0.35
        t.pintar(np.clip(cor, 0, 1), cobertura(d))

    def painel(self, t, x0, y0, w, h):
        sombra(t, rect_d(x0, y0 + 6, w, h, 6), 16, 0.45)
        d = rect_d(x0, y0, w, h, 6)
        self.papel(t, d, 13)
        t.pintar(rgb(92, 60, 34), cobertura(np.abs(d + 7) - 0.9) * 0.8)

    def botao(self, t, x0, y0, w, h, tipo):
        d = rect_d(x0, y0, w, h, 5)
        if tipo == "principal":
            altura = np.clip(-d / 8, 0, 1)
            cor = metal(altura, 3, base=rgb(150, 40, 34), claro=rgb(220, 110, 90), escuro=rgb(70, 16, 14))
            t.pintar(cor, cobertura(d))
            traco(t, x0 + w / 2 - w * 0.22, y0 + h / 2 - 3, w * 0.44, 6, rgb(250, 230, 200))
            return
        fundo = rgb(196, 170, 124) if tipo == "ativo" else rgb(212, 190, 146)
        t.pintar(fundo, cobertura(d))
        t.pintar(rgb(92, 60, 34), cobertura(np.abs(d) - (1.2 if tipo == "ativo" else 0.6)))
        traco(t, x0 + w / 2 - w * 0.22, y0 + h / 2 - 3, w * 0.44, 6, self.titulo if tipo == "ativo" else self.texto2)

    def espaco(self, t, x0, y0, s):
        d = rect_d(x0, y0, s, s, 4)
        t.pintar(rgb(190, 164, 118), cobertura(d))
        t.pintar(rgb(0, 0, 0), cobertura(d) * np.clip(1 + d / 10, 0, 1) * 0.18)
        t.pintar(rgb(92, 60, 34), cobertura(np.abs(d) - 0.7))

    def barra(self, t, x0, y0, w, h, valor, cor):
        t.pintar(rgb(120, 92, 60), cobertura(rect_d(x0, y0, w, h, h / 2)))
        t.pintar(cor * 0.8, cobertura(rect_d(x0 + 2, y0 + 2, (w - 4) * valor, h - 4, (h - 4) / 2)))

    def retrato(self, t, cx, cy, r):
        d = circulo_d(cx, cy, r)
        self.papel(t, d, 17, base=rgb(204, 180, 136))
        t.pintar(rgb(92, 60, 34), cobertura(np.abs(d) - 1.4))


class Pedra(Estilo):
    """Pedra escura com moldura de ferro rebitada, destaque azul frio (mais sério e sombrio)."""
    nome = "3 · Pedra e ferro"
    titulo = rgb(200, 214, 228)
    texto2 = rgb(140, 148, 156)
    azul = rgb(110, 170, 225)

    def ferro(self, altura, forca):
        return metal(altura, forca, base=rgb(120, 126, 134), claro=rgb(220, 226, 234), escuro=rgb(40, 42, 48))

    def painel(self, t, x0, y0, w, h):
        sombra(t, rect_d(x0, y0 + 6, w, h, 8), 18, 0.55)
        d = rect_d(x0, y0, w, h, 8)
        cor = rgb(46, 48, 52) + ruido(W, H, 21, 2)[..., None] * 0.05 + ruido(W, H, 22, 12)[..., None] * 0.06
        t.pintar(np.clip(cor, 0, 1), cobertura(d))
        tela = Tela(W, H)
        moldura(tela, None, None, d, 10, 2.0)
        tela.rgb = np.clip(tela.rgb.mean(-1, keepdims=True) * np.array([0.95, 1.0, 1.08]) * 1.15, 0, 1)
        t.pintar(tela.rgb, tela.alfa)
        x, y = grade(W, H)
        for cx in (x0 + 5, x0 + w - 5):
            for cy in np.arange(y0 + 5, y0 + h, 60):
                dd = np.hypot(x - cx, y - cy) - 3
                t.pintar(self.ferro(np.clip(-dd / 3, 0, 1), 3), cobertura(dd))

    def botao(self, t, x0, y0, w, h, tipo):
        d = rect_d(x0, y0, w, h, 4)
        if tipo == "principal":
            t.pintar(rgb(34, 70, 104), cobertura(d))
            t.pintar(self.azul, cobertura(np.abs(d) - 1.0))
        else:
            t.pintar(rgb(58, 60, 66) if tipo == "ativo" else rgb(38, 40, 44), cobertura(d))
            t.pintar(self.ferro(np.clip(-d / 3, 0, 1), 2), cobertura(np.abs(d + 1.5) - 1.5))
        traco(t, x0 + w / 2 - w * 0.22, y0 + h / 2 - 3, w * 0.44, 6, self.titulo if tipo != "normal" else self.texto2)

    def espaco(self, t, x0, y0, s):
        d = rect_d(x0, y0, s, s, 3)
        t.pintar(rgb(24, 25, 28), cobertura(d))
        t.pintar(self.ferro(np.clip(-d / 3, 0, 1), 2), cobertura(np.abs(d + 1.5) - 1.5))

    def barra(self, t, x0, y0, w, h, valor, cor):
        t.pintar(rgb(18, 19, 22), cobertura(rect_d(x0, y0, w, h, 2)))
        t.pintar(cor * 0.9, cobertura(rect_d(x0 + 2, y0 + 2, (w - 4) * valor, h - 4, 1)))
        t.pintar(rgb(140, 146, 154), cobertura(np.abs(rect_d(x0, y0, w, h, 2)) - 0.7))

    def retrato(self, t, cx, cy, r):
        d = circulo_d(cx, cy, r)
        t.pintar(rgb(40, 42, 46), cobertura(d))
        t.pintar(self.ferro(np.clip(1 - np.abs(d + 5) / 5, 0, 1), 3), cobertura(np.abs(d + 5) - 5))


class Limpo(Estilo):
    """Vidro escuro translúcido, cantos redondos, sem ornamento, uma cor de destaque (mais atual)."""
    nome = "4 · Limpo moderno"
    titulo = rgb(240, 244, 248)
    texto2 = rgb(150, 160, 172)
    destaque = rgb(84, 214, 190)

    def painel(self, t, x0, y0, w, h):
        sombra(t, rect_d(x0, y0 + 8, w, h, 16), 24, 0.35)
        d = rect_d(x0, y0, w, h, 16)
        t.pintar(rgb(16, 20, 28), cobertura(d) * 0.78)
        t.pintar(np.ones(3), cobertura(np.abs(d) - 0.6) * 0.16)

    def botao(self, t, x0, y0, w, h, tipo):
        d = rect_d(x0, y0, w, h, h / 2)
        if tipo == "principal":
            t.pintar(self.destaque, cobertura(d))
            traco(t, x0 + w / 2 - w * 0.22, y0 + h / 2 - 3, w * 0.44, 6, rgb(10, 30, 28))
            return
        t.pintar(np.ones(3), cobertura(d) * (0.16 if tipo == "ativo" else 0.06))
        if tipo == "ativo":
            traco(t, x0 + w * 0.3, y0 + h - 4, w * 0.4, 3, self.destaque)
        traco(t, x0 + w / 2 - w * 0.22, y0 + h / 2 - 3, w * 0.44, 6, self.titulo if tipo == "ativo" else self.texto2)

    def espaco(self, t, x0, y0, s):
        d = rect_d(x0, y0, s, s, 12)
        t.pintar(np.ones(3), cobertura(d) * 0.06)
        t.pintar(np.ones(3), cobertura(np.abs(d) - 0.5) * 0.14)

    def barra(self, t, x0, y0, w, h, valor, cor):
        t.pintar(np.ones(3), cobertura(rect_d(x0, y0, w, h, h / 2)) * 0.1)
        t.pintar(cor, cobertura(rect_d(x0, y0, w * valor, h, h / 2)))

    def retrato(self, t, cx, cy, r):
        d = circulo_d(cx, cy, r)
        t.pintar(rgb(16, 20, 28), cobertura(d) * 0.8)
        t.pintar(self.destaque, cobertura(np.abs(d) - 1.5))


# ------------------------------------------------------------------ cena

def cena(estilo, caminho):
    t = Tela(W, H)
    mundo(t)
    s = estilo
    # cartão do jogador (baixo à esquerda)
    s.painel(t, 20, 570, 420, 130)
    s.retrato(t, 82, 635, 46)
    traco(t, 142, 590, 120, 9, s.titulo)
    for i, cor in enumerate(s.barras):
        s.barra(t, 142, 612 + i * 24, 280, 13, (0.8, 0.55, 0.9)[i], cor)
    # atalhos (alto à direita)
    s.painel(t, 900, 16, 360, 64)
    for i in range(4):
        s.botao(t, 912 + i * 86, 26, 76, 44, "ativo" if i == 3 else "normal")
    # janela de personagem
    s.painel(t, 380, 90, 660, 450)
    traco(t, 408, 116, 230, 14, s.titulo)
    for i, tipo in enumerate(("ativo", "normal", "normal")):
        s.botao(t, 408 + i * 176, 148, 164, 42, tipo)
    for i in range(4):
        s.espaco(t, 412 + (i % 2) * 118, 214 + (i // 2) * 118, 104)
    for i in range(6):
        traco(t, 680, 222 + i * 30, 70, 7, s.texto2)
        traco(t, 900, 222 + i * 30, 90 - i * 8, 7, s.texto)
    s.botao(t, 800, 470, 210, 48, "principal")
    t.salvar(caminho)
    return t


def main():
    op = argumentos({"saida": "build/ui/estilos"})
    saida = os.path.abspath(op["saida"])
    os.makedirs(saida, exist_ok=True)
    prancha = Tela(W, H)
    prancha.alfa[:] = 1
    for i, estilo in enumerate((Elegante(), Pergaminho(), Pedra(), Limpo())):
        t = cena(estilo, os.path.join(saida, f"estilo{i + 1}.png"))
        # reduz à metade para a prancha 2 x 2
        prancha.rgb[(i // 2) * 360:(i // 2) * 360 + 360, (i % 2) * 640:(i % 2) * 640 + 640] = t.rgb[::2, ::2]
        print("[ui_estilos]", estilo.nome)
    prancha.salvar(os.path.join(saida, "prancha.png"))


if __name__ == "__main__":
    main()
