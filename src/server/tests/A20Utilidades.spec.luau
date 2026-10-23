-- SOMENTE STUDIO: árvores de utilidade (A20) no serviço real, mesa isolada.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)

local FURT, BARDO, NAV = "furtividade-e-armadilhas", "bardo-e-interacao", "navegacao-e-lideranca"
local ADAGA = { name = "Adaga / Punhal", type = "arma", equipped = true, baseDie = "d4" }
local LANCA = { name = "Alabarda / Lança", type = "arma", equipped = true, baseDie = "d10" }

local function jogador(id, x, z, arvore, compras, arma)
	return { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 30, pvMax = 30, mana = 8, manaMax = 8, version = 1, conditions = {},
		sheet = { ca = 12, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = if arvore then { "rank/" .. arvore .. "/Principiante" } else {}, purchasedIds = compras or {}, inventory = { arma or ADAGA } },
			calculated = { highestRankBonus = 1, attributes = { forca = 0, agilidade = 3, vigor = 1, intelecto = 2, espirito = 2 }, maxima = { pt = 0, pp = 2 }, movementMeters = 9 },
			session = { current = { pt = 0, pp = 2 } } },
	}
end
local function inimigo(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "npc", pv = 40, pvMax = 40, mana = 0, manaMax = 0, version = 1,
		conditions = {}, ia = true,
		criatura = { ca = 10, bonusResistencia = 0, bonusAtaque = 3, patamar = 1, danoPorTurno = 6, deslocamentoMetros = 9,
			categoria = "humanoide", resistencias = {}, imunidades = {} } }
end
local function contexto(lista, d20, dados, terreno)
	local tokens, ordem = {}, {}
	for _, t in lista do tokens[t.id] = t; table.insert(ordem, t.id) end
	local handlers, logs = {}, {}
	local combat = { active = true, round = 1, turn = 1, current = ordem[1], order = ordem, turnIndex = 1 }
	local fila, filaDados = table.clone(d20 or {}), table.clone(dados or {})
	local api = Servico.start({
		handlers = handlers, tokens = tokens, tokenOrder = ordem, combat = combat,
		catalogo = Catalogo, terrain = terreno or {}, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi)
			if hi == 20 then return math.clamp(table.remove(fila, 1) or 10, lo, hi) end
			return math.clamp(table.remove(filaDados, 1) or 3, lo, hi)
		end },
		remote = { FireClient = function() end },
		canSee = function() return true end, currentTurnId = function() return combat.current end,
		logAboutToken = function(_, texto) table.insert(logs, texto) end,
		moverFicha = function(token, x, z) token.x, token.z = x, z end,
		removerFicha = function(id) tokens[id] = nil end, reviverBoneco = function() end,
	})
	local resposta = {}
	api.reacoes.decidir = function(token, _, opcoes)
		for _, o in opcoes do if resposta[o.id] then return o.id end end
		return nil
	end
	local P = { UserId = 123 }
	return { api = api, handlers = handlers, logs = logs, combat = combat, tokens = tokens, responder = function(r) resposta = r end,
		usar = function(id, hab, extra) local p = { tokenId = id, habilidadeId = hab }; for k, v in extra or {} do p[k] = v end; return handlers.usarHabilidade(P, p, false) end,
		vez = function(id) local ant = combat.current; combat.current = id; combat.turn += 1; api.aoTrocarVez(ant, id) end,
		registro = function() return table.concat(logs, "\n") end }
end
local function tem(t, cond) for _, c in t.conditions or {} do if c.id == cond then return true end end return false end

