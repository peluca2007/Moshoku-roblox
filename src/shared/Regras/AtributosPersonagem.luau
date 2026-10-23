-- Cálculo puro dos atributos finais da ficha própria (J1, primeiro recorte).
-- Replica selectors.ts:getFinalAttribute; não altera ficha v2 importada nem
-- substitui os cálculos aceitos pelo mestre no fluxo legado.
local AtributosPersonagem = {}

local ATRIBUTOS = { "forca", "agilidade", "vigor", "intelecto", "espirito" }

local function bonusAtributo(entrada, atributo): number
	return entrada and entrada.data and entrada.data.bonuses
		and entrada.data.bonuses.attributes and entrada.data.bonuses.attributes[atributo] or 0
end

local function entrada(catalogo, especie: string, id: string?)
	if type(id) ~= "string" then
		return nil
	end
	local encontrada = catalogo.POR_ID[id]
	if encontrada and encontrada.kind == especie then
		return encontrada
	end
	return nil
end

-- Mesma soma de selectors.ts: base + bônus fixos de raça/antecedente/subtabela
-- + escolhas raciais limitadas ao número concedido pela raça.
function AtributosPersonagem.finais(construcao, catalogo): { [string]: number }
	local raca = entrada(catalogo, "race", construcao.raceId)
	local antecedente = entrada(catalogo, "background", construcao.backgroundId)
	local subtabela = entrada(catalogo, "subtable-entry", construcao.subtableEntryId)
	if not antecedente or not antecedente.data.requiresSubtable
		or not subtabela or subtabela.data.subtableId ~= antecedente.data.requiresSubtable then
		subtabela = nil
	end

	local escolhas = {}
	local limite = raca and raca.data.attributeChoices or 0
	for indice, atributo in ipairs(construcao.raceAttributeChoices or {}) do
		if indice > limite then
			break
		end
		if type(atributo) == "string" then
			escolhas[atributo] = (escolhas[atributo] or 0) + 1
		end
	end

	local resultado = {}
	for _, atributo in ATRIBUTOS do
		local base = (construcao.attributeBase or {})[atributo] or 0
		resultado[atributo] = base
			+ bonusAtributo(raca, atributo)
			+ bonusAtributo(antecedente, atributo)
			+ bonusAtributo(subtabela, atributo)
			+ (escolhas[atributo] or 0)
	end
	return resultado
end

return AtributosPersonagem
