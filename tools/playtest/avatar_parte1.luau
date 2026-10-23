-- Avatar é ficha, parte 1 (Client): cria uma ficha de jogador do próprio jogador
-- e a move; a parte 2 (Server) confere onde o avatar está.
local Players = game:GetService("Players")
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
send("createToken", { name = "Herói Avatar", kind = "jogador", pvMax = 30, x = 8, z = 8, ownerUserId = Players.LocalPlayer.UserId }, 3)
local heroi
for _, t in snapshot.tokens do
	if t.name == "Herói Avatar" then
		heroi = t
	end
end
connection:Disconnect()
return string.format("ficha=%s avatar=%s avatares=%s", tostring(heroi and heroi.id), tostring(heroi and heroi.avatar), table.concat(snapshot.avatares or {}, ","))
