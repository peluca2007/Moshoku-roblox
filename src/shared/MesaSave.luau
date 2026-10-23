-- Codec puro. Texto é refiltrado pelo servidor depois de decode.
local Shared = game:GetService("ReplicatedStorage").Shared
local Protocol = require(Shared.MesaProtocol)
local FichaImport = require(Shared.FichaImport)
local CondicaoRules = require(Shared.CondicaoRules)
local Condicoes = require(Shared.Condicoes)
local FichaV2 = require(Shared.FichaV2)

local MesaSave = {}
MesaSave.SCHEMA = 1
local MAX_INTEGER = 9007199254740991
local TERRAIN = { parede = true, dificil = true, agua = true }

local function integer(value, low, high)
	return Protocol.isInteger(value, low, high)
end

local function idNumber(value)
	if type(value) ~= "string" or not string.match(value, "^t%d+$") then return nil end
	local number = tonumber(string.sub(value, 2))
	if not integer(number, 1, MAX_INTEGER) then return nil end
	return number
end

local function emptyCombat()
	return { active = false, round = 0, order = {}, turnIndex = 0, turn = 0 }
end

local function emptyMap()
	return { terrain = {}, fog = {} }
end

local function rgb(color)
	return {
		r = math.clamp(math.round(color.R * 255), 0, 255),
		g = math.clamp(math.round(color.G * 255), 0, 255),
		b = math.clamp(math.round(color.B * 255), 0, 255),
	}
end

local function cellKey(x, z)
	return tostring(x) .. "," .. tostring(z)
end

local function parseKey(key)
	if type(key) ~= "string" then return nil, nil end
	local sx, sz = string.match(key, "^(%d+),(%d+)$")
	if not sx then return nil, nil end
	local x, z = tonumber(sx), tonumber(sz)
	if not Protocol.isCell(x, z) or cellKey(x, z) ~= key then return nil, nil end
	return x, z
end

local function encodeMap(map)
	if map == nil then return { terrain = {}, fog = {} } end
	assert(type(map) == "table", "Mapa inválido no estado.")
	local result = { terrain = {}, fog = {} }
	for _, field in { "terrain", "fog" } do
		local source = map[field]
		assert(source == nil or type(source) == "table", "Lista de mapa inválida: " .. field)
		for key, value in (source or {}) do
			local x, z = parseKey(key)
			assert(x ~= nil, "Casa inválida no mapa: " .. tostring(key))
			if field == "terrain" then
				assert(type(value) == "string" and TERRAIN[value], "Terreno inválido: " .. tostring(value))
				table.insert(result.terrain, { x = x, z = z, kind = value })
			else
				assert(value == true, "Névoa inválida em " .. key)
				table.insert(result.fog, { x = x, z = z })
			end
		end
		table.sort(result[field], function(a, b)
			if a.x ~= b.x then return a.x < b.x end
			return a.z < b.z
		end)
	end
	return result
end

