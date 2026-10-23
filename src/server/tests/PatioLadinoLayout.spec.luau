local Shared = game:GetService("ReplicatedStorage").Shared
local P=require(Shared.Mundo.PatioLadinoLayout)
local L=require(Shared.Mundo.TreinadoresLayout)
local Cone=require(Shared.Regras.VisaoCone)
local function segmento(a,b,visitar)
 local n=math.ceil(math.sqrt((b.x-a.x)^2+(b.z-a.z)^2)*4)
 for k=0,n do visitar(a.x+(b.x-a.x)*k/n,a.z+(b.z-a.z)*k/n) end
end
local function caminhoSeguro(tempo,alcance)
 local function livre(x,z)
  if not P.dentro(x,z,2) or P.ocupado(x,z,1.1) then return false end
  for i=1,#P.ROTAS do
   local o,f=P.guarda(i,tempo)
   -- Critério mais estrito: nem usa a proteção das coberturas contra visão.
   if Cone.dentro(o,f,{x=x,z=z},alcance,70) then return false end
  end
  return true
 end
 local fila={{x=L.ENTRADA.x,z=L.ENTRADA.z}}
 if not livre(fila[1].x,fila[1].z) then return false end
 local vistos={[fila[1].x..":"..fila[1].z]=true}
 local indice=1
 while indice<=#fila do
  local p=fila[indice]; indice+=1
  if p.x==L.SINO.x and p.z==L.SINO.z then return true end
  for _,d in {{1,0},{-1,0},{0,1},{0,-1}} do
   local x,z=p.x+d[1],p.z+d[2]
   local chave=x..":"..z
   if not vistos[chave] then
    vistos[chave]=true
    -- Aresta inteira, não somente centro das células.
    if livre(x,z) and livre((x+p.x)/2,(z+p.z)/2) then table.insert(fila,{x=x,z=z}) end
   end
  end
 end
 return false
end
return {
 ["T1d guardas percorrem rotas com folga corporal sem atravessar coberturas"]=function(t)
  for tempo=0,48,.125 do for i=1,#P.ROTAS do
   local p,f=P.guarda(i,tempo)
   t.ok(P.dentro(p.x,p.z,2.2),"patrulha fora do muro")
   t.ok(not P.ocupado(p.x,p.z,1.2),"patrulha cruza cobertura")
   t.ok(math.abs(f.x*f.x+f.z*f.z-1)<.0001)
  end end
 end,
 ["T1d quatro rotas fisicas com largura de avatar ligam entrada ao sino"]=function(t)
  for _,x in {49,62,68,81} do
   local rota={L.ENTRADA,{x=x,z=-235},{x=x,z=-265},L.SINO}
   for i=2,#rota do segmento(rota[i-1],rota[i],function(px,pz)
    t.ok(P.dentro(px,pz,2),"rota fora do patio")
    t.ok(not P.ocupado(px,pz,1.1),"rota bloqueada")
   end) end
  end
 end,
 ["T1d existe instante amostrado com rota inteira fora de todos os cones estaticos"]=function(t)
  local encontrou=false
  for tempo=0,24,.5 do
   if caminhoSeguro(tempo,20) then encontrou=true; break end
  end
  t.ok(encontrou,"nenhuma rota em 49 instantes, alcance em pe 20 e angulo 70")
 end,
 ["T1d coberturas altas e muro preservam portao sino e clareira autorizada"]=function(t)
  t.ok(P.ALTURA_COBERTURA>=3.5)
  -- Raio do olho: HRP ~3 + 1 no raycast atual; volume chega a 5,5.
  t.ok(P.ALTURA_COBERTURA>=5)
  for _,p in {L.PORTAO,L.ENTRADA,L.SINO} do t.ok(not P.ocupado(p.x,p.z,2)) end
  for _,c in P.COBERTURAS do
   t.ok(P.dentro(c.x-c.sx/2,c.z-c.sz/2,2))
   t.ok(P.dentro(c.x+c.sx/2,c.z+c.sz/2,2))
  end
  local zona=L.ZONA_PLANA_NECESSARIA
  t.ok(math.abs(L.PATIO.x-zona.x)+L.PATIO.sx/2<=zona.sx/2)
  t.ok(math.abs(L.PATIO.z-zona.z)+L.PATIO.sz/2<=zona.sz/2)
  t.ok(L.PORTAO.z>L.PATIO.z,"portao voltado para vila")
 end,
}
