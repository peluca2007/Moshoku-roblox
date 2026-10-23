-- Mapa único criatura -> modelo do Blender (módulos em server/Mundo/Modelos).
-- Dados puros: patrulhas do mundo (PatrulhaModelo) e miniaturas J2 (EncontroAutonomoMiniaturas)
-- consultam só este módulo. Pivôs das juntas: Shared.Mundo.PivosModelos (nome do módulo).
-- escalaMundo: patrulha andando pelo mapa; escalaCombate: miniatura na grade (casas de 1,8 stud). Pequenas/médias
-- mantêm a escala do mundo (o avatar do jogador também é em tamanho real); as grandes encolhem para caber.
-- tipo: família de animação (AnimacaoCriatura): humanoide | quadrupede | aranha | pesado.
local ModelosCriaturas = {}

ModelosCriaturas.POR_CRIATURA = table.freeze({
	["creature/goblin-batedor"] = { modulos = { "GoblinFaca", "GoblinArco" }, escalaMundo = 1, escalaCombate = 1, tipo = "humanoide" },
	["creature/lobo-cinzento"] = { modulos = { "LoboCinzento" }, escalaMundo = 1, escalaCombate = 1, tipo = "quadrupede" },
	["creature/urso-de-presas-vermelhas"] = { modulos = { "UrsoPresasVermelhas" }, escalaMundo = 1, escalaCombate = 0.8, tipo = "quadrupede" },
	["creature/bandido-de-estrada"] = { modulos = { "BandidoPorrete", "BandidoEspada" }, escalaMundo = 1, escalaCombate = 1, tipo = "humanoide" },
	["creature/rato-gigante"] = { modulos = { "RatoGigante" }, escalaMundo = 1, escalaCombate = 1, tipo = "quadrupede" },
	["creature/aranha-da-floresta"] = { modulos = { "AranhaFloresta" }, escalaMundo = 1, escalaCombate = 0.8, tipo = "aranha" },
	["creature/treant-anciao"] = { modulos = { "TreantAnciao" }, escalaMundo = 1, escalaCombate = 0.4, tipo = "pesado" },
	["creature/golem-de-pedra-menor"] = { modulos = { "GolemPedraMenor" }, escalaMundo = 1, escalaCombate = 0.6, tipo = "pesado" },
})

-- Prefixo legado de `EncontrosPorZona.patrulhas()[i].modelo` -> criatura.
ModelosCriaturas.POR_PREFIXO = table.freeze({
	Goblin = "creature/goblin-batedor",
	Lobo = "creature/lobo-cinzento",
	Urso = "creature/urso-de-presas-vermelhas",
	Bandido = "creature/bandido-de-estrada",
	Rato = "creature/rato-gigante",
	Aranha = "creature/aranha-da-floresta",
	Treant = "creature/treant-anciao",
	Golem = "creature/golem-de-pedra-menor",
})

-- Devolve {modulo, escalaMundo, escalaCombate, tipo} ou nil. `variante` (inteiro) escolhe entre
-- os modelos da criatura de forma determinística (ex.: índice do ator ou hash do nome).
function ModelosCriaturas.escolher(criaturaId, variante)
	local entrada = if type(criaturaId) == "string" then ModelosCriaturas.POR_CRIATURA[criaturaId] else nil
	if not entrada then return nil end
	local indice = 1
	if type(variante) == "number" then indice = (math.floor(variante) % #entrada.modulos) + 1 end
	return {
		modulo = entrada.modulos[indice],
		escalaMundo = entrada.escalaMundo,
		escalaCombate = entrada.escalaCombate,
		tipo = entrada.tipo,
		criaturaId = criaturaId,
	}
end

function ModelosCriaturas.criaturaDoPrefixo(prefixo)
	return if type(prefixo) == "string" then ModelosCriaturas.POR_PREFIXO[prefixo] else nil
end

-- Hash estável de texto para a variante (patrulhas escolhem o modelo pelo nome).
function ModelosCriaturas.variante(texto)
	local soma = 0
	for i = 1, #tostring(texto) do soma = (soma * 31 + string.byte(tostring(texto), i)) % 100003 end
	return soma
end

-- Política visual comum às patrulhas e miniaturas; nunca modifica o asset gerado.
function ModelosCriaturas.material(nome, materialOriginal)
	if string.match(nome, "Brilho") then return "Neon" end
	if materialOriginal == "Metal" then return "Metal" end
	return "SmoothPlastic"
end

return ModelosCriaturas
