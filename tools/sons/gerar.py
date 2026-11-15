"""Gerador local de efeitos sonoros sintéticos (SOM1a).

Uso:
    python tools/sons/gerar.py              gera tudo em build/sons/
    python tools/sons/gerar.py --so clique  gera um som só
    python tools/sons/gerar.py --lista      lista o catálogo

Cada som tem 3 variações; semente = crc32(nome) + n, então a saída é
reproduzível byte a byte. Só biblioteca padrão. Nada é enviado a lugar
nenhum: a saída fica em build/sons (pasta não versionada).
"""

import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sintese as s  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA_PADRAO = os.path.join(RAIZ, "build", "sons")
ORIGEM = "gerado localmente por tools/sons/gerar.py"
VARIACOES = 3

# Notas (Hz) de uma escala pentatônica menor em Lá, para tons suaves.
A3, C4, D4, E4, G4, A4, C5, D5, E5, G5, A5 = (
    220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0)


# --- peças reutilizáveis das receitas ---------------------------------------

def jit(rng, base, frac=0.05):
    """Valor `base` com variação de ±frac (cada variação soa um pouco diferente)."""
    return base * (1.0 + rng.uniform(-frac, frac))


def dedilhado(freq, dur, tau, harm=((1, 1.0), (2, 0.35), (3, 0.12), (4, 0.05))):
    """Nota de alaúde/harpa: harmônicos suaves e queda exponencial."""
    return s.multiplicar(s.oscilador(freq, dur, harm), s.decaimento(dur, tau, 0.003))


def sino(freq, dur, tau):
    """Sino/metal: parciais inarmônicas, as altas decaem mais rápido."""
    razoes = ((1.0, 1.0), (2.32, 0.55), (3.87, 0.35), (5.43, 0.2), (7.1, 0.1))
    return s.parciais([(freq * r, a) for r, a in razoes], dur,
                      [tau / (1.0 + 0.6 * i) for i in range(len(razoes))])


def toque_madeira(rng, dur, freq, tau=0.03, q=9.0):
    """Estalo de madeira: ruído curto passando por ressoador."""
    ruido = s.ruido_branco(dur, rng)
    estalo = s.multiplicar(ruido, s.decaimento(dur, tau * 0.35, 0.0005))
    corpo = s.ressoador(estalo, freq, q)
    return s.multiplicar(corpo, s.decaimento(dur, tau, 0.0005))


def sopro(rng, dur, f_baixa, f_alta, env):
    return s.multiplicar(s.passa_banda(s.ruido_branco(dur, rng), f_baixa, f_alta), env)


def baque(freq_ini, freq_fim, dur, tau):
    """Senoide grave com queda de afinação (batida em couro/madeira)."""
    f = s.rampa(freq_ini, freq_fim, dur, 0.5)
    return s.multiplicar(s.oscilador(f, dur), s.decaimento(dur, tau, 0.002))


# --- receitas: interface ----------------------------------------------------

def r_clique(rng, dur):
    estalo = toque_madeira(rng, dur, jit(rng, 1900), 0.018, 7.0)
    corpo = baque(jit(rng, 700), 500, dur, 0.02)
    return s.mixar(dur, [(estalo, 1.0, 0.0), (corpo, 0.4, 0.0)])


def r_passar_mouse(rng, dur):
    env = s.sino_env(dur, 1, 2)
    return sopro(rng, dur, jit(rng, 2500), 5200, env)


def r_abrir_painel(rng, dur):
    n = s.amostras(dur)
    varre = s.rampa(500, jit(rng, 3500), dur, 1.5)
    ruido = s.passa_baixa(s.ruido_branco(dur, rng), varre)
    ruido = s.passa_alta(ruido, 300)
    # papel: ruído "amassado" por amplitude irregular
    amassa = s.passa_baixa([rng.uniform(0, 1) ** 3 for _ in range(n)], 90)
    amassa = [0.35 + 2.2 * v for v in amassa]
    env = s.sino_env(dur, 1, 1.4)
    return s.multiplicar(s.multiplicar(ruido, amassa), env)


