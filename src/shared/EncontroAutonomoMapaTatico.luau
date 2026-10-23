-- Prévia de destinos do mapa tático; serviço do encontro revalida cada pedido.
local Movimento = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoMovimento)
local Terreno = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTerreno)

local MapaTatico = {}

local function atorControlado(estado)
	if type(estado) ~= "table" or estado.phase ~= "active" or estado.isMyTurn ~= true
		or type(estado.actionsRemaining) ~= "number" or estado.actionsRemaining <= 0
		or type(estado.actors) ~= "table" or type(estado.controlledActorId) ~= "string"
	then
		return nil
	end
	for _, ator in ipairs(estado.actors) do
		if type(ator) == "table" and ator.id == estado.controlledActorId
			and ator.kind == "jogador" and type(ator.pv) == "number" and ator.pv > 0
		then
			return ator
		end
	end
	return nil
end

function MapaTatico.destinos(estado)
	local controlado = atorControlado(estado)
	if not controlado or type(controlado.movementCasas) ~= "number" or controlado.movementCasas <= 0 then
		return nil
	end
	local ocupantes = {}
	for _, ator in ipairs(estado.actors) do
		if type(ator) == "table" and (ator.kind ~= "criatura" or ator.defeated ~= true) then
			table.insert(ocupantes, ator)
		end
	end
	return Movimento.destinos(controlado.x, controlado.z, ocupantes, controlado.movementCasas,
		Terreno.chavesDe(estado.blockedCells), Terreno.chavesDe(estado.difficultCells))
end

function MapaTatico.solicitarMovimento(state, estado, x, z)
	if type(state) ~= "table" or type(state.mover) ~= "function" then return false end
	local destinos = MapaTatico.destinos(estado)
	if not destinos or not destinos[tostring(x) .. ":" .. tostring(z)] then return false end
	return state.mover(x, z) == true
end

return MapaTatico
