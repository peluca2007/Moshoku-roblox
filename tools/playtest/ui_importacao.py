"""Fecha T12 com entrada de texto e cliques MCP reais no painel.

Uso: python tools/playtest/ui_importacao.py
Exige MoshokuRPGMesa em Edit. Inicia seu próprio Play e o encerra no finally.
Não salva campanha, não sincroniza scripts e não publica. Consulta o snapshot
pelo MesaDebug do servidor; ações de importação/iniciativa passam pela UI.
Rolagem do painel é ajustada por código, como em ui_cliques.py.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from studio_mcp import Client
from ui_cliques import LOCATE, REVEAL, BOARD_CELL

SNAPSHOT = """
local player = game.Players:GetPlayers()[1]
local s = game.ServerStorage.MesaDebug:Invoke("snapshotOf", player)
local tokens = {}
for _, t in s.tokens do
 table.insert(tokens, {id=t.id, name=t.name, x=t.x, z=t.z, pv=t.pv,
  pvMax=t.pvMax, mana=t.mana, manaMax=t.manaMax, ownerUserId=t.ownerUserId,
  hidden=t.hidden, sheet=t.sheet})
end
return game:GetService("HttpService"):JSONEncode({tokens=tokens, combat=s.combat})
"""


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    client = Client()
    started = False
    report = []
    failure = None
    studio = None

    def check(name, condition):
        if not condition:
            raise AssertionError(name)
        report.append("OK    " + name)
        print(report[-1], flush=True)

    try:
        client.studio_id()  # Aguarda o anúncio das sessões pelo proxy.
        studios = json.loads(client.call("list_roblox_studios", {})["text"])["studios"]
        matches = [s for s in studios if "MoshokuRPGMesa" in s["name"]]
        if len(matches) != 1:
            raise RuntimeError("Esperava uma única sessão MoshokuRPGMesa.")
        studio = matches[0]["id"]

        def call(tool, **args):
            result = client.call(tool, {"studio_id": studio, **args}, timeout=45)
            if result.get("isError") or "erro" in result:
                raise RuntimeError(f"{tool}: {result}")
            return result["text"]

        def luau(code, model="Client"):
            return call("execute_luau", datamodel_type=model, code=code)

        def snapshot():
            return json.loads(luau(SNAPSHOT, "Server"))

        def ui():
            return json.loads(luau(LOCATE))

        def click(x, y):
            call("user_mouse_input", datamodel_type="Client", actions=[
                {"action": "moveTo", "x": x, "y": y},
                {"action": "mouseButtonClick", "mouse_button": "left"},
                {"action": "wait", "wait_time_ms": 500},
            ])

        if "Current Studio Mode: Edit" not in call("get_studio_state"):
            raise RuntimeError("Studio já está em Play; a sessão existente foi preservada.")
        # Se a resposta ao Play se perder, o finally ainda tenta encerrá-lo.
        started = True
        call("start_stop_play", is_start=True)
        time.sleep(8)
        check("sessão começa sem fichas", not snapshot()["tokens"])
        layout = ui()
        ready_until = time.monotonic() + 10
        while "Visão da mesa (M)" not in layout["buttons"] and time.monotonic() < ready_until:
            time.sleep(.25)
            layout = ui()
        inset = layout["inset"]
        bx, by = layout["buttons"]["Visão da mesa (M)"]
        offset = None
        for candidate in (0, inset):
            click(bx, by + candidate)
            if "Voltar ao avatar (M)" in ui()["buttons"]:
                offset = candidate
                break
        check("botão abre visão da mesa", offset is not None)

        def press(text):
            buttons = ui()["buttons"]
            if text not in buttons:
                luau(REVEAL % json.dumps(text, ensure_ascii=False))
                buttons = ui()["buttons"]
            if text not in buttons:
                raise AssertionError("Botão não acessível: " + text)
            x, y = buttons[text]
            click(x, y + offset)

        def cell(x, z):
            px, py = map(int, luau(BOARD_CELL % (x, z)).split(","))
            click(px, py - inset + offset)

        def fill(value):
            # Localiza e revela o campo; o texto entra pelo teclado simulado.
            pos = json.loads(luau('''
local gui = game.Players.LocalPlayer.PlayerGui.MesaPanel
local box = gui:FindFirstChild("FichaImportCode", true)
assert(box, "campo de importação ausente")
local frame = box:FindFirstAncestorWhichIsA("ScrollingFrame")
while frame do
 local offset = box.AbsolutePosition.Y - frame.AbsolutePosition.Y - frame.AbsoluteSize.Y / 2
 frame.CanvasPosition = Vector2.new(0, math.max(0, frame.CanvasPosition.Y + offset))
 frame = frame:FindFirstAncestorWhichIsA("ScrollingFrame")
end
task.wait(.2)
local p=box.AbsolutePosition + box.AbsoluteSize/2
return game:GetService("HttpService"):JSONEncode({x=math.round(p.X), y=math.round(p.Y)})
'''))
            click(pos["x"], pos["y"] + offset)
            call("user_keyboard_input", datamodel_type="Client", actions=[
                {"action": "keyDown", "key_code": "LeftControl"},
                {"action": "keyPress", "key_code": "A"},
                {"action": "keyUp", "key_code": "LeftControl"},
                {"action": "textInput", "text_inputs": value},
            ])
            actual = luau('return game.Players.LocalPlayer.PlayerGui.MesaPanel:FindFirstChild("FichaImportCode", true).Text')
            check("campo recebe o código pelo teclado", actual == value)

        data = {"mesa": 1, "nome": "Aria UI", "pv": 30, "pvMax": 34,
                "mana": 12, "manaMax": 16,
                "atributos": {"forca": 1, "agilidade": 3, "vigor": 2, "intelecto": 0, "espirito": 4},
                "ca": 13, "deslocamento": 4.5, "iniciativa": -50, "vantagemIniciativa": False}
        cell(8, 8)
        fill(json.dumps(data, ensure_ascii=False))
        press("Importar na casa selecionada")
        current = snapshot()
        check("importar pelo botão cria ficha na casa escolhida",
              len(current["tokens"]) == 1 and current["tokens"][0]["x"] == 8 and current["tokens"][0]["z"] == 8)
        first = current["tokens"][0]
        check("importação mantém PV, mana e dados da ficha",
              first["pv"] == 30 and first["mana"] == 12 and first["sheet"]["deslocamento"] == 4.5)
        cell(8, 8)
        labels = ui()["texts"]
        check("seleção exibe atributos, CA e deslocamento",
              any("CA 13" in t and "4,5 m" in t and "FOR +1" in t for t in labels))

        data["pv"], data["pvMax"], data["nome"] = 17, 40, "Aria Atualizada"
        fill(json.dumps(data, ensure_ascii=False))
        press("Atualizar ficha selecionada")
        current = snapshot()
        updated = current["tokens"][0]
        check("atualizar pelo botão mantém identidade, casa e dono",
              len(current["tokens"]) == 1 and updated["id"] == first["id"]
              and updated["x"] == 8 and updated["z"] == 8
              and updated["ownerUserId"] == first["ownerUserId"] and updated["hidden"] == first["hidden"])
        check("atualização aplica novos PV e máximo", updated["pv"] == 17 and updated["pvMax"] == 40)

        fill("{invalido")
        press("Atualizar ficha selecionada")
        check("código inválido não altera a ficha", snapshot()["tokens"] == current["tokens"])
        check("código inválido informa erro na interface", any("JSON" in t for t in ui()["texts"]))

        # Desmarca com clique direito para não mover a ficha ao escolher a segunda casa.
        # O clique direito precisa de posição na mesma chamada MCP.
        px, py = map(int, luau(BOARD_CELL % (8, 8)).split(","))
        call("user_mouse_input", datamodel_type="Client", actions=[
            {"action": "moveTo", "x": px, "y": py - inset + offset},
            {"action": "mouseButtonClick", "mouse_button": "right"},
        ])
        cell(10, 8)
        data["nome"], data["iniciativa"], data["vantagemIniciativa"] = "Bruno UI", 50, True
        fill(json.dumps(data, ensure_ascii=False))
        press("Importar na casa selecionada")
        current = snapshot()
        check("segunda importação cria outra ficha", len(current["tokens"]) == 2)
        second = next(t for t in current["tokens"] if t["id"] != first["id"])
        press("Rolar iniciativa")
        combat = snapshot()["combat"]
        check("iniciativa pelo botão inclui as duas fichas e usa os bônus",
              combat["active"] and combat["order"] == [second["id"], first["id"]])
        check("vantagem de iniciativa aparece no registro", any("vantagem" in t for t in ui()["texts"]))
        press("Encerrar combate")
        check("botão encerra combate", not snapshot()["combat"]["active"])
        capture = call("screen_capture", capture_id="Importacao_UI_Final")
        print(capture, flush=True)
        print("Console:", call("get_console_output"), flush=True)
    except Exception as exc:
        failure = str(exc)
        print("FALHA", failure, flush=True)
    finally:
        if started and studio:
            try:
                result = client.call("start_stop_play", {"studio_id": studio, "is_start": False}, timeout=45)
                if result.get("isError") or "erro" in result:
                    raise RuntimeError(str(result))
            except Exception as exc:
                failure = failure or str(exc)
                print("FALHA ao encerrar Play:", exc, flush=True)
        client.close()
    print(f"RESULTADO: {len(report)} verificações aprovadas, {int(failure is not None)} falha(s)", flush=True)
    return 1 if failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
