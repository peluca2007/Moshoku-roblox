-- Progressão nas árvores (puro; catálogo injetado). Porte de `canUnlockRank` e
-- `canPurchaseAbility` do site (src/store/selectors.ts), sobre a construção da
-- ficha v2 (construction.unlockedRankIds / purchasedIds).
--
-- Decisões do Pedro (09/10/2026), provisórias:
-- - PA INFINITO: o custo em PA não trava nada (no site ele também só informa).
-- - TETO no Intermediário: ranks acima ficam "em breve".
-- Livro: abrir um rank exige o rank anterior aberto na mesma árvore e N
-- conhecimentos (magias e talentos comprados) nela (RANK_REQUIREMENTS); comprar
-- exige o rank aberto, não ter a habilidade, os `requires` da mesma árvore e o
-- `requiresRank` (patamar mínimo numa árvore ou numa categoria).
-- Não portado (avisado no motivo): os Símbolos de origem natural da Teórica.
local Regras = require(game:GetService("ReplicatedStorage").Shared.Livro.Regras)

local Progressao = {}

Progressao.PA_INFINITO = true
Progressao.TETO = "Intermediário"

local function indiceDoRank(rank: string): number?
	return table.find(Regras.ordemDosRanks, rank)
end

-- Segmento de ID com percent-encoding (CONTRATOS §2.1): "Intermediário" →
-- "Intermedi%C3%A1rio", como o gerador e o exportador do site.
function Progressao.segmento(texto: string): string
	return (string.gsub(texto, "[^%w%-%._~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

function Progressao.idDoRank(arvore: string, rank: string): string
	return "rank/" .. Progressao.segmento(arvore) .. "/" .. Progressao.segmento(rank)
end

function Progressao.rankAberto(construcao, arvore: string, rank: string): boolean
	return table.find(construcao.unlockedRankIds, Progressao.idDoRank(arvore, rank)) ~= nil
end

-- Maior rank aberto numa árvore (nome) ou nil.
function Progressao.maiorRank(construcao, arvore: string): string?
	local maior, indice = nil, 0
	for i, rank in Regras.ordemDosRanks do
		if Progressao.rankAberto(construcao, arvore, rank) and i > indice then
			maior, indice = rank, i
		end
	end
	return maior
end

-- Conhecimentos numa árvore: habilidades e talentos comprados nela.
function Progressao.conhecimentos(construcao, arvore: string): number
	local prefixoA = "ability/" .. Progressao.segmento(arvore) .. "/"
	local prefixoT = "talent/" .. Progressao.segmento(arvore) .. "/"
	local n = 0
	for _, id in construcao.purchasedIds do
		if string.sub(id, 1, #prefixoA) == prefixoA or string.sub(id, 1, #prefixoT) == prefixoT then
			n += 1
		end
	end
	return n
end

-- Carta de 0 PA (o truque da escola) não se compra: quem abriu o patamar a tem
-- (Cap. 2, §1; combatSim "gratuitas").
function Progressao.gratuita(entrada): boolean
	return entrada.kind == "ability" and entrada.data.paCost == 0
end

-- Habilidades e talentos que a construção conhece: as compras e as cartas
-- gratuitas dos ranks abertos.
function Progressao.conhecidas(construcao, catalogo): { string }
	local lista = table.clone(construcao.purchasedIds)
	for _, rankId in construcao.unlockedRankIds do
		local rank = catalogo.POR_ID[rankId]
		for _, id in (rank and rank.data.abilities) or {} do
			local entrada = catalogo.POR_ID[id]
			if entrada and Progressao.gratuita(entrada) and not table.find(lista, id) then
				table.insert(lista, id)
			end
		end
	end
	return lista
end

function Progressao.acimaDoTeto(rank: string): boolean
	local i, teto = indiceDoRank(rank), indiceDoRank(Progressao.TETO)
	return i == nil or teto == nil or i > teto
end

-- Pode abrir o rank? (ok, motivo)
function Progressao.podeAbrir(construcao, catalogo, arvore: string, rank: string): (boolean, string?)
	if not catalogo.POR_ID["tree/" .. Progressao.segmento(arvore)] then
		return false, "Árvore desconhecida."
	end
	local indice = indiceDoRank(rank)
	if not indice or not catalogo.POR_ID[Progressao.idDoRank(arvore, rank)] then
		return false, "Rank desconhecido nesta árvore."
	end
	if Progressao.acimaDoTeto(rank) then
		return false, "Por enquanto o jogo vai até o " .. Progressao.TETO .. "."
	end
	if Progressao.rankAberto(construcao, arvore, rank) then
		return false, "Rank já desbloqueado."
	end
	if indice > 1 then
		local anterior = Regras.ordemDosRanks[indice - 1]
		if not Progressao.rankAberto(construcao, arvore, anterior) then
			return false, "Desbloqueie " .. anterior .. " antes."
		end
	end
	local exigidos = Regras.requisitosDeRank[rank].knowledgeRequired
	local tem = Progressao.conhecimentos(construcao, arvore)
	if tem < exigidos then
		return false, string.format("Precisa de %d conhecimento(s) nesta árvore (tem %d).", exigidos, tem)
	end
	return true, nil
end

-- Pode comprar a habilidade ou talento? (ok, motivo)
function Progressao.podeComprar(construcao, catalogo, id: string): (boolean, string?)
	local entrada = catalogo.POR_ID[id]
	if not entrada or (entrada.kind ~= "ability" and entrada.kind ~= "talent") then
		return false, "Habilidade desconhecida."
	end
	local dados = entrada.data
	local arvore, rank = dados.treeId, dados.rank
	if Progressao.acimaDoTeto(rank) then
		return false, "Por enquanto o jogo vai até o " .. Progressao.TETO .. "."
	end
	if not Progressao.rankAberto(construcao, arvore, rank) then
		return false, "Rank ainda não desbloqueado nesta árvore."
	end
	if table.find(construcao.purchasedIds, id) then
		return false, "Já adquirido."
	end
	if Progressao.gratuita(entrada) then
		return false, "Vem com o rank: não se compra."
	end
	if arvore == "teorica" and dados.requires and #dados.requires > 0 then
		-- Símbolos de origem natural (selectors.ts `origemNaturalDoSimbolo`) não portados.
		return false, "Pré-requisitos de Símbolo da Teórica ainda não suportados no jogo."
	end
	for _, requerido in dados.requires or {} do
		local tem = false
		for _, comprado in construcao.purchasedIds do
			local outra = catalogo.POR_ID[comprado]
			if outra and outra.data.treeId == arvore and outra.sourceId == requerido then
				tem = true
				break
			end
		end
		if not tem then
			local nome = requerido
			for _, candidato in catalogo.POR_ESPECIE.ability or {} do
				if candidato.data.treeId == arvore and candidato.sourceId == requerido then
					nome = candidato.data.name
				end
			end
			return false, string.format('Exige "%s" nesta árvore antes.', nome)
		end
	end
	local exigencia = dados.requiresRank
	if exigencia then
		local minimo = indiceDoRank(exigencia.rank) or 1
		local atende = false
		for _, rankId in construcao.unlockedRankIds do
			local r = catalogo.POR_ID[rankId]
			if r then
				local outraArvore = r.data.treeId
				local i = indiceDoRank(r.data.rank) or 0
				if i >= minimo then
					if exigencia.treeId and outraArvore == exigencia.treeId then
						atende = true
					elseif exigencia.categoria then
						local arv = catalogo.POR_ID["tree/" .. Progressao.segmento(outraArvore)]
						if arv and arv.data.category == exigencia.categoria then
							atende = true
						end
					end
				end
			end
		end
		if not atende then
			local onde = exigencia.treeId or ("alguma árvore de " .. tostring(exigencia.categoria))
			local arv = exigencia.treeId and catalogo.POR_ID["tree/" .. Progressao.segmento(exigencia.treeId)]
			if arv then
				onde = arv.data.name
			end
			return false, string.format("Exige o patamar %s em %s.", exigencia.rank, onde)
		end
	end
	return true, nil
end

return Progressao
