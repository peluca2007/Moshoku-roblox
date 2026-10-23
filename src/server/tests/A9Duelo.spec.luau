-- SOMENTE STUDIO: Duelo (PvP), Luta em grupo e escolha de personagem no
-- EncontroService real, com jogadores e mesa falsos (o MCP do Studio abre 1 jogador).
local Encontro = require(script.Parent.Parent.EncontroService)
local Treino = require(script.Parent.Parent.TreinoService)
local Trava = require(game:GetService("ReplicatedStorage").Shared.TravaPartida)
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(game:GetService("ReplicatedStorage").Shared.Livro.Catalogo)
local Execucao = require(game:GetService("ReplicatedStorage").Shared.Regras.Execucao)

local function mesa(nJogadores: number, master: boolean?)
	local jogadores = {}
	for i = 1, nJogadores do
		table.insert(jogadores, { UserId = 1000 + i, DisplayName = "Amigo" .. i })
	end
	local tokens, logs, avisos, criados, inicios = {}, {}, {}, {}, {}
	local combat = { active = false, turn = 0, round = 0, order = {} }
	local proximo = 0
	local pausar = false
	local montagem = Trava.new()
	local handlers = {}
	handlers.combatEnd = function() combat.active = false end
	handlers.tableClear = function() table.clear(tokens) end
	handlers.criarPremontado = function(_, p)
		if pausar then pausar = false; coroutine.yield("filtro de nome") end
		proximo += 1
		local id = "t" .. proximo
		tokens[id] = { id = id, name = p.id, kind = "jogador", ownerUserId = p.ownerUserId, x = p.x, z = p.z,
			pv = 30, pvMax = 30, mana = 8, manaMax = 8, version = 1, conditions = {},
			ficha2 = { calculated = { initiative = { bonus = 1 } } } }
		table.insert(criados, p.id)
		return nil, { id = id }
	end
	handlers.criarCriatura = function(_, p)
		proximo += 1
		local id = "t" .. proximo
		tokens[id] = { id = id, name = p.creatureId, kind = "npc", x = p.x, z = p.z, pv = 20, pvMax = 20, mana = 0, manaMax = 0, version = 1, conditions = {}, criatura = {} }
		return nil, { id = id }
	end
	handlers.combatStart = function(_, p)
		combat.active = true
		combat.turn += 1
		table.insert(inicios, p.entries)
	end
	handlers.createToken = function(_, p)
		proximo += 1
		local id = "t" .. proximo
		tokens[id] = { id = id, name = p.name, kind = p.kind, pv = p.pvMax, pvMax = p.pvMax, version = 1 }
		return nil, id
	end
	local api = Encontro.start({
		montagem = montagem,
		handlers = handlers, tokens = tokens, combat = combat,
		random = { NextInteger = function(_, lo) return lo end },
		remote = { FireAllClients = function(_, kind, data) table.insert(avisos, { kind = kind, data = data }) end },
		habilidades = function() return { turnoDoInimigo = function() return true end } end,
		avancarVez = function() end, mudou = function() end,
		logAll = function(texto) table.insert(logs, texto) end,
		currentTurnId = function() return nil end, desligarTreino = function() end,
		jogadores = function() return jogadores end, agora = function() return 100 end, esperaDoFim = 0,
	})
	local treino = Treino.start({
		montagem = montagem, handlers = handlers, tokens = tokens, combat = combat,
		personagemDe = api.personagemDe, avancarVez = function() end,
		mudou = function() end, logAll = function() end,
	})
	return { api = api, handlers = handlers, tokens = tokens, logs = logs, avisos = avisos, criados = criados,
		inicios = inicios, combat = combat, jogadores = jogadores, treino = treino,
		pausarCriacao = function() pausar = true end }
end
local function esperar(cond)
	for _ = 1, 40 do
		if cond() then return true end
		task.wait(0.1)
	end
	return false
end

