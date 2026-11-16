"""Conferência dos clipes das criaturas (ANIM2) sem o Studio: roda os clipes Luau GERADOS (src/shared/Animacoes/Criaturas)
sobre as peças rígidas EXPORTADAS (build/criaturas/<Modulo>.fbx), e não sobre o esqueleto original.

  Blender:  python tools/blender_rodar.py tools/blender/kits/criaturas_prancha_anim.py --so Rato,Aranha,Esqueleto,Dragao
            -> build/beleza/anim/quadros/<Modulo>_<Clipe>_<k>.png
  Python:   python tools/blender/kits/criaturas_prancha_anim.py --montar [--so ...]
            -> build/beleza/anim/criaturas_prancha.jpg   (precisa de Pillow; 4 quadros por clipe)

A amostragem espelha shared/Mundo/AnimacaoCriatura.amostrar (slerp pelo caminho curto + interpolação linear).
"""
import glob
import json
import math
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
BUILD = os.environ.get("MOSHOKU_BUILD") or os.path.join(RAIZ, "build")
CLIPES = os.path.join(RAIZ, "src", "shared", "Animacoes", "Criaturas")
SAIDA = os.path.join(BUILD, "beleza", "anim")
QUADROS = os.path.join(SAIDA, "quadros")
ORDEM = ["Respirar", "Voar", "Andar", "Correr", "Atacar", "Atacar2", "LevarGolpe", "Morrer"]


def opcao(nome, padrao=""):
    if "--" in sys.argv:
        resto = sys.argv[sys.argv.index("--") + 1:]
    else:
        resto = sys.argv[1:]
    return resto[resto.index("--" + nome) + 1] if "--" + nome in resto else padrao


def escolhidos():
    quais = [q for q in opcao("so").split(",") if q]
    nomes = sorted(os.path.basename(f)[:-4] for f in glob.glob(os.path.join(BUILD, "criaturas", "*Quaternius.fbx")))
    return [n for n in nomes if not quais or any(q.lower() in n.lower() for q in quais)]


# ---------------------------------------------------------------- leitura do Luau gerado
def ler_luau(caminho):
    """{clipe: {laco, duracao, marcos, pecas: {parte: [[t, qx..qw, dx, dy, dz], ...]}}} a partir do texto gerado."""
    txt = open(caminho, encoding="utf-8").read()
    dados = {}
    for m in re.finditer(r"\n\t\t(\w+) = \{\n(.*?)\n\t\t\},", txt, re.S):
        corpo = m.group(2)
        c = {"laco": "laco = true" in corpo, "duracao": float(re.search(r"duracao = ([\d.]+)", corpo).group(1))}
        c["marcos"] = {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)", re.search(r"marcos = \{ (.*?) \}", corpo).group(1))}
        c["pecas"] = {}
        for p in re.finditer(r"\t\t\t\t(\w+) = \{\n(.*?)\n\t\t\t\t\},", corpo, re.S):
            c["pecas"][p.group(1)] = [[float(x) for x in q.split(",")] for q in re.findall(r"\{([^{}]*)\}", p.group(2))]
        dados[m.group(1)] = c
    return dados


def amostrar(chaves, t):
    import numpy as np
    ts = [k[0] for k in chaves]
    if t <= ts[0]:
        return np.array(chaves[0][1:])
    if t >= ts[-1]:
        return np.array(chaves[-1][1:])
    i = max(j for j in range(len(ts)) if ts[j] <= t)
    a, b = np.array(chaves[i][1:]), np.array(chaves[i + 1][1:])
    u = (t - ts[i]) / (ts[i + 1] - ts[i])
    qa, qb = a[:4], b[:4]
    if qa @ qb < 0:
        qb = -qb
    d = min(1.0, float(qa @ qb))
    if d > 0.9995:
        q = qa * (1 - u) + qb * u
    else:
        ang = math.acos(d)
        q = (qa * math.sin((1 - u) * ang) + qb * math.sin(u * ang)) / math.sin(ang)
    return np.concatenate([q / np.linalg.norm(q), a[4:] * (1 - u) + b[4:] * u])


def matriz(q):
    x, y, z, w = q
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]


def tempos_quadros(c):
    d = c["duracao"]
    return [d * k / 4 for k in range(4)] if c["laco"] else [d * k / 3 for k in range(4)]


