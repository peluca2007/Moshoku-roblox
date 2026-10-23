
local V3 = {}; V3.__index = V3
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local C3 = { __eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end }
Color3 = { new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end }
Color3.fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end

local spec = (function()
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
local P = (function()
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
local function ficha(rank, escola, talentos)
	local ids = { P.idDoRank("teorica", rank or "Principiante") }
	if escola then table.insert(ids, P.idDoRank(escola, "Principiante")) end
	return { construction = { unlockedRankIds = ids, purchasedIds = talentos or {} } }
end
local function pedido(e,v,f,p) return { essencia=e or "mana",verbo=v or "lancar",forma=f or "circulo",potencia=p or "Principiante" } end
local specs = {}
specs["tabela do Cap.2 §8: números independentes dos cálculos"] = function(t)
	local linhas={{1,20,9,3,2},{2,40,18,6,2},{5,60,27,9,3},{6,80,45,12,3},{10,100,90,18,4},{12,120,150,30,4}}
	for i,rank in F.RANKS do
		local p=F.POTENCIA[rank]; local v=linhas[i]
		t.eq(p.pm,v[1]); t.eq(p.dados,v[1]); t.eq(p.pv,v[2]); t.eq(p.alcance,v[3]); t.eq(p.tamanho,v[4]); t.eq(p.acoes,v[5])
	end
end
for _,rank in F.RANKS do
	for essencia,e in F.ESSENCIAS do
		for verbo in F.VERBOS do
			for forma in F.FORMAS do
				specs[rank.." · "..essencia.." · "..verbo.." · "..forma] = function(t)
					local r,err=F.validar(ficha(rank,e.arvore),pedido(essencia,verbo,forma,rank))
					t.ok(r,err); local p=F.POTENCIA[rank]
					t.eq(r.pm,p.pm+(if essencia=="mana" then 0 else 1)+(if forma=="circulo" then 0 else 1))
					t.eq(r.acoes,p.acoes); t.eq(r.dados,p.dados)
					t.eq(r.fere,verbo=="lancar" and essencia~="vida"); t.eq(r.cura,verbo=="lancar" and essencia=="vida")
					if verbo=="erguer" then t.eq(r.pv,math.ceil(p.pv*(1+(if forma=="quadrado" then .5 else 0)+(if essencia=="terra" then .5 else 0)))) end
					t.eq(r.alcanceMetros,if verbo=="lancar" then math.floor(p.alcance*(if forma=="linha" then 1.5 else 1)/1.5)*1.5 else 1.5)
					t.ok(#r.descricao>0)
				end
			end
		end
	end
end
specs["recusa payload inválido, palavras desconhecidas e potência acima"] = function(t)
	for _,q in {false,{},pedido("raio"),pedido(nil,"explodir"),pedido(nil,nil,"estrela"),pedido(nil,nil,nil,"Deus"),pedido(nil,nil,nil,"Rei")} do
		local r,err=F.validar(ficha(),q); t.eq(r,nil); t.ok(err)
	end
	t.eq(F.validar(nil,pedido()),nil)
	t.eq(F.validar({construction={unlockedRankIds={},purchasedIds={}}},pedido()),nil)
end
specs["essências exigem origem aberta OU talento, não habilidade nem talento alheio"] = function(t)
	for id,e in F.ESSENCIAS do if id~="mana" then
		t.eq(F.validar(ficha(),pedido(id)),nil)
		t.ok(F.validar(ficha(nil,e.arvore),pedido(id)))
		t.ok(F.validar(ficha(nil,nil,{"talent/teorica/Principiante/simbolo-"..id}),pedido(id)))
		t.eq(F.validar(ficha(nil,nil,{"ability/teorica/Principiante/simbolo-"..id}),pedido(id)),nil)
	end end
end
specs["giz e bolso levam 60 segundos, ativam 1 Ação; Lançar nunca prepara"] = function(t)
	local f=ficha(nil,nil,{"talent/teorica/Principiante/simbolo-rejeitar"})
	for _,meio in {"giz","bolso"} do
		for _,v in {"erguer","selar","sinalizar"} do
			local r=F.validar(f,pedido(nil,v),meio); t.eq(r.preparoSegundos,60); t.eq(r.acoes,1)
			t.eq(r.duracaoRodadas,if v=="sinalizar" then 1 else 100)
		end
		t.eq(F.validar(f,pedido(),meio),nil)
		t.eq(F.validar(ficha(nil,"cura"),pedido("vida"),meio),nil)
	end
	t.eq(F.validar(ficha(),pedido(nil,"selar"),"bolso"),nil)
	t.eq(F.validar(f,pedido(nil,"selar"),"pedra"),nil)
end
specs["efeitos próprios de contato e adição Terra + Quadrado"] = function(t)
	local terra=F.validar(ficha(nil,"terra"),pedido("terra","erguer","quadrado")); t.eq(terra.pv,40)
	local fogo=F.validar(ficha("Avançado","fogo"),pedido("fogo","erguer",nil,"Avançado")); t.eq(fogo.contatoDados,3)
	local vida=F.validar(ficha(nil,"cura"),pedido("vida","erguer")); t.eq(vida.pvTemp,5)
	local mana=F.validar(ficha(),pedido(nil,"erguer")); t.eq(mana.contato,nil)
end
specs["qualidade não altera nenhuma regra e Quadrado não muda Lançar"] = function(t)
	local q=pedido(nil,nil,"quadrado"); q.qualidade=0/0
	local r=F.validar(ficha(),q); t.eq(r.pm,2); t.eq(r.dados,1); t.eq(r.acoes,2)
end
specs["régua Mana bloqueia igual, reduz um acima e deixa dois acima"] = function(t)
	local r=F.validar(ficha(),pedido(nil,"selar"))
	t.eq(F.fatorSelo(r,"Principiante","terra",true),0)
	t.eq(F.fatorSelo(r,"Intermediário","terra",true),.5)
	t.eq(F.fatorSelo(r,"Avançado","terra",true),1)
	t.eq(F.fatorSelo(r,"Principiante","terra",false),1)
	t.eq(F.fatorSelo(r,"errado","terra",true),nil)
end
specs["selo elemental ganha um rank mas só barra sua escola"] = function(t)
	local r=F.validar(ficha(nil,"fogo"),pedido("fogo","selar"))
	t.eq(F.fatorSelo(r,"Intermediário","fogo",true),0)
	t.eq(F.fatorSelo(r,"Avançado","fogo",true),.5)
	t.eq(F.fatorSelo(r,"Principiante","terra",true),1)
end
specs["concentração usa Espírito + metade para cima e rank do atacante, não dano"] = function(t)
	local random={NextInteger=function() return 8 end}
	local r=F.concentracao(random,2,3,3); t.eq(r.total,12); t.eq(r.cd,13); t.eq(r.passou,false)
	t.eq(F.concentracao(random,2,3,nil).passou,true)
	for pm=1,15 do t.eq(pm-F.reembolsoInterrupcao(pm),math.floor(pm/2)) end
end
specs["concentração com Desvantagem usa menor d20; sem críticos automáticos"] = function(t)
	local dados={20,1}; local random={NextInteger=function() return table.remove(dados,1) end}
	local r=F.concentracao(random,0,1,1,true); t.eq(r.dado,1); t.eq(r.passou,false)
	t.eq(F.concentracao({NextInteger=function() return 1 end},20,6,1).passou,true)
end
specs["mecânica de cura sem BC, parede com PV e selo sem colisão"] = function(t)
	local m=F.mecanica(F.validar(ficha(nil,"cura"),pedido("vida")))
	t.eq(m.tipo,"cura"); t.eq(m.partes[1].bc,false); t.eq(m.partes[1].dados,"1d8")
	m=F.mecanica(F.validar(ficha(),pedido(nil,"erguer","quadrado")))
	t.eq(m.pvZona,30); t.eq(m.comprimentoCasas,2); t.eq(m.bloqueiaMovimento,true); t.eq(m.bloqueiaVisao,nil)
	m=F.mecanica(F.validar(ficha(),pedido(nil,"selar"))); t.eq(m.pvZona,nil); t.eq(m.bloqueiaMovimento,false)
end
specs["selo reduz dados e área/duração, conserva BC/CD e não muda original"] = function(t)
	local m={partes={{dados="5d8",bc=true}},resistencia={cdBase=8},raioCasas=6,duracaoRodadas=10}
	local r=F.reduzirMecanica(m,.5)
	t.eq(r.partes[1].dados,"2d8"); t.eq(r.partes[1].bc,true); t.eq(r.resistencia.cdBase,8)
	t.eq(r.raioCasas,3); t.eq(r.duracaoRodadas,5); t.eq(m.partes[1].dados,"5d8")
	t.eq(F.reduzirMecanica({partes={{dados="1d8",bc=true}}},.5).partes[1].dados,nil)
	t.eq(F.reduzirMecanica({partes={{dados="1d8+4d6"}}},.5).partes[1].dados,"2d6")
end
local function caminho(vertices)
	local pts={}
	for i=1,#vertices-1 do for j=0,12 do
		local a,b=vertices[i],vertices[i+1]; table.insert(pts,{a[1]+(b[1]-a[1])*j/12,a[2]+(b[2]-a[2])*j/12})
	end end
	return pts
end
specs["traços reais: linha, quadrado, quadrado rotacionado, círculo"] = function(t)
	t.eq(F.reconhecer(caminho({{10,10},{170,90}})),"linha")
	t.eq(F.reconhecer(caminho({{20,20},{180,20},{180,180},{20,180},{20,20}})),"quadrado")
	t.eq(F.reconhecer(caminho({{100,10},{190,100},{100,190},{10,100},{100,10}})),"quadrado")
	local pts={}; for i=0,60 do local a=i/60*2*math.pi; table.insert(pts,{100+80*math.cos(a),100+80*math.sin(a)}) end
	t.eq(F.reconhecer(pts),"circulo")
end
specs["não reconhece clique, rabisco, triângulo, retângulo estreito nem infinito"] = function(t)
	t.eq(F.reconhecer({}),nil)
	t.eq(F.reconhecer(caminho({{10,10},{15,15}})),nil)
	t.eq(F.reconhecer(caminho({{20,20},{180,20},{100,180},{20,20}})),nil)
	t.eq(F.reconhecer(caminho({{20,20},{200,20},{200,55},{20,55},{20,20}})),nil)
	t.eq(F.reconhecer(caminho({{0,0},{math.huge,0}})),nil)
end
specs["reconhecimento tolera traço irregular e quadrado iniciado no meio do lado"] = function(t)
	local pts=caminho({{100,20},{180,20},{180,180},{20,180},{20,20},{100,20}})
	for i,p in pts do p[1]+=math.sin(i*1.7)*2; p[2]+=math.cos(i*1.1)*2 end
	t.eq(F.reconhecer(pts),"quadrado")
	pts={}; for i=0,90 do local a=i/90*2*math.pi; local r=80+math.sin(i)*3; table.insert(pts,{100+r*math.cos(a),100+r*math.sin(a)}) end
	t.eq(F.reconhecer(pts),"circulo")
	pts=caminho({{20,20},{180,140}})
	for i,p in pts do p[2]+=math.sin(i)*2 end
	t.eq(F.reconhecer(pts),"linha")
end
return specs

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
