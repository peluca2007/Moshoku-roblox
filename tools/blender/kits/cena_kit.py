"""Cena de prévia dos kits (Blender sem janela): importa os FBX gravados em build/kits (o que o pipeline
enviaria de verdade), pinta cada MeshPart pela cor do .json e renderiza folhas de contato e cenas.
Não envia nada a lugar nenhum."""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
import lib  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
KITS = os.path.join(RAIZ, "build", "kits")
PREVIA = os.path.join(KITS, "previa")

_materiais = {}


def _srgb_para_linear(c):
    return tuple(((x / 255.0) / 12.92) if x / 255.0 <= 0.04045 else (((x / 255.0) + 0.055) / 1.055) ** 2.4 for x in c)


def _novo_material(nome, cor, mat):
    mt = bpy.data.materials.new(nome)
    mt.use_nodes = True
    p = mt.node_tree.nodes["Principled BSDF"]
    lin = _srgb_para_linear(cor)
    p.inputs["Base Color"].default_value = (*lin, 1.0)
    p.inputs["Roughness"].default_value = 0.9
    if mat == "Neon":
        p.inputs["Emission Color"].default_value = (*lin, 1.0)
        p.inputs["Emission Strength"].default_value = 4.0
    elif mat == "Glass":
        p.inputs["Roughness"].default_value = 0.1
    elif mat in ("Metal", "DiamondPlate"):
        p.inputs["Metallic"].default_value = 0.6
        p.inputs["Roughness"].default_value = 0.5
    elif mat == "SmoothPlastic":
        p.inputs["Roughness"].default_value = 0.55
    return mt


def material(cor, mat):
    chave = (tuple(cor), mat)
    if chave not in _materiais:
        _materiais[chave] = _novo_material(f"m{len(_materiais)}_{mat}", cor, mat)
    return _materiais[chave]


def carregar(categoria, nome, x=0.0, y=0.0, giro=0.0, rot_x=0.0, escala=1.0, z=0.0):
    """Importa build/kits/<categoria>/<nome>.fbx, pinta pelos grupos do .json e posiciona em (x, y).
    Devolve a lista de objetos (todos filhos soltos, sem hierarquia)."""
    base = os.path.join(KITS, categoria, nome)
    with open(base + ".json", encoding="utf-8") as f:
        dados = json.load(f)
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=base + ".fbx", axis_forward="-Z", axis_up="Y")
    novos = [o for o in bpy.data.objects if o not in antes]
    malhas = [o for o in novos if o.type == "MESH"]
    for o in novos:
        o.parent = None
    for o in malhas:
        grupo = o.name.split(".")[0]
        g = dados["grupos"].get(grupo)
        if g is None:  # nome com prefixo do arquivo: tenta pelo mais parecido
            g = next((v for k, v in dados["grupos"].items() if o.name.startswith(k)), None)
        o.data.materials.clear()
        if g:
            o.data.materials.append(material(g["cor"], g["material"]))
    for o in novos:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    malhas = [o for o in malhas if o.name in bpy.data.objects]
    m = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(giro), 4, "Z") @ Matrix.Rotation(math.radians(rot_x), 4, "X") @ Matrix.Scale(escala, 4)
    for o in malhas:
        o.matrix_world = m @ o.matrix_world
        o.data.update()
    bpy.context.view_layer.update()
    return malhas


