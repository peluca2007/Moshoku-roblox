"""Converte os kits CC0 baixados em build/externos para o formato do pipeline (FBX por cor + .json)
em build/kits/<categoria>/<Nome>.fbx e escreve build/kits/manifesto.json.

Uso (sem janela; baixar os pacotes antes, ver tools/blender/kits/README.md):
  python tools/blender_rodar.py tools/blender/kits/preparar.py [--so Nome1,Nome2]
"""
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))  # tools/blender (lib)
sys.path.insert(0, AQUI)
import bpy  # noqa: E402
import lib  # noqa: E402
import kit_lib  # noqa: E402
import catalogo  # noqa: E402
import extras  # noqa: E402
from lib import Modelo  # noqa: E402


def _extra(fn):
    lib.limpar()
    modelo, opc = fn()
    objs = modelo.finalizar()
    modelo.apoiar_no_chao(objs)
    base = os.path.join(kit_lib.SAIDA, opc["categoria"], modelo.nome)
    modelo.exportar(objs, base + ".fbx")
    with open(base + ".json", encoding="utf-8") as f:
        dados = json.load(f)
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    return {
        "nome": modelo.nome, "categoria": opc["categoria"], "uso": opc["uso"], "origem": "moshoku/extras.py (gerado por código)",
        "arquivo_origem": "", "licenca": "projeto (sem terceiros)", "triangulos": tris, "triangulos_originais": tris,
        "orcamento": kit_lib.ORCAMENTO[opc["orcamento"]], "dimensoes_studs": dados["dimensoes"], "escala_aplicada": 1.0,
        "pivo": opc.get("pivo", "chao"),
        "cores": [{"grupo": n, "cor": g["cor"], "material": g["material"]} for n, g in dados["grupos"].items()],
        "fbx": os.path.relpath(base + ".fbx", kit_lib.RAIZ).replace("\\", "/"),
    }


def main():
    opcoes = lib.argumentos({"so": ""})
    so = {s for s in opcoes["so"].split(",") if s}
    manifesto = []
    falhas = []
    for item in catalogo.ITENS:
        if so and item["nome"] not in so:
            continue
        fonte = catalogo.FONTES[item["fonte"]]
        obj = os.path.join(kit_lib.EXTERNOS, fonte["pasta"], item["arquivo"] + ".obj")
        base = os.path.join(kit_lib.SAIDA, item["categoria"], item["nome"])
        os.makedirs(os.path.dirname(base), exist_ok=True)
        try:
            manifesto.append(kit_lib.converter(fonte, obj, item, base))
        except Exception as erro:  # um arquivo ruim não derruba o lote
            falhas.append((item["nome"], repr(erro)))
            print("FALHA", item["nome"], erro)
    for fn in extras.EXTRAS:
        if so and not any(fn.__name__.lower() in s.lower() for s in so) and fn.__name__ not in so:
            continue
        manifesto.append(_extra(fn))
    destino = os.path.join(kit_lib.SAIDA, "manifesto.json")
    if so and os.path.isfile(destino):  # lote parcial: mantém o resto
        with open(destino, encoding="utf-8") as f:
            antigos = {m["nome"]: m for m in json.load(f)["pecas"]}
        antigos.update({m["nome"]: m for m in manifesto})
        manifesto = list(antigos.values())
    with open(destino, "w", encoding="utf-8") as f:
        json.dump({"formato": "FBX por cor + .json (tools/blender/lib.py); 1 unidade = 1 stud; casa do combate = 5 studs",
                   "pecas": manifesto}, f, ensure_ascii=False, indent=1)
    estouros = [m["nome"] for m in manifesto if m["triangulos"] > m["orcamento"]]
    print(f"KITS pecas={len(manifesto)} falhas={falhas} acima_do_orcamento={estouros}")


main()
