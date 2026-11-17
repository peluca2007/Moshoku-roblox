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
ANIMAIS = glob.glob(os.path.join(EXTERNOS, "animais-vol2", "*", "FBX"))  # Animal Pack Vol.2 (lobo), MOD4
ANIMAIS = ANIMAIS[0] if ANIMAIS else ""
PERSONAGENS = glob.glob(os.path.join(EXTERNOS, "personagens-ultimate", "*", "FBX"))  # Ultimate Animated Character Pack (goblin), MOD4
PERSONAGENS = PERSONAGENS[0] if PERSONAGENS else ""
URSO = os.path.join(EXTERNOS, "urso-branco", "x")  # Bear de Phelippeau Rudy (CC0, OpenGameArt, sem esqueleto), MOD6
GOLEM = os.path.join(EXTERNOS, "golem-knight", "x")  # Golem Knight (CC0, OpenGameArt), MOD6
TREANT = os.path.join(EXTERNOS, "treant-floresta", "x")  # Forest Monster de Cestmir Dammer (CC0, OpenGameArt), MOD6
PASTAS = {"monstros": MONSTROS, "easy": INIMIGOS, "animais": ANIMAIS, "personagens": PERSONAGENS, "golem": GOLEM, "treant": TREANT, "urso": URSO}


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


def regra_lobo(nome, x, _):
    """Ossos sem nome do Animal Pack: Bone.003 cabeça; 004-007 cauda; 014-019 patas da frente; 008-013 patas de trás."""
    n = nome.replace("_end", "")
    if n == "Bone.003": return "Cabeca"
    if n in ("Bone.004", "Bone.005", "Bone.006", "Bone.007"): return "Cauda"
    if n in ("Bone.014", "Bone.015", "Bone.016", "Bone.017", "Bone.018", "Bone.019"): return "Braco" + _lado(nome, x)
    if n in ("Bone.008", "Bone.009", "Bone.010", "Bone.011", "Bone.012", "Bone.013"): return "Perna" + _lado(nome, x)
    return "Corpo"


def regra_goblin(nome, x, _):
    if re.search(r"Head|Neck", nome): return "Cabeca"
    if re.search(r"Shoulder|UpperArm|LowerArm|Fist", nome): return "Braco" + _lado(nome, x)
    if re.search(r"UpperLeg|LowerLeg|Foot", nome): return "Perna" + _lado(nome, x)
    return "Corpo"


def regra_golem_osso(nome, x, _):
    if nome in ("bone", "bone5", "bone4", "bone6"): return "Braco" + _lado(nome, x)
    if nome in ("bone7", "bone9", "bone8", "bone10"): return "Perna" + _lado(nome, x)
    return "Corpo"


def regra_golem_objeto(nome, x):
    """O Golem Knight tem uma malha por peça (head, arm, leg...) e a cabeça pesa no osso do corpo: a parte vem do nome do objeto."""
    base = nome.split(".")[0]
    if base == "head": return "Cabeca"
    if base in ("arm", "hand", "shoulder"): return "Braco" + _lado(nome, x)
    if base in ("leg", "ankle", "foot"): return "Perna" + _lado(nome, x)
    return "Corpo"


def regra_treant(nome, x, _):
    if re.search(r"Head|Neck|Mouth", nome): return "Cabeca"
    if re.search(r"Shoulder|Arm|Hand|Finger|Toe[0-9]", nome): return "Braco" + _lado(nome, x)
    if re.search(r"Thigh|Leg|Foot|Footfinger", nome, re.I): return "Perna" + _lado(nome, x)
    return "Corpo"


def regra_urso(nome, x, _):
    return "Corpo"


def parte_urso(c):
    """Urso sem esqueleto (Bear.blend): partes pela posição do centro do polígono, em coordenadas do .blend (olha para +Y,
    cabeça em y > 1,5, pernas da frente em y 0,3..1,3 e de trás em y -1,6..-0,6, abaixo de z 1)."""
    if c.y > 1.5: return "Cabeca"
    if c.z < 1.05 and abs(c.x) > 0.2:
        lado = "D" if c.x < 0 else "E"  # depois do giro de 180 graus a direita do urso fica em -X
        if c.y > 0.25: return "Braco" + lado
        if c.y < -0.55: return "Perna" + lado
    return "Corpo"


def cor_urso(c):
    return "Pata" if (c.z < 0.22 and abs(c.x) > 0.2) else ("Focinho" if c.y > 2.2 else "Pelo")


