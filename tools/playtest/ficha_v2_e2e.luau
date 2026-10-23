-- Teste de ponta a ponta da ficha v2 (T23b), no datamodel Client durante o Play.
-- GERADO a partir deste modelo por tools/playtest/gerar_ficha_v2_e2e.py, que troca
-- o marcador pelo JSON de tools/fixtures/ficha-v2-aria.json (ficha FICTÍCIA).
-- Age como o mestre: usa o MesaState real para o envio em partes e o RemoteEvent
-- cru para os casos de recusa.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local JSON = [==[{"mesa":2,"envelopeVersion":2,"exporterVersion":"ficha-v2/1","compatibility":"master-approved-snapshot","sourceCharacterId":"char_mmfua2mi","name":"Aria","constructionComplete":true,"omissions":[],"warnings":["Contextos de ação não são exportados nesta versão; devem ser calculados pelo executor","Inventário por valor: textos e modificações declarados pelo jogador, sujeitos à aprovação","Proficiências livres são texto do jogador, não referências de perícia"],"construction":{"raceId":"race/humano","raceChosen":true,"backgroundId":"background/plebeu","backgroundChosen":true,"attributeBase":{"forca":0,"agilidade":0,"vigor":0,"intelecto":0,"espirito":0},"raceAttributeChoices":[],"racialUpgradeIds":[],"saveAdvantages":[],"startingTreeId":"tree/agua","unlockedRankIds":["rank/agua/Principiante"],"purchasedIds":["ability/agua/Principiante/bola-de-agua","talent/agua/Principiante/condutor-de-gelo"],"combinedSpellIds":[],"skillIds":[],"treeSkillChoiceIds":[],"proficiencyTexts":["Cartografia de rios"],"weaponGroupIds":[],"bonusHp":0,"bonusMp":0,"gold":0,"inventory":[{"sourceLocalId":"item_h0snz9en","name":"Cajado de salgueiro","type":"geral","equipped":false,"description":"Leve, com runas gastas."}],"overrides":{}},"calculated":{"attributes":{"forca":0,"agilidade":0,"vigor":1,"intelecto":0,"espirito":0},"maxima":{"pv":22,"pm":12,"pt":0,"pp":0},"armorClass":10,"movementMeters":9,"initiative":{"bonus":0,"advantage":false},"highestRankBonus":1,"skills":[{"skillId":"skill/atletismo","bonus":0,"trained":false},{"skillId":"skill/acrobacia","bonus":0,"trained":false},{"skillId":"skill/furtividade","bonus":0,"trained":false},{"skillId":"skill/ladinagem","bonus":0,"trained":false},{"skillId":"skill/arcanismo","bonus":0,"trained":false},{"skillId":"skill/historia","bonus":0,"trained":false},{"skillId":"skill/investigacao","bonus":0,"trained":false},{"skillId":"skill/medicina","bonus":0,"trained":false},{"skillId":"skill/natureza","bonus":0,"trained":false},{"skillId":"skill/oficios","bonus":0,"trained":false},{"skillId":"skill/religiao","bonus":0,"trained":false},{"skillId":"skill/atuacao","bonus":0,"trained":false},{"skillId":"skill/enganacao","bonus":0,"trained":false},{"skillId":"skill/intimidacao","bonus":0,"trained":false},{"skillId":"skill/intuicao","bonus":0,"trained":false},{"skillId":"skill/labia","bonus":0,"trained":false},{"skillId":"skill/lidar-com-animais","bonus":0,"trained":false},{"skillId":"skill/percepcao","bonus":0,"trained":false},{"skillId":"skill/persuasao","bonus":0,"trained":false},{"skillId":"skill/sobrevivencia","bonus":0,"trained":false}],"actionContexts":[],"paSpent":4},"session":{"current":{"pv":22,"pm":12,"pt":0,"pp":0},"conditions":[{"conditionId":"condition/apontado","stacks":1,"note":"pelo arqueiro da torre"}],"shortRests":0,"manualEffects":[]}}]==]

