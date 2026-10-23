-- Permissão, frequência e respostas; alterações da mesa ficam em AdminCombate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Comandos = require(ReplicatedStorage.Shared.AdminComandos)
local Admin = {}

function Admin.start(deps)
	local ultimo, pedidos = {}, {}
	local agora = deps.agora or os.clock
	local remote = deps.remote or Instance.new("RemoteEvent")
	if not deps.remote then remote.Name, remote.Parent = "ComandosAdmin", ReplicatedStorage end
	local function responder(p, texto)
		remote:FireClient(p, { texto = texto })
	end
	local diversao = require(script.Parent.AdminDiversao).start({ avatarSecreto = deps.avatarSecreto })
	local limpar = diversao.limpar
	-- eu | todos | UserId | nome de usuário ou de exibição de quem está no servidor.
	local function jogadoresAlvo(p, alvo): { Player }
		if alvo == "eu" then return { p } end
		local presentes = deps.jogadores and deps.jogadores() or Players:GetPlayers()
		if alvo == "todos" then return presentes end
		local lista = {}
		for _, outro in presentes do
			if tostring(outro.UserId) == alvo or string.lower(outro.Name) == string.lower(alvo)
				or string.lower(outro.DisplayName) == string.lower(alvo) then
				table.insert(lista, outro)
				break
			end
		end
		return lista
	end
	local function divertir(p, id, alvo)
		local lista = jogadoresAlvo(p, alvo)
		if #lista == 0 then return "Jogador não encontrado. Use eu, todos, o nome ou o UserId." end
		local aplicados, ultimaFalha = 0, nil
		for _, outro in lista do
			local falha = diversao.aplicar(outro, id)
			if falha then ultimaFalha = falha else aplicados += 1 end
		end
		-- Em "todos", furtivos ficam de fora em silêncio; alvo único informa o motivo.
		if aplicados == 0 then return ultimaFalha end
		if id == "normal" then responder(p, "Efeitos de diversão removidos.")
		elseif #lista == 1 and lista[1] == p then responder(p, "Efeito " .. id .. " ativado no seu avatar por 15 s.")
		else responder(p, string.format("Efeito %s ativado em %d avatar(es) por 15 s.", id, aplicados)) end
		return nil
	end
	local function executar(p, texto)
		if not deps.isAdmin(p) then return "Apenas administradores podem usar /adm." end
		local id, erro, args = Comandos.parse(texto)
		if not id then return erro end
		local stamp = agora()
		if ultimo[p] and stamp - ultimo[p] < 1 then return "Espere um segundo entre comandos." end
		ultimo[p] = stamp
		if id ~= "ajuda" and id ~= "status" and deps.bloqueado and deps.bloqueado() then
			return "Aguarde o carregamento da campanha ou o fechamento do servidor."
		end
		if id == "ajuda" then
			local lista = {}
			for _, c in Comandos.LISTA do table.insert(lista, Comandos.uso(c) .. " — " .. c.descricao) end
			responder(p, table.concat(lista, "\n"))
		elseif id == "status" then
			local n = 0
			for _ in deps.tokens do n += 1 end
			responder(p, string.format("%s • %d fichas na mesa.", if deps.combat.active then "Partida em andamento" else "Sala livre", n))
		elseif id == "brotos" or id == "arrumar" then
			if not deps.sala then return "Sala indisponível." end
			local falha=deps.sala(p,id);if falha then return falha end
			responder(p,if id=="brotos" then "Dados do Brotos abertos para toda a sala por 15 segundos." else "Papéis recolhidos. Sala organizada.")
		elseif id == "encerrar" then
			local falha = deps.encerrar(p)
			if falha then return falha end
			responder(p, "Partida encerrada pelo administrador.")
		elseif Comandos.POR_ID[id].alvo or id == "acoes" or id == "passar" then
			local falha, mensagem = deps.combate(p, id, args)
			if falha then return falha end
			responder(p, mensagem)
		elseif id == "voltar" then
			local falha, mensagem = deps.combate(p, id, args)
			if not falha then responder(p, mensagem)
			elseif falha ~= "semFicha" then return falha
			else
			local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
			if not p.Character or not spawn then return "Entrada ou personagem indisponível." end
			p.Character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
			responder(p, "Você voltou à entrada.")
			end
		elseif id == "jogador" or id == "mestre" then
			if not deps.definirModoJogador then return "Troca de papel indisponível nesta mesa." end
			local falha=deps.definirModoJogador(p, id == "jogador");if falha then return falha end
			responder(p, if id == "jogador" then "Modo jogador: você joga como os outros. /adm mestre para mestrar." else "Modo mestre: painel de mestre liberado. /adm jogador para voltar.")
		elseif Comandos.POR_ID[id].diversao then
			local falha = divertir(p, id, args.alvo)
			if falha then return falha end
		else
			return "Comando administrativo não implementado."
		end
		-- Auditoria apenas do ID fechado, nunca do texto bruto do chat.
		if deps.auditar then deps.auditar(p, id) end
		return nil
	end
	local function receber(p, texto)
		local stamp = agora()
		if pedidos[p] and stamp - pedidos[p] < 0.25 then return end
		pedidos[p] = stamp
		local ok, erro = pcall(executar, p, texto)
		if not ok then warn("[Admin] Falha em comando administrativo"); erro = "Falha ao executar o comando." end
		if erro then responder(p, erro) end
	end
	if not deps.remote then
		remote.OnServerEvent:Connect(receber)
		local chat = Instance.new("TextChatCommand")
		chat.Name, chat.PrimaryAlias = "MoshokuAdmin", "/adm"
		chat.Parent = game:GetService("TextChatService")
		chat.Triggered:Connect(function(source, texto)
			local p = source and Players:GetPlayerByUserId(source.UserId)
			if p then receber(p, texto) end
		end)
		Players.PlayerRemoving:Connect(function(p) limpar(p); ultimo[p], pedidos[p] = nil, nil end)
	end
	return { executar = executar, limpar = limpar, diversao = diversao }
end
return Admin
