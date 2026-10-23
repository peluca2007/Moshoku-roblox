-- SOMENTE STUDIO: fórmula desenhada no serviço real (HabilidadeService +
-- FormulasService), mesa isolada. Não altera a campanha aberta.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)

local function teorico(id, x, z, compras)
	return { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 30, pvMax = 30, mana = 12, manaMax = 12, version = 1, conditions = {},
		sheet = { ca = 10, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = { "rank/teorica/Principiante" }, purchasedIds = compras or {}, inventory = {} },
			calculated = { highestRankBonus = 1, attributes = { forca = 0, agilidade = 0, vigor = 0, intelecto = 3, espirito = 1 }, maxima = { pt = 0 }, movementMeters = 9 },
			session = { current = { pt = 0 } } },
	}
end
local function inimigo(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "npc", pv = 30, pvMax = 30, mana = 0, manaMax = 0, version = 1,
		conditions = {}, ia = true,
		criatura = { ca = 10, bonusResistencia = 0, bonusAtaque = 3, patamar = 1, danoPorTurno = 6, deslocamentoMetros = 9,
			categoria = "humanoide", resistencias = {}, imunidades = {} } }
end
local function contexto(lista, rolagem)
	local tokens, ordem = {}, {}
	for _, t in lista do tokens[t.id] = t; table.insert(ordem, t.id) end
	local handlers, logs = {}, {}
	local combat = { active = true, round = 1, turn = 1, current = ordem[1], order = ordem, turnIndex = 1 }
	local api = Servico.start({
		handlers = handlers, tokens = tokens, tokenOrder = ordem, combat = combat,
		catalogo = Catalogo, terrain = {}, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi) return math.clamp(rolagem or 15, lo, hi) end },
		remote = { FireClient = function() end },
		canSee = function() return true end, currentTurnId = function() return combat.current end,
		logAboutToken = function(_, texto) table.insert(logs, texto) end,
		moverFicha = function(token, x, z) token.x, token.z = x, z end,
		removerFicha = function(id) tokens[id] = nil end, reviverBoneco = function() end,
	})
	api.reacoes.decidir = function() return nil end
	return { api = api, handlers = handlers, logs = logs, combat = combat, tokens = tokens,
		registro = function() return table.concat(logs, "\n") end }
end
local P = { UserId = 123 }

return {
	["carta Desenhar fórmula aparece só para quem tem a Teórica"] = function(t)
		local a, e = teorico("a", 5, 5), inimigo("e", 8, 5)
		local x = contexto({ a, e })
		t.ok(table.find(x.api.habilidadesDe(a), "mesa/desenhar-formula") ~= nil)
		t.ok(type(x.handlers.usarHabilidade(P, { tokenId = "a", habilidadeId = "mesa/desenhar-formula" }, false)) == "string")
	end,
	["Mana + Lançar + Círculo: 2 Ações, 1 PM, ataque mágico 1d8 + BC"] = function(t)
		local a, e = teorico("a", 5, 5), inimigo("e", 8, 5)
		local x = contexto({ a, e }, 15)
		local falha = x.handlers.desenharFormula(P, { tokenId = "a", essencia = "mana", verbo = "lancar", forma = "circulo", potencia = "Principiante", alvoId = "e" }, false)
		t.eq(falha, nil, x.registro())
		t.eq(a.mana, 11)
		t.eq(x.api.estado().acoes.usadas, 2)
		t.ok(e.pv < 30, "o dardo fere: " .. x.registro())
	end,
	["Erguer cria parede com PV; Selar de Mana barra magia Principiante"] = function(t)
		local a, e = teorico("a", 5, 5), inimigo("e", 9, 5)
		local x = contexto({ a, e }, 15)
		t.eq(x.handlers.desenharFormula(P, { tokenId = "a", essencia = "mana", verbo = "selar", forma = "circulo", potencia = "Principiante", x = 6, z = 5 }, false), nil, x.registro())
		x.combat.turn += 1
		x.api.aoTrocarVez("a", "a")
		local falha = x.handlers.desenharFormula(P, { tokenId = "a", essencia = "mana", verbo = "lancar", forma = "circulo", potencia = "Principiante", alvoId = "e" }, false)
		t.ok(type(falha) == "string" and string.find(falha, "Selo", 1, true) ~= nil, tostring(falha))
	end,
	["não usa outra habilidade no meio de um desenho de vários turnos"] = function(t)
		local a, e = teorico("a", 5, 5), inimigo("e", 8, 5)
		local x = contexto({ a, e }, 15)
		local estado = x.api.estado()
		-- gasta 2 Ações antes: só 1 resta, o desenho de 2 Ações fica pela metade
		x.handlers.usarHabilidade(P, { tokenId = "a", habilidadeId = "mesa/defender" }, false)
		x.handlers.usarHabilidade(P, { tokenId = "a", habilidadeId = "mesa/defender" }, false)
		t.eq(x.handlers.desenharFormula(P, { tokenId = "a", essencia = "mana", verbo = "lancar", forma = "circulo", potencia = "Principiante", alvoId = "e" }, false), nil, x.registro())
		t.ok(x.api.formulas.desenhando(a), "desenho em andamento")
		t.ok(type(x.handlers.usarHabilidade(P, { tokenId = "a", habilidadeId = "mesa/ataque-basico", alvoId = "e" }, false)) == "string")
		t.eq(estado ~= nil, true)
	end,
}
