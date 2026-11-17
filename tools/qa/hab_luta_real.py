"""HAB1b: apresentação de uma habilidade na LUTA REAL (esgoto), só visual: o servidor reenvia ao cliente um recibo
"efeito" (Mesa:FireClient) com a habilidade pedida, usando as fichas reais (personagem do QA e a criatura mais próxima).
Requer Play em luta (qa.py esgoto_sala1 --manter-play). Nada muda no estado do jogo.
  python tools/qa/hab_luta_real.py <habilidade-id completo> <nome-do-arquivo> [escala] [--crit]
Salva build/beleza/hab1/<nome>_<n>.png (10 quadros)."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ

ident, nome = sys.argv[1], sys.argv[2]
escala = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else "6"
crit = "--crit" in sys.argv
q = Qa()
q.cenario = "hab_real"
dest = os.path.join(RAIZ, "build", "beleza", "hab1")
os.makedirs(dest, exist_ok=True)
# 1) espera a vez, chega ao lado da criatura mais próxima e lê os ids
info = q.lua_cliente("""local remote=game.ReplicatedStorage:WaitForChild('Mesa') local snap
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
 local p=math.max(1,math.min(dist-1,3)) remote:FireServer('move',{id=h.id,x=h.x+dx*p,z=h.z+dz*p,andar=true}) task.wait(2.2)
 remote:FireServer('requestSnapshot') task.wait(0.5)
 h=eu() for _,t in snap.tokens do if t.id==alvo.id then alvo=t end end
 dist=math.max(math.abs(alvo.x-h.x),math.abs(alvo.z-h.z))
end
con:Disconnect() return h.id..'|'..alvo.id..'|'..alvo.name..'|dist='..dist""")
print(info)
if "|" not in info:
    sys.exit(1)
hid, aid, anome = info.split("|")[:3]
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', %s) workspace:SetAttribute('QaCritico', %s) return 'ok'" % (escala, "true" if crit else "nil"))
time.sleep(0.5)
q.lua_servidor("""local r=game.ReplicatedStorage.Mesa for _,p in game.Players:GetPlayers() do
r:FireClient(p,'efeito',{habilidadeId='%s',casterId='%s',origem={1,1},alvos={{id='%s',acertou=true,critico=%s,dano=6}}}) end return 'enviado'""" % (ident, hid, aid, "true" if crit else "false"))
for i in range(10):
    f = q.foto("%s_%d" % (nome, i))
    print(i, f)
    if f.startswith("build"):
        shutil.copyfile(os.path.join(RAIZ, f), os.path.join(dest, "%s_%d.png" % (nome, i)))
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', nil) workspace:SetAttribute('QaCritico', nil) return 'ok'")
q.c.close()
