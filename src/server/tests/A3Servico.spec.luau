-- SOMENTE STUDIO: serviço real com dependências/mesa isoladas; não altera a campanha aberta.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)

local function ficha(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 50, pvMax = 100, mana = 100, manaMax = 100, version = 1, conditions = {},
		sheet = { ca = 10, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = {}, purchasedIds = {}, inventory = {} },
			calculated = { highestRankBonus = 1, attributes = { forca = 2, agilidade = 4, vigor = 3 }, maxima = { pt = 10 } },
			session = { current = { pt = 10 } } },
	}
end
local function contexto(mecanicas, rolagem)
	local a, b, c = ficha("a", 5, 5), ficha("b", 8, 5), ficha("c", 5, 8)
	local tokens = { a = a, b = b, c = c }
	local handlers, logs, movimentos, recibos = {}, {}, {}, {}
	local combat = { active = true, round = 1, turn = 1, current = "a" }
	local terrain, player = {}, { UserId = 123 }
	local registro = table.clone(Execucao)
	registro.MECANICAS = mecanicas
	registro.habilidadesDe = function() local ids = {}; for id in mecanicas do table.insert(ids, id) end; return ids end
	registro.bc = function() return 3 end
	registro.bonusDeRankDa = function() return 1 end
	registro.bandeiras = function() return {} end
	local api
	api = Servico.start({
		execucao = registro, handlers = handlers, tokens = tokens, tokenOrder = { "a", "b", "c" }, combat = combat,
		catalogo = Catalogo, terrain = terrain, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi) return math.clamp(rolagem or 10, lo, hi) end },
		remote = { FireClient = function(_, p, kind, data) table.insert(recibos, { player = p, kind = kind, data = data }) end },
		canSee = function(_, token) return not token.hidden end, currentTurnId = function() return combat.current end,
		logAboutToken = function(token, texto) table.insert(logs, { id = token.id, text = texto }) end,
		moverFicha = function(token, x, z)
			local deX, deZ = token.x, token.z
			token.x, token.z = x, z; token.version += 1
			table.insert(movimentos, token.id); api.moveu(token, deX, deZ)
		end,
		removerFicha = function() error("Não deveria remover ficha") end, reviverBoneco = function() end,
	})
	local function usar(id, alvoId, extra, master)
		local payload = { tokenId = combat.current, habilidadeId = id, alvoId = alvoId }
		for k, v in extra or {} do payload[k] = v end
		return handlers.usarHabilidade(player, payload, master == true)
	end
	local function vez(id)
		local anterior = combat.current
		combat.current = id; combat.turn += 1
		api.aoTrocarVez(anterior, id)
	end
	return { a = a, b = b, c = c, tokens = tokens, handlers = handlers, api = api, usar = usar, vez = vez,
		combat = combat, terrain = terrain, logs = logs, movimentos = movimentos, recibos = recibos, player = player }
end
local function tem(token, id)
	for _, c in token.conditions do if c.id == id then return true end end
	return false
end
local function efeito(extra)
	local m = { tipo = "efeito", acoes = 1, pm = 0, alcanceCasas = 20 }
	for k, v in extra or {} do m[k] = v end
	return m
end
local dano = efeito({ partes = { { fixo = 5 } } })
local cura = { tipo = "cura", acoes = 1, pm = 1, alcanceCasas = 20, partes = { { dados = "1d8", bc = true } }, dobraComFeridaFresca = true }

