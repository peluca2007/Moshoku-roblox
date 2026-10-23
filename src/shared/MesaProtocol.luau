-- Contrato da mesa virtual: nomes, limites e geometria do tabuleiro.
-- Puro: não cria Instances nem envia eventos. Documentação em docs/MESA.md.
local Protocol = {}

Protocol.REMOTE = "Mesa"
-- ReplicatedStorage: true somente após a inicialização completa do servidor.
Protocol.READY_ATTRIBUTE = "MesaPronta"

-- origin é o centro da superfície superior do tabuleiro. O salão da mesa (320x320) fica longe
-- do mundo explorável (região em x -120..229, vila em z -44..-300); não aproximar sem rever o mapa.
Protocol.BOARD = table.freeze({
	width = 20,
	height = 20,
	cell = 5,
	origin = Vector3.new(0, 1, 900),
})

-- Provisório: o livro mede distâncias em metros; tamanho da casa ainda não confirmado.
Protocol.METERS_PER_CELL = 1.5

Protocol.LIMITS = table.freeze({
	name = 32,
	tokens = 60,
	stat = 9999,
	delta = 999,
	initiative = 999,
	formula = 60,
	log = 50,
})

Protocol.MODES = table.freeze({
	"normal",
	"vantagem",
	"desvantagem",
	"vantagemAbsoluta",
	"desvantagemAbsoluta",
})

Protocol.KINDS = table.freeze({ "jogador", "npc" })
Protocol.VISIBILITY = table.freeze({ "publica", "mestre" })

function Protocol.isOneOf(value: any, list: { string }): boolean
	return type(value) == "string" and table.find(list, value) ~= nil
end

function Protocol.isInteger(value: any, low: number, high: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end

function Protocol.isCell(x: any, z: any): boolean
	local board = Protocol.BOARD
	return Protocol.isInteger(x, 1, board.width) and Protocol.isInteger(z, 1, board.height)
end

-- Distância em casas com diagonal custando 1 (adaptação provisória, ver docs/MESA.md).
function Protocol.distance(x: number, z: number, a: number, b: number): number
	return math.max(math.abs(x - a), math.abs(z - b))
end

function Protocol.cellCenter(x: number, z: number): Vector3
	local board = Protocol.BOARD
	return board.origin
		+ Vector3.new((x - 0.5 - board.width / 2) * board.cell, 0, (z - 0.5 - board.height / 2) * board.cell)
end

function Protocol.cellAt(point: Vector3): (number?, number?)
	local board = Protocol.BOARD
	local x = math.floor((point.X - board.origin.X) / board.cell + board.width / 2) + 1
	local z = math.floor((point.Z - board.origin.Z) / board.cell + board.height / 2) + 1
	if Protocol.isCell(x, z) then
		return x, z
	end
	return nil, nil
end

return table.freeze(Protocol)
