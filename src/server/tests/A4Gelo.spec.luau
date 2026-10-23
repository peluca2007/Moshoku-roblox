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
			calculated = { highestRankBonus = 1, attributes = { forca = 2, agilidade = 4, vigor = 3, intelecto = 5 }, maxima = { pt = 10 } },
			session = { current = { pt = 10 } } },
	}
end
local function contexto(mecanicas, rolagem)
	local a, b, c = ficha("a", 5, 5), ficha("b", 8, 5), ficha("c", 5, 8)
	local tokens = { a = a, b = b, c = c }
	local handlers, logs, movimentos, recibos = {}, {}, {}, {}
	local combat = { active = true, round = 1, turn = 1, current = "a", order = { "a", "b", "c" }, turnIndex = 1 }
	local terrain, player = {}, { UserId = 123 }
	local registro = table.clone(Execucao)
	registro.MECANICAS = mecanicas
	registro.habilidadesDe = function() local ids = {}; for id, m in mecanicas do if not m.exigeArmaGelo then table.insert(ids, id) end end; return ids end
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
		removerFicha = function(id) tokens[id] = nil end, reviverBoneco = function() end,
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
local CAST = "ability/agua/Principiante/lamina-de-gelo"
local FORCA, INT = "mesa/lamina-de-gelo-forca", "mesa/lamina-de-gelo-intelecto"
local function gelo(rolagem)
 local x = contexto({ [CAST] = Execucao.MECANICAS[CAST], [FORCA] = Execucao.MECANICAS[FORCA], [INT] = Execucao.MECANICAS[INT] }, rolagem)
 x.b.x = 6
 return x
end
return {
 ["gelo: ataque forjado sem conjuração não cobra"] = function(t)
  local x = gelo(10)
  t.ok(x.usar(FORCA,"b") ~= nil); t.eq(x.api.estado().acoes.usadas,0); t.eq(x.a.mana,100); t.eq(x.b.pv,50)
 end,
 ["gelo: conjura e ataca por uma ação sem gastar mais PM"] = function(t)
  local x = gelo(10)
  t.eq(x.usar(CAST),nil); t.eq(x.a.mana,98); t.eq(x.api.estado().acoes.usadas,2)
  t.eq(x.usar(FORCA,"b"),nil); t.eq(x.b.pv,35); t.eq(x.a.mana,98); t.eq(x.api.estado().acoes.usadas,3)
  t.ok(x.usar(INT,"b") ~= nil); t.eq(x.b.pv,35)
 end,
 ["gelo: escolha do atributo muda acerto mas não BC do dano"] = function(t)
  local f, i = gelo(10), gelo(10); f.b.sheet.ca=15; i.b.sheet.ca=15
  t.eq(f.usar(CAST),nil); t.eq(i.usar(CAST),nil)
  t.eq(f.usar(FORCA,"b"),nil); t.eq(i.usar(INT,"b"),nil)
  t.eq(f.b.pv,50); t.eq(i.b.pv,35)
 end,
 ["gelo: Molhado dobra apenas a parcela de frio"] = function(t)
  local x = gelo(10); x.b.conditions = { { id="molhado" } }
  t.eq(x.usar(CAST),nil); t.eq(x.usar(INT,"b"),nil); t.eq(x.b.pv,31)
 end,
 ["gelo: alcance inválido não gasta a última ação"] = function(t)
  local x = gelo(10); t.eq(x.usar(CAST),nil); x.b.x=12
  t.ok(x.usar(INT,"b") ~= nil); t.eq(x.api.estado().acoes.usadas,2); t.eq(x.b.pv,50)
 end,
 ["gelo: dez rodadas expiram a arma e impedem nova intenção"] = function(t)
  local x = gelo(10); t.eq(x.usar(CAST),nil)
  x.combat.round=10; x.vez("a"); t.ok(table.find(x.api.habilidadesDe(x.a),INT))
  x.combat.round=11; x.vez("a"); t.ok(not table.find(x.api.habilidadesDe(x.a),INT)); t.ok(x.usar(INT,"b") ~= nil); t.eq(x.api.estado().acoes.usadas,0)
 end,
 ["gelo: fim de combate remove autorização mesmo com ID conhecido"] = function(t)
  local x = gelo(10); t.eq(x.usar(CAST),nil); x.api.combateEncerrado(); x.vez("a")
  t.ok(x.usar(INT,"b") ~= nil); t.eq(x.b.pv,50)
 end,
}
