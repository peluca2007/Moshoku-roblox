"""Resolve uma pose autoral (canais) nas 15 rotações de junta do R15 + translação da raiz (ANIM1).

Canais (todos opcionais; o que faltar vem da pose de repouso):
  raiz_pos (x, y, z)   deslocamento do pivô da raiz (centro da LowerTorso), studs, eixos do personagem
  raiz_rot (rx,ry,rz)  rotação da LowerTorso;   cintura, pescoco: rotações locais (Waist, Neck)
  Braço X (X = D ou E), modo "fk": ombroX, cotoveloX, pulsoX (rotações locais)
  Braço X, modo "ik": maoX (x, y, z) = onde fica o pivô do PULSO, somado ao ponto de referência `ref_maoX` do clipe
            ("mundo", "ombroD", "ombroE", "pescoco"); poloX = para onde aponta o cotovelo; pulsoX = rotação local da mão
  Perna X, modo "ik" (padrão): peX (x, y, z) = centro da sola no mundo (y = altura do pé), peX_rot = rotação do pé no
            mundo, joelhoX_polo = para onde aponta o joelho (padrão: frente do pé, um pouco para fora)
  Perna X, modo "fk": quadrilX, joelhoX, tornozeloX (rotações locais)
Rotações autorais em graus (rx, ry, rz) -> `anim_rig.rot` (Rx * Ry * Rz, como CFrame.Angles).
"""
from mathutils import Quaternion, Vector

import anim_rig as R

ROTACOES = {
    "raiz_rot", "cintura", "pescoco", "ombroD", "cotoveloD", "pulsoD", "ombroE", "cotoveloE", "pulsoE",
    "peD_rot", "peE_rot", "quadrilD", "joelhoD", "tornozeloD", "quadrilE", "joelhoE", "tornozeloE",
}
POSICOES = {"pesoIK_bracoD", "pesoIK_bracoE", "pesoIK_pernas", "raiz_pos", "maoD", "maoE", "poloD", "poloE", "peD", "peE", "joelhoD_polo", "joelhoE_polo"}

LADOS = {"D": "Right", "E": "Left"}
SINAL = {"D": 1.0, "E": -1.0}


def canal(nome, valor):
    """Converte o valor autoral (tupla) no tipo do canal."""
    if isinstance(valor, (Quaternion, Vector)):
        return valor.copy()
    if nome in ROTACOES:
        return R.rot(*valor)
    if nome in POSICOES:
        return Vector(valor)
    raise KeyError("canal desconhecido: " + nome)


def padrao(nome):
    if nome in ROTACOES:
        return R.rot()
    if nome == "raiz_pos" or nome.startswith("pesoIK_"):
        return Vector((0, 0, 0))
    if nome in ("peD", "peE"):
        s = SINAL[nome[-1]]
        return Vector((0.5 * s, 0.0, 0.0))
    if nome in ("maoD", "maoE"):
        return Vector(R.JUNTAS[LADOS[nome[-1]] + "Wrist"][2])
    if nome in ("poloD", "poloE"):
        return Vector((0.3 * SINAL[nome[-1]], -0.2, 1.0))
    if nome in ("joelhoD_polo", "joelhoE_polo"):
        return Vector((0.25 * SINAL[nome[0:-5][-1]], 0.0, -1.0))
    raise KeyError(nome)


def ponto_ref(mundo, ref):
    if ref == "mundo":
        return Vector((0, 0, 0))
    if ref in ("ombroD", "ombroE"):
        return R.pivo_mundo(mundo, LADOS[ref[-1]] + "Shoulder")
    if ref == "pescoco":
        return R.pivo_mundo(mundo, "Neck")
    raise KeyError(ref)


def peso_ik(c, modos, membro):
    """Peso IK (0 = FK, 1 = IK) do membro ("bracoD", "bracoE", "pernas"): canal `pesoIK_<membro>` (Vector, só x) ou,
    sem canal, o modo do clipe. As chaves convertidas de outro modo carregam o peso do modo em que foram escritas,
    então a primeira e a última chave reproduzem a POSTURA exatamente e a troca FK<->IK é gradual."""
    nome = "pesoIK_" + membro
    if nome in c:
        return max(0.0, min(1.0, c[nome].x))
    padrao_ = "ik" if membro == "pernas" else "fk"
    return 1.0 if modos.get(membro, padrao_) == "ik" else 0.0


