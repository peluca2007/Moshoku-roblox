"""Rig R15 de referência e matemática das animações por dados (ANIM1).

Tudo aqui é no ESPAÇO DO ROBLOX: Y para cima, o personagem olha para -Z, a mão direita fica em +X.
Só a prévia converte para o Blender (`para_blender`). Em repouso todas as peças do R15 ficam alinhadas aos
eixos do personagem (C0/C1 são só translação), então a rotação do `Motor6D.Transform` de uma junta é a rotação
da peça filha relativa à peça mãe, expressa nos eixos da mãe:  Part1.CFrame = Part0.CFrame * C0 * Transform * C1:Inverse().

Convenção de ângulos autorais (`rot`): graus, matriz = Rx * Ry * Rz (a mesma de `CFrame.Angles(rx, ry, rz)`).
  ombro/quadril/cotovelo Rx(+) leva o membro para a FRENTE (-Z); joelho dobra com Rx(-);
  ombro direito Rz(+) abre o braço para fora; no esquerdo o "para fora" é Rz(-) (`espelhar`);
  Ry(+) gira a frente para a esquerda do personagem (-X).
Proporções: boneco de blocos R15 padrão (mesmas medidas de tools/blender/avatar.py: cabeça 1,2 com centro em y=4,6,
UpperTorso 2 x 1,6 x 1 em y=3,2, LowerTorso 2 x 0,4 x 1 em y=2,2, mãos em y~1,55, pés 1 x 0,3 x 1 no chão).
"""
import math

from mathutils import Matrix, Quaternion, Vector

# peça -> (centro em repouso, tamanho). HumanoidRootPart não é desenhada.
PECAS = {
    "HumanoidRootPart": ((0.0, 2.2, 0.0), (2.0, 2.0, 1.0)),
    "LowerTorso": ((0.0, 2.2, 0.0), (2.0, 0.4, 1.0)),
    "UpperTorso": ((0.0, 3.2, 0.0), (2.0, 1.6, 1.0)),
    "Head": ((0.0, 4.6, 0.0), (1.2, 1.2, 1.2)),
}
for _lado, _s in (("Right", 1.0), ("Left", -1.0)):
    PECAS[_lado + "UpperArm"] = ((1.5 * _s, 3.40, 0.0), (1.0, 1.10, 1.0))
    PECAS[_lado + "LowerArm"] = ((1.5 * _s, 2.285, 0.0), (1.0, 1.13, 1.0))
    PECAS[_lado + "Hand"] = ((1.5 * _s, 1.56, 0.0), (1.0, 0.32, 1.0))
    PECAS[_lado + "UpperLeg"] = ((0.5 * _s, 1.60, 0.0), (1.0, 0.80, 1.0))
    PECAS[_lado + "LowerLeg"] = ((0.5 * _s, 0.75, 0.0), (1.0, 0.90, 1.0))
    PECAS[_lado + "Foot"] = ((0.5 * _s, 0.15, 0.0), (1.0, 0.30, 1.0))

# junta -> (Part0, Part1, pivô em repouso). Ordem = ordem de avaliação (mãe antes da filha).
JUNTAS = {
    "Root": ("HumanoidRootPart", "LowerTorso", (0.0, 2.2, 0.0)),
    "Waist": ("LowerTorso", "UpperTorso", (0.0, 2.4, 0.0)),
    "Neck": ("UpperTorso", "Head", (0.0, 4.0, 0.0)),
}
for _lado, _s in (("Right", 1.0), ("Left", -1.0)):
    JUNTAS[_lado + "Shoulder"] = ("UpperTorso", _lado + "UpperArm", (1.0 * _s, 3.76, 0.0))
    JUNTAS[_lado + "Elbow"] = (_lado + "UpperArm", _lado + "LowerArm", (1.5 * _s, 2.85, 0.0))
    JUNTAS[_lado + "Wrist"] = (_lado + "LowerArm", _lado + "Hand", (1.5 * _s, 1.72, 0.0))
    JUNTAS[_lado + "Hip"] = ("LowerTorso", _lado + "UpperLeg", (0.5 * _s, 2.0, 0.0))
    JUNTAS[_lado + "Knee"] = (_lado + "UpperLeg", _lado + "LowerLeg", (0.5 * _s, 1.2, 0.0))
    JUNTAS[_lado + "Ankle"] = (_lado + "LowerLeg", _lado + "Foot", (0.5 * _s, 0.3, 0.0))

NOMES_JUNTAS = list(JUNTAS)
ALTURA_PE = 0.3  # do chão ao pivô do tornozelo
IDENT = Quaternion((1.0, 0.0, 0.0, 0.0))


def V(*c):
    return Vector(c[0] if len(c) == 1 else c)


