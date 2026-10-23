-- Cliente real: escolha -> Treino -> ficha completa retornada pelo servidor.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local Arma = require(game.ReplicatedStorage.Shared.Regras.Arma)
local Catalogo = require(game.ReplicatedStorage.Shared.Livro.Catalogo)
local R = { pronto = false, falhas = 0, linhas = {} }
shared.A15 = R
local snapshot, detalhe, confirmacao
local connection = remote.OnClientEvent:Connect(function(k, d)
	if k == "snapshot" then snapshot = d elseif k == "fichaDetalhe" then detalhe = d
	elseif k == "escolhaPersonagem" then confirmacao = d end
end)
local function send(c, p, espera) remote:FireServer(c, p or {}); task.wait(espera or 0.4) end
local function check(nome, ok)
	table.insert(R.linhas, (if ok then "OK " else "FALHA ") .. nome)
	if not ok then R.falhas += 1 end
end
task.spawn(function()
	local ok, e = pcall(function()
		send("requestSnapshot")
		for _, caso in {
			{ "espadachim", "Espadão / Montante", "d12", false },
			{ "brutamontes", "desarmado", "d8", false },
			{ "arqueira", "Besta", "d12", true },
			{ "mago-de-fogo", nil, "d6", false },
		} do
			send("combatEnd"); send("tableClear")
			confirmacao = nil
			send("escolherPersonagem", { id = caso[1], arma = caso[2] })
			check(caso[1] .. " escolha confirmada", confirmacao and confirmacao.id == caso[1])
			send("iniciarTreino", {}, 1.5)
			local token
			for _, t in snapshot.tokens do
				if t.ownerUserId == game.Players.LocalPlayer.UserId and t.kind == "jogador" then token = t end
			end
			assert(token, "personagem não criado")
			detalhe = nil; send("fichaDetalhe", { id = token.id }, 0.6)
			assert(detalhe and detalhe.ficha2, "ficha não retornou")
			local f = detalhe.ficha2
			local a = Arma.daFicha(f, Catalogo, caso[4])
			check(caso[1] .. " dado " .. caso[3], a.dado == caso[3] and a.aviso == nil)
			if caso[2] == "desarmado" then
				local equipado = false
				for _, i in f.construction.inventory do if i.type == "arma" and i.equipped then equipado = true end end
				check("punhos sem arma equipada", not equipado and a.desarmado)
			elseif caso[1] == "arqueira" then
				local reserva = false
				for _, i in f.construction.inventory do if i.name == "Funda / Dardo" then reserva = true end end
				check("reserva preservada", reserva)
			end
		end
		local anterior = snapshot.you.personagem
		confirmacao = nil; send("escolherPersonagem", { id = "mago-de-fogo", arma = "Besta" })
		check("arma proibida nao muda escolha", snapshot.you.personagem == anterior and confirmacao == nil)
		send("combatEnd"); send("tableClear")
	end)
	if not ok then check(tostring(e), false) end
	connection:Disconnect(); R.pronto = true
end)
return "A15 iniciada"
