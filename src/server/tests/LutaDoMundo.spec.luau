-- SOMENTE STUDIO: ponte patrulha -> luta da mesa -> volta ao mapa (PLANO §13), com serviços reais e fichas falsas.
local Encontro = require(script.Parent.Parent.EncontroService)
local LutaDoMundo = require(script.Parent.Parent.LutaDoMundoServico)
local Protocol = require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)
local Players = game:GetService("Players")

local function mesa()
	local p, outro = { UserId = 101 }, { UserId = 202 }
	local d = { handlers = {}, tokens = {}, combat = { active = false }, random = Random.new(7),
		remote = { FireClient = function() end, FireAllClients = function() end },
		jogadores = function() return { p, outro } end,
		avancarVez = function() end, mudancas = 0, logAll = function() end,
		currentTurnId = function() return nil end, desligarTreino = function() end }
	function d.mudou() d.mudancas += 1 end
	local seq, inicio, limpezas = 0, nil, 0
	local function novo(tabela)
		seq += 1
		tabela.id, tabela.version = "t" .. seq, 1
		d.tokens[tabela.id] = tabela
		return tabela.id
	end
	local hab = { criarPersonagemPessoal = function(_, corpo, posicao)
		return nil, { id = novo({ kind = "jogador", ownerUserId = posicao.ownerUserId, pv = 20, pvMax = 20, x = posicao.x, z = posicao.z, pessoal = corpo }) }
	end }
	d.habilidades = function() return hab end
	d.handlers.criarPremontado = function() return "Não deveria montar o pronto da sala." end
	d.handlers.criarCriatura = function(_, payload)
		return nil, { id = novo({ kind = "npc", catalogId = payload.creatureId, papel = payload.papel, pv = 10, pvMax = 10, x = payload.x, z = payload.z }) }
	end
	d.handlers.combatStart = function(_, payload) d.combat.active = true; inicio = payload end
	d.handlers.combatEnd = function() d.combat.active = false end
	d.handlers.tableClear = function() limpezas += 1; table.clear(d.tokens) end
	d.corpoPessoal = function(player) return if player.UserId == 101 then { dono = 101 } else nil, "Perfil ausente." end
	local api = Encontro.start(d)
	return d, api, p, outro, function() return inicio end, function() return limpezas end
end

local function personagem(nome, posicao)
	local modelo = Instance.new("Model")
	modelo.Name = nome
	local raiz = Instance.new("Part")
	raiz.Name, raiz.Anchored, raiz.Position = "HumanoidRootPart", false, posicao
	raiz.Parent = modelo
	Instance.new("Humanoid").Parent = modelo
	modelo.Parent = workspace
	return modelo, raiz
end

local function ponte(jogadores, opcoes)
	opcoes = opcoes or {}
	local registro = { lutas = {}, pagos = {}, cenarios = {}, encerrados = {}, avisos = {} }
	local relogio = 0
	local api = LutaDoMundo.start({
		jogadores = function() return jogadores end,
		agora = function() return relogio end,
		rng = function() return 0.5 end,
		corpoPessoal = opcoes.corpoPessoal or function() return { session = { current = { pv = 10 } } } end,
		iniciarLuta = function(grupo, criaturas, info)
			table.insert(registro.lutas, { grupo = grupo, criaturas = criaturas, info = info })
			return opcoes.erroInicio
		end,
		recompensar = function(player, id, moedas, marco, pa)
			table.insert(registro.pagos, { player = player, id = id, moedas = moedas, marco = marco, pa = pa })
			return true, moedas
		end,
		avisarRecompensa = function(player, recompensa) table.insert(registro.avisos, { player = player, recompensa = recompensa }) end,
		cenario = { aplicar = function(arena) table.insert(registro.cenarios, arena or "livro") end },
		aoEncerrar = function(encontro, estado) table.insert(registro.encerrados, { encontro = encontro, estado = estado }) end,
	})
	local patrulha = { ocupada = nil, derrotas = 0 }
	function patrulha.ocupar(valor) patrulha.ocupada = valor end
	function patrulha.derrotada() patrulha.derrotas += 1 end
	return api, registro, patrulha, function(dt) relogio += dt end
end

local CELEIRO = { id = "ratos-celeiro", nome = "Ratos no celeiro", zona = "region/clareira-inicial",
	marco = "region/encounter/clearing", criatura = "creature/rato-gigante" }

