"""Play exclusivo A19. Não para nem sincroniza um Play encontrado ao entrar.

Uso: python tools/playtest/a19_studio.py [--cliente]
Executa TestRunner inteiro e opcionalmente a bancada do cliente; conserva o
Play se --cliente para a etapa de traço. Sem publicação.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client

sys.stdout.reconfigure(encoding="utf-8")
client = Client()
try:
    studio = client.studio_id()
    state = client.call("get_studio_state", {"studio_id": studio})
    print(state)
    if "Edit" not in state["text"] or "Server" in state["text"]:
        raise SystemExit("Studio ocupado: não sincronizado/iniciado/encerrado.")
    started = client.call("start_stop_play", {"studio_id": studio, "is_start": True})
    print(started)
    if started.get("isError"):
        raise SystemExit("Play não iniciado por A19.")
    print(client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Server",
        "code": "local s=game.ServerScriptService:WaitForChild('Server'); local p,f=require(s.TestRunner).run(s.tests); assert(f==0,p..' ok / '..f..' falhas'); return p..' specs, 0 falhas'"}))
    if "--cliente" in sys.argv:
        print(client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Client",
            "code": Path("tools/playtest/a19_cliente.luau").read_text(encoding="utf-8")}))
        print("Play A19 mantido para traço/inspeção. Encerrar só após registrar fim.")
    else:
        print(client.call("start_stop_play", {"studio_id": studio, "is_start": False}))
finally:
    client.close()
