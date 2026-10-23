-- Teste de ponta a ponta da fatia A1 (Árvore do Fogo jogável), no datamodel
-- Client durante o Play. Age como o mestre (Studio), pelo RemoteEvent, como o
-- painel faria: personagem pronto Ignis, criaturas do bestiário, combate e as
-- seis magias do Principiante, com as recusas do servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("Mesa", 10)
local snapshot, logs, efeitos = nil, {}, {}
local conexao = remote.OnClientEvent:Connect(function(kind, data)
	if kind == "snapshot" then
		snapshot = data
	elseif kind == "log" then
		table.insert(logs, data)
	elseif kind == "efeito" then
		table.insert(efeitos, data)
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
local function lastLog(pattern)
	for i = #logs, 1, -1 do
		if string.find(logs[i].text, pattern, 1, true) then
			return logs[i]
		end
	end
	return nil
end
local function ultimo()
	return logs[#logs] and logs[#logs].text
end
local function token(nome)
	for _, t in (snapshot and snapshot.tokens or {}) do
		if string.find(t.name, nome, 1, true) then
			return t
		end
	end
	return nil
end
local function usar(hab, payload)
	payload.tokenId = token("Ignis").id
	payload.habilidadeId = "ability/fogo/Principiante/" .. hab
	send("usarHabilidade", payload, 0.5)
end

send("requestSnapshot")
send("combatEnd")
send("tableClear")
local me = Players.LocalPlayer.UserId
send("criarPremontado", { id = "mago-de-fogo", ownerUserId = me, x = 5, z = 5 })
send("criarCriatura", { creatureId = "creature/lobo-cinzento", x = 9, z = 5 })
send("criarCriatura", { creatureId = "creature/goblin-batedor", x = 5, z = 14 })
local ignis, lobo, goblin = token("Ignis"), token("Lobo"), token("Goblin")
check("Ignis criado com PV/PM do site", ignis and ignis.pvMax == 26 and ignis.manaMax == 12, ignis and (ignis.pvMax .. "/" .. ignis.manaMax))
check("Ignis tem as 6 magias do Principiante (truque + 5 compras) e os 2 ataques básicos", ignis and ignis.habilidades and #ignis.habilidades == 8, ignis and ignis.habilidades and #ignis.habilidades)
check("Lobo do bestiário com PV do Apêndice G (patamar 1, padrão: 64)", lobo and lobo.pvMax == 64, lobo and lobo.pvMax)
check("criatura marcada", lobo and lobo.criatura == true)

usar("brasa", { alvoId = lobo.id })
check("fora de combate: recusa", lastLog("Inicie o combate") ~= nil, ultimo())

send("combatStart", { entries = { { id = ignis.id, initiative = 20 }, { id = lobo.id, initiative = 10 }, { id = goblin.id, initiative = 5 } } })
check("vez do Ignis", snapshot.combat.turnId == ignis.id)

local antes = #efeitos
usar("brasa", { alvoId = lobo.id })
check("Brasa resolvida no registro", lastLog("conjura Brasa") ~= nil, ultimo())
check("recibo do efeito chegou", #efeitos == antes + 1 and efeitos[#efeitos].habilidadeId == "ability/fogo/Principiante/brasa")
check("1 Ação gasta", snapshot.jogo and snapshot.jogo.acoes and snapshot.jogo.acoes.usadas == 1)
check("Brasa não gasta PM", token("Ignis").mana == 12)
usar("brasa", { alvoId = lobo.id })
check("Brasa só uma vez por turno", lastLog("uma vez por turno") ~= nil, ultimo())

usar("bola-de-fogo", { alvoId = goblin.id })
check("Bola de Fogo: fora de alcance? goblin a 9 casas está dentro de 12", lastLog("usa Bola de Fogo") ~= nil, ultimo())
check("Bola de Fogo gasta 1 PM e 2 Ações", token("Ignis").mana == 11 and snapshot.jogo.acoes.usadas == 3)
usar("clarao", {})
check("sem Ações: recusa", lastLog("Ações insuficientes") ~= nil, ultimo())

send("nextTurn", { expectedTurn = snapshot.combat.turn })
send("nextTurn", { expectedTurn = snapshot.combat.turn })
local queimou = lastLog("queima (Em Chamas")
local goblinQueimando = false
for _, c in (token("Goblin") and token("Goblin").conditions or {}) do
	if c.id == "em-chamas" then
		goblinQueimando = true
	end
end
check("Em Chamas cobra no início do turno de quem queima (se a Bola acertou)", (not goblinQueimando and queimou == nil) or queimou ~= nil or token("Goblin") == nil)

send("nextTurn", { expectedTurn = snapshot.combat.turn })
check("rodada 2: vez do Ignis", snapshot.combat.turnId == ignis.id and snapshot.combat.round == 2)
check("Ações zeradas na vez nova", snapshot.jogo.acoes.usadas == 0)

usar("toque-escaldante", { alvoId = lobo.id })
check("Toque Escaldante: precisa estar colado", lastLog("Fora de alcance") ~= nil, ultimo())
send("move", { id = ignis.id, x = 8, z = 5 })
usar("toque-escaldante", { alvoId = lobo.id })
check("Toque Escaldante colado ao lobo", lastLog("conjura Toque Escaldante") ~= nil, ultimo())
check("Toque gasta 2 PM", token("Ignis").mana == 9)
usar("clarao", {})
check("Clarão: teste de Vigor no raio", lastLog("conjura Clarão") ~= nil and string.find(ultimo(), "CD 11", 1, true) ~= nil, ultimo())

send("nextTurn", { expectedTurn = snapshot.combat.turn })
send("nextTurn", { expectedTurn = snapshot.combat.turn })
send("nextTurn", { expectedTurn = snapshot.combat.turn })
check("rodada 3: vez do Ignis", snapshot.combat.turnId == ignis.id)
usar("muro-de-chamas", { x = 8, z = 9 })
check("Muro de Chamas erguido", lastLog("muro de fogo") ~= nil, ultimo())
check("muro no snapshot com 6 casas", snapshot.jogo.muros[1] and #snapshot.jogo.muros[1].casas == 6, snapshot.jogo.muros[1] and #snapshot.jogo.muros[1].casas)
check("Muro gasta 3 PM (12 - 1 - 2 - 1 - 3)", token("Ignis").mana == 5, token("Ignis").mana)

-- O muro sai de (8,6) a (8,11): o goblin (5,14) atravessa ao ir para (11,8)?
-- Linha de (5,14) a (11,8) cruza x=8 em z=11: casa do muro.
if token("Goblin") then
	send("move", { id = token("Goblin").id, x = 11, z = 8 })
	check("atravessar o muro queima", lastLog("atravessa o Muro de Chamas") ~= nil, ultimo())
end

-- Linha de visão: o muro bloqueia Brasa através dele.
send("move", { id = token("Ignis").id, x = 6, z = 8 })
if token("Lobo") then
	send("move", { id = token("Lobo").id, x = 10, z = 8 })
	usar("brasa", { alvoId = token("Lobo").id })
	check("muro bloqueia a visão", lastLog("Sem linha de visão") ~= nil, ultimo())
end

usar("fagulha", { x = 3, z = 8 })
check("Fagulha: 1 Ação, registro", lastLog("conjura Fagulha") ~= nil, ultimo())

-- Apagar o fogo (1 Ação, Agilidade CD 10).
local queimando = nil
for _, t in snapshot.tokens do
	for _, c in t.conditions or {} do
		if c.id == "em-chamas" then
			queimando = t
		end
	end
end
if queimando then
	send("apagarFogo", { tokenId = queimando.id })
	check("apagar o fogo: teste de Agilidade no registro", lastLog("rola no chão") ~= nil or lastLog("Aguarde a vez") ~= nil, ultimo())
end

send("combatEnd")
check("fim do combate apaga os muros", snapshot.jogo and #snapshot.jogo.muros == 0)
send("tableClear")
conexao:Disconnect()
table.insert(report, "PM final do Ignis: 4/12 esperado")
table.insert(report, string.format("RESUMO: %d falha(s); %d recibos de efeito", failures, #efeitos))
local amostra = {}
for i = math.max(1, #logs - 14), #logs do
	table.insert(amostra, "  » " .. logs[i].text)
end
return table.concat(report, "\n") .. "\nÚltimos registros:\n" .. table.concat(amostra, "\n")
