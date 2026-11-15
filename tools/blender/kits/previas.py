"""Prévias dos kits (folhas de contato, arena montada, comparação com modelos do projeto).
Lê build/kits (o que o pipeline enviaria) e grava PNG em build/kits/previa/. Não envia nada.

Uso (sem janela):
  python tools/blender_rodar.py tools/blender/kits/previas.py [--qual folhas|arena|comparacao|tudo]
"""
import json
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
sys.path.insert(0, AQUI)
import bpy  # noqa: E402
import lib  # noqa: E402
import cena_kit as ck  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402


def manifesto():
    with open(os.path.join(ck.KITS, "manifesto.json"), encoding="utf-8") as f:
        return json.load(f)["pecas"]


def folhas():
    pecas = manifesto()
    por = {}
    for p in pecas:
        por.setdefault(p["categoria"], []).append(p["nome"])
    # armas e flecha mostradas em pé (a ponta aponta para -Y no arquivo; rot_x=-90 leva -Y para cima)
    em_pe = {n: {"rot_x": -90.0} for n in por.get("armas", []) if not n.startswith(("Arco", "Escudo"))}
    em_pe.update({n: {"giro": 20.0} for n in por.get("armas", []) if n.startswith(("Arco", "Escudo"))})
    ck.folha("esgoto.png", [("esgoto", n) for n in por["esgoto"]], colunas=8, exibir={})
    ck.folha("armas.png", [("armas", n) for n in por["armas"]], colunas=8, exibir=em_pe, escala_cam=0.72)
    ck.folha("taverna.png", [("taverna", n) for n in por["taverna"]], colunas=6)
    ck.folha("criaturas.png", [("criaturas", n) for n in por["criaturas"]], colunas=3, res=(1200, 800))


def _atual(gerador, x, y, giro=0.0):
    """Gera um modelo ATUAL do projeto (tools/blender/*.py) e pinta pelos grupos, como o pipeline faz."""
    modelo = gerador(1)
    modelo.espelhar_y = False
    objs = modelo.finalizar()
    modelo.apoiar_no_chao(objs)
    for o in objs:
        g = modelo.grupos[o.name.split(".")[0]]
        o.data.materials.append(ck.material(g["cor"], g["material"]))
    mn, mx = ck.caixa(objs)
    for o in objs:
        o.location.x += x - (mn.x + mx.x) / 2
        o.location.y += y - (mn.y + mx.y) / 2
    bpy.context.view_layer.update()
    return objs


def comparacao():
    """Modelos atuais (fileira de trás) ao lado dos kits (fileira da frente), mesma luz e escala."""
    import criaturas
    import props
    import ruinas
    cena = ck.preparar_cena(res=(2000, 1200), amostras=48)
    atuais = [("ATUAL rato", criaturas.GERADORES["rato"]), ("ATUAL caixotes", props.GERADORES["caixotes"]),
              ("ATUAL lampiao", props.GERADORES["lampiao"]), ("ATUAL carroca", props.GERADORES["carroca"]),
              ("ATUAL coluna", ruinas.GERADORES["coluna"])]
    x = 0.0
    for rot, g in atuais:
        objs = _atual(g, x, 0.0)
        mn, mx = ck.caixa(objs)
        ck.rotulo(rot, x, -3.4, tam=0.5)
        x += max(mx.x - mn.x, 4.0) + 2.5
    boneco_r15(-6.0, 0.0, 0)
    novos = [("Barril", "esgoto"), ("Bau", "esgoto"), ("Lampiao", "taverna"), ("EsgotoColuna", "esgoto"), ("TavernaMesa", "taverna"),
             ("Orc", "criaturas"), ("EspadaLonga", "armas"), ("Arco", "armas")]
    x = 0.0
    for nome, cat in novos:
        ex = {"rot_x": -90.0} if cat == "armas" and nome != "Arco" else {}
        objs = ck.carregar(cat, nome, 0, 0, **ex)
        ck.apoiar(objs)
        mn, mx = ck.caixa(objs)
        for o in objs:
            o.location.x += x - (mn.x + mx.x) / 2
            o.location.y += -14 - (mn.y + mx.y) / 2
        ck.rotulo("KIT " + nome, x, -17.4, tam=0.5)
        x += max(mx.x - mn.x, 3.0) + 2.5
    boneco_r15(-6.0, -14.0, 0)
    ck.camera(cena, (x / 2 - 4, -8, 2), dist=2.5 * x / 2 + 22, azimute=-8, elevacao=34, lente=60)
    ck.renderizar(os.path.join(ck.PREVIA, "comparacao.png"))


def _cubo(centro, tam, cor, mat="SmoothPlastic"):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    o = bpy.context.active_object
    o.scale = tam
    o.data.materials.append(ck.material(cor, mat))
    return o