# ---------------------------------------------------------------- Blender
def no_blender():
    import bpy
    import bmesh  # noqa: F401
    import numpy as np
    from mathutils import Vector

    pivos_todos = {}
    for modulo in escolhidos():
        dados = ler_luau(os.path.join(CLIPES, modulo + ".luau"))
        info = json.load(open(os.path.join(BUILD, "criaturas", modulo + ".json"), encoding="utf-8"))
        pivos = {k: np.array(v) for k, v in info["pivos"].items()}
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=os.path.join(BUILD, "criaturas", modulo + ".fbx"))
        peças = []
        for o in [o for o in bpy.data.objects if o.type == "MESH"]:
            grupo = re.match(r"^(\w+?)_", o.name)
            nome_grupo = o.name.split(".")[0]
            cor = info["grupos"].get(nome_grupo, {}).get("cor", [150, 150, 150])
            o.color = tuple(((c / 255.0) / 12.92 if c / 255.0 <= 0.04045 else ((c / 255.0 + 0.055) / 1.055) ** 2.4) for c in cor) + (1.0,)
            v = np.empty(len(o.data.vertices) * 3)
            o.data.vertices.foreach_get("co", v)
            v = v.reshape(-1, 3)
            roblox = np.stack([-v[:, 0], v[:, 2], v[:, 1]], axis=1)  # autoral -> Roblox
            peças.append((o, grupo.group(1) if grupo else nome_grupo, roblox))
        cena = bpy.context.scene
        cena.render.engine = "BLENDER_WORKBENCH"
        cena.display.shading.light = "STUDIO"
        cena.display.shading.color_type = "OBJECT"
        cena.display.shading.show_shadows = False
        cena.render.resolution_x, cena.render.resolution_y = 360, 288
        cena.world = bpy.data.worlds.new("Fundo")
        cena.world.color = (0.45, 0.55, 0.62)
        todos = np.concatenate([p[2] for p in peças])
        mn, mx = todos.min(axis=0), todos.max(axis=0)
        centro = Vector((0, 0, (mn[1] + mx[1]) / 2 * 0.9))  # em coordenadas autorais (Blender)
        dist = max(mx - mn) * 1.7 + 0.8
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
        chao.location = (0, 0, -0.01)
        chao.color = (0.20, 0.30, 0.15, 1.0)
        cena.collection.objects.link(chao)
        os.makedirs(QUADROS, exist_ok=True)
        for clipe, c in dados.items():
            for k, t in enumerate(tempos_quadros(c)):
                for o, parte, roblox in peças:
                    if parte in c["pecas"] and parte in pivos:
                        s = amostrar(c["pecas"][parte], t)
                        R, d = np.array(matriz(s[:4])), s[4:]
                        novo = (roblox - pivos[parte]) @ R.T + pivos[parte] + d
                    else:
                        novo = roblox
                    aut = np.stack([-novo[:, 0], novo[:, 2], novo[:, 1]], axis=1)
                    o.data.vertices.foreach_set("co", aut.reshape(-1))
                    o.data.update()
                cena.render.filepath = os.path.join(QUADROS, f"{modulo}_{clipe}_{k}.png")
                bpy.ops.render.render(write_still=True)
            print(f"PRANCHA {modulo}.{clipe}: 4 quadros")
        with open(os.path.join(QUADROS, modulo + ".json"), "w", encoding="utf-8") as f:
            json.dump({c: {"t": tempos_quadros(v), "marcos": v["marcos"]} for c, v in dados.items()}, f)


# ---------------------------------------------------------------- montagem (Python comum)
def montar():
    from PIL import Image, ImageDraw

    w, h = 360, 288
    linhas = []
    for modulo in escolhidos():
        info = json.load(open(os.path.join(QUADROS, modulo + ".json"), encoding="utf-8"))
        for clipe in sorted(info, key=lambda c: ORDEM.index(c) if c in ORDEM else 99):
            linhas.append((modulo, clipe, info[clipe]))
    folha = Image.new("RGB", (w * 4, h * len(linhas)), (30, 30, 30))
    desenho = ImageDraw.Draw(folha)
    for i, (modulo, clipe, info) in enumerate(linhas):
        for k in range(4):
            im = Image.open(os.path.join(QUADROS, f"{modulo}_{clipe}_{k}.png")).convert("RGB").resize((w, h))
            folha.paste(im, (k * w, i * h))
            desenho.text((k * w + 8, i * h + 6), f"{modulo[:-10]} {clipe}  t={info['t'][k]:.2f}s", fill=(0, 0, 0))
    os.makedirs(SAIDA, exist_ok=True)
    caminho = os.path.join(SAIDA, "criaturas_prancha.jpg")
    folha.save(caminho, quality=82)
    print(caminho, len(linhas), "clipes")


if "--montar" in sys.argv:
    montar()
else:
    try:
        import bpy  # noqa: F401
    except ImportError:
        sys.exit(__doc__)
    no_blender()