return {
	["G12 nao ladino nao pode forjar esconder nem gastar acao"] = function(t)
		local a=jogador("a",5,5,BARDO)
		local x=contexto({a});local mana=a.mana
		t.ok(type(x.usar("a","mesa/esconder"))=="string")
		t.eq(x.api.estado().acoes.usadas,0);t.eq(a.mana,mana);t.eq(tem(a,"escondido"),false)
	end,
	["Se Esconder exige ficar fora da vista; Escondido não é alvo da IA e se revela ao atacar"] = function(t)
		local a, e = jogador("a", 5, 5, FURT), inimigo("e", 9, 5)
		e.olharX, e.olharZ = -1, 0
		local x = contexto({ a, e }, { 18 })
		t.ok(type(x.usar("a", "mesa/esconder")) == "string", "à vista do inimigo, recusa")
		local b, f = jogador("b", 5, 5, FURT), inimigo("f", 9, 5)
		local y = contexto({ b, f }, { 18, 15 }, {}, { ["7:5"] = "parede" })
		t.eq(y.usar("b", "mesa/esconder"), nil, y.registro())
		t.ok(tem(b, "escondido"), y.registro())
		t.eq(y.api.turnoDoInimigo(f), false, "a IA não acha quem está Escondido")
		f.x = 6
		y.vez("b")
		y.usar("b", "mesa/ataque-basico", { alvoId = "f" })
		t.ok(not tem(b, "escondido"), "atacar revela")
		t.ok(string.find(y.registro(), "Vantagem", 1, true) ~= nil, y.registro())
	end,
	["Primeiro Golpe: alvo que ainda não agiu, Dano Furtivo triplicado, 1 vez por combate"] = function(t)
		local a = jogador("a", 5, 5, FURT, { "ability/" .. FURT .. "/Principiante/primeiro-golpe" })
		local e = inimigo("e", 6, 5)
		local x = contexto({ a, e }, { 15 }, { 2, 4, 4, 4 }) -- adaga d4 = 2; 3d6 furtivos = 12
		t.eq(x.usar("a", "ability/" .. FURT .. "/Principiante/primeiro-golpe", { alvoId = "e" }), nil, x.registro())
		t.ok(string.find(x.registro(), "triplicado", 1, true) ~= nil, x.registro())
		t.ok(e.pv <= 40 - 12, "furtivo entra no dano: " .. e.pv)
		x.vez("a")
		t.ok(type(x.usar("a", "ability/" .. FURT .. "/Principiante/primeiro-golpe", { alvoId = "e" })) == "string", "uma vez por combate")
	end,
	["Dano Furtivo: uma vez por turno contra quem ainda não agiu"] = function(t)
		local a, e = jogador("a", 5, 5, FURT), inimigo("e", 6, 5)
		local x = contexto({ a, e }, { 15, 15 })
		x.usar("a", "mesa/ataque-basico", { alvoId = "e" })
		x.usar("a", "mesa/ataque-basico", { alvoId = "e" })
		local n = 0
		for _, l in x.logs do if string.find(l, "Dano Furtivo", 1, true) then n += 1 end end
		t.eq(n, 1, x.registro())
	end,
	["Inspiração: o aliado soma o dado depois de errar e o golpe acerta"] = function(t)
		local b = jogador("b", 5, 5, BARDO, { "ability/" .. BARDO .. "/Principiante/inspiracao" })
		local a = jogador("a", 5, 6)
		local e = inimigo("e", 6, 6)
		local x = contexto({ b, a, e }, { 6 }, { 6, 2 }) -- ataque: 6 + 3 = 9 contra CA 10; d6 = 6
		t.eq(x.usar("b", "ability/" .. BARDO .. "/Principiante/inspiracao", { alvoId = "a" }), nil, x.registro())
		x.vez("a")
		x.responder({ inspiracao = true })
		x.usar("a", "mesa/ataque-basico", { alvoId = "e" })
		t.ok(e.pv < 40, "com a Inspiração o golpe acerta: " .. x.registro())
	end,
	["Insulto Afiado dá Desvantagem no próximo ataque do inimigo"] = function(t)
		local b = jogador("b", 5, 5, BARDO, { "talent/" .. BARDO .. "/Principiante/insulto-afiado" })
		local e = inimigo("e", 6, 5)
		local x = contexto({ b, e }, { 15, 2, 18, 4 }) -- 17 contra 2: vence; depois o inimigo rola 18 e 4 (fica 4)
		t.eq(x.usar("b", "mesa/insulto", { alvoId = "e" }), nil, x.registro())
		x.vez("e")
		x.api.turnoDoInimigo(e)
		t.eq(b.pv, 30, "com Desvantagem o 4 erra: " .. x.registro())
	end,
	["Dissonância fere quem ouve no começo da vez do bardo"] = function(t)
		local b = jogador("b", 5, 5, BARDO)
		local e = inimigo("e", 8, 5)
		local x = contexto({ b, e }, {}, { 5 })
		t.eq(x.usar("b", "mesa/dissonancia"), nil, x.registro())
		x.vez("e"); x.vez("b")
		t.eq(e.pv, 35, x.registro())
	end,
	["Ordem de Tiro: o primeiro acerto no Apontado soma 1d6; o Tático com haste soma o Rank"] = function(t)
		local n = jogador("n", 5, 5, NAV, {}, LANCA)
		local e = inimigo("e", 6, 5)
		local x = contexto({ n, e }, { 15 }, { 4, 5 }) -- lança d10 = 4; apontado 1d6 = 5
		t.eq(x.usar("n", "mesa/apontar", { alvoId = "e" }), nil, x.registro())
		x.usar("n", "mesa/ataque-basico", { alvoId = "e" })
		t.ok(string.find(x.registro(), "Apontado: +1d6", 1, true) ~= nil, x.registro())
		t.ok(string.find(x.registro(), "ordem própria", 1, true) ~= nil, x.registro())
	end,
	["Voz que Corrige: o Tático faz o aliado repetir a rolagem contra o Apontado"] = function(t)
		local n = jogador("n", 5, 5, NAV, { "talent/" .. NAV .. "/Principiante/voz-que-corrige" })
		local a = jogador("a", 5, 6)
		local e = inimigo("e", 6, 6)
		local x = contexto({ n, a, e }, { 2, 18 })
		x.usar("n", "mesa/apontar", { alvoId = "e" })
		x.vez("a")
		x.responder({ voz = true })
		x.usar("a", "mesa/ataque-basico", { alvoId = "e" })
		t.ok(string.find(x.registro(), "grita a correção", 1, true) ~= nil, x.registro())
		t.ok(e.pv < 40)
	end,
	["Refrão da Retomada: aliado erra, o bardo gasta 1 PP e dá PV temporários"] = function(t)
		local b = jogador("b", 5, 5, BARDO, { "ability/" .. BARDO .. "/Principiante/refrao-da-retomada" })
		local a = jogador("a", 5, 6)
		local e = inimigo("e", 6, 6)
		local x = contexto({ a, b, e }, { 2 }, { 3, 4 })
		x.responder({ refrao = true })
		x.usar("a", "mesa/ataque-basico", { alvoId = "e" })
		t.ok(string.find(x.registro(), "Refrão da Retomada", 1, true) ~= nil, x.registro())
		t.ok((a.pvTemp or 0) > 0)
		t.eq(b.pp, 1)
	end,
	["cartas aparecem só para quem tem a árvore ou o talento"] = function(t)
		local b = jogador("b", 5, 5, BARDO)
		local s = jogador("s", 6, 5)
		local x = contexto({ b, s })
		local lb, ls = x.api.habilidadesDe(b), x.api.habilidadesDe(s)
		t.ok(table.find(lb, "mesa/dissonancia") ~= nil)
		t.eq(table.find(ls, "mesa/dissonancia"), nil)
		t.eq(table.find(ls, "mesa/esconder"), nil, "G12: Se Esconder é exclusivo de Furtividade")
		t.eq(table.find(lb, "mesa/insulto"), nil, "Insulto exige o talento")
	end,
}
