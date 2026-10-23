-- SOMENTE STUDIO: Reações (A14) no serviço real, com mesa isolada e a pergunta
-- substituída por api.reacoes.decidir. Não altera a campanha aberta.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)

local ESPADA = { name = "Espada Longa", type = "arma", equipped = true, baseDie = "d8" }

local function jogador(id, x, z, ranks, compras, inventario)
	return { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 40, pvMax = 40, mana = 10, manaMax = 10, version = 1, conditions = {},
		sheet = { ca = 14, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = ranks or {}, purchasedIds = compras or {}, inventory = inventario or { ESPADA } },
			calculated = { highestRankBonus = 1, attributes = { forca = 2, agilidade = 3, vigor = 2, intelecto = 3, espirito = 1 }, maxima = { pt = 10 } },
			session = { current = { pt = 10 } } },
	}
end
local function inimigo(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "npc", pv = 30, pvMax = 30, mana = 0, manaMax = 0, version = 1,
		conditions = {}, ia = true,
		criatura = { ca = 12, bonusResistencia = 2, bonusAtaque = 3, patamar = 1, danoPorTurno = 16, deslocamentoMetros = 9,
			categoria = "besta", resistencias = {}, imunidades = {} } }
end
-- Cada d20 sai da fila `rolagens` (acabou a fila, vale `padrao`); os outros
-- dados saem da fila `dados` (acabou, 3).
local function contexto(rolagens, padrao, lista, dados)
	local tokens, ordem = {}, {}
	for _, t in lista do tokens[t.id] = t; table.insert(ordem, t.id) end
	local handlers, logs = {}, {}
	local combat = { active = true, round = 1, turn = 1, current = ordem[1], order = ordem, turnIndex = 1 }
	local fila, filaDados = table.clone(rolagens), table.clone(dados or {})
	local api = Servico.start({
		handlers = handlers, tokens = tokens, tokenOrder = ordem, combat = combat,
		catalogo = Catalogo, terrain = {}, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi)
			if hi == 20 then return math.clamp(table.remove(fila, 1) or padrao, lo, hi) end
			return math.clamp(table.remove(filaDados, 1) or 3, lo, hi)
		end },
		remote = { FireClient = function() end },
		canSee = function() return true end, currentTurnId = function() return combat.current end,
		logAboutToken = function(_, texto) table.insert(logs, texto) end,
		moverFicha = function(token, x, z) token.x, token.z = x, z end,
		removerFicha = function(id) tokens[id] = nil end, reviverBoneco = function() end,
	})
	local perguntas = {}
	local resposta = nil
	api.reacoes.decidir = function(token, texto, opcoes)
		local ids = {}
		for _, o in opcoes do table.insert(ids, o.id) end
		table.insert(perguntas, { token = token.id, texto = texto, opcoes = ids })
		return if type(resposta) == "function" then resposta(token, ids) else resposta
	end
	return {
		api = api, tokens = tokens, logs = logs, combat = combat, handlers = handlers, perguntas = perguntas,
		responder = function(r) resposta = r end,
		registro = function() return table.concat(logs, "\n") end,
	}
end

local AGUA = "rank/deus-da-agua-corpo/Principiante"
local APARAR = { "ability/deus-da-agua-corpo/Principiante/aparar" }
local GUARDA = { "ability/deus-da-agua-corpo/Principiante/guarda-do-corpo" }

