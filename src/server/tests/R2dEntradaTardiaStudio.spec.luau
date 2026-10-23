-- SOMENTE STUDIO: observação física e entrada tardia autenticada no encontro.
local Service = require(script.Parent.Parent.EncontroAutonomoService)

local function fixture(quantidadeInicial, opcoes)
	opcoes = opcoes or {}
	local world = Instance.new("WorldModel")
	world.Parent = workspace
	local parent = Instance.new("Folder")
	parent.Name, parent.Parent = "ArenaR2d", world
	local jogadores, chars, roots, perfis, envios = {}, {}, {}, {}, {}
	for i = 1, 7 do
		local char = Instance.new("Model")
		char.Name, char.Parent = "Char" .. i, world
		local root = Instance.new("Part")
		root.Name, root.Anchored, root.Parent = "HumanoidRootPart", true, char
		root.Position = Vector3.new(100, 0, 100)
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = char
		local player = { UserId = 100 + i, Character = char }
		jogadores[i], chars[i], roots[i] = player, char, root
		perfis[player.UserId] = {
			name = "Jogador " .. i,
			calculated = { initiative = { bonus = 30, advantage = false }, movementMeters = 9,
				attributes = { vigor = 0, forca = 0 }, skills = {}, maxima = { pv = 30, pm = 0 }, armorClass = 10 },
			session = { current = { pv = 30, pm = 0 } },
		}
	end
	local conectados = {}
	for _, player in ipairs(jogadores) do conectados[player.UserId] = player end
	local nextId, rngCalls = 0, 0
	local api = Service.start({
		remote = {}, jogadoresPatrulha = function()
			local lista = {}
			for _, p in ipairs(jogadores) do if conectados[p.UserId] == p then table.insert(lista, p) end end
			return lista
		end,
		localizarJogador = function(id) return conectados[id] end,
		conectado = function(p) return conectados[p.UserId] == p end,
		corpoPessoal = function(p)
			if p.aguardarFicha then coroutine.yield() end
			return perfis[p.UserId]
		end,
		emCombate = function(p) return p.emCombate == true end,
		workspace = world, novoId = function() nextId += 1; return "r2d-entrada-" .. nextId end,
		agora = opcoes.agora or function() return 10 end, agendarPrazo = function() end, cancelarPrazo = function() end,
		rng = opcoes.rng or { NextInteger = function(_, minimo) rngCalls += 1; return minimo end },
		emitir = function(player, tipo, dados) table.insert(envios, { player = player, tipo = tipo, dados = dados }) end,
	})
	local arena = { centro = Vector3.new(0, 0, 0), pasta = parent, parent = world,
		bloqueadas = {}, validarInicio = function() return true end }
	local function limpar()
		if world.Parent then world:Destroy() end
	end
	return api, jogadores, roots, chars, conectados, perfis, envios, arena, limpar, function() return rngCalls end
end

local function executarComLimpeza(limpar, callback, t)
	local ok, erro = pcall(callback)
	limpar()
	if not ok then error(erro, 0) end
end

local function criar(api, player, arena)
	return api.criarParaGrupo({ player }, { "creature/goblin-batedor" }, "region/encounter/clearing", arena)
end

local function encerrarVez(api, player, id)
	local estado = api.estado(id)
	local ok, recibo = api.solicitarFimTurno(player, {
		encounterId = id, expectedVersion = estado.version, requestId = "fim-r2d-" .. tostring(estado.version),
	})
	return ok, recibo
end

local function atoresEntrados(recibo)
	return recibo and recibo.result and recibo.result.joinedActors or {}
end