# Módulo -> função(centro do polígono no mundo do Blender, antes do giro) -> parte (malha sem esqueleto), e seus pivôs (mundo do Blender).
PARTE_POLIGONO = {"UrsoQuaternius": parte_urso}
PIVOS_FIXOS = {"UrsoQuaternius": {"BracoD": (-0.5, 0.8, 1.55), "BracoE": (0.5, 0.8, 1.55), "PernaD": (-0.5, -1.0, 1.55), "PernaE": (0.5, -1.0, 1.55),
                                  "Cabeca": (0.0, 1.5, 1.35), "Corpo": (0.0, 0.0, 1.1)}}
# Cor por polígono (módulo -> função(centro) -> nome do grupo) e as cores dos grupos.
COR_POLIGONO = {"UrsoQuaternius": (cor_urso, {"Pelo": (112, 80, 54), "Pata": (58, 42, 32), "Focinho": (176, 140, 112)})}
# Modulo -> função(nome do objeto, x) que decide a parte pelo objeto (quando os pesos não separam as peças).
PARTE_OBJETO = {"GolemQuaternius": regra_golem_objeto}
# Partes sem osso próprio: pivô tirado da cabeça de um osso (módulo -> {parte: osso}).
PIVO_DE_OSSO = {"GolemQuaternius": {"Cabeca": "bone3"}}
# Cor fixa por material (módulo -> material -> (rgb, nome do grupo)); o pacote do golem vem sem cor (branco).
COR_POR_MATERIAL = {"GolemQuaternius": {
    "Material_0": ((86, 88, 92), "PedraEscura"), "Material_1": ((110, 112, 116), "Pedra"), "Material_2": ((98, 100, 104), "PedraEscura"),
    "Material_3": ((82, 84, 88), "PedraEscura"), "Material_4": ((136, 138, 142), "PedraClara"), "Material_5": ((255, 176, 70), "Brilho"),
    "Material_6": ((124, 126, 130), "Pedra"), "Material_7": ((108, 110, 114), "Pedra"), "Material_8": ((98, 122, 84), "Musgo"),
    "Material_9": ((120, 122, 126), "Pedra")}}
# Módulos coloridos por textura: cor amostrada no UV de cada polígono e reduzida a K cores (k-means) para limitar as peças.
TEXTURA_K = {"TreantQuaternius": 7}
# O .blend do treant perdeu os nós de textura na conversão: material -> imagem de cor (módulo -> {material: imagem}).
TEXTURA_IMG = {"TreantQuaternius": {"Monster": "monster-skin", "Tree": "skin_dieing.png"}}

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
    "LoboQuaternius": ("animais", "Wolf.fbx", regra_lobo, 6.4, "h", "quadrupede", None),
    "GoblinQuaternius": ("personagens", "Goblin_Male.fbx", regra_goblin, 4.4, "a", "humanoide", None),
    # MOD5: bandidos humanoides (Ultimate Animated Character Pack) com arma do Medieval Weapons Pack como peça `Arma`
    # MOD6: golem (Golem Knight, gltf, CC0) e treant (Forest Monster, blend, CC0); o urso é feito por geometria (ver ursos.py)
    "UrsoQuaternius": ("urso", "Bear.blend", regra_urso, 7.4, "h", "quadrupede", None),
    "GolemQuaternius": ("golem", "golem.gltf", regra_golem_osso, 8.0, "a", "pesado", None),
    "TreantQuaternius": ("treant", "forest-monster-final.blend", regra_treant, 14.0, "a", "pesado", None),
    "BandidoEspadaQuaternius": ("personagens", "Cowboy_Male.fbx", regra_goblin, 5.4, "a", "humanoide", None),
    "BandidoPorreteQuaternius": ("personagens", "Casual3_Male.fbx", regra_goblin, 5.4, "a", "humanoide", None),
}
# yaw em graus (rotação em Z do Blender) que põe a frente em -Y; descoberto olhando a pose de repouso.
YAW = {"UrsoQuaternius": 180.0}
# Onde a pose de repouso não mostra para onde a criatura olha: (ossos da frente, osso de referência) -> direção no plano XY.
FRENTE = {"LoboQuaternius": (["Bone.003"], "Bone"), "VespaQuaternius": (["Head"], "Abdomen"), "SlimeQuaternius": (["RightEye", "LeftEye"], "Body")}