function MesaSave.encode(state)
	local tokens = {}
	for _, token in state.tokens do
		local sheet
		if token.sheet ~= nil then
			local valid, failure = FichaImport.parseSheet(token.sheet)
			assert(valid, "Sheet inválido em " .. tostring(token.id) .. ": " .. tostring(failure))
			sheet = valid
		end
		-- Ficha v2 aprovada: só o formato é revalidado (o catálogo pode mudar entre sessões).
		local ficha2
		if token.ficha2 ~= nil then
			local valid, failure = FichaV2.validarCorpo(token.ficha2)
			assert(valid, "Ficha v2 inválida em " .. tostring(token.id) .. ": " .. tostring(failure))
			ficha2 = valid
		end
		local conditions, warnings = CondicaoRules.validate(token.conditions, Condicoes)
		assert(#warnings == 0, "Condições inválidas em " .. tostring(token.id) .. ": " .. tostring(warnings[1]))
		table.insert(tokens, {
			id = token.id, name = token.name, kind = token.kind,
			ownerUserId = token.ownerUserId, x = token.x, z = token.z,
			pv = token.pv, pvMax = token.pvMax, mana = token.mana, manaMax = token.manaMax,
			hidden = token.hidden, showStats = token.showStats,
			color = rgb(token.color), version = token.version,
			sheet = sheet, conditions = conditions,
			ficha2 = ficha2,
			-- Criatura do bestiário: só o id; o servidor recalcula a ficha pelo catálogo.
			criatura = if token.criatura then { catalogId = token.criatura.catalogId } else nil,
		})
	end
	local order = {}
	for _, id in state.combat.order do table.insert(order, id) end
	return {
		schema = MesaSave.SCHEMA, nextId = state.nextId, tokens = tokens,
		combat = {
			active = state.combat.active, round = state.combat.round,
			order = order, turnIndex = state.combat.turnIndex, turn = state.combat.turn,
		},
		map = encodeMap(state.map),
	}
end

local function arrayKeys(value)
	local keys = {}
	for key in value do
		if not integer(key, 1, MAX_INTEGER) then return nil end
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function decodeToken(raw)
	if type(raw) ~= "table" then return nil, "estrutura inválida" end
	if not idNumber(raw.id) then return nil, "id inválido" end
	local length = if type(raw.name) == "string" then utf8.len(raw.name) else nil
	if not length or length == 0 or length > Protocol.LIMITS.name
		or not string.find(raw.name, "%S") then
		return nil, "nome inválido"
	end
	if not Protocol.isOneOf(raw.kind, Protocol.KINDS) then return nil, "tipo inválido" end
	if not integer(raw.ownerUserId, -MAX_INTEGER, MAX_INTEGER) then return nil, "dono inválido" end
	if not Protocol.isCell(raw.x, raw.z) then return nil, "casa inválida" end
	for _, field in { "pv", "pvMax", "mana", "manaMax" } do
		if not integer(raw[field], 0, Protocol.LIMITS.stat) then return nil, field .. " inválido" end
	end
	if type(raw.hidden) ~= "boolean" or type(raw.showStats) ~= "boolean" then
		return nil, "visibilidade inválida"
	end
	if not integer(raw.version, 0, MAX_INTEGER) then return nil, "versão da ficha inválida" end
	local color = raw.color
	if type(color) ~= "table" or not integer(color.r, 0, 255)
		or not integer(color.g, 0, 255) or not integer(color.b, 0, 255) then
		return nil, "cor inválida"
	end
	return {
		id = raw.id, name = raw.name, kind = raw.kind,
		ownerUserId = raw.ownerUserId, x = raw.x, z = raw.z,
		pv = raw.pv, pvMax = raw.pvMax, mana = raw.mana, manaMax = raw.manaMax,
		hidden = raw.hidden, showStats = raw.showStats,
		color = Color3.fromRGB(color.r, color.g, color.b), version = raw.version,
	}, nil
end

local function decodeCombat(raw, ids)
	if type(raw) ~= "table" or type(raw.active) ~= "boolean"
		or not integer(raw.round, 0, MAX_INTEGER)
		or not integer(raw.turn, 0, MAX_INTEGER)
		or not integer(raw.turnIndex, 0, MAX_INTEGER)
		or type(raw.order) ~= "table" then return nil end
	local keys = arrayKeys(raw.order)
	if not keys or #keys > Protocol.LIMITS.tokens then return nil end
	local seen, order = {}, {}
	for index, key in keys do
		local id = raw.order[key]
		if key ~= index or type(id) ~= "string" or not ids[id] or seen[id] then return nil end
		seen[id] = true
		table.insert(order, id)
	end
	if raw.active then
		if #order == 0 or raw.round < 1 or raw.turn < 1
			or not integer(raw.turnIndex, 1, #order) then return nil end
	elseif #order == 0 then
		if raw.turnIndex ~= 0 then return nil end
	elseif not integer(raw.turnIndex, 1, #order) then return nil end
	return {
		active = raw.active, round = raw.round, order = order,
		turnIndex = raw.turnIndex, turn = raw.turn,
	}
end

local function decodeMap(raw, warnings)
	local result = emptyMap()
	if raw == nil then return result end
	if type(raw) ~= "table" then
		table.insert(warnings, "Mapa inválido; removido.")
		return result
	end
	for _, field in { "terrain", "fog" } do
		local source = raw[field]
		if source == nil then continue end
		if type(source) ~= "table" then
			table.insert(warnings, "Mapa " .. field .. " inválido; removido.")
			continue
		end
		local keys = {}
		for key in source do
			if integer(key, 1, MAX_INTEGER) then
				table.insert(keys, key)
			else
				table.insert(warnings, "Mapa " .. field .. ": chave inválida descartada.")
			end
		end
		table.sort(keys)
		local sparse = false
		for index, key in keys do
			if index ~= key then sparse = true end
			local item = source[key]
			if type(item) ~= "table" or not Protocol.isCell(item.x, item.z) then
				table.insert(warnings, "Mapa " .. field .. ": casa inválida descartada.")
				continue
			end
			if field == "terrain" and (type(item.kind) ~= "string" or not TERRAIN[item.kind]) then
				table.insert(warnings, "Mapa terrain: tipo inválido descartado.")
				continue
			end
			local coordinate = cellKey(item.x, item.z)
			if result[field][coordinate] ~= nil then
				table.insert(warnings, "Mapa " .. field .. ": casa repetida descartada (" .. coordinate .. ").")
				continue
			end
			result[field][coordinate] = if field == "terrain" then item.kind else true
		end
		if sparse then table.insert(warnings, "Mapa " .. field .. ": lacunas removidas.") end
	end
	return result
end

function MesaSave.decode(data)
	local warnings = {}
	if type(data) ~= "table" then
		return nil, { "Mesa salva inválida: a entrada não é uma tabela." }
	end
	if type(data.schema) == "number" and data.schema > MesaSave.SCHEMA then
		return nil, { "Mesa salva por versão mais nova." }
	end
	if data.schema ~= MesaSave.SCHEMA then
		return nil, { "Mesa salva inválida: schema ausente ou incompatível." }
	end
	if type(data.tokens) ~= "table" then
		return nil, { "Mesa salva inválida: lista de fichas ausente." }
	end
	local keys = arrayKeys(data.tokens)
	if not keys then
		return nil, { "Mesa salva inválida: a lista de fichas contém chaves inválidas." }
	end
	local tokens, ids = {}, {}
	local largestId, sparse = 0, false
	if #keys > Protocol.LIMITS.tokens then
		table.insert(warnings, "Lista de fichas truncada ao limite de " .. Protocol.LIMITS.tokens .. ".")
	end
	for index, key in keys do
		if key ~= index then sparse = true end
		if index > Protocol.LIMITS.tokens then break end
		local raw = data.tokens[key]
		local token, failure = decodeToken(raw)
		if not token then
			table.insert(warnings, "Ficha " .. key .. " descartada: " .. failure .. ".")
			continue
		end
		if ids[token.id] then
			table.insert(warnings, "Ficha " .. key .. " descartada: id repetido (" .. token.id .. ").")
			continue
		end
		if raw.sheet ~= nil then
			local sheet, sheetFailure = FichaImport.parseSheet(raw.sheet)
			token.sheet = sheet
			if not sheet then
				table.insert(warnings, "Ficha " .. key .. " mantida sem sheet: " .. tostring(sheetFailure))
			end
		end
		if type(raw.criatura) == "table" and type(raw.criatura.catalogId) == "string"
			and #raw.criatura.catalogId <= 256 and string.match(raw.criatura.catalogId, "^creature/[%w%-%%._~]+$") then
			token.criatura = { catalogId = raw.criatura.catalogId }
		end
		if raw.ficha2 ~= nil then
			local ficha2, ficha2Failure = FichaV2.validarCorpo(raw.ficha2)
			token.ficha2 = ficha2
			if not ficha2 then
				table.insert(warnings, "Ficha " .. key .. " mantida sem a ficha v2: " .. tostring(ficha2Failure))
			end
		end
		local conditions, conditionWarnings = CondicaoRules.validate(raw.conditions, Condicoes)
		token.conditions = conditions
		for _, warning in conditionWarnings do
			table.insert(warnings, "Ficha " .. key .. ": " .. warning)
		end
		ids[token.id] = true
		largestId = math.max(largestId, idNumber(token.id))
		table.insert(tokens, token)
	end
	if sparse then
		table.insert(warnings, "Lacunas na lista de fichas removidas; ordem preservada.")
	end
	local nextId = data.nextId
	if not integer(nextId, 0, MAX_INTEGER) then
		nextId = largestId
		table.insert(warnings, "nextId inválido; recalculado pelas fichas preservadas.")
	elseif nextId < largestId then
		nextId = largestId
		table.insert(warnings, "nextId recalculado pelas fichas preservadas.")
	end
	local combat = decodeCombat(data.combat, ids)
	if not combat then
		combat = emptyCombat()
		table.insert(warnings, "Combate inconsistente encerrado.")
	end
	return {
		nextId = nextId, tokens = tokens, combat = combat,
		map = decodeMap(data.map, warnings),
	}, warnings
end

return table.freeze(MesaSave)
