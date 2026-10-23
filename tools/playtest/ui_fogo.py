"""Cliques reais na barra de ações da fatia A1 (Árvore do Fogo).

Uso: python tools/playtest/ui_fogo.py   (Studio aberto, modo Edit)

Fluxo: Play → mesa com Ignis (pronto) e um Lobo Cinzento, combate com o Ignis
primeiro → a barra aparece com as 6 cartas → clica na carta Bola de Fogo (a
mira liga a Visão da mesa) → clica no lobo no tabuleiro → confere no registro →
Clarão com dois cliques na carta → Encerrar turno esconde a barra → Stop.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from studio_mcp import Client  # noqa: E402

PREPARAR = """
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local me = game.Players.LocalPlayer.UserId
local snap
local c = remote.OnClientEvent:Connect(function(k, d) if k == "snapshot" then snap = d end end)
remote:FireServer("combatEnd"); task.wait(0.3)
remote:FireServer("tableClear"); task.wait(0.3)
remote:FireServer("criarPremontado", { id = "mago-de-fogo", ownerUserId = me, x = 8, z = 10 }); task.wait(0.4)
remote:FireServer("criarCriatura", { creatureId = "creature/lobo-cinzento", x = 12, z = 10 }); task.wait(0.4)
local ignis, lobo
for _, t in snap.tokens do
	if string.find(t.name, "Ignis") then ignis = t.id elseif string.find(t.name, "Lobo") then lobo = t.id end
end
remote:FireServer("combatStart", { entries = { { id = ignis, initiative = 20 }, { id = lobo, initiative = 5 } } }); task.wait(0.6)
c:Disconnect()
return lobo
"""

BARRA = """
local GuiService = game:GetService("GuiService")
local gui = game.Players.LocalPlayer.PlayerGui:WaitForChild("AcoesDoTurno", 10)
local barra = gui:FindFirstChild("Barra")
local out = { visivel = barra.Visible, inset = GuiService:GetGuiInset().Y, cartas = {}, botoes = {}, dica = "", acoes = "" }
for _, o in barra:GetDescendants() do
	if o:IsA("TextButton") and o.Name:sub(1, 6) == "Carta_" then
		local c = o.AbsolutePosition + o.AbsoluteSize / 2
		out.cartas[o.Name:sub(7)] = { math.round(c.X), math.round(c.Y) }
	elseif o:IsA("TextButton") and o.Visible then
		local c = o.AbsolutePosition + o.AbsoluteSize / 2
		out.botoes[o.Name] = { math.round(c.X), math.round(c.Y) }
	elseif o.Name == "Dica" then
		out.dica = o.Text
	elseif o.Name == "Acoes" then
		out.acoes = o.Text
	end
end
return game:GetService("HttpService"):JSONEncode(out)
"""

LOBO_NA_TELA = """
local mini = workspace:WaitForChild("MesaFichasLocais"):FindFirstChild(%s)
if not mini then return "nil" end
local p = workspace.CurrentCamera:WorldToViewportPoint(mini:GetPivot().Position + Vector3.new(0, 1, 0))
return math.round(p.X) .. "," .. math.round(p.Y)
"""

REGISTRO = """
local gui = game.Players.LocalPlayer.PlayerGui:WaitForChild("MesaPanel")
local t = {}
for _, o in gui:GetDescendants() do
	if o:IsA("TextLabel") and (string.find(o.Text, "conjura", 1, true) or string.find(o.Text, "Ações", 1, true)) then table.insert(t, o.Text) end
end
return table.concat(t, " || ")
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

        def barra():
            return json.loads(luau(BARRA))

        def click(x, y):
            call("user_mouse_input", datamodel_type="Client", actions=[
                {"action": "moveTo", "x": x, "y": y},
                {"action": "wait", "wait_time_ms": 100},
                {"action": "mouseButtonClick", "mouse_button": "left"},
                {"action": "wait", "wait_time_ms": 500},
            ])

        call("start_stop_play", is_start=True)
        time.sleep(9)
        lobo = luau(PREPARAR).strip().strip('"')
        time.sleep(0.8)
        b = barra()
        check("barra aparece na vez do Ignis", b["visivel"])
        check("8 cartas (Brasa, as 5 compras e os 2 ataques básicos)", len(b["cartas"]) == 8, sorted(b["cartas"]))
        check("3 Ações disponíveis", b["acoes"].count("◆") == 3, b["acoes"])

        # Convenção de coordenadas: tenta sem e com a barra superior.
        x, y = b["cartas"]["bola-de-fogo"]
        offset = None
        for candidato in (0, b["inset"]):
            click(x, y + candidato)
            if "alvo" in barra()["dica"]:
                offset = candidato
                break
        check("clique na carta liga a mira", offset is not None, barra()["dica"])
        if offset is None:
            return
        time.sleep(1.0)  # câmera indo para a Visão da mesa
        pos = luau(LOBO_NA_TELA % json.dumps(lobo))
        check("lobo visível na tela", pos != "nil", pos)
        lx, ly = map(int, pos.split(","))
        click(lx, ly - b["inset"])
        time.sleep(1.2)
        registro = luau(REGISTRO)
        check("clique no lobo conjura a Bola de Fogo", "conjura Bola de Fogo" in registro, registro[-300:])
        b = barra()
        check("2 Ações gastas", b["acoes"].count("◇") == 2, b["acoes"])
        check("mira desligada depois do disparo", "alvo" not in b["dica"], b["dica"])

        x, y = b["cartas"]["clarao"]
        click(x, y + offset)
        check("Clarão: primeiro clique arma (raio)", "de novo" in barra()["dica"], barra()["dica"])
        click(x, y + offset)
        time.sleep(1.0)
        check("Clarão: segundo clique solta", "conjura Clarão" in luau(REGISTRO))

        b = barra()
        check("cartas bloqueadas sem Ações", b["acoes"].count("◆") == 0, b["acoes"])
        ex, ey = b["botoes"]["EncerrarTurno"]
        click(ex, ey + offset)
        time.sleep(0.8)
        check("Encerrar turno esconde a barra (vez do lobo)", not barra()["visivel"])
        call("screen_capture", capture_id="UI_Fogo")
    finally:
        try:
            client.call("start_stop_play", {"studio_id": client.studio_id(), "is_start": False})
        except Exception:  # noqa: BLE001 - parar o Play é melhor esforço
            pass
        client.close()
        failures = sum(1 for line in report if line.startswith("FALHA"))
        print("\n".join(report))
        print("RESUMO: %d falha(s)" % failures)


if __name__ == "__main__":
    main()
