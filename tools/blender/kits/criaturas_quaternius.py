"""Criaturas CC0 do Quaternius (Monster Pack Animated + Easy Animated Enemy Pack) -> peças rígidas por junta (MOD3).

Roda dentro do Blender:  python tools/blender_rodar.py tools/blender/kits/criaturas_quaternius.py [--so Rat,Spider]

Cada FBX tem malha com pesos de osso. Aqui a malha é lida na pose de repouso, cada polígono vai para a parte
(Corpo, Cabeca, BracoE/D, PernaE/D, Cauda) do osso de maior peso e vira um grupo "<Parte>_<Cor>" (cor do material do
pacote). Saída no MESMO contrato de `tools/blender/criaturas.py`: FBX + .json com `grupos` e `pivos` (coordenadas do Roblox,
origem no centro da base), para o `AnimacaoCriatura` e o `CriaturaAnimada` animarem sem esqueleto. As curvas de
animação do pacote NÃO são usadas (ver docs/ARTE.md, "MOD3").

Saída: build/criaturas/<Modulo>.fbx|.json|.png  (fora do git). Fontes e licença: tools/blender/kits/FONTES.md.
"""
import colorsys
import glob
import json
import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
BLENDER = os.path.dirname(AQUI)
sys.path.insert(0, BLENDER)
sys.path.insert(0, AQUI)
import lib  # noqa: E402
from criaturas import _Criatura  # noqa: E402

RAIZ = os.environ.get("MOSHOKU_BUILD") or os.path.join(os.path.dirname(os.path.dirname(BLENDER)), "build")
EXTERNOS = os.path.join(RAIZ, "externos")
SAIDA = os.path.join(RAIZ, "criaturas")
MONSTROS = os.path.join(EXTERNOS, "monster-pack", "FBX")
INIMIGOS = glob.glob(os.path.join(EXTERNOS, "easy-enemy", "*", "FBX"))
INIMIGOS = INIMIGOS[0] if INIMIGOS else ""


# ---------------------------------------------------------------- regras osso -> parte
def _lado(nome, x):
    """D/E pela geometria (criatura olha para -Y: a direita dela fica em -X); sem lateralidade -> pelo nome."""
    if abs(x) > 0.04:
        return "D" if x < 0 else "E"
    return "D" if re.search(r"\.R\b|R\.", nome) else "E"


def regra_rato(nome, x, _):
    if re.search(r"Head|Neck", nome): return "Cabeca"
    if "Tail" in nome: return "Cauda"
    if re.search(r"Front(Leg|UpLeg|LowLeg|Foot)", nome): return "Braco" + _lado(nome, x)
    if re.search(r"Back(Leg|UpLeg|LowLeg|Foot)", nome): return "Perna" + _lado(nome, x)
    return "Corpo"


def regra_aranha(nome, x, _):
    if nome.startswith("Head"): return "Cabeca"
    m = re.match(r"(Front|MidFront|MidBack|Back)(Leg|Foot)", nome)
    if m and "PoleTarget" not in nome:
        idx = ["Front", "MidFront", "MidBack", "Back"].index(m.group(1))
        lado = _lado(nome, x)
        # marcha alternada: pernas em diagonal balançam juntas
        return "PernaE" if (idx + (1 if lado == "D" else 0)) % 2 == 0 else "PernaD"
    return "Corpo"


def regra_esqueleto(nome, x, _):
    if re.search(r"Head|Neck", nome): return "Cabeca"
    if re.search(r"UpperLeg|DownLeg", nome):
        return ("Braco" if ".001" in nome else "Perna") + _lado(nome, x)
    return "Corpo"


def regra_slime(nome, x, _):
    if re.search(r"Head|Neck|Eye", nome): return "Cabeca"
    if re.search(r"Shoulder|LowerArm|Hand", nome): return "Braco" + _lado(nome, x)
    return "Corpo"


def regra_morcego(nome, x, _):
    if re.search(r"Head|Face|Nose|Neck", nome): return "Cabeca"
    if re.search(r"Shoulder|Wing", nome): return "Braco" + _lado(nome, x)
    if re.search(r"Leg|Feet", nome): return "Perna" + _lado(nome, x)
    if "Tail" in nome: return "Cauda"
    return "Corpo"


