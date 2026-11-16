"""Redireciona clipes da Universal Animation Library (Quaternius, CC0) para o R15 (ANIM1).

O arquivo da UAL (glb/gltf/fbx baixado à mão para build/externos/ual/, ver tools/animacao/FONTES.md) é DADO NÃO
CONFIÁVEL: só é aberto pelo importador do Blender, nunca executado. Método (por segmento, no espaço do armature):
  1. acha os ossos pelo nome (nomes do esqueleto da UAL/Unreal, Mixamo e genéricos; sem diferenciar caixa);
  2. acha os eixos do personagem na pose de repouso (cima = pelve->cabeça, direita = ombro esq.->ombro dir.) e monta a
     matriz C que leva vetores do armature para o espaço do Roblox (X direita, Y cima, Z trás);
  3. "pose de referência" = repouso da UAL com cada membro girado (giro mínimo) para a direção do repouso do R15
     (braços e pernas para baixo, pé para a frente): isso desfaz a T/A-pose;
  4. rotação do segmento no quadro = W(t) * (A * W_repouso)^-1, levada ao Roblox por C;
  5. Transform da junta = D_mãe^-1 * D_filha (a mãe da Root é o HumanoidRootPart, parado);
  6. raiz: deslocamento da pelve, escalado pela razão das alturas do quadril, sem deriva horizontal acumulada.
`testar_ida_e_volta` monta um esqueleto sintético em T-pose com nomes da UAL, anima-o a partir de um clipe já exportado e
redireciona de volta: o erro mede a matemática (eixos, repouso, ordem de multiplicação), não a UAL real.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

import anim_curvas as C_
import anim_rig as R

# segmento R15 -> nomes candidatos do osso (normalizados: minúsculas, sem "_", ".", "-", " " e sem "mixamorig")
CANDIDATOS = {
    "LowerTorso": ["pelvis", "hips", "hip", "root_pelvis"],
    "UpperTorso": ["spine03", "spine3", "chest", "upperchest", "spine02", "spine2"],
    "Head": ["head"],
}
for _l, _u, _m in (("Right", "r", "right"), ("Left", "l", "left")):
    CANDIDATOS[_l + "UpperArm"] = [f"upperarm{_u}", f"{_m}arm", f"upperarm{_m}", f"{_m}upperarm"]
    CANDIDATOS[_l + "LowerArm"] = [f"lowerarm{_u}", f"forearm{_u}", f"{_m}forearm", f"lowerarm{_m}", f"{_m}lowerarm"]
    CANDIDATOS[_l + "Hand"] = [f"hand{_u}", f"{_m}hand", f"hand{_m}"]
    CANDIDATOS[_l + "UpperLeg"] = [f"thigh{_u}", f"{_m}upleg", f"upperleg{_m}", f"{_m}thigh", f"{_m}upperleg"]
    CANDIDATOS[_l + "LowerLeg"] = [f"calf{_u}", f"shin{_u}", f"{_m}leg", f"lowerleg{_m}", f"{_m}shin", f"{_m}lowerleg"]
    CANDIDATOS[_l + "Foot"] = [f"foot{_u}", f"{_m}foot", f"foot{_m}"]

# direção de repouso de cada membro no R15 (Roblox); torso e cabeça: sem alinhamento
REF_DIR = {}
for _l in ("Right", "Left"):
    for _s in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg"):
        REF_DIR[_l + _s] = Vector((0, -1, 0))
    REF_DIR[_l + "Foot"] = Vector((0, 0, -1))


def _norm(nome):
    n = nome.lower().replace("mixamorig", "")
    for c in "_.- :":
        n = n.replace(c, "")
    return n


def achar_ossos(arm):
    nomes = {_norm(b.name): b.name for b in arm.data.bones}
    achados = {}
    for seg, cands in CANDIDATOS.items():
        for c in cands:
            if c in nomes:
                achados[seg] = nomes[c]
                break
    faltam = [s for s in CANDIDATOS if s not in achados]
    if faltam:
        raise SystemExit("ossos não encontrados para: " + ", ".join(faltam) + " (ossos: " + ", ".join(b.name for b in arm.data.bones) + ")")
    return achados


def importar(caminho):
    ext = caminho.lower().rsplit(".", 1)[-1]
    antes = set(bpy.data.objects)
    if ext in ("glb", "gltf"):
        bpy.ops.import_scene.gltf(filepath=caminho)
    elif ext == "fbx":
        bpy.ops.import_scene.fbx(filepath=caminho, automatic_bone_orientation=False)
    else:
        raise SystemExit("formato não suportado: " + caminho)
    arms = [o for o in bpy.data.objects if o not in antes and o.type == "ARMATURE"]
    if not arms:
        raise SystemExit("nenhum armature em " + caminho)
    return arms[0]


def _eixos(arm, ossos):
    """Matriz 3x3 que leva vetores do espaço do armature para o do Roblox, achada na pose de repouso."""
    b = arm.data.bones
    cima = (b[ossos["Head"]].head_local - b[ossos["LowerTorso"]].head_local).normalized()
    direita = b[ossos["RightUpperArm"]].head_local - b[ossos["LeftUpperArm"]].head_local
    direita = (direita - cima * direita.dot(cima)).normalized()
    tras = direita.cross(cima)
    return Matrix((direita, cima, tras))  # linhas: v_roblox = C @ v_armature


def _alinhamentos(arm, ossos, C):
    """A[seg] (espaço do armature): giro mínimo que leva o osso em repouso à direção de repouso do R15."""
    A = {}
    Ci = C.transposed()
    for seg, osso in ossos.items():
        if seg in REF_DIR:
            dir_osso = (arm.data.bones[osso].matrix_local.to_3x3() @ Vector((0, 1, 0))).normalized()
            A[seg] = dir_osso.rotation_difference(Ci @ REF_DIR[seg]).to_matrix()
        else:
            A[seg] = Matrix.Identity(3)
    return A


def amostrar_armature(arm, ossos, quadros_blender, fps_origem, inicio=0):
    """Lê o armature nos quadros pedidos e devolve [(t, pose {junta: (q, t)})] no formato do exportador."""
    C = _eixos(arm, ossos)
    Ci = C.transposed()
    A = _alinhamentos(arm, ossos, C)
    repouso = {seg: arm.data.bones[o].matrix_local.to_3x3() for seg, o in ossos.items()}
    ref_inv = {seg: (A[seg] @ repouso[seg]).inverted() for seg in ossos}
    pelve0 = arm.data.bones[ossos["LowerTorso"]].head_local.copy()
    quadril_origem = abs((C @ arm.data.bones[ossos["RightUpperLeg"]].head_local)[1] -
                         (C @ (arm.data.bones[ossos["RightFoot"]].head_local))[1])
    quadril_r15 = R.JUNTAS["RightHip"][2][1] - R.JUNTAS["RightAnkle"][2][1]
    escala = quadril_r15 / max(quadril_origem, 1e-6)
    cena = bpy.context.scene
    saida = []
    desl0 = None
    for f in quadros_blender:
        cena.frame_set(int(f), subframe=f - int(f))
        D = {}
        for seg, o in ossos.items():
            W = arm.pose.bones[o].matrix.to_3x3()
            D[seg] = C @ (W @ ref_inv[seg]) @ Ci
        pose = {}
        for junta, (p0, p1, _) in R.JUNTAS.items():
            dm = Matrix.Identity(3) if p0 == "HumanoidRootPart" else D[p0]
            q = (dm.transposed() @ D[p1]).to_quaternion()
            pose[junta] = (q, None)
        desl = C @ (arm.pose.bones[ossos["LowerTorso"]].head - pelve0) * escala
        if desl0 is None:
            desl0 = Vector((desl.x, 0, desl.z))
        desl = desl - desl0  # começa na casa; o vertical fica
        desl.x = max(-0.6, min(0.6, desl.x))
        desl.z = max(-0.9, min(0.9, desl.z))
        pose["Root"] = (pose["Root"][0], desl)
        saida.append(((f - inicio) / fps_origem, pose))
    return saida


def exportar(caminho, mapa, fps):
    """mapa = {"CorteLeve": {"acao": "Sword_Attack", "inicio": quadro?, "fim": quadro?, "laco": bool?,
    "marcos": {"impacto": t}}}. Devolve {clipe: (quadros, info)} para anim_exportar.para_dados."""
    arm = importar(caminho)
    ossos = achar_ossos(arm)
    print("UAL: ossos", ossos)
    fps_origem = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    saida = {}
    for clipe, cfg in mapa.items():
        if clipe.startswith("_"):
            continue  # "_nota" e afins
        # "acao" pode ser uma lista de trechos ({acao, inicio, fim}) emendados em sequência; "velocidade" > 1 acelera
        trechos = cfg["acao"] if isinstance(cfg["acao"], list) else [cfg]
        vel = float(cfg.get("velocidade", 1.0))
        arm.animation_data_create()
        quadros_total, t_base, ok = [], 0.0, True
        for tr in trechos:
            nome_acao = tr["acao"] if isinstance(tr, dict) else tr
            acao = bpy.data.actions.get(nome_acao)
            if not acao:
                print("UAL: ação não encontrada:", nome_acao, "disponíveis:", [a.name for a in bpy.data.actions])
                ok = False
                break
            arm.animation_data.action = acao
            f0, f1 = acao.frame_range
            f0 = tr.get("inicio", f0) if isinstance(tr, dict) else f0
            f1 = tr.get("fim", f1) if isinstance(tr, dict) else f1
            dur = (f1 - f0) / fps_origem / vel
            n = int(math.ceil(dur * fps - 1e-9))
            ts = [min(k / fps, dur) for k in range(n + 1)]
            if quadros_total:
                ts = ts[1:]  # o primeiro quadro repete o último do trecho anterior
            qs = [f0 + t * vel * fps_origem for t in ts]
            for t, pose in amostrar_armature(arm, ossos, qs, fps_origem, f0):
                quadros_total.append((t_base + t / vel, pose))
            t_base += dur
        if not ok:
            continue
        saida[clipe] = (quadros_total,
                        {"duracao": round(t_base, 4), "laco": bool(cfg.get("laco")), "marcos": cfg.get("marcos", {}),
                         "segurar": bool(cfg.get("segurar"))})
    return saida


# ------------------------------------------------------------------------------------------------ teste sintético
OSSOS_SINTETICOS = {
    # nome: (cabeça, cauda, pai) em metros, Blender (Z cima, olha para -Y, direita do personagem = -X), T-pose
    "pelvis": ((0, 0, 1.0), (0, 0, 1.1), None),
    "spine_03": ((0, 0, 1.1), (0, 0.02, 1.5), "pelvis"),
    "Head": ((0, 0, 1.55), (0, 0, 1.8), "spine_03"),
}
for _x, _u in ((-1, "r"), (1, "l")):
    OSSOS_SINTETICOS.update({
        f"upperarm_{_u}": ((0.2 * _x, 0, 1.45), (0.5 * _x, 0.01, 1.45), "spine_03"),
        f"lowerarm_{_u}": ((0.5 * _x, 0.01, 1.45), (0.75 * _x, 0, 1.44), f"upperarm_{_u}"),
        f"hand_{_u}": ((0.75 * _x, 0, 1.44), (0.85 * _x, -0.01, 1.44), f"lowerarm_{_u}"),
        f"thigh_{_u}": ((0.1 * _x, 0, 1.0), (0.11 * _x, -0.01, 0.55), "pelvis"),
        f"calf_{_u}": ((0.11 * _x, -0.01, 0.55), (0.1 * _x, 0.02, 0.1), f"thigh_{_u}"),
        f"foot_{_u}": ((0.1 * _x, 0.02, 0.1), (0.1 * _x, -0.12, 0.02), f"calf_{_u}"),
    })


def _armature_sintetico():
    dados = bpy.data.armatures.new("UALSintetico")
    arm = bpy.data.objects.new("UALSintetico", dados)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for i, (nome, (cab, cau, pai)) in enumerate(OSSOS_SINTETICOS.items()):
        e = dados.edit_bones.new(nome)
        e.head, e.tail = cab, cau
        e.roll = 0.37 * i  # rolagens arbitrárias: o método não pode depender delas
        if pai:
            e.parent = dados.edit_bones[pai]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def testar_ida_e_volta(dados, fps):
    """Anima o esqueleto sintético com o clipe `dados` (formato exportado) e redireciona de volta.
    Devolve (maior erro angular em graus, maior erro da raiz em studs, erro da T-pose em graus)."""
    import anim_previa
    arm = _armature_sintetico()
    ossos = achar_ossos(arm)
    C = _eixos(arm, ossos)
    Ci = C.transposed()
    A = _alinhamentos(arm, ossos, C)
    repouso = {seg: arm.data.bones[o].matrix_local.to_3x3() for seg, o in ossos.items()}
    escala = (R.JUNTAS["RightHip"][2][1] - R.JUNTAS["RightAnkle"][2][1]) / 0.9
    pelve0 = arm.data.bones["pelvis"].head_local.copy()
    # conferência absoluta: em repouso (T-pose) o braço direito tem de sair abduzido 90 graus para +X (Rz+) e o
    # esquerdo para -X (Rz-); isso pega eixo trocado ou lado espelhado, que a ida e volta sozinha não pegaria
    bpy.context.scene.frame_set(0)
    tpose = amostrar_armature(arm, ossos, [0], fps)[0][1]
    erro_tpose = max(C_.angulo(tpose["RightShoulder"][0], R.rot(0, 0, 90)),
                     C_.angulo(tpose["LeftShoulder"][0], R.rot(0, 0, -90)),
                     C_.angulo(tpose["RightHip"][0], R.rot()), C_.angulo(tpose["Waist"][0], R.rot()))
    ordem = list(OSSOS_SINTETICOS)
    seg_de = {o: s for s, o in ossos.items()}
    n = int(math.ceil(dados["duracao"] * fps - 1e-9))
    tempos = [min(k / fps, dados["duracao"]) for k in range(n + 1)]
    bpy.context.scene.render.fps = fps
    for k, t in enumerate(tempos):
        m = anim_previa.posar(dados, t)
        for nome in ordem:
            pb = arm.pose.bones[nome]
            seg = seg_de[nome]
            Drb = m[seg].to_3x3()  # orientação da peça no Roblox (repouso = identidade)
            W = (Ci @ Drb @ C) @ A[seg] @ repouso[seg]
            M = W.to_4x4()
            if nome == "pelvis":
                desl = C_.amostrar_raiz(dados["raiz"], t)
                M.translation = pelve0 + Ci @ (desl / escala)
            else:
                pai = arm.pose.bones[nome].parent
                # mantém a cabeça do osso presa ao pai (posição de repouso relativa)
                rel = pai.bone.matrix_local.inverted() @ pb.bone.matrix_local
                M.translation = (pai.matrix @ rel).translation
            pb.matrix = M
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion", frame=k)
            pb.keyframe_insert("location", frame=k)
    volta = amostrar_armature(arm, ossos, list(range(n + 1)), fps)
    erro_rot, erro_raiz = 0.0, 0.0
    r0 = C_.amostrar_raiz(dados["raiz"], 0.0)
    r0 = Vector((r0.x, 0, r0.z))  # o redirecionamento começa na casa (tira o deslocamento horizontal inicial)
    for (t, pose) in volta:
        for junta, chaves in dados["juntas"].items():
            erro_rot = max(erro_rot, C_.angulo(pose[junta][0], C_.amostrar_junta(chaves, t)))
        erro_raiz = max(erro_raiz, (pose["Root"][1] - (C_.amostrar_raiz(dados["raiz"], t) - r0)).length)
    return erro_rot, erro_raiz, erro_tpose
