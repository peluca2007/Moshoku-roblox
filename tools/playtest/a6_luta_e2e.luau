-- A6: Modo Luta ponta a ponta (cliente em Play). Joga sozinho com Disparo/Bola de Fogo
-- até o fim do encontro e confere IA, vitória/derrota e recuperação. Grava em shared.A6.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local R = { linhas = {}, falhas = 0, pronto = false, logs = {} }
shared.A6 = R
local snapshot, resultado = nil, nil
remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d
	elseif k == "log" then table.insert(R.logs, d.text)
	elseif k == "encontro" then resultado = d.resultado end
end)
local function check(nome, ok, det)
	table.insert(R.linhas, (if ok then "OK    " else "FALHA ") .. nome .. ((not ok and det) and (" — " .. tostring(det)) or ""))
	if not ok then R.falhas += 1 end
end
local function send(cmd, p, w) remote:FireServer(cmd, p); task.wait(w or 0.4) end
local function eu()
	for _, t in snapshot.tokens do if t.ownerUserId == game.Players.LocalPlayer.UserId then return t end end
end
local function inimigos()
	local l = {}
	for _, t in snapshot.tokens do if t.criatura and not t.derrotado and t.pv > 0 then table.insert(l, t) end end
	return l
end
local function achouLog(trecho)
	for _, l in R.logs do if string.find(l, trecho, 1, true) then return true end end
	return false
end
task.spawn(function()
	local ok, erro = pcall(function()
		send("requestSnapshot")
		send("iniciarLuta", {}, 1.5)
		local heroi = eu()
		check("herói criado", heroi ~= nil)
		check("um goblin em jogo (encontro padrão)", #inimigos() == 1, #inimigos())
		check("combate ativo", snapshot.combat.active)
		local pvInicial = heroi and heroi.pvMax
		local rodadas, maxPv = 0, 0
		local inicio = os.clock()
		while resultado == nil and os.clock() - inicio < 150 do
			task.wait(0.4)
			local h = eu()
			if snapshot.combat.active and h and snapshot.combat.turnId == h.id then
				rodadas += 1
				-- Bola de Fogo (2 Ações, 1 PM) e depois Disparo (1 Ação): usa o turno todo.
				for _, habilidade in { "ability/fogo/Principiante/bola-de-fogo", "mesa/ataque-a-distancia", "mesa/ataque-a-distancia" } do
					local alvos = inimigos()
					if #alvos == 0 then break end
					table.sort(alvos, function(a, b) return math.abs(a.x - h.x) + math.abs(a.z - h.z) < math.abs(b.x - h.x) + math.abs(b.z - h.z) end)
					send("usarHabilidade", { tokenId = h.id, habilidadeId = habilidade, alvoId = alvos[1].id }, 0.35)
				end
				if snapshot.combat.active and snapshot.combat.turnId == h.id then
					send("nextTurn", { expectedTurn = snapshot.combat.turn }, 0.3)
				end
			end
		end
		check("o encontro terminou", resultado ~= nil, "tempo esgotado")
		table.insert(R.linhas, "INFO  resultado=" .. tostring(resultado) .. " em " .. rodadas .. " turno(s) do jogador")
		check("inimigos andaram até o herói", achouLog("avança"))
		check("inimigos atacaram (acerto ou erro no registro)", achouLog("morde") or achouLog("golpeia") or achouLog("ataca"))
		task.wait(2.5)
		local h = eu()
		check("combate encerrado", not snapshot.combat.active)
		check("herói recuperado ao fim", h and h.pv == h.pvMax and h.mana == h.manaMax, h and (h.pv .. "/" .. h.pvMax))
		check("mensagem de fim no registro", achouLog("Vitória!") or achouLog("Derrota..."))
	end)
	if not ok then check("sem erro de execução: " .. tostring(erro), false) end
	table.insert(R.linhas, string.format("A6 luta: %d falha(s)", R.falhas))
	local fim = math.max(1, #R.logs - 14)
	for i = fim, #R.logs do table.insert(R.linhas, "  » " .. R.logs[i]) end
	R.pronto = true
end)
return "iniciado"
