"""Geradores de modelos low-poly de cenário (vila e floresta), rodados no Blender sem janela.

Uso (via tools/blender_rodar.py):
  python tools/blender_rodar.py tools/blender/modelos.py --modelo rocha --semente 3 \
      --saida build/blender/Rocha3.fbx --previa build/blender/Rocha3.png
Modelos: arvore (carvalho), rocha, arbusto (--flores 1), tora, tocos, cerca (--variante trilhos|ripas), casa (paleta pela semente), taverna, forja, dojo, barraca; ruinas: coluna, colunaquebrada, muro, arco, altar, lapide.
Cada grupo de cor vira uma MeshPart; cores e materiais ficam no .json ao lado do FBX.
V5 (vila e trajes): chafariz, bandeirolas (--semente 1-3), estandarte (--semente 1-3), banco, canteiro, jardineira, varal, lenha, poco,
mercado (--variante listrado|liso), casasacada, casapalha; trajes (acessórios com origem = ponto de encaixe, ver trajes.ENCAIXES):
ladinocapuz, ladinocapa, ladinomascara, ladinocinto, mestratiara, mestramanto, mestracajado, mestraobi.
Avatar quadradão (avatar.py; origem = ponto de encaixe de avatar.ENCAIXES; espelhovila é prop de chão): cabelocurto, cabeloespetado, cabelofranja, cabelorabo,
cabelococo, cabelolongo, cabelomoicano, cabelolaterais, cabelocachos; barbacavanhaque, barbacurta, barbatrancada, bigode; orelhaselfo, orelhaselfolongas,
orelhasferafelina, orelhasferacanina, caudafera, chifresdemonioretos, chifresdemoniocurvos, chifresdragao, caudadragao, caudasuperd, aureola,
barbatanasoceano, presasogro, joiatesta; tunicabasica, capuzbasico, cintobasico, botasbasicas, luvasbasicas, mochilabasica; espelhovila.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import predios  # noqa: E402
import avatar  # noqa: E402
import casas  # noqa: E402
import criaturas  # noqa: E402
import props  # noqa: E402
import ruinas  # noqa: E402
import trajes  # noqa: E402
import vegetacao  # noqa: E402
import vila  # noqa: E402
from lib import Modelo  # noqa: E402


def rocha(semente, **_):
    rng = random.Random(semente)
    m = Modelo(f"Rocha{semente}")
    pedra = m.grupo("Pedra", (128, 130, 124), "Slate")
    bm = __import__("bmesh").new()
    larg = 1.7 + rng.random() * 0.5
    Modelo.esfera(bm, (0, 0, 0), 1.0, (larg, larg * (0.8 + rng.random() * 0.3), 1.35 + rng.random() * 0.45), 2, 0.14, rng, corte_z=-0.5)
    for _ in range(rng.randint(1, 2)):
        ang = rng.random() * math.tau
        r = 0.45 + rng.random() * 0.4
        Modelo.esfera(bm, (math.cos(ang) * larg * 0.8, math.sin(ang) * larg * 0.7, -0.1), r + 0.25, (1, 1, 1.1), 2, 0.1, rng, corte_z=-0.5)
    import bmesh
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    topo = max(v.co.z for v in bm.verts)
    musgo_bm, pedra_bm = Modelo.dividir_faces(bm, lambda f: f.normal.z > 0.55 and f.calc_center_median().z > topo * 0.35)
    bm.free()
    m.grupos["Pedra"]["bm"] = pedra_bm
    m.grupo("Musgo", (82, 118, 58), "Grass")
    m.grupos["Musgo"]["bm"] = musgo_bm
    return m


def arbusto(semente, flores=0, **_):
    rng = random.Random(semente * 7 + 1)
    m = Modelo(f"Arbusto{semente}")
    escuro = m.grupo("Folhas", (44, 98, 46), "Grass")
    claro = m.grupo("FolhasClaras", (112, 166, 70), "Grass")
    centros = []
    for i in range(rng.randint(8, 10)):
        ang = rng.random() * math.tau
        d = rng.random() * 1.1
        c = (math.cos(ang) * d, math.sin(ang) * d, 0.3 + (1.1 - d) * 0.5 + rng.random() * 0.3)
        r = 0.55 + rng.random() * 0.4
        centros.append((c, r))
        alvo = claro if rng.random() < 0.38 else escuro
        Modelo.esfera(alvo, c, r, (1, 1, 0.9), 2, 0.2, rng, corte_z=0.0)
    if flores:
        fl = m.grupo("Flores", (236, 206, 92), "Plastic")
        for _ in range(rng.randint(5, 8)):
            c, r = rng.choice(centros)
            a, b = rng.random() * math.tau, 0.3 + rng.random() * 0.6
            p = (c[0] + math.cos(a) * r * math.cos(b), c[1] + math.sin(a) * r * math.cos(b), c[2] + r * 0.85 * math.sin(b) + 0.08)
            Modelo.esfera(fl, p, 0.13, subdiv=0)
    return m


def tora(semente, **_):
    rng = random.Random(semente * 11 + 5)
    m = Modelo(f"Tora{semente}")
    comp = 5.5 + rng.random() * 2.0
    raio = 0.62 + rng.random() * 0.22
    casca = m.grupo("Casca", (96, 70, 46), "Wood")
    Modelo.cilindro(casca, (0, 0, raio * 0.92), raio, comp, 9, raio * 0.92, "X", tampas=False)
    for lado in (-1, 1):
        Modelo.cilindro(casca, (lado * comp * 0.18, raio * 0.2 * lado, raio * 1.75), raio * 0.18, 0.9, 6, raio * 0.12, "Y", tampas=True)
    cerne = m.grupo("Cerne", (200, 164, 112), "Wood")
    for lado in (-1, 1):
        Modelo.cilindro(cerne, (lado * (comp / 2 + 0.02), 0, raio * 0.92), raio * 0.86, 0.06, 9, None, "X", tampas=True)
    musgo = m.grupo("Musgo", (78, 116, 56), "Grass")
    for _ in range(rng.randint(2, 3)):
        x = (rng.random() - 0.5) * comp * 0.7
        Modelo.esfera(musgo, (x, (rng.random() - 0.5) * 0.3, raio * 1.62), 0.5 + rng.random() * 0.3, (1.3, 0.7, 0.28), 1, 0.12, rng)
    return m


def tocos(semente, **_):
    rng = random.Random(semente * 13 + 3)
    m = Modelo(f"Toco{semente}")
    casca = m.grupo("Casca", (96, 70, 46), "Wood")
    cerne = m.grupo("Cerne", (200, 164, 112), "Wood")
    raio = 0.85 + rng.random() * 0.3
    alt = 0.8 + rng.random() * 0.5
    Modelo.cilindro(casca, (0, 0, alt / 2), raio, alt, 9, raio * 0.9, "Z", tampas=False)
    Modelo.cilindro(casca, (0, 0, 0.05), raio * 1.18, 0.3, 9, raio * 0.95, "Z", tampas=False)
    Modelo.cilindro(cerne, (0, 0, alt + 0.01), raio * 0.88, 0.05, 9, None, "Z", tampas=True)
    musgo = m.grupo("Musgo", (78, 116, 56), "Grass")
    Modelo.esfera(musgo, (raio * 0.35, raio * 0.3, alt + 0.04), 0.4, (1.2, 0.9, 0.22), 1, 0.1, rng)
    return m


def cerca(semente, variante="trilhos", **_):
    m = Modelo(f"Cerca{variante.capitalize()}")
    madeira = m.grupo("Madeira", (122, 88, 56), "WoodPlanks")
    rng = random.Random(semente)
    comp = 4.0
    for x in (-comp / 2, comp / 2):
        Modelo.caixa(madeira, (x, 0, 0.95), (0.32, 0.32, 1.9))
        Modelo.cilindro(madeira, (x, 0, 2.0), 0.23, 0.3, 4, 0.0, "Z", tampas=False)
    if variante == "trilhos":
        for z in (0.8, 1.45):
            Modelo.caixa(madeira, (0, 0.04, z + rng.uniform(-0.03, 0.03)), (comp, 0.16, 0.26))
    else:
        for i in range(7):
            x = -comp / 2 + 0.3 + i * (comp - 0.6) / 6
            Modelo.caixa(madeira, (x, -0.06, 0.75), (0.34, 0.1, 1.5))
            Modelo.cilindro(madeira, (x, -0.06, 1.62), 0.19, 0.26, 4, 0.0, "Z", tampas=False)
        for z in (0.5, 1.15):
            Modelo.caixa(madeira, (0, 0.06, z), (comp, 0.1, 0.2))
    return m


def arvore(semente, **_):
    """Carvalho low-poly: tronco cônico com raízes e copa de esferas em dois verdes."""
    rng = random.Random(semente * 17 + 9)
    m = Modelo(f"CarvalhoB{semente}")
    tronco = m.grupo("Tronco", (104, 76, 52), "Wood")
    escuro = m.grupo("Copa", (52, 106, 54), "Grass")
    claro = m.grupo("CopaClara", (104, 160, 68), "Grass")
    alt = 3.6 + rng.random() * 1.2
    Modelo.cilindro(tronco, (0, 0, alt / 2), 0.62, alt, 7, 0.38, tampas=False)
    Modelo.cilindro(tronco, (0, 0, 0.45), 0.95, 0.9, 7, 0.62, tampas=False)
    for i in range(3):
        a = rng.random() * math.tau
        Modelo.esfera(tronco, (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.15), 0.45, (1.2, 0.8, 0.6), 1, 0.1, rng, corte_z=0.0)
    base = alt + 1.2
    centros = [((0, 0, base + 1.6), 2.5 + rng.random() * 0.4)]
    for i in range(rng.randint(5, 7)):
        a = rng.random() * math.tau
        d = 1.5 + rng.random() * 1.3
        centros.append(((math.cos(a) * d, math.sin(a) * d, base + rng.uniform(0.2, 2.6)), 1.7 + rng.random() * 0.9))
    centros.append(((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), base + 3.8), 1.9 + rng.random() * 0.5))
    for c, r in centros:
        alvo = claro if c[2] > base + 1.8 and rng.random() < 0.6 else escuro
        Modelo.esfera(alvo, c, r, (1, 1, 0.92), 2, 0.17, rng)
    return m

def arvore_morta(semente, **_):
    """Árvore seca: tronco torto e galhos nus, para ruínas e bordas sombrias."""
    rng = random.Random(semente * 23 + 4)
    m = Modelo(f"ArvoreMorta{semente}")
    madeira = m.grupo("Madeira", (92, 78, 68), "Wood")
    altura = 6.0 + rng.random() * 2.5
    topo = (rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), altura)
    meio = (topo[0] * 0.5 + rng.uniform(-0.3, 0.3), topo[1] * 0.5, altura * 0.5)
    Modelo.ramo(madeira, (0, 0, 0), meio, 0.78, 0.5, 7)
    Modelo.ramo(madeira, meio, topo, 0.5, 0.16, 7)
    Modelo.cilindro(madeira, (0, 0, 0.35), 1.05, 0.7, 7, 0.78, tampas=False)
    for i in range(rng.randint(8, 10)):
        t = 0.3 + rng.random() * 0.62
        base = (meio[0] + (topo[0] - meio[0]) * max(0, (t - 0.5) * 2) * 0.9 if t > 0.5 else meio[0] * t * 2,
                meio[1] + (topo[1] - meio[1]) * max(0, (t - 0.5) * 2) * 0.9 if t > 0.5 else meio[1] * t * 2,
                altura * t)
        a = rng.random() * math.tau
        comp = 2.6 + rng.random() * 2.6 * (1.25 - t * 0.6)
        fim = (base[0] + math.cos(a) * comp, base[1] + math.sin(a) * comp, base[2] + comp * rng.uniform(0.35, 0.95))
        Modelo.ramo(madeira, base, fim, 0.34, 0.08, 5)
        if rng.random() < 0.65:
            meio_g = ((base[0] + fim[0]) / 2, (base[1] + fim[1]) / 2, (base[2] + fim[2]) / 2)
            a2 = a + rng.uniform(-1.1, 1.1)
            fim2 = (meio_g[0] + math.cos(a2) * comp * 0.5, meio_g[1] + math.sin(a2) * comp * 0.5, meio_g[2] + comp * 0.45)
            Modelo.ramo(madeira, meio_g, fim2, 0.17, 0.05, 5)
    return m


GERADORES = {"arvore": arvore, "arvoremorta": arvore_morta, "rocha": rocha, "arbusto": arbusto, "tora": tora, "tocos": tocos, "cerca": cerca,
             "casa": lambda semente, **_: predios.casa(semente), "taverna": lambda semente, **_: predios.taverna(semente),
             "forja": lambda semente, **_: predios.forja(semente), "dojo": lambda semente, **_: predios.dojo(semente),
             "barraca": lambda semente, **_: predios.barraca(semente),
             "tenda": lambda semente, **_: predios.tenda(semente), "fardo": lambda semente, **_: predios.fardo(semente),
             "placa": lambda semente, **_: predios.placa(semente), "tripe": lambda semente, **_: predios.tripe(semente)}


GERADORES.update(ruinas.GERADORES)
GERADORES.update(vegetacao.GERADORES)  # abeto, carvalhoantigo, samambaia, cogumelos, toramusgo, raizes, tufo, flores, juncos, rochedo
GERADORES.update(props.GERADORES)  # lampiao, carroca, caixotes, ponte, palicada, portao
GERADORES.update(vila.GERADORES)  # V5a: chafariz, bandeirolas, estandarte, banco, canteiro, jardineira, varal, lenha, poco, mercado (--variante listrado|liso)
GERADORES.update(casas.GERADORES)  # V5a: casasacada, casapalha
GERADORES.update(avatar.GERADORES)  # avatar quadradão (16/10): cabelos, barbas, traços de raça, roupas básicas, espelhovila (ver avatar.py:ENCAIXES)
GERADORES.update(criaturas.GERADORES)  # criaturas do mundo aberto (17/10): goblin (--variante faca|arco), lobo, urso, bandido (--variante porrete|espada), rato, aranha, treant, golem; grupos "<Parte>_<Cor>" + chave "pivos" no .json (ver criaturas.py)
GERADORES.update(trajes.GERADORES)  # V5b: acessórios dos trajes (origem = ponto de encaixe): ladinocapuz, ladinocapa, ladinomascara, ladinocinto, mestratiara, mestramanto, mestracajado, mestraobi


def main():
    op = lib.argumentos({"modelo": "rocha", "semente": 1, "saida": "build/blender/Modelo.fbx", "previa": "", "flores": 0, "variante": "trilhos"})
    lib.limpar()
    modelo = GERADORES[op["modelo"]](op["semente"], flores=op["flores"], variante=op["variante"])
    objetos = modelo.finalizar()
    modelo.apoiar_no_chao(objetos)
    modelo.exportar(objetos, op["saida"], op["previa"])


main()
