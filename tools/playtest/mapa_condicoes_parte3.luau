-- M4/M5, parte 3 (Client): condições, mapa e névoa sobrevivem a salvar/carregar (espaço 5).
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Mesa", 10)
local snapshot
local connection = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then
		snapshot = data
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
local function settle()
	local deadline = os.clock() + 30
	repeat
		task.wait(0.25)
	until (snapshot.campaign.status ~= "salvando" and snapshot.campaign.status ~= "carregando") or os.clock() > deadline
end

send("requestSnapshot")
send("campaignSave", { slot = 5, force = true }, 0.2)
settle()
if snapshot.campaign.status ~= "ok" then
	connection:Disconnect()
	return "RESULTADO salvamento indisponível: " .. tostring(snapshot.campaign.status)
end
task.wait(5.2)
send("tableClear")
send("paintCells", { brush = "limpar", cells = { { x = 3, z = 2 }, { x = 7, z = 7 } } })
send("fogAll", { covered = false })
check("mesa e mapa limpos antes de carregar", #snapshot.tokens == 0 and snapshot.map.terrain["3,2"] == nil)
send("campaignLoad", { slot = 5 }, 0.2)
settle()
local heroi
for _, t in snapshot.tokens do
	if t.name == "MC Heroi" then
		heroi = t
	end
end
local ids = {}
for _, c in (heroi and heroi.conditions or {}) do
	ids[c.id] = c
end
check(
	"condições voltam (Atordoado, Caído com nota, Amedrontado)",
	ids.atordoado ~= nil and ids.caido ~= nil and ids.caido.note == "levanta com 1 Ação" and ids.amedrontado ~= nil
)
check("parede e água voltam", snapshot.map.terrain["3,2"] == "parede" and snapshot.map.terrain["7,7"] == "agua")
check("névoa volta", snapshot.map.fog["6,6"] == true)

task.wait(5.2)
send("tableClear")
send("paintCells", { brush = "limpar", cells = { { x = 3, z = 2 }, { x = 7, z = 7 } } })
send("fogAll", { covered = false })
send("campaignSave", { slot = 5, force = true }, 0.2)
settle()
connection:Disconnect()
table.insert(report, 1, string.format("RESULTADO %d falha(s)", failures))
return table.concat(report, "\n")
