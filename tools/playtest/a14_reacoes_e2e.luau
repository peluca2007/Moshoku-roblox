-- A14: Reações ponta a ponta (cliente em Play). Isa (Deus da Água) no Modo Luta
-- só passa a vez e deixa o inimigo atacar. Confere a pergunta de Reação na tela
-- (ReacaoView), a resposta pelo protocolo e o Fluxo no registro. Grava em shared.A14.
local Players = game:GetService("Players")
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local R = { linhas = {}, falhas = 0, pronto = false, logs = {}, perguntas = 0, telaVisivel = 0, fechou = 0 }
shared.A14 = R
local snapshot, resultado = nil, nil
local pendente = nil
remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d
	elseif k == "log" then table.insert(R.logs, d.text)
	elseif k == "encontro" then resultado = d.resultado
	elseif k == "reacao" and type(d) == "table" then
		if d.fechar then R.fechou += 1 else R.perguntas += 1; pendente = d end
	end
end)
local function check(nome, ok, det)
	table.insert(R.linhas, (if ok then "OK    " else "FALHA ") .. nome .. ((not ok and det) and (" — " .. tostring(det)) or ""))
	if not ok then R.falhas += 1 end
end
local function send(cmd, p, w) remote:FireServer(cmd, p); task.wait(w or 0.4) end
local function eu()
	for _, t in snapshot.tokens do if t.ownerUserId == Players.LocalPlayer.UserId then return t end end
end
local function achouLog(trecho)
	for _, l in R.logs do if string.find(l, trecho, 1, true) then return true end end
	return false
end
task.spawn(function()
	local ok, erro = pcall(function()
		send("requestSnapshot")
		send("escolherPersonagem", { id = "duelista-da-agua" }, 0.5)
		send("iniciarLuta", {}, 1.5)
		local heroi = eu()
		check("Isa criada", heroi ~= nil and string.find(heroi.name, "Isa", 1, true) ~= nil, heroi and heroi.name)
		local inicio = os.clock()
		while resultado == nil and os.clock() - inicio < 120 and (R.perguntas < 1 or not achouLog("Fluxo")) do
			task.wait(0.2)
			if pendente then
				local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("ReacaoJogo")
				local caixa = gui and gui:FindFirstChildWhichIsA("Frame")
				if caixa and caixa.Visible then R.telaVisivel += 1 end
				local escolha = pendente.opcoes[1].id
				table.insert(R.linhas, "INFO  pergunta: " .. tostring(pendente.texto) .. " → " .. escolha)
				send("reagir", { id = pendente.id, escolha = escolha }, 0.6)
				pendente = nil
			end
			local h = eu()
			if snapshot.combat.active and h and snapshot.combat.turnId == h.id then
				send("nextTurn", { expectedTurn = snapshot.combat.turn }, 0.3)
			end
		end
		check("o servidor perguntou uma Reação", R.perguntas >= 1, R.perguntas)
		check("a pergunta apareceu na tela", R.telaVisivel >= 1, R.telaVisivel)
		check("a pergunta fechou depois da resposta", R.fechou >= 1, R.fechou)
		check("Aparar ou Guarda aparece no registro", achouLog("Aparar") or achouLog("Guarda"))
		check("Fluxo apareceu no registro", achouLog("Fluxo"))
		local falhaInterna = achouLog("Erro interno")
		check("sem erro interno", not falhaInterna)
	end)
	if not ok then check("roteiro sem erro", false, erro) end
	R.pronto = true
end)
return "A14 iniciada"