def boneco_r15(x, y, giro, arma=None, rot_arma=0.0):
    """R15 de blocos de 5 studs (medidas de trajes.R15_CENTROS) com a arma na mão, de frente para -Y e girado `giro`."""
    pele, roupa, calca = (222, 180, 142), (96, 98, 110), (58, 58, 72)
    partes = [
        _cubo((0, 0, 4.6), (1.15, 1.15, 1.15), pele), _cubo((0, 0, 3.2), (2.0, 1.0, 1.6), roupa), _cubo((0, 0, 2.2), (2.0, 1.0, 0.4), calca),
        _cubo((-0.28, -0.59, 4.72), (0.16, 0.06, 0.16), (36, 30, 34)), _cubo((0.28, -0.59, 4.72), (0.16, 0.06, 0.16), (36, 30, 34)),
    ]
    for s in (-1, 1):
        partes += [_cubo((s * 1.5, 0, 2.825), (1.0, 1.0, 2.25), roupa), _cubo((s * 1.5, 0, 1.55), (1.0, 1.0, 0.3), pele),
                   _cubo((s * 0.5, 0, 1.0), (1.0, 1.0, 2.0), calca)]
    if arma:
        categoria, nome, px, py, pz, rx = arma
        partes += ck.carregar(categoria, nome, px, py, 0, rot_x=rx, z=pz)
    m = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians(giro), 4, "Z")
    for o in partes:
        o.matrix_world = m @ o.matrix_world
    return partes


def luz_ponto(x, y, z, energia=900, cor=(1.0, 0.62, 0.28), raio=0.3):
    l = bpy.data.lights.new("Tocha", "POINT")
    l.energy, l.color, l.shadow_soft_size = energia, cor, raio
    o = bpy.data.objects.new("Tocha", l)
    o.location = (x, y, z)
    bpy.context.scene.collection.objects.link(o)


def arena():
    """10 x 8 casas de 5 studs, câmera alta como a do combate (~50 graus), dois bonecos R15 e um orc para escala."""
    cena = ck.preparar_cena(res=(2000, 1300), ceu=(0.30, 0.32, 0.38), energia=2.4, amostras=48)
    C = 5.0
    L, P = 10, 8
    # piso: lajes alternadas e uma faixa de água no fundo (fora da grade de combate)
    for i in range(L):
        for j in range(P):
            nome = "EsgotoPisoLajes" if (i + j) % 2 == 0 else "EsgotoPiso"
            ck.carregar("esgoto", nome, (i + 0.5) * C, (j + 0.5) * C)
    for i in range(L):
        ck.carregar("esgoto", "EsgotoAgua", (i + 0.5) * C, (P + 0.5) * C)
    # grade de ralo e pedras no piso
    ck.carregar("esgoto", "EsgotoGradePiso", 7.5 * C, 3.5 * C)
    ck.carregar("esgoto", "EsgotoPedregulhos", 1.5 * C, 5.5 * C, giro=30)
    # paredes de fundo (+Y) e do lado direito (+X); arco no meio do fundo
    fundo_y = (P + 1.5) * C
    for i in range(L):
        ck.carregar("esgoto", "EsgotoArco" if i == 4 else "EsgotoParede", (i + 0.5) * C, fundo_y, giro=0)
    for j in range(P + 1):
        ck.carregar("esgoto", "EsgotoParede", (L + 0.5) * C, (j + 0.5) * C, giro=90)
    # canos, colunas, tochas
    ck.carregar("esgoto", "EsgotoCano", 2.0 * C, (P + 1.5) * C - 1.9)
    ck.carregar("esgoto", "EsgotoCanoCurva", 7.4 * C, (P + 1.5) * C - 1.9)
    ck.carregar("esgoto", "EsgotoCanoParede", 6.0 * C, (P + 1.5) * C - 2.4)
    for i in (0, 9):
        ck.carregar("esgoto", "EsgotoColuna", (i + 0.5) * C, (P - 0.5) * C)
    for x in (1.5, 6.5, 9.0):
        ck.carregar("esgoto", "EsgotoTocha", x * C, fundo_y - 2.5, giro=180)
        luz_ponto(x * C, fundo_y - 4.0, 3.9)
    # barris, caixas, potes
    for x, y, g in ((0.4, 6.4, 0), (0.4, 7.2, 40), (9.3, 1.0, 10)):
        ck.carregar("esgoto", "Barril", x * C, y * C, giro=g)
    ck.carregar("esgoto", "Bau", 9.2 * C, 2.2 * C, giro=90)
    ck.carregar("esgoto", "Pote", 8.4 * C, 7.3 * C, giro=20)
    ck.carregar("esgoto", "EsgotoEscora", 3.5 * C, 7.7 * C)
    # personagens: espadachim e arqueiro (frente = +Y, na direção do inimigo) e o orc
    boneco_r15(3.5 * C, 2.5 * C, 180, ("armas", "EspadaLonga", -1.5, -0.4, 1.6, -90))
    boneco_r15(6.5 * C, 2.5 * C, 180, ("armas", "Arco", 1.5, -0.9, 2.2, 0))
    ck.carregar("criaturas", "Orc", 5.5 * C, 5.5 * C, giro=180)
    cena.render.film_transparent = False
    centro = (L * C / 2, (P + 0.6) * C / 2, 0)
    camera(cena, centro)
    ck.renderizar(os.path.join(ck.PREVIA, "arena_esgoto.png"))


def camera(cena, centro):
    # câmera do combate: vista de cima-diagonal, ~50 graus de elevação
    ck.camera(cena, centro, dist=104, azimute=-28, elevacao=50, lente=45)


def main():
    opc = lib.argumentos({"qual": "tudo"})
    if opc["qual"] in ("folhas", "tudo"):
        folhas()
    if opc["qual"] in ("arena", "tudo"):
        arena()
    if opc["qual"] in ("comparacao", "tudo"):
        comparacao()


main()