def regra_serpente(nome, x, _):
    if re.search(r"Head|Neck|Mouth|Tongue", nome): return "Cabeca"
    if nome.startswith("Tail"): return "Cauda"
    return "Corpo"


def regra_sapo(nome, x, _):
    if re.search(r"Head|Neck", nome): return "Cabeca"
    if re.search(r"Front(Leg|UpLeg|LowLeg|Foot)", nome): return "Braco" + _lado(nome, x)
    if re.search(r"Back(Leg|UpLeg|LowLeg|Foot|Hip)", nome): return "Perna" + _lado(nome, x)
    return "Corpo"


def regra_vespa(nome, x, _):
    if re.search(r"Head|Neck", nome): return "Cabeca"
    if "Wing" in nome: return "Braco" + _lado(nome, x)
    if re.search(r"Abdomen|Sting", nome): return "Cauda"
    if "Leg" in nome: return "Perna" + _lado(nome, x)
    return "Corpo"


# Modulo -> (arquivo, regra, medida alvo em studs, "h" maior dimensão horizontal | "a" altura, tipo de animação, yaw extra graus,
# arquivo de origem do osso que aponta a frente)
CRIATURAS = {
    "RatoQuaternius": ("easy", "Rat.fbx", regra_rato, 4.6, "h", "quadrupede", None),
    "AranhaQuaternius": ("easy", "Spider.fbx", regra_aranha, 5.2, "h", "aranha", None),
    "SerpenteQuaternius": ("easy", "Snake.fbx", regra_serpente, 4.2, "h", "quadrupede", None),
    "SapoQuaternius": ("easy", "Frog.fbx", regra_sapo, 3.4, "h", "quadrupede", None),
    "VespaQuaternius": ("easy", "Wasp.fbx", regra_vespa, 3.6, "h", "voador", None),
    "EsqueletoQuaternius": ("monstros", "Skeleton.fbx", regra_esqueleto, 5.6, "a", "humanoide", None),
    "SlimeQuaternius": ("monstros", "Slime.fbx", regra_slime, 3.2, "h", "pesado", None),
    "MorcegoQuaternius": ("monstros", "Bat.fbx", regra_morcego, 4.4, "h", "voador", None),
    "DragaoQuaternius": ("monstros", "Dragon.fbx", regra_morcego, 9.0, "h", "voador", None),
}
# yaw em graus (rotação em Z do Blender) que põe a frente em -Y; descoberto olhando a pose de repouso.
YAW = {}
# Onde a pose de repouso não mostra para onde a criatura olha: (ossos da frente, osso de referência) -> direção no plano XY.
FRENTE = {"VespaQuaternius": (["Head"], "Abdomen"), "SlimeQuaternius": (["RightEye", "LeftEye"], "Body")}

# Aperto da paleta: o pacote é saturado e claro; o jogo é sóbrio (kit_lib.sobrio faz o mesmo para os outros kits).
SATURACAO, VALOR = 0.78, 0.92


def _lin_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def _srgb_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def cor_do_material(mat):
    cor = tuple(mat.diffuse_color[:3]) if mat else (0.6, 0.6, 0.6)
    if mat and mat.use_nodes:
        for no in mat.node_tree.nodes:
            if no.type == "BSDF_PRINCIPLED":
                cor = tuple(no.inputs["Base Color"].default_value[:3])
    rgb = [_lin_srgb(c) for c in cor]
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    r, g, b = colorsys.hsv_to_rgb(h, s * SATURACAO, v * VALOR)
    return (round(r * 255), round(g * 255), round(b * 255))


def importar(caminho):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=caminho)
    # Pose base: primeiro quadro do clipe de espera (Idle; senão Flying/Walk). Braços do esqueleto e asas saem do T.
    for o in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
        acoes = [a for a in bpy.data.actions if a.name.startswith(o.name + "|")]
        escolhida = None
        for pref in ("Idle", "Flying", "Walk"):
            escolhida = next((a for a in acoes if a.name.endswith("_" + pref)), None)
            if escolhida:
                break
        o.animation_data_create().action = escolhida
        o.data.pose_position = "POSE"
        if escolhida:
            bpy.context.scene.frame_set(int(escolhida.frame_range[0]))
    bpy.context.view_layer.update()


