"""Aceita no quadro a primeira caçada de perigo baixo e leva o avatar até a patrulha dela, esperando o contato.
Pré-requisito: vila com ficha válida (mundo_aberto_inicio.py + mundo_ladino_atalho.py). Imprime o estado da patrulha."""
import json
import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
# O cliente MCP liga MoshokuTesteMestre ao iniciar o Play (modo mestre dos roteiros antigos): sem SalaConceitual no snapshot,
# a CameraMundo (diagonal alta) nunca liga. Estes roteiros jogam como jogador comum.
os.environ.setdefault("MOSHOKU_TESTE_JOGADOR", "1")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client  # noqa: E402

c = Client()
sid = json.loads(c.call("list_roblox_studios", {})["text"])["studios"][0]["id"]


def lua(code, onde="Client"):
    return c.call("execute_luau", dict(studio_id=sid, datamodel_type=onde, code=code)).get("text", "")


OFERTAS = r'''local p=game.Players:GetPlayers()[1]
p.Character:PivotTo(CFrame.new(22,3,-186))
task.wait(0.8)
local q=workspace.Vila["Quadro de caçadas"]
local out={}
local pick
for passo=1,2 do
 for i=1,3 do
  local t=q["Caçada "..i]:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel").Text
  if passo==1 then out[i]=i..": "..string.gsub(t,"\n"," | ") end
  local baixo=string.find(t,"Perigo: baixo",1,true)
  local rato=string.find(t,"Ratos",1,true)
  if not pick and baixo and (passo==2 or rato) then pick=i workspace:SetAttribute("CacadaNome",string.match(t,"^[^\n]+")) end
 end
end
workspace:SetAttribute("CacadaIdx",pick)
return table.concat(out,"\n")'''
print(lua(OFERTAS, "Server"))
idx = lua('return tostring(workspace:GetAttribute("CacadaIdx"))', "Server")
nome = lua('return tostring(workspace:GetAttribute("CacadaNome"))', "Server")
print("aceitando caçada", idx, nome)
print(lua('local pr=workspace.Vila["Quadro de caçadas"]["Caçada ' + idx + '"].ProximityPrompt pr:InputHoldBegin() task.wait(0.4) pr:InputHoldEnd() task.wait(1) return "aceita"'))
pos = json.loads(lua('local m=workspace["Patrulhas do mundo"]["' + nome + '"] local c=m.PrimaryPart.Position return game:GetService("HttpService"):JSONEncode({x=c.X,y=c.Y,z=c.Z})', "Server"))
lua('local p=game.Players:GetPlayers()[1] p.Character:PivotTo(CFrame.new(%f,%f,%f)) task.wait(0.6) return "tp"' % (pos["x"] - 2, pos["y"] + 4, pos["z"] - 26), "Server")
c.call("character_navigation", dict(studio_id=sid, datamodel_type="Client", x=pos["x"], y=3, z=pos["z"] - 5, speed_multiplier=1))
print(lua('''local p=game.Players:GetPlayers()[1] local m=workspace["Patrulhas do mundo"]["''' + nome + '''"] local out={}
for i=1,40 do task.wait(0.5) local c=m.PrimaryPart.Position local r=p.Character.HumanoidRootPart.Position
 out[#out+1]=string.format("%.1f %s d=%.0f",i*0.5,tostring(m:GetAttribute("Estado")),(c-r).Magnitude) if m:GetAttribute("Estado")=="em-encontro" then break end end
return table.concat(out," | "):sub(-300)''', "Server"))
