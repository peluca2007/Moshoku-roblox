-- Teste de salvar/carregar campanha no espaço 5 (reservado a testes), no
-- datamodel Client durante o Play. Exige place publicado e "Enable Studio
-- Access to API Services"; sem isso, registra o status e para.
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Mesa", 10)
local snapshot, logs = nil, {}
local connection = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then
		snapshot = data
	else
		table.insert(logs, data.text)
	end
end)
local report, failures = {}, 0
local function check(name, condition, detail)
	if condition then
		table.insert(report, "OK    " .. name)
	else
		failures += 1
		table.insert(report, "FALHA " .. name .. (if detail then " — " .. tostring(detail) else ""))
	end
end
local function send(command, payload, wait)
	remote:FireServer(command, payload)
	task.wait(wait or 0.4)
end
local function waitStatus(timeout)
	local deadline = os.clock() + timeout
	repeat
		task.wait(0.25)
		local status = snapshot and snapshot.campaign and snapshot.campaign.status
	until (status ~= "salvando" and status ~= "carregando") or os.clock() > deadline
	return snapshot.campaign
end

send("requestSnapshot")
send("tableClear")
send("createToken", { name = "Teste Salvo", kind = "npc", pvMax = 33, x = 7, z = 7 })
send("updateToken", { id = snapshot.tokens[1].id, hidden = true })

send("campaignSave", { slot = 5, force = true }, 0.2)
local campaign = waitStatus(30)
table.insert(report, "INFO  após salvar: status=" .. tostring(campaign.status) .. " revisão=" .. tostring(campaign.revision))
if campaign.status ~= "ok" then
	table.insert(report, "INFO  último registro: " .. tostring(logs[#logs]))
	connection:Disconnect()
	table.insert(report, 1, "RESULTADO salvamento indisponível neste Studio")
	return table.concat(report, "\n")
end
check("salva no espaço 5", campaign.slot == 5 and campaign.dirty == false)

task.wait(5.2) -- intervalo mínimo entre operações de campanha
send("tableClear")
check("mesa limpa antes de carregar", #snapshot.tokens == 0)
send("campaignLoad", { slot = 5 }, 0.2)
campaign = waitStatus(30)
local restored = snapshot.tokens[1]
check("carrega o espaço 5", campaign.status == "ok" and restored ~= nil, campaign.status)
check("ficha volta com PV, casa e oculta", restored and restored.pvMax == 33 and restored.x == 7 and restored.hidden == true)

task.wait(5.2)
send("tableClear")
send("campaignSave", { slot = 5, force = true }, 0.2)
waitStatus(30)
connection:Disconnect()
table.insert(report, 1, string.format("RESULTADO %d falha(s)", failures))
return table.concat(report, "\n")
