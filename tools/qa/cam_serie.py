"""CAM1: grava a série da câmera do cliente (Heartbeat) durante uma ação e analisa com camera_saltos.
  ini = iniciar(q)            # liga a gravação no cliente (traz a janela do Studio para o primeiro plano)
  ok = parar(q, "saida.csv", "rótulo")   # desliga, salva o CSV e imprime o relatório; True se não houver salto"""
import os, subprocess, time
from camera_saltos import ler, relatorio

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def iniciar(q):
    subprocess.run(["powershell", "-File", os.path.join(RAIZ, "tools", "qa", "studio_janela.ps1"), "-Foco"], capture_output=True)
    time.sleep(1)
    # o tremor do contato (Efeitos.tremorCFrame) é um impulso intencional DEPOIS do filtro da câmera: fica de fora para
    # provar só o caminho dos planos; o jogador o desliga pelo mesmo atributo
    q.lua_cliente("game.Players.LocalPlayer:SetAttribute('SemTremor', true) return 'ok'")
    q.lua_cliente("""local RS=game:GetService('RunService') shared.CamSerie={} local t0=os.clock()
shared.CamCon=RS.Heartbeat:Connect(function() local c=workspace.CurrentCamera local p,l=c.CFrame.Position,c.CFrame.LookVector
table.insert(shared.CamSerie,string.format('%.4f,%.3f,%.3f,%.3f,%.4f,%.4f,%.4f',os.clock()-t0,p.X,p.Y,p.Z,l.X,l.Y,l.Z)) end) return 'gravando'""")


def parar(q, caminho, rotulo="", max_vel=45.0, max_giro=260.0, ignorar=0.0):
    n = int(q.lua_cliente("shared.CamCon:Disconnect() game.Players.LocalPlayer:SetAttribute('SemTremor', nil) return tostring(#shared.CamSerie)"))
    linhas = []
    for i in range(1, n + 1, 150):
        linhas += q.lua_cliente("local o={} for i=%d,math.min(%d,#shared.CamSerie) do table.insert(o,shared.CamSerie[i]) end return table.concat(o,';')" % (i, i + 149)).split(";")
    os.makedirs(os.path.dirname(os.path.abspath(caminho)), exist_ok=True)
    with open(caminho, "w", encoding="utf-8") as f:
        f.write("t,x,y,z,lx,ly,lz" + chr(10) + chr(10).join(linhas) + chr(10))
    return relatorio(ler(caminho), max_vel, max_giro, rotulo, ignorar)
