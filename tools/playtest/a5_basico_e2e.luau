-- A5 ponta a ponta (cliente em Play): Modo Treino real, ataque básico pela rede,
-- recibo do servidor e gesto do corpo tocando de verdade no cliente.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local snapshot, logs, recibos = nil, {}, {}
remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d
	elseif k == "log" then table.insert(logs, d.text)
	elseif k == "efeito" then table.insert(recibos, d) end
end)
local report, falhas = {}, 0
local function check(nome, ok, det)
	if ok then table.insert(report, "OK    " .. nome) else falhas += 1; table.insert(report, "FALHA " .. nome .. (det and (" — " .. tostring(det)) or "")) end
end
local function send(cmd, p, w) remote:FireServer(cmd, p); task.wait(w or 0.5) end
local function meu()
	for _, t in snapshot.tokens do if t.ownerUserId == game.Players.LocalPlayer.UserId then return t end end
end
local function bonecos()
	local l = {}
	for _, t in snapshot.tokens do if t.name == "Boneco de Treino" then table.insert(l, t) end end
	return l
end
send("requestSnapshot")
send("iniciarTreino", {}, 1.5)
local eu = meu()
check("personagem do treino existe", eu ~= nil)
local h = eu.habilidades or {}
check("barra termina com os dois ataques básicos", h[#h] == "mesa/ataque-a-distancia" and h[#h - 1] == "mesa/ataque-basico", table.concat(h, ","))
local alvo = bonecos()[1]
local antes = alvo.pv
send("usarHabilidade", { tokenId = eu.id, habilidadeId = "mesa/ataque-a-distancia", alvoId = alvo.id }, 0.05)
local r = recibos[#recibos]
check("recibo do disparo chegou", r ~= nil and r.habilidadeId == "mesa/ataque-a-distancia")
check("recibo informa a arma", r ~= nil and type(r.arma) == "string", r and r.arma)
-- O require de teste cria outra instância dos módulos: o estado real se vê no Workspace.
local pasta = workspace:FindFirstChild("MagiasLocais")
local function fantasmas()
	local n = 0
	for _, d in (pasta and pasta:GetDescendants() or {}) do
		if d:IsA("Model") and d.Name == "Fantasma" then n += 1 end
	end
	return n
end
local personagem = game.Players.LocalPlayer.Character
local viu, escondido = 0, false
for _ = 1, 8 do
	viu = math.max(viu, fantasmas())
	escondido = escondido or personagem.Head.LocalTransparencyModifier > 0
	task.wait(0.1)
end
check("gesto do corpo tocando no cliente real", viu > 0, viu)
check("corpo real escondido só durante o gesto", escondido)
task.wait(2.2)
check("corpo volta ao fim do gesto", fantasmas() == 0 and personagem.Head.LocalTransparencyModifier == 0)
local depois
for _, t in snapshot.tokens do if t.id == alvo.id then depois = t.pv end end
table.insert(report, string.format("INFO  PV do boneco: %s → %s (depende da rolagem)", tostring(antes), tostring(depois)))
local ultima = logs[#logs] or ""
table.insert(report, "INFO  último log: " .. ultima)
table.insert(report, string.format("A5 ponta a ponta: %d falha(s)", falhas))
return table.concat(report, "\n")
