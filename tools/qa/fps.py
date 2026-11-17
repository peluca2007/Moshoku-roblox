"""PERF1: mede o fps do cliente no Studio (RenderStepped) por N segundos e imprime média, p5 e contadores.
  python tools/qa/fps.py [rótulo] [segundos]   (Play ligado; janela do Studio em foco, sem gravação de tela)"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa

rotulo = sys.argv[1] if len(sys.argv) > 1 else "medida"
seg = float(sys.argv[2]) if len(sys.argv) > 2 else 10
JANELA = os.path.join(os.path.dirname(__file__), "studio_janela.ps1")
q = Qa()
def medir():
    subprocess.run(["powershell", "-File", JANELA, "-Foco"], capture_output=True)  # foco: janela sem foco cai para ~15 fps
    time.sleep(0.5)
    q.lua_cliente("workspace:SetAttribute('FpsFim', nil) local t={} local ini=os.clock() local ult=ini local c c=game:GetService('RunService').RenderStepped:Connect(function() local n=os.clock() t[#t+1]=n-ult ult=n if ult-ini>=%d then c:Disconnect() table.sort(t) local s=0 for _,v in t do s+=v end local p5=t[math.floor(#t*0.95)] workspace:SetAttribute('FpsFim', string.format('%%.1f %%.1f', #t/s, 1/p5)) end end) return 'ok'" % int(seg))
    fim = None
    for _ in range(int(seg * 6) + 40):
        time.sleep(1)
        fim = q.lua_cliente("return tostring(workspace:GetAttribute('FpsFim'))")
        if fim and fim != "nil":
            break
    return fim

fim = medir()
for _ in range(2):  # fps ~15 = Studio sem foco, não o jogo: refaz com foco
    if fim and float(fim.split()[0]) < 25:
        fim = medir()
info = q.lua_cliente("local n=0 local l=0 local pe=0 local sh=0 for _,d in workspace:GetDescendants() do if d:IsA('BasePart') then n+=1 elseif d:IsA('Light') then l+=1 if d.Shadows then sh+=1 end elseif d:IsA('ParticleEmitter') and d.Enabled then pe+=1 end end return 'partes='..n..' luzes='..l..' sombras='..sh..' emissores='..pe..' fisicaFPS='..string.format('%.0f', workspace:GetRealPhysicsFPS())")
print(rotulo, "| fps medio / p5:", fim, "|", info)
q.c.close()
