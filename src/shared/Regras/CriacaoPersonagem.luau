-- Validação estrutural da criação própria (J1). Catálogo e escolhas vêm do
-- cliente como intenção; o servidor deve usar apenas a construção devolvida.
-- Sem Instances, rede, persistência ou execução de combate.
local CriacaoPersonagem = {}
local Shared = game:GetService("ReplicatedStorage").Shared
local AtributosPersonagem = require(Shared.Regras.AtributosPersonagem)
local PericiasPersonagem = require(Shared.Regras.PericiasPersonagem)
local PericiasDeCriacao = require(Shared.Regras.PericiasDeCriacao)
local EstatisticasPersonagem = require(Shared.Regras.EstatisticasPersonagem)
local RegrasLivro = require(Shared.Livro.Regras)
local KitsIniciais = require(Shared.KitsIniciais)

local ATRIBUTOS = { "forca", "agilidade", "vigor", "intelecto", "espirito" }
local PA_INICIAIS = 3
local CUSTO_RACA_ESCOLHIDA = {
	comum = 1,
	incomum = 1,
	rara = 2,
	lendaria = 3,
	mitica = 3,
}
local ATRIBUTO_VALIDO = {
	forca = true,
	agilidade = true,
	vigor = true,
	intelecto = true,
	espirito = true,
}
local CAMPOS = {
	raceId = true,
	backgroundId = true,
	subtableEntryId = true,
	attributeBase = true,
	raceAttributeChoices = true,
	freeSkillChoiceIds = true,
	startingTreeId = true,
	treeSkillChoiceIds = true,
}

local function densa(lista): boolean
	if type(lista) ~= "table" then
		return false
	end
	local quantidade = 0
	for chave in lista do
		if type(chave) ~= "number" or chave % 1 ~= 0 or chave < 1 then
			return false
		end
		quantidade += 1
	end
	return quantidade == #lista
end

local function semRepetir(lista): boolean
	local vistas = {}
	for _, valor in lista do
		if vistas[valor] then
			return false
		end
		vistas[valor] = true
	end
	return true
end

local function entrada(catalogo, id, especie)
	if type(id) ~= "string" then
		return nil
	end
	local encontrada = catalogo.POR_ID[id]
	if encontrada and encontrada.kind == especie then
		return encontrada
	end
	return nil
end

local function quantidade(valor): number
	if type(valor) ~= "number" or valor % 1 ~= 0 then
		return 0
	end
	return valor
end