def r_fechar_painel(rng, dur):
    n = s.amostras(dur)
    varre = s.rampa(jit(rng, 3000), 450, dur, 0.8)
    ruido = s.passa_alta(s.passa_baixa(s.ruido_branco(dur, rng), varre), 300)
    amassa = s.passa_baixa([rng.uniform(0, 1) ** 3 for _ in range(n)], 90)
    amassa = [0.35 + 2.2 * v for v in amassa]
    env = s.sino_env(dur, 1, 2.5)
    papel = s.multiplicar(s.multiplicar(ruido, amassa), env)
    toque = toque_madeira(rng, 0.05, 1100, 0.02, 6.0)
    return s.mixar(dur, [(papel, 1.0, 0.0), (toque, 0.5, dur * 0.7)])


def r_confirmar(rng, dur):
    f1 = jit(rng, E4, 0.02)
    return s.mixar(dur, [(dedilhado(f1, dur, 0.09), 0.8, 0.0),
                         (dedilhado(f1 * 1.5, dur, 0.12), 1.0, 0.09)])


def r_negar(rng, dur):
    def toque(f, atraso):
        return (s.mixar(0.2, [(baque(f * 1.3, f, 0.2, 0.05), 1.0, 0.0),
                              (toque_madeira(rng, 0.2, f * 2.2, 0.03), 0.5, 0.0)]),
                atraso)
    a, ta = toque(jit(rng, 170), 0.0)
    b, tb = toque(jit(rng, 170) * 0.89, 0.15)  # segunda grave, um tom abaixo
    return s.mixar(dur, [(a, 1.0, ta), (b, 0.9, tb)])


def r_aviso(rng, dur):
    f = jit(rng, A4, 0.02)
    return s.mixar(dur, [(sino(f, dur, 0.18), 0.8, 0.0),
                         (sino(f, dur - 0.18, 0.18), 0.8, 0.18)])


def r_virar_pagina(rng, dur):
    n = s.amostras(dur)
    ruido = s.passa_banda(s.ruido_branco(dur, rng), 800, jit(rng, 4500))
    voo = s.sino_env(dur, 1.0, 1.6)
    tremor = [0.65 + 0.35 * math.sin(2 * math.pi * 38 * i / s.TAXA + rng.uniform(0, 6))
              for i in range(n)]
    return s.multiplicar(s.multiplicar(ruido, voo), tremor)


# --- progresso --------------------------------------------------------------

def r_moedas(rng, dur):
    camadas = []
    t = 0.0
    for _ in range(rng.choice((2, 3))):
        f = jit(rng, rng.choice((2400, 2750, 3100)), 0.04)
        d = 0.4
        # dois tilintos por moeda: fundamental e uma segunda batida levemente acima
        moeda = s.mixar(d, [(sino(f, d, 0.07), 1.0, 0.0),
                            (sino(f * 1.34, d, 0.05), 0.6, 0.018)])
        camadas.append((moeda, rng.uniform(0.7, 1.0), t))
        t += rng.uniform(0.07, 0.15)
    return s.mixar(dur, camadas)


def r_recompensa(rng, dur):
    notas = (C5, E5, G5, C5 * 2)
    camadas = []
    for i, f in enumerate(notas):
        camadas.append((dedilhado(jit(rng, f, 0.003), 0.7, 0.22), 0.8, i * 0.1))
    camadas.append((sino(C5 * 2, dur - 0.3, 0.35), 0.5, 0.3))
    return s.reverb_leve(s.mixar(dur, camadas), 0.2, 0.0)[:s.amostras(dur)]


