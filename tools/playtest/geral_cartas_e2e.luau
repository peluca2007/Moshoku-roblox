-- Varredura geral (cliente em Play, Studio = mestre): para cada personagem pronto,
-- entra no Treino, cria um aliado ao lado e usa TODAS as cartas da barra num
-- alvo coerente (boneco, aliado, si mesmo ou casa). Registra recusas e erro
-- interno por carta. Grava em shared.GERAL. Parâmetro: shared.GERAL_SO = {ids}.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local remote = RS:WaitForChild("Mesa")
local Execucao = require(RS.Shared.Regras.Execucao)
local Personagens = require(RS.Shared.PersonagensProntos)
local R = { linhas = {}, falhas = 0, pronto = false, cartas = 0, recusas = 0 }
shared.GERAL = R
local snapshot, ultimos = nil, {}
remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d
	elseif k == "log" and type(d) == "table" then table.insert(ultimos, d)
	elseif k == "reacao" and type(d) == "table" and not d.fechar then
		task.spawn(function() task.wait(0.1); remote:FireServer("reagir", { id = d.id, escolha = d.opcoes[1].id }) end)
	end
end)
local function send(c, p, w) remote:FireServer(c, p or {}); task.wait(w or 0.45) end
local function linha(t) table.insert(R.linhas, t) end
local function eu()
	for _, t in snapshot.tokens do
		if t.ownerUserId == Players.LocalPlayer.UserId and t.habilidades then return t end
	end
end
local function achar(nome)
	for _, t in snapshot.tokens do if t.name == nome then return t end end
end
local function bonecos()
	local l = {}
	for _, t in snapshot.tokens do if string.find(t.name, "Boneco", 1, true) and not t.derrotado then table.insert(l, t) end end
	table.sort(l, function(a, b) return a.id < b.id end)
	return l
end
local function minhaVez(me)
	return snapshot.combat.active and snapshot.combat.turnId == me.id
end
local function esperarVez(me)
	local t0 = os.clock()
	while os.clock() - t0 < 12 do
		if minhaVez(me) then
			local j = snapshot.jogo and snapshot.jogo.acoes
			if not j or j.tokenId ~= me.id or j.usadas == 0 then return true end
			send("nextTurn", { expectedTurn = snapshot.combat.turn }, 0.5)
		end
		task.wait(0.3)
	end
	return minhaVez(me)
end
local function acoesRestantes(me)
	local j = snapshot.jogo and snapshot.jogo.acoes
	if j and j.tokenId == me.id then return j.total - j.usadas end
	return 3
end

task.spawn(function()
	local ok, erro = pcall(function()
		send("requestSnapshot")
		for _, p in Personagens do
			if shared.GERAL_SO and not table.find(shared.GERAL_SO, p.id) then continue end
			send("combatEnd", {}, 0.4)
			send("escolherPersonagem", { id = p.id }, 0.4)
			table.clear(ultimos)
			send("iniciarTreino", {}, 1.5)
			local me = eu()
			if not me then linha("FALHA " .. p.id .. ": não entrou no treino"); R.falhas += 1; continue end
			send("createToken", { name = "Aliado", kind = "jogador", pvMax = 30, ownerUserId = 0, x = me.x + 1, z = me.z }, 0.6)
			local ids = table.clone(me.habilidades)
			for _, hab in ids do
				local mec = Execucao.MECANICAS[hab]
				if Execucao.INDISPONIVEIS[hab] or not mec or mec.tipo == "formula" then continue end
				me = eu()
				if not esperarVez(me) or acoesRestantes(me) < (mec.acoes or 1) then
					send("nextTurn", { expectedTurn = snapshot.combat.turn }, 0.5); esperarVez(me)
				end
				me = eu()
				local alvo = bonecos()[1]
				local aliado = achar("Aliado")
				-- posiciona (movimento livre do mestre) ao lado do boneco, aliado ao lado
				if alvo then
					send("move", { id = me.id, x = alvo.x, z = alvo.z + 1 }, 0.35)
					if aliado then send("move", { id = aliado.id, x = alvo.x + 1, z = alvo.z + 1 }, 0.35) end
				end
				me, alvo, aliado = eu(), bonecos()[1], achar("Aliado")
				local payload = { tokenId = me.id, habilidadeId = hab }
				local forma = mec.alvo or "unico"
				if mec.tipo == "zona" or mec.alvoCasa or mec.tipo == "deslocamento" then
					payload.x, payload.z = me.x, me.z + 2
					if mec.tipo == "zona" and alvo then payload.x, payload.z = alvo.x, alvo.z + 2 end
				elseif mec.soAliados and aliado then
					payload.alvoId = aliado.id
				elseif forma == "lista" or forma == "disparos" then
					payload.alvoIds = { alvo and alvo.id }
				elseif alvo and forma ~= "si" then
					payload.alvoId = alvo.id
				end
				table.clear(ultimos)
				R.cartas += 1
				send("usarHabilidade", payload, 0.9)
				local recusa
				for _, l in ultimos do
					if l.tone == "erro" then recusa = l.text end
					if string.find(l.text or "", "Erro interno", 1, true) then R.falhas += 1; linha("FALHA " .. p.id .. " " .. hab .. ": ERRO INTERNO") end
				end
				if recusa then
					R.recusas += 1
					linha("RECUSA " .. p.id .. " " .. hab .. ": " .. recusa)
				end
			end
			linha("OK    " .. p.id .. ": " .. #ids .. " cartas na barra")
		end
		send("combatEnd", {}, 0.4)
	end)
	if not ok then linha("FALHA roteiro: " .. tostring(erro)); R.falhas += 1 end
	R.pronto = true
end)
return "varredura iniciada"
