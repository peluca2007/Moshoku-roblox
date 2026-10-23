-- Cliente (execute_luau): joga o combate autônomo J2 até o fim (ou 55 s): aproxima do inimigo mais perto,
-- ataca (basic-attack) e encerra o turno. Devolve fase final, PV de todos e ouro ganho/total do snapshot.
-- Ajuste TEMPO e repita a chamada se a luta for longa. Estratégia simples; não representa um jogador bom.
local TEMPO = 55
local REINICIAR = true -- false: só devolve o jogador ao fim (útil na run: o guardião não deve recomeçar)
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local remote = RS:WaitForChild("EncontroAutonomo")
local est, log, retornou, novoInicio, encounterTerminal = nil, {}, false, false, nil
local con = remote.OnClientEvent:Connect(function(tipo, dado)
	if tipo == "estado" and type(dado) == "table" then
		if dado.phase == "victory" or dado.phase == "defeat" then encounterTerminal = dado.encounterId end
		if encounterTerminal and dado.phase == "active" and dado.encounterId ~= encounterTerminal then novoInicio = true end
		est = dado
	elseif tipo == "retornado" then retornou = true
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
local inicio, ultimo, parado = os.clock(), -1, 0
while os.clock() - inicio < TEMPO do
	if not est then task.wait(0.5) continue end
	if est.phase ~= "active" then break end
	if est.isMyTurn and est.version ~= ultimo then
		ultimo = est.version
		local eu, alvo, melhor
		for _, a in est.actors do if a.id == est.controlledActorId then eu = a end end
		for _, a in est.actors do
			if a.kind == "criatura" and (a.pv or 0) > 0 and not a.defeated then
				local d = math.max(math.abs(a.x - eu.x), math.abs(a.z - eu.z))
				if not melhor or d < melhor then melhor, alvo = d, a end
			end
		end
		if not alvo then break end
		if est.actionsRemaining <= 0 then enviar({ command = "end-turn" })
		elseif melhor <= 1 then enviar({ command = "basic-attack", targetId = alvo.id })
		else
			local dx = alvo.x > eu.x and 1 or (alvo.x < eu.x and -1 or 0)
			local dz = alvo.z > eu.z and 1 or (alvo.z < eu.z and -1 or 0)
			local passos = math.min(melhor - 1, est.movementRemaining or 3)
			enviar({ command = "move", x = eu.x + dx * passos, z = eu.z + dz * passos })
		end
	elseif est.isMyTurn then
		parado += 1
		if parado > 6 then enviar({ command = "end-turn" }) parado, ultimo = 0, -1 end
	end
	task.wait(0.6)
end
local resumo = {}
if est then for _, a in est.actors or {} do table.insert(resumo, tostring(a.name) .. " pv=" .. tostring(a.pv)) end end
local faseFinal, ouroGanho, ouroTotal, encounterFinal = est and est.phase, est and est.ouroGanho, est and est.ouroTotal, est and est.encounterId
if est and (est.phase == "victory" or est.phase == "defeat") then
	remote:FireServer({ command = "return-autonomous", encounterId = est.encounterId, requestId = HS:GenerateGUID(false) })
	task.wait(1)
	if REINICIAR then
		remote:FireServer({ command = "start-autonomous", requestId = HS:GenerateGUID(false) })
		task.wait(2)
	end
end
con:Disconnect()
return "faseFinal=" .. tostring(faseFinal) .. " ouroGanho=" .. tostring(ouroGanho) .. " ouroTotal=" .. tostring(ouroTotal)
	.. " retorno=" .. tostring(retornou) .. " novoInicio=" .. tostring(novoInicio)
	.. " encontroFinal=" .. tostring(encounterFinal) .. " | " .. table.concat(resumo, "; ") .. "\n" .. table.concat(log, "\n")