def r_subir_nivel(rng, dur):
    notas = (A4, C5, E5, A5)
    camadas = []
    for i, f in enumerate(notas):
        camadas.append((dedilhado(f, 1.0, 0.3), 0.7, i * 0.13))
        camadas.append((sino(f * 2, 0.9, 0.25), 0.18, i * 0.13))
    # acorde final sustentado, com batimento leve entre vozes
    for f, d in ((A4, 0.0), (A4 * 1.003, 0.0), (E5, 0.0), (A5, 0.0)):
        camadas.append((dedilhado(f, dur - 0.55, 0.6), 0.45, 0.55))
    return s.mixar(dur, camadas)


def r_missao_concluida(rng, dur):
    def sopro_nota(f, d):
        harm = tuple((k, 1.0 / k) for k in range(1, 7))
        onda = s.oscilador(f, d, harm)
        onda = s.passa_baixa(onda, 1500)
        return s.multiplicar(onda, s.adsr(d, 0.06, 0.1, 0.7, 0.25))
    camadas = [(sopro_nota(G4, 0.45), 0.6, 0.0),
               (sopro_nota(C5, 0.45), 0.6, 0.4),
               (sopro_nota(E5, 1.0), 0.6, 0.8),
               (sopro_nota(G4, 1.0), 0.4, 0.8),
               (sopro_nota(C5, 1.0), 0.4, 0.8),
               (sino(C5, 1.0, 0.5), 0.3, 0.8)]
    return s.reverb_leve(s.mixar(dur, camadas), 0.25, 0.0)[:s.amostras(dur)]


# --- movimento --------------------------------------------------------------

def _passo(rng, dur, f_corte, f_corpo, tau_corpo, arranhao):
    batida = s.multiplicar(s.passa_baixa(s.ruido_branco(dur, rng), f_corte),
                           s.decaimento(dur, 0.035, 0.001))
    corpo = baque(jit(rng, f_corpo), f_corpo * 0.6, dur, tau_corpo)
    areia = s.multiplicar(s.passa_alta(s.ruido_branco(dur, rng), 2500),
                          s.decaimento(dur, 0.05, 0.01))
    return s.mixar(dur, [(batida, 1.0, 0.0), (corpo, 0.7, 0.0),
                         (areia, arranhao, 0.02)])


def r_passo_pedra(rng, dur):
    p = _passo(rng, dur, jit(rng, 1800), 200, 0.06, 0.18)
    clic = toque_madeira(rng, 0.05, jit(rng, 1500), 0.012, 5.0)
    return s.mixar(dur, [(p, 1.0, 0.0), (clic, 0.5, 0.0)])


def r_passo_terra(rng, dur):
    return _passo(rng, dur, jit(rng, 700), 120, 0.07, 0.35)


def r_passo_agua(rng, dur):
    n = s.amostras(dur)
    chap = s.multiplicar(s.passa_banda(s.ruido_branco(dur, rng), 500, 2800),
                         s.sino_env(dur, 1, 3))
    camadas = [(chap, 0.7, 0.0)]
    for _ in range(rng.randint(3, 5)):  # bolhas: senoides que sobem rápido
        f0 = rng.uniform(500, 900)
        d = rng.uniform(0.04, 0.08)
        b = s.multiplicar(s.oscilador(s.rampa(f0, f0 * 2.2, d), d), s.decaimento(d, d * 0.4, 0.004))
        camadas.append((b, rng.uniform(0.2, 0.45), rng.uniform(0.02, dur * 0.7)))
    pata = baque(150, 90, dur, 0.05)
    camadas.append((pata, 0.5, 0.0))
    return s.mixar(dur, camadas)


# --- combate ----------------------------------------------------------------

def _swish(rng, dur, f_ini, f_pico, f_fim, grossura):
    n = s.amostras(dur)
    metade = n // 2
    varre = ([f_ini + (f_pico - f_ini) * (i / metade) for i in range(metade)]
             + [f_pico + (f_fim - f_pico) * (i / (n - metade)) for i in range(n - metade)])
    ruido = s.passa_baixa(s.ruido_branco(dur, rng), varre)
    ruido = s.passa_alta(ruido, grossura)
    return s.multiplicar(ruido, s.sino_env(dur, 1.0, 1.2))