def caixa(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return Vector((min(p[i] for p in pts) for i in range(3))), Vector((max(p[i] for p in pts) for i in range(3)))


def apoiar(objs):
    """Desce o conjunto até o menor z ficar em 0 (peças exibidas em rot_x, p. ex. armas em pé)."""
    mn, _ = caixa(objs)
    for o in objs:
        o.location.z -= mn.z
    bpy.context.view_layer.update()


def rotulo(texto, x, y, tam=0.5, cor=(0.92, 0.9, 0.84)):
    bpy.ops.object.text_add(location=(x, y, 0.02), rotation=(0, 0, 0))
    t = bpy.context.active_object
    t.data.body = texto
    t.data.size = tam
    t.data.align_x = "CENTER"
    t.data.extrude = 0.01
    t.data.materials.append(material(tuple(int(c * 255) for c in cor), "SmoothPlastic"))
    return t


def preparar_cena(res=(1600, 1000), amostras=40, ceu=(0.55, 0.57, 0.62), chao=(0.30, 0.28, 0.26), sol=(1.0, 0.92, 0.78), energia=3.2):
    lib.limpar()
    _materiais.clear()
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = amostras
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = res
    mundo = bpy.data.worlds.new("Mundo")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs[0].default_value = (*ceu, 1)
    mundo.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    cena.world = mundo
    s = bpy.data.lights.new("Sol", "SUN")
    s.energy, s.color, s.angle = energia, sol, math.radians(5)
    so = bpy.data.objects.new("Sol", s)
    cena.collection.objects.link(so)
    so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-35))
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, -0.01))
    pl = bpy.context.active_object
    pl.scale = (400, 400, 1)
    pl.name = "ChaoDePrevia"
    pl.data.materials.append(_novo_material("chaoprev", tuple(int(c * 255) for c in chao), "Slate"))
    return cena


def camera(cena, alvo, dist, azimute=-30.0, elevacao=35.0, lente=85):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cena.collection.objects.link(cam)
    cam.data.lens = lente
    cam.data.clip_end = 2000
    az, el = math.radians(azimute), math.radians(elevacao)
    cam.location = Vector(alvo) + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * dist
    ponto = bpy.data.objects.new("Alvo", None)
    ponto.location = alvo
    cena.collection.objects.link(ponto)
    r = cam.constraints.new("TRACK_TO")
    r.target, r.track_axis, r.up_axis = ponto, "TRACK_NEGATIVE_Z", "UP_Y"
    cena.camera = cam
    return cam


def renderizar(caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.context.scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    print("PNG", caminho)


def folha(titulo_arquivo, itens, colunas=6, espaco=1.6, res=(2000, 1300), exibir=None, escala_cam=1.0):
    """Folha de contato. `itens`: [(categoria, nome)]. `exibir`: {nome: dict(rot_x=, giro=)} só para mostrar."""
    exibir = exibir or {}
    cena = preparar_cena(res)
    celulas = []
    for c, n in itens:
        ex = exibir.get(n, {})
        o = carregar(c, n, **ex)
        apoiar(o)
        mn, mx = caixa(o)
        celulas.append((n, o, mn, mx))
    # layout em fileiras: cada peça usa a largura que tem, a fileira quebra ao passar do alvo
    area = sum((mx.x - mn.x + espaco) * (mx.y - mn.y + espaco) for _, _, mn, mx in celulas)
    alvo_larg = max(math.sqrt(area) * 1.9, max(mx.x - mn.x for _, _, mn, mx in celulas) + espaco)
    fileiras, atual, usado = [], [], 0.0
    for c in celulas:
        w = c[3].x - c[2].x + espaco
        if atual and usado + w > alvo_larg:
            fileiras.append(atual)
            atual, usado = [], 0.0
        atual.append(c)
        usado += w
    fileiras.append(atual)
    y = 0.0
    limites = [1e9, -1e9, 1e9, -1e9]
    for fila in fileiras:
        prof = max(mx.y - mn.y + 1.1 * (mx.z - mn.z) for _, _, mn, mx in fila) + espaco + 0.9
        x = 0.0
        for n, o, mn, mx in fila:
            w = mx.x - mn.x
            dx = x + w / 2 - (mn.x + mx.x) / 2
            dy = y - prof / 2 - (mn.y + mx.y) / 2 + 0.45
            for ob in o:
                ob.location.x += dx
                ob.location.y += dy
            rotulo(n, x + w / 2, y - prof + 0.35, tam=0.42)
            x += w + espaco
        limites = [min(limites[0], 0), max(limites[1], x), min(limites[2], y - prof), max(limites[3], y)]
        y -= prof
    cx, cy = (limites[0] + limites[1]) / 2, (limites[2] + limites[3]) / 2
    ancho, prof_total = limites[1] - limites[0], limites[3] - limites[2]
    camera(cena, (cx, cy, 0.5), dist=2.9 * max(ancho, prof_total * res[0] / res[1]) * escala_cam, azimute=-12, elevacao=50)
    renderizar(os.path.join(PREVIA, titulo_arquivo))
