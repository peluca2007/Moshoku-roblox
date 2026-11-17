"""HAB1: gera clipes novos por deformação de tempo de clipes existentes (sem Blender).
  python tools/animacao/hab1_clipes.py
Emboscada = Estocada com antecipação longa agachada (x2,4), golpe rápido e congelamento de 0,07 s no contato
(Primeiro Golpe). Escreve src/shared/Animacoes/Clipes/Emboscada.luau."""
import math, os, re
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLIPES = os.path.join(RAIZ, "src", "shared", "Animacoes", "Clipes")


def ler(nome):
    txt = open(os.path.join(CLIPES, nome + ".luau"), encoding="utf-8").read()
    faixas = {}
    corpo = txt.split("\tjuntas = {", 1)[1]
    juntas_txt, raiz_txt = corpo.split("\n\t},\n\traiz = {", 1)
    for m in re.finditer(r"\n\t\t(\w+) = \{\n(.*?)\n\t\t\},", juntas_txt, re.S):
        faixas[m.group(1)] = [[float(x) for x in k.split(",")] for k in re.findall(r"\{([-\d.e, ]+)\}", m.group(2))]
    faixas["raiz"] = [[float(x) for x in k.split(",")] for k in re.findall(r"\{([-\d.e, ]+)\}", raiz_txt)]
    meta = {k: re.search(k + r" = ([^,\n]+)", txt).group(1) for k in ("duracao", "fps", "laco")}
    impacto = float(re.search(r"impacto = ([\d.]+)", txt).group(1))
    return faixas, meta, impacto


def valor(chaves, t):
    if t <= chaves[0][0]:
        return chaves[0][1:]
    for a, b in zip(chaves, chaves[1:]):
        if a[0] <= t <= b[0]:
            u = 0 if b[0] == a[0] else (t - a[0]) / (b[0] - a[0])
            v = [x + (y - x) * u for x, y in zip(a[1:], b[1:])]
            if len(v) == 4:  # quatérnio: normaliza
                n = math.sqrt(sum(c * c for c in v)) or 1
                v = [c / n for c in v]
            return v
    return chaves[-1][1:]


def deformar(chaves, impacto, fator_antes, fator_golpe, congela, ponto_golpe):
    novo = []
    def w(t):
        if t <= ponto_golpe:
            return t * fator_antes
        if t <= impacto:
            return ponto_golpe * fator_antes + (t - ponto_golpe) * fator_golpe
        return ponto_golpe * fator_antes + (impacto - ponto_golpe) * fator_golpe + congela + (t - impacto)
    tempos = sorted(set([c[0] for c in chaves] + [impacto]))
    for t in tempos:
        novo.append([round(w(t), 4)] + [round(x, 4) for x in valor(chaves, t)])
        if abs(t - impacto) < 1e-9:  # congelamento: repete a pose do contato
            novo.append([round(w(t) + congela, 4)] + [round(x, 4) for x in valor(chaves, t)])
    return novo, w(impacto)


def escrever(nome, origem, faixas, impacto_novo, duracao, fps, laco, juntas_ordem):
    def linha(ch):
        return "{" + ", ".join(str(x) for x in ch) + "}"
    saida = ["-- Gerado por tools/animacao/hab1_clipes.py (HAB1) a partir de %s. Não editar à mão." % origem,
             "-- Formato: ver src/shared/Animacoes/Amostra.luau.", "return {", '\tnome = "%s",' % nome, '\torigem = "script",',
             "\tfps = %s," % fps, "\tduracao = %.4f," % duracao, "\tlaco = %s," % laco, "\tmarcos = { impacto = %.4f }," % impacto_novo, "\tjuntas = {"]
    for j in juntas_ordem:
        saida.append("\t\t%s = {" % j)
        ks = faixas[j]
        for i in range(0, len(ks), 4):
            saida.append("\t\t\t" + ", ".join(linha(k) for k in ks[i:i + 4]) + ",")
        saida.append("\t\t},")
    saida.append("\t},")
    ks = faixas["raiz"]
    saida.append("\traiz = {")
    for i in range(0, len(ks), 4):
        saida.append("\t\t" + ", ".join(linha(k) for k in ks[i:i + 4]) + ",")
    saida.append("\t},")
    saida.append("}")
    open(os.path.join(CLIPES, nome + ".luau"), "w", encoding="utf-8", newline="\n").write("\n".join(saida) + "\n")


