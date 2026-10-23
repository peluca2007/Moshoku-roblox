-- Arenas fixas por região do Modo História (PLANO §13), em dados puros. A grade é sempre o tabuleiro
-- da mesa (MesaProtocol.BOARD, 20x20 casas de 5 studs); cada arena só troca o cenário em volta.
-- Posições relativas ao centro do tabuleiro; o tabuleiro ocupa ±50 studs em x e z.
local ArenasDados = {}

-- Patrulha (EncontrosPorZona.PATRULHAS) -> arena: primeiro `definicao.arena`, depois o id, depois a zona.
-- Ratos do celeiro/horta ficam na cidade; o goblin rondando o campo e a passagem lutam no campo.
local POR_PATRULHA = table.freeze({
	["goblin-campo"] = "campo",
})
local POR_ZONA = table.freeze({
	["region/clareira-inicial"] = "cidade",
	["region/floresta-sombria"] = "floresta",
	["region/passagem"] = "campo",
	["region/ruinas-do-vale"] = "ruinas",
})

-- Marco do mundo / luta do chefe da run (areaId de EncontrosPorZona) -> arena.
local POR_MARCO = table.freeze({
	["region/encounter/clearing"] = "campo",
	["region/encounter/forest"] = "floresta",
	["region/encounter/dark-forest"] = "floresta",
	["region/encounter/ruinas"] = "ruinas",
})

function ArenasDados.daMarco(areaId)
	return if type(areaId) == "string" then POR_MARCO[areaId] else nil
end

function ArenasDados.daZona(zona)
	return if type(zona) == "string" then POR_ZONA[zona] else nil
end

function ArenasDados.daPatrulha(definicao)
	if type(definicao) ~= "table" then return nil end
	if type(definicao.arena) == "string" and ArenasDados.layout(definicao.arena) then return definicao.arena end
	return (type(definicao.id) == "string" and POR_PATRULHA[definicao.id]) or ArenasDados.daZona(definicao.zona)
end

-- props: { modelo, x, z, anguloGraus, escala? } (inclui criaturas paradas que espreitam a luta);
-- moradores: { x, z } (avatares que olham para o centro e acenam).
-- `mundo`: ponto do mapa que a arena representa, para a luz do cliente seguir a região e a hora da run.
ArenasDados.CIDADE = table.freeze({
	mundo = { x = 0, z = -150 },
	piso = { material = "Cobblestone", cor = { 132, 126, 116 } },
	chao = { material = "Grass", cor = { 92, 118, 70 } },
	props = {
		{ "Casa1", -30, -78, 0 }, { "CasaSacada1", 8, -80, 0 }, { "Casa2", 44, -76, 0 },
		{ "CasaPalha1", -76, -36, 90 }, { "Casa3", -78, 14, 90 }, { "CasaPalha1", -76, 56, 90 },
		{ "CasaSacada1", 78, -30, -90 }, { "Casa1", 80, 20, -90 }, { "Casa2", 76, 60, -90 },
		{ "MercadoLiso", -34, 74, 180 }, { "Barraca", 0, 76, 180 }, { "MercadoLiso", 34, 74, 180 },
		{ "Barril", -58, -60, 0 }, { "Caixotes", 60, -60, 30 }, { "Carroca", -60, 66, 45 },
		{ "Barril", 62, 64, 0 }, { "Lampiao", -56, -10, 0 }, { "Lampiao", 56, 10, 0 },
		{ "Bandeirolas1", 0, -62, 0 }, { "Bandeirolas2", 0, 62, 0 },
	},
	moradores = {
		{ -36, -58 }, { -12, -60 }, { 20, -58 }, { 40, -57 },
		{ -58, -24 }, { -59, 30 }, { 58, -20 }, { 59, 36 },
		{ -40, 58 }, { 16, 59 }, { 42, 58 },
	},
})

-- Campo aberto fora da vila (e a estrada da passagem): cercas, feno, carroça e camponeses curiosos.
ArenasDados.CAMPO = table.freeze({
	mundo = { x = 32, z = -66 },
	piso = { material = "Grass", cor = { 112, 138, 74 } },
	chao = { material = "Grass", cor = { 98, 128, 66 } },
	props = {
		{ "CercaTrilhos", -40, -56, 0 }, { "CercaTrilhos", -14, -56, 0 }, { "CercaTrilhos", 14, -56, 0 }, { "CercaTrilhos", 40, -56, 0 },
		{ "CercaRipas", -56, -30, 90 }, { "CercaRipas", -56, 0, 90 }, { "CercaRipas", 56, -30, 90 }, { "CercaRipas", 56, 0, 90 },
		{ "Fardo1", -64, -62, 15 }, { "Fardo1", -70, -50, 70 }, { "Fardo1", 66, 58, 40 },
		{ "Carroca", 70, -60, -30 }, { "Tenda1", -74, 50, 60 }, { "Placa1", 58, 54, -45 },
		{ "Pinheiro1", -86, -10, 0 }, { "Pinheiro3", -84, 30, 0 }, { "CarvalhoB1", 86, 26, 0 }, { "CarvalhoB3", 0, -92, 0 },
		{ "Rochedo1", 74, -14, 0 }, { "Rocha2", -62, 72, 0 }, { "TufoGrama1", 30, 62, 0 }, { "Flores2", -28, 62, 0 },
		{ "Lenha", -60, 30, 90 }, { "Tora1", 62, 34, 0 },
	},
	moradores = { { -30, -62 }, { 26, -63 }, { -62, -14 }, { 62, 20 } },
})

