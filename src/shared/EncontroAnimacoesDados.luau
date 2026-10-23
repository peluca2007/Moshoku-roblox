-- Traduz somente resultados confirmados J2 ao contrato visual já usado pela mesa.
-- Não calcula dano, acerto, custo ou condição e não altera recibos/snapshots.
local A = {}
local function casa(ator)
 return ator and type(ator.x)=="number" and type(ator.z)=="number" and {ator.x,ator.z} or nil
end
function A.projetar(recibo, estado)
 if type(recibo)~="table" or type(estado)~="table" or recibo.encounterId~=estado.encounterId
  or type(recibo.version)~="number" or type(recibo.result)~="table" then return nil end
 local r, acao = recibo.result, recibo.action
 local id = r.abilityId
 if acao=="basic-attack" or acao=="creature-attack" then id="mesa/ataque-basico"
 elseif acao=="ranged-attack" then id="mesa/ataque-a-distancia"
 elseif type(acao)~="string" or acao:sub(1,8)~="ability:" then return nil end
 if type(id)~="string" then return nil end
 local atores={}
 for _,ator in ipairs(estado.actors or {}) do atores[ator.id]=ator end
 if not atores[recibo.actorId] then return nil end
 local efeito={habilidadeId=id,casterId=recibo.actorId,origem=casa(atores[recibo.actorId]),alvos={}}
 local function alvo(resultado, fallback)
  local alvoId=resultado.targetId or resultado.actorId or fallback
  if not atores[alvoId] then return end
  local ataque, resistencia=resultado.attack,resultado.resistance
  table.insert(efeito.alvos,{id=alvoId,casa=casa(atores[alvoId]),
   acertou=if type(ataque)=="table" then ataque.acertou else nil,
   critico=type(ataque)=="table" and ataque.critico==true,
   passou=type(resistencia)=="table" and resistencia.passou==true,
   dano=resultado.damageDealt or 0,cura=resultado.healing or 0,
   aplica=type(resultado.applies)=="table" and resultado.applies[1] or nil})
 end
 if type(r.targets)=="table" then
  for _,resultado in ipairs(r.targets) do alvo(resultado) end
 else alvo(r,recibo.targetId) end
 if #efeito.alvos==0 and not r.zone and not r.cells and not r.to then alvo({},recibo.actorId) end
 local zona=r.zone or r
 if type(zona.cells)=="table" then
  efeito.casas={}
  for _,c in ipairs(zona.cells) do table.insert(efeito.casas,{c.x or c[1],c.z or c[2]}) end
 end
 if type(r.x)=="number" and type(r.z)=="number" then efeito.centro={r.x,r.z}
 elseif type(zona.x)=="number" and type(zona.z)=="number" then efeito.centro={zona.x,zona.z}
 elseif type(recibo.targetId)=="string" then
  local x,z=recibo.targetId:match("^clarao:(%d+):(%d+)$")
  if x then efeito.centro={tonumber(x),tonumber(z)} end
 end
 if r.to and type(r.to.x)=="number" then efeito.trajeto={efeito.origem,{r.to.x,r.to.z}} end
 return efeito
end
return A
