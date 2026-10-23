-- T29: execute no Client. O wrapper injeta a ficha e escolhe a fase do teste.
-- Comandos reais de importação e campanha; não toca no armazenamento padrão.
local Players = game:GetService("Players")
local remote = game.ReplicatedStorage:WaitForChild("Mesa", 10)
local state = require(Players.LocalPlayer.PlayerScripts.Client.MesaState)
state.start() -- contexto próprio do execute_luau
local snapshot, logs = nil, {}
local connection = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then snapshot = data
	elseif kind == "log" then table.insert(logs, data.text) end
end)
local report = {}
local function check(name, ok)
	assert(ok, name .. " | último log: " .. tostring(logs[#logs]))
	table.insert(report, "OK " .. name)
end
local function send(command, payload)
	remote:FireServer(command, payload)
	task.wait(.4)
end
local function campaign(command)
	send(command, { slot = 1 })
	local untilTime = os.clock() + 35
	while snapshot and (snapshot.campaign.status == "salvando" or snapshot.campaign.status == "carregando") and os.clock() < untilTime do task.wait(.2) end
	check(command .. " conclui no DataStore", snapshot and snapshot.campaign.status == "ok" and snapshot.campaign.slot == 1)
end
local function detail(id)
	local result = state.fichaDetalhe(id)
	local untilTime = os.clock() + 8
	while not result and os.clock() < untilTime do
		task.wait(.15)
		result = state.fichaDetalhe(id)
	end
	check("detalhe completo recebido", result ~= nil)
	return result
end
local ok, failure = pcall(function()
	send("requestSnapshot")
	check("sessão inicia vazia", snapshot and #snapshot.tokens == 0)
	check("jogador é mestre do teste", snapshot.you.master)
	if not RESUME_ONLY then
		local done, failed = false, false
		state.enviarFichaV2(FIXTURE_JSON, { ownerUserId = Players.LocalPlayer.UserId, x = 3, z = 3 }, function(_, finished, error)
			if finished then done, failed = true, error end
		end)
		local untilTime = os.clock() + 25
		while not done and os.clock() < untilTime do task.wait(.15) end
		check("envio da ficha conclui", done and not failed)
		local proposal = snapshot.fichaPropostas[1]
		check("importação aguarda aprovação", proposal ~= nil and #snapshot.tokens == 0)
		send("fichaImportApply", { proposalId = proposal.id, version = proposal.version })
		local token = snapshot.tokens[1]
		check("importação aprovada", token and token.name == "Aria")
		send("adjust", { id = token.id, field = "pv", delta = -5 })
		send("adjust", { id = token.id, field = "mana", delta = -3 })
		send("conditionAdd", { id = token.id, condition = "caido", note = "nota da campanha" })
		send("paintCells", { brush = "nevoa", cells = { {x = 3, z = 3} } })
		campaign("campaignSave")
		check("revisão inicial gravada sem forçar", snapshot.campaign.revision == 1 and not snapshot.campaign.dirty)
		token = snapshot.tokens[1]
		local savedId, savedVersion = token.id, token.ficha2Versao
		local cached = detail(token.id)
		cached.name = "cache antigo proposital"
		task.wait(5.2)
		campaign("campaignLoad")
		token = snapshot.tokens[1]
		check("restaura mesmo id e versão local", token.id == savedId and token.ficha2Versao:match(":(%d+)$") == savedVersion:match(":(%d+)$"))
		check("geração invalida versão do detalhe", token.ficha2Versao ~= savedVersion)
		check("cache antigo foi descartado", state.fichaDetalhe(token.id) == nil)
		check("novo detalhe tem nome salvo", detail(token.id).name == "Aria")
		send("adjust", { id = token.id, field = "pv", delta = -5 })
		send("move", { id = token.id, x = 5, z = 4 })
		send("conditionRemove", { id = token.id, condition = "caido" })
		check("mudanças posteriores existem antes de carregar", snapshot.tokens[1].pv == 12 and snapshot.tokens[1].x == 5)
		task.wait(5.2)
		campaign("campaignLoad")
	else
		campaign("campaignLoad")
	end
	local token = snapshot.tokens[1]
	check("PV PM e casa recuperados", token and token.pv == 17 and token.mana == 9 and token.x == 3 and token.z == 3)
	check("dono recuperado", token.ownerUserId == Players.LocalPlayer.UserId)
	check("névoa recuperada", snapshot.map.fog["3,3"] == true)
	local ficha = detail(token.id)
	check("construção completa recuperada", #ficha.construction.purchasedIds == 2 and ficha.constructionComplete)
	check("inventário recuperado", ficha.construction.inventory[1].name == "Cajado de salgueiro")
	check("valores da sessão recuperados no detalhe", ficha.session.current.pv == 17 and ficha.session.current.pm == 9)
	local found = false
	for _, condition in ficha.session.conditions do
		if condition.conditionId == "condition/caido" and condition.note == "nota da campanha" then found = true end
	end
	check("condição e nota recuperadas", found)
	check("campanha recuperada está limpa", not snapshot.campaign.dirty)
end)
connection:Disconnect()
if not ok then error(table.concat(report, "\n") .. "\nFALHA " .. tostring(failure)) end
table.insert(report, "RESULTADO: campanha v2 ok")
return table.concat(report, "\n")
