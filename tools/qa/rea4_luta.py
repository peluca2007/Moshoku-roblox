"""REA4: reação do alvo na LUTA REAL (esgoto), pelo caminho do servidor. Requer Play em luta (qa.py esgoto_sala1 --manter-play).
  python tools/qa/rea4_luta.py <rotulo> <golpe|critico|esquiva|bloqueio|morte> [--nome=trecho] [--escala=1]
Reenvia ao cliente o recibo (como hab_luta_real.py) E aciona no servidor o mesmo caminho do recibo real (workspace.QaReacao ->
CorposDeCriatura.reagir -> ReacoesAlvo.decidir -> clipe no contato). morte: depois do golpe derruba o corpo (QaMorrer).
Grava build/beleza/rea4/<rotulo>_<cenario>.mp4 (gravar.py, sem foco o Studio cai a ~15 fps: studio_janela.ps1 -Foco)."""
import os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ

rotulo, cen = sys.argv[1], sys.argv[2]
nome_exige = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--nome=")), None)
escala = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--escala=")), "1")
q = Qa(); q.cenario = "rea4"
dest = os.path.join(RAIZ, "build", "beleza", "rea4"); os.makedirs(dest, exist_ok=True)
LUA = """local remote=game.ReplicatedStorage:WaitForChild('Mesa') local snap
local con=remote.OnClientEvent:Connect(function(k,d) if k=='snapshot' then snap=d end end)
remote:FireServer('requestSnapshot') local t0=os.clock() while not snap and os.clock()-t0<5 do task.wait(0.1) end
local function eu() for _,t in snap.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId then return t end end end
local h local t1=os.clock()
while os.clock()-t1<40 do task.wait(0.4) h=eu() if snap.combat.active and h and snap.combat.turnId==h.id then break end h=nil end
if not h then con:Disconnect() return 'sem vez' end
local alvo,dist for _,t in snap.tokens do if t.criatura and not t.derrotado and (t.pv or 0)>0 then local d=math.max(math.abs(t.x-h.x),math.abs(t.z-h.z)) if not dist or d<dist then dist,alvo=d,t end end end
if not alvo then con:Disconnect() return 'sem alvo' end
for _=1,4 do
 if dist<=1 then break end
 local dx=alvo.x>h.x and 1 or (alvo.x<h.x and -1 or 0) local dz=alvo.z>h.z and 1 or (alvo.z<h.z and -1 or 0)
 local p=math.max(1,math.min(math.abs(dist-1),3))
 remote:FireServer('move',{id=h.id,x=h.x+dx*p,z=h.z+dz*p,andar=true}) task.wait(2.2)
 remote:FireServer('requestSnapshot') task.wait(0.5)
 h=eu() for _,t in snap.tokens do if t.id==alvo.id then alvo=t end end
 dist=math.max(math.abs(alvo.x-h.x),math.abs(alvo.z-h.z))
end
con:Disconnect() return h.id..'|'..alvo.id..'|'..alvo.name..'|dist='..dist"""
info = q.lua_cliente(LUA); print(info)
if "|" not in info: sys.exit(1)
hid, aid, nome = info.split("|")[:3]
if nome_exige and nome_exige.lower() not in nome.lower():
    print("alvo errado:", nome); sys.exit(2)
crit = cen == "critico"
erro = cen == "esquiva"
dano = 0 if cen == "bloqueio" else (14 if cen in ("critico", "morte") else 5)
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', %s) workspace:SetAttribute('QaCritico', %s) return 'ok'" % (escala, "true" if crit else "nil"))
time.sleep(0.5)
from gravar import Gravador
saida = os.path.join(dest, "%s_%s.mp4" % (rotulo, cen))
with Gravador(saida, 9):
    time.sleep(1.0)
    q.lua_servidor("""local r=game.ReplicatedStorage.Mesa for _,p in game.Players:GetPlayers() do
r:FireClient(p,'efeito',{habilidadeId='mesa/ataque-basico',casterId='%s',origem={1,1},arma='Espada',alvos={{id='%s',acertou=%s,critico=%s,dano=%d,passou=false}}}) end
workspace:SetAttribute('QaReacao','%s|mesa/ataque-basico|%s|%s|%d') return 'enviado'""" % (hid, aid, "false" if erro else "true", "true" if crit else "false", dano, aid, "false" if erro else "true", "true" if crit else "false", dano))
    if cen == "morte":
        time.sleep(0.2)
        q.lua_servidor("workspace:SetAttribute('QaMorrer','%s') return 'ok'" % aid)
    time.sleep(7.5)
print("QaReagiu:", q.lua_servidor("return tostring(workspace:GetAttribute('QaReagiu'))"))
print("video", saida)
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', nil) workspace:SetAttribute('QaCritico', nil) return 'ok'")
q.c.close()
