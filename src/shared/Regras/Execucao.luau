-- Registro das habilidades EXECUTÁVEIS no jogo: junta as tabelas de mecânicas de
-- cada árvore (Regras/Fogo, ...). Cada árvore nova entra em TABELAS. Puro; o
-- catálogo é injetado. Ver docs/FIDELIDADE.md.
local Shared = game:GetService("ReplicatedStorage").Shared
local Regras = require(Shared.Livro.Regras)
local Progressao = require(Shared.Regras.Progressao)
local Fogo = require(Shared.Regras.Fogo)
local Arvores = require(Shared.Regras.ArvoresPrincipiante)
local Maestrias = require(Shared.Regras.Maestrias)
local Utilidades = require(Shared.Regras.Utilidades)

local Execucao = {}

Execucao.TABELAS = { Fogo, Arvores, Maestrias, Utilidades }
Execucao.INDISPONIVEIS = table.clone(Arvores.INDISPONIVEIS)
for id, texto in {
	["ability/deus-da-espada/Principiante/roupa-leve"] = "Passiva automática: sem armadura, +3 m de Deslocamento; andar 3 m concede +2 CA até a próxima vez.",
	["ability/deus-da-espada/Principiante/sem-recuo"] = "Passiva automática: imune a Amedrontado.",
	["ability/deus-da-agua-corpo/Principiante/base-firme"] = "Passiva automática: ignora empurrão, puxão e Caído de efeitos com teste de Força ou Agilidade.",
} do Execucao.INDISPONIVEIS[id] = texto end

Execucao.PACTOS = {
	["talent/invocacao/Principiante/pacto-filhote"] = { nome = "Filhote Evolutivo", ajuda = true, dados = "1d4" },
	["talent/invocacao/Principiante/pacto-cao-de-caca"] = { nome = "Cão de Caça", dados = "2d6", derruba = true },
	["talent/invocacao/Principiante/pacto-corvo-mensageiro"] = { nome = "Corvo Mensageiro", dados = "1d6", movimento = 12 },
	["talent/invocacao/Principiante/pacto-fogo-fatuo"] = { nome = "Fogo-Fátuo", ajuda = true, marca = true },
}
function Execucao.pactosDe(ficha2)
	local lista = {}
	for _, id in (ficha2 and ficha2.construction.purchasedIds) or {} do
		if Execucao.PACTOS[id] then table.insert(lista, id) end
	end
	table.sort(lista)
	return lista
end

local mecanicas = {}
for _, tabela in Execucao.TABELAS do
	for id, mec in tabela.MECANICAS do
		assert(mecanicas[id] == nil, "mecânica repetida: " .. id)
		mecanicas[id] = mec
	end
end
for id, nome in { ["invocado/ataque"] = "Atacar", ["invocado/ajudar"] = "Ajudar", ["invocado/derrubar"] = "Derrubar" } do
	mecanicas[id] = { tipo = "ataque", nome = nome, acoes = 1, corpoACorpo = true, pm = 0, pt = 0 }
end
-- Duas intenções explícitas preservam a escolha de atributo do livro.
for _, atributo in { "forca", "intelecto" } do
	mecanicas["mesa/lamina-de-gelo-" .. atributo] = {
		tipo = "ataque", nome = "Lâmina · " .. (if atributo == "forca" then "Força" else "Intelecto"),
		acoes = 1, pm = 0, pt = 0, corpoACorpo = true, exigeMao = true,
		arvore = "agua", exigeArmaGelo = true, atributoAcerto = atributo,
		partes = { { dados = "1d8", bc = true, tipo = "cortante" }, { dados = "1d4", tipo = "frio" } },
	}
