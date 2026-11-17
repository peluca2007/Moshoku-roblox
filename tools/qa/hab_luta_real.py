"""HAB1b/c: apresentação de uma habilidade na LUTA REAL (esgoto), só visual: o servidor reenvia ao cliente um recibo
"efeito" (Mesa:FireClient) com a habilidade pedida, usando as fichas reais (personagem do QA e a criatura mais próxima).
Requer Play em luta (qa.py esgoto_sala1 --manter-play). Nada muda no estado do jogo.
  python tools/qa/hab_luta_real.py <habilidade-id completo> <nome> [escala] [--crit] [--longe] [--video=arquivo.mp4]
--longe: magia, fica a 3-4 casas do alvo (padrão: casa adjacente). --video: grava a janela do Studio (gravar.py)
em vez de fotos. Fotos: build/beleza/hab1/<nome>_<n>.png (10 quadros)."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ

ident, nome = sys.argv[1], sys.argv[2]
escala = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else "6"
crit = "--crit" in sys.argv
longe = "--longe" in sys.argv
camera = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--camera=")), None)  # grava a série da câmera (csv) e reprova se houver salto
nome_exige = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--nome=")), None)  # sai com 2 se o alvo não tiver esse trecho no nome
solta = "--solta" in sys.argv  # pede ao servidor (só Studio) que a arma do corpo caia de verdade
si = "--si" in sys.argv  # recibo com o próprio conjurador como alvo (escudo, cura, auras)
resultado = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--res=")), "falha")  # falha | passa | erro (Vigor/erro do recibo visual)
video = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--video=")), None)
trajeto = next((int(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--trajeto=")), 0)  # Investida: casas de corrida para trás do conjurador (REA2)
q = Qa()
q.cenario = "hab_real"
dest = os.path.join(RAIZ, "build", "beleza", "hab1")
os.makedirs(dest, exist_ok=True)
LUA = """local LONGE=%s
local remote=game.ReplicatedStorage:WaitForChild('Mesa') local snap
local con=remote.OnClientEvent:Connect(function(k,d) if k=='snapshot' then snap=d end end)
remote:FireServer('requestSnapshot') local t0=os.clock() while not snap and os.clock()-t0<5 do task.wait(0.1) end
local function eu() for _,t in snap.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId then return t end end end
local h local t1=os.clock()
while os.clock()-t1<40 do task.wait(0.4) h=eu() if snap.combat.active and h and snap.combat.turnId==h.id then break end h=nil end
if not h then con:Disconnect() return 'sem vez' end
local alvo,dist for _,t in snap.tokens do if t.criatura and not t.derrotado and (t.pv or 0)>0 then local d=math.max(math.abs(t.x-h.x),math.abs(t.z-h.z)) if not dist or d<dist then dist,alvo=d,t end end end
if not alvo then con:Disconnect() return 'sem alvo' end
for _=1,4 do
 if dist<=(LONGE and 6 or 1) then break end -- longe: só se aproxima se estiver além de 6 (sem gastar Ação à toa: some o aviso 'Sem Ação para mover')
 local dx=alvo.x>h.x and 1 or (alvo.x<h.x and -1 or 0) local dz=alvo.z>h.z and 1 or (alvo.z<h.z and -1 or 0)
 local alvoDist=(LONGE and 3 or 1)
 local p=math.max(1,math.min(math.abs(dist-alvoDist),3)) if dist<alvoDist then p=-p end
 remote:FireServer('move',{id=h.id,x=h.x+dx*p,z=h.z+dz*p,andar=true}) task.wait(2.2)
 remote:FireServer('requestSnapshot') task.wait(0.5)
 h=eu() for _,t in snap.tokens do if t.id==alvo.id then alvo=t end end
 dist=math.max(math.abs(alvo.x-h.x),math.abs(alvo.z-h.z))
end
con:Disconnect() return h.id..'|'..alvo.id..'|'..alvo.name..'|dist='..dist..'|'..h.x..','..h.z..','..alvo.x..','..alvo.z"""
info = q.lua_cliente(LUA % ("true" if longe else "false"))
print(info)
if "|" not in info:
    sys.exit(1)
hid, aid = info.split("|")[:2]
hx, hz, ax, az = [int(float(v)) for v in info.split("|")[4].split(",")]
sgn = lambda v: (v > 0) - (v < 0)
traj_lua = "trajeto={{%d,%d},{%d,%d}}," % (hx - sgn(ax - hx) * trajeto, hz - sgn(az - hz) * trajeto, hx, hz) if trajeto else ""

if nome_exige and not any(n.strip().lower() in info.split("|")[2].lower() for n in nome_exige.split(",")):
    print("alvo errado:", info); sys.exit(2)
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', %s) workspace:SetAttribute('QaCritico', %s) return 'ok'" % (escala, "true" if crit else "nil"))
time.sleep(0.5)


def disparar():
    q.lua_servidor("""local r=game.ReplicatedStorage.Mesa for _,p in game.Players:GetPlayers() do
r:FireClient(p,'efeito',{habilidadeId='%s',casterId='%s',origem={1,1},%s alvos={{id='%s',acertou=%s,critico=%s,dano=6,passou=%s,largouArma=%s}}}) end return 'enviado'""" % (ident, hid, traj_lua, hid if si else aid, "false" if resultado == "erro" else "true", "true" if crit else "false", "true" if resultado == "passa" else "false", "true" if (solta and resultado == "falha") else "false"))
    if solta and resultado == "falha":
        time.sleep(0.85 * float(escala))  # o contato cai ~0,8 s depois do recibo
        q.lua_servidor("workspace:SetAttribute('QaSoltarArma', '%s') return 'ok'" % aid)
        time.sleep(0.5)
        # prova por números: peças Arma* fora do modelo (filhas do workspace): Y, ancoragem, colisão, ao longo de 3 s
        print("QaSoltouArma/QaArmaSolta:", q.lua_servidor("return tostring(workspace:GetAttribute('QaSoltouArma'))..' '..tostring(workspace:GetAttribute('QaArmaSolta'))"))
        print(q.lua_servidor("""local o={} for i=1,10 do local l={} for _,p in workspace:GetChildren() do if p:IsA('BasePart') and p.Name:sub(1,4)=='Arma' then l[#l+1]=string.format('%s y=%.2f A=%s C=%s',p.Name,p.Position.Y,tostring(p.Anchored),tostring(p.CanCollide)) end end o[#o+1]=string.format('t=%.1f %s',i*0.3,table.concat(l,' ; ')) task.wait(0.3) end return table.concat(o,' || ')"""))


if camera:
    import cam_serie
    cam_serie.iniciar(q)
    disparar()
    time.sleep(7 * max(float(escala), 1.0))
    ok = cam_serie.parar(q, camera, ident.split("/")[-1])
    q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', nil) workspace:SetAttribute('QaCritico', nil) return 'ok'")
    q.c.close()
    sys.exit(0 if ok else 1)
if video:
    from gravar import Gravador
    dur = 12 if escala != "1" else 6
    with Gravador(video, dur):
        time.sleep(0.5)
        disparar()
        time.sleep(dur - 0.5)
    print("video", video)
else:
    disparar()
    for i in range(10):
        f = q.foto("%s_%d" % (nome, i))
        print(i, f)
        if f.startswith("build"):
            shutil.copyfile(os.path.join(RAIZ, f), os.path.join(dest, "%s_%d.png" % (nome, i)))
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', nil) workspace:SetAttribute('QaCritico', nil) return 'ok'")
q.c.close()