def r_golpe_ar(rng, dur):
    return _swish(rng, dur, 500, jit(rng, 3200), 900, 350)


def r_impacto_leve(rng, dur):
    thud = baque(jit(rng, 190), 80, dur, 0.07)
    carne = s.multiplicar(s.passa_baixa(s.ruido_branco(dur, rng), 2200),
                          s.decaimento(dur, 0.03, 0.0008))
    return s.mixar(dur, [(thud, 1.0, 0.0), (carne, 0.9, 0.0)])


def r_impacto_pesado(rng, dur):
    thud = baque(jit(rng, 95), 38, dur, 0.28)
    rachado = s.multiplicar(s.passa_baixa(s.ruido_branco(dur, rng), 900),
                            s.decaimento(dur, 0.12, 0.001))
    estalo = s.multiplicar(s.passa_alta(s.ruido_branco(dur, rng), 1500),
                           s.decaimento(dur, 0.02, 0.0005))
    ronco = s.multiplicar(s.passa_baixa(s.ruido_branco(dur, rng), 160),
                          s.decaimento(dur, 0.45, 0.01))
    return s.mixar(dur, [(thud, 1.0, 0.0), (rachado, 0.8, 0.0),
                         (estalo, 0.35, 0.0), (ronco, 0.8, 0.02)])


def r_bloqueio(rng, dur):
    f = jit(rng, 1150, 0.08)
    metal = sino(f, dur, 0.28)
    raspa = s.multiplicar(s.passa_alta(s.ruido_branco(dur, rng), 3000),
                          s.decaimento(dur, 0.025, 0.0005))
    batida = baque(400, 220, dur, 0.03)
    return s.mixar(dur, [(metal, 0.8, 0.0), (raspa, 0.7, 0.0), (batida, 0.5, 0.0)])


def r_esquiva(rng, dur):
    return _swish(rng, dur, 900, jit(rng, 4200), 2200, 800)


def r_queda_corpo(rng, dur):
    thud = baque(130, 45, dur, 0.18)
    pano = s.multiplicar(s.passa_banda(s.ruido_branco(dur, rng), 300, 2000),
                         s.sino_env(dur, 1, 4))
    ronco = s.multiplicar(s.passa_baixa(s.ruido_branco(dur, rng), 250),
                          s.decaimento(dur, 0.25, 0.01))
    segundo = baque(100, 50, 0.3, 0.07)
    return s.mixar(dur, [(thud, 1.0, 0.0), (pano, 0.35, 0.0),
                         (ronco, 0.7, 0.0), (segundo, 0.4, 0.28)])


def r_rolar_dado(rng, dur):
    camadas = []
    t = 0.0
    passo = 0.22
    amp = 1.0
    while t < dur - 0.2 and passo > 0.02:
        f = jit(rng, rng.choice((850, 1000, 1150)), 0.1)
        camadas.append((toque_madeira(rng, 0.12, f, 0.025, 8.0), amp, t))
        t += passo * rng.uniform(0.85, 1.15)
        passo *= 0.74
        amp *= 0.82
    # chocalhar final do dado parando, e uma batida de assentamento
    camadas.append((toque_madeira(rng, 0.15, 700, 0.04, 6.0), 0.35, t + 0.02))
    return s.mixar(dur, camadas)


# --- magia ------------------------------------------------------------------