local remote = ReplicatedStorage:WaitForChild("Mesa", 10)
assert(remote, "RemoteEvent Mesa não apareceu")
local MesaState = require(Players.LocalPlayer.PlayerScripts:WaitForChild("Client"):WaitForChild("MesaState"))
-- O execute_luau carrega uma cópia nova do módulo (cache próprio): liga-a ao RemoteEvent.
MesaState.start()

local snapshot, logs, uploads, detalhe = nil, {}, {}, nil
local connection = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then
		snapshot = data
	elseif kind == "log" then
		table.insert(logs, data)
	elseif kind == "fichaUpload" then
		table.insert(uploads, data)
	elseif kind == "fichaDetalhe" then
		detalhe = data
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

local function propostas()
	return snapshot and snapshot.fichaPropostas or {}
end

-- Envia pelo MesaState (o mesmo caminho do painel) e espera terminar.
local function enviar(opcoes)
	local fim, falhou, texto = false, false, nil
	MesaState.enviarFichaV2(JSON, opcoes, function(t, terminou, erro)
		texto = t
		if terminou then
			fim, falhou = true, erro
		end
	end)
	local limite = os.clock() + 20
	while not fim and os.clock() < limite do
		task.wait(0.1)
	end
	task.wait(0.4)
	return fim and not falhou, texto
end

