-- Constrói atores exclusivamente a partir de fichas validadas pelo servidor e
-- entradas de criatura do catálogo. Nenhum campo de ficha vem do cliente.
local EncontroAutonomoElenco = {}
local Encontros = require(game:GetService("ReplicatedStorage").Shared.EncontrosPorZona)
local RESPIRAM = table.freeze({
 ["creature/rato-gigante"] = true,
 ["creature/aranha-da-floresta"] = true,
 ["creature/bandido-de-estrada"] = true,
	["creature/goblin-batedor"] = true,
	["creature/lobo-cinzento"] = true,
	["creature/urso-de-presas-vermelhas"] = true,
})
-- Metadados do Apêndice G vinculados ao ID canônico do bestiário. Só as
-- criaturas mapeadas aqui participam do cálculo; o payload remoto não escolhe valor.
local RECOMPENSAS = table.freeze({
 ["creature/rato-gigante"] = { patamar = 1, papel = "lacaio", arquetipo = "agil", subArquetipo = "besta" },
 ["creature/aranha-da-floresta"] = { patamar = 2, papel = "padrao", arquetipo = "agil", subArquetipo = "besta" },
 ["creature/bandido-de-estrada"] = { patamar = 1, papel = "padrao", arquetipo = "bruto", subArquetipo = "humanoide" },
 ["creature/golem-de-pedra-menor"] = { patamar = 2, papel = "padrao", arquetipo = "fortaleza", subArquetipo = "construto", temImunidade = true },
	["creature/urso-de-presas-vermelhas"] = { patamar = 2, papel = "padrao", arquetipo = "bruto", subArquetipo = "besta" },
	["creature/goblin-batedor"] = { patamar = 1, papel = "lacaio", arquetipo = "agil", subArquetipo = "humanoide" },
	["creature/lobo-cinzento"] = { patamar = 1, papel = "padrao", arquetipo = "bruto", subArquetipo = "besta" },
	["creature/treant-anciao"] = { patamar = 3, papel = "chefe", arquetipo = "bruto", subArquetipo = "planta" },
})

local function listaDensa(lista)
	if type(lista) ~= "table" then return false end
	local quantidade = 0
	for chave in lista do
		if type(chave) ~= "number" or chave % 1 ~= 0 or chave < 1 or chave > #lista then
			return false
		end
		quantidade += 1
	end
	return quantidade == #lista
end

function EncontroAutonomoElenco.montar(jogadores, criaturas, deps)
	if type(deps) ~= "table" or type(deps.conectado) ~= "function"
		or type(deps.corpoPessoal) ~= "function" or type(deps.criatura) ~= "function"
	then
		return nil, "Dependências do elenco indisponíveis."
	end
	if not listaDensa(jogadores) or #jogadores < 1 or #jogadores > 4
		or not listaDensa(criaturas) or #criaturas < 1 or #criaturas > 12
	then
		return nil, "O grupo precisa ter de 1 a 4 jogadores e de 1 a 12 criaturas."
	end

	local atores, userIds = {}, {}
	local formacao = Encontros.formacaoInicial(deps.formacaoId or deps.areaId)
	local posicoesPorGrupo = {
		[1] = { 10 },
		[2] = { 9, 11 },
		[3] = { 9, 10, 11 },
		[4] = { 8, 9, 10, 11 },
	}
	for indice, player in ipairs(jogadores) do
		local okId, userId = pcall(function() return player.UserId end)
		local okConectado, conectado = pcall(deps.conectado, player)
		if not okId or type(userId) ~= "number"
			or userId % 1 ~= 0 or userId <= 0 or userIds[userId]
			or not okConectado or conectado ~= true
		then
			return nil, "Jogador inválido, repetido ou desconectado."
		end
		userIds[userId] = true
		local ok, ficha, erro = pcall(deps.corpoPessoal, player)
		if not ok or type(ficha) ~= "table" or type(ficha.name) ~= "string"
			or type(ficha.calculated) ~= "table" or type(ficha.calculated.initiative) ~= "table"
		then
			return nil, if ok and type(erro) == "string" then erro else "Ficha pessoal indisponível ou inválida."
		end
		local iniciativa = ficha.calculated.initiative
		local deslocamentoMetros = ficha.calculated.movementMeters
		if type(iniciativa.bonus) ~= "number" or iniciativa.bonus % 1 ~= 0
			or iniciativa.bonus < -50 or iniciativa.bonus > 50 or type(iniciativa.advantage) ~= "boolean"
			or type(deslocamentoMetros) ~= "number" or deslocamentoMetros ~= deslocamentoMetros
			or deslocamentoMetros < 0 or deslocamentoMetros > 30
		then
			return nil, "Iniciativa ou deslocamento da ficha pessoal inválido."
		end
		table.insert(atores, {
			id = "jogador:" .. tostring(userId),
			userId = userId,
			name = ficha.name,
			bonus = iniciativa.bonus,
			advantage = iniciativa.advantage,
			movementCasas = math.floor(deslocamentoMetros / 1.5),
			kind = "jogador",
			respira = true,
			x = posicoesPorGrupo[#jogadores][indice],
			z = if deps.areaId == "region/encounter/ruinas" then 18 else 10,
			ficha = ficha,
		})
	end

	for indice, creatureId in ipairs(criaturas) do
		if type(creatureId) ~= "string" or #creatureId == 0 or #creatureId > 160 then
			return nil, "Identificador de criatura inválido."
		end
		local ok, ficha = pcall(deps.criatura, creatureId, indice)
		if not ok or type(ficha) ~= "table" or ficha.catalogId ~= creatureId or type(ficha.nome) ~= "string" then
			return nil, "Criatura indisponível no bestiário."
		end
		local recompensa = RECOMPENSAS[creatureId] and table.clone(RECOMPENSAS[creatureId]) or nil
		if recompensa and ficha.papel then recompensa.papel = ficha.papel end
		-- O bestiário não fornece bônus de iniciativa. A mesa usa zero para token
		-- sem ficha própria; mantemos esse fallback explicitamente até haver fonte.
		table.insert(atores, {
			id = "criatura:" .. tostring(indice),
			criaturaId = creatureId, -- só apresentação: escolhe o modelo da miniatura (Shared.Mundo.ModelosCriaturas)
			name = ficha.nome,
			bonus = 0,
			advantage = false,
			kind = "criatura",
			respira = RESPIRAM[creatureId] == true,
			x = if deps.areaId == "region/encounter/ruinas" then 5 + (indice - 1) % 8 else 8 + indice,
			z = if formacao then formacao.zCriaturas elseif deps.areaId == "region/encounter/ruinas" then 4 + math.floor((indice - 1) / 8) else 11,
			movementCasas = math.floor((ficha.deslocamentoMetros or 0) / 1.5),
			fichaCriatura = ficha,
			recompensa = recompensa,
		})
	end
	return atores
end

function EncontroAutonomoElenco.recompensas(atores)
	local lista = {}
	for _, ator in ipairs(atores) do
		if ator.kind == "criatura" and ator.recompensa then table.insert(lista, table.clone(ator.recompensa)) end
	end
	return lista
end

return EncontroAutonomoElenco
