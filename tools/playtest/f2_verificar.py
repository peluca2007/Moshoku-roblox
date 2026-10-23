"""Regressão F2 no place local: suíte completa e ciclo dos personagens pelo cliente.
Uso: python tools/playtest/f2_verificar.py
Não altera o outro place aberto; encerra somente o Play que este roteiro iniciou.
"""
import json
from pathlib import Path
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client

client = Client()
iniciou = False
studio = None


def chamar(tool, **args):
    result = client.call(tool, {"studio_id": studio, **args})
    if result.get("isError") or "erro" in result:
        raise RuntimeError(result)
    return result["text"]


try:
    resposta = client.call("list_roblox_studios", {})
    studios = json.loads(resposta["text"])["studios"]
    locais = [s for s in studios if s["name"] == "Moshoku-Prototipo.rbxlx"]
    if len(locais) != 1:
        raise RuntimeError("Esperado exatamente um Moshoku-Prototipo.rbxlx aberto.")
    studio = locais[0]["id"]
    estado = chamar("get_studio_state")
    print("Estado inicial:", estado, flush=True)
    if "- Current Studio Mode: Edit" not in estado.splitlines():
        raise RuntimeError("Studio local não confirmou Edit; nenhum Play foi encerrado.")
    print(chamar("start_stop_play", is_start=True), flush=True)
    iniciou = True
    time.sleep(8)
    specs = chamar("execute_luau", datamodel_type="Server", code=(
        'local r=game.ServerScriptService.Server; '
        'local p,f=require(r.TestRunner).run(r.tests); assert(f==0); return p.." specs aprovados"'
    ))
    print("Specs:", specs, flush=True)
    if "specs aprovados" not in specs:
        raise RuntimeError("A suíte não confirmou aprovação.")
    source = Path(__file__).with_name("a9_personagens_e2e.luau").read_text(encoding="utf-8")
    print(chamar("execute_luau", datamodel_type="Client", code=source), flush=True)
    limite = time.monotonic() + 600
    while time.monotonic() < limite:
        time.sleep(10)
        status = chamar("execute_luau", datamodel_type="Client", code=(
            'local r=shared.A9; if r and r.pronto then '
            'return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n") '
            'end; return "EM ANDAMENTO "..(r and #r.linhas or 0)'
        ))
        print(status, flush=True)
        if "FINAL " in status:
            if "FINAL 0" not in status or "FALHA " in status:
                raise RuntimeError("Regressão dos personagens falhou.")
            break
    else:
        raise TimeoutError("Regressão dos personagens não terminou em 600 s.")
    print("Console:", chamar("get_console_output"), flush=True)
finally:
    if iniciou:
        print(chamar("start_stop_play", is_start=False), flush=True)
        print("Estado final:", chamar("get_studio_state"), flush=True)
    client.close()
