"""T28: importa, aprova e consulta a ficha por cliques MCP reais.
Exige MoshokuRPGMesa em Edit. Rolagem posicionada por código.
Não sincroniza, publica ou salva campanha; encerra o Play no finally.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from studio_mcp import Client
from studio_sync import long_string
from ui_cliques import LOCATE, REVEAL, BOARD_CELL

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SNAPSHOT = """
local p=game.Players:GetPlayers()[1]
local s=game.ServerStorage.MesaDebug:Invoke('snapshotOf',p)
local tokens={}
for _,t in s.tokens do table.insert(tokens,{id=t.id,name=t.name,pv=t.pv,mana=t.mana,x=t.x,z=t.z}) end
return game.HttpService:JSONEncode({tokens=tokens,proposals=s.fichaPropostas})
"""

def main():
    sys.stdout.reconfigure(encoding="utf-8")
    client, started, count = Client(), False, 0
    studio = None
    try:
        client.studio_id()
        studios = json.loads(client.call("list_roblox_studios", {})["text"])["studios"]
        matches = [s for s in studios if "MoshokuRPGMesa" in s["name"]]
        assert len(matches) == 1, "Esperava uma única sessão MoshokuRPGMesa"
        studio = matches[0]["id"]

        def call(tool, **args):
            result = client.call(tool, {"studio_id": studio, **args}, timeout=50)
            assert not result.get("isError") and "erro" not in result, result
            return result["text"]

        def luau(code, model="Client"):
            return call("execute_luau", datamodel_type=model, code=code)

        def check(name, condition):
            nonlocal count
            assert condition, name
            count += 1
            print("OK " + name, flush=True)

        def ui():
            return json.loads(luau(LOCATE))

        def snapshot():
            return json.loads(luau(SNAPSHOT, "Server"))

        def click(x, y):
            call("user_mouse_input", datamodel_type="Client", actions=[
                {"action": "moveTo", "x": x, "y": y},
                {"action": "mouseButtonClick", "mouse_button": "left"},
                {"action": "wait", "wait_time_ms": 500},
            ])

        assert "Current Studio Mode: Edit" in call("get_studio_state"), "Play existente preservado"
        started = True
        call("start_stop_play", is_start=True)
        time.sleep(8)
        check("mesa inicia vazia", len(snapshot()["tokens"]) == 0)
        layout = ui()
        deadline = time.monotonic() + 10
        while "Visão da mesa (M)" not in layout["buttons"] and time.monotonic() < deadline:
            time.sleep(.25)
            layout = ui()
        bx, by = layout["buttons"]["Visão da mesa (M)"]
        inset, offset = layout["inset"], None
        for candidate in (0, inset):
            click(bx, by + candidate)
            if "Voltar ao avatar (M)" in ui()["buttons"]:
                offset = candidate
                break
        check("visão da mesa abre pelo botão", offset is not None)

        def press(title):
            buttons = ui()["buttons"]
            if title not in buttons:
                luau(REVEAL % json.dumps(title, ensure_ascii=False))
                buttons = ui()["buttons"]
            assert title in buttons, "Botão inacessível: " + title
            x, y = buttons[title]
            click(x, y + offset)

        def cell():
            x, y = map(int, luau(BOARD_CELL % (8, 8)).split(","))
            click(x, y - inset + offset)

        cell()
        press("Mestre")
        position = json.loads(luau("""
local box=game.Players.LocalPlayer.PlayerGui.MesaPanel:FindFirstChild('FichaImportCode',true)
local frame=box:FindFirstAncestorWhichIsA('ScrollingFrame')
while frame do
 frame.CanvasPosition=Vector2.new(0,math.max(0,frame.CanvasPosition.Y+box.AbsolutePosition.Y-frame.AbsolutePosition.Y-frame.AbsoluteSize.Y/2))
 frame=frame:FindFirstAncestorWhichIsA('ScrollingFrame')
end
task.wait(.2)
local p=box.AbsolutePosition+box.AbsoluteSize/2
return game.HttpService:JSONEncode({math.round(p.X),math.round(p.Y)})
"""))
        click(position[0], position[1] + offset)
        with open(os.path.join(ROOT, "tools", "fixtures", "ficha-v2-aria.json"), encoding="utf-8") as handle:
            fixture = handle.read().strip()
        call("user_keyboard_input", datamodel_type="Client", actions=[
            {"action": "keyDown", "key_code": "LeftControl"},
            {"action": "keyPress", "key_code": "A"},
            {"action": "keyUp", "key_code": "LeftControl"},
            {"action": "textInput", "text_inputs": fixture},
        ])
        check("JSON completo entra pelo teclado", luau("return game.Players.LocalPlayer.PlayerGui.MesaPanel:FindFirstChild('FichaImportCode',true).Text") == fixture)
        press("Importar na casa selecionada")
        deadline = time.monotonic() + 15
        current = snapshot()
        while not current["proposals"] and time.monotonic() < deadline:
            time.sleep(.3)
            current = snapshot()
        check("proposta chega sem criar ficha", len(current["proposals"]) == 1 and not current["tokens"])
        press("Aprovar")
        current = snapshot()
        check("aprovar cria Aria na casa selecionada", len(current["tokens"]) == 1 and current["tokens"][0]["name"] == "Aria" and current["tokens"][0]["x"] == 8)
        cell()
        press("Ficha")
        press("Abrir ficha completa")
        texts = ui()["texts"]
        check("ficha completa mostra nome e recursos", "Aria" in texts and any("22 / 22" in s for s in texts))
        for title, expected in [
            ("Perícias", "Atletismo"),
            ("Habilidades e Talentos", "Bola de Água"),
            ("Inventário", "Cajado de salgueiro"),
        ]:
            press("▸ " + title)
            check(title + " abre por clique e mostra conteúdo", any(expected.lower() in s.lower() for s in ui()["texts"]))
        check("seções têm alvos de pelo menos 44 px", luau("""
local gui=game.Players.LocalPlayer.PlayerGui.MesaPanel
local n=0
for _,v in gui:GetDescendants() do
 if v:IsA('TextButton') and v.Name:match('^FichaAbrir_') then
  assert(v.AbsoluteSize.Y>=44,v.Name);n+=1
 end
end
return tostring(n)
""") == "8")
        press("Voltar aos controles")
        press("PV -5")
        check("PV muda pelos controles", snapshot()["tokens"][0]["pv"] == 17)
        press("Abrir ficha completa")
        check("detalhe reflete PV atualizado", any("17 / 22" in s for s in ui()["texts"]))
        press("Mesa")
        check("outra aba não fica coberta pelo detalhe", "Rolar" in ui()["buttons"] and "Voltar aos controles" not in ui()["buttons"])
        press("Ficha")
        check("voltar à aba preserva a ficha aberta", "Voltar aos controles" in ui()["buttons"])
        with open(os.path.join(ROOT, "tools", "playtest", "ficha_v2_revisao.luau"), encoding="utf-8") as handle:
            review = handle.read().replace("HttpService:JSONDecode(FIXTURE_JSON)", "HttpService:JSONDecode(" + long_string(fixture) + ")")
        result = luau(review, "Server")
        print(result, flush=True)
        check("regressões de filtro, sessão e privacidade", "RESUMO: 0 falha(s)" in result)
        print(call("screen_capture", capture_id="T28FichaCompleta"), flush=True)
        print(call("get_console_output"), flush=True)
        print(f"RESULTADO: {count} verificações aprovadas", flush=True)
    finally:
        if started:
            print(client.call("start_stop_play", {"studio_id": studio, "is_start": False}), flush=True)
        client.close()

if __name__ == "__main__":
    main()