return {
	["observar na rodada dois reserva apenas a rodada tres"] = function(t)
		local tempo = 10
		local api, ps, roots, _, _, _, _, arena, limpar = fixture(1, { agora = function() return tempo end })
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			encerrarVez(api, ps[1], id)
			t.eq(api.estado(id).turn, 2)
			roots[2].Position = Vector3.zero
			api.observarEntradasPatrulha()
			t.eq(#api.atores(id), 2)
			t.eq(api.estado(id).turn, 2)
			tempo = 11
			encerrarVez(api, ps[1], id)
			t.eq(api.estado(id).turn, 3)
			t.eq(#api.atores(id), 3)
		end, t)
	end,
	["fuga na ultima vez da rodada admite candidato sem remover fugitivo duas vezes"] = function(t)
		local api, ps, roots, _, _, perfis, envios, arena, limpar = fixture(2, {
			rng = { NextInteger = function(_, _, maximo) return math.min(10, maximo) end },
		})
		executarComLimpeza(limpar, function()
			local Shared = game:GetService("ReplicatedStorage").Shared
			for _, perfil in pairs(perfis) do perfil.calculated.maxima.pv = 100; perfil.session.current.pv = 100 end
			perfis[ps[2].UserId].calculated.attributes.forca = 50
			local elenco = require(Shared.EncontroAutonomoElenco).montar({ ps[1], ps[2] }, { "creature/goblin-batedor" }, {
				conectado = function() return true end, corpoPessoal = function(p) return perfis[p.UserId] end,
				criatura = function(id) return require(Shared.Regras.Criaturas).ficha(require(Shared.Livro.Catalogo).POR_ID[id]) end,
			})
			elenco[1].bonus, elenco[2].bonus, elenco[3].bonus = 40, 30, 50
			elenco[2].x, elenco[2].z = 1, 10
			local id = api.criarComIniciativa(elenco, "region/encounter/clearing", arena)
			roots[3].Position = Vector3.new(17, 3, -18)
			api.observarEntradasPatrulha()
			encerrarVez(api, ps[1], id)
			local ok, recibo = api.solicitarFuga(ps[2], { command = "flee-encounter", encounterId = id,
				expectedVersion = api.estado(id).version, requestId = "fuga-fecha-rodada" })
			t.eq(ok, true); t.eq(recibo.result.fugiu, true)
			t.eq(#recibo.result.joinedActors, 1)
			t.eq(recibo.result.joinedActors[1].actorId, "jogador:103")
			t.eq(api.estado(id).turn, 2); t.eq(api.estado(id).phase, "active")
			t.eq(#api.atores(id), 4)
		end, t)
	end,
	["patrulha fisica inclui proximos e heartbeat admite o tardio com avatar projetado"] = function(t)
		local Server = script.Parent.Parent
		local Regiao = require(Server.RegiaoInicial)
		local mundo = Instance.new("WorldModel")
		mundo.Parent = workspace
		executarComLimpeza(function() mundo:Destroy() end, function()
			local regiao = Instance.new("Folder")
			regiao.Name, regiao.Parent = "RegiaoInicial", mundo
			local piso = Instance.new("Part")
			piso.Size, piso.Position, piso.Anchored, piso.Parent = Vector3.new(120, 2, 120), Vector3.new(54, -1, 43), true, mundo
			local ps, roots = {}, {}
			for i = 1, 4 do
				local char = Instance.new("Model")
				char.Parent = mundo
				local root = Instance.new("Part")
				root.Name, root.Anchored, root.CanCollide, root.Parent = "HumanoidRootPart", true, false, char
				local hum = Instance.new("Humanoid")
				hum.Parent = char
				ps[i], roots[i] = { UserId = 200 + i, Character = char }, root
			end
			local service, encontroId, tickEntradas
			local patrulha = Regiao.iniciarPatrulha({ workspace = mundo, agora = function() return 10 end,
				elegivel = function() return true end, ocupado = function() return false end,
				jogadores = function() return ps end,
				encontrar = function(player, origem)
					local ok, id = service.iniciarPorPatrulha(player, origem)
					encontroId = id
					return ok
				end })
			local centro = Vector3.new(patrulha.corpo.Position.X, 0, patrulha.corpo.Position.Z)
			roots[1].Position = centro + Vector3.new(0, 3, 3)
			roots[2].Position = centro + Vector3.new(2, 3, 0)
			roots[3].Position = centro + Vector3.new(16, 3, -17)
			roots[4].Position = centro + Vector3.new(30, 3, 0)
			local posicaoDistante = roots[4].Position
			local function localizar(id)
				for _, p in ipairs(ps) do if p.UserId == id then return p end end
				return nil
			end
			local avatares = require(Server.EncontroAutonomoAvatares).start({ workspace = mundo, localizarJogador = localizar })
			service = Service.start({ remote = {}, workspace = mundo,
				criarPatrulha = function() return patrulha end,
				jogadoresPatrulha = function() return table.clone(ps) end,
				heartbeatEntradas = { Connect = function(_, callback) tickEntradas = callback end },
				localizarJogador = localizar, conectado = function(p) return localizar(p.UserId) == p end,
				avatares = avatares, agendarPrazo = function() end, cancelarPrazo = function() end,
				agora = function() return 10 end, novoId = function() return "r2d-patrulha-integrada" end,
				rng = { NextInteger = function() return 10 end }, emitir = function() end,
				corpoPessoal = function(p) return { name = "Integrado " .. p.UserId, calculated = {
					initiative = { bonus = 30, advantage = false }, movementMeters = 9,
					attributes = { vigor = 0, forca = 0 }, maxima = { pv = 100, pm = 0 }, armorClass = 30 } } end })
			patrulha.atualizar(0.1)
			t.ok(encontroId ~= nil, "contato físico criou o encontro")
			t.eq(#service.atores(encontroId), 3, "dois próximos e uma criatura no grupo inicial")
			t.eq(roots[3].Position, centro + Vector3.new(16, 3, -17), "tardio ainda explora")
			tickEntradas()
			t.eq(#service.atores(encontroId), 3, "heartbeat reserva sem inserir na rodada um")
			encerrarVez(service, ps[1], encontroId)
			encerrarVez(service, ps[2], encontroId)
			t.eq(service.estado(encontroId).turn, 2)
			local novo
			for _, ator in ipairs(service.atores(encontroId)) do if ator.userId == ps[3].UserId then novo = ator end end
			t.ok(novo ~= nil, "terceiro entrou na rodada dois")
			t.eq(novo.x, 19); t.eq(novo.z, 1)
			local projetada = require(Server.EncontroAutonomoGeometria).posicao(centro, novo.x, novo.z)
			t.ok((roots[3].Position - Vector3.new(projetada.X, 3, projetada.Z)).Magnitude < 0.01)
			t.eq(ps[3].Character:FindFirstChildOfClass("Humanoid").WalkSpeed, 0)
			t.eq(roots[4].Position, posicaoDistante, "fora da grade permanece livre")
			avatares.limpar(encontroId)
			t.eq(ps[3].Character:FindFirstChildOfClass("Humanoid").WalkSpeed, 16)
		end, t)
	end,
	["reserva impede fila e segundo encontro e confirma identidade novamente"] = function(t)
		local api, ps, roots, _, conectados, _, _, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			roots[2].Position = Vector3.new(17, 3, 0)
			api.observarEntradasPatrulha()
			t.eq(api.solicitarFila(ps[2], { command = "join-autonomous-queue", requestId = "fila-reservada" }), false)
			t.eq(api.criarParaGrupo({ ps[2] }, { "creature/goblin-batedor" }), nil)
			conectados[ps[2].UserId] = { UserId = ps[2].UserId, Character = ps[2].Character }
			encerrarVez(api, ps[1], id)
			t.eq(#api.atores(id), 2, "troca de identidade cancela candidato reservado")
		end, t)
	end,
	["combate legado e ficha que aguarda carregamento impedem entrada"] = function(t)
		local api, ps, roots, _, _, _, _, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			roots[2].Position, ps[2].emCombate = Vector3.zero, true
			roots[3].Position, ps[3].aguardarFicha = Vector3.zero, true
			api.observarEntradasPatrulha()
			encerrarVez(api, ps[1], id)
			t.eq(#api.atores(id), 2, "não suspende nem confirma transação esperando ficha")
		end, t)
	end,
	["borda bloqueada recusa entrada sem sobrepor atores nem incluir iniciativa"] = function(t)
		local api, ps, roots, _, _, _, envios, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			for x = 1, 20 do
				for z = 1, 20 do
					if x == 1 or x == 20 or z == 1 or z == 20 then table.insert(arena.bloqueadas, { x = x, z = z }) end
				end
			end
			local id = criar(api, ps[1], arena)
			roots[2].Position = Vector3.new(17, 3, -18)
			api.observarEntradasPatrulha()
			encerrarVez(api, ps[1], id)
			t.eq(#api.atores(id), 2)
			for _, envio in ipairs(envios) do
				if envio.tipo == "estado" then t.eq(#envio.dados.initiativeRolls, 2) end
			end
		end, t)
	end,
	["entrada respeita bloqueio na borda e snapshots privados chegam a ambos"] = function(t)
		local api, ps, roots, _, _, perfis, envios, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			arena.bloqueadas = { { x = 20, z = 1 } }
			perfis[ps[2].UserId].session.current = { pv = 17, pm = 0 }
			local id = criar(api, ps[1], arena)
			roots[2].Position = Vector3.new(17, 3, -18)
			api.observarEntradasPatrulha()
			encerrarVez(api, ps[1], id)
			local recebeuRecibo, recebeuEstado = {}, {}
			for _, envio in ipairs(envios) do
				if envio.tipo == "recibo" and #atoresEntrados(envio.dados) > 0 then
					recebeuRecibo[envio.player.UserId] = (recebeuRecibo[envio.player.UserId] or 0) + 1
				elseif envio.tipo == "estado" and envio.dados.turn == 2 then
					recebeuEstado[envio.player.UserId] = true
					t.eq(envio.dados.controlledActorId, "jogador:" .. envio.player.UserId)
				end
			end
			for _, p in ipairs({ ps[1], ps[2] }) do
				t.eq(recebeuRecibo[p.UserId], 1, "um recibo por observador")
				t.eq(recebeuEstado[p.UserId], true)
			end
			t.eq(recebeuEstado[ps[3].UserId], nil, "distante não recebe estado do combate")
			local novo = api.atores(id)[3]
			t.eq(novo.x, 19); t.eq(novo.z, 1)
			t.eq(novo.pv, 17, "montagem preserva recursos atuais")
			novo.ficha.session.current.pv = 1
			t.eq(perfis[ps[2].UserId].session.current.pv, 17, "corpo do encontro é isolado da ficha de origem")
		end, t)
	end,
	["encontro terminal não admite candidato reservado"] = function(t)
		local api, ps, roots, _, _, _, _, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			roots[2].Position = Vector3.zero
			api.observarEntradasPatrulha()
			t.eq(api.solicitarDesistencia(ps[1], { command = "abandon-encounter", encounterId = id,
				expectedVersion = api.estado(id).version, requestId = "terminar-antes-entrada" }), true)
			t.eq(api.estado(id).phase, "defeat")
			api.observarEntradasPatrulha()
			t.eq(#api.atores(id), 2)
		end, t)
	end,
	["fugitivo permanece excluido mesmo pisando de novo e retornando ao mundo"] = function(t)
		local api, ps, roots, _, _, perfis, _, arena, limpar = fixture(2, {
			rng = { NextInteger = function(_, _, maximo) return maximo end },
		})
		executarComLimpeza(limpar, function()
			local Shared = game:GetService("ReplicatedStorage").Shared
			local elenco = require(Shared.EncontroAutonomoElenco).montar({ ps[1], ps[2] }, { "creature/goblin-batedor" }, {
				conectado = function() return true end, corpoPessoal = function(p) return perfis[p.UserId] end,
				criatura = function(id) return require(Shared.Regras.Criaturas).ficha(require(Shared.Livro.Catalogo).POR_ID[id]) end,
			})
			elenco[1].x, elenco[1].z = 1, 10
			local id = api.criarComIniciativa(elenco, "region/encounter/clearing", arena)
			t.eq(api.solicitarFuga(ps[1], { command = "flee-encounter", encounterId = id,
				expectedVersion = api.estado(id).version, requestId = "fugir-r2d" }), true)
			t.eq(api.solicitarRetorno(ps[1], { command = "return-autonomous", encounterId = id, requestId = "retornar-r2d" }), true)
			roots[1].Position = Vector3.zero
			api.observarEntradasPatrulha()
			encerrarVez(api, ps[2], id)
			local atores = api.atores(id)
			t.eq(#atores, 3)
			t.eq(atores[1].fled, true)
		end, t)
	end,
	["observacao reserva candidato uma vez para a rodada seguinte e recibo inclui posicao"] = function(t)
		local api, ps, roots, _, _, _, envios, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			t.ok(id ~= nil)
			roots[2].Position = Vector3.new(17, 6, -18)
			api.observarEntradasPatrulha()
			api.observarEntradasPatrulha()
			t.eq(#api.atores(id), 2, "observar so reserva; ainda nao altera elenco/turno")
			local _, recibo = encerrarVez(api, ps[1], id)
			t.ok(recibo ~= nil)
			local joined = atoresEntrados(recibo)[1]
			if not joined then
				for _, envio in ipairs(envios) do
					if envio.tipo == "recibo" and #atoresEntrados(envio.dados) > 0 then joined = atoresEntrados(envio.dados)[1] end
				end
			end
			t.ok(joined ~= nil, "observacoes repetidas nao duplicam a reserva")
			t.eq(joined.actorId, "jogador:102")
			t.eq(joined.name, "Jogador 2")
			t.eq(joined.x, 20)
			t.eq(joined.z, 1)
			local ids = {}
			for indice = #envios, 1, -1 do
				local envio = envios[indice]
				if envio.tipo == "estado" and envio.dados.actors then
					for _, actor in ipairs(envio.dados.actors) do ids[actor.id] = true end
					break
				end
			end
			t.eq(ids["jogador:102"], true, "snapshot apos a fronteira contem o ator")
		end, t)
	end,
	["limites espaciais e identidade recusam entradas inelegiveis"] = function(t)
		local api, ps, roots, _, conectados, perfis, _, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			roots[2].Position = Vector3.new(18.01, 0, 0)
			roots[3].Position = Vector3.new(0, 6.01, 0)
			roots[4].Position = Vector3.new(0, 0, 18.01)
			local falso = { UserId = ps[5].UserId, Character = ps[5].Character }
			conectados[ps[5].UserId] = falso
			api.observarEntradasPatrulha()
			local _, recibo = encerrarVez(api, ps[1], id)
			t.eq(#atoresEntrados(recibo), 0)
			t.eq(#api.atores(id), 2)
		end, t)
	end,
	["morte desconexao e combate paralelo cancelam reserva antes de concluir"] = function(t)
		local api, ps, roots, _, conectados, perfis, _, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			roots[2].Position = Vector3.new(1, 0, 0)
			api.observarEntradasPatrulha()
			perfis[ps[2].UserId].session.current.pv = 0
			roots[3].Position = Vector3.new(2, 0, 0)
			api.observarEntradasPatrulha()
			conectados[ps[3].UserId] = nil
			local _, recibo = encerrarVez(api, ps[1], id)
			t.eq(#atoresEntrados(recibo), 0)
			t.eq(#api.atores(id), 2)
		end, t)
	end,
	["candidato sai da grade ou nao tem ficha e perde a reserva"] = function(t)
		local api, ps, roots, _, _, perfis, _, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			roots[2].Position = Vector3.new(3, 0, 3)
			api.observarEntradasPatrulha()
			roots[2].Position = Vector3.new(19, 0, 0)
			api.observarEntradasPatrulha()
			roots[3].Position = Vector3.new(0, 0, 0)
			perfis[ps[3].UserId] = nil
			api.observarEntradasPatrulha()
			local _, recibo = encerrarVez(api, ps[1], id)
			t.eq(#atoresEntrados(recibo), 0)
			t.eq(#api.atores(id), 2)
		end, t)
	end,
	["fila e outro encontro ativo bloqueiam candidatos da patrulha"] = function(t)
		local api, ps, roots, _, _, _, _, arena, limpar = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			t.ok(id ~= nil)
			t.eq(api.solicitarFila(ps[2], { command = "join-autonomous-queue", requestId = "r2d-fila" }), true)
			local outro = api.criarParaGrupo({ ps[3] }, { "creature/goblin-batedor" })
			t.ok(outro ~= nil)
			roots[2].Position = Vector3.new(1, 0, 0)
			roots[3].Position = Vector3.new(2, 0, 0)
			api.observarEntradasPatrulha()
			local _, recibo = encerrarVez(api, ps[1], id)
			t.eq(#atoresEntrados(recibo), 0)
			for _, actor in ipairs(api.atores(id)) do
				t.ok(actor.id ~= "jogador:102" and actor.id ~= "jogador:103")
			end
		end, t)
	end,
	["somente iniciativa nova rola e os resultados originais permanecem"] = function(t)
		local api, ps, roots, _, _, perfis, envios, arena, limpar, contarRng = fixture(1)
		executarComLimpeza(limpar, function()
			local id = criar(api, ps[1], arena)
			local chamadasIniciais = contarRng()
			local naturaisIniciais = {}
			for _, envio in ipairs(envios) do
				if envio.tipo == "estado" and envio.dados.initiativeRolls then
					for _, rolagem in ipairs(envio.dados.initiativeRolls) do
						naturaisIniciais[rolagem.actorId] = rolagem.natural
					end
					break
				end
			end
			perfis[ps[2].UserId].calculated.initiative = { bonus = 50, advantage = true }
			roots[2].Position = Vector3.new(1, 0, 0)
			api.observarEntradasPatrulha()
			t.eq(contarRng(), chamadasIniciais, "observar nao rola iniciativa antes da fronteira")
			for _ = 1, 6 do
				local encontrado = false
				for _, actor in ipairs(api.atores(id)) do if actor.id == "jogador:102" then encontrado = true end end
				if encontrado then break end
				local atual = api.estado(id).currentActorId
				local userId = tonumber(string.match(atual, "^jogador:(%d+)$"))
				if userId then
					local player = if userId == ps[1].UserId then ps[1] else ps[2]
					encerrarVez(api, player, id)
				end
			end
			local finalIds = {}
			for _, envio in ipairs(envios) do
				if envio.tipo == "estado" and envio.dados.initiativeRolls then
					for _, rolagem in ipairs(envio.dados.initiativeRolls) do
						if naturaisIniciais[rolagem.actorId] ~= nil then
							finalIds[rolagem.actorId] = rolagem.natural
						end
					end
				end
			end
			for atorId, natural in naturaisIniciais do t.eq(finalIds[atorId], natural) end
			t.eq(api.estado(id).currentActorId, "jogador:102", "iniciativa maior entra antes do primeiro ator da nova rodada")
			t.eq(api.estado(id).actionsRemaining, 3)
			local ataques = 0
			-- A IA também consome um d20 de ataque nesta rodada; recibos são
			-- enviados a cada observador, então contamos só os do jogador inicial.
			for _, envio in ipairs(envios) do
				if envio.player == ps[1] and envio.tipo == "recibo" and envio.dados.action == "creature-attack" then ataques += 1 end
			end
			t.eq(contarRng(), chamadasIniciais + ataques + 2, "vantagem rola duas vezes somente para a entrada nova")
		end, t)
	end,
	["grupo limitado a quatro jogadores ao admitir o candidato observado"] = function(t)
		local api, ps, roots, _, _, _, envios, arena, limpar = fixture(3)
		executarComLimpeza(limpar, function()
			local id = api.criarParaGrupo({ ps[1], ps[2], ps[3] }, { "creature/goblin-batedor" }, "region/encounter/clearing", arena)
			t.ok(id ~= nil)
			for indice = 4, 7 do roots[indice].Position = Vector3.new(indice, 0, 0) end
			api.observarEntradasPatrulha()
			-- A reserva deve respeitar o teto total de quatro atores jogadores.
			local entrou = false
			for _ = 1, 8 do
				for _, actor in ipairs(api.atores(id)) do
					if actor.id == "jogador:104" then entrou = true end
				end
				if entrou then break end
				local estado = api.estado(id)
				local userId = tonumber(string.match(estado.currentActorId, "^jogador:(%d+)$"))
				if not userId then continue end -- a IA conclui a parte inimiga durante a transicao.
				local player
				for _, candidato in ipairs(ps) do
					if candidato.UserId == userId then player = candidato; break end
				end
				encerrarVez(api, player, id)
			end
			for _, envio in ipairs(envios) do
				if envio.tipo == "recibo" and envio.dados.result and envio.dados.result.joinedActors then
				t.eq(#atoresEntrados(envio.dados), 1)
				end
			end
			t.ok(entrou, "o candidato entra na proxima rodada, sem exceder quatro jogadores")
			t.eq(#api.atores(id), 5, "quatro jogadores mais a criatura")
		end, t)
	end,
}