end
-- Atacar com Arma (Cap. 4, §3): 1 Ação, "um golpe corpo a corpo ou um projétil
-- disparado". Todo personagem tem; o Dado de Arma e o bônus vêm da árvore de
-- corpo de maior rank (Arma.daFicha).
mecanicas["mesa/ataque-basico"] = { tipo = "ataque", nome = "Ataque básico", acoes = 1, pm = 0, pt = 0, corpoACorpo = true,
	arma = true, basico = true, partes = { { arma = true, bc = true } },
	descricao = "Golpe com a arma equipada num inimigo ao lado. Dano: Dado de Arma + atributo." }
mecanicas["mesa/ataque-a-distancia"] = { tipo = "ataque", nome = "Disparo", acoes = 1, pm = 0, pt = 0, arma = true, armaADistancia = true,
	basico = true, alcanceCasas = 12, partes = { { arma = true, bc = true } },
	aviso = "Alcance de disparo desta fatia: 18 m (12 casas).",
	descricao = "Dispara a arma de longe, até 12 casas. Dano: Dado de Arma + atributo." }
local quebra = "ability/armas-pesadas/Principiante/quebrar-equipamento"
mecanicas["mesa/quebrar-escudo"] = table.clone(mecanicas[quebra])
mecanicas["mesa/quebrar-escudo"].nome = "Quebrar escudo"
mecanicas["mesa/quebrar-escudo"].exigeHabilidade = quebra
mecanicas["mesa/quebrar-escudo"].equipamento = "escudo"
mecanicas["mesa/quebrar-escudo"].arvore = "armas-pesadas"
-- Controles transitórios: expostos pelo serviço somente quando aplicáveis.
for id, nome in { ["escapar"] = "Escapar", ["soltar"] = "Soltar agarrão", ["arrastar"] = "Arrastar 3 m", ["pegar-arma"] = "Pegar arma", ["desarmar"] = "Desarmar", ["levantar"] = "Levantar" } do
 mecanicas["mesa/" .. id] = { tipo = "utilidade", nome = nome, acoes = if id == "soltar" then 0 else 1, pm = 0, pt = 0,
  controleA16 = id, alvoCasa = id == "arrastar" or id == "pegar-arma", alcanceCasas = if id == "arrastar" then 12 else 1,
  descricao = "O servidor valida o vínculo, equipamento, alcance e custo." }
end
mecanicas["mesa/levantar"].alcanceCasas = nil
mecanicas["mesa/levantar"].descricao = "1 Ação: levanta e remove Caído. Você ainda pode andar metade do seu Deslocamento sem outra Ação, nesta vez. A 0 PV, receba cura primeiro. Agarrado ou imobilizado precisa se soltar."
mecanicas["mesa/desarmar"].tipo = "efeito"
mecanicas["mesa/desarmar"].corpoACorpo = true
mecanicas["mesa/desarmar"].controleA16 = nil
mecanicas["mesa/desarmar"].basico = true
mecanicas["mesa/desarmar"].desarmarManobra = true
mecanicas["mesa/desarmar"].disputa = "forca"
Execucao.BASICOS = table.freeze({ "mesa/ataque-basico", "mesa/ataque-a-distancia" })
Execucao.MECANICAS = table.freeze(mecanicas)

-- Atributo-chave da árvore ("Intelecto" → intelecto). "Força ou Agilidade" usa
-- o maior dos dois (adaptação: o livro deixa o jogador escolher a arma/estilo).
local ATRIBUTO = {
	["Força"] = "forca",
	["Agilidade"] = "agilidade",
	["Vigor"] = "vigor",
	["Intelecto"] = "intelecto",
	["Espírito"] = "espirito",
}

function Execucao.atributoChave(rotulo: string?, atributos): number
	local melhor = nil
	for nome in string.gmatch(rotulo or "", "[^%s]+") do
		local chave = ATRIBUTO[nome]
		if chave then
			local valor = atributos[chave] or 0
			melhor = if melhor then math.max(melhor, valor) else valor
		end
	end
	return melhor or 0
end

