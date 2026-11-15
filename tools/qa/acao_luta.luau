-- Uma ação da QA na luta (cliente, remoto Mesa), para tirar captura LOGO DEPOIS. MODO: 'disparo' ou 'golpe'.
-- Espera a vez do jogador (até 30 s). golpe: se longe, anda até perto e devolve 'moveu'; se ao lado, ataca e devolve 'golpe'.
-- disparo: dispara no mais próximo e devolve 'disparo'. Sem Ações sobrando devolve 'passou' (encerra o turno).
local MODO = "@MODO@"
local remote = game.ReplicatedStorage:WaitForChild("Mesa", 5)
if not remote then return "erro sem Mesa" end
local snap
local con = remote.OnClientEvent:Connect(function(k, d) if k == "snapshot" then snap = d end end)
remote:FireServer("requestSnapshot")
local function eu() if snap then for _, t in snap.tokens do if t.ownerUserId == game.Players.LocalPlayer.UserId then return t end end end end
local t0 = os.clock()
local saida = "esperando"
while os.clock() - t0 < 30 do
	task.wait(0.4)
	local h = eu()
	if snap and snap.combat and not snap.combat.active then saida = "fim" break end
	if snap and snap.combat and snap.combat.active and h and snap.combat.turnId == h.id then
		local alvo, dist
		for _, t in snap.tokens do
			if t.criatura and not t.derrotado and (t.pv or 0) > 0 then
				local d = math.max(math.abs(t.x - h.x), math.abs(t.z - h.z))
				if not dist or d < dist then dist, alvo = d, t end
			end
		end
		if not alvo then saida = "semalvo" break end
		if MODO == "disparo" and dist <= 12 then
			remote:FireServer("usarHabilidade", { tokenId = h.id, habilidadeId = "mesa/ataque-a-distancia", alvoId = alvo.id })
			saida = "disparo" break
		elseif MODO == "golpe" and dist <= 1 then
			remote:FireServer("usarHabilidade", { tokenId = h.id, habilidadeId = "mesa/ataque-basico", alvoId = alvo.id })
			saida = "golpe" break
		else
			local dx = alvo.x > h.x and 1 or (alvo.x < h.x and -1 or 0)
			local dz = alvo.z > h.z and 1 or (alvo.z < h.z and -1 or 0)
			local p = math.max(1, math.min(dist - 1, 3))
			remote:FireServer("move", { id = h.id, x = h.x + dx * p, z = h.z + dz * p, andar = true })
			task.wait(1.2)
			remote:FireServer("nextTurn", { expectedTurn = snap.combat.turn })
			saida = "moveu" break
		end
	end
end
con:Disconnect()
return saida
