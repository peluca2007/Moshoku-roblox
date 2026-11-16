"""CEN2: capturas do esgoto de vários ângulos. Requer Play em luta (qa.py esgoto_sala1 --manter-play).
  python tools/qa/esgoto_fotos.py [prefixo]
Salva em build/beleza/esgoto2/<prefixo>_<ângulo>.png. A câmera fica Scriptable só nas capturas e volta ao normal."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from qa_lib import Qa, RAIZ

prefixo = sys.argv[1] if len(sys.argv) > 1 else "r1"
# (nome, posição relativa à origem da arena, ponto para onde olha relativo)
ANGULOS = [
    ("geral", (0, 30, 80), (0, 12, -40)),
    ("canto", (-70, 26, 70), (20, 10, -40)),
    ("arco", (-40, 12, -40), (-40, 14, -86)),
    ("agua", (-40, 6, -62), (-40, 0, -90)),
    ("tocha", (-8, 15, -60), (-16, 16, -81)),
    ("abobada", (0, 6, 20), (0, 34, -40)),
    ("poca", (6, 7, 14), (4, 1, 4)),
]
q = Qa()
q.cenario = "esgoto2"
destino = os.path.join(RAIZ, "build", "beleza", "esgoto2")
os.makedirs(destino, exist_ok=True)
# O controlador da luta (BoardView) escreve na câmera original a cada quadro: usamos uma câmera nossa e devolvemos a original no fim.
q.lua_cliente("local o=workspace.CurrentCamera; local n=Instance.new('Camera'); n.Name='CamCap'; n.FieldOfView=o.FieldOfView; n.Parent=workspace; "
              "workspace.CurrentCamera=n; workspace:SetAttribute('CapCF', nil); "
              "game:GetService('RunService'):BindToRenderStep('CapEsgoto', Enum.RenderPriority.Last.Value + 1, function() "
              "local cf=workspace:GetAttribute('CapCF') local c=workspace.CurrentCamera if cf and c.Name=='CamCap' then c.CameraType=Enum.CameraType.Scriptable c.CFrame=cf end end) return 'ok'")
for nome, p, a in ANGULOS:
    q.lua_cliente("local o=require(game.ReplicatedStorage.Shared.MesaProtocol).BOARD.origin; workspace:SetAttribute('CapCF', CFrame.lookAt(o+Vector3.new(%s,%s,%s), o+Vector3.new(%s,%s,%s))); return 'ok'" % (p + a))
    time.sleep(1.2)
    f = q.foto("%s_%s" % (prefixo, nome))
    print(nome, f)
    if f.startswith("build"):
        shutil.copyfile(os.path.join(RAIZ, f), os.path.join(destino, "%s_%s.png" % (prefixo, nome)))
# A câmera original não é restaurada: pare o Play (ou rode qa.py de novo) depois das capturas.
q.c.close()
