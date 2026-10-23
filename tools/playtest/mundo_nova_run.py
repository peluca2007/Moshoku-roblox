"""Depois de uma derrota: fecha o resultado e começa outra run (MENU > Expedição > "Aprender na vila"), com cliques reais
por instance_path. Uso (Play em andamento, modo jogador): python tools/playtest/mundo_nova_run.py [--fuga]
  --fuga: o resultado foi "Fugiu" (botão Continuar do painel de combate) em vez de vitória/derrota (ResultadoPartida).
Imprime relógio e posição (a run nova nasce em (0,-70), com o relógio andando; "pausado" = a run não começou, p.ex.
um encontro novo prendeu o avatar antes: use mundo_bot_combate2/mundo_bot_fugir e repita)."""
import json
import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
# O cliente MCP liga MoshokuTesteMestre ao iniciar o Play (modo mestre dos roteiros antigos): sem SalaConceitual no snapshot,
# a CameraMundo (diagonal alta) nunca liga. Estes roteiros jogam como jogador comum.
os.environ.setdefault("MOSHOKU_TESTE_JOGADOR", "1")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client  # noqa: E402

c = Client()
sid = json.loads(c.call("list_roblox_studios", {})["text"])["studios"][0]["id"]
PG = "LocalPlayer.PlayerGui."


def lua(code):
    return c.call("execute_luau", dict(studio_id=sid, datamodel_type="Client", code=code)).get("text", "")


def clique(caminho, espera=900):
    r = c.call("user_mouse_input", dict(studio_id=sid, datamodel_type="Client", actions=[
        {"action": "mouseButtonClick", "mouse_button": "left", "instance_path": caminho},
        {"action": "wait", "wait_time_ms": espera}]))
    if r.get("isError") or "erro" in r:
        print("falha no clique", caminho, r)


if "--fuga" in sys.argv:
    clique(PG + "EncontroAutonomo.Painel.EncerrarTurno", 700)
else:
    clique(PG + "ResultadoPartida.Fundo.Painel.Proxima", 700)
# O botão "Nova expedição" do painel RUN fica cortado no fim da lista; o MENU é o caminho confiável.
print(lua("local g=game.Players.LocalPlayer.PlayerGui.InicioJogo g.Enabled=true return 'menu ligado (nav visivel: '..tostring(g.Navegacao.Visible)..')'"))
clique(PG + "RunJogo.Painel.Conteudo.Fechar", 300)
clique(PG + "InicioJogo.Navegacao.MENU", 1200)
clique(PG + "InicioJogo.MenuInicial.Entrada.Conteudo.Conteudo.Pagina_Inicio.Expedicao", 3500)
clique(PG + "InicioJogo.MenuInicial.Entrada.Conteudo.Conteudo.Pagina_Modos.Modo_semArvore", 3000)
print(lua("""local pg=game.Players.LocalPlayer.PlayerGui local o={}
for _,d in pg.RelogioRun:GetDescendants() do if d:IsA('TextLabel') and d.Text~='' then table.insert(o,d.Text) end end
local r=game.Players.LocalPlayer.Character.HumanoidRootPart
return table.concat(o,' | ')..string.format(' pos %.0f,%.0f',r.Position.X,r.Position.Z)"""))
