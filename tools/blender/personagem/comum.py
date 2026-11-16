"""Utilidades comuns da proposta de personagem (PERS1, fase 1): geometria, rig R15, pose, rosto pintado, cena e folhas.

Roda dentro do Blender (headless). Convenção AUTORAL igual a tools/blender/avatar.py: Z para cima, o personagem olha para -Y,
a mão DIREITA dele fica em -X; o Roblox recebe (x, y, z) -> (-x, z, y). 1 unidade = 1 stud.

Modelo de dados
  Boneco = {parte R15: [Grupo]}; Grupo = (peca, papel, bmesh, suave). `peca` diz de onde veio a malha ("corpo" ou o nome
  da peça de customização: "cabelo_curto", "orelhas_elfo"...), `papel` é a cor/material (pele, camisa, cabelo...).
  Papel "corpo" = parte R15 padrão com Shirt/Pants clássicas por cima (material_corpo); papel "rosto" = cabeça com o
  rosto pintado projetado na frente (alfa 0 = pele, como um Decal). Demais papéis = peças rígidas e cabelos: no Roblox
  cada (parte, papel) vira uma MeshPart soldada à parte R15, recolorida por MeshPart.Color.
  Rig = {"pivos": {junta: Vector}, ...}: as 15 juntas do R15 com o pivô em repouso (coordenadas autorais).
  Pose = saída de anim_pose.resolver (rotações do Motor6D.Transform no espaço do Roblox), convertida aqui.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.dirname(AQUI)
RAIZ = os.path.dirname(os.path.dirname(BLENDER_DIR))
SAIDA = os.path.join(RAIZ, "build", "personagem")
for _p in (AQUI, BLENDER_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)

PARTES = ["HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
          "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
          "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]
# junta -> (Part0, Part1); a ordem é a de avaliação (mãe antes da filha)
JUNTAS = {"Root": ("HumanoidRootPart", "LowerTorso"), "Waist": ("LowerTorso", "UpperTorso"), "Neck": ("UpperTorso", "Head")}
for _L in ("Right", "Left"):
    JUNTAS[_L + "Shoulder"] = ("UpperTorso", _L + "UpperArm")
    JUNTAS[_L + "Elbow"] = (_L + "UpperArm", _L + "LowerArm")
    JUNTAS[_L + "Wrist"] = (_L + "LowerArm", _L + "Hand")
    JUNTAS[_L + "Hip"] = ("LowerTorso", _L + "UpperLeg")
    JUNTAS[_L + "Knee"] = (_L + "UpperLeg", _L + "LowerLeg")
    JUNTAS[_L + "Ankle"] = (_L + "LowerLeg", _L + "Foot")
LADO_X = {"Right": -1.0, "Left": 1.0}  # x autoral do lado (a direita do personagem fica em -X)

# Roblox -> autoral: (x, y, z) -> (-x, z, y)  (rotação própria, det = +1)
R2A = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


# ====================================================================================== geometria
def _frames(pts, up, fechado=False):
    n = len(pts)
    saida = []
    for i in range(n):
        a = pts[(i - 1) % n] if fechado else pts[max(i - 1, 0)]
        b = pts[(i + 1) % n] if fechado else pts[min(i + 1, n - 1)]
        t = (b - a)
        t = t.normalized() if t.length > 1e-9 else Vector((0, 0, 1))
        u = up(i) if callable(up) else Vector(up)
        lado = t.cross(u)
        if lado.length < 1e-6:
            lado = t.orthogonal()
        lado.normalize()
        normal = lado.cross(t).normalized()
        saida.append((t, lado, normal))
    return saida


def _se(c, expo):
    return math.copysign(abs(c) ** (2.0 / expo), c)


def sweep(bm, secoes, up=(0, -1, 0), lados=10, expo=2.0, tampa_ini=True, tampa_fim=True, giro=0.0, fechado=False):
    """Varre uma seção superelíptica ao longo de pontos. secoes = [(Vector p, w, h)] (meias medidas: w ao longo do
    'lado' = T x up, h ao longo da 'normal'). w = h = 0 vira um vértice (ponta). Devolve a lista de anéis (verts)."""
    pts = [Vector(s[0]) for s in secoes]
    fr = _frames(pts, up, fechado)
    aneis = []
    for (p, w, h), (t, lado, normal) in zip(secoes, fr):
        p = Vector(p)
        if w <= 1e-6 and h <= 1e-6:
            aneis.append([bm.verts.new(p)])
            continue
        anel = []
        for k in range(lados):
            a = 2 * math.pi * k / lados + giro
            anel.append(bm.verts.new(p + lado * (w * _se(math.cos(a), expo)) + normal * (h * _se(math.sin(a), expo))))
        aneis.append(anel)
    pares = list(zip(aneis[:-1], aneis[1:]))
    if fechado:
        pares.append((aneis[-1], aneis[0]))
    for r0, r1 in pares:
        if len(r0) == 1 and len(r1) == 1:
            continue
        if len(r0) == 1:
            for k in range(lados):
                _face(bm, [r0[0], r1[k], r1[(k + 1) % lados]])
        elif len(r1) == 1:
            for k in range(lados):
                _face(bm, [r0[k], r0[(k + 1) % lados], r1[0]][::-1])
        else:
            for k in range(lados):
                _face(bm, [r0[k], r0[(k + 1) % lados], r1[(k + 1) % lados], r1[k]][::-1])
    if not fechado:
        if tampa_ini and len(aneis[0]) > 1:
            _face(bm, list(aneis[0]))
        if tampa_fim and len(aneis[-1]) > 1:
            _face(bm, list(aneis[-1])[::-1])
    return aneis


def _face(bm, verts):
    try:
        return bm.faces.new(verts)
    except ValueError:
        return None


def elipsoide(bm, c, r, seg=12, aneis=8, deform=None, filtro=None):
    """Esfera UV própria com (az, el) conhecidos: az=0 frente (-Y), +90 = esquerda do personagem (+X); el=+90 topo.
    `filtro(az, el)` (graus, centro da face) decide quais quads existem (calotas de cabelo). Devolve verts."""
    c, r = Vector(c), Vector(r)

    def pos(az, el):
        a, e = math.radians(az), math.radians(el)
        p = c + Vector((math.sin(a) * math.cos(e) * r.x, -math.cos(a) * math.cos(e) * r.y, math.sin(e) * r.z))
        return deform(p) if deform else p
    grade = {}

    def v(i, j):
        chave = (i % seg if 0 < j < aneis else 0, j)
        if chave not in grade:
            az = 360.0 * chave[0] / seg
            el = -90 + 180.0 * j / aneis
            grade[chave] = bm.verts.new(pos(az, el))
        return grade[chave]
    for j in range(aneis):
        for i in range(seg):
            az = 360.0 * (i + 0.5) / seg
            az = az - 360 if az > 180 else az
            el = -90 + 180.0 * (j + 0.5) / aneis
            if filtro and not filtro(az, el):
                continue
            q = [v(i, j), v(i + 1, j), v(i + 1, j + 1), v(i, j + 1)]
            uniq = []
            for x in q:
                if x not in uniq:
                    uniq.append(x)
            if len(uniq) >= 3:
                _face(bm, uniq)
    return list(grade.values())


def caixa(bm, c, t, rot=None):
    m = Matrix.Translation(Vector(c))
    if rot is not None:
        m = m @ rot.to_4x4()
    m = m @ Matrix.Diagonal(Vector((*t, 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def placa(bm, pontos_uv, espessura, lados=False):
    """Superfície em grade (lista de linhas de Vector) com espessura (para capas e abas). Normal pelo produto da grade."""
    nl, nc = len(pontos_uv), len(pontos_uv[0])
    fr, tr = [], []
    for i in range(nl):
        lf, lt = [], []
        for j in range(nc):
            p = Vector(pontos_uv[i][j])
            a = Vector(pontos_uv[i][min(j + 1, nc - 1)]) - Vector(pontos_uv[i][max(j - 1, 0)])
            b = Vector(pontos_uv[min(i + 1, nl - 1)][j]) - Vector(pontos_uv[max(i - 1, 0)][j])
            n = a.cross(b).normalized()
            lf.append(bm.verts.new(p + n * espessura / 2))
            lt.append(bm.verts.new(p - n * espessura / 2))
        fr.append(lf)
        tr.append(lt)
    for i in range(nl - 1):
        for j in range(nc - 1):
            _face(bm, [fr[i][j], fr[i][j + 1], fr[i + 1][j + 1], fr[i + 1][j]])
            _face(bm, [tr[i][j], tr[i + 1][j], tr[i + 1][j + 1], tr[i][j + 1]])
    borda = [(i, 0) for i in range(nl)] + [(nl - 1, j) for j in range(1, nc)] + \
            [(i, nc - 1) for i in range(nl - 2, -1, -1)] + [(0, j) for j in range(nc - 2, 0, -1)]
    for k in range(len(borda)):
        (i0, j0), (i1, j1) = borda[k], borda[(k + 1) % len(borda)]
        _face(bm, [fr[i0][j0], tr[i0][j0], tr[i1][j1], fr[i1][j1]])


def tubo_espesso(bm, secoes, espessura, up=(0, -1, 0), lados=12, expo=2.0):
    """Tubo aberto com parede (saias, golas, canos de bota): seções [(p, w, h)] externas; a interna é w-esp, h-esp."""
    ext = sweep(bm, secoes, up=up, lados=lados, expo=expo, tampa_ini=False, tampa_fim=False)
    inn = sweep(bm, [(p, max(w - espessura, 0.01), max(h - espessura, 0.01)) for p, w, h in secoes], up=up, lados=lados,
                expo=expo, tampa_ini=False, tampa_fim=False)
    for r_e, r_i in ((ext[0], inn[0]), (ext[-1], inn[-1])):
        for k in range(lados):
            _face(bm, [r_e[k], r_e[(k + 1) % lados], r_i[(k + 1) % lados], r_i[k]])
    return ext, inn


def juntar(destino, origem):
    origem.verts.index_update()
    mapa = [destino.verts.new(v.co) for v in origem.verts]
    for f in origem.faces:
        _face(destino, [mapa[v.index] for v in f.verts])


def normais_fora(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def triangulos(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


# ====================================================================================== boneco (partes, peças, papéis)
class Boneco:
    def __init__(self, rig, cores, nome=""):
        self.rig = rig
        self.cores = dict(cores)
        self.nome = nome
        self.grupos = {p: [] for p in PARTES}
        self.uv_rosto = None  # (x0, x1, z0, z1) da projeção frontal do rosto
        self.textura_rosto = None
        self.tex_camisa = None  # bpy.Image do molde 585x559 (Shirt clássica) ou None
        self.tex_calca = None   # idem (Pants clássica)
        self.escala = (1.0, 1.0, 1.0)  # (largura, profundidade, altura) como HumanoidDescription
        self.escala_cabeca = 1.0
        self.facetado = False

    def add(self, parte, papel, bm, peca="corpo", suave=None):
        normais_fora(bm)
        self.grupos[parte].append((peca, papel, bm, (not self.facetado) if suave is None else suave))

    def tris(self):
        """{peca: {parte: tris}}"""
        t = {}
        for parte, gs in self.grupos.items():
            for peca, _, bm, _ in gs:
                t.setdefault(peca, {}).setdefault(parte, 0)
                t[peca][parte] += triangulos(bm)
        return t


# ====================================================================================== pose (FK nos pivôs do estilo)
def pose_de_clipe(nome, t=None, indice=None):
    """Resolve uma chave de tools/blender/anim_clipes.py com anim_pose.resolver -> {junta: (Quaternion, Vector|None)}
    no espaço do Roblox (rotação do Motor6D.Transform)."""
    import anim_clipes
    import anim_pose
    clipe = anim_clipes.CLIPES[nome]
    chaves = clipe["chaves"]
    if indice is None:
        indice = min(range(len(chaves)), key=lambda i: abs(chaves[i][0] - t))
    canais = {k: anim_pose.canal(k, v) for k, v in chaves[indice][1].items()}
    pose, _ = anim_pose.resolver(canais, clipe.get("modos", {}))
    return pose


def deltas(rig, pose=None):
    """{parte: Matrix 4x4} levando a parte do repouso à pose (espaço autoral). Part1 = Part0 * C0 * Transform * C1^-1."""
    D = {"HumanoidRootPart": Matrix.Identity(4)}
    for junta, (p0, p1) in JUNTAS.items():
        piv = rig["pivos"][junta]
        m = Matrix.Identity(4)
        if pose and junta in pose:
            q, t = pose[junta]
            qa = (R2A @ q.to_matrix() @ R2A.transposed()).to_4x4()
            m = qa
            if t is not None:
                m = Matrix.Translation(R2A @ Vector(t)) @ m
        D[p1] = D[p0] @ Matrix.Translation(piv) @ m @ Matrix.Translation(-piv)
    return D


# ====================================================================================== materiais
def _lin(c):
    return tuple(((x / 255.0) / 12.92) if x / 255.0 <= 0.04045 else (((x / 255.0) + 0.055) / 1.055) ** 2.4 for x in c[:3])


PROPRIEDADES = {  # papel -> (rugosidade, metálico, brilho especular)
    "metal": (0.32, 0.9, 0.5), "couro": (0.55, 0.0, 0.5), "bota": (0.5, 0.0, 0.5), "sola": (0.8, 0.0, 0.3),
    "cabelo": (0.5, 0.0, 0.45), "barba": (0.55, 0.0, 0.45), "olho": (0.2, 0.0, 0.5), "madeira": (0.45, 0.0, 0.5),
    "base": (0.6, 0.0, 0.3), "rotulo": (0.9, 0.0, 0.0),
}


def material(nome, cor, papel="", textura=None, madeira=False):
    chave = f"{nome}|{cor}|{papel}|{id(textura) if textura else 0}|{madeira}"
    if chave in bpy.data.materials:
        return bpy.data.materials[chave]
    mt = bpy.data.materials.new(chave)
    mt.use_nodes = True
    nos, lig = mt.node_tree.nodes, mt.node_tree.links
    p = nos["Principled BSDF"]
    rug, met, spec = PROPRIEDADES.get(papel, (0.62, 0.0, 0.4))
    p.inputs["Roughness"].default_value = rug
    p.inputs["Metallic"].default_value = met
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = spec
    base = (*_lin(cor), 1.0)
    if textura is not None:
        tex = nos.new("ShaderNodeTexImage")
        tex.image = textura
        tex.interpolation = "Linear"
        mix = nos.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["A"].default_value = base
        lig.new(tex.outputs["Alpha"], mix.inputs["Factor"])
        lig.new(tex.outputs["Color"], mix.inputs["B"])
        lig.new(mix.outputs["Result"], p.inputs["Base Color"])
    elif madeira:
        # veio de madeira só na prévia (no Roblox: Enum.Material.Wood faz esse papel)
        coord = nos.new("ShaderNodeTexCoord")
        onda = nos.new("ShaderNodeTexWave")
        onda.inputs["Scale"].default_value = 2.2
        onda.inputs["Distortion"].default_value = 6.0
        onda.inputs["Detail"].default_value = 3.0
        lig.new(coord.outputs["Object"], onda.inputs["Vector"])
        rampa = nos.new("ShaderNodeValToRGB")
        escuro = tuple(x * 0.62 for x in _lin(cor))
        rampa.color_ramp.elements[0].color = (*escuro, 1)
        rampa.color_ramp.elements[1].color = base
        lig.new(onda.outputs["Fac"], rampa.inputs["Fac"])
        lig.new(rampa.outputs["Color"], p.inputs["Base Color"])
    else:
        p.inputs["Base Color"].default_value = base
    if papel == "olho_brilho":
        p.inputs["Emission Color"].default_value = base
        p.inputs["Emission Strength"].default_value = 1.5
    return mt


def material_corpo(pele, calca, camisa):
    """Pele do corpo com Pants e Shirt clássicas por cima (o alfa do molde deixa a cor do corpo aparecer, como no Roblox)."""
    chave = f"corpo|{pele}|{calca.name if calca else ''}|{camisa.name if camisa else ''}"
    if chave in bpy.data.materials:
        return bpy.data.materials[chave]
    mt = bpy.data.materials.new(chave)
    mt.use_nodes = True
    nos, lig = mt.node_tree.nodes, mt.node_tree.links
    p = nos["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.72
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = 0.35
    saida = None
    base = (*_lin(pele), 1.0)
    for img in (calca, camisa):
        if img is None:
            continue
        tex = nos.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest" if False else "Linear"
        mix = nos.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        if saida is None:
            mix.inputs["A"].default_value = base
        else:
            lig.new(saida, mix.inputs["A"])
        lig.new(tex.outputs["Alpha"], mix.inputs["Factor"])
        lig.new(tex.outputs["Color"], mix.inputs["B"])
        saida = mix.outputs["Result"]
    if saida is None:
        p.inputs["Base Color"].default_value = base
    else:
        lig.new(saida, p.inputs["Base Color"])
    return mt


# ====================================================================================== rosto pintado (numpy)
class Tela:
    """Textura RGBA do rosto em coordenadas de stud no plano frontal da cabeça: x em [x0, x1], z em [z0, z1]."""

    def __init__(self, x0, x1, z0, z1, n=512):
        import numpy as np
        self.np = np
        self.x0, self.x1, self.z0, self.z1, self.n = x0, x1, z0, z1, n
        xs = np.linspace(x0, x1, n)
        zs = np.linspace(z0, z1, n)
        self.X, self.Z = np.meshgrid(xs, zs)  # linha 0 = z0 (de baixo: como bpy.Image.pixels)
        self.px = (x1 - x0) / n
        self.rgba = np.zeros((n, n, 4), dtype=np.float32)

    def elipse(self, cx, cz, rx, rz, ang=0.0):
        np = self.np
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        dx, dz = self.X - cx, self.Z - cz
        u = (dx * ca + dz * sa) / rx
        v = (-dx * sa + dz * ca) / rz
        d = (np.sqrt(u * u + v * v) - 1.0) * min(rx, rz)
        return np.clip(0.5 - d / self.px, 0.0, 1.0)

    def traco(self, pts, larguras):
        """Linha poligonal com largura variável (afina nas pontas). Devolve cobertura."""
        np = self.np
        melhor = np.full(self.X.shape, 1e9, dtype=np.float32)
        for (ax, az), (bx, bz), wa, wb in zip(pts[:-1], pts[1:], larguras[:-1], larguras[1:]):
            vx, vz = bx - ax, bz - az
            l2 = vx * vx + vz * vz + 1e-12
            t = np.clip(((self.X - ax) * vx + (self.Z - az) * vz) / l2, 0, 1)
            d = np.sqrt((self.X - (ax + t * vx)) ** 2 + (self.Z - (az + t * vz)) ** 2) - (wa + (wb - wa) * t) / 2
            melhor = np.minimum(melhor, d)
        return np.clip(0.5 - melhor / self.px, 0.0, 1.0)

    def pintar(self, cobertura, cor, alfa=1.0):
        np = self.np
        a = (cobertura * alfa)[..., None]
        c = np.array([*_lin(cor), 1.0], dtype=np.float32)
        self.rgba[..., :3] = c[:3] * a + self.rgba[..., :3] * (1 - a)
        self.rgba[..., 3:] = a + self.rgba[..., 3:] * (1 - a)

    def imagem(self, nome):
        img = bpy.data.images.new(nome, self.n, self.n, alpha=True, float_buffer=True)
        img.colorspace_settings.name = "Linear Rec.709"
        img.pixels.foreach_set(self.rgba.ravel())
        img.pack()
        return img

    def salvar_png(self, caminho):
        np = self.np
        rgb = self.rgba[..., :3]
        srgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(np.maximum(rgb, 0), 1 / 2.4) - 0.055)
        img = bpy.data.images.new("tmp_png", self.n, self.n, alpha=True)
        out = np.concatenate([srgb, self.rgba[..., 3:]], axis=2)
        img.pixels.foreach_set(out.ravel())
        img.filepath_raw = caminho
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)


def olho_amendoado(tela, cx, cz, larg, alt, cor_iris, lado, iris=0.62, delineado=0.028, brilho=True, cilios=False,
                   inclinacao=6.0):
    """Olho estilizado: esclera em amêndoa, íris, pupila, brilho, pálpebra superior grossa (lado: -1 direito, +1 esq.)."""
    np = tela.np
    esc = tela.elipse(cx, cz, larg / 2, alt / 2, ang=-lado * inclinacao)
    tela.pintar(esc, (248, 244, 236))
    ri = alt * 0.5 * iris / 0.62 * 0.62
    ir = tela.elipse(cx + lado * 0.0, cz - alt * 0.04, ri * 0.98, ri) * esc
    tela.pintar(ir, cor_iris)
    tela.pintar(tela.elipse(cx, cz - alt * 0.04, ri * 0.98, ri) * esc * np.clip((tela.Z - (cz - alt * 0.3)) / (alt * 0.5), 0, 1),
                tuple(int(c * 0.55) for c in cor_iris), 0.55)
    tela.pintar(tela.elipse(cx, cz - alt * 0.03, ri * 0.48, ri * 0.52) * esc, (16, 12, 14))
    if brilho:
        tela.pintar(tela.elipse(cx - lado * ri * 0.35 + ri * 0.1, cz + ri * 0.32, ri * 0.24, ri * 0.24) * esc, (255, 255, 255))
    # pálpebra superior: arco grosso que afina nas pontas
    pts, ws = [], []
    for i in range(9):
        t = i / 8
        a = math.pi * (1 - t)
        x = cx + math.cos(a) * larg / 2 * 1.06
        z = cz + math.sin(a) * alt / 2 * 1.02 - lado * (x - cx) * math.tan(math.radians(inclinacao))
        pts.append((x, z))
        w = delineado * (0.4 + 0.9 * math.sin(math.pi * min(1.0, t * 1.15)))
        if (lado < 0 and t < 0.25) or (lado > 0 and t > 0.75):
            w *= 1.25  # canto externo mais marcado
        ws.append(w)
    tela.pintar(tela.traco(pts, ws), (34, 22, 20))
    if cilios:
        ext = pts[0] if lado < 0 else pts[-1]
        tela.pintar(tela.traco([ext, (ext[0] + lado * larg * 0.16, ext[1] + alt * 0.18)], [delineado * 0.9, 0.002]), (34, 22, 20))
    # linha inferior suave
    pts2 = []
    for i in range(7):
        a = math.pi + math.pi * i / 6
        pts2.append((cx + math.cos(a) * larg / 2 * 0.9, cz + math.sin(a) * alt / 2 * 1.0))
    tela.pintar(tela.traco(pts2, [0.002, 0.008, 0.01, 0.01, 0.01, 0.008, 0.002]), (120, 70, 60), 0.35)


def sobrancelha(tela, cx, cz, larg, grossura, cor, lado, arco=0.02, angulo=-6.0):
    pts, ws = [], []
    for i in range(7):
        t = i / 6
        x = cx - lado * larg / 2 + lado * larg * t
        z = cz + math.sin(math.pi * t) * arco + (t - 0.5) * larg * math.tan(math.radians(angulo)) * -1
        pts.append((x, z))
        ws.append(grossura * (1.15 - 0.75 * t))  # grossa perto do nariz, fina na ponta
    tela.pintar(tela.traco(pts, ws), cor)


def boca(tela, cx, cz, larg, curva, cor=(110, 46, 44), grossura=0.016, labio=None):
    pts, ws = [], []
    for i in range(7):
        t = i / 6
        x = cx - larg / 2 + larg * t
        z = cz - math.sin(math.pi * t) * curva + (abs(t - 0.5) * 2) ** 2 * curva * 0.6
        pts.append((x, z))
        ws.append(grossura * (0.35 + 0.65 * math.sin(math.pi * t)))
    if labio:
        tela.pintar(tela.elipse(cx, cz - grossura * 1.6, larg * 0.32, grossura * 1.2), labio, 0.45)
    tela.pintar(tela.traco(pts, ws), cor)


# ====================================================================================== instanciar no Blender
def instanciar(boneco, pos=(0, 0, 0), rot_z=0.0, pose=None, apoiar=True, nome=""):
    """Cria os objetos do boneco (cópias dos bmeshes) na pose dada, girado rot_z graus e com a escala de raça.
    Devolve a lista de objetos."""
    rig = boneco.rig
    D = deltas(rig, pose)
    sw, sd, sh = boneco.escala
    if boneco.escala_cabeca != 1.0:
        piv = rig["pivos"]["Neck"]
        s = boneco.escala_cabeca
        D["Head"] = D["Head"] @ Matrix.Translation(piv) @ Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation(-piv)
    G = Matrix.Rotation(math.radians(rot_z), 4, "Z") @ Matrix.Diagonal((sw, sd, sh, 1))
    objs = []
    for parte, gs in boneco.grupos.items():
        for peca, papel, bm, suave in gs:
            copia = bm.copy()
            malha = bpy.data.meshes.new(f"{parte}_{papel}")
            copia.to_mesh(malha)
            copia.free()
            for pl in malha.polygons:
                pl.use_smooth = suave
            o = bpy.data.objects.new(f"{nome}{parte}_{peca}_{papel}", malha)
            bpy.context.scene.collection.objects.link(o)
            o.matrix_world = G @ D[parte]
            cor = boneco.cores.get(papel, (200, 0, 200))
            if papel == "rosto":
                mt = material("rosto", boneco.cores["pele"], papel, textura=boneco.textura_rosto)
            elif papel == "corpo":
                # Shirt cobre tronco e braços; Pants cobre tronco e pernas (o molde usa as mesmas regiões para os dois)
                braco = "Arm" in parte or "Hand" in parte
                perna = "Leg" in parte or "Foot" in parte
                mt = material_corpo(boneco.cores["pele"], None if braco else boneco.tex_calca,
                                    None if perna else boneco.tex_camisa)
            else:
                mt = material(papel, cor, papel, madeira=(papel in ("madeira", "cabelo_avatar")))
            malha.materials.append(mt)
            objs.append(o)
    bpy.context.view_layer.update()
    dz = 0.0
    if apoiar:
        dz = -min((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
    for o in objs:
        o.matrix_world = Matrix.Translation(Vector(pos) + Vector((0, 0, dz))) @ o.matrix_world
    return objs


def objetos_avulsos(bm, nome, cor, papel="", suave=True, matriz=None):
    malha = bpy.data.meshes.new(nome)
    bm.to_mesh(malha)
    for pl in malha.polygons:
        pl.use_smooth = suave
    o = bpy.data.objects.new(nome, malha)
    bpy.context.scene.collection.objects.link(o)
    if matriz is not None:
        o.matrix_world = matriz
    malha.materials.append(material(nome, cor, papel))
    return o


def espada(boneco, pose, pos, rot_z, objs_ref=None):
    """Espada curta presa à mão direita (lâmina para a frente/-Y em repouso, como na pega das animações)."""
    rig = boneco.rig
    D = deltas(rig, pose)
    sw, sd, sh = boneco.escala
    G = Matrix.Rotation(math.radians(rot_z), 4, "Z") @ Matrix.Diagonal((sw, sd, sh, 1))
    mao = rig["mao_centro"]["Right"]
    bm_l, bm_g, bm_c = bmesh.new(), bmesh.new(), bmesh.new()
    y0 = mao.y
    # cabo atravessando o punho (eixo Y), guarda e lâmina para -Y
    sweep(bm_c, [(Vector((mao.x, y0 + 0.62, mao.z)), 0.08, 0.08), (Vector((mao.x, y0 - 0.3, mao.z)), 0.075, 0.075)],
          up=(0, 0, 1), lados=8)
    sweep(bm_g, [(Vector((mao.x, y0 + 0.74, mao.z)), 0.13, 0.13), (Vector((mao.x, y0 + 0.62, mao.z)), 0.1, 0.1)],
          up=(0, 0, 1), lados=8)
    caixa(bm_g, (mao.x, y0 - 0.36, mao.z), (0.16, 0.12, 0.9))
    L = 2.5
    sec = [(Vector((mao.x, y0 - 0.4, mao.z)), 0.17, 0.035), (Vector((mao.x, y0 - 0.4 - L * 0.82, mao.z)), 0.15, 0.03),
           (Vector((mao.x, y0 - 0.4 - L, mao.z)), 0.0, 0.0)]
    sweep(bm_l, sec, up=(1, 0, 0), lados=4, expo=2.0)
    objs = []
    for bm, nome, cor, papel in ((bm_l, "lamina", (196, 204, 212), "metal"), (bm_g, "guarda", (150, 120, 70), "metal"),
                                 (bm_c, "cabo", (80, 52, 36), "couro")):
        normais_fora(bm)
        o = objetos_avulsos(bm, nome, cor, papel, suave=False, matriz=G @ D["RightHand"])
        bm.free()
        objs.append(o)
    return objs


def deslocar(objs, d):
    for o in objs:
        o.matrix_world = Matrix.Translation(Vector(d)) @ o.matrix_world


# ====================================================================================== cena, luz, textos, render
def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def cena_estudio(luz_ambiente=0.32, ceu=(0.62, 0.6, 0.57)):
    cena = bpy.context.scene
    cena.render.engine = "BLENDER_EEVEE"
    ee = cena.eevee
    for attr, val in (("taa_render_samples", 64), ("use_shadows", True), ("use_raytracing", True),
                      ("shadow_ray_count", 2), ("shadow_step_count", 8), ("use_fast_gi", True)):
        if hasattr(ee, attr):
            try:
                setattr(ee, attr, val)
            except Exception:
                pass
    cena.view_settings.view_transform = "AgX"
    try:
        cena.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    cena.render.film_transparent = True
    mundo = bpy.data.worlds.new("Estudio")
    mundo.use_nodes = True
    bg = mundo.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*ceu, 1.0)
    bg.inputs["Strength"].default_value = luz_ambiente
    cena.world = mundo
    return cena


def tres_pontos(azimute_camera=0.0, forca=1.0):
    """Luz de três pontos em sóis (direção constante: vale para várias fileiras na mesma cena). azimute_camera em graus
    (0 = câmera em -Y olhando +Y)."""
    def sol(nome, energia, cor, az, el, angulo):
        l = bpy.data.lights.new(nome, "SUN")
        l.energy = energia * forca
        l.color = cor
        l.angle = math.radians(angulo)
        o = bpy.data.objects.new(nome, l)
        bpy.context.scene.collection.objects.link(o)
        # luz vinda da direção (az, el) relativa à câmera
        a = math.radians(az + azimute_camera)
        e = math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        o.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        return o
    sol("Chave", 3.6, (1.0, 0.93, 0.84), -42, 48, 6)
    sol("Preenchimento", 1.1, (0.80, 0.88, 1.0), 55, 18, 12)
    sol("Recorte", 4.2, (1.0, 0.95, 0.88), 160, 32, 4)
    sol("Recorte2", 2.2, (0.85, 0.9, 1.0), -150, 40, 4)


def camera_orto(centro, largura, altura_img, largura_img, elevacao=6.0, azimute=0.0, dist=60.0):
    cena = bpy.context.scene
    cena.render.resolution_x, cena.render.resolution_y = largura_img, altura_img
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cena.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = largura
    cam.data.clip_end = 500
    a, e = math.radians(azimute), math.radians(elevacao)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = Vector(centro) + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cena.camera = cam
    return cam


def camera_persp(alvo, dist, elevacao, azimute, lente=50, largura_img=1600, altura_img=900):
    cena = bpy.context.scene
    cena.render.resolution_x, cena.render.resolution_y = largura_img, altura_img
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cena.collection.objects.link(cam)
    cam.data.lens = lente
    cam.data.clip_end = 500
    a, e = math.radians(azimute), math.radians(elevacao)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = Vector(alvo) + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cena.camera = cam
    return cam


def base_miniatura(x, y, z=0.0, raio=1.25, cor=(72, 56, 44)):
    bm = bmesh.new()
    sec = [(Vector((x, y, z - 0.18)), raio, raio), (Vector((x, y, z - 0.02)), raio, raio),
           (Vector((x, y, z)), raio - 0.04, raio - 0.04)]
    sweep(bm, sec, up=(0, 1, 0), lados=40)
    o = objetos_avulsos(bm, "base", cor, "base", suave=True)
    bm.free()
    # bordas facetadas visíveis: suaviza por ângulo
    return o


def texto(corpo, pos, tamanho=0.32, cor=(52, 38, 30), elevacao=6.0, alinhar="CENTER", azimute=0.0):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = corpo
    cu.size = tamanho
    cu.align_x = alinhar
    cu.align_y = "CENTER"
    o = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(o)
    o.location = pos
    o.rotation_euler = (math.radians(90 - elevacao), 0, math.radians(azimute))
    mt = bpy.data.materials.new("txt")
    mt.use_nodes = True
    p = mt.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*_lin(cor), 1)
    p.inputs["Emission Color"].default_value = (*_lin(cor), 1)
    p.inputs["Emission Strength"].default_value = 0.6
    p.inputs["Roughness"].default_value = 1.0
    cu.materials.append(mt)
    return o


def renderizar(caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.context.scene.render.filepath = caminho
    bpy.context.scene.render.image_settings.file_format = "PNG"
    bpy.context.scene.render.image_settings.color_mode = "RGBA"
    bpy.ops.render.render(write_still=True)
    print("PNG", caminho)
    return caminho


def compor(arquivos, destino, fundo_topo=(232, 226, 214), fundo_base=(198, 190, 176)):
    """Empilha PNGs (com alfa) na vertical sobre um fundo neutro em degradê e grava `destino`."""
    import numpy as np
    imgs = []
    for a in arquivos:
        im = bpy.data.images.load(a)
        w, h = im.size
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        imgs.append(px)
        bpy.data.images.remove(im)
    W = max(i.shape[1] for i in imgs)
    H = sum(i.shape[0] for i in imgs)
    tela = np.zeros((H, W, 4), dtype=np.float32)
    t = np.linspace(0, 1, H)[:, None]  # linha 0 = base da imagem final
    topo = np.array(fundo_topo, dtype=np.float32) / 255
    base = np.array(fundo_base, dtype=np.float32) / 255
    tela[..., :3] = (base * (1 - t) + topo * t)[:, None, :].repeat(W, axis=1)[:, :, :3].reshape(H, W, 3)
    tela[..., 3] = 1
    y = H
    for px in imgs:
        h, w = px.shape[:2]
        y -= h
        x = (W - w) // 2
        a = px[..., 3:4]
        reg = tela[y:y + h, x:x + w, :3]
        tela[y:y + h, x:x + w, :3] = px[..., :3] * a + reg * (1 - a)
    out = bpy.data.images.new("folha", W, H, alpha=False)
    out.pixels.foreach_set(tela.ravel())
    out.filepath_raw = destino
    out.file_format = "JPEG" if destino.lower().endswith((".jpg", ".jpeg")) else "PNG"
    out.save()
    print("FOLHA", destino)


def solidificar(bm, espessura, offset=-1.0):
    """Dá espessura a uma casca aberta (cabelo, capuz) com o modificador Solidify. Devolve um bmesh novo."""
    malha = bpy.data.meshes.new("_sol")
    bm.to_mesh(malha)
    bm.free()
    o = bpy.data.objects.new("_sol", malha)
    bpy.context.scene.collection.objects.link(o)
    mod = o.modifiers.new("s", "SOLIDIFY")
    mod.thickness = espessura
    mod.offset = offset
    mod.use_even_offset = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    novo = bmesh.new()
    novo.from_mesh(ev.to_mesh())
    ev.to_mesh_clear()
    bpy.data.objects.remove(o)
    bpy.data.meshes.remove(malha)
    return novo


def aro(bm, c, hx, hy, w, h, n=36, expo_caminho=8.0, expo=4.0, lados=8):
    """Aro fechado em retângulo arredondado (cinto, canos de bota, punhos em membros de caixa): seção w (radial) x h."""
    c = Vector(c)
    sec, ups = [], []
    for k in range(n):
        a = 2 * math.pi * k / n
        ca, sa = math.cos(a), math.sin(a)
        x, y = hx * _se(ca, expo_caminho), hy * _se(sa, expo_caminho)
        sec.append((c + Vector((x, y, 0)), h, w))
        ups.append(Vector((x / hx ** 2, y / hy ** 2, 0)).normalized())
    return sweep(bm, sec, up=lambda i: ups[i], lados=lados, expo=expo, fechado=True)
