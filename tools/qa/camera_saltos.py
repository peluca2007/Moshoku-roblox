"""Continuidade da câmera: analisa a série gravada por `hab_luta_real.py --camera=arquivo.csv` (t,x,y,z,lx,ly,lz por quadro)
e REPROVA (código 1) se algum quadro saltar mais que o limite.
  python tools/qa/camera_saltos.py arquivo.csv [--max-vel=45] [--max-giro=260] [--rotulo=antes]
Limites em studs/s e graus/s sobre atualizações reais da câmera (independe do fps de render)."""
import math, sys


def ler(caminho):
    linhas = [l.strip().split(",") for l in open(caminho, encoding="utf-8") if l.strip() and not l.startswith("t,")]
    return [[float(x) for x in l] for l in linhas]


def analisar(serie, max_pos=2.0, max_gr=14.0):
    """Cada ponto = uma atualização REAL da câmera (linhas repetidas pelo Heartbeat entre dois quadros de render são
    descartadas). Devolve (t, studs, graus, dt, studs/s, graus/s)."""
    unicos = [serie[0]]
    for r in serie[1:]:
        if r[1:] != unicos[-1][1:]:
            unicos.append(r)
    saltos = []
    for a, b in zip(unicos, unicos[1:]):
        dt = b[0] - a[0]
        if dt <= 0 or dt > 0.4:
            continue
        dp = math.dist(a[1:4], b[1:4])
        dot = max(-1, min(1, sum(x * y for x, y in zip(a[4:7], b[4:7]))))
        dg = math.degrees(math.acos(dot))
        saltos.append((b[0], dp, dg, dt, dp / dt, dg / dt))
    return saltos


def relatorio(serie, max_vel=45.0, max_giro=260.0, rotulo=""):
    """Limites em studs/s e graus/s (independem do fps de render)."""
    s = analisar(serie)
    ruins = [x for x in s if x[4] > max_vel or x[5] > max_giro]
    top = sorted(s, key=lambda x: -x[5])[:4]
    fps = len(s) / max(serie[-1][0] - serie[0][0], 1e-6)
    print("%sCÂMERA: %d atualizações (~%.0f/s), maior velocidade %.1f studs/s, maior giro %.0f graus/s (limites %.0f / %.0f)" % (
        rotulo + " ", len(s), fps, max((x[4] for x in s), default=0), max((x[5] for x in s), default=0), max_vel, max_giro))
    for t, dp, dg, dt, vp, vg in top:
        print("   t=%.2f s  %.2f studs, %.1f graus em %.3f s (%.0f studs/s, %.0f graus/s)" % (t, dp, dg, dt, vp, vg))
    print("%s %d atualização(ões) acima do limite" % ("FALHA" if ruins else "OK  ", len(ruins)))
    return not ruins


if __name__ == "__main__":
    def opt(n, d):
        return next((float(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--" + n + "=")), d)
    rot = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--rotulo=")), "")
    sys.exit(0 if relatorio(ler(sys.argv[1]), opt("max-vel", 45.0), opt("max-giro", 260.0), rot) else 1)
