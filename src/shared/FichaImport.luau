-- Valida dados já decodificados do código de mesa.
-- Puro: não cria Instances, não filtra texto e não recalcula regras do site.
local Protocol = require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)

local FichaImport = {}

local ATTRIBUTES = { "forca", "agilidade", "vigor", "intelecto", "espirito" }

export type Sheet = {
	forca: number,
	agilidade: number,
	vigor: number,
	intelecto: number,
	espirito: number,
	ca: number,
	deslocamento: number,
	iniciativa: number,
	vantagemIniciativa: boolean,
}

export type Import = {
	name: string,
	pv: number,
	pvMax: number,
	mana: number,
	manaMax: number,
	sheet: Sheet,
}

local function validMovement(value: any): boolean
	if type(value) ~= "number" or value ~= value or value < 0 or value > 999 then
		return false
	end
	-- Compara com a representação numérica canônica de um décimo.
	-- Evita exigir que value * 10 seja exatamente inteiro em ponto flutuante.
	return value == math.round(value * 10) / 10
end

-- Recebe o formato achatado de token.sheet, não o código de mesa.
-- Devolve uma cópia contendo somente campos conhecidos.
function FichaImport.parseSheet(value: any): (Sheet?, string?)
	if type(value) ~= "table" then
		return nil, "Dados importados precisam ser uma tabela."
	end
	local sheet = {}
	for _, field in ATTRIBUTES do
		if not Protocol.isInteger(value[field], -20, 50) then
			return nil, "Atributo " .. field .. " precisa ser inteiro entre -20 e 50."
		end
		sheet[field] = value[field]
	end
	if not Protocol.isInteger(value.ca, 0, 99) then
		return nil, "CA precisa ser inteiro entre 0 e 99."
	end
	if not validMovement(value.deslocamento) then
		return nil, "Deslocamento precisa estar entre 0 e 999 metros, com até uma casa decimal."
	end
	if not Protocol.isInteger(value.iniciativa, -50, 50) then
		return nil, "Iniciativa precisa ser inteiro entre -50 e 50."
	end
	if type(value.vantagemIniciativa) ~= "boolean" then
		return nil, "Vantagem de iniciativa precisa ser booleano."
	end
	sheet.ca = value.ca
	sheet.deslocamento = value.deslocamento
	sheet.iniciativa = value.iniciativa
	sheet.vantagemIniciativa = value.vantagemIniciativa
	return sheet :: Sheet, nil
end

function FichaImport.parse(decoded: any): (Import?, string?, { string })
	local warnings = {}
	if type(decoded) ~= "table" then
		return nil, "Código de ficha precisa conter uma tabela.", warnings
	end
	if decoded.mesa ~= 1 then
		return nil, "Versão do código de mesa inválida; esperado mesa = 1.", warnings
	end
	local nameLength = if type(decoded.nome) == "string" then utf8.len(decoded.nome) else nil
	if not nameLength or nameLength < 1 or nameLength > Protocol.LIMITS.name
		or not string.find(decoded.nome, "%S") then
		return nil, "Nome precisa ter entre 1 e " .. Protocol.LIMITS.name .. " caracteres válidos.", warnings
	end
	for _, field in { "pv", "pvMax", "mana", "manaMax" } do
		if not Protocol.isInteger(decoded[field], 0, Protocol.LIMITS.stat) then
			return nil, field .. " precisa ser inteiro entre 0 e " .. Protocol.LIMITS.stat .. ".", warnings
		end
	end
	if type(decoded.atributos) ~= "table" then
		return nil, "Atributos precisam ser uma tabela.", warnings
	end
	local candidate = {}
	for _, field in ATTRIBUTES do
		candidate[field] = decoded.atributos[field]
	end
	candidate.ca = decoded.ca
	candidate.deslocamento = decoded.deslocamento
	candidate.iniciativa = decoded.iniciativa
	candidate.vantagemIniciativa = decoded.vantagemIniciativa
	local sheet, failure = FichaImport.parseSheet(candidate)
	if not sheet then
		return nil, failure, warnings
	end
	local pv = decoded.pv
	local mana = decoded.mana
	if pv > decoded.pvMax then
		pv = decoded.pvMax
		table.insert(warnings, "PV atual acima do máximo; reduzido para " .. pv .. ".")
	end
	if mana > decoded.manaMax then
		mana = decoded.manaMax
		table.insert(warnings, "Mana atual acima do máximo; reduzida para " .. mana .. ".")
	end
	return {
		name = decoded.nome,
		pv = pv,
		pvMax = decoded.pvMax,
		mana = mana,
		manaMax = decoded.manaMax,
		sheet = sheet,
	}, nil, warnings
end

return table.freeze(FichaImport)
