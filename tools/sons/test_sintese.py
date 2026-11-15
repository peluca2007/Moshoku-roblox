"""Testes do gerador de sons: python -m unittest discover tools/sons (ou
python tools/sons/test_sintese.py). Biblioteca padrão apenas."""

import math
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar  # noqa: E402
import sintese as s  # noqa: E402

LIMITE_PICO = 10 ** (-3.0 / 20) + 0.002  # -3 dBFS com tolerância de quantização


class BlocosTest(unittest.TestCase):
    def test_oscilador_frequencia(self):
        x = s.oscilador(441.0, 1.0)
        cruzamentos = sum(1 for a, b in zip(x, x[1:]) if a < 0 <= b)
        self.assertAlmostEqual(cruzamentos, 441, delta=2)

    def test_normalizar_pico(self):
        y = s.normalizar([0.1, -0.2, 0.05])
        self.assertAlmostEqual(s.dbfs(s.pico(y)), -3.0, places=3)

    def test_fade_zera_pontas(self):
        y = s.fade([1.0] * 4410)
        self.assertEqual(y[0], 0.0)
        self.assertEqual(y[-1], 0.0)
        self.assertAlmostEqual(y[2205], 1.0)

    def test_passa_baixa_reduz_agudos(self):
        r = s.novo_rng(1)
        ruido = s.ruido_branco(0.5, r)
        baixo = s.passa_baixa(ruido, 300)
        alto = s.passa_alta(ruido, 300)
        self.assertLess(s.rms(baixo), s.rms(ruido))
        # derivada (agudos) bem menor no filtrado
        def agudeza(x):
            return s.rms([b - a for a, b in zip(x, x[1:])])
        self.assertLess(agudeza(baixo), agudeza(alto))

    def test_decaimento_e_adsr(self):
        env = s.adsr(1.0, 0.1, 0.1, 0.5, 0.2)
        self.assertEqual(len(env), s.TAXA)
        self.assertAlmostEqual(env[-1], 0.0, places=3)
        self.assertLess(s.decaimento(1.0, 0.1)[-1], 0.001)

    def test_mixar_corta_no_fim(self):
        buf = s.mixar(0.01, [([1.0] * 1000, 1.0, 0.005)])
        self.assertEqual(len(buf), s.amostras(0.01))

    def test_wav_ida_e_volta(self):
        with tempfile.TemporaryDirectory() as d:
            caminho = os.path.join(d, "t.wav")
            s.escrever_wav(caminho, s.oscilador(220.0, 0.1))
            dados, taxa, canais, largura = s.ler_wav(caminho)
            self.assertEqual((taxa, canais, largura), (44100, 1, 2))
            self.assertEqual(len(dados), s.amostras(0.1))


class CatalogoTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sinais = {it["nome"]: gerar.sintetizar(it, 1)[0] for it in gerar.CATALOGO}

    def test_nomes_unicos_e_categorias(self):
        nomes = [i["nome"] for i in gerar.CATALOGO]
        self.assertEqual(len(nomes), len(set(nomes)))
        self.assertEqual({i["categoria"] for i in gerar.CATALOGO},
                         {"interface", "progresso", "movimento", "combate",
                          "magia", "expedicao", "criatura"})

    def test_duracao_exata(self):
        for it in gerar.CATALOGO:
            with self.subTest(som=it["nome"]):
                self.assertEqual(len(self.sinais[it["nome"]]), s.amostras(it["duracao"]))

    def test_duracoes_dentro_das_faixas(self):
        for it in gerar.CATALOGO:
            with self.subTest(som=it["nome"]):
                if it["categoria"] == "interface":
                    self.assertLessEqual(it["duracao"], 0.5)
                elif it.get("laco"):
                    self.assertTrue(8 <= it["duracao"] <= 15)
                else:
                    self.assertLessEqual(it["duracao"], 3.0)

    def test_sem_clipping_e_pico_alvo(self):
        for nome, x in self.sinais.items():
            with self.subTest(som=nome):
                self.assertLessEqual(s.pico(x), LIMITE_PICO)
                self.assertGreater(s.pico(x), LIMITE_PICO - 0.02)

    def test_sem_silencio_total(self):
        for nome, x in self.sinais.items():
            with self.subTest(som=nome):
                self.assertGreater(s.rms(x), 0.005)

    def test_pontas_sem_estalo(self):
        for it in gerar.CATALOGO:
            x = self.sinais[it["nome"]]
            with self.subTest(som=it["nome"]):
                self.assertLess(abs(x[0]), 0.005)
                self.assertLess(abs(x[-1]), 0.005)

    def test_lacos_comecam_e_terminam_em_zero(self):
        lacos = [i for i in gerar.CATALOGO if i.get("laco")]
        self.assertGreaterEqual(len(lacos), 2)
        for it in lacos:
            x = self.sinais[it["nome"]]
            with self.subTest(som=it["nome"]):
                self.assertLess(max(abs(v) for v in x[:20]), 0.005)
                self.assertLess(max(abs(v) for v in x[-20:]), 0.005)

    def test_variacoes_diferem(self):
        it = next(i for i in gerar.CATALOGO if i["nome"] == "impacto-leve")
        a, _ = gerar.sintetizar(it, 1)
        b, _ = gerar.sintetizar(it, 2)
        self.assertNotEqual(a, b)

    def test_mesma_semente_mesmo_arquivo(self):
        escolhidos = [i for i in gerar.CATALOGO
                      if i["nome"] in ("clique", "moedas", "passo-agua", "rolar-dado", "rosnado")]
        with tempfile.TemporaryDirectory() as d1, tempfile.TemporaryDirectory() as d2:
            for it in escolhidos:
                gerar.gerar_item(it, d1)
                gerar.gerar_item(it, d2)
            for it in escolhidos:
                for n in range(1, gerar.VARIACOES + 1):
                    rel = os.path.join(it["categoria"], "%s-%d.wav" % (it["nome"], n))
                    with open(os.path.join(d1, rel), "rb") as f1, open(os.path.join(d2, rel), "rb") as f2:
                        self.assertEqual(f1.read(), f2.read(), rel)

    def test_arquivo_gerado_abre(self):
        it = gerar.CATALOGO[0]
        with tempfile.TemporaryDirectory() as d:
            ent = gerar.gerar_item(it, d)
            self.assertEqual(len(ent), gerar.VARIACOES)
            dados, taxa, canais, largura = s.ler_wav(os.path.join(d, ent[0]["arquivo"]))
            self.assertEqual((taxa, canais, largura), (44100, 1, 2))
            self.assertAlmostEqual(len(dados) / taxa, it["duracao"], places=2)


if __name__ == "__main__":
    unittest.main()
