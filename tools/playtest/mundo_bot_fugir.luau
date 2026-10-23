-- (Mundo aberto, 17/10) Cliente (execute_luau): no combate J2 do mundo tenta "Fugir pela borda" (flee-encounter, Atletismo)
-- até 6 vezes; se a fuga falhar, encerra o turno e tenta no seguinte. Devolve fase final e o resumo da fuga.
-- A fuga NÃO encerra a run (derrota encerra): serve para atravessar patrulhas fortes com a run ativa.
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local remote = RS:WaitForChild("EncontroAutonomo")
local est, log = nil, {}
local con = remote.OnClientEvent:Connect(function(tipo, dado)
	if tipo == "estado" and type(dado) == "table" then est = dado
	elseif tipo == "recusado" and type(dado) == "table" then
		table.insert(log, "recusa: " .. tostring(dado.mensagem))
		if type(dado.estado) == "table" then est = dado.estado end
	end
end)
remote:FireServer({ command = "reconnect-autonomous", requestId = HS:GenerateGUID(false) })
task.wait(2)
local function enviar(t)
	t.requestId, t.encounterId, t.expectedVersion = HS:GenerateGUID(false), est.encounterId, est.version
	remote:FireServer(t)
end
local inicio, ultimo, tentativas = os.clock(), -1, 0
while os.clock() - inicio < 50 do
	if not est then task.wait(0.5) continue end
	if est.phase ~= "active" then break end
	if est.isMyTurn and est.version ~= ultimo then
		ultimo = est.version
		local eu
		for _, a in est.actors do if a.id == est.controlledActorId then eu = a end end
		table.insert(log, string.format("eu=(%s,%s) pm=%s acoes=%s", tostring(eu and eu.x), tostring(eu and eu.z), tostring(est.movementRemaining), tostring(est.actionsRemaining)))
		if est.actionsRemaining <= 0 or tentativas >= 8 then enviar({ command = "end-turn" })
		elseif eu and (eu.z <= 1 or eu.z >= 20 or eu.x <= 1 or eu.x >= 20) then tentativas += 1 enviar({ command = "flee-encounter" })
		elseif eu then
			-- vai para a borda mais próxima (em z) e depois foge
			local alvoZ = if eu.z <= 10 then 1 else 20
			local passos = math.min(math.abs(eu.z - alvoZ), est.movementRemaining or 3)
			enviar({ command = "move", x = eu.x, z = eu.z + (if alvoZ < eu.z then -passos else passos) })
		end
	end
	task.wait(0.6)
end
con:Disconnect()
local r = est and est.fleeResult
return "fase=" .. tostring(est and est.phase) .. " tentativas=" .. tentativas .. (if r then string.format(" d20=%s total=%s cd=%s", tostring(r.natural), tostring(r.total), tostring(r.cd)) else "") .. " " .. table.concat(log, "; ")
