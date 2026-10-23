"""Teste de cliques reais no painel (mouse simulado pelo MCP do Studio).

Uso: python tools/playtest/ui_cliques.py   (Studio aberto, modo Edit)

Fluxo: Play → liga a Visão da mesa pelo botão → d20 + Rolar → clica numa casa
do tabuleiro → cria ficha pelo formulário do mestre → confere pelo texto do
painel e do registro → Stop. Os resultados vão para a saída.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from studio_mcp import Client  # noqa: E402

LOCATE = """
local GuiService = game:GetService("GuiService")
local gui = game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("MesaPanel", 10)
local inset = GuiService:GetGuiInset()
local camera = workspace.CurrentCamera
local function shown(object)
	while object and object ~= gui do
		if object:IsA("GuiObject") and not object.Visible then return false end
		object = object.Parent
	end
	return true
end
local out = { inset = inset.Y, buttons = {}, texts = {}, viewport = { camera.ViewportSize.X, camera.ViewportSize.Y } }
-- Só conta o que está dentro da área visível de todas as ScrollingFrames acima.
local function clipped(object, point)
	local parent = object.Parent
	while parent and parent ~= gui do
		if parent:IsA("ScrollingFrame") then
			local a, s = parent.AbsolutePosition, parent.AbsoluteSize
			if point.X < a.X or point.Y < a.Y or point.X > a.X + s.X or point.Y > a.Y + s.Y then
				return true
			end
		end
		parent = parent.Parent
	end
	return false
end
for _, object in gui:GetDescendants() do
	if object:IsA("TextButton") and shown(object) and object.Text ~= "" then
		local center = object.AbsolutePosition + object.AbsoluteSize / 2
		if center.Y >= 0 and center.Y <= camera.ViewportSize.Y - inset.Y and not clipped(object, center) then
			out.buttons[object.Text] = { math.round(center.X), math.round(center.Y) }
		end
	elseif object:IsA("TextLabel") and shown(object) then
		table.insert(out.texts, object.Text)
	end
end
return game:GetService("HttpService"):JSONEncode(out)
"""

# Rola o painel (como a roda do mouse faria) até o botão ficar no meio da área visível.
REVEAL = """
local gui = game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("MesaPanel", 10)
for _, object in gui:GetDescendants() do
	if object:IsA("TextButton") and object.Text == %s then
		local frame = object:FindFirstAncestorWhichIsA("ScrollingFrame")
		while frame do
			local offset = object.AbsolutePosition.Y - frame.AbsolutePosition.Y - frame.AbsoluteSize.Y / 2
			frame.CanvasPosition = Vector2.new(0, math.max(0, frame.CanvasPosition.Y + offset))
			frame = frame:FindFirstAncestorWhichIsA("ScrollingFrame")
		end
		task.wait(0.1)
		return "ok"
	end
end
return "ausente"
"""

BOARD_CELL = """
local Protocol = require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)
local camera = workspace.CurrentCamera
local point = camera:WorldToViewportPoint(Protocol.cellCenter(%d, %d))
return string.format("%%d,%%d", math.round(point.X), math.round(point.Y))
"""


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    client = Client()
    report = []

    def check(name, ok, detail=""):
        report.append(("OK    " if ok else "FALHA ") + name + ("" if ok or not detail else " — " + str(detail)))

    try:
        studio = client.studio_id()

        def call(tool, **args):
            args["studio_id"] = studio
            return client.call(tool, args)

        def luau(code):
            return call("execute_luau", datamodel_type="Client", code=code)["text"]

        def ui():
            return json.loads(luau(LOCATE))

        def click(x, y):
            call("user_mouse_input", datamodel_type="Client", actions=[
                {"action": "moveTo", "x": x, "y": y},
                {"action": "wait", "wait_time_ms": 100},
                {"action": "mouseButtonClick", "mouse_button": "left"},
                {"action": "wait", "wait_time_ms": 500},
            ])

        call("start_stop_play", is_start=True)
        time.sleep(8)
        state = ui()
        inset = state["inset"]

        # 1. Descobre a convenção de coordenadas: sem e com a barra superior.
        bx, by = state["buttons"]["Visão da mesa (M)"]
        offset = None
        for candidate in (0, inset):
            click(bx, by + candidate)
            if "Voltar ao avatar (M)" in ui()["buttons"]:
                offset = candidate
                break
        check("clique liga a Visão da mesa", offset is not None)
        if offset is None:
            return
        report.append("INFO  coordenadas do clique: posição da interface + %d px" % offset)

        def press(text):
            buttons = ui()["buttons"]
            if text not in buttons:
                luau(REVEAL % json.dumps(text, ensure_ascii=False))
                buttons = ui()["buttons"]
            if text not in buttons:
                return False
            x, y = buttons[text]
            click(x, y + offset)
            return True

        # 2. Dados pelo painel (aba Mesa).
        press("Mesa")
        check("botão d20 existe", press("d20"))
        check("botão Rolar existe", press("Rolar"))
        time.sleep(0.6)
        texts = ui()["texts"]
        check("rolagem aparece no registro", any("rolou 1d20" in t for t in texts), [t for t in texts if "rolou" in t][-1:])

        # 3. Seleciona uma casa clicando no tabuleiro 3D e cria uma ficha pelo formulário.
        cx, cy = map(int, luau(BOARD_CELL % (8, 8)).split(","))
        # WorldToViewportPoint conta a barra superior; o clique simulado não.
        cx, cy = cx, cy - inset
        click(cx, cy)
        texts = ui()["texts"]
        check("clique no tabuleiro seleciona a casa", any("Casa selecionada: 8, 8" in t for t in texts),
              [t for t in texts if "Casa" in t][:2])
        check("aba Mestre abre", press("Mestre"))
        check("formulário: Nova ficha", press("Nova ficha"))
        check("formulário: Enviar ficha ao servidor", press("Enviar ficha ao servidor"))
        time.sleep(0.8)
        press("Mesa")
        texts = ui()["texts"]
        check("ficha criada aparece no registro", any("Nova ficha entrou na mesa" in t for t in texts),
              [t for t in texts if "mesa" in t][-2:])

        # 4. Seleciona a ficha criada clicando nela e ajusta PV pelo botão.
        click(cx, cy)
        check("aba Ficha abre", press("Ficha"))
        check("ajuste PV -5 pelo botão", press("PV -5"))
        time.sleep(0.6)
        texts = ui()["texts"]
        check("PV muda na ficha selecionada", any("PV 5/10" in t for t in texts), [t for t in texts if "PV" in t][:2])
        call("screen_capture", capture_id="UI_Final")
    finally:
        try:
            client.call("start_stop_play", {"studio_id": client.studio_id(), "is_start": False})
        except Exception:  # noqa: BLE001 - parar o Play é melhor esforço
            pass
        client.close()
        failures = sum(1 for line in report if line.startswith("FALHA"))
        print("RESULTADO %d falha(s)" % failures)
        print("\n".join(report))


if __name__ == "__main__":
    main()
