-- Perfil pessoal separado dos slots de campanha. Registra apenas escolhas
-- validadas; atributos e inventário são reconstruídos pelo servidor.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Dojo = require(game:GetService("ReplicatedStorage").Shared.Regras.Dojo)
local Missao = require(game:GetService("ReplicatedStorage").Shared.Regras.Missao)
local MissoesDados = require(game:GetService("ReplicatedStorage").Shared.Mundo.MissoesDados)

local STORE_NAME = "PersonagensPessoais"
local TEST_CONFIG_NAME = "PersonagemTestConfig"
local SCHEMA_VERSION = 6
local Aparencia = require(game:GetService("ReplicatedStorage").Shared.Aparencia.Aparencia)
local CatalogoAparencia = require(game:GetService("ReplicatedStorage").Shared.Aparencia.Catalogo)
-- Aqui valida estrutura; posse é confirmada na fronteira da sessão/conta.
local pecasConhecidas = {}
for id in CatalogoAparencia.PECAS do pecasConhecidas[id] = true end
local ATTEMPTS = 3
local storesVolateis = {}

local Persistencia = {}
Persistencia.__index = Persistencia
Persistencia.TEST_CONFIG_NAME = TEST_CONFIG_NAME

local function inteiro(valor, minimo)
	return type(valor) == "number" and valor == valor and valor % 1 == 0 and valor >= minimo and valor < 2 ^ 53
end

local function copiarRegistro(valor)
	if type(valor) ~= "table" then return valor end
	local copia = {}
	for chave, item in valor do copia[chave] = copiarRegistro(item) end
	return copia
end

local function storeVolatil(scope)
	local dados = storesVolateis[scope]
	if not dados then
		dados = {}
		storesVolateis[scope] = dados
	end
	return {
		GetAsync = function(_, key)
			return copiarRegistro(dados[key])
		end,
		UpdateAsync = function(_, key, transformar)
			local proximo = transformar(copiarRegistro(dados[key]))
			if proximo ~= nil then dados[key] = copiarRegistro(proximo) end
			return copiarRegistro(dados[key])
		end,
	}
end

local function tentar(callback)
	local falha
	for indice = 1, ATTEMPTS do
		local ok, resultado = pcall(callback)
		if ok then return true, resultado end
		falha = resultado
		local mensagem = tostring(resultado)
		if string.find(mensagem, "StudioAccessToApisNotAllowed", 1, true) or string.find(mensagem, "403", 1, true) then break end
		if indice < ATTEMPTS then task.wait(indice) end
	end
	return false, falha
end

