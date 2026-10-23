-- Intenção inicial determinística; catálogo/servidor continuam validando tudo.
local Shared = game:GetService("ReplicatedStorage").Shared
local Pericias = require(Shared.Regras.PericiasDeCriacao)
local Preset = {}
local NOMES = { "Lina", "Ren", "Mira", "Ariel", "Theo", "Nara", "Ilan", "Sora", "Luca", "Yuna", "Noa", "Cora" }
local ATRIBUTOS = { "forca", "agilidade", "vigor", "intelecto", "espirito" }
-- O livro manda o Plebeu escolher perícias de trabalhos mundanos; elas vêm primeiro no preset.
local PREFERIDAS = { "Ofícios", "Lidar com Animais", "Natureza", "Atletismo", "Percepção", "Sobrevivência" }

function Preset.nomeValido(valor)
	if type(valor) ~= "string" or #valor > 128 then return nil, "Nome: use de 1 a 32 caracteres." end
	local nome = string.gsub(valor, "^%s*(.-)%s*$", "%1")
	local ok, tamanho = pcall(utf8.len, nome)
	if not ok or type(tamanho) ~= "number" or tamanho < 1 or tamanho > 32 or string.find(nome, "%c") then
		return nil, "Nome: use de 1 a 32 caracteres, sem quebras de linha."
	end
	return nome
end

