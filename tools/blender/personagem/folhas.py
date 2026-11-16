"""Folhas da PERS1 (fase 1): build/personagem/estilo_roblox.png e build/personagem/comparacao.png.

Uso:  python tools/blender_rodar.py tools/blender/personagem/folhas.py [--folha estilo|comparacao|todas] [--escala 1.0]
Também grava os moldes de roupa (PNG 585 x 559) e o rosto em build/personagem/moldes/ e a contagem de triângulos em
build/personagem/triangulos.json.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import comum as C  # noqa: E402
import roblox_r15 as R  # noqa: E402
import roupas as RP  # noqa: E402
import cabelos_racas as CR  # noqa: E402

TMP = os.path.join(C.SAIDA, "_tmp")
MOLDES = os.path.join(C.SAIDA, "moldes")
PELES = {"clara": (234, 192, 156), "media": (190, 136, 98), "escura": (112, 72, 52), "elfo": (240, 210, 186)}
CABELO = {"castanho": (92, 58, 36), "loiro": (226, 196, 120), "ruivo": (168, 70, 36), "preto": (34, 30, 34),
          "prata": (200, 204, 214), "azul": (60, 100, 180)}
_imgs = {}


def boneco(conjunto="aventureiro", cabelo="curto", raca=None, pele="clara", cor_cabelo="castanho", escala=None,
           sem_pecas=False, olho=(92, 55, 32)):
    cj = RP.CONJUNTOS[conjunto]
    cores = dict(RP.CORES_BASE)
    cores.update(cj["cores"])
    cores["pele"] = PELES[pele]
    cores["pele_interna"] = (226, 150, 150)
    cores["cabelo"] = CABELO[cor_cabelo]
    cores["barba"] = CABELO[cor_cabelo]
    cores["cabelo_avatar"] = (70, 44, 30)
    b = R.corpo(cores)
    chave = (conjunto, pele)
    if chave not in _imgs:
        cam = cj["camisa"](dict(cores))
        cal = cj["calca"](dict(cores))
        os.makedirs(MOLDES, exist_ok=True)
        cam.salvar(os.path.join(MOLDES, f"camisa_{conjunto}_{pele}.png"))
        cal.salvar(os.path.join(MOLDES, f"calca_{conjunto}_{pele}.png"))
        _imgs[chave] = (cam.imagem(f"camisa_{conjunto}_{pele}"), cal.imagem(f"calca_{conjunto}_{pele}"))
    b.tex_camisa, b.tex_calca = _imgs[chave]
    rk = ("rosto", olho, cor_cabelo)
    if rk not in _imgs:
        t = R.tela_rosto(olho, tuple(int(c * 0.7) for c in CABELO[cor_cabelo]))
        t.salvar_png(os.path.join(MOLDES, f"rosto_{cor_cabelo}.png"))
        _imgs[rk] = t.imagem(f"rosto_{cor_cabelo}")
    b.textura_rosto = _imgs[rk]
    if not sem_pecas:
        for f in cj["pecas"]:
            f(b)
    if cabelo:
        CR.CABELOS[cabelo](b)
    if raca:
        CR.RACAS[raca](b)
    if escala:
        b.escala = escala[:3]
        b.escala_cabeca = escala[3]
    b.conjunto = conjunto
    return b


def arma(b, pose, pos, rot_z):
    if getattr(b, "conjunto", "") == "mago":
        objs = RP.cajado(b, pose, pos, rot_z)
    else:
        objs = C.espada(b, pose, pos, rot_z)
    return objs


def colocar(b, x, rot=0.0, pose=None, com_arma=False, y=0.0):
    objs = C.instanciar(b, pos=(0, 0, 0), rot_z=rot, pose=pose, apoiar=False)
    if com_arma:
        objs += arma(b, pose, (0, 0, 0), rot)
    corpo = [o for o in objs if o.name.startswith(("Right", "Left", "Lower", "Upper", "Head"))]
    dz = -min((o.matrix_world @ v.co).z for o in corpo for v in o.data.vertices)
    C.deslocar(objs, (x, y, dz))
    C.base_miniatura(x, y)
    return objs


# ====================================================================================== folha do estilo
POSE_GOLPE = ("CorteLeve", 0.40)


def fileira(itens, titulo, arquivo, largura_px=2400, esp=3.9, elev=8.0, altura=8.4, margem=0.0):
    """itens = [(boneco, rotulo, rot, pose|None, arma)] numa fileira, câmera ortográfica frontal."""
    C.limpar()
    _imgs.clear()
    C.cena_estudio()
    C.tres_pontos()
    if callable(itens):
        itens = itens()
    n = len(itens)
    xs, x = [], 0.0
    for i, it in enumerate(itens):
        if i:
            x += esp + (2.0 if it[3] is not None else 0.0)  # golpe: espaço para a arma apontar à esquerda
        xs.append(x)
    x0 = -xs[-1] / 2
    for xi, (b, rot_lbl, rot, pose, com_arma) in zip(xs, itens):
        x = x0 + xi
        colocar(b, x, rot, pose, com_arma)
        C.texto(rot_lbl, (x, -1.6, -0.55), 0.3, elevacao=elev)
    largura = xs[-1] + esp + 0.6 + margem
    if titulo:
        C.texto(titulo, (x0 - esp / 2 + 0.3, -1.6, altura - 1.55), 0.42, alinhar="LEFT", elevacao=elev, cor=(110, 36, 30))
    alt_px = int(largura_px * altura / largura)
    C.camera_orto((0, 0, altura / 2 - 0.9), largura, alt_px, largura_px, elevacao=elev)
    return C.renderizar(os.path.join(TMP, arquivo))


VISTAS = [("frente", 0), ("3/4", -38), ("perfil", -90), ("costas", 180)]


def folha_estilo(so=""):
    arqs = []
    golpe = C.pose_de_clipe(*POSE_GOLPE)
    for conj, cab, cc in (("aventureiro", "avatar", "castanho"), ("ladino", None, "preto"), ("mago", "longo", "prata")):
        if so and so != conj:
            continue
        nome = RP.CONJUNTOS[conj]["nome"]

        def itens(conj=conj, cab=cab, cc=cc):
            b = boneco(conj, cab, None, "clara" if conj != "ladino" else "media", cc)
            return [(b, v, r, None, False) for v, r in VISTAS] + [(b, "golpe (CorteLeve)", -62, golpe, True)]
        arqs.append(fileira(itens, nome + ("  -  cabelo de exemplo no lugar do cabelo do avatar" if cab == "avatar" else ""),
                            f"conj_{conj}.png"))

    def racas():
        ana = boneco("aventureiro", "rabo", "ana", "media", "ruivo", escala=(1.12, 1.1, 0.85, 0.95))
        elfo = boneco("mago", "rabo", "elfo", "elfo", "loiro", escala=(0.92, 0.92, 1.04, 1.0), sem_pecas=True)
        RP.saia_manto(elfo)
        RP.mangas_sino(elfo)
        fera = boneco("ladino", "curto", "fera", "clara", "castanho", sem_pecas=True)
        for f in (RP.capelete, lambda bb: RP.cinto(bb, z=2.22, bolsa=False),
                  lambda bb: RP.canos_bota(bb, 0.9, "bota", altura=0.06)):
            f(fera)
        return [(elfo, "elfo: orelhas", -38, None, False), (elfo, "elfo (perfil)", -90, None, False),
                (ana, "anão: barba trançada", -30, None, False), (ana, "anão (golpe)", -62, golpe, True),
                (fera, "raça-fera: orelhas", -38, None, False), (fera, "raça-fera (costas)", 160, None, False)]
    if not so or so == "racas":
        arqs.append(fileira(racas, "Traços de raça (acessórios nossos, cor da pele/cabelo pela criação)", "racas.png", esp=4.1))

    def cabelos():
        itens = []
        for cab, cor in (("curto", "castanho"), ("longo", "loiro"), ("rabo", "preto"), ("espetado", "azul"),
                         ("curto", "ruivo"), ("longo", "prata")):
            b = boneco("aventureiro", cab, None, "clara" if cor != "preto" else "escura", cor, sem_pecas=True)
            itens.append((b, f"{cab} / {cor}", -38 if cab != "rabo" else -120, None, False))
        return itens
    if not so or so == "cabelos":
        arqs.append(fileira(cabelos, "Cabelos padrão nossos (uma cor por MeshPart: recoloríveis)", "cabelos.png", esp=3.7))
    if so:
        return
    C.compor(arqs, os.path.join(C.SAIDA, "estilo_roblox.png"))
    tris = {}
    for conj in RP.CONJUNTOS:
        tris[conj] = boneco(conj, None).tris()
    for cab in CR.CABELOS:
        tris["cabelo_" + cab] = boneco("aventureiro", cab, sem_pecas=True).tris().get("cabelo_" + cab, {})
    for rc in CR.RACAS:
        tb = boneco("aventureiro", None, rc, sem_pecas=True).tris()
        tris["raca_" + rc] = {k: v for k, v in tb.items() if k != "corpo"}
    with open(os.path.join(C.SAIDA, "triangulos.json"), "w", encoding="utf-8") as f:
        json.dump(tris, f, ensure_ascii=False, indent=1)
    print("TRIS", json.dumps(tris))


# ====================================================================================== comparação
def boneco_atual(x0, y0=0.0, rot=0.0):
    """Boneco de cubos do jogo hoje (tools/blender/previa.py:boneco_avatar) + cabelo curto, túnica, cinto e botas de avatar.py."""
    import avatar
    import formas  # noqa: F401
    pele = (238, 192, 152)
    objs = []
    R_ = Matrix.Rotation(math.radians(rot), 4, "Z")

    def cubo(centro, tam, cor):
        bm = bmesh.new()
        C.caixa(bm, centro, tam)
        objs.append(C.objetos_avulsos(bm, "atual", cor, "", suave=False))
        bm.free()
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
        cubo((s * 0.27, -0.61, 5.01), (0.22, 0.04, 0.06), (107, 86, 68))
    cubo((0, -0.65, 4.5), (0.12, 0.1, 0.24), (210, 170, 134))
    cubo((0, -0.61, 4.26), (0.26, 0.04, 0.05), (132, 56, 60))
    cores = {"Cabelo": (86, 58, 36), "CabeloSombra": (58, 39, 24), "Pele": pele}
    for nome in ("cabelocurto", "tunicabasica", "cintobasico", "botasbasicas"):
        for pos in avatar.posicoes_autorais(nome):
            modelo = avatar.GERADORES[nome](1)
            for o in modelo.finalizar():
                g = o.name.split(".")[0]
                cor = tuple(cores.get(g, modelo.grupos[g]["cor"]))
                o.data.materials.append(C.material("av_" + g, cor, ""))
                o.location = pos
                objs.append(o)
    bpy.context.view_layer.update()
    for o in objs:
        o.matrix_world = Matrix.Translation((x0, y0, 0)) @ R_ @ o.matrix_world
    return objs


def criatura(nome, x, y, rot=0.0, **kw):
    import criaturas
    modelo = criaturas.GERADORES[nome](1, **kw)
    objs = modelo.finalizar()
    modelo.apoiar_no_chao(objs)
    for o in objs:
        g = modelo.grupos[o.name.split(".")[0]]
        o.data.materials.append(C.material("cr_" + o.name, tuple(g["cor"]), "Neon" if g["material"] == "Neon" else ""))
    bpy.context.view_layer.update()
    for o in objs:
        o.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians(rot), 4, "Z") @ o.matrix_world
    return objs


def chao_grade(cx, cy, nx, ny, casa=5.0, cor=(112, 104, 92)):
    bm = bmesh.new()
    C.caixa(bm, (cx, cy, -0.1), (nx * casa, ny * casa, 0.2))
    C.objetos_avulsos(bm, "chao", cor, "base", suave=False)
    bm.free()
    linhas = bmesh.new()
    for i in range(nx + 1):
        x = cx - nx * casa / 2 + i * casa
        C.caixa(linhas, (x, cy, 0.005), (0.07, ny * casa, 0.01))
    for j in range(ny + 1):
        y = cy - ny * casa / 2 + j * casa
        C.caixa(linhas, (cx, y, 0.005), (nx * casa, 0.07, 0.01))
    C.objetos_avulsos(linhas, "linhas", (70, 64, 58), "base", suave=False)
    linhas.free()


def folha_comparacao():
    arqs = []
    # A) mesma escala e câmera: atual x três conjuntos novos (3/4, perspectiva)
    C.limpar()
    _imgs.clear()
    C.cena_estudio()
    C.tres_pontos()
    esp = 4.2
    boneco_atual(-1.5 * esp, rot=-25)
    C.base_miniatura(-1.5 * esp, 0)
    C.texto("ATUAL (cubos + caixas)", (-1.5 * esp, -1.7, -0.55), 0.3, elevacao=8, cor=(110, 36, 30))
    novos = [("aventureiro", "curto", "castanho", "clara"), ("ladino", None, "preto", "media"), ("mago", "longo", "prata", "clara")]
    for i, (cj, cab, cc, pl) in enumerate(novos):
        x = (-0.5 + i) * esp
        b = boneco(cj, cab, None, pl, cc)
        colocar(b, x, -25)
        C.texto("NOVO: " + RP.CONJUNTOS[cj]["nome"], (x, -1.7, -0.55), 0.26, elevacao=8)
    C.camera_persp((0.0, 0, 2.6), 30, 10, -20, lente=50, largura_px=2400, altura_px=1000) if False else \
        C.camera_orto((0, 0, 3.05), 4 * esp + 0.6, 1100, 2400, elevacao=8)
    arqs.append(C.renderizar(os.path.join(TMP, "comp_frente.png")))
    # B) vista da luta: câmera a 50 graus, casas de 5 studs, goblin e rato atuais
    C.limpar()
    _imgs.clear()
    C.cena_estudio(luz_ambiente=0.4)
    C.tres_pontos(-10)
    grupos = [("ATUAL", None), ("aventureiro", ("aventureiro", "curto", "castanho", "clara")),
              ("ladino", ("ladino", None, "preto", "media")), ("mago", ("mago", "longo", "prata", "clara"))]
    largura_grupo = 10.0
    chao_grade(0, 3.5, 8, 3)
    for i, (rot_lbl, spec) in enumerate(grupos):
        cx = -1.5 * largura_grupo + i * largura_grupo
        px, py = cx - 2.5, 0.0
        if spec is None:
            boneco_atual(px, py, rot=150)
        else:
            colocar(boneco(*spec[:2], None, spec[3], spec[2]), px, 150, None, False, y=py)
        criatura("goblin", cx + 2.5, 5.0, rot=180 + 30, variante="faca")
        criatura("rato", cx - 2.5, 5.0, rot=180 - 20)
        C.texto(rot_lbl.upper(), (cx, -3.8, 0.02), 0.6, elevacao=90, cor=(240, 230, 210))
    C.camera_persp((0, 3.0, 1.5), 46, 50, 0, 40, 2400, 1150)
    arqs.append(C.renderizar(os.path.join(TMP, "comp_luta.png")))
    C.compor(arqs, os.path.join(C.SAIDA, "comparacao.png"))


# ====================================================================================== prancha (PERS2)
def folha_prancha():
    """build/beleza/personagem/prancha.jpg: classes e raças principais, de frente e de lado, em pose de luta."""
    golpe = C.pose_de_clipe(*POSE_GOLPE)
    arqs = []

    def classes():
        itens = []
        for conj, cab, cc, pele in (("aventureiro", "curto", "castanho", "clara"), ("ladino", "espetado", "preto", "media"),
                                    ("mago", "longo", "prata", "clara")):
            b = boneco(conj, cab, None, pele, cc)
            itens += [(b, RP.CONJUNTOS[conj]["nome"] + " (frente)", -20, golpe, True),
                      (b, "perfil", -90, golpe, True)]
        return itens
    arqs.append(fileira(classes, "Classes: conjuntos do jogo (pano pintado + pecas), pose de luta", "pr_classes.png", esp=3.3, margem=2.4))

    def racas(rot):
        def f():
            humano = boneco("aventureiro", "curto", None, "media", "castanho")
            elfo = boneco("mago", "rabo", "elfo", "elfo", "loiro", escala=(0.92, 0.92, 1.04, 1.0))
            anao = boneco("aventureiro", "rabo", "ana", "media", "ruivo", escala=(1.12, 1.1, 0.85, 0.95))
            hobbit = boneco("aventureiro", "espetado", None, "clara", "castanho", escala=(0.9, 0.9, 0.78, 1.05))
            fera = boneco("ladino", "curto", "fera", "clara", "castanho")
            ogro = boneco("aventureiro", "curto", None, "escura", "preto", escala=(1.15, 1.12, 1.18, 1.08))
            return [(b, n, rot, golpe, True) for b, n in
                    ((humano, "humano"), (elfo, "elfo"), (anao, "anao"), (hobbit, "hobbit"), (fera, "raca-fera"), (ogro, "ogro"))]
        return f
    arqs.append(fileira(racas(-25), "Racas (frente): pele pela raca, tracos como acessorios", "pr_racas_f.png", esp=2.6, margem=2.4))
    arqs.append(fileira(racas(-90), "Racas (perfil)", "pr_racas_p.png", esp=2.6, margem=2.4))
    destino = os.path.join(C.RAIZ, "build", "beleza", "personagem")
    os.makedirs(destino, exist_ok=True)
    C.compor(arqs, os.path.join(destino, "prancha.jpg"))


def main():
    resto = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folha = resto[resto.index("--folha") + 1] if "--folha" in resto else "todas"
    so = resto[resto.index("--so") + 1] if "--so" in resto else ""
    if folha in ("estilo", "todas"):
        folha_estilo(so)
    if folha in ("comparacao", "todas"):
        folha_comparacao()
    if folha == "prancha":
        folha_prancha()


main()
