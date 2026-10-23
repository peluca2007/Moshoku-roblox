-- Principiante das árvores de utilidade (A20): Furtividade e Armadilhas (Ladino),
-- Bardo e Interação e Navegação e Liderança (Tático). Puro: bandeiras da ficha,
-- números das regras e as cartas "mesa/*" que não têm id no catálogo.
-- Texto: Livro/Dados/Arvores/{furtividade_e_armadilhas,bardo_e_interacao,
-- navegacao_e_lideranca}.luau e Livro/Dados/Condicoes (Escondido, Desprevenido,
-- Apontado). Adaptações: docs/FIDELIDADE.md §7K.
local Shared = game:GetService("ReplicatedStorage").Shared
local Progressao = require(Shared.Regras.Progressao)
local Regras = require(Shared.Livro.Regras)

local U = {}

U.FURTIVIDADE, U.BARDO, U.NAVEGACAO = "furtividade-e-armadilhas", "bardo-e-interacao", "navegacao-e-lideranca"
-- Alcance da voz (Inspiração, canções, Insulto, Refrão "9 m"): o livro diz "que te
-- ouça"; a grade usa 12 casas (18 m) para voz e 6 casas para os 9 m do Refrão.
U.ALCANCE_VOZ = 12
U.ALCANCE_REFRAO = 6

-- Patamar numa árvore: 1 no Principiante, 2 no Intermediário...
function U.patamar(ficha2, arvore: string): number
	local c = ficha2 and ficha2.construction
	local rank = c and Progressao.maiorRank(c, arvore)
	return if rank then (table.find(Regras.ordemDosRanks, rank) or 0) else 0
end

local function comprou(c, id: string): boolean
	return table.find(c.purchasedIds, id) ~= nil
end

function U.daFicha(ficha2, catalogo): { [string]: any }
	local f = { furtivo = 0, bardo = 0, tatico = 0 }
	local c = ficha2 and ficha2.construction
	if not c then
		return f
	end
	local conhecidas = Progressao.conhecidas(c, catalogo)
	local function sabe(id)
		return table.find(conhecidas, id) ~= nil
	end
	local function talento(arvore, id)
		return comprou(c, "talent/" .. arvore .. "/Principiante/" .. id)
	end
	f.furtivo = U.patamar(ficha2, U.FURTIVIDADE)
	f.primeiroGolpe = sabe("ability/" .. U.FURTIVIDADE .. "/Principiante/primeiro-golpe")
	f.duelistaDeRua = talento(U.FURTIVIDADE, "duelista-de-rua")
	f.nuncaPreso = talento(U.FURTIVIDADE, "nunca-preso")
	f.bardo = U.patamar(ficha2, U.BARDO)
	f.inspiracao = sabe("ability/" .. U.BARDO .. "/Principiante/inspiracao")
	f.refrao = sabe("ability/" .. U.BARDO .. "/Principiante/refrao-da-retomada")
	f.marcha = talento(U.BARDO, "cantiga-de-marcha")
	f.tatico = U.patamar(ficha2, U.NAVEGACAO)
	f.vozQueCorrige = talento(U.NAVEGACAO, "voz-que-corrige")
	f.primeiroAVer = sabe("ability/" .. U.NAVEGACAO .. "/Principiante/primeiro-a-ver")
	return f
end

-- Dado de Inspiração: 1d6 (1º-2º patamar), 2d6 (3º-4º), 3d6 (5º-6º).
function U.dadoDeInspiracao(patamar: number): string
	return math.max(1, math.ceil(patamar / 2)) .. "d6"
end

-- Desprevenido: ainda não agiu neste combate, está Surpreso, ou não sabe onde
-- o atacante está (atacante Escondido).
function U.desprevenido(alvoJaAgiu: boolean, surpreso: boolean, atacanteEscondido: boolean): boolean
	return not alvoJaAgiu or surpreso or atacanteEscondido
end

-- Dano Furtivo (maestria): uma vez por turno, ao acertar alvo Desprevenido, Cego,
-- imobilizado ou contra o qual tenha Vantagem: +1d6 por patamar. Primeiro Golpe:
-- "Dano Furtivo triplicado". Devolve quantos d6.
function U.dadosFurtivos(patamar: number, primeiroGolpe: boolean): number
	return patamar * (if primeiroGolpe then 3 else 1)
end

U.IMOBILIZADO = table.freeze({ agarrado = true, preso = true, paralisado = true, petrificado = true, inconsciente = true })

function U.furtivoValido(desprevenido: boolean, condicoesDoAlvo: { [string]: number }, comVantagem: boolean): boolean
	if desprevenido or comVantagem or condicoesDoAlvo.cego then
		return true
	end
	for id in condicoesDoAlvo do
		if U.IMOBILIZADO[id] then
			return true
		end
	end
	return false
end

-- Ordem de Tiro: +1d6 por patamar; apontar de novo o mesmo alvo não acertado
-- acumula outro 1d6, até o dobro do patamar.
function U.dadosApontado(patamar: number, acumulo: number): number
	return math.min(acumulo, 2 * patamar)
end

