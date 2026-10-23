-- Operações puras sobre condições. O catálogo é recebido como parâmetro.
-- Não filtra texto, não calcula duração e não aplica efeitos além de "vira".
local Rules = {}

Rules.MAX_CONDITIONS = 12
Rules.MAX_NOTE = 60
Rules.MAX_REQUEST_STACKS = 20

local function integer(value, low, high)
	return type(value) == "number" and value == value
		and value % 1 == 0 and value >= low and value <= high
end

local function entryFor(catalog, id)
	if type(id) ~= "string" then return nil end
	return catalog.POR_ID[id]
end

local function ceiling(entry, catalog)
	if not entry.acumulavel then return 1 end
	local value = entry.teto or catalog.TETO_PADRAO
	assert(integer(value, 1, Rules.MAX_REQUEST_STACKS), "Teto inválido no catálogo.")
	return value
end

local function validNote(note)
	if note == nil then return true end
	if type(note) ~= "string" then return false end
	local length = utf8.len(note)
	return length ~= nil and length <= Rules.MAX_NOTE
end

local function copyEntry(item)
	return { id = item.id, stacks = item.stacks, note = item.note }
end

-- Ordena índices válidos para não depender de # em listas com lacunas.
local function indices(raw, warnings)
	local keys = {}
	for key in raw do
		if integer(key, 1, 9007199254740991) then
			table.insert(keys, key)
		else
			table.insert(warnings, "Chave inválida na lista de condições descartada.")
		end
	end
	table.sort(keys)
	return keys
end

function Rules.validate(raw, catalog)
	local result, warnings = {}, {}
	if raw == nil then return result, warnings end
	if type(raw) ~= "table" then
		return result, { "Lista de condições inválida; removida." }
	end
	local seen = {}
	local keys = indices(raw, warnings)
	local sparse = false
	for index, key in keys do
		if key ~= index then sparse = true end
		local item = raw[key]
		local entry = if type(item) == "table" then entryFor(catalog, item.id) else nil
		local failure
		if type(item) ~= "table" then
			failure = "estrutura inválida"
		elseif not entry then
			failure = "id desconhecido"
		elseif not integer(item.stacks, 1, ceiling(entry, catalog)) then
			failure = "acúmulos inválidos"
		elseif not validNote(item.note) then
			failure = "nota inválida"
		elseif seen[item.id] then
			failure = "id repetido"
		elseif #result >= Rules.MAX_CONDITIONS then
			failure = "limite de condições atingido"
		end
		if failure then
			table.insert(warnings, "Condição " .. key .. " descartada: " .. failure .. ".")
		else
			seen[item.id] = true
			table.insert(result, copyEntry(item))
		end
	end
	if sparse then
		table.insert(warnings, "Lacunas na lista de condições removidas; ordem preservada.")
	end
	return result, warnings
end

local function commandList(list, catalog)
	local result, warnings = Rules.validate(list, catalog)
	if #warnings > 0 then
		return nil, "Lista atual de condições inválida."
	end
	return result, nil
end

local function find(list, id)
	for index, item in list do
		if item.id == id then return index, item end
	end
	return nil, nil
end

-- Trabalha em cópia privada. Erro em qualquer transformação cancela a operação.
local function applyAdd(list, catalog, id, stacks, note, messages, path)
	local entry = entryFor(catalog, id)
	if not entry then return "Condição desconhecida: " .. tostring(id) .. "." end
	if path[id] then return "Ciclo de transformação no catálogo de condições." end

	local index, existing = find(list, id)
	local limit = ceiling(entry, catalog)
	local total = if entry.acumulavel then (if existing then existing.stacks else 0) + stacks else 1
	local resultingNote = if note ~= nil then note else (if existing then existing.note else nil)

	if entry.acumulavel and total >= limit and entry.vira ~= nil then
		if not entryFor(catalog, entry.vira) then
			return "Destino de transformação desconhecido: " .. tostring(entry.vira) .. "."
		end
		path[id] = true
		if index then table.remove(list, index) end
		local target = entryFor(catalog, entry.vira)
		table.insert(messages, entry.nome .. " chegou ao teto e virou " .. target.nome .. ".")
		local failure = applyAdd(list, catalog, entry.vira, 1, resultingNote, messages, path)
		path[id] = nil
		return failure
	end

	total = math.min(total, limit)
	if existing then
		existing.stacks = total
		existing.note = resultingNote
	else
		if #list >= Rules.MAX_CONDITIONS then
			return "Limite de " .. Rules.MAX_CONDITIONS .. " condições atingido."
		end
		table.insert(list, { id = id, stacks = total, note = resultingNote })
	end
	if entry.acumulavel and total == limit then
		table.insert(messages, entry.nome .. " está no teto de " .. limit .. " acúmulo(s).")
	end
	return nil
end

function Rules.add(list, catalog, id, stacks, note)
	local messages = {}
	local entry = entryFor(catalog, id)
	if not entry then
		return nil, "Condição desconhecida: " .. tostring(id) .. ".", messages
	end
	stacks = if stacks == nil then 1 else stacks
	if not integer(stacks, 1, Rules.MAX_REQUEST_STACKS) then
		return nil, "Acúmulos precisam ser inteiros entre 1 e 20.", messages
	end
	if not entry.acumulavel and stacks ~= 1 then
		return nil, "Essa condição não é acumulável.", messages
	end
	if not validNote(note) then
		return nil, "Nota precisa ter até 60 caracteres UTF-8 válidos.", messages
	end
	local result, failure = commandList(list, catalog)
	if not result then return nil, failure, messages end
	failure = applyAdd(result, catalog, id, stacks, note, messages, {})
	if failure then return nil, failure, {} end
	return result, nil, messages
end

function Rules.remove(list, catalog, id, stacks)
	local messages = {}
	local entry = entryFor(catalog, id)
	if not entry then
		return nil, "Condição desconhecida: " .. tostring(id) .. ".", messages
	end
	if stacks ~= nil and not integer(stacks, 1, Rules.MAX_REQUEST_STACKS) then
		return nil, "Acúmulos precisam ser inteiros entre 1 e 20.", messages
	end
	if not entry.acumulavel and stacks ~= nil and stacks ~= 1 then
		return nil, "Essa condição não é acumulável.", messages
	end
	local result, failure = commandList(list, catalog)
	if not result then return nil, failure, messages end
	local index, item = find(result, id)
	if item then
		if stacks == nil or stacks >= item.stacks then
			table.remove(result, index)
		else
			item.stacks -= stacks
		end
	end
	return result, nil, messages
end

function Rules.labels(list, catalog)
	local valid = Rules.validate(list, catalog)
	local labels = {}
	for _, item in valid do
		local entry = entryFor(catalog, item.id)
		table.insert(labels, entry.nome .. (if entry.acumulavel then " ×" .. item.stacks else ""))
	end
	return labels
end

return table.freeze(Rules)
