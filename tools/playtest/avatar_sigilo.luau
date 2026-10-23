-- Avatar e sigilo (Client, mestre): ficha de jogador entra na névoa → avatar vai
-- ao bastidor; névoa revelada → volta. Confere pelo snapshot; a posição real é
-- conferida no servidor por avatar_onde.luau.
local Players = game:GetService("Players")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Mesa", 10)
local snapshot
local c = remote.OnClientEvent:Connect(function(kind, data) if kind == "snapshot" then snapshot = data end end)
local function send(command, payload, wait)
	remote:FireServer(command, payload)
	task.wait(wait or 0.4)
end
local function heroi()
	for _, t in snapshot.tokens do if t.name == "Herói Avatar" then return t end end
end
send("requestSnapshot")
send("tableClear")
send("fogAll", { covered = false })
send("createToken", { name = "Herói Avatar", kind = "jogador", pvMax = 30, x = 8, z = 8, ownerUserId = Players.LocalPlayer.UserId }, 2)
local antes = heroi().avatar
send("paintCells", { brush = "nevoa", cells = { { x = 9, z = 8 } } })
send("move", { id = heroi().id, x = 9, z = 8 }, 1)
local naNevoa = heroi().avatar
c:Disconnect()
return string.format("avatar antes=%s; na névoa=%s (esperado nil: miniatura local)", tostring(antes), tostring(naNevoa))
