-- Catálogo puro dos marcos de encontro disponíveis na região inicial.
local EncontrosPorZona = {}

local ZONAS = {
 ["region/encounter/ruinas"] = {
  id = "region/encounter/ruinas", zona = "region/ruinas-do-vale",
  marco = "region/ruinas-do-vale/encontro/marco", ameaca = "moderada", familia = "ruinas",
 },
	["region/encounter/clearing"] = {
		id = "region/encounter/clearing",
		zona = "region/clareira-inicial",
		marco = "region/clareira-inicial/encontro/marco",
		ameaca = "baixa",
		familia = "baixa",
	},
	["region/encounter/forest"] = {
		id = "region/encounter/forest",
		zona = "region/clareira-inicial/bosque",
		marco = "region/clareira-inicial/encontro-bosque/marco",
		ameaca = "moderada",
		familia = "moderada",
	},
	["region/encounter/dark-forest"] = {
		id = "region/encounter/dark-forest",
		zona = "region/floresta-sombria",
		marco = "region/floresta-sombria/encontro/marco",
		ameaca = "alta",
		familia = "alta",
	},
}

-- B1: espaço para uma primeira troca à distância, sem alterar regras ou recursos.
-- Disparo básico já existe no J2; a IA ainda move/ataca com as regras de sempre.
function EncontrosPorZona.formacaoInicial(id)
 if id == "region/encounter/clearing" then return { zCriaturas=18 } end
 return nil
end

function EncontrosPorZona.consultar(id)
	local zona = ZONAS[id]
	if not zona then return nil end
	return {
		id = zona.id,
		zona = zona.zona,
		marco = zona.marco,
		ameaca = zona.ameaca,
		elenco = EncontrosPorZona.elegivel(id, 1).elenco,
	}
end

function EncontrosPorZona.elegivel(id, quantidadeJogadores)
	local zona = ZONAS[id]
	if not zona or type(quantidadeJogadores) ~= "number"
		or quantidadeJogadores % 1 ~= 0 or quantidadeJogadores < 1 or quantidadeJogadores > 4
	then return nil end
	-- Apêndice G: orçamento equilibrado é 1 criatura padrão do patamar do grupo
	-- por jogador; lacaio pesa 0,5. Ameaças alvo são 0,5x (baixa), 1x
	-- (moderada) e 1,5x (alta), escaladas pelo tamanho real do grupo.
	local elenco = {}
	local function repetir(id, n)
		for _ = 1, n do table.insert(elenco, id) end
	end
	if zona.familia == "ruinas" then
		repetir("creature/goblin-batedor", quantidadeJogadores * 2)
	elseif zona.familia == "baixa" then
		repetir("creature/goblin-batedor", quantidadeJogadores)
	elseif zona.familia == "moderada" then
		repetir("creature/lobo-cinzento", quantidadeJogadores)
	else
		repetir("creature/lobo-cinzento", quantidadeJogadores)
		repetir("creature/goblin-batedor", quantidadeJogadores)
	end
	return { id = zona.id, zona = zona.zona, ameaca = zona.ameaca, elenco = elenco }
end

-- Conteúdo R7b para grupo inicial de patamar 1. Pesos e limite Difícil:
-- bestiary.ts/pesoNoOrcamento e TEMPERATURAS (Apêndice G).
-- Preserva um guardião; acompanhantes completam o orçamento em passos de 0,5.
-- Expedição do esgoto: as salas sorteiam elencos diferentes para a mesma área. A lista recebida é o elenco
-- para 1 jogador (1 a 4 criaturas do catálogo, sem chefe); o grupo repete esse elenco por jogador, o que
-- mantém o orçamento proporcional (peso = papel x 2^(patamar-1); lacaio 0,5, padrão 1).
EncontrosPorZona.AREA_ESGOTO = "region/encounter/esgoto"
local PESO_PAPEL = { lacaio = 0.5, padrao = 1 }
local dadosCriaturas
local function pesoDaCriatura(id)
	if not dadosCriaturas then
		dadosCriaturas = {}
		for _, item in require(game:GetService("ReplicatedStorage").Shared.Livro.Dados.Criaturas) do dadosCriaturas[item.id] = item.data end
	end
	local d = type(id) == "string" and dadosCriaturas[id] or nil
	local papel = d and PESO_PAPEL[d.papel]
	return papel and papel * 2 ^ ((d.patamar or 1) - 1) or nil
