-- Defeitos do personagem pronto (PLANO §12): características negativas sorteadas, em troca de PA
-- extra e de uma recompensa maior no fim da run. Cada defeito usa mecânica que o livro já tem
-- (Desvantagem em perícia, como as "Maldições" dos antecedentes; deslocamento menor) e pode
-- bloquear opções de eventos por tag. Adaptação registrada em docs/FIDELIDADE.md.
-- Pura: só dados e consultas. Quem aplica Desvantagem/deslocamento é o motor de combate/perícias.
local Defeitos = {}

-- desvantagemEm = perícias com Desvantagem; deslocamentoMenos = metros; bloqueia = tags de opção
-- de evento que o personagem não consegue escolher. Lista PROVISÓRIA; o Pedro cita Zangado,
-- Manco e Burro como exemplos.
Defeitos.LISTA = table.freeze({
	{ id = "zangado", nome = "Zangado", desvantagemEm = { "Persuasão" }, bloqueia = { "diplomacia" } },
	{ id = "manco", nome = "Manco", deslocamentoMenos = 3, bloqueia = { "escalada" } },
	{ id = "burro", nome = "Burro", desvantagemEm = { "Investigação" }, bloqueia = { "enigma" } },
	{ id = "medroso", nome = "Medroso", desvantagemEm = { "Intimidação" }, bloqueia = { "confronto" } },
	{ id = "desastrado", nome = "Desastrado", desvantagemEm = { "Furtividade" }, bloqueia = { "furtividade" } },
	{ id = "fragil", nome = "Frágil", desvantagemEm = { "Vigor" }, bloqueia = { "forca" } },
})

local POR_ID = {}
for _, d in Defeitos.LISTA do POR_ID[d.id] = d end

function Defeitos.porId(id)
	return POR_ID[id]
end

-- Sorteia `quantidade` defeitos distintos (padrão: peso igual).
function Defeitos.sortear(quantidade, rng)
	if type(quantidade) ~= "number" or quantidade < 0 or quantidade % 1 ~= 0 or quantidade > #Defeitos.LISTA then
		return nil, "Quantidade inválida."
	end
	local restantes = {}
	for _, d in Defeitos.LISTA do table.insert(restantes, d.id) end
	local escolhidos = {}
	for _ = 1, quantidade do
		local i = rng:NextInteger(1, #restantes)
		table.insert(escolhidos, table.remove(restantes, i))
	end
	return escolhidos
end

-- ids = lista de defeitos do personagem -> { desvantagemEm = { [pericia] = true }, deslocamentoMenos, bloqueia = { [tag] = true } }
function Defeitos.efeitos(ids)
	local efeitos = { desvantagemEm = {}, deslocamentoMenos = 0, bloqueia = {} }
	for _, id in ids or {} do
		local d = POR_ID[id]
		if not d then return nil, "Defeito desconhecido: " .. tostring(id) end
		for _, p in d.desvantagemEm or {} do efeitos.desvantagemEm[p] = true end
		efeitos.deslocamentoMenos += d.deslocamentoMenos or 0
		for _, tag in d.bloqueia or {} do efeitos.bloqueia[tag] = true end
	end
	return efeitos
end

-- Uma opção de evento (com `tags`) está bloqueada para quem tem estes defeitos?
function Defeitos.bloqueiaOpcao(ids, tags)
	local efeitos = Defeitos.efeitos(ids)
	if not efeitos then return false end
	for _, tag in tags or {} do
		if efeitos.bloqueia[tag] then return true end
	end
	return false
end

-- Fronteira J2: só IDs canônicos, distintos e em lista densa; nunca aceitar
-- efeitos/bônus calculados pelo chamador. Retorna cópia para congelar o encontro.
function Defeitos.validarCombate(ids)
	if type(ids) ~= "table" then return nil, "Lista de defeitos inválida." end
	local copia, vistos, quantidade = {}, {}, 0
	for chave, id in ids do
		quantidade += 1
		if quantidade > #Defeitos.LISTA or type(chave) ~= "number" or chave % 1 ~= 0
			or chave < 1 or chave > #ids or type(id) ~= "string" or not POR_ID[id] or vistos[id]
		then return nil, "Lista de defeitos inválida." end
		vistos[id] = true
		copia[chave] = id
	end
	if quantidade ~= #ids then return nil, "Lista de defeitos inválida." end
	return copia
end

function Defeitos.deslocamentoCombate(ids, metros)
	local validos, erro = Defeitos.validarCombate(ids)
	if not validos then return nil, erro end
	if type(metros) ~= "number" or metros ~= metros or metros < 0 or metros > 30 then
		return nil, "Deslocamento inválido."
	end
	local efeitos = Defeitos.efeitos(validos)
	local efetivo = math.max(0, metros - efeitos.deslocamentoMenos)
	return { baseMeters = metros, movementMeters = efetivo,
		movementCasas = math.floor(efetivo / 1.5), reductionMeters = metros - efetivo }
end

-- O nome é exato: penalidade em Persuasão não afeta ataque, nem outro teste
-- que use o mesmo atributo. Vigor também identifica resistência desse atributo.
function Defeitos.fontesDeDesvantagem(ids, teste)
	local validos, erro = Defeitos.validarCombate(ids)
	if not validos then return nil, erro end
	if type(teste) ~= "string" then return nil, "Teste inválido." end
	local fontes = {}
	for _, id in validos do
		if table.find(POR_ID[id].desvantagemEm or {}, teste) then table.insert(fontes, id) end
	end
	return fontes
end

return Defeitos
