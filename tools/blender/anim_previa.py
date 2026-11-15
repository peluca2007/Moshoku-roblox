"""Prévia das animações exportadas (ANIM1): boneco de blocos R15 posado pelos DADOS EXPORTADOS (as tabelas que vão
para o Luau, amostradas como o Amostra.luau faz), folha de contato PNG por clipe e conferências numéricas
(pé no chão, membro dentro do tronco). Não usa a animação original nem as poses-chave."""
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

import anim_curvas as C
import anim_rig as R

CORES = {
    "LowerTorso": (60, 78, 120), "UpperTorso": (70, 98, 160), "Head": (236, 190, 150),
    "UpperArm": (96, 128, 190), "LowerArm": (226, 178, 138), "Hand": (246, 214, 180),
    "UpperLeg": (66, 60, 56), "LowerLeg": (84, 76, 70), "Foot": (40, 34, 30),
}
LADO_COR = {"Right": 1.0, "Left": 0.82}  # o lado esquerdo um pouco mais escuro, para distinguir


def _lin(c, f=1.0):
    return tuple(min(1.0, x * f / 255.0) for x in c) + (1.0,)


def limpar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for cu in list(bpy.data.curves):
        bpy.data.curves.remove(cu)


def _caixa(nome, tamanho, cor, local=Matrix()):
    malha = bpy.data.meshes.new(nome)
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(malha)
    bm.free()
    malha.transform(R.PARA_BLENDER @ local @ Matrix.Diagonal((*tamanho, 1.0)))
    o = bpy.data.objects.new(nome, malha)
    bpy.context.scene.collection.objects.link(o)
    o.color = cor
    return o


def montar_boneco(arma):
    """Devolve [(objeto, peça)] e a lista de pontos de teste [(peça, ponto local)] das peças/arma."""
    itens = []
    for parte, (_, tam) in R.PECAS.items():
        if parte == "HumanoidRootPart":
            continue
        chave = next((k for k in CORES if parte.endswith(k)), parte)
        lado = "Left" if parte.startswith("Left") else "Right"
        itens.append((_caixa(parte, tam, _lin(CORES[chave], LADO_COR[lado])), parte))
    # nariz e olhos: mostram para onde a cabeça olha
    itens.append((_caixa("Nariz", (0.2, 0.25, 0.2), _lin((150, 90, 70)), Matrix.Translation((0, -0.05, -0.68))), "Head"))
    for x in (-0.28, 0.28):
        itens.append((_caixa("Olho", (0.16, 0.2, 0.06), _lin((30, 30, 40)), Matrix.Translation((x, 0.15, -0.61))), "Head"))
    # faixa no peito marca a frente do tronco
    itens.append((_caixa("Peito", (1.4, 0.18, 0.06), _lin((220, 190, 90)), Matrix.Translation((0, 0.35, -0.52))), "UpperTorso"))
    pontos_arma = []
    if arma == "espada":
        # pega recomendada: lâmina ao longo de -Z da mão (perpendicular ao antebraço), ver tools/animacao/README.md
        for nome, tam, centro, cor in (("Punho", (0.2, 0.2, 0.8), (0, 0, 0.05), (92, 66, 46)),
                                       ("Guarda", (0.2, 0.9, 0.2), (0, 0, -0.38), (150, 118, 60)),
                                       ("Lamina", (0.1, 0.34, 3.0), (0, 0, -1.95), (200, 206, 216))):
            itens.append((_caixa(nome, tam, _lin(cor), Matrix.Translation(centro)), "RightHand"))
        pontos_arma = [("RightHand", Vector((0, 0, -0.6 - 0.35 * k))) for k in range(8)]
    elif arma == "arco":
        for k in range(7):
            a = (k - 3) / 3.0
            local = Matrix.Translation((0, -0.15 - 0.35 * (1 - a * a) + 0.35, a * 1.5)) @ Matrix.Rotation(a * 0.5, 4, "X")
            itens.append((_caixa("Arco", (0.14, 0.14, 0.55), _lin((110, 76, 48)), local), "LeftHand"))
    return itens, pontos_arma


def posar(dados, t):
    pose = {}
    for junta, chaves in dados["juntas"].items():
        pose[junta] = (C.amostrar_junta(chaves, t), C.amostrar_raiz(dados["raiz"], t) if junta == "Root" else None)
    return R.fk(pose)


