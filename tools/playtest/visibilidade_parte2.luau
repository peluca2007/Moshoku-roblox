-- Visibilidade, parte 2 (Server): usa ServerStorage.MesaDebug (só existe no
-- Studio) para ver a mesa como o jogador comum de UserId 999.
local Players = game:GetService("Players")
local debug = game:GetService("ServerStorage"):WaitForChild("MesaDebug", 5)
assert(debug, "MesaDebug ausente")
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
local function idOf(name)
	for _, t in master.tokens do
		if t.name == name then
			return t.id
		end
	end
end
debug:Invoke("setOwner", idOf("Vis Dono"), 999)

local view = debug:Invoke("snapshotAs", 999)
local function find(name)
	for _, t in view.tokens do
		if t.name == name then
			return t
		end
	end
end
check("jogador comum não é mestre", view.you.master == false)
check("não recebe dados de campanha", view.campaign == nil)
local visivel = find("Vis Visivel")
check("vê ficha comum", visivel ~= nil)
check("não vê PV de NPC sem 'mostrar atributos'", visivel and visivel.pv == nil and visivel.pvMax == nil)
check("não recebe campos hidden/showStats", visivel and visivel.hidden == nil and visivel.showStats == nil)
local conds = visivel and visivel.conditions or {}
check("vê as condições da ficha", #conds == 2, #conds)
local caido
for _, c in conds do
	if c.id == "caido" then
		caido = c
	end
end
check("não vê a nota do mestre na condição", caido ~= nil and caido.note == nil)
local dose
for _, c in conds do
	if c.id == "dose" then
		dose = c
	end
end
check("acúmulos de Dose chegam (2)", dose ~= nil and dose.stacks == 2, dose and dose.stacks)
check("não vê ficha oculta", find("Vis Oculto") == nil)
check("não vê ficha na névoa", find("Vis Nevoa") == nil)
local dono = find("Vis Dono")
check("dono vê a própria ficha dentro da névoa", dono ~= nil)
check("dono vê o próprio PV", dono and dono.pv == 10)
check("vê quais casas têm névoa", view.map and view.map.fog["3,1"] == true)
check("vê a parede", view.map and view.map.terrain["5,5"] == "parede")
check("vez de ficha oculta aparece como 'vez do mestre'", view.combat.masterTurn == true and view.combat.turnId == nil)
check("ordem de combate omite a ficha oculta", #view.combat.order == 1, #view.combat.order)
check("mestre vê a nota da condição", (function()
	for _, t in master.tokens do
		if t.name == "Vis Visivel" then
			for _, c in t.conditions or {} do
				if c.id == "caido" then
					return c.note == "segredo do mestre"
				end
			end
		end
	end
	return false
end)())
table.insert(report, 1, string.format("RESULTADO %d falha(s)", failures))
return table.concat(report, "\n")