function Persistencia.new(opcoes)
	opcoes = opcoes or {}
	local store, motivo, scope = opcoes.store, nil, nil
	if not store then
		local config = if RunService:IsStudio() then ServerStorage:FindFirstChild(TEST_CONFIG_NAME) else nil
		scope = if config then config:GetAttribute("Scope") else nil
		local ok, resultado = pcall(function()
			if RunService:IsStudio() then
				assert(config:IsA("Folder") and type(scope) == "string" and #scope == 37 and string.match(scope, "^test_%x+$"), "Scope de teste inválido")
				local mode = config:GetAttribute("Mode")
				assert(mode == nil or mode == "memory", "Modo de teste inválido")
				if mode == "memory" then return storeVolatil(scope) end
				return DataStoreService:GetDataStore(STORE_NAME, scope)
			end
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		store = if ok then resultado else nil
		motivo = if ok then nil else tostring(resultado)
	end
	return setmetatable({ store = store, motivo = motivo, scope = scope }, Persistencia)
end

local function chave(userId)
	return "user_" .. tostring(userId)
end

local function perfilValido(perfil)
	if type(perfil) ~= "table" or type(perfil.nome) ~= "string" or #perfil.nome == 0 or #perfil.nome > 128
		or type(perfil.construcao) ~= "table" or type(perfil.habilidadesCompradas) ~= "table"
	then return false end
	if perfil.armaInicialSourceLocalId ~= nil and (type(perfil.armaInicialSourceLocalId) ~= "string"
		or #perfil.armaInicialSourceLocalId == 0 or #perfil.armaInicialSourceLocalId > 96) then return false end
	if perfil.descanso ~= nil then
		local d = perfil.descanso
		if type(d) ~= "table" or type(d.atuais) ~= "table" or type(d.descansosCurtos) ~= "number"
			or d.descansosCurtos % 1 ~= 0 or d.descansosCurtos < 0 or d.descansosCurtos > 2 then return false end
		for k, v in d.atuais do
			if (k ~= "pv" and k ~= "pm" and k ~= "pt" and k ~= "pp") or type(v) ~= "number"
				or v < 0 or v % 1 ~= 0 then return false end
		end
		for _, k in { "pv", "pm", "pt", "pp" } do if d.atuais[k] == nil then return false end end
		for k in d do if k ~= "atuais" and k ~= "descansosCurtos" then return false end end
	end
	if perfil.paGanhos ~= nil and not inteiro(perfil.paGanhos, 0) then return false end
	if perfil.arvoresAprendidas ~= nil then
		if type(perfil.arvoresAprendidas) ~= "table" or #perfil.arvoresAprendidas > 8 then return false end
		local vistos = {}
		for k, id in perfil.arvoresAprendidas do
			if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #perfil.arvoresAprendidas or type(id) ~= "string" or #id > 128 or vistos[id] then return false end
			vistos[id] = true
		end
	end
	if perfil.dojo ~= nil and not Dojo.estadoValido(perfil.dojo) then return false end
	if perfil.ouro ~= nil and (not inteiro(perfil.ouro, 0) or perfil.ouro > 9007199254740991) then return false end
	if perfil.encontrosPagos ~= nil then
		if type(perfil.encontrosPagos) ~= "table" or #perfil.encontrosPagos > 2048 then return false end
		local vistos = {}
		for _, id in ipairs(perfil.encontrosPagos) do
			if type(id) ~= "string" or #id < 1 or #id > 128 or vistos[id] then return false end
			vistos[id] = true
		end
	end
	if perfil.inventarioLoja ~= nil then
		if type(perfil.inventarioLoja) ~= "table" or #perfil.inventarioLoja > 256 then return false end
		for i, item in ipairs(perfil.inventarioLoja) do
			if type(item) ~= "table" or type(item.itemId) ~= "string" or #item.itemId > 128
				or type(item.sourceLocalId) ~= "string" or #item.sourceLocalId > 96
				or item.sourceLocalId == "" then return false end
			for k in item do if k ~= "itemId" and k ~= "sourceLocalId" then return false end end
		end
	end
	if perfil.itensVendidos ~= nil then
		if type(perfil.itensVendidos) ~= "table" or #perfil.itensVendidos > 256 then return false end
		for _, id in ipairs(perfil.itensVendidos) do if type(id) ~= "string" or #id > 96 or id == "" then return false end end
	end
	if perfil.aparencia ~= nil and not Aparencia.validar(perfil.aparencia, perfil.construcao.raceId, pecasConhecidas) then return false end
	if perfil.missoes ~= nil and not Missao.estadoValido(perfil.missoes, MissoesDados.porId()) then return false end
	for campo in perfil do
		if campo ~= "nome" and campo ~= "construcao" and campo ~= "habilidadesCompradas"
		and campo ~= "armaInicialSourceLocalId" and campo ~= "descanso" and campo ~= "dojo"
		and campo ~= "ouro" and campo ~= "encontrosPagos" and campo ~= "inventarioLoja" and campo ~= "itensVendidos"
		and campo ~= "arvoresAprendidas" and campo ~= "paGanhos" and campo ~= "missoes" and campo ~= "aparencia" then return false end
	end
	local vistos, entradas = {}, 0
	local function valorValido(valor, nivel)
		entradas += 1
		if entradas > 512 then return false end
		local tipo = type(valor)
		if tipo == "string" then return #valor <= 256 end
		if tipo == "number" then return valor == valor and math.abs(valor) < math.huge end
		if tipo == "boolean" then return true end
		if tipo ~= "table" or nivel > 4 or vistos[valor] or getmetatable(valor) ~= nil then return false end
		vistos[valor] = true
		for chave, item in valor do
			if (type(chave) ~= "string" and type(chave) ~= "number") or not valorValido(chave, nivel + 1)
				or not valorValido(item, nivel + 1) then return false end
		end
		return true
	end
	if not valorValido(perfil.construcao, 0) then return false end
	local quantidade = 0
	for indice, id in perfil.habilidadesCompradas do
		quantidade += 1
		if quantidade > 128 or type(indice) ~= "number" or indice % 1 ~= 0 or indice < 1
			or type(id) ~= "string" or #id == 0 or #id > 256
		then return false end
	end
	for indice = 1, quantidade do
		if type(perfil.habilidadesCompradas[indice]) ~= "string" then return false end
	end
	return true
end

-- nil,nil = perfil novo; registro inválido ou erro nunca vira perfil vazio.
function Persistencia:load(userId)
	if not self.store then return nil, nil, self.motivo or "DataStore indisponível." end
	local options = Instance.new("DataStoreGetOptions")
	options.UseCache = false
	local ok, registro = tentar(function() return self.store:GetAsync(chave(userId), options) end)
	if not ok then return nil, nil, tostring(registro) end
	if registro == nil then return nil, 0, nil end
	if type(registro) ~= "table" or (registro.schemaVersion ~= 1 and registro.schemaVersion ~= 2 and registro.schemaVersion ~= 3 and registro.schemaVersion ~= 4 and registro.schemaVersion ~= 5 and registro.schemaVersion ~= SCHEMA_VERSION)
		or not inteiro(registro.revision, 1) or not inteiro(registro.savedAt, 0) or not perfilValido(registro.perfil)
	then return nil, nil, "Registro pessoal inválido; carregamento bloqueado para preservar os dados." end
	local perfil = copiarRegistro(registro.perfil)
	if perfil.dojo == nil then perfil.dojo = Dojo.novoEstado() end
	if perfil.ouro == nil then perfil.ouro = 0 end
	if perfil.encontrosPagos == nil then perfil.encontrosPagos = {} end
	if perfil.inventarioLoja == nil then perfil.inventarioLoja = {} end
	if perfil.itensVendidos == nil then perfil.itensVendidos = {} end
	if perfil.missoes == nil then perfil.missoes = Missao.novoEstado() end
	return perfil, registro.revision, nil
end

-- CAS impede uma sessão antiga de sobrescrever alterações de outro servidor.
function Persistencia:save(userId, perfil, revisaoEsperada)
	if not self.store then return "erro", self.motivo or "DataStore indisponível." end
	if not inteiro(userId, 1) or not inteiro(revisaoEsperada, 0) or not perfilValido(perfil) then
		return "invalido", "Perfil pessoal inválido."
	end
	local opId = HttpService:GenerateGUID(false)
	local outcome, info
	local ok, falha = tentar(function()
		self.store:UpdateAsync(chave(userId), function(atual)
			local revisaoAtual = 0
			if atual ~= nil then
				if type(atual) ~= "table" or (atual.schemaVersion ~= 1 and atual.schemaVersion ~= 2 and atual.schemaVersion ~= 3 and atual.schemaVersion ~= 4 and atual.schemaVersion ~= 5 and atual.schemaVersion ~= SCHEMA_VERSION)
					or not inteiro(atual.revision, 1) or not inteiro(atual.savedAt, 0) or not perfilValido(atual.perfil)
				then outcome, info = "invalido", "Registro pessoal inválido; gravação bloqueada para preservar os dados."; return nil end
				if atual.opId == opId then outcome, info = "ok", atual.revision; return nil end
				revisaoAtual = atual.revision
			end
			if revisaoAtual ~= revisaoEsperada then outcome, info = "conflito", revisaoAtual; return nil end
			outcome, info = "ok", revisaoAtual + 1
			local perfilSalvo = copiarRegistro(perfil)
			if perfilSalvo.dojo == nil then perfilSalvo.dojo = Dojo.novoEstado() end
			if perfilSalvo.ouro == nil then perfilSalvo.ouro = 0 end
			if perfilSalvo.encontrosPagos == nil then perfilSalvo.encontrosPagos = {} end
			if perfilSalvo.inventarioLoja == nil then perfilSalvo.inventarioLoja = {} end
			if perfilSalvo.itensVendidos == nil then perfilSalvo.itensVendidos = {} end
			if perfilSalvo.missoes == nil then perfilSalvo.missoes = Missao.novoEstado() end
			return { schemaVersion = SCHEMA_VERSION, revision = info, savedAt = os.time(), opId = opId, perfil = perfilSalvo }
		end)
	end)
	if not ok then return "erro", tostring(falha) end
	return outcome or "erro", info
end

return Persistencia