# Aperto da paleta: o pacote é saturado e claro; o jogo é sóbrio (kit_lib.sobrio faz o mesmo para os outros kits).
SATURACAO, VALOR = 0.78, 0.92
# Cor do material clara demais sob a luz do jogo (lobo ficava azul-claro): cinza de lobo escurecido.
COR_FIXA = {"LoboQuaternius": (124, 116, 106)}
# O pacote de personagens traz pele preta (bonecos de vitrine); os humanos recebem tom de pele por módulo (material "Skin").
PELE = {"BandidoEspadaQuaternius": (204, 152, 118), "BandidoPorreteQuaternius": (178, 124, 92)}

# MOD5, arma como peça separada `Arma` (grupo "Arma_<Cor>"), na mão direita (osso Fist.R). Medidas do Medieval Weapons Pack
# (CC0, Quaternius): comprimento ao longo de +Z (ponta em +Z); `agarre` = ponto do cabo (z local) que fica na mão;
# `tipo` = atributo TipoArma (espada/porrete/arco/adaga/machado/cajado); `comp` = comprimento total em studs;
# `euler` = (inclinação em X, inclinação em Y, giro em Z) em graus (gira em Z primeiro): +Z = ponta para cima; X positivo leva a ponta para -Y (frente); Y negativo leva a ponta para -X (para fora da mão direita).
ARMAS = {
    "BandidoEspadaQuaternius": dict(arquivo="Sword_2.fbx", tipo="espada", comp=3.6, agarre=-0.25, euler=(12, -28, 0)),
    "BandidoPorreteQuaternius": dict(arquivo="Hammer_Small.fbx", tipo="porrete", comp=3.4, agarre=0.0, euler=(12, -28, 0)),
    "GoblinQuaternius": dict(arquivo="Dagger_2.fbx", tipo="adaga", comp=1.9, agarre=-0.2, euler=(12, -28, 0)),
}
ARMAS_DIR = glob.glob(os.path.join(EXTERNOS, "quaternius-weapons-2018", "*", "*", "FBX"))
ARMAS_DIR = ARMAS_DIR[0] if ARMAS_DIR else ""
METAIS = ("Steel", "LightSteel", "DarkSteel", "Gold")


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
    ext = os.path.splitext(caminho)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=caminho)
    elif ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=caminho)
    else:
        bpy.ops.import_scene.fbx(filepath=caminho)
    # Pose base: primeiro quadro do clipe de espera (Idle; senão Flying/Walk). Braços do esqueleto e asas saem do T.
    # Pacotes sem prefixo de objeto nas ações (gltf, blend) usam todas as ações.
    armaduras = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    for o in armaduras:
        acoes = [a for a in bpy.data.actions if a.name.startswith(o.name + "|")] or list(bpy.data.actions)
        escolhida = None
        for pref in ("Idle", "Flying", "Walk"):
            escolhida = next((a for a in acoes if a.name.endswith("_" + pref) or a.name.endswith("|" + pref) or a.name.lower() == pref.lower()), None)
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


def adicionar_arma(modelo, modulo, T, chave_cor, paleta):
    """MOD5: importa a arma do Medieval Weapons Pack e põe na mão direita (osso Fist.R) como grupo `Arma_<Cor>`.
    Devolve a posição da mão (espaço final autoral). Roda com o esqueleto do personagem ainda na cena."""
    from mathutils import Euler
    cfg = ARMAS[modulo]
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ARMAS_DIR, cfg["arquivo"]))
    novos = [o for o in bpy.data.objects if o not in antes and o.type == "MESH"]
    mao = None
    for a in [o for o in antes if o.type == "ARMATURE"]:
        if "Fist.R" in a.pose.bones:
            pb = a.pose.bones["Fist.R"]
            mao = T(a.matrix_world @ ((pb.head + pb.tail) / 2))
    assert mao is not None, "osso Fist.R não encontrado"
    zs = [(o.matrix_world @ v.co).z for o in novos for v in o.data.vertices]
    esc = cfg["comp"] / (max(zs) - min(zs))
    gira = Euler(tuple(math.radians(g) for g in cfg["euler"]), "ZYX").to_matrix()
    grip = Vector((0, 0, cfg["agarre"]))
    for o in novos:
        for p in o.data.polygons:
            mat = o.material_slots[p.material_index].material if o.material_slots and p.material_index < len(o.material_slots) else None
            cor = chave_cor(mat)
            if mat and mat.name in METAIS:
                paleta[cor] = (paleta[cor][0], "Metal")
            bm = modelo.g("Arma", cor)
            vs = [bm.verts.new(mao + gira @ (((o.matrix_world @ o.data.vertices[i].co) - grip) * esc)) for i in p.vertices]
            try:
                bm.faces.new(vs)
            except ValueError:
                pass
    modelo.tipo_arma = cfg["tipo"]
    return mao


