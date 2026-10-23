"""Diagnóstico curto de M: monitor persistente versus execute_luau; fonte real.
Cria somente fixture temporária em Edit e a remove em finally. Não sincroniza src.
"""
import json, os, sys, time, uuid
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE.parent))
os.environ["MOSHOKU_TESTE_JOGADOR"] = "1"
from studio_mcp import Client
from studio_sync import collect, long_string

c = Client()
sid = None
started = fixture = False
run_id = str(uuid.uuid4())
checks = []

def call(tool, **args):
    r = c.call(tool, dict(studio_id=sid, **args), timeout=60)
    if r.get("isError") or "erro" in r:
        raise RuntimeError(r)
    return r["text"]

def lua(code, dm="Client"):
    return call("execute_luau", datamodel_type=dm, code=code)

def read():
    return json.loads(lua('''local f=game.Players.LocalPlayer.PlayerScripts.G18Monitor;local h=game.HttpService;local r=h:JSONDecode(f:GetAttribute("Estado"));r.events=h:JSONDecode(f:GetAttribute("Eventos"));r.changes=h:JSONDecode(f:GetAttribute("Trocas"));r.transient=shared.G18Input.events;return h:JSONEncode(r)'''))

def check(name, value):
    checks.append(bool(value))
    print(("OK " if value else "FALHA ") + name, flush=True)

def press(key, phase):
    lua('game.Players.LocalPlayer.PlayerScripts.G18Monitor:SetAttribute("Fase",' + json.dumps(phase) + ');return "fase"')
    print(call("user_keyboard_input", datamodel_type="Client", actions=[
        dict(action="keyDown", key_code=key),
        dict(action="wait", wait_time_ms=250),
        dict(action="keyUp", key_code=key)]), flush=True)
    time.sleep(.4)
    result = read()
    print(phase, json.dumps(result, ensure_ascii=False), flush=True)
    return result

def phase_events(result, phase):
    return [e for e in result["events"] if e.get("phase") == phase and e["key"] == "M"]

