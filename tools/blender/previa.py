"""Prévias dos modelos de vegetação e props (V3): monta os modelos em fileira numa cena de
Blender, pinta cada grupo com sua cor, sol baixo dourado + céu de fim de tarde, câmera 3/4,
e renderiza PNG em build/blender/previas/. Não exporta nada e não toca o Roblox.

Uso (sem janela):
  python tools/blender_rodar.py tools/blender/previa.py --conjunto floresta [--individuais 1] [--escala 1.0]
Conjuntos: floresta, campos, vila, ruinas, todos (gera as pranchas de cada conjunto + prancha.png), trajes, avatar, criaturas
(criaturas: prancha_criaturas.png, bonecos de escala de 5 studs, vistas 3/4 e de cima a 50 graus; --individuais 1 grava criatura_<rotulo>.png; --itens a,b so esses)
(avatar: prancha_avatar.png com 12 bonecos de cubos montados + imagens individuais das peças; ver `prancha_avatar`).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import lib  # noqa: E402
from mathutils import Vector  # noqa: E402

import formas  # noqa: E402
import ruinas  # noqa: E402
import vegetacao  # noqa: E402

try:
    import props  # noqa: E402
except ImportError:
    props = None
import avatar  # noqa: E402
import casas  # noqa: E402
import criaturas  # noqa: E402
import trajes  # noqa: E402
import vila  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "build", "blender", "previas")

# (rótulo/arquivo, gerador, semente, opções)
CONJUNTOS = {
    "floresta": {
        "chao": (70, 74, 52),
        "itens": [
            ("abeto1", "abeto", 1, {}), ("abeto2", "abeto", 2, {}), ("abeto3", "abeto", 3, {}),
            ("carvalho1", "carvalhoantigo", 1, {}), ("carvalho2", "carvalhoantigo", 2, {}),
        ],
    },
    "sub_bosque": {
        "chao": (70, 74, 52),
        "itens": [
            ("samambaia1", "samambaia", 1, {}), ("samambaia2", "samambaia", 2, {}),
            ("cogumelos1", "cogumelos", 1, {}), ("cogumelos_luz", "cogumelos", 2, {"variante": "luminoso"}),
            ("toramusgo", "toramusgo", 1, {}), ("raizes", "raizes", 1, {}),
        ],
    },
    "campos": {
        "chao": (104, 118, 62),
        "itens": [
            ("tufo1", "tufo", 1, {}), ("tufo2", "tufo", 2, {}),
            ("flores1", "flores", 1, {}), ("flores2", "flores", 2, {}), ("flores3", "flores", 3, {}),
            ("juncos1", "juncos", 1, {}), ("rochedo1", "rochedo", 1, {}), ("rochedo2", "rochedo", 2, {}),
        ],
    },
    "vila": {
        "chao": (122, 108, 86),
        "itens": [
            ("lampiao", "lampiao", 1, {}), ("carroca", "carroca", 1, {}), ("caixotes", "caixotes", 1, {}),
            ("ponte", "ponte", 1, {}), ("palicada", "palicada", 1, {}), ("portao", "portao", 1, {}),
        ],
    },
    "vila2": {
        "chao": (122, 108, 86),
        "itens": [
            ("chafariz", "chafariz", 1, {}), ("bandeirolas1", "bandeirolas", 1, {}), ("bandeirolas2", "bandeirolas", 2, {}),
            ("bandeirolas3", "bandeirolas", 3, {}), ("estandarte1", "estandarte", 1, {}), ("estandarte2", "estandarte", 2, {}),
            ("banco", "banco", 1, {}), ("canteiro", "canteiro", 1, {}), ("jardineira", "jardineira", 1, {}),
            ("varal", "varal", 1, {}), ("lenha", "lenha", 1, {}), ("poco", "poco", 1, {}),
            ("mercado_listrado", "mercado", 1, {"variante": "listrado"}), ("mercado_liso", "mercado", 2, {"variante": "liso"}),
            ("casa_sacada", "casasacada", 1, {}), ("casa_palha", "casapalha", 1, {}),
        ],
        "linhas": [
            ["chafariz", "poco", "lenha", "banco", "canteiro", "jardineira", "estandarte1", "estandarte2"],
            ["bandeirolas1", "bandeirolas2", "bandeirolas3"],
            ["varal", "mercado_listrado", "mercado_liso"],
            ["casa_sacada", "casa_palha"],
        ],
    },
    "ruinas": {
        "chao": (96, 94, 74),
        "itens": [("colunahera1", "colunahera", 1, {}), ("colunahera2", "colunahera", 2, {}), ("escada", "escada", 1, {})],
    },
}


def gerador(nome):
    for modulo in (vegetacao, props, ruinas, vila, casas, avatar, criaturas):
        if modulo is not None and nome in modulo.GERADORES:
            return modulo.GERADORES[nome]
    raise KeyError(nome)


def _srgb_para_linear(c):
    return tuple(((x / 255.0) / 12.92) if x / 255.0 <= 0.04045 else (((x / 255.0) + 0.055) / 1.055) ** 2.4 for x in c)


def material(nome, cor, mat):
    existente = bpy.data.materials.get(nome)
    if existente:
        return existente
    mt = bpy.data.materials.new(nome)
    mt.use_nodes = True
    nos = mt.node_tree.nodes
    p = nos["Principled BSDF"]
    lin = _srgb_para_linear(cor)
    p.inputs["Base Color"].default_value = (*lin, 1.0)
    p.inputs["Roughness"].default_value = 0.92
    if mat == "Neon":
        p.inputs["Emission Color"].default_value = (*lin, 1.0)
        p.inputs["Emission Strength"].default_value = 2.0
    elif mat == "Glass":
        p.inputs["Roughness"].default_value = 0.08
        p.inputs["Transmission Weight"].default_value = 0.55
        p.inputs["IOR"].default_value = 1.33
    elif mat == "SmoothPlastic":
        p.inputs["Roughness"].default_value = 0.55
    elif mat in ("Metal", "DiamondPlate"):
        p.inputs["Metallic"].default_value = 0.7
        p.inputs["Roughness"].default_value = 0.45
    return mt


def montar(itens, espaco=3.0, boneco=True, inicio=2.0):
    """Gera, finaliza e posiciona os itens em fileira. Devolve [(rotulo, objetos, bbox, tris, dim)]."""
    x = 0.0
    resultado = []
    if boneco:
        x += inicio
    for rotulo, nome, semente, opcoes in itens:
        modelo = gerador(nome)(semente, **opcoes)
        modelo.espelhar_y = False  # a prévia mostra o autoral: frente em -Y, de frente para a câmera
        tris = formas.triangulos(modelo)
        objetos = modelo.finalizar()
        modelo.apoiar_no_chao(objetos)
        for o in objetos:
            g = modelo.grupos[o.name.split(".")[0]]
            o.data.materials.append(material(f"{rotulo}_{o.name}", g["cor"], g["material"]))
        pts = [o.matrix_world @ Vector(c) for o in objetos for c in o.bound_box]
        mn = Vector((min(p[i] for p in pts) for i in range(3)))
        mx = Vector((max(p[i] for p in pts) for i in range(3)))
        larg = mx.x - mn.x
        x += larg / 2
        for o in objetos:
            o.location.x += x
        mn.x += x
        mx.x += x
        resultado.append((rotulo, objetos, (mn, mx), tris, (mx - mn)))
        print(f"[{rotulo}] tris={tris} dim(x,y,z)=({mx.x - mn.x:.1f}, {mx.y - mn.y:.1f}, {mx.z - mn.z:.1f}) grupos={list(modelo.grupos)}")
        x += larg / 2 + espaco
    return resultado


def boneco(x, y=0.0):
    """Figura de referência de 5 studs (a altura do avatar do Roblox) feita de blocos."""
    objs = []
    partes = [((0, 0, 1.0), (0.9, 0.9, 2.0)), ((0, 0, 3.0), (1.6, 0.9, 2.0)), ((0, 0, 4.55), (0.9, 0.9, 0.9))]
    for i, (c, d) in enumerate(partes):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x + c[0], y + c[1], c[2]))
        o = bpy.context.active_object
        o.scale = d
        o.data.materials.append(material("boneco", (200, 70, 60), "Plastic"))
        objs.append(o)
    return objs


def cenario(cor_chao, centro, raio):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 40
    cena.cycles.use_denoising = True
    cena.view_settings.view_transform = "Standard"
    cena.view_settings.look = "None"
    # céu: gradiente do horizonte quente ao zênite azul
    mundo = bpy.data.worlds.new("Ceu")
    mundo.use_nodes = True
    nos, lig = mundo.node_tree.nodes, mundo.node_tree.links
    nos.clear()
    coord = nos.new("ShaderNodeTexCoord")
    sep = nos.new("ShaderNodeSeparateXYZ")
    mapa = nos.new("ShaderNodeMapRange")
    mapa.inputs["From Min"].default_value = -0.05
    mapa.inputs["From Max"].default_value = 0.75
    rampa = nos.new("ShaderNodeValToRGB")
    rampa.color_ramp.elements[0].color = (0.95, 0.62, 0.38, 1)
    rampa.color_ramp.elements[1].color = (0.30, 0.46, 0.74, 1)
    fundo = nos.new("ShaderNodeBackground")
    fundo.inputs["Strength"].default_value = 0.9
    saida = nos.new("ShaderNodeOutputWorld")
    lig.new(coord.outputs["Generated"], sep.inputs["Vector"])
    lig.new(sep.outputs["Z"], mapa.inputs["Value"])
    lig.new(mapa.outputs["Result"], rampa.inputs["Fac"])
    lig.new(rampa.outputs["Color"], fundo.inputs["Color"])
    lig.new(fundo.outputs["Background"], saida.inputs["Surface"])
    cena.world = mundo
    # sol baixo dourado, vindo da frente-esquerda
    sol = bpy.data.lights.new("Sol", "SUN")
    sol.energy = 4.6
    sol.color = (1.0, 0.78, 0.52)
    sol.angle = math.radians(3.0)
    so = bpy.data.objects.new("Sol", sol)
    cena.collection.objects.link(so)
    so.rotation_euler = (math.radians(66), 0, math.radians(-38))
    # chão
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(centro.x, centro.y, -0.02))
    chao = bpy.context.active_object
    chao.scale = (3000, 3000, 1)
    chao.data.materials.append(material("chao", cor_chao, "Grass"))
    return cena


def camera(cena, mn, mx, largura, altura, margem=1.12, azimute=-18.0, elevacao=17.0):
    cena.render.resolution_x, cena.render.resolution_y = largura, altura
    c = (mn + mx) / 2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cena.collection.objects.link(cam)
    cam.data.lens = 42
    cam.data.sensor_width = 36
    cam.data.sensor_fit = "HORIZONTAL"  # as contas abaixo supõem o FOV de 36 mm na horizontal, também em retrato
    ar = largura / altura
    hfov = 2 * math.atan(18 / 42)
    vfov = 2 * math.atan(math.tan(hfov / 2) / ar)
    meia_l, meia_a = (mx.x - mn.x) / 2 * margem, max((mx.z - mn.z) / 2, 1.0) * margem
    prof = (mx.y - mn.y) / 2
    d = max(meia_l / math.tan(hfov / 2), meia_a / math.tan(vfov / 2)) + prof + 1.5
    az, el = math.radians(azimute), math.radians(elevacao)
    direcao = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    alvo_pos = Vector((c.x, c.y, (mn.z + mx.z) / 2 - (mx.z - mn.z) * 0.02))
    cam.location = alvo_pos + direcao * d
    alvo = bpy.data.objects.new("Alvo", None)
    alvo.location = alvo_pos
    cena.collection.objects.link(alvo)
    regra = cam.constraints.new("TRACK_TO")
    regra.target, regra.track_axis, regra.up_axis = alvo, "TRACK_NEGATIVE_Z", "UP_Y"
    cena.camera = cam
    return cam


def renderizar(caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.context.scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    print("PNG", caminho)


def _prancha_linha(conj, itens_def, destino, escala):
    """Uma fileira de modelos numa imagem só (câmera 3/4, boneco de 5 studs à esquerda)."""
    lib.limpar()
    itens = montar(itens_def)
    mn = Vector((min(r[2][0].x for r in itens) - 2, min(r[2][0].y for r in itens), 0))
    mx = Vector((max(r[2][1].x for r in itens) + 2, max(r[2][1].y for r in itens), max(r[2][1].z for r in itens)))
    centro = (mn + mx) / 2
    boneco(0.8)
    cena = cenario(conj["chao"], centro, max(mx.x - mn.x, 30))
    camera(cena, mn, mx, int(1600 * escala), int(600 * escala))
    renderizar(destino)
    return itens


def _juntar_verticalmente(arquivos, destino):
    """Empilha PNGs de mesma largura numa imagem só."""
    import numpy as np
    imagens = []
    for a in arquivos:
        im = bpy.data.images.load(a)
        imagens.append((im.size[0], im.size[1], np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)))
    largura = max(i[0] for i in imagens)
    altura = sum(i[1] for i in imagens)
    tela = np.ones((altura, largura, 4), dtype=np.float32)
    y = altura
    for w, h, px in imagens:
        y -= h
        tela[y:y + h, :w, :] = px
    out = bpy.data.images.new("juntar", largura, altura, alpha=False)
    out.pixels = tela.ravel().tolist()
    out.filepath_raw = destino
    out.file_format = "PNG"
    out.save()
    print("PNG", destino)


def prancha_do_conjunto(nome, individuais=False, escala=1.0):
    conj = CONJUNTOS[nome]
    por_rotulo = {i[0]: i for i in conj["itens"]}
    if "linhas" in conj:
        arquivos = []
        for n, linha in enumerate(conj["linhas"]):
            arq = os.path.join(SAIDA, f"_linha_{nome}_{n}.png")
            _prancha_linha(conj, [por_rotulo[r] for r in linha], arq, escala)
            arquivos.append(arq)
        _juntar_verticalmente(arquivos, os.path.join(SAIDA, f"prancha_{nome}.png"))
    else:
        itens = _prancha_linha(conj, conj["itens"], os.path.join(SAIDA, f"prancha_{nome}.png"), escala)
    if individuais:
        for rotulo, *_ in conj["itens"]:
            lib.limpar()
            unico = montar([por_rotulo[rotulo]], espaco=0.0, boneco=False)
            _, objs, (a, b), _, _ = unico[0]
            # boneco ao lado, no canto esquerdo
            boneco(a.x - 2.2, (a.y + b.y) / 2)
            ex = Vector((a.x - 3.2, a.y, 0))
            cena = cenario(conj["chao"], (a + b) / 2, max(b.x - a.x, 10))
            camera(cena, ex, b, int(1000 * escala), int(750 * escala), margem=1.1, azimute=-25.0, elevacao=22.0)
            renderizar(os.path.join(SAIDA, f"{rotulo}.png"))


def _grade(arquivos, colunas, destino):
    """Junta PNGs de mesmo tamanho numa grade (linha a linha, da esquerda para a direita)."""
    import numpy as np
    ims = [bpy.data.images.load(a) for a in arquivos]
    w, h = ims[0].size
    linhas = (len(ims) + colunas - 1) // colunas
    tela = np.ones((linhas * h, colunas * w, 4), dtype=np.float32)
    for i, im in enumerate(ims):
        r, c = divmod(i, colunas)
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        y0 = (linhas - 1 - r) * h
        tela[y0:y0 + h, c * w:(c + 1) * w, :] = px
    out = bpy.data.images.new("grade", colunas * w, linhas * h, alpha=False)
    out.pixels = tela.ravel().tolist()
    out.filepath_raw = destino
    out.file_format = "PNG"
    out.save()
    print("PNG", destino)


# ---------- trajes (V5b): boneco R15 simplificado de 5 studs, em coordenadas AUTORAIS (frente em -Y) ----------
TRAJES = {
    "ladino": ["ladinocapuz", "ladinocapa", "ladinomascara", "ladinocinto"],
    "mestra": ["mestratiara", "mestramanto", "mestracajado", "mestraobi"],
}
# quadro (mn, mx) de cada peça nos closes
QUADROS = {
    "ladinocapuz": ((-2.4, -1.6, 2.7), (2.4, 1.8, 5.9)),
    "ladinocapa": ((-2.6, -1.4, 1.7), (2.6, 1.4, 4.4)),
    "ladinomascara": ((-1.5, -1.5, 3.3), (1.5, 1.5, 5.6)),
    "ladinocinto": ((-2.3, -1.4, 0.6), (2.3, 1.4, 3.2)),
    "mestratiara": ((-1.6, -1.6, 3.5), (1.6, 1.6, 5.9)),
    "mestramanto": ((-2.8, -1.4, -0.2), (2.8, 1.4, 4.6)),
    "mestracajado": ((-3.4, -1.2, 0.0), (0.6, 1.2, 7.4)),
    "mestraobi": ((-2.3, -1.4, 0.6), (2.3, 1.4, 3.2)),
}


def boneco_r15():
    """R15 de 5 studs feito de blocos (medidas das partes em trajes.R15_CENTROS), de frente para -Y."""
    pele, roupa, calca = (238, 192, 152), (176, 178, 186), (68, 70, 90)

    def cubo(centro, tam, cor):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
        o = bpy.context.active_object
        o.scale = tam
        o.data.materials.append(material(f"r15_{cor}", cor, "SmoothPlastic"))
    cubo((0, 0, 4.6), (1.15, 1.15, 1.15), pele)
    cubo((0, 0, 3.2), (2.0, 1.0, 1.6), roupa)
    cubo((0, 0, 2.2), (2.0, 1.0, 0.4), calca)
    for s in (-1, 1):
        cubo((s * 1.5, 0, 2.825), (1.0, 1.0, 2.25), roupa)
        cubo((s * 1.5, 0, 1.55), (1.0, 1.0, 0.3), pele)
        cubo((s * 0.5, 0, 1.0), (1.0, 1.0, 2.0), calca)
        cubo((s * 0.28, -0.59, 4.72), (0.16, 0.06, 0.16), (36, 30, 34))  # olhos: mostram a frente


def _vestir(pecas):
    """Boneco + peças soldadas nos pontos de encaixe de `trajes.ENCAIXES`. Devolve o que foi montado."""
    boneco_r15()
    resumo = []
    for nome in pecas:
        modelo = trajes.GERADORES[nome](1)
        tris = formas.triangulos(modelo)
        objetos = modelo.finalizar()
        pos = Vector(trajes.posicao_autoral(nome))
        for o in objetos:
            g = modelo.grupos[o.name.split(".")[0]]
            o.data.materials.append(material(f"{nome}_{o.name}", g["cor"], g["material"]))
            o.location = pos
        resumo.append((nome, tris, list(modelo.grupos)))
        print(f"[{nome}] tris={tris} grupos={list(modelo.grupos)}")
    return resumo


def prancha_trajes(individuais=False, escala=1.0):
    fundo = (122, 108, 86)
    arquivos = []
    for traje, pecas in TRAJES.items():
        for lado, az in (("frente", 10.0), ("costas", 190.0)):
            lib.limpar()
            _vestir(pecas)
            cena = cenario(fundo, Vector((0, 0, 3)), 10)
            camera(cena, Vector((-2.8, -1.2, 0)), Vector((2.8, 1.2, 7.4)), int(800 * escala), int(1000 * escala), margem=1.0, azimute=az, elevacao=6.0)
            arq = os.path.join(SAIDA, f"_traje_{traje}_{lado}.png")
            renderizar(arq)
            arquivos.append(arq)
    _grade(arquivos, 2, os.path.join(SAIDA, "prancha_trajes.png"))
    if individuais:
        for traje, pecas in TRAJES.items():
            for nome in pecas:
                duo = []
                for az in (25.0, 155.0):
                    lib.limpar()
                    _vestir([nome])
                    cena = cenario(fundo, Vector((0, 0, 3)), 10)
                    mn, mx = QUADROS[nome]
                    camera(cena, Vector(mn), Vector(mx), int(700 * escala), int(700 * escala), margem=1.0, azimute=az, elevacao=12.0)
                    arq = os.path.join(SAIDA, f"_close_{nome}_{int(az)}.png")
                    renderizar(arq)
                    duo.append(arq)
                _grade(duo, 2, os.path.join(SAIDA, f"{nome}.png"))


# ---------- avatar quadradão: bonecos de cubos montados (frente em -Y, coordenadas AUTORAIS) ----------
FUNDO_AVATAR = (122, 108, 86)
PELES = {"humano": (238, 192, 152), "elfo": (246, 218, 192), "anao": (224, 172, 132), "hobbit": (236, 188, 146), "fera": (214, 170, 118),
         "dragao": (150, 186, 120), "celestial": (252, 238, 216), "ogro": (150, 176, 110), "demonio": (196, 120, 110),
         "oceano": (118, 178, 206), "migurd": (240, 214, 196), "superd": (244, 236, 232)}


def _tom(cor, k):
    return tuple(max(0, min(255, int(c * k))) for c in cor)


def _cabelo_cor(cor):
    """Cores dos grupos de cabelo/barba a partir de uma cor base (a sombra é 68% da cor)."""
    return {"Cabelo": cor, "CabeloSombra": _tom(cor, 0.68), "Barba": cor, "BarbaSombra": _tom(cor, 0.68)}


# (rótulo, raça/pele, [(peça, {grupo: cor})])
BONECOS_A = [
    ("humano", "humano", [("cabelocurto", _cabelo_cor((86, 58, 36))), ("tunicabasica", {}), ("cintobasico", {}), ("botasbasicas", {}), ("luvasbasicas", {})]),
    ("elfo", "elfo", [("cabelolongo", _cabelo_cor((226, 204, 120))), ("orelhaselfo", {}), ("tunicabasica", {"Pano": (96, 122, 88), "PanoClaro": (124, 150, 112)}), ("botasbasicas", {})]),
    ("anao", "anao", [("cabelotrancado", _cabelo_cor((176, 84, 40))), ("barbatrancada", _cabelo_cor((176, 84, 40))), ("tunicabasica", {}), ("cintobasico", {}), ("botasbasicas", {})]),
    ("hobbit", "hobbit", [("cabelocachos", _cabelo_cor((120, 78, 44))), ("tunicabasica", {"Pano": (150, 118, 70)}), ("mochilabasica", {}), ("botasbasicas", {})]),
    ("fera", "fera", [("cabelofranja", _cabelo_cor((176, 128, 78))), ("orelhasferafelina", {}), ("caudafera", {}), ("tunicabasica", {}), ("luvasbasicas", {})]),
    ("ogro", "ogro", [("cabelomoicano", _cabelo_cor((40, 36, 36))), ("chifresogro", {}), ("barbacurta", _cabelo_cor((40, 36, 36))), ("capuzbasico", {}), ("cintobasico", {})]),
]
BONECOS_B = [
    ("dragao", "dragao", [("cabeloespetado", _cabelo_cor((50, 80, 56))), ("chifresdragao", {}), ("caudadragao", {}), ("tunicabasica", {}), ("cintobasico", {})]),
    ("celestial", "celestial", [("cabelococo", _cabelo_cor((244, 226, 160))), ("asascelestial", {}), ("tunicabasica", {"Pano": (232, 228, 214), "PanoClaro": (252, 248, 236)}), ("botasbasicas", {})]),
    ("demonio", "demonio", [("cabelococo", _cabelo_cor((30, 26, 34))), ("chifresdemoniocurvos", {}), ("tunicabasica", {"Pano": (96, 52, 60)}), ("cintobasico", {}), ("luvasbasicas", {})]),
    ("oceano", "oceano", [("cabelocachos", _cabelo_cor((36, 100, 140))), ("barbatanasoceano", {}), ("tunicabasica", {"Pano": (70, 120, 140)}), ("botasbasicas", {})]),
    ("migurd", "migurd", [("cabelocurto", _cabelo_cor((60, 120, 214))), ("joiatesta", {}), ("tunicabasica", {}), ("mochilabasica", {})]),
    ("superd", "superd", [("cabelofranja", _cabelo_cor((55, 150, 85))), ("caudasuperd", {}), ("tunicabasica", {"Pano": (60, 80, 110)}), ("cintobasico", {})]),
]


def boneco_avatar(x0, pele):
    """Boneco R15 de CUBOS do avatar (cabeça 1,2; tronco 2 x 1,6 x 1; braços e pernas em blocos) com rosto de blocos nas
    alturas do catálogo de rosto (olhos +0,14, sobrancelhas +0,41, nariz -0,10, boca -0,34), em x0."""
    def cubo(centro, tam, cor, mat="SmoothPlastic"):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x0 + centro[0], centro[1], centro[2]))
        o = bpy.context.active_object
        o.scale = tam
        o.data.materials.append(material(f"av_{cor}", cor, mat))
    camisa, calca, escuro = (92, 104, 126), (66, 68, 88), (34, 28, 32)
    cubo((0, 0, 4.6), (1.2, 1.2, 1.2), pele)
    cubo((0, 0, 3.2), (2.0, 1.0, 1.6), camisa)
    cubo((0, 0, 2.2), (2.0, 1.0, 0.4), calca)
    for s in (-1, 1):
        cubo((s * 1.5, 0, 2.825), (1.0, 1.0, 2.25), pele)
        cubo((s * 1.5, 0, 1.55), (1.0, 1.0, 0.3), pele)
        cubo((s * 0.5, 0, 1.0), (1.0, 1.0, 2.0), calca)
        cubo((s * 0.27, -0.61, 4.74), (0.18, 0.04, 0.16), (244, 244, 240))
        cubo((s * 0.27, -0.63, 4.74), (0.1, 0.04, 0.1), escuro)
        cubo((s * 0.27, -0.61, 5.01), (0.22, 0.04, 0.06), _tom(pele, 0.45))
    cubo((0, -0.65, 4.5), (0.12, 0.1, 0.24), _tom(pele, 0.88))
    cubo((0, -0.61, 4.26), (0.26, 0.04, 0.05), (132, 56, 60))


def _vestir_avatar(x0, itens, pele, resumo=None):
    """Boneco em x0 + peças nos encaixes de `avatar.ENCAIXES` (cores por grupo trocadas pelo dict de cada item)."""
    boneco_avatar(x0, pele)
    for nome, cores in itens:
        cores = dict(cores)
        cores.setdefault("Pele", pele)
        cores.setdefault("PeleSombra", _tom(pele, 0.88))
        for pos in avatar.posicoes_autorais(nome):
            modelo = avatar.GERADORES[nome](1)
            tris = formas.triangulos(modelo)
            objetos = modelo.finalizar()
            for o in objetos:
                grupo = o.name.split(".")[0]
                cor = tuple(cores.get(grupo, modelo.grupos[grupo]["cor"]))
                o.data.materials.append(material(f"{nome}_{o.name}_{cor}", cor, modelo.grupos[grupo]["material"]))
                o.location = (pos[0] + x0, pos[1], pos[2])
            if resumo is not None:
                resumo[nome] = (tris, list(modelo.grupos))


def _prancha_avatar_linha(grupo, nome, escala):
    """Uma fileira de bonecos em três vistas (frente, 3/4, topo); devolve os caminhos dos PNG."""
    n = len(grupo)
    esp = 5.4
    largo = (n - 1) * esp
    arqs = []
    for tag, az, el, alt, quad in (("frente", 8.0, 6.0, 520, 1.0), ("tresquartos", 38.0, 14.0, 560, 1.0), ("topo", 14.0, 58.0, 640, 1.18)):
        lib.limpar()
        for i, (_, raca, itens) in enumerate(grupo):
            _vestir_avatar(i * esp - largo / 2, itens, PELES[raca])
        cena = cenario(FUNDO_AVATAR, Vector((0, 0, 3)), 20)
        camera(cena, Vector((-largo / 2 - 2.8, -1.8, 0)), Vector((largo / 2 + 2.8, 2.2 if tag != "topo" else 4.6, 7.6)), int(1800 * escala), int(alt * escala), margem=quad, azimute=az, elevacao=el)
        arq = os.path.join(SAIDA, f"_avatar_{nome}_{tag}.png")
        renderizar(arq)
        arqs.append(arq)
    return arqs


# quadro (mn, mx) de cada peça nos closes, por encaixe e exceções
QUADRO_PARTE = {"Head": ((-1.7, -1.3, 3.9), (1.7, 1.7, 5.8)), "UpperTorso": ((-2.4, -1.6, 2.0), (2.4, 2.0, 4.9)),
                "LowerTorso": ((-1.8, -1.5, 1.7), (1.8, 1.5, 3.0)), "LeftFoot": ((-1.4, -1.3, -0.3), (1.4, 1.3, 1.6)),
                "LeftHand": ((-2.3, -1.0, 1.0), (2.3, 1.0, 2.2))}
QUADRO_PECA = {"cabelolongo": ((-1.9, -1.4, 2.5), (1.9, 1.8, 5.8)), "barbatrancada": ((-1.7, -1.4, 2.3), (1.7, 1.6, 5.6)),
               "cabelotrancado": ((-1.9, -1.4, 3.0), (1.9, 1.8, 5.8)),
               "caudafera": ((-2.4, -1.4, 0.4), (2.4, 4.6, 4.6)), "caudadragao": ((-2.4, -1.4, 0.2), (2.4, 5.4, 4.4)),
               "caudasuperd": ((-2.4, -1.4, 0.4), (2.4, 5.0, 4.6)), "cabelorabo": ((-1.9, -1.4, 3.4), (1.9, 1.8, 5.8)),
               "chifresdragao": ((-2.0, -1.4, 3.9), (2.0, 2.2, 6.4)), "orelhasferacanina": ((-1.8, -1.3, 3.9), (1.8, 1.8, 6.4)),
               "orelhaselfolongas": ((-2.4, -1.3, 3.9), (2.4, 1.7, 6.0)), "chifresdemoniocurvos": ((-2.0, -1.3, 3.9), (2.0, 1.7, 6.1)),
               "mochilabasica": ((-2.4, -1.6, 2.0), (2.4, 2.8, 5.0)), "capuzbasico": ((-2.0, -1.6, 3.2), (2.0, 2.0, 6.0)),
               "asascelestial": ((-3.2, -1.6, 1.4), (3.2, 2.2, 5.2)), "cabelocachos": ((-1.7, -1.3, 3.9), (1.7, 1.7, 6.0))}


def _individual_avatar(nome, escala):
    """Peça vestida no boneco em quatro vistas (3/4 frontal, costas, lado e topo), numa grade `avatar_<peça>.png`."""
    parte = avatar.ENCAIXES[nome][0][0]
    mn, mx = QUADRO_PECA.get(nome, QUADRO_PARTE[parte])
    arqs = []
    for tag, az, el in (("a", 28.0, 12.0), ("b", 160.0, 14.0), ("c", 82.0, 8.0), ("d", 20.0, 62.0)):
        lib.limpar()
        _vestir_avatar(0.0, [(nome, {})], PELES["humano"])
        cena = cenario(FUNDO_AVATAR, Vector((0, 0, 3)), 10)
        camera(cena, Vector(mn), Vector(mx), int(560 * escala), int(560 * escala), margem=1.0, azimute=az, elevacao=el)
        arq = os.path.join(SAIDA, f"_av_{nome}_{tag}.png")
        renderizar(arq)
        arqs.append(arq)
    _grade(arqs, 4, os.path.join(SAIDA, f"avatar_{nome}.png"))


def prancha_avatar(individuais=False, escala=1.0, so=""):
    """Pranchas do avatar: duas fileiras de 6 bonecos (frente, 3/4, topo) em prancha_avatar.png; `so` = lista de peças
    separadas por vírgula para renderizar só as individuais (avatar_<peça>.png); `individuais` gera todas e o espelho."""
    if so:
        for nome in so.split(","):
            if nome == "espelhovila":
                prancha_espelho(escala)
            elif nome == "espelhoperto":
                prancha_espelho(escala, True)
            else:
                _individual_avatar(nome, escala)
        return
    arqs = []
    for nome, grupo in (("a", BONECOS_A), ("b", BONECOS_B)):
        arqs += _prancha_avatar_linha(grupo, nome, escala)
    _juntar_verticalmente(arqs, os.path.join(SAIDA, "prancha_avatar.png"))
    if individuais:
        for nome in avatar.ENCAIXES:
            _individual_avatar(nome, escala)
        prancha_espelho(escala)


def prancha_espelho(escala=1.0, perto=False):
    """Espelho de vila com um boneco de cubos ao lado (escala): vista 3/4 e frontal em avatar_espelhovila.png."""
    arqs = []
    for tag, az, el in (("a", -24.0, 14.0), ("b", 20.0, 6.0)):
        lib.limpar()
        modelo = avatar.GERADORES["espelhovila"](1)
        modelo.espelhar_y = False  # a prévia mostra o autoral: frente em -Y, de frente para a câmera
        tris = formas.triangulos(modelo)
        objetos = modelo.finalizar()
        modelo.apoiar_no_chao(objetos)
        for o in objetos:
            g = modelo.grupos[o.name.split(".")[0]]
            o.data.materials.append(material(f"espelho_{o.name}", g["cor"], g["material"]))
        pts = [o.matrix_world @ Vector(c) for o in objetos for c in o.bound_box]
        mn = Vector((min(p[i] for p in pts) for i in range(3)))
        mx = Vector((max(p[i] for p in pts) for i in range(3)))
        print(f"[espelhovila] tris={tris} dim(x,y,z)=({mx.x - mn.x:.2f}, {mx.y - mn.y:.2f}, {mx.z - mn.z:.2f}) grupos={list(modelo.grupos)}")
        boneco_avatar(mn.x - 1.6, PELES["humano"])
        cena = cenario(FUNDO_AVATAR, Vector((0, 0, 3)), 12)
        if perto:  # base do espelho (conferir encaixe de pés e montantes)
            camera(cena, Vector((mn.x - 0.4, mn.y, 0)), Vector((mn.x + 3.6, mx.y, 2.2)), int(1000 * escala), int(840 * escala), margem=1.0, azimute=az, elevacao=el)
        else:
            camera(cena, Vector((mn.x - 2.8, mn.y, 0)), Vector((mx.x + 0.2, mx.y, mx.z)), int(1000 * escala), int(840 * escala), margem=1.05, azimute=az, elevacao=el)
        arq = os.path.join(SAIDA, f"_espelho_{tag}.png")
        renderizar(arq)
        arqs.append(arq)
    _grade(arqs, 2, os.path.join(SAIDA, "avatar_espelhovila.png"))


# ---------- criaturas do mundo aberto (17/10): prancha com o boneco de cubos do jogador (5 studs) para escala ----------
CRIATURAS_PEQUENAS = [
    ("goblin_faca", "goblin", 1, {"variante": "faca"}), ("goblin_arco", "goblin", 1, {"variante": "arco"}),
    ("lobo", "lobo", 1, {}), ("bandido_porrete", "bandido", 1, {"variante": "porrete"}),
    ("bandido_espada", "bandido", 1, {"variante": "espada"}), ("rato", "rato", 1, {}), ("aranha", "aranha", 1, {}),
]
CRIATURAS_GRANDES = [("urso", "urso", 1, {}), ("golem", "golem", 1, {}), ("treant", "treant", 1, {})]
VISTAS_CRIATURA = (("3q", -34.0, 20.0), ("topo", -16.0, 50.0))


def _boneco_escala(x0):
    boneco_avatar(x0, PELES["humano"])


def _prancha_criaturas_linha(nome, itens_def, escala):
    arqs = []
    for tag, az, el in VISTAS_CRIATURA:
        lib.limpar()
        itens = montar(itens_def, espaco=2.2, boneco=True, inicio=3.0)
        _boneco_escala(0.0)
        mn = Vector((-2.4, min(r[2][0].y for r in itens), 0))
        mx = Vector((max(r[2][1].x for r in itens) + 1.0, max(r[2][1].y for r in itens), max(r[2][1].z for r in itens)))
        cena = cenario(FUNDO_AVATAR, (mn + mx) / 2, 40)
        camera(cena, mn, mx, int(1800 * escala), int(700 * escala), margem=1.22, azimute=az, elevacao=el)
        arq = os.path.join(SAIDA, f"_criaturas_{nome}_{tag}.png")
        renderizar(arq)
        arqs.append(arq)
    return arqs


def _individual_criatura(item, escala):
    rotulo = item[0]
    arqs = []
    for tag, az, el in VISTAS_CRIATURA:
        lib.limpar()
        r = montar([item], espaco=0.0, boneco=False)[0]
        a, b = r[2]
        xd = a.x - 3.4
        _boneco_escala(xd)
        mn = Vector((xd - 2.2, a.y, 0))
        cena = cenario(FUNDO_AVATAR, (a + b) / 2, 20)
        camera(cena, mn, b, int(900 * escala), int(760 * escala), margem=1.08, azimute=az, elevacao=el)
        arq = os.path.join(SAIDA, f"_crc_{rotulo}_{tag}.png")
        renderizar(arq)
        arqs.append(arq)
    _grade(arqs, 2, os.path.join(SAIDA, f"criatura_{rotulo}.png"))


def prancha_criaturas(individuais=False, escala=1.0, so=""):
    todos = CRIATURAS_PEQUENAS + CRIATURAS_GRANDES
    if so:
        for it in todos:
            if it[0] in so.split(","):
                _individual_criatura(it, escala)
        return
    arqs = _prancha_criaturas_linha("pequenas", CRIATURAS_PEQUENAS, escala) + _prancha_criaturas_linha("grandes", CRIATURAS_GRANDES, escala)
    _juntar_verticalmente(arqs, os.path.join(SAIDA, "prancha_criaturas.png"))
    if individuais:
        for it in todos:
            _individual_criatura(it, escala)


def prancha_geral(rotulos, colunas=4, larg=500, alt=375):
    """Contact sheet com os PNG individuais (na ordem de `rotulos`) em prancha.png."""
    import numpy as np
    linhas = (len(rotulos) + colunas - 1) // colunas
    tela = np.zeros((linhas * alt, colunas * larg, 4), dtype=np.float32)
    tela[..., 3] = 1.0
    for i, rotulo in enumerate(rotulos):
        im = bpy.data.images.load(os.path.join(SAIDA, f"{rotulo}.png"))
        im.scale(larg, alt)
        px = np.array(im.pixels[:], dtype=np.float32).reshape(alt, larg, 4)
        r, c = divmod(i, colunas)
        y0 = (linhas - 1 - r) * alt
        tela[y0:y0 + alt, c * larg:(c + 1) * larg, :] = px
    out = bpy.data.images.new("prancha", colunas * larg, linhas * alt, alpha=False)
    out.pixels = tela.ravel().tolist()
    out.filepath_raw = os.path.join(SAIDA, "prancha.png")
    out.file_format = "PNG"
    out.save()
    print("PNG", out.filepath_raw, "ordem:", ", ".join(rotulos))


def main():
    op = lib.argumentos({"conjunto": "floresta", "individuais": 0, "escala": 1.0, "itens": ""})
    if op["conjunto"] == "criaturas":
        prancha_criaturas(bool(op["individuais"]), op["escala"], op["itens"])
        return
    if op["conjunto"] == "avatar":
        prancha_avatar(bool(op["individuais"]), op["escala"], op["itens"])
        return
    if op["itens"]:  # só alguns rótulos do conjunto, numa fileira (prancha_<conjunto>_parcial.png)
        base = CONJUNTOS[op["conjunto"]]
        quais = op["itens"].split(",")
        CONJUNTOS[op["conjunto"] + "_parcial"] = {"chao": base["chao"], "itens": [i for i in base["itens"] if i[0] in quais]}
        op["conjunto"] += "_parcial"
    nomes = list(CONJUNTOS) if op["conjunto"] == "todos" else [op["conjunto"]]
    if op["conjunto"] == "trajes":
        prancha_trajes(bool(op["individuais"]), op["escala"])
        return
    for n in nomes:
        if n == "vila" and props is None:
            continue
        prancha_do_conjunto(n, bool(op["individuais"]), op["escala"])
    if op["conjunto"] == "todos" and op["individuais"]:
        prancha_geral([i[0] for n in nomes for i in CONJUNTOS[n]["itens"]])


main()
