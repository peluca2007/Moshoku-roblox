"""RODA1/RODA2: QA da roda de ações da luta, com cliques e teclas reais no Studio (Play).

  python tools/qa/roda_qa.py [--video] [--sem-base]      (precisa do lock build/qa/STUDIO_EM_USO.txt criado por quem roda)

Leva o jogo até a luta da sala 1 do esgoto (qa.py esgoto_sala1 --manter-play), abre a roda pelo botão, escolhe
Golpear, Habilidades e Ações com o mouse, usa Andar (a roda fecha e a mira liga), testa as teclas C/1/2/3 e
confere os custos/apagados. Capturas em build/qa/<data>/roda_*.png; com --video grava build/beleza/roda2/roda.mp4.
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ  # noqa: E402

GUI = "LocalPlayer.PlayerGui.AcoesDoTurno."
LUA_BASE = "local g=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno local m=g.Menu "


def lua(q, corpo):
    return q.lua_cliente(LUA_BASE + corpo)


def corpo_visivel(q):
    return lua(q, "return tostring(m.Roda.Corpo.Visible and m.Roda.Corpo.Cunha_golpear.GroupTransparency<0.5)")


def lista_visivel(q):
    return lua(q, "return tostring(g.Lista.Visible)")


def linhas_da_lista(q):
    return lua(q, "local n={} for _,c in g.Lista.Cartas:GetChildren() do if c:IsA('TextButton') and c.Visible then table.insert(n,c.Name) end end table.sort(n) return table.concat(n,',')")


def custos(q):
    return lua(q, "local o={} for _,id in {'golpear','habilidades','acoes'} do local f=m.Roda.Corpo['Cunha_'..id]['Fatia_'..id] o[#o+1]=id..'='..f.Custo.Text..(f:GetAttribute('Bloqueada') and '(apagada)' or '') end return table.concat(o,' ')")


def aprender_agua(q):
    """Gancho QaAprender (só no Studio): a ficha aprende a Água; as cartas só chegam num snapshot novo, então
    encerra o turno pelo botão central e espera a vez voltar com as cartas da árvore."""
    q.lua_servidor("workspace:SetAttribute('QaAprender','agua') return 'ok'")
    q.esperar_lua("workspace:GetAttribute('QaAprenderFeito')", 8, "Server")
    q.clique(GUI + "Menu.Roda.Hub", 1000)
    return q.esperar(lambda: lua(q, "local n=0 for _,c in g.Lista.Cartas:GetChildren() do if c.Name:find('respingo') then n+=1 end end return tostring(n>0 and m.Visible)") == "true", 60, 3)


def passos(q):
    q.cenario = "roda"
    q.verificar("a roda existe, fechada, com o gatilho e o botão Encerrar", lua(q, "return tostring(m.Visible and m.Gatilho.Visible and m.Roda.Hub.Visible)") == "true"
                and corpo_visivel(q) == "false", lua(q, "return tostring(m.Visible)"), foto=True)
    q.foto("fechada", "roda_fechada")
    q.clique(GUI + "Menu.Gatilho", 900)
    q.verificar("botão Roda abre a roda", corpo_visivel(q) == "true", corpo_visivel(q), foto=True)
    q.foto("aberta", "roda_aberta")
    c = custos(q)
    q.verificar("cada fatia mostra custo (Ações)", "golpear=1 Ação" in c and "Ação" in c.split("acoes=")[1], c)
    q.clique(GUI + "Menu.Roda.Corpo.Cunha_golpear.Fatia_golpear", 900)
    q.verificar("Golpear abre a lista de golpes", lista_visivel(q) == "true" and "ataque-basico" in linhas_da_lista(q), linhas_da_lista(q), foto=True)
    q.foto("golpear", "roda_golpear")
    # RODA2: personagem COM habilidades (gancho QaAprender, ver aprender_agua): a árvore da Água
    q.clique(GUI + "Menu.Roda.Corpo.Cunha_habilidades.Fatia_habilidades", 1200)
    lh = linhas_da_lista(q)
    q.verificar("Habilidades abre a lista com cartas do livro (Água)", lista_visivel(q) == "true" and "respingo" in lh, lh[:140] + " | " + custos(q), foto=True)
    colada = lua(q, "local l=g.Lista local w=m.Roda return tostring(math.abs((l.AbsolutePosition.X+l.AbsoluteSize.X)-w.AbsolutePosition.X)<=14*g.Menu.Roda.AbsoluteSize.X/300)")
    q.verificar("lista colada à roda (≤ 14 px)", colada == "true", colada)
    tam = lua(q, "return tostring(m.Roda.Corpo.Cunha_golpear.Fatia_golpear.Custo.TextSize)")
    q.verificar("texto de custo com 16 px ou mais", float(tam or 0) >= 16, tam)
    q.foto("habilidades", "roda_habilidades")
    q.clique(GUI + "Menu.Roda.Corpo.Cunha_acoes.Fatia_acoes", 900)
    la = linhas_da_lista(q)
    q.verificar("Ações lista Andar", lista_visivel(q) == "true" and "mesa/andar" in la, la, foto=True)
    q.foto("acoes", "roda_acoes")
    # teclas (mouse fora): C fecha, C abre, 1 abre Golpear, 3 abre Ações
    q.tecla("C", 150, 900)
    q.verificar("tecla C fecha a roda e a lista", corpo_visivel(q) == "false" and lista_visivel(q) == "false", corpo_visivel(q) + lista_visivel(q))
    q.tecla("C", 150, 900)
    q.tecla("One", 150, 900)
    q.verificar("tecla 1 abre Golpear", lista_visivel(q) == "true" and "ataque-basico" in linhas_da_lista(q), linhas_da_lista(q))
    q.tecla("Three", 150, 900)
    q.verificar("tecla 3 troca para Ações", "mesa/andar" in linhas_da_lista(q), linhas_da_lista(q))
    # Andar pela lista: a roda fecha e a mira liga (mesmo fluxo do botão antigo)
    p = q.achar("Carta_mesa/andar", "AcoesDoTurno", "GuiButton")
    q.verificar("linha Andar encontrada", bool(p), p)
    if p:
        q.clique(p, 1000)
    mira = lua(q, "return tostring(m.CancelarMira.Visible)")
    q.verificar("Andar liga a mira e fecha a roda", mira == "true" and corpo_visivel(q) == "false", mira + corpo_visivel(q), foto=True)
    q.foto("mira_andar", "roda_mira_andar")
    q.clique(GUI + "Menu.CancelarMira", 800)
    q.verificar("Cancelar mira volta ao normal", lua(q, "return tostring(m.CancelarMira.Visible)") == "false")
    q.erros_do_console()


def main():
    video = "--video" in sys.argv
    if "--sem-base" not in sys.argv:  # --sem-base: já há um Play na luta (qa.py esgoto_sala1 --manter-play)
        subprocess.run([sys.executable, os.path.join(RAIZ, "tools", "qa", "qa.py"), "esgoto_sala1", "--manter-play"])
    q = Qa()
    try:
        time.sleep(2)
        q.cenario = "roda"
        q.verificar("a ficha aprendeu a Água (cartas na vez seguinte)", bool(aprender_agua(q)))  # fora do vídeo: espera a vez voltar
        if video:
            sys.path.insert(0, os.path.dirname(__file__))
            from gravar import Gravador
            saida = os.path.join(RAIZ, "build", "beleza", os.environ.get('RODA_PASTA', 'roda2'), "roda.mp4")
            with Gravador(saida, segundos=int(os.environ.get('RODA_VIDEO_S', '42'))):
                passos(q)
        else:
            passos(q)
    finally:
        q.fechar()
    print("RESULTADO: %d ok, %d falha(s)" % (q.ok, q.falhas))
    return 1 if q.falhas else 0


if __name__ == "__main__":
    sys.exit(main())
