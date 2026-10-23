-- M4/M5, parte 2 (Server): permissões do jogador comum via MesaDebug (só no Studio).
local Players = game:GetService("Players")
local debug = game:GetService("ServerStorage"):WaitForChild("MesaDebug", 5)
local report, failures = {}, 0
local function check(name, condition, detail)
	if condition then
		table.insert(report, "OK    " .. name)
	else
		failures += 1
		table.insert(report, "FALHA " .. name .. (if detail then " — " .. tostring(detail) else ""))
	end
end
local master = debug:Invoke("snapshotOf", Players:GetPlayers()[1])
assert(master.you.master, "o jogador do teste precisa ser mestre")
local ids = {}
for _, t in master.tokens do
	ids[t.name] = t.id
end
debug:Invoke("setOwner", ids["MC Heroi"], 999)
local function as(command, payload)
	return debug:Invoke("commandAs", 999, command, payload)
end

assert(ids["MC Heroi"] and ids["MC Inimigo"], "fichas do teste não encontradas")
local err = as("move", { id = ids["MC Heroi"], x = 3, z = 2 })
check("jogador não entra na parede", err == "Há uma parede nessa casa.", err)
err = as("move", { id = ids["MC Heroi"], x = 2, z = 4 })
check("jogador move a própria ficha", err == nil, err)
err = as("move", { id = ids["MC Inimigo"], x = 9, z = 9 })
check("jogador não move ficha alheia (na névoa: nem a encontra)", err == "Ficha não encontrada.", err)
err = as("conditionAdd", { id = ids["MC Heroi"], condition = "amedrontado", note = "fonte: o dragão" })
check("jogador marca condição na própria ficha", err == nil, err)
err = as("conditionAdd", { id = ids["MC Inimigo"], condition = "caido" })
check("jogador não marca condição na ficha alheia", err ~= nil, err)
err = as("paintCells", { brush = "parede", cells = { { x = 1, z = 1 } } })
check("jogador não pinta o mapa", err == "Só o mestre edita o mapa.", err)
err = as("fogAll", { covered = false })
check("jogador não revela a névoa", err == "Só o mestre edita o mapa.", err)

local view = debug:Invoke("snapshotAs", 999)
local heroi, inimigo = nil, false
for _, t in view.tokens do
	if t.name == "MC Heroi" then
		heroi = t
	elseif t.name == "MC Inimigo" then
		inimigo = true
	end
end
local note
for _, c in (heroi and heroi.conditions or {}) do
	if c.id == "amedrontado" then
		note = c.note
	end
end
check("dono vê a nota da própria condição", note == "fonte: o dragão", note)
check("inimigo na névoa some para o jogador", not inimigo)
table.insert(report, 1, string.format("RESULTADO %d falha(s)", failures))
return table.concat(report, "\n")
