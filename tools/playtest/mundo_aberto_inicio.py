"""Avança uma partida nova (Studio, place com persistência em memória) até a 1ª provação concluída.

Uso: python tools/playtest/mundo_aberto_inicio.py [--sem-play | --retomar (já ao lado do Ladino)]
Pré-requisitos (regras do Pedro): ServerStorage.PersonagemTestConfig e MesaTestConfig (Mode=memory) criadas em Edit;
nunca salvar nem publicar. Fluxo, com cliques reais por instance_path onde a interface permite:
  Play -> cena (Pular) -> criação rápida (Humano > Continuar > Começar) -> nasce no portão ->
  anda até o Ladino -> E -> Treinar -> aceita a provação -> bot de furtividade (e2e_ladino_furtivo.luau) ->
  equipa a arma inicial. Imprime o tempo (s) de cada marco. Depois o playtest continua à mão.
"""
import json
import os
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
# O cliente MCP liga MoshokuTesteMestre ao iniciar o Play (modo mestre dos roteiros antigos): sem SalaConceitual no snapshot,
# a CameraMundo (diagonal alta) nunca liga. Estes roteiros jogam como jogador comum.
os.environ.setdefault("MOSHOKU_TESTE_JOGADOR", "1")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client  # noqa: E402

RAIZ = Path(__file__).resolve().parents[2]
c = Client()
sid = json.loads(c.call("list_roblox_studios", {})["text"])["studios"][0]["id"]
t0 = time.time()


def marco(texto):
    print("[%6.1fs] %s" % (time.time() - t0, texto), flush=True)


def call(tool, **args):
    r = c.call(tool, dict(studio_id=sid, **args))
    if r.get("isError") or "erro" in r:
        raise RuntimeError(r)
    return r.get("text", "")


def lua(code, onde="Client"):
    return call("execute_luau", datamodel_type=onde, code=code)


def mouse(*acoes):
    return call("user_mouse_input", datamodel_type="Client", actions=list(acoes))


def clique(caminho, espera=800):
    return mouse({"action": "mouseButtonClick", "mouse_button": "left", "instance_path": caminho},
                 {"action": "wait", "wait_time_ms": espera})


CR = "LocalPlayer.PlayerGui.CriacaoRapida.Fundo.Moldura.Conteudo."

if "--retomar" not in sys.argv:
    if "--sem-play" not in sys.argv:
        call("start_stop_play", is_start=True)
    marco("Play iniciado")
    print(lua("""local pg=game.Players.LocalPlayer:WaitForChild('PlayerGui')
    local t=os.clock()
    while not (pg:FindFirstChild('CenaAbertura') and pg.CenaAbertura:FindFirstChild('Pular')) and os.clock()-t<60 do task.wait(0.25) end
    return 'cena visivel'"""))
    marco("cena de abertura na tela")
    if "--sem-play" not in sys.argv:
        clique("LocalPlayer.PlayerGui.CenaAbertura.Pular", 500)
    print(lua("""local pg=game.Players.LocalPlayer.PlayerGui
    local t=os.clock()
    while not (pg:FindFirstChild('CriacaoRapida') and pg.CriacaoRapida.Fundo.Moldura.Conteudo.Area.Raca.Racas:FindFirstChild('Raca_humano')) and os.clock()-t<30 do task.wait(0.25) end
    task.wait(0.8) return 'criacao visivel'"""))
    marco("cena pulada; criação rápida")
    clique(CR + "Area.Raca.Racas.Raca_humano")
    clique(CR + "Rodape.Avancar")
    clique(CR + "Rodape.Avancar", 4000)
    marco("personagem criado; nasce no portão (objetivo: falar com um mestre)")
    call("character_navigation", datamodel_type="Client", x=65, y=3, z=-221, speed_multiplier=1)
    print(lua("""local r=game.Players.LocalPlayer.Character.HumanoidRootPart
local t=os.clock()
while (Vector3.new(r.Position.X,0,r.Position.Z)-Vector3.new(65,0,-221)).Magnitude>6 and os.clock()-t<60 do task.wait(0.5) end
return 'chegou em '..string.format('%.0f',os.clock()-t)..' s'"""))
    marco("chegou ao Ladino")
for tentativa in range(4):
    call("user_keyboard_input", datamodel_type="Client", actions=[
        {"action": "keyDown", "key_code": "E"}, {"action": "wait", "wait_time_ms": 1500},
        {"action": "keyUp", "key_code": "E"}, {"action": "wait", "wait_time_ms": 1200}])
    r = lua("""local c=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ConversaNpc')
local d=c and c:FindFirstChild('DialogoNpc')
if not d then return 'sem' end
for _,b in d.Conteudo:GetChildren() do if b.Name=='Botao' then local r=b:FindFirstChild('Rotulo') b.Name='B_'..((r and r.Text or '?'):gsub('[^%w]','')) end end
return 'ok'""")
    if r == "ok":
        break
clique("LocalPlayer.PlayerGui.ConversaNpc.DialogoNpc.Conteudo.B_Treinar", 1500)
marco("oferta da provação na tela")
print(lua("""local r=game.ReplicatedStorage:FindFirstChild('TreinadorJogo')
local H=game:GetService('HttpService')
local npc for _,m in workspace.Vila.TreinadoresRun:GetChildren() do if m.Name=='Ladino' then npc=m end end
r:FireServer({acao='aceitar',npcId=npc:GetAttribute('TreinadorId'),requestId=H:GenerateGUID(false)})
task.wait(1.5) return 'aceita'"""))
marco("provação aceita")
call("character_navigation", datamodel_type="Client", x=64, y=3, z=-237, speed_multiplier=1)
print(lua("""local r=game.Players.LocalPlayer.Character.HumanoidRootPart
local t=os.clock()
while (Vector3.new(r.Position.X,0,r.Position.Z)-Vector3.new(64,0,-237)).Magnitude>4 and os.clock()-t<40 do task.wait(0.5) end
return 'no patio em '..string.format('%.0f',os.clock()-t)..' s'"""))
call("user_keyboard_input", datamodel_type="Client", actions=[{"action": "keyPress", "key_code": "C"}, {"action": "wait", "wait_time_ms": 500}])
codigo = (RAIZ / "tools/playtest/e2e_ladino_furtivo.luau").read_text(encoding="utf-8")
print(lua(codigo))
marco("bot de furtividade em andamento")
for _ in range(40):
    time.sleep(3)
    estado = lua("local L=_G.LADINO return L.fase..' fim='..tostring(L.fim)")
    if "fim=true" in estado:
        break
marco("provação do Ladino: " + estado)
print(lua("""local mesa=game.ReplicatedStorage.Mesa
mesa:FireServer('personagemPessoalEquiparArma',{sourceLocalId='kit-inicial-01',requestId='arma-'..tostring(os.clock())})
task.wait(2) return 'arma enviada'"""))
marco("pronto: vila, ficha com árvore, arma equipada")
