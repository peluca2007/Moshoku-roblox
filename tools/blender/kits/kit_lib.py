"""Funções do conversor de kits (roda dentro do Blender, sem janela).

Importa OBJ de kits CC0, descobre a cor de cada face (textura-paleta pelo UV, ou Kd do material),
suaviza a paleta para o tom sóbrio do jogo, agrupa por cor e grava no mesmo formato de
tools/blender/lib.py (um objeto/MeshPart por cor em FBX + .json ao lado).
Dados baixados são tratados só como dados: nada de dentro dos pacotes é executado.
"""
import colorsys
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))  # tools/blender
import lib  # noqa: E402
from lib import Modelo  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
EXTERNOS = os.path.join(RAIZ, "build", "externos")
SAIDA = os.path.join(RAIZ, "build", "kits")

ORCAMENTO = {"cenario": 3000, "prop": 1500, "arma": 800, "criatura": 2500}


def importar_obj(caminho):
    """Importa um OBJ (Y-up -> Z-up do Blender) e devolve os objetos de malha."""
    antes = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=os.path.abspath(caminho), forward_axis="NEGATIVE_Z", up_axis="Y")
    return [o for o in bpy.data.objects if o not in antes and o.type == "MESH"]


def _lin_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def _cor_do_material(mat, cache):
    """(imagem|None, cor_sRGB 0-255) do material: textura base ou valor Base Color."""
    if mat is None:
        return None, (160, 160, 160)
    if mat.name in cache:
        return cache[mat.name]
    imagem, cor = None, (160, 160, 160)
    if mat.use_nodes:
        for no in mat.node_tree.nodes:
            if no.type == "TEX_IMAGE" and no.image:
                imagem = no.image
            if no.type == "BSDF_PRINCIPLED":
                v = no.inputs["Base Color"].default_value
                cor = tuple(round(_lin_srgb(c) * 255) for c in v[:3])
    cache[mat.name] = (imagem, cor)
    return imagem, cor


def _pixels(imagem, cache):
    """Pixels sem gestão de cor (0-1 = byte/255), com cache."""
    if imagem.name not in cache:
        imagem.colorspace_settings.name = "Non-Color"
        cache[imagem.name] = (imagem.size[0], imagem.size[1], list(imagem.pixels))
    return cache[imagem.name]


def faces_coloridas(objetos, matriz=None):
    """Lista de (cor_sRGB, [vertices no espaço do modelo]) por polígono."""
    matriz = matriz or Matrix.Identity(4)
    saida, mats, pix = [], {}, {}
    for o in objetos:
        malha = o.data
        uv = malha.uv_layers.active
        for p in malha.polygons:
            mat = o.material_slots[p.material_index].material if o.material_slots and p.material_index < len(o.material_slots) else None
            imagem, cor = _cor_do_material(mat, mats)
            if imagem is not None and uv is not None:
                u = sum(uv.data[i].uv[0] for i in p.loop_indices) / p.loop_total
                v = sum(uv.data[i].uv[1] for i in p.loop_indices) / p.loop_total
                w, h, px = _pixels(imagem, pix)
                x = min(w - 1, max(0, int(u * w)))
                y = min(h - 1, max(0, int(v * h)))
                k = (y * w + x) * 4
                cor = tuple(round(px[k + c] * 255) for c in range(3))
            vs = [matriz @ o.matrix_world @ malha.vertices[i].co for i in p.vertices]
            saida.append((cor, vs))
    return saida


def sobrio(cor, sat=0.62, valor=0.92):
    """Puxa uma cor para um tom de fantasia sóbria: menos saturação, um pouco mais escura."""
    r, g, b = (c / 255 for c in cor)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = min(s * sat, 0.55)
    v = v * valor
    return tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, v))


def _lum(cor):
    return (0.2126 * cor[0] + 0.7152 * cor[1] + 0.0722 * cor[2]) / 255


