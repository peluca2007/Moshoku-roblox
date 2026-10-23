-- M4/M5, parte 1 (Client, como mestre): condições do livro, mapa e lembretes.
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
local function token(name)
	for _, t in snapshot.tokens do
		if t.name == name then
			return t
		end
	end
end
local function cond(name, id)
	for _, c in (token(name) or {}).conditions or {} do
		if c.id == id then
			return c
		end
	end
end
local function lastLog(pattern)
	for i = #logs, 1, -1 do
		if string.find(logs[i], pattern, 1, true) then
			return logs[i]
		end
	end
end

send("requestSnapshot")
send("tableClear")
send("fogAll", { covered = false })
send("paintCells", { brush = "limpar", cells = { { x = 3, z = 2 }, { x = 7, z = 7 } } })
send("createToken", { name = "MC Heroi", kind = "jogador", pvMax = 30, x = 2, z = 2 })
send("createToken", { name = "MC Inimigo", kind = "npc", pvMax = 20, x = 6, z = 6 })
local heroi = token("MC Heroi").id

send("conditionAdd", { id = heroi, condition = "dose" })
send("conditionAdd", { id = heroi, condition = "dose" })
check("Dose acumula (2)", cond("MC Heroi", "dose") and cond("MC Heroi", "dose").stacks == 2)
send("conditionAdd", { id = heroi, condition = "dose" })
check("3ª Dose vira Atordoado (Colapso)", cond("MC Heroi", "dose") == nil and cond("MC Heroi", "atordoado") ~= nil)
check("registro explica a transformação", lastLog("virou Atordoado") ~= nil, logs[#logs])
send("conditionAdd", { id = heroi, condition = "quebrantado", stacks = 20 })
local q = cond("MC Heroi", "quebrantado")
check("Quebrantado para no teto do site (12)", q and q.stacks == 12, q and q.stacks)
send("conditionRemove", { id = heroi, condition = "quebrantado", stacks = 5 })
q = cond("MC Heroi", "quebrantado")
check("remove acúmulos (12 - 5 = 7)", q and q.stacks == 7, q and q.stacks)
send("conditionRemove", { id = heroi, condition = "quebrantado" })
check("remove a condição inteira", cond("MC Heroi", "quebrantado") == nil)
send("conditionAdd", { id = heroi, condition = "inventada" })
check("recusa condição fora do livro", lastLog("Condição desconhecida") ~= nil)
send("conditionAdd", { id = heroi, condition = "caido", note = "levanta com 1 Ação" }, 0.8)
local caido = cond("MC Heroi", "caido")
check("nota na condição (mestre vê)", caido and caido.note == "levanta com 1 Ação", caido and caido.note)

send("paintCells", { brush = "parede", cells = { { x = 3, z = 2 } } })
check("pinta parede", snapshot.map.terrain["3,2"] == "parede")
send("paintCells", { brush = "agua", cells = { { x = 7, z = 7 } } })
check("pinta água", snapshot.map.terrain["7,7"] == "agua")
send("move", { id = heroi, x = 3, z = 2 })
check("mestre pode pôr ficha na parede", token("MC Heroi").x == 3)
send("move", { id = heroi, x = 2, z = 2 })
send("createToken", { name = "MC Na Parede", kind = "npc", pvMax = 5, x = 3, z = 2 })
local naParede = token("MC Na Parede")
check("ficha criada sobre parede vai para casa livre (D-19 da revisão)", naParede and not (naParede.x == 3 and naParede.z == 2),
	naParede and (naParede.x .. "," .. naParede.z))
if naParede then
	send("removeToken", { id = naParede.id })
end
send("paintCells", { brush = "lava", cells = { { x = 1, z = 1 } } })
check("recusa pincel inválido", lastLog("Pincel inválido") ~= nil)
send("paintCells", { brush = "nevoa", cells = { { x = 6, z = 6 } } })
check("cobre casa com névoa", snapshot.map.fog["6,6"] == true)
send("fogAll", { covered = true })
local count = 0
for _ in snapshot.map.fog do
	count += 1
end
check("cobre o tabuleiro inteiro (400 casas)", count == 400, count)
send("fogAll", { covered = false })
send("paintCells", { brush = "nevoa", cells = { { x = 6, z = 6 } } })

send("combatStart", { entries = { { id = heroi, initiative = 10 } } }, 0.6)
check(
	"lembrete de condição no início do turno",
	lastLog("Lembrete — MC Heroi") ~= nil and lastLog("Atordoado (sem Ações e sem Reação") ~= nil,
	lastLog("Lembrete")
)
send("combatEnd")
connection:Disconnect()
table.insert(report, 1, string.format("RESULTADO %d falha(s)", failures))
return table.concat(report, "\n")