end
local function paraEsgoto(luta, quantidade)
	local base = luta.criaturas
	if type(base) ~= "table" or #base < 1 or #base > 4 then return nil, "Elenco do esgoto inválido." end
	for chave in base do
		if type(chave) ~= "number" or chave < 1 or chave > #base then return nil, "Elenco do esgoto inválido." end
	end
	local pesoBase = 0
	for _, id in base do
		local p = pesoDaCriatura(id)
		if not p then return nil, "Criatura sem suporte no esgoto." end
		pesoBase += p
	end
	local elenco = {}
	for _ = 1, quantidade do
		for _, id in base do table.insert(elenco, id) end
	end
	local peso = pesoBase * quantidade
	return { elenco = elenco, papeis = {}, peso = peso, orcamento = quantidade, razao = peso / quantidade }
end

function EncontrosPorZona.paraRun(luta, quantidade)
	if type(luta) == "table" and luta.areaId == EncontrosPorZona.AREA_ESGOTO then
		if type(quantidade) ~= "number" or quantidade % 1 ~= 0 or quantidade < 1 or quantidade > 4 then
			return nil, "Luta da run ou tamanho do grupo inválido."
		end
		return paraEsgoto(luta, quantidade)
	end
	if type(luta) ~= "table" or type(quantidade) ~= "number" or quantidade % 1 ~= 0
		or quantidade < 1 or quantidade > 4 or not ZONAS[luta.areaId]
		or (luta.areaId ~= "region/encounter/forest" and luta.areaId ~= "region/encounter/dark-forest" and luta.areaId ~= "region/encounter/ruinas")
		or type(luta.criaturas) ~= "table" or #luta.criaturas ~= 1
	then return nil, "Luta da run ou tamanho do grupo inválido." end
	for chave in luta.criaturas do
		if chave ~= 1 then return nil, "O elenco base da run deve conter um guardião." end
	end
	-- Não aceitar qualquer criatura sem conhecer peso/imunidades e suporte J2.
	-- Golem (imunidades/fortaleza) aguarda conteúdo seguro das Ruínas.
	if luta.criaturas[1] == "creature/goblin-batedor" then
		-- Bando das Ruínas: lacaios de patamar 1 pesam 0,5; dois por jogador fecham o orçamento (Equilibrado).
		local elenco = {}
		for _ = 1, quantidade * 2 do table.insert(elenco, "creature/goblin-batedor") end
		return { elenco = elenco, papeis = {}, peso = quantidade, orcamento = quantidade, razao = 1 }
	end
	if luta.criaturas[1] ~= "creature/urso-de-presas-vermelhas" then
		return nil, "Este guardião ainda não tem elenco seguro para a run."
	end
	local elenco, papeis = { luta.criaturas[1] }, {}
	local peso = 2 -- patamar 2 padrão versus grupo 1: 2^(2-1).
	if quantidade == 1 then
		papeis[1], peso = "lacaio", 1 -- papel do Apêndice G, sem mudar o molde.
	else
		local teto = math.floor(quantidade * 1.25 * 2) / 2
		while peso + 1 <= teto do
			table.insert(elenco, "creature/lobo-cinzento")
			peso += 1
		end
		if peso + 0.5 <= teto then
			table.insert(elenco, "creature/goblin-batedor")
			peso += 0.5
		end
	end
	return { elenco = elenco, papeis = papeis, peso = peso, orcamento = quantidade,
		razao = peso / quantidade }
end

function EncontrosPorZona.listar()
	local resultado = {}
	for id in ZONAS do table.insert(resultado, id) end
	table.sort(resultado)
	return resultado
