local Protocol = require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)
local board = Protocol.BOARD

return {
	["centro e casa se correspondem nas bordas"] = function(t)
		for _, cell in { { 1, 1 }, { board.width, 1 }, { 1, board.height }, { board.width, board.height }, { 7, 13 } } do
			local x, z = Protocol.cellAt(Protocol.cellCenter(cell[1], cell[2]))
			t.eq(x, cell[1], "x")
			t.eq(z, cell[2], "z")
		end
	end,
	["ponto fora do tabuleiro não é casa"] = function(t)
		local edge = board.width * board.cell / 2
		t.eq(Protocol.cellAt(board.origin + Vector3.new(edge + 0.1, 0, 0)), nil)
		t.eq(Protocol.cellAt(board.origin - Vector3.new(0, 0, edge + 0.1)), nil)
	end,
	["isCell recusa tipos e valores inválidos"] = function(t)
		t.ok(Protocol.isCell(1, board.height))
		t.ok(not Protocol.isCell(0, 1))
		t.ok(not Protocol.isCell(1.5, 1))
		t.ok(not Protocol.isCell(0 / 0, 1))
		t.ok(not Protocol.isCell(math.huge, 1))
		t.ok(not Protocol.isCell("1", 1))
		t.ok(not Protocol.isCell(nil, 1))
	end,
	["diagonal custa uma casa"] = function(t)
		t.eq(Protocol.distance(1, 1, 4, 3), 3)
		t.eq(Protocol.distance(5, 5, 5, 5), 0)
	end,
	["isOneOf exige string da lista"] = function(t)
		t.ok(Protocol.isOneOf("vantagem", Protocol.MODES))
		t.ok(not Protocol.isOneOf("VANTAGEM", Protocol.MODES))
		t.ok(not Protocol.isOneOf(1, Protocol.MODES))
	end,
}
