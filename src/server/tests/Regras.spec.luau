local Shared = game:GetService("ReplicatedStorage").Shared
local Combate = require(Shared.Regras.Combate)
local Criaturas = require(Shared.Regras.Criaturas)
local Habilidades = require(Shared.Regras.Habilidades)
local Fogo = require(Shared.Regras.Fogo)
local Regras = require(Shared.Livro.Regras)

-- Gerador roteirizado: devolve os valores na ordem e confere o intervalo pedido.
local function roteiro(valores: { number })
	local i = 0
	return {
		NextInteger = function(_, minimo, maximo)
			i += 1
			local v = valores[i]
			assert(v, "roteiro acabou")
			assert(v >= minimo and v <= maximo, "valor fora do dado: " .. v .. " em " .. minimo .. ".." .. maximo)
			return v
		end,
		usados = function()
			return i
		end,
	}
end

local function alvo(id, ca, condicoes, resistencia, defesas)
	return {
		id = id,
		ca = ca,
		condicoes = condicoes or {},
		resistencia = function()
			return resistencia or 0
		end,
		resistencias = defesas and defesas.resistencias,
		imunidades = defesas and defesas.imunidades,
	}
end

-- Mecânicas das condições como o catálogo as traz (Livro/Dados/Condicoes).
local REGRAS = {
	cego = { desvantagemEmAtaques = true, vantagemParaQuemAtaca = true },
	caido = { desvantagemEmAtaques = true, vantagemCorpoACorpo = true, desvantagemADistancia = true },
	preso = { deslocamento = "zero", desvantagemEmAtaques = true, vantagemParaQuemAtaca = true },
	envenenado = { desvantagemEmAtaques = true, desvantagemEmTestes = true },
}
local function resolver(rng, mec, conj, alvos)
	return Habilidades.resolver(rng, mec, conj, alvos, REGRAS)
end

local IGNIS = { bc = 3, pv = 26, pvMax = 26, condicoes = {} }
local BRASA = Fogo.MECANICAS["ability/fogo/Principiante/brasa"]
local BOLA = Fogo.MECANICAS["ability/fogo/Principiante/bola-de-fogo"]
local TOQUE = Fogo.MECANICAS["ability/fogo/Principiante/toque-escaldante"]
local CLARAO = Fogo.MECANICAS["ability/fogo/Principiante/clarao"]