def r_conjurar(rng, dur):
    n = s.amostras(dur)
    f = s.rampa(jit(rng, 260), jit(rng, 880), dur, 1.6)
    tom = s.oscilador(f, dur, ((1, 1.0), (2, 0.3), (3, 0.1)))
    trem = [0.8 + 0.2 * math.sin(2 * math.pi * 6.0 * i / s.TAXA) for i in range(n)]
    tom = s.multiplicar(s.multiplicar(tom, trem), s.sino_env(dur, 2.2, 1.0))
    ar = s.multiplicar(s.passa_alta(s.ruido_branco(dur, rng), 3500), s.sino_env(dur, 2.2, 1.0))
    return s.mixar(dur, [(tom, 1.0, 0.0), (ar, 0.25, 0.0)])


def r_impacto_magico(rng, dur):
    estouro = s.multiplicar(s.passa_banda(s.ruido_branco(dur, rng), 400, 4500),
                            s.decaimento(dur, 0.12, 0.002))
    grave = baque(jit(rng, 140), 55, dur, 0.2)
    brilho = [(sino(jit(rng, f, 0.03), dur, 0.35), 0.18, 0.02 * i)
              for i, f in enumerate((1200, 1800, 2700))]
    sinal = s.mixar(dur, [(estouro, 0.9, 0.0), (grave, 1.0, 0.0)] + brilho)
    return s.reverb_leve(sinal, 0.25, 0.0)[:s.amostras(dur)]


def r_cura(rng, dur):
    camadas = []
    notas = (A4, C5, E5, G5, A5)
    for i, f in enumerate(notas):
        d = dur - 0.14 * i
        par = s.mixar(d, [(s.oscilador(f, d, ((1, 1), (2, 0.15))), 0.5, 0.0),
                          (s.oscilador(f + 1.8, d, ((1, 1), (2, 0.15))), 0.5, 0.0)])  # batimento
        camadas.append((s.multiplicar(par, s.sino_env(d, 1, 2.5)), 0.5, 0.14 * i))
    cintilar = s.multiplicar(s.passa_alta(s.ruido_branco(dur, rng), 6000), s.sino_env(dur, 1, 1.5))
    camadas.append((cintilar, 0.06, 0.0))
    return s.reverb_leve(s.mixar(dur, camadas), 0.2, 0.0)[:s.amostras(dur)]


def r_escudo(rng, dur):
    n = s.amostras(dur)
    zumbido = s.mixar(dur, [(s.oscilador(220.0, dur, ((1, 1), (2, 0.4), (3, 0.2))), 0.5, 0.0),
                            (s.oscilador(223.5, dur, ((1, 1), (2, 0.4), (3, 0.2))), 0.5, 0.0)])
    zumbido = s.multiplicar(zumbido, s.sino_env(dur, 1.0, 1.3))
    toque = sino(jit(rng, 660, 0.03), dur, 0.3)
    onda = s.multiplicar(s.passa_banda(s.ruido_branco(dur, rng), 600, 3000), s.sino_env(dur, 1, 3))
    return s.mixar(dur, [(zumbido, 0.9, 0.0), (toque, 0.35, 0.0), (onda, 0.3, 0.0)])


# --- expedição --------------------------------------------------------------

def r_porta_pedra(rng, dur):
    n = s.amostras(dur)
    arrasto = s.passa_baixa(s.ruido_branco(dur, rng), 420)
    # arranque e solta (stick-slip): amplitude lenta e irregular
    irregular = s.passa_baixa([rng.uniform(0, 1) for _ in range(n)], 9)
    irregular = [0.4 + 3.0 * v for v in irregular]
    arrasto = s.multiplicar(s.multiplicar(arrasto, irregular), s.adsr(dur, 0.3, 0.2, 0.85, 0.9))
    ronco = s.multiplicar(s.oscilador(jit(rng, 48), dur, ((1, 1), (2, 0.5))),
                          s.adsr(dur, 0.4, 0.2, 0.8, 0.8))
    batida = baque(80, 35, 0.7, 0.2)
    poeira = s.multiplicar(s.passa_alta(s.ruido_branco(dur, rng), 3000), s.adsr(dur, 0.5, 0.3, 0.3, 1.0))
    return s.mixar(dur, [(arrasto, 1.0, 0.0), (ronco, 0.5, 0.0),
                         (poeira, 0.08, 0.0), (batida, 0.8, dur * 0.82)])