def _cantos(tam, n=3):
    hx, hy, hz = (s / 2 for s in tam)
    return [Vector((hx * (2 * i / (n - 1) - 1), hy * (2 * j / (n - 1) - 1), hz * (2 * k / (n - 1) - 1)))
            for i in range(n) for j in range(n) for k in range(n)]


def conferir(dados, pontos_arma):
    """Mede, em 60 instantes: altura mínima dos pés (sola), maior penetração de braço/mão/arma no tronco ou na cabeça,
    e quanto as pernas se cruzam. Devolve um dicionário com os piores valores e seus instantes."""
    corpo = ("UpperTorso", "LowerTorso", "Head")
    membros = [p for p in R.PECAS if any(p.endswith(s) for s in ("UpperArm", "LowerArm", "Hand"))]
    pior = {"pe_min": (9.0, 0), "pe_max_apoio": (0.0, 0), "penetra": (0.0, 0, "")}
    n = 60
    for k in range(n + 1):
        t = dados["duracao"] * k / n
        m = posar(dados, t)
        for lado in ("Right", "Left"):
            sola = min((m[lado + "Foot"] @ c).y for c in _cantos(R.PECAS[lado + "Foot"][1]))
            if sola < pior["pe_min"][0]:
                pior["pe_min"] = (sola, t)
        testes = [(p, c) for p in membros for c in _cantos(R.PECAS[p][1])]
        testes += pontos_arma
        for parte, local in testes:
            # o braço só é testado contra o tronco e a cabeça (a junta do ombro encosta por construção)
            w = m[parte] @ local
            for alvo in corpo:
                if alvo == "UpperTorso" and parte.endswith("UpperArm"):
                    continue
                inv = m[alvo].inverted() @ w
                tam = R.PECAS[alvo][1]
                folga = min(tam[0] / 2 - abs(inv.x), tam[1] / 2 - abs(inv.y), tam[2] / 2 - abs(inv.z))
                if folga > pior["penetra"][0]:
                    pior["penetra"] = (folga, t, parte + "->" + alvo)
    return pior


def _texto(corpo, pos, rot, tam=0.42):
    cu = bpy.data.curves.new("rotulo", "FONT")
    cu.body = corpo
    cu.size = tam
    cu.align_x = "CENTER"
    o = bpy.data.objects.new("rotulo", cu)
    bpy.context.scene.collection.objects.link(o)
    o.location = pos
    o.rotation_euler = rot
    o.color = (0.05, 0.05, 0.08, 1)
    return o


def cena():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "OBJECT"
    sh.show_shadows = True
    sh.shadow_intensity = 0.45
    sh.show_object_outline = True
    sh.object_outline_color = (0.08, 0.08, 0.1)
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.80, 0.82, 0.86)
    sc.display.light_direction = (0.35, -0.45, 0.82)
    sc.render.resolution_x, sc.render.resolution_y = 340, 420
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    # chão, casa do personagem (4 x 4) e o alvo à frente
    chao = _caixa("Chao", (30, 0.1, 30), _lin((196, 190, 172)), Matrix.Translation((0, -0.05, 0)))
    for x0, z0, sx, sz in ((-2, 0, 0.06, 4), (2, 0, 0.06, 4), (0, -2, 4, 0.06), (0, 2, 4, 0.06)):
        _caixa("Casa", (sx, 0.02, sz), _lin((90, 86, 76)), Matrix.Translation((x0, 0.005, z0)))
    _caixa("Alvo", (0.7, 4.6, 0.7), _lin((170, 70, 60)), Matrix.Translation((0, 2.3, -5.0)))
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 42
    return chao, cam


# vistas da folha: 3/4 pela frente-direita e perfil pela direita (Blender: frente do personagem = +Y, direita = +X)
VISTAS = [(Vector((7.4, 10.4, 5.4)), Vector((0, 0.6, 2.4))), (Vector((13.0, 1.4, 3.4)), Vector((0, 1.4, 2.2)))]


def apontar(cam, vista):
    pos, alvo_b = vista
    cam.location = pos
    cam.rotation_euler = (alvo_b - cam.location).to_track_quat("-Z", "Y").to_euler()


