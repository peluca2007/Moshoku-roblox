-- Bot de luta da QA (cliente, via remoto Mesa). Joga até o encontro acabar ou TEMPO s: Disparo no inimigo mais
-- próximo (<=12 casas), senão anda até ele; ataque básico ao lado; encerra o turno ao acabar as Ações.
-- Abaixo de 60% dos PV, na própria vez, cura até 20 PV pelo caminho só de Studio "QALutaTeste" (ver EncontroService).
-- Devolve "fase=vitoria|derrota|ativa ... curas=N" em uma linha.
local TEMPO = @TEMPO@
local remote = game.ReplicatedStorage:WaitForChild("Mesa", 5)
if not remote then return "fase=erro sem remoto Mesa" end
local snap, resultado
local con = remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snap = d elseif k == "encontro" and type(d) == "table" then resultado = d.resultado end
end)
remote:FireServer("requestSnapshot")
local function eu()
	if not snap then return end
	for _, t in snap.tokens do if t.ownerUserId == game.Players.LocalPlayer.UserId then return t end end
end
local function alvoPerto(h)
	local m, a
	for _, t in snap.tokens do
		if t.criatura and not t.derrotado and (t.pv or 0) > 0 then
			local d = math.max(math.abs(t.x - h.x), math.abs(t.z - h.z))
			if not m or d < m then m, a = d, t end
		end
	end
	return a, m
end
local inicio, ultimoTurno, tentativas, curas = os.clock(), nil, 0, 0
while os.clock() - inicio < TEMPO and resultado == nil do
	task.wait(0.55)
	local h = eu()
	if snap and snap.combat and snap.combat.active and h and snap.combat.turnId == h.id then
		-- Atalho só de teste: cura pela API do servidor exposta apenas no Studio (EncontroService, "QALutaTeste");
		-- o "adjust" da Mesa agora é recusado na luta sem mestre e não existe atalho no jogo publicado.
		local qa = game.ReplicatedStorage:FindFirstChild("QALutaTeste")
		if qa and (h.pv or 0) < (h.pvMax or 0) * 0.6 then
			local ok, curou = pcall(function() return qa:InvokeServer("curar") end)
			if ok and curou then curas += 1 end
			task.wait(0.4)
		end
		local alvo, dist = alvoPerto(h)
		if not alvo then break end
		local habil = (dist <= 1) and "mesa/ataque-basico" or "mesa/ataque-a-distancia"
		if dist <= 12 then
			remote:FireServer("usarHabilidade", { tokenId = h.id, habilidadeId = habil, alvoId = alvo.id })
		else
			local dx = alvo.x > h.x and 1 or (alvo.x < h.x and -1 or 0)
			local dz = alvo.z > h.z and 1 or (alvo.z < h.z and -1 or 0)
			remote:FireServer("move", { id = h.id, x = h.x + dx * 3, z = h.z + dz * 3, andar = true })
		end
		task.wait(0.55)
		tentativas += 1
		if tentativas >= 3 then -- sem Ações (ou recusas): passa a vez
			tentativas = 0
			remote:FireServer("nextTurn", { expectedTurn = snap.combat.turn })
		end
	elseif snap and not (snap.combat and snap.combat.active) and resultado == nil then
		remote:FireServer("requestSnapshot")
	end
end
task.wait(1.5)
con:Disconnect()
local ativa = snap and snap.combat and snap.combat.active
return "fase=" .. tostring(resultado or (ativa and "ativa" or "encerrada")) .. " curas=" .. curas