def r_fogueira(rng, dur):
    n = s.amostras(dur)
    base = s.passa_baixa(s.ruido_branco(dur, rng), 450)
    ondula = s.passa_baixa([rng.uniform(0, 1) for _ in range(n)], 3)
    ondula = [0.5 + 3.0 * v for v in ondula]
    base = s.multiplicar(base, ondula)
    chama = s.multiplicar(s.passa_banda(s.ruido_branco(dur, rng), 1200, 3500), ondula)
    buf = s.mixar(dur, [(base, 1.0, 0.0), (chama, 0.1, 0.0)])
    t = 0.0
    while t < dur - 0.1:  # estalos de lenha: ~12 por segundo, irregulares
        d = rng.uniform(0.006, 0.03)
        est = s.multiplicar(s.passa_alta(s.ruido_branco(d, rng), rng.uniform(1500, 3500)),
                            s.decaimento(d, d * 0.35, 0.0005))
        s.colocar(buf, est, t, rng.uniform(0.15, 1.1) ** 2 * 2.0)
        t += rng.expovariate(12.0)
    return buf


def r_gotejar(rng, dur):
    buf = [0.0] * s.amostras(dur)
    s.colocar(buf, s.multiplicar(s.passa_baixa(s.ruido_branco(dur, rng), 300), [0.02] * s.amostras(dur)), 0.0)
    t = rng.uniform(0.2, 0.6)
    while t < dur - 1.0:
        f = rng.uniform(900, 1700)
        d = 0.25
        gota = s.multiplicar(s.oscilador(s.rampa(f, f * 1.7, d, 0.7), d), s.decaimento(d, 0.035, 0.001))
        gota = s.mixar(d + 0.6, [(gota, 1.0, 0.0), (s.ressoador(gota, 600, 4.0), 0.5, 0.0)])
        gota = s.eco(gota, 0.13, 0.45, 0.4, 0.5)
        s.colocar(buf, gota, t, rng.uniform(0.35, 0.9))
        t += rng.uniform(0.8, 2.2)
    return buf


def r_viajando(rng, dur):
    n = s.amostras(dur)
    lento = [math.sin(2 * math.pi * 0.6 * i / s.TAXA + rng.uniform(0, 1)) for i in range(n)]
    corte = [600 + 450 * v for v in lento]
    vento = s.passa_baixa(s.ruido_branco(dur, rng), corte)
    assobio = s.passa_banda(s.ruido_branco(dur, rng), 900, 1400)
    assobio = s.multiplicar(assobio, [0.2 + 0.8 * abs(v) for v in lento])
    return s.multiplicar(s.mixar(dur, [(vento, 1.0, 0.0), (assobio, 0.4, 0.0)]),
                         s.sino_env(dur, 1.0, 1.0))


# --- criatura ---------------------------------------------------------------

def r_rato_guincho(rng, dur):
    camadas = []
    for i in range(2):
        d = 0.12
        f0 = jit(rng, 2800, 0.06)
        f = [f0 * (1 + 0.4 * math.sin(math.pi * k / max(1, s.amostras(d) - 1))) for k in range(s.amostras(d))]
        voz = s.oscilador(f, d, ((1, 1.0), (2, 0.45), (3, 0.2)))
        trem = [0.7 + 0.3 * math.sin(2 * math.pi * 45 * k / s.TAXA) for k in range(len(voz))]
        voz = s.multiplicar(s.multiplicar(voz, trem), s.sino_env(d, 1, 1.5))
        camadas.append((voz, 1.0 - 0.25 * i, i * 0.14))
    return s.mixar(dur, camadas)


