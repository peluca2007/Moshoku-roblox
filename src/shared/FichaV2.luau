-- Validação do envelope da ficha v2 (docs/CONTRATOS.md §4 e §5.4, com as emendas
-- E1–E4 da T23a). Recebe a tabela já decodificada (depois do JsonEstrutura e do
-- JSONDecode) e devolve uma cópia contendo só os campos conhecidos.
-- Puro: não cria Instances, não filtra texto. O catálogo é injetado.
--
-- Política:
-- - Chave desconhecida, tipo errado ou número fora do limite: recusa a ficha.
-- - ID de catálogo bem formado mas ausente deste catálogo: aviso e
--   constructionComplete = false (o site pode estar numa revisão mais nova).
-- - Recursos atuais acima do máximo: reduzidos com aviso (§4.4).
-- - Os números de "calculated" são a foto do site, aprovada pelo mestre; não são
--   recalculados aqui (compatibility = "master-approved-snapshot").
local FichaV2 = {}

FichaV2.EXPORTADOR_PREFIXO = "ficha-v2/"

local ATRIBUTOS = { "forca", "agilidade", "vigor", "intelecto", "espirito" }
local EH_ATRIBUTO = { forca = true, agilidade = true, vigor = true, intelecto = true, espirito = true }
local RECURSOS = { "pv", "pm", "pt", "pp" }
local TIPOS_DE_ITEM = { arma = true, armadura = true, geral = true }
local RANKS_DA_GUILDA = { F = true, E = true, D = true, C = true, B = true, A = true, S = true }

-- Limites de transporte (os mesmos do exportador), não regras do livro.
FichaV2.LIMITES = table.freeze({
	nome = 32,
	listaIds = 256,
	ranks = 512,
	compras = 1024,
	inventario = 256,
	condicoes = 12,
	notaCondicao = 60,
	avisos = 64,
	estado = 9999,
})

local Falha = {}

local function falhar(campo: string, motivo: string): never
	error(setmetatable({ mensagem = campo .. ": " .. motivo }, Falha), 0)
end

local function inteiro(valor: any, campo: string, minimo: number, maximo: number): number
	if type(valor) ~= "number" or valor ~= valor or valor % 1 ~= 0 then
		falhar(campo, "esperado inteiro")
	end
	if valor < minimo or valor > maximo then
		falhar(campo, "fora do intervalo " .. minimo .. " a " .. maximo)
	end
	return valor
end

local function booleano(valor: any, campo: string): boolean
	if type(valor) ~= "boolean" then
		falhar(campo, "esperado verdadeiro ou falso")
	end
	return valor
end

-- Texto UTF-8 sem caracteres de controle (exceto quebra de linha e tabulação
-- quando multilinha). Conta pontos de código e bytes.
local function texto(valor: any, campo: string, maxBytes: number, minCar: number, maxCar: number?, multilinha: boolean?): string
	if type(valor) ~= "string" then
		falhar(campo, "esperado texto")
	end
	local quantidade = utf8.len(valor)
	if not quantidade then
		falhar(campo, "UTF-8 inválido")
	end
	if #valor > maxBytes then
		falhar(campo, "texto excede " .. maxBytes .. " bytes")
	end
	if quantidade < minCar or (maxCar and quantidade > maxCar) then
		falhar(campo, "quantidade de caracteres fora do formato")
	end
	for _, codigo in utf8.codes(valor) do
		if (codigo < 32 or codigo == 127) and not (multilinha and (codigo == 10 or codigo == 9)) then
			falhar(campo, "caractere de controle não permitido")
		end
	end
	return valor
end

local function objeto(valor: any, campo: string, permitidas: { [string]: boolean }): { [string]: any }
	if type(valor) ~= "table" then
		falhar(campo, "esperado objeto")
	end
	for chave in valor do
		if type(chave) ~= "string" then
			falhar(campo, "objeto com chave não textual")
		end
		if not permitidas[chave] then
			falhar(campo .. "." .. chave, "campo desconhecido")
		end
	end
	return valor
end

