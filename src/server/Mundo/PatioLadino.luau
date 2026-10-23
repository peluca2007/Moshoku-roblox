-- Somente construção do pátio; prompts/resultado pertencem a Provacoes/Servico.
local Shared = game:GetService("ReplicatedStorage").Shared
local L=require(Shared.Mundo.TreinadoresLayout)
local P=require(Shared.Mundo.PatioLadinoLayout)
local Montar=require(script.Parent.MontarModelo)
local Guardas=require(script.Parent.GuardasLadino)
local M={}
function M.criar(pai)
 local patio=Instance.new("Model",pai); patio.Name="Pátio do Ladino"
 patio:SetAttribute("AreaId","region/vila/provacao/ladino")
 patio:SetAttribute("LimitePecas",600)
 local madeira=Color3.fromRGB(101,68,42)
 local pedra=Color3.fromRGB(115,110,95)
 local function parte(nome,x,y,z,sx,sy,sz,material,cor)
  local p=Instance.new("Part")
  p.Name=nome; p.Size=Vector3.new(sx,sy,sz); p.Position=Vector3.new(x,y,z)
  p.Material=material or Enum.Material.WoodPlanks; p.Color=cor or madeira
  p.Anchored=true; p.Parent=patio
  return p
 end
 -- Ajuste pela caixa exportada: pivôs de props podem estar na base ou no centro.
 local function modelo(nome,x,y,z,escala)
  local dados=require(script.Parent.Modelos:FindFirstChild(nome))
  local cf=CFrame.new(x-dados.centro[1]*escala,y+(dados.caixa[2]/2-dados.centro[2])*escala,z-dados.centro[3]*escala)
  local m=Montar.montar(nome,patio,cf,escala)
  for _,p in m:GetDescendants() do if p:IsA("BasePart") then
   p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
  end end
  return m
 end
 local function luz(p,alcance,brilho)
  local l=Instance.new("PointLight",p)
  l.Color=Color3.fromRGB(255,191,104); l.Range=alcance; l.Brightness=brilho
 end
 -- Muro misto contínuo, com contrafortes de madeira e base de pedra.
 for _,x in {45.8,84.2} do
  parte("Muro lateral",x,3,-250,1.6,6,40,Enum.Material.WoodPlanks)
  parte("Alicerce lateral",x,.8,-250,1.8,1.6,40,Enum.Material.Cobblestone,pedra)
  for z=-268,-232,6 do parte("Esteio lateral",x,3,z,1.9,6,1,Enum.Material.Wood) end
 end
 parte("Muro do fundo",65,3,-269.2,40,6,1.6,Enum.Material.Cobblestone,pedra)
 for _,x in {52.5,77.5} do
  parte("Muro da entrada",x,3,-230.8,15,6,1.6,Enum.Material.Cobblestone,pedra)
 end
 -- Portão aberto: folhas junto às ombreiras, passagem central livre de oito studs.
 for _,x in {60.5,69.5} do
  parte("Ombreira do portão",x,3.5,-230.8,1,7,1.5,Enum.Material.Wood)
  parte("Folha aberta do portão",x,2.8,-233, .4,5.6,4.4)
  local lamp=modelo("Lampiao",x,0,-228.5,.65)
  for _,p in lamp:GetDescendants() do if p:IsA("BasePart") and p.Name=="Luz" then luz(p,12,.5) end end
 end
 parte("Verga do portão",65,6.8,-230.8,10,.6,1.5,Enum.Material.Wood)
 local gate=parte("Portão",L.PORTAO.x,.08,L.PORTAO.z,7,.12,2,Enum.Material.Ground,Color3.fromRGB(143,117,79))
 gate.CanCollide=false
 -- Quatro corredores longitudinais e três travessas; terra/feno contrastam com grama.
 for _,x in {49,62,68,81} do
  local p=parte("Terra pisada",x,.025,-250,3,.05,34,Enum.Material.Ground,Color3.fromRGB(111,91,63))
  p.CanCollide=false
 end
 for _,z in {-235,-245,-255,-265} do
  local p=parte("Travessa de terra",65,.03,z,34,.05,3,Enum.Material.Ground,Color3.fromRGB(124,104,73))
  p.CanCollide=false
 end
 for _,c in P.COBERTURAS do
  local grupo=Instance.new("Model",patio); grupo.Name=c.id
  grupo:SetAttribute("CoberturaLadino",true); grupo:SetAttribute("AlturaVisao",P.ALTURA_COBERTURA)
  -- Colisão conservadora intencional: o mesmo volume bloqueia passagem e raycast.
  local volume=parte("Volume de cobertura",c.x,P.ALTURA_COBERTURA/2,c.z,c.sx,P.ALTURA_COBERTURA,c.sz)
  volume.Transparency=1; volume.Parent=grupo
  if c.tipo=="Varal" then
   for _,dx in {-3.7,3.7} do
    local poste=parte("Poste do varal",c.x+dx,3,c.z,.25,6,.25,Enum.Material.Wood); poste.Parent=grupo
   end
   local corda=parte("Corda do varal",c.x,5.7,c.z,8,.08,.08,Enum.Material.Fabric); corda.Parent=grupo
   for _,dz in {-1.9,1.9} do
    local pano=parte("Lençóis opacos",c.x,2.8,c.z+dz,8,5.5,.12,Enum.Material.Fabric,Color3.fromRGB(206,191,156)); pano.Parent=grupo
   end
  elseif c.tipo=="Barril" then
   for _,dx in {-2.4,0,2.4} do
    for nivel=0,1 do local m=modelo("Barril",c.x+dx,nivel*2.75,c.z,.84); m.Parent=grupo end
   end
  elseif c.tipo=="Fardo1" then
   for _,dx in {-2.6,0,2.6} do
    for nivel=0,2 do local m=modelo("Fardo1",c.x+dx,nivel*1.84,c.z,.97); m.Parent=grupo end
   end
  elseif c.tipo=="Carroca" then
   local m=modelo("Carroca",c.x,0,c.z,.83); m.Parent=grupo
   local carga=parte("Carga alta da carroça",c.x,4,c.z,6,3,3,Enum.Material.WoodPlanks); carga.Parent=grupo
  else
   local m=modelo("Caixotes",c.x,0,c.z,.85); m.Parent=grupo
   local topo=parte("Caixas superiores",c.x,5,c.z,5,1,2.5); topo.Parent=grupo
  end
  local mancha=parte("Palha caída",c.x,.04,c.z,c.sx+1,.06,c.sz+1,Enum.Material.Sand,Color3.fromRGB(167,140,73))
  mancha.CanCollide=false
 end
 -- Campanário aberto; pé-direito suficiente para chegar por qualquer lado.
 for _,dx in {-2,2} do for _,dz in {-1.5,1.5} do
  parte("Poste do campanário",L.SINO.x+dx,3.25,L.SINO.z+dz,.4,6.5,.4,Enum.Material.Wood)
 end end
 parte("Trave do sino",65,6,-266,4.5,.3,.4,Enum.Material.Wood)
 for _,sinal in {-1,1} do
  local telha=parte("Telhado do campanário",65+sinal*1.2,6.8,-266,2.8,.25,4.5,Enum.Material.WoodPlanks,Color3.fromRGB(74,49,35))
  telha.CFrame*=CFrame.Angles(0,0,math.rad(-sinal*23))
 end
 parte("Suspensão do sino",65,5.2,-266,.12,1.4,.12,Enum.Material.Metal,Color3.fromRGB(70,65,49))
 local sino=parte("Sino",65,4.1,-266,1.6,1.6,1.6,Enum.Material.Metal,Color3.fromRGB(224,181,58))
 sino.Shape=Enum.PartType.Ball; sino.CanCollide=false
 local aro=parte("Boca do sino",65,3.5,-266,.2,1.9,1.9,Enum.Material.Metal,sino.Color)
 aro.Shape=Enum.PartType.Cylinder; aro.CFrame*=CFrame.Angles(0,0,math.pi/2); aro.CanCollide=false
 luz(sino,9,.35)
 local guardas={}
 for i=1,#P.ROTAS do local g=Guardas.criar(patio,i); if g then table.insert(guardas,g) end end
 local api={modelo=patio,sino=sino,gate=gate,guardas=guardas}
 function api.mostrarSino(tem)
  sino.Transparency=if tem then 0 else 1; aro.Transparency=sino.Transparency
  sino:FindFirstChildOfClass("PointLight").Enabled=tem
 end
 return api
end
return M
