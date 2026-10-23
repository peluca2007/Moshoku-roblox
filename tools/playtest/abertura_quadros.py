"""Captura quadros da cena de abertura no Play do Studio (cliente).

Uso (Studio já em Play, mundo carregado): python tools/playtest/abertura_quadros.py <pasta> t1 t2 ...
Para cada t (segundos de cena) congela o quadro com CenaAbertura.tocar{inicioEm=t, velocidade=0}
e salva <pasta>/cena-<t>.jpg. Não decide nada no jogo: só câmera e interface locais.
"""
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client  # noqa: E402

pasta = Path(sys.argv[1])
pasta.mkdir(parents=True, exist_ok=True)
tempos = [float(x) for x in sys.argv[2:]]
c = Client()
studios = json.loads(c.call("list_roblox_studios", {})["text"])["studios"]
sid = studios[0]["id"]


def call(tool, **args):
    r = c.call(tool, dict(studio_id=sid, **args))
    if r.get("isError") or "erro" in r:
        raise RuntimeError(r)
    return r["text"]


def lua(code):
    return call("execute_luau", datamodel_type="Client", code=code)


PREPARO = """
local P = game.Players.LocalPlayer
pcall(function() game:GetService("RunService"):UnbindFromRenderStep("vistaTeste") end)
shared.Cena = shared.Cena or require(P.PlayerScripts.Client.CenaAbertura)
shared.frame = function(t)
  local Cena = shared.Cena
  if Cena.ativa() then Cena.pular(); while Cena.ativa() do task.wait(.1) end; task.wait(0.7) end
  local stub = {pausar=function() end, retomar=function() end}
  task.spawn(function() shared.resultado = Cena.tocar({cameraMundo=stub, inicioEm=t, velocidade=0}) end)
  task.wait(0.8)
end
return "pronto"
"""

subprocess.run(["powershell", "-File", str(Path(__file__).resolve().parents[1] / "restaurar_studio.ps1")], check=False)
print(lua(PREPARO))
for t in tempos:
    lua("shared.frame(%s) return 'ok'" % t)
    time.sleep(0.4)
    m = re.search(r"\[imagem salva em (.*?)\]", call("screen_capture", capture_id="abertura_%s" % t))
    if m:
        destino = pasta / ("cena-%05.2f.jpg" % t)
        shutil.copyfile(m[1], destino)
        print("salvo", destino)
lua("if shared.Cena.ativa() then shared.Cena.pular() end return 'ok'")
