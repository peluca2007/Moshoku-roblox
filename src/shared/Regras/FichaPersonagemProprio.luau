-- Corpo interno para um personagem recém-criado pelo servidor (J1).
-- Não é envelope de importação nem aprovação do mestre. O chamador deve guardar
-- a identidade do dono e fornecer um nome que já passou pelo filtro do Roblox.
-- Nenhum dado de calculated/session alternativo é recebido por esta API.
local FichaPersonagemProprio = {}
local Shared = game:GetService("ReplicatedStorage").Shared
local FichaV2 = require(Shared.FichaV2)
local CriacaoPersonagem = require(Shared.Regras.CriacaoPersonagem)
local Progressao = require(Shared.Regras.Progressao)
local Armas = require(Shared.Regras.Armas)
local Dojo = require(Shared.Regras.Dojo)
local ItensLoja = require(Shared.Livro.Dados.Itens)
local RegraLoja = require(Shared.Regras.Loja)
local Missao = require(Shared.Regras.Missao)
local MissoesDados = require(Shared.Mundo.MissoesDados)

local ArvoresAprendidas = require(Shared.Regras.ArvoresAprendidas)

local ERRO_PERFIL = "Perfil inicial incompleto ou incompatível."
local CAMPOS_PERFIL = {
	nome = true, arvoresAprendidas = true, paGanhos = true,
	habilidadesCompradas = true,
	armaInicialSourceLocalId = true,
	descanso = true,
	dojo = true,
	ouro = true, encontrosPagos = true,
	inventarioLoja = true, itensVendidos = true,
	missoes = true,
	construcao = true, atributos = true, pericias = true, estatisticas = true,
	pontosAprimoramento = true, kitInicial = true, inventarioInicial = true,
}

-- Compara apenas tabelas produzidas pelo cálculo puro. Também recusa campos
-- extras e valores derivados substituídos, sem usar esses valores para a ficha.
local function iguais(a, b, profundidade): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	if profundidade > 12 then
		return false
	end
	for chave, valor in a do
		if not iguais(valor, b[chave], profundidade + 1) then
			return false
		end
	end
	for chave in b do
		if a[chave] == nil then
			return false
		end
	end
	return true
end

