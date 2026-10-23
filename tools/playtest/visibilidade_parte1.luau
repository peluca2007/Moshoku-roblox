-- Visibilidade, parte 1 (Client, como mestre): monta a mesa com casos de
-- visibilidade. A parte 2 (Server) olha a mesa como um jogador comum.
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
local function id(name)
	for _, t in snapshot.tokens do
		if t.name == name then
			return t.id
		end
	end
end
send("requestSnapshot")
send("tableClear")
send("fogAll", { covered = false })
send("createToken", { name = "Vis Visivel", kind = "npc", pvMax = 10, x = 1, z = 1 })
send("createToken", { name = "Vis Oculto", kind = "npc", pvMax = 10, x = 2, z = 1, hidden = true })
send("createToken", { name = "Vis Nevoa", kind = "npc", pvMax = 10, x = 3, z = 1 })
send("createToken", { name = "Vis Dono", kind = "jogador", pvMax = 10, x = 4, z = 1 })
send("paintCells", { brush = "nevoa", cells = { { x = 3, z = 1 }, { x = 4, z = 1 } } })
send("paintCells", { brush = "parede", cells = { { x = 5, z = 5 } } })
send("conditionAdd", { id = id("Vis Visivel"), condition = "caido", note = "segredo do mestre" }, 0.8)
send("conditionAdd", { id = id("Vis Visivel"), condition = "dose" })
send("conditionAdd", { id = id("Vis Visivel"), condition = "dose" })
send("combatStart", { entries = { { id = id("Vis Oculto"), initiative = 20 }, { id = id("Vis Visivel"), initiative = 5 } } })
connection:Disconnect()
return string.format("montada: %d fichas, combate=%s", #snapshot.tokens, tostring(snapshot.combat.active))
