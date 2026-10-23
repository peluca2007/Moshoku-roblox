-- Acesso ao DataStore das campanhas. Não conhece regras da mesa: grava e lê
-- registros { revision, savedAt, opId, mesa } por espaço. Contrato em docs/MESA.md.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local STORE_NAME = "MesaCampanhas"
local ATTEMPTS = 3

local Persistence = {}
Persistence.__index = Persistence
Persistence.TEST_CONFIG_NAME = "MesaTestConfig"

export type SaveOutcome = "ok" | "conflito" | "invalido" | "erro"

function Persistence.new()
	local config = if RunService:IsStudio() then ServerStorage:FindFirstChild(Persistence.TEST_CONFIG_NAME) else nil
	local scope = if config then config:GetAttribute("Scope") else nil
	-- Em place não publicado, GetDataStore pode falhar já aqui.
	local ok, store = pcall(function()
		if config then
			-- Falhar fechado: um scope de teste incorreto nunca cai no armazenamento real.
			assert(config:IsA("Folder") and type(scope) == "string" and #scope == 37 and string.match(scope, "^test_%x+$"), "Scope de teste inválido")
			return DataStoreService:GetDataStore(STORE_NAME, scope)
		end
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	return setmetatable({
		store = if ok then store else nil,
		reason = if ok then nil else tostring(store),
		scope = scope,
	}, Persistence)
end

local function key(slot: number): string
	return "slot_" .. slot
end

local function validInteger(value: any, low: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value < 2 ^ 53
end

local function validRevision(value: any): boolean
	return validInteger(value, 1)
end

-- Repete falhas transitórias do serviço com espera crescente (1 s, 2 s).
local function attempt(callback: () -> any): (boolean, any)
	local failure
	for index = 1, ATTEMPTS do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		failure = result
		-- Acesso negado (ex.: Studio sem acesso às APIs) não melhora repetindo.
		if string.find(tostring(result), "StudioAccessToApisNotAllowed", 1, true) or string.find(tostring(result), "403", 1, true) then
			break
		end
		if index < ATTEMPTS then
			task.wait(index)
		end
	end
	return false, failure
end

-- Devolve (registro?, erro?, inválido?). Sem registro e sem erro = espaço vazio.
-- inválido = o registro existe mas não é legível: só substituição forçada resolve.
-- Leitura sem cache: um carregamento explícito precisa ver gravações de outros servidores.
function Persistence:load(slot: number): (any, string?, boolean?)
	if not self.store then
		return nil, self.reason or "DataStore indisponível."
	end
	local options = Instance.new("DataStoreGetOptions")
	options.UseCache = false
	local ok, record = attempt(function()
		return self.store:GetAsync(key(slot), options)
	end)
	if not ok then
		return nil, tostring(record)
	end
	if record == nil then
		return nil, nil
	end
	if type(record) ~= "table" or not validRevision(record.revision) or not validInteger(record.savedAt, 0) then
		return nil, "registro do espaço " .. slot .. " é inválido; salve mesmo assim para substituí-lo", true
	end
	return record, nil
end

-- Grava se a revisão no DataStore ainda for expectedRevision (0 = espaço vazio).
-- force ignora a comparação. Devolve ("ok", revisão, savedAt), ("conflito",
-- revisão gravada), ("invalido", mensagem) ou ("erro", mensagem).
function Persistence:save(slot: number, mesa: any, expectedRevision: number, force: boolean): (SaveOutcome, any, number?)
	if not self.store then
		return "erro", self.reason or "DataStore indisponível."
	end
	-- Mesmo id em todas as tentativas: se uma resposta falhar depois de gravar,
	-- a repetição reconhece a própria gravação em vez de acusar conflito.
	local opId = HttpService:GenerateGUID(false)
	local outcome, info, savedAt
	local ok, failure = attempt(function()
		self.store:UpdateAsync(key(slot), function(current)
			-- O callback pode rodar mais de uma vez; o resultado é o da última.
			local stored = 0
			if current ~= nil then
				if type(current) == "table" and validRevision(current.revision) then
					if current.opId == opId then
						outcome, info, savedAt = "ok", current.revision, current.savedAt
						return nil
					end
					stored = current.revision
				elseif not force then
					outcome, info = "invalido", "o espaço " .. slot .. " tem um registro inválido; salve mesmo assim para substituí-lo"
					return nil
				end
			end
			if not force and stored ~= expectedRevision then
				outcome, info = "conflito", stored
				return nil -- cancela a gravação
			end
			local now = os.time()
			outcome, info, savedAt = "ok", stored + 1, now
			return { revision = stored + 1, savedAt = now, opId = opId, mesa = mesa }
		end)
	end)
	if not ok then
		return "erro", tostring(failure)
	end
	return outcome, info, savedAt
end

return Persistence