-- Devolve uma cópia normalizada ou nil + mensagem segura para UI.
function CriacaoPersonagem.validar(construcao, catalogo)
	if type(construcao) ~= "table" then
		return nil, "Criação inválida."
	end
	for chave in construcao do
		if type(chave) ~= "string" or not CAMPOS[chave] then
			return nil, "Criação contém campo desconhecido."
		end
	end

	local raca = entrada(catalogo, construcao.raceId, "race")
	if not raca then
		return nil, "Raça: escolha uma raça do catálogo."
	end
	local antecedente = entrada(catalogo, construcao.backgroundId, "background")
	if not antecedente then
		return nil, "Antecedente: escolha um antecedente do catálogo."
	end
	local arvore = entrada(catalogo, construcao.startingTreeId, "tree")
	if construcao.startingTreeId ~= nil and not arvore then
		return nil, "Árvore inicial: escolha uma árvore do catálogo."
	end
	local kitInicial = arvore and type(arvore.data.subgroup) == "string" and KitsIniciais.obter(arvore.data.subgroup) or nil
	if arvore and (type(kitInicial) ~= "table" or type(kitInicial.items) ~= "table" or #kitInicial.items == 0) then
		return nil, "Esta árvore ainda não tem um kit inicial jogável."
	end
	-- A tela atual exige que o jogador escolha a raça. O livro cobra pelo tier
	-- da raça escolhida; selecionar também um antecedente não soma outro PA.
	local custoRaca = CUSTO_RACA_ESCOLHIDA[raca.data.tier]
	if custoRaca == nil then
		return nil, "Raça sem tier de custo de escolha válido no catálogo."
	end
	local rankInicial
	for _, rankId in (arvore and arvore.data.ranks) or {} do
		local rank = entrada(catalogo, rankId, "rank")
		if rank and rank.data.rank == "Principiante" and rank.data.treeId == arvore.data.id then
			rankInicial = rank
			break
		end
	end
	if arvore and not rankInicial then
		return nil, "Árvore sem rank inicial válido no catálogo."
	end

	local atributoBase = construcao.attributeBase
	if type(atributoBase) ~= "table" then
		return nil, "Atributos: distribua os pontos base."
	end
	for chave in atributoBase do
		if type(chave) ~= "string" or not ATRIBUTO_VALIDO[chave] then
			return nil, "Atributos: campo desconhecido."
		end
	end
	local baseNormalizada = {}
	local gastos, faltas = 0, { [-1] = 0, [-2] = 0 }
	for _, atributo in ATRIBUTOS do
		local valor = atributoBase[atributo]
		if type(valor) ~= "number" or valor % 1 ~= 0 or valor < -2 or valor > 4 then
			return nil, "Atributos: valor fora do limite da criação."
		end
		baseNormalizada[atributo] = valor
		gastos += math.max(0, valor)
		if valor == -1 or valor == -2 then
			faltas[valor] += 1
			if faltas[valor] > 1 then
				return nil, "Atributos: cada defeito só pode ser escolhido uma vez."
			end
		end
	end
	local orcamento = 2 + (faltas[-1] > 0 and 1 or 0) + (faltas[-2] > 0 and 2 or 0)
	if gastos ~= orcamento then
		if gastos > orcamento then
			return nil, string.format("Atributos: %d pontos de atributo a mais que o permitido.", gastos - orcamento)
		end
		return nil, string.format("Atributos: distribua todos os pontos de atributo (%d restantes).", orcamento - gastos)
	end

	local escolhasRaciais = construcao.raceAttributeChoices
	if not densa(escolhasRaciais) or #escolhasRaciais ~= quantidade(raca.data.attributeChoices) then
		return nil, "Raça: complete as escolhas de atributo da raça."
	end
	for _, atributo in escolhasRaciais do
		if not ATRIBUTO_VALIDO[atributo] then
			return nil, "Raça: atributo racial inválido."
		end
	end

	local escolhasLivres = construcao.freeSkillChoiceIds
	if not densa(escolhasLivres) or not semRepetir(escolhasLivres) then
		return nil, "Perícias: escolhas de perícia de raça/antecedente inválidas."
	end
	local quantidadePericiasLivres = quantidade(raca.data.bonusSkillChoices) + quantidade(antecedente.data.bonusSkillChoices)
	if #escolhasLivres ~= quantidadePericiasLivres then
		return nil, "Perícias: complete as escolhas de perícia de raça e antecedente."
	end
	for _, skillId in escolhasLivres do
		if not entrada(catalogo, skillId, "skill") then
			return nil, "Perícia de raça/antecedente não existe no catálogo."
		end
	end

	local idSubtabela = construcao.subtableEntryId
	local exigeSubtabela = antecedente.data.requiresSubtable
	if exigeSubtabela then
		if type(idSubtabela) ~= "string" then
			return nil, "Antecedente: escolha uma opção da subtabela do antecedente."
		end
		local subentrada = entrada(catalogo, idSubtabela, "subtable-entry")
		if not subentrada or subentrada.data.subtableId ~= exigeSubtabela then
			return nil, "Antecedente: opção de subtabela incompatível com o antecedente."
		end
	elseif idSubtabela ~= nil then
		return nil, "Antecedente: este antecedente não usa subtabela."
	end

	local escolhasArvore = construcao.treeSkillChoiceIds
	if not densa(escolhasArvore) or not semRepetir(escolhasArvore) then
		return nil, "Perícias: escolhas de perícia inválidas."
	end
	local escolha = arvore and arvore.data.grantedSkills and arvore.data.grantedSkills.choose
	local quantidadeEscolhas = escolha and quantidade(escolha.count) or 0
	if #escolhasArvore ~= quantidadeEscolhas then
		return nil, "Árvore inicial: complete as escolhas de perícia da árvore inicial."
	end
	local permitidas = {}
	for _, nome in escolha and escolha.from or {} do
		permitidas[nome] = true
	end
	for _, skillId in escolhasArvore do
		local skill = entrada(catalogo, skillId, "skill")
		if not skill or not permitidas[skill.data.name] then
			return nil, "Árvore inicial: perícia não disponível nesta árvore."
		end
	end
	-- A escolha livre precisa acrescentar uma perícia; UI e servidor compartilham
	-- a derivação das concessões iniciais para evitar opções que seriam deduplicadas.
	local periciasJaConcedidas = PericiasDeCriacao.idsJaConcedidos(
		catalogo, raca.id, antecedente.id, arvore and arvore.id, escolhasArvore
	)
	for _, skillId in escolhasLivres do
		if periciasJaConcedidas[skillId] then
			return nil, "Perícias: a perícia livre já é concedida pela raça, antecedente ou árvore."
		end
	end
	local gruposDeArma = arvore and arvore.data.proficiencies and arvore.data.proficiencies.gruposDeArma or {}
	if not densa(gruposDeArma) or not semRepetir(gruposDeArma) then
		return nil, "Grupos de arma da árvore inicial inválidos no catálogo."
	end
	-- O livro dá o grupo Desarmado e Improvisado como piso a todos; grupos
	-- adicionais vêm das árvores abertas. Neste recorte há só a árvore inicial.
	local weaponGroupIds = { "weapon-group/desarmado-e-improvisado" }
	if not entrada(catalogo, weaponGroupIds[1], "weapon-group") then
		return nil, "Grupo básico de arma não existe no catálogo."
	end
	for _, grupoId in gruposDeArma do
		if type(grupoId) ~= "string" or not entrada(catalogo, "weapon-group/" .. grupoId, "weapon-group") then
			return nil, "Grupo de arma da árvore inicial não existe no catálogo."
		end
		table.insert(weaponGroupIds, "weapon-group/" .. grupoId)
	end

	return {
		raceId = raca.id,
		raceChosen = true,
		backgroundId = antecedente.id,
		backgroundChosen = true,
		subtableEntryId = idSubtabela,
		attributeBase = baseNormalizada,
		raceAttributeChoices = table.clone(escolhasRaciais),
		skillIds = table.clone(escolhasLivres),
		startingTreeId = arvore and arvore.id,
		unlockedRankIds = if rankInicial then { rankInicial.id } else {},
		treeSkillChoiceIds = table.clone(escolhasArvore),
		weaponGroupIds = weaponGroupIds,
		pontosAprimoramento = {
			iniciais = PA_INICIAIS,
			custoEscolhaRaca = custoRaca,
			restantes = PA_INICIAIS - custoRaca,
		},
	}, nil
end

-- Prévia calculada para criação: ignora qualquer número derivado vindo do
-- cliente e parte da construção recém-validada pelo servidor.
function CriacaoPersonagem.calcular(construcao, catalogo)
	local normalizada, erro = CriacaoPersonagem.validar(construcao, catalogo)
	if not normalizada then
		return nil, erro
	end
	local atributos = AtributosPersonagem.finais(normalizada, catalogo)
	local pericias = PericiasPersonagem.calcularTodas(normalizada, catalogo, atributos, RegrasLivro.bonusDeRank)
	local estatisticas, erroEstatisticas = EstatisticasPersonagem.calcular(normalizada, catalogo, atributos)
	if not estatisticas then
		return nil, erroEstatisticas
	end
	local arvore = catalogo.POR_ID[normalizada.startingTreeId]
	local subgrupo = arvore and arvore.data.subgroup
	local kit = type(subgrupo) == "string" and KitsIniciais.obter(subgrupo) or nil
	if arvore and (type(kit) ~= "table" or type(kit.items) ~= "table" or #kit.items == 0) then
		return nil, "Esta árvore ainda não tem um kit inicial jogável."
	end
	local kitInicial, inventarioInicial = nil, {}
	if kit then
		local itens, inventario = {}, {}
		for indice, item in kit.items do
			local copia = table.clone(item)
			table.insert(itens, copia)
			table.insert(inventario, {
				sourceLocalId = string.format("kit-inicial-%02d", indice),
				name = item.name,
				type = item.type,
				equipped = false,
				baseDie = item.baseDie,
				armorClassBonus = item.acBonus,
				description = item.description,
			})
		end
		kitInicial = { subgrupo = kit.subgroup, itens = itens }
		inventarioInicial = inventario
	end
	return {
		construcao = normalizada,
		atributos = atributos,
		pericias = pericias,
		estatisticas = estatisticas,
		pontosAprimoramento = table.clone(normalizada.pontosAprimoramento),
		kitInicial = kitInicial,
		inventarioInicial = inventarioInicial,
	}, nil
end

return CriacaoPersonagem
