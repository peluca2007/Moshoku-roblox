-- SOMENTE STUDIO: lê o catálogo completo para conferir cartas e custos.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Livro.Catalogo)
local X = require(Shared.Regras.Execucao)
local A = require(Shared.Regras.ArvoresPrincipiante)
return {
 ["árvores: IDs e custos do registro vêm do livro"] = function(t)
  for id, m in A.MECANICAS do
   local e = C.POR_ID[id]; t.ok(e ~= nil, "ID não existe: " .. id)
   if e then
    t.eq(m.acoes, e.data.actions.normal, id .. " ações")
    t.eq(m.pm, e.data.pmCost or 0, id .. " PM")
   end
  end
 end,
 ["árvores: toda carta Principiante está executável ou tem motivo"] = function(t)
  local arvores = { agua=true, vento=true, terra=true, cura=true, desintoxicacao=true, teorica=true, invocacao=true, ["deus-da-espada"]=true, ["deus-da-agua-corpo"]=true, ["deus-do-norte"]=true, ["armas-pesadas"]=true, ["cavalaria-e-escudos"]=true, arquearia=true }
  for _, e in C.POR_ESPECIE.ability do
   if arvores[e.data.treeId] and e.data.rank == "Principiante" then t.ok(A.MECANICAS[e.id] or A.INDISPONIVEIS[e.id], "Carta sem classificação: " .. e.id) end
  end
  for id in A.INDISPONIVEIS do t.ok(C.POR_ID[id], "Indisponível desconhecida: " .. id); t.eq(A.MECANICAS[id], nil) end
 end,
 ["árvores: pactos e ações do invocado conhecidos"] = function(t)
  for id in X.PACTOS do t.ok(C.POR_ID[id], id) end
  t.ok(X.MECANICAS["invocado/ajudar"]); t.ok(X.MECANICAS["invocado/ataque"]); t.ok(X.MECANICAS["invocado/derrubar"])
 end,
}
