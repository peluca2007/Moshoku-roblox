local Terreno = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTerreno)
return {
 ["grade amostrada substitui layout fixo e devolve copia"] = function(t)
  local amostra = { { x = 10, z = 10 }, { x = 9, z = 11 } }
  local lista = Terreno.celulas("region/encounter/forest", amostra)
  t.eq(#lista, 2)
  t.eq(Terreno.chaves("region/encounter/forest", amostra)["6:8"], nil)
  t.eq(Terreno.chaves("region/encounter/forest", amostra)["10:10"], true)
  lista[1].x = 1
  t.eq(amostra[1].x, 10)
  t.eq(#Terreno.celulas("region/encounter/forest", {}), 0)
 end,
 ["spawn bloqueado, duplicado ou fora da grade impede inicio"] = function(t)
  local atores = { { x = 10, z = 10 }, { x = 9, z = 11 } }
  t.eq(Terreno.posicoesIniciaisLivres(atores, {}), true)
  t.eq(Terreno.posicoesIniciaisLivres(atores, { { x = 9, z = 11 } }), false)
  t.eq(Terreno.posicoesIniciaisLivres({ atores[1], atores[1] }, {}), false)
  t.eq(Terreno.posicoesIniciaisLivres({ { x = 21, z = 1 } }, {}), false)
 end,
 ["mesma amostra bloqueia movimento e visao"] = function(t)
  local amostra = { { x = 10, z = 10 } }
  t.eq(Terreno.chaves("region/encounter/patrol", amostra)["10:10"], true)
  t.eq(Terreno.visaoLivre(9, 10, 11, 10, Terreno.celulas("region/encounter/patrol", amostra)), false)
 end,
}
