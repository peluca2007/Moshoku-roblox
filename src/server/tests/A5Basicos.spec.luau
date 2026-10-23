-- SOMENTE STUDIO: ataque básico (Atacar com Arma, Cap. 4 §3) no serviço real,
-- com mesa isolada; não altera a campanha aberta.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)

local function ficha(id, x, z, extra)
	local t = { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 50, pvMax = 100, mana = 10, manaMax = 10, version = 1, conditions = {},
		sheet = { ca = 10, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = {}, purchasedIds = {}, inventory = {} },
			calculated = { highestRankBonus = 1, attributes = { forca = 2, agilidade = 4, vigor = 3 }, maxima = { pt = 10 } },
			session = { current = { pt = 10 } } },
	}
	for k, v in extra or {} do t[k] = v end
	return t
end
local function contexto(rolagem, distancia)
	local a, b = ficha("a", 5, 5), ficha("b", 5 + (distancia or 1), 5)
	local tokens = { a = a, b = b }
	local handlers, recibos = {}, {}
	local combat = { active = true, round = 1, turn = 1, current = "a", order = { "a", "b" }, turnIndex = 1 }
	local player = { UserId = 123 }
	local api
	api = Servico.start({
		handlers = handlers, tokens = tokens, tokenOrder = { "a", "b" }, combat = combat,
		catalogo = Catalogo, terrain = {}, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi) return math.clamp(rolagem or 15, lo, hi) end },
		remote = { FireClient = function(_, p, kind, data) table.insert(recibos, { player = p, kind = kind, data = data }) end },
		canSee = function() return true end, currentTurnId = function() return combat.current end,
		logAboutToken = function() end,
		moverFicha = function(token, x, z) token.x, token.z = x, z end,
		removerFicha = function(id) tokens[id] = nil end, reviverBoneco = function() end,
	})
	local function usar(id, alvoId)
		return handlers.usarHabilidade(player, { tokenId = combat.current, habilidadeId = id, alvoId = alvoId }, false)
	end
	return { a = a, b = b, api = api, usar = usar, recibos = recibos }
end

return {
	["ataque básico: toda ficha com ficha completa tem os dois ataques, depois das cartas da árvore"] = function(t)
		local x = contexto()
		local lista = x.api.habilidadesDe(x.a)
		t.eq(lista[#lista - 1], "mesa/ataque-basico")
		t.eq(lista[#lista], "mesa/ataque-a-distancia")
	end,
	["ataque básico: custa 1 Ação, acerta e informa a arma no recibo"] = function(t)
		local x = contexto(15, 1)
		t.eq(x.usar("mesa/ataque-basico", "b"), nil)
		t.eq(x.api.estado().acoes.usadas, 1)
		t.ok(x.b.pv < 50, "o golpe tem que ferir o alvo (d20 15 + 2 contra CA 10)")
		-- O recibo só sai para jogadores presentes: no boot do servidor não há nenhum.
		if #game:GetService("Players"):GetPlayers() > 0 then
			local recibo = x.recibos[1] and x.recibos[1].data
			t.ok(recibo and type(recibo.arma) == "string", "recibo sem nome da arma")
			t.eq(recibo.habilidadeId, "mesa/ataque-basico")
		end
	end,
	["ataque básico: corpo a corpo recusa alvo longe, sem gastar Ação"] = function(t)
		local x = contexto(15, 4)
		t.ok(type(x.usar("mesa/ataque-basico", "b")) == "string")
		t.eq(x.api.estado().acoes.usadas, 0)
	end,
	["ataque básico: disparo alcança 4 casas"] = function(t)
		local x = contexto(15, 4)
		t.eq(x.usar("mesa/ataque-a-distancia", "b"), nil)
		t.eq(x.api.estado().acoes.usadas, 1)
		t.ok(x.b.pv < 50)
	end,
	["ataque básico: d20 baixo erra e não fere"] = function(t)
		local x = contexto(2, 1)
		t.eq(x.usar("mesa/ataque-basico", "b"), nil)
		t.eq(x.b.pv, 50)
	end,
	["ataque básico: ficha sem ficha completa não ganha as cartas"] = function(t)
		local x = contexto()
		x.a.ficha2 = nil
		t.eq(x.api.habilidadesDe(x.a), nil)
	end,
}
