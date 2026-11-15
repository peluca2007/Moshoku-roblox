"""Blocos de síntese sonora em Python puro (biblioteca padrão).

Sinais são listas de floats em [-1, 1] a 44,1 kHz, mono. Nada aqui usa
numpy nem rede. Quem precisa de aleatoriedade recebe um `random.Random`
com semente, para a saída ser reproduzível byte a byte.
"""

import array
import math
import random
import struct
import wave

TAXA = 44100
PICO_DBFS = -3.0
DOIS_PI = 2.0 * math.pi


# --- tempo e curvas ---------------------------------------------------------

def amostras(dur):
    return max(1, int(round(dur * TAXA)))


def rampa(a, b, dur, curva=1.0):
    """Lista de valores de a até b; curva>1 demora a sair de a."""
    n = amostras(dur)
    if n == 1:
        return [a]
    return [a + (b - a) * ((i / (n - 1)) ** curva) for i in range(n)]


# --- osciladores ------------------------------------------------------------

def oscilador(freq, dur, harmonicos=((1, 1.0),), fase=0.0):
    """Soma de senoides harmônicas. `freq` é número ou lista (um valor por
    amostra, para glissando/vibrato). `harmonicos` = ((múltiplo, amplitude),...).
    A saída é normalizada pela soma das amplitudes."""
    n = amostras(dur)
    soma = sum(abs(a) for _, a in harmonicos) or 1.0
    saida = [0.0] * n
    fase_atual = fase
    constante = not isinstance(freq, (list, tuple))
    passo_const = DOIS_PI * freq / TAXA if constante else 0.0
    for i in range(n):
        f = freq if constante else freq[min(i, len(freq) - 1)]
        s = 0.0
        for k, a in harmonicos:
            s += a * math.sin(k * fase_atual)
        saida[i] = s / soma
        fase_atual += passo_const if constante else DOIS_PI * f / TAXA
    return saida


def parciais(freqs_amps, dur, taus):
    """Soma de senoides inarmônicas, cada uma com decaimento exponencial
    próprio (sinos, metal). freqs_amps = ((hz, amp),...); taus = segundos."""
    n = amostras(dur)
    saida = [0.0] * n
    for (f, a), tau in zip(freqs_amps, taus):
        w = DOIS_PI * f / TAXA
        for i in range(n):
            t = i / TAXA
            saida[i] += a * math.sin(w * i) * math.exp(-t / tau)
    return saida


# --- ruído e filtros --------------------------------------------------------

def ruido_branco(dur, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(amostras(dur))]


def _coef(fc):
    return 1.0 - math.exp(-DOIS_PI * fc / TAXA)


def passa_baixa(x, fc):
    """Filtro de um polo. `fc` em Hz, número ou lista (varredura)."""
    saida = [0.0] * len(x)
    y = 0.0
    if isinstance(fc, (list, tuple)):
        for i, v in enumerate(x):
            y += _coef(fc[min(i, len(fc) - 1)]) * (v - y)
            saida[i] = y
    else:
        a = _coef(fc)
        for i, v in enumerate(x):
            y += a * (v - y)
            saida[i] = y
    return saida


def passa_alta(x, fc):
    """x menos o passa-baixa de mesma frequência."""
    baixa = passa_baixa(x, fc)
    return [v - b for v, b in zip(x, baixa)]


def passa_banda(x, f_baixa, f_alta):
    return passa_alta(passa_baixa(x, f_alta), f_baixa)


def ressoador(x, freq, q=8.0):
    """Biquad passa-banda (ganho de pico 0 dB). Dá corpo de madeira/metal."""
    w0 = DOIS_PI * freq / TAXA
    alfa = math.sin(w0) / (2.0 * q)
    a0 = 1.0 + alfa
    b0 = alfa / a0
    b2 = -alfa / a0
    a1 = -2.0 * math.cos(w0) / a0
    a2 = (1.0 - alfa) / a0
    x1 = x2 = y1 = y2 = 0.0
    saida = [0.0] * len(x)
    for i, v in enumerate(x):
        y = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, y
        saida[i] = y
    return saida


def eco(x, atraso, realim, mistura, extra=0.0):
    """Eco com realimentação (reverberação barata). `extra` = cauda em s."""
    d = max(1, int(atraso * TAXA))
    n = len(x) + int(extra * TAXA)
    buf = list(x) + [0.0] * (n - len(x))
    for i in range(d, n):
        buf[i] += realim * buf[i - d]
    return [(1 - mistura) * (x[i] if i < len(x) else 0.0) + mistura * buf[i]
            for i in range(n)]


def reverb_leve(x, mistura=0.25, cauda=0.3):
    """Três combs com atrasos primos entre si; só dá ambiente à sala."""
    n = len(x) + int(cauda * TAXA)
    base = list(x) + [0.0] * (n - len(x))
    soma = [0.0] * n
    for atraso, g in ((0.0297, 0.62), (0.0371, 0.58), (0.0437, 0.55)):
        d = int(atraso * TAXA)
        buf = list(base)
        for i in range(d, n):
            buf[i] += g * buf[i - d]
        for i in range(n):
            soma[i] += buf[i] / 3.0
    return [(1 - mistura) * base[i] + mistura * soma[i] for i in range(n)]


