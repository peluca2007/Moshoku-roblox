-- Perícias concedidas pela construção própria (J1, recorte inicial).
-- Replica selectors.ts:getTreeGrantedSkills usando o catálogo gerado.
-- Não altera a ficha; valores derivados são injetados pelo chamador.
local PericiasPersonagem = {}

local function porId(catalogo, id: string?)
	if type(id) ~= "string" then
		return nil
	end
	return catalogo.POR_ID[id]
end

local function arvorePorId(catalogo, id: string)
	for _, arvore in catalogo.POR_ESPECIE.tree or {} do
		if arvore.data.id == id then
			return arvore
		end
	end
	return nil
end

local function incluirUnicas(destino: { string }, vistas: { [string]: boolean }, valores)
	for _, valor in valores or {} do
		if type(valor) == "string" and not vistas[valor] then
			vistas[valor] = true
			table.insert(destino, valor)
		end
	end
end

function PericiasPersonagem.concedidas(construcao, catalogo): { string }
	local resultado, vistas = {}, {}
	local arvoreInicial = porId(catalogo, construcao.startingTreeId)
	local idInicial = arvoreInicial and arvoreInicial.data.id

	if arvoreInicial then
		local concessoes = arvoreInicial.data.grantedSkills
		if concessoes then
			incluirUnicas(resultado, vistas, concessoes.fixed)
			local escolha = concessoes.choose
			if escolha then
				local permitidas = {}
				for _, nome in escolha.from or {} do
					permitidas[nome] = true
				end
				-- O seletor do site limita a lista antes de filtrar opções inválidas.
				for indice, skillId in ipairs(construcao.treeSkillChoiceIds or {}) do
					if indice > escolha.count then
						break
					end
					local skill = porId(catalogo, skillId)
					local nome = skill and skill.data.name
					if nome and permitidas[nome] then
						incluirUnicas(resultado, vistas, { nome })
					end
				end
			end
		end
	end

	-- Só árvores com algum rank aberto contam, e a inicial não recebe a
	-- concessão especial de "quando não é a primeira".
	local arvoresAdicionais, vistasArvores = {}, {}
	for _, rankId in ipairs(construcao.unlockedRankIds or {}) do
		local rank = porId(catalogo, rankId)
		local idArvore = rank and rank.data.treeId
		if idArvore and idArvore ~= idInicial and not vistasArvores[idArvore] then
			vistasArvores[idArvore] = true
			table.insert(arvoresAdicionais, idArvore)
		end
	end
	for _, idArvore in arvoresAdicionais do
		local arvore = arvorePorId(catalogo, idArvore)
		if arvore then
			incluirUnicas(resultado, vistas, arvore.data.masterySkillsWhenNotFirst)
		end
	end

	-- O seletor do site inclui habilidades compradas; talentos não concedem
	-- perícias por este campo, mesmo se houver texto parecido na descrição.
	for _, habilidadeId in ipairs(construcao.purchasedIds or {}) do
		local habilidade = porId(catalogo, habilidadeId)
		if habilidade and habilidade.kind == "ability" then
			incluirUnicas(resultado, vistas, habilidade.data.grantsSkills)
		end
	end

	return resultado
end

-- Parte numérica de selectors.ts:getBonusDePericia. Valores derivados são
-- injetados para manter este módulo puro e permitir comparação com o livro.
function PericiasPersonagem.calcularBonus(
	construcao,
	catalogo,
	nome: string,
	valorAtributo: number,
	bonusPorRank: { [string]: number }
)
	local idPericia
	for _, pericia in catalogo.POR_ESPECIE.skill or {} do
		if pericia.data.name == nome then
			idPericia = pericia.id
			break
		end
	end
	if not idPericia then
		return nil
	end

	local treinada = table.find(construcao.skillIds or {}, idPericia) ~= nil
		or table.find(PericiasPersonagem.concedidas(construcao, catalogo), nome) ~= nil
	local raca = porId(catalogo, construcao.raceId)
	local antecedente = porId(catalogo, construcao.backgroundId)
	treinada = treinada
		or (raca and table.find(raca.data.fixedSkills or {}, nome) ~= nil) == true
		or (antecedente and table.find(antecedente.data.fixedSkills or {}, nome) ~= nil) == true
	local bonusDeRank = 0
	if treinada then
		for _, rankId in ipairs(construcao.unlockedRankIds or {}) do
			local rank = porId(catalogo, rankId)
			local arvore = rank and arvorePorId(catalogo, rank.data.treeId)
			local cobertas = arvore and arvore.data.proficiencies and arvore.data.proficiencies.periciasCobertas
			if cobertas and table.find(cobertas, nome) then
				bonusDeRank = math.max(bonusDeRank, bonusPorRank[rank.data.rank] or 0)
			end
		end
	end

	return {
		nome = nome,
		atributoValor = valorAtributo,
		bonusDeRank = bonusDeRank,
		total = valorAtributo + bonusDeRank,
		treinada = treinada,
	}
end

-- Formato calculado compatível com calculated.skills da ficha v2. Atributos e
-- bônus de rank são fornecidos pelo chamador; nenhuma entrada é mutada.
function PericiasPersonagem.calcularTodas(construcao, catalogo, atributos, bonusPorRank)
	local resultado = {}
	for _, pericia in catalogo.POR_ESPECIE.skill or {} do
		local calculada = PericiasPersonagem.calcularBonus(
			construcao,
			catalogo,
			pericia.data.name,
			atributos[pericia.data.attribute] or 0,
			bonusPorRank
		)
		table.insert(resultado, {
			skillId = pericia.id,
			bonus = calculada.total,
			trained = calculada.treinada,
		})
	end
	return resultado
end

return PericiasPersonagem