return {
	["luta do mundo usa a ficha propria mesmo com o pronto escolhido na sala"] = function(t)
		local d, api, p, _, inicio = mesa()
		t.eq(d.handlers.escolherPersonagem(p, { id = "mago-de-fogo" }), nil)
		t.eq(api.iniciarLutaDoMundo({ p }, { "creature/rato-gigante", "creature/rato-gigante" }, { nome = "Ratos" }), nil)
		t.ok(d.combat.active)
		t.ok(d.mudancas > 0, "o início envia o snapshot: sem remoto, o cliente não veria a luta")
		local jogador, inimigos = nil, 0
		for _, token in d.tokens do
			if token.kind == "jogador" then jogador = token else inimigos += 1; t.eq(token.ia, true) end
		end
		t.eq(jogador.pessoal.dono, 101, "ficha pessoal, não o pronto da sala")
		t.eq(inimigos, 2)
		t.eq(#inicio().entries, 3)
		t.eq(api.personagemDe(p), "mago-de-fogo", "a escolha da sala continua a mesma")
		api.desligar()
	end,
	["luta do mundo recusa perfil ausente antes de limpar a mesa e recusa combate em andamento"] = function(t)
		local d, api, _, outro, _, limpezas = mesa()
		t.ok(api.iniciarLutaDoMundo({ outro }, { "creature/rato-gigante" }) ~= nil)
		t.eq(limpezas(), 0)
		t.eq(d.combat.active, false)
		d.combat.active = true
		t.ok(api.iniciarLutaDoMundo({ outro }, { "creature/rato-gigante" }) ~= nil)
		t.ok(api.iniciarLutaDoMundo({}, { "creature/rato-gigante" }) ~= nil)
	end,
	["mesa limpa no meio da luta do mundo avisa a ponte para devolver o grupo"] = function(t)
		local _, api, p = mesa()
		local resultado
		t.eq(api.iniciarLutaDoMundo({ p }, { "creature/rato-gigante" }, { aoTerminar = function(r) resultado = r end }), nil)
		api.desligar()
		t.eq(resultado, "cancelada")
	end,
	["ponte junta quem esta perto, ancora na entrada da arena e devolve ao ponto do contato"] = function(t)
		local m1, r1 = personagem("A", Vector3.new(10, 5, -80))
		local m2, r2 = personagem("B", Vector3.new(30, 5, -80))
		local m3, r3 = personagem("C", Vector3.new(200, 5, -80))
		local a = { UserId = 1, Character = m1, Parent = Players }
		local b = { UserId = 2, Character = m2, Parent = Players }
		local c = { UserId = 3, Character = m3, Parent = Players }
		local api, registro, patrulha = ponte({ a, b, c })
		t.eq(api.iniciar(a, patrulha, CELEIRO), true)
		local luta = registro.lutas[1]
		t.eq(#luta.grupo, 2, "quem está longe fica de fora")
		t.eq(#luta.criaturas, 2, "um rato por jogador")
		t.eq(registro.cenarios[1], "cidade")
		t.ok(r1.Anchored and r2.Anchored and not r3.Anchored)
		t.ok(r1.Position.Z > Protocol.BOARD.origin.Z, "grupo posto na beira sul do tabuleiro")
		t.eq(api.ativa(), true)
		t.eq(api.iniciar(a, patrulha, CELEIRO), false, "uma luta do mundo por vez")
		luta.info.aoTerminar("vitoria")
		t.eq(api.ativa(), false)
		t.ok((r1.Position - Vector3.new(10, 5, -80)).Magnitude < 0.01 and not r1.Anchored)
		t.ok((r2.Position - Vector3.new(30, 5, -80)).Magnitude < 0.01 and not r2.Anchored)
		t.eq(patrulha.derrotas, 1)
		t.eq(patrulha.ocupada, false)
		t.eq(#registro.pagos, 2)
		t.ok(registro.pagos[1].moedas > 0)
		t.eq(registro.pagos[1].marco, "region/encounter/clearing")
		-- Cada jogador recebe o ouro creditado para a tela de vitória.
		t.eq(#registro.avisos, 2)
		t.eq(registro.avisos[1].player, registro.pagos[1].player)
		t.eq(registro.avisos[1].recompensa.ouro, registro.pagos[1].moedas)
		t.eq(registro.avisos[1].recompensa.total, registro.pagos[1].moedas)
		t.eq(registro.cenarios[#registro.cenarios], "livro")
		t.eq(registro.encerrados[1].estado.phase, "victory")
		t.ok(registro.encerrados[1].encontro.atoresPorJogador[1] and registro.encerrados[1].encontro.atoresPorJogador[2])
		for _, m in { m1, m2, m3 } do m:Destroy() end
	end,
	["derrota nao paga nem derrota a patrulha e a tregua impede recomeco imediato"] = function(t)
		local m1 = personagem("A", Vector3.new(0, 5, -80))
		local a = { UserId = 1, Character = m1, Parent = Players }
		local api, registro, patrulha, passar = ponte({ a })
		t.eq(api.iniciar(a, patrulha, CELEIRO), true)
		registro.lutas[1].info.aoTerminar("derrota")
		t.eq(#registro.pagos, 0)
		t.eq(#registro.avisos, 0, "derrota não anuncia ouro")
		t.eq(patrulha.derrotas, 0)
		t.eq(registro.encerrados[1].estado.phase, "defeat")
		t.eq(api.iniciar(a, patrulha, CELEIRO), false, "trégua logo após a luta")
		local idDojo = api.iniciarProvaDojo(a)
		t.ok(idDojo ~= nil, "a trégua não barra o que o jogador pediu")
		registro.lutas[#registro.lutas].info.aoTerminar("cancelada")
		t.eq(api.iniciar(a, patrulha, CELEIRO), false, "trégua renovada pela luta pedida")
		passar(LutaDoMundo.TREGUA_SEGUNDOS + 1)
		t.eq(api.iniciar(a, patrulha, CELEIRO), true)
		registro.lutas[#registro.lutas].info.aoTerminar("cancelada")
		m1:Destroy()
	end,
	["inicio recusado devolve cenario e solta o personagem"] = function(t)
		local m1, r1 = personagem("A", Vector3.new(0, 5, -80))
		local a = { UserId = 1, Character = m1, Parent = Players }
		local api, registro, patrulha = ponte({ a }, { erroInicio = "Já há um combate em andamento." })
		t.eq(api.iniciar(a, patrulha, CELEIRO), false)
		t.eq(api.ativa(), false)
		t.ok(not r1.Anchored and (r1.Position - Vector3.new(0, 5, -80)).Magnitude < 0.01)
		t.eq(registro.cenarios[#registro.cenarios], "livro")
		m1:Destroy()
	end,
	["ponte recusa quem esta sem ficha ou caido"] = function(t)
		local m1 = personagem("A", Vector3.new(0, 5, -80))
		local a = { UserId = 1, Character = m1, Parent = Players }
		local api, registro, patrulha = ponte({ a }, { corpoPessoal = function() return { session = { current = { pv = 0 } } } end })
		t.eq(api.iniciar(a, patrulha, CELEIRO), false)
		t.eq(#registro.lutas, 0)
		m1:Destroy()
	end,
	["luta do mundo repassa o papel pedido pela composicao"] = function(t)
		local d, api, p = mesa()
		t.eq(api.iniciarLutaDoMundo({ p }, { { id = "creature/urso-de-presas-vermelhas", papel = "lacaio" }, "creature/lobo-cinzento" }), nil)
		local papeis = {}
		for _, token in d.tokens do if token.kind == "npc" then papeis[token.catalogId] = token.papel or "catalogo" end end
		t.eq(papeis["creature/urso-de-presas-vermelhas"], "lacaio")
		t.eq(papeis["creature/lobo-cinzento"], "catalogo")
		api.desligar()
	end,
	["guardiao da run vai para a arena da regiao e devolve o id que a run espera"] = function(t)
		local m1 = personagem("A", Vector3.new(0, 5, -420))
		local a = { UserId = 1, Character = m1, Parent = Players }
		local api, registro = ponte({ a })
		local id, erro = api.iniciarChefe({ a }, { areaId = "region/encounter/dark-forest", criaturas = { "creature/urso-de-presas-vermelhas" } })
		t.ok(id ~= nil, tostring(erro))
		local luta = registro.lutas[1]
		t.eq(registro.cenarios[1], "floresta")
		t.eq(type(luta.criaturas[1]), "table")
		t.eq(luta.criaturas[1].papel, "lacaio", "urso sozinho contra um jogador entra como lacaio, como no J2")
		luta.info.aoTerminar("vitoria")
		t.eq(registro.encerrados[1].estado.encounterId, id)
		t.eq(registro.encerrados[1].estado.phase, "victory")
		t.eq(registro.pagos[1].marco, "region/encounter/dark-forest")
		t.eq(api.iniciarChefe({}, { areaId = "region/encounter/ruinas", criaturas = { "creature/goblin-batedor" } }), nil)
		m1:Destroy()
	end,
	["marco usa o elenco do marco e a arena do campo"] = function(t)
		local m1 = personagem("A", Vector3.new(0, 5, -80))
		local a = { UserId = 1, Character = m1, Parent = Players }
		local api, registro = ponte({ a })
		local ok = api.iniciarMarco(a, "region/encounter/clearing")
		t.eq(ok, true)
		t.eq(registro.cenarios[1], "campo")
		t.ok(#registro.lutas[1].criaturas >= 1)
		local recusado, motivo = api.iniciarMarco(a, "region/encounter/clearing")
		t.eq(recusado, false)
		t.ok(motivo ~= nil)
		registro.lutas[1].info.aoTerminar("derrota")
		t.eq(#registro.pagos, 0)
		m1:Destroy()
	end,
	["provacao do dojo luta um lobo na cidade sem ouro e avisa o dojo pelo participante"] = function(t)
		local m1 = personagem("A", Vector3.new(0, 5, -150))
		local a = { UserId = 7, Character = m1, Parent = Players }
		local api, registro = ponte({ a })
		local id = api.iniciarProvaDojo(a)
		t.ok(id ~= nil)
		t.eq(registro.cenarios[1], "cidade")
		t.eq(#registro.lutas[1].criaturas, 1)
		t.eq(registro.lutas[1].criaturas[1], "creature/lobo-cinzento")
		registro.lutas[1].info.aoTerminar("vitoria")
		t.eq(#registro.pagos, 0, "o dojo dá a própria recompensa")
		t.eq(#registro.avisos, 0)
		local fim = registro.encerrados[1]
		local atorId = fim.encontro.ordemInicial[1]
		t.eq(fim.encontro.atoresPorId[atorId].userId, 7)
		t.eq(fim.estado.encounterId, id)
		m1:Destroy()
	end,
}