# --- envelopes --------------------------------------------------------------

def adsr(dur, ataque, decai, sustenta, solta):
    """ADSR; `solta` termina exatamente no fim de `dur`."""
    n = amostras(dur)
    a, d, r = (int(ataque * TAXA), int(decai * TAXA), int(solta * TAXA))
    r = min(r, n)
    inicio_r = n - r
    env = [0.0] * n
    for i in range(n):
        if i < a:
            v = i / max(1, a)
        elif i < a + d:
            v = 1.0 + (sustenta - 1.0) * ((i - a) / max(1, d))
        else:
            v = sustenta
        if i >= inicio_r:
            v *= 1.0 - (i - inicio_r) / max(1, r)
        env[i] = v
    return env


def decaimento(dur, tau, ataque=0.002):
    """Ataque linear curto e queda exponencial com constante `tau` (s)."""
    n = amostras(dur)
    a = max(1, int(ataque * TAXA))
    return [(min(1.0, i / a)) * math.exp(-(i / TAXA) / tau) for i in range(n)]


def sino_env(dur, subida, descida):
    """Envelope em sino (subida e descida em fração de seno)."""
    n = amostras(dur)
    pico = int(n * subida / (subida + descida))
    env = []
    for i in range(n):
        if i < pico:
            env.append(math.sin(0.5 * math.pi * i / max(1, pico)))
        else:
            env.append(math.cos(0.5 * math.pi * (i - pico) / max(1, n - pico)))
    return env


def multiplicar(x, env):
    return [v * env[min(i, len(env) - 1)] for i, v in enumerate(x)]


def ganho(x, g):
    return [v * g for v in x]


# --- mistura ----------------------------------------------------------------

def mixar(dur, camadas):
    """Soma camadas (sinal, ganho, atraso_em_s) num buffer de `dur` s.
    O que passar do fim é cortado."""
    n = amostras(dur)
    buf = [0.0] * n
    for sinal, g, atraso in camadas:
        ini = int(round(atraso * TAXA))
        for i, v in enumerate(sinal):
            j = ini + i
            if j >= n:
                break
            if j >= 0:
                buf[j] += v * g
    return buf


def colocar(buf, sinal, atraso, g=1.0):
    """Soma `sinal` em `buf` (no lugar) a partir de `atraso` s."""
    ini = int(round(atraso * TAXA))
    n = len(buf)
    for i, v in enumerate(sinal):
        j = ini + i
        if j >= n:
            break
        buf[j] += v * g


# --- acabamento -------------------------------------------------------------

def pico(x):
    return max((abs(v) for v in x), default=0.0)


def rms(x):
    return math.sqrt(sum(v * v for v in x) / len(x)) if x else 0.0


def dbfs(valor):
    return 20.0 * math.log10(valor) if valor > 0 else -math.inf


def remover_dc(x):
    m = sum(x) / len(x)
    return [v - m for v in x]


def fade(x, ms_ini=8.0, ms_fim=15.0):
    """Fade linear curto no início e no fim (evita estalos)."""
    n = len(x)
    ni = min(n, max(1, int(ms_ini * TAXA / 1000)))
    nf = min(n, max(1, int(ms_fim * TAXA / 1000)))
    y = list(x)
    for i in range(ni):
        y[i] *= i / ni
    for i in range(nf):
        y[n - 1 - i] *= i / nf
    # a última amostra fica exatamente em zero
    y[0] = 0.0
    y[-1] = 0.0
    return y


def normalizar(x, alvo_dbfs=PICO_DBFS):
    p = pico(x)
    if p <= 0:
        return list(x)
    g = (10.0 ** (alvo_dbfs / 20.0)) / p
    return [v * g for v in x]


def acabar(x, laco=False):
    """Remove DC, aplica fade e normaliza o pico em -3 dBFS."""
    y = remover_dc(x)
    y = fade(y, 30.0, 30.0) if laco else fade(y)
    return normalizar(y)


# --- WAV --------------------------------------------------------------------

def escrever_wav(caminho, x):
    """WAV PCM 16 bits mono 44,1 kHz."""
    dados = array.array("h", (
        int(round(max(-1.0, min(1.0, v)) * 32767)) for v in x))
    if struct.pack("=h", 1) != struct.pack("<h", 1):  # máquina big-endian
        dados.byteswap()
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(dados.tobytes())


def ler_wav(caminho):
    """Retorna (amostras_float, taxa, canais, bytes_por_amostra)."""
    with wave.open(str(caminho), "rb") as w:
        n = w.getnframes()
        bruto = w.readframes(n)
        info = (w.getframerate(), w.getnchannels(), w.getsampwidth())
    dados = array.array("h")
    dados.frombytes(bruto)
    if struct.pack("=h", 1) != struct.pack("<h", 1):
        dados.byteswap()
    return [v / 32768.0 for v in dados], info[0], info[1], info[2]


def semente_de(nome, variacao):
    """Semente estável (zlib.crc32, não o hash() aleatório do Python)."""
    import zlib
    return zlib.crc32(nome.encode("utf-8")) + variacao


def novo_rng(semente):
    return random.Random(semente)
