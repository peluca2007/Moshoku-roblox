-- Teste de ponta a ponta da mesa, executado no datamodel Client durante o Play
-- (tools/studio_mcp.py + execute_luau). Age como o mestre: envia comandos pelo
-- RemoteEvent, como o painel faria, e confere snapshots e registro do servidor.
-- Só um jogador: cenários de dois clientes (visibilidade para jogador) ficam
-- fora; ver docs/TESTES.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("Mesa", 10)
assert(remote, "RemoteEvent Mesa não apareceu")

local snapshot = nil
local logs = {}
local connection = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then
		snapshot = data
	elseif kind == "log" then
		table.insert(logs, data)
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
	task.wait(wait or 0.35)
end

local function lastLog(pattern)
	for index = #logs, 1, -1 do
		if string.find(logs[index].text, pattern, 1, true) then
			return logs[index]
		end
	end
	return nil
end

local function token(name)
	for _, t in (snapshot and snapshot.tokens or {}) do
		if t.name == name then
			return t
		end
	end
	return nil
end

-- Mesa limpa para o teste não depender de estado anterior.
send("requestSnapshot")
check("snapshot recebido", snapshot ~= nil)
check("jogador local é mestre (Studio)", snapshot and snapshot.you.master == true)
send("tableClear")
check("mesa limpa", snapshot and #snapshot.tokens == 0)

-- Criar e validar
send("createToken", { name = "Teste Lobo", kind = "npc", pvMax = 20, manaMax = 5, x = 3, z = 3 })
local lobo = token("Teste Lobo")
check("cria ficha na casa pedida", lobo and lobo.x == 3 and lobo.z == 3 and lobo.pv == 20, lobo and (lobo.x .. "," .. lobo.z))
local before = #snapshot.tokens
send("createToken", { name = "   ", kind = "npc" })
check("recusa nome vazio", #snapshot.tokens == before and lastLog("Nome inválido") ~= nil)
send("createToken", { name = "Teste Falso", pvMax = false })
check("recusa false em campo opcional (D-6 do servidor)", token("Teste Falso") == nil)

-- Movimento
send("move", { id = lobo.id, x = 5, z = 5 })
lobo = token("Teste Lobo")
check("move a ficha", lobo.x == 5 and lobo.z == 5)
check("registro informa casas e metros", lastLog("moveu 2 casa(s) (3,0 m)") ~= nil, logs[#logs] and logs[#logs].text)
send("createToken", { name = "Teste Muro", kind = "npc", pvMax = 5, x = 6, z = 6 })
send("move", { id = lobo.id, x = 6, z = 6 })
check("recusa casa ocupada", token("Teste Lobo").x == 5 and lastLog("Casa ocupada") ~= nil)
send("move", { id = lobo.id, x = 0, z = 99 })
check("recusa casa fora do tabuleiro", token("Teste Lobo").x == 5 and lastLog("Casa inválida") ~= nil)

-- PV
send("adjust", { id = lobo.id, field = "pv", delta = -5 })
check("ajusta PV", token("Teste Lobo").pv == 15)
send("adjust", { id = lobo.id, field = "pv", delta = -999 })
check("PV não fica negativo", token("Teste Lobo").pv == 0)
send("adjust", { id = lobo.id, field = "pv", delta = 999 })
check("PV não passa do máximo", token("Teste Lobo").pv == 20)

-- Dados
send("roll", { formula = "1d20+4", mode = "vantagem" }, 0.5)
check("rola com vantagem", lastLog("rolou 1d20+4 (vantagem)") ~= nil, logs[#logs] and logs[#logs].text)
send("roll", { formula = "abc" }, 0.5)
check("recusa fórmula inválida", lastLog("Fórmula inválida") ~= nil or (logs[#logs] and logs[#logs].tone == "erro"))
send("roll", { formula = "1d6" }, 0.05)
send("roll", { formula = "1d6" }, 0.5)
check("intervalo entre rolagens", lastLog("Aguarde um instante entre rolagens") ~= nil)

-- Importar ficha (código real gerado pela ferramenta a partir de Kade, o Capanga)
local kadeCode = '{"mesa":1,"nome":"Kade, o Capanga","pv":39,"pvMax":39,"mana":8,"manaMax":8,'
	.. '"atributos":{"forca":0,"agilidade":3,"vigor":2,"intelecto":0,"espirito":-1},'
	.. '"ca":13,"deslocamento":9,"iniciativa":3,"vantagemIniciativa":false}'
send("importToken", { code = kadeCode, x = 2, z = 2 }, 0.6)
local kade = token("Kade, o Capanga")
check("importa ficha do site", kade and kade.pvMax == 39 and kade.sheet and kade.sheet.ca == 13 and kade.sheet.iniciativa == 3)
send("importToken", { code = "{quebrado" })
check("recusa código ilegível", lastLog("Código de ficha ilegível") ~= nil)

-- Iniciativa e turnos
send("rollInitiative", { ids = { lobo.id, kade.id } }, 0.6)
check("rola iniciativa e inicia combate", snapshot.combat.active and #snapshot.combat.order == 2)
check("registro mostra rolagens de iniciativa", lastLog("Iniciativa de Kade, o Capanga") ~= nil)
local turn = snapshot.combat.turn
local firstId = snapshot.combat.turnId
remote:FireServer("nextTurn", { expectedTurn = turn })
remote:FireServer("nextTurn", { expectedTurn = turn })
task.wait(0.5)
check("clique duplo avança uma vez só (D-2)", snapshot.combat.turn == turn + 1 and snapshot.combat.turnId ~= firstId)

-- Ocultar e remover a ficha da vez
send("updateToken", { id = lobo.id, hidden = true })
check("mestre ainda vê ficha oculta", token("Teste Lobo") and token("Teste Lobo").hidden == true)
local current = snapshot.combat.turnId
send("removeToken", { id = current })
check("remover a ficha da vez passa a vez", snapshot.combat.turnId ~= current)
send("combatEnd")
check("encerra combate", not snapshot.combat.active)

-- Campanha: o resultado depende de place publicado e acesso às APIs no Studio.
local status = snapshot.campaign and snapshot.campaign.status
table.insert(report, "INFO  campanha: status inicial " .. tostring(status))

send("tableClear")
check("limpa a mesa no fim", #snapshot.tokens == 0)

connection:Disconnect()
table.insert(report, 1, string.format("RESULTADO %d falha(s) — jogador %s", failures, Players.LocalPlayer.Name))
return table.concat(report, "\n")
