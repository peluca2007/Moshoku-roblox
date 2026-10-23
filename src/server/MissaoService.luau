-- Missões pessoais da vila: o cliente só solicita aceitar/entregar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Missao = require(ReplicatedStorage.Shared.Regras.Missao)
local Dados = require(ReplicatedStorage.Shared.Mundo.MissoesDados)

local MissaoService = {}
local INTERVALO = 0.5

function MissaoService.start(deps)
	local ultima, abertas = {}, {}
	local transacoes = 0
	local relogio = deps.relogio or os.clock
	local function raizNpc()
		if deps.obterNpcRaiz then return deps.obterNpcRaiz() end
		local vila = workspace:FindFirstChild("Vila")
		local npcs = vila and vila:FindFirstChild("Npcs")
		local modelo = npcs and npcs:FindFirstChild("Dona Brisa")
		return modelo and modelo:FindFirstChild("HumanoidRootPart")
	end
	local function perto(player)
		local personagem = player and player.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		local npc = raizNpc()
		return raiz ~= nil and humanoide ~= nil and humanoide.Health > 0 and npc ~= nil
			and (raiz.Position - npc.Position).Magnitude <= 10
	end
	local function lista(perfil)
		local estado = perfil.missoes or Missao.novoEstado()
		local resultado = {}
		for _, definicao in ipairs(Dados.LISTA) do
			local progresso = estado[definicao.id]
			table.insert(resultado, {
				id = definicao.id,
				nome = definicao.nome,
				texto = definicao.texto,
				situacao = Missao.situacao(estado, definicao),
				progresso = progresso and progresso.progresso or 0,
				objetivo = definicao.objetivo.quantidade,
				recompensa = definicao.recompensa.ouro,
			})
		end
		return resultado
	end
	local function enviar(player)
		if not deps.conectado(player) or not perto(player) or deps.emCombate() then return false end
		local perfil = deps.consultar(player)
		if not perfil then return false end
		abertas[player.UserId] = true
		deps.remote:FireClient(player, "missoes", lista(perfil))
		return true
	end
	local function payloadValido(payload)
		if type(payload) ~= "table" or getmetatable(payload) ~= nil then return false end
		for chave in payload do if chave ~= "acao" and chave ~= "missaoId" then return false end end
		return true
	end
	local function registrar()
		deps.registrarHandler("missaoAcao", function(player, payload)
			if not payloadValido(payload) or type(payload.acao) ~= "string"
				or (payload.acao ~= "aceitar" and payload.acao ~= "entregar")
				or type(payload.missaoId) ~= "string" or #payload.missaoId < 1 or #payload.missaoId > 96 then
				return "Pedido de missão inválido."
			end
			if abertas[player.UserId] ~= true or not perto(player) then return "Aproxime-se de Dona Brisa para tratar das missões." end
			if deps.emCombate() then return "Missões indisponíveis durante combate." end
			local agora = relogio()
			if ultima[player.UserId] and agora - ultima[player.UserId] < INTERVALO then return "Aguarde antes de tratar outra missão." end
			ultima[player.UserId] = agora
			transacoes += 1
			local chamadaOk, sucesso, perfil, ouro = pcall(deps.acao, player, payload.acao, payload.missaoId)
			transacoes -= 1
			if not chamadaOk then return "Não foi possível salvar a missão." end
			if not sucesso then return perfil or "Ação de missão recusada." end
			enviar(player)
			if ouro and ouro > 0 then deps.avisar(player, string.format("Missão entregue: +%d PO.", ouro)) end
			return nil
		end)
	end
	registrar()
	local function abrir(player)
		return enviar(player)
	end
	local function notificarConclusoes(player, cumpridas)
		if not deps.conectado(player) then return false end
		for _, id in ipairs(cumpridas or {}) do
			local definicao = Dados.porId()[id]
			if definicao then deps.avisar(player, "Missão cumprida: " .. definicao.nome) end
		end
		return true
	end
	local function transacaoAtiva()
		return transacoes > 0
	end
	Players.PlayerRemoving:Connect(function(player) ultima[player.UserId], abertas[player.UserId] = nil, nil end)
	return table.freeze({ abrir = abrir, notificarConclusoes = notificarConclusoes, transacaoAtiva = transacaoAtiva })
end

return MissaoService
