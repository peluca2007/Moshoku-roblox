-- Apresentação das comportas; a grade pura continua sendo a única regra de fluxo.
local Shared=game:GetService("ReplicatedStorage").Shared
local Layout=require(Shared.Mundo.TreinadoresLayout)
local T=require(Shared.Mundo.TerrenoLayout)
local Canais=require(Shared.Regras.ProvacaoComportas)
local Montar=require(script.Parent.MontarModelo)
local Props=require(script.Parent.Props)
local Tween=game:GetService("TweenService")
local M={}
function M.criar(pasta,girar,prompt)
 local base=Layout.grade()
 local pedra=Color3.fromRGB(202,199,177)
 local escuro=Color3.fromRGB(35,57,61)
 local azul=Color3.fromRGB(46,211,201)
 local function parte(nome,x,y,z,sx,sy,sz,cor,pai)
  local p=Instance.new("Part")
  p.Name,p.Size,p.Position=nome,Vector3.new(sx,sy,sz),Vector3.new(x,y,z)
  p.Anchored,p.Material,p.Color,p.Parent=true,Enum.Material.Slate,cor or pedra,pai or pasta
  return p
 end
 local function agua(p)
  p.Material,p.Transparency,p.CanCollide=Enum.Material.Glass,.3,false
  p.CanTouch,p.CanQuery=false,false
  p.CastShadow=false
 end
 local function luz(p)
  local l=Instance.new("PointLight",p); l.Color=azul; l.Brightness=.25; l.Range=5
 end
 -- Um único tanque baixo une a composição, sem esconder os sulcos de 0,4 stud.
 parte("Tanque do jardim",base.x+1,.15,base.z,28,.3,24)
 for _,z in {-11.5,11.5} do parte("Moldura do jardim",base.x+1,.45,base.z+z,28,.3,1) end
 for _,x in {-12.5,14.5} do parte("Moldura do jardim",base.x+x,.45,base.z,1,.3,22) end
 local m=Layout.mestra()
 parte("Lugar da Mestra",m.x,.3,m.z,6,.6,5)
 local rota=Layout.acessoAgua()
 for n=2,#rota do
  local a,b=rota[n-1],rota[n]
  local passos=math.ceil(math.sqrt((b.x-a.x)^2+(b.z-a.z)^2)/3)
  for k=1,passos do
   local x,z=a.x+(b.x-a.x)*k/passos,a.z+(b.z-a.z)*k/passos
   parte("Pedra do caminho",x,T.altura(x,z)+.1,z,2.5,.2,2.5)
  end
 end
 local cap,entrada=Layout.captacao()
 local comprimento=entrada.x-cap.x
 parte("Leito da bica",(cap.x+entrada.x)/2,.25,cap.z,comprimento,.2,1.8,escuro)
 for _,lado in {-1,1} do
  parte("Borda da bica",(cap.x+entrada.x)/2,.55,cap.z+lado*.9,comprimento,.5,.3)
 end
 local fluxo=parte("Água da bica",(cap.x+entrada.x)/2,.4,cap.z,comprimento,.1,1.4,azul)
 agua(fluxo); luz(fluxo)
 -- Cabeça na água, coluna/aqueduto pequeno até a cota do terraço.
 parte("Cabeça da bica",cap.x,-.4,cap.z,2.4,2.4,2.4)
 local boca=parte("Boca da bica",cap.x+.8,.4,cap.z,1.1,.15,1.4,azul); agua(boca)
 local pecas,visuais,bacias,prompts={},{},{},{}
 for i=1,5 do
  pecas[i],visuais[i]={},{}
  for j=1,5 do
   local x,z=base.x+(j-3)*4,base.z+(i-3)*4
   local p=parte("Canal "..i..":"..j,x,.3,z,4,.2,4,escuro)
   pecas[i][j]=p
   local v=Instance.new("Folder",pasta); v.Name="CanalVisual"; visuais[i][j]=v
   -- Desligado até a provação começar: 25 prompts "E" a 4 studs da Mestra escondiam o dela (OnePerButton, vence o mais próximo).
   local q=prompt(p,"Girar 90°",0,function(player) girar(player,i,j,p) end)
   -- 4,2 (3D, ~3,1 na horizontal): só a peça sob o jogador responde; com 8 a CameraMundo elegia a peça mais próxima da câmera, não da personagem.
   q.MaxActivationDistance=4.2; q.Enabled=false; table.insert(prompts,q)
  end
 end
 for k,i in {1,3,5} do
  local x,z=base.x+12,base.z+(i-3)*4
  local fundo=parte("Bacia "..k,x,.3,z,.6,4,4)
  fundo.Shape=Enum.PartType.Cylinder; fundo.CFrame*=CFrame.Angles(0,0,math.pi/2)
  for n=0,19 do
   local a=n*math.pi/10
   local p=parte("Borda da bacia",x+math.cos(a)*1.85,.7,z+math.sin(a)*1.85,.4,.8,.7)
   p.CFrame*=CFrame.Angles(0,-a,0)
  end
  local p=parte("Água da bacia",x,.62,z,.08,3.3,3.3,azul)
  p.Shape=Enum.PartType.Cylinder; p.CFrame*=CFrame.Angles(0,0,math.pi/2)
  agua(p); p.Transparency=1; luz(p)
  bacias[k]={parte=p,seca=p.CFrame,cheia=p.CFrame+Vector3.new(0,.3,0)}
 end
 -- Mesmos modelos locais revisados do mundo, sem assets ou scripts novos.
 for _,d in {{"Juncos1",-14,-9,.6},{"Juncos1",-14,9,.7},{"Rochedo1",-13,-13,.35},{"Rochedo2",13,-14,.3},{"Lampiao",6,-14,.8}} do
  if Montar.existe(d[1]) then
   local x,z=base.x+d[2],base.z+d[3]
   local modelo=Montar.montar(d[1],pasta,CFrame.new(x,T.altura(x,z),z),d[4])
   Props.aplicarMateriaisELuzes(modelo,d[1])
   for _,p in modelo:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end
  end
 end
 local api={pecas=pecas}
 function api.ativar(ligado) for _,q in prompts do q.Enabled=ligado end end
 function api.grade(grade)
  local ligados,profundidades=Canais.conexoes(grade)
  for i=1,5 do for j=1,5 do
   local v,p=visuais[i][j],pecas[i][j]
   v:ClearAllChildren()
   local x,z=p.Position.X,p.Position.Z
   local ab=Canais.aberturas(grade[i][j])
   -- Cantos claros deixam um sulco escuro de 1,4, fundo .4 e borda .8.
   for _,dx in {-1,1} do for _,dz in {-1,1} do
    parte("Pedra do canal",x+dx*1.35,.6,z+dz*1.35,1.3,.4,1.3,pedra,v)
   end end
   -- Água central e braços só nas peças conectadas à fonte.
   local centro=parte("Fluxo",x,.51,z,1.4,.12,1.4,azul,v); agua(centro); centro.Transparency=1
   local function encher(q)
    if ligados[i..":"..j] then
     Tween:Create(q,TweenInfo.new(.25,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,(profundidades[i..":"..j] or 0)*.025),{Transparency=.3}):Play()
    end
   end
   encher(centro)
   for d=1,4 do
    local dx,dz=0,0
    if d==1 then dz=-1 elseif d==2 then dx=1 elseif d==3 then dz=1 else dx=-1 end
    if ab[d] then
     local q=parte("Fluxo",x+dx*1.35,.51,z+dz*1.35,if dx==0 then 1.4 else 1.3,.12,if dz==0 then 1.4 else 1.3,azul,v)
     agua(q); q.Transparency=1; encher(q)
    else
     parte("Borda do canal",x+dx*1.35,.6,z+dz*1.35,if dx==0 then 1.4 else 1.3,.4,if dz==0 then 1.4 else 1.3,pedra,v)
    end
   end
  end end
  for k,cheia in Canais.bacias(grade) do
   local b=bacias[k]
   Tween:Create(b.parte,TweenInfo.new(.35),{Transparency=if cheia then .3 else 1,CFrame=if cheia then b.cheia else b.seca}):Play()
  end
 end
 api.grade(Canais.gerar(Random.new(13)))
 return api
end
return M