-- O sorteio é injetado; não acessa Random, relógio ou serviços.
function Preset.sugerirNome(sortear)
	return NOMES[sortear(1, #NOMES)]
end

-- Preenche as perícias livres sem repetir as já concedidas por raça, antecedente e árvore.
-- Mantém as escolhas atuais que continuam válidas (ajuste do jogador sobrevive a trocar de árvore).
function Preset.completarPericiasLivres(catalogo, escolha, raca, antecedente)
	local concedidas = Pericias.idsJaConcedidos(catalogo, raca.id, antecedente.id, escolha.startingTreeId, escolha.treeSkillChoiceIds)
	local quantidade = (raca.data.bonusSkillChoices or 0) + (antecedente.data.bonusSkillChoices or 0)
	local novas = {}
	local function tentar(pericia)
		if #novas < quantidade and not concedidas[pericia.id] then
			concedidas[pericia.id] = true
			table.insert(novas, pericia.id)
		end
	end
	for _, id in escolha.freeSkillChoiceIds or {} do
		local pericia = catalogo.POR_ID[id]
		if pericia and pericia.kind == "skill" then tentar(pericia) end
	end
	for _, nome in PREFERIDAS do
		for _, pericia in catalogo.POR_ESPECIE.skill or {} do
			if pericia.data.name == nome then tentar(pericia) end
		end
	end
	for _, pericia in catalogo.POR_ESPECIE.skill or {} do tentar(pericia) end
	escolha.freeSkillChoiceIds = novas
end

function Preset.criar(catalogo, raceId, startingTreeId)
	local raca = catalogo.POR_ID[raceId]
	if not raca or raca.kind ~= "race" then return nil, "Raça: escolha uma opção liberada." end
	local antecedente = catalogo.POR_ID["background/plebeu"]
	if not antecedente then return nil, "Antecedente: Plebeu indisponível no catálogo." end
	local arvore = startingTreeId and catalogo.POR_ID[startingTreeId]
	if startingTreeId and (not arvore or arvore.kind ~= "tree") then return nil, "Árvore inicial inválida." end
	local escolha = {
		raceId = raceId, backgroundId = antecedente.id, startingTreeId = startingTreeId,
		attributeBase = { forca = 1, agilidade = 0, vigor = 1, intelecto = 0, espirito = 0 },
		raceAttributeChoices = {}, freeSkillChoiceIds = {}, treeSkillChoiceIds = {},
	}
	for i = 1, raca.data.attributeChoices or 0 do
		table.insert(escolha.raceAttributeChoices, ATRIBUTOS[(i - 1) % #ATRIBUTOS + 1])
	end
	local escolhaArvore = arvore and arvore.data.grantedSkills and arvore.data.grantedSkills.choose
	local vistas = {}
	for _, nome in escolhaArvore and escolhaArvore.from or {} do
		for _, pericia in catalogo.POR_ESPECIE.skill or {} do
			if pericia.data.name == nome and not vistas[pericia.id] and #escolha.treeSkillChoiceIds < escolhaArvore.count then
				vistas[pericia.id] = true
				table.insert(escolha.treeSkillChoiceIds, pericia.id)
			end
		end
	end
	Preset.completarPericiasLivres(catalogo, escolha, raca, antecedente)
	return escolha
end

-- Mesma ficha com a árvore aprendida (provação): conserva atributos, antecedente e nome da ficha;
-- escolhe as perícias da árvore e refaz as livres para não repetir nenhuma. Devolve nil + campo inválido.
function Preset.comArvore(catalogo, construcao, startingTreeId)
	local base, erro = Preset.criar(catalogo, construcao.raceId, startingTreeId)
	if not base then return nil, erro end
	local atual = construcao.backgroundId and catalogo.POR_ID[construcao.backgroundId]
	if atual and atual.kind == "background" then base.backgroundId = atual.id end
	base.subtableEntryId = construcao.subtableEntryId
	if type(construcao.attributeBase) == "table" then base.attributeBase = table.clone(construcao.attributeBase) end
	if type(construcao.raceAttributeChoices) == "table" and #construcao.raceAttributeChoices == #base.raceAttributeChoices then
		base.raceAttributeChoices = table.clone(construcao.raceAttributeChoices)
	end
	base.freeSkillChoiceIds = table.clone(construcao.freeSkillChoiceIds or construcao.skillIds or {})
	Preset.completarPericiasLivres(catalogo, base, catalogo.POR_ID[construcao.raceId], catalogo.POR_ID[base.backgroundId])
	return base
end

-- Raças que o cartão pode oferecer: comuns e incomuns sempre; raras só se a conta liberou (set por id).
function Preset.racasDisponiveis(catalogo, liberadas)
	local lista = {}
	for _, raca in catalogo.POR_ESPECIE.race or {} do
		local tier = raca.data and raca.data.tier
		if tier == "comum" or tier == "incomum" or (tier == "rara" and liberadas ~= nil and liberadas[raca.id] == true) then
			table.insert(lista, raca)
		end
	end
	table.sort(lista, function(a, b) return a.data.name < b.data.name end)
	return lista
end

function Preset.nomeCurto(raca)
	local completo = raca.data.name or "Raça"
	return string.match(completo, "^(.-) %(") or string.match(completo, "^(.-) /") or completo
end

-- Primeira frase da descrição do livro: uma linha para o cartão da raça.
function Preset.frase(raca)
	local d = raca.data.description
	if type(d) ~= "string" or d == "" then return (raca.data.traits and raca.data.traits[1]) or "Consulte esta raça no livro." end
	local fim = string.find(d, "%.%s") or string.find(d, "%.$")
	local frase = if fim then string.sub(d, 1, fim) else d
	if utf8.len(frase) and (utf8.len(frase) :: number) > 120 then
		frase = string.sub(frase, 1, (utf8.offset(frase, 118) or 118) - 1) .. "…"
	end
	return frase
end

function Preset.selo(raca)
	local dados = raca.data
	local bonus = {}
	for _, chave in ATRIBUTOS do
		local valor = dados.bonuses and dados.bonuses.attributes and dados.bonuses.attributes[chave]
		if valor and valor ~= 0 then table.insert(bonus, string.format("%+d %s", valor, chave)) end
	end
	if (dados.attributeChoices or 0) > 0 then table.insert(bonus, "+1 atributo à escolha") end
	if (dados.bonusSkillChoices or 0) > 0 then table.insert(bonus, tostring(dados.bonusSkillChoices) .. " perícias extras") end
	return if #bonus > 0 then table.concat(bonus, " · ") else (dados.traits and dados.traits[1]) or "Traços próprios da raça"
end

return Preset