def renderizar(objetos, caminho):
    """Prévia 3/4 pela frente (-Y), luz de estúdio, sem sombra projetada (a do Workbench duplica a silhueta)."""
    cena = bpy.context.scene
    cena.render.engine = "BLENDER_WORKBENCH"
    cena.display.shading.light = "STUDIO"
    cena.display.shading.color_type = "OBJECT"
    cena.display.shading.show_shadows = False
    cena.display.shading.show_cavity = False
    cena.render.resolution_x, cena.render.resolution_y = 640, 512
    cena.world = bpy.data.worlds.new("Fundo")
    cena.world.color = (0.45, 0.55, 0.62)
    minimo = Vector((min((o.matrix_world @ Vector(c))[i] for o in objetos for c in o.bound_box) for i in range(3)))
    maximo = Vector((max((o.matrix_world @ Vector(c))[i] for o in objetos for c in o.bound_box) for i in range(3)))
    centro, tam = (minimo + maximo) / 2, maximo - minimo
    dist = max(tam.x, tam.y, tam.z) * 1.9 + 1.5
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cena.collection.objects.link(cam)
    cam.location = centro + Vector((dist * 0.7, -dist * 0.9, dist * 0.45))
    alvo = bpy.data.objects.new("Alvo", None)
    cena.collection.objects.link(alvo)
    alvo.location = centro
    regra = cam.constraints.new("TRACK_TO")
    regra.target, regra.track_axis, regra.up_axis = alvo, "TRACK_NEGATIVE_Z", "UP_Y"
    cena.camera = cam
    chao = bpy.data.objects.new("Chao", bpy.data.meshes.new("Chao"))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=dist * 1.6)
    bm.to_mesh(chao.data)
    bm.free()
    chao.location = (centro.x, centro.y, minimo.z - 0.01)
    chao.color = (0.20, 0.30, 0.15, 1.0)
    cena.collection.objects.link(chao)
    cena.render.filepath = os.path.abspath(caminho)
    bpy.ops.render.render(write_still=True)


