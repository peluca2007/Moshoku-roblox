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
	local combat = { active = true, round = 1, turn = 1, current = "a", order = { "a", "b", "c" }, turnIndex = 1 }
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

local function carta(arvore, id) return "ability/" .. arvore .. "/Principiante/" .. id end
local function ctx(arvore, id, rolagem)
 local chave = carta(arvore, id)
 return contexto({ [chave] = Execucao.MECANICAS[chave] }, rolagem), chave
end
return {
 ["árvores servidor: Corte de Braço contra Santo larga arma sem inutilizar braço"] = function(t)
  local x,id=ctx("deus-da-espada","corte-de-braco",10)
  x.b.x=6; x.b.ficha2.calculated.highestRankBonus=4
  x.b.ficha2.construction.inventory={{name="Espada Longa",type="arma",equipped=true,baseDie="d8"}}
  x.b.sheet.vigor=-20 -- acerto e teste falho, explicitamente
  t.eq(x.usar(id,"b"),nil); t.eq(x.api.estado().acoes.usadas,1)
  t.eq(x.b.ficha2.construction.inventory[1].equipped,false)
  t.eq(#x.api.estado().objetos,1)
  t.eq(table.find(x.api.estadosDe(x.b),"bracoInutil"),nil)
 end,
 ["árvores servidor: Escudo de Água corta fogo que cruza a barreira"] = function(t)
  local escudo, fogo = carta("agua", "escudo-de-agua"), "ability/fogo/Principiante/bola-de-fogo"
  local x = contexto({ [escudo] = Execucao.MECANICAS[escudo], [fogo] = Execucao.MECANICAS[fogo] }, 12)
  t.eq(x.usar(escudo, nil, {x=7,z=5}),nil); x.vez("b")
  t.eq(x.usar(fogo, "a"),nil); t.eq(x.a.pv,45)
 end,
 ["árvores servidor: Cabeçada também tira a única ação do Pacto"] = function(t)
  local cabeca = carta("armas-pesadas", "cabecada")
  local x = contexto({ [cabeca] = Execucao.MECANICAS[cabeca] }, 9)
  x.b.x=6; x.b.invocado={pactoId="talent/invocacao/Principiante/pacto-cao-de-caca",bc=1,ca=10,rank=1,rodadaFim=600}
  t.eq(x.usar(cabeca,"b"),nil); x.vez("b"); t.eq(x.api.estado().acoes.total,0)
  t.ok(x.usar("invocado/ataque","a")~=nil); t.eq(x.api.estado().acoes.usadas,0)
 end,
 ["árvores servidor: lista validada antes de gastar"] = function(t)
  local x, id = ctx("terra", "lanca-de-pedra", 1)
  t.ok(x.usar(id, nil, { alvoIds = { "b", "b" } }) ~= nil); t.eq(x.a.mana, 100)
  t.eq(x.usar(id, nil, { alvoIds = { "b", "c" } }), nil)
  t.eq(x.b.pv, 48); t.eq(x.c.pv, 48); t.ok(tem(x.b, "atolado")); t.eq(x.a.mana, 98)
 end,
 ["árvores servidor: Antídoto em si impede Dose"] = function(t)
  local antidoto, peconha = carta("desintoxicacao", "antidoto"), carta("desintoxicacao", "peconha")
  local x = contexto({ [antidoto] = Execucao.MECANICAS[antidoto], [peconha] = Execucao.MECANICAS[peconha] }, 1)
  t.eq(x.usar(antidoto, nil, { alvoIds = { "a" } }), nil); x.vez("b")
  t.eq(x.usar(peconha, "a"), nil); t.ok(not tem(x.a, "dose"))
 end,
 ["árvores servidor: Cabecada reduz orçamento real de ações"] = function(t)
  local cabeca, rajada = carta("armas-pesadas", "cabecada"), carta("vento", "rajada-curta")
  local x = contexto({ [cabeca] = Execucao.MECANICAS[cabeca], [rajada] = Execucao.MECANICAS[rajada] }, 9)
  x.b.x = 6; t.eq(x.usar(cabeca, "b"), nil); x.vez("b")
  t.eq(x.api.estado().acoes.total, 2)
 end,
 ["árvores servidor: provocação recusa outro alvo sem cobrar"] = function(t)
  local provocar, rajada = carta("deus-da-agua-corpo", "provocar"), carta("vento", "rajada-curta")
  local x = contexto({ [provocar] = Execucao.MECANICAS[provocar], [rajada] = Execucao.MECANICAS[rajada] }, 1)
  t.eq(x.usar(provocar, "b"), nil); x.vez("b")
  t.ok(x.usar(rajada, "c") ~= nil); t.eq(x.b.mana, 100); t.eq(x.api.estado().acoes.usadas, 0)
 end,
 ["árvores servidor: Atoleiro cria terreno difícil e limpa no fim"] = function(t)
  local x, id = ctx("terra", "atoleiro", 20)
  t.eq(x.usar(id), nil); t.eq(#x.api.estado().muros, 1)
  x.vez("b"); t.ok(x.api.validarMovimento(x.b, 5, 9, true) ~= nil)
  x.api.combateEncerrado(); t.eq(#x.api.estado().muros, 0)
 end,
 ["árvores servidor: chamado cria turno do Pacto e impede segundo ativo"] = function(t)
  local x, id = ctx("invocacao", "chamado", 10)
  x.a.ficha2.construction.purchasedIds = { "talent/invocacao/Principiante/pacto-cao-de-caca" }
  t.eq(x.usar(id), nil); t.eq(x.a.mana, 93)
  local invocado
  for _, token in x.tokens do if token.invocado then invocado = token end end
  t.ok(invocado); t.eq(invocado.pv, 10); t.eq(invocado.pvMax, 20); t.eq(x.combat.order[2], invocado.id)
  x.vez(invocado.id); t.eq(x.api.estado().acoes.total, 1); t.eq(x.api.habilidadesDe(invocado)[1], "invocado/ataque")
  x.vez("a"); t.ok(x.usar(id) ~= nil); t.eq(x.a.mana, 93)
  x.api.combateEncerrado(); t.eq(x.tokens[invocado.id], nil)
 end,
 ["árvores servidor: cartas manuais não cobram recursos"] = function(t)
  local id = carta("cura", "estancar"); local x = contexto({ [id] = { tipo="efeito", acoes=2, pm=2 } })
  t.ok(x.usar(id, "b") ~= nil); t.eq(x.a.mana, 100); t.eq(x.api.estado().acoes.usadas, 0)
 end,
 ["árvores servidor: movimento normal custa uma ação"] = function(t)
  local x = contexto({ magia = dano }); t.eq(x.api.validarMovimento(x.a, 7, 5, true), nil); t.eq(x.api.estado().acoes.usadas, 1)
  t.ok(x.api.validarMovimento(x.a, 15, 5, true) ~= nil); t.eq(x.api.estado().acoes.usadas, 1)
 end,
}
