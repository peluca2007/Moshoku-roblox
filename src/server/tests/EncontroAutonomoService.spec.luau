-- SOMENTE STUDIO: cobre a fronteira real do serviço servidor e seu RemoteEvent.
local Service = require(script.Parent.Parent.EncontroAutonomoService)
local Fogo = require(game:GetService("ReplicatedStorage").Shared.Regras.Fogo)
local Clarao = "ability/fogo/Principiante/clarao"
local ALVO_CLARAO = "clarao:11:10"

local function comLimpeza(instancia, corpo)
	local ok, erro = pcall(corpo)
	instancia:Destroy()
	if not ok then error(erro, 0) end
end

local function novoServico(combateLegadoAtivo, consumirItemPessoal, podeIniciarNaRegiao, avatares, remote, workspaceAtual, linhaDeVisao, miniaturas, prazos, rngOverride, recompensarEncontro)
	local a, b, estranho, c, d, e = { UserId = 101 }, { UserId = 202 }, { UserId = 303 }, { UserId = 304 }, { UserId = 305 }, { UserId = 306 }
	local jogadores = { [101] = a, [202] = b, [303] = estranho, [304] = c, [305] = d, [306] = e }
	local envios = {}
	local numero = 0
	local tempo = 0
	local remoteHandler
	local remoteAtual = remote or {}
	remoteAtual.OnServerEvent = { Connect = function(_, callback) remoteHandler = callback end }
	local dados = { 20, 1, 10, 10, 10, 10, 10, 10 }
	local rng = rngOverride or { NextInteger = function(_, minimo, maximo)
		local valor = table.remove(dados, 1) or minimo
		return math.clamp(valor, minimo, maximo)
	end }
	local api = Service.start({
		remote = remoteAtual,
		workspace = workspaceAtual,
		localizarJogador = function(userId) return jogadores[userId] end,
		emCombate = function() return combateLegadoAtivo == true end,
		consumirItemPessoal = consumirItemPessoal,
		podeIniciarNaRegiao = podeIniciarNaRegiao,
		linhaDeVisao = linhaDeVisao,
		avatares = avatares,
		miniaturas = miniaturas,
			conectado = function(player) return jogadores[player.UserId] == player end,
			corpoPessoal = function(player)
				return {

					name = "Ficha " .. player.UserId,
					calculated = { initiative = { bonus = 0, advantage = false }, movementMeters = 9 },
				}
			end,
		novoId = function() numero += 1; return "encounter-" .. numero end,
		agora = function() return tempo end,
		tempoServidor = function() return 1000 + tempo end,
		agendarPrazo = prazos and prazos.agendar or function() return nil end,
		cancelarPrazo = prazos and prazos.cancelar or function() end,
		rng = rng,
		recompensarEncontro = recompensarEncontro,
		emitir = function(player, tipo, dados)
			table.insert(envios, { player = player, tipo = tipo, dados = dados })
		end,
	})
	return api, a, b, estranho, envios, function(delta) tempo += delta end, c, d, e, jogadores,
		function(player, pedido) if remoteHandler then remoteHandler(player, pedido) end end
end

local function criarContexto(distancia, linhaDeVisao, requiresLineOfSight, usarWorkspaceReal, altura)
	local workspaceFixture = Instance.new(if usarWorkspaceReal then "WorldModel" else "Folder")
	local ok, resultado = pcall(function()
	local regiao = Instance.new("Folder")
	regiao.Name, regiao.Parent = "RegiaoInicial", workspaceFixture
	local marco = Instance.new("Part")
	marco.Name, marco.Anchored, marco.Position, marco.Parent = "Marco", true, Vector3.new(0, altura or 0, 0), regiao
	marco:SetAttribute("AreaRole", "encounter-trigger")
	marco:SetAttribute("EncounterId", "region/encounter/clearing")
	local prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = if requiresLineOfSight ~= nil then requiresLineOfSight else linhaDeVisao ~= nil
	prompt.Parent = marco
	local floresta = Instance.new("Folder")
	floresta.Name, floresta.Parent = "FlorestaSombria", workspaceFixture
	local marcoSombrio = Instance.new("Part")
	marcoSombrio.Name, marcoSombrio.Anchored, marcoSombrio.Position, marcoSombrio.Parent = "Marco Floresta Sombria", true, Vector3.new(0, altura or 0, 0), floresta
	marcoSombrio:SetAttribute("AreaRole", "encounter-trigger")
	marcoSombrio:SetAttribute("EncounterId", "region/encounter/dark-forest")
	local promptSombrio = Instance.new("ProximityPrompt")
	promptSombrio.MaxActivationDistance = 12
	promptSombrio.RequiresLineOfSight = if requiresLineOfSight ~= nil then requiresLineOfSight else linhaDeVisao ~= nil
	promptSombrio.Parent = marcoSombrio
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(distancia, altura or 0, 0), character
	character.Parent = workspaceFixture
	if usarWorkspaceReal then workspaceFixture.Parent = workspace end
	local api, player, _, _, _, avancarTempo = novoServico(nil, nil, nil, nil, nil,
		workspaceFixture, linhaDeVisao)
	player.Character = character
	return table.pack(api, player, workspaceFixture, avancarTempo)
	end)
	if not ok then workspaceFixture:Destroy(); error(resultado, 0) end
	return table.unpack(resultado, 1, resultado.n)
end


local function servicoComPrazo()
	local tempo, eventos = 0, {}
	local prazos = {
		agendar = function(segundos, callback)
			local evento = { at = tempo + segundos, callback = callback }
			table.insert(eventos, evento)
			return evento
		end,
		cancelar = function(evento) evento.cancelado = true end,
	}
	local api, a, b, _, envios, avancarTempo, _, _, _, jogadores = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, prazos)
	local function avancar(segundos)
		tempo += segundos
		avancarTempo(segundos)
		-- Dispara os vencidos como o scheduler, sem executar os recém-agendados cedo.
		for _, evento in ipairs(table.clone(eventos)) do
			if not evento.cancelado and not evento.executado and evento.at <= tempo then
				evento.executado = true
				evento.callback()
			end
		end
	end
	return api, a, b, envios, avancar, eventos, jogadores
end

local function encontroComCondicao(arvore, habilidadeId, alvoX, alvoZ, aliadoX, aliadoZ, rngOverride, deslocamentoMetros, respiracaoAlvo, pvMaxAlvo, habilidadeAdicional)
local api, a, b, _, envios, avancarTempo = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rngOverride)
	local ranks = { "rank/" .. arvore .. "/Principiante" }
	local compras = { habilidadeId }
	if habilidadeAdicional then
		table.insert(ranks, "rank/fogo/Principiante")
		table.insert(compras, habilidadeAdicional)
	end
	local id = api.criar({
		{ id = "jogador", userId = a.UserId, kind = "jogador", name = "Conjurador", x = 10, z = 10,
			ficha = { construction = { unlockedRankIds = ranks,
				purchasedIds = compras },
				calculated = { attributes = { intelecto = 4 }, maxima = { pv = 50, pm = 5 }, armorClass = 12 },
				session = { current = { pv = 50, pm = 5 } } } },
		{ id = "criatura", kind = "criatura", name = "Alvo", x = alvoX or 10, z = alvoZ or 15,
			respira = respiracaoAlvo ~= false,
			fichaCriatura = { pvMax = pvMaxAlvo or 1000, ca = 10, patamar = 1, respira = respiracaoAlvo ~= false,
				bonusAtaque = 0, danoPorTurno = 0, deslocamentoMetros = deslocamentoMetros or 0 } },
		{ id = "aliado", userId = b.UserId, kind = "jogador", name = "Aliado", x = aliadoX or 1, z = aliadoZ or 1,
			ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
				calculated = { attributes = { intelecto = 0 }, maxima = { pv = 50, pm = 0 }, armorClass = 12 },
				session = { current = { pv = 50, pm = 0 } } } },
	})
	if rngOverride and type(rngOverride.armar) == "function" then rngOverride:armar() end
	local contador = 0
	local function encerrarProximoTurno()
		local estado = api.estado(id)
		local player = if estado.currentActorId == "jogador" then a else b
		contador += 1
		avancarTempo(0.3)
		return api.solicitarFimTurno(player, {
			encounterId = id, expectedVersion = estado.version, requestId = "condicao-fim-" .. contador,
		})
	end
	return api, a, id, avancarTempo, encerrarProximoTurno, envios
end

local function encontroComLanca(terceiroX, terreno, pv, comAliado, recompensaCallback)
	local rng = { armado = false, chamadas = 0, NextNumber = function() return 0 end, NextInteger = function(self, minimo, maximo)
		if not self.armado then return minimo end
		self.chamadas += 1
		return minimo
	end }
	local api, a, b, _, envios, avancar = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng, recompensaCallback)
	local atores = { { id = "jogador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
		ficha = { construction = { unlockedRankIds = { "rank/terra/Principiante" }, purchasedIds = { "ability/terra/Principiante/lanca-de-pedra" } },
			calculated = { attributes = { intelecto = 4 }, maxima = { pv = 50, pm = 5 }, armorClass = 12 } } } }
	if comAliado then
		table.insert(atores, { id = "aliado", userId = b.UserId, kind = "jogador", x = 1, z = 1,
			ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
				calculated = { attributes = {}, maxima = { pv = 50, pm = 5 }, armorClass = 12 } } })
	end
	for indice = 1, 3 do
		table.insert(atores, { id = "c" .. indice, kind = "criatura", x = if indice == 3 then terceiroX or 12 else 10 + indice, z = if indice == 3 and terreno then 13 else 11,
			fichaCriatura = { pvMax = pv or 100, ca = 10, bonusAtaque = 0, danoPorTurno = 0, deslocamentoMetros = 0 }, recompensa = { patamar = 1, papel = "padrao", arquetipo = "bruto", subArquetipo = "humanoide" } })
	end
	local id = api.criar(atores, nil, if terreno then "region/encounter/forest" else nil)
	rng.armado = true
	return api, a, id, avancar, rng, envios
end

local function encontroComAtoleiro()
	local rng = { NextInteger = function(_, minimo) return minimo end }
	local api, a, b, _, envios, avancar = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng)
	local function ficha(purchasedIds)
		return { construction = { unlockedRankIds = { "rank/terra/Principiante" }, purchasedIds = purchasedIds or {} },
			calculated = { attributes = { intelecto = 4, agilidade = 0 }, maxima = { pv = 100, pm = 4 }, armorClass = 12 },
			session = { current = { pv = 100, pm = 4 } } }
	end
	local id = api.criar({
		{ id = "jogador", userId = a.UserId, kind = "jogador", name = "Terra", x = 10, z = 10, movementCasas = 1,
			ficha = ficha({ "ability/terra/Principiante/atoleiro" }) },
		{ id = "aliado", userId = b.UserId, kind = "jogador", name = "Aliado", x = 12, z = 10, movementCasas = 1, ficha = ficha() },
		{ id = "criatura", kind = "criatura", name = "Alvo", x = 14, z = 10, movementCasas = 0,
			fichaCriatura = { pvMax = 100, ca = 10, bonusAtaque = 0, danoPorTurno = 0, deslocamentoMetros = 0 } },
		{ id = "fora", kind = "criatura", name = "Fora", x = 15, z = 10, movementCasas = 0,
			fichaCriatura = { pvMax = 100, ca = 10, bonusAtaque = 0, danoPorTurno = 0, deslocamentoMetros = 0 } },
	})
	return api, a, b, id, avancar, envios
end

local function encontroComMao(condicoesAlvo, comFagulha, pvAlvo)
	local dado = 1
	local rng = { NextInteger = function(_, minimo, maximo) return math.clamp(dado, minimo, maximo) end }
	local api, a, b, _, envios, avancar = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng)
	local function ficha(compras, pv)
		local ranks = { "rank/terra/Principiante" }
		if comFagulha then table.insert(ranks, Fogo.RANK_PRINCIPIANTE) end
		return { construction = { unlockedRankIds = ranks, purchasedIds = compras or {} },
			calculated = { attributes = { forca = 0, agilidade = 0, vigor = 0 }, maxima = { pv = pv or 50, pm = 5 }, armorClass = 12 },
			session = { current = { pv = pv or 50, pm = 5 } } }
	end
	local id = api.criar({
		{ id = "jogador", userId = a.UserId, kind = "jogador", name = "Terra", x = 10, z = 10,
			ficha = ficha(if comFagulha then { "ability/terra/Principiante/mao-de-terra", "ability/fogo/Principiante/fagulha" }
				else { "ability/terra/Principiante/mao-de-terra" }) },
		{ id = "alvo", userId = b.UserId, kind = "jogador", name = "Alvo", x = 13, z = 10,
			condicoes = condicoesAlvo, ficha = ficha(if comFagulha then { "ability/fogo/Principiante/fagulha" } else nil, pvAlvo) },
	})
	local function usar(player, abilityId, actorId, requestId)
		local estado = api.estado(id)
		avancar(0.3)
		return api.solicitarHabilidade(player, { command = "use-ability", encounterId = id,
			expectedVersion = estado.version, requestId = requestId,
			abilityId = abilityId, targetId = actorId })
	end
	return api, a, b, id, envios, avancar, usar, function(valor) dado = valor end
end