-- Revalida o perfil fechado do recorte inicial contra o mesmo cálculo puro.
-- Isto impede usar um snapshot importado, um perfil parcial ou uma construção
-- ampliada com compras/overrides nesta entrada, mesmo por engano do chamador.
local function validarPerfil(perfil, catalogo)
	if type(perfil) ~= "table" or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table" then
		return nil
	end
	local okComprimento, comprimento = false, nil
	if type(perfil.nome) == "string" then okComprimento, comprimento = pcall(utf8.len, perfil.nome) end
	if type(perfil.nome) ~= "string" or #perfil.nome > 128 or not okComprimento
		or type(comprimento) ~= "number" or comprimento < 1 or comprimento > 32
		or string.find(perfil.nome, "%c") or string.gsub(perfil.nome, "^%s*(.-)%s*$", "%1") ~= perfil.nome then
		return nil
	end
	for chave in perfil do
		if not CAMPOS_PERFIL[chave] then
			return nil
		end
	end
	local c = perfil.construcao
	if type(c) ~= "table" then
		return nil
	end
	local esperado = CriacaoPersonagem.calcular({
		raceId = c.raceId,
		backgroundId = c.backgroundId,
		subtableEntryId = c.subtableEntryId,
		attributeBase = c.attributeBase,
		raceAttributeChoices = c.raceAttributeChoices,
		freeSkillChoiceIds = c.skillIds,
		startingTreeId = c.startingTreeId,
		treeSkillChoiceIds = c.treeSkillChoiceIds,
	}, catalogo)
	if not esperado or not esperado.kitInicial or not esperado.inventarioInicial
		or #esperado.kitInicial.itens == 0 then return nil end
	esperado = ArvoresAprendidas.aplicar(esperado, perfil.arvoresAprendidas or {}, catalogo)
	if not esperado then return nil end
	local inventarioKit = esperado.inventarioInicial
	if (perfil.inventarioLoja ~= nil and type(perfil.inventarioLoja) ~= "table")
		or (perfil.itensVendidos ~= nil and type(perfil.itensVendidos) ~= "table") then return nil end
	local inventarioAlterado = #(perfil.inventarioLoja or {}) > 0 or #(perfil.itensVendidos or {}) > 0
	local perfilSemNome = table.clone(perfil)
	perfilSemNome.nome = nil
	perfilSemNome.arvoresAprendidas = nil
	esperado.arvoresAprendidas = nil
	perfilSemNome.paGanhos = nil
	perfilSemNome.habilidadesCompradas = nil
	perfilSemNome.armaInicialSourceLocalId = nil
	perfilSemNome.descanso = nil
	perfilSemNome.dojo = nil
	perfilSemNome.ouro = nil
	perfilSemNome.encontrosPagos = nil
	perfilSemNome.inventarioLoja = nil
	perfilSemNome.itensVendidos = nil
	perfilSemNome.missoes = nil
	if inventarioAlterado then
		perfilSemNome.inventarioInicial = nil
		esperado.inventarioInicial = nil
	end
	if not iguais(perfilSemNome, esperado, 0) then
		return nil
	end
	local compras = perfil.habilidadesCompradas or {}
	if type(compras) ~= "table" or #compras > 96 then return nil end
	local construcao = table.clone(esperado.construcao)
	construcao.unlockedRankIds = table.clone(construcao.unlockedRankIds)
	construcao.purchasedIds = {}
	local vistas = {}
	for indice = 1, #compras do
		local id = compras[indice]
		if type(id) ~= "string" or vistas[id] then return nil end
		local permitido = Progressao.podeComprar(construcao, catalogo, id)
		if not permitido then return nil end
		vistas[id] = true
		table.insert(construcao.purchasedIds, id)
	end
	for chave in compras do
		if type(chave) ~= "number" or chave % 1 ~= 0 or chave < 1 or chave > #compras then return nil end
	end
	local armaSelecionada = perfil.armaInicialSourceLocalId
	if armaSelecionada ~= nil then
		if type(armaSelecionada) ~= "string" or #armaSelecionada == 0 or #armaSelecionada > 128 then return nil end
		local pertenceAoKit = false
		for _, item in inventarioKit do
			if item.sourceLocalId == armaSelecionada and item.type == "arma" then
				pertenceAoKit = true
				break
			end
		end
		if not pertenceAoKit then return nil end
	end
	-- O kit e a arma vêm do catálogo do servidor. A seleção apenas ordena o
	-- inventário para o Disparo e equipa uma arma corpo a corpo para Ataque.
	local inventario, vendidos, fontes, idsKit = {}, {}, {}, {}
	for _, item in inventarioKit do idsKit[item.sourceLocalId] = true end
	for _, localId in ipairs(perfil.itensVendidos or {}) do
		if type(localId) ~= "string" or vendidos[localId] or not idsKit[localId] then return nil end
		vendidos[localId] = true
	end
	for _, item in inventarioKit do
		if not vendidos[item.sourceLocalId] then
		local copia = table.clone(item)
		copia.equipped = armaSelecionada ~= nil and item.sourceLocalId == armaSelecionada
			and not Armas.ehDisparo(item.name)
		fontes[copia.sourceLocalId] = true
		if item.sourceLocalId == armaSelecionada then
			table.insert(inventario, 1, copia)
		else
			table.insert(inventario, copia)
		end
		end
	end
	local porId = {}
	for _, registro in ipairs(ItensLoja) do porId[registro.id] = registro.data end
	for _, comprado in ipairs(perfil.inventarioLoja or {}) do
		local item = porId[comprado.itemId]
		if not item or not RegraLoja.naPrateleira(item, "F") or type(comprado.sourceLocalId) ~= "string"
			or fontes[comprado.sourceLocalId] or type(item.price) ~= "number" then return nil end
		fontes[comprado.sourceLocalId] = true
		table.insert(inventario, { sourceLocalId = comprado.sourceLocalId, name = item.name, type = item.type,
			equipped = false, description = item.description, baseDie = item.baseDie,
			damageAttribute = item.damageAttribute, armorClassBonus = item.acBonus })
	end
	if type(perfil.inventarioInicial) ~= "table" or #perfil.inventarioInicial ~= #inventario then return nil end
	local function semEquipamento(lista)
		local saida = {}
		for indice, item in ipairs(lista) do
			if type(item) ~= "table" or type(item.sourceLocalId) ~= "string" or item.equipped == true then return nil end
			local copia = table.clone(item); copia.equipped = nil
			saida[indice] = copia
		end
		table.sort(saida, function(a, b) return a.sourceLocalId < b.sourceLocalId end)
		return saida
	end
	if inventarioAlterado and not iguais(semEquipamento(perfil.inventarioInicial), semEquipamento(inventario), 0) then return nil end
	esperado.inventarioInicial = inventario
	esperado.nome = perfil.nome
	esperado.armaInicialSourceLocalId = armaSelecionada
	esperado.habilidadesCompradas = table.clone(construcao.purchasedIds)
	if perfil.descanso ~= nil then
		local d = perfil.descanso
		if type(d) ~= "table" or type(d.atuais) ~= "table" or type(d.descansosCurtos) ~= "number"
			or d.descansosCurtos % 1 ~= 0 or d.descansosCurtos < 0 or d.descansosCurtos > 2 then return nil end
		local atuais = {}
		for _, chave in { "pv", "pm", "pt", "pp" } do
			local valor = d.atuais[chave]
			if type(valor) ~= "number" or valor < 0 or valor % 1 ~= 0 then return nil end
			atuais[chave] = math.min(esperado.estatisticas.maxima[chave], valor)
		end
		for chave in d.atuais do if chave ~= "pv" and chave ~= "pm" and chave ~= "pt" and chave ~= "pp" then return nil end end
		esperado.descanso = { atuais = atuais, descansosCurtos = d.descansosCurtos }
	end
	if perfil.dojo ~= nil and not Dojo.estadoValido(perfil.dojo) then return nil end
	if perfil.missoes ~= nil and not Missao.estadoValido(perfil.missoes, MissoesDados.porId()) then return nil end
	if perfil.ouro ~= nil and (type(perfil.ouro) ~= "number" or perfil.ouro < 0 or perfil.ouro % 1 ~= 0) then return nil end
	esperado.ouro = perfil.ouro or 0
	esperado.encontrosPagos = table.clone(perfil.encontrosPagos or {})
	esperado.inventarioLoja = table.clone(perfil.inventarioLoja or {})
	esperado.itensVendidos = table.clone(perfil.itensVendidos or {})
	esperado.missoes = table.clone(perfil.missoes or Missao.novoEstado())
	esperado.inventarioInicial = inventario
	return esperado
