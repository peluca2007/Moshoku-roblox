"""Repete o bot de furtividade do Ladino (e2e_ladino_furtivo.luau) até a provação ser aprovada (máx. 6 tentativas).
Pré-requisito: provação aceita e jogador agachado no pátio. Aprovada = o objetivo do HUD deixa de falar do sino/portão."""
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


def lua(code):
    r = c.call("execute_luau", dict(studio_id=sid, datamodel_type="Client", code=code))
    return r.get("text", "")


codigo = (RAIZ / "tools/playtest/e2e_ladino_furtivo.luau").read_text(encoding="utf-8")
OBJ = "local g=game.Players.LocalPlayer.PlayerGui.OrientacaoJogador local t={} for _,d in g:GetDescendants() do if d:IsA('TextLabel') and d.Visible and #d.Text>6 then table.insert(t,d.Text) end end return table.concat(t,' | ')"
for tentativa in range(1, 7):
    lua(codigo)
    t0 = time.time()
    while time.time() - t0 < 150:
        time.sleep(4)
        if "fim=true" in lua("local L=_G.LADINO return L.fase..' fim='..tostring(L.fim)"):
            break
    time.sleep(2)
    objetivo = lua(OBJ)
    print("tentativa %d (%.0fs): %s" % (tentativa, time.time() - t0, objetivo[:160]), flush=True)
    if "sino" not in objetivo.lower() and "portão" not in objetivo.lower():
        print("provação concluída")
        break