def _mistura(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


MADEIRA_ESC, MADEIRA_CLARA = (62, 44, 32), (146, 108, 76)


def afinar(cor, modo="cenario", sat=0.62, valor=0.92):
    """Paleta do jogo. Modo "cenario": pedra/ferro viram cinza neutro (a paleta do Kenney é azulada), madeira vira
    marrom (a do Kenney é salmão), o resto só perde saturação. Modo "sobrio": só `sobrio`."""
    if modo == "cenario":
        h, s, v = _hsv(cor)
        if s < 0.3:
            g = 0.08 + _lum(cor) * 0.50
            return (round(g * 255 * 1.03), round(g * 255), round(g * 255 * 0.96))
        if h < 0.1 and s >= 0.3 and v > 0.35:
            return _mistura(MADEIRA_ESC, MADEIRA_CLARA, (_lum(cor) - 0.38) / 0.4)
    return sobrio(cor, sat, valor)


def _distancia(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def _area(vs):
    a = 0.0
    for i in range(1, len(vs) - 1):
        a += ((vs[i] - vs[0]).cross(vs[i + 1] - vs[0])).length / 2
    return a


def agrupar_cores(faces, maximo=6, passo=20):
    """Quantiza as cores das faces e funde as raras no vizinho mais próximo. Devolve [{cor, faces}]."""
    baldes = {}
    for cor, vs in faces:
        chave = tuple(round(c / passo) * passo for c in cor)
        b = baldes.setdefault(chave, {"area": 0.0, "soma": [0, 0, 0], "faces": []})
        a = max(_area(vs), 1e-9)
        b["area"] += a
        for i in range(3):
            b["soma"][i] += cor[i] * a
        b["faces"].append(vs)
    total = sum(b["area"] for b in baldes.values()) or 1
    medias = {k: tuple(round(b["soma"][i] / b["area"]) for i in range(3)) for k, b in baldes.items()}
    ordem = sorted(baldes, key=lambda k: -baldes[k]["area"])
    fica = [k for k in ordem[:maximo] if baldes[k]["area"] / total > 0.015 or k == ordem[0]]
    saida = {}
    for k in ordem:
        alvo = k if k in fica else min(fica, key=lambda f: _distancia(medias[f], medias[k]))
        s = saida.setdefault(alvo, {"cor": medias[alvo], "faces": []})
        s["faces"] += baldes[k]["faces"]
    return list(saida.values())


def _hsv(cor):
    return colorsys.rgb_to_hsv(*(c / 255 for c in cor))


def material_por_cor(cor):
    """Palpite de material do Roblox pela cor (pedra, madeira, ferro, tecido); o .json pode ser editado."""
    h, s, v = _hsv(cor)
    if s < 0.16:
        return "Slate" if v < 0.6 else "Metal"
    if 0.02 <= h <= 0.14:
        return "Wood"
    return "SmoothPlastic" if v > 0.6 else "Fabric"


def nome_do_grupo(cor, usados):
    h, s, v = _hsv(cor)
    if s < 0.16:
        base = "Escuro" if v < 0.3 else ("Pedra" if v < 0.62 else "Claro")
    elif 0.02 <= h <= 0.14:
        base = "Madeira"
    elif h < 0.02 or h > 0.9:
        base = "Vermelho"
    elif h < 0.2:
        base = "Ouro"
    elif h < 0.45:
        base = "Verde"
    elif h < 0.72:
        base = "Azul"
    else:
        base = "Roxo"
    n = usados.get(base, 0) + 1
    usados[base] = n
    return base if n == 1 else f"{base}{n}"


def decimar_para(objetos, tris_alvo):
    """Decima (Decimate, colapso) até ~tris_alvo triângulos no total. Devolve o total final."""
    contar = lambda: sum(len(p.vertices) - 2 for o in objetos for p in o.data.polygons)
    total = contar()
    if total <= tris_alvo:
        return total
    for o in objetos:
        bpy.context.view_layer.objects.active = o
        m = o.modifiers.new("dec", "DECIMATE")
        m.ratio = tris_alvo / total
        bpy.ops.object.modifier_apply(modifier=m.name)
    return contar()


def caixa_de(faces):
    pts = [v for _, vs in faces for v in vs]
    return (Vector((min(p[i] for p in pts) for i in range(3))), Vector((max(p[i] for p in pts) for i in range(3))))


def converter(fonte, caminho_obj, opc, saida_base):
    """Converte um OBJ num modelo exportado e devolve a entrada do manifesto.
    `opc`: nome, categoria, orcamento, alvo=(eixo, studs) | escala, rot=(graus x,y,z), pivo, sat, valor,
    maximo_cores, materiais={grupo: material}, uso."""
    lib.limpar()
    objetos = importar_obj(caminho_obj)
    if not objetos:
        raise RuntimeError(f"OBJ sem malha: {caminho_obj}")
    tris_ini = sum(len(p.vertices) - 2 for o in objetos for p in o.data.polygons)
    decimar_para(objetos, ORCAMENTO[opc.get("orcamento", "prop")])
    faces = faces_coloridas(objetos)
    rot = Matrix.Identity(4)
    for eixo, graus in zip("XYZ", opc.get("rot", (0, 0, 0))):
        rot = Matrix.Rotation(math.radians(graus), 4, eixo) @ rot
    faces = [(c, [rot @ v for v in vs]) for c, vs in faces]
    mn, mx = caixa_de(faces)
    dim = mx - mn
    if "alvo" in opc:
        eixo, studs = opc["alvo"]
        esc = studs / {"x": dim.x, "y": dim.y, "z": dim.z, "max": max(dim)}[eixo]
    else:
        esc = opc.get("escala", 5.0)
    faces = [(c, [v * esc for v in vs]) for c, vs in faces]
    mn, mx = caixa_de(faces)
    pivo = opc.get("pivo", "chao")
    cx, cy, cz = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2
    if pivo == "chao":  # base no chão, centrada em x/y
        o3 = Vector((cx, cy, mn.z))
    elif pivo == "centro":
        o3 = Vector((cx, cy, cz))
    elif pivo == "origem":  # a origem do modelo original (cabo/mão em armas do Quaternius)
        o3 = Vector((0, 0, 0))
    elif isinstance(pivo, tuple) and pivo[0] == "punho":  # armas: eixo longo = Y, ponta em -Y; fração do comprimento a partir da ponta traseira
        o3 = Vector((cx, mx.y - pivo[1] * (mx.y - mn.y), cz))
    else:
        raise ValueError(pivo)
    faces = [(afinar(c, opc.get("paleta", "cenario" if opc["categoria"] in ("esgoto", "taverna") else "sobrio"), opc.get("sat", 0.62), opc.get("valor", 0.92)), [v - o3 for v in vs]) for c, vs in faces]
    mn, mx = caixa_de(faces)
    grupos = agrupar_cores(faces, opc.get("maximo_cores", 6))
    return _gravar(fonte, opc, grupos, saida_base, mn, mx, tris_ini, esc)


def _gravar(fonte, opc, grupos, saida_base, mn, mx, tris_ini, esc):
    m = Modelo(opc["nome"])
    m.manter_origem = True
    usados = {}
    forcado = opc.get("materiais", {})
    cores = []
    for g in sorted(grupos, key=lambda g: -len(g["faces"])):
        cor = tuple(g["cor"])
        gn = nome_do_grupo(cor, usados)
        bm = m.grupo(gn, cor, forcado.get(gn, material_por_cor(cor)))
        for vs in g["faces"]:
            try:
                bm.faces.new([bm.verts.new(v) for v in vs])
            except ValueError:
                pass
        cores.append({"grupo": gn, "cor": list(cor), "material": m.grupos[gn]["material"]})
    tris = sum(len(f.verts) - 2 for gr in m.grupos.values() for f in gr["bm"].faces)
    objs = m.finalizar()
    m.exportar(objs, saida_base + ".fbx")
    return {
        "nome": opc["nome"], "categoria": opc["categoria"], "uso": opc.get("uso", ""),
        "origem": fonte["id"], "arquivo_origem": opc.get("arquivo", ""), "licenca": fonte["licenca"],
        "triangulos": tris, "triangulos_originais": tris_ini, "orcamento": ORCAMENTO[opc.get("orcamento", "prop")],
        "dimensoes_studs": [round(mx.x - mn.x, 2), round(mx.z - mn.z, 2), round(mx.y - mn.y, 2)],  # largura, altura, profundidade (eixos do Roblox)
        "escala_aplicada": round(esc, 3), "pivo": str(opc.get("pivo", "chao")),
        "cores": cores, "fbx": os.path.relpath(saida_base + ".fbx", RAIZ).replace("\\", "/"),
    }