-- Envio cru de um texto qualquer, para os casos de recusa.
local function enviarCru(texto, partes)
	local pedido = "e2e" .. math.random(1, 1e6)
	partes = partes or { texto }
	send("fichaImportBegin", { requestId = pedido, byteCount = #texto, partCount = #partes })
	local uploadId
	for _, u in uploads do
		if u.requestId == pedido then
			uploadId = u.uploadId
		end
	end
	return uploadId, partes
end

-- Mesa limpa.
send("requestSnapshot")
check("jogador local é mestre (Studio)", snapshot and snapshot.you.master == true)
send("tableClear")
check("mesa limpa", snapshot and #snapshot.tokens == 0)
check("detecta o código v2", MesaState.ehFichaV2(JSON))

-- 1. Criar: proposta primeiro, nada na mesa.
local ok, texto = enviar({ ownerUserId = Players.LocalPlayer.UserId, x = 3, z = 3 })
check("envio em partes concluído", ok, texto)
local p = propostas()[1]
check("proposta aparece só para o mestre", p ~= nil and p.name == "Aria", p and p.name)
check("resumo com os números do site", p and p.resumo.pv == 22 and p.resumo.pm == 12 and p.resumo.compras == 2, p and HttpService:JSONEncode(p.resumo))
check("nada criado antes da aprovação", token("Aria") == nil)

-- 2. Aprovar.
send("fichaImportApply", { proposalId = p.id, version = p.version }, 0.8)
local aria = token("Aria")
check("ficha criada ao aprovar", aria ~= nil)
check("na casa pedida", aria and aria.x == 3 and aria.z == 3, aria and (aria.x .. "," .. aria.z))
check("PV e mana da sessão do site", aria and aria.pv == 22 and aria.pvMax == 22 and aria.manaMax == 12)
check("atributos para a iniciativa", aria and aria.sheet and aria.sheet.iniciativa ~= nil)
check("condição do site com nota", aria and aria.conditions and aria.conditions[1] and aria.conditions[1].id == "apontado" and aria.conditions[1].note ~= nil)
check("ficha2Versao no snapshot", aria and aria.ficha2Versao ~= nil)
check("proposta consumida", #propostas() == 0)

-- 3. Ficha completa sob demanda.
send("fichaDetalhe", { id = aria.id }, 0.5)
check("detalhe recebido", detalhe and detalhe.id == aria.id and detalhe.ficha2 ~= nil)
check("detalhe tem compras do catálogo", detalhe and detalhe.ficha2 and #detalhe.ficha2.construction.purchasedIds == 2)
check("detalhe sem cabeçalho de transporte", detalhe and detalhe.ficha2 and detalhe.ficha2.mesa == nil)

-- 4. Atualizar preservando a sessão da mesa.
send("adjust", { id = aria.id, field = "pv", delta = -5 })
ok = enviar({ targetId = aria.id, sessionPolicy = "preserve" })
p = propostas()[1]
check("proposta de atualização", ok and p and p.targetId == aria.id and p.sessionPolicy == "preserve")
send("fichaImportApply", { proposalId = p.id, version = p.version }, 0.8)
check("preserve mantém o PV da mesa", token("Aria") and token("Aria").pv == 17, token("Aria") and token("Aria").pv)

-- 5. Atualizar substituindo a sessão.
ok = enviar({ targetId = aria.id, sessionPolicy = "replace" })
p = propostas()[1]
send("fichaImportApply", { proposalId = p.id, version = p.version }, 0.8)
check("replace usa o PV do site", token("Aria") and token("Aria").pv == 22, token("Aria") and token("Aria").pv)

-- 6. Ficha mudou durante a aprovação: recusa.
ok = enviar({ targetId = aria.id })
p = propostas()[1]
send("adjust", { id = aria.id, field = "pv", delta = -1 })
send("fichaImportApply", { proposalId = p.id, version = p.version }, 0.8)
check("aprovação recusada se a ficha mudou", lastLog("A ficha mudou desde a proposta") ~= nil)
check("proposta vencida sai da lista", #propostas() == 0)

-- 7. Recusar.
ok = enviar({ x = 5, z = 5 })
p = propostas()[1]
send("fichaImportReject", { proposalId = p.id })
check("recusar remove a proposta", #propostas() == 0)
check("recusar não cria ficha", #snapshot.tokens == 1)

-- 8. Recusas do servidor (envio cru).
local uploadId = enviarCru('{"mesa":2,"mesa":2}')
send("fichaImportPart", { uploadId = uploadId, index = 1, text = '{"mesa":2,"mesa":2}' })
send("fichaImportCommit", { uploadId = uploadId })
check("chave repetida recusada antes do JSONDecode", lastLog("Ficha ilegível") ~= nil, logs[#logs] and logs[#logs].text)

local alterado = string.gsub(JSON, '"gold":', '"preco":1,"gold":', 1)
uploadId = enviarCru(alterado)
send("fichaImportPart", { uploadId = uploadId, index = 1, text = alterado })
send("fichaImportCommit", { uploadId = uploadId })
check("campo desconhecido recusado", lastLog("campo desconhecido") ~= nil, logs[#logs] and logs[#logs].text)

local metade = math.floor(#JSON / 2)
local partes = { string.sub(JSON, 1, metade), string.sub(JSON, metade + 1) }
uploadId = enviarCru(JSON, partes)
send("fichaImportPart", { uploadId = uploadId, index = 2, text = partes[2] })
check("parte fora de ordem recusada", lastLog("fora de ordem") ~= nil, logs[#logs] and logs[#logs].text)
send("fichaImportAbort", { uploadId = uploadId })

-- Duas partes em ordem (o meio do JSON da Aria não corta caractere de vários bytes).
uploadId, partes = enviarCru(JSON, { string.sub(JSON, 1, metade), string.sub(JSON, metade + 1) })
local antes = #propostas()
send("fichaImportPart", { uploadId = uploadId, index = 1, text = partes[1] })
send("fichaImportPart", { uploadId = uploadId, index = 2, text = partes[2] })
send("fichaImportCommit", { uploadId = uploadId }, 0.8)
check("duas partes viram uma proposta", #propostas() == antes + 1, #propostas())
if propostas()[1] then
	send("fichaImportReject", { proposalId = propostas()[1].id })
end

send("fichaImportBegin", { byteCount = 70000, partCount = 20 })
check("tamanho acima do limite recusado", lastLog("tamanho fora do limite") ~= nil, logs[#logs] and logs[#logs].text)

-- Limpeza.
send("tableClear")
connection:Disconnect()
table.insert(report, string.format("RESUMO: %d falha(s)", failures))
return table.concat(report, "\n")
