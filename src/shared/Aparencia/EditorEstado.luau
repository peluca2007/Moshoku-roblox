local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Aparencia.Catalogo)
local Racas = require(Shared.Aparencia.Racas)
local Aparencia = require(Shared.Aparencia.Aparencia)

local M = {}
local CAMPOS = {
	olhos = { tipo = "rosto", chave = "olhos" },
	sobrancelhas = { tipo = "rosto", chave = "sobrancelhas" },
	nariz = { tipo = "rosto", chave = "nariz" },
	boca = { tipo = "rosto", chave = "boca" },
	olho = { tipo = "cor", chave = "olho" },
	cabelo = { tipo = "estilo", catalogo = "CABELOS" },
	corCabelo = { tipo = "cor", chave = "cabelo" },
	barba = { tipo = "estilo", catalogo = "BARBAS" },
	pele = { tipo = "cor", chave = "pele" },
	camisa = { tipo = "cor", chave = "camisa" },
	calca = { tipo = "cor", chave = "calca" },
	tracos = { tipo = "tracos" },
	roupas = { tipo = "roupas" },
}

local function copiar(valor)
	if type(valor) ~= "table" then return valor end
	local resultado = {}
	for k, v in valor do resultado[k] = copiar(v) end
	return resultado
end

function M.clone(aparencia)
	return copiar(aparencia)
end

local function opcoesInternas(estado, campo)
	local cfg = CAMPOS[campo]
	local raca = estado and Racas.POR_ID[estado.raceId]
	if not cfg or not raca then return {} end
	local resultado = {}
	local function adicionar(id, item)
		if item then table.insert(resultado, { id = id, nome = item.nome or id, raridade = item.raridade }) end
	end
	if cfg.tipo == "rosto" then
		for id in Catalogo.ROSTO[cfg.chave] do adicionar(id, { nome = id }) end
	elseif cfg.tipo == "estilo" then
		for id, item in Catalogo[cfg.catalogo] do adicionar(id, item) end
	elseif cfg.tipo == "cor" then
		local paleta = ({ pele = raca.paleta, olho = raca.coresOlho, cabelo = raca.coresCabelo, camisa = raca.coresCamisa, calca = raca.coresCalca })[cfg.chave]
		for _, id in paleta do adicionar(id, { nome = id }) end
	elseif cfg.tipo == "tracos" then
		for _, id in raca.opcionais do adicionar(id, Catalogo.PECAS[id]) end
	elseif cfg.tipo == "roupas" then
		for id, item in Catalogo.PECAS do
			if not item.racial and (item.raridade ~= "rara" or estado.possuidos[id] == true) then adicionar(id, item) end
		end
	end
	table.sort(resultado, function(a, b) return a.id < b.id end)
	return resultado
end

function M.opcoes(estado, campo)
	return opcoesInternas(estado, campo)
end

