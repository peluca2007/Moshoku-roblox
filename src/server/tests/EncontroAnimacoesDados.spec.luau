local A=require(game:GetService("ReplicatedStorage").Shared.EncontroAnimacoesDados)
local function estado() return {encounterId="e",actors={{id="p",x=10,z=10},{id="c",x=11,z=10}}} end
return {
 ["dano, erro e crítico vêm do resultado confirmado"] = function(t)
  local s=estado()
  local r={encounterId="e",version=2,actorId="p",targetId="c",action="ability:teste",
   result={abilityId="ability/fogo/Principiante/brasa",damageDealt=12,attack={acertou=false,critico=false}}}
  local a=A.projetar(r,s)
  t.eq(a.alvos[1].dano,12);t.eq(a.alvos[1].acertou,false);t.eq(a.alvos[1].id,"c")
  t.eq(r.result.damageDealt,12);t.eq(s.actors[1].x,10)
 end,
 ["outro encontro e movimentos não viram ataques"] = function(t)
  t.eq(A.projetar({encounterId="outro",version=1,result={}},estado()),nil)
  t.eq(A.projetar({encounterId="e",version=2,actorId="p",action="move",result={}},estado()),nil)
 end,
 ["múltiplos alvos, cura e zona conservam posições"] = function(t)
  local a=A.projetar({encounterId="e",version=3,actorId="p",action="ability:teste",result={abilityId="x",
   targets={{actorId="c",healing=4,resistance={passou=true}}},zone={cells={{x=12,z=10}}}}},estado())
  t.eq(a.alvos[1].cura,4);t.eq(a.alvos[1].passou,true);t.eq(a.casas[1][1],12)
 end,
 ["ataque básico usa a coreografia existente"] = function(t)
  local a=A.projetar({encounterId="e",version=3,actorId="c",targetId="p",action="creature-attack",
   result={damageDealt=3,attack={acertou=true,critico=true}}},estado())
  t.eq(a.habilidadeId,"mesa/ataque-basico");t.eq(a.alvos[1].critico,true)
 end,
 ["centro do Clarão não volta ao conjurador"] = function(t)
  local a=A.projetar({encounterId="e",version=2,actorId="p",targetId="clarao:13:12",action="ability:teste",
   result={abilityId="ability/fogo/Principiante/clarao",targets={}}},estado())
  t.eq(a.centro[1],13);t.eq(a.centro[2],12)
 end,
}
