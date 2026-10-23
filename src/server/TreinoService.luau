-- Modo Treino (pedido do Pedro, 09/10/2026: "arruma de uma forma que no jogo seja
-- fácil testar"). Um clique transforma a mesa num campo de treino:
-- - o personagem pronto escolhido (Ignis se ninguém escolheu) com o avatar de quem pediu;
-- - três Bonecos de Treino (não agem; "derrotados" voltam inteiros);
-- - combate já começado na vez do jogador; a vez dos bonecos passa sozinha;
-- - PM recarregado no início de cada turno do jogador;
-- - compra na árvore liberada mesmo em combate (ProgressaoService consulta).
-- Não é regra do livro: é uma bancada de teste, desligada ao limpar ou carregar
-- a mesa e ao encerrar o combate.
local Players = game:GetService("Players")
local TravaPartida = require(game:GetService("ReplicatedStorage").Shared.TravaPartida)

local TreinoService = {}

local BONECO = { nome = "Boneco de Treino", pv = 40, ca = 12, resistencia = 2 }
local CASAS_DOS_BONECOS = { { 10, 8 }, { 6, 10 }, { 14, 10 } }

-- deps: handlers, tokens, avancarVez(), mudou(), logAll(texto, tom)
function TreinoService.start(deps)
	local handlers, tokens = deps.handlers, deps.tokens
	local treino = { ativo = false, jogadorTokenId = nil :: string? }
	local fichasTreino={}
	local montagem = deps.montagem or TravaPartida.new()

	handlers.iniciarTreino = function(player, payload, master)
		if deps.combat and deps.combat.active then return "Encerre a partida atual antes de iniciar outro treino." end
		-- O treino troca a mesa inteira: o mestre, ou quem está sozinho no servidor.
		if not master and #Players:GetPlayers() > 1 then
			return "Só o mestre inicia o treino quando há outros jogadores."
		end
		local grupo=(deps.grupo and deps.grupo()) or {player}
		if #grupo == 0 then return "Escolha pelo menos um personagem." end
		for _, p in grupo do
			local erro = deps.validarPersonagem and deps.validarPersonagem(p)
			if erro then return erro end
		end
		handlers.combatEnd(player, {}, true)
		handlers.tableClear(player, {}, true)
		local entradas={};local criado
		table.clear(fichasTreino)
		for i,p in grupo do
			local x,z=if i==1 then 10 else 2+((i-2)%5)*3,if i<=6 then 15 else 18
			local falha,nova
			if deps.criarPersonagem then falha,nova=deps.criarPersonagem(player,p,x,z)
			else falha,nova=handlers.criarPremontado(player,{id=deps.personagemDe(p),ownerUserId=p.UserId,x=x,z=z},true) end
			if falha then return falha end
			criado=criado or nova;fichasTreino[nova.id]=true;tokens[nova.id].balanceamentoJogo=true
			table.insert(entradas,{id=nova.id,initiative=20-i+1})
		end
		if not criado then return "Escolha pelo menos um personagem." end
		for i, casa in CASAS_DOS_BONECOS do
			local erro, id = handlers.createToken(player, { name = BONECO.nome, kind = "npc", pvMax = BONECO.pv, manaMax = 0, x = casa[1], z = casa[2] }, true)
			if erro then
				return erro
			end
			local boneco = tokens[id]
			boneco.criatura = { ca = BONECO.ca, bonusResistencia = BONECO.resistencia, resistencias = {}, imunidades = {} }
			boneco.boneco = true
			boneco.showStats = true
			boneco.color = Color3.fromRGB(120, 112, 100)
			boneco.version += 1
			table.insert(entradas, { id = id, initiative = 10 - i })
		end
		tokens[criado.id].balanceamentoJogo = true
		treino.ativo, treino.jogadorTokenId = true, criado.id
		handlers.combatStart(player, { entries = entradas }, true)
		deps.logAll("Treino: use as habilidades na barra de baixo. Os bonecos não atacam; pratique movimento, alvos e alcance.", "sistema")
		return nil
	end

	local api = {}

	function api.ativo(): boolean
		return treino.ativo
	end

	-- Ficha do jogador dono do treino (para ele poder sair).
	function api.tokenDoJogador(): string?
		return treino.jogadorTokenId
	end

	function api.desligar()
		table.clear(fichasTreino)
		treino.ativo, treino.jogadorTokenId = false, nil
	end

	-- Início de uma vez: boneco passa sozinho; o jogador recupera os PM.
	function api.aoTrocarVez(novoId: string?)
		if not treino.ativo or not novoId then
			return
		end
		local token = tokens[novoId]
		if not token then
			return
		end
		if token.boneco then
			task.delay(0.35, function()
				if treino.ativo and tokens[novoId] == token then
					deps.avancarVez(novoId)
				end
			end)
		elseif fichasTreino[novoId] then
			-- Recursos cheios a cada turno. PT: a ficha ainda não recalcula o PT das
			-- árvores de corpo (motor J1); o treino dá 6 provisórios para testar.
			token.mana = token.manaMax
			token.ptMax = math.max(token.ptMax or 0, 6)
			token.pt = token.ptMax
			token.version += 1
		end
	end

	-- Boneco a 0 PV: cai e levanta inteiro.
	function api.reviver(token)
		task.delay(2.5, function()
			if tokens[token.id] == token then
				token.pv = token.pvMax
				token.derrotado = nil
				token.conditions = {}
				token.version += 1
				deps.mudou()
			end
		end)
	end

	handlers.iniciarTreino = montagem.proteger(handlers.iniciarTreino)
	return api
end

return TreinoService
