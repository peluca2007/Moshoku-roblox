"""Biblioteca dos geradores de modelos low-poly (roda dentro do Blender, sem janela).

Um modelo é um conjunto de GRUPOS; cada grupo vira um objeto (uma MeshPart no Roblox) com
cor e material próprios, gravados em <saida>.json. Assim a cor não depende de textura:
o Roblox ignora cor de material/vértice do FBX, e a pipeline repinta por grupo.
Unidades: 1 unidade do Blender = 1 stud. Z é "para cima" (vira Y no Roblox).
"""
import json
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector


def argumentos(padroes):
    """Lê `--chave valor` depois do `--` e converte para o tipo do padrão."""
    resto = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opcoes = dict(padroes)
    i = 0
    while i < len(resto):
        chave = resto[i].lstrip("-")
        opcoes[chave] = type(opcoes.get(chave, ""))(resto[i + 1])
        i += 2
    return opcoes


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


class Modelo:
    def __init__(self, nome):
        self.nome = nome
        self.grupos = {}  # nome -> {"bm", "cor", "material"}
        self.espelhar_y = False  # True: a frente (porta) modelada em -Y passa a ficar em +Y (+Z no Roblox)

    def grupo(self, nome, cor, material="Plastic"):
        if nome not in self.grupos:
            self.grupos[nome] = {"bm": bmesh.new(), "cor": list(cor), "material": material}
        return self.grupos[nome]["bm"]

    # ---------- primitivas (cada uma adiciona ao bmesh do grupo) ----------
    @staticmethod
    def caixa(bm, centro, tamanho, giro_z=0.0):
        m = Matrix.Translation(Vector(centro)) @ Matrix.Rotation(giro_z, 4, "Z") @ Matrix.Diagonal(Vector((*tamanho, 1.0)))
        bmesh.ops.create_cube(bm, size=1.0, matrix=m)

    @staticmethod
    def cilindro(bm, centro, raio, altura, lados=8, raio_topo=None, eixo="Z", tampas=True, giro_z=0.0):
        rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[eixo]
        m = Matrix.Translation(Vector(centro)) @ rot @ Matrix.Rotation(giro_z, 4, "Z")
        bmesh.ops.create_cone(bm, cap_ends=tampas, cap_tris=False, segments=lados, radius1=raio,
                              radius2=raio if raio_topo is None else raio_topo, depth=altura, matrix=m)

    @staticmethod
    def ramo(bm, inicio, fim, raio_ini, raio_fim, lados=6):
        """Cilindro cônico entre dois pontos quaisquer (troncos e galhos inclinados)."""
        a, b = Vector(inicio), Vector(fim)
        d = b - a
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados, radius1=raio_ini, radius2=raio_fim, depth=d.length, matrix=m)

    @staticmethod
    def esfera(bm, centro, raio, escala=(1, 1, 1), subdiv=2, ruido=0.0, rng=None, corte_z=None):
        m = Matrix.Translation(Vector(centro)) @ Matrix.Diagonal(Vector((raio * escala[0], raio * escala[1], raio * escala[2], 1.0)))
        resultado = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0, matrix=m)
        for v in resultado["verts"]:
            if ruido and rng:
                direcao = (v.co - Vector(centro))
                v.co += direcao * (rng.uniform(-ruido, ruido))
            if corte_z is not None and v.co.z < corte_z:
                v.co.z = corte_z

    @staticmethod
    def telhado(bm, centro, comprimento, largura, altura):
        """Prisma triangular fechado (telhado de duas águas) com a cumeeira ao longo de X.
        `centro` é o ponto do beiral (base) no meio; o prisma já inclui o beiral nas medidas."""
        cx, cy, cz = centro
        w, d = comprimento / 2, largura / 2
        base = [(-w, -d), (-w, d)]
        pts = [
            bm.verts.new((cx - w, cy - d, cz)), bm.verts.new((cx - w, cy + d, cz)), bm.verts.new((cx - w, cy, cz + altura)),
            bm.verts.new((cx + w, cy - d, cz)), bm.verts.new((cx + w, cy + d, cz)), bm.verts.new((cx + w, cy, cz + altura)),
        ]
        for f in [(0, 1, 2), (3, 5, 4), (0, 2, 5, 3), (1, 4, 5, 2), (0, 3, 4, 1)]:
            bm.faces.new([pts[i] for i in f])

    @staticmethod
    def prisma_y(bm, centro, largura, comprimento, altura):
        """Prisma triangular fechado com a cumeeira ao longo de Y (A-frame de tenda); base em `centro`."""
        cx, cy, cz = centro
        w, d = largura / 2, comprimento / 2
        v = [bm.verts.new((cx - w, cy - d, cz)), bm.verts.new((cx + w, cy - d, cz)), bm.verts.new((cx, cy - d, cz + altura)),
             bm.verts.new((cx - w, cy + d, cz)), bm.verts.new((cx + w, cy + d, cz)), bm.verts.new((cx, cy + d, cz + altura))]
        for f in [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]:
            bm.faces.new([v[i] for i in f])

    @staticmethod
    def telhado_4_aguas(bm, centro, comprimento, largura, altura):
        """Telhado de quatro águas (cumeeira ao longo de X; vira pirâmide se for quadrado)."""
        cx, cy, cz = centro
        w, d = comprimento / 2, largura / 2
        r = max(w - d, 0.0)
        a, b = bm.verts.new((cx - w, cy - d, cz)), bm.verts.new((cx + w, cy - d, cz))
        c, dd = bm.verts.new((cx + w, cy + d, cz)), bm.verts.new((cx - w, cy + d, cz))
        r1, r2 = bm.verts.new((cx - r, cy, cz + altura)), bm.verts.new((cx + r, cy, cz + altura))
        if r > 1e-6:
            faces = [(a, b, r2, r1), (c, dd, r1, r2), (dd, a, r1), (b, c, r2), (a, dd, c, b)]
        else:
            faces = [(a, b, r1), (b, c, r1), (c, dd, r1), (dd, a, r1), (a, dd, c, b)]
        for f in faces:
            bm.faces.new(list(f))

    # ---------- utilidades ----------
    @staticmethod
    def dividir_faces(bm, criterio):
        """Separa as faces de `bm` em dois bmeshes: (as que cumprem `criterio`, as demais)."""
        a, b = bmesh.new(), bmesh.new()
        mapa_a, mapa_b = {}, {}
        for face in bm.faces:
            alvo, mapa = (a, mapa_a) if criterio(face) else (b, mapa_b)
            novos = []
            for v in face.verts:
                if v.index not in mapa:
                    mapa[v.index] = alvo.verts.new(v.co)
                novos.append(mapa[v.index])
            try:
                alvo.faces.new(novos)
            except ValueError:
                pass
        return a, b

    def finalizar(self):
        """Converte cada grupo em objeto (flat shading, base no chão não é movida)."""
        objetos = []
        for nome in [n for n, g in self.grupos.items() if not g["bm"].faces]:
            self.grupos.pop(nome)["bm"].free()  # grupo sem geometria não vira objeto (nem entra no .json)
        for nome, g in self.grupos.items():
            bm = g["bm"]
            if self.espelhar_y:
                for v in bm.verts:
                    v.co.y = -v.co.y
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            for f in bm.faces:
                f.smooth = False
            malha = bpy.data.meshes.new(nome)
            bm.to_mesh(malha)
            bm.free()
            objeto = bpy.data.objects.new(nome, malha)
            bpy.context.scene.collection.objects.link(objeto)
            objeto.color = (*[c / 255.0 for c in g["cor"]], 1.0)
            objetos.append(objeto)
        return objetos

    def apoiar_no_chao(self, objetos):
        """Move todos os objetos juntos para a base ficar em z=0 e centrada em x/y.
        Com `manter_origem` (acessórios de traje) não mexe: a origem do modelo é o ponto de encaixe."""
        if getattr(self, "manter_origem", False):
            return
        minimo = min((o.matrix_world @ Vector(c))[2] for o in objetos for c in o.bound_box)
        xs = [(o.matrix_world @ Vector(c))[0] for o in objetos for c in o.bound_box]
        ys = [(o.matrix_world @ Vector(c))[1] for o in objetos for c in o.bound_box]
        dx, dy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        for o in objetos:
            o.location = (o.location.x - dx, o.location.y - dy, o.location.z - minimo)
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action="DESELECT")
        for o in objetos:
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    def exportar(self, objetos, saida, previa=""):
        os.makedirs(os.path.dirname(os.path.abspath(saida)), exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in objetos:
            o.select_set(True)
        bpy.ops.export_scene.fbx(filepath=saida, use_selection=True, apply_scale_options="FBX_SCALE_ALL",
                                 axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", bake_space_transform=False)
        lateral = os.path.splitext(saida)[0] + ".json"
        caixa_min = Vector((min((o.matrix_world @ Vector(c))[i] for o in objetos for c in o.bound_box) for i in range(3)))
        caixa_max = Vector((max((o.matrix_world @ Vector(c))[i] for o in objetos for c in o.bound_box) for i in range(3)))
        with open(lateral, "w", encoding="utf-8") as f:
            json.dump({
                "nome": self.nome,
                "grupos": {n: {"cor": g["cor"], "material": g["material"]} for n, g in self.grupos.items()},
                "dimensoes": [round(caixa_max[0] - caixa_min[0], 2), round(caixa_max[2] - caixa_min[2], 2), round(caixa_max[1] - caixa_min[1], 2)],
            }, f, ensure_ascii=False, indent=1)
        if previa:
            self._previa(objetos, previa, caixa_min, caixa_max, self.espelhar_y)
        print(f"[{self.nome}] objetos={len(objetos)} verts={sum(len(o.data.vertices) for o in objetos)} -> {saida}")

    @staticmethod
    def _previa(objetos, caminho, minimo, maximo, espelho=False):
        cena = bpy.context.scene
        cena.render.engine = "BLENDER_WORKBENCH"
        cena.display.shading.light = "STUDIO"
        cena.display.shading.color_type = "OBJECT"
        cena.display.shading.show_shadows = True
        cena.render.resolution_x, cena.render.resolution_y = 640, 512
        cena.render.film_transparent = False
        cena.world = bpy.data.worlds.new("Fundo")
        cena.world.color = (0.62, 0.78, 0.9)
        cena.render.filepath = os.path.abspath(caminho)
        tam = maximo - minimo
        centro = (minimo + maximo) / 2
        dist = max(tam.x, tam.y, tam.z) * 2.1 + 2
        camera = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        cena.collection.objects.link(camera)
        camera.location = centro + Vector((dist * 0.75, dist * 0.95 if espelho else -dist * 0.95, dist * 0.55))
        alvo = bpy.data.objects.new("Alvo", None)
        cena.collection.objects.link(alvo)
        alvo.location = centro
        regra = camera.constraints.new("TRACK_TO")
        regra.target, regra.track_axis, regra.up_axis = alvo, "TRACK_NEGATIVE_Z", "UP_Y"
        cena.camera = camera
        chao = bpy.data.objects.new("Chao", bpy.data.meshes.new("Chao"))
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=dist * 1.4)
        bm.to_mesh(chao.data)
        bm.free()
        chao.location = (centro.x, centro.y, minimo.z - 0.01)
        chao.color = (0.34, 0.5, 0.26, 1.0)
        cena.collection.objects.link(chao)
        os.makedirs(os.path.dirname(os.path.abspath(caminho)), exist_ok=True)
        bpy.ops.render.render(write_still=True)
