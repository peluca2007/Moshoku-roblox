-- Arenas fixas por região do Modo História (PLANO §13), em dados puros. A grade é sempre o tabuleiro
-- da mesa (MesaProtocol.BOARD, 20x20 casas de 5 studs); cada arena só troca o cenário em volta.
-- Posições relativas ao centro do tabuleiro; o tabuleiro ocupa ±50 studs em x e z.
local ArenasDados = {}

-- Zona da patrulha (EncontrosPorZona.PATRULHAS.zona) -> arena. Zona sem arena própria usa o livro da mesa.
local POR_ZONA = table.freeze({
	["region/clareira-inicial"] = "cidade",
})

function ArenasDados.daZona(zona)
	return if type(zona) == "string" then POR_ZONA[zona] else nil
end

-- Praça da cidade: casas e barracas fechando o largo, moradores na beira assistindo a luta.
-- props: { modelo, x, z, anguloGraus, escala? }; moradores: { x, z } (olham para o centro).
ArenasDados.CIDADE = table.freeze({
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

function ArenasDados.layout(arenaId)
	return if arenaId == "cidade" then ArenasDados.CIDADE else nil
end

return table.freeze(ArenasDados)