-- Floresta Sombria: mata fechada, cogumelos que brilham e bichos espreitando entre as árvores.
ArenasDados.FLORESTA = table.freeze({
	mundo = { x = 0, z = -420 },
	piso = { material = "LeafyGrass", cor = { 64, 82, 50 } },
	chao = { material = "Mud", cor = { 54, 48, 38 } },
	props = {
		{ "AbetoSombrio1", -70, -70, 0 }, { "AbetoSombrio2", -30, -82, 0 }, { "CarvalhoAntigo1", 20, -84, 0 }, { "AbetoSombrio3", 66, -74, 0 },
		{ "Pinheiro2", -84, -30, 0 }, { "CarvalhoAntigo2", -86, 20, 0 }, { "AbetoSombrio1", -76, 64, 0 },
		{ "Pinheiro4", 84, -24, 0 }, { "AbetoSombrio2", 86, 24, 0 }, { "CarvalhoAntigo1", 72, 72, 0 },
		{ "ArvoreMorta1", -30, 80, 0 }, { "AbetoSombrio3", 14, 86, 0 }, { "ArvoreMorta2", 46, 82, 0 },
		{ "Samambaia1", -58, -40, 0 }, { "Samambaia2", 58, -44, 0 }, { "Samambaia1", -56, 40, 0 }, { "Samambaia2", 60, 46, 0 },
		{ "CogumelosLuz1", -57, -6, 0 }, { "CogumelosLuz1", 55, 8, 0 }, { "Cogumelos1", -20, 58, 0 }, { "CogumelosLuz1", 24, -57, 0 },
		{ "ToraMusgo1", -62, 20, 80 }, { "Toco1", 62, -10, 0 }, { "Rocha1", 36, 60, 0 },
		{ "LoboCinzento", -64, -24, 70 }, { "LoboCinzento", 66, 32, -110 }, { "AranhaFloresta", -6, -64, 180 },
	},
	moradores = {},
})

-- Ruínas do Vale: colunas tomadas pela hera, arco e altar; goblins vigiam do alto das pedras.
ArenasDados.RUINAS = table.freeze({
	mundo = { x = 600, z = -150 },
	piso = { material = "Slate", cor = { 112, 108, 100 } },
	chao = { material = "Ground", cor = { 98, 90, 74 } },
	props = {
		{ "Arco", 0, -66, 0 }, { "Altar", 0, -82, 0 }, { "EscadaQuebrada", -40, -70, 0 }, { "EscadaQuebrada", 40, -70, 0 },
		{ "ColunaHera1", -58, -58, 0 }, { "Coluna1", -58, -20, 0 }, { "ColunaQuebrada1", -58, 20, 0 }, { "ColunaHera2", -58, 58, 0 },
		{ "ColunaHera2", 58, -58, 0 }, { "ColunaQuebrada2", 58, -20, 0 }, { "Coluna2", 58, 20, 0 }, { "ColunaHera1", 58, 58, 0 },
		{ "ColunaQuebrada1", -24, 60, 0 }, { "ColunaQuebrada2", 24, 60, 0 }, { "Estandarte2", -20, -60, 0 }, { "Estandarte3", 20, -60, 0 },
		{ "Rochedo2", -82, 0, 0 }, { "Rochedo1", 84, 36, 0 }, { "ArvoreMorta3", -78, 70, 0 }, { "Lapide1", 74, -76, 20 },
		{ "GoblinArco", -66, -40, 60 }, { "GoblinFaca", 66, -36, -60 }, { "GolemPedraMenor", 0, 72, 180 },
	},
	moradores = {},
})

local LAYOUTS = table.freeze({
	cidade = ArenasDados.CIDADE, campo = ArenasDados.CAMPO,
	floresta = ArenasDados.FLORESTA, ruinas = ArenasDados.RUINAS,
})

function ArenasDados.layout(arenaId)
	return if type(arenaId) == "string" then LAYOUTS[arenaId] else nil
end

function ArenasDados.ids()
	local lista = {}
	for id in LAYOUTS do table.insert(lista, id) end
	table.sort(lista)
	return lista
end

-- Ponto do mapa que a arena representa (luz e hora da run); nil fora de uma arena regional.
function ArenasDados.pontoDoMundo(arenaId)
	local layout = ArenasDados.layout(arenaId)
	return layout and layout.mundo
end

return table.freeze(ArenasDados)
