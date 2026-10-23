local MapaTatico = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoMapaTatico)

local function estadoBase()
	return {
		phase = "active", isMyTurn = true, actionsRemaining = 3, controlledActorId = "jogador:1",
		actors = {
			{ id = "jogador:1", kind = "jogador", x = 10, z = 10, pv = 30, movementCasas = 2 },
			{ id = "criatura:1", kind = "criatura", x = 12, z = 10, pv = 20, defeated = false },
			{ id = "criatura:2", kind = "criatura", x = 11, z = 10, pv = 0, defeated = true },
		},
	}
end

return {
	["destinos excluem criaturas derrotadas e respeitam ocupantes vivos"] = function(t)
		local destinos = MapaTatico.destinos(estadoBase())
		t.ok(destinos["11:10"] ~= nil, "casa liberada pela criatura derrotada fica alcançável")
		t.eq(destinos["12:10"], nil, "criatura viva segue ocupando sua casa")
	end,
	["destinos refletidos no mapa excluem terreno bloqueado"] = function(t)
		local estado = estadoBase()
		estado.blockedCells = { { x = 10, z = 11 }, { x = 10, z = 12 } }
		local destinos = MapaTatico.destinos(estado)
		t.eq(destinos["10:11"], nil)
		t.eq(destinos["10:12"], nil)
		t.ok(destinos["9:11"] ~= nil)
	end,
	["previsão do mapa exclui casa difícil quando o orçamento não paga o dobro"] = function(t)
		local estado = estadoBase()
		estado.actors[1].movementCasas = 1
		estado.difficultCells = { { x = 11, z = 10 } }
		local destinos = MapaTatico.destinos(estado)
		t.eq(destinos["11:10"], nil)
		t.ok(destinos["11:11"] ~= nil)
	end,
	["sem vez propria acao deslocamento ou PV nao exibe destinos"] = function(t)
		local estado = estadoBase()
		estado.isMyTurn = false
		t.eq(MapaTatico.destinos(estado), nil)
		estado.isMyTurn, estado.actionsRemaining = true, 0
		t.eq(MapaTatico.destinos(estado), nil)
		estado.actionsRemaining, estado.actors[1].movementCasas = 1, 0
		t.eq(MapaTatico.destinos(estado), nil)
		estado.actors[1].movementCasas, estado.actors[1].pv = 2, 0
		t.eq(MapaTatico.destinos(estado), nil)
	end,
	["envia uma vez apenas um destino alcançavel"] = function(t)
		local estado, pedidos = estadoBase(), {}
		local state = { mover = function(x, z) table.insert(pedidos, { x, z }); return true end }
		t.ok(MapaTatico.solicitarMovimento(state, estado, 11, 10))
		t.eq(#pedidos, 1)
		t.eq(pedidos[1][1], 11)
		t.eq(pedidos[1][2], 10)
		t.eq(MapaTatico.solicitarMovimento(state, estado, 13, 10), false)
		t.eq(#pedidos, 1)
	end,
}
