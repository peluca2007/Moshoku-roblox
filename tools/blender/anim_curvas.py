"""Curvas das animações (ANIM1): interpolação entre poses-chave, amostragem, redução de quadros e o espelho em
Python de `src/shared/Animacoes/Amostra.luau` (a prévia usa ESTE amostrador sobre os dados exportados, para ver
exatamente o que o jogo vai tocar).

Canais de uma pose-chave: Vector (posição) ou Quaternion (rotação). Entre chaves: Hermite cúbica com tangentes de
Catmull-Rom (tempos não uniformes), escaladas por (1 - tensao) da chave: tensao 1 = para na chave, 0 = passa fluido.
Quatérnios: componentes alinhadas no mesmo hemisfério, Hermite em 4D e normalização (bom até ~120 graus por trecho).
"""
import math

from mathutils import Quaternion, Vector


def _comp(v):
    return list(v) if isinstance(v, Vector) else [v.w, v.x, v.y, v.z]


def _de(lista, modelo):
    if isinstance(modelo, Vector):
        return Vector(lista)
    q = Quaternion(lista)
    q.normalize()
    return q


def _alinhar(valores):
    """Quatérnios consecutivos no mesmo hemisfério (dot > 0)."""
    saida = [valores[0]]
    for q in valores[1:]:
        if isinstance(q, Quaternion) and saida[-1].dot(q) < 0:
            q = Quaternion((-q.w, -q.x, -q.y, -q.z))
        saida.append(q)
    return saida


def hermite(tempos, valores, tensoes, t, laco=False):
    """Valor do canal no instante t. `valores` já alinhados; `laco` exige valores[0] == valores[-1]."""
    n = len(tempos)
    if n == 1 or t <= tempos[0]:
        return valores[0]
    if t >= tempos[-1]:
        return valores[-1]
    i = 0
    while i < n - 2 and t > tempos[i + 1]:
        i += 1
    comps = [_comp(v) for v in valores]

    def tangente(k):
        if 0 < k < n - 1:
            a, b, ta, tb = comps[k - 1], comps[k + 1], tempos[k - 1], tempos[k + 1]
        elif laco and n > 2:
            # o quadro final repete o primeiro: vizinhos são o penúltimo e o segundo
            a, b = comps[n - 2], comps[1]
            ta, tb = tempos[n - 2] - tempos[n - 1], tempos[1]
        else:
            return [0.0] * len(comps[k])
        return [(bb - aa) / (tb - ta) * (1.0 - tensoes[k]) for aa, bb in zip(a, b)]

    t0, t1 = tempos[i], tempos[i + 1]
    h = t1 - t0
    s = (t - t0) / h
    m0, m1 = tangente(i), tangente(i + 1)
    h00, h10, h01, h11 = 2 * s ** 3 - 3 * s ** 2 + 1, s ** 3 - 2 * s ** 2 + s, -2 * s ** 3 + 3 * s ** 2, s ** 3 - s ** 2
    p0, p1 = comps[i], comps[i + 1]
    r = [h00 * a + h10 * h * ma + h01 * b + h11 * h * mb for a, b, ma, mb in zip(p0, p1, m0, m1)]
    return _de(r, valores[0])


# ------------------------------------------------------------------------------------------------
# redução de quadros
def angulo(a, b):
    d = abs(a.dot(b))
    return 2 * math.degrees(math.acos(min(1.0, d)))


def slerp(a, b, u):
    if a.dot(b) < 0:
        b = Quaternion((-b.w, -b.x, -b.y, -b.z))
    return a.slerp(b, u)


def reduzir(tempos, valores, tolerancia, rot):
    """Douglas-Peucker no tempo: mantém o mínimo de quadros tal que a interpolação linear/slerp entre os mantidos fica
    a menos de `tolerancia` (graus para rotação, studs para posição) de todos os quadros amostrados."""
    n = len(tempos)
    manter = {0, n - 1}

    def erro(i, j, k):
        u = (tempos[k] - tempos[i]) / (tempos[j] - tempos[i])
        if rot:
            return angulo(slerp(valores[i], valores[j], u), valores[k])
        return (valores[i].lerp(valores[j], u) - valores[k]).length

    pilha = [(0, n - 1)]
    while pilha:
        i, j = pilha.pop()
        if j - i < 2:
            continue
        pior, kpior = -1.0, None
        for k in range(i + 1, j):
            e = erro(i, j, k)
            if e > pior:
                pior, kpior = e, k
        if pior > tolerancia:
            manter.add(kpior)
            pilha += [(i, kpior), (kpior, j)]
    return sorted(manter)


# ------------------------------------------------------------------------------------------------
# espelho do Amostra.luau (sobre os dados exportados: listas {t, qx, qy, qz, qw} / {t, x, y, z})
def _indice(chaves, t):
    lo, hi = 0, len(chaves) - 1
    if t <= chaves[0][0]:
        return 0
    if t >= chaves[hi][0]:
        return hi
    while hi - lo > 1:
        meio = (lo + hi) // 2
        if chaves[meio][0] <= t:
            lo = meio
        else:
            hi = meio
    return lo


def amostrar_junta(chaves, t):
    i = _indice(chaves, t)
    a = chaves[i]
    qa = Quaternion((a[4], a[1], a[2], a[3]))
    if i == len(chaves) - 1:
        return qa
    b = chaves[i + 1]
    qb = Quaternion((b[4], b[1], b[2], b[3]))
    u = (t - a[0]) / (b[0] - a[0])
    return slerp(qa, qb, max(0.0, min(1.0, u)))


def amostrar_raiz(chaves, t):
    i = _indice(chaves, t)
    a = chaves[i]
    if i == len(chaves) - 1:
        return Vector(a[1:4])
    b = chaves[i + 1]
    u = max(0.0, min(1.0, (t - a[0]) / (b[0] - a[0])))
    return Vector(a[1:4]).lerp(Vector(b[1:4]), u)