def rot(rx=0.0, ry=0.0, rz=0.0):
    """Graus -> Quaternion, matriz Rx * Ry * Rz (como CFrame.Angles)."""
    qx = Quaternion((1, 0, 0), math.radians(rx))
    qy = Quaternion((0, 1, 0), math.radians(ry))
    qz = Quaternion((0, 0, 1), math.radians(rz))
    return qx @ qy @ qz


def espelhar_q(q):
    """Rotação espelhada no plano YZ (troca direita/esquerda): (x, y, z, w) -> (x, -y, -z, w)."""
    return Quaternion((q.w, q.x, -q.y, -q.z))


def espelhar_v(v):
    return Vector((-v.x, v.y, v.z))


def cframe(pos, q):
    m = q.to_matrix().to_4x4()
    m.translation = Vector(pos)
    return m


def fk(pose):
    """pose = {junta: (Quaternion, Vector translação ou None)} -> {peça: Matrix 4x4 no mundo (HRP na origem do rig)}.
    Fórmula do Roblox: Part1 = Part0 * C0 * Transform * C1^-1, com C0/C1 só translação até o pivô."""
    mundo = {"HumanoidRootPart": cframe(PECAS["HumanoidRootPart"][0], IDENT)}
    for nome, (p0, p1, pivo) in JUNTAS.items():
        c0 = Matrix.Translation(Vector(pivo) - Vector(PECAS[p0][0]))
        c1 = Matrix.Translation(Vector(pivo) - Vector(PECAS[p1][0]))
        q, t = pose.get(nome, (IDENT, None))
        tr = cframe(t if t is not None else (0, 0, 0), q)
        mundo[p1] = mundo[p0] @ c0 @ tr @ c1.inverted()
    return mundo


def pivo_mundo(mundo, junta):
    p0, _, pivo = JUNTAS[junta]
    return mundo[p0] @ (Vector(pivo) - Vector(PECAS[p0][0]))


def rot_de(m):
    return m.to_quaternion()


def _quadro(eixo, dobra):
    """Base ortonormal: coluna 0 = dobra (ortogonalizada), coluna 1 = eixo do segmento, coluna 2 = 0 x 1."""
    a = eixo.normalized()
    h = dobra - a * dobra.dot(a)
    if h.length < 1e-6:
        h = a.orthogonal()
    h.normalize()
    c = h.cross(a)
    return Matrix((h, a, c)).transposed()


def ik2(raiz, r1, r2, alvo, polo, dobra_repouso, q_mae, sinal=1.0):
    """IK de dois segmentos. raiz = pivô da junta 1 (mundo); r1, r2 = vetores de repouso (pivô->pivô) nos eixos
    das peças; alvo = onde o pivô da junta 3 deve ficar; polo = para onde a junta do meio aponta; dobra_repouso = eixo
    da dobradiça em repouso (X); q_mae = rotação no mundo da peça mãe da junta 1.
    Devolve (q_local1, q_local2, q_mundo2): rotações locais das juntas 1 e 2 e rotação no mundo do segmento 2."""
    l1, l2 = r1.length, r2.length
    d = alvo - raiz
    dist = max(min(d.length, l1 + l2 - 1e-4), abs(l1 - l2) + 1e-4)
    dirv = d.normalized() if d.length > 1e-6 else Vector((0, -1, 0))
    u = polo - dirv * polo.dot(dirv)
    if u.length < 1e-6:
        u = dirv.orthogonal()
    u.normalize()
    cos_a = max(-1.0, min(1.0, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)))
    a = math.acos(cos_a)
    meio = raiz + (dirv * math.cos(a) + u * math.sin(a)) * l1
    fim = raiz + dirv * dist
    s1 = (meio - raiz).normalized()
    s2 = (fim - meio).normalized()
    h1 = dirv.cross(u) * sinal
    m_mae = q_mae.to_matrix()
    m1 = _quadro(s1, h1) @ _quadro(m_mae @ r1, m_mae @ dobra_repouso).transposed() @ m_mae
    m2 = _quadro(s2, h1) @ _quadro(m1 @ r2, m1 @ dobra_repouso).transposed() @ m1
    q1 = (m_mae.transposed() @ m1).to_quaternion()
    q2 = (m1.transposed() @ m2).to_quaternion()
    return q1, q2, m2.to_quaternion()


def vet_repouso(j_a, j_b):
    return Vector(JUNTAS[j_b][2]) - Vector(JUNTAS[j_a][2])


# Roblox (x, y, z) -> Blender: o personagem olha para +Y do Blender, Z para cima (rotação própria, det = +1).
PARA_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def para_blender(m):
    return PARA_BLENDER @ m @ PARA_BLENDER.inverted()
