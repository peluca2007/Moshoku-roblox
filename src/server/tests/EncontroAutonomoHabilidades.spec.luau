-- SOMENTE STUDIO: usa o catálogo canônico da hierarquia Roblox.
local Habilidade = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoHabilidades)
local Fogo = require(game:GetService("ReplicatedStorage").Shared.Regras.Fogo)
local Catalogo = require(game:GetService("ReplicatedStorage").Shared.Livro.Catalogo)

local function montarAtacante(arvore)
	return {
		id = "jogador:1", kind = "jogador", x = 10, z = 10, pv = 20, pvMax = 20,
		ficha = {
			construction = {
				unlockedRankIds = { "rank/" .. arvore .. "/Principiante" },
				purchasedIds = {},
			},
			calculated = { attributes = { inteligencia = 3 } },
		},
	}
end

local function montarAlvo(defesas)
	return {
		id = "criatura:1", kind = "criatura", x = 10, z = 15, pv = 30, ca = 10,
		fichaCriatura = { resistencias = defesas or {}, imunidades = {} },
	}
end

local function montarClarao()
	local atacante = montarAtacante("fogo")
	local clarao = "ability/fogo/Principiante/clarao"
	atacante.ficha.construction.purchasedIds = { clarao }
	atacante.pm = 1
	local aliado = { id = "jogador:2", kind = "jogador", x = 12, z = 10, pv = 12, pvMax = 12,
		ficha = { calculated = { attributes = { vigor = 0 }, highestRankBonus = 0 } } }
	local criatura = { id = "criatura:1", kind = "criatura", x = 13, z = 10, pv = 10, ca = 10,
		fichaCriatura = { bonusAtaque = 4, resistencias = {}, imunidades = {} } }
	local fora = { id = "criatura:2", kind = "criatura", x = 15, z = 10, pv = 10,
		fichaCriatura = { bonusAtaque = 0 } }
	return atacante, { atacante, aliado, criatura, fora }, aliado, criatura
end