return {
	["treino e encontros nao sobrepoem criacao durante filtro de nome"] = function(t)
		for _, modos in { { "iniciarTreino", "iniciarLuta" }, { "iniciarLuta", "iniciarTreino" },
			{ "iniciarTreino", "iniciarTreino" }, { "iniciarDuelo", "iniciarTreino" },
			{ "iniciarTreino", "iniciarDuelo" } } do
			local m = mesa(2)
			m.handlers.entrarFila(m.jogadores[2], { modo = "duelo" })
			m.pausarCriacao()
			local thread = coroutine.create(function()
				return m.handlers[modos[1]](m.jogadores[1], {}, true)
			end)
			local ok, etapa = coroutine.resume(thread)
			t.ok(ok, etapa); t.eq(etapa, "filtro de nome")
			t.ok(type(m.handlers[modos[2]](m.jogadores[2], {}, true)) == "string", table.concat(modos, "/"))
			t.ok(m.handlers.entrarFila(m.jogadores[2], { modo = "sair" }) ~= nil)
			t.eq(#m.criados, 0); t.eq(#m.inicios, 0)
			local terminou, erro = coroutine.resume(thread)
			t.ok(terminou, erro); t.eq(erro, nil); t.eq(#m.inicios, 1)
			t.eq(m.treino.ativo(), modos[1] == "iniciarTreino")
			m.api.desligar(); m.treino.desligar()
		end
	end,
	["recem-chegado nao entra em duelo ou luta sem consentir"] = function(t)
		local m = mesa(2)
		t.eq(m.handlers.iniciarDuelo(m.jogadores[1], {}, false), nil)
		t.eq(m.combat.active, false)
		t.eq(m.api.sala(m.jogadores[1]).suaFila, "duelo")
		t.eq(#m.criados, 0)
		m.handlers.entrarFila(m.jogadores[1], { modo = "sair" })
		t.eq(m.handlers.iniciarLuta(m.jogadores[1], {}, false), nil)
		t.eq(#m.criados, 1)
		m.api.desligar()
	end,
	["mestre tambem nao reinicia partida por clique acidental"] = function(t)
		local m = mesa(1)
		m.handlers.iniciarLuta(m.jogadores[1], {}, true)
		local antes = #m.criados
		t.ok(m.handlers.iniciarLuta(m.jogadores[1], {}, true) ~= nil)
		t.eq(#m.criados, antes)
		m.api.desligar()
	end,
	["fila valida modo e limpa jogador desconectado"] = function(t)
		local m = mesa(2)
		t.ok(m.handlers.entrarFila(m.jogadores[1], { modo = "todos" }) ~= nil)
		m.handlers.entrarFila(m.jogadores[1], { modo = "duelo" })
		m.api.remover(m.jogadores[1])
		t.eq(m.api.sala(m.jogadores[2]).duelo, 0)
	end,
	["escolha: personagem válido vale, inválido é recusado, padrão é o Ignis"] = function(t)
		local m = mesa(2)
		m.handlers.entrarFila(m.jogadores[2], { modo = "duelo" })
		local p = m.jogadores[1]
		t.eq(m.api.personagemDe(p), "mago-de-fogo")
		t.eq(m.handlers.escolherPersonagem(p, { id = "espadachim" }, false), nil)
		t.eq(m.api.personagemDe(p), "espadachim")
		t.ok(type(m.handlers.escolherPersonagem(p, { id = "dragao" }, false)) == "string")
		t.ok(type(m.handlers.escolherPersonagem(p, "x", false)) == "string")
		t.eq(m.api.personagemDe(p), "espadachim")
	end,
	["duelo: precisa de 2 jogadores"] = function(t)
		local m = mesa(1)
		t.ok(type(m.handlers.iniciarDuelo(m.jogadores[1], {}, false)) == "string")
		t.eq(m.combat.active, false)
	end,
	["duelo: cria o personagem escolhido de cada jogador e começa o combate"] = function(t)
		local m = mesa(2)
		m.handlers.entrarFila(m.jogadores[2], { modo = "duelo" })
		m.handlers.escolherPersonagem(m.jogadores[1], { id = "espadachim" }, false)
		m.handlers.escolherPersonagem(m.jogadores[2], { id = "arqueira" }, false)
		t.eq(m.handlers.iniciarDuelo(m.jogadores[1], {}, false), nil)
		t.eq(m.criados[1], "espadachim")
		t.eq(m.criados[2], "arqueira")
		t.eq(#m.inicios[1], 2)
		t.ok(m.api.emDuelo())
		m.api.desligar()
	end,
	["duelo: último de pé vence, todos se recuperam e o cliente é avisado"] = function(t)
		local m = mesa(2)
		m.handlers.entrarFila(m.jogadores[2], { modo = "duelo" })
		m.handlers.iniciarDuelo(m.jogadores[1], {}, false)
		local perdedor
		for _, tk in m.tokens do if tk.ownerUserId == 1002 then perdedor = tk end end
		perdedor.pv = 0
		t.ok(esperar(function() return #m.avisos > 0 end), "o duelo não terminou")
		t.eq(m.avisos[1].data.modo, "duelo")
		t.ok(string.find(m.avisos[1].data.vencedor or "", "Amigo1", 1, true) ~= nil, m.avisos[1].data.vencedor)
		t.eq(perdedor.pv, perdedor.pvMax)
		t.ok(not m.api.emDuelo())
	end,
	["duelo: invocado do vivo mantém o dono de pé"] = function(t)
		local m = mesa(2)
		m.handlers.entrarFila(m.jogadores[2], { modo = "duelo" })
		m.handlers.iniciarDuelo(m.jogadores[1], {}, false)
		local a
		for _, tk in m.tokens do if tk.ownerUserId == 1001 then a = tk end end
		m.tokens.inv = { id = "inv", name = "Cão", kind = "jogador", ownerUserId = 1001, pv = 10, pvMax = 10, version = 1, conditions = {} }
		a.pv = 0
		task.wait(0.4)
		t.eq(#m.avisos, 0, "o dono ainda tem o invocado de pé")
		m.api.desligar()
	end,
	["sem mestre, ninguém começa outro encontro com combate em andamento"] = function(t)
		local m = mesa(2)
		m.handlers.entrarFila(m.jogadores[2], { modo = "duelo" })
		m.handlers.iniciarDuelo(m.jogadores[1], {}, false)
		t.ok(type(m.handlers.iniciarLuta(m.jogadores[2], {}, false)) == "string")
		t.ok(type(m.handlers.iniciarDuelo(m.jogadores[2], {}, false)) == "string")
		m.api.desligar()
	end,
	["luta em grupo: 3 jogadores enfrentam o bando (4 criaturas)"] = function(t)
		local m = mesa(3)
		m.handlers.entrarFila(m.jogadores[2], { modo = "luta" })
		m.handlers.entrarFila(m.jogadores[3], { modo = "luta" })
		t.eq(m.handlers.iniciarLuta(m.jogadores[1], {}, false), nil)
		local criaturas, herois = 0, 0
		for _, tk in m.tokens do
			if tk.ia then criaturas += 1 elseif tk.kind == "jogador" then herois += 1 end
		end
		t.eq(herois, 3)
		t.eq(criaturas, 4)
		m.api.desligar()
	end,
	["prazo: com 2 jogadores a vez de um personagem ganha prazo"] = function(t)
		local m = mesa(2)
		m.handlers.entrarFila(m.jogadores[2], { modo = "duelo" })
		m.handlers.iniciarDuelo(m.jogadores[1], {}, false)
		local id
		for k in m.tokens do id = k end
		m.api.aoTrocarVez(id)
		local pub = m.api.publico()
		t.eq(pub.modo, "duelo")
		t.eq(pub.prazoFim, 160)
		t.eq(pub.prazoId, id)
		m.api.desligar()
	end,
	["aliado no duelo: Puxar (só aliados) não alcança o adversário"] = function(t)
		local function ficha(id, dono, x)
			return { id = id, name = id, x = x, z = 5, kind = "jogador", ownerUserId = dono, pv = 30, pvMax = 30, mana = 10, manaMax = 10,
				version = 1, conditions = {}, sheet = { ca = 10 },
				ficha2 = { construction = { unlockedRankIds = {}, purchasedIds = {}, inventory = {} },
					calculated = { highestRankBonus = 1, attributes = { forca = 0, agilidade = 0, vigor = 2 }, maxima = { pt = 10 } },
					session = { current = { pt = 10 } } } }
		end
		local function tentar(duelo: boolean)
			local a, b = ficha("a", 1001, 5), ficha("b", 1002, 8)
			local tokens = { a = a, b = b }
			local handlers = {}
			local combat = { active = true, round = 1, turn = 1, order = { "a", "b" }, turnIndex = 1 }
			local registro = table.clone(Execucao)
			local id = "ability/cavalaria-e-escudos/Principiante/puxar"
			registro.MECANICAS = { [id] = Execucao.MECANICAS[id] }
			registro.habilidadesDe = function() return { id } end
			registro.bc = function() return 2 end
			registro.bonusDeRankDa = function() return 1 end
			registro.bandeiras = function() return {} end
			Servico.start({
				execucao = registro, handlers = handlers, tokens = tokens, tokenOrder = { "a", "b" }, combat = combat,
				catalogo = Catalogo, terrain = {}, cellKey = function(x, z) return x .. ":" .. z end,
				random = { NextInteger = function(_, lo, hi) return math.clamp(10, lo, hi) end },
				remote = { FireClient = function() end }, canSee = function() return true end,
				currentTurnId = function() return "a" end, logAboutToken = function() end,
				moverFicha = function(tk, x, z) tk.x, tk.z = x, z end, removerFicha = function() end, reviverBoneco = function() end,
				emDuelo = function() return duelo end,
			})
			return handlers.usarHabilidade({ UserId = 1001 }, { tokenId = "a", habilidadeId = id, alvoId = "b" }, false)
		end
		t.eq(tentar(false), nil, "fora do duelo, o outro jogador é aliado")
		t.ok(type(tentar(true)) == "string", "no duelo, o adversário não é aliado")
	end,
}