-- Se Esconder: Agilidade (Furtividade) contra 10 + Espírito de cada inimigo.
function U.cdParaEsconder(espiritoDoInimigo: number): number
	return 10 + espiritoDoInimigo
end

-- Refrão da Retomada: 1d6 + patamar em Bardo de PV temporários.
function U.pvDoRefrao(d6: number, patamar: number): number
	return d6 + patamar
end

-- Dissonância: até `patamar` criaturas hostis que ouvem sofrem 1d6 sônico por patamar.
function U.dissonancia(patamar: number): (number, string)
	return patamar, patamar .. "d6"
end

local function carta(id, m)
	m.pm, m.pt = m.pm or 0, m.pt or 0
	m.basico = true
	return id, table.freeze(m)
end

-- Cartas sem id próprio no catálogo (o id do livro fica em `livro`).
local C = {}
local function add(id, m) local k, v = carta(id, m); C[k] = v end
add("mesa/esconder", { tipo = "especial", especial = "esconder", nome = "Se Esconder (Ladino)", acoes = 1,
	descricao = "1 Ação, inclusive ao falhar: fora da visão ou na névoa, faça um teste de Furtividade (d20 + bônus da perícia). CD 10, ou 10 + Espírito do inimigo próximo que possa procurar você, se maior. Só o sucesso aplica Escondido: os outros não veem sua ficha. Visão: 90°, até 4 casas (6 m); paredes bloqueiam. Entrar na visão, atacar ou usar a voz revela você. Escondido dá Vantagem e habilita Dano Furtivo/Primeiro Golpe." })
add("mesa/insulto", { tipo = "especial", especial = "insulto", nome = "Insulto Afiado", acoes = 1, alcanceCasas = U.ALCANCE_VOZ,
	exigeTalento = "talent/" .. U.BARDO .. "/Principiante/insulto-afiado", arvore = U.BARDO,
	descricao = "1 Ação: Espírito contra a Intuição do alvo; se vencer, o próximo ataque dele tem Desvantagem." })
add("mesa/dissonancia", { tipo = "especial", especial = "cancao", cancao = "dissonancia", nome = "Canção: Dissonância", acoes = 1,
	exigeRank = U.BARDO, arvore = U.BARDO,
	descricao = "1 Ação: começa Dissonância e substitui sua canção anterior. No começo de cada vez sua, até 1 inimigo por patamar que te ouça a 12 casas sofre 1d6 sônico por patamar. Só uma canção ativa; combina com Inspiração, Insulto e Refrão. Não ocupa sustentação de magia." })
add("mesa/marcha", { tipo = "especial", especial = "cancao", cancao = "marcha", nome = "Canção: Marcha", acoes = 1,
	exigeTalento = "talent/" .. U.BARDO .. "/Principiante/cantiga-de-marcha", arvore = U.BARDO,
	descricao = "1 Ação: começa Marcha e substitui sua canção anterior. Você e aliados que te ouvem a 12 casas ganham +1 casa (1,5 m) de Deslocamento enquanto estiverem no alcance. Marchas não acumulam. Combina com Inspiração, Insulto e Refrão. Não ocupa sustentação de magia." })
add("mesa/parar-cancao", { tipo = "especial", especial = "pararCancao", nome = "Parar a canção", acoes = 0,
	exigeRank = U.BARDO, arvore = U.BARDO, descricao = "Sem Ação: para de tocar." })
add("mesa/apontar", { tipo = "especial", especial = "apontar", nome = "Ordem de Tiro", acoes = 0, alcanceCasas = 32, umaVezPorTurno = true,
	exigeRank = U.NAVEGACAO, arvore = U.NAVEGACAO,
	descricao = "Sem Ação, 1 vez por turno: o alvo fica Apontado. O primeiro acerto nele causa +1d6 por patamar." })
add("mesa/veneno-de-campo", { tipo = "efeito", nome = "Veneno de campo", acoes = 1, alcanceCasas = 1, naoAliados = true,
	exigeTalento = "talent/" .. U.FURTIVIDADE .. "/Principiante/boticario", arvore = U.FURTIVIDADE,
	resistencia = { atributo = "vigor", cdBase = 8, cdAtributo = "intelecto" }, aplica = "envenenado", duracao = { rodadas = 10 },
	descricao = "1 Ação, ao toque: Vigor (CD 8 + Intelecto + Rank) ou Envenenado por 1 minuto." })
U.CARTAS = table.freeze(C)
U.MECANICAS = U.CARTAS

-- Quais cartas "mesa/*" a ficha recebe na barra.
function U.cartasDe(ficha2): { string }
	local lista = {}
	if U.patamar(ficha2, U.FURTIVIDADE) > 0 then table.insert(lista, "mesa/esconder") end
	local c = ficha2 and ficha2.construction
	if not c then
		return lista
	end
	for id, m in U.CARTAS do
		if id ~= "mesa/esconder" then
			local ok = true
			if m.exigeRank and not Progressao.rankAberto(c, m.exigeRank, "Principiante") then ok = false end
			if m.exigeTalento and not comprou(c, m.exigeTalento) then ok = false end
			if ok then table.insert(lista, id) end
		end
	end
	table.sort(lista)
	return lista
end

return U