-- BC da árvore: atributo-chave + Bônus de Rank do maior rank aberto nela.
function Execucao.bc(ficha2, arvore: string?, catalogo): number
	if not arvore then
		return 0
	end
	local entrada = catalogo.POR_ID["tree/" .. Progressao.segmento(arvore)]
	local rotulo = entrada and entrada.data.keyAttributeLabel
	local rank = Progressao.maiorRank(ficha2.construction, arvore)
	return Execucao.atributoChave(rotulo, ficha2.calculated.attributes) + (if rank then Regras.bonusDeRank[rank] else 0)
end

-- Árvore local de um id de habilidade ("ability/fogo/Principiante/brasa" → "fogo").
function Execucao.arvoreDe(id: string): string?
	return string.match(id, "^%a+/([^/]+)/")
end

-- Habilidades executáveis que a ficha conhece, na ordem do catálogo.
function Execucao.habilidadesDe(ficha2, catalogo): { string }
	local lista = {}
	if not ficha2 or not ficha2.construction then
		return lista
	end
	local conhecidas = Progressao.conhecidas(ficha2.construction, catalogo)
	for _, rankId in ficha2.construction.unlockedRankIds do
		local rank = catalogo.POR_ID[rankId]
		for _, id in (rank and rank.data.abilities) or {} do
			if (Execucao.MECANICAS[id] or Execucao.INDISPONIVEIS[id]) and table.find(conhecidas, id) and not table.find(lista, id) then
				table.insert(lista, id)
			end
		end
	end
	return lista
end

-- Árvore de corpo de maior rank aberto (a que dá o atributo e o Dado de Arma do
-- ataque básico). Empate: a primeira na ordem do catálogo. nil sem árvore de corpo.
function Execucao.arvoreDeCorpo(ficha2, catalogo): string?
	local melhor, indice = nil, 0
	for _, rankId in ficha2.construction.unlockedRankIds do
		local rank = catalogo.POR_ID[rankId]
		local arvore = rank and catalogo.POR_ID["tree/" .. rank.data.treeId]
		if arvore and arvore.data.category == "corpo" then
			local i = table.find(Regras.ordemDosRanks, rank.data.rank) or 0
			if i > indice then
				melhor, indice = rank.data.treeId, i
			end
		end
	end
	return melhor
end

-- Bônus de Rank do maior rank aberto numa árvore.
function Execucao.bonusDeRankDa(ficha2, arvore: string?): number
	if not arvore then
		return 0
	end
	local rank = Progressao.maiorRank(ficha2.construction, arvore)
	return if rank then Regras.bonusDeRank[rank] else 0
end

-- Atributo do golpe com arma (combatWeapon `atributoDaArma`): Deus da Água usa
-- Agilidade; Deus do Norte e Cavalaria, o atributo-chave da árvore; senão o
-- atributo da arma; sem arma, Força.
function Execucao.atributoDaArma(arvore: string?, atributoDoItem: string?, ficha2, catalogo): number
	local atributos = ficha2.calculated.attributes
	if arvore == "deus-da-agua-corpo" then
		return atributos.agilidade or 0
	end
	if arvore == "deus-do-norte" or arvore == "cavalaria-e-escudos" then
		local entrada = catalogo.POR_ID["tree/" .. arvore]
		return Execucao.atributoChave(entrada and entrada.data.keyAttributeLabel, atributos)
	end
	return atributos[atributoDoItem or "forca"] or 0
end

-- Bandeiras do conjurador vindas de maestrias, para a habilidade da árvore dada:
-- Chama Viva (Fogo): dano cheio contra Em Chamas; Brisa (Vento): um dado a mais
-- contra Desequilibrado em toda magia de Vento.
function Execucao.bandeiras(ficha2, arvore: string?): { [string]: any }
	local vento = arvore == "vento" and Progressao.rankAberto(ficha2.construction, "vento", "Principiante")
	return {
		danoCheioEmChamas = arvore == "fogo" and Fogo.danoCheioEmChamas(ficha2),
		dadoExtraContra = if vento then "desequilibrado" else nil,
	}
end

return Execucao
