local Shared = game:GetService("ReplicatedStorage").Shared
local A = require(Shared.EncontroApresentacaoDados)
return {
 ["anúncio usa nomes das criaturas e não IDs"] = function(t)
  t.eq(A.inimigos({{kind="jogador", name="Pedro"},{kind="criatura", name="Goblin Batedor"}}), "Goblin Batedor")
 end,
 ["efeito só na transição viva para derrotada"] = function(t)
  local vivo = {{id="a",kind="criatura",pv=5}}
  local morto = {{id="a",kind="criatura",pv=0,defeated=true}}
  t.eq(#A.derrotados(vivo,morto),1)
  t.eq(#A.derrotados(morto,morto),0)
  t.eq(#A.derrotados(nil,morto),0)
  t.eq(#A.derrotados(vivo,{}),0)
 end,
 ["pulso termina em 0.8 segundos sem deslocamento residual"] = function(t)
  t.eq(A.pulso(0),0); t.eq(A.pulso(.8),0); t.eq(A.pulso(1),0)
  t.ok(math.abs(A.pulso(.4)-1)<.00001)
 end,
}
