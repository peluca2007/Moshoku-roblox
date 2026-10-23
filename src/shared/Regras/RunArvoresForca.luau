-- Força relativa das 19 árvores no rank Principiante, para ponderar a oferta da criação por run
-- (PLANO §12; método e limites em docs/FIDELIDADE.md "R3a — força das árvores").
-- Dados puros. As contagens vêm do catálogo do livro (Livro/Dados/Arvores) e do porte do jogo
-- (Regras/ArvoresPrincipiante, Fogo, Execucao), medidas em 14/10/2026; reconte ao portar habilidades.
--
-- Contagens por função das habilidades Principiante (uma habilidade pode ter mais de uma etiqueta):
--   a = ataque/dano, c = cura, b = proteção, k = controle, m = mobilidade, u = utilidade,
--   p = passivas, r = reações, o = outro/invocação. exec = executáveis no jogo hoje; total = no catálogo.
-- `indeterminada` = o poder está nos talentos ou em rank maior, que esta análise NÃO mediu:
-- recebe força neutra (NEUTRA) em vez de uma nota inventada.
local Forca = {}

Forca.NEUTRA = 5
-- Mínimo de habilidades executáveis para entrar na oferta; evita oferecer personagem sem ação em combate.
Forca.EXEC_MINIMO = 3
-- Árvores de utilidade e invocação têm 1–2 habilidades Principiante por desenho do livro: basta 1 executável.
Forca.EXEC_MINIMO_UTILIDADE = 1

local function d(categoria, total, exec, c, extra)
	local t = { categoria = categoria, total = total, exec = exec, a = 0, c = 0, b = 0, k = 0, m = 0, u = 0, p = 0, r = 0, o = 0 }
	for k, v in c do t[k] = v end
	for k, v in extra or {} do t[k] = v end
	return table.freeze(t)
end

Forca.ARVORES = table.freeze({
	["agua"] = d("magia", 7, 7, { a = 5, b = 1, k = 3 }),
	["desintoxicacao"] = d("magia", 7, 5, { a = 3, c = 2, b = 1, k = 1, u = 2 }),
	["terra"] = d("magia", 7, 6, { a = 3, b = 2, k = 4, r = 1 }),
	["fogo"] = d("magia", 6, 6, { a = 4, k = 2, u = 1 }),
	["vento"] = d("magia", 6, 6, { a = 3, k = 3, m = 1 }),
	["cura"] = d("magia", 5, 4, { c = 4, b = 1 }),
	["teorica"] = d("magia", 4, 2, { a = 1, b = 2, u = 1, r = 1 }),
	["invocacao"] = d("magia", 1, 1, { o = 1 }, { indeterminada = true }),

	["armas-pesadas"] = d("corpo", 5, 5, { a = 3, k = 3, m = 1, o = 1 }),
	["arquearia"] = d("corpo", 4, 2, { a = 2, k = 2, u = 2, p = 1 }),
	["cavalaria-e-escudos"] = d("corpo", 6, 6, { a = 2, b = 1, k = 4, o = 1 }),
	["deus-da-agua-corpo"] = d("corpo", 5, 1, { b = 4, k = 1, p = 2, r = 2 }),
	["deus-da-espada"] = d("corpo", 5, 3, { a = 3, b = 1, k = 1, m = 2, p = 2 }),
	["deus-do-norte"] = d("corpo", 6, 5, { a = 3, c = 1, k = 2, m = 1, u = 2, p = 1, r = 1 }),
	["punho-de-fogo"] = d("corpo", 3, 0, { a = 1, k = 1, m = 1 }),
	["vendaval"] = d("corpo", 4, 0, { a = 2, k = 2, m = 1 }),

	["bardo-e-interacao"] = d("utilidade", 2, 1, { b = 1, r = 1, o = 1 }, { indeterminada = true }),
	["furtividade-e-armadilhas"] = d("utilidade", 1, 1, { a = 1 }, { indeterminada = true }),
	["navegacao-e-lideranca"] = d("utilidade", 1, 0, { p = 1, o = 1 }, { indeterminada = true, valorNaRun = true }),
})

-- Pontuação de desenho: cobertura de papéis, sem olhar o porte. Pesos são julgamento de design
-- (ataque e cura valem mais por resolver o combate sozinhos; proteção e controle vêm em seguida).
local PESOS = { a = 2, c = 2, b = 1.5, k = 1, m = 1, u = 1, p = 0.5, r = 0.5, o = 0.5 }

function Forca.pontuacao(arvore)
	local total = 0
	for chave, peso in PESOS do total += (arvore[chave] or 0) * peso end
	return total
end

-- Escala 1..10 de Sorteios.FORCA_MAX: 15 pontos de desenho ≈ força 10.
function Forca.forca(id)
	local a = Forca.ARVORES[id]
	if not a then return nil end
	if a.indeterminada then return Forca.NEUTRA end
	return math.clamp(math.round(Forca.pontuacao(a) * 10 / 15), 1, 10)
end

-- Elegível = tem ação suficiente no combate do jogo hoje (muda quando mais habilidades forem portadas), ou
-- vale fora do combate na run (`valorNaRun`: Navegação e Liderança dá o Explorador, que pesa 2 no voto, encurta
-- a viagem, melhora eventos e evita emboscada — RunVotacao/RunViagem/EncontroPatrulha).
function Forca.elegivel(id)
	local a = Forca.ARVORES[id]
	if not a then return false end
	if a.valorNaRun == true then return true end
	local minimo = if a.categoria == "utilidade" or a.indeterminada then Forca.EXEC_MINIMO_UTILIDADE else Forca.EXEC_MINIMO
	return a.exec >= minimo
end

-- Lista no formato de Sorteios.ofertaDeArvores: só árvores elegíveis, em ordem estável por id.
function Forca.candidatas()
	local ids = {}
	for id in Forca.ARVORES do
		if Forca.elegivel(id) then table.insert(ids, id) end
	end
	table.sort(ids)
	local lista = {}
	for _, id in ids do
		table.insert(lista, { id = id, categoria = Forca.ARVORES[id].categoria, forca = Forca.forca(id) })
	end
	return lista
end

return Forca
