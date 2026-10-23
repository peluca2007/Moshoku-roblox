-- A20: Nyx (Ladina), Lírio (Bardo) e Orion (Tático) no Modo Luta (cliente em Play).
-- Para cada um: escolhe, começa o Desafio nível 1, usa as cartas da árvore na
-- própria vez e procura erro interno. Reações respondidas pelo protocolo. Grava em shared.A20.
local Players = game:GetService("Players")
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local R = { linhas = {}, falhas = 0, pronto = false, logs = {} }
shared.A20 = R
local snapshot, resultado = nil, nil
remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d
	elseif k == "log" then table.insert(R.logs, d.text)
	elseif k == "encontro" then resultado = d.resultado
	elseif k == "reacao" and type(d) == "table" and not d.fechar then
		task.spawn(function() task.wait(0.2); remote:FireServer("reagir", { id = d.id, escolha = d.opcoes[1].id }) end)
	end
end)
local function check(nome, ok, det)
	table.insert(R.linhas, (if ok then "OK    " else "FALHA ") .. nome .. ((not ok and det) and (" — " .. tostring(det)) or ""))
	if not ok then R.falhas += 1 end
end
local function send(c, p, w) remote:FireServer(c, p); task.wait(w or 0.5) end
local function eu()
	for _, t in snapshot.tokens do if t.ownerUserId == Players.LocalPlayer.UserId and not t.ia then return t end end
end
local function inimigo(h)
	local melhor, d = nil, math.huge
	for _, t in snapshot.tokens do
		if t.criatura and not t.derrotado and (t.pv or 1) > 0 then
			local dist = math.max(math.abs(t.x - h.x), math.abs(t.z - h.z))
			if dist < d then melhor, d = t, dist end
		end
	end
	return melhor, d
end
local function achou(trecho) for _, l in R.logs do if string.find(l, trecho, 1, true) then return true end end return false end
local function erroInterno() return achou("Erro interno") end

local ROTEIRO = {
	{ id = "ladina", cartas = { "mesa/esconder", "ability/furtividade-e-armadilhas/Principiante/primeiro-golpe", "mesa/veneno-de-campo", "mesa/ataque-basico" }, esperado = { "esconder" }, algum = { "triplicado", "Desprevenido" } },
	{ id = "bardo", cartas = { "mesa/dissonancia", "mesa/insulto", "mesa/ataque-basico" }, esperado = { "Dissonância", "insulta" } },
	{ id = "tatico", cartas = { "mesa/apontar", "mesa/ataque-basico", "mesa/ataque-basico" }, esperado = { "aponta", "Apontado" } },
}
task.spawn(function()
	local ok, erro = pcall(function()
		send("requestSnapshot")
		for _, r in ROTEIRO do
			table.clear(R.logs); resultado = nil
			send("combatEnd", {}, 0.5)
			send("escolherPersonagem", { id = r.id }, 0.5)
			send("iniciarLuta", { nivel = 1 }, 2)
			local h = eu()
			check(r.id .. ": criado", h ~= nil)
			local vezes = 0
			local inicio = os.clock()
			while resultado == nil and os.clock() - inicio < 45 and vezes < 3 do
				task.wait(0.3)
				h = eu()
				if h and snapshot.combat.active and snapshot.combat.turnId == h.id then
					vezes += 1
					for _, carta in r.cartas do
						local alvo, dist = inimigo(h)
						if not alvo then break end
						if (carta == "mesa/ataque-basico" or carta:find("primeiro%-golpe") or carta == "mesa/veneno-de-campo") and dist > 1 then
							-- anda até 6 casas na direção do alvo
							local dx, dz = alvo.x - h.x, alvo.z - h.z
							local passo = math.min(6, dist - 1)
							local nx = h.x + (if dx == 0 then 0 else math.sign(dx) * math.min(passo, math.abs(dx) - (if math.abs(dx) >= math.abs(dz) then 1 else 0)))
							local nz = h.z + (if dz == 0 then 0 else math.sign(dz) * math.min(passo, math.abs(dz) - (if math.abs(dz) > math.abs(dx) then 1 else 0)))
							send("move", { id = h.id, x = nx, z = nz, andar = true }, 0.8)
							h = eu()
						end
						send("usarHabilidade", { tokenId = h.id, habilidadeId = carta, alvoId = alvo.id }, 0.6)
					end
					if snapshot.combat.active and snapshot.combat.turnId == h.id then
						send("nextTurn", { expectedTurn = snapshot.combat.turn }, 0.4)
					end
				end
			end
			check(r.id .. ": jogou " .. vezes .. " vez(es)", vezes >= 1)
			for _, trecho in r.esperado do
				check(r.id .. ": registro tem '" .. trecho .. "'", achou(trecho), table.concat(R.logs, " / "):sub(1, 400))
			end
			if r.algum then
				local viu = false
				for _, trecho in r.algum do if achou(trecho) then viu = true end end
				check(r.id .. ": Primeiro Golpe resolvido (acerto ou recusa por Desprevenido)", viu)
			end
			check(r.id .. ": sem erro interno", not erroInterno())
		end
		send("combatEnd", {}, 0.5)
	end)
	if not ok then check("roteiro sem erro", false, erro) end
	R.pronto = true
end)
return "A20 iniciada"
