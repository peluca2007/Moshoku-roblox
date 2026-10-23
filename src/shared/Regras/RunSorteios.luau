-- Sorteios da run (PLANO §12). Puros: o gerador é injetado (`rng:NextInteger(lo, hi)`).
-- Servem à oferta de árvores na criação, aos treinadores da vila (sorteio SEPARADO da oferta),
-- ao extra da taverna e, depois, aos eventos da viagem.
local Sorteios = {}

Sorteios.FORCA_MAX = 10

-- Quantas árvores a oferta traz de cada categoria. PROVISÓRIO (o Pedro disse "3 de corpo,
-- 2 de magia, 1 de utilidade"); se uma categoria tiver menos candidatas, traz as que houver.
Sorteios.COMPOSICAO_OFERTA = table.freeze({ corpo = 3, magia = 2, utilidade = 1 })

-- Quanto mais forte a árvore, mais rara: força 1..FORCA_MAX vira peso FORCA_MAX..1.
function Sorteios.pesoDeForca(forca)
	if type(forca) ~= "number" or forca % 1 ~= 0 or forca < 1 or forca > Sorteios.FORCA_MAX then return nil end
	return Sorteios.FORCA_MAX + 1 - forca
end

-- itens = { { id, peso (inteiro > 0) }... }; sorteia `quantidade` ids distintos, na ordem sorteada.
function Sorteios.ponderado(itens, quantidade, rng)
	if type(itens) ~= "table" or type(quantidade) ~= "number" or quantidade < 0 or quantidade % 1 ~= 0
		or type(rng) ~= "table" and typeof(rng) ~= "Random" then
		return nil, "Sorteio inválido."
	end
	local restantes, total = {}, 0
	for _, item in itens do
		if type(item) ~= "table" or item.id == nil or type(item.peso) ~= "number"
			or item.peso % 1 ~= 0 or item.peso < 1 then
			return nil, "Item de sorteio inválido."
		end
		table.insert(restantes, item)
		total += item.peso
	end
	local escolhidos = {}
	for _ = 1, math.min(quantidade, #restantes) do
		local alvo = rng:NextInteger(1, total)
		local acumulado = 0
		for i, item in restantes do
			acumulado += item.peso
			if alvo <= acumulado then
				table.insert(escolhidos, item.id)
				total -= item.peso
				table.remove(restantes, i)
				break
			end
		end
	end
	return escolhidos
end

-- arvores = { { id, categoria = "corpo"|"magia"|"utilidade", forca = 1..10 }... }
-- Devolve { ids... } com a composição configurada, ponderada pela força.
function Sorteios.ofertaDeArvores(arvores, rng, composicao)
	composicao = composicao or Sorteios.COMPOSICAO_OFERTA
	if type(arvores) ~= "table" then return nil, "Árvores inválidas." end
	local porCategoria = {}
	for _, a in arvores do
		local peso = type(a) == "table" and Sorteios.pesoDeForca(a.forca)
		if not peso or type(a.categoria) ~= "string" then return nil, "Árvore inválida." end
		porCategoria[a.categoria] = porCategoria[a.categoria] or {}
		table.insert(porCategoria[a.categoria], { id = a.id, peso = peso })
	end
	local oferta = {}
	for _, categoria in { "corpo", "magia", "utilidade" } do
		local n = composicao[categoria] or 0
		local sorteadas, motivo = Sorteios.ponderado(porCategoria[categoria] or {}, n, rng)
		if not sorteadas then return nil, motivo end
		for _, id in sorteadas do table.insert(oferta, id) end
	end
	return oferta
end

-- candidatos = { { id, peso = 1, taverna = bool }... } (treinador = arvore + NPC).
-- Sorteia `quantidade` treinadores para a vila e, com chance `chanceTaverna` (0..100), um extra
-- vindo dos candidatos `taverna = true` que ainda não saíram. Devolve (ids, extraId|nil).
function Sorteios.treinadoresDaVila(candidatos, quantidade, chanceTaverna, rng)
	local lista = {}
	for _, c in candidatos do
		if type(c) ~= "table" then return nil, "Candidato inválido." end
		table.insert(lista, { id = c.id, peso = c.peso or 1 })
	end
	local ids, motivo = Sorteios.ponderado(lista, quantidade, rng)
	if not ids then return nil, motivo end
	if type(chanceTaverna) ~= "number" or chanceTaverna <= 0 then return ids, nil end
	if rng:NextInteger(1, 100) > chanceTaverna then return ids, nil end
	local jaSaiu = {}
	for _, id in ids do jaSaiu[id] = true end
	local taverna = {}
	for _, c in candidatos do
		if c.taverna == true and not jaSaiu[c.id] then table.insert(taverna, { id = c.id, peso = c.peso or 1 }) end
	end
	local extra = Sorteios.ponderado(taverna, 1, rng)
	if extra and extra[1] ~= nil then
		table.insert(ids, extra[1])
		return ids, extra[1]
	end
	return ids, nil
end

return Sorteios