return {
	["Aparar: golpe que acertaria por pouco vira erro e gasta a Reação"] = function(t)
		local a, e = jogador("a", 5, 5, { AGUA }, APARAR), inimigo("e", 6, 5)
		local x = contexto({ 11 }, 1, { e, a }) -- 11 + 3 = 14 contra CA 14: acerta; Aparar +1 → 15
		x.responder("aparar")
		x.api.turnoDoInimigo(e)
		t.eq(a.pv, 40, "o golpe aparado não fere")
		t.eq(#x.perguntas, 1)
		t.ok(string.find(x.registro(), "Aparar", 1, true) ~= nil)
		t.eq(x.api.reacoes.temReacao(a), false, "a Reação foi gasta")
	end,
	["Aparar não é oferecido quando não faria o golpe errar"] = function(t)
		local a, e = jogador("a", 5, 5, { AGUA }, APARAR), inimigo("e", 6, 5)
		local x = contexto({ 18 }, 3, { e, a }) -- 21 contra CA 14
		x.responder("aparar")
		x.api.turnoDoInimigo(e)
		t.eq(#x.perguntas, 0)
		t.eq(a.pv, 24)
	end,
	["Fluxo: inimigo adjacente erra e leva o contra-ataque, uma vez por rodada"] = function(t)
		local a, e = jogador("a", 5, 5, { AGUA }), inimigo("e", 6, 5)
		local x = contexto({ 2, 15, 2, 2, 15 }, 1, { e, a }) -- inimigo erra (2); contra-ataque 15 acerta CA 12
		x.api.turnoDoInimigo(e)
		t.ok(string.find(x.registro(), "Fluxo de a", 1, true) ~= nil, x.registro())
		t.ok(e.pv < 30, "o contra-ataque fere")
		local depois = e.pv
		x.api.turnoDoInimigo(e) -- erra de novo na mesma rodada: sem segundo Fluxo
		t.eq(e.pv, depois)
		x.combat.round = 2
		x.api.turnoDoInimigo(e)
		t.ok(e.pv < depois, "rodada nova: o Fluxo volta")
	end,
	["uma Reação por rodada: volta no início da vez de quem reagiu"] = function(t)
		local a, e = jogador("a", 5, 5, { AGUA }), inimigo("e", 6, 5)
		a.ficha2.construction.purchasedIds = APARAR
		local x = contexto({ 11, 1, 11 }, 1, { e, a }) -- golpe, Fluxo (erra), golpe
		x.responder("aparar")
		x.api.turnoDoInimigo(e)
		x.api.turnoDoInimigo(e)
		t.eq(#x.perguntas, 1, "sem Reação, não pergunta")
		t.eq(a.pv, 24)
		x.api.aoTrocarVez("e", "a")
		t.eq(x.api.reacoes.temReacao(a), true)
	end,
	["Desequilibrado não reage"] = function(t)
		local a, e = jogador("a", 5, 5, { AGUA }), inimigo("e", 6, 5)
		a.conditions = { { id = "desequilibrado", stacks = 1 } }
		a.ficha2.construction.purchasedIds = APARAR
		local x = contexto({ 11 }, 1, { e, a })
		x.responder("aparar")
		x.api.turnoDoInimigo(e)
		t.eq(#x.perguntas, 0)
	end,
	["Guarda do Corpo: o aliado ao lado vira o alvo"] = function(t)
		local a = jogador("a", 5, 5)
		local g = jogador("g", 5, 6, { AGUA }, GUARDA)
		local e = inimigo("e", 6, 5)
		local x = contexto({ 15 }, 1, { e, a, g })
		x.responder(function(_, ids) return if table.find(ids, "guardaDoCorpo") then "guardaDoCorpo" else nil end)
		x.api.turnoDoInimigo(e)
		t.eq(a.pv, 40)
		t.eq(g.pv, 24)
	end,
	["Couraça de Barro: 2 PM, reduz 1d6 + BC do dano físico"] = function(t)
		local a, e = jogador("a", 5, 5, { "rank/terra/Principiante" }, { "ability/terra/Principiante/couraca-de-barro" }), inimigo("e", 6, 5)
		local x = contexto({ 15 }, 1, { e, a }, { 4 }) -- acerta; d6 = 4; BC Terra = Intelecto 3 + 1
		x.responder("couraca")
		x.api.turnoDoInimigo(e)
		t.eq(a.mana, 8)
		t.eq(a.pv, 40 - (16 - 8))
	end,
	["Parede de Emergência: 4 PM, a parede de 15 PV recebe o golpe"] = function(t)
		local a = jogador("a", 5, 5, { "rank/teorica/Principiante" }, { "ability/teorica/Principiante/parede-de-emergencia" })
		local e = inimigo("e", 6, 5)
		local x = contexto({ 15 }, 1, { e, a })
		x.responder("parede")
		x.api.turnoDoInimigo(e)
		t.eq(a.mana, 6)
		t.eq(a.pv, 40, "barreira recebe o golpe; excesso não atravessa")
		t.eq(#x.api.estado().muros, 0, "16 destrói a barreira real de 15 PV")
	end,
	["Interpor: o protetor a até 3 m toma todo o dano do designado"] = function(t)
		local a = jogador("a", 5, 5)
		local p = jogador("p", 5, 7, { "rank/cavalaria-e-escudos/Principiante" })
		local e = inimigo("e", 6, 5)
		local x = contexto({ 15 }, 1, { e, a, p })
		x.api.reacoes.designar(p, a)
		x.responder("interpor")
		x.api.turnoDoInimigo(e)
		t.eq(a.pv, 40)
		t.eq(p.pv, 24)
	end,
	["Bloquear com Escudo (proficiente): +5 na CA faz o golpe errar"] = function(t)
		local escudo = { name = "Escudo", type = "armadura", equipped = true, acBonus = 2 }
		local a = jogador("a", 5, 5, { "rank/cavalaria-e-escudos/Principiante" }, {}, { ESPADA, escudo })
		local e = inimigo("e", 6, 5)
		local x = contexto({ 13 }, 1, { e, a }) -- 16 contra CA 14; +5 → 19
		x.responder("escudo")
		x.api.turnoDoInimigo(e)
		t.eq(a.pv, 40)
	end,
	["Sob Minha Guarda: carta de 0 Ação designa o aliado"] = function(t)
		local p = jogador("p", 5, 7, { "rank/cavalaria-e-escudos/Principiante" })
		local a = jogador("a", 5, 5)
		local x = contexto({}, 10, { p, a })
		local jogadorFalso = { UserId = 123 }
		t.ok(table.find(x.api.habilidadesDe(p), "mesa/sob-minha-guarda") ~= nil)
		t.eq(table.find(x.api.habilidadesDe(a), "mesa/sob-minha-guarda"), nil)
		t.eq(x.handlers.usarHabilidade(jogadorFalso, { tokenId = "p", habilidadeId = "mesa/sob-minha-guarda", alvoId = "a" }, false), nil)
		t.eq(x.api.reacoes.designadoDe("p"), "a")
		x.combat.current = "a"
		t.ok(type(x.handlers.usarHabilidade(jogadorFalso, { tokenId = "a", habilidadeId = "mesa/sob-minha-guarda", alvoId = "p" }, false)) == "string",
			"sem a maestria de Cavalaria, recusa")
	end,
	["reagir: recusa pedido inexistente"] = function(t)
		local x = contexto({}, 10, { jogador("a", 5, 5) })
		t.ok(type(x.handlers.reagir({ UserId = 123 }, { id = 999 })) == "string")
	end,
}
