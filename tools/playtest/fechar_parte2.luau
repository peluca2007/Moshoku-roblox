-- Fechamento do servidor, parte 2 (novo Play): carrega o espaço 5 e confere
-- que a posição gravada no fechamento voltou. Depois limpa o espaço de teste.
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
local function settle()
	local deadline = os.clock() + 30
	repeat
		task.wait(0.25)
	until (snapshot.campaign.status ~= "salvando" and snapshot.campaign.status ~= "carregando") or os.clock() > deadline
end
send("requestSnapshot")
send("campaignLoad", { slot = 5 }, 0.2)
settle()
local token = snapshot.tokens[1]
local ok = token ~= nil and token.name == "Teste Fechamento" and token.x == 15 and token.z == 16
local result = string.format("%s — carregado: %s em %s,%s (revisão %s)", if ok then "OK" else "FALHA",
	token and token.name or "nenhuma ficha", token and token.x or "?", token and token.z or "?", tostring(snapshot.campaign.revision))
task.wait(5.2)
send("tableClear")
send("campaignSave", { slot = 5, force = true }, 0.2)
settle()
connection:Disconnect()
return result
