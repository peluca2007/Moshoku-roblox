import time
from PIL import Image
from qa_lib import Qa
CROP=(250,90,730,520)
def serie(q, nome, n=5, passo=1.1):
    ims=[]
    for i in range(n):
        f=q.foto("%s%d"%(nome,i)); ims.append(Image.open(os.path.join(RAIZ,f)).crop(CROP)); time.sleep(passo)
    W=Image.new("RGB",((CROP[2]-CROP[0])*n,CROP[3]-CROP[1]))
    for i,x in enumerate(ims): W.paste(x,(i*(CROP[2]-CROP[0]),0))
    d=os.path.join(RAIZ,"build","qa","pers3b"); os.makedirs(d,exist_ok=True)
    W.save(os.path.join(d,nome+".png")); return nome
from qa_lib import RAIZ, os

LUA_VP = """local PG=game.Players.LocalPlayer.PlayerGui
local old=PG:FindFirstChild('XVP') if old then old:Destroy() end
local v0=PG.CriacaoRapida.Fundo.Moldura.Conteudo.Previa.Previa3D
local P=v0:FindFirstChild('Player',true)
local g=Instance.new('ScreenGui') g.Name='XVP' g.DisplayOrder=999 g.IgnoreGuiInset=true g.Parent=PG
local v=Instance.new('ViewportFrame') v.Size=UDim2.fromScale(1,1) v.BackgroundColor3=Color3.fromRGB(60,55,50) v.Ambient=v0.Ambient v.LightColor=v0.LightColor v.LightDirection=v0.LightDirection v.Parent=g
local w=Instance.new('WorldModel') w.Parent=v
local c=P:Clone() c.Parent=w
for _,d in c:GetDescendants() do if d:IsA('BasePart') then d.Anchored=true end end
local cam=Instance.new('Camera') cam.FieldOfView=%(fov)s v.CurrentCamera=cam cam.Parent=v
local alvo=Vector3.new(%(tx)s,%(ty)s,0)
cam.CFrame=CFrame.lookAt(alvo+Vector3.new(math.sin(math.rad(%(ang)s)),0,-math.cos(math.rad(%(ang)s)))*%(dist)s+Vector3.new(0,%(alt)s,0),alvo)
return 'ok'"""
def vista(q, nome, ang=0, dist=5, tx=0, ty=1.6, alt=0, fov=40):
    q.lua_cliente(LUA_VP % dict(ang=ang,dist=dist,tx=tx,ty=ty,alt=alt,fov=fov)); time.sleep(1.5)
    return q.foto(nome)
def montagem(arqs, saida, crop=None):
    ims=[Image.open(os.path.join(RAIZ,a)) for a in arqs]
    if crop: ims=[i.crop(crop) for i in ims]
    W=Image.new("RGB",(sum(i.width for i in ims),max(i.height for i in ims)))
    x=0
    for i in ims: W.paste(i,(x,0)); x+=i.width
    W.save(os.path.join(RAIZ,saida)); return saida
