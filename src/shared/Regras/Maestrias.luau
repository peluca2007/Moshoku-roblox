-- Maestrias, talentos e passivas do Principiante que mudam o combate (A17).
-- Puro: lê a ficha v2 e devolve bandeiras e números; o servidor aplica.
-- Texto de cada regra: Livro/Dados/Arvores (mastery/talent/ability ...Principiante).
-- Adaptações à grade registradas em docs/FIDELIDADE.md §7G.
local Progressao = require(game:GetService("ReplicatedStorage").Shared.Regras.Progressao)

local Maestrias = {}

local function rank(c, arvore: string): boolean
	return Progressao.rankAberto(c, arvore, "Principiante")
end
local function comprou(c, id: string): boolean
	return table.find(c.purchasedIds, id) ~= nil
end

-- Bandeiras da ficha. Habilidades passivas contam se a ficha as conhece
-- (compradas ou gratuitas do rank); talentos, se comprados; maestrias, com o rank.
function Maestrias.daFicha(ficha2, catalogo): { [string]: boolean }
	local f = {}
	local c = ficha2 and ficha2.construction
	if not c then
		return f
	end
	local conhecidas = Progressao.conhecidas(c, catalogo)
	local function sabe(id)
		return table.find(conhecidas, id) ~= nil
	end
	f.quemSeMovePrimeiro = rank(c, "deus-da-espada")
	f.roupaLeve = sabe("ability/deus-da-espada/Principiante/roupa-leve")
	f.semRecuo = sabe("ability/deus-da-espada/Principiante/sem-recuo")
	f.baseFirme = sabe("ability/deus-da-agua-corpo/Principiante/base-firme")
	f.pacienciaDePedra = comprou(c, "talent/deus-da-agua-corpo/Principiante/paciencia-de-pedra")
	f.corpoEArma = rank(c, "armas-pesadas")
	f.pesNoChao = comprou(c, "talent/deus-do-norte/Principiante/pes-no-chao")
	f.pesLeves = comprou(c, "talent/vento/Principiante/pes-leves")
	f.olhoDoCacador = rank(c, "arquearia")
	f.passoETiro = comprou(c, "talent/arquearia/Principiante/passo-e-tiro")
	f.condutorDeGelo = comprou(c, "talent/agua/Principiante/condutor-de-gelo")
	f.afinidadeAquatica = rank(c, "agua")
	f.brisa = rank(c, "vento")
	f.moldar = rank(c, "terra")
	for k, v in f do
		if not v then
			f[k] = nil
		end
	end
	return f
end

-- Armadura de corpo vestida (escudo não conta: Roupa Leve fala de armadura).
function Maestrias.vestindoArmadura(ficha2): boolean
	for _, item in (ficha2 and ficha2.construction and ficha2.construction.inventory) or {} do
		if item.equipped and item.type == "armadura" and not string.find(string.lower(item.name or ""), "escudo", 1, true) then
			return true
		end
	end
	return false
end

-- Deslocamento em casas de 1,5 m. Base: a ficha (movementMeters; 9 m sem dado).
-- Bônus de Deslocamento do mesmo tipo não somam (Cap. 4 §5): vale o maior.
function Maestrias.deslocamentoCasas(ficha2, flags): number
	local metros = (ficha2 and ficha2.calculated and ficha2.calculated.movementMeters) or 9
	local bonus = 0
	if flags.pesLeves then
		bonus = math.max(bonus, 3)
	end
	if flags.roupaLeve and not Maestrias.vestindoArmadura(ficha2) then
		bonus = math.max(bonus, 3)
	end
	return math.floor((metros + bonus) / 1.5)
end

-- Roupa Leve: +2 na CA nos turnos em que se moveu 3 m (2 casas) ou mais.
-- Adaptação: vale do momento em que andou até o início da próxima vez.
function Maestrias.caExtra(ficha2, flags, casasMovidas: number): number
	if flags.roupaLeve and casasMovidas >= 2 and not Maestrias.vestindoArmadura(ficha2) then
		return 2
	end
	return 0
end