faixas, meta, impacto = ler("Estocada")
nova, imp2 = {}, None
for nome, ch in faixas.items():
    nova[nome], imp2 = deformar(ch, impacto, 2.4, 0.8, 0.07, 0.3)
dur = float(meta["duracao"]) - impacto + imp2 + 0.07
juntas = [n for n in faixas if n != "raiz"]
escrever("Emboscada", "Estocada", nova, imp2, dur, meta["fps"], meta["laco"], juntas)
print("Emboscada: %d juntas, impacto %.3f s, duração %.3f s" % (len(juntas), imp2, dur))


# ---------------------------------------------------------------------------------------------------------------
# CorteDeBraco: CorteLeve (corte horizontal na altura do braço) com peso de corpo inteiro. Tempo deformado (antecipação mais longa, golpe seco, 0,09 s de
# congelamento no contato) + rotações aditivas: agachamento (joelhos e queda da raiz) na antecipação e torção do tronco
# para trás; depois do contato, assentamento amortecido (overshoot do tronco e do ombro) em vez de parar seco.
def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz]


def qeixo(eixo, ang):
    s, c = math.sin(ang / 2), math.cos(ang / 2)
    return [eixo[0] * s, eixo[1] * s, eixo[2] * s, c]


def suave(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def corte_de_braco():
    faixas, meta, impacto = ler("CorteLeve")
    ANT, F_ANT, F_GOLPE, CONGELA = 0.2, 1.7, 1.0, 0.09
    def w(t):
        if t <= ANT:
            return t * F_ANT
        if t <= impacto:
            return ANT * F_ANT + (t - ANT) * F_GOLPE
        return ANT * F_ANT + (impacto - ANT) * F_GOLPE + CONGELA + (t - impacto)
    ti = w(impacto)
    dur_orig = float(meta["duracao"])
    dur = w(dur_orig)
    def env_a(t):  # agacha e torce na antecipação, solta no contato
        return suave((t - 0.1) / (ti * 0.7)) * (1 - suave((t - (ti - 0.12)) / 0.17))
    def env_b(t):  # assentamento depois do congelamento
        u = t - (ti + CONGELA)
        return 0.0 if u < 0 else math.sin(2 * math.pi * 3.0 * u) * math.exp(-4.5 * u)
    passo = 1 / 60
    n = int(dur / passo) + 1
    tempos = [round(i * passo, 4) for i in range(n)] + [round(dur, 4)]
    # inversa de w por busca (monótona): tempo original para cada tempo novo
    def inv(tn):
        lo, hi = 0.0, dur_orig
        for _ in range(40):
            mid = (lo + hi) / 2
            if w(mid) < tn:
                lo = mid
            else:
                hi = mid
        return lo
    saida = {}
    for nome, ch in faixas.items():
        novos = []
        for tn in tempos:
            to = inv(tn)
            if tn > ti and tn < ti + CONGELA:
                to = impacto  # congelado
            v = valor(ch, to)
            a, b = env_a(tn), env_b(tn)
            if nome == "raiz":
                v = [v[0], v[1] - 0.15 * a, v[2]]  # corpo desce
            elif len(v) == 4:
                q = v
                if nome in ("RightKnee", "LeftKnee"):
                    q = qmul(q, qeixo((1, 0, 0), -0.25 * a))
                elif nome == "Waist":
                    q = qmul(q, qeixo((0, 1, 0), -0.12 * a + 0.10 * b))
                elif nome == "RightShoulder":
                    q = qmul(q, qeixo((1, 0, 0), 0.12 * b))
                n_ = math.sqrt(sum(c * c for c in q)) or 1
                v = [c / n_ for c in q]
            novos.append([tn] + [round(x, 4) for x in v])
        saida[nome] = novos
    juntas = [n for n in faixas if n != "raiz"]
    escrever("CorteDeBraco", "CorteLeve", saida, ti, dur, meta["fps"], meta["laco"], juntas)
    print("CorteDeBraco: impacto %.3f s, duração %.3f s, %d quadros por junta" % (ti, dur, len(tempos)))


# Não gerado por padrão: o resultado sobre CorteLeve/CortePesado ficou ilegível (tronco dobrado, tempo esticado) e foi
# retirado do catálogo; mantido aqui como experimento. Para gerar: python -c "import runpy; ..." ou chame corte_de_braco().
