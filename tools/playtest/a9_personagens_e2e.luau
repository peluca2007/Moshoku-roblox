-- A9/F2: todos os personagens prontos no jogo real (cliente em Play). Para cada um:
-- escolhe, entra no Treino, confere nome e cartas, usa cada carta num boneco e
-- procura erro interno do servidor. Grava em shared.A9.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local Personagens = require(game.ReplicatedStorage.Shared.PersonagensProntos)
local R = { linhas = {}, falhas = 0, pronto = false }
shared.A9 = R
local snapshot, logs = nil, {}
local conexao = remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d elseif k == "log" then table.insert(logs, d.text) end
end)
local function check(nome, ok, det)
	table.insert(R.linhas, (if ok then "OK    " else "FALHA ") .. nome .. ((not ok and det) and (" — " .. tostring(det)) or ""))
	if not ok then R.falhas += 1 end
end
local function send(c, p, w) remote:FireServer(c, p); task.wait(w or 0.35) end
local function esperar(condicao, segundos)
	local limite = os.clock() + (segundos or 12)
	repeat
		if snapshot and condicao() then return true end
		task.wait(0.1)
	until os.clock() >= limite
	return false
end
local function esperarVezPrincipal(id, turnoAnterior)
	local limite = os.clock() + 15
	repeat
		local combat = snapshot.combat
		if combat.turnId == id and (not turnoAnterior or combat.turn > turnoAnterior) then return true end
		-- Pactos acrescenta fichas controladas pelo jogador à iniciativa. Passar
		-- deliberadamente a vez delas; esperar sozinho nunca volta ao invocador.
		for _, t in snapshot.tokens do
			if t.id == combat.turnId and t.id ~= id and t.ownerUserId == game.Players.LocalPlayer.UserId then
				send("nextTurn", { expectedId = t.id, expectedTurn = combat.turn })
				break
			end
		end
		task.wait(0.1)
	until os.clock() >= limite
	return false
end
task.spawn(function()
	local ok, erro = pcall(function()
		send("requestSnapshot")
		assert(esperar(function() return true end), "snapshot não recebido")
		assert(not snapshot.combat.active, "comece o roteiro sem uma partida ativa")
		for _, p in Personagens do
			send("escolherPersonagem", { id = p.id })
			check(p.id .. ": escolha registrada", snapshot.you.personagem == p.id, snapshot.you.personagem)
			send("iniciarTreino", {}, 1.6)
			assert(esperar(function() return snapshot.combat.active end), p.id .. ": treino não iniciou")
			local eu, boneco
			for _, t in snapshot.tokens do
				if t.ownerUserId == game.Players.LocalPlayer.UserId and t.kind == "jogador" then eu = t end
			end
			check(p.id .. ": personagem certo na mesa", eu and eu.name == p.nome, eu and eu.name)
			if eu then
				local faltam = {}
				for _, c in p.cartas do
					if not table.find(eu.habilidades or {}, c) then table.insert(faltam, c) end
				end
				check(p.id .. ": cartas na barra", #faltam == 0, table.concat(faltam, ","))
				local antes = #logs
				for _, h in eu.habilidades or {} do
					assert(esperarVezPrincipal(eu.id), "vez não voltou ao jogador")
					-- boneco mais próximo como alvo; cada carta tenta uma vez
					local melhor, dist = nil, math.huge
					for _, t in snapshot.tokens do
						if t.name == "Boneco de Treino" then
							local d = math.max(math.abs(t.x - eu.x), math.abs(t.z - eu.z))
							if d < dist then melhor, dist = t, d end
						end
					end
					send("usarHabilidade", { tokenId = eu.id, habilidadeId = h, alvoId = melhor and melhor.id, x = melhor and melhor.x, z = melhor and melhor.z }, 0.25)
					local turno = snapshot.combat.turn
					send("nextTurn", { expectedId = eu.id, expectedTurn = turno })
					assert(esperarVezPrincipal(eu.id, turno), "turno não renovado")
				end
				local internos = {}
				for i = antes + 1, #logs do
					if string.find(logs[i], "Erro interno", 1, true) then table.insert(internos, logs[i]) end
				end
				check(p.id .. ": " .. #(eu.habilidades or {}) .. " cartas usadas sem erro interno", #internos == 0, table.concat(internos, " | "))
			end
			-- Usa o mesmo caminho do jogador comum; iniciar outro treino em combate é recusado.
			send("sairPartida", {})
			local saiu = esperar(function() return not snapshot.combat.active and #snapshot.tokens == 0 end)
			check(p.id .. ": saiu do treino e liberou a arena", saiu)
			assert(saiu, "arena não foi liberada")
		end
	end)
	if not ok then check("sem erro de execução: " .. tostring(erro), false) end
	table.insert(R.linhas, string.format("A9 personagens: %d falha(s)", R.falhas))
	R.pronto = true
	conexao:Disconnect()
end)
return "iniciado"
