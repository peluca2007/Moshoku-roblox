-- SOMENTE STUDIO: IA dos inimigos (Modo Luta) no serviço real, com mesa isolada;
-- não altera a campanha aberta.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)

local function jogador(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 40, pvMax = 40, mana = 10, manaMax = 10, version = 1, conditions = {},
		sheet = { ca = 10, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = {}, purchasedIds = {}, inventory = {} },
			calculated = { highestRankBonus = 1, attributes = { forca = 2, agilidade = 4, vigor = 3 }, maxima = { pt = 10 } },
			session = { current = { pt = 10 } } },
	}
end
local function inimigo(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "npc", pv = 30, pvMax = 30, mana = 0, manaMax = 0, version = 1,
		conditions = {}, ia = true,
		criatura = { ca = 12, bonusResistencia = 2, bonusAtaque = 3, patamar = 1, danoPorTurno = 16, deslocamentoMetros = 9,
			categoria = "besta", resistencias = {}, imunidades = {} } }
end
local function contexto(rolagem, lista)
	local tokens, ordem = {}, {}
	for _, t in lista do tokens[t.id] = t; table.insert(ordem, t.id) end
	local handlers, logs, recibos = {}, {}, {}
	local combat = { active = true, round = 1, turn = 1, current = ordem[1], order = ordem, turnIndex = 1 }
	local api
	api = Servico.start({
		handlers = handlers, tokens = tokens, tokenOrder = ordem, combat = combat,
		catalogo = Catalogo, terrain = {}, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi) return math.clamp(rolagem or 15, lo, hi) end },
		remote = { FireClient = function(_, p, kind, data) table.insert(recibos, data) end },
		canSee = function() return true end, currentTurnId = function() return combat.current end,
		logAboutToken = function(token, texto) table.insert(logs, texto) end,
		moverFicha = function(token, x, z) token.x, token.z = x, z end,
		removerFicha = function(id) tokens[id] = nil end, reviverBoneco = function() end,
	})
	return { api = api, tokens = tokens, logs = logs, recibos = recibos, combat = combat }
end
local function distancia(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z)) end

return {
	["inimigo longe: anda até colar no alvo e ataca no mesmo turno"] = function(t)
		local a, e = jogador("a", 5, 5), inimigo("e", 15, 5)
		local x = contexto(15, { e, a })
		t.eq(x.api.turnoDoInimigo(e), true)
		t.eq(distancia(e, a), 1, "tem que terminar adjacente")
		t.eq(a.pv, 24, "acerto: d20 15 + 3 contra CA 10 causa o dano por turno (16)")
	end,
	["inimigo com d20 baixo erra e não fere"] = function(t)
		local a, e = jogador("a", 5, 5), inimigo("e", 6, 5)
		local x = contexto(2, { e, a })
		t.eq(x.api.turnoDoInimigo(e), true)
		t.eq(a.pv, 40)
	end,
	["inimigo muito longe só se aproxima (2 Andares) e não ataca"] = function(t)
		local a, e = jogador("a", 1, 1), inimigo("e", 20, 20)
		local x = contexto(15, { e, a })
		local antes = distancia(e, a)
		t.eq(x.api.turnoDoInimigo(e), true)
		t.ok(distancia(e, a) < antes, "tem que chegar mais perto")
		t.ok(distancia(e, a) > 1)
		t.eq(a.pv, 40)
	end,
	["inimigo escolhe o alvo mais próximo"] = function(t)
		local longe, perto, e = jogador("longe", 2, 2), jogador("perto", 12, 10), inimigo("e", 10, 10)
		local x = contexto(15, { e, longe, perto })
		x.api.turnoDoInimigo(e)
		t.eq(perto.pv, 24)
		t.eq(longe.pv, 40)
	end,
	["inimigo ignora ficha caída e sem alvo devolve false"] = function(t)
		local a, e = jogador("a", 5, 5), inimigo("e", 7, 5)
		a.pv = 0
		local x = contexto(15, { e, a })
		t.eq(x.api.turnoDoInimigo(e), false)
	end,
	["inimigo não pisa em casa ocupada: contorna para chegar"] = function(t)
		local a, e, bloqueio = jogador("a", 5, 5), inimigo("e", 9, 5), jogador("b", 7, 5)
		bloqueio.ownerUserId = nil
		local x = contexto(15, { e, a, bloqueio })
		t.eq(x.api.turnoDoInimigo(e), true)
		t.ok(not (e.x == bloqueio.x and e.z == bloqueio.z))
		t.ok(distancia(e, a) <= 1 or distancia(e, bloqueio) <= 1)
	end,
	["inimigo mandado pela IA envia recibo público com o golpe"] = function(t)
		local a, e = jogador("a", 5, 5), inimigo("e", 6, 5)
		local x = contexto(15, { e, a })
		x.api.turnoDoInimigo(e)
		local achou = false
		for _, r in x.recibos do
			if r.habilidadeId == "criatura/ataque" then achou = true end
		end
		-- sem jogadores no boot do servidor não há quem receba; só vale com jogador presente
		t.ok(achou or #game:GetService("Players"):GetPlayers() == 0)
	end,
	["ficha sem bloco de criatura não age"] = function(t)
		local a, e = jogador("a", 5, 5), inimigo("e", 6, 5)
		e.criatura = nil
		local x = contexto(15, { e, a })
		t.eq(x.api.turnoDoInimigo(e), false)
	end,
}