try:
    studios = json.loads(c.call("list_roblox_studios", {})["text"])["studios"]
    sid = next(s["id"] for s in studios if "MoshokuRPGMesa" in s["name"])
    assert "Mode: Edit" in call("get_studio_state"), "Preservado Play externo"
    # Verifica todas as fontes sem reescrever mudanças alheias.
    items = collect()
    for offset in range(0, len(items), 12):
        code = ["local different={}"]
        for parents, name, cls, path in items[offset:offset+12]:
            target = "game" + "".join("[" + json.dumps(p) + "]" for p in parents + [name])
            source = Path(path).read_text(encoding="utf-8").replace("\r\n", "\n")
            code.append('if ' + target + '.Source:gsub("\\r\\n","\\n")~=' + long_string(source) + ' then table.insert(different,' + json.dumps(name) + ') end')
        code.append('return table.concat(different,",")')
        assert lua("\n".join(code), "Edit").strip() == "", "Fonte Studio diverge de src"
    print("Fonte conferida sem alteracao", len(items), flush=True)
    assert "Mode: Edit" in call("get_studio_state"), "Preservado Play externo"
    assert lua('return tostring(game.StarterPlayer.StarterPlayerScripts:FindFirstChild("G18Monitor")==nil and workspace:GetAttribute("MoshokuTesteMestre")==nil)', "Edit").strip() == "true"
    source = (BASE / "g18_monitor.luau").read_text(encoding="utf-8")
    fixture = True
    lua('local s=Instance.new("LocalScript");s.Name="G18Monitor";s:SetAttribute("Execucao",' + json.dumps(run_id) + ');s.Source=' + long_string(source) + ';s.Parent=game.StarterPlayer.StarterPlayerScripts;return "fixture"', "Edit")
    assert "Mode: Edit" in call("get_studio_state"), "Preservado Play externo"
    # Marca tentativa antes da chamada: uma resposta perdida pode ter iniciado Play.
    started = True
    print(call("start_stop_play", is_start=True), flush=True)
    print(lua('local f=game.Players.LocalPlayer.PlayerScripts:WaitForChild("G18Monitor",20);assert(f,"monitor ausente");local deadline=os.clock()+20;local r;repeat task.wait(.2);local v=f:GetAttribute("Estado");r=v and game.HttpService:JSONDecode(v) until (r and r.snapshot and r.avatar and r.seated and f:GetAttribute("Pronto")) or os.clock()>deadline;assert(r and r.snapshot and r.avatar and r.seated and f:GetAttribute("Pronto"),"snapshot/monitor/avatar/assento nao iniciou em20s");return "estado real e monitor prontos"'), flush=True)
    print(lua('''local p=game.Players.LocalPlayer;shared.G18Input={events={}};shared.G18Input.connection=game.UserInputService.InputBegan:Connect(function(i,processed) if i.UserInputType==Enum.UserInputType.Keyboard then table.insert(shared.G18Input.events,{key=i.KeyCode.Name,processed=processed}) end end);local r=game.HttpService:JSONDecode(p.PlayerScripts.G18Monitor:GetAttribute("Estado"));assert(r.master==r.me,"mestre local ausente");assert(r.seated,"assento da sala ausente");r.snapshotViaExecute=require(p.PlayerScripts.Client.MesaState).snapshot()~=nil;return game.HttpService:JSONEncode(r)'''), flush=True)
    initial = read()["table"]
    result = press("M", "lobby")
    e = phase_events(result, "lobby")
    check("M entregue no lobby sem alternar tabuleiro", len(e) == 1 and not e[0]["processed"] and result["table"] == initial)
    # Pré-requisitos reais, cada pedido continua validado pelo servidor.
    print(lua('local r=game.ReplicatedStorage.Mesa;r:FireServer("escolherPersonagem",{id="mago-de-fogo",arma=require(game.ReplicatedStorage.Shared.PersonagensProntos)[1].armas[1].id});task.wait(.4);r:FireServer("salaConfigurar",{modo="treino",nivel=1,monstros=false});task.wait(.4);r:FireServer("salaPronto",{ativo=true});task.wait(.4);r:FireServer("salaIniciar",{});return "inicio solicitado"'), flush=True)
    time.sleep(4)
    result = read()
    check("partida real iniciou", result["combat"])
    assert result["combat"], "Precondicao de partida falhou"
    initial = result["table"]
    result = press("M", "partida1")
    e = phase_events(result, "partida1")
    check("M entregue alterna partida", len(e) == 1 and not e[0]["processed"] and result["table"] != initial)
    result = press("M", "partida2")
    e = phase_events(result, "partida2")
    check("M entregue restaura partida", len(e) == 1 and not e[0]["processed"] and result["table"] == initial)
    lua('game.Players.LocalPlayer.PlayerScripts.G18Monitor:SetAttribute("CriarTexto",true);return "campo solicitado no LocalScript"')
    time.sleep(.3)
    result = press("M", "texto")
    e = phase_events(result, "texto")
    check("M entregue com foco nao alterna partida", len(e) == 1 and e[0]["focused"] and result["focused"] and result["table"] == initial)
    print("Texto apos keyDown M:", repr(result["text"]), flush=True)
    # Inserção textual é medida separadamente da guarda de InputBegan.
    before_text = result["text"]
    print(call("user_keyboard_input", datamodel_type="Client", actions=[dict(action="textInput", instance_path="LocalPlayer.PlayerGui.G18EntradaTexto.TextBox", text_inputs="x")]), flush=True)
    time.sleep(.4)
    result = read()
    print("textInput", json.dumps(result, ensure_ascii=False), flush=True)
    check("textInput insere marcador novo", "x" not in before_text.lower() and result["text"].lower().count("x") == 1)
    check("monitores recebem mesmas teclas", [e["key"] for e in result["events"]] == [e["key"] for e in result["transient"]] and len(result["events"]) >= 4)
    print(call("get_console_output"), flush=True)
    print("FINAL", sum(not v for v in checks), "falhas /", len(checks), "checks", flush=True)
    assert all(checks)
finally:
    try:
        try:
            if started and "Mode: Edit" not in call("get_studio_state"):
                print(call("start_stop_play", is_start=False), flush=True)
        finally:
            if fixture and "Mode: Edit" in call("get_studio_state"):
                print(lua('local f=game.StarterPlayer.StarterPlayerScripts:FindFirstChild("G18Monitor");if f and f:GetAttribute("Execucao")=='+json.dumps(run_id)+' then f:Destroy() end;return "limpeza da fixture propria"', "Edit"), flush=True)
    finally:
        c.close()
