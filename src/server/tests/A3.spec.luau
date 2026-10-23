local Shared = game:GetService("ReplicatedStorage").Shared
local Estado = require(Shared.Regras.EstadoHabilidades)
local Arma = require(Shared.Regras.Arma)
local Habilidades = require(Shared.Regras.Habilidades)
local Regras = require(Shared.Livro.Regras)
local Execucao = require(Shared.Regras.Execucao)

local function rng(valores)
	local i = 0
	return { NextInteger = function(_, minimo, maximo)
		i += 1
		local v = valores[i]
		assert(v and v >= minimo and v <= maximo, "rolagem inesperada " .. i)
		return v
	end }
end
local function conj()
	return { bc = 3, pv = 20, pvMax = 20, condicoes = {}, bonusDeRank = 1, atributos = { forca = 3, agilidade = 5, vigor = 2 }, arma = { dado = "d8", bonus = 4 } }
end
local function alvo()
	return { id = "alvo", ca = 10, condicoes = {}, resistencia = function() return 0 end }
end
local function resolve(mec, c, a, dados)
	return Habilidades.resolver(rng(dados), mec, c or conj(), { a or alvo() }, {})[1]
end
return {
	["patamar usa criatura e maior rank do personagem"] = function(t)
		t.eq(Estado.patamar({ criatura = { patamar = 5 } }), 5)
		t.eq(Estado.patamar({ ficha2 = { calculated = { highestRankBonus = 4 } } }), 4)
		t.eq(Estado.patamar({}), 0)
	end,
	["Força ou Agilidade usa o melhor com metade do rank arredondada para cima"] = function(t)
		t.eq(Estado.resistencia({ forca = 2, agilidade = 5 }, 3, "forcaOuAgilidade"), 7)
		t.eq(Estado.resistencia({ forca = 6, agilidade = 1 }, 2, "forcaOuAgilidade"), 7)
		t.eq(Estado.resistencia(nil, 0, "vigor"), 0)
	end,
	["Ferida Fresca é relativa ao fim do turno do curador"] = function(t)
		t.ok(Estado.feridaFresca({ ultimoDano = 8 }, { fimUltimoTurno = 7 }, 20))
		t.ok(not Estado.feridaFresca({ ultimoDano = 8 }, { fimUltimoTurno = 9 }, 20))
		t.ok(not Estado.feridaFresca({}, {}, 1))
		t.ok(Estado.feridaFresca({ ultimoDano = 1 }, {}, 1))
	end,
	["selo expira sem depender de dano ou turno do curador"] = function(t)
		t.ok(Estado.feridaFresca({ feridaSeladaAte = 601 }, { fimUltimoTurno = 50 }, 600))
		t.ok(not Estado.feridaFresca({ feridaSeladaAte = 601 }, {}, 601))
	end,
	["escada de arma confere com todos os vetores do site"] = function(t)
		for _, v in Regras.vetores.escalarDado do
			t.eq(Arma.escalar(v.dado, v.degraus), v.saida)
		end
	end,
	["descer do topo consome excesso antes de diminuir dado"] = function(t)
		local topo = Regras.escadaDeDados[#Regras.escadaDeDados]
		t.eq(Arma.descer(topo .. "+4", 1), topo .. "+2")
		t.eq(Arma.descer(topo .. "+2", 1), topo)
		t.eq(Arma.descer("d4", 1), "d4")
	end,
	["arma importada inválida não vira fórmula arbitrária"] = function(t)
		local ficha = { construction = { unlockedRankIds = {}, inventory = { { type = "arma", equipped = true, name = "Espada", baseDie = "999999d999999" } } } }
		local a = Arma.daFicha(ficha, { POR_ID = {}, POR_ESPECIE = { rank = {} } })
		t.eq(a.dado, "d6")
		t.ok(a.aviso)
	end,
	["atributo da arma aplica exceções de árvores"] = function(t)
		local ficha = { calculated = { attributes = { forca = 7, agilidade = 2, vigor = 5 } } }
		local cat = { POR_ID = { ["tree/cavalaria-e-escudos"] = { data = { keyAttributeLabel = "Vigor" } } } }
		t.eq(Execucao.atributoDaArma("deus-da-agua-corpo", "forca", ficha, cat), 2)
		t.eq(Execucao.atributoDaArma("cavalaria-e-escudos", "forca", ficha, cat), 5)
		t.eq(Execucao.atributoDaArma("deus-da-espada", nil, ficha, cat), 7)
	end,
	["cura dobra dados da Ferida Fresca sem dobrar BC"] = function(t)
		local a = alvo(); a.feridaFresca = true
		local r = resolve({ tipo = "cura", partes = { { dados = "1d8", bc = true } }, dobraComFeridaFresca = true }, nil, a, { 4, 5 })
		t.eq(r.cura, 12)
	end,
	["rank maior resiste, igual dispensa teste"] = function(t)
		local m = { tipo = "efeito", testeSoContraRankMaior = true, resistencia = { atributo = "vigor", cdBase = 8 }, aplica = "cego" }
		local a = alvo(); a.patamar = 1
		t.eq(resolve(m, nil, a, {}).aplica[1], "cego")
		a.patamar = 2
		local r = resolve(m, nil, a, { 20 }); t.ok(r.resistencia.passou); t.eq(r.aplica, nil)
	end,
	["segundo disparo ocorre quando primeiro erra"] = function(t)
		local m = { tipo = "ataque", arma = true, partes = { { arma = true, bc = true } }, segundoDisparo = { { arma = true, degrau = -1 } } }
		local r = resolve(m, nil, nil, { 1, 15, 4 })
		t.ok(not r.ataque.acertou); t.eq(r.dano.total, 4); t.ok(not r.ambosAcertaram)
	end,
	["dois disparos somam danos, só primeiro soma bônus"] = function(t)
		local m = { tipo = "ataque", arma = true, partes = { { arma = true, bc = true } }, segundoDisparo = { { arma = true, degrau = -1 } } }
		local r = resolve(m, nil, nil, { 15, 15, 4, 6 })
		t.eq(r.dano.total, 14); t.ok(r.ambosAcertaram)
	end,
	["Brisa não atravessa imunidade e resistência"] = function(t)
		local c = conj(); c.dadoExtraContra = "desequilibrado"
		local a = alvo(); a.condicoes.desequilibrado = 1; a.imunidades = { "cortante" }
		local m = { tipo = "ataque", partes = { { dados = "1d6", bc = true, tipo = "cortante" } } }
		t.eq(resolve(m, c, a, { 15, 4, 5 }).dano.total, 0)
		a.imunidades = nil; a.resistencias = { "cortante" }
		t.eq(resolve(m, c, a, { 15, 4, 5 }).dano.total, 6)
	end,
	["Molhado dobra parcela fria sem dobrar contundente"] = function(t)
		local a = alvo(); a.condicoes.molhado = 1
		local m = { tipo = "efeito", partes = { { dados = "1d8", tipo = "frio" }, { bc = true, tipo = "contundente" } } }
		t.eq(resolve(m, nil, a, { 5 }).dano.total, 13)
	end,
	["teste após acerto usa atributo alternativo na CD"] = function(t)
		local m = { tipo = "ataque", efeitoNoAcerto = { resistencia = { atributo = "forcaOuAgilidade", cdBase = 8, cdAtributo = "vigor" }, aplica = "caido" } }
		local a = alvo(); a.resistencia = function(atributo) t.eq(atributo, "forcaOuAgilidade"); return 0 end
		local r = resolve(m, nil, a, { 15, 2 })
		t.eq(r.resistencia.cd, 11); t.eq(r.aplica[1], "caido")
	end,
}
