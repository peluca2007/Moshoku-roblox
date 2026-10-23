-- Salvar/restaurar uma run no meio (PLANO §12, R5). Puro: só converte e valida; quem grava no DataStore é o servidor.
-- Por que existe: o estado da run usa userId NUMÉRICO como chave de `jogadores`, e DataStore/JSON só aceitam
-- chaves de texto em dicionários. Aqui as chaves viram texto na gravação e voltam ao tipo original na leitura.
local Shared = game:GetService("ReplicatedStorage").Shared
local Run = require(Shared.Regras.Run)
local Criacao = require(Shared.Regras.RunCriacao)

local Save = {}

Save.VERSAO = 1

local function modoValido(modo)
	for _, m in Criacao.MODOS do
		if m == modo then return true end
	end
	return false
end

-- planos = { [idJogador] = plano de RunCriacao.planejar (+ escolhas já feitas) } | nil
-- extras = tabela plana de texto/número/booleano (ex.: { eventoPendente = "id" }) | nil
function Save.serializar(run, planos, extras)
	if not Run.estadoValido(run) then return nil, "Estado da run inválido." end
	local copia = table.clone(run)
	copia.jogadores = {}
	local tipos = {}
	for id, j in run.jogadores do
		local chave = tostring(id)
		if copia.jogadores[chave] ~= nil then return nil, "Ids de jogador ambíguos." end
		copia.jogadores[chave] = table.clone(j)
		tipos[chave] = type(id)
	end
	local planosTexto = {}
	for id, plano in planos or {} do
		if run.jogadores[id] == nil then return nil, "Plano de quem não está na run." end
		if type(plano) ~= "table" or not modoValido(plano.modo) then return nil, "Plano inválido." end
		planosTexto[tostring(id)] = plano
	end
	local extrasCopia = {}
	for chave, valor in extras or {} do
		local t = type(valor)
		if type(chave) ~= "string" or (t ~= "string" and t ~= "number" and t ~= "boolean") then return nil, "Extra inválido." end
		extrasCopia[chave] = valor
	end
	return { versao = Save.VERSAO, run = copia, tiposDeId = tipos, planos = planosTexto, extras = extrasCopia }
end

-- Devolve (run, planos, extras) ou (nil, motivo). Recusa versão desconhecida e estado corrompido.
function Save.restaurar(dado)
	if type(dado) ~= "table" or dado.versao ~= Save.VERSAO then return nil, "Versão de save desconhecida." end
	if type(dado.run) ~= "table" or type(dado.run.jogadores) ~= "table" or type(dado.tiposDeId) ~= "table" then
		return nil, "Save incompleto."
	end
	local run = table.clone(dado.run)
	run.jogadores = {}
	for chave, j in dado.run.jogadores do
		local tipo = dado.tiposDeId[chave]
		local id
		if tipo == "number" then id = tonumber(chave)
		elseif tipo == "string" then id = chave end
		if id == nil then return nil, "Id de jogador sem tipo conhecido." end
		run.jogadores[id] = j
	end
	if not Run.estadoValido(run) then return nil, "Estado da run corrompido." end
	local planos = {}
	for chave, plano in dado.planos or {} do
		local tipo = dado.tiposDeId[chave]
		local id = if tipo == "number" then tonumber(chave) else chave
		if run.jogadores[id] == nil or type(plano) ~= "table" or not modoValido(plano.modo) then
			return nil, "Plano corrompido."
		end
		planos[id] = plano
	end
	local extras = {}
	for chave, valor in dado.extras or {} do
		local t = type(valor)
		if type(chave) ~= "string" or (t ~= "string" and t ~= "number" and t ~= "boolean") then return nil, "Extra corrompido." end
		extras[chave] = valor
	end
	return run, planos, extras
end

-- Todas as chaves de dicionário do resultado são texto (exigência do DataStore)? Usado pelo spec e pelo servidor.
function Save.chavesSaoTexto(valor, visitados)
	if type(valor) ~= "table" then return true end
	visitados = visitados or {}
	if visitados[valor] then return false end -- ciclo não é salvável
	visitados[valor] = true
	local ehLista = #valor > 0
	for chave, sub in valor do
		if ehLista then
			if type(chave) ~= "number" then return false end
		elseif type(chave) ~= "string" then
			return false
		end
		if not Save.chavesSaoTexto(sub, visitados) then return false end
	end
	visitados[valor] = nil
	return true
end

return Save
