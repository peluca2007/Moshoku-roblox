-- SOMENTE STUDIO: valida a fronteira autenticada de fuga e retorno em grupo.
local Service = require(script.Parent.Parent.EncontroAutonomoService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)
local Criaturas = require(ReplicatedStorage.Shared.Regras.Criaturas)

local function novoServico(valores)
	local a, b, estranho = { UserId = 101 }, { UserId = 202 }, { UserId = 303 }
	local jogadores = { [101] = a, [202] = b, [303] = estranho }
	local envios, tempo, remoto, indice = {}, 0, {}, 0
	local prazos = {}
	remoto.OnServerEvent = { Connect = function(_, callback) remoto.handler = callback end }
	local api = Service.start({
		remote = remoto,
		localizarJogador = function(userId) return jogadores[userId] end,
		conectado = function(player) return jogadores[player.UserId] == player end,
		novoId = function() return "r2c-fuga" end,
		agora = function() return tempo end,
		agendarPrazo = function(segundos, callback)
			table.insert(prazos, { segundos = segundos, callback = callback })
		end,
		cancelarPrazo = function() end,
		rng = { NextInteger = function(_, minimo, maximo)
			indice += 1
			return math.clamp(valores[indice] or minimo, minimo, maximo)
		end },
		emitir = function(player, tipo, dados)
			table.insert(envios, { player = player, tipo = tipo, dados = dados })
		end,
	})
	local function criar(grupo, pv, interior)
		local ficha = {
			calculated = { attributes = { vigor = 0, forca = 0 },
				skills = { { skillId = "skill/atletismo", bonus = 3, trained = true } },
				maxima = { pv = 30, pm = 0 }, armorClass = 10, movementMeters = 9 },
			session = { current = { pv = pv or 23, pm = 0 } },
		}
		local atores = {
			{ id = "jogador-a", userId = a.UserId, kind = "jogador", ficha = ficha, x = if interior then 10 else 1, z = 10 },
			{ id = "criatura", kind = "criatura", x = 2, z = 11,
				fichaCriatura = Criaturas.ficha(Catalogo.POR_ID["creature/goblin-batedor"]) },
		}
		if grupo then
			table.insert(atores, 2, { id = "jogador-b", userId = b.UserId, kind = "jogador", x = 1, z = 11,
				ficha = { calculated = { attributes = { vigor = 0, forca = 0 },
					skills = { { skillId = "skill/atletismo", bonus = 0, trained = true } },
					maxima = { pv = 30, pm = 0 }, armorClass = 10, movementMeters = 9 },
					session = { current = { pv = 30, pm = 0 } } } })
		end
		return api.criar(atores)
	end
	return api, a, b, estranho, envios, jogadores, function(delta) tempo += delta end, criar, remoto, prazos
end

local function pedido(id, versao, requestId)
	return { command = "flee-encounter", encounterId = id, expectedVersion = versao, requestId = requestId }
end

