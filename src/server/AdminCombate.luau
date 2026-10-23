-- Orquestração administrativa injetada. Não recebe dano, código ou regras do cliente.
local A = {}
function A.start(deps)
 local function alvos(p, alvo)
  local lista={}
  for id,t in deps.tokens do
   if alvo=="todos" or (alvo=="meus" and t.ownerUserId==p.UserId) or alvo==id then table.insert(lista,t) end
  end
  table.sort(lista,function(a,b) return a.id<b.id end)
  return lista
 end
 local function livre(t,x,z)
  if deps.bloqueada(x,z) then return false end
  for _,outro in deps.tokens do if outro~=t and outro.x==x and outro.z==z then return false end end
  return true
 end
 return function(p,id,args)
  if id=="acoes" then
   if not deps.combat.active then return "Não há combate em andamento." end
   local erro=deps.acoes()
   if erro then return erro end
   deps.mudou(); return nil,"Ações da vez atual recuperadas; limites de técnicas preservados."
  elseif id=="passar" then
   local erro=deps.passar(p)
   return erro, if not erro then "Vez avançada pelo administrador." else nil
  elseif id=="voltar" then
   local lista=alvos(p,"meus")
   if #lista==0 then return "semFicha" end
   -- Pré-valida todos os destinos antes de alterar qualquer ficha.
   local destinos,usadas={},{}
   for _,t in lista do
    local destino
    for z=1,20 do for x=1,20 do
     if not destino and (x==1 or z==1 or x==20 or z==20) and livre(t,x,z) and not usadas[x..","..z] then destino={x,z} end
    end end
    if not destino then return "Não há casa livre na borda da mesa." end
    usadas[destino[1]..","..destino[2]]=true; table.insert(destinos,destino)
   end
   for i,t in lista do deps.mover(t,destinos[i][1],destinos[i][2]) end
   deps.mudou(); return nil,"Suas fichas voltaram à borda da mesa sem gastar Ações."
  end
  local lista=alvos(p,args.alvo)
  if #lista==0 then return "Ficha não encontrada. Use meus, todos ou o ID de uma ficha." end
  if id=="mover" then
   if #lista~=1 then return "Escolha uma única ficha para mover." end
   if not livre(lista[1],args.x,args.z) then return "Destino ocupado ou bloqueado por parede/barreira." end
   deps.mover(lista[1],args.x,args.z)
  else
   for _,t in lista do
    if id=="curar" or id=="reviver" then
     if id=="curar" or t.pv<=0 then deps.pv(t,t.pvMax) end
    elseif id=="recursos" then
     t.mana=t.manaMax; if t.ptMax then t.pt=t.ptMax end; t.version+=1
    elseif id=="limpar" then deps.limpar(t)
    elseif id=="pv" then deps.pv(t,math.min(t.pvMax,args.valor))
    elseif id=="mana" then t.mana=math.min(t.manaMax,args.valor); t.version+=1
    elseif id=="pt" then if t.ptMax then t.pt=math.min(t.ptMax,args.valor);t.version+=1 end
    else return "Comando administrativo não implementado." end
   end
  end
  deps.mudou()
  return nil,string.format("ADM %s aplicado em %d ficha(s).",id,#lista)
 end
end
return A
