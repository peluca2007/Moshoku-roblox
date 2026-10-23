"""Executa um .luau no Client do Studio e imprime o retorno. Uso: python tools/playtest/rodar_cliente.py arquivo.luau [Client|Server]"""
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client  # noqa: E402

c = Client()
sid = json.loads(c.call("list_roblox_studios", {})["text"])["studios"][0]["id"]
onde = sys.argv[2] if len(sys.argv) > 2 else "Client"
code = Path(sys.argv[1]).read_text(encoding="utf-8")
print(c.call("execute_luau", dict(studio_id=sid, datamodel_type=onde, code=code)).get("text"))