return {
	["servidor: patamar de personagem maior exige resistência"] = function(t)
		local x = contexto({ magia = efeito({ testeSoContraRankMaior = true, resistencia = { cdBase = 8, atributo = "vigor" }, aplica = "cego" }) }, 20)
		x.b.ficha2.calculated.highestRankBonus = 4
		t.eq(x.usar("magia", "b"), nil); t.ok(not tem(x.b, "cego"))
	end,
	["servidor: Força ou Agilidade usa Agilidade maior"] = function(t)
		local x = contexto({ magia = efeito({ resistencia = { cdBase = 8, atributo = "forcaOuAgilidade" }, aplica = "caido" }) }, 2)
		x.b.sheet.agilidade = 12
		t.eq(x.usar("magia", "b"), nil); t.ok(not tem(x.b, "caido"))
	end,
	["servidor: dano absorvido por PV temporários abre Ferida Fresca"] = function(t)
		local x = contexto({ dano = dano, cura = cura }, 4)
		x.b.pvTemp = 10
		t.eq(x.usar("dano", "b"), nil); t.eq(x.b.pv, 50); t.eq(x.b.pvTemp, 5)
		t.eq(x.usar("cura", "b"), nil); t.eq(x.b.pv, 61)
	end,
	["servidor: terminar turno do curador fecha a janela"] = function(t)
		local x = contexto({ dano = dano, cura = cura }, 4)
		t.eq(x.usar("dano", "b"), nil)
		x.vez("c"); x.vez("a")
		t.eq(x.usar("cura", "b"), nil); t.eq(x.b.pv, 52)
	end,
	["servidor: Selar preserva janela e selo sai ao encerrar combate"] = function(t)
		local x = contexto({ selo = efeito({ marca = "feridaSelada" }), cura = cura }, 4)
		t.eq(x.usar("selo", "b"), nil)
		x.vez("c"); x.vez("a")
		t.eq(x.usar("cura", "b"), nil); t.eq(x.b.pv, 61)
		x.api.combateEncerrado(); t.eq(x.b.feridaSeladaAte, nil); t.eq(x.b.feridaSelada, nil)
	end,
	["servidor: puxão move para adjacente por moverFicha"] = function(t)
		local x = contexto({ puxar = efeito({ puxar = true }) })
		t.eq(x.usar("puxar", "b"), nil)
		t.eq(x.b.x, 6); t.eq(x.b.z, 5); t.eq(x.movimentos[1], "b")
	end,
	["servidor: puxão não atravessa parede"] = function(t)
		local x = contexto({ puxar = efeito({ puxar = true }) })
		for z = 1, 24 do x.terrain["7:" .. z] = "parede" end
		t.ok(x.usar("puxar", "b") ~= nil); t.eq(x.b.x, 8); t.eq(x.a.mana, 100)
	end,
	["servidor: puxão sem destino livre não gasta Ações nem PM"] = function(t)
		local x = contexto({ puxar = efeito({ puxar = true, pm = 2 }) })
		for dx = -1, 1 do for dz = -1, 1 do
			if dx ~= 0 or dz ~= 0 then x.terrain[(5 + dx) .. ":" .. (5 + dz)] = "parede" end
		end end
		t.ok(x.usar("puxar", "b") ~= nil); t.eq(x.a.mana, 100); t.eq(x.api.estado().acoes.usadas, 0)
	end,
	["servidor: PT é cobrado uma vez e recusa não muda recursos"] = function(t)
		local x = contexto({ tecnica = efeito({ pt = 6, pm = 1 }) })
		t.eq(x.usar("tecnica", "b"), nil); t.eq(x.a.pt, 4); t.eq(x.a.mana, 99)
		t.ok(x.usar("tecnica", "b") ~= nil); t.eq(x.a.pt, 4); t.eq(x.a.mana, 99); t.eq(x.api.estado().acoes.usadas, 1)
	end,
	["servidor: investida não atravessa ficha no caminho"] = function(t)
		local x = contexto({ investida = { tipo = "investida", acoes = 1, pt = 1, alcanceCasas = 10, partes = { { arma = true, bc = true } } } })
		x.c.x, x.c.z = 6, 5
		t.ok(x.usar("investida", "b") ~= nil); t.eq(x.a.x, 5); t.eq(x.api.estado().acoes.usadas, 0)
	end,
	["servidor: empurrão chama integração do avatar"] = function(t)
		local x = contexto({ vento = efeito({ empurraCasas = 2 }) })
		t.eq(x.usar("vento", "b"), nil); t.eq(x.b.x, 10); t.eq(x.movimentos[1], "b")
	end,
	["servidor: duração expira no fim da próxima vez do alvo"] = function(t)
		local x = contexto({ cego = efeito({ aplica = "cego", duracao = { de = "alvo" } }) })
		t.eq(x.usar("cego", "b"), nil)
		x.vez("b"); t.ok(tem(x.b, "cego"))
		x.vez("c"); t.ok(not tem(x.b, "cego"))
	end,
	["servidor: renovar duração invalida o prazo antigo"] = function(t)
		local x = contexto({ cego = efeito({ aplica = "cego", duracao = { de = "alvo" } }) })
		t.eq(x.usar("cego", "b"), nil)
		x.vez("b"); x.vez("a")
		t.eq(x.usar("cego", "b"), nil)
		x.vez("c"); t.ok(tem(x.b, "cego"))
		x.vez("b"); x.vez("a"); t.ok(not tem(x.b, "cego"))
	end,
	["servidor: duração não remove condição pré-existente"] = function(t)
		local x = contexto({ cego = efeito({ aplica = "cego", duracao = { de = "alvo" } }) })
		x.b.conditions = { { id = "cego", stacks = 1 } }
		t.eq(x.usar("cego", "b"), nil); x.vez("b"); x.vez("a")
		t.ok(tem(x.b, "cego")); x.api.combateEncerrado(); t.ok(tem(x.b, "cego"))
	end,
	["servidor: PV temporários não acumulam e são limpos sem condição"] = function(t)
		local x = contexto({ vigor = { tipo = "cura", acoes = 1, pm = 0, alcanceCasas = 20, partes = { { fixo = 8 } }, pvTemporarios = true } })
		t.eq(x.usar("vigor", "b"), nil); t.eq(x.usar("vigor", "b"), nil); t.eq(x.b.pvTemp, 8)
		x.api.combateEncerrado(); t.eq(x.b.pvTemp, nil)
	end,
	["servidor: Molhado seca com fogo e impede Em Chamas nesse golpe"] = function(t)
		local x = contexto({ fogo = efeito({ partes = { { fixo = 5, tipo = "ígneo" } }, aplica = "em-chamas" }) })
		x.b.conditions = { { id = "molhado", stacks = 1 } }
		t.eq(x.usar("fogo", "b"), nil); t.eq(x.b.pv, 45)
		t.ok(not tem(x.b, "molhado")); t.ok(not tem(x.b, "em-chamas"))
	end,
	["servidor: incapacitado não pode apagar fogo"] = function(t)
		local x = contexto({})
		x.a.conditions = { { id = "em-chamas", stacks = 1 }, { id = "inconsciente", stacks = 1 } }
		t.ok(x.handlers.apagarFogo(x.player, { tokenId = "a" }, false) ~= nil)
		t.eq(x.api.estado().acoes.usadas, 0)
	end,
	["servidor: recusa controle alheio, custo, alcance e turno sem cobrar"] = function(t)
		local x = contexto({ teste = efeito({ pm = 3, pt = 2, alcanceCasas = 1 }) })
		t.ok(x.usar("teste", "b") ~= nil); t.eq(x.a.mana, 100)
		x.a.ownerUserId = 999
		t.ok(x.usar("teste", "b") ~= nil); t.eq(x.api.estado().acoes.usadas, 0)
		x.a.ownerUserId = 123; x.b.x = 6; x.a.pt = 0; x.a.ptMax = 10
		t.ok(x.usar("teste", "b") ~= nil); t.eq(x.a.mana, 100)
	end,
	["servidor: área não inclui alvo oculto no log público do conjurador"] = function(t)
		local x = contexto({ area = efeito({ alvo = "esferaNoConjurador", raioCasas = 5, partes = { { fixo = 2 } } }) })
		x.b.hidden = true; x.b.name = "SEGREDO_UNICO"
		t.eq(x.usar("area"), nil); t.eq(x.b.pv, 48)
		for _, log in x.logs do if log.id ~= "b" then t.ok(not string.find(log.text, "SEGREDO_UNICO", 1, true)) end end
	end,
}