-- Condições a que a ficha é imune.
function Maestrias.imuneA(flags, condicao: string): boolean
	if condicao == "amedrontado" then
		return flags.semRecuo == true or flags.pacienciaDePedra == true
	end
	if condicao == "provocado" then
		return flags.pacienciaDePedra == true
	end
	return false
end

-- Base Firme: não é empurrado, puxado contra a vontade nem derrubado por efeito
-- que permita teste de Força ou Agilidade.
function Maestrias.resisteDeslocamento(flags, atributoDoTeste: string?): boolean
	return flags.baseFirme == true and (atributoDoTeste == "forca" or atributoDoTeste == "agilidade")
end

-- Iniciativa: empates de Quem Se Move Primeiro são sempre dele. A mesa mantém a
-- ordem enviada nos empates; então basta pôr quem ganha empate antes.
function Maestrias.ordenarEmpates(entradas, ganhaEmpate: (string) -> boolean)
	local indice = {}
	for i, e in entradas do
		indice[e.id] = i
	end
	table.sort(entradas, function(a, b)
		if a.initiative ~= b.initiative then
			return a.initiative > b.initiative
		end
		local ga, gb = ganhaEmpate(a.id), ganhaEmpate(b.id)
		if ga ~= gb then
			return ga
		end
		return indice[a.id] < indice[b.id]
	end)
	return entradas
end

-- Quem Se Move Primeiro: no primeiro turno do combate, o primeiro ataque tem
-- Vantagem e rola o Dado de Arma uma vez a mais.
function Maestrias.primeiroAtaque(flags, primeiroTurnoDoPersonagem: boolean, jaAtacou: boolean): boolean
	return flags.quemSeMovePrimeiro == true and primeiroTurnoDoPersonagem and not jaAtacou
end

-- O Corpo é a Arma: o primeiro ataque corpo a corpo que acertar cada criatura
-- no seu turno aplica 1 Quebrantado (técnica que diz um número usa o dela).
function Maestrias.quebrantaNoAcerto(flags, corpoACorpo: boolean, jaQuebrantouNesteTurno: boolean, numeroDaTecnica: number?): number?
	if not flags.corpoEArma or not corpoACorpo or jaQuebrantouNesteTurno then
		return nil
	end
	return numeroDaTecnica or 1
end

-- Olho do Caçador: +1 no acerto contra criaturas Marcadas por você.
function Maestrias.bonusContraMarcado(flags, marcadoPorMim: boolean): number
	return if flags.olhoDoCacador and marcadoPorMim then 1 else 0
end

