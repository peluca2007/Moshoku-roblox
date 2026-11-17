#!/bin/sh
# REA4: regenera os clipes Mixamo das criaturas humanoides (reação leve/forte, esquiva, bloqueio, morte).
# Uso: sh tools/blender/gerar_reacoes_criaturas.sh   (precisa dos FBX em build/ferramentas/mixamo, fora do git)
M=BandidoEspadaQuaternius,BandidoPorreteQuaternius,GoblinQuaternius,EsqueletoQuaternius
MP=build/ferramentas/mixamo/Pro_Magic_Pack; LB=build/ferramentas/mixamo/Pro_Longbow_Pack; SS=build/ferramentas/mixamo/Pro_Sword_and_Shield_Pack
g() { f="$1"; n="$2"; shift 2; python tools/blender_rodar.py tools/blender/anim_mixamo.py --fbx "$f" --nome "$n" --criatura $M --sem-r15 "$@" | grep -iE "error|criatura: Bandido.*Espada|Trace"; }
g "$MP/Standing React Small From Front.fbx" ReacaoLeve --volta 0.2
g "$MP/Standing React Large From Front.fbx" ReacaoForte --volta 0.25
g "$LB/standing dodge backward.fbx" Esquiva --volta 0.35
g "$LB/standing dodge left.fbx" EsquivaLado --volta 0.35
g "$LB/standing dodge right.fbx" EsquivaLadoD --volta 0.35
g "$MP/Standing Block React Large.fbx" Bloqueio --volta 0.25
g "$SS/sword and shield death.fbx" MorrerMx --segurar
