
local V3 = {}; V3.__index = V3
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local C3 = { __eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end }
Color3 = { new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end }
Color3.fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end

local spec = (function()
-- SOMENTE STUDIO: controlador servidor isolado; relógio/RNG/execução injetados.
local S=(function()
-- A19: estado servidor de desenho, preparo e alimentação. Execução/dano/zona
-- são injetados pelo HabilidadeService; nenhum segundo motor de combate.
local F = (function()
-- Cap. 2 §6–8; porte de lib/magiaTeorica.ts (site somente leitura).
-- Escopo: uma essência, UM verbo e as três formas do Alfabeto Arcano.
-- Sem Instances/eventos; RNG e ficha são fornecidos pelo chamador.
local Progressao = (function()
-- Progressão nas árvores (puro; catálogo injetado). Porte de `canUnlockRank` e
-- `canPurchaseAbility` do site (src/store/selectors.ts), sobre a construção da
-- ficha v2 (construction.unlockedRankIds / purchasedIds).
--
-- Decisões do Pedro (09/10/2026), provisórias:
-- - PA INFINITO: o custo em PA não trava nada (no site ele também só informa).
-- - TETO no Intermediário: ranks acima ficam "em breve".
-- Livro: abrir um rank exige o rank anterior aberto na mesma árvore e N
-- conhecimentos (magias e talentos comprados) nela (RANK_REQUIREMENTS); comprar
-- exige o rank aberto, não ter a habilidade, os `requires` da mesma árvore e o
-- `requiresRank` (patamar mínimo numa árvore ou numa categoria).
-- Não portado (avisado no motivo): os Símbolos de origem natural da Teórica.
local Regras = (function()
-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Constantes de regra lidas do site (bônus de rank, Ações de magia, Ações por turno, moldes e arquétipos do Apêndice G) e vetores das funções do site para os testes diferenciais.
local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
return congelar({
	bonusDeRank = {
		Principiante = 1,
		["Intermediário"] = 2,
		["Avançado"] = 3,
		Santo = 4,
		Rei = 5,
		Imperador = 6,
		Deus = 7,
	},
	ordemDosRanks = {
		"Principiante",
		"Intermediário",
		"Avançado",
		"Santo",
		"Rei",
		"Imperador",
		"Deus",
	},
	requisitosDeRank = {
		Principiante = {
			knowledgeRequired = 0,
			paCost = 0,
		},
		["Intermediário"] = {
			knowledgeRequired = 3,
			paCost = 1,
		},
		["Avançado"] = {
			knowledgeRequired = 6,
			paCost = 2,
		},
		Santo = {
			knowledgeRequired = 9,
			paCost = 2,
		},
		Rei = {
			knowledgeRequired = 12,
			paCost = 3,
		},
		Imperador = {
			knowledgeRequired = 15,
			paCost = 3,
		},
		Deus = {
			knowledgeRequired = 18,
			paCost = 4,
		},
	},
	acoesDeMagia = {
		Principiante = {
			normal = 2,
			encurtada = 1,
			silenciosa = 1,
		},
		["Intermediário"] = {
			normal = 2,
			encurtada = 1,
			silenciosa = 1,
		},
		["Avançado"] = {
			normal = 3,
			encurtada = 2,
			silenciosa = 1,
		},
		Santo = {
			normal = 3,
			encurtada = 2,
			silenciosa = 2,
		},
		Rei = {
			normal = 4,
			encurtada = 3,
			silenciosa = 3,
		},
		Imperador = {
			normal = 4,
			silenciosa = 3,
		},
		Deus = {
			normal = 4,
			silenciosa = 3,
		},
	},
	acoesPorTurno = 3,
	escadaDeDados = {
		"d4",
		"d6",
		"d8",
		"d10",
		"d12",
		"2d8",
		"2d10",
		"2d12",
		"3d10",
		"3d12",
		"4d10",
		"4d12",
		"5d10",
		"5d12",
	},
	excessoPorDegrau = 2,
	moldesDeCriatura = {
		{
			patamar = 1,
			titulo = "Comum",
			pv = 64,
			ca = 12,
			bonusAtaque = 3,
			danoPorTurno = 16,
			cdResistencia = 11,
		},
		{
			patamar = 2,
			titulo = "Perigosa",
			pv = 68,
			ca = 14,
			bonusAtaque = 4,
			danoPorTurno = 21,
			cdResistencia = 13,
		},
		{
			patamar = 3,
			titulo = "Ameaça",
			pv = 121,
			ca = 16,
			bonusAtaque = 6,
			danoPorTurno = 29,
			cdResistencia = 15,
		},
		{
			patamar = 4,
			titulo = "Elite",
			pv = 152,
			ca = 18,
			bonusAtaque = 8,
			danoPorTurno = 38,
			cdResistencia = 17,
		},
		{
			patamar = 5,
			titulo = "Terror",
			pv = 210,
			ca = 20,
			bonusAtaque = 10,
			danoPorTurno = 48,
			cdResistencia = 19,
		},
		{
			patamar = 6,
			titulo = "Lenda",
			pv = 332,
			ca = 22,
			bonusAtaque = 12,
			danoPorTurno = 50,
			cdResistencia = 21,
		},
	},
	arquetiposDeCriatura = {
		{
			id = "bruto",
			principal = "Força",
			bom = "Vigor",
			comum = {
				"Agilidade",
			},
			fraco = {
				"Intelecto",
				"Espírito",
			},
			deslocamento = 6,
		},
		{
			id = "agil",
			principal = "Agilidade",
			bom = "Vigor",
			comum = {
				"Força",
			},
			fraco = {
				"Intelecto",
				"Espírito",
			},
			deslocamento = 12,
		},
		{
			id = "fortaleza",
			principal = "Vigor",
			bom = "Força",
			comum = {
				"Espírito",
			},
			fraco = {
				"Agilidade",
				"Intelecto",
			},
			deslocamento = 6,
		},
		{
			id = "conjurador",
			principal = "Intelecto",
			bom = "Espírito",
			comum = {
				"Agilidade",
				"Vigor",
			},
			fraco = {
				"Força",
			},
			deslocamento = 9,
		},
		{
			id = "mente",
			principal = "Espírito",
			bom = "Intelecto",
			comum = {
				"Agilidade",
				"Vigor",
			},
			fraco = {
				"Força",
			},
			deslocamento = 9,
		},
	},
	vetores = {
		aplicarPapel = {
			{
				patamar = 1,
				papel = "lacaio",
				saida = {
					pv = 32,
					danoPorTurno = 8,
				},
			},
			{
				patamar = 1,
				papel = "padrao",
				saida = {
					pv = 64,
					danoPorTurno = 16,
				},
			},
			{
				patamar = 1,
				papel = "chefe",
				saida = {
					pv = 160,
					danoPorTurno = 24,
				},
			},
			{
				patamar = 2,
				papel = "lacaio",
				saida = {
					pv = 34,
					danoPorTurno = 11,
				},
			},
			{
				patamar = 2,
				papel = "padrao",
				saida = {
					pv = 68,
					danoPorTurno = 21,
				},
			},
			{
				patamar = 2,
				papel = "chefe",
				saida = {
					pv = 170,
					danoPorTurno = 32,
				},
			},
			{
				patamar = 3,
				papel = "lacaio",
				saida = {
					pv = 61,
					danoPorTurno = 15,
				},
			},
			{
				patamar = 3,
				papel = "padrao",
				saida = {
					pv = 121,
					danoPorTurno = 29,
				},
			},
			{
				patamar = 3,
				papel = "chefe",
				saida = {
					pv = 303,
					danoPorTurno = 44,
				},
			},
			{
				patamar = 4,
				papel = "lacaio",
				saida = {
					pv = 76,
					danoPorTurno = 19,
				},
			},
			{
				patamar = 4,
				papel = "padrao",
				saida = {
					pv = 152,
					danoPorTurno = 38,
				},
			},
			{
				patamar = 4,
				papel = "chefe",
				saida = {
					pv = 380,
					danoPorTurno = 57,
				},
			},
			{
				patamar = 5,
				papel = "lacaio",
				saida = {
					pv = 105,
					danoPorTurno = 24,
				},
			},
			{
				patamar = 5,
				papel = "padrao",
				saida = {
					pv = 210,
					danoPorTurno = 48,
				},
			},
			{
				patamar = 5,
				papel = "chefe",
				saida = {
					pv = 525,
					danoPorTurno = 72,
				},
			},
			{
				patamar = 6,
				papel = "lacaio",
				saida = {
					pv = 166,
					danoPorTurno = 25,
				},
			},
			{
				patamar = 6,
				papel = "padrao",
				saida = {
					pv = 332,
					danoPorTurno = 50,
				},
			},
			{
				patamar = 6,
				papel = "chefe",
				saida = {
					pv = 830,
					danoPorTurno = 75,
				},
			},
		},
		atributosDaCriatura = {
			{
				patamar = 1,
				saida = {
					principal = 2,
					bom = 1,
					comum = 0,
					fraco = -1,
				},
			},
			{
				patamar = 2,
				saida = {
					principal = 2,
					bom = 1,
					comum = 0,
					fraco = -1,
				},
			},
			{
				patamar = 3,
				saida = {
					principal = 3,
					bom = 2,
					comum = 1,
					fraco = -1,
				},
			},
			{
				patamar = 4,
				saida = {
					principal = 4,
					bom = 2,
					comum = 1,
					fraco = -1,
				},
			},
			{
				patamar = 5,
				saida = {
					principal = 5,
					bom = 3,
					comum = 2,
					fraco = -1,
				},
			},
			{
				patamar = 6,
				saida = {
					principal = 6,
					bom = 3,
					comum = 2,
					fraco = -1,
				},
			},
		},
		bonusResistencia = {
			{
				patamar = 1,
				saida = 2,
			},
			{
				patamar = 2,
				saida = 2,
			},
			{
				patamar = 3,
				saida = 3,
			},
			{
				patamar = 4,
				saida = 4,
			},
			{
				patamar = 5,
				saida = 5,
			},
			{
				patamar = 6,
				saida = 6,
			},
		},
		escalarDado = {
			{
				dado = "d4",
				degraus = 0,
				saida = "d4",
			},
			{
				dado = "d4",
				degraus = 1,
				saida = "d6",
			},
			{
				dado = "d4",
				degraus = 2,
				saida = "d8",
			},
			{
				dado = "d4",
				degraus = 3,
				saida = "d10",
			},
			{
				dado = "d4",
				degraus = 5,
				saida = "2d8",
			},
			{
				dado = "d4",
				degraus = 9,
				saida = "3d12",
			},
			{
				dado = "d6",
				degraus = 0,
				saida = "d6",
			},
			{
				dado = "d6",
				degraus = 1,
				saida = "d8",
			},
			{
				dado = "d6",
				degraus = 2,
				saida = "d10",
			},
			{
				dado = "d6",
				degraus = 3,
				saida = "d12",
			},
			{
				dado = "d6",
				degraus = 5,
				saida = "2d10",
			},
			{
				dado = "d6",
				degraus = 9,
				saida = "4d10",
			},
			{
				dado = "d8",
				degraus = 0,
				saida = "d8",
			},
			{
				dado = "d8",
				degraus = 1,
				saida = "d10",
			},
			{
				dado = "d8",
				degraus = 2,
				saida = "d12",
			},
			{
				dado = "d8",
				degraus = 3,
				saida = "2d8",
			},
			{
				dado = "d8",
				degraus = 5,
				saida = "2d12",
			},
			{
				dado = "d8",
				degraus = 9,
				saida = "4d12",
			},
			{
				dado = "d10",
				degraus = 0,
				saida = "d10",
			},
			{
				dado = "d10",
				degraus = 1,
				saida = "d12",
			},
			{
				dado = "d10",
				degraus = 2,
				saida = "2d8",
			},
			{
				dado = "d10",
				degraus = 3,
				saida = "2d10",
			},
			{
				dado = "d10",
				degraus = 5,
				saida = "3d10",
			},
			{
				dado = "d10",
				degraus = 9,
				saida = "5d10",
			},
			{
				dado = "d12",
				degraus = 0,
				saida = "d12",
			},
			{
				dado = "d12",
				degraus = 1,
				saida = "2d8",
			},
			{
				dado = "d12",
				degraus = 2,
				saida = "2d10",
			},
			{
				dado = "d12",
				degraus = 3,
				saida = "2d12",
			},
			{
				dado = "d12",
				degraus = 5,
				saida = "3d12",
			},
			{
				dado = "d12",
				degraus = 9,
				saida = "5d12",
			},
			{
				dado = "2d8",
				degraus = 0,
				saida = "2d8",
			},
			{
				dado = "2d8",
				degraus = 1,
				saida = "2d10",
			},
			{
				dado = "2d8",
				degraus = 2,
				saida = "2d12",
			},
			{
				dado = "2d8",
				degraus = 3,
				saida = "3d10",
			},
			{
				dado = "2d8",
				degraus = 5,
				saida = "4d10",
			},
			{
				dado = "2d8",
				degraus = 9,
				saida = "5d12+2",
			},
			{
				dado = "2d10",
				degraus = 0,
				saida = "2d10",
			},
			{
				dado = "2d10",
				degraus = 1,
				saida = "2d12",
			},
			{
				dado = "2d10",
				degraus = 2,
				saida = "3d10",
			},
			{
				dado = "2d10",
				degraus = 3,
				saida = "3d12",
			},
			{
				dado = "2d10",
				degraus = 5,
				saida = "4d12",
			},
			{
				dado = "2d10",
				degraus = 9,
				saida = "5d12+4",
			},
			{
				dado = "2d12",
				degraus = 0,
				saida = "2d12",
			},
			{
				dado = "2d12",
				degraus = 1,
				saida = "3d10",
			},
			{
				dado = "2d12",
				degraus = 2,
				saida = "3d12",
			},
			{
				dado = "2d12",
				degraus = 3,
				saida = "4d10",
			},
			{
				dado = "2d12",
				degraus = 5,
				saida = "5d10",
			},
			{
				dado = "2d12",
				degraus = 9,
				saida = "5d12+6",
			},
			{
				dado = "3d10",
				degraus = 0,
				saida = "3d10",
			},
			{
				dado = "3d10",
				degraus = 1,
				saida = "3d12",
			},
			{
				dado = "3d10",
				degraus = 2,
				saida = "4d10",
			},
			{
				dado = "3d10",
				degraus = 3,
				saida = "4d12",
			},
			{
				dado = "3d10",
				degraus = 5,
				saida = "5d12",
			},
			{
				dado = "3d10",
				degraus = 9,
				saida = "5d12+8",
			},
			{
				dado = "3d12",
				degraus = 0,
				saida = "3d12",
			},
			{
				dado = "3d12",
				degraus = 1,
				saida = "4d10",
			},
			{
				dado = "3d12",
				degraus = 2,
				saida = "4d12",
			},
			{
				dado = "3d12",
				degraus = 3,
				saida = "5d10",
			},
			{
				dado = "3d12",
				degraus = 5,
				saida = "5d12+2",
			},
			{
				dado = "3d12",
				degraus = 9,
				saida = "5d12+10",
			},
			{
				dado = "4d10",
				degraus = 0,
				saida = "4d10",
			},
			{
				dado = "4d10",
				degraus = 1,
				saida = "4d12",
			},
			{
				dado = "4d10",
				degraus = 2,
				saida = "5d10",
			},
			{
				dado = "4d10",
				degraus = 3,
				saida = "5d12",
			},
			{
				dado = "4d10",
				degraus = 5,
				saida = "5d12+4",
			},
			{
				dado = "4d10",
				degraus = 9,
				saida = "5d12+12",
			},
			{
				dado = "4d12",
				degraus = 0,
				saida = "4d12",
			},
			{
				dado = "4d12",
				degraus = 1,
				saida = "5d10",
			},
			{
				dado = "4d12",
				degraus = 2,
				saida = "5d12",
			},
			{
				dado = "4d12",
				degraus = 3,
				saida = "5d12+2",
			},
			{
				dado = "4d12",
				degraus = 5,
				saida = "5d12+6",
			},
			{
				dado = "4d12",
				degraus = 9,
				saida = "5d12+14",
			},
			{
				dado = "5d10",
				degraus = 0,
				saida = "5d10",
			},
			{
				dado = "5d10",
				degraus = 1,
				saida = "5d12",
			},
			{
				dado = "5d10",
				degraus = 2,
				saida = "5d12+2",
			},
			{
				dado = "5d10",
				degraus = 3,
				saida = "5d12+4",
			},
			{
				dado = "5d10",
				degraus = 5,
				saida = "5d12+8",
			},
			{
				dado = "5d10",
				degraus = 9,
				saida = "5d12+16",
			},
			{
				dado = "5d12",
				degraus = 0,
				saida = "5d12",
			},
			{
				dado = "5d12",
				degraus = 1,
				saida = "5d12+2",
			},
			{
				dado = "5d12",
				degraus = 2,
				saida = "5d12+4",
			},
			{
				dado = "5d12",
				degraus = 3,
				saida = "5d12+6",
			},
			{
				dado = "5d12",
				degraus = 5,
				saida = "5d12+10",
			},
			{
				dado = "5d12",
				degraus = 9,
				saida = "5d12+18",
			},
		},
	},
})

end)()

local Progressao = {}

Progressao.PA_INFINITO = true
Progressao.TETO = "Intermediário"

local function indiceDoRank(rank: string): number?
	return table.find(Regras.ordemDosRanks, rank)
end

-- Segmento de ID com percent-encoding (CONTRATOS §2.1): "Intermediário" →
-- "Intermedi%C3%A1rio", como o gerador e o exportador do site.
function Progressao.segmento(texto: string): string
	return (string.gsub(texto, "[^%w%-%._~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

function Progressao.idDoRank(arvore: string, rank: string): string
	return "rank/" .. Progressao.segmento(arvore) .. "/" .. Progressao.segmento(rank)
end

function Progressao.rankAberto(construcao, arvore: string, rank: string): boolean
	return table.find(construcao.unlockedRankIds, Progressao.idDoRank(arvore, rank)) ~= nil
end

-- Maior rank aberto numa árvore (nome) ou nil.
function Progressao.maiorRank(construcao, arvore: string): string?
	local maior, indice = nil, 0
	for i, rank in Regras.ordemDosRanks do
		if Progressao.rankAberto(construcao, arvore, rank) and i > indice then
			maior, indice = rank, i
		end
	end
	return maior
end

-- Conhecimentos numa árvore: habilidades e talentos comprados nela.
function Progressao.conhecimentos(construcao, arvore: string): number
	local prefixoA = "ability/" .. Progressao.segmento(arvore) .. "/"
	local prefixoT = "talent/" .. Progressao.segmento(arvore) .. "/"
	local n = 0
	for _, id in construcao.purchasedIds do
		if string.sub(id, 1, #prefixoA) == prefixoA or string.sub(id, 1, #prefixoT) == prefixoT then
			n += 1
		end
	end
	return n
end

-- Carta de 0 PA (o truque da escola) não se compra: quem abriu o patamar a tem
-- (Cap. 2, §1; combatSim "gratuitas").
function Progressao.gratuita(entrada): boolean
	return entrada.kind == "ability" and entrada.data.paCost == 0
end

-- Habilidades e talentos que a construção conhece: as compras e as cartas
-- gratuitas dos ranks abertos.
function Progressao.conhecidas(construcao, catalogo): { string }
	local lista = table.clone(construcao.purchasedIds)
	for _, rankId in construcao.unlockedRankIds do
		local rank = catalogo.POR_ID[rankId]
		for _, id in (rank and rank.data.abilities) or {} do
			local entrada = catalogo.POR_ID[id]
			if entrada and Progressao.gratuita(entrada) and not table.find(lista, id) then
				table.insert(lista, id)
			end
		end
	end
	return lista
end

function Progressao.acimaDoTeto(rank: string): boolean
	local i, teto = indiceDoRank(rank), indiceDoRank(Progressao.TETO)
	return i == nil or teto == nil or i > teto
end

-- Pode abrir o rank? (ok, motivo)
function Progressao.podeAbrir(construcao, catalogo, arvore: string, rank: string): (boolean, string?)
	if not catalogo.POR_ID["tree/" .. Progressao.segmento(arvore)] then
		return false, "Árvore desconhecida."
	end
	local indice = indiceDoRank(rank)
	if not indice or not catalogo.POR_ID[Progressao.idDoRank(arvore, rank)] then
		return false, "Rank desconhecido nesta árvore."
	end
	if Progressao.acimaDoTeto(rank) then
		return false, "Por enquanto o jogo vai até o " .. Progressao.TETO .. "."
	end
	if Progressao.rankAberto(construcao, arvore, rank) then
		return false, "Rank já desbloqueado."
	end
	if indice > 1 then
		local anterior = Regras.ordemDosRanks[indice - 1]
		if not Progressao.rankAberto(construcao, arvore, anterior) then
			return false, "Desbloqueie " .. anterior .. " antes."
		end
	end
	local exigidos = Regras.requisitosDeRank[rank].knowledgeRequired
	local tem = Progressao.conhecimentos(construcao, arvore)
	if tem < exigidos then
		return false, string.format("Precisa de %d conhecimento(s) nesta árvore (tem %d).", exigidos, tem)
	end
	return true, nil
end

-- Pode comprar a habilidade ou talento? (ok, motivo)
function Progressao.podeComprar(construcao, catalogo, id: string): (boolean, string?)
	local entrada = catalogo.POR_ID[id]
	if not entrada or (entrada.kind ~= "ability" and entrada.kind ~= "talent") then
		return false, "Habilidade desconhecida."
	end
	local dados = entrada.data
	local arvore, rank = dados.treeId, dados.rank
	if Progressao.acimaDoTeto(rank) then
		return false, "Por enquanto o jogo vai até o " .. Progressao.TETO .. "."
	end
	if not Progressao.rankAberto(construcao, arvore, rank) then
		return false, "Rank ainda não desbloqueado nesta árvore."
	end
	if table.find(construcao.purchasedIds, id) then
		return false, "Já adquirido."
	end
	if Progressao.gratuita(entrada) then
		return false, "Vem com o rank: não se compra."
	end
	if arvore == "teorica" and dados.requires and #dados.requires > 0 then
		-- Símbolos de origem natural (selectors.ts `origemNaturalDoSimbolo`) não portados.
		return false, "Pré-requisitos de Símbolo da Teórica ainda não suportados no jogo."
	end
	for _, requerido in dados.requires or {} do
		local tem = false
		for _, comprado in construcao.purchasedIds do
			local outra = catalogo.POR_ID[comprado]
			if outra and outra.data.treeId == arvore and outra.sourceId == requerido then
				tem = true
				break
			end
		end
		if not tem then
			local nome = requerido
			for _, candidato in catalogo.POR_ESPECIE.ability or {} do
				if candidato.data.treeId == arvore and candidato.sourceId == requerido then
					nome = candidato.data.name
				end
			end
			return false, string.format('Exige "%s" nesta árvore antes.', nome)
		end
	end
	local exigencia = dados.requiresRank
	if exigencia then
		local minimo = indiceDoRank(exigencia.rank) or 1
		local atende = false
		for _, rankId in construcao.unlockedRankIds do
			local r = catalogo.POR_ID[rankId]
			if r then
				local outraArvore = r.data.treeId
				local i = indiceDoRank(r.data.rank) or 0
				if i >= minimo then
					if exigencia.treeId and outraArvore == exigencia.treeId then
						atende = true
					elseif exigencia.categoria then
						local arv = catalogo.POR_ID["tree/" .. Progressao.segmento(outraArvore)]
						if arv and arv.data.category == exigencia.categoria then
							atende = true
						end
					end
				end
			end
		end
		if not atende then
			local onde = exigencia.treeId or ("alguma árvore de " .. tostring(exigencia.categoria))
			local arv = exigencia.treeId and catalogo.POR_ID["tree/" .. Progressao.segmento(exigencia.treeId)]
			if arv then
				onde = arv.data.name
			end
			return false, string.format("Exige o patamar %s em %s.", exigencia.rank, onde)
		end
	end
	return true, nil
end

return Progressao

end)()
local F = {}
F.RANKS = table.freeze({ "Principiante", "Intermediário", "Avançado", "Santo", "Rei", "Imperador" })
F.POTENCIA = table.freeze({
	Principiante = { pm = 1, dados = 1, pv = 20, alcance = 9, tamanho = 3, acoes = 2 },
	["Intermediário"] = { pm = 2, dados = 2, pv = 40, alcance = 18, tamanho = 6, acoes = 2 },
	["Avançado"] = { pm = 5, dados = 5, pv = 60, alcance = 27, tamanho = 9, acoes = 3 },
	Santo = { pm = 6, dados = 6, pv = 80, alcance = 45, tamanho = 12, acoes = 3 },
	Rei = { pm = 10, dados = 10, pv = 100, alcance = 90, tamanho = 18, acoes = 4 },
	Imperador = { pm = 12, dados = 12, pv = 120, alcance = 150, tamanho = 30, acoes = 4 },
})
F.ESSENCIAS = table.freeze({
	mana = { nome = "Mana", glifo = "◇", tipo = "arcano" },
	fogo = { nome = "Fogo", glifo = "△", tipo = "ígneo", arvore = "fogo" },
	agua = { nome = "Água", glifo = "≋", tipo = "contundente", arvore = "agua" },
	vento = { nome = "Vento", glifo = "⌁", tipo = "cortante", arvore = "vento" },
	terra = { nome = "Terra", glifo = "▱", tipo = "contundente", arvore = "terra" },
	som = { nome = "Som", glifo = "♫", tipo = "sônico", arvore = "bardo" },
	vida = { nome = "Vida", glifo = "✧", tipo = "cura", arvore = "cura" },
})
F.VERBOS = table.freeze({ lancar = "Lançar", erguer = "Erguer", selar = "Selar", sinalizar = "Sinalizar" })
F.FORMAS = table.freeze({ circulo = "Círculo", linha = "Linha", quadrado = "Quadrado" })
local function inteiro(n) return type(n) == "number" and n == n and math.abs(n) < math.huge and n % 1 == 0 end
function F.rank(ficha)
	return ficha and ficha.construction and Progressao.maiorRank(ficha.construction, "teorica") or nil
end
function F.talento(ficha, id)
	return ficha ~= nil and ficha.construction ~= nil and table.find(ficha.construction.purchasedIds or {}, "talent/teorica/Principiante/" .. id) ~= nil
end
function F.conheceEssencia(ficha, id)
	local e = F.ESSENCIAS[id]
	if not e or not F.rank(ficha) then return false end
	return id == "mana" or F.talento(ficha, "simbolo-" .. id)
		or Progressao.rankAberto(ficha.construction, e.arvore, "Principiante")
end
local CONTATO = {
	fogo = "Quem encosta sofre %dd6 ígneo, Agilidade CD 8 + BC para metade, uma vez por rodada; arma não transmite calor.",
	agua = "Quem encosta testa Agilidade CD 8 + BC ou fica Molhado até o fim da próxima vez.",
	vento = "Quem encosta testa Força CD 8 + BC ou é empurrado 1,5 m para fora, uma vez por rodada.",
	terra = "Terra soma +50% dos PV base (soma com Quadrado).",
	som = "Encostar produz som audível a 18 m.",
	vida = "Ao erguer, um aliado ao toque recebe %d PV temporários por até 10 turnos.",
}
-- Resultado canônico independente dos recursos atuais. Nunca usa qualidade.
function F.validar(ficha, pedido, meio)
	if type(pedido) ~= "table" then return nil, "Fórmula deve ser uma tabela." end
	local rank = F.rank(ficha)
	if not rank then return nil, "Exige Alfabeto Arcano (Magia Teórica)." end
	if type(pedido.essencia) ~= "string" or not F.ESSENCIAS[pedido.essencia] then return nil, "Essência desconhecida." end
	if type(pedido.verbo) ~= "string" or not F.VERBOS[pedido.verbo] then return nil, "Escolha um dos quatro verbos do Alfabeto Arcano." end
	if type(pedido.forma) ~= "string" or not F.FORMAS[pedido.forma] then return nil, "Só Círculo, Linha e Quadrado são desenháveis nesta etapa." end
	if type(pedido.potencia) ~= "string" or not F.POTENCIA[pedido.potencia] then return nil, "Potência desconhecida." end
	if (table.find(F.RANKS, pedido.potencia) or 99) > (table.find(F.RANKS, rank) or 0) then return nil, "Potência excede o rank na Teórica." end
	if not F.conheceEssencia(ficha, pedido.essencia) then return nil, "Essência exige o talento ou o Principiante da escola de origem." end
	meio = meio or "ar"
	if meio ~= "ar" and meio ~= "giz" and meio ~= "bolso" then return nil, "Meio não implementado; pedra e fórmulas armadas ficam fora deste escopo." end
	if meio ~= "ar" and pedido.verbo == "lancar" then return nil, "Lançar sozinho não pode ser preparado, inclusive Vida." end
	if meio == "bolso" and not F.talento(ficha, "simbolo-rejeitar") then return nil, "Exige Fórmula de Bolso." end
	local p, e = F.POTENCIA[pedido.potencia], F.ESSENCIAS[pedido.essencia]
	local r = { essencia = pedido.essencia, verbo = pedido.verbo, forma = pedido.forma, potencia = pedido.potencia, meio = meio,
		pm = p.pm + (if pedido.essencia == "mana" then 0 else 1) + (if pedido.forma == "circulo" then 0 else 1),
		acoes = if meio == "ar" then p.acoes else 1, preparoSegundos = if meio == "ar" then 0 else 60,
		alcanceMetros = if pedido.verbo == "lancar" then math.floor(p.alcance * (if pedido.forma == "linha" then 1.5 else 1) / 1.5) * 1.5 else 1.5,
		tamanhoMetros = math.floor(p.tamanho * (if pedido.forma == "linha" then 1.5 else 1) / 1.5) * 1.5,
		duracaoRodadas = if pedido.verbo == "lancar" then 0 elseif pedido.verbo == "sinalizar" then 1 elseif meio == "ar" then 10 else 100,
		dados = p.dados, tipoDano = e.tipo, fere = pedido.verbo == "lancar" and pedido.essencia ~= "vida",
		cura = pedido.verbo == "lancar" and pedido.essencia == "vida", sustenta = pedido.verbo == "erguer" or pedido.verbo == "selar",
		leitura = e.nome .. " + " .. F.VERBOS[pedido.verbo] .. " + " .. F.FORMAS[pedido.forma],
	}
	if meio == "ar" then r.tamanhoMetros = math.min(r.tamanhoMetros, 12) end
	if pedido.verbo == "erguer" then
		r.pv = math.ceil(p.pv * (1 + (if pedido.forma == "quadrado" then 0.5 else 0) + (if pedido.essencia == "terra" then 0.5 else 0)))
		r.contato = CONTATO[pedido.essencia]
		if pedido.essencia == "fogo" then r.contatoDados = math.ceil(p.dados / 2); r.contato = string.format(r.contato, r.contatoDados) end
		if pedido.essencia == "vida" then r.pvTemp = p.dados * 5; r.contato = string.format(r.contato, r.pvTemp) end
		r.descricao = string.format("Parede: %d PV, até %g m. Segura corpos e projéteis; magia atravessa. %s", r.pv, r.tamanhoMetros, r.contato or "")
	elseif pedido.verbo == "selar" then
		r.tetoSelo = (table.find(F.RANKS, pedido.potencia) or 0) + (if pedido.essencia == "mana" then 0 else 1)
		r.descricao = "Fronteira sem PV. Magia até a potência" .. (if pedido.essencia == "mana" then "" else " +1 rank, só de " .. e.nome)
			.. ": bloqueada; 1 rank acima: dados, área e duração pela metade; 2+ acima: atravessa. Corpos, armas e Touki atravessam."
	elseif pedido.verbo == "sinalizar" then
		r.descricao = "Sinal de luz, som ou cheiro no desenho por 1 turno. Sem dano, cura ou condição."
	else
		r.descricao = string.format("%s %dd8%s; um alvo a até %g m.%s", if r.cura then "Cura" else "Ataque mágico:", p.dados,
			if r.cura then " PV, sem BC, alvo voluntário" else " + BC contra CA", r.alcanceMetros, if pedido.forma == "quadrado" then " Quadrado não altera Lançar." else "")
	end
	return r, nil
end
-- A escola vem da origem da MAGIA, não do tipo de dano (Pedrisco é Terra).
function F.fatorSelo(formula, rankMagia, escola, magica)
	if not magica or formula.verbo ~= "selar" then return 1 end
	local origem = F.ESSENCIAS[formula.essencia].arvore
	if origem and escola ~= origem then return 1 end
	local indice = table.find(F.RANKS, rankMagia)
	if rankMagia == "Deus" then indice = 7 end
	if not indice then return nil, "Rank da magia desconhecido; não presumir bloqueio." end
	local delta = indice - formula.tetoSelo
	return if delta <= 0 then 0 elseif delta == 1 then 0.5 else 1
end
function F.concentracao(random, espirito, maiorBonus, bonusAtacante, desvantagem)
	local a = random:NextInteger(1, 20)
	local b = if desvantagem then random:NextInteger(1, 20) else a
	local dado = math.min(a, b)
	local cd = if bonusAtacante then 10 + bonusAtacante else 12
	local total = dado + espirito + math.ceil(maiorBonus / 2)
	return { passou = total >= cd, dado = dado, total = total, cd = cd }
end
function F.reembolsoInterrupcao(pm) return pm - math.floor(pm / 2) end

-- Contrato do executor existente. O servidor decide Ações/PM (o chamador
-- pode reservar o custo primeiro para conjuração dividida entre turnos).
function F.mecanica(r)
	local m = { arvore = "teorica", estilo = "teorica", formula = r, nome = r.leitura,
		acoes = r.acoes, pm = r.pm, pt = 0, alcanceCasas = r.alcanceMetros / 1.5,
		duracaoRodadas = r.duracaoRodadas, descricao = r.descricao }
	if r.verbo == "lancar" then
		m.tipo = if r.cura then "cura" else "ataque"
		m.partes = {{ dados = r.dados .. "d8", bc = not r.cura, tipo = if r.cura then nil else r.tipoDano }}
		m.soAliados, m.permiteSi = r.cura, r.cura
	elseif r.verbo == "erguer" or r.verbo == "selar" then
		m.tipo, m.forma, m.comprimentoCasas = "zona", "linhaTransversal", r.tamanhoMetros / 1.5
		m.pvZona = r.pv
		m.bloqueiaMovimento = r.verbo == "erguer"
		-- Erguer deixa magia passar, inclusive a visão necessária à mira.
		m.bloqueiaProjeteis = r.verbo == "erguer"
	else m.tipo, m.alvoCasa, m.registro = "utilidade", true, r.descricao end
	return m
end

-- Régua: metade DOS DADOS, não do dano com BC. Área e duração se ajustam
-- antes de escolher alvos; a parcela fixa e a CD não são cortadas.
function F.reduzirMecanica(mec, fator)
	local m = table.clone(mec)
	if fator ~= 0.5 then return m end
	local function reduzirPartes(partes)
		local out = {}
		for _,parte in partes or {} do
			local p = table.clone(parte)
			if p.dados then
				local dados = {}
				for n,d in string.gmatch(p.dados, "(%d*)d(%d+)") do
					local qtd = math.floor((tonumber(n) or 1) / 2)
					if qtd > 0 then table.insert(dados,qtd .. "d" .. d) end
				end
				p.dados = if #dados > 0 then table.concat(dados,"+") else nil
			end
			table.insert(out,p)
		end
		return out
	end
	if m.partes then m.partes = reduzirPartes(m.partes) end
	if m.dados then
		local dados = {}
		for _,formula in m.dados do
			local reduzida = reduzirPartes({{dados=formula}})[1].dados
			if reduzida then table.insert(dados,reduzida) end
		end
		m.dados = dados
	end
	if m.segundoDisparo then m.segundoDisparo = reduzirPartes(m.segundoDisparo) end
	for _,campo in {"raioCasas","comprimentoCasas","duracaoRodadas"} do if m[campo] then m[campo] /= 2 end end
	if m.duracao and m.duracao.rodadas then m.duracao=table.clone(m.duracao); m.duracao.rodadas/=2 end
	return m
end

-- Reconhecimento cosmético, sem efeito em PM/ataque/concentração. Coordenadas
-- são pares {x,y}; o servidor recebe somente a forma canônica e a revalida.
local function distancia(a,b) return math.sqrt((a[1]-b[1])^2 + (a[2]-b[2])^2) end
local function distLinha(p,a,b)
	local dx,dy = b[1]-a[1],b[2]-a[2]
	local d = dx*dx+dy*dy
	if d == 0 then return distancia(p,a) end
	local u = math.clamp(((p[1]-a[1])*dx+(p[2]-a[2])*dy)/d,0,1)
	return distancia(p,{a[1]+u*dx,a[2]+u*dy})
end
local function simplificar(pontos, primeiro, ultimo, tolerancia, saida)
	local maior, indice = 0, primeiro
	for i=primeiro+1,ultimo-1 do
		local d = distLinha(pontos[i],pontos[primeiro],pontos[ultimo])
		if d > maior then maior,indice=d,i end
	end
	if maior > tolerancia then
		simplificar(pontos,primeiro,indice,tolerancia,saida); simplificar(pontos,indice,ultimo,tolerancia,saida)
	else table.insert(saida,pontos[primeiro]) end
end
function F.reconhecer(pontos)
	if type(pontos) ~= "table" or #pontos < 6 or #pontos > 512 then return nil, 0 end
	local minX,minY,maxX,maxY,comprimento = math.huge,math.huge,-math.huge,-math.huge,0
	for i,p in pontos do
		if type(p) ~= "table" or not inteiro(i) or type(p[1]) ~= "number" or type(p[2]) ~= "number"
			or p[1] ~= p[1] or p[2] ~= p[2] or math.abs(p[1]) > 10000 or math.abs(p[2]) > 10000 then return nil,0 end
		minX,minY,maxX,maxY=math.min(minX,p[1]),math.min(minY,p[2]),math.max(maxX,p[1]),math.max(maxY,p[2])
		if i>1 then comprimento+=distancia(p,pontos[i-1]) end
	end
	local span=math.max(maxX-minX,maxY-minY)
	if span < 24 or comprimento > span*6 then return nil,0 end
	local ponta=distancia(pontos[1],pontos[#pontos])
	if ponta/span > 0.7 and comprimento/ponta < 1.12 then
		local erro=0
		for _,p in pontos do erro=math.max(erro,distLinha(p,pontos[1],pontos[#pontos])/span) end
		if erro<0.06 then return "linha",math.clamp(1-erro*5,0,1) end
	end
	if ponta/span>0.22 or comprimento<span*2.5 then return nil,0 end
	local fechado=table.clone(pontos); table.insert(fechado,pontos[1])
	local vertices={}; simplificar(fechado,1,#fechado,span*0.06,vertices)
	-- Se o gesto começa no meio de um lado, elimina esse vértice colinear.
	local mudou=true
	while mudou and #vertices>3 do
		mudou=false
		for i,p in vertices do
			local anterior=vertices[(i-2)%#vertices+1]; local proximo=vertices[i%#vertices+1]
			if distLinha(p,anterior,proximo)<span*0.06 then table.remove(vertices,i); mudou=true; break end
		end
	end
	if #vertices==4 then
		local menor,maior,ortogonal=math.huge,0,true
		for i,p in vertices do
			local a,b=vertices[(i-2)%4+1],vertices[i%4+1]
			local la,lb=distancia(p,a),distancia(p,b)
			menor,maior=math.min(menor,lb),math.max(maior,lb)
			if la*lb==0 or math.abs(((a[1]-p[1])*(b[1]-p[1])+(a[2]-p[2])*(b[2]-p[2]))/(la*lb))>0.35 then ortogonal=false end
		end
		if ortogonal and menor/maior>0.7 then return "quadrado",menor/maior end
	end
	local cx,cy=(minX+maxX)/2,(minY+maxY)/2
	local raio,soma,erro=span/2,0,0
	for _,p in pontos do soma+=distancia(p,{cx,cy}) end
	local media=soma/#pontos
	for _,p in pontos do erro+=(distancia(p,{cx,cy})-media)^2 end
	erro=math.sqrt(erro/#pontos)/raio
	if math.min(maxX-minX,maxY-minY)/span>0.72 and erro<0.13 then return "circulo",math.clamp(1-erro*4,0,1) end
	return nil,0
end
return F

end)()
local Protocol = (function()
-- Contrato da mesa virtual: nomes, limites e geometria do tabuleiro.
-- Puro: não cria Instances nem envia eventos. Documentação em docs/MESA.md.
local Protocol = {}

Protocol.REMOTE = "Mesa"

-- origin é o centro da superfície superior do tabuleiro.
Protocol.BOARD = table.freeze({
	width = 20,
	height = 20,
	cell = 5,
	origin = Vector3.new(0, 1, 0),
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

end)()
local S = {}
function S.novo(ctx)
	local api = {}
	local desenhos, preparadas, executando, tracoUsado = {}, {}, {}, {}
	local serial = 0
	local agora = ctx.agora or os.clock
	local function ficha(player,payload,master,vez)
		if type(payload) ~= "table" or type(payload.tokenId) ~= "string" or #payload.tokenId > 160 then return nil,"Pedido inválido." end
		local token = ctx.tokens[payload.tokenId]
		if not token or not ctx.canSee(player,token) then return nil,"Ficha não encontrada." end
		if not master and token.ownerUserId ~= player.UserId then return nil,"Você só age com sua ficha." end
		if token.pv <= 0 or token.derrotado or ctx.semAcoes(token) then return nil,"Não pode desenhar ou alimentar neste estado." end
		if ctx.reacoes.pendente() or executando[token.id] then return nil,"Aguarde a execução/Reação em andamento." end
		if vez and (not ctx.combat.active or ctx.currentTurnId() ~= token.id) then return nil,"Aguarde a vez da ficha em combate." end
		return token,nil
	end
	local function intencao(payload)
		if payload.alvoId ~= nil and (type(payload.alvoId) ~= "string" or #payload.alvoId > 160) then return nil,"Alvo inválido." end
		if (payload.x ~= nil or payload.z ~= nil) and not Protocol.isCell(payload.x,payload.z) then return nil,"Casa inválida." end
		if payload.qualidade ~= nil and (type(payload.qualidade) ~= "number" or payload.qualidade ~= payload.qualidade or payload.qualidade < 0 or payload.qualidade > 1) then return nil,"Qualidade cosmética inválida." end
		return { tokenId=payload.tokenId,essencia=payload.essencia,verbo=payload.verbo,forma=payload.forma,potencia=payload.potencia,
			alvoId=payload.alvoId,x=payload.x,z=payload.z },nil
	end
	local function interromper(token,motivo)
		local d = desenhos[token.id]
		if not d then return end
		desenhos[token.id] = nil
		if ctx.tokens[token.id] == token then token.mana=math.min(token.manaMax,token.mana+F.reembolsoInterrupcao(d.r.pm)); token.version+=1 end
		ctx.logAboutToken(token,token.name.." interrompe "..d.r.leitura..": "..motivo..". Perde as Ações gastas e "..math.floor(d.r.pm/2).." PM.")
	end
	local function conferir(d)
		local token=d.token
		if ctx.tokens[token.id]~=token or token.pv<=0 or token.derrotado or ctx.semAcoes(token) then return "Incapacitado/caído ou ficha removida." end
		local c=ctx.condicoesDe(token)
		if c.surdo or c.soterrado or ctx.silenciado(token) then return "Perdeu voz/postura da conjuração." end
		return ctx.validarAlvo(d.player,token,d.mec,d.pedido)
	end
	local function executar(player,token,r,pedido,bc)
		local mec=F.mecanica(r); mec.pm,mec.acoes=0,0 -- custo já reservado
		mec.bcFormula=bc
		executando[token.id]=true
		local ok,erro=pcall(ctx.executar,player,token,mec,pedido,bc)
		executando[token.id]=nil
		if not ok then error(erro,0) end
		return erro
	end
	local function dedicar(d)
		local erro=conferir(d)
		if erro then interromper(d.token,erro); return erro end
		local turno=ctx.turno(d.token.id)
		local n=math.min(d.r.acoes-d.gastas,math.max(0,ctx.limiteDeAcoes(d.token)-turno.usadas))
		if n<=0 then return "Sem Ações para continuar desenhando." end
		if d.r.fere and turno.usos["formula-feriu"] then return "Só uma fórmula desenhada que fere por turno." end
		turno.usadas+=n; d.gastas+=n; d.ultimaDedicacao=ctx.combat.turn; d.token.version+=1
		ctx.logAboutToken(d.token,string.format("%s desenha %s · %d/%d Ações",d.token.name,d.r.leitura,d.gastas,d.r.acoes))
		if d.gastas<d.r.acoes then return nil end
		if d.r.fere then turno.usos["formula-feriu"]=true end
		desenhos[d.token.id]=nil
		return executar(d.player,d.token,d.r,d.pedido,d.bc)
	end
	ctx.handlers.desenharFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,true); if not token then return err end
		if desenhos[token.id] then return "Já desenha uma fórmula; continue ou cancele." end
		local pedido; pedido,err=intencao(payload); if not pedido then return err end
		local r; r,err=F.validar(token.ficha2,pedido); if not r then return err end
		local mec=F.mecanica(r)
		err=ctx.validarAlvo(player,token,mec,pedido); if err then return err end
		if ctx.silenciado(token) or ctx.condicoesDe(token).surdo then return "Sem voz para Conjurar; desenho não se silencia." end
		local turno=ctx.turno(token.id)
		if turno.usadas>=ctx.limiteDeAcoes(token) then return "Sem Ação para começar o desenho." end
		if r.fere and turno.usos["formula-feriu"] then return "Só uma fórmula desenhada que fere por turno." end
		if token.mana<r.pm then return "PM insuficiente." end
		token.mana-=r.pm; token.version+=1
		local d={token=token,player=player,r=r,mec=mec,pedido=pedido,bc=ctx.bc(token),gastas=0,inicioVez=ctx.combat.turn,reacaoDisponivel=ctx.reacoes.temReacao(token)}
		desenhos[token.id]=d
		return dedicar(d)
	end
	ctx.handlers.continuarFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,true); if not token then return err end
		local d=desenhos[token.id]; if not d then return "Não há fórmula em desenho." end
		return dedicar(d)
	end
	ctx.handlers.cancelarFormula=function(player,payload,master)
		-- Cancelar é livre, inclusive fora da vez e quando incapaz de agir.
		if type(payload)~="table" or type(payload.tokenId)~="string" then return "Pedido inválido." end
		local token=ctx.tokens[payload.tokenId]
		if not token or not ctx.canSee(player,token) or not master and token.ownerUserId~=player.UserId then return "Ficha não encontrada/não controlada." end
		if executando[token.id] then return "A execução já começou." end
		if not desenhos[token.id] then return "Não há fórmula em desenho." end
		interromper(token,"cancelou voluntariamente"); return nil
	end
	ctx.handlers.prepararFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,false); if not token then return err end
		if ctx.combat.active then return "Prepare fora de combate, durante 1 minuto." end
		local pedido; pedido,err=intencao(payload); if not pedido then return err end
		local meio=payload.meio
		if meio~="giz" and meio~="bolso" then return "Escolha giz ou Fórmula de Bolso." end
		local r; r,err=F.validar(token.ficha2,pedido,meio); if not r then return err end
		serial+=1
		preparadas[token.id]={id="f"..serial,token=token,r=r,bc=ctx.bc(token),prontaEm=agora()+60}
		ctx.logAboutToken(token,token.name.." prepara "..r.leitura.."; requer 60 segundos. PM será pago por quem alimentar.")
		token.version+=1; return nil
	end
	local function perto(token,p,player)
		local origem=p.token
		return ctx.tokens[origem.id]==origem and ctx.canSee(player,origem)
			and math.max(math.abs(token.x-origem.x),math.abs(token.z-origem.z))<=1
	end
	ctx.handlers.ativarFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,true); if not token then return err end
		if desenhos[token.id] then return "Não pode usar pergaminho enquanto Conjura." end
		local pedido; pedido,err=intencao(payload); if not pedido then return err end
		if payload.preparadaId~=nil and (type(payload.preparadaId)~="string" or #payload.preparadaId>40) then return "Preparo inválido." end
		local p=preparadas[token.id]
		if payload.preparadaId then
			p=nil; for _,c in preparadas do if c.id==payload.preparadaId then p=c; break end end
		elseif not p then
			for _,id in ctx.tokenOrder do local c=preparadas[id]; if c and perto(token,c,player) then p=c; break end end
		end
		if not p or not perto(token,p,player) then return "Escolha uma fórmula preparada visível ao toque." end
		if agora()<p.prontaEm then return "O preparo ainda não completou 1 minuto." end
		local mec=F.mecanica(p.r)
		err=ctx.validarAlvo(player,token,mec,pedido); if err then return err end
		local turno=ctx.turno(token.id)
		if turno.usadas>=ctx.limiteDeAcoes(token) then return "Sem Ação para ativar." end
		if token.mana<p.r.pm then return "PM insuficiente para alimentar a fórmula." end
		preparadas[p.token.id]=nil
		token.mana-=p.r.pm; turno.usadas+=1; token.version+=1
		return executar(player,token,p.r,pedido,p.bc)
	end
	function api.ocupado(token) return desenhos[token.id]~=nil or executando[token.id]==true end
	function api.desenhando(token) return desenhos[token.id]~=nil end
	function api.aoSofrerDano(token,atacante,mec,dano)
		local d=desenhos[token.id]; if not d or dano<=0 then return end
		if token.pv<=0 or ctx.semAcoes(token) then interromper(token,"caiu/incapacitado"); return end
		local f=token.ficha2
		local bonus=if atacante then ctx.patamar(atacante) else nil
		local r=F.concentracao(ctx.random,f.calculated.attributes.espirito or 0,f.calculated.highestRankBonus or 0,bonus,mec and mec.corteBraco)
		ctx.logAboutToken(token,string.format("Concentração: d20 %d, total %d contra CD %d: %s",r.dado,r.total,r.cd,if r.passou then "mantém" else "falha"))
		if not r.passou and F.talento(f,"traco-firme") and not tracoUsado[token.id] then
			tracoUsado[token.id]=true
			r=F.concentracao(ctx.random,f.calculated.attributes.espirito or 0,f.calculated.highestRankBonus or 0,bonus,mec and mec.corteBraco)
			ctx.logAboutToken(token,string.format("Traço Firme (1/combate): %d contra CD %d: %s",r.total,r.cd,if r.passou then "mantém" else "falha"))
		end
		if not r.passou then interromper(token,"falhou em Concentração") end
	end
	function api.revalidar()
		for _,d in desenhos do
			local err=conferir(d)
			if err then interromper(d.token,err)
			elseif d.reacaoDisponivel and not ctx.reacoes.temReacao(d.token) then interromper(d.token,"usou Reação") end
		end
	end
	function api.aoTrocarVez(anteriorId,novoId)
		local d=anteriorId and desenhos[anteriorId]
		if d and d.ultimaDedicacao~=d.inicioVez then interromper(d.token,"Perda de Foco: passou sua vez sem desenhar") end
		d=novoId and desenhos[novoId]; if d then d.inicioVez=ctx.combat.turn end
		for id,p in preparadas do
			if ctx.tokens[id]~=p.token or ctx.combat.active and agora()<p.prontaEm then preparadas[id]=nil end
		end
		api.revalidar()
	end
	function api.estadosDe(token)
		local out={}; local d=desenhos[token.id]; local p=preparadas[token.id]
		if d then table.insert(out,string.format("Conjurando fórmula %s · %d/%d Ações",d.r.potencia,d.gastas,d.r.acoes)) end
		if p then table.insert(out,if agora()<p.prontaEm then "Preparando fórmula · "..math.ceil(p.prontaEm-agora()).." s" else "Fórmula preparada · 1 Ação") end
		return out
	end
	function api.temPreparada(token)
		for _,p in preparadas do
			local publico = p.token==token or ctx.publico and ctx.publico(p.token)
			if publico and ctx.tokens[p.token.id]==p.token and agora()>=p.prontaEm and math.max(math.abs(token.x-p.token.x),math.abs(token.z-p.token.z))<=1 then return true end
		end
		return false
	end
	function api.descanso()
		for _,d in desenhos do interromper(d.token,"combate encerrado") end
		for id,p in preparadas do if p.r.meio~="bolso" or ctx.tokens[id]~=p.token or agora()<p.prontaEm then preparadas[id]=nil end end
		table.clear(tracoUsado)
	end
	function api.descartar() table.clear(desenhos); table.clear(preparadas); table.clear(executando); table.clear(tracoUsado) end
	return api
end
return S

end)()
local P=(function()
-- Progressão nas árvores (puro; catálogo injetado). Porte de `canUnlockRank` e
-- `canPurchaseAbility` do site (src/store/selectors.ts), sobre a construção da
-- ficha v2 (construction.unlockedRankIds / purchasedIds).
--
-- Decisões do Pedro (09/10/2026), provisórias:
-- - PA INFINITO: o custo em PA não trava nada (no site ele também só informa).
-- - TETO no Intermediário: ranks acima ficam "em breve".
-- Livro: abrir um rank exige o rank anterior aberto na mesma árvore e N
-- conhecimentos (magias e talentos comprados) nela (RANK_REQUIREMENTS); comprar
-- exige o rank aberto, não ter a habilidade, os `requires` da mesma árvore e o
-- `requiresRank` (patamar mínimo numa árvore ou numa categoria).
-- Não portado (avisado no motivo): os Símbolos de origem natural da Teórica.
local Regras = (function()
-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Constantes de regra lidas do site (bônus de rank, Ações de magia, Ações por turno, moldes e arquétipos do Apêndice G) e vetores das funções do site para os testes diferenciais.
local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
return congelar({
	bonusDeRank = {
		Principiante = 1,
		["Intermediário"] = 2,
		["Avançado"] = 3,
		Santo = 4,
		Rei = 5,
		Imperador = 6,
		Deus = 7,
	},
	ordemDosRanks = {
		"Principiante",
		"Intermediário",
		"Avançado",
		"Santo",
		"Rei",
		"Imperador",
		"Deus",
	},
	requisitosDeRank = {
		Principiante = {
			knowledgeRequired = 0,
			paCost = 0,
		},
		["Intermediário"] = {
			knowledgeRequired = 3,
			paCost = 1,
		},
		["Avançado"] = {
			knowledgeRequired = 6,
			paCost = 2,
		},
		Santo = {
			knowledgeRequired = 9,
			paCost = 2,
		},
		Rei = {
			knowledgeRequired = 12,
			paCost = 3,
		},
		Imperador = {
			knowledgeRequired = 15,
			paCost = 3,
		},
		Deus = {
			knowledgeRequired = 18,
			paCost = 4,
		},
	},
	acoesDeMagia = {
		Principiante = {
			normal = 2,
			encurtada = 1,
			silenciosa = 1,
		},
		["Intermediário"] = {
			normal = 2,
			encurtada = 1,
			silenciosa = 1,
		},
		["Avançado"] = {
			normal = 3,
			encurtada = 2,
			silenciosa = 1,
		},
		Santo = {
			normal = 3,
			encurtada = 2,
			silenciosa = 2,
		},
		Rei = {
			normal = 4,
			encurtada = 3,
			silenciosa = 3,
		},
		Imperador = {
			normal = 4,
			silenciosa = 3,
		},
		Deus = {
			normal = 4,
			silenciosa = 3,
		},
	},
	acoesPorTurno = 3,
	escadaDeDados = {
		"d4",
		"d6",
		"d8",
		"d10",
		"d12",
		"2d8",
		"2d10",
		"2d12",
		"3d10",
		"3d12",
		"4d10",
		"4d12",
		"5d10",
		"5d12",
	},
	excessoPorDegrau = 2,
	moldesDeCriatura = {
		{
			patamar = 1,
			titulo = "Comum",
			pv = 64,
			ca = 12,
			bonusAtaque = 3,
			danoPorTurno = 16,
			cdResistencia = 11,
		},
		{
			patamar = 2,
			titulo = "Perigosa",
			pv = 68,
			ca = 14,
			bonusAtaque = 4,
			danoPorTurno = 21,
			cdResistencia = 13,
		},
		{
			patamar = 3,
			titulo = "Ameaça",
			pv = 121,
			ca = 16,
			bonusAtaque = 6,
			danoPorTurno = 29,
			cdResistencia = 15,
		},
		{
			patamar = 4,
			titulo = "Elite",
			pv = 152,
			ca = 18,
			bonusAtaque = 8,
			danoPorTurno = 38,
			cdResistencia = 17,
		},
		{
			patamar = 5,
			titulo = "Terror",
			pv = 210,
			ca = 20,
			bonusAtaque = 10,
			danoPorTurno = 48,
			cdResistencia = 19,
		},
		{
			patamar = 6,
			titulo = "Lenda",
			pv = 332,
			ca = 22,
			bonusAtaque = 12,
			danoPorTurno = 50,
			cdResistencia = 21,
		},
	},
	arquetiposDeCriatura = {
		{
			id = "bruto",
			principal = "Força",
			bom = "Vigor",
			comum = {
				"Agilidade",
			},
			fraco = {
				"Intelecto",
				"Espírito",
			},
			deslocamento = 6,
		},
		{
			id = "agil",
			principal = "Agilidade",
			bom = "Vigor",
			comum = {
				"Força",
			},
			fraco = {
				"Intelecto",
				"Espírito",
			},
			deslocamento = 12,
		},
		{
			id = "fortaleza",
			principal = "Vigor",
			bom = "Força",
			comum = {
				"Espírito",
			},
			fraco = {
				"Agilidade",
				"Intelecto",
			},
			deslocamento = 6,
		},
		{
			id = "conjurador",
			principal = "Intelecto",
			bom = "Espírito",
			comum = {
				"Agilidade",
				"Vigor",
			},
			fraco = {
				"Força",
			},
			deslocamento = 9,
		},
		{
			id = "mente",
			principal = "Espírito",
			bom = "Intelecto",
			comum = {
				"Agilidade",
				"Vigor",
			},
			fraco = {
				"Força",
			},
			deslocamento = 9,
		},
	},
	vetores = {
		aplicarPapel = {
			{
				patamar = 1,
				papel = "lacaio",
				saida = {
					pv = 32,
					danoPorTurno = 8,
				},
			},
			{
				patamar = 1,
				papel = "padrao",
				saida = {
					pv = 64,
					danoPorTurno = 16,
				},
			},
			{
				patamar = 1,
				papel = "chefe",
				saida = {
					pv = 160,
					danoPorTurno = 24,
				},
			},
			{
				patamar = 2,
				papel = "lacaio",
				saida = {
					pv = 34,
					danoPorTurno = 11,
				},
			},
			{
				patamar = 2,
				papel = "padrao",
				saida = {
					pv = 68,
					danoPorTurno = 21,
				},
			},
			{
				patamar = 2,
				papel = "chefe",
				saida = {
					pv = 170,
					danoPorTurno = 32,
				},
			},
			{
				patamar = 3,
				papel = "lacaio",
				saida = {
					pv = 61,
					danoPorTurno = 15,
				},
			},
			{
				patamar = 3,
				papel = "padrao",
				saida = {
					pv = 121,
					danoPorTurno = 29,
				},
			},
			{
				patamar = 3,
				papel = "chefe",
				saida = {
					pv = 303,
					danoPorTurno = 44,
				},
			},
			{
				patamar = 4,
				papel = "lacaio",
				saida = {
					pv = 76,
					danoPorTurno = 19,
				},
			},
			{
				patamar = 4,
				papel = "padrao",
				saida = {
					pv = 152,
					danoPorTurno = 38,
				},
			},
			{
				patamar = 4,
				papel = "chefe",
				saida = {
					pv = 380,
					danoPorTurno = 57,
				},
			},
			{
				patamar = 5,
				papel = "lacaio",
				saida = {
					pv = 105,
					danoPorTurno = 24,
				},
			},
			{
				patamar = 5,
				papel = "padrao",
				saida = {
					pv = 210,
					danoPorTurno = 48,
				},
			},
			{
				patamar = 5,
				papel = "chefe",
				saida = {
					pv = 525,
					danoPorTurno = 72,
				},
			},
			{
				patamar = 6,
				papel = "lacaio",
				saida = {
					pv = 166,
					danoPorTurno = 25,
				},
			},
			{
				patamar = 6,
				papel = "padrao",
				saida = {
					pv = 332,
					danoPorTurno = 50,
				},
			},
			{
				patamar = 6,
				papel = "chefe",
				saida = {
					pv = 830,
					danoPorTurno = 75,
				},
			},
		},
		atributosDaCriatura = {
			{
				patamar = 1,
				saida = {
					principal = 2,
					bom = 1,
					comum = 0,
					fraco = -1,
				},
			},
			{
				patamar = 2,
				saida = {
					principal = 2,
					bom = 1,
					comum = 0,
					fraco = -1,
				},
			},
			{
				patamar = 3,
				saida = {
					principal = 3,
					bom = 2,
					comum = 1,
					fraco = -1,
				},
			},
			{
				patamar = 4,
				saida = {
					principal = 4,
					bom = 2,
					comum = 1,
					fraco = -1,
				},
			},
			{
				patamar = 5,
				saida = {
					principal = 5,
					bom = 3,
					comum = 2,
					fraco = -1,
				},
			},
			{
				patamar = 6,
				saida = {
					principal = 6,
					bom = 3,
					comum = 2,
					fraco = -1,
				},
			},
		},
		bonusResistencia = {
			{
				patamar = 1,
				saida = 2,
			},
			{
				patamar = 2,
				saida = 2,
			},
			{
				patamar = 3,
				saida = 3,
			},
			{
				patamar = 4,
				saida = 4,
			},
			{
				patamar = 5,
				saida = 5,
			},
			{
				patamar = 6,
				saida = 6,
			},
		},
		escalarDado = {
			{
				dado = "d4",
				degraus = 0,
				saida = "d4",
			},
			{
				dado = "d4",
				degraus = 1,
				saida = "d6",
			},
			{
				dado = "d4",
				degraus = 2,
				saida = "d8",
			},
			{
				dado = "d4",
				degraus = 3,
				saida = "d10",
			},
			{
				dado = "d4",
				degraus = 5,
				saida = "2d8",
			},
			{
				dado = "d4",
				degraus = 9,
				saida = "3d12",
			},
			{
				dado = "d6",
				degraus = 0,
				saida = "d6",
			},
			{
				dado = "d6",
				degraus = 1,
				saida = "d8",
			},
			{
				dado = "d6",
				degraus = 2,
				saida = "d10",
			},
			{
				dado = "d6",
				degraus = 3,
				saida = "d12",
			},
			{
				dado = "d6",
				degraus = 5,
				saida = "2d10",
			},
			{
				dado = "d6",
				degraus = 9,
				saida = "4d10",
			},
			{
				dado = "d8",
				degraus = 0,
				saida = "d8",
			},
			{
				dado = "d8",
				degraus = 1,
				saida = "d10",
			},
			{
				dado = "d8",
				degraus = 2,
				saida = "d12",
			},
			{
				dado = "d8",
				degraus = 3,
				saida = "2d8",
			},
			{
				dado = "d8",
				degraus = 5,
				saida = "2d12",
			},
			{
				dado = "d8",
				degraus = 9,
				saida = "4d12",
			},
			{
				dado = "d10",
				degraus = 0,
				saida = "d10",
			},
			{
				dado = "d10",
				degraus = 1,
				saida = "d12",
			},
			{
				dado = "d10",
				degraus = 2,
				saida = "2d8",
			},
			{
				dado = "d10",
				degraus = 3,
				saida = "2d10",
			},
			{
				dado = "d10",
				degraus = 5,
				saida = "3d10",
			},
			{
				dado = "d10",
				degraus = 9,
				saida = "5d10",
			},
			{
				dado = "d12",
				degraus = 0,
				saida = "d12",
			},
			{
				dado = "d12",
				degraus = 1,
				saida = "2d8",
			},
			{
				dado = "d12",
				degraus = 2,
				saida = "2d10",
			},
			{
				dado = "d12",
				degraus = 3,
				saida = "2d12",
			},
			{
				dado = "d12",
				degraus = 5,
				saida = "3d12",
			},
			{
				dado = "d12",
				degraus = 9,
				saida = "5d12",
			},
			{
				dado = "2d8",
				degraus = 0,
				saida = "2d8",
			},
			{
				dado = "2d8",
				degraus = 1,
				saida = "2d10",
			},
			{
				dado = "2d8",
				degraus = 2,
				saida = "2d12",
			},
			{
				dado = "2d8",
				degraus = 3,
				saida = "3d10",
			},
			{
				dado = "2d8",
				degraus = 5,
				saida = "4d10",
			},
			{
				dado = "2d8",
				degraus = 9,
				saida = "5d12+2",
			},
			{
				dado = "2d10",
				degraus = 0,
				saida = "2d10",
			},
			{
				dado = "2d10",
				degraus = 1,
				saida = "2d12",
			},
			{
				dado = "2d10",
				degraus = 2,
				saida = "3d10",
			},
			{
				dado = "2d10",
				degraus = 3,
				saida = "3d12",
			},
			{
				dado = "2d10",
				degraus = 5,
				saida = "4d12",
			},
			{
				dado = "2d10",
				degraus = 9,
				saida = "5d12+4",
			},
			{
				dado = "2d12",
				degraus = 0,
				saida = "2d12",
			},
			{
				dado = "2d12",
				degraus = 1,
				saida = "3d10",
			},
			{
				dado = "2d12",
				degraus = 2,
				saida = "3d12",
			},
			{
				dado = "2d12",
				degraus = 3,
				saida = "4d10",
			},
			{
				dado = "2d12",
				degraus = 5,
				saida = "5d10",
			},
			{
				dado = "2d12",
				degraus = 9,
				saida = "5d12+6",
			},
			{
				dado = "3d10",
				degraus = 0,
				saida = "3d10",
			},
			{
				dado = "3d10",
				degraus = 1,
				saida = "3d12",
			},
			{
				dado = "3d10",
				degraus = 2,
				saida = "4d10",
			},
			{
				dado = "3d10",
				degraus = 3,
				saida = "4d12",
			},
			{
				dado = "3d10",
				degraus = 5,
				saida = "5d12",
			},
			{
				dado = "3d10",
				degraus = 9,
				saida = "5d12+8",
			},
			{
				dado = "3d12",
				degraus = 0,
				saida = "3d12",
			},
			{
				dado = "3d12",
				degraus = 1,
				saida = "4d10",
			},
			{
				dado = "3d12",
				degraus = 2,
				saida = "4d12",
			},
			{
				dado = "3d12",
				degraus = 3,
				saida = "5d10",
			},
			{
				dado = "3d12",
				degraus = 5,
				saida = "5d12+2",
			},
			{
				dado = "3d12",
				degraus = 9,
				saida = "5d12+10",
			},
			{
				dado = "4d10",
				degraus = 0,
				saida = "4d10",
			},
			{
				dado = "4d10",
				degraus = 1,
				saida = "4d12",
			},
			{
				dado = "4d10",
				degraus = 2,
				saida = "5d10",
			},
			{
				dado = "4d10",
				degraus = 3,
				saida = "5d12",
			},
			{
				dado = "4d10",
				degraus = 5,
				saida = "5d12+4",
			},
			{
				dado = "4d10",
				degraus = 9,
				saida = "5d12+12",
			},
			{
				dado = "4d12",
				degraus = 0,
				saida = "4d12",
			},
			{
				dado = "4d12",
				degraus = 1,
				saida = "5d10",
			},
			{
				dado = "4d12",
				degraus = 2,
				saida = "5d12",
			},
			{
				dado = "4d12",
				degraus = 3,
				saida = "5d12+2",
			},
			{
				dado = "4d12",
				degraus = 5,
				saida = "5d12+6",
			},
			{
				dado = "4d12",
				degraus = 9,
				saida = "5d12+14",
			},
			{
				dado = "5d10",
				degraus = 0,
				saida = "5d10",
			},
			{
				dado = "5d10",
				degraus = 1,
				saida = "5d12",
			},
			{
				dado = "5d10",
				degraus = 2,
				saida = "5d12+2",
			},
			{
				dado = "5d10",
				degraus = 3,
				saida = "5d12+4",
			},
			{
				dado = "5d10",
				degraus = 5,
				saida = "5d12+8",
			},
			{
				dado = "5d10",
				degraus = 9,
				saida = "5d12+16",
			},
			{
				dado = "5d12",
				degraus = 0,
				saida = "5d12",
			},
			{
				dado = "5d12",
				degraus = 1,
				saida = "5d12+2",
			},
			{
				dado = "5d12",
				degraus = 2,
				saida = "5d12+4",
			},
			{
				dado = "5d12",
				degraus = 3,
				saida = "5d12+6",
			},
			{
				dado = "5d12",
				degraus = 5,
				saida = "5d12+10",
			},
			{
				dado = "5d12",
				degraus = 9,
				saida = "5d12+18",
			},
		},
	},
})

end)()

local Progressao = {}

Progressao.PA_INFINITO = true
Progressao.TETO = "Intermediário"

local function indiceDoRank(rank: string): number?
	return table.find(Regras.ordemDosRanks, rank)
end

-- Segmento de ID com percent-encoding (CONTRATOS §2.1): "Intermediário" →
-- "Intermedi%C3%A1rio", como o gerador e o exportador do site.
function Progressao.segmento(texto: string): string
	return (string.gsub(texto, "[^%w%-%._~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

function Progressao.idDoRank(arvore: string, rank: string): string
	return "rank/" .. Progressao.segmento(arvore) .. "/" .. Progressao.segmento(rank)
end

function Progressao.rankAberto(construcao, arvore: string, rank: string): boolean
	return table.find(construcao.unlockedRankIds, Progressao.idDoRank(arvore, rank)) ~= nil
end

-- Maior rank aberto numa árvore (nome) ou nil.
function Progressao.maiorRank(construcao, arvore: string): string?
	local maior, indice = nil, 0
	for i, rank in Regras.ordemDosRanks do
		if Progressao.rankAberto(construcao, arvore, rank) and i > indice then
			maior, indice = rank, i
		end
	end
	return maior
end

-- Conhecimentos numa árvore: habilidades e talentos comprados nela.
function Progressao.conhecimentos(construcao, arvore: string): number
	local prefixoA = "ability/" .. Progressao.segmento(arvore) .. "/"
	local prefixoT = "talent/" .. Progressao.segmento(arvore) .. "/"
	local n = 0
	for _, id in construcao.purchasedIds do
		if string.sub(id, 1, #prefixoA) == prefixoA or string.sub(id, 1, #prefixoT) == prefixoT then
			n += 1
		end
	end
	return n
end

-- Carta de 0 PA (o truque da escola) não se compra: quem abriu o patamar a tem
-- (Cap. 2, §1; combatSim "gratuitas").
function Progressao.gratuita(entrada): boolean
	return entrada.kind == "ability" and entrada.data.paCost == 0
end

-- Habilidades e talentos que a construção conhece: as compras e as cartas
-- gratuitas dos ranks abertos.
function Progressao.conhecidas(construcao, catalogo): { string }
	local lista = table.clone(construcao.purchasedIds)
	for _, rankId in construcao.unlockedRankIds do
		local rank = catalogo.POR_ID[rankId]
		for _, id in (rank and rank.data.abilities) or {} do
			local entrada = catalogo.POR_ID[id]
			if entrada and Progressao.gratuita(entrada) and not table.find(lista, id) then
				table.insert(lista, id)
			end
		end
	end
	return lista
end

function Progressao.acimaDoTeto(rank: string): boolean
	local i, teto = indiceDoRank(rank), indiceDoRank(Progressao.TETO)
	return i == nil or teto == nil or i > teto
end

-- Pode abrir o rank? (ok, motivo)
function Progressao.podeAbrir(construcao, catalogo, arvore: string, rank: string): (boolean, string?)
	if not catalogo.POR_ID["tree/" .. Progressao.segmento(arvore)] then
		return false, "Árvore desconhecida."
	end
	local indice = indiceDoRank(rank)
	if not indice or not catalogo.POR_ID[Progressao.idDoRank(arvore, rank)] then
		return false, "Rank desconhecido nesta árvore."
	end
	if Progressao.acimaDoTeto(rank) then
		return false, "Por enquanto o jogo vai até o " .. Progressao.TETO .. "."
	end
	if Progressao.rankAberto(construcao, arvore, rank) then
		return false, "Rank já desbloqueado."
	end
	if indice > 1 then
		local anterior = Regras.ordemDosRanks[indice - 1]
		if not Progressao.rankAberto(construcao, arvore, anterior) then
			return false, "Desbloqueie " .. anterior .. " antes."
		end
	end
	local exigidos = Regras.requisitosDeRank[rank].knowledgeRequired
	local tem = Progressao.conhecimentos(construcao, arvore)
	if tem < exigidos then
		return false, string.format("Precisa de %d conhecimento(s) nesta árvore (tem %d).", exigidos, tem)
	end
	return true, nil
end

-- Pode comprar a habilidade ou talento? (ok, motivo)
function Progressao.podeComprar(construcao, catalogo, id: string): (boolean, string?)
	local entrada = catalogo.POR_ID[id]
	if not entrada or (entrada.kind ~= "ability" and entrada.kind ~= "talent") then
		return false, "Habilidade desconhecida."
	end
	local dados = entrada.data
	local arvore, rank = dados.treeId, dados.rank
	if Progressao.acimaDoTeto(rank) then
		return false, "Por enquanto o jogo vai até o " .. Progressao.TETO .. "."
	end
	if not Progressao.rankAberto(construcao, arvore, rank) then
		return false, "Rank ainda não desbloqueado nesta árvore."
	end
	if table.find(construcao.purchasedIds, id) then
		return false, "Já adquirido."
	end
	if Progressao.gratuita(entrada) then
		return false, "Vem com o rank: não se compra."
	end
	if arvore == "teorica" and dados.requires and #dados.requires > 0 then
		-- Símbolos de origem natural (selectors.ts `origemNaturalDoSimbolo`) não portados.
		return false, "Pré-requisitos de Símbolo da Teórica ainda não suportados no jogo."
	end
	for _, requerido in dados.requires or {} do
		local tem = false
		for _, comprado in construcao.purchasedIds do
			local outra = catalogo.POR_ID[comprado]
			if outra and outra.data.treeId == arvore and outra.sourceId == requerido then
				tem = true
				break
			end
		end
		if not tem then
			local nome = requerido
			for _, candidato in catalogo.POR_ESPECIE.ability or {} do
				if candidato.data.treeId == arvore and candidato.sourceId == requerido then
					nome = candidato.data.name
				end
			end
			return false, string.format('Exige "%s" nesta árvore antes.', nome)
		end
	end
	local exigencia = dados.requiresRank
	if exigencia then
		local minimo = indiceDoRank(exigencia.rank) or 1
		local atende = false
		for _, rankId in construcao.unlockedRankIds do
			local r = catalogo.POR_ID[rankId]
			if r then
				local outraArvore = r.data.treeId
				local i = indiceDoRank(r.data.rank) or 0
				if i >= minimo then
					if exigencia.treeId and outraArvore == exigencia.treeId then
						atende = true
					elseif exigencia.categoria then
						local arv = catalogo.POR_ID["tree/" .. Progressao.segmento(outraArvore)]
						if arv and arv.data.category == exigencia.categoria then
							atende = true
						end
					end
				end
			end
		end
		if not atende then
			local onde = exigencia.treeId or ("alguma árvore de " .. tostring(exigencia.categoria))
			local arv = exigencia.treeId and catalogo.POR_ID["tree/" .. Progressao.segmento(exigencia.treeId)]
			if arv then
				onde = arv.data.name
			end
			return false, string.format("Exige o patamar %s em %s.", exigencia.rank, onde)
		end
	end
	return true, nil
end

return Progressao

end)()
local function ambiente(rank,fila)
	local a={id="a",name="Teórico",ownerUserId=1,x=5,z=5,pv=100,pvMax=100,mana=30,manaMax=30,version=1,
		ficha2={construction={unlockedRankIds={P.idDoRank("teorica",rank or "Principiante")},purchasedIds={}},calculated={attributes={espirito=0},highestRankBonus=1}}}
	local b={id="b",name="Outro",ownerUserId=2,x=6,z=5,pv=100,mana=30,manaMax=30,version=1}
	local tokens={a=a,b=b}; local combat={active=true,current="a",turn=1}; local handlers,logs,execs={},{},{}
	local turnos={}; local time=0; local geo=nil; local reacao=true; local incapaz=false; local silencioso=false
	local rng=table.clone(fila or {}); local limite=3
	local ctx={tokens=tokens,tokenOrder={"a","b"},combat=combat,handlers=handlers,agora=function() return time end,
		canSee=function(_,t) return not t.hidden end,semAcoes=function(t) return t==a and incapaz end,
		reacoes={pendente=function() return false end,temReacao=function() return reacao end},currentTurnId=function() return combat.current end,
		turno=function(id) local k=id..combat.turn; turnos[k]=turnos[k] or {usadas=0,usos={}}; return turnos[k] end,
		limiteDeAcoes=function() return limite end,bc=function() return 3 end,condicoesDe=function(t) return t.conds or {} end,
		silenciado=function() return silencioso end,patamar=function() return 1 end,publico=function(t) return not t.hidden end,
		validarAlvo=function() return geo end,executar=function(_,t,m,p,bc) table.insert(execs,{token=t,m=m,p=p,bc=bc}); return nil end,
		logAboutToken=function(_,txt) table.insert(logs,txt) end,random={NextInteger=function() return table.remove(rng,1) or 10 end}}
	local api=S.novo(ctx)
	local x={a=a,b=b,api=api,combat=combat,ctx=ctx,handlers=handlers,execs=execs,logs=logs,tokens=tokens}
	x.send=function(c,p,id) return handlers[c]({UserId=id or 1},p,false) end
	x.desenhar=function(extra)
		local p={tokenId="a",essencia="mana",verbo="lancar",forma="circulo",potencia=rank or "Principiante",alvoId="b"}
		for k,v in extra or {} do p[k]=v end
		return x.send("desenharFormula",p)
	end
	x.vez=function(id) local old=combat.current; combat.current=id; combat.turn+=1; api.aoTrocarVez(old,id) end
	x.now=function(n) time=n end; x.geo=function(e) geo=e end; x.reacao=function(v) reacao=v end; x.incapaz=function(v) incapaz=v end
	x.silencio=function(v) silencioso=v end; x.limite=function(n) limite=n end
	x.preparar=function(meio,v)
		return x.send("prepararFormula",{tokenId="a",essencia="mana",verbo=v or "erguer",forma="quadrado",potencia="Principiante",meio=meio or "giz"})
	end
	return x
end
return {
	["A19 custo reservado uma vez, intenção canônica, executor sem custo duplicado"] = function(t)
		local x=ambiente(); t.eq(x.desenhar({qualidade=.01}),nil); t.eq(x.a.mana,29); t.eq(x.ctx.turno("a").usadas,2)
		t.eq(#x.execs,1); t.eq(x.execs[1].m.pm,0); t.eq(x.execs[1].m.acoes,0); t.eq(x.execs[1].p.qualidade,nil)
		t.eq(x.desenhar(),"Só uma fórmula desenhada que fere por turno."); t.eq(x.a.mana,29)
	end,
	["A19 tipos/contexto/forma/rank/essência/alvo recusados antes do custo"] = function(t)
		local x=ambiente(); t.ok(x.send("desenharFormula",false)); t.ok(x.desenhar({forma="triangulo"})); t.ok(x.desenhar({potencia="Rei"})); t.ok(x.desenhar({essencia="fogo"}))
		t.ok(x.desenhar({qualidade=0/0})); t.ok(x.desenhar({alvoId={}})); t.ok(x.desenhar({x=0,z=5}))
		t.ok(x.send("desenharFormula",{tokenId="a"},2)); x.a.hidden=true; t.ok(x.desenhar()); x.a.hidden=nil
		x.geo("Sem visão"); t.ok(x.desenhar()); t.eq(x.a.mana,30); t.eq(x.ctx.turno("a").usadas,0); t.eq(#x.execs,0)
	end,
	["A19 Rei divide 3+1 Ações e só paga PM ao começar"] = function(t)
		local x=ambiente("Rei"); t.eq(x.desenhar(),nil); t.eq(x.a.mana,20); t.eq(#x.execs,0); t.eq(x.api.desenhando(x.a),true)
		t.ok(x.desenhar()); x.vez("b"); t.ok(x.send("continuarFormula",{tokenId="a"})); x.vez("a")
		t.eq(x.send("continuarFormula",{tokenId="a"}),nil); t.eq(x.ctx.turno("a").usadas,1); t.eq(x.a.mana,20); t.eq(#x.execs,1)
		t.eq(x.api.ocupado(x.a),false); t.ok(x.desenhar())
	end,
	["A19 Principiante pode dividir se só restar 1 Ação"] = function(t)
		local x=ambiente(); x.ctx.turno("a").usadas=2; t.eq(x.desenhar(),nil); t.eq(#x.execs,0)
		x.vez("b"); x.vez("a"); t.eq(x.send("continuarFormula",{tokenId="a"}),nil); t.eq(#x.execs,1); t.eq(x.a.mana,29)
	end,
	["A19 Perda de Foco perde metade PM e Ações sem efeito"] = function(t)
		local x=ambiente("Rei"); x.desenhar(); x.vez("b"); x.vez("a"); x.vez("b")
		t.eq(x.api.desenhando(x.a),false); t.eq(x.a.mana,25); t.eq(#x.execs,0); t.eq(x.ctx.turno("a").usadas,0)
	end,
	["A19 concentração falha reembolsa teto da metade; preserva as 3 Ações"] = function(t)
		local x=ambiente("Avançado",{1}); x.limite(2); x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{},5)
		t.eq(x.api.desenhando(x.a),false); t.eq(x.a.mana,28); t.eq(x.ctx.turno("a").usadas,2); t.eq(#x.execs,0)
	end,
	["A19 concentração sucesso e zero dano conservam progresso"] = function(t)
		local x=ambiente("Rei",{20}); x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{},0); t.eq(x.api.desenhando(x.a),true)
		x.api.aoSofrerDano(x.a,x.b,{},1); t.eq(x.api.desenhando(x.a),true); t.eq(x.a.mana,20)
	end,
	["A19 Traço Firme refaz uma falha por combate, sem novo custo"] = function(t)
		local x=ambiente("Rei",{1,20,1}); table.insert(x.a.ficha2.construction.purchasedIds,"talent/teorica/Principiante/traco-firme")
		x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{},3); t.eq(x.api.desenhando(x.a),true)
		x.api.aoSofrerDano(x.a,x.b,{},3); t.eq(x.api.desenhando(x.a),false); t.eq(x.a.mana,25)
	end,
	["A19 Corte de Braço dá Desvantagem ao teste daquele golpe"] = function(t)
		local x=ambiente("Rei",{20,1}); x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{corteBraco=true},1)
		t.eq(x.api.desenhando(x.a),false)
	end,
	["A19 usar Reação interrompe, cancelamento livre não exige sua vez"] = function(t)
		local x=ambiente("Rei"); x.desenhar(); x.vez("b"); x.reacao(false); x.api.revalidar(); t.eq(x.api.desenhando(x.a),false)
		x.vez("a"); x.reacao(true); x.desenhar(); x.vez("b"); t.eq(x.send("cancelarFormula",{tokenId="a"}),nil); t.eq(x.api.desenhando(x.a),false)
	end,
	["A19 incapacidade e perda de alcance interrompem sem teste"] = function(t)
		local x=ambiente("Rei"); x.desenhar(); x.geo("Alvo saiu do alcance"); x.api.revalidar(); t.eq(x.api.desenhando(x.a),false)
		x=ambiente("Rei"); x.desenhar(); x.incapaz(true); x.api.revalidar(); t.eq(x.api.desenhando(x.a),false)
	end,
	["A19 PM/Ações insuficientes e silêncio não iniciam conjuração"] = function(t)
		local x=ambiente(); x.a.mana=0; t.ok(x.desenhar()); t.eq(x.api.desenhando(x.a),false)
		x.a.mana=30; x.ctx.turno("a").usadas=3; t.ok(x.desenhar()); t.eq(x.a.mana,30)
		x.ctx.turno("a").usadas=0; x.silencio(true); t.ok(x.desenhar()); t.eq(#x.execs,0)
	end,
	["A19 preparo só fora de combate, sem PM; Lançar/Vida não prepara"] = function(t)
		local x=ambiente(); t.ok(x.preparar()); x.combat.active=false; t.eq(x.preparar(),nil); t.eq(x.a.mana,30)
		t.ok(x.preparar("giz","lancar")); t.ok(x.preparar("bolso")); t.eq(#x.execs,0)
	end,
	["A19 alimentador sem Teórica paga PM/1 Ação; BC fica na fórmula"] = function(t)
		local x=ambiente(); x.combat.active=false; t.eq(x.preparar(),nil); x.now(60); x.combat.active=true; x.vez("b")
		t.eq(x.send("ativarFormula",{tokenId="b",x=7,z=5},2),nil); t.eq(x.b.mana,28); t.eq(x.a.mana,30); t.eq(x.ctx.turno("b").usadas,1)
		t.eq(x.execs[1].bc,3); t.eq(x.api.temPreparada(x.a),false); t.ok(x.send("ativarFormula",{tokenId="b",x=7,z=5},2))
	end,
	["A19 um minuto real e contexto de toque; preparo incompleto cancela ao lutar"] = function(t)
		local x=ambiente(); x.combat.active=false; x.preparar(); x.now(59); x.combat.active=true
		t.ok(x.send("ativarFormula",{tokenId="a",x=5,z=6})); t.eq(x.a.mana,30)
		x.vez("b"); x.now(61); t.eq(x.api.temPreparada(x.a),false)
		x.combat.active=false; x.preparar(); x.now(121); x.combat.active=true; x.vez("b"); x.b.x=9
		t.ok(x.send("ativarFormula",{tokenId="b",x=9,z=6},2)); t.eq(x.b.mana,30)
	end,
	["A19 Bolso sobrevive descanso; giz expira; descartar limpa ambos"] = function(t)
		local x=ambiente(); table.insert(x.a.ficha2.construction.purchasedIds,"talent/teorica/Principiante/simbolo-rejeitar")
		x.combat.active=false; x.preparar("bolso"); x.now(60); x.api.descanso(); t.eq(x.api.temPreparada(x.a),true)
		x.api.descartar(); t.eq(x.api.temPreparada(x.a),false)
		x.preparar("giz"); x.now(120); x.api.descanso(); t.eq(x.api.temPreparada(x.a),false)
	end,
	["A19 falha de alvo/recursos na ativação preserva pergaminho"] = function(t)
		local x=ambiente(); x.combat.active=false; x.preparar(); x.now(60); x.combat.active=true
		x.geo("Sem visão"); t.ok(x.send("ativarFormula",{tokenId="a",x=5,z=6})); t.eq(x.api.temPreparada(x.a),true)
		x.geo(nil); x.a.mana=0; t.ok(x.send("ativarFormula",{tokenId="a",x=5,z=6})); t.eq(x.api.temPreparada(x.a),true)
	end,
}

end)()

local t = {
	eq = function(a, b, msg) if a ~= b then error((msg or "") .. " esperado " .. tostring(b) .. ", obtido " .. tostring(a), 2) end end,
	ok = function(a, msg) if not a then error(msg or "condição falsa", 2) end end,
	fails = function(fn, msg) if pcall(fn) then error(msg or "era esperado erro", 2) end end,
}
local passed, failed = 0, 0
for name, fn in spec do
	local ok, err = pcall(fn, t)
	if ok then passed += 1 else failed += 1; print("FALHA", name, err) end
end
print("RESULTADO", passed, failed)