return {
	["criaturas: igual às funções do site em todos os vetores"] = function(t)
		for _, v in Regras.vetores.aplicarPapel do
			local r = Criaturas.aplicarPapel(v.patamar, v.papel)
			t.eq(r.pv, v.saida.pv, "PV " .. v.patamar .. " " .. v.papel)
			t.eq(r.danoPorTurno, v.saida.danoPorTurno, "dano " .. v.patamar .. " " .. v.papel)
		end
		for _, v in Regras.vetores.atributosDaCriatura do
			local r = Criaturas.atributos(v.patamar)
			for _, k in { "principal", "bom", "comum", "fraco" } do
				t.eq(r[k], v.saida[k], k .. " " .. v.patamar)
			end
		end
		for _, v in Regras.vetores.bonusResistencia do
			t.eq(Criaturas.bonusResistencia(v.patamar), v.saida, "resistência " .. v.patamar)
		end
		t.ok(#Regras.vetores.aplicarPapel == 18)
	end,
	["ataque: 1 natural erra mesmo com bônus alto; 20 acerta e é crítico"] = function(t)
		local a = Combate.ataque(roteiro({ 1 }), 50, 10)
		t.eq(a.acertou, false)
		local b = Combate.ataque(roteiro({ 20 }), -5, 30)
		t.eq(b.acertou, true)
		t.eq(b.critico, true)
		local c = Combate.ataque(roteiro({ 9 }), 3, 12)
		t.eq(c.acertou, true, "9 + 3 = 12 empata a CA e acerta")
	end,
	["vantagem pega o maior, desvantagem o menor, as duas se anulam"] = function(t)
		t.eq(Combate.d20(roteiro({ 4, 17 }), true, false).natural, 17)
		t.eq(Combate.d20(roteiro({ 4, 17 }), false, true).natural, 4)
		local r = roteiro({ 11 })
		t.eq(Combate.d20(r, true, true).natural, 11)
		t.eq(r.usados(), 1)
	end,
	["crítico rola os dados de novo e não dobra o bônus"] = function(t)
		local d = Combate.dano(roteiro({ 4, 6 }), { "1d6" }, 3, true)
		t.eq(d.total, 4 + 6 + 3)
		t.eq(#d.partes, 2)
	end,
	["Brasa: 1d6 + BC ao acertar, sem condição"] = function(t)
		local e = resolver(roteiro({ 15, 5 }), BRASA, IGNIS, { alvo("lobo", 12) })[1]
		t.eq(e.ataque.total, 18)
		t.eq(e.dano.total, 8)
		t.eq(e.aplica, nil)
	end,
	["Bola de Fogo: erro não causa dano nem queima; acerto aplica Em Chamas"] = function(t)
		local erro = resolver(roteiro({ 5 }), BOLA, IGNIS, { alvo("lobo", 12) })[1]
		t.eq(erro.ataque.acertou, false)
		t.eq(erro.dano, nil)
		t.eq(erro.aplica, nil)
		local acerto = resolver(roteiro({ 12, 8 }), BOLA, IGNIS, { alvo("lobo", 12) })[1]
		t.eq(acerto.dano.total, 11)
		t.eq(acerto.aplica[1], "em-chamas")
	end,
	["Toque Escaldante: +1d6 só com metade dos PV ou menos"] = function(t)
		local cheio = resolver(roteiro({ 12, 3, 4 }), TOQUE, IGNIS, { alvo("lobo", 12) })[1]
		t.eq(cheio.dano.total, 3 + 4 + 3)
		local ferido = { bc = 3, pv = 13, pvMax = 26, condicoes = {} }
		local metade = resolver(roteiro({ 12, 3, 4, 5 }), TOQUE, ferido, { alvo("lobo", 12) })[1]
		t.eq(metade.dano.total, 3 + 4 + 5 + 3)
	end,
	["alvo Cego dá Vantagem; atacante Cego tem Desvantagem; Caído à distância dá Desvantagem"] = function(t)
		local r = roteiro({ 2, 19, 6 })
		local e = resolver(r, BRASA, IGNIS, { alvo("lobo", 12, { cego = true }) })[1]
		t.eq(e.ataque.d20.natural, 19)
		local cego = { bc = 3, pv = 26, pvMax = 26, condicoes = { cego = true } }
		local d = resolver(roteiro({ 19, 2 }), BRASA, cego, { alvo("lobo", 12) })[1]
		t.eq(d.ataque.d20.natural, 2)
		local caido = resolver(roteiro({ 19, 2 }), BOLA, IGNIS, { alvo("lobo", 12, { caido = true }) })[1]
		t.eq(caido.ataque.d20.natural, 2)
	end,
	["Clarão: CD 8 + BC em Vigor; falhou fica Cego, passou nada; sem dano"] = function(t)
		local efeitos = resolver(roteiro({ 9, 10 }), CLARAO, IGNIS, { alvo("a", 12, nil, 1), alvo("b", 12, nil, 1) })
		t.eq(efeitos[1].resistencia.cd, 11)
		t.eq(efeitos[1].resistencia.passou, false, "9 + 1 = 10 < 11")
		t.eq(efeitos[1].aplica[1], "cego")
		t.eq(efeitos[2].resistencia.passou, true, "10 + 1 = 11 passa")
		t.eq(efeitos[2].aplica, nil)
		t.eq(efeitos[1].dano, nil)
	end,
	["muro: atravessar causa 3d6 e Em Chamas, sem teste"] = function(t)
		local e = Habilidades.atravessar(roteiro({ 1, 2, 3 }), Fogo.MECANICAS["ability/fogo/Principiante/muro-de-chamas"], alvo("lobo", 12))
		t.eq(e.dano.total, 6)
		t.eq(e.aplica[1], "em-chamas")
	end,
	["habilidades do Ignis: o truque vem com o rank; o resto pelas compras"] = function(t)
		local ficha2 = { construction = {
			unlockedRankIds = { "rank/fogo/Principiante" },
			purchasedIds = { "ability/fogo/Principiante/bola-de-fogo", "talent/fogo/Principiante/pavio-curto" },
		} }
		local lista = Fogo.habilidadesDe(ficha2)
		t.eq(#lista, 2)
		t.eq(lista[1], "ability/fogo/Principiante/brasa")
		t.eq(lista[2], "ability/fogo/Principiante/bola-de-fogo")
		t.eq(#Fogo.habilidadesDe({ construction = { unlockedRankIds = {}, purchasedIds = {} } }), 0)
	end,
	["geometria: distância com diagonal 1, linha e visão bloqueada"] = function(t)
		t.eq(Combate.distancia(1, 1, 4, 3), 3)
		t.eq(Combate.casasDeMetros(9), 6)
		t.eq(Combate.casasDeMetros(18), 12)
		local linha = Combate.linha(1, 1, 4, 1)
		t.eq(#linha, 3)
		t.eq(linha[3][1], 4)
		t.eq(Combate.temVisao(1, 1, 4, 1, function(x)
			return x == 2
		end), false)
		t.eq(Combate.temVisao(1, 1, 2, 1, function(x)
			return x == 2
		end), true, "o próprio alvo não bloqueia")
	end,
	["fórmula de dados: só parcelas positivas NdM; o resto é erro"] = function(t)
		t.eq(#Combate.lerDados("1d8 + 1d6"), 2)
		for _, ruim in { "1d6 - 1d4", "erro", "", "1d6+", "+1d6", "1d6+3", "2d" } do
			t.fails(function()
				Combate.lerDados(ruim)
			end, "devia recusar: " .. ruim)
		end
	end,
	["dano tipado: Resistência corta pela metade (para baixo), Imunidade zera"] = function(t)
		local resiste = resolver(roteiro({ 15, 4 }), BOLA, IGNIS, { alvo("salamandra", 12, nil, 0, { resistencias = { "ígneo", "frio" } }) })[1]
		t.eq(resiste.dano.total, 3, "(4 + 3) / 2 para baixo")
		t.eq(resiste.dano.tipo, "ígneo")
		local imune = resolver(roteiro({ 15, 4 }), BOLA, IGNIS, { alvo("elemental", 12, nil, 0, { imunidades = { "ígneo" } }) })[1]
		t.eq(imune.dano.total, 0)
		t.eq(imune.aplica, nil, "imune a ígneo não pega Em Chamas")
		local outro = resolver(roteiro({ 15, 4 }), BOLA, IGNIS, { alvo("golem", 12, nil, 0, { resistencias = { "cortante" } }) })[1]
		t.eq(outro.dano.total, 7, "resistência a outro tipo não muda nada")
	end,
	["Quebrantado tira 1 de CA por acúmulo; atacante Escondido tem Vantagem"] = function(t)
		local e = resolver(roteiro({ 7, 1 }), BRASA, IGNIS, { alvo("lobo", 12, { quebrantado = 2 }) })[1]
		t.eq(e.ataque.defesa, 10)
		t.eq(e.ataque.acertou, true, "7 + 3 = 10 contra CA 10")
		local escondido = { bc = 3, pv = 26, pvMax = 26, condicoes = { escondido = 1 } }
		t.eq(resolver(roteiro({ 3, 18, 2 }), BRASA, escondido, { alvo("lobo", 12) })[1].ataque.d20.natural, 18)
	end,
	["crítico com parcela condicional: rola de novo todos os dados, BC uma vez"] = function(t)
		local ferido = { bc = 3, pv = 10, pvMax = 26, condicoes = {} }
		local e = resolver(roteiro({ 20, 1, 2, 3, 4, 5, 6 }), TOQUE, ferido, { alvo("lobo", 12) })[1]
		t.eq(e.ataque.critico, true)
		-- 2d6 [1,2] + crítico [3,4]; 1d6 [5] + crítico [6]; + BC 3
		t.eq(e.dano.total, 1 + 2 + 3 + 4 + 5 + 6 + 3)
	end,
	["Chama Viva: contra alvo Em Chamas o dano de área é cheio mesmo no sucesso"] = function(t)
		local mec = { tipo = "efeito", alvo = "esferaNoConjurador", raioCasas = 2, dados = { "2d6" }, tipoDano = "ígneo", metadeNoSucesso = true, resistencia = { atributo = "agilidade", cdBase = 8 } }
		local mestre = { bc = 3, pv = 26, pvMax = 26, condicoes = {}, danoCheioEmChamas = true }
		local alvos = { alvo("a", 12, { ["em-chamas"] = 1 }, 20), alvo("b", 12, nil, 20) }
		local efeitos = resolver(roteiro({ 10, 3, 3, 10, 3, 3 }), mec, mestre, alvos)
		t.eq(efeitos[1].resistencia.passou, true)
		t.eq(efeitos[1].dano.total, 6, "Em Chamas: cheio")
		t.eq(efeitos[2].dano.total, 3, "sem Em Chamas: metade")
		local semMaestria = { bc = 3, pv = 26, pvMax = 26, condicoes = {} }
		t.eq(resolver(roteiro({ 10, 3, 3 }), mec, semMaestria, { alvos[1] })[1].dano.total, 3)
	end,
	["muro nas 8 direções; área em círculo"] = function(t)
		local dx, dz = Combate.direcao8(3, 2)
		t.eq(dx, 1)
		t.eq(dz, 1)
		dx, dz = Combate.direcao8(5, 1)
		t.eq(dx, 1)
		t.eq(dz, 0)
		dx, dz = Combate.direcao8(0, -4)
		t.eq(dx, 0)
		t.eq(dz, -1)
		t.ok(Combate.distanciaEuclidiana(0, 0, 3, 3) > 4, "canto do quadrado fica fora do raio 4")
		t.ok(Combate.distanciaEuclidiana(0, 0, 4, 0) <= 4)
	end,

	["atacante Quebrantado causa −1 de dano por acúmulo"] = function(t)
		local q = { bc = 3, pv = 26, pvMax = 26, condicoes = { quebrantado = 2 } }
		local e = resolver(roteiro({ 15, 4 }), BRASA, q, { alvo("lobo", 12) })[1]
		t.eq(e.dano.total, 4 + 3 - 2)
	end,

}
