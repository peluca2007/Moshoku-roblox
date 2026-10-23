-- Fechamento do servidor, parte 1: salva uma ficha no espaço 5 e a move sem
-- salvar. Ao parar o Play, o BindToClose deve gravar a posição nova.
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Mesa", 10)
local snapshot
local connection = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then
		snapshot = data
	end
end)
local function send(command, payload, wait)
	remote:FireServer(command, payload)
	task.wait(wait or 0.4)
end
send("requestSnapshot")
send("tableClear")
send("createToken", { name = "Teste Fechamento", kind = "npc", pvMax = 12, x = 2, z = 2 })
send("campaignSave", { slot = 5, force = true }, 0.2)
local deadline = os.clock() + 30
repeat
	task.wait(0.25)
until snapshot.campaign.status ~= "salvando" or os.clock() > deadline
local saved = snapshot.campaign.status
send("move", { id = snapshot.tokens[1].id, x = 15, z = 16 })
connection:Disconnect()
return string.format("salvo=%s revisão=%s; movida para 15,16 sem salvar (dirty=%s)", saved, tostring(snapshot.campaign.revision), tostring(snapshot.campaign.dirty))