-- Lista densa 1..n. O JSONDecode devolve {} tanto para [] quanto para {}.
local function lista(valor: any, campo: string, maximo: number): { any }
	if type(valor) ~= "table" then
		falhar(campo, "esperada lista")
	end
	local n = 0
	for chave in valor do
		if type(chave) ~= "number" or chave % 1 ~= 0 or chave < 1 then
			falhar(campo, "esperada lista")
		end
		n += 1
	end
	if n ~= #valor then
		falhar(campo, "lista com lacunas")
	end
	if n > maximo then
		falhar(campo, "mais de " .. maximo .. " entradas")
	end
	return valor
end

local function conjunto(chaves: { string }): { [string]: boolean }
	local resultado = {}
	for _, chave in chaves do
		resultado[chave] = true
	end
	return resultado
end

-- Contexto de uma validação: catálogo e avisos acumulados.
type Contexto = { catalogo: any?, avisos: { string }, incompleta: boolean, faltando: { [string]: boolean } }

-- "espécie/segmento(/segmento)*", segmentos percent-encoded (CONTRATOS §2.1).
local function idCatalogo(ctx: Contexto, valor: any, campo: string, especies: { [string]: boolean }): string
	texto(valor, campo, 256, 1)
	if not string.match(valor, "^[%w%-]+/[%w%-%._~%%]+[%w%-%._~%%/]*$") or string.find(valor, "//", 1, true) or string.sub(valor, -1) == "/" then
		falhar(campo, "ID de catálogo malformado")
	end
	local especie = string.match(valor, "^([^/]+)/")
	if not especies[especie] then
		falhar(campo, "espécie inesperada (" .. especie .. ")")
	end
	if ctx.catalogo then
		local entrada = ctx.catalogo.POR_ID[valor]
		if not entrada then
			ctx.incompleta = true
			if not ctx.faltando[valor] then
				ctx.faltando[valor] = true
				table.insert(ctx.avisos, "Fora do catálogo desta mesa: " .. valor)
			end
		elseif entrada.kind ~= especie then
			falhar(campo, "ID aponta para outra espécie")
		end
	end
	return valor
end

local function listaDeIds(ctx: Contexto, valor: any, campo: string, maximo: number, especies: { [string]: boolean }): { string }
	local resultado, vistos = {}, {}
	for indice, id in lista(valor, campo, maximo) do
		local limpo = idCatalogo(ctx, id, campo .. "[" .. indice .. "]", especies)
		if vistos[limpo] then
			falhar(campo, "ID repetido: " .. limpo)
		end
		vistos[limpo] = true
		table.insert(resultado, limpo)
	end
	return resultado
end

local function atributos(valor: any, campo: string): { [string]: number }
	objeto(valor, campo, EH_ATRIBUTO)
	local resultado = {}
	for _, chave in ATRIBUTOS do
		resultado[chave] = inteiro(valor[chave], campo .. "." .. chave, -20, 50)
	end
	return resultado
end