def converter(modulo, cfg):
    pasta, arquivo, regra, alvo, medida, tipo, _ = cfg
    caminho = os.path.join(MONSTROS if pasta == "monstros" else INIMIGOS, arquivo)
    importar(caminho)
    dg = bpy.context.evaluated_depsgraph_get()
    yaw = math.radians(YAW.get(modulo, 0.0))
    if modulo in FRENTE:
        alvos, ref = FRENTE[modulo]
        pos = {pb.name: arm.matrix_world @ pb.head for arm in bpy.data.objects if arm.type == "ARMATURE" for pb in arm.pose.bones}
        d = sum((pos[n] for n in alvos), Vector()) / len(alvos) - pos[ref]
        yaw = math.radians(-90) - math.atan2(d.y, d.x)
        print(f"YAW {modulo}: {math.degrees(yaw):.0f}")
    rot = lib.Matrix.Rotation(yaw, 3, "Z")

    malhas = [o for o in bpy.data.objects if o.type == "MESH"]
    # pontos já na pose de repouso, mundo do Blender
    pts = []
    for o in malhas:
        me = o.evaluated_get(dg).to_mesh()
        pts.append([o.matrix_world @ v.co for v in me.vertices])
        o.evaluated_get(dg).to_mesh_clear()
    todos = [p for lista in pts for p in lista]
    mn = Vector((min(p.x for p in todos), min(p.y for p in todos), min(p.z for p in todos)))
    mx = Vector((max(p.x for p in todos), max(p.y for p in todos), max(p.z for p in todos)))
    dim = rot @ (mx - mn)
    horizontal = max(abs(rot.col[0].x * (mx - mn).x) + abs(rot.col[0].y * (mx - mn).y),
                     abs(rot.col[1].x * (mx - mn).x) + abs(rot.col[1].y * (mx - mn).y))
    medida_atual = (mx - mn).z if medida == "a" else horizontal
    esc = alvo / medida_atual
    centro_xy = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))

    def T(p):
        return (rot @ ((p - centro_xy) * esc))

    # ossos: cabeça de cada um, no espaço do modelo final
    ossos = {}
    for a in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
        for b in a.data.bones:
            pb = a.pose.bones[b.name]
            ossos[b.name] = (T(a.matrix_world @ pb.head), b.parent.name if b.parent else None)

    def parte_do_osso(nome):
        if nome in ossos:
            return regra(nome, ossos[nome][0].x, None)
        return "Cabeca" if "Bone" in nome or "Eye" in nome else "Corpo"

    paleta, chaves = {}, {}  # cor_nome -> (rgb, material)
    modelo = _Criatura(modulo, paleta)

    def chave_cor(mat):
        rgb = cor_do_material(mat)
        base = re.sub(r"[^A-Za-z]", "", mat.name if mat else "Cor") or "Cor"
        nome = base
        i = 0
        while nome in paleta and paleta[nome][0] != rgb:
            i += 1
            nome = base + "X" * i
        paleta[nome] = (rgb, "Plastic")
        return nome

    raizes = {}  # parte -> [posições das cabeças dos ossos-raiz dessa parte]
    for nome, (cabeca, pai) in ossos.items():
        parte = parte_do_osso(nome)
        pai_parte = parte_do_osso(pai) if pai else None
        if parte != "Corpo" and pai_parte != parte:
            raizes.setdefault(parte, []).append(cabeca)

    for o, lista in zip(malhas, pts):
        grupos_v = [[(o.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in o.data.vertices]
        eh_olho = not o.vertex_groups or all(n not in ossos for n, _ in (grupos_v[0] if grupos_v else []))
        for p in o.data.polygons:
            peso = {}
            for i in p.vertices:
                for nome, w in grupos_v[i]:
                    parte = parte_do_osso(nome)
                    peso[parte] = peso.get(parte, 0.0) + w
            parte = "Cabeca" if (eh_olho and not peso) else (max(peso, key=peso.get) if peso else "Corpo")
            mat = o.material_slots[p.material_index].material if o.material_slots and p.material_index < len(o.material_slots) else None
            cor = chave_cor(mat)
            bm = modelo.g(parte, cor)
            vs = [bm.verts.new(T(lista[i])) for i in p.vertices]
            try:
                bm.faces.new(vs)
            except ValueError:
                pass

    for o in list(bpy.data.objects):  # remove o FBX original da cena (só interessam as peças novas)
        bpy.data.objects.remove(o, do_unlink=True)
    objetos = modelo.finalizar()
    for ob in objetos:  # a prévia do Blender trata a cor do objeto como linear; o JSON segue em sRGB
        ob.color = (*[_srgb_lin(c / 255.0) for c in modelo.grupos[ob.name]["cor"]], 1.0)
    # raízes -> pivôs (média das cabeças dos ossos-raiz de cada parte)
    for parte, lista in raizes.items():
        if any(g.startswith(parte + "_") for g in modelo.grupos):
            c = sum(lista, Vector()) / len(lista)
            modelo.pivo(parte, c.x, c.y, c.z)
    for parte in ("Corpo",):
        if parte not in modelo.pivos_autorais:
            modelo.pivo(parte, 0, 0, alvo * 0.3)
    modelo.apoiar_no_chao(objetos)
    saida = os.path.join(SAIDA, modulo + ".fbx")
    previa = os.path.join(SAIDA, modulo + ".png")
    modelo.exportar(objetos, saida, "")
    renderizar(objetos, previa)
    # contagem para o relatório
    tris = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in objetos)
    caixa = json.load(open(os.path.join(SAIDA, modulo + ".json"), encoding="utf-8"))["dimensoes"]
    ph = modelo.pivos_autorais.get("Cabeca")
    print(f"FRENTE {modulo}: cabeça em y(autoral)={ph[1] if ph else None:.2f} (corpo {modelo.pivos_autorais.get('Corpo', (0,0,0))[1]:.2f}); frente deve ser y negativo")
    print(f"RESUMO {modulo}: {len(objetos)} peças, {tris} tris, caixa {caixa}, tipo {tipo}, partes {sorted(set(g.split('_')[0] for g in modelo.grupos))}")


def main():
    opcoes = lib.argumentos({"so": ""})
    quais = [q for q in opcoes["so"].split(",") if q]
    for modulo, cfg in CRIATURAS.items():
        if quais and not any(q.lower() in modulo.lower() or q.lower() in cfg[1].lower() for q in quais):
            continue
        converter(modulo, cfg)


main()
