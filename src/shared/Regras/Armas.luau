-- A15: opções geradas do livro; nunca aceita nome/dado fornecido pelo cliente.
-- A troca substitui a arma inicial. Não vende o kit nem concede outro item.
local Personagens = require(game:GetService("ReplicatedStorage").Shared.PersonagensProntos)
local Armas = {}
local POR_ID = {}
for _, p in Personagens do POR_ID[p.id] = p end

function Armas.personagem(id)
	return POR_ID[id]
end

function Armas.validar(payload)
	if type(payload) ~= "table" then return nil, "Pedido de personagem inválido." end
	for chave in payload do
		if chave ~= "id" and chave ~= "arma" then return nil, "Campo desconhecido na escolha." end
	end
	if type(payload.id) ~= "string" or #payload.id > 64 or not POR_ID[payload.id] then
		return nil, "Personagem desconhecido."
	end
	local p = POR_ID[payload.id]
	local id = payload.arma
	if id == nil then id = p.armaPadrao end
	if type(id) ~= "string" or #id == 0 or #id > 96 or not utf8.len(id) then
		return nil, "Arma inválida."
	end
	for _, arma in p.armas do
		if arma.id == id then
			if arma.indisponivel then return nil, arma.indisponivel end
			return arma, nil
		end
	end
	return nil, "Esta árvore não permite escolher essa arma."
end

function Armas.grupo(nome)
	for _, p in Personagens do
		for _, arma in p.armas do
			if arma.nome == nome then return arma.grupo end
		end
	end
	return nil
end

-- Só altera inventário de uma ficha já validada e pertencente ao servidor.
-- Retorna cópias dos itens: não modifica o pré-montado nem outra ficha.
function Armas.aplicar(ficha, personagemId, armaId)
	local arma, erro = Armas.validar({ id = personagemId, arma = armaId })
	if not arma then return erro end
	local p = POR_ID[personagemId]
	local inventario = {}
	for _, item in ficha.construction.inventory or {} do
		if item.type ~= "arma" or item.name ~= p.armaPadrao then
			local copia = table.clone(item)
			if copia.type == "arma" then
				-- Reserva continua na mochila; só a escolhida pode ser equipada.
				copia.equipped = false
			end
			table.insert(inventario, copia)
		end
	end
	if not arma.desarmado then
		-- Primeiro projétil = escolha, inclusive ao escolher a própria reserva.
		for i = #inventario, 1, -1 do
			if inventario[i].type == "arma" and inventario[i].name == arma.nome then table.remove(inventario, i) end
		end
		table.insert(inventario, 1, {
			sourceLocalId = "arma-inicial-a15", name = arma.nome, type = "arma",
			baseDie = arma.dado, equipped = not arma.disparo,
		})
	end
	ficha.construction.inventory = inventario
	return nil
end

function Armas.ehDisparo(nome)
	local grupo = Armas.grupo(nome)
	return grupo == "arcos-e-bestas" or grupo == "arremesso"
end

return Armas
