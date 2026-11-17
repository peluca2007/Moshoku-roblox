"""HAB3: magias da Água pelo CAMINHO NORMAL (remoto usarHabilidade, recibo real do servidor), em vídeo.
Pré-requisito: Play em luta (qa.py primeira_arvore --manter-play; setar workspace.QaEncontro e QaAprender='agua' no servidor;
qa.py esgoto_sala1 --sem-deps --manter-play). A ficha do QA aprende a árvore da Água por QaAprender (HabilidadeService, só Studio).
  python tools/qa/hab_real_agua.py <respingo|bola-de-agua|flecha-de-agua|impacto-de-gelo|lamina-de-gelo|escudo-de-agua|nevoa-densa> [--rodadas=N]
Grava build/beleza/hab6/real_<magia>.mp4 e passa N rodadas (padrão 0) depois do uso para ver a zona sumir."""
import os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ
from gravar import Gravador

magia = sys.argv[1]
rodadas = next((int(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--rodadas=")), 0)
q = Qa()
q.cenario = "hab_real_agua"
saida = os.path.join(RAIZ, "build", "beleza", "hab6", "real_%s.mp4" % magia)
os.makedirs(os.path.dirname(saida), exist_ok=True)

ESPERA = """local remote=game.ReplicatedStorage:WaitForChild('Mesa') local snap
local con=remote.OnClientEvent:Connect(function(k,d) if k=='snapshot' then snap=d end end)
remote:FireServer('requestSnapshot') local t0=os.clock() while not snap and os.clock()-t0<5 do task.wait(0.1) end
local function eu() for _,t in snap.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId then return t end end end
local h local t1=os.clock()
while os.clock()-t1<45 do task.wait(0.4) remote:FireServer('requestSnapshot') h=eu() if snap.combat.active and h and snap.combat.turnId==h.id then break end h=nil end
con:Disconnect() if not h then return 'sem vez' end return 'vez'"""

USAR = """local remote=game.ReplicatedStorage:WaitForChild('Mesa') local snap
local con=remote.OnClientEvent:Connect(function(k,d) if k=='snapshot' then snap=d end end)
remote:FireServer('requestSnapshot') local t0=os.clock() while not snap and os.clock()-t0<5 do task.wait(0.1) end
local h for _,t in snap.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId then h=t end end
local alvo,dist for _,t in snap.tokens do if t.criatura and not t.derrotado and (t.pv or 0)>0 then local d=math.max(math.abs(t.x-h.x),math.abs(t.z-h.z)) if not dist or d<dist then dist,alvo=d,t end end end
local dx=alvo.x>h.x and 1 or (alvo.x<h.x and -1 or 0) local dz=alvo.z>h.z and 1 or (alvo.z<h.z and -1 or 0)
local p={tokenId=h.id,habilidadeId='ability/agua/Principiante/@M@'}
if '@M@'=='escudo-de-agua' then p.x=h.x+dx*2 p.z=h.z+dz*2 elseif '@M@'=='lamina-de-gelo' or '@M@'=='nevoa-densa' then p.alvoId=h.id else p.alvoId=alvo.id end
local avisos={} local c2=remote.OnClientEvent:Connect(function(k,d) if k=='aviso' or k=='toast' or k=='erro' then table.insert(avisos,tostring(k)..':'..tostring(type(d)=='table' and (d.texto or d.mensagem or d[1]) or d)) end end)
remote:FireServer('usarHabilidade',p) task.wait(2.5) remote:FireServer('requestSnapshot') task.wait(0.5)
c2:Disconnect() con:Disconnect()
return 'usou dist='..tostring(dist)..' '..table.concat(avisos,' | ')"""

FIM = """local remote=game.ReplicatedStorage:WaitForChild('Mesa') local snap
local con=remote.OnClientEvent:Connect(function(k,d) if k=='snapshot' then snap=d end end)
remote:FireServer('requestSnapshot') local t0=os.clock() while not snap and os.clock()-t0<5 do task.wait(0.1) end
remote:FireServer('nextTurn',{expectedTurn=snap.combat.turn}) con:Disconnect() return 'rodada='..tostring(snap.combat.round)"""

print(q.lua_cliente(ESPERA))
dur = 9 + rodadas * 14
with Gravador(saida, dur):
    time.sleep(0.5)
    print(q.lua_cliente(USAR.replace("@M@", magia)))
    for i in range(rodadas):
        time.sleep(1.0)
        print(q.lua_cliente(FIM))
        print(q.lua_cliente(ESPERA))
        time.sleep(0.5)
        print("passou a vez", i + 1)
    time.sleep(3)
print(q.lua_cliente(FIM))  # passa a vez: a próxima magia começa com as Ações cheias
q.c.close()
print("video", saida)
