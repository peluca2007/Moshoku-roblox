"""IMP4: fotografa o corte desenhado no ponto da criatura mais próxima, em câmera lenta (x10), por variante.
  python tools/qa/corte_teste.py [prefixo] [variantes, ex.: base A C]   (Play em luta)
Salva em build/beleza/impacto/<prefixo>_corte_<variante>.png"""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ
pref = sys.argv[1] if len(sys.argv) > 1 else "r4"
variantes = sys.argv[2:] or ["base", "A", "C"]
q = Qa()
q.cenario = "corte"
dest = os.path.join(RAIZ, "build", "beleza", "impacto")
os.makedirs(dest, exist_ok=True)
for v in variantes:
    q.lua_cliente("""workspace:SetAttribute('EscalaDeTempoDasCenas', 10) workspace:SetAttribute('QaCorteVar', %s)
local Fx=require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild('ImpactoFx',true))
local ch=game.Players.LocalPlayer.Character local melhor,bd
for _,m in workspace.CorposDeCriatura:GetChildren() do if m:IsA('Model') then local d=(m:GetPivot().Position-ch.HumanoidRootPart.Position).Magnitude if not bd or d<bd then melhor,bd=m,d end end end
local alvo=melhor:GetPivot().Position+Vector3.new(0,1.5,0)
local dir=alvo-ch.HumanoidRootPart.Position
Fx.corte(workspace.MesaEfeitosLocais,alvo,dir,Color3.fromRGB(255,232,170),false)
Fx.faiscas(workspace.MesaEfeitosLocais,alvo,Color3.fromRGB(255,232,170),8,false,dir)
return 'ok'""" % ("nil" if v == "base" else "'%s'" % v))
    time.sleep(0.6)
    f = q.foto("corte_%s" % v)
    if f.startswith("build"):
        shutil.copyfile(os.path.join(RAIZ, f), os.path.join(dest, "%s_corte_%s.png" % (pref, v)))
    print(v, f)
    time.sleep(2.2)
q.lua_cliente("workspace:SetAttribute('EscalaDeTempoDasCenas', nil) workspace:SetAttribute('QaCorteVar', nil) return 'ok'")
q.c.close()