TRANSPARENTES = set()


def amostrar_texturas(malhas, k, mapa=None):
    """Cor de cada polígono = pixel da textura no UV do centro (sRGB do arquivo), reduzida a k cores por k-means.
    Devolve {(índice da malha, polígono): (r, g, b)} já com o aperto de SATURACAO/VALOR."""
    import numpy as np
    amostras = {}
    imagens = {}
    for mi, o in enumerate(malhas):
        uv = o.data.uv_layers.active
        if not uv:
            continue
        for p in o.data.polygons:
            mat = o.material_slots[p.material_index].material if o.material_slots and p.material_index < len(o.material_slots) else None
            img = None
            if mat and mapa and mat.name in mapa:
                img = bpy.data.images.get(mapa[mat.name])
            elif mat and mat.use_nodes:
                img = next((n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0), None)
            if img is None:
                continue
            if img.name not in imagens:
                imagens[img.name] = (np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], -1), img.size)
            px, (w, h) = imagens[img.name]
            u = sum(uv.data[l].uv.x for l in p.loop_indices) / p.loop_total
            v = sum(uv.data[l].uv.y for l in p.loop_indices) / p.loop_total
            texel = px[min(max(int(v * h), 0), h - 1), min(max(int(u * w), 0), w - 1)]
            if texel.shape[0] > 3 and texel[3] < 0.5:  # cartão de folha transparente: o polígono não entra no modelo
                TRANSPARENTES.add((mi, p.index))
                continue
            amostras[(mi, p.index)] = texel[:3]
    if not amostras:
        return {}
    chaves = list(amostras)
    X = np.array([amostras[c] for c in chaves])
    rng = np.random.default_rng(1)
    centros = X[rng.choice(len(X), size=min(k, len(X)), replace=False)]
    for _ in range(25):
        rotulo = np.argmin(((X[:, None, :] - centros[None]) ** 2).sum(-1), axis=1)
        for j in range(len(centros)):
            if (rotulo == j).any():
                centros[j] = X[rotulo == j].mean(0)
    saida = {}
    for c, r in zip(chaves, rotulo):
        h_, s_, v_ = colorsys.rgb_to_hsv(*[float(x) for x in centros[r]])
        rr, gg, bb = colorsys.hsv_to_rgb(h_, s_ * SATURACAO, v_ * VALOR)
        saida[c] = (round(rr * 255), round(gg * 255), round(bb * 255))
    return saida


