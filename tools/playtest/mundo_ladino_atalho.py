"""Atalho de TESTE para concluir a provação do Ladino de forma confiável (o bot de furtividade falha com frequência).
Cobre os guardas com caixas invisíveis (os raios do cone batem nelas), leva o avatar ao sino e depois ao portão e
aciona os prompts. Só vale para playtest no Studio; o servidor continua decidindo tudo (detecção, sino, aprovação).
Achado: com o prompt do Ladino habilitado, o E no portão pode ser consumido por ele; por isso desligamos (só no
cliente) os outros prompts perto do portão antes do E."""
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

c = Client()
sid = json.loads(c.call("list_roblox_studios", {})["text"])["studios"][0]["id"]


def lua(code, onde="Client"):
    r = c.call("execute_luau", dict(studio_id=sid, datamodel_type=onde, code=code))
    return r.get("text", "")


CAIXAS = """local patio=workspace.ProvacoesTreinadores["Pátio do Ladino"]
local f=Instance.new("Folder") f.Name="AnteparosTesteLadino" f.Parent=workspace
local caixas={}
for i=1,3 do local ps={} for k=1,4 do local s=Instance.new("Part") s.Anchored=true s.CanCollide=true s.CanQuery=true s.Transparency=1 s.Parent=f ps[k]=s end
 ps[1].Size=Vector3.new(4,10,0.3) ps[2].Size=Vector3.new(4,10,0.3) ps[3].Size=Vector3.new(0.3,10,4) ps[4].Size=Vector3.new(0.3,10,4) caixas[i]=ps end
game:GetService("RunService").Heartbeat:Connect(function()
 for i=1,3 do local g=patio:FindFirstChild("Guarda "..i) local h=g and (g:FindFirstChild("HumanoidRootPart") or g.PrimaryPart)
  if h and caixas[i][1].Parent then local c=h.Position+Vector3.new(0,3,0)
   caixas[i][1].Position=c+Vector3.new(0,0,1.8) caixas[i][2].Position=c+Vector3.new(0,0,-1.8) caixas[i][3].Position=c+Vector3.new(1.8,0,0) caixas[i][4].Position=c+Vector3.new(-1.8,0,0) end end end)
return 'caixas'"""
TP = "local p=game.Players:GetPlayers()[1] p.Character:PivotTo(CFrame.new(%s)) task.wait(0.6) return tostring(p.Character.HumanoidRootPart.Position)"
print(lua(CAIXAS, "Server"))
print(lua(TP % "64,3,-263", "Server"))
print(lua("""local s=workspace.ProvacoesTreinadores["Pátio do Ladino"].Sino.ProximityPrompt
s:InputHoldBegin() task.wait(1.7) s:InputHoldEnd() task.wait(0.6)
return 'sino='..workspace.ProvacoesTreinadores["Pátio do Ladino"].Sino.Transparency"""))
print(lua(TP % "65,3,-231.5", "Server"))
print(lua("""local root=game.Players.LocalPlayer.Character.HumanoidRootPart
for _,d in workspace:GetDescendants() do if d:IsA('ProximityPrompt') and d.Parent.Name~='Portão' and d.Parent:IsA('BasePart') and (d.Parent.Position-root.Position).Magnitude<14 then d.Enabled=false end end
task.wait(1.5) return 'outros prompts desligados (cliente)'"""))
c.call("user_keyboard_input", dict(studio_id=sid, datamodel_type="Client", actions=[
    {"action": "keyDown", "key_code": "E"}, {"action": "wait", "wait_time_ms": 700},
    {"action": "keyUp", "key_code": "E"}, {"action": "wait", "wait_time_ms": 2500}]))
print(lua("""for _,d in workspace:GetDescendants() do if d:IsA('ProximityPrompt') then d.Enabled=true end end
local pg=game.Players.LocalPlayer.PlayerGui.OrientacaoJogador local t={} for _,x in pg:GetDescendants() do if x:IsA('TextLabel') and x.Visible and #x.Text>6 then table.insert(t,x.Text) end end
return table.concat(t,' | ')"""))
print(lua("local f=workspace:FindFirstChild('AnteparosTesteLadino') if f then f:Destroy() end return 'caixas removidas'", "Server"))