end

-- (corpo, nil) ou (nil, mensagem segura). O catálogo é obrigatório: um corpo
-- marcado incompleto pelo validador nunca se torna personagem próprio válido.
function FichaPersonagemProprio.construir(perfilServidor, nomeFiltrado, catalogo)
	local ok, corpo, erro = pcall(function()
		local perfil = validarPerfil(perfilServidor, catalogo)
		if not perfil or perfil.nome ~= nomeFiltrado then
			return nil, ERRO_PERFIL
		end
		local c, stats = perfil.construcao, perfil.estatisticas
		-- Defaults de blankCharacter do site: ainda não há compras, bônus
		-- manuais, ouro, condições ou descansos; recursos null iniciam cheios.
		local candidato = {
			exporterVersion = "ficha-v2/personagem-proprio-1",
			sourceCharacterId = "personagem-proprio/sessao",
			name = nomeFiltrado,
			constructionComplete = true,
			omissions = {}, warnings = {},
			construction = {
				raceId = c.raceId, raceChosen = c.raceChosen,
				backgroundId = c.backgroundId, backgroundChosen = c.backgroundChosen,
				subtableEntryId = c.subtableEntryId,
				attributeBase = c.attributeBase, raceAttributeChoices = c.raceAttributeChoices,
				startingTreeId = c.startingTreeId, unlockedRankIds = c.unlockedRankIds,
				skillIds = c.skillIds, treeSkillChoiceIds = c.treeSkillChoiceIds,
				weaponGroupIds = c.weaponGroupIds,
				 racialUpgradeIds = {}, saveAdvantages = {}, purchasedIds = table.clone(perfil.habilidadesCompradas),
				combinedSpellIds = {}, proficiencyTexts = {},
				bonusHp = 0, bonusMp = 0, gold = perfil.ouro or 0,
				inventory = perfil.inventarioInicial, overrides = {},
			},
			calculated = {
				attributes = perfil.atributos, skills = perfil.pericias,
				maxima = stats.maxima, armorClass = stats.armorClass,
				movementMeters = stats.movementMeters, initiative = stats.initiative,
				-- CriacaoPersonagem só abre Principiante (bônus 1).
				highestRankBonus = 1, actionContexts = {},
				paSpent = perfil.pontosAprimoramento.custoEscolhaRaca,
			},
			session = {
				current = perfil.descanso and perfil.descanso.atuais or stats.maxima,
				conditions = {}, shortRests = perfil.descanso and perfil.descanso.descansosCurtos or 0, manualEffects = {},
			},
		}
		local validado, falha = FichaV2.validarCorpo(candidato, catalogo)
		if not validado or not validado.constructionComplete then
			return nil, if falha then "Não foi possível validar a ficha inicial." else ERRO_PERFIL
		end
		return validado, nil
	end)
	if not ok then
		return nil, ERRO_PERFIL
	end
	return corpo, erro
end

return FichaPersonagemProprio
