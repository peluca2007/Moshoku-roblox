"""PERS3: exporta as peças em malha (FBX + JSON no formato de tools/gerar_modelo.py) e os rostos (PNG).

Uso:  python tools/blender_rodar.py tools/blender/personagem/exportar.py [--so Modulo] [--rostos 1]
Saída: build/personagem/pecas/<Modulo>.fbx|.json e build/personagem/rostos/rosto_<estilo>_<OlhoXxx>.png
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import comum as C  # noqa: E402
import roblox_r15 as R  # noqa: E402
import roupas as RP  # noqa: E402
import cabelos_racas as CR  # noqa: E402
import pecas as P  # noqa: E402
import lib  # noqa: E402

SAIDA = os.path.join(C.SAIDA, "pecas")
CORES = {"Cabelo": (120, 120, 120), "Ferro": (150, 150, 158), "Interno": (226, 150, 150)}


def gerar(modulo):
    chave, parte = P.TODAS[modulo]
    cores = dict(RP.CORES_BASE)
    cores.update(RP.CONJUNTOS["ladino"]["cores"])
    b = C.Boneco(R.rig(), cores, "r15")
    if modulo in P.CABELOS:
        CR.CABELOS[chave](b)
    elif modulo in P.BARBAS:
        CR.BARBAS[chave](b)
    elif modulo in P.RACAS:
        CR.RACAS[chave](b)
    elif chave == "capuz":
        RP.capuz(b)
    elif chave == "capa_curta":
        RP.capa_curta(b)
    elif chave == "cinto_bolsa":
        RP.cinto(b, z=2.22, bolsa=True)
        RP.bolsa_lateral(b)
    else:
        RP.ombreira(b, -1)
    centro = R.rig()["pecas"][parte][0]
    modelo = lib.Modelo(modulo)
    modelo.manter_origem = True
    suaves = {}
    tris = 0
    for p, itens in b.grupos.items():
        for peca, papel, bm, suave in itens:
            assert p == parte, f"{modulo}: peça em {p}, esperado {parte}"
            nome = P.GRUPO.get(papel, papel.capitalize().replace("_", ""))
            cor = CORES.get(nome) or tuple(cores.get(papel, (140, 140, 140)))
            alvo = modelo.grupo(nome, cor, "SmoothPlastic")
            bm.transform(Matrix.Translation(-centro))
            suaves.setdefault(nome, suave)
            C.juntar(alvo, bm)
            tris += C.triangulos(bm)
    objetos = []
    for nome in [n for n, g in modelo.grupos.items() if not g["bm"].faces]:
        modelo.grupos.pop(nome)
    for nome, g in modelo.grupos.items():
        bm = g["bm"]
        C.normais_fora(bm)
        for f in bm.faces:
            f.smooth = suaves[nome]
        malha = bpy.data.meshes.new(nome)
        bm.to_mesh(malha)
        o = bpy.data.objects.new(nome, malha)
        bpy.context.scene.collection.objects.link(o)
        o.color = (*[c / 255.0 for c in g["cor"]], 1.0)
        objetos.append(o)
    bpy.context.view_layer.update()
    modelo.exportar(objetos, os.path.join(SAIDA, modulo + ".fbx"))
    return tris


def rostos():
    os.makedirs(os.path.join(C.SAIDA, "rostos"), exist_ok=True)
    for estilo in P.ROSTOS:
        for olho, rgb in P.OLHOS.items():
            R.tela_rosto(rgb, (60, 40, 30), estilo).salvar_png(os.path.join(C.SAIDA, "rostos", f"rosto_{estilo}_{olho}.png"))


def main():
    op = lib.argumentos({"so": "", "rostos": 0})
    os.makedirs(SAIDA, exist_ok=True)
    resumo = {}
    for modulo in P.TODAS:
        if op["so"] and op["so"] != modulo:
            continue
        lib.limpar()
        resumo[modulo] = gerar(modulo)
    if op["rostos"]:
        rostos()
    with open(os.path.join(SAIDA, "triangulos.json"), "w", encoding="utf-8") as f:
        json.dump(resumo, f, indent=1)
    print("TRIS", json.dumps(resumo))


main()