-- Cartas de 0 Ação (uma vez por turno) e a Ação de Marcar. Cada uma exige o
-- rank que dá a maestria. Formato das mecânicas de Regras/ArvoresPrincipiante.
local fimAlvo = { de = "alvo" }
Maestrias.CARTAS = table.freeze({
	["mesa/brisa"] = { tipo = "efeito", nome = "Brisa", acoes = 0, pm = 0, pt = 0, alcanceCasas = 6, umaVezPorTurno = true,
		exigeRank = "vento", arvore = "vento", basico = true, naoAliados = true,
		resistencia = { atributo = "forca", cdBase = 8 }, empurraSempre = 1, aplica = "desequilibrado", duracao = fimAlvo,
		descricao = "Sem Ação, 1 vez por turno: empurra 1,5 m uma criatura a até 9 m; teste de Força ou fica Desequilibrada." },
	["mesa/molhar"] = { tipo = "efeito", nome = "Afinidade Aquática", acoes = 0, pm = 0, pt = 0, alcanceCasas = 1, umaVezPorTurno = true,
		exigeRank = "agua", arvore = "agua", basico = true, semTeste = true, aplica = "molhado", duracao = { rodadas = 10 },
		descricao = "Sem Ação, 1 vez por turno: deixa Molhada uma criatura adjacente." },
	["mesa/moldar"] = { tipo = "efeito", nome = "Moldar", acoes = 0, pm = 0, pt = 0, alcanceCasas = 6, umaVezPorTurno = true,
		exigeRank = "terra", arvore = "terra", basico = true, naoAliados = true,
		resistencia = { atributo = "agilidade", cdBase = 8 }, aplica = "atolado", duracao = fimAlvo, terrenoDificilNoAlvo = true,
		descricao = "Sem Ação, 1 vez por turno: molda o chão sob uma criatura hostil a até 9 m; teste de Agilidade ou fica Atolada." },
	-- Interpor (Cavalaria e Escudos): designar o protegido. O livro não dá custo
	-- de Ação para designar; 0 Ações, troca o designado anterior.
	["mesa/sob-minha-guarda"] = { tipo = "efeito", nome = "Sob Minha Guarda", acoes = 0, pm = 0, pt = 0,
		alcanceCasas = 32, soAliados = true, semTeste = true, guarda = true, designaGuarda = true, basico = true,
		exigeRank = "cavalaria-e-escudos", arvore = "cavalaria-e-escudos",
		descricao = "Designa um aliado: a até 3 m, sua Reação toma para você todo o dano de um golpe contra ele." },
	-- Alfabeto Arcano (Teórica): abre o quadro de desenho (FormulaView). A fórmula
	-- vai pelos comandos desenharFormula/continuarFormula/... (FormulasService).
	["mesa/desenhar-formula"] = { tipo = "formula", nome = "Desenhar fórmula", acoes = 0, pm = 0, pt = 0,
		exigeRank = "teorica", arvore = "teorica", basico = true,
		descricao = "Abre o quadro: trace círculo, linha ou quadrado e escolha essência e verbo." },
	["mesa/marcar"] = { tipo = "efeito", nome = "Marcar", acoes = 1, pm = 0, pt = 0, alcanceCasas = 32,
		exigeRank = "arquearia", arvore = "arquearia", basico = true, semTeste = true, aplica = "marcado",
		descricao = "1 Ação: uma criatura que você vê fica Marcada; +1 no seu acerto contra ela." },
})
-- Ações que todo personagem tem (Cap. 4 §4, "opções básicas que qualquer
-- personagem tem acesso"). Até o início do seu próximo turno = { inicio = true }.
Maestrias.BASICAS = table.freeze({
	["mesa/esquivar"] = { tipo = "efeito", nome = "Esquivar", acoes = 1, pm = 0, pt = 0, alvo = "si", basico = true,
		semTeste = true, esquiva = true,
		descricao = "1 Ação, em você: assume uma postura evasiva até a sua próxima vez. Ataques contra você têm Desvantagem e você tem Vantagem nos testes de resistência. Não precisa escolher um inimigo." },
	["mesa/defender"] = { tipo = "utilidade", nome = "Defender", acoes = 1, pm = 0, pt = 0, basico = true,
		estadosConjurador = { { nome = "defender", valor = true, duracao = { inicio = true } } },
		registro = "defende-se: até a sua próxima vez, todo golpe que acertar perde Vigor + metade do Rank de corpo",
		descricao = "1 Ação: até a sua próxima vez, todo golpe que te acertar causa menos dano (Vigor + metade do maior Rank de corpo)." },
	["mesa/ajudar"] = { tipo = "efeito", nome = "Ajudar", acoes = 1, pm = 0, pt = 0, alcanceCasas = 1, basico = true,
		soAliados = true, semTeste = true, estados = { { nome = "auxilio", valor = true, duracao = { de = "conjurador", inicio = true } } },
		descricao = "1 Ação: um aliado ao seu lado tem Vantagem no próximo ataque até a sua próxima vez." },
})

-- Defender/Absorver: Vigor + metade do maior Bônus de Rank entre as árvores do
-- Corpo (para cima; 0 sem árvore de corpo); nunca negativo.
function Maestrias.reducaoDefender(vigor: number, maiorRankCorpo: number): number
	return math.max(0, vigor + math.ceil(maiorRankCorpo / 2))
end

-- Registro completo de cartas A17, consumido por Execucao no servidor/cliente.
local mecanicas = {}
for _, grupo in { Maestrias.CARTAS, Maestrias.BASICAS } do
	for id, mec in grupo do mecanicas[id] = mec end
end
Maestrias.MECANICAS = table.freeze(mecanicas)

return Maestrias