def converter(modulo, cfg):
    TRANSPARENTES.clear()
    pasta, arquivo, regra, alvo, medida, tipo, _ = cfg
    caminho = os.path.join(PASTAS[pasta], arquivo)
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

    malhas = [o for o in bpy.data.objects if o.type == "MESH" and (o.vertex_groups or o.material_slots) and len(o.data.polygons) > 0]  # sem ajudantes (formas de controle)
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

    def chave_cor(mat, rgb=None, base=None):
        if rgb is None and mat is not None and mat.name in COR_POR_MATERIAL.get(modulo, {}):
            rgb, base = COR_POR_MATERIAL[modulo][mat.name]
        if rgb is None:
            rgb = COR_FIXA.get(modulo) or (PELE[modulo] if mat and mat.name.startswith("Skin") and modulo in PELE else None) or ((40, 32, 30) if mat and mat.name.startswith("Face") and modulo in PELE else None) or cor_do_material(mat)
        base = base or re.sub(r"[^A-Za-z]", "", mat.name if mat else "Cor") or "Cor"
        nome = base
        i = 0
        while nome in paleta and paleta[nome][0] != rgb:
            i += 1
            nome = base + "X" * i
        paleta[nome] = (rgb, "Plastic")
        return nome

    cores_tex = amostrar_texturas(malhas, TEXTURA_K[modulo], TEXTURA_IMG.get(modulo)) if modulo in TEXTURA_K else {}

    raizes = {}  # parte -> [posições das cabeças dos ossos-raiz dessa parte]
    for nome, (cabeca, pai) in ossos.items():
        parte = parte_do_osso(nome)
        pai_parte = parte_do_osso(pai) if pai else None
        if parte != "Corpo" and pai_parte != parte:
            raizes.setdefault(parte, []).append(cabeca)

    for parte, ponto in PIVOS_FIXOS.get(modulo, {}).items():
        raizes.setdefault(parte, [T(Vector(ponto))])
    for parte, osso in PIVO_DE_OSSO.get(modulo, {}).items():
        raizes.setdefault(parte, [ossos[osso][0]])
    partes_verts = {}  # parte -> {(índice da malha, vértice)}  (para os clipes por peça rígida)
    for mi, (o, lista) in enumerate(zip(malhas, pts)):
        grupos_v = [[(o.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in o.data.vertices]
        olhos_soltos = o.name.lower().startswith("eye")
        eh_olho = not o.vertex_groups or all(n not in ossos for n, _ in (grupos_v[0] if grupos_v else []))
        for p in o.data.polygons:
            peso = {}
            for i in p.vertices:
                for nome, w in grupos_v[i]:
                    parte = parte_do_osso(nome)
                    peso[parte] = peso.get(parte, 0.0) + w
            parte = "Cabeca" if (eh_olho and not peso) else (max(peso, key=peso.get) if peso else "Corpo")
            if olhos_soltos:  # malha dos olhos com armadura própria (parada): vai na Cabeca e acompanha a cabeça (ANIM2)
                parte = "Cabeca"
            if (mi, p.index) in TRANSPARENTES:
                continue
            centro_p = sum((o.matrix_world @ o.data.vertices[i].co for i in p.vertices), Vector()) / len(p.vertices)
            if modulo in PARTE_POLIGONO:
                parte = PARTE_POLIGONO[modulo](centro_p)
            if modulo in PARTE_OBJETO:
                parte = PARTE_OBJETO[modulo](o.name, sum(lista[i].x for i in p.vertices) / len(p.vertices))
            mat = o.material_slots[p.material_index].material if o.material_slots and p.material_index < len(o.material_slots) else None
            if modulo in COR_POLIGONO:
                fn_cor, tabela = COR_POLIGONO[modulo]
                nome_cor = fn_cor(centro_p)
                cor = chave_cor(mat, tabela[nome_cor], nome_cor)
            else:
                cor = chave_cor(mat, cores_tex.get((mi, p.index)), "Tex" if (mi, p.index) in cores_tex else None)
            bm = modelo.g(parte, cor)
            if not olhos_soltos:  # a armadura dos olhos não anima: fora do ajuste rígido
                partes_verts.setdefault(parte, set()).update((mi, i) for i in p.vertices)
            vs = [bm.verts.new(T(lista[i])) for i in p.vertices]
            try:
                bm.faces.new(vs)
            except ValueError:
                pass

    mao_arma = None
    if modulo in ARMAS:
        mao_arma = adicionar_arma(modelo, modulo, T, chave_cor, paleta)

    if opcoes_clipes:
        import numpy as np
        import criaturas_clipes as clipes
        rot_np, c_np = np.array(rot), np.array(centro_xy)
        Tnp = lambda A: ((A - c_np) * esc) @ rot_np.T  # noqa: E731
        pts_np = [Tnp(np.array([tuple(v) for v in lista])) for lista in pts]
        pivos_aut = {}
        for parte, lista in raizes.items():
            if parte in partes_verts:
                c = sum(lista, Vector()) / len(lista)
                pivos_aut[parte] = (c.x, c.y, c.z)
        pivos_aut.setdefault("Corpo", (0, 0, alvo * 0.3))
        todos_np = np.concatenate(pts_np)
        desloc = ((todos_np[:, 0].min() + todos_np[:, 0].max()) / 2, (todos_np[:, 1].min() + todos_np[:, 1].max()) / 2, todos_np[:, 2].min())
        clipes.gerar(bpy, modulo, malhas, partes_verts, pts_np, Tnp, pivos_aut, desloc)

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
    if mao_arma is not None:  # o pivô de `Arma` só indica de que braço ela é (AnimacaoCriatura.bracoDaArma)
        modelo.pivo("Arma", mao_arma.x, mao_arma.y, mao_arma.z)
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


opcoes_clipes = False


def main():
    global opcoes_clipes
    opcoes = lib.argumentos({"so": "", "clipes": "0"})
    opcoes_clipes = opcoes["clipes"] == "1"
    quais = [q for q in opcoes["so"].split(",") if q]
    for modulo, cfg in CRIATURAS.items():
        if quais and not any(q.lower() in modulo.lower() or q.lower() in cfg[1].lower() for q in quais):
            continue
        converter(modulo, cfg)


main()
