"""Traça formas por user_mouse_input na bancada de cliente A19 já preparada.

Uso: python tools/playtest/a19_tracar.py
Não inicia/para Play. Não atua se a bancada A19 não for a mesa/vez atual.
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client
sys.stdout.reconfigure(encoding="utf-8")

client = Client()
try:
    studio = client.studio_id()
    # Abre o quadro com clique real na carta "Desenhar fórmula" da barra.
    carta = client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Client", "code": """
assert(shared.A19 and shared.A19.uiPronta,'Bancada A19 não está pronta')
local c=game.Players.LocalPlayer.PlayerGui:FindFirstChild('Carta_mesa/desenhar-formula',true)
assert(c,'Carta Desenhar fórmula ausente')
local rolagem=c:FindFirstAncestorOfClass('ScrollingFrame')
if rolagem then
	-- traz a carta para a área visível da barra antes do clique
	local rel=c.AbsolutePosition-rolagem.AbsolutePosition+rolagem.CanvasPosition
	rolagem.CanvasPosition=Vector2.new(math.max(0,rel.X-20),math.max(0,rel.Y-20))
	task.wait(0.3)
end
local gui=c:FindFirstAncestorOfClass('ScreenGui')
-- user_mouse_input usa o mesmo espaço de AbsolutePosition (sem somar o inset).
local inset=Vector2.zero
local p=c.AbsolutePosition+c.AbsoluteSize/2+inset
return game.HttpService:JSONEncode({x=p.X,y=p.Y})
"""})
    if carta.get("isError"):
        raise SystemExit(carta)
    t = carta["text"]; pc = json.loads(t[t.find("{"):t.rfind("}") + 1]); print("CARTA", pc)
    client.call("user_mouse_input", {"studio_id": studio, "datamodel_type": "Client", "actions": [
        {"action": "moveTo", "x": pc["x"], "y": pc["y"]}, {"action": "mouseButtonDown", "mouse_button": "left"}, {"action": "wait", "wait_time_ms": 120},
        {"action": "mouseButtonUp", "mouse_button": "left"}, {"action": "wait", "wait_time_ms": 900}]})
    result = client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Client", "code": """
assert(shared.A19 and shared.A19.uiPronta,'Bancada A19 não está pronta')
local g=game.Players.LocalPlayer.PlayerGui.FormulaView
assert(g.Fundo.Visible,'Tela não está aberta')
local q=g:FindFirstChild('Quadro',true)
return game.HttpService:JSONEncode({x=q.AbsolutePosition.X,y=q.AbsolutePosition.Y,w=q.AbsoluteSize.X,h=q.AbsoluteSize.Y})
"""})
    if result.get("isError"):
        raise SystemExit(result)
    text = result["text"]
    # execute_luau devolve a string JSON, eventualmente entre aspas.
    start = text.find("{")
    end = text.rfind("}")
    quad = json.loads(text[start:end + 1])
    cx, cy = quad["x"] + quad["w"] / 2, quad["y"] + quad["h"] / 2
    radius = min(quad["w"], quad["h"]) / 2 - 22
    shapes = {
        "circulo": [(cx + radius * math.cos(i * math.tau / 48), cy + radius * math.sin(i * math.tau / 48)) for i in range(49)],
        "linha": [(cx - radius + i * radius * 2 / 24, cy) for i in range(25)],
        "quadrado": [],
    }
    corners = [(cx - radius, cy - radius), (cx + radius, cy - radius), (cx + radius, cy + radius), (cx - radius, cy + radius), (cx - radius, cy - radius)]
    for a, b in zip(corners, corners[1:]):
        shapes["quadrado"].extend([(a[0] + (b[0] - a[0]) * i / 12, a[1] + (b[1] - a[1]) * i / 12) for i in range(13)])
    for name, points in shapes.items():
        actions = [{"action": "moveTo", "x": points[0][0], "y": points[0][1]}, {"action": "mouseButtonDown", "mouse_button": "left"}]
        for x, y in points[1:]:
            actions.extend([{"action": "moveTo", "x": x, "y": y}, {"action": "wait", "wait_time_ms": 20}])
        actions.append({"action": "mouseButtonUp", "mouse_button": "left"})
        result = client.call("user_mouse_input", {"studio_id": studio, "datamodel_type": "Client", "actions": actions})
        print("TRAÇO", name, result)
        if result.get("isError"):
            raise SystemExit("Entrada de mouse recusada")
        result = client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Client", "code": f"""
local g=game.Players.LocalPlayer.PlayerGui.FormulaView
local text=g:FindFirstChild('Reconhecimento',true).Text
local expected=({{circulo='Círculo',linha='Linha',quadrado='Quadrado'}})['{name}']
assert(text:find(expected,1,true),text)
local n=0; for _,p in g:FindFirstChild('Quadro',true):GetChildren() do if p.Name=='Traco' then n+=1 end end
assert(n>=5,'Traço não desenhou segmentos')
return expected..' reconhecido por mouse real · '..n..' segmentos · '..g:FindFirstChild('Custo',true).Text
"""})
        print(result)
        if result.get("isError"):
            raise SystemExit("Reconhecimento falhou")
finally:
    client.close()
