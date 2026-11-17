"""Redireciona UMA animação do Mixamo (FBX, rig X Bot / mixamorig:*) para o R15 e grava um clipe do projeto (HAB1).

Uso (Blender sem janela, via tools/blender_rodar.py):
  python tools/blender_rodar.py tools/blender/anim_mixamo.py --fbx "build/ferramentas/mixamo/<pacote>/<arquivo>.fbx" \
      --nome CorteDeBraco [--inicio 12] [--fim 70] [--velocidade 1.0] [--impacto 0.55] [--laco] [--segurar] \
      [--sem-registro] [--sem-previa]

O que faz (reaproveita anim_ual.py, que já desfaz a T-pose e normaliza escala/eixos para o R15):
  1. importa o FBX (dado NÃO confiável: só é lido pelo importador do Blender, nunca executado);
  2. acha os ossos pelo nome (mixamorig:Hips, Spine2, LeftArm, LeftForeArm, LeftUpLeg...), refaz a pose de referência
     (braços/pernas para baixo), amostra a ação a 30 fps no recorte [inicio, fim] (quadros do FBX) e escala o
     deslocamento da pelve pela razão das alturas do quadril;
  3. sem --impacto, o marco `impacto` vai no instante de maior velocidade da mão direita (o contato do golpe);
  4. ergue a raiz até a sola do primeiro quadro tocar o chão, confere pé/penetração e gera a folha de prévia
     (build/anim/previa);
  5. grava src/shared/Animacoes/Clipes/<nome>.luau (origem "mixamo") e registra o nome em Catalogo.luau
     (sem regenerar os demais clipes, ao contrário de anim_exportar.py).

Licença: as animações do Mixamo (Adobe) podem ser usadas nos jogos, mas os FBX crus não podem ser redistribuídos:
ficam em build/ferramentas/mixamo (ignorado pelo git); só os clipes convertidos (dados {t,qx,qy,qz,qw}) entram no
repositório. Procedência em docs/ARTE.md.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import anim_exportar as E  # noqa: E402
import anim_previa  # noqa: E402
import anim_rig as R  # noqa: E402
import anim_ual  # noqa: E402


def args():
    o = {"fbx": None, "nome": None, "inicio": None, "fim": None, "velocidade": 1.0, "impacto": None, "laco": False,
         "segurar": False, "registro": True, "previa": True}
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    i = 0
    while i < len(a):
        k = a[i]
        if k in ("--fbx", "--nome"):
            o[k[2:]] = a[i + 1]; i += 2
        elif k in ("--inicio", "--fim", "--velocidade", "--impacto"):
            o[k[2:]] = float(a[i + 1]); i += 2
        elif k == "--laco":
            o["laco"] = True; i += 1
        elif k == "--segurar":
            o["segurar"] = True; i += 1
        elif k == "--sem-registro":
            o["registro"] = False; i += 1
        elif k == "--sem-previa":
            o["previa"] = False; i += 1
        else:
            raise SystemExit("argumento desconhecido: " + k)
    if not o["fbx"] or not o["nome"]:
        raise SystemExit(__doc__)
    return o


def registrar(nome):
    """Acrescenta o clipe ao Catalogo.luau (CLIPES e NOMES) se ainda não estiver."""
    txt = open(E.CATALOGO, encoding="utf-8").read()
    if f"\t{nome} = require" in txt:
        return
    marca = "}\n\nreturn {"
    txt = txt.replace(marca, f"\t{nome} = require(Shared.Animacoes.Clipes.{nome}), -- HAB1: Mixamo (tools/blender/anim_mixamo.py)\n" + marca, 1)
    i = txt.index("NOMES = {")
    j = txt.index("}", i)
    txt = txt[:j].rstrip() + f', "{nome}" ' + txt[j:]
    with open(E.CATALOGO, "w", encoding="utf-8", newline="\n") as f:
        f.write(txt)


def principal():
    o = args()
    caminho = os.path.abspath(o["fbx"])
    arm = anim_ual.importar(caminho)
    ossos = anim_ual.achar_ossos(arm)
    acoes = [a for a in bpy.data.actions if a.frame_range[1] > a.frame_range[0]]
    if not acoes:
        raise SystemExit("o FBX não tem ação animada: " + caminho)
    acao = acoes[0]
    arm.animation_data_create()
    arm.animation_data.action = acao
    fps_origem = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    f0, f1 = acao.frame_range
    f0 = o["inicio"] if o["inicio"] is not None else f0
    f1 = o["fim"] if o["fim"] is not None else f1
    vel = o["velocidade"]
    dur = (f1 - f0) / fps_origem / vel
    n = int(math.ceil(dur * E.FPS - 1e-9))
    ts = [min(k / E.FPS, dur) for k in range(n + 1)]
    qs = [f0 + t * vel * fps_origem for t in ts]
    quadros = [(t / vel * vel, p) for t, p in anim_ual.amostrar_armature(arm, ossos, qs, fps_origem, f0)]
    # amostrar_armature devolve t = (quadro - inicio) / fps_origem; com velocidade, reescala para o tempo final
    quadros = [(ts[i], p) for i, (_, p) in enumerate(quadros)]
    base = {"duracao": round(dur, 4), "laco": o["laco"], "segurar": o["segurar"], "marcos": {}}
    dados = E.para_dados(o["nome"], base, quadros, "mixamo")
    # marco de impacto: instante de maior velocidade da mão direita (ou o pedido)
    if o["impacto"] is None:
        melhor, t_melhor, ant = 0.0, dur * 0.5, None
        for k in range(1, 4 * n):
            t = k * dur / (4 * n)
            pos = anim_previa.posar(dados, t)["RightHand"].translation
            if ant is not None:
                v = (pos - ant).length / (dur / (4 * n))
                if v > melhor:
                    melhor, t_melhor = v, t
            ant = pos
        dados["marcos"] = {"impacto": round(t_melhor, 3)}
    else:
        dados["marcos"] = {"impacto": o["impacto"]}
    m = anim_previa.posar(dados, 0.0)
    m0 = min((m[l + "Foot"] @ c).y for l in ("Right", "Left") for c in anim_previa._cantos(R.PECAS[l + "Foot"][1]))
    dados["raiz"] = [[t, x, y - m0, z] for t, x, y, z in dados["raiz"]]
    nota = ("Origem: Mixamo (Adobe), pacote Pro Sword and Shield; redirecionada para o R15 por tools/blender/anim_mixamo.py. "
            "Arquivo FBX cru não redistribuído (docs/ARTE.md).")
    E.escrever_luau(dados, os.path.join(E.PASTA_CLIPES, o["nome"] + ".luau"), nota)
    n_chaves = sum(len(v) for v in dados["juntas"].values()) + len(dados["raiz"])
    linha = f"[{o['nome']}] fonte={os.path.basename(caminho)} dur={dados['duracao']} impacto={dados['marcos']['impacto']} chaves={n_chaves}"
    if o["previa"]:
        c = anim_previa.conferir(dados, E._pontos_arma(None))
        linha += f" pe_min={c['pe_min'][0]:.3f}@{c['pe_min'][1]:.2f} penetra={c['penetra'][0]:.3f}@{c['penetra'][1]:.2f} {c['penetra'][2]}"
        png = anim_previa.folha(o["nome"], dados, None, E.PASTA_PREVIA, 8)
        linha += " -> " + os.path.relpath(png, E.RAIZ)
    print(linha)
    if o["registro"]:
        registrar(o["nome"])
        print("catálogo: registrado", o["nome"])


principal()
