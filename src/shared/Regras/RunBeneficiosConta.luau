-- Benefícios entre runs: dados do livro somente leitura; nenhuma autoridade do cliente.
local Shared = game:GetService("ReplicatedStorage").Shared
local Racas = require(Shared.Livro.Dados.Racas)
local Itens = require(Shared.Livro.Dados.Itens)
local Beneficios = {}

-- Compra legada raca:rara libera o tier rara. Comum/incomum são a base;
-- lendária/mítica aguardam catálogo próprio. Não altera PA nem cálculo racial.
function Beneficios.racasLiberadas(conta)
 local liberadas = {}
 for _, raca in Racas do
  local tier = raca.data.tier
  if tier == "comum" or tier == "incomum" or (tier == "rara" and conta and conta.desbloqueios
   and conta.desbloqueios["raca:rara"] == true) then liberadas[raca.id] = true end
 end
 return liberadas
end

-- Verdadeiro só para raça conhecida e ainda não liberada; raça ausente/inválida passa adiante
-- para o cálculo canônico recusar com a mensagem de sempre.
function Beneficios.racaBloqueada(conta, raceId)
	for _, raca in Racas do
		if raca.id == raceId then
			return Beneficios.racasLiberadas(conta)[raceId] ~= true
		end
	end
	return false
end

Beneficios.KIT_EXTRA = table.freeze({
 table.freeze({ compraId = "item:pocao-menor", itemId = "item/pocao_menor_cura", quantidade = 1 }),
})

-- Registros persistíveis no invent?rio existente; ID estável por run impede
-- duplicar no recálculo/replay ou repor item vendido após reconexão.
function Beneficios.itensIniciais(conta, runId)
 local registros = {}
 if not runId then return registros end
 for _, extra in Beneficios.KIT_EXTRA do
  if conta and conta.desbloqueios and conta.desbloqueios[extra.compraId] == true then
   for i = 1, extra.quantidade do
    table.insert(registros, { itemId = extra.itemId, sourceLocalId = "conta-" .. runId .. "-pocao-" .. i })
   end
  end
 end
 return registros
end

function Beneficios.materializar(registro)
 for _, item in Itens do
  if item.id == registro.itemId then
   return { sourceLocalId = registro.sourceLocalId, name = item.data.name, type = item.data.type,
    equipped = false, description = item.data.description, baseDie = item.data.baseDie,
    damageAttribute = item.data.damageAttribute, armorClassBonus = item.data.acBonus }
  end
 end
 return nil
end
-- Recalcular a criação conserva entregas anteriores e baixas, sem conceder novamente.
function Beneficios.prepararInventario(inicial, registros, baixas, conta, runId)
 local inventario, persistidos, ids, entregues, removidos = {}, {}, {}, {}, {}
 for _, id in baixas or {} do removidos[id] = true end
 for _, item in inicial or {} do
  if not removidos[item.sourceLocalId] then table.insert(inventario, table.clone(item)); ids[item.sourceLocalId] = true end
 end
 for _, registro in registros or {} do
  table.insert(persistidos, table.clone(registro)); entregues[registro.sourceLocalId] = true
  if not ids[registro.sourceLocalId] and not removidos[registro.sourceLocalId] then
   local item = Beneficios.materializar(registro)
   if not item then return nil, nil, "Item persistido fora do catálogo." end
   table.insert(inventario, item); ids[registro.sourceLocalId] = true
  end
 end
 for _, registro in Beneficios.itensIniciais(conta, runId) do
  if not entregues[registro.sourceLocalId] and not removidos[registro.sourceLocalId] then
   local item = Beneficios.materializar(registro)
   if not item then return nil, nil, "Kit extra indisponível no catálogo." end
   table.insert(inventario, item); table.insert(persistidos, registro)
  end
 end
 return inventario, persistidos
end
return Beneficios