def r_rosnado(rng, dur):
    n = s.amostras(dur)
    f = [jit(rng, 68, 0.03) * (1 + 0.04 * math.sin(2 * math.pi * 3 * i / s.TAXA)) for i in range(n)]
    harm = tuple((k, 1.0 / k) for k in range(1, 13))
    voz = s.passa_baixa(s.oscilador(f, dur, harm), 550)
    rouco = [0.5 + 0.5 * math.sin(2 * math.pi * 26 * i / s.TAXA) for i in range(n)]
    voz = s.multiplicar(voz, rouco)
    ar = s.passa_baixa(s.ruido_branco(dur, rng), 700)
    return s.multiplicar(s.mixar(dur, [(voz, 1.0, 0.0), (ar, 0.5, 0.0)]),
                         s.adsr(dur, 0.15, 0.2, 0.8, 0.4))


# --- catálogo ---------------------------------------------------------------

CATALOGO = [
    # interface
    {"nome": "clique", "categoria": "interface", "duracao": 0.10, "receita": r_clique},
    {"nome": "passar-mouse", "categoria": "interface", "duracao": 0.10, "receita": r_passar_mouse},
    {"nome": "abrir-painel", "categoria": "interface", "duracao": 0.35, "receita": r_abrir_painel},
    {"nome": "fechar-painel", "categoria": "interface", "duracao": 0.30, "receita": r_fechar_painel},
    {"nome": "confirmar", "categoria": "interface", "duracao": 0.40, "receita": r_confirmar},
    {"nome": "negar", "categoria": "interface", "duracao": 0.40, "receita": r_negar},
    {"nome": "aviso", "categoria": "interface", "duracao": 0.50, "receita": r_aviso},
    {"nome": "virar-pagina", "categoria": "interface", "duracao": 0.45, "receita": r_virar_pagina},
    # progresso
    {"nome": "moedas", "categoria": "progresso", "duracao": 0.90, "receita": r_moedas},
    {"nome": "recompensa", "categoria": "progresso", "duracao": 1.30, "receita": r_recompensa},
    {"nome": "subir-nivel", "categoria": "progresso", "duracao": 2.00, "receita": r_subir_nivel},
    {"nome": "missao-concluida", "categoria": "progresso", "duracao": 2.50, "receita": r_missao_concluida},
    # movimento
    {"nome": "passo-pedra", "categoria": "movimento", "duracao": 0.30, "receita": r_passo_pedra},
    {"nome": "passo-terra", "categoria": "movimento", "duracao": 0.30, "receita": r_passo_terra},
    {"nome": "passo-agua", "categoria": "movimento", "duracao": 0.50, "receita": r_passo_agua},
    # combate
    {"nome": "golpe-no-ar", "categoria": "combate", "duracao": 0.35, "receita": r_golpe_ar},
    {"nome": "impacto-leve", "categoria": "combate", "duracao": 0.35, "receita": r_impacto_leve},
    {"nome": "impacto-pesado", "categoria": "combate", "duracao": 1.20, "receita": r_impacto_pesado},
    {"nome": "bloqueio", "categoria": "combate", "duracao": 0.90, "receita": r_bloqueio},
    {"nome": "esquiva", "categoria": "combate", "duracao": 0.30, "receita": r_esquiva},
    {"nome": "queda-corpo", "categoria": "combate", "duracao": 1.40, "receita": r_queda_corpo},
    {"nome": "rolar-dado", "categoria": "combate", "duracao": 2.00, "receita": r_rolar_dado},
    # magia
    {"nome": "conjurar", "categoria": "magia", "duracao": 1.20, "receita": r_conjurar},
    {"nome": "impacto-magico", "categoria": "magia", "duracao": 1.20, "receita": r_impacto_magico},
    {"nome": "cura", "categoria": "magia", "duracao": 1.40, "receita": r_cura},
    {"nome": "escudo", "categoria": "magia", "duracao": 1.00, "receita": r_escudo},
    # expedição
    {"nome": "porta-pedra", "categoria": "expedicao", "duracao": 3.00, "receita": r_porta_pedra},
    {"nome": "fogueira", "categoria": "expedicao", "duracao": 12.0, "receita": r_fogueira, "laco": True},
    {"nome": "gotejar-esgoto", "categoria": "expedicao", "duracao": 10.0, "receita": r_gotejar, "laco": True},
    {"nome": "viajando", "categoria": "expedicao", "duracao": 2.50, "receita": r_viajando},
    # criatura
    {"nome": "rato-guincho", "categoria": "criatura", "duracao": 0.30, "receita": r_rato_guincho},
    {"nome": "rosnado", "categoria": "criatura", "duracao": 1.20, "receita": r_rosnado},
]