end

-- B1: perigo por distância; 1 lacaio de patamar 1 por jogador = 0,5× (Fácil).
-- Lobos (1×) ficam na borda, com aviso alto para iniciantes; interior preservado.
-- W1b: percursos locais; uma silhueta representa o pequeno grupo J2.
local PATRULHAS = {
 { id="ratos-celeiro", nome="Ratos no celeiro", zona="region/clareira-inicial", marco="region/encounter/clearing", criatura="creature/rato-gigante", modelo="Rato", x=-16, z=-90, raio=6, perigo="fácil", faixa="inicial" },
 { id="goblin-campo", nome="Goblin rondando o campo", zona="region/clareira-inicial", marco="region/encounter/clearing", criatura="creature/goblin-batedor", modelo="Goblin", x=32, z=-66, raio=6, perigo="fácil", faixa="inicial" },
 { id="lobos-estrada", nome="Lobos na borda da floresta", zona="region/floresta-sombria", marco="region/encounter/forest", criatura="creature/lobo-cinzento", modelo="Lobo", x=28, z=-345, raio=5, perigo="alto", faixa="borda" },
 { id="ratos-horta", nome="Ratos da horta", zona="region/clareira-inicial", marco="region/encounter/clearing", criatura="creature/rato-gigante", modelo="Rato", x=-34, z=-76, raio=5, perigo="fácil", faixa="inicial" },
 { id="lobos-trilha", nome="Batedor da trilha", zona="region/floresta-sombria", marco="region/encounter/dark-forest", criatura="creature/goblin-batedor", modelo="Goblin", x=4, z=-315, raio=4, perigo="médio", faixa="trilha", quantidadePorJogador=1 },
 { id="aranhas-floresta", nome="Aranhas da floresta", zona="region/floresta-sombria", marco="region/encounter/dark-forest", criatura="creature/aranha-da-floresta", modelo="Aranha", x=-12, z=-420, raio=5 },
 { id="urso-floresta", nome="Urso da floresta", zona="region/floresta-sombria", marco="region/encounter/dark-forest", criatura="creature/urso-de-presas-vermelhas", modelo="Urso", x=18, z=-462, raio=6 },
 { id="bandidos-passagem", nome="Bandidos da passagem", zona="region/passagem", marco="region/encounter/forest", criatura="creature/bandido-de-estrada", modelo="Bandido", x=380, z=-40, raio=4 },
 { id="goblins-ruinas", nome="Goblins das Ruínas", zona="region/ruinas-do-vale", marco="region/encounter/ruinas", criatura="creature/goblin-batedor", modelo="Goblin", x=600, z=-150, raio=5 },
 { id="golem-ruinas", nome="Golem menor das Ruínas", zona="region/ruinas-do-vale", marco="region/encounter/ruinas", criatura="creature/golem-de-pedra-menor", modelo="Golem", x=600, z=-200, raio=5 },
}
EncontrosPorZona.REAPARECER_SEGUNDOS = 120 -- tempo da run: combate não conta.
function EncontrosPorZona.patrulhas()
 local lista = {}
 for _, item in ipairs(PATRULHAS) do table.insert(lista, table.clone(item)) end
 return lista
end
function EncontrosPorZona.elencoPatrulha(id, quantidade)
 if type(quantidade) ~= "number" or quantidade % 1 ~= 0 or quantidade < 1 or quantidade > 4 then return nil end
 for _, item in ipairs(PATRULHAS) do
  if item.id == id then
   local elenco = {}
   for _ = 1, quantidade * (item.quantidadePorJogador or 1) do table.insert(elenco, item.criatura) end
   return elenco
  end
 end
 return nil
end
function EncontrosPorZona.podeReaparecer(agora, derrotadaEm)
 return type(agora) == "number" and type(derrotadaEm) == "number"
  and agora >= derrotadaEm + EncontrosPorZona.REAPARECER_SEGUNDOS
end

return EncontrosPorZona
