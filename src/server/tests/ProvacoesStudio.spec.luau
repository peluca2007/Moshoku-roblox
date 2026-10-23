-- SOMENTE STUDIO: constru??o real, prompts e apresentação; não substitui caminhar/jogar com dois clientes.
local Mundo=require(script.Parent.Parent.Mundo.Provacoes)
local Shared=game:GetService("ReplicatedStorage").Shared
local C=require(Shared.Regras.ProvacaoComportas)
local Aparencia=require(script.Parent.Parent.Mundo.TreinadoresAparencia)
local PatioLayout=require(Shared.Mundo.PatioLadinoLayout)
return {
 ["T1 mundo real cria tres vigias, sino com hold e 25 pecas acessiveis por toque"]=function(t)
  local n=0
  local m=Mundo.criar({sino=function() n+=1 end,segurarSino=function() end,portao=function() end,girar=function() end})
  local ok,erro=pcall(function()
   t.eq(#m.guardas,3)
   local patio=m.pasta:FindFirstChild("Pátio do Ladino")
   t.ok(patio and patio:IsA("Model"))
   local contagem=0
   for _,p in patio:GetDescendants() do
    if p:IsA("BasePart") then contagem+=1 end
    t.ok(not p:IsA("LuaSourceContainer"),"nenhum script importado")
   end
   t.ok(contagem<600,"orçamento de peças do pátio")
   for i,g in m.guardas do
    t.eq(g.modelo.Parent,patio)
    t.eq(g.modelo:FindFirstChildOfClass("Humanoid").RigType,Enum.HumanoidRigType.R15)
    t.ok(g.modelo:FindFirstChild("UpperTorso")~=nil)
    t.ok(g.modelo:FindFirstChild("Elmo")~=nil)
    t.ok(g.modelo:FindFirstChild("Haste da lança")~=nil)
    t.eq(g.parte.Name,"HumanoidRootPart")
    local esperado=PatioLayout.guarda(i,0)
    t.ok(math.abs(g.parte.Position.X-esperado.x)<.01)
    t.ok(math.abs(g.parte.Position.Z-esperado.z)<.01)
   end
   for _,c in PatioLayout.COBERTURAS do
    local grupo=patio:FindFirstChild(c.id)
    local volume=grupo:FindFirstChild("Volume de cobertura")
    t.eq(volume.CanCollide,true); t.eq(volume.CanQuery,true)
    t.eq(volume.Size.Y,PatioLayout.ALTURA_COBERTURA)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances={volume}; params.RespectCanCollide=true
    local hit=workspace:Raycast(Vector3.new(c.x-10,4,c.z),Vector3.new(20,0,0),params)
    t.ok(hit and hit.Instance==volume,"cobertura bloqueia raycast na altura do olho")
   end
   t.eq(m.sino:FindFirstChildOfClass("ProximityPrompt").HoldDuration,1.5)
   for i=1,5 do for j=1,5 do
    local q=m.pecas[i][j]:FindFirstChildOfClass("ProximityPrompt")
    t.ok(q~=nil); t.eq(q.Enabled,false,"canais desligados fora da provação (não escondem o prompt da Mestra)")
    t.ok(q.MaxActivationDistance<=4.5,"só a peça sob o jogador responde")
   end end
   m.canais(true); t.eq(m.pecas[1][1]:FindFirstChildOfClass("ProximityPrompt").Enabled,true); m.canais(false)
   t.eq(m.sino:FindFirstChildOfClass("ProximityPrompt").RequiresLineOfSight,false,"sino sem linha de visão (telhado do campanário)")
   local grade,solucao=C.gerar(Random.new(13))
   m.grade(grade); m.grade(solucao)
   t.eq(C.bacias(solucao)[1],true)
   m.mostrarSino(false); t.eq(m.sino.Transparency,1)
   m.mostrarSino(true); t.eq(m.sino.Transparency,0)
   t.eq(n,0,"Construir e apresentar nao autoriza interacoes")
   t.eq(m.pasta:FindFirstChild("Plataforma da Mestra"),nil)
   local bacias=0
   for _,p in m.pasta:GetDescendants() do
    if p:IsA("BasePart") and string.match(p.Name,"^Bacia %d") then
     bacias+=1; t.eq(p.Shape,Enum.PartType.Cylinder)
    end
    if p.Name=="Borda do canal" or p.Name=="Pedra do canal" or p.Name=="Borda da bacia" then
     t.ok(p.Position.Y+p.Size.Y/2<=1.11)
    end
   end
   t.eq(bacias,3)
   t.ok(m.pasta:FindFirstChild("Tanque do jardim")~=nil)
   t.ok(m.pasta:FindFirstChild("Lugar da Mestra")~=nil)
   t.ok(m.pasta:FindFirstChild("Água da bica").Size.X<=6)
   for i=1,5 do for j=1,5 do
    local p=m.pecas[i][j]
    t.eq(p.Size.X,4); t.eq(p.Size.Z,4)
    t.eq(p.Material,Enum.Material.Slate); t.ok(p.Color.R<.3,"fundo do sulco escuro")
   end end
  end)
  m.destruir(); if not ok then error(erro,0) end
 end,
 ["T1 identidades distintas e contrato Blender opcional"]=function(t)
  local a,b=Instance.new("HumanoidDescription"),Instance.new("HumanoidDescription")
  local ok,erro=pcall(function()
  Aparencia.descrever(a,"agua"); Aparencia.descrever(b,"furtividade-e-armadilhas")
  t.ok(a.HeadColor~=b.HeadColor); t.ok(a.HeightScale~=b.HeightScale)
  t.eq(Aparencia.TRAJES["furtividade-e-armadilhas"][1].parte,"Head")
  end)
  a:Destroy(); b:Destroy(); if not ok then error(erro,0) end
 end,
}