local function listaDeAtributos(valor: any, campo: string, unicos: boolean): { string }
	local resultado, vistos = {}, {}
	for indice, chave in lista(valor, campo, #ATRIBUTOS * 4) do
		if not EH_ATRIBUTO[chave] then
			falhar(campo .. "[" .. indice .. "]", "atributo desconhecido")
		end
		if unicos and vistos[chave] then
			falhar(campo, "atributo repetido")
		end
		vistos[chave] = true
		table.insert(resultado, chave)
	end
	return resultado
end

local function movimento(valor: any, campo: string): number
	if type(valor) ~= "number" or valor ~= valor or valor < 0 or valor > 999 or valor ~= math.round(valor * 10) / 10 then
		falhar(campo, "esperado 0 a 999 metros, com até uma casa decimal")
	end
	return valor
end

local function opcional(valor: any, validar: (any) -> any): any
	if valor == nil then
		return nil
	end
	return validar(valor)
end

local SO = function(...)
	return conjunto({ ... })
end

-- Construção (§4.2 emendada) --------------------------------------------------

local CHAVES_CONSTRUCAO = SO(
	"raceId", "raceChosen", "backgroundId", "backgroundChosen", "subtableEntryId",
	"attributeBase", "raceAttributeChoices", "racialUpgradeIds", "saveAdvantages",
	"startingTreeId", "unlockedRankIds", "purchasedIds", "combinedSpellIds", "skillIds",
	"treeSkillChoiceIds", "proficiencyTexts", "weaponGroupIds", "bonusHp", "bonusMp",
	"gold", "inventory", "overrides"
)
local CHAVES_ITEM = SO(
	"sourceLocalId", "name", "type", "equipped", "description", "armorClassBonus",
	"baseDie", "damageAttribute", "treatmentsUsed"
)
local CHAVES_OVERRIDES = SO("maxHp", "maxMp", "maxPt", "maxPp", "armorClass", "initiative", "guildRank")

local function inventario(valor: any): { any }
	local resultado, vistos = {}, {}
	for indice, item in lista(valor, "Inventário", FichaV2.LIMITES.inventario) do
		local campo = "Inventário[" .. indice .. "]"
		objeto(item, campo, CHAVES_ITEM)
		local limpo = {
			sourceLocalId = texto(item.sourceLocalId, campo .. ".sourceLocalId", 128, 1),
			name = texto(item.name, campo .. ".name", 256, 1, 128),
			type = item.type,
			equipped = booleano(item.equipped, campo .. ".equipped"),
			description = opcional(item.description, function(v)
				return texto(v, campo .. ".description", 2048, 0, nil, true)
			end),
			armorClassBonus = opcional(item.armorClassBonus, function(v)
				return inteiro(v, campo .. ".armorClassBonus", -99, 99)
			end),
			baseDie = opcional(item.baseDie, function(v)
				return texto(v, campo .. ".baseDie", 256, 1)
			end),
			damageAttribute = opcional(item.damageAttribute, function(v)
				if not EH_ATRIBUTO[v] then
					falhar(campo .. ".damageAttribute", "atributo desconhecido")
				end
				return v
			end),
			treatmentsUsed = opcional(item.treatmentsUsed, function(v)
				return inteiro(v, campo .. ".treatmentsUsed", 0, 9999)
			end),
		}
		if not TIPOS_DE_ITEM[item.type] then
			falhar(campo .. ".type", "tipo de item desconhecido")
		end
		if vistos[limpo.sourceLocalId] then
			falhar(campo, "item repetido")
		end
		vistos[limpo.sourceLocalId] = true
		table.insert(resultado, limpo)
	end
	return resultado
end

local function overrides(valor: any): { [string]: any }
	objeto(valor, "Overrides", CHAVES_OVERRIDES)
	local resultado = {}
	for _, chave in { "maxHp", "maxMp", "maxPt", "maxPp" } do
		resultado[chave] = opcional(valor[chave], function(v)
			return inteiro(v, "Overrides." .. chave, 0, 9999)
		end)
	end
	resultado.armorClass = opcional(valor.armorClass, function(v)
		return inteiro(v, "Overrides.armorClass", 0, 99)
	end)
	resultado.initiative = opcional(valor.initiative, function(v)
		return inteiro(v, "Overrides.initiative", -50, 50)
	end)
	resultado.guildRank = opcional(valor.guildRank, function(v)
		if not RANKS_DA_GUILDA[v] then
			falhar("Overrides.guildRank", "rank da guilda desconhecido")
		end
		return v
	end)
	return resultado
end

local function construcao(ctx: Contexto, valor: any)
	objeto(valor, "Construção", CHAVES_CONSTRUCAO)
	local L = FichaV2.LIMITES
	local textos = {}
	for indice, proficiencia in lista(valor.proficiencyTexts, "Proficiências livres", L.listaIds) do
		table.insert(textos, texto(proficiencia, "Proficiências livres[" .. indice .. "]", 256, 1, 128))
	end
	return {
		raceId = opcional(valor.raceId, function(v)
			return idCatalogo(ctx, v, "Raça", SO("race"))
		end),
		raceChosen = booleano(valor.raceChosen, "Raça escolhida"),
		backgroundId = opcional(valor.backgroundId, function(v)
			return idCatalogo(ctx, v, "Antecedente", SO("background"))
		end),
		backgroundChosen = booleano(valor.backgroundChosen, "Antecedente escolhido"),
		subtableEntryId = opcional(valor.subtableEntryId, function(v)
			return idCatalogo(ctx, v, "Subentrada", SO("subtable-entry"))
		end),
		attributeBase = atributos(valor.attributeBase, "Atributos base"),
		raceAttributeChoices = listaDeAtributos(valor.raceAttributeChoices, "Escolhas de atributo da raça", false),
		racialUpgradeIds = listaDeIds(ctx, valor.racialUpgradeIds, "Aprimoramentos raciais", L.listaIds, SO("race-upgrade")),
		saveAdvantages = listaDeAtributos(valor.saveAdvantages, "Vantagens de resistência", true),
		startingTreeId = opcional(valor.startingTreeId, function(v)
			return idCatalogo(ctx, v, "Árvore inicial", SO("tree"))
		end),
		unlockedRankIds = listaDeIds(ctx, valor.unlockedRankIds, "Ranks", L.ranks, SO("rank")),
		purchasedIds = listaDeIds(ctx, valor.purchasedIds, "Compras", L.compras, SO("ability", "talent")),
		combinedSpellIds = listaDeIds(ctx, valor.combinedSpellIds, "Magias combinadas", L.listaIds, SO("combined-spell")),
		skillIds = listaDeIds(ctx, valor.skillIds, "Perícias", L.listaIds, SO("skill")),
		treeSkillChoiceIds = listaDeIds(ctx, valor.treeSkillChoiceIds, "Perícias da árvore", L.listaIds, SO("skill")),
		proficiencyTexts = textos,
		weaponGroupIds = listaDeIds(ctx, valor.weaponGroupIds, "Grupos de arma", L.listaIds, SO("weapon-group")),
		bonusHp = inteiro(valor.bonusHp, "Bônus de PV", 0, 9999),
		bonusMp = inteiro(valor.bonusMp, "Bônus de PM", 0, 9999),
		gold = inteiro(valor.gold, "Ouro", 0, 1000000000),
		inventory = inventario(valor.inventory),
		overrides = overrides(valor.overrides),
	}
end

-- Calculados (§4.3) ------------------------------------------------------------

local CHAVES_CALCULADOS = SO(
	"attributes", "maxima", "armorClass", "movementMeters", "initiative",
	"highestRankBonus", "skills", "actionContexts", "paSpent"
)

local function recursos(valor: any, campo: string): { [string]: number }
	objeto(valor, campo, conjunto(RECURSOS))
	local resultado = {}
	for _, chave in RECURSOS do
		resultado[chave] = inteiro(valor[chave], campo .. "." .. chave, 0, FichaV2.LIMITES.estado)
	end
	return resultado
end

local function calculados(ctx: Contexto, valor: any)
	objeto(valor, "Calculados", CHAVES_CALCULADOS)
	objeto(valor.initiative, "Iniciativa", SO("bonus", "advantage"))
	local pericias, vistas = {}, {}
	for indice, pericia in lista(valor.skills, "Perícias calculadas", FichaV2.LIMITES.listaIds) do
		local campo = "Perícias calculadas[" .. indice .. "]"
		objeto(pericia, campo, SO("skillId", "bonus", "trained"))
		local id = idCatalogo(ctx, pericia.skillId, campo .. ".skillId", SO("skill"))
		if vistas[id] then
			falhar(campo, "perícia repetida")
		end
		vistas[id] = true
		table.insert(pericias, {
			skillId = id,
			bonus = inteiro(pericia.bonus, campo .. ".bonus", -9999, 9999),
			trained = booleano(pericia.trained, campo .. ".trained"),
		})
	end
	-- ficha-v2/1 não exporta contextos de ação: o executor os calcula (T23a).
	if #lista(valor.actionContexts, "Contextos de ação", 0) ~= 0 then
		falhar("Contextos de ação", "não suportados nesta versão")
	end
	return {
		attributes = atributos(valor.attributes, "Atributos"),
		maxima = recursos(valor.maxima, "Máximos"),
		armorClass = inteiro(valor.armorClass, "CA", 0, 99),
		movementMeters = movimento(valor.movementMeters, "Deslocamento"),
		initiative = {
			bonus = inteiro(valor.initiative.bonus, "Iniciativa.bonus", -50, 50),
			advantage = booleano(valor.initiative.advantage, "Iniciativa.advantage"),
		},
		highestRankBonus = inteiro(valor.highestRankBonus, "Maior bônus de Rank", 0, 12),
		skills = pericias,
		actionContexts = {},
		paSpent = inteiro(valor.paSpent, "PA gasto", 0, 1000000000),
	}
end

-- Sessão (§4.4) ----------------------------------------------------------------

local function sessao(ctx: Contexto, valor: any, maximos: { [string]: number })
	objeto(valor, "Sessão", SO("current", "conditions", "shortRests", "manualEffects"))
	local atuais = recursos(valor.current, "Recursos atuais")
	for _, chave in RECURSOS do
		if atuais[chave] > maximos[chave] then
			table.insert(ctx.avisos, string.format("%s atual %d acima do máximo %d; reduzido.", string.upper(chave), atuais[chave], maximos[chave]))
			atuais[chave] = maximos[chave]
		end
	end
	local condicoes, vistas = {}, {}
	for indice, condicao in lista(valor.conditions, "Condições", FichaV2.LIMITES.condicoes) do
		local campo = "Condições[" .. indice .. "]"
		objeto(condicao, campo, SO("conditionId", "stacks", "note", "sourceRankBonus"))
		local id = idCatalogo(ctx, condicao.conditionId, campo .. ".conditionId", SO("condition"))
		if vistas[id] then
			falhar(campo, "condição repetida")
		end
		vistas[id] = true
		table.insert(condicoes, {
			conditionId = id,
			stacks = inteiro(condicao.stacks, campo .. ".stacks", 1, 12),
			note = opcional(condicao.note, function(v)
				return texto(v, campo .. ".note", 240, 0, FichaV2.LIMITES.notaCondicao)
			end),
			sourceRankBonus = opcional(condicao.sourceRankBonus, function(v)
				return inteiro(v, campo .. ".sourceRankBonus", 0, 12)
			end),
		})
	end
	if #lista(valor.manualEffects, "Efeitos manuais", 0) ~= 0 then
		falhar("Efeitos manuais", "não suportados nesta versão")
	end
	return {
		current = atuais,
		conditions = condicoes,
		shortRests = opcional(valor.shortRests, function(v)
			return inteiro(v, "Descansos curtos", 0, 2)
		end),
		manualEffects = {},
	}
end

-- Entrada ------------------------------------------------------------------

local CHAVES_ENVELOPE = SO(
	"mesa", "envelopeVersion", "exporterVersion", "compatibility", "sourceCharacterId",
	"name", "constructionComplete", "omissions", "warnings", "construction", "calculated", "session"
)
-- O corpo guardado na mesa (e salvo na campanha): o envelope sem o cabeçalho de transporte.
local CHAVES_CORPO = SO(
	"exporterVersion", "sourceCharacterId", "name", "constructionComplete",
	"omissions", "warnings", "construction", "calculated", "session"
)

local function avisosDoSite(valor: any, campo: string): { string }
	local resultado = {}
	for indice, aviso in lista(valor, campo, FichaV2.LIMITES.avisos) do
		table.insert(resultado, texto(aviso, campo .. "[" .. indice .. "]", 512, 1, 256))
	end
	return resultado
end

local function nome(valor: any): string
	texto(valor, "Nome", 128, 1, FichaV2.LIMITES.nome)
	local aparado = string.match(valor, "^%s*(.-)%s*$")
	if aparado == "" then
		falhar("Nome", "vazio")
	end
	return aparado
end

local function corpo(ctx: Contexto, valor: any)
	local exportador = texto(valor.exporterVersion, "exporterVersion", 64, 1)
	if string.sub(exportador, 1, #FichaV2.EXPORTADOR_PREFIXO) ~= FichaV2.EXPORTADOR_PREFIXO then
		falhar("exporterVersion", "exportador desconhecido")
	end
	local calc = calculados(ctx, valor.calculated)
	local resultado = {
		exporterVersion = exportador,
		sourceCharacterId = texto(valor.sourceCharacterId, "ID local da ficha", 128, 1),
		name = nome(valor.name),
		constructionComplete = booleano(valor.constructionComplete, "constructionComplete"),
		omissions = avisosDoSite(valor.omissions, "Omissões"),
		warnings = avisosDoSite(valor.warnings, "Avisos do site"),
		construction = construcao(ctx, valor.construction),
		calculated = calc,
		session = sessao(ctx, valor.session, calc.maxima),
	}
	if ctx.incompleta then
		resultado.constructionComplete = false
	end
	return resultado
end

local function executar(fn: () -> any): (any, string?)
	local ok, resultado = pcall(fn)
	if ok then
		return resultado, nil
	end
	if type(resultado) == "table" and getmetatable(resultado) == Falha then
		return nil, resultado.mensagem
	end
	error(resultado, 0)
end

-- Envelope recebido do site. catalogo: { POR_ID = {...} } ou nil (só formato).
-- Devolve (corpo, nil, avisos) ou (nil, motivo, avisos).
function FichaV2.validar(envelope: any, catalogo: any?): (any?, string?, { string })
	local ctx: Contexto = { catalogo = catalogo, avisos = {}, incompleta = false, faltando = {} }
	local resultado, falha = executar(function()
		objeto(envelope, "Envelope", CHAVES_ENVELOPE)
		if envelope.mesa ~= 2 then
			falhar("mesa", "esperado 2 (ficha v2)")
		end
		if envelope.envelopeVersion ~= 2 then
			falhar("envelopeVersion", "versão de envelope desconhecida")
		end
		if envelope.compatibility ~= "master-approved-snapshot" then
			falhar("compatibility", "modo desconhecido")
		end
		return corpo(ctx, envelope)
	end)
	return resultado, falha, ctx.avisos
end

-- Corpo já aceito antes (campanha salva). Revalida tudo, com ou sem catálogo.
function FichaV2.validarCorpo(valor: any, catalogo: any?): (any?, string?, { string })
	local ctx: Contexto = { catalogo = catalogo, avisos = {}, incompleta = false, faltando = {} }
	local resultado, falha = executar(function()
		objeto(valor, "Ficha v2", CHAVES_CORPO)
		return corpo(ctx, valor)
	end)
	return resultado, falha, ctx.avisos
end

-- Textos do jogador que precisam passar pelo filtro do Roblox antes de aparecer
-- para outra pessoa. Cada item: { tabela, chave }; o servidor troca o valor.
function FichaV2.textos(c): { { any } }
	local refs = { { c, "name" } }
	for indice in c.construction.proficiencyTexts do
		table.insert(refs, { c.construction.proficiencyTexts, indice })
	end
	for _, item in c.construction.inventory do
		table.insert(refs, { item, "name" })
		if item.description and item.description ~= "" then
			table.insert(refs, { item, "description" })
		end
	end
	for _, condicao in c.session.conditions do
		if condicao.note and condicao.note ~= "" then
			table.insert(refs, { condicao, "note" })
		end
	end
	for _, campo in { "warnings", "omissions" } do
		for indice in c[campo] do
			table.insert(refs, { c[campo], indice })
		end
	end
	return refs
end

-- Campos da ficha da mesa derivados do corpo (formato achatado de token.sheet
-- e condições no formato da mesa).
function FichaV2.paraMesa(c)
	local calc = c.calculated
	local condicoes = {}
	for _, condicao in c.session.conditions do
		table.insert(condicoes, {
			id = string.sub(condicao.conditionId, #"condition/" + 1),
			stacks = condicao.stacks,
			note = if condicao.note and condicao.note ~= "" then condicao.note else nil,
		})
	end
	return {
		pvMax = calc.maxima.pv,
		manaMax = calc.maxima.pm,
		pv = c.session.current.pv,
		mana = c.session.current.pm,
		sheet = {
			forca = calc.attributes.forca,
			agilidade = calc.attributes.agilidade,
			vigor = calc.attributes.vigor,
			intelecto = calc.attributes.intelecto,
			espirito = calc.attributes.espirito,
			ca = calc.armorClass,
			deslocamento = calc.movementMeters,
			iniciativa = calc.initiative.bonus,
			vantagemIniciativa = calc.initiative.advantage,
		},
		conditions = condicoes,
	}
end

return FichaV2