def _misturar(a, b, w):
    if w <= 0.0:
        return a
    if w >= 1.0:
        return b
    if a.dot(b) < 0:
        b = Quaternion((-b.w, -b.x, -b.y, -b.z))
    return a.slerp(b, w)


def resolver(c, modos):
    """c = {canal: valor já convertido}; modos = {"bracoD": "fk"/"ik", "bracoE": ..., "pernas": "ik"/"fk",
    "ref_maoD": ..., "ref_maoE": ...}. Cada membro: pose FK dos canais, IK dos alvos e mistura pelo peso IK.
    Devolve ({junta: (Quaternion, Vector|None)}, maior erro dos pés em IK pleno)."""
    def g(nome):
        return c[nome] if nome in c else padrao(nome)

    pose = {"Root": (g("raiz_rot"), g("raiz_pos")), "Waist": (g("cintura"), None), "Neck": (g("pescoco"), None)}
    for X, L in LADOS.items():
        pose[L + "Shoulder"] = (g("ombro" + X), None)
        pose[L + "Elbow"] = (g("cotovelo" + X), None)
        pose[L + "Wrist"] = (g("pulso" + X), None)
        pose[L + "Hip"] = (g("quadril" + X), None)
        pose[L + "Knee"] = (g("joelho" + X), None)
        pose[L + "Ankle"] = (g("tornozelo" + X), None)
    mundo = R.fk(pose)  # a mãe dos membros (LowerTorso/UpperTorso) só depende de Root e Waist
    w_pernas = peso_ik(c, modos, "pernas")
    for X, L in LADOS.items():
        if w_pernas > 0:
            q_pe = g("pe" + X + "_rot")
            alvo = g("pe" + X) + q_pe @ Vector((0, R.ALTURA_PE, 0))
            polo = g("joelho" + X + "_polo") if ("joelho" + X + "_polo") in c else q_pe @ padrao("joelho" + X + "_polo")
            q1, q2, qm2 = R.ik2(R.pivo_mundo(mundo, L + "Hip"), R.vet_repouso(L + "Hip", L + "Knee"),
                                R.vet_repouso(L + "Knee", L + "Ankle"), alvo, polo, Vector((1, 0, 0)),
                                R.rot_de(mundo["LowerTorso"]), 1.0)
            for junta, q in ((L + "Hip", q1), (L + "Knee", q2), (L + "Ankle", qm2.inverted() @ q_pe)):
                pose[junta] = (_misturar(pose[junta][0], q, w_pernas), None)
        w = peso_ik(c, modos, "braco" + X)
        if w > 0:
            alvo = ponto_ref(mundo, modos.get("ref_mao" + X, "mundo")) + g("mao" + X)
            q1, q2, _ = R.ik2(R.pivo_mundo(mundo, L + "Shoulder"), R.vet_repouso(L + "Shoulder", L + "Elbow"),
                              R.vet_repouso(L + "Elbow", L + "Wrist"), alvo, g("polo" + X), Vector((1, 0, 0)),
                              R.rot_de(mundo["UpperTorso"]), -1.0)
            pose[L + "Shoulder"] = (_misturar(pose[L + "Shoulder"][0], q1, w), None)
            pose[L + "Elbow"] = (_misturar(pose[L + "Elbow"][0], q2, w), None)
    # conferência: os alvos dos pés foram atingidos (só faz sentido com IK plena)?
    erros = 0.0
    if w_pernas >= 1.0:
        mundo = R.fk(pose)
        for X, L in LADOS.items():
            q_pe = g("pe" + X + "_rot")
            alvo = g("pe" + X) + q_pe @ Vector((0, R.ALTURA_PE, 0))
            erros = max(erros, (R.pivo_mundo(mundo, L + "Ankle") - alvo).length)
    return pose, erros
