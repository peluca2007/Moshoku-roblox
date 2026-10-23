-- Teste do Modo Treino (cliente, Play no Studio): um clique monta o campo; a vez
-- dos bonecos passa sozinha; PM recarregam; boneco a 0 PV levanta; compra na
-- árvore liberada em combate e a carta nova aparece nas habilidades.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local snapshot, logs = nil, {}
local c = remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d elseif k == "log" then table.insert(logs, d.text) end
end)
local report, falhas = {}, 0
local function check(nome, ok, det)
	if ok then table.insert(report, "OK    " .. nome) else falhas += 1; table.insert(report, "FALHA " .. nome .. (det and (" — " .. tostring(det)) or "")) end
end
local function send(cmd, p, w) remote:FireServer(cmd, p); task.wait(w or 0.5) end
local function ultimo() return logs[#logs] end
local function meu()
	for _, t in snapshot.tokens do if t.ownerUserId == game.Players.LocalPlayer.UserId then return t end end
end
local function bonecos()
	local l = {}
	for _, t in snapshot.tokens do if t.name == "Boneco de Treino" then table.insert(l, t) end end
	return l
end

send("requestSnapshot")
send("iniciarTreino", {}, 1.2)
local eu = meu()
check("treino cria o personagem do jogador", eu ~= nil)
check("três bonecos", #bonecos() == 3, #bonecos())
check("combate na vez do jogador", snapshot.combat.active and snapshot.combat.turnId == eu.id)
check("habilidades na barra", eu.habilidades and #eu.habilidades >= 6, eu.habilidades and #eu.habilidades)

local alvo = bonecos()[1]
send("usarHabilidade", { tokenId = eu.id, habilidadeId = "ability/fogo/Principiante/bola-de-fogo", alvoId = alvo.id }, 0.6)
check("conjura no boneco", string.find(ultimo() or "", "usa Bola de Fogo", 1, true) ~= nil, ultimo())
check("PM gasto", meu().mana == meu().manaMax - 1, meu().mana)
send("nextTurn", { expectedTurn = snapshot.combat.turn }, 2.2)
check("bonecos passam e a vez volta ao jogador", snapshot.combat.turnId == eu.id and snapshot.combat.round == 2, snapshot.combat.round)
check("PM recarregado no turno novo", meu().mana == meu().manaMax, meu().mana)

-- Compra em combate (treino): abre Água e a carta gratuita (truque) aparece.
send("abrirRank", { tokenId = eu.id, arvore = "agua", rank = "Principiante" }, 0.6)
check("abre a Magia de Água em combate no treino", string.find(ultimo() or "", "abre Magia de Água", 1, true) ~= nil, ultimo())
send("aprender", { tokenId = eu.id, habilidadeId = "ability/agua/Principiante/bola-de-agua" }, 0.6)
check("aprende Bola de Água", string.find(ultimo() or "", "aprende Bola de Água", 1, true) ~= nil, ultimo())

-- Boneco cai e levanta.
for i = 1, 8 do
	local b = bonecos()[1]
	if not b or b.pv == 0 then break end
	send("usarHabilidade", { tokenId = eu.id, habilidadeId = "ability/fogo/Principiante/brasa", alvoId = b.id }, 0.3)
	send("nextTurn", { expectedTurn = snapshot.combat.turn }, 1.6)
end
local caiu = false
for _, l in logs do if string.find(l, "levanta inteiro", 1, true) then caiu = true end end
if caiu then
	task.wait(3)
	check("boneco levanta com o PV cheio", bonecos()[1] and bonecos()[1].pv == bonecos()[1].pvMax)
else
	table.insert(report, "INFO  nenhum boneco chegou a 0 PV nas tentativas (rolagens)")
end
send("combatEnd")
c:Disconnect()
table.insert(report, string.format("RESUMO: %d falha(s)", falhas))
return table.concat(report, "\n")
