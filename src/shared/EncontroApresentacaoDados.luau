-- Projeção cosmética de snapshots confirmados; não decide fim, dano ou recompensa.
local A = {}
function A.inimigos(atores)
 local nomes = {}
 for _, ator in atores or {} do
  if ator.kind == "criatura" then table.insert(nomes, ator.name or "Inimigo") end
 end
 return table.concat(nomes, " · ")
end
function A.derrotados(antes, depois)
 local vivos, ids = {}, {}
 for _, ator in antes or {} do
  if ator.kind == "criatura" and (ator.pv or 0) > 0 and not ator.defeated then vivos[ator.id] = true end
 end
 for _, ator in depois or {} do
  if vivos[ator.id] and (ator.defeated or (ator.pv or 0) <= 0) then table.insert(ids, ator.id) end
 end
 return ids
end
function A.pulso(tempo)
 if tempo < 0 or tempo >= .8 then return 0 end
 return math.sin(tempo / .8 * math.pi) -- retorna à pose original sem alterar o enquadramento
end
return A