return {
	["fugitivo retornado não impede limpar grupo desconectado após 60 segundos"] = function(t)
		local api, a, b, _, _, jogadores, avancar, criar, _, prazos = novoServico({ 20 })
		local id = criar(true)
		t.eq(api.solicitarFuga(a, pedido(id, 1, "fugiu-antes-desconexao")), true)
		t.eq(api.solicitarRetorno(a, { command = "return-autonomous", encounterId = id, requestId = "voltou" }), true)
		jogadores[b.UserId] = nil
		api.notificarDesconexao(b)
		avancar(60)
		prazos[#prazos].callback()
		t.eq(api.estado(id), nil, "o fugitivo conectado não segura a arena")
	end,
	["fuga exige borda tática sem consumir Ação nem rolar no interior"] = function(t)
		local api, a, _, _, envios, _, _, criar = novoServico({ 20 })
		local id = criar(true, 17, true)
		t.eq(api.solicitarFuga(a, pedido(id, 1, "interior")), false)
		t.eq(api.estado(id).version, 1)
		t.eq(api.estado(id).actionsRemaining, 3)
		t.eq(envios[#envios].dados.mensagem, "Chegue à borda da grade para fugir.")
	end,
	["fuga recusa autenticacao, campos extras, fase ou versao incorretas sem alterar encontro"] = function(t)
		local api, a, b, estranho, envios, _, _, criar = novoServico({ 1 })
		local id = criar(true)
		local inicial = api.estado(id)
		local base = pedido(id, inicial.version, "fuga-validacao")
		local extra = table.clone(base)
		extra.actorId = "jogador-a"
		t.eq(api.solicitarFuga(a, extra), false)
		t.eq(api.solicitarFuga(estranho, base), false)
		local antiga = table.clone(base)
		antiga.expectedVersion -= 1
		t.eq(api.solicitarFuga(a, antiga), false)
		t.eq(api.solicitarFuga(b, base), false, "aliado fora da vez não pode fugir")
		t.eq(api.estado(id).version, inicial.version)
		t.eq(api.estado(id).phase, "active")
		t.eq(envios[#envios].tipo, "recusado")
	end,
	["falha no teste de Atletismo gasta uma acao, encerra a vez e emite recibo"] = function(t)
		local api, a, b, _, envios, _, _, criar = novoServico({ 1, 20 })
		local id = criar(true)
		local ok, recibo = api.solicitarFuga(a, pedido(id, 1, "fuga-falhou"))
		t.eq(ok, true)
		t.eq(recibo.action, "flee-encounter")
		t.eq(recibo.result.fugiu, false)
		t.eq(recibo.result.natural, 1)
		t.eq(recibo.result.total, 4, "inclui o bônus de Atletismo da ficha")
		t.eq(recibo.result.cd, 10, "criatura canônica desloca o CD para 10")
		t.eq(recibo.result.perdeTurno, true)
		t.eq(api.estado(id).currentActorId, "jogador-b", "falha passa a vez ao aliado")
		local recibos = {}
		for _, envio in envios do
			if envio.tipo == "recibo" and envio.dados.action == "flee-encounter" then
				table.insert(recibos, envio)
			end
		end
		t.eq(#recibos, 2, "recibo compartilhado com o grupo")
		local versaoAliado = api.estado(id).version
		local fugaAliado, reciboAliado = api.solicitarFuga(b, pedido(id, versaoAliado, "fuga-b-apos-a"))
		t.eq(fugaAliado, true, "cooldown de A não bloqueia B após a tentativa aceita de A")
		t.eq(reciboAliado.result.natural, 20)
	end,
	["pedido de fuga sem Ações é recusado sem alterar a vez"] = function(t)
		local api, a, _, _, envios, _, _, criar = novoServico({ 1 })
		local id = criar(true)
		local versao = api.estado(id).version
		for indice = 1, 3 do
			local recibo = api.consumirAcaoInterno(id, "jogador-a", versao, "gastar-acao-" .. indice)
			t.ok(recibo ~= nil)
			versao = api.estado(id).version
		end
		local semAcao = api.solicitarFuga(a, pedido(id, versao, "fuga-sem-acao"))
		t.eq(semAcao, false)
		t.eq(api.estado(id).version, versao)
		t.eq(api.estado(id).currentActorId, "jogador-a")
		t.eq(envios[#envios].tipo, "recusado")
	end,
	["fuga bem-sucedida tira o ator da ordem, conserva PV e permite retorno durante a luta"] = function(t)
		local api, a, b, estranho, envios, _, avancar, criar = novoServico({ 20 })
		local id = criar(true, 17)
		local ok, recibo = api.solicitarFuga(a, pedido(id, 1, "fuga-sucesso"))
		t.eq(ok, true)
		t.eq(recibo.result.fugiu, true)
		t.eq(recibo.result.natural, 20)
		t.eq(recibo.result.total, 23)
		t.eq(recibo.result.cd, 10)
		local ator = api.atores(id)[1]
		t.eq(ator.fled, true)
		t.eq(ator.pv, 17)
		t.eq(ator.ficha.session.current.pv, 17)
		local snapshotFugitivo
		for _, envio in envios do
			if envio.tipo == "estado" and envio.player == a and envio.dados.phase == "fled" then
				snapshotFugitivo = envio.dados
			end
		end
		t.ok(snapshotFugitivo ~= nil, "o snapshot privado do fugitivo informa phase=fled")
		t.eq(api.estado(id).phase, "active", "o aliado mantém o combate")
		local ataqueAoFugitivo = api.solicitarAtaqueBasico(b, { encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "ataque-fugitivo", targetId = "jogador-a" })
		t.eq(ataqueAoFugitivo, false, "o fugitivo não está mais disponível como alvo")
		t.eq(api.atores(id)[1].pv, 17)
		avancar(0.3)
		t.eq(api.solicitarRetorno(estranho, { command = "return-autonomous", encounterId = id, requestId = "retorno-alheio" }), false)
		t.eq(api.solicitarRetorno(a, { command = "return-autonomous", encounterId = id, requestId = "retorno-fuga" }), true)
		t.eq(api.estado(id).phase, "active", "o retorno do fugitivo não encerra a luta do aliado")
		local versaoAliado = api.estado(id).version
		t.eq(api.solicitarDesistencia(b, { command = "abandon-encounter", encounterId = id,
			expectedVersion = versaoAliado, requestId = "aliado-derrotado" }), true)
		t.eq(api.estado(id).phase, "defeat", "derrota do participante restante encerra o encontro")
		ator = api.atores(id)[1]
		t.eq(ator.pv, 17, "derrota do grupo não aplica descanso RB-25 ao fugitivo")
		t.eq(ator.ficha.session.current.pv, 17)
	end,
	["ultimo jogador que foge deixa encontro fled e não recebe recuperação RB-25"] = function(t)
		local api, a, _, _, _, _, _, criar = novoServico({ 20 })
		local id = criar(false, 11)
		local ok = api.solicitarFuga(a, pedido(id, 1, "ultima-fuga"))
		t.eq(ok, true)
		t.eq(api.estado(id).phase, "fled")
		local ator = api.atores(id)[1]
		t.eq(ator.fled, true)
		t.eq(ator.pv, 11)
		t.eq(ator.ficha.session.current.pv, 11, "fuga não aplica restauração RB-25")
	end,
	["replay idempotente preserva recibo e requestId conflitante é recusado"] = function(t)
		local api, a, _, _, _, _, _, criar = novoServico({ 20 })
		local id = criar(true)
		local original = pedido(id, 1, "fuga-replay")
		local ok, recibo = api.solicitarFuga(a, original)
		t.eq(ok, true)
		local repetido, reciboRepetido = api.solicitarFuga(a, original)
		t.eq(repetido, true)
		t.eq(reciboRepetido.version, recibo.version)
		local conflito = table.clone(original)
		conflito.expectedVersion = 2
		t.eq(api.solicitarFuga(a, conflito), false, "requestId reutilizado com outra assinatura é recusado")
		t.eq(api.estado(id).version, recibo.version)
	end,
}