def sintetizar(item, variacao):
    """Gera o sinal final (já com fade e pico em -3 dBFS) e devolve (sinal, semente)."""
    semente = s.semente_de(item["nome"], variacao)
    rng = s.novo_rng(semente)
    bruto = item["receita"](rng, item["duracao"])
    alvo = s.amostras(item["duracao"])
    bruto = (list(bruto) + [0.0] * alvo)[:alvo]  # duração exata do catálogo
    return s.acabar(bruto, item.get("laco", False)), semente


def gerar_item(item, pasta_saida):
    """Escreve as variações de um som; devolve as entradas do manifesto."""
    destino = os.path.join(pasta_saida, item["categoria"])
    os.makedirs(destino, exist_ok=True)
    entradas = []
    for n in range(1, VARIACOES + 1):
        sinal, semente = sintetizar(item, n)
        arquivo = "%s-%d.wav" % (item["nome"], n)
        s.escrever_wav(os.path.join(destino, arquivo), sinal)
        entradas.append({
            "nome": item["nome"],
            "categoria": item["categoria"],
            "variacao": n,
            "arquivo": "%s/%s" % (item["categoria"], arquivo),
            "duracao": round(len(sinal) / s.TAXA, 3),
            "pico_dbfs": round(s.dbfs(s.pico(sinal)), 2),
            "laco": bool(item.get("laco", False)),
            "semente": semente,
            "origem": ORIGEM,
        })
    return entradas


def main(argv=None):
    ap = argparse.ArgumentParser(description="Gera efeitos sonoros sintéticos locais.")
    ap.add_argument("--so", metavar="NOME", help="gera apenas este som")
    ap.add_argument("--lista", action="store_true", help="lista o catálogo e sai")
    ap.add_argument("--saida", default=SAIDA_PADRAO, help="pasta de saída (padrão build/sons)")
    args = ap.parse_args(argv)

    if args.lista:
        for it in CATALOGO:
            print("%-10s %-18s %5.2f s%s" % (it["categoria"], it["nome"], it["duracao"],
                                             "  (laço)" if it.get("laco") else ""))
        return 0

    itens = CATALOGO
    if args.so:
        itens = [i for i in CATALOGO if i["nome"] == args.so]
        if not itens:
            print("som desconhecido: %s (use --lista)" % args.so, file=sys.stderr)
            return 2

    os.makedirs(args.saida, exist_ok=True)
    manifesto = []
    for it in itens:
        manifesto += gerar_item(it, args.saida)
        print("ok %s/%s" % (it["categoria"], it["nome"]))

    caminho = os.path.join(args.saida, "manifesto.json")
    if args.so and os.path.exists(caminho):  # preserva as outras entradas
        with open(caminho, encoding="utf-8") as f:
            antigo = [e for e in json.load(f) if e["nome"] != args.so]
        manifesto = sorted(antigo + manifesto, key=lambda e: (e["categoria"], e["nome"], e["variacao"]))
    with open(caminho, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifesto, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("manifesto: %s (%d arquivos)" % (caminho, len(manifesto)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