function M.reajustar(estado, raceId)
	assert(Racas.POR_ID[raceId], "raça inválida")
	local possuidos = if type(estado) == "table" and type(estado.possuidos) == "table" then copiar(estado.possuidos) else {}
	local aparencia = if type(estado) == "table" and type(estado.aparencia) == "table" then copiar(estado.aparencia) else nil
	local padrao = Aparencia.padrao(raceId, 1)
	local origemValida = type(estado) == "table" and Aparencia.validar(aparencia, estado.raceId, possuidos)
	if not origemValida then aparencia = padrao end
	local function temOpcao(campo, id)
		for _, opcao in opcoesInternas({ raceId = raceId, possuidos = possuidos }, campo) do
			if opcao.id == id then return true end
		end
		return false
	end
	for _, campo in { "olhos", "sobrancelhas", "nariz", "boca" } do
		if not temOpcao(campo, aparencia.rosto[campo]) then aparencia.rosto[campo] = padrao.rosto[campo] end
	end
	for _, campo in { "olho", "cabelo", "pele", "camisa", "calca" } do
		local chave = if campo == "olho" then "olho" else campo
		local opCampo = if campo == "cabelo" then "corCabelo" else campo
		if not temOpcao(opCampo, aparencia.cores[chave]) then aparencia.cores[chave] = padrao.cores[chave] end
	end
	local function estiloValido(campo, id)
		for _, o in opcoesInternas({ raceId = raceId, possuidos = possuidos }, campo) do if o.id == id then return true end end
		return false
	end
	if not estiloValido("cabelo", aparencia.cabelo) then aparencia.cabelo = padrao.cabelo end
	if not estiloValido("barba", aparencia.barba) then aparencia.barba = padrao.barba end
	aparencia.roupas = type(aparencia.roupas) == "table" and aparencia.roupas or {}
	for slot, id in aparencia.roupas do
		local item = Catalogo.PECAS[id]
		if not item or item.slot ~= slot or (item.raridade == "rara" and possuidos[id] ~= true) then aparencia.roupas[slot] = nil end
	end
	local permitidasRaciais = {}
	for _, id in Racas.POR_ID[raceId].opcionais do permitidasRaciais[id] = true end
	for slot, id in aparencia.roupas do
		local item = Catalogo.PECAS[id]
		if item and item.racial and not permitidasRaciais[id] then aparencia.roupas[slot] = nil end
	end
	-- Só aceita a forma resultante se o validador A1 confirmar todos os campos e paletas.
	if not Aparencia.validar(aparencia, raceId, possuidos) then aparencia = padrao end
	return { raceId = raceId, aparencia = aparencia, possuidos = possuidos, cursores = copiar(type(estado) == "table" and estado.cursores or {}) }
end

function M.novo(raceId, aparencia, possuidos)
	return M.reajustar({ raceId = raceId, aparencia = aparencia, possuidos = possuidos }, raceId)
end

local function valorAtual(estado, campo)
	local cfg = CAMPOS[campo]
	if cfg.tipo == "rosto" then return estado.aparencia.rosto[cfg.chave] end
	if cfg.tipo == "cor" then return estado.aparencia.cores[cfg.chave] end
	if cfg.tipo == "estilo" then return estado.aparencia[campo] end
end

function M.selecionar(estado, campo, id)
	local cfg = CAMPOS[campo]
	if not cfg then return false end
	local disponivel = false
	for _, o in opcoesInternas(estado, campo) do if o.id == id then disponivel = true; break end end
	if not disponivel then return false end
	if cfg.tipo == "roupas" or cfg.tipo == "tracos" then
		local item = Catalogo.PECAS[id]
		local slot = item.slot
		if estado.aparencia.roupas[slot] == id then estado.aparencia.roupas[slot] = nil else estado.aparencia.roupas[slot] = id end
	else
		if cfg.tipo == "rosto" then estado.aparencia.rosto[cfg.chave] = id
		elseif cfg.tipo == "cor" then estado.aparencia.cores[cfg.chave] = id
		else estado.aparencia[campo] = id end
	end
	estado.cursores = estado.cursores or {}
	estado.cursores[campo] = id
	return true
end

function M.navegar(estado, campo, delta)
	local lista = opcoesInternas(estado, campo)
	if #lista == 0 or type(delta) ~= "number" then return false end
	local atual = (estado.cursores and estado.cursores[campo]) or valorAtual(estado, campo)
	local indice = 0
	for i, o in lista do if o.id == atual then indice = i; break end end
	local passo = math.floor(delta)
	local base = if indice == 0 then (if passo < 0 then 1 else 0) else indice
	local destino = ((base - 1 + passo) % #lista) + 1
	return M.selecionar(estado, campo, lista[destino].id)
end

function M.aleatorio(estado, rng)
	assert(rng and rng.NextInteger, "RNG inválido")
	local gerada = Aparencia.aleatoria(estado.raceId, rng)
	estado.aparencia = gerada
	return estado
end

return M