def folha(nome, dados, arma, pasta, quadros=8):
    limpar()
    _, cam = cena()
    itens, pontos_arma = montar_boneco(arma)
    dur = dados["duracao"]
    n = quadros
    tempos = [dur * k / (n if dados.get("laco") else n - 1) for k in range(n)]
    rotulos = ["" for _ in tempos]
    for marco, tm in sorted(dados["marcos"].items(), key=lambda kv: kv[1]):
        i = min(range(n), key=lambda k: abs(tempos[k] - tm) if not rotulos[k] else 99)
        tempos[i], rotulos[i] = tm, marco
    ordem = sorted(range(n), key=lambda k: tempos[k])
    tempos = [tempos[k] for k in ordem]
    rotulos = [rotulos[k] for k in ordem]
    txt = _texto("", (0, -1.05, -4.0), (0, 0, 0), 0.2)
    txt.parent = cam
    corda = []
    os.makedirs(pasta, exist_ok=True)
    linhas = []
    sc = bpy.context.scene
    for v, pos in enumerate(VISTAS):
        apontar(cam, pos)
        imagens = []
        for i, t in enumerate(tempos):
            m = posar(dados, t)
            for o, parte in itens:
                o.matrix_world = R.para_blender(m[parte])
            for c in corda:
                bpy.data.objects.remove(c, do_unlink=True)
            corda = []
            if arma == "arco":
                corda = _corda(m, t, dados)
            txt.data.body = f"{t:.2f}s {rotulos[i]}".strip() if v == 0 else ""
            caminho = os.path.join(pasta, f"_q{v}_{i}.png")
            sc.render.filepath = caminho
            bpy.ops.render.render(write_still=True)
            imagens.append(caminho)
        linhas.append(imagens)
    saida = os.path.join(pasta, nome + ".png")
    _juntar(linhas, saida)
    for c in sum(linhas, []):
        os.remove(c)
    return saida


def _corda(m, t, dados):
    """Corda do arco: das pontas do arco até a mão direita enquanto não passou o marco `soltar`; depois, reta."""
    mao_e = m["LeftHand"]
    topo = mao_e @ Vector((0, 0.35 - 0.15, 1.5))
    base = mao_e @ Vector((0, 0.35 - 0.15, -1.5))
    soltar = dados["marcos"].get("soltar", 1e9)
    puxa = dados["marcos"].get("puxar", 0.0)
    mao_d = m["RightHand"] @ Vector((0, 0, 0))
    objs = []
    meio = mao_d if puxa <= t < soltar else (topo + base) / 2
    for a, b in ((topo, meio), (meio, base)):
        objs.append(_segmento(a, b, 0.05, (0.9, 0.9, 0.85, 1)))
    if puxa <= t < soltar:
        frente = (mao_e @ Vector((0, 0, 0)) - mao_d)
        objs.append(_segmento(mao_d, mao_d + frente.normalized() * (frente.length + 0.6), 0.07, (0.55, 0.35, 0.2, 1)))
    return objs


def _segmento(a, b, esp, cor):
    d = b - a
    centro = (a + b) / 2
    q = Vector((0, 1, 0)).rotation_difference(d.normalized())
    local = Matrix.Translation(centro) @ q.to_matrix().to_4x4()
    o = _caixa("Seg", (esp, max(d.length, 0.01), esp), cor)
    o.matrix_world = R.para_blender(local)
    return o


def _juntar(linhas, saida):
    """Uma linha da folha por vista; os quadros lado a lado, separados por uma faixa escura."""
    faixas = []
    for caminhos in linhas:
        blocos = []
        for c in caminhos:
            img = bpy.data.images.load(c)
            w, h = img.size
            px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
            blocos.append(px)
            bpy.data.images.remove(img)
        sep = np.full((blocos[0].shape[0], 4, 4), 0.3, dtype=np.float32)
        sep[..., 3] = 1
        partes = []
        for b in blocos:
            partes += [b, sep]
        faixas.append(np.concatenate(partes[:-1], axis=1))
    sep_h = np.full((4, faixas[0].shape[1], 4), 0.3, dtype=np.float32)
    sep_h[..., 3] = 1
    pilha = []
    for f in reversed(faixas):  # pixels do Blender começam embaixo
        pilha += [f, sep_h]
    tudo = np.concatenate(pilha[:-1], axis=0)
    h, w = tudo.shape[:2]
    img = bpy.data.images.new("folha", width=w, height=h, alpha=False)
    img.pixels = tudo.ravel()
    img.filepath_raw = saida
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
