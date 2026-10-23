-- Cena de demonstração visual (Client, como mestre): fichas, mapa, combate e
-- uma rolagem, para captura de tela. Não confere nada; só monta a cena.
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Mesa", 10)
local snapshot
local connection = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then
		snapshot = data
	end
end)
local function send(command, payload, wait)
	remote:FireServer(command, payload)
	task.wait(wait or 0.35)
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
send("importToken", { code = '{"mesa":1,"nome":"Irmão Ossório","pv":44,"pvMax":44,"mana":8,"manaMax":8,"atributos":{"forca":2,"agilidade":3,"vigor":1,"intelecto":0,"espirito":0},"ca":11,"deslocamento":9,"iniciativa":3,"vantagemIniciativa":true}', x = 8, z = 12 }, 0.6)
send("importToken", { code = '{"mesa":1,"nome":"Kade, o Capanga","pv":39,"pvMax":39,"mana":8,"manaMax":8,"atributos":{"forca":0,"agilidade":3,"vigor":2,"intelecto":0,"espirito":-1},"ca":13,"deslocamento":9,"iniciativa":3,"vantagemIniciativa":false}', x = 11, z = 12 }, 0.6)
send("createToken", { name = "Lobo Cinzento", kind = "npc", pvMax = 20, x = 10, z = 8 })
send("createToken", { name = "Lobo Sombrio", kind = "npc", pvMax = 20, x = 12, z = 7, hidden = true })
send("paintCells", { brush = "parede", cells = { { x = 6, z = 6 }, { x = 6, z = 7 }, { x = 6, z = 8 }, { x = 6, z = 9 }, { x = 7, z = 6 }, { x = 8, z = 6 } } })
send("paintCells", { brush = "agua", cells = { { x = 13, z = 11 }, { x = 14, z = 11 }, { x = 14, z = 12 }, { x = 13, z = 12 } } })
send("paintCells", { brush = "dificil", cells = { { x = 9, z = 9 }, { x = 10, z = 9 }, { x = 11, z = 9 } } })
send("paintCells", { brush = "nevoa", cells = { { x = 14, z = 5 }, { x = 15, z = 5 }, { x = 14, z = 6 }, { x = 15, z = 6 }, { x = 16, z = 5 }, { x = 16, z = 6 } } })
send("conditionAdd", { id = id("Lobo Cinzento"), condition = "caido" })
send("conditionAdd", { id = id("Kade, o Capanga"), condition = "dose" })
send("conditionAdd", { id = id("Kade, o Capanga"), condition = "dose" })
send("adjust", { id = id("Irmão Ossório"), field = "pv", delta = -15 })
send("adjust", { id = id("Lobo Cinzento"), field = "pv", delta = -14 })
send("rollInitiative", { ids = { id("Irmão Ossório"), id("Kade, o Capanga"), id("Lobo Cinzento") } }, 0.5)
send("move", { id = id("Lobo Cinzento"), x = 10, z = 10 }, 0.1)
remote:FireServer("roll", { formula = "1d20+4", mode = "vantagem" })
connection:Disconnect()
return "cena montada"
