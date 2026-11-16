"""PERS4: prancha comparativa de corpos (Personagem.CORPOS) com ModeloAparencia.criarR15 num ViewportFrame no Play.
Linhas = corpo, colunas = conjunto/raça (cada um de frente e 3/4). Uso: python tools/qa/pers4_comparar.py [corpo ...]
Saída: build/beleza/personagem/corpos_comparacao.jpg (Studio visível, src sincronizado, sem outro qa.py rodando)."""
import sys, time
import pers3b_lib as L
from qa_jogo import criar_personagem
from pers3b_grade import lua_tab
from PIL import Image

CORPOS = sys.argv[1:] or ["caixas", "homem", "mulher", "dawson"]
CONJUNTOS = [
    dict(raca="race/humano", roupas={}, cabelo="CabeloCurto1", barba="Barba1", cores={"cabelo": "CabeloCastanho"}),
    dict(raca="race/elfo", roupas={"cabeca": "LadinoCapuz", "costas": "LadinoCapa", "cintura": "LadinoCinto"}, cabelo="CabeloLongo1", cores={"cabelo": "CabeloLoiro"}),
    dict(raca="race/anao", roupas={"costas": "MestraManto", "cintura": "MestraObi"}, cabelo="CabeloTrancado1", barba="BarbaLonga1", cores={"cabelo": "CabeloRuivo"}),
    dict(raca="race/ogro", roupas={}, cabelo="CabeloEspetado1", cores={"cabelo": "CabeloPreto"}),
]
LUA = """local PG=game.Players.LocalPlayer.PlayerGui
local old=PG:FindFirstChild('XVP') if old then old:Destroy() end
local MA=require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild('ModeloAparencia',true))
local Pe=require(game.ReplicatedStorage.Shared.Aparencia.Personagem)
local Ap=require(game.ReplicatedStorage.Shared.Aparencia.Aparencia)
Pe.CORPO='%s'
local g=Instance.new('ScreenGui') g.Name='XVP' g.DisplayOrder=9999 g.IgnoreGuiInset=true g.Parent=PG
local v=Instance.new('ViewportFrame') v.Size=UDim2.fromScale(1,1) v.BackgroundColor3=Color3.fromRGB(60,55,50) v.Ambient=Color3.fromRGB(200,190,170) v.LightColor=Color3.fromRGB(220,210,190) v.LightDirection=Vector3.new(-1,-1,-1) v.Parent=g
local w=Instance.new('WorldModel') w.Parent=v
local cam=Instance.new('Camera') cam.FieldOfView=30 v.CurrentCamera=cam cam.Parent=v
local itens=%s
local x=0 local erros={}
for _,it in itens do
  for _,ang in {0,35} do
    local a=Ap.padrao(it.raca,3)
    a.barba=it.barba or 'BarbaNenhum' a.cabelo=it.cabelo a.roupas=it.roupas
    for k,c in it.cores do a.cores[k]=c end
    local ok,m=pcall(MA.criarR15,a,it.raca)
    if ok then m.Parent=w m:PivotTo(CFrame.new((3.5-x)*3.9,0,0)*CFrame.Angles(0,math.rad(ang),0)) else table.insert(erros,tostring(m)) end
    x+=1
  end
end
cam.CFrame=CFrame.lookAt(Vector3.new(0,3.0,-27),Vector3.new(0,3.0,0))
return 'ok '..table.concat(erros,'; ')"""

q = L.Qa(); q.cenario = "pers4"
try:
    try:
        q.play_parar(); time.sleep(3)
    except Exception:
        pass
    criar_personagem(q); time.sleep(4)
    linhas = []
    for c in CORPOS:
        print(c, q.lua_cliente(LUA % (c, lua_tab(CONJUNTOS)), timeout=180)); time.sleep(5)
        f = q.foto("corpo_" + c)
        linhas.append(Image.open(L.os.path.join(L.RAIZ, f)).crop((0, 235, 1411, 525)))
    W = Image.new("RGB", (1411, 290 * len(linhas)))
    for i, im in enumerate(linhas): W.paste(im, (0, 290 * i))
    saida = L.os.path.join(L.RAIZ, "build", "beleza", "personagem", "corpos_comparacao.jpg")
    W.convert("RGB").save(saida, quality=88); print(saida)
finally:
    try: q.play_parar()
    except Exception: pass
    q.c.close()