return {
	["Sopro de Poeira resolve cone no servidor e expira condições após a vez de cada alvo"] = function(t)
		local habilidade = "ability/vento/Principiante/sopro-de-poeira"
		local rng = { NextInteger = function(_, minimo) return minimo end }
		local api, a, id, _, encerrar = encontroComCondicao("vento", habilidade, 10, 14, 1, 1, rng)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "sopro-integrado", abilityId = habilidade, targetId = "sopro-poeira:10:11" })
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.actionsCost, 1)
		t.eq(recibo.result.pmCost, 1)
		t.eq(#recibo.result.targets, 1)
		t.eq(recibo.result.targets[1].actorId, "criatura")
		t.eq(recibo.result.targets[1].resistance.passou, false)
		local criatura
		for _, ator in ipairs(api.atores(id)) do if ator.id == "criatura" then criatura = ator end end
		t.eq(criatura.condicoes.cego, true)
		t.eq(criatura.condicoes.desequilibrado, true)
		t.eq(criatura.pv, 1000, "cone não causa dano")
		t.eq(encerrar(), true)
		for _, ator in ipairs(api.atores(id)) do
			if ator.id == "criatura" then
				t.eq(ator.condicoes.cego, nil)
				t.eq(ator.condicoes.desequilibrado, nil)
			end
		end
	end,
	["Passo de Vento move a ficha no servidor e recusa destino ocupado sem cobrar"] = function(t)
		local habilidade = "ability/vento/Principiante/passo-de-vento"
		local api, a, id, avancarTempo = encontroComCondicao("vento", habilidade)
		local ocupado = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "passo-ocupado", abilityId = habilidade, targetId = "passo-vento:10:15" })
		t.eq(ocupado, false)
		t.eq(api.estado(id).actionsRemaining, 3)
		t.eq(api.atores(id)[1].pm, 5)
		avancarTempo(0.3)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "passo-valido", abilityId = habilidade, targetId = "passo-vento:12:10" })
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.from.x, 10)
		t.eq(recibo.result.from.z, 10)
		t.eq(recibo.result.to.x, 12)
		t.eq(recibo.result.to.z, 10)
		t.eq(api.estado(id).actionsRemaining, 1)
		local jogador
		for _, ator in ipairs(api.atores(id)) do if ator.id == "jogador" then jogador = ator end end
		t.eq(jogador.x, 12)
		t.eq(jogador.z, 10)
		t.eq(jogador.pm, 3)
	end,
	["Vácuo Localizado usa respiração/patamar canônicos, silencia e recusa não respirador"] = function(t)
		local habilidade = "ability/vento/Principiante/vacuo-localizado"
		local rng = { NextInteger = function(_, minimo) return minimo end }
		local api, a, id, avancarTempo, encerrar, envios = encontroComCondicao("vento", habilidade, 10, 12, 1, 1, rng)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "vacuo-cast", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.resistance, nil, "patamar igual não testa")
		t.eq(recibo.result.damageDealt, 1)
		local criatura
		for _, ator in ipairs(api.atores(id)) do if ator.id == "criatura" then criatura = ator end end
		t.eq(criatura.estadosDeCombate.silenciado.valor, true)
		local function passarAteRodada(rodada)
			local contador = 0
			while api.estado(id).turn < rodada do
				local estado = api.estado(id)
				local okTurno, reciboTurno = encerrar()
				t.eq(okTurno, true, tostring(reciboTurno))
				contador += 1
				t.ok(contador <= 4, "a rodada avança pelos turnos do grupo e da IA")
			end
		end
		passarAteRodada(2)
		local antesDoCooldown = api.estado(id)
		t.eq(antesDoCooldown.currentActorId, "jogador", "novo turno deve estar no conjurador")
		avancarTempo(0.3)
		local repeticaoConsecutiva, erroCooldown = api.solicitarHabilidade(a, { command = "use-ability",
			encounterId = id, expectedVersion = antesDoCooldown.version, requestId = "vacuo-consecutivo",
			abilityId = habilidade, targetId = "criatura" })
		t.eq(repeticaoConsecutiva, false)
		local recusaCooldown = envios[#envios]
		t.eq(recusaCooldown.tipo, "recusado")
		t.ok(string.find(recusaCooldown.dados.mensagem, "rodadas consecutivas") ~= nil,
			"bloqueia repetição consecutiva")
		t.eq(api.estado(id).actionsRemaining, 3, "recusa não consome Ações")
		passarAteRodada(3)
		local antesDoIntervalo = api.estado(id)
		avancarTempo(0.3)
		local aposIntervalo, reciboIntervalo = api.solicitarHabilidade(a, { command = "use-ability",
			encounterId = id, expectedVersion = antesDoIntervalo.version, requestId = "vacuo-apos-intervalo",
			abilityId = habilidade, targetId = "criatura" })
		t.eq(aposIntervalo, true, tostring(reciboIntervalo))
		t.eq(encerrar(), true)
		for _, ator in ipairs(api.atores(id)) do
			if ator.id == "criatura" then t.eq(ator.estadosDeCombate.silenciado, nil) end
		end
		local apiSemAr, b, idSemAr = encontroComCondicao("vento", habilidade, 10, 12, 1, 1, rng, nil, false)
		local semAr = apiSemAr.solicitarHabilidade(b, { command = "use-ability", encounterId = idSemAr,
			expectedVersion = 1, requestId = "vacuo-sem-ar", abilityId = habilidade, targetId = "criatura" })
		t.eq(semAr, false)
		t.eq(apiSemAr.estado(idSemAr).actionsRemaining, 3)
		t.eq(apiSemAr.atores(idSemAr)[1].pm, 5)
		local apiCaida, c, idCaida = encontroComCondicao("vento", habilidade, 10, 12, 1, 1, rng, nil, true, 0)
		local semVida = apiCaida.solicitarHabilidade(c, { command = "use-ability", encounterId = idCaida,
			expectedVersion = 1, requestId = "vacuo-sem-pv", abilityId = habilidade, targetId = "criatura" })
		t.eq(semVida, false, "criatura com 0 PV não é alvo válido")
		t.eq(apiCaida.estado(idCaida).actionsRemaining, 3)
		t.eq(apiCaida.atores(idCaida)[1].pm, 5)
	end,
	["Mão de Terra vincula alvo, cobrar ações uma vez e escapar repete a CD"] = function(t)
		local api, a, b, id, envios, avancar, usar, armarDado = encontroComMao()
		local ok, conjuracao = usar(a, "ability/terra/Principiante/mao-de-terra", "alvo", "mao-cast")
		t.eq(ok, true, tostring(conjuracao))
		t.eq(conjuracao.result.resistance.cd, conjuracao.result.bindingDc)
		t.eq(conjuracao.result.resistance.passou, false)
		t.eq(api.atores(id)[2].condicoes.agarrado, true)
		t.eq(api.atores(id)[2].condicoes.atolado, true)
		t.eq(api.estado(id).actionsRemaining, 1, "Mão de Terra usa 2 das 3 Ações")
		t.eq(api.atores(id)[1].pm, 3, "conjuração paga os 2 PM canônicos")
		local vinculo = envios[#envios].dados.bindings.alvo
		t.eq(vinculo.sourceId, "jogador")
		avancar(0.3)
		local turno = api.estado(id)
		t.eq(api.solicitarFimTurno(a, { encounterId = id, expectedVersion = turno.version, requestId = "mao-passa" }), true)
		armarDado(1)
		local falha, tentativa = usar(b, "mesa/mao-de-terra-escapar", "alvo", "mao-escape-falha")
		t.eq(falha, true, tostring(tentativa))
		t.eq(tentativa.result.escaped, false)
		t.eq(tentativa.result.resistance.cd, vinculo.cd)
		t.eq(api.estado(id).actionsRemaining, 2)
		armarDado(20)
		local sucesso, escape = usar(b, "mesa/mao-de-terra-escapar", "alvo", "mao-escape-sucesso")
		t.eq(sucesso, true, tostring(escape))
		t.eq(escape.result.escaped, true)
		t.eq(api.atores(id)[2].condicoes.agarrado, nil)
		t.eq(api.atores(id)[2].condicoes.atolado, nil)
		t.eq(envios[#envios].dados.bindings.alvo, nil)
	end,
	["Mão de Terra arrasta o alvo no servidor e Soltar continua grátis sem Ações"] = function(t)
		local api, a, _, id, envios, avancar, usar = encontroComMao()
		local ok, conjuracao = usar(a, "ability/terra/Principiante/mao-de-terra", "alvo", "mao-cast-arrasto")
		t.eq(ok, true, tostring(conjuracao))
		local xOrigem = api.atores(id)[1].x
		local okArrasto, arrasto = usar(a, "mesa/mao-de-terra-arrastar", "jogador", "mao-arrastar")
		t.eq(okArrasto, true, tostring(arrasto))
		t.eq(arrasto.result.houses, 2)
		t.eq(api.atores(id)[2].x, 11)
		t.eq(api.atores(id)[1].x, xOrigem, "só o alvo é movido")
		t.eq(api.estado(id).actionsRemaining, 0)
		local okSoltar, soltar = usar(a, "mesa/mao-de-terra-soltar", "jogador", "mao-soltar-livre")
		t.eq(okSoltar, true, tostring(soltar))
		t.eq(soltar.result.actionsCost, 0)
		t.eq(api.estado(id).actionsRemaining, 0)
		t.eq(api.atores(id)[2].condicoes.agarrado, nil)
		t.eq(api.atores(id)[2].condicoes.atolado, nil)
		t.eq(envios[#envios].dados.bindings.alvo, nil)
	end,
	["Mão de Terra arrasta pela Fagulha e interrompe quando o alvo cai"] = function(t)
		local fagulha = "ability/fogo/Principiante/fagulha"
		local mao = "ability/terra/Principiante/mao-de-terra"
		local function preparar(pvAlvo, prefixo)
			local api, a, b, id, envios, avancar, usar = encontroComMao(nil, true, pvAlvo)
			local okMao, reciboMao = usar(a, mao, "alvo", prefixo .. "-mao")
			t.eq(okMao, true, tostring(reciboMao))
			local function fim(player, suffix)
				local estado = api.estado(id)
				avancar(0.3)
				return api.solicitarFimTurno(player, { encounterId = id, expectedVersion = estado.version,
					requestId = prefixo .. "-fim-" .. suffix })
			end
			t.eq(fim(a, "a"), true)
			local okZona, reciboZona = usar(b, fagulha, "casa:12:9", prefixo .. "-fagulha")
			t.eq(okZona, true, tostring(reciboZona))
			t.eq(fim(b, "b"), true)
			t.eq(#envios[#envios].dados.dangers, 1, "a Fagulha precisa seguir ativa até o arrasto")
			return api, a, id, usar
		end
		local api, a, id, usar = preparar(10, "mao-fagulha")
		local ok, arrasto = usar(a, "mesa/mao-de-terra-arrastar", "jogador", "mao-arrasto-fagulha")
		t.eq(ok, true, tostring(arrasto))
		t.eq(arrasto.result.hazardsTriggered[1].abilityId, fagulha)
		t.eq(arrasto.result.houses, 2)
		t.eq(arrasto.result.to.x, 11)
		t.eq(arrasto.result.to.z, 9)
		t.eq(api.atores(id)[2].pv, 9)

		local apiCaida, aCaida, idCaida, usarCaida = preparar(1, "mao-fagulha-queda")
		local okQueda, queda = usarCaida(aCaida, "mesa/mao-de-terra-arrastar", "jogador", "mao-arrasto-queda")
		t.eq(okQueda, true, tostring(queda))
		t.eq(queda.result.houses, 1, "o caminho termina na casa da zona que derrubou o alvo")
		t.eq(queda.result.to.x, 12)
		t.eq(queda.result.to.z, 9)
		t.eq(queda.result.hazardsTriggered[1].damage.total, 1)
		t.eq(apiCaida.atores(idCaida)[2].pv, 0)
	end,
	["Mão de Terra solta o alvo quando a fonte cai"] = function(t)
		local api, a, _, id, envios, avancar, usar = encontroComMao()
		local ok, conjuracao = usar(a, "ability/terra/Principiante/mao-de-terra", "alvo", "mao-cast-fonte-cai")
		t.eq(ok, true, tostring(conjuracao))
		avancar(0.3)
		local estado = api.estado(id)
		local caiu, recibo = api.solicitarDesistencia(a, { command = "abandon-encounter", encounterId = id,
			expectedVersion = estado.version, requestId = "mao-fonte-cai" })
		t.eq(caiu, true, tostring(recibo))
		t.eq(api.atores(id)[2].condicoes.agarrado, nil)
		t.eq(api.atores(id)[2].condicoes.atolado, nil)
		t.eq(envios[#envios].dados.bindings.alvo, nil)
	end,
	["Mão de Terra não remove condição que já pertencia ao alvo"] = function(t)
		local api, a, _, id, _, _, usar = encontroComMao({ atolado = true })
		local ok, conjuracao = usar(a, "ability/terra/Principiante/mao-de-terra", "alvo", "mao-cast-condicao-antiga")
		t.eq(ok, true, tostring(conjuracao))
		local soltou = usar(a, "mesa/mao-de-terra-soltar", "jogador", "mao-soltar-condicao-antiga")
		t.eq(soltou, true)
		t.eq(api.atores(id)[2].condicoes.agarrado, nil)
		t.eq(api.atores(id)[2].condicoes.atolado, true, "a condição anterior continua ativa")
	end,
	["Muro de Terra instala quatro casas com 40 PV, bloqueia projétil e movimento"] = function(t)
		local api, a, b, _, envios, avancar = novoServico()
		local muro = "ability/terra/Principiante/muro-de-terra"
		local pedra = "ability/terra/Principiante/bala-de-pedra"
		local function ficha(compras)
			return { construction = { unlockedRankIds = { "rank/terra/Principiante" }, purchasedIds = compras },
				calculated = { attributes = { intelecto = 3 }, maxima = { pv = 50, pm = 3 }, armorClass = 12 },
				session = { current = { pv = 50, pm = 3 } } }
		end
		local id = api.criar({
			{ id = "conjurador", userId = a.UserId, kind = "jogador", x = 10, z = 10, movementCasas = 6,
				ficha = ficha({ muro }) },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 12, z = 10, movementCasas = 6,
				ficha = ficha({ pedra }) },
			{ id = "alvo", kind = "criatura", x = 16, z = 10, movementCasas = 0,
				fichaCriatura = { pvMax = 100, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local estado = api.estado(id)
		t.eq(estado.currentActorId, "conjurador")
		local snapshotConjurador
		for _, envio in ipairs(envios) do
			if envio.player == a and envio.tipo == "estado" then snapshotConjurador = envio.dados end
		end
		t.eq(table.find(snapshotConjurador.availableAbilities, muro) ~= nil, true)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = estado.version, requestId = "muro-terra-1", abilityId = muro, targetId = "muro-terra:14:10" })
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 3)
		t.eq(recibo.result.zone.pv, 40)
		t.eq(recibo.result.zone.expiresTurn, 101)
		t.eq(#recibo.result.zone.cells, 4)
		local bloqueadas = {}
		for _, celula in ipairs(envios[#envios].dados.blockedCells) do
			bloqueadas[tostring(celula.x) .. ":" .. tostring(celula.z)] = true
		end
		t.eq(bloqueadas["14:9"], true)
		t.eq(bloqueadas["14:10"], true)
		avancar(0.3)
		t.eq(api.solicitarFimTurno(a, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "muro-terra-fim" }), true)
		estado = api.estado(id)
		t.eq(estado.currentActorId, "aliado")
		avancar(0.3)
		local ataque, erro = api.solicitarHabilidade(b, { command = "use-ability", encounterId = id,
			expectedVersion = estado.version, requestId = "pedra-muro-bloqueia", abilityId = pedra, targetId = "alvo" })
		t.eq(ataque, false, "muro de terra corta linha de projétil no servidor")
		t.eq(api.estado(id).actionsRemaining, 3, tostring(erro))
		local moveu = api.solicitarMovimento(b, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "muro-terra-movimento-bloqueado", x = 15, z = 10 })
		t.eq(moveu, false, "rota com orçamento 6 não atravessa a parede nem contorna as pontas")
		t.eq(api.estado(id).actionsRemaining, 3)
		avancar(0.3)
		local pvCriatura = api.atores(id)[3].pv
		local tiro, reciboTiro = api.solicitarDisparo(b, { command = "ranged-attack", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "tiro-interceptado", targetId = "alvo" })
		t.eq(tiro, true, tostring(reciboTiro))
		t.eq(reciboTiro.result.targetId:sub(1, 7), "parede:")
		t.eq(reciboTiro.result.automatic, true)
		t.eq(reciboTiro.result.critical, false)
		t.eq(reciboTiro.result.barrierPv < 40, true)
		t.eq(api.atores(id)[3].pv, pvCriatura, "o dano não atravessa para a criatura")
		local replay, reciboReplay = api.solicitarDisparo(b, { command = "ranged-attack", encounterId = id,
			expectedVersion = reciboTiro.version - 1, requestId = "tiro-interceptado", targetId = "alvo" })
		t.eq(replay, true)
		t.eq(reciboReplay.version, reciboTiro.version)
		t.eq(api.atores(id)[3].pv, pvCriatura, "replay não reaplica dano na barreira")
		avancar(0.3)
		local wallId = string.match(reciboTiro.result.targetId, "^parede:(.+)$")
		local alvoDireto, reciboDireto = api.solicitarDisparo(b, { command = "ranged-attack", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "tiro-casa-muro", targetId = "parede:" .. wallId .. ":14:10" })
		t.eq(alvoDireto, true, tostring(reciboDireto))
		t.eq(reciboDireto.result.targetId, "parede:" .. wallId)
		local pvCompartilhado
		for _, perigo in ipairs(envios[#envios].dados.dangers) do
			if perigo.wallId == wallId then
				pvCompartilhado = pvCompartilhado or perigo.pv
				t.eq(perigo.pv, pvCompartilhado, "as quatro casas compartilham PV")
			end
		end
		t.eq(pvCompartilhado, reciboDireto.result.barrierPv)
	end,
	["Muro de Terra revalida rochas fixas antes de cobrar custo"] = function(t)
		local api, a = novoServico()
		local muro = "ability/terra/Principiante/muro-de-terra"
		local id = api.criar({
			{ id = "conjurador", userId = a.UserId, kind = "jogador", x = 5, z = 8,
				ficha = { construction = { unlockedRankIds = { "rank/terra/Principiante" }, purchasedIds = { muro } },
				calculated = { attributes = { intelecto = 3 }, maxima = { pv = 50, pm = 2 }, armorClass = 12 },
				session = { current = { pv = 50, pm = 2 } } } },
			{ id = "criatura", kind = "criatura", x = 10, z = 8, movementCasas = 0,
				fichaCriatura = { pvMax = 20, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		}, nil, "region/encounter/forest")
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "muro-terra-rocha", abilityId = muro, targetId = "muro-terra:8:8" })
		t.eq(ok, false, "rocha fixa entre fonte e centro impede a colocação")
		t.eq(api.estado(id).actionsRemaining, 3)
		t.eq(api.atores(id)[1].pm, 2)
	end,
	["Anteparo bloqueia movimento e ataque fisico, mas deixa magia atravessar"] = function(t)
		local api, a, b, _, envios, avancar = novoServico()
		local anteparo = "ability/teorica/Principiante/anteparo-teorico"
		local id = api.criar({
			{ id = "teorico", userId = a.UserId, kind = "jogador", x = 12, z = 10,
				ficha = { construction = { unlockedRankIds = { "rank/teorica/Principiante" }, purchasedIds = { anteparo } },
					calculated = { attributes = { intelecto = 2 }, maxima = { pv = 30, pm = 4 }, armorClass = 10 },
					session = { current = { pv = 30, pm = 4 } } } },
			{ id = "terra", userId = b.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = { "rank/terra/Principiante" }, purchasedIds = {} },
					calculated = { attributes = { intelecto = 2 }, maxima = { pv = 30, pm = 2 }, armorClass = 10 },
					session = { current = { pv = 30, pm = 2 } } } },
			{ id = "alvo", kind = "criatura", x = 16, z = 10, movementCasas = 0,
				fichaCriatura = { pvMax = 100, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		t.eq(api.estado(id).currentActorId, "teorico")
		local cast, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "anteparo-cast", abilityId = anteparo, targetId = "anteparo:13:10" })
		t.eq(cast, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 2)
		t.eq(recibo.result.zone.pv, 30)
		t.eq(#recibo.result.zone.cells, 2)
		local cells = {}
		for _, cell in ipairs(recibo.result.zone.cells) do cells[tostring(cell.x) .. ":" .. tostring(cell.z)] = true end
		t.eq(cells["13:10"], true)
		t.eq(cells["13:11"], true)
		local moveu = api.solicitarMovimento(a, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "anteparo-move", x = 13, z = 10 })
		t.eq(moveu, false, "barreira barra deslocamento")
		t.eq(api.estado(id).actionsRemaining, 1)
		avancar(0.3)
		t.eq(api.solicitarFimTurno(a, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "anteparo-fim" }), true)
		avancar(0.3)
		local tiro, reciboTiro = api.solicitarDisparo(b, { command = "ranged-attack", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "anteparo-intercepta", targetId = "alvo" })
		t.eq(tiro, true, tostring(reciboTiro))
		t.eq(reciboTiro.result.barrierAbility, anteparo)
		t.eq(reciboTiro.result.barrierPv < 30, true)
		avancar(0.3)
		local pvAntes = api.atores(id)[3].pv
		local magia, reciboMagia = api.solicitarHabilidade(b, { command = "use-ability", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "anteparo-magia", abilityId = "ability/terra/Principiante/pedrisco",
			targetId = "alvo" })
		t.eq(magia, true, tostring(reciboMagia))
		t.eq(reciboMagia.result.targetId, "alvo", "magia atravessa mesmo com dano físico")
		t.eq(api.atores(id)[3].pv <= pvAntes, true)
		local anteparoPv
		for indice = #envios, 1, -1 do
			local snapshot = envios[indice].dados
			if type(snapshot) == "table" and type(snapshot.dangers) == "table" then
				for _, perigo in ipairs(snapshot.dangers) do
					if perigo.abilityId == anteparo then anteparoPv = perigo.pv; break end
				end
				if anteparoPv then break end
			end
		end
		t.eq(anteparoPv, reciboTiro.result.barrierPv, "magia não consome PV do Anteparo")
	end,
	["Escudo de Água protege aliado contra ataque da criatura sem virar barreira"] = function(t)
		local rng = { NextInteger = function(_, minimo, maximo)
			return math.clamp(15, minimo, maximo)
		end }
		local api, a, b, _, envios, avancar = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng)
		local escudo = "ability/agua/Principiante/escudo-de-agua"
		local function ficha(user, compras)
			return { construction = { unlockedRankIds = { "rank/agua/Principiante" }, purchasedIds = compras },
				calculated = { attributes = { intelecto = 2 }, maxima = { pv = 30, pm = 4 }, armorClass = 12 },
				session = { current = { pv = 30, pm = 4 } } }
		end
		local id = api.criar({
			{ id = "conjurador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = ficha(a, { escudo }) },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 12, z = 10,
				ficha = ficha(b, {}) },
			{ id = "criatura", kind = "criatura", x = 13, z = 10,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 8, deslocamentoMetros = 0 } },
		})
		local cast, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "escudo-agua-cast",
			abilityId = escudo, targetId = "escudo-agua:12:10" })
		t.eq(cast, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 2)
		t.eq(api.atores(id)[1].pm, 2)
		t.eq(recibo.result.zone.expiresTurn, recibo.turn + 2)
		t.eq(#recibo.result.zone.cells, 2)
		local replay, reciboReplay = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = recibo.version - 1, requestId = "escudo-agua-cast",
			abilityId = escudo, targetId = "escudo-agua:12:10" })
		t.eq(replay, true, tostring(reciboReplay))
		t.eq(reciboReplay.version, recibo.version)
		t.eq(api.atores(id)[1].pm, 2, "replay não cobra PM novamente")
		local antes = api.atores(id)[2].pv
		avancar(0.3)
		local fimConjurador = api.solicitarFimTurno(a, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "escudo-agua-fim-conjurador" })
		t.eq(fimConjurador, true)
		avancar(0.3)
		local fimAliado = api.solicitarFimTurno(b, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "escudo-agua-fim-aliado" })
		t.eq(fimAliado, true)
		local reciboAtaque
		for indice = #envios, 1, -1 do
			if envios[indice].tipo == "recibo" and envios[indice].dados.result
				and envios[indice].dados.result.action == "creature-attack" then
				reciboAtaque = envios[indice].dados
				break
			end
		end
		t.eq(type(reciboAtaque), "table", "a IA atacou no próprio turno")
		t.eq(reciboAtaque.result.targetId, "aliado")
		t.eq(reciboAtaque.result.coverageBonus, 5)
		t.eq(reciboAtaque.result.attack.defesa, 17, "cobertura soma CA antes da rolagem")
		t.eq(reciboAtaque.result.attack.acertou, false)
		t.eq(api.atores(id)[2].pv, antes, "a falha não causa o dano fixo da criatura")
	end,
	["Escudo de Água reduz parcela ígnea de habilidade que cruza a linha"] = function(t)
		local rng = { NextInteger = function(_, _, maximo) return maximo end }
		local api, a, _, _, envios, avancar = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng)
		local escudo = "ability/agua/Principiante/escudo-de-agua"
		local brasa = "ability/fogo/Principiante/brasa"
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = { "rank/agua/Principiante", Fogo.RANK_PRINCIPIANTE },
					purchasedIds = { escudo } },
					calculated = { attributes = { intelecto = 4 }, maxima = { pv = 30, pm = 5 }, armorClass = 12 },
					session = { current = { pv = 30, pm = 5 } } } },
			{ id = "criatura", kind = "criatura", x = 15, z = 10,
				fichaCriatura = { pvMax = 100, ca = 1, resistencias = {}, imunidades = {}, bonusAtaque = 0,
					danoPorTurno = 0, deslocamentoMetros = 0 } },
		})
		local function usar(abilityId, targetId, requestId)
			local estado = api.estado(id)
			return api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
				expectedVersion = estado.version, requestId = requestId, abilityId = abilityId, targetId = targetId })
		end
		local okEscudo, reciboEscudo = usar(escudo, "escudo-agua:12:10", "escudo-fogo-conjurar")
		t.eq(okEscudo, true, tostring(reciboEscudo))
		avancar(0.3)
		local okBrasa, reciboBrasa = usar(brasa, "criatura", "escudo-fogo-brasa")
		t.eq(okBrasa, true, tostring(reciboBrasa))
		t.eq(reciboBrasa.result.damageDealt, reciboBrasa.result.damage.total)
		local reduziu = false
		for _, nota in ipairs(reciboBrasa.result.notes or {}) do
			if string.find(nota, "Escudo de Água: metade", 1, true) then reduziu = true end
		end
		t.eq(reduziu, true, "o resolvedor canônico recebeu a proteção da linha ativa")
		t.eq(api.atores(id)[2].pv, 100 - reciboBrasa.result.damage.total)
	end,
	["Névoa Densa controla visão e aplica cegueira transitória nas rolagens"] = function(t)
		local dados = { 18, 5 }
		local rng = { NextInteger = function(_, minimo, maximo)
			return math.clamp(table.remove(dados, 1) or minimo, minimo, maximo)
		end }
		local api, a, b, _, envios, avancar = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng)
		local nevoa = "ability/agua/Principiante/nevoa-densa"
		local function ficha(compras)
			return { construction = { unlockedRankIds = { "rank/agua/Principiante" }, purchasedIds = compras },
				calculated = { attributes = { intelecto = 2 }, maxima = { pv = 30, pm = 1 }, armorClass = 12 },
				session = { current = { pv = 30, pm = 1 } } }
		end
		local id = api.criar({
			{ id = "conjurador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = ficha({ nevoa }) },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 15, z = 10,
				ficha = ficha({}) },
			{ id = "criatura", kind = "criatura", x = 14, z = 10,
				fichaCriatura = { pvMax = 30, ca = 12, bonusAtaque = 0, danoPorTurno = 8, deslocamentoMetros = 0 } },
		})
		local cast, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "nevoa-cast",
			abilityId = nevoa, targetId = "conjurador" })
		t.eq(cast, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 2)
		t.eq(api.atores(id)[1].pm, 0)
		t.eq(recibo.result.zone.expiresTurn, recibo.turn + 50)
		t.eq(#recibo.result.zone.cells, 49)
		local chaves
		for _, envio in ipairs(envios) do
			if envio.player == a and envio.tipo == "estado" then chaves = envio.dados end
		end
		t.eq(table.find(chaves.availableAbilities, nevoa) ~= nil, true)
		local bloqueadas = {}
		for _, celula in ipairs(chaves.blockedCells) do bloqueadas[tostring(celula.x) .. ":" .. tostring(celula.z)] = true end
		t.eq(bloqueadas["12:10"], nil, "neblina não bloqueia movimento")
		avancar(0.3)
		t.eq(api.solicitarFimTurno(a, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "nevoa-fim-conjurador" }), true)
		avancar(0.3)
		t.eq(api.solicitarFimTurno(b, { encounterId = id, expectedVersion = api.estado(id).version,
			requestId = "nevoa-fim-aliado" }), true)
		local reciboAtaque
		for indice = #envios, 1, -1 do
			if envios[indice].tipo == "recibo" and envios[indice].dados.result
				and envios[indice].dados.result.action == "creature-attack" then
				reciboAtaque = envios[indice].dados
				break
			end
		end
		t.eq(type(reciboAtaque), "table", "IA ataca após os dois turnos de jogador")
		t.eq(reciboAtaque.result.attack.d20.natural, 5, "desvantagem escolhe o menor d20")
		t.eq(reciboAtaque.result.attack.acertou, false, "a Névoa aplica cegueira só durante a rolagem")
		t.eq(api.atores(id)[2].condicoes.cegos, nil, "não grava cegueira permanente no ator")
	end,
	["Atoleiro aplica Atolado e terreno difícil uma vez, e ambas as durações expiram"] = function(t)
		local api, a, b, id, avancar, envios = encontroComAtoleiro()
		local pedido = { command = "use-ability", encounterId = id, expectedVersion = 1, requestId = "atoleiro-1",
			abilityId = "ability/terra/Principiante/atoleiro", targetId = "area:atoleiro" }
		local ok, recibo = api.solicitarHabilidade(a, pedido)
		t.eq(ok, true)
		t.eq(api.estado(id).actionsRemaining, 1)
		t.eq(api.atores(id)[1].pm, 2)
		t.eq(#recibo.result.targets, 2, "inclui aliado e criatura dentro da esfera, não a fonte nem o alvo fora")
		t.eq(recibo.result.zone.expiresTurn, 101)
		t.eq(#envios[#envios].dados.difficultCells, 49)
		local criaturas = api.atores(id)
		t.eq(criaturas[2].condicoes.atolado, true)
		t.eq(criaturas[3].condicoes.atolado, true)
		t.eq(criaturas[4].condicoes.atolado, nil)
		local repetido, mesmo = api.solicitarHabilidade(a, pedido)
		t.eq(repetido, true)
		t.eq(mesmo.version, recibo.version)
		t.eq(#envios[#envios].dados.difficultCells, 49, "replay não cria uma segunda zona")

		local function passarTurno(player, nome)
			local estado = api.estado(id)
			avancar(0.3)
			return api.solicitarFimTurno(player, { encounterId = id, expectedVersion = estado.version,
				requestId = "atoleiro-fim-" .. nome .. "-" .. tostring(estado.version) })
		end
		t.eq(passarTurno(a, "jogador"), true)
		local estadoAliado = api.estado(id)
		t.eq(estadoAliado.currentActorId, "aliado")
		avancar(0.3)
		t.eq(api.solicitarMovimento(b, { encounterId = id, expectedVersion = estadoAliado.version,
			requestId = "move-ato-dificil", x = 12, z = 9 }), false, "1 casa de deslocamento não paga o custo 2")
		t.eq(api.estado(id).version, estadoAliado.version)
		t.eq(passarTurno(b, "aliado"), true)
		t.eq(api.atores(id)[2].condicoes.atolado, nil, "condição termina após a próxima vez do alvo")

		while api.estado(id).turn < 100 do
			local estado = api.estado(id)
			local player = if estado.currentActorId == "jogador" then a elseif estado.currentActorId == "aliado" then b else nil
			t.ok(player ~= nil, "a IA conclui sua vez antes de devolver o controle ao grupo")
			t.eq(passarTurno(player, estado.currentActorId), true)
		end
		t.eq(api.estado(id).turn, 100)
		t.eq(#envios[#envios].dados.difficultCells, 49, "100 rodadas completas ainda mantêm a área até a rodada seguinte")
		while api.estado(id).turn < 101 do
			local estado = api.estado(id)
			local player = if estado.currentActorId == "jogador" then a elseif estado.currentActorId == "aliado" then b else nil
			t.ok(player ~= nil)
			t.eq(passarTurno(player, estado.currentActorId), true)
		end
		t.eq(#envios[#envios].dados.difficultCells, 0, "terreno expira no início da rodada 101")
	end,
	["Lança de Pedra cobra conjunto uma vez, aplica Atolado e replay não duplica"] = function(t)
		local api, a, id, avancar, rng = encontroComLanca()
		local pedido = { command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "lanca", abilityId = "ability/terra/Principiante/lanca-de-pedra", targetId = "lista:c1,c2,c3" }
		local ok, recibo = api.solicitarHabilidade(a, pedido)
		t.eq(ok, true)
		t.eq(api.estado(id).actionsRemaining, 1)
		t.eq(api.atores(id)[1].pm, 3)
		t.eq(#recibo.result.targets, 3)
		for indice = 2, 4 do
			t.eq(api.atores(id)[indice].pv, 98)
			t.eq(api.atores(id)[indice].condicoes.atolado, true)
		end
		local chamadas = rng.chamadas
		t.eq(api.solicitarHabilidade(a, pedido), true)
		t.eq(rng.chamadas, chamadas)
		t.eq(api.atores(id)[1].pm, 3)
		t.eq(api.atores(id)[2].pv, 98)
		avancar(0.3) -- Fim de turno é outro comando e respeita o intervalo do remoto.
		t.eq(api.solicitarFimTurno(a, { encounterId = id, expectedVersion = api.estado(id).version, requestId = "fim-lanca" }), true)
		for indice = 2, 4 do t.eq(api.atores(id)[indice].condicoes.atolado, nil, "expira após a próxima vez da criatura") end
	end,
	["Lança de Pedra recusa qualquer alvo inválido sem custo, dado ou efeito parcial"] = function(t)
		for _, caso in ipairs({ { lista = "lista:c1,c1" }, { lista = "lista:c1,c2,c3,c4" },
			{ lista = "lista:c1,inexistente" }, { lista = "lista:c1,jogador" }, { lista = "lista:c1,c3", x = 17 },
			{ lista = "lista:c2,c1" }, { lista = "c1" }, { lista = "lista:c1,c3", x = 16, terreno = true } }) do
			local api, a, id, _, rng = encontroComLanca(caso.x, caso.terreno)
			t.eq(api.solicitarHabilidade(a, { command = "use-ability", encounterId = id, expectedVersion = 1,
				requestId = "lanca-invalida", abilityId = "ability/terra/Principiante/lanca-de-pedra", targetId = caso.lista }), false)
			t.eq(api.estado(id).version, 1)
			t.eq(api.estado(id).actionsRemaining, 3)
			t.eq(api.atores(id)[1].pm, 5)
			t.eq(api.atores(id)[2].pv, 100)
			t.eq(api.atores(id)[2].condicoes.atolado, nil)
			t.eq(rng.chamadas, 0)
		end
	end,
	["Lança de Pedra derrota todas as criaturas na mesma transição"] = function(t)
		local api, a, id = encontroComLanca(nil, nil, 2)
		t.eq(api.solicitarHabilidade(a, { command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "lanca-final", abilityId = "ability/terra/Principiante/lanca-de-pedra", targetId = "lista:c1,c2,c3" }), true)
		t.eq(api.estado(id).phase, "victory")
		t.eq(api.estado(id).currentActorId, "jogador")
		for indice = 2, 4 do
			t.eq(api.atores(id)[indice].pv, 0)
			t.eq(api.atores(id)[indice].defeated, true)
		end
		t.eq(api.estado(id).version, 2)
		t.eq(api.atores(id)[1].pm, 5, "vitoria restaura os recursos ao encerrar o encontro")
	end,
	["Ãšltima criatura derrotada encerra vitória com dois jogadores"] = function(t)
		local api, a, id = encontroComLanca(nil, nil, 2, true)
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "lanca-vitoria-em-grupo",
			abilityId = "ability/terra/Principiante/lanca-de-pedra", targetId = "lista:c1,c2,c3" })
		t.eq(ok, true)
		t.eq(api.estado(id).phase, "victory")
		t.eq(api.atores(id)[1].pm, 5)
		t.eq(api.atores(id)[2].pv, 50, "descanso terminal preserva todos os jogadores do grupo")
	end,
	["prazo de 60 segundos usa versao atual sem reiniciar apos acao"] = function(t)
		local api, a, b, envios, avancar, eventos = servicoComPrazo()
		local id = api.criar({ { id = "a", userId = a.UserId }, { id = "b", userId = b.UserId } })
		t.eq(#eventos, 1)
		t.eq(envios[1].dados.turnDeadline, 1060)
		avancar(30)
		t.ok(api.consumirAcaoInterno(id, "a", 1, "acao-no-prazo") ~= nil)
		t.eq(api.estado(id).version, 2)
		t.eq(#eventos, 1, "acao nao agenda outro prazo")
		t.eq(envios[#envios].dados.turnDeadline, 1060)
		avancar(29.99)
		t.eq(api.estado(id).currentActorId, "a")
		avancar(0.02)
		t.eq(api.estado(id).currentActorId, "b")
		t.eq(api.estado(id).version, 3)
		t.eq(envios[#envios].dados.turnDeadline, 1120.01)
		local avisosPrazo = {}
		for _, envio in envios do
			if envio.tipo == "recibo" and envio.dados.result and envio.dados.result.turnTimedOut == true then
				table.insert(avisosPrazo, envio)
			end
		end
		t.eq(#avisosPrazo, 2, "todos os jogadores conectados recebem o prazo esgotado")
		t.eq(avisosPrazo[1].dados.result.turnTimedOut, true)
		t.eq(avisosPrazo[2].dados.result.turnTimedOut, true)
	end,
	["desconexao nao suspende prazo nem duplica encerramento"] = function(t)
		local api, a, b, envios, avancar, eventos, jogadores = servicoComPrazo()
		local id = api.criar({
			{ id = "a", userId = a.UserId, name = "Jogadora desconectada" },
			{ id = "b", userId = b.UserId, name = "Aliado conectado" },
		})
		jogadores[a.UserId] = nil
		avancar(60)
		t.eq(api.estado(id).currentActorId, "b")
		t.eq(api.estado(id).version, 2)
		local avisosPrazo = {}
		for _, envio in envios do
			if envio.tipo == "recibo" and envio.dados.result and envio.dados.result.turnTimedOut == true then
				table.insert(avisosPrazo, envio)
			end
		end
		t.eq(#avisosPrazo, 1, "participante conectado recebe aviso mesmo com ator da vez desconectado")
		t.eq(avisosPrazo[1].player, b)
		t.eq(avisosPrazo[1].dados.result.turnTimedOut, true)
		t.eq(avisosPrazo[1].dados.result.turnTimedOutActorName, "Jogadora desconectada")
		eventos[1].callback()
		t.eq(api.estado(id).version, 2)
	end,
	["clique invalida callback antigo mesmo quando mesmo ator retorna em outra rodada"] = function(t)
		local api, a, b, _, avancar, eventos = servicoComPrazo()
		local id = api.criar({ { id = "a", userId = a.UserId }, { id = "b", userId = b.UserId } })
		local velho = eventos[1]
		avancar(59)
		t.eq(api.solicitarFimTurno(a, { encounterId = id, expectedVersion = 1, requestId = "clique" }), true)
		t.eq(velho.cancelado, true)
		velho.callback()
		t.eq(api.estado(id).version, 2)
		t.eq(api.solicitarFimTurno(b, { encounterId = id, expectedVersion = 2, requestId = "clique-b" }), true)
		t.eq(api.estado(id).currentActorId, "a")
		t.eq(api.estado(id).turn, 2)
		avancar(1)
		velho.callback()
		t.eq(api.estado(id).version, 3)
		t.eq(api.estado(id).currentActorId, "a")
	end,
	["apos expirar jogador IA executa e devolve vez com novo prazo"] = function(t)
		local api, a, _, envios, avancar, eventos = servicoComPrazo()
		local id = api.criar({
			{ id = "a", userId = a.UserId, kind = "jogador", pv = 100, pvMax = 100, ca = 20, x = 1, z = 1 },
			{ id = "lobo", kind = "criatura", x = 18, z = 18, fichaCriatura = { pvMax = 10, ca = 10, deslocamentoMetros = 9 } },
		})
		avancar(60)
		local estado = api.estado(id)
		t.eq(estado.currentActorId, "a")
		t.eq(estado.turn, 2)
		t.eq(estado.actionsRemaining, 3)
		t.ok(estado.version >= 3)
		t.eq(#eventos, 2, "criatura nao recebe temporizador de jogador")
		t.eq(envios[#envios].dados.turnDeadline, 1120)
		eventos[1].callback()
		t.eq(api.estado(id).version, estado.version)
	end,
	["inicio propaga area apenas aos adaptadores servidor e preserva a escolha em snapshots seguintes"] = function(t)
		for _, area in ipairs({ "region/encounter/clearing", "region/encounter/forest", "menu" }) do
			local syncs, renders = {}, {}
			local avatares = { sincronizar = function(_, _, _, areaId) table.insert(syncs, areaId) end }
			local miniaturas = { render = function(_, _, _, _, areaId) table.insert(renders, areaId) end }
			local api, a, _, _, envios = novoServico(nil, nil, function(_, id) return id == area end,
				avatares, nil, nil, nil, miniaturas)
			local pedido = { command = if area == "menu" then "start-autonomous" else "start-world-encounter",
				requestId = "inicio-area", areaId = if area == "menu" then nil else area }
			local ok, id = api.solicitarInicio(a, pedido)
			t.eq(ok, true)
			local esperado = if area == "menu" then "region/encounter/clearing" else area
			t.ok(#syncs > 0 and #renders > 0)
			for _, valor in ipairs(syncs) do t.eq(valor, esperado) end
			for _, valor in ipairs(renders) do t.eq(valor, esperado) end
			local estado = api.estado(id)
			t.eq(estado.areaId, nil, "area permanece interna ao servidor")
			t.eq(api.solicitarFimTurno(a, { encounterId = id, requestId = "fim-area", expectedVersion = estado.version }), true)
			t.ok(#syncs >= 2 and #renders >= 2)
			for _, valor in ipairs(syncs) do t.eq(valor, esperado) end
			for _, valor in ipairs(renders) do t.eq(valor, esperado) end
			for _, envio in ipairs(envios) do
				if envio.tipo == "estado" then t.eq(envio.dados.areaId, nil) end
			end
		end
	end,
	["servico sincroniza avatares a cada snapshot ativo com IDs e casas autoritativos"] = function(t)
		local sincronizacoes = {}
		local adaptador = {
			sincronizar = function(encounterId, atores, phase)
				table.insert(sincronizacoes, { encounterId = encounterId, atores = atores, phase = phase })
				return true
			end,
			limpar = function() return true end,
		}
		local api, a = novoServico(nil, nil, nil, adaptador)
		local id = api.criar({
			{ id = "jogador", kind = "jogador", userId = a.UserId, x = 9, z = 10 },
			{ id = "criatura", kind = "criatura", x = 10, z = 11 },
		})
		t.eq(#sincronizacoes, 1)
		t.eq(sincronizacoes[1].encounterId, id)
		t.eq(sincronizacoes[1].phase, "active")
		t.eq(#sincronizacoes[1].atores, 1)
		t.eq(sincronizacoes[1].atores[1].userId, a.UserId)
		t.eq(sincronizacoes[1].atores[1].x, 9)
		t.eq(sincronizacoes[1].atores[1].z, 10)
	end,
	["cria encontro no servidor e envia estado so aos jogadores participantes"] = function(t)
		local api, a, b, _, envios = novoServico()
		local id, inicial = api.criar({
			{ id = "jogador-a", userId = a.UserId },
			{ id = "jogador-b", userId = b.UserId },
		})
		t.eq(id, "encounter-1")
		t.eq(inicial.currentActorId, "jogador-a")
		t.eq(#envios, 2)
		local estadoA, estadoB
		for _, envio in envios do
			if envio.player == a then estadoA = envio.dados end
			if envio.player == b then estadoB = envio.dados end
			t.eq(envio.tipo, "estado")
		end
		t.eq(estadoA.isMyTurn, true)
		t.eq(estadoA.currentActorName, "Jogador")
		t.eq(estadoB.isMyTurn, false)
	end,
	["pedido deriva ator do jogador e repeticao nao avanca duas vezes"] = function(t)
		local api, a, b, _, envios = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId },
			{ id = "jogador-b", userId = b.UserId },
		})
		local pedido = { encounterId = id, expectedVersion = 1, requestId = "fim-1", actorId = "jogador-b" }
		local ok, recibo = api.solicitarFimTurno(a, pedido)
		t.eq(ok, true)
		t.eq(recibo.actorId, "jogador-a")
		t.eq(recibo.nextActorId, "jogador-b")
		local repetido, mesmoRecibo = api.solicitarFimTurno(a, pedido)
		t.eq(repetido, true)
		t.eq(mesmoRecibo.version, recibo.version)
		t.eq(api.estado(id).version, 2)
		local contagemRecibos = 0
		for _, envio in envios do
			if envio.tipo == "recibo" then contagemRecibos += 1 end
		end
		t.eq(contagemRecibos, 2, "a repetição não retransmite o recibo ao grupo")
	end,
	["recusa espectador payload malformado e ator na vez alheia"] = function(t)
		local api, a, b, espectador = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId },
			{ id = "jogador-b", userId = b.UserId },
		})
		local fora = api.solicitarFimTurno(espectador, {
			encounterId = id, expectedVersion = 1, requestId = "fora",
		})
		t.eq(fora, false)
		local invalido = api.solicitarFimTurno(a, "fim")
		t.eq(invalido, false)
		local atorFora = api.solicitarFimTurno(b, {
			encounterId = id, expectedVersion = 1, requestId = "cedo",
		})
		t.eq(atorFora, false)
		t.eq(api.estado(id).version, 1)
	end,
	["nao cria ordens repetidas jogador duplicado nem sem jogador vivo"] = function(t)
		local api, a, _, _, envios = novoServico()
		local id, erro = api.criar({ { id = "x", userId = a.UserId }, { id = "x" } })
		t.eq(id, nil)
		t.ok(type(erro) == "string")
		id = api.criar({ { id = "x", userId = a.UserId }, { id = "y", userId = a.UserId } })
		t.eq(id, nil)
		id = api.criar({ { id = "x" }, { id = "y" } })
		t.eq(id, nil)
		t.eq(#envios, 0)
	end,
	["ator controlado pelo servidor avanca pelo caminho interno"] = function(t)
		local api, a, b, _, _, avancarTempo = novoServico()
		local id = api.criar({
			{ id = "criatura" },
			{ id = "jogador", userId = a.UserId },
		})
		local recibo, erro = api.encerrarTurnoInterno(id, "criatura", 1, "ia-1")
		t.eq(erro, nil)
		t.eq(recibo.actorId, "criatura")
		t.eq(recibo.nextActorId, "jogador")
		local recusado = api.encerrarTurnoInterno(id, "jogador", 2, "ia-2")
		t.eq(recusado, nil)
	end,
	["resolvedor interno gasta uma acao e retransmissao nao gasta duas"] = function(t)
		local api, a, _, _, envios = novoServico()
		local id = api.criar({
			{ id = "jogador", userId = a.UserId },
			{ id = "criatura" },
		})
		local recibo = api.consumirAcaoInterno(id, "jogador", 1, "ataque-1")
		t.eq(recibo.actionsRemaining, 2)
		t.eq(api.estado(id).version, 2)
		local replay = api.consumirAcaoInterno(id, "jogador", 1, "ataque-1")
		t.eq(replay.version, recibo.version)
		t.eq(api.estado(id).actionsRemaining, 2)
		local outroAtor = api.consumirAcaoInterno(id, "criatura", 2, "ataque-inimigo")
		t.eq(outroAtor, nil)
		local recibos = 0
		for _, envio in envios do
			if envio.tipo == "recibo" then
				recibos += 1
				t.eq(envio.dados.version, recibo.version)
				t.eq(envio.dados.actorId, "jogador")
			end
		end
		t.eq(recibos, 1, "replay devolve recibo ao resolvedor sem retransmitir evento da mesma versão")
	end,
	["ataque remoto autentica ator resolve critico atualiza pv e replay nao rola de novo"] = function(t)
		local api, a, _, _, envios = novoServico()
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Aventureiro", kind = "jogador", x = 10, z = 10,
				ficha = {
					construction = { inventory = {}, unlockedRankIds = {} },
					calculated = { attributes = { forca = 2 }, maxima = { pv = 20, pm = 5, pt = 2, pp = 1 }, armorClass = 10 },
					session = { current = { pv = 12, pm = 1, pt = 0, pp = 0 }, conditions = { Fogo.EM_CHAMAS } },
				},
				condicoes = { [Fogo.EM_CHAMAS] = true },
				defenderReduction = 3,
			},
			{
				id = "criatura:1", name = "Goblin", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 4, ca = 10 },
			},
		})
		local pedido = {
			encounterId = id, expectedVersion = 1, requestId = "golpe-1", targetId = "criatura:1",
			command = "basic-attack", actorId = "criatura:1",
		}
		local ok, recibo = api.solicitarAtaqueBasico(a, pedido)
		t.eq(ok, true)
		t.eq(recibo.actorId, "jogador", "ator vem do UserId autenticado")
		t.eq(recibo.action, "basic-attack")
		t.eq(recibo.result.attack.critico, true)
		t.eq(recibo.result.targetPv, 0)
		t.eq(api.estado(id).phase, "victory")
		t.eq(envios[#envios].dados.descansoAutomatico, true)
		t.eq(envios[#envios].dados.actors[1].pt, 2)
		t.eq(envios[#envios].dados.actors[1].pp, 1)
		t.eq(api.estado(id).actionsRemaining, 2)
		t.eq(api.estado(id).currentActorId, "jogador", "criatura derrotada sai da fila ativa")
		local jogador = api.atores(id)[1]
		t.eq(jogador.pv, 20)
		t.eq(jogador.pm, 5)
		t.eq(jogador.pt, 2)
		t.eq(jogador.pp, 1)
		t.eq(jogador.condicoes[Fogo.EM_CHAMAS], nil)
		t.eq(jogador.defenderReduction, nil)
		t.eq(jogador.ficha.session.current.pv, 20)
		t.eq(jogador.ficha.session.current.pm, 5)
		t.eq(#jogador.ficha.session.conditions, 0)
		local pv = api.atores(id)[2].pv
		t.eq(pv, 0, "criatura derrotada não recebe descanso")
		t.eq(api.atores(id)[2].defeated, true)
		local repetido, mesmo = api.solicitarAtaqueBasico(a, pedido)
		t.eq(repetido, true)
		t.eq(mesmo.version, recibo.version)
		t.eq(api.atores(id)[2].pv, pv)
		t.eq(api.estado(id).version, 2)
	end,
	["recibo de ação do jogador vai ao grupo sem incluir terceiros"] = function(t)
		local api, a, b, estranho, envios = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, name = "Aventureiro", kind = "jogador", x = 10, z = 10,
				ficha = { construction = { inventory = {}, unlockedRankIds = {} },
					calculated = { attributes = { forca = 2 }, maxima = { pv = 20, pm = 0, pt = 0, pp = 0 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 0, pt = 0, pp = 0 }, conditions = {} } } },
			{ id = "jogador-b", userId = b.UserId, name = "Aliada", kind = "jogador", x = 1, z = 1,
				ficha = { construction = { inventory = {}, unlockedRankIds = {} },
					calculated = { attributes = { forca = 0 }, maxima = { pv = 20, pm = 0, pt = 0, pp = 0 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 0, pt = 0, pp = 0 }, conditions = {} } } },
			{ id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 40, ca = 10 } },
		})
		local ok, recibo = api.solicitarAtaqueBasico(a, {
			command = "basic-attack", encounterId = id, expectedVersion = 1,
			requestId = "ataque-grupo", targetId = "criatura",
		})
		t.eq(ok, true)
		local avisos = {}
		for _, envio in envios do
			if envio.tipo == "recibo" then table.insert(avisos, envio) end
		end
		t.eq(#avisos, 2)
		local recebeuA, recebeuB = false, false
		for _, envio in avisos do
			recebeuA = recebeuA or envio.player == a
			recebeuB = recebeuB or envio.player == b
			t.eq(envio.dados.version, recibo.version)
		end
		t.eq(recebeuA, true)
		t.eq(recebeuB, true)
		for _, envio in envios do
			t.eq(envio.player == estranho and envio.tipo == "recibo", false, "jogador fora do grupo não recebe combate")
		end
	end,
	["disparo remoto valida alcance consome uma acao e replay nao aplica dano duplicado"] = function(t)
		local api, a, b, _, _, avancarTempo = novoServico()
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Arqueira", kind = "jogador", x = 10, z = 10,
				ficha = {
					construction = { inventory = {}, unlockedRankIds = {} },
					calculated = { attributes = { forca = 2 }, maxima = { pv = 20, pm = 5, pt = 2, pp = 1 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 5, pt = 2, pp = 1 }, conditions = {} },
				},
			},
			{ id = "criatura:1", name = "Goblin", kind = "criatura", x = 10, z = 22, fichaCriatura = { pvMax = 30, ca = 10 } },
		})
		local pedido = { command = "ranged-attack", encounterId = id, expectedVersion = 1,
			requestId = "disparo-12", targetId = "criatura:1" }
		local ok, recibo = api.solicitarDisparo(a, pedido)
		t.eq(ok, true)
		t.eq(recibo.action, "ranged-attack")
		t.eq(recibo.result.distance, 12)
		t.eq(recibo.result.weapon, "Arma de referência (d6)")
		t.eq(api.estado(id).actionsRemaining, 2)
		local pv = api.atores(id)[2].pv
		avancarTempo(1)
		local repetido, mesmo = api.solicitarDisparo(a, pedido)
		t.eq(repetido, true)
		t.eq(mesmo.version, recibo.version)
		t.eq(api.atores(id)[2].pv, pv)
		avancarTempo(1)
		local idFora = api.criar({
			{ id = "jogador-fora", userId = b.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { inventory = {}, unlockedRankIds = {} },
					calculated = { attributes = { forca = 2 }, maxima = { pv = 20, pm = 5 }, armorClass = 10 } } },
			{ id = "criatura-fora", kind = "criatura", x = 10, z = 23, fichaCriatura = { pvMax = 30, ca = 10 } },
		})
		local recusado = api.solicitarDisparo(b, { command = "ranged-attack", encounterId = idFora,
			expectedVersion = 1, requestId = "disparo-13", targetId = "criatura-fora" })
		t.eq(recusado, false)
		t.eq(api.estado(idFora).actionsRemaining, 3, "alcance inválido não consome Ação")
	end,
	["Brasa só aparece para ficha de Fogo e uma vez por turno com replay idempotente"] = function(t)
		local api, a, b, _, envios, avancarTempo = novoServico()
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Fogo", kind = "jogador", x = 10, z = 10,
				ficha = {
					construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = {} },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20 }, armorClass = 10 },
				},
			},
			{
				id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 15,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 1 },
			},
		})
		t.eq(envios[1].dados.availableAbilities[1], "ability/fogo/Principiante/brasa")
		local pedido = {
			command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "brasa-1", abilityId = "ability/fogo/Principiante/brasa", targetId = "criatura",
		}
		local ok, recibo = api.solicitarHabilidade(a, pedido)
		t.eq(ok, true)
		t.eq(recibo.action, "ability:ability/fogo/Principiante/brasa")
		t.eq(api.estado(id).actionsRemaining, 2)
		local replay, mesmoRecibo = api.solicitarHabilidade(a, pedido)
		t.eq(replay, true)
		t.eq(mesmoRecibo.version, recibo.version)
		avancarTempo(0.3)
		local segundo = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 2,
			requestId = "brasa-2", abilityId = "ability/fogo/Principiante/brasa", targetId = "criatura",
		})
		t.eq(segundo, false, "a limitação uma vez por turno vem da mecânica")
		t.eq(api.estado(id).version, 2)
		t.eq(api.estado(id).actionsRemaining, 2)
	end,
	["Dardo Arcano usa rank/compra, alcance, dano arcano e replay do serviço"] = function(t)
		local rng = { NextInteger = function(_, _, maximo) return maximo end }
		local api, a, b, _, envios = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng)
		local dardo = "ability/teorica/Principiante/dardo-arcano"
		local function ficha(compras)
			return { construction = { unlockedRankIds = { "rank/teorica/Principiante" }, purchasedIds = compras },
				calculated = { attributes = { intelecto = 2 }, maxima = { pv = 30, pm = 3 }, armorClass = 12 },
				session = { current = { pv = 30, pm = 3 } } }
		end
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador", x = 10, z = 10, ficha = ficha({ dardo }) },
			{ id = "criatura", kind = "criatura", x = 10, z = 15,
				fichaCriatura = { pvMax = 100, ca = 1, bonusAtaque = 0, danoPorTurno = 0,
					resistencias = {}, imunidades = {}, deslocamentoMetros = 0 } },
		})
		local disponiveis = envios[1].dados.availableAbilities
		t.eq(table.find(disponiveis, dardo) ~= nil, true)
		local estado = api.estado(id)
		local pedido = { command = "use-ability", encounterId = id, expectedVersion = estado.version,
			requestId = "dardo-arcano-1", abilityId = dardo, targetId = "criatura" }
		local ok, recibo = api.solicitarHabilidade(a, pedido)
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 2)
		t.eq(api.atores(id)[1].pm, 2)
		t.eq(recibo.result.damage.tipo, "arcano")
		t.eq(recibo.result.damageDealt > 0, true)
		t.eq(api.atores(id)[2].pv, 100 - recibo.result.damage.total)
		local replay, mesmoRecibo = api.solicitarHabilidade(a, pedido)
		t.eq(replay, true)
		t.eq(mesmoRecibo.version, recibo.version)
		t.eq(api.atores(id)[1].pm, 2, "replay não cobra PM novamente")
		local idSemCompra = api.criar({
			{ id = "jogador-sem-compra", userId = b.UserId, kind = "jogador", x = 10, z = 10, ficha = ficha({}) },
			{ id = "alvo-sem-compra", kind = "criatura", x = 10, z = 15,
				fichaCriatura = { pvMax = 100, ca = 1, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local recusado = api.solicitarHabilidade(b, { command = "use-ability", encounterId = idSemCompra,
			expectedVersion = api.estado(idSemCompra).version, requestId = "dardo-sem-compra",
			abilityId = dardo, targetId = "alvo-sem-compra" })
		t.eq(recusado, false)
		t.eq(api.estado(idSemCompra).actionsRemaining, 3, "sem compra não consome Ações")
	end,
	["Lâmina de Vento expira Desequilibrado ao fim da próxima vez do alvo"] = function(t)
		local habilidade = "ability/vento/Principiante/lamina-de-vento"
		local api, a, id, _, encerrar = encontroComCondicao("vento", habilidade)
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "lamina-duracao", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true)
		t.eq(api.atores(id)[2].condicoes.desequilibrado, true)
		t.eq(encerrar(), true)
		t.eq(api.atores(id)[2].condicoes.desequilibrado, nil,
			"a criatura teve sua próxima vez encerrada pela IA")
	end,
	["Respingo mantém Molhado até o fim da próxima vez do conjurador"] = function(t)
		local habilidade = "ability/agua/Principiante/respingo"
		local api, a, id, _, encerrar = encontroComCondicao("agua", habilidade)
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "respingo-duracao", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true)
		t.eq(api.atores(id)[2].condicoes.molhado, true)
		t.eq(encerrar(), true)
		t.eq(encerrar(), true)
		t.eq(api.atores(id)[2].condicoes.molhado, true, "não expira antes da vez seguinte do conjurador")
		t.eq(encerrar(), true)
		t.eq(api.atores(id)[2].condicoes.molhado, nil)
	end,
	["Flecha dâ€™Água expira Molhado após dez rodadas completas"] = function(t)
		local habilidade = "ability/agua/Principiante/flecha-de-agua"
		local api, a, id, _, encerrar = encontroComCondicao("agua", habilidade)
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "flecha-duracao", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true)
		for rodada = 1, 9 do
			t.eq(encerrar(), true)
			t.eq(encerrar(), true)
			t.eq(api.atores(id)[2].condicoes.molhado, true)
		end
		t.eq(encerrar(), true)
		t.eq(api.atores(id)[2].condicoes.molhado, true, "a décima rodada ainda conta como duração")
		t.eq(encerrar(), true)
		t.eq(api.estado(id).turn, 11)
		t.eq(api.atores(id)[2].condicoes.molhado, nil)
	end,
	["Lâmina de Gelo só libera ataque após conjuração pessoal e cobra custos uma vez"] = function(t)
		local habilidade = "ability/agua/Principiante/lamina-de-gelo"
		local forca, intelecto = "mesa/lamina-de-gelo-forca", "mesa/lamina-de-gelo-intelecto"
		local rng = {
			armado = false,
			NextInteger = function(self, minimo, maximo)
				return if self.armado then (if maximo == 20 then 10 else maximo) else minimo
			end,
			armar = function(self) self.armado = true end,
		}
		local api, a, id, avancarTempo, _, envios = encontroComCondicao("agua", habilidade, 10, 11, 1, 1, rng)
		local function snapshotDoJogador()
			for indice = #envios, 1, -1 do
				local envio = envios[indice]
				if envio.player == a and envio.tipo == "estado" then return envio.dados end
			end
			return nil
		end
		local antes = snapshotDoJogador()
		t.eq(table.find(antes.availableAbilities, forca), nil)
		local ataqueForjado = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = antes.version, requestId = "lamina-forjada", abilityId = forca, targetId = "criatura" })
		t.eq(ataqueForjado, false)
		t.eq(api.estado(id).version, antes.version, "tentativa sem arma não gasta recurso")
		avancarTempo(0.3)
		local conjurada, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = antes.version, requestId = "lamina-conjurar", abilityId = habilidade, targetId = "jogador" })
		t.eq(conjurada, true)
		t.eq(recibo.result.pmCost, 2)
		t.eq(recibo.result.actionsCost, 2)
		t.eq(recibo.result.weaponExpiresTurn, 11)
		local estado = snapshotDoJogador()
		local atores = api.atores(id)
		t.eq(atores[1].pm, 3)
		t.eq(estado.actors[1].states.armaGelo.valor, true)
		t.eq(table.find(estado.availableAbilities, forca) ~= nil, true)
		t.eq(table.find(estado.availableAbilities, intelecto) ~= nil, true)
		local encontrouSnapshot = false
		for _, envio in ipairs(envios) do
			if envio.player == a and envio.tipo == "estado" and envio.dados.actors[1].states.armaGelo then
				encontrouSnapshot = true
			end
		end
		t.eq(encontrouSnapshot, true, "arma temporária é reconstruível pelo snapshot")
		avancarTempo(0.3)
		local atacou, ataque = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = estado.version, requestId = "lamina-ataque", abilityId = intelecto, targetId = "criatura" })
		t.eq(atacou, true)
		t.eq(ataque.result.actionsCost, 1)
		t.eq(ataque.result.pmCost, 0)
		t.eq(ataque.result.damage.partes[1].formula, "1d8")
		t.eq(ataque.result.damage.partes[2].formula, "1d4")
		t.eq(api.atores(id)[1].pm, 3, "ataque não cobra PM adicional")
	end,
	["Lâmina de Gelo expira após dez rodadas completas e o servidor recusa ID antigo"] = function(t)
		local habilidade = "ability/agua/Principiante/lamina-de-gelo"
		local intelecto = "mesa/lamina-de-gelo-intelecto"
		local api, a, id, _, encerrar, envios = encontroComCondicao("agua", habilidade, 10, 11, 1, 1)
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "lamina-duracao", abilityId = habilidade, targetId = "jogador" })
		t.eq(ok, true)
		for _ = 1, 10 do
			t.eq(encerrar(), true)
			t.eq(encerrar(), true)
		end
		t.eq(api.estado(id).turn, 11)
		t.eq(api.atores(id)[1].estadosDeCombate.armaGelo, nil)
		local snapshotExpirado
		for indice = #envios, 1, -1 do
			local envio = envios[indice]
			if envio.player == a and envio.tipo == "estado" then snapshotExpirado = envio.dados; break end
		end
		t.eq(table.find(snapshotExpirado.availableAbilities, intelecto), nil)
		local expirado = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "lamina-expirada", abilityId = intelecto, targetId = "criatura" })
		t.eq(expirado, false)
	end,
	["Bola dâ€™Água empurra uma casa, atualiza snapshot e inclui destino no recibo"] = function(t)
		local habilidade = "ability/agua/Principiante/bola-de-agua"
		local api, a, id = encontroComCondicao("agua", habilidade)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "bola-empurrao", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true)
		t.eq(recibo.result.push.from.z, 15)
		t.eq(recibo.result.push.to.z, 16)
		t.eq(recibo.result.push.houses, 1)
		t.eq(api.atores(id)[2].z, 16)
		t.eq(api.atores(id)[2].condicoes.molhado, true)
	end,
	["Bola dâ€™Água para diante de aliado e do limite da grade"] = function(t)
		local habilidade = "ability/agua/Principiante/bola-de-agua"
		local function usar(alvoX, alvoZ, aliadoX, aliadoZ, requestId)
			local api, a, id = encontroComCondicao("agua", habilidade, alvoX, alvoZ, aliadoX, aliadoZ)
			local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
				expectedVersion = 1, requestId = requestId, abilityId = habilidade, targetId = "criatura" })
			t.eq(ok, true)
			return api.atores(id)[2], recibo
		end
		local alvoOcupado, reciboOcupado = usar(10, 15, 10, 16, "bola-ocupado")
		t.eq(alvoOcupado.z, 15)
		t.eq(reciboOcupado.result.push.houses, 0)
		local alvoLimite, reciboLimite = usar(10, 20, 1, 1, "bola-limite")
		t.eq(alvoLimite.z, 20)
		t.eq(reciboLimite.result.push.houses, 0)
	end,
	["Impacto de Gelo aplica dano sempre e reduz movimento até o fim da vez do alvo"] = function(t)
		local habilidade = "ability/agua/Principiante/impacto-de-gelo"
		local rng = {
			armado = false,
			NextInteger = function(self, minimo, maximo) return if self.armado then minimo else maximo end,
			armar = function(self) self.armado = true end,
		}
		local api, a, id, _, encerrar, envios = encontroComCondicao("agua", habilidade,
			10, 20, 1, 1, rng, 9)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "impacto-gelo", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true)
		t.eq(recibo.result.resistance.passou, false)
		t.eq(recibo.result.damageDealt, 6, "dano 1d8 + BC mesmo quando o alvo recebe sucesso")
		t.eq(api.atores(id)[2].estadosDeCombate.reduzMovimento.valor, 2)
		local snapshot
		for _, envio in ipairs(envios) do
			if envio.player == a and envio.tipo == "estado" then snapshot = envio.dados end
		end
		local alvoSnapshot
		for _, ator in ipairs(snapshot and snapshot.actors or {}) do
			if ator.id == "criatura" then alvoSnapshot = ator end
		end
		t.eq(alvoSnapshot.states.reduzMovimento.valor, 2)
		t.eq(encerrar(), true)
		local casasNoTurnoDaCriatura
		for _, envio in ipairs(envios) do
			local resultado = envio.dados and envio.dados.result
			if envio.tipo == "recibo" and resultado and resultado.actorId == "criatura"
				and resultado.action == "creature-move"
			then casasNoTurnoDaCriatura = resultado.houses end
		end
		t.eq(casasNoTurnoDaCriatura, 4, "6 casas de movimento menos a redução de 2")
		t.eq(api.atores(id)[2].estadosDeCombate.reduzMovimento, nil,
			"o estado expira no fim da próxima vez do alvo")
	end,
	["Impacto de Gelo causa dano total também quando a resistência passa"] = function(t)
		local habilidade = "ability/agua/Principiante/impacto-de-gelo"
		local rng = { NextInteger = function(_, _, maximo) return maximo end }
		local api, a, id = encontroComCondicao("agua", habilidade, nil, nil, nil, nil, rng)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "impacto-gelo-resistido", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true)
		t.eq(recibo.result.resistance.passou, true)
		t.eq(recibo.result.damageDealt, 13, "dano sempre: 1d8 máximo + BC")
		t.eq(api.atores(id)[2].estadosDeCombate, nil, "redução só entra quando o alvo falha")
	end,
	["Empurrão falhado desloca quatro casas, aplica Desequilibrado e expira"] = function(t)
		local habilidade = "ability/vento/Principiante/empurrao"
		local rng = {
			armado = false,
			NextInteger = function(self, minimo, maximo) return if self.armado then minimo else maximo end,
			armar = function(self) self.armado = true end,
		}
		local api, a, id, _, encerrar = encontroComCondicao("vento", habilidade, 10, 15, 1, 1, rng)
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "empurrao-falha", abilityId = habilidade, targetId = "criatura" })
		t.eq(ok, true)
		t.eq(recibo.result.resistance.passou, false)
		t.eq(recibo.result.push.houses, 4)
		t.eq(recibo.result.push.to.z, 19)
		t.eq(api.atores(id)[2].condicoes.desequilibrado, true)
		t.eq(encerrar(), true)
		t.eq(api.atores(id)[2].condicoes.desequilibrado, nil)
	end,
	["Empurrão para em um aliado ou na borda e não desloca ao resistir"] = function(t)
		local habilidade = "ability/vento/Principiante/empurrao"
		local function usar(alvoX, alvoZ, aliadoX, aliadoZ, rng, requestId)
			local api, a, id = encontroComCondicao("vento", habilidade,
				alvoX, alvoZ, aliadoX, aliadoZ, rng)
			local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
				expectedVersion = 1, requestId = requestId, abilityId = habilidade, targetId = "criatura" })
			t.eq(ok, true)
			return api.atores(id)[2], recibo
		end
		local falha = { armado = false, NextInteger = function(self, minimo, maximo) return if self.armado then minimo else maximo end,
			armar = function(self) self.armado = true end }
		local bloqueado, reciboBloqueado = usar(10, 15, 10, 16, falha, "empurrao-ocupado")
		t.eq(bloqueado.z, 15)
		t.eq(reciboBloqueado.result.push.houses, 0)
		local naBorda, reciboBorda = usar(10, 19, 1, 1, falha, "empurrao-borda")
		t.eq(naBorda.z, 20)
		t.eq(reciboBorda.result.push.houses, 1)
		local passa = { NextInteger = function(_, _, maximo) return maximo end }
		local resistiu, reciboResistiu = usar(10, 15, 1, 1, passa, "empurrao-resistido")
		t.eq(reciboResistiu.result.resistance.passou, true)
		t.eq(reciboResistiu.result.push, nil)
		t.eq(resistiu.z, 15)
		t.eq(resistiu.condicoes.desequilibrado, nil)
	end,
	["Empurrão atravessa Fagulha e termina o percurso quando a criatura cai"] = function(t)
		local habilidade = "ability/vento/Principiante/empurrao"
		local fagulha = "ability/fogo/Principiante/fagulha"
		local rng = { armado = false, NextInteger = function(self, minimo, maximo)
			return if self.armado then minimo else maximo
		end, armar = function(self) self.armado = true end }
		local function resolver(pv, sufixo)
		local api, a, id, avanca = encontroComCondicao("vento", habilidade, 10, 13, 1, 1, rng,
				nil, true, pv, fagulha)
			local okZona, zona = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
				expectedVersion = 1, requestId = sufixo .. "-fagulha", abilityId = fagulha, targetId = "casa:10:14" })
			t.eq(okZona, true, tostring(zona))
			avanca(0.3)
			local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
				expectedVersion = api.estado(id).version, requestId = sufixo .. "-empurrao",
				abilityId = habilidade, targetId = "criatura" })
			t.eq(ok, true, tostring(recibo))
			return api, id, recibo
		end
		local api, id, recibo = resolver(10, "empurrao-fagulha")
		t.eq(recibo.result.push.houses, 4)
		t.eq(recibo.result.push.to.z, 17)
		t.eq(#recibo.result.hazardsTriggered, 1)
		t.eq(recibo.result.hazardsTriggered[1].damage.total, 1)
		t.eq(recibo.result.targetPv, 9)
		t.eq(api.atores(id)[2].z, 17)

		local apiCaida, idCaida, reciboCaida = resolver(1, "empurrao-fagulha-queda")
		t.eq(reciboCaida.result.push.houses, 1)
		t.eq(reciboCaida.result.push.to.z, 14)
		t.eq(reciboCaida.result.targetPv, 0)
		t.eq(reciboCaida.result.targetDefeated, true)
		t.eq(apiCaida.atores(idCaida)[2].defeated, true)
		t.eq(apiCaida.estado(idCaida).phase, "victory", "a última criatura derrotada encerra a luta do grupo")
	end,
	["Clarão resolve a área no servidor, preserva PM e encerra Cego no próximo turno do alvo"] = function(t)
		local api, a, b, _, envios, avancarTempo = novoServico()
		local id = api.criar({
			{ id = "conjurador", userId = a.UserId, kind = "jogador", name = "Conjurador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = { Clarao } },
					calculated = { attributes = { inteligencia = 3, vigor = 0 }, maxima = { pv = 20, pm = 1 }, armorClass = 10 },
					session = { current = { pm = 1 } } } },
			{ id = "aliado", userId = b.UserId, kind = "jogador", name = "Aliado", x = 12, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = { vigor = 0 }, maxima = { pv = 15, pm = 0 }, armorClass = 10 } } },
			{ id = "criatura-perto", kind = "criatura", name = "Goblin", x = 13, z = 10,
				fichaCriatura = { pvMax = 10, ca = 10, bonusAtaque = 0, danoPorTurno = 1 } },
			{ id = "criatura-longe", kind = "criatura", name = "Lobo", x = 15, z = 10,
				fichaCriatura = { pvMax = 10, ca = 10, bonusAtaque = 0, danoPorTurno = 1 } },
			{ id = "criatura-fora", kind = "criatura", name = "Esqueleto", x = 16, z = 10,
				fichaCriatura = { pvMax = 10, ca = 10, bonusAtaque = 0, danoPorTurno = 1 } },
		})
		local estadoConjurador
		for _, envio in ipairs(envios) do
			if envio.player == a and envio.tipo == "estado" then estadoConjurador = envio.dados end
		end
		t.eq(table.find(estadoConjurador and estadoConjurador.availableAbilities or {}, Clarao) ~= nil, true)
		local pedido = { command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "clarao-1", abilityId = Clarao, targetId = ALVO_CLARAO }
		local ok, recibo = api.solicitarHabilidade(a, pedido)
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.pmCost, 1)
		t.eq(#recibo.result.targets, 3, "o centro escolhido desloca a esfera para fora do conjurador")
		t.eq(recibo.result.center.x, 11)
		t.eq(recibo.result.center.z, 10)
		t.eq(recibo.result.targets[1].actorId, "aliado")
		t.eq(recibo.result.targets[2].actorId, "criatura-perto")
		t.eq(recibo.result.targets[3].actorId, "criatura-longe", "alvo na borda do centro escolhido é afetado")
		t.eq(table.find(recibo.result.targets[1].applies, "cego"), nil, "o aliado passou na resistência")
		t.eq(table.find(recibo.result.targets[2].applies, "cego") ~= nil, true)
		local atores = api.atores(id)
		t.eq(atores[1].pm, 0)
		t.eq(atores[2].pv, 15)
		t.eq(atores[3].pv, 10, "Clarão não causa dano")
		t.eq(atores[4].id, "criatura-longe", "alvo na borda deslocada entra na resolução")
		t.eq(#recibo.result.targets, 3, "o ator além do raio não entra na lista de resistência")
		local replay, mesmo = api.solicitarHabilidade(a, pedido)
		t.eq(replay, true)
		t.eq(mesmo.version, recibo.version)
		t.eq(api.estado(id).actionsRemaining, 2)
		avancarTempo(0.3)
		local fimConjurador = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = 2, requestId = "clarao-fim-caster",
		})
		t.eq(fimConjurador, true)
		local fimAliado = api.solicitarFimTurno(b, {
			encounterId = id, expectedVersion = 3, requestId = "clarao-fim-aliado",
		})
		t.eq(fimAliado, true)
		t.eq(api.atores(id)[3].condicoes.cego, nil,
			"a IA encerra a próxima vez da criatura e o serviço expira Cego nessa transição")
	end,
	["Clarão rejeita centro oculto antes de consumir ações ou PM"] = function(t)
		local pagamentos = 0
		local api, a = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, function() pagamentos += 1; return true, 0 end)
		local id = api.criar({
			{ id = "conjurador", userId = a.UserId, kind = "jogador", x = 4, z = 8,
				ficha = { construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = { Clarao } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 1 }, armorClass = 10 },
					session = { current = { pm = 1 } } } },
			{ id = "criatura", kind = "criatura", x = 8, z = 8,
				fichaCriatura = { pvMax = 10, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		}, nil, "region/encounter/forest")
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "clarao-centro-oculto", abilityId = Clarao, targetId = "clarao:7:8" })
		t.eq(ok, false)
		t.eq(api.atores(id)[1].pm, 1)
		t.eq(api.estado(id).actionsRemaining, 3)
	end,
	["Muro de Chamas cobra ao atravessar, uma vez por movimento, e expira em dez rodadas"] = function(t)
		local api, a, b, _, envios, avancarTempo = novoServico()
		local muro = "ability/fogo/Principiante/muro-de-chamas"
		local id = api.criar({
			{ id = "conjurador", userId = a.UserId, kind = "jogador", x = 10, z = 10, movementCasas = 6,
				ficha = { construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = { muro } },
				calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 100, pm = 3 }, armorClass = 10 },
				session = { current = { pv = 100, pm = 3 } } } },
			{ id = "sobre-a-linha", userId = b.UserId, kind = "jogador", x = 11, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = { vigor = 0 }, maxima = { pv = 15, pm = 0 }, armorClass = 10 } } },
			{ id = "do-outro-lado", kind = "criatura", x = 14, z = 10,
				fichaCriatura = { pvMax = 10, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local estadoConjurador
		for _, envio in ipairs(envios) do
			if envio.player == a and envio.tipo == "estado" then estadoConjurador = envio.dados end
		end
		t.eq(table.find(estadoConjurador.availableAbilities, muro) ~= nil, true)
		local pedido = { command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "muro-1", abilityId = muro, targetId = "muro:11:10:1:0:3" }
		local ok, recibo = api.solicitarHabilidade(a, pedido)
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 2)
		t.eq(recibo.result.zone.expiresTurn, 11)
		t.eq(#recibo.result.zone.cells, 3)
		t.eq(api.atores(id)[1].pm, 0)
		t.eq(api.atores(id)[2].pv, 15, "erguer não acerta quem já estava na linha")
		local bloqueado = api.solicitarAtaqueBasico(a, {
			encounterId = id, expectedVersion = 2, requestId = "muro-bloqueia-visao", targetId = "do-outro-lado",
		})
		t.eq(bloqueado, false, "o muro bloqueia a linha de visão antes de consumir Ação")
		t.eq(api.estado(id).actionsRemaining, 1)
		local repetido, mesmo = api.solicitarHabilidade(a, pedido)
		t.eq(repetido, true)
		t.eq(mesmo.version, recibo.version)
		avancarTempo(0.3)
		local moveu, movimento = api.solicitarMovimento(a, {
			encounterId = id, expectedVersion = 2, requestId = "muro-atravessa", x = 13, z = 10,
		})
		t.eq(moveu, true, tostring(movimento))
		t.eq(#movimento.result.hazardsTriggered, 1, "duas casas contíguas do mesmo muro cobram uma vez")
		t.eq(movimento.result.hazardsTriggered[1].damage.total, 13)
		t.eq(api.atores(id)[1].condicoes[Fogo.EM_CHAMAS], true)
		for rodada = 1, 10 do
			avancarTempo(0.3)
			local fimA = api.solicitarFimTurno(a, {
				encounterId = id, expectedVersion = api.estado(id).version, requestId = "muro-fim-" .. rodada,
			})
			t.eq(fimA, true)
			local fimB = api.solicitarFimTurno(b, {
				encounterId = id, expectedVersion = api.estado(id).version, requestId = "muro-fim-aliado-" .. rodada,
			})
			t.eq(fimB, true)
		end
		local perigosAtivos = envios[#envios].dados.dangers
		local muroAtivo = false
		for _, perigo in ipairs(perigosAtivos) do if perigo.wallId == "muro-1" then muroAtivo = true end end
		t.eq(muroAtivo, false, "o muro desaparece ao iniciar a 11Âª rodada")
	end,
	["Fagulha cria zona com custo e movimento ativo aciona dano uma vez"] = function(t)
		local api, a, _, _, envios, avancarTempo = novoServico()
		local fagulha = "ability/fogo/Principiante/fagulha"
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador", x = 10, z = 10, movementCasas = 6,
				ficha = { construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = { fagulha } },
					calculated = { attributes = {}, maxima = { pv = 20, pm = 1 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 1 } } } },
			{ id = "criatura", kind = "criatura", x = 15, z = 15, movementCasas = 0,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		t.eq(table.find(envios[1].dados.availableAbilities, fagulha) ~= nil, true)
		local invalido = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "fagulha-fora-grade", abilityId = fagulha, targetId = "casa:21:10",
		})
		t.eq(invalido, false)
		t.eq(api.estado(id).version, 1)
		t.eq(api.atores(id)[1].pm, 1, "casa inválida não cobra recursos")
		avancarTempo(0.3)
		local ok, criado = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "fagulha-cria", abilityId = fagulha, targetId = "casa:11:11",
		})
		t.eq(ok, true, tostring(criado))
		t.eq(criado.actionsRemaining, 2, "Fagulha gasta uma Ação e deixa duas")
		t.eq(criado.result.zone.x, 11)
		t.eq(api.atores(id)[1].pm, 0)
		avancarTempo(0.3)
		local movido, reciboMovimento = api.solicitarMovimento(a, {
			encounterId = id, expectedVersion = 2, requestId = "passa-fagulha", x = 12, z = 12,
		})
		t.eq(movido, true, tostring(reciboMovimento))
		t.eq(#reciboMovimento.result.hazardsTriggered, 1)
		t.ok(reciboMovimento.result.hazardsTriggered[1].damage.total > 0)
		t.eq(api.atores(id)[1].pv < 20, true)
		t.eq(api.atores(id)[1].x, 12)
		avancarTempo(0.3)
		local rodada2 = api.solicitarFimTurno(a, { encounterId = id, expectedVersion = 3, requestId = "fagulha-r1" })
		t.eq(rodada2, true)
		t.eq(api.estado(id).turn, 2)
		t.eq(#envios[#envios].dados.dangers, 1)
		avancarTempo(0.3)
		local rodada3 = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = api.estado(id).version, requestId = "fagulha-r2",
		})
		t.eq(rodada3, true)
		t.eq(api.estado(id).turn, 3)
		t.eq(#envios[#envios].dados.dangers, 0)
	end,
	["Bola exige posse, gasta 2 Ações e 1 PM e aplica Em Chamas no acerto"] = function(t)
		local api, a = novoServico()
		local bola = "ability/fogo/Principiante/bola-de-fogo"
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Fogo", kind = "jogador", x = 10, z = 10,
				ficha = {
					construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = { bola } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 2 }, armorClass = 10 },
					session = { current = { pm = 2 } },
				},
			},
			{ id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 15,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 1 } },
		})
		local inicial = api.atores(id)[1]
		t.eq(inicial.pm, 2)
		local ok, recibo = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "bola-1", abilityId = bola, targetId = "criatura",
		})
		t.eq(ok, true)
		t.eq(recibo.actionsSpent, 2)
		t.eq(api.estado(id).actionsRemaining, 1)
		t.eq(api.atores(id)[1].pm, 1)
		t.eq(api.atores(id)[2].condicoes[Fogo.EM_CHAMAS], true)
	end,
	["Em Chamas causa dano no início da vez do alvo"] = function(t)
		local api, a, _, _, _, avancarTempo = novoServico()
		local bola = "ability/fogo/Principiante/bola-de-fogo"
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = { bola } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 2 }, armorClass = 10 },
					session = { current = { pm = 2 } } } },
			{ id = "criatura", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local ataque = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "bola-tick", abilityId = bola, targetId = "criatura",
		})
		t.eq(ataque, true)
		local pvAntes = api.atores(id)[2].pv
		avancarTempo(0.3)
		local passou = api.solicitarFimTurno(a, { encounterId = id, expectedVersion = 2, requestId = "passar-tick" })
		t.eq(passou, true)
		t.ok(api.atores(id)[2].pv < pvAntes, "a condição deve causar dano ao iniciar a vez da criatura")
		t.eq(api.atores(id)[2].condicoes[Fogo.EM_CHAMAS], true)
	end,
	["Toque Escaldante usa PV atual, bônus de metade e custo da ficha"] = function(t)
		local api, a, _, _, envios = novoServico()
		local toque = "ability/fogo/Principiante/toque-escaldante"
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = { Fogo.RANK_PRINCIPIANTE }, purchasedIds = { toque } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 2 }, armorClass = 10 },
					session = { current = { pv = 10, pm = 2 } } } },
			{ id = "criatura", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 300, ca = 1, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		t.eq(api.atores(id)[1].pv, 10)
		local ok, recibo = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
				requestId = "toque-1", abilityId = toque, targetId = "criatura",
		})
		t.eq(ok, true, tostring(recibo or (envios[#envios] and envios[#envios].dados.mensagem)))
		t.eq(recibo.actionsSpent, 2)
		t.eq(api.estado(id).actionsRemaining, 1)
		t.eq(api.atores(id)[1].pm, 0)
		t.eq(recibo.result.attack.acertou, true)
		t.eq(api.atores(id)[2].condicoes[Fogo.EM_CHAMAS], true)
		local bonusDePV = false
		for _, nota in ipairs(recibo.result.notes) do
			if string.find(nota, "Com metade dos PV ou menos", 1, true) then bonusDePV = true end
		end
		t.eq(bonusDePV, true)
	end,
	["Defender reduz o próximo golpe e termina no início da própria vez"] = function(t)
		local api, a, _, _, _, avancarTempo = novoServico()
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = { vigor = 2 }, maxima = { pv = 20, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 0 } } } },
			{ id = "criatura", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 4, danoPorTurno = 5 } },
		})
		local ok, recibo = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
				requestId = "defender-1", abilityId = "mesa/defender", targetId = "jogador",
		})
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.defenderReduction, 2)
		t.eq(api.estado(id).actionsRemaining, 2)
		avancarTempo(0.3)
		local passou = api.solicitarFimTurno(a, { encounterId = id, expectedVersion = 2, requestId = "defender-fim" })
		t.eq(passou, true)
		t.eq(api.atores(id)[1].pv, 17)
		t.eq(api.atores(id)[1].defenderReduction, nil)
	end,
	["Cura exige compra, custa 2 Ações e PM e recupera aliado adjacente caído"] = function(t)
		local api, a, b = novoServico()
		local cura = "ability/cura/Principiante/cura"
		local id = api.criar({
			{ id = "curandeiro", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = { cura } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 2 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 2 } } } },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 10, z = 11,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = { vigor = 2 }, maxima = { pv = 20, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 0, pm = 0 } } } },
			{ id = "criatura", kind = "criatura", x = 12, z = 12,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local ok, recibo = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "cura-aliado", abilityId = cura, targetId = "aliado",
		})
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 2)
		t.eq(recibo.result.healing, 8, "rolagem fixa do spec: 1d8")
		t.eq(api.estado(id).actionsRemaining, 1)
		t.eq(api.atores(id)[1].pm, 0)
		t.eq(api.atores(id)[2].pv, 8)
		t.eq(api.atores(id)[2].downed, false)
	end,
	["Cura permite o próprio conjurador como alvo, conforme a validação compartilhada"] = function(t)
		local api, a = novoServico()
		local cura = "ability/cura/Principiante/cura"
		local id = api.criar({
			{ id = "curandeiro", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = { cura } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 2 }, armorClass = 10 },
					session = { current = { pv = 10, pm = 2 } } } },
			{ id = "criatura", kind = "criatura", x = 12, z = 12,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local ok, recibo = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = 1,
			requestId = "cura-propria", abilityId = cura, targetId = "curandeiro",
		})
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.healing, 8)
		t.eq(api.atores(id)[1].pv, 18)
	end,
	["Vigor Emprestado concede proteção canônica e dano da IA consome-a antes dos PV reais"] = function(t)
		local vigor = "ability/cura/Principiante/vigor-emprestado"
		local rng = { NextInteger = function(_, minimo, maximo)
			return if maximo == 8 then maximo elseif maximo == 20 then 10 else minimo
		end }
		local api, a, b, _, envios, avancarTempo = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, rng)
		local id = api.criar({
			{ id = "curandeiro", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = { "rank/cura/Principiante" }, purchasedIds = { vigor } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 6 },
						initiative = { bonus = 0 } }, session = { current = { pv = 20, pm = 3 } } } },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 10, z = 11,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = {}, maxima = { pv = 20, pm = 0 }, armorClass = 10,
						initiative = { bonus = 0 } }, session = { current = { pv = 15, pm = 0 } } } },
			{ id = "criatura", kind = "criatura", x = 10, z = 12,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 30, danoPorTurno = 5 } },
		})
		local estado = api.estado(id)
		t.eq(estado.currentActorId, "curandeiro")
		local ok, recibo = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = estado.version, requestId = "vigor-aliado", abilityId = vigor, targetId = "aliado" })
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.actionsSpent, 2)
		t.eq(recibo.result.pmCost, 3)
		t.eq(recibo.result.pvTemporariosConcedidos, 17, "2d8 + Bônus de Rank em Cura")
		t.eq(recibo.result.pvTemporariosAtual, 17)
		local atores = api.atores(id)
		t.eq(atores[2].pv, 15)
		t.eq(atores[2].pvTemporarios.valor, 17)
		t.eq(atores[2].pvTemporarios.expiraNoTurno, 101)
		avancarTempo(0.3)
		local fim = api.solicitarFimTurno(a, { encounterId = id, expectedVersion = 2, requestId = "vigor-passa" })
		t.eq(fim, true)
		avancarTempo(0.3)
		local fimAliado = api.solicitarFimTurno(b,
			{ encounterId = id, expectedVersion = 3, requestId = "vigor-passa-aliado" })
		t.eq(fimAliado, true)
		atores = api.atores(id)
		t.eq(atores[2].pv, 15, "o golpe de 5 foi totalmente absorvido")
		t.eq(atores[2].pvTemporarios.valor, 12)
		t.eq(atores[2].ultimoDano, 1, "dano absorvido ainda abre a sequência de Ferida Fresca")
		t.eq(atores[1].fimUltimoTurno, 0)
		local estadoEnviado
		for _, envio in ipairs(envios) do if envio.tipo == "estado" then estadoEnviado = envio.dados end end
		t.ok(estadoEnviado ~= nil)
		t.eq(estadoEnviado.actors[2].pvTemporarios, 12)
	end,
	["Ferida Fresca dobra Cura por dano recebido depois do fim da vez do curador"] = function(t)
		local api, a, b, _, _, avancarTempo = novoServico()
		local cura = "ability/cura/Principiante/cura"
		local id = api.criar({
			{ id = "curandeiro", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = { cura } },
					calculated = { attributes = { inteligencia = 3 }, maxima = { pv = 20, pm = 2 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 2 } } } },
			{ id = "criatura", kind = "criatura", x = 10, z = 12,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 5 } },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 10, z = 11,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = {}, maxima = { pv = 20, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 0 } } } },
		})
		local passouCurandeiro = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = 1, requestId = "curandeiro-primeira-vez",
		})
		t.eq(passouCurandeiro, true)
		local atores = api.atores(id)
		t.eq(atores[1].fimUltimoTurno, 0)
		t.eq(atores[3].ultimoDano, 1, "o ataque da criatura acontece depois do marco do curador")
		t.eq(atores[3].pv, 15)
		avancarTempo(0.3)
		local estado = api.estado(id)
		t.eq(estado.currentActorId, "aliado")
		local passouAliado = api.solicitarFimTurno(b, {
			encounterId = id, expectedVersion = estado.version, requestId = "aliado-passa",
		})
		t.eq(passouAliado, true)
		estado = api.estado(id)
		t.eq(estado.currentActorId, "curandeiro")
		local ok, recibo = api.solicitarHabilidade(a, {
			command = "use-ability", encounterId = id, expectedVersion = estado.version,
			requestId = "cura-ferida-fresca", abilityId = cura, targetId = "aliado",
		})
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.freshWound, true)
		t.eq(recibo.result.healing, 9, "o RNG determinístico fornece 8 + 1 nos dois dados d8")
	end,
	["Poção Menor consome 1 Ação e um item, cura aliado adjacente e não repete no replay"] = function(t)
		local consumos = {}
		local api, a, b, _, envios = novoServico(false, function(player, itemId, sourceLocalId)
			table.insert(consumos, { player = player, itemId = itemId, sourceLocalId = sourceLocalId })
			return true
		end)
		local pocao = "item/pocao_menor_cura"
		local id = api.criar({
			{ id = "portador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {}, inventory = {
					{ sourceLocalId = "pocao-1", name = "Poção Menor de Cura", type = "geral", equipped = false,
						description = "Cura 1d8 + 2 PV. Beber ou dar a um aliado adjacente é Usar Item (1 Ação). Poção não é magia: a Ferida Fresca não a dobra, e nenhuma poção apaga Ferimento Crítico." },
				} }, calculated = { attributes = {}, maxima = { pv = 20, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 0 } } } },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 10, z = 11,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = {}, maxima = { pv = 20, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 4, pm = 0 } } } },
			{ id = "criatura", kind = "criatura", x = 12, z = 12,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local itensDisponiveis
		for _, envio in ipairs(envios) do
			if envio.player == a then itensDisponiveis = envio.dados.availableItems end
		end
		t.eq(table.find(itensDisponiveis, pocao), 1)
		local pedido = { command = "use-item", encounterId = id, expectedVersion = 1,
			requestId = "pocao-aliado", itemId = pocao, targetId = "aliado" }
		local ok, recibo = api.solicitarItem(a, pedido)
		t.eq(ok, true, tostring(recibo))
		t.eq(recibo.result.actionsCost, 1)
		t.eq(recibo.result.healing, 10, "1d8 máximo mais 2, sem duplicar por Ferida Fresca")
		t.eq(api.estado(id).actionsRemaining, 2)
		t.eq(api.atores(id)[2].pv, 14)
		t.eq(#api.atores(id)[1].ficha.construction.inventory, 0)
		t.eq(#consumos, 1)
		t.eq(consumos[1].player, a)
		t.eq(consumos[1].itemId, pocao)
		t.eq(consumos[1].sourceLocalId, "pocao-1")
		local replay, mesmoRecibo = api.solicitarItem(a, pedido)
		t.eq(replay, true)
		t.eq(mesmoRecibo.version, recibo.version)
		t.eq(api.atores(id)[2].pv, 14)
		t.eq(#api.atores(id)[1].ficha.construction.inventory, 0)
		t.eq(#consumos, 1, "replay não consome novamente o inventário pessoal")
	end,
	["recusa do inventário pessoal preserva Ação, PV e item local do encontro"] = function(t)
		local api, a, b = novoServico(false, function() return false end)
		local pocao = "item/pocao_menor_cura"
		local id = api.criar({
			{ id = "portador", userId = a.UserId, kind = "jogador", x = 10, z = 10,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {}, inventory = {
					{ sourceLocalId = "pocao-recusada", name = "Poção Menor de Cura", type = "geral",
						description = "Cura 1d8 + 2 PV. Beber ou dar a um aliado adjacente é Usar Item (1 Ação). Poção não é magia: a Ferida Fresca não a dobra, e nenhuma poção apaga Ferimento Crítico." },
				} }, calculated = { attributes = {}, maxima = { pv = 20, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 20, pm = 0 } } } },
			{ id = "aliado", userId = b.UserId, kind = "jogador", x = 10, z = 11,
				ficha = { construction = { unlockedRankIds = {}, purchasedIds = {} },
					calculated = { attributes = {}, maxima = { pv = 20, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 4, pm = 0 } } } },
			{ id = "criatura", kind = "criatura", x = 12, z = 12,
				fichaCriatura = { pvMax = 30, ca = 10, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local ok = api.solicitarItem(a, { command = "use-item", encounterId = id, expectedVersion = 1,
			requestId = "pocao-sem-inventario", itemId = pocao, targetId = "aliado" })
		t.eq(ok, false)
		t.eq(api.estado(id).actionsRemaining, 3)
		t.eq(api.atores(id)[2].pv, 4)
		t.eq(#api.atores(id)[1].ficha.construction.inventory, 1)
	end,
	["fim do jogador executa ataque da criatura e devolve a vez ao grupo"] = function(t)
		local pagamentos = 0
		local api, a = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, function() pagamentos += 1; return true, 0 end)
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Aventureiro", kind = "jogador", x = 10, z = 10,
				ficha = { calculated = { maxima = { pv = 20 }, armorClass = 10 } },
			},
			{
				id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 12, ca = 10, bonusAtaque = 4, danoPorTurno = 5 },
			},
		})
		local ok = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = 1, requestId = "jogador-passa",
		})
		t.eq(ok, true)
		t.eq(api.estado(id).currentActorId, "jogador")
		t.eq(api.estado(id).phase, "active")
		t.eq(api.estado(id).version, 4, "fim, ataque da IA e fim da vez da criatura")
		t.eq(api.atores(id)[1].pv, 15)
	end,
	["ataque da criatura encerra encontro quando derruba o ultimo jogador"] = function(t)
		local pagamentos = 0
		local api, a = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, function() pagamentos += 1; return true, 0 end)
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Aventureiro", kind = "jogador", x = 10, z = 10,
				ficha = { calculated = { maxima = { pv = 5, pm = 3 }, armorClass = 10 },
					session = { current = { pv = 5, pm = 2 }, conditions = {} } },
			},
			{
				id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 12, ca = 10, bonusAtaque = 4, danoPorTurno = 5 },
			},
		})
		local ok = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = 1, requestId = "jogador-passa",
		})
		t.eq(ok, true)
		t.eq(api.estado(id).phase, "defeat")
		t.eq(api.atores(id)[1].pv, 5, "descanso automático ocorre depois de registrar a derrota")
		t.eq(api.atores(id)[1].ficha.session.current.pm, 3)
		t.eq(api.estado(id).currentActorId, "criatura")
	end,
	["criatura sem alvo adjacente passa sem causar dano"] = function(t)
		local pagamentos = 0
		local api, a = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, function() pagamentos += 1; return true, 0 end)
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Aventureiro", kind = "jogador", x = 10, z = 10,
				ficha = { calculated = { maxima = { pv = 20 }, armorClass = 10 } },
			},
			{
				id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 13,
				fichaCriatura = { pvMax = 12, ca = 10, bonusAtaque = 4, danoPorTurno = 5 },
			},
		})
		local ok = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = 1, requestId = "jogador-passa",
		})
		t.eq(ok, true)
		t.eq(api.estado(id).currentActorId, "jogador")
		t.eq(api.estado(id).phase, "active")
		t.eq(api.estado(id).version, 3, "fim do jogador e fim do turno da criatura")
		t.eq(api.atores(id)[1].pv, 20)
	end,
	["criatura usa deslocamento do bestiario para se aproximar e atacar"] = function(t)
		local pagamentos = 0
		local api, a = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, function() pagamentos += 1; return true, 0 end)
		local id = api.criar({
			{
				id = "jogador", userId = a.UserId, name = "Aventureiro", kind = "jogador", x = 10, z = 10,
				ficha = { calculated = { maxima = { pv = 20 }, armorClass = 10 } },
			},
			{
				id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 14,
				fichaCriatura = { pvMax = 12, ca = 10, bonusAtaque = 4, danoPorTurno = 5, deslocamentoMetros = 6 },
			},
		})
		local ok = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = 1, requestId = "jogador-passa-para-ia-mover",
		})
		t.eq(ok, true)
		local criatura = api.atores(id)[2]
		t.ok(math.max(math.abs(criatura.x - 10), math.abs(criatura.z - 10)) <= 1)
		t.eq(api.estado(id).currentActorId, "jogador")
		t.eq(api.atores(id)[1].pv, 15, "depois de se aproximar, o ataque da IA aplica o dano")
	end,
	["criatura escolhe o personagem adjacente com menos PV"] = function(t)
		local api, a, b = novoServico()
		local id = api.criar({
			{
				id = "jogador-a", userId = a.UserId, name = "A", kind = "jogador", x = 10, z = 10,
				ficha = { calculated = { maxima = { pv = 20 }, armorClass = 10 } },
			},
			{
				id = "jogador-b", userId = b.UserId, name = "B", kind = "jogador", x = 11, z = 10,
				ficha = { calculated = { maxima = { pv = 6 }, armorClass = 10 } },
			},
			{
				id = "criatura", name = "Goblin", kind = "criatura", x = 10, z = 11,
				fichaCriatura = { pvMax = 12, ca = 10, bonusAtaque = 4, danoPorTurno = 5 },
			},
		})
		api.solicitarFimTurno(a, { encounterId = id, expectedVersion = 1, requestId = "a-passa" })
		local ok = api.solicitarFimTurno(b, { encounterId = id, expectedVersion = 2, requestId = "b-passa" })
		t.eq(ok, true)
		local atores = api.atores(id)
		t.eq(atores[1].pv, 20)
		t.eq(atores[2].pv, 1)
	end,
	["inicio remoto cria elenco canonico de solo uma vez por pedido"] = function(t)
		local api, a, _, _, envios = novoServico()
		local pedido = { command = "start-autonomous", requestId = "inicio-solo" }
		local ok, encounterId = api.solicitarInicio(a, pedido)
		t.eq(ok, true)
		t.eq(encounterId, "encounter-1")
		local estado = envios[1].dados
		t.eq(estado.encounterId, encounterId)
		t.eq(#estado.actors, 3)
		local repetido, mesmoId = api.solicitarInicio(a, pedido)
		t.eq(repetido, true)
		t.eq(mesmoId, encounterId)
		t.eq(#envios, 2, "reenvia estado sem criar novo encontro")
	end,
	["inicio pela clareira exige alcance validado no servidor e mantém replay vinculado ao comando"] = function(t)
		local perto = false
		local areaValidada
		local api, a, _, _, envios, avancarTempo = novoServico(nil, nil, function(_, areaId)
			areaValidada = areaId
			return perto and areaId == "region/encounter/forest"
		end)
		local pedido = {
			command = "start-world-encounter", requestId = "inicio-clareira", areaId = "region/encounter/forest",
		}
		t.eq(api.solicitarInicio(a, pedido), false)
		t.eq(envios[#envios].tipo, "recusado")
		t.eq(api.estado("encounter-1"), nil)
		t.eq(areaValidada, pedido.areaId, "servidor valida o ID indicado pelo prompt")
		avancarTempo(1.1)
		perto = true
		local pedidoPerto = { command = pedido.command, requestId = "inicio-clareira-perto", areaId = pedido.areaId }
		local ok, id = api.solicitarInicio(a, pedidoPerto)
		t.eq(ok, true)
		t.eq(id, "encounter-1")
		local replay, mesmoId = api.solicitarInicio(a, pedidoPerto)
		t.eq(replay, true)
		t.eq(mesmoId, id)
		t.eq(api.solicitarInicio(a, { command = "start-autonomous", requestId = pedidoPerto.requestId }), false)
		avancarTempo(1.1)
		t.eq(api.solicitarInicio(a, {
			command = "start-world-encounter", requestId = "inicio-sem-marco",
		}), false, "início do mundo exige ID de marco explícito")
	end,
	["inicio mundial exige que todos do grupo cheguem ao mesmo marco e retry preserva a fila"] = function(t)
		local proximos = { [101] = true, [202] = false }
		local api, a, b = novoServico(nil, nil, function(player, areaId)
			return areaId == "region/encounter/forest" and proximos[player.UserId] == true
		end)
		t.eq(api.solicitarFila(a, { command = "join-autonomous-queue", requestId = "fila-a" }), true)
		t.eq(api.solicitarFila(b, { command = "join-autonomous-queue", requestId = "fila-b" }), true)
		local pedido = {
			command = "start-world-encounter", requestId = "partida-na-floresta",
			areaId = "region/encounter/forest",
		}
		t.eq(api.solicitarInicio(a, pedido), false, "aliado longe não é levado para o encontro")
		t.eq(api.estado("encounter-1"), nil, "recusa não cria encontro")
		proximos[202] = true
		local iniciou, encounterId = api.solicitarInicio(a, pedido)
		t.eq(iniciou, true, "a mesma intenção pode ser repetida após reunir o grupo")
		local atores = api.atores(encounterId)
		local userIds = {}
		for _, ator in atores do if ator.userId then userIds[ator.userId] = true end end
		t.eq(userIds[a.UserId], true)
		t.eq(userIds[b.UserId], true)
	end,
	["jogador externo nao entra nem recebe snapshot de encontro ativo"] = function(t)
		local api, a, _, estranho, envios = novoServico(nil, nil, function() return true end)
		local iniciou, encounterId = api.solicitarInicio(a, {
			command = "start-world-encounter", requestId = "grupo-privado",
			areaId = "region/encounter/clearing",
		})
		t.eq(iniciou, true)
		for _, ator in ipairs(api.atores(encounterId)) do
			t.ok(ator.userId ~= estranho.UserId, "o jogador externo não foi incluído")
		end
		for _, envio in ipairs(envios) do
			t.ok(envio.player ~= estranho or (envio.tipo == "recusado" and envio.dados.estado == nil),
				"o jogador externo não recebe estado do encontro")
		end
		t.eq(api.solicitarReconexao(estranho, { command = "reconnect-autonomous", requestId = "reconectar-fora" }), false)
		t.eq(envios[#envios].player, a, "reconexão recusada não envia snapshot ao estranho")
	end,
	["validação padrão usa o alcance do prompt e rejeita marcos desconhecidos"] = function(t)
		local apiPerto, jogadorPerto, mundoPerto = criarContexto(11.99)
		local iniciou = apiPerto.solicitarInicio(jogadorPerto, {
			command = "start-world-encounter", requestId = "perto-limite", areaId = "region/encounter/clearing",
		})
		t.eq(iniciou, true)
		mundoPerto:Destroy()

		local apiLonge, jogadorLonge, mundoLonge, avancarTempo = criarContexto(12.01)
		local longe = apiLonge.solicitarInicio(jogadorLonge, {
			command = "start-world-encounter", requestId = "fora-limite", areaId = "region/encounter/clearing",
		})
		t.eq(longe, false)
		t.eq(apiLonge.estado("encounter-1"), nil)
		avancarTempo(1.1)
		local marcoDesconhecido = apiLonge.solicitarInicio(jogadorLonge, {
			command = "start-world-encounter", requestId = "marco-desconhecido", areaId = "region/encounter/forged",
		})
		t.eq(marcoDesconhecido, false)
		t.eq(apiLonge.estado("encounter-1"), nil)
		mundoLonge:Destroy()

		local apiRetry, jogadorRetry, mundoRetry = criarContexto(6)
		local requestId = "marco-falso"
		local tentativaInvalida = apiRetry.solicitarInicio(jogadorRetry, {
			command = "start-world-encounter", requestId = requestId, areaId = "region/encounter/forged",
		})
		t.eq(tentativaInvalida, false)
		local retryValido = apiRetry.solicitarInicio(jogadorRetry, {
			command = "start-world-encounter", requestId = "marco-valido-apos-recusado", areaId = "region/encounter/clearing",
		})
		t.eq(retryValido, true, "tentativa inválida não consome o cooldown do jogador")
		mundoRetry:Destroy()

		local apiSombria, jogadorSombrio, mundoSombrio = criarContexto(6, nil, false)
		local inicioSombrio, idSombrio = apiSombria.solicitarInicio(jogadorSombrio, {
			command = "start-world-encounter", requestId = "marco-floresta-sombria",
			areaId = "region/encounter/dark-forest",
		})
		t.eq(inicioSombrio, true, "marco fora da RegiaoInicial é localizado e validado pelo catálogo")
		local elencoSombrio = apiSombria.atores(idSombrio)
		local lobos, goblins = 0, 0
		for _, ator in ipairs(elencoSombrio) do
			local criaturaId = ator.fichaCriatura and ator.fichaCriatura.catalogId
			if ator.kind == "criatura" and criaturaId == "creature/lobo-cinzento" then lobos += 1 end
			if ator.kind == "criatura" and criaturaId == "creature/goblin-batedor" then goblins += 1 end
		end
		t.eq(lobos, 1)
		t.eq(goblins, 1, "ameaça alta solo combina um padrão e um lacaio segundo o orçamento")
		mundoSombrio:Destroy()
	end,
	["inicio de marco respeita linha de visao e bloqueia pedidos remotos atras de obstaculos"] = function(t)
		local function comVisibilidade(estaVisivel)
			local verificacoes = 0
			local api, player, mundo, avancarTempo = criarContexto(6, function(character, marco)
				verificacoes += 1
				t.ok(character:IsA("Model"))
				t.eq(marco:GetAttribute("EncounterId"), "region/encounter/clearing")
				return estaVisivel
			end)
			local iniciou = api.solicitarInicio(player, {
				command = "start-world-encounter", requestId = "linha-de-visao-" .. tostring(estaVisivel),
				areaId = "region/encounter/clearing",
			})
			t.eq(verificacoes, 1)
			mundo:Destroy()
			return iniciou, api, avancarTempo
		end

		local iniciou, apiVisivel = comVisibilidade(true)
		t.eq(iniciou, true, "marco visível dentro do alcance inicia")
		t.eq(apiVisivel.estado("encounter-1").phase, "active")

		local bloqueado, apiBloqueado, avancarTempo = comVisibilidade(false)
		t.eq(bloqueado, false, "marco obstruído não inicia por pedido remoto")
		t.eq(apiBloqueado.estado("encounter-1"), nil)
		avancarTempo(1.1)
		local apiSemVisao, playerSemVisao, mundoSemVisao = criarContexto(6, nil, false)
		local iniciouSemVisao = apiSemVisao.solicitarInicio(playerSemVisao, {
			command = "start-world-encounter", requestId = "sem-linha-de-visao", areaId = "region/encounter/clearing",
		})
		t.eq(iniciouSemVisao, true, "prompt sem exigência de linha de visão mantém o fluxo dentro do alcance")
		mundoSemVisao:Destroy()
	end,
	["raycast real distingue marco visível de marco atrás de parede"] = function(t)
		local apiVisivel, playerVisivel, mundoVisivel = criarContexto(6, nil, true, true, 500)
		comLimpeza(mundoVisivel, function()
		local visivel = apiVisivel.solicitarInicio(playerVisivel, {
			command = "start-world-encounter", requestId = "raycast-visivel", areaId = "region/encounter/clearing",
		})
		t.eq(visivel, true, "raycast termina no marco quando não há obstrução")
		end)

		local apiBloqueado, playerBloqueado, mundoBloqueado = criarContexto(6, nil, true, true, 500)
		comLimpeza(mundoBloqueado, function()
		local parede = Instance.new("Part")
		parede.Name, parede.Anchored, parede.Size, parede.Position = "Obstrucao de teste", true, Vector3.new(0.5, 6, 6), Vector3.new(4.5, 500, 0)
		parede.Parent = mundoBloqueado
		local bloqueado = apiBloqueado.solicitarInicio(playerBloqueado, {
			command = "start-world-encounter", requestId = "raycast-bloqueado", areaId = "region/encounter/clearing",
		})
		t.eq(bloqueado, false, "parede interceptada impede o início remoto")
		t.eq(apiBloqueado.estado("encounter-1"), nil)
		end)
	end,
	["inicio remoto recusa campos do cliente e partida legada ativa"] = function(t)
		local api, a, _, _, envios = novoServico()
		local comCampo = api.solicitarInicio(a, {
			command = "start-autonomous", requestId = "inicio-adulterado", targetId = "criatura-do-cliente",
		})
		t.eq(comCampo, false)
		t.eq(#envios, 1)
		local apiEmCombate, jogador, _, _, enviosCombate = novoServico(true)
		local durantePartida = apiEmCombate.solicitarInicio(jogador, {
			command = "start-autonomous", requestId = "inicio-durante-partida",
		})
		t.eq(durantePartida, false)
		t.eq(#enviosCombate, 1)
		t.eq(enviosCombate[1].tipo, "recusado")
	end,
	["movimento usa caminho livre, consome uma acao e repete sem mover duas vezes"] = function(t)
		local api, a, _, _, _, avancarTempo = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, kind = "jogador", movementCasas = 6, x = 10, z = 10 },
			{ id = "criatura", kind = "criatura", x = 12, z = 10 },
		})
		local ocupado = api.solicitarMovimento(a, {
			command = "move", encounterId = id, expectedVersion = 1, requestId = "move-ocupado", x = 12, z = 10,
		})
		t.eq(ocupado, false)
		t.eq(api.estado(id).version, 1, "movimento recusado não consome Ação")
		avancarTempo(0.3)
		local pedido = { command = "move", encounterId = id, expectedVersion = 1, requestId = "move-1", x = 13, z = 10 }
		local ok, recibo = api.solicitarMovimento(a, pedido)
		t.eq(ok, true)
		t.eq(recibo.result.casas, 3, "caminho contorna a casa ocupada")
		t.eq(api.estado(id).actionsRemaining, 2)
		local atores = api.atores(id)
		t.eq(atores[1].x, 13)
		t.eq(atores[1].z, 10)
		local repetido, mesmoRecibo = api.solicitarMovimento(a, pedido)
		t.eq(repetido, true)
		t.eq(mesmoRecibo.version, recibo.version)
		t.eq(api.estado(id).version, 2)
	end,
	["grupo autônomo é opt-in, limitado a quatro e iniciado só pela liderança"] = function(t)
		local api, a, b, _, envios, avancarTempo = novoServico()
		t.eq(api.solicitarFila(a, { command = "join-autonomous-queue", requestId = "fila-a" }), true)
		avancarTempo(0.3)
		t.eq(api.solicitarFila(b, { command = "join-autonomous-queue", requestId = "fila-b" }), true)
		local semLideranca = api.solicitarInicio(b, { command = "start-autonomous", requestId = "inicio-b" })
		t.eq(semLideranca, false)
		avancarTempo(1.1)
		local ok, encounterId = api.solicitarInicio(a, { command = "start-autonomous", requestId = "inicio-a" })
		t.eq(ok, true)
		local atores = api.atores(encounterId)
		t.eq(#atores, 4, "dois jogadores consentidos e duas criaturas canônicas")
		local jogadores = 0
		for _, ator in ipairs(atores) do if ator.kind == "jogador" then jogadores += 1 end end
		t.eq(jogadores, 2)
		local filaLimpa = false
		for _, envio in ipairs(envios) do
			if envio.tipo == "fila" and #envio.dados.jogadores == 0 then filaLimpa = true end
		end
		t.eq(filaLimpa, true, "envia confirmação para quem estava na fila")
	end,
	["fila autônoma recusa dados extras e bloqueia quinta vaga"] = function(t)
		local api, a, b, _, envios, avancarTempo, c, d, e = novoServico()
		t.eq(api.solicitarFila(a, { command = "join-autonomous-queue", requestId = "fila-extra", userId = b.UserId }), false)
		t.eq(api.solicitarFila(a, { command = "join-autonomous-queue", requestId = "fila-a" }), true)
		avancarTempo(0.3)
		t.eq(api.solicitarFila(b, { command = "join-autonomous-queue", requestId = "fila-b" }), true)
		avancarTempo(0.3)
		t.eq(api.solicitarFila(c, { command = "join-autonomous-queue", requestId = "fila-c" }), true)
		avancarTempo(0.3)
		t.eq(api.solicitarFila(d, { command = "join-autonomous-queue", requestId = "fila-d" }), true)
		avancarTempo(0.3)
		t.eq(api.solicitarFila(e, { command = "join-autonomous-queue", requestId = "fila-e" }), false)
		local ultimoEstado
		for _, envio in ipairs(envios) do if envio.tipo == "fila" then ultimoEstado = envio.dados end end
		t.eq(#ultimoEstado.jogadores, 4)
	end,
	["reconexão reenvia snapshot privado ao participante ainda presente no encontro"] = function(t)
		local api, a, b, _, envios, avancarTempo, _, _, _, jogadores = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId },
			{ id = "jogador-b", userId = b.UserId },
		})
		local versao = api.estado(id).version
		-- Trocar a instância simula o retorno do mesmo participante à sessão.
		local substituto = { UserId = a.UserId }
		jogadores[a.UserId] = substituto
		t.eq(api.solicitarReconexao(substituto, { command = "reconnect-autonomous", requestId = "extra", encounterId = id }), false)
		t.eq(api.estado(id).version, versao)
		local entrada = { command = "reconnect-autonomous", requestId = "reconnect-a" }
		t.eq(api.solicitarReconexao(substituto, entrada), true)
		local enviosAposPrimeira = #envios
		t.eq(api.solicitarReconexao(substituto, { command = entrada.command, requestId = "reconnect-a-2" }), false)
		t.eq(#envios, enviosAposPrimeira, "throttle impede snapshot duplicado")
		avancarTempo(0.3)
		t.eq(api.solicitarReconexao(substituto, { command = entrada.command, requestId = "reconnect-a-2" }), true)
		t.eq(envios[#envios].tipo, "estado")
		t.eq(envios[#envios].player, substituto)
		t.eq(envios[#envios].dados.encounterId, id)
		t.eq(envios[#envios].dados.version, versao)
		t.eq(api.estado(id).version, versao)
	end,
	["grupo desconectado por 60 segundos encerra e limpa o encontro"] = function(t)
		local limpezas = 0
		local miniaturas = { limpar = function() limpezas += 1 end }
		local tempo, eventos = 0, {}
		local prazos = {
			agendar = function(segundos, callback)
				local evento = { at = tempo + segundos, callback = callback }
				table.insert(eventos, evento)
				return evento
			end,
			cancelar = function(evento) evento.cancelado = true end,
		}
		local api, a, b, _, _, avancar, _, _, _, jogadores = novoServico(nil, nil, nil, nil, nil,
			nil, nil, miniaturas, prazos)
		local id = api.criar({ { id = "jogador-a", userId = a.UserId }, { id = "jogador-b", userId = b.UserId } })
		local function avancarComScheduler(segundos)
			tempo += segundos
			avancar(segundos)
			for _, evento in ipairs(table.clone(eventos)) do
				if not evento.cancelado and not evento.executado and evento.at <= tempo then
					evento.executado = true
					evento.callback()
				end
			end
		end
		jogadores[a.UserId] = nil
		api.notificarDesconexao(a)
		t.eq(api.estado(id) ~= nil, true, "ainda há participante conectado")
		jogadores[b.UserId] = nil
		api.notificarDesconexao(b)
		avancarComScheduler(59)
		t.eq(api.estado(id) ~= nil, true)
		avancarComScheduler(1)
		t.eq(api.estado(id), nil)
		t.eq(limpezas, 1)
	end,
	["reconexão antes de 60 segundos cancela encerramento por inatividade"] = function(t)
		local api, a, b, envios, avancar, _, jogadores = servicoComPrazo()
		local id = api.criar({ { id = "jogador-a", userId = a.UserId }, { id = "jogador-b", userId = b.UserId } })
		jogadores[a.UserId] = nil
		api.notificarDesconexao(a)
		jogadores[b.UserId] = nil
		api.notificarDesconexao(b)
		avancar(59)
		local substituto = { UserId = a.UserId }
		jogadores[a.UserId] = substituto
		api.notificarConexao(substituto)
		avancar(1)
		t.eq(api.estado(id) ~= nil, true)
		t.eq(api.solicitarReconexao(substituto, { command = "reconnect-autonomous", requestId = "retorno-em-59" }), true)
		t.eq(envios[#envios].tipo, "estado")
	end,
	["retorno só aceita encontro terminal e participante autenticado"] = function(t)
		local api, a, b, estranho, envios = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId },
			{ id = "criatura", kind = "criatura" },
		})
		local pedido = { command = "return-autonomous", encounterId = id, requestId = "retorno-ativo" }
		t.eq(api.solicitarRetorno(a, pedido), false)
		t.eq(api.solicitarRetorno(estranho, pedido), false)
		t.eq(api.estado(id).phase, "active")
		t.eq(envios[#envios].tipo, "recusado")
	end,
	["retorno final autenticado libera encontro após todos e é idempotente"] = function(t)
		local api, a, b, _, envios = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, ficha = { calculated = { maxima = { pv = 0 }, armorClass = 10 } } },
			{ id = "jogador-b", userId = b.UserId, ficha = { calculated = { maxima = { pv = 0 }, armorClass = 10 } } },
			{ id = "criatura", kind = "criatura" },
		})
		local okFim = api.solicitarFimTurno(a, { encounterId = id, expectedVersion = 1, requestId = "fim-derrota" })
		t.eq(okFim, true)
		t.eq(api.estado(id).phase, "defeat")
		local retornoA = { command = "return-autonomous", encounterId = id, requestId = "retorno-a" }
		t.eq(api.solicitarRetorno(a, retornoA), true)
		t.eq(api.estado(id).phase, "defeat", "aguarda confirmação do outro participante conectado")
		local retornoB = { command = "return-autonomous", encounterId = id, requestId = "retorno-b" }
		t.eq(api.solicitarRetorno(b, retornoB), true)
		t.eq(api.estado(id), nil, "limpa estado encerrado após retorno de todos")
		t.eq(api.solicitarRetorno(b, retornoB), true, "repetição do retorno confirma sem reaplicar")
		t.eq(envios[#envios].tipo, "retornado")
	end,
	["limita pedidos novos sem bloquear retransmissao idempotente"] = function(t)
		local api, a, b, _, _, avancarTempo = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId },
			{ id = "jogador-b", userId = b.UserId },
		})
		local primeiro = { encounterId = id, expectedVersion = 1, requestId = "primeiro" }
		local ok = api.solicitarFimTurno(a, primeiro)
		t.eq(ok, true)
		local repetido = api.solicitarFimTurno(a, primeiro)
		t.eq(repetido, true)
		local spam = api.solicitarFimTurno(a, {
			encounterId = id, expectedVersion = 2, requestId = "novo-imediato",
		})
		t.eq(spam, false)
		t.eq(api.estado(id).version, 2)
		avancarTempo(0.3)
		local novo = api.solicitarFimTurno(b, {
			encounterId = id, expectedVersion = 2, requestId = "novo-depois",
		})
		t.eq(novo, true)
		t.eq(api.estado(id).version, 3)
	end,
	["movimento de jogador no bosque recusa celula de rocha pelo estado do servidor"] = function(t)
		local api, a, _, _, envios = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, kind = "jogador", x = 10, z = 10, movementCasas = 8 },
			{ id = "criatura", kind = "criatura", x = 18, z = 18 },
		}, nil, "region/encounter/forest")
		t.eq(#envios[1].dados.blockedCells, 4, "o snapshot distribui o terreno sem expor ID interno da área")
		local ok = api.solicitarMovimento(a, { encounterId = id, expectedVersion = 1,
			requestId = "movimento-na-rocha", x = 6, z = 8 })
		t.eq(ok, false)
		t.eq(envios[#envios].tipo, "recusado")
		t.eq(api.atores(id)[1].x, 10, "a recusa não altera a posição autoritativa")
	end,
	["rocha do bosque impede ataque sem gastar acao"] = function(t)
		local api, a, _, _, envios = novoServico()
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, kind = "jogador", x = 5, z = 8 },
			{ id = "criatura", kind = "criatura", x = 7, z = 8 },
		}, nil, "region/encounter/forest")
		local ok = api.solicitarAtaqueBasico(a, { encounterId = id, expectedVersion = 1,
			requestId = "ataque-atraves-rocha", targetId = "criatura" })
		t.eq(ok, false)
		t.eq(envios[#envios].tipo, "recusado")
		t.eq(api.estado(id).version, 1, "a recusa precede o consumo de Ação")
	end,
	["cria com ordem de iniciativa calculada no servidor"] = function(t)
		local api, a, b, _, envios = novoServico()
		local id, estado, rolagens = api.criarComIniciativa({
			{ id = "jogador-a", userId = a.UserId, name = "A", bonus = 0, advantage = false },
			{ id = "jogador-b", userId = b.UserId, name = "B", bonus = 0, advantage = false },
		})
		t.eq(estado.currentActorId, "jogador-a")
		t.eq(#rolagens, 2)
		t.eq(rolagens[1].natural, 20)
		t.eq(envios[1].dados.initiativeRolls[1].actorId, "jogador-a")
		t.eq(api.estado(id).version, 1)
	end,
	["monta encontro com ficha pessoal e criaturas canonicas do bestiario"] = function(t)
		local api, a, _, _, envios = novoServico()
		local id, estado = api.criarParaGrupo({ a }, {
			"creature/goblin-batedor", "creature/lobo-cinzento",
		})
		t.ok(type(id) == "string")
		t.eq(estado.version, 1)
		local atores = api.atores(id)
		t.eq(#atores, 3)
		t.eq(atores[1].id, "jogador:101")
		t.eq(atores[1].ficha.name, "Ficha 101")
		local criaturas = 0
		for _, ator in atores do
			if ator.kind == "criatura" then
				criaturas += 1
				t.eq(ator.bonus, 0)
				t.ok(type(ator.fichaCriatura.pvMax) == "number")
			end
		end
		t.eq(criaturas, 2)
		t.eq(#envios[1].dados.initiativeRolls, 3)
		atores[1].ficha.name = "adulterada"
		t.eq(api.atores(id)[1].ficha.name, "Ficha 101")
	end,
	["roteador remoto recusa comando desconhecido sem encerrar o turno"] = function(t)
		local remoto = {}
		local api, a, _, _, envios, _, _, _, _, _, rotear = novoServico(nil, nil, nil, nil, remoto)
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, kind = "jogador", x = 10, z = 10 },
			{ id = "criatura", kind = "criatura", x = 12, z = 10 },
		})
		local versao = api.estado(id).version
		rotear(a, { command = "comando-desconhecido", encounterId = id,
			expectedVersion = versao, requestId = "comando-invalido" })
		t.eq(api.estado(id).version, versao)
		t.eq(envios[#envios].tipo, "recusado")
		rotear(a, { command = "end-turn", encounterId = id, expectedVersion = versao,
			requestId = "fim-com-campo-extra", targetId = "criatura" })
		t.eq(api.estado(id).version, versao)
		t.eq(envios[#envios].tipo, "recusado")
	end,

	["arena compartilhada recusa segundo encontro enquanto esta ocupada"] = function(t)
		local api, a, b, _, envios, avancarTempo = novoServico()
		local primeiro, id = api.solicitarInicio(a, { command = "start-autonomous", requestId = "arena-1" })
		t.eq(primeiro, true)
		t.eq(id, "encounter-1")
		avancarTempo(1.1)
		local segundo = api.solicitarInicio(b, { command = "start-autonomous", requestId = "arena-2" })
		t.eq(segundo, false)
		t.eq(api.estado("encounter-2"), nil)
		t.eq(envios[#envios].tipo, "recusado")
	end,
	["derrota terminal exige retorno claro e retorno libera nova luta"] = function(t)
		local api, a, _, _, envios, avancarTempo = novoServico()
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador",
				ficha = { calculated = { maxima = { pv = 10, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 10, pm = 0 } } } },
			{ id = "criatura", kind = "criatura", fichaCriatura = { pvMax = 10, ca = 10 } },
		})
		local desistiu = api.solicitarDesistencia(a, { command = "abandon-encounter", encounterId = id,
			expectedVersion = api.estado(id).version, requestId = "terminal-desistiu" })
		t.eq(desistiu, true)
		t.eq(api.estado(id).phase, "defeat")
		avancarTempo(1.1)
		local preso = api.solicitarInicio(a, { command = "start-autonomous", requestId = "terminal-2" })
		t.eq(preso, false)
		t.ok(string.find(envios[#envios].dados.mensagem, "return%-autonomous") ~= nil)
		t.eq(api.solicitarRetorno(a, { command = "return-autonomous", encounterId = id, requestId = "terminal-volta" }), true)
		avancarTempo(1.1)
		local novo, novoId = api.solicitarInicio(a, { command = "start-autonomous", requestId = "terminal-3" })
		t.eq(novo, true)
		t.eq(novoId, "encounter-2")
	end,
	["roteador remoto aceita end-turn explicito"] = function(t)
		local api, a, b, _, envios, _, _, _, _, _, rotear = novoServico(nil, nil, nil, nil, {})
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, kind = "jogador", x = 10, z = 10 },
			{ id = "jogador-b", userId = b.UserId, kind = "jogador", x = 12, z = 10 },
		})
		rotear(a, { command = "end-turn", encounterId = id,
			expectedVersion = 1, requestId = "fim-remoto-valido" })
		t.eq(api.estado(id).version, 2)
		t.eq(envios[#envios].tipo, "estado")
	end,
	["desistencia autenticada zera PV e mantém a luta para o grupo"] = function(t)
		local api, a, b, estranho, envios = novoServico()
		local fichaA = { calculated = { maxima = { pv = 20, pm = 3 }, armorClass = 12 },
			session = { current = { pv = 12, pm = 3 } } }
		local id = api.criar({
			{ id = "jogador-a", userId = a.UserId, kind = "jogador", ficha = fichaA },
			{ id = "jogador-b", userId = b.UserId, kind = "jogador",
				ficha = { calculated = { maxima = { pv = 20, pm = 3 }, armorClass = 12 },
					session = { current = { pv = 20, pm = 3 } } } },
			{ id = "criatura", kind = "criatura", x = 1, z = 1,
				fichaCriatura = { pvMax = 10, ca = 10, deslocamentoMetros = 0, bonusAtaque = 0, danoPorTurno = 0 } },
		})
		local pedido = { command = "abandon-encounter", encounterId = id,
			expectedVersion = 1, requestId = "desistencia-a" }
		local comCampoExtra = table.clone(pedido)
		comCampoExtra.actorId = "jogador-a"
		t.eq(api.solicitarDesistencia(a, comCampoExtra), false)
		t.eq(api.solicitarDesistencia(estranho, pedido), false)
		local desatualizado = table.clone(pedido)
		desatualizado.requestId, desatualizado.expectedVersion = "versao-antiga", 2
		t.eq(api.solicitarDesistencia(a, desatualizado), false)
		local aceito, recibo = api.solicitarDesistencia(a, pedido)
		t.eq(aceito, true)
		t.eq(recibo.action, "abandon-encounter")
		t.eq(recibo.nextActorId, "jogador-b")
		t.eq(api.estado(id).phase, "active")
		t.eq(api.estado(id).version, 2)
		t.eq(api.atores(id)[1].pv, 0)
		t.eq(api.atores(id)[1].downed, true)
		t.eq(api.atores(id)[1].defeated, true)
		t.eq(api.atores(id)[1].ficha.session.current.pv, 0)
		local terminou = api.solicitarFimTurno(b, {
			encounterId = id, expectedVersion = 2, requestId = "jogador-b-encerra",
		})
		t.eq(terminou, true)
		local versaoAposIA = api.estado(id).version
		local repetido, reciboRepetido = api.solicitarDesistencia(a, pedido)
		t.eq(repetido, true)
		t.eq(reciboRepetido.version, recibo.version)
		t.eq(api.estado(id).version, versaoAposIA, "replay atrasado não reaplica desistência nem avança a IA")
		local recibos = {}
		for _, envio in envios do
			if envio.tipo == "recibo" and envio.dados.action == "abandon-encounter" then
				table.insert(recibos, envio)
			end
		end
		t.eq(#recibos, 2, "cada participante recebe um recibo, sem repetir a animacao")
		local destinatarios = { recibos[1].player, recibos[2].player }
		t.ok(table.find(destinatarios, a) ~= nil)
		t.ok(table.find(destinatarios, b) ~= nil)
	end,
	["desistencia do ultimo jogador encerra em derrota"] = function(t)
		local pagamentos = 0
		local api, a = novoServico(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, function() pagamentos += 1; return true, 0 end)
		local id = api.criar({
			{ id = "jogador", userId = a.UserId, kind = "jogador",
				ficha = { calculated = { maxima = { pv = 10, pm = 0 }, armorClass = 10 },
					session = { current = { pv = 10, pm = 0 } } } },
			{ id = "criatura", kind = "criatura", fichaCriatura = { pvMax = 10, ca = 10 } },
		})
		local ok, recibo = api.solicitarDesistencia(a, { command = "abandon-encounter", encounterId = id,
			expectedVersion = 1, requestId = "desistencia-final" })
		t.eq(ok, true)
		t.eq(recibo.result.encounterEnded, "defeat")
		t.eq(pagamentos, 0, "derrota/desistência não paga")
		t.eq(api.estado(id).phase, "defeat")
		t.eq(api.atores(id)[1].pv, 10, "RB-25 restaura recursos depois de concluir o encontro")
		t.eq(api.atores(id)[1].ficha.session.current.pv, 10)
	end,
	["vitoria paga igualmente a cada jogador vivo e inclui total no estado terminal"] = function(t)
		local pagamentos, totalChamadas = {}, 0
		local function pagar(player, encounterId, moedas)
			totalChamadas += 1
			pagamentos[player.UserId] = { encounterId = encounterId, moedas = moedas }
			return true, 40 + moedas
		end
		local api, a, id, _, _, envios = encontroComLanca(nil, nil, 2, true, pagar)
		local ok = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id,
			expectedVersion = 1, requestId = "lanca-paga", abilityId = "ability/terra/Principiante/lanca-de-pedra", targetId = "lista:c1,c2,c3" })
		t.eq(ok, true); t.eq(api.estado(id).phase, "victory")
		-- Três humanoides: 18 PO em moedas e 12 PO em partes liquidadas.
		t.eq(pagamentos[a.UserId].moedas, 30); t.eq(pagamentos[202].moedas, 30)
		t.eq(totalChamadas, 2)
		local estadoA, estadoB
		for _, envio in ipairs(envios) do
			if envio.tipo == "estado" and envio.dados.phase == "victory" then
				if envio.player.UserId == a.UserId then estadoA = envio.dados elseif envio.player.UserId == 202 then estadoB = envio.dados end
			end
		end
		t.eq(estadoA.ouroGanho, 30); t.eq(estadoA.ouroTotal, 70)
		t.eq(estadoB.ouroGanho, 30); t.eq(estadoB.ouroTotal, 70)
		local replay = api.solicitarHabilidade(a, { command = "use-ability", encounterId = id, expectedVersion = 1, requestId = "lanca-paga", abilityId = "ability/terra/Principiante/lanca-de-pedra", targetId = "lista:c1,c2,c3" })
		t.eq(replay, true); t.eq(totalChamadas, 2)
		local estadoA
		for _, envio in ipairs(api._envios or {}) do estadoA = envio end
	end,
}
