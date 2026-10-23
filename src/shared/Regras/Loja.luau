-- Regra pura da loja (Cap. 5, §2; fonte: ../Moshoku tensei rpg/src/data/shopItems.ts e
-- src/lib/lootGenerator.ts). Opera sobre `data` das entradas de shared/Livro/Dados/Itens:
-- { id, name, category, type, description, guildRankRequired, price, aVenda, disponibilidade?,
--   baseDie?, damageAttribute?, acBonus? }. Sem Instances nem rede; ouro é inteiro (PO).
local Loja = {}

Loja.RANKS = table.freeze({ "F", "E", "D", "C", "B", "A", "S" })
Loja.RANK_INICIAL = "F"

local INDICE = {}
for i, r in ipairs(Loja.RANKS) do INDICE[r] = i end

local CATEGORIAS = table.freeze({ "arma", "armadura", "aventura", "pocao", "veneno", "ferramenta-magica", "encantamento", "tralha" })
local ORDEM = {}
for i, c in ipairs(CATEGORIAS) do ORDEM[c] = i end

local function inteiro(v)
	return type(v) == "number" and v == v and v % 1 == 0 and v >= 0
end

function Loja.rankValido(rank)
	return INDICE[rank] ~= nil
end

function Loja.atingeRank(tem, exige)
	return INDICE[tem] ~= nil and INDICE[exige] ~= nil and INDICE[tem] >= INDICE[exige]
end

-- À venda na prateleira: disponibilidade "loja" (ausente = loja), com preço, e rank mínimo cumprido.
-- Itens "restrito" (drop/contrabando) e "inestimavel" (relíquia) nunca estão na prateleira.
function Loja.naPrateleira(item, rankDoJogador)
	if type(item) ~= "table" or not inteiro(item.price) or item.price <= 0 then return false end
	if item.aVenda == false then return false end
	local disp = item.disponibilidade
	if disp ~= nil and disp ~= "loja" then return false end
	return Loja.atingeRank(rankDoJogador or Loja.RANK_INICIAL, item.guildRankRequired or Loja.RANK_INICIAL)
end

-- Lista ordenada (categoria, preço, nome) do que o jogador pode comprar agora.
function Loja.listar(itens, rankDoJogador)
	local lista = {}
	for _, item in ipairs(itens) do
		if Loja.naPrateleira(item, rankDoJogador) then table.insert(lista, item) end
	end
	table.sort(lista, function(a, b)
		local ca, cb = ORDEM[a.category] or 99, ORDEM[b.category] or 99
		if ca ~= cb then return ca < cb end
		if a.price ~= b.price then return a.price < b.price end
		return a.name < b.name
	end)
	return lista
end

-- Compra: devolve (novoOuro, itemDeInventario) ou (nil, nil, motivo). O item de inventário tem o
-- mesmo formato de `toInventoryItem` do site; id/sourceLocalId são do serviço.
function Loja.comprar(ouro, item, rankDoJogador)
	if not inteiro(ouro) then return nil, nil, "Ouro inválido." end
	if type(item) ~= "table" then return nil, nil, "Item desconhecido." end
	if not Loja.naPrateleira(item, rankDoJogador) then
		return nil, nil, "Este item não está à venda para você."
	end
	if ouro < item.price then return nil, nil, "Ouro insuficiente." end
	return ouro - item.price, {
		name = item.name, type = item.type, description = item.description,
		baseDie = item.baseDie, damageAttribute = item.damageAttribute, acBonus = item.acBonus,
	}
end

-- Quanto a loja paga: tralha a 100% do preço, o resto a 50% (arredondado para baixo);
-- sem preço (relíquia) não tem compra.
function Loja.valorDeVenda(item)
	if type(item) ~= "table" or not inteiro(item.price) or item.price <= 0 then return nil end
	if item.disponibilidade == "inestimavel" then return nil end
	if item.category == "tralha" then return item.price end
	return item.price // 2
end

-- Venda: devolve novoOuro ou (nil, motivo).
function Loja.vender(ouro, item)
	if not inteiro(ouro) then return nil, "Ouro inválido." end
	local valor = Loja.valorDeVenda(item)
	if not valor then return nil, "A loja não compra este item." end
	return ouro + valor
end

return table.freeze(Loja)