return {
	["Sopro de Poeira exige compra de Vento, direciona cone e resolve resistência sem dano"] = function(t)
		local id = Habilidade.SOPRO_DE_POEIRA
		local atacante = montarAtacante("vento")
		local mecanica = Habilidade.mecanica(id)
		t.eq(mecanica.alvo, "cone")
		t.eq(mecanica.comprimentoCasas, 4)
		t.eq(mecanica.acoes, 1)
		t.eq(mecanica.pm, 1)
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil, "sem compra, não aparece")
		atacante.ficha.construction.purchasedIds = { id }
		atacante.pm = 1
		t.eq(table.find(Habilidade.disponiveis(atacante), id) ~= nil, true)
		local previa = Habilidade.preverSoproDePoeira(atacante, 10, 11)
		t.eq(previa.targetId, "sopro-poeira:10:11")
		local casas = {}
		for _, celula in ipairs(previa.cells) do casas[tostring(celula.x) .. ":" .. tostring(celula.z)] = true end
		t.eq(casas["10:14"], true, "a direção cobre casas até o alcance")
		t.eq(Habilidade.preverSoproDePoeira(atacante, 10, 15), nil, "direção acima do alcance é recusada")
		local alvo = { id = "criatura:1", kind = "criatura", x = 10, z = 14, pv = 30, ca = 10,
			fichaCriatura = { bonusAtaque = 4, resistencias = {}, imunidades = {} } }
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then minimo else maximo end }
		local resultado, erro = Habilidade.usarSoproDePoeira(rng, atacante, { atacante, alvo }, previa.targetId,
			nil, nil, 1, Catalogo)
		t.eq(erro, nil)
		t.eq(#resultado.targets, 1)
		t.eq(resultado.targets[1].resistance.passou, false)
		t.eq(table.find(resultado.targets[1].applies, "cego") ~= nil, true)
		t.eq(table.find(resultado.targets[1].applies, "desequilibrado") ~= nil, true)
		t.eq(resultado.pmCost, 1)
		t.eq(resultado.damageDealt, nil, "não causa dano")
	end,
	["Passo de Vento deriva custo, alcance e destinos livres sem terreno difícil"] = function(t)
		local id = Habilidade.PASSO_DE_VENTO
		local atacante = montarAtacante("vento")
		local mecanica = Habilidade.mecanica(id)
		t.eq(mecanica.acoes, 2)
		t.eq(mecanica.pm, 2)
		t.eq(mecanica.alcanceCasas, 12)
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil, "sem compra, não aparece")
		atacante.ficha.construction.purchasedIds = { id }
		atacante.pm = 2
		atacante.x, atacante.z = 2, 2
		local previa = Habilidade.preverPassoDeVento(atacante, 2, 10, { atacante }, {})
		t.eq(previa.houses, 8)
		local resultado, erro = Habilidade.criarPassoDeVento(atacante, previa.targetId, { atacante }, {})
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 2)
		t.eq(resultado.from.x, 2)
		t.eq(resultado.to.z, 10)
		t.eq(#resultado.route, 8)
		t.eq(Habilidade.preverPassoDeVento(atacante, 2, 2, { atacante }, {}), nil, "não permite permanecer")
		t.eq(Habilidade.preverPassoDeVento(atacante, 20, 20, { atacante }, {}), nil, "não excede alcance")
		local ocupante = { id = "outro", x = 2, z = 4 }
		t.eq(Habilidade.preverPassoDeVento(atacante, 2, 4, { atacante, ocupante }, {}), nil, "não ocupa outra peça")
		atacante.pm = 1
		t.eq(Habilidade.criarPassoDeVento(atacante, previa.targetId, { atacante }, {}), nil, "revalida PM")
	end,
	["Vácuo Localizado aplica sufocamento/silêncio sem teste no mesmo patamar e testa acima"] = function(t)
		local id = Habilidade.VACUO_LOCALIZADO
		local atacante = montarAtacante("vento")
		atacante.ficha.construction.purchasedIds = { id }
		atacante.pm = 4
		local mecanica = Habilidade.mecanica(id)
		t.eq(mecanica.alcanceCasas, 6)
		t.eq(mecanica.acoes, 2)
		t.eq(mecanica.pm, 2)
		t.eq(mecanica.naoConsecutivo, true)
		local alvo = { id = "criatura:1", kind = "criatura", x = 10, z = 12, pv = 30, ca = 10, respira = true,
			fichaCriatura = { patamar = 1, bonusAtaque = 0, resistencias = {}, imunidades = {} } }
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then minimo else minimo end }
		local igual, erro = Habilidade.usar(rng, id, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(igual.resistance, nil, "igual patamar não testa")
		t.eq(igual.damageDealt, 1, "1d6 de sufocamento no teste determinístico")
		t.eq(igual.states[1].nome, "silenciado")
		alvo.fichaCriatura.patamar = 2
		local maior, erroMaior = Habilidade.usar(rng, id, atacante, alvo, Catalogo)
		t.eq(erroMaior, nil)
		t.eq(maior.resistance.passou, false, "patamar maior resiste")
		alvo.respira = false
		local naoRespira, erroNaoRespira = Habilidade.usar(rng, id, atacante, alvo, Catalogo)
		t.eq(erroNaoRespira, nil)
		t.eq(naoRespira.damageDealt, 0)
		t.eq(#naoRespira.states, 0)
	end,
	["Escudo de Água exige compra, rank, recursos e linha transversal de duas casas"] = function(t)
		local id = Habilidade.ESCUDO_DE_AGUA
		local atacante = montarAtacante("agua")
		local mecanica = Habilidade.mecanica(id)
		t.eq(mecanica.acoes, 2)
		t.eq(mecanica.pm, 2)
		t.eq(mecanica.alcanceCasas, 4)
		t.eq(mecanica.comprimentoCasas, 2)
		t.eq(mecanica.duracaoRodadas, 2)
		t.eq(mecanica.cobertura, 5)
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil)
		atacante.ficha.construction.purchasedIds, atacante.pm = { id }, 2
		local desenho = Habilidade.preverEscudoDeAgua(atacante, 12, 10)
		t.eq(#desenho.cells, 2)
		t.eq(desenho.cells[1].x, 12)
		t.eq(desenho.cells[2].x, 12)
		local resultado, erro = Habilidade.criarEscudoDeAgua(atacante, desenho.targetId)
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 2)
		t.eq(resultado.coverage, 5)
		t.eq(resultado.reduzIgneo, true)
		atacante.pm = 1
		t.eq(Habilidade.criarEscudoDeAgua(atacante, desenho.targetId), nil, "PM insuficiente")
		atacante.pm = 2
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(Habilidade.criarEscudoDeAgua(atacante, desenho.targetId), nil, "rank bloqueado")
	end,
	["Dardo Arcano usa a mecânica canônica e exige rank Teórica com compra"] = function(t)
		local id = "ability/teorica/Principiante/dardo-arcano"
		local atacante = montarAtacante("teorica")
		local mecanica = Habilidade.mecanica(id)
		t.eq(mecanica.acoes, 2)
		t.eq(mecanica.pm, 1)
		t.eq(mecanica.alcanceCasas, 6)
		t.eq(mecanica.partes[1].dados, "1d8")
		t.eq(mecanica.partes[1].tipo, "arcano")
		t.eq(mecanica.partes[1].bc, true)
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil, "sem compra não aparece")
		atacante.ficha.construction.purchasedIds = { id }
		atacante.pm = 1
		t.eq(table.find(Habilidade.disponiveis(atacante), id) ~= nil, true)
		local rng = { NextInteger = function(_, _, maximo) return maximo end }
		local resultado, erro = Habilidade.usar(rng, id, atacante, montarAlvo(), Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 1)
		t.eq(resultado.damageDealt > 0, true)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil, "rank bloqueado")
	end,
	["Névoa Densa exige compra/rank e cria círculo canônico centrado no conjurador"] = function(t)
		local id = Habilidade.NEVOA_DENSA
		local atacante = montarAtacante("agua")
		local mecanica = Habilidade.mecanica(id)
		t.eq(mecanica.acoes, 2)
		t.eq(mecanica.pm, 1)
		t.eq(mecanica.raioCasas, 4)
		t.eq(mecanica.duracaoRodadas, 50)
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil)
		atacante.ficha.construction.purchasedIds, atacante.pm = { id }, 1
		local resultado, erro = Habilidade.criarNevoaDensa(atacante)
		t.eq(erro, nil)
		t.eq(resultado.targetId, atacante.id)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 1)
		t.eq(resultado.radiusHouses, 4)
		t.eq(resultado.durationRounds, 50)
		t.eq(#resultado.cells, 49)
		local centro, borda, fora = false, false, false
		for _, celula in ipairs(resultado.cells) do
			if celula.x == 10 and celula.z == 10 then centro = true end
			if celula.x == 14 and celula.z == 10 then borda = true end
			if celula.x == 15 and celula.z == 10 then fora = true end
		end
		t.eq(centro, true)
		t.eq(borda, true)
		t.eq(fora, false)
		atacante.pm = 0
		t.eq(Habilidade.criarNevoaDensa(atacante), nil, "PM insuficiente")
	end,
	["Lança de Pedra valida lista canônica e compra antes de rolar"] = function(t)
		local id = Habilidade.LANCA_DE_PEDRA
		local atacante = montarAtacante("terra")
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil)
		atacante.ficha.construction.purchasedIds, atacante.pm = { id }, 2
		t.eq(table.find(Habilidade.disponiveis(atacante), id) ~= nil, true)
		t.eq(Habilidade.codificarLista({ "b", "a" }), "lista:a,b")
		for _, texto in ipairs({ "lista:", "lista:b,a", "lista:a,a", "lista:a,", "lista:a,b,c,d", "lista:a b", "lista:" .. string.rep("x", 91) }) do
			t.eq(Habilidade.decodificarLista(texto), nil, texto)
		end
		local rng = { NextInteger = function() error("não deve rolar para lista inválida") end }
		local primeiro, fora = montarAlvo(), montarAlvo()
		fora.id, fora.z = "criatura:2", 17
		t.eq(Habilidade.usarLancaDePedra(rng, atacante, { primeiro, fora }, Catalogo), nil)
		t.eq(Habilidade.usarLancaDePedra(rng, atacante, { primeiro, primeiro }, Catalogo), nil)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(Habilidade.usarLancaDePedra(rng, atacante, { primeiro }, Catalogo), nil)
	end,
	["Lança de Pedra resolve até três resistências individuais sem dano no sucesso"] = function(t)
		local atacante = montarAtacante("terra")
		atacante.ficha.construction.purchasedIds, atacante.pm = { Habilidade.LANCA_DE_PEDRA }, 2
		atacante.ficha.calculated.attributes = { intelecto = 4 }
		local a, b, c = montarAlvo(), montarAlvo(), montarAlvo()
		a.id, b.id, c.id, c.z = "a", "b", "c", 16
		local dados = { 1, 3, 4, 20, 1, 2, 2 }
		local rng = { NextInteger = function() return table.remove(dados, 1) end }
		local resultado, erro = Habilidade.usarLancaDePedra(rng, atacante, { a, b, c }, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 2)
		t.eq(#resultado.targets, 3)
		t.eq(resultado.targets[1].resistance.cd, 13, "CD 8 + BC de Terra")
		t.eq(resultado.targets[1].damageDealt, 7, "2d6, sem somar BC")
		t.eq(resultado.targets[1].applies[1], "atolado")
		t.eq(resultado.targets[2].resistance.passou, true)
		t.eq(resultado.targets[2].damageDealt, 0)
		t.eq(#resultado.targets[2].applies, 0)
		t.eq(resultado.targets[3].damageDealt, 4)
		t.eq(#dados, 0)
	end,
	["Muro de Terra valida compra, alcance, linha transversal e 40 PV"] = function(t)
		local atacante = montarAtacante("terra")
		local id = Habilidade.MURO_DE_TERRA
		local mecanica = Habilidade.mecanica(id)
		t.eq(mecanica.acoes, 3)
		t.eq(mecanica.pm, 2)
		t.eq(mecanica.comprimentoCasas, 4)
		t.eq(mecanica.alcanceCasas, 6)
		t.eq(mecanica.duracaoRodadas, 100)
		t.eq(mecanica.pvZona, 40)
		t.eq(table.find(Habilidade.disponiveis(atacante), id), nil)
		atacante.ficha.construction.purchasedIds, atacante.pm = { id }, 2
		local desenho = Habilidade.preverMuroDeTerra(atacante, 14, 10)
		t.eq(#desenho.cells, 4)
		t.eq(desenho.cells[1].x, 14)
		t.eq(desenho.cells[1].z, 9)
		t.eq(desenho.cells[4].z, 12)
		local resultado, erro = Habilidade.criarMuroDeTerra(atacante, desenho.targetId)
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 3)
		t.eq(resultado.pmCost, 2)
		t.eq(resultado.durationRounds, 100)
		t.eq(resultado.zonePv, 40)
		t.eq(#resultado.cells, 4)
		t.eq(Habilidade.criarMuroDeTerra(atacante, "muro-terra:17:10"), nil)
		t.eq(Habilidade.preverMuroDeTerra(atacante, 14, 10, { { x = 14, z = 9 } }), nil,
			"a parede não pode sobrepor terreno bloqueado")
		t.eq(Habilidade.preverMuroDeTerra(atacante, 14, 10, { { x = 12, z = 10 } }, {}, 1), nil,
			"o centro precisa estar visível ao conjurador")
	end,
	["Muro de Terra recusa linha fora do tabuleiro e rank não comprado"] = function(t)
		local atacante = montarAtacante("terra")
		t.eq(Habilidade.preverMuroDeTerra(atacante, 10, 3), nil, "linha transversal sairia da grade")
		atacante.ficha.construction.purchasedIds, atacante.pm = { Habilidade.MURO_DE_TERRA }, 2
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(Habilidade.criarMuroDeTerra(atacante, "muro-terra:14:10"), nil)
	end,
	["Atoleiro exige compra e rank, centra a esfera na fonte e cria 100 rodadas"] = function(t)
		local habilidade = Habilidade.ATOLEIRO
		local atacante = montarAtacante("terra")
		atacante.ficha.calculated.attributes = { intelecto = 4 }
		t.eq(table.find(Habilidade.disponiveis(atacante), habilidade), nil)
		atacante.ficha.construction.purchasedIds, atacante.pm = { habilidade }, 2
		t.ok(table.find(Habilidade.disponiveis(atacante), habilidade) ~= nil)
		local dentro = montarAlvo()
		dentro.id, dentro.x, dentro.z = "dentro", 12, 10
		local borda = montarAlvo()
		borda.id, borda.x, borda.z = "borda", 14, 10
		local fora = montarAlvo()
		fora.id, fora.x, fora.z = "fora", 15, 10
		local rng = { NextInteger = function(_, minimo) return minimo end }
		local resultado, erro = Habilidade.usarAtoleiro(rng, atacante, { atacante, dentro, borda, fora }, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 2)
		t.eq(resultado.center.x, atacante.x)
		t.eq(resultado.center.z, atacante.z)
		t.eq(resultado.radiusHouses, 4)
		t.eq(resultado.zone.durationRounds, 100)
		t.eq(#resultado.zone.cells, 49)
		t.eq(#resultado.targets, 2, "apenas criaturas dentro da esfera, sem atingir a fonte")
		t.eq(resultado.targets[1].resistance.cd, 13)
		t.eq(resultado.targets[1].applies[1], "atolado")
		t.eq(resultado.targets[2].actorId, "borda")
		t.eq(Habilidade.celulasAtoleiro(1, 1)[1].x, 1, "esfera é recortada pelo limite da grade")
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(Habilidade.usarAtoleiro(rng, atacante, { dentro }, Catalogo), nil)
	end,
	["Atoleiro registra resistência individual e sucesso evita Atolado"] = function(t)
		local atacante = montarAtacante("terra")
		atacante.ficha.construction.purchasedIds = { Habilidade.ATOLEIRO }
		atacante.ficha.calculated.attributes = { intelecto = 4 }
		atacante.pm = 2
		local alvo = montarAlvo()
		alvo.x, alvo.z = 11, 10
		local resultado, erro = Habilidade.usarAtoleiro({ NextInteger = function(_, _, maximo) return maximo end },
			atacante, { atacante, alvo }, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.targets[1].resistance.passou, true)
		t.eq(#resultado.targets[1].applies, 0)
		t.eq(resultado.targets[1].damageDealt, nil, "Atoleiro não causa dano")
	end,
	["Bala de Pedra exige compra e rank de Terra"] = function(t)
		local bala = "ability/terra/Principiante/bala-de-pedra"
		local atacante = montarAtacante("terra")
		t.eq(table.find(Habilidade.disponiveis(atacante), bala), nil)
		atacante.ficha.construction.purchasedIds = { bala }
		t.eq(table.find(Habilidade.disponiveis(atacante), bala) ~= nil, true)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), bala), nil)
		local recusado = Habilidade.usar({ NextInteger = function(_, minimo) return minimo end },
			bala, atacante, montarAlvo(), Catalogo)
		t.eq(recusado, nil, "compra sem o rank não libera Bala de Pedra")
	end,
	["Bala de Pedra usa BC de Terra e acerta Atolado sem crítico natural"] = function(t)
		local bala = "ability/terra/Principiante/bala-de-pedra"
		local atacante, alvo = montarAtacante("terra"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { bala }
		atacante.ficha.calculated.attributes = { intelecto = 4 }
		table.insert(atacante.ficha.construction.unlockedRankIds, Fogo.RANK_PRINCIPIANTE)
		table.insert(atacante.ficha.construction.unlockedRankIds, "rank/fogo/Intermedi%C3%B3rio")
		atacante.pm = 1
		alvo.condicoes = { atolado = true }
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 1 else maximo end }
		local resultado, erro = Habilidade.usar(rng, bala, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.attack.bonus, 5, "BC usa Intelecto e Principiante de Terra")
		t.eq(resultado.attack.d20.natural, 1)
		t.eq(resultado.attack.acertou, true)
		t.eq(resultado.attack.critico, false, "Atolado não transforma 1 natural em crítico")
		t.eq(resultado.damageDealt, 15, "1d10 máximo + BC 5")
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 1)
		t.ok(table.find(resultado.notes, "Alvo Atolado: qualquer resultado acerta; só 20 natural é crítico") ~= nil)
		local critico = Habilidade.usar({ NextInteger = function(_, minimo, maximo)
			return if maximo == 20 then 20 else maximo
		end }, bala, atacante, alvo, Catalogo)
		t.eq(critico.attack.acertou, true)
		t.eq(critico.attack.critico, true, "20 natural continua crítico contra Atolado")
	end,
	["Bala de Pedra mantém alcance de dezoito casas e erro sem Atolado"] = function(t)
		local bala = "ability/terra/Principiante/bala-de-pedra"
		local atacante, alvo = montarAtacante("terra"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { bala }
		atacante.pm = 1
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 1 else maximo end }
		alvo.z = 28
		local resultado, erro = Habilidade.usar(rng, bala, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.distance, 18)
		t.eq(resultado.attack.acertou, false)
		t.eq(resultado.damageDealt, 0)
		t.eq(Habilidade.mecanica(bala).alcanceCasas, 18)
		alvo.z = 29
		local recusado, erroLonge = Habilidade.usar(rng, bala, atacante, alvo, Catalogo)
		t.eq(recusado, nil)
		t.ok(type(erroLonge) == "string")
	end,
	["Pedrisco vem com Principiante de Terra sem compra e exige essa escola"] = function(t)
		local pedrisco = "ability/terra/Principiante/pedrisco"
		local atacante = montarAtacante("terra")
		t.eq(#atacante.ficha.construction.purchasedIds, 0)
		t.eq(table.find(Habilidade.disponiveis(atacante), pedrisco) ~= nil, true)
		t.eq(table.find(Habilidade.disponiveis(montarAtacante("fogo")), pedrisco), nil)
		local recusado, erro = Habilidade.usar({ NextInteger = function(_, minimo) return minimo end },
			pedrisco, montarAtacante("fogo"), montarAlvo(), Catalogo)
		t.eq(recusado, nil)
		t.ok(type(erro) == "string")
		atacante.ficha.construction.unlockedRankIds = {}
		atacante.ficha.construction.purchasedIds = { pedrisco }
		t.eq(table.find(Habilidade.disponiveis(atacante), pedrisco), nil,
			"compra isolada não abre a escola")
	end,
	["Pedrisco usa BC de Terra e custo/dano contundente canônicos"] = function(t)
		local pedrisco = "ability/terra/Principiante/pedrisco"
		local atacante = montarAtacante("terra")
		atacante.ficha.calculated.attributes = { intelecto = 4 }
		-- Fogo tem rank maior para detectar BC incorreto ou fixado em outra árvore.
		table.insert(atacante.ficha.construction.unlockedRankIds, Fogo.RANK_PRINCIPIANTE)
		table.insert(atacante.ficha.construction.unlockedRankIds, "rank/fogo/Intermedi%C3%A1rio")
		atacante.pm = 0
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 10 else maximo end }
		local resultado, erro = Habilidade.usar(rng, pedrisco, atacante, montarAlvo(), Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.attack.bonus, 5, "Intelecto 4 + Principiante 1 de Terra")
		t.eq(resultado.attack.critico, false)
		t.eq(resultado.damageDealt, 11, "1d6 máximo + BC 5")
		t.eq(resultado.actionsCost, 1)
		t.eq(resultado.pmCost, 0)
		t.eq(Habilidade.mecanica(pedrisco).umaVezPorTurno, true)
		t.eq(Habilidade.mecanica(pedrisco).partes[1].tipo, "contundente")
		local resistente = Habilidade.usar(rng, pedrisco, atacante, montarAlvo({ "contundente" }), Catalogo)
		t.ok(resistente.damageDealt < resultado.damageDealt)
	end,
	["Pedrisco aceita seis casas e recusa além do alcance canônico"] = function(t)
		local pedrisco = "ability/terra/Principiante/pedrisco"
		local atacante, alvo = montarAtacante("terra"), montarAlvo()
		local rng = { NextInteger = function(_, minimo) return minimo end }
		alvo.z = 16
		local resultado, erro = Habilidade.usar(rng, pedrisco, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.distance, 6)
		t.eq(Habilidade.mecanica(pedrisco).alcanceCasas, 6)
		alvo.z = 17
		local recusado, erroLonge = Habilidade.usar(rng, pedrisco, atacante, alvo, Catalogo)
		t.eq(recusado, nil)
		t.ok(type(erroLonge) == "string")
	end,
	["Rajada Curta vem com Principiante de Vento sem compra e exige essa escola"] = function(t)
		local rajada = "ability/vento/Principiante/rajada-curta"
		local atacante = montarAtacante("vento")
		t.eq(#atacante.ficha.construction.purchasedIds, 0)
		t.eq(table.find(Habilidade.disponiveis(atacante), rajada) ~= nil, true)
		t.eq(table.find(Habilidade.disponiveis(montarAtacante("fogo")), rajada), nil)
		local rng = { NextInteger = function(_, minimo) return minimo end }
		local recusado, erro = Habilidade.usar(rng, rajada, montarAtacante("fogo"), montarAlvo(), Catalogo)
		t.eq(recusado, nil)
		t.ok(type(erro) == "string")
		atacante.ficha.construction.unlockedRankIds = {}
		atacante.ficha.construction.purchasedIds = { rajada }
		t.eq(table.find(Habilidade.disponiveis(atacante), rajada), nil, "compra isolada não abre a escola")
	end,
	["Rajada Curta usa BC de Vento e dano cortante canônico sem PM"] = function(t)
		local rajada = "ability/vento/Principiante/rajada-curta"
		local atacante = montarAtacante("vento")
		atacante.ficha.calculated.attributes = { intelecto = 4 }
		-- Fogo tem rank maior para detectar regressão ao BC fixado na árvore errada.
		table.insert(atacante.ficha.construction.unlockedRankIds, Fogo.RANK_PRINCIPIANTE)
		table.insert(atacante.ficha.construction.unlockedRankIds, "rank/fogo/Intermedi%C3%A1rio")
		atacante.pm = 0
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 10 else maximo end }
		local resultado, erro = Habilidade.usar(rng, rajada, atacante, montarAlvo(), Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.attack.bonus, 5, "Intelecto 4 + Principiante 1 de Vento")
		t.eq(resultado.attack.critico, false)
		t.eq(resultado.damageDealt, 11, "1d6 máximo + BC 5")
		t.eq(resultado.actionsCost, 1)
		t.eq(resultado.pmCost, 0)
		t.eq(Habilidade.mecanica(rajada).umaVezPorTurno, true)
		local resistente = Habilidade.usar(rng, rajada, atacante, montarAlvo({ "cortante" }), Catalogo)
		t.ok(resistente.damageDealt < resultado.damageDealt)
	end,
	["Rajada Curta aceita seis casas e recusa além do alcance canônico"] = function(t)
		local rajada = "ability/vento/Principiante/rajada-curta"
		local atacante, alvo = montarAtacante("vento"), montarAlvo()
		local rng = { NextInteger = function(_, minimo) return minimo end }
		alvo.z = 16
		local resultado, erro = Habilidade.usar(rng, rajada, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.distance, 6)
		t.eq(Habilidade.mecanica(rajada).alcanceCasas, 6)
		alvo.z = 17
		local recusado, erroLonge = Habilidade.usar(rng, rajada, atacante, alvo, Catalogo)
		t.eq(recusado, nil)
		t.ok(type(erroLonge) == "string")
	end,
	["Lâmina de Vento exige compra e o rank de Vento"] = function(t)
		local lamina = "ability/vento/Principiante/lamina-de-vento"
		local atacante = montarAtacante("vento")
		t.eq(table.find(Habilidade.disponiveis(atacante), lamina), nil)
		t.eq(Habilidade.mecanica(lamina).pm, 1)
		atacante.ficha.construction.purchasedIds = { lamina }
		t.eq(table.find(Habilidade.disponiveis(atacante), lamina) ~= nil, true)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), lamina), nil)
		local recusado = Habilidade.usar({ NextInteger = function(_, minimo) return minimo end },
			lamina, atacante, montarAlvo(), Catalogo)
		t.eq(recusado, nil, "compra sem o rank não concede acesso")
	end,
	["Lâmina de Vento usa BC, custo, dano e condição canônicos"] = function(t)
		local lamina = "ability/vento/Principiante/lamina-de-vento"
		local atacante, alvo = montarAtacante("vento"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { lamina }
		atacante.ficha.calculated.attributes.intelecto = 4
		atacante.pm = 1
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 10 else maximo end }
		local resultado, erro = Habilidade.usar(rng, lamina, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.attack.bonus, 5, "BC usa Intelecto e o rank de Vento")
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 1)
		t.eq(resultado.damageDealt, 15, "1d10 máximo + BC 5")
		t.eq(table.find(resultado.applies, "desequilibrado") ~= nil, true)
		atacante.pm = 0
		local semPm = Habilidade.usar(rng, lamina, atacante, montarAlvo(), Catalogo)
		t.eq(semPm, nil)
	end,
	["Lâmina de Vento preserva alcance canônico de dezoito casas"] = function(t)
		local lamina = "ability/vento/Principiante/lamina-de-vento"
		local atacante, alvo = montarAtacante("vento"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { lamina }
		atacante.pm = 1
		local rng = { NextInteger = function(_, minimo) return minimo end }
		alvo.z = 28
		local resultado, erro = Habilidade.usar(rng, lamina, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.distance, 18)
		t.eq(Habilidade.mecanica(lamina).alcanceCasas, 18)
		alvo.z = 29
		local fora = Habilidade.usar(rng, lamina, atacante, alvo, Catalogo)
		t.eq(fora, nil)
	end,
	["Respingo exige compra e o rank de Água"] = function(t)
		local respingo = "ability/agua/Principiante/respingo"
		local atacante = montarAtacante("agua")
		t.eq(table.find(Habilidade.disponiveis(atacante), respingo), nil)
		atacante.ficha.construction.purchasedIds = { respingo }
		t.eq(table.find(Habilidade.disponiveis(atacante), respingo) ~= nil, true)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), respingo), nil)
		local recusado = Habilidade.usar({ NextInteger = function(_, minimo) return minimo end },
			respingo, atacante, montarAlvo(), Catalogo)
		t.eq(recusado, nil, "compra sem o rank não concede acesso")
	end,
	["Respingo aplica dano contundente e Molhado uma vez por turno sem PM"] = function(t)
		local respingo = "ability/agua/Principiante/respingo"
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { respingo }
		atacante.ficha.calculated.attributes.intelecto = 4
		atacante.pm = 0
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 10 else maximo end }
		local resultado, erro = Habilidade.usar(rng, respingo, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.attack.bonus, 5, "BC usa Intelecto e o rank de Água")
		t.eq(resultado.actionsCost, 1)
		t.eq(resultado.pmCost, 0)
		t.eq(resultado.damageDealt, 11, "1d6 máximo + BC 5")
		t.eq(table.find(resultado.applies, "molhado") ~= nil, true)
		t.eq(Habilidade.mecanica(respingo).umaVezPorTurno, true)
	end,
	["Respingo preserva alcance de seis casas e recusa a sétima"] = function(t)
		local respingo = "ability/agua/Principiante/respingo"
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { respingo }
		local rng = { NextInteger = function(_, minimo) return minimo end }
		alvo.z = 16
		local resultado, erro = Habilidade.usar(rng, respingo, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.distance, 6)
		alvo.z = 17
		local fora = Habilidade.usar(rng, respingo, atacante, alvo, Catalogo)
		t.eq(fora, nil)
	end,
	["Flecha d’Água exige compra e o rank de Água"] = function(t)
		local flecha = "ability/agua/Principiante/flecha-de-agua"
		local atacante = montarAtacante("agua")
		t.eq(table.find(Habilidade.disponiveis(atacante), flecha), nil)
		atacante.ficha.construction.purchasedIds = { flecha }
		t.eq(table.find(Habilidade.disponiveis(atacante), flecha) ~= nil, true)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), flecha), nil)
		local recusado = Habilidade.usar({ NextInteger = function(_, minimo) return minimo end },
			flecha, atacante, montarAlvo(), Catalogo)
		t.eq(recusado, nil)
	end,
	["Flecha d’Água usa BC, PM, dano e Molhado canônicos"] = function(t)
		local flecha = "ability/agua/Principiante/flecha-de-agua"
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { flecha }
		atacante.ficha.calculated.attributes.intelecto = 4
		atacante.pm = 1
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 10 else maximo end }
		local resultado, erro = Habilidade.usar(rng, flecha, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.attack.bonus, 5, "BC usa Intelecto e o rank de Água")
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 1)
		t.eq(resultado.damageDealt, 13, "1d8 máximo + BC 5")
		t.eq(table.find(resultado.applies, "molhado") ~= nil, true)
		t.eq(Habilidade.mecanica(flecha).duracao.rodadas, 10)
		atacante.pm = 0
		local semPm = Habilidade.usar(rng, flecha, atacante, montarAlvo(), Catalogo)
		t.eq(semPm, nil)
	end,
	["Flecha d’Água preserva alcance 18 e recusa além dele"] = function(t)
		local flecha = "ability/agua/Principiante/flecha-de-agua"
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { flecha }
		atacante.pm = 1
		local rng = { NextInteger = function(_, minimo) return minimo end }
		alvo.z = 28
		local resultado, erro = Habilidade.usar(rng, flecha, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.distance, 18)
		alvo.z = 29
		local fora = Habilidade.usar(rng, flecha, atacante, alvo, Catalogo)
		t.eq(fora, nil)
	end,
	["Bola d’Água exige compra e o rank de Água"] = function(t)
		local bola = "ability/agua/Principiante/bola-de-agua"
		local atacante = montarAtacante("agua")
		t.eq(table.find(Habilidade.disponiveis(atacante), bola), nil)
		atacante.ficha.construction.purchasedIds = { bola }
		t.eq(table.find(Habilidade.disponiveis(atacante), bola) ~= nil, true)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), bola), nil)
	end,
	["Bola d’Água usa mecânica canônica de dano, custo, duração e empurrão"] = function(t)
		local bola = "ability/agua/Principiante/bola-de-agua"
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { bola }
		atacante.ficha.calculated.attributes.intelecto = 4
		atacante.pm = 1
		local rng = { NextInteger = function(_, minimo, maximo) return if maximo == 20 then 10 else maximo end }
		local resultado, erro = Habilidade.usar(rng, bola, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 1)
		t.eq(resultado.attack.bonus, 5, "BC usa Intelecto e o rank Principiante de Água")
		t.eq(resultado.damageDealt, 11, "1d6 máximo + BC canônico")
		t.eq(table.find(resultado.applies, "molhado") ~= nil, true)
		t.eq(resultado.pushHouses, 1)
		t.eq(Habilidade.mecanica(bola).duracao.rodadas, 10)
		t.eq(Habilidade.mecanica(bola).alcanceCasas, 12)
	end,
	["Bola d’Água mantém alcance 12 e recusa a décima terceira casa"] = function(t)
		local bola = "ability/agua/Principiante/bola-de-agua"
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { bola }
		atacante.pm = 1
		local rng = { NextInteger = function(_, minimo) return minimo end }
		alvo.z = 22
		local resultado, erro = Habilidade.usar(rng, bola, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.distance, 12)
		alvo.z = 23
		t.eq(Habilidade.usar(rng, bola, atacante, alvo, Catalogo), nil)
	end,
	["Impacto de Gelo exige compra e o rank de Água"] = function(t)
		local impacto = "ability/agua/Principiante/impacto-de-gelo"
		local atacante = montarAtacante("agua")
		t.eq(table.find(Habilidade.disponiveis(atacante), impacto), nil)
		atacante.ficha.construction.purchasedIds = { impacto }
		t.eq(table.find(Habilidade.disponiveis(atacante), impacto) ~= nil, true)
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), impacto), nil)
	end,
	["Impacto de Gelo usa alcance, custos, dano sempre e redução canônicos"] = function(t)
		local impacto = "ability/agua/Principiante/impacto-de-gelo"
		local mecanica = Habilidade.mecanica(impacto)
		t.eq(mecanica.alcanceCasas, 12)
		t.eq(mecanica.acoes, 2)
		t.eq(mecanica.pm, 2)
		t.eq(mecanica.danoSempre, true)
		t.eq(mecanica.resistencia.atributo, "agilidade")
		t.eq(mecanica.estados[1].nome, "reduzMovimento")
		t.eq(mecanica.estados[1].valor, 2)
		t.eq(mecanica.estados[1].duracao.de, "alvo")
	end,
	["resistência de criatura usa metade do bônus de ataque arredondada para cima"] = function(t)
		local impacto = "ability/agua/Principiante/impacto-de-gelo"
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { impacto }
		atacante.pm = 2
		alvo.fichaCriatura.bonusAtaque = 7
		local resultado, erro = Habilidade.usar({ NextInteger = function(_, _, maximo) return maximo end },
			impacto, atacante, alvo, Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.resistance.bonus, 4)
		t.eq(resultado.resistance.passou, true)
		t.eq(#resultado.states, 0, "sucesso não aplica a redução")
	end,
	["Empurrão exige compra e rank de Vento e preserva custo/alcance canônicos"] = function(t)
		local habilidade = "ability/vento/Principiante/empurrao"
		local atacante = montarAtacante("vento")
		t.eq(table.find(Habilidade.disponiveis(atacante), habilidade), nil)
		atacante.ficha.construction.purchasedIds = { habilidade }
		t.eq(table.find(Habilidade.disponiveis(atacante), habilidade) ~= nil, true)
		local mecanica = Habilidade.mecanica(habilidade)
		t.eq(mecanica.acoes, 2)
		t.eq(mecanica.pm, 1)
		t.eq(mecanica.alcanceCasas, 12)
		t.eq(mecanica.empurraCasas, 4)
		t.eq(mecanica.resistencia.atributo, "forca")
		atacante.ficha.construction.unlockedRankIds = {}
		t.eq(table.find(Habilidade.disponiveis(atacante), habilidade), nil)
	end,
	["somente personagem que abriu Fogo recebe Brasa"] = function(t)
		local habilidades = Habilidade.disponiveis(montarAtacante("fogo"))
		t.eq(habilidades[1], "ability/fogo/Principiante/brasa")
		t.eq(habilidades[2], "mesa/defender")
		t.eq(Habilidade.disponiveis(montarAtacante("agua"))[1], "mesa/defender")
	end,
	["Brasa usa alcance, BC, dano ígneo e crítico do resolvedor comum"] = function(t)
		local rng = { NextInteger = function(_, _, maximo) return maximo end }
		local resultado, erro = Habilidade.usarBrasa(rng, montarAtacante("fogo"), montarAlvo(), Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.abilityId, "ability/fogo/Principiante/brasa")
		t.eq(resultado.attack.critico, true)
		t.ok(resultado.damageDealt > 0)
		t.eq(resultado.targetPv, 30 - resultado.damageDealt)
	end,
	["Brasa respeita resistência e imunidade ígneas"] = function(t)
		local rng = { NextInteger = function(_, _, maximo) return maximo end }
		local resistente = Habilidade.usarBrasa(rng, montarAtacante("fogo"), montarAlvo({ "ígneo" }), Catalogo)
		local imuneAlvo = montarAlvo()
		imuneAlvo.fichaCriatura.imunidades = { "ígneo" }
		local imune = Habilidade.usarBrasa(rng, montarAtacante("fogo"), imuneAlvo, Catalogo)
		t.ok(resistente.damageDealt > 0)
		t.ok(resistente.damageDealt < imuneAlvo.pv)
		t.eq(imune.damageDealt, 0)
	end,
	["recusa árvore alheia e alvo além de seis casas"] = function(t)
		local rng = { NextInteger = function(_, minimo) return minimo end }
		local alheio, erroAlheio = Habilidade.usarBrasa(rng, montarAtacante("agua"), montarAlvo(), Catalogo)
		t.eq(alheio, nil)
		t.ok(type(erroAlheio) == "string")
		local alvo = montarAlvo()
		alvo.z = 17
		local fora, erroFora = Habilidade.usarBrasa(rng, montarAtacante("fogo"), alvo, Catalogo)
		t.eq(fora, nil)
		t.ok(type(erroFora) == "string")
	end,
	["Fagulha só é exposta quando comprada e respeita PM e alcance"] = function(t)
		local fagulha = "ability/fogo/Principiante/fagulha"
		local atacante = montarAtacante("fogo")
		atacante.ficha.construction.purchasedIds = { fagulha }
		atacante.pm = 1
		t.eq(table.find(Habilidade.disponiveis(atacante), fagulha) ~= nil, true)
		local zona, erro = Habilidade.criarFagulha(atacante, 16, 10)
		t.eq(erro, nil)
		t.eq(zona.x, 16)
		t.eq(zona.durationRounds, 2)
		atacante.pm = 0
		local semPm = Habilidade.criarFagulha(atacante, 11, 10)
		t.eq(semPm, nil)
		atacante.pm = 1
		local longe = Habilidade.criarFagulha(atacante, 17, 10)
		t.eq(longe, nil)
	end,
	["Clarão só é exposto quando comprado e atinge o círculo sem acertar o conjurador"] = function(t)
		local atacante, atores = montarClarao()
		local rng = { NextInteger = function(_, minimo, maximo) return math.clamp(minimo, 1, maximo) end }
	local previsao = Habilidade.preverClarao(atacante, 12, 10)
	t.eq(previsao.targetId, "clarao:12:10")
	local resultado, erro = Habilidade.usarClarao(rng, atacante, atores, Catalogo, 12, 10)
		t.eq(erro, nil)
		t.eq(table.find(Habilidade.disponiveis(atacante), "ability/fogo/Principiante/clarao") ~= nil, true)
	t.eq(resultado.radiusHouses, 4)
	t.eq(resultado.center.x, 12)
	t.eq(resultado.center.z, 10)
	t.eq(#resultado.targets, 3, "a área acompanha o centro escolhido, não o conjurador")
		t.eq(resultado.targets[1].actorId, "jogador:2", "aliados também são alvos")
		t.eq(resultado.targets[2].actorId, "criatura:1")
	t.eq(resultado.targets[3].actorId, "criatura:2", "alvo fora da esfera antiga entra na nova área")
		local semCompra = montarAtacante("fogo")
	local recusado = Habilidade.usarClarao(rng, semCompra, atores, Catalogo, 12, 10)
		t.eq(recusado, nil)
	end,
	["Clarão só prevê casa dentro da grade e visível"] = function(t)
		local atacante = montarClarao()
		local visivel = Habilidade.preverClarao(atacante, 12, 10)
		t.eq(visivel ~= nil, true)
		t.eq(Habilidade.preverClarao(atacante, 21, 10), nil)
		t.eq(Habilidade.preverClarao(atacante, 12, 10, { { x = 11, z = 10 } }), nil,
			"obstáculo entre conjurador e centro invalida o alvo")
		t.eq(Habilidade.coordenadasAlvoClarao("clarao:12:10"), 12)
		local x, z = Habilidade.coordenadasAlvoClarao("clarao:21:10")
		t.eq(x, nil); t.eq(z, nil)
	end,
	["Clarão aplica Cego em falha de Vigor e não causa dano"] = function(t)
		local atacante, atores, aliado, criatura = montarClarao()
		local dados = { 20, 1 }
		local rng = { NextInteger = function(_, minimo, maximo)
			return math.clamp(table.remove(dados, 1) or minimo, minimo, maximo)
		end }
		local pvAliado, pvCriatura = aliado.pv, criatura.pv
		local resultado = Habilidade.usarClarao(rng, atacante, atores, Catalogo, 12, 10)
		t.eq(table.find(resultado.targets[1].applies, "cego"), nil, "o aliado passou na resistência")
		t.eq(table.find(resultado.targets[2].applies, "cego") ~= nil, true, "a criatura falhou na resistência")
		t.eq(aliado.pv, pvAliado)
		t.eq(criatura.pv, pvCriatura)
		t.eq(resultado.pmCost, 1)
	end,
	["Muro de Chamas prévia uma linha reta curta nas oito direções"] = function(t)
		local atacante = montarAtacante("fogo")
		local horizontal = Habilidade.preverMuro(atacante, 14, 10)
		t.eq(#horizontal.cells, 4)
		t.eq(horizontal.cells[1].x, 11)
		t.eq(horizontal.cells[4].x, 14)
		local diagonal = Habilidade.preverMuro(atacante, 7, 7)
		t.eq(#diagonal.cells, 3)
		t.eq(diagonal.cells[1].x, 9)
		t.eq(diagonal.cells[3].z, 7)
		t.eq(Habilidade.preverMuro(atacante, 14, 13), nil, "direção fora das oito diagonais não é válida")
		t.eq(Habilidade.preverMuro(atacante, 17, 10), nil, "não pode passar de seis casas")
	end,
	["Muro valida posse, vizinhança da origem e limites de grade"] = function(t)
		local atacante = montarAtacante("fogo")
		local muro = "ability/fogo/Principiante/muro-de-chamas"
		atacante.ficha.construction.purchasedIds = { muro }
		atacante.pm = 3
		local desenho = Habilidade.preverMuro(atacante, 14, 10)
		local resultado, erro = Habilidade.criarMuro(atacante, desenho.targetId)
		t.eq(erro, nil)
		t.eq(#resultado.cells, 4)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 3)
		t.eq(resultado.durationRounds, 10)
		local inicioFalso = Habilidade.criarMuro(atacante, "muro:12:10:1:0:3")
		t.eq(inicioFalso, nil)
		atacante.pm = 0
		local semPm = Habilidade.criarMuro(atacante, desenho.targetId)
		t.eq(semPm, nil)
	end,
	["Lâmina de Gelo só expõe ataques com arma ativa e usa a mecânica canônica"] = function(t)
		local cast, forca, intelecto = Habilidade.LAMINA_DE_GELO,
			Habilidade.LAMINA_GELO_FORCA, Habilidade.LAMINA_GELO_INTELECTO
		local atacante = montarAtacante("agua")
		atacante.ficha.construction.purchasedIds = { cast }
		atacante.pm = 2
		t.eq(table.find(Habilidade.disponiveis(atacante), cast) ~= nil, true)
		t.eq(table.find(Habilidade.disponiveis(atacante), forca), nil)
		local resultado, erro = Habilidade.conjurarLaminaDeGelo(atacante)
		t.eq(erro, nil)
		t.eq(resultado.actionsCost, 2)
		t.eq(resultado.pmCost, 2)
		t.eq(resultado.weaponDurationRounds, 10)
		atacante.estadosDeCombate = { armaGelo = { valor = true } }
		t.eq(table.find(Habilidade.disponiveis(atacante), forca) ~= nil, true)
		t.eq(table.find(Habilidade.disponiveis(atacante), intelecto) ~= nil, true)
		local mecanica = Habilidade.mecanica(forca)
		t.eq(mecanica.acoes, 1)
		t.eq(mecanica.pm, 0)
		t.eq(mecanica.alcanceCasas, 1)
		t.eq(mecanica.atributoAcerto, "forca")
		t.eq(mecanica.partes[1].dados, "1d8")
		t.eq(mecanica.partes[1].tipo, "cortante")
		t.eq(mecanica.partes[2].dados, "1d4")
		t.eq(mecanica.partes[2].tipo, "frio")
	end,
	["Lâmina de Gelo usa BC de Água, escolha de atributo e Molhado só dobra frio"] = function(t)
		local forca, intelecto = Habilidade.LAMINA_GELO_FORCA, Habilidade.LAMINA_GELO_INTELECTO
		local atacante, alvo = montarAtacante("agua"), montarAlvo()
		atacante.ficha.construction.purchasedIds = { Habilidade.LAMINA_DE_GELO }
		atacante.ficha.calculated.attributes = { forca = 2, intelecto = 5 }
		atacante.estadosDeCombate = { armaGelo = { valor = true } }
		atacante.pm = 0
		alvo.z = 11
		local rng = { NextInteger = function(_, minimo, maximo)
			return if maximo == 20 then 10 else maximo
		end }
		local ataqueForca, erroForca = Habilidade.usar(rng, forca, atacante, alvo, Catalogo)
		t.eq(erroForca, nil)
		t.eq(ataqueForca.attack.bonus, 3, "Força 2 + rank Principiante de Água")
		t.eq(ataqueForca.actionsCost, 1)
		t.eq(ataqueForca.pmCost, 0)
		t.eq(ataqueForca.damageDealt, 18, "1d8 + BC 6 de Água + 1d4")
		alvo.condicoes = { molhado = true }
		local ataqueIntelecto, erroIntelecto = Habilidade.usar(rng, intelecto, atacante, alvo, Catalogo)
		t.eq(erroIntelecto, nil)
		t.eq(ataqueIntelecto.attack.bonus, 6, "Intelecto 5 + rank Principiante de Água")
		t.eq(ataqueIntelecto.damageDealt, 22, "Molhado dobra apenas 1d4 frio")
		alvo.z = 12
		t.eq(Habilidade.usar(rng, intelecto, atacante, alvo, Catalogo), nil, "segundo alvo adjacente é fora de alcance")
	end,
}
