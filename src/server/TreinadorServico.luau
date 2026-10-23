-- Fronteira autoritativa do treino da run; transporte e mundo separados do handler testável.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Regras = require(ReplicatedStorage.Shared.Regras.RunTreinadores)
local Servico = { REMOTE = "TreinadorJogo", INTERVALO = Regras.INTERVALO }

Servico.payloadValido = Regras.payloadValido
Servico.criarHandler = Regras.criarHandler

function Servico.start(deps)
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = Servico.REMOTE, ReplicatedStorage
	local mundo, handler, remover
 local provacoes = require(script.Parent.ProvacoesServico).start({
  remote = remote, sessao = deps.runServico.sessao, ocupado = deps.runServico.ocupado,
  transmitir = deps.runServico.transmitir, emCombate = deps.emCombate,
 })
	local function enviar(player, pedido)
		local r = handler(player, pedido)
		if r then remote:FireClient(player, r) end
	end
	local HttpService = game:GetService("HttpService")
	mundo = require(script.Parent.Mundo.Treinadores).start(function(player, npcId)
		enviar(player, { acao = "consultar", npcId = npcId, requestId = HttpService:GenerateGUID(false) })
	end)
	handler, remover = Servico.criarHandler({
		sessao = deps.runServico.sessao, ocupado = deps.runServico.ocupado,
  iniciarProvacao = provacoes.iniciar,
		transmitir = deps.runServico.transmitir, emCombate = deps.emCombate,
		autenticado = function(p) return typeof(p) == "Instance" and p:IsA("Player") and p.Parent == Players end,
		perto = function(player, sessao, npcId)
			local npc = mundo.obter(sessao, npcId)
			local raizNpc = npc and npc.corpo:FindFirstChild("HumanoidRootPart")
			local personagem = player.Character
			local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
			local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
			return raizNpc ~= nil and raiz ~= nil and humanoide ~= nil and humanoide.Health > 0
				and (raiz.Position - raizNpc.Position).Magnitude <= 10
		end,
	})
	Players.PlayerRemoving:Connect(remover)
	deps.runServico.observar(mundo.atualizar)
	remote.OnServerEvent:Connect(enviar)
	return { remote = remote, mundo = mundo }
end

return Servico
