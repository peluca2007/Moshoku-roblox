-- Conta do jogador entre runs (R6b): guarda moeda, desbloqueios, conquistas e códice (RunConta).
-- DataStore "ContasRun" no jogo publicado; memória no Studio com place não publicado. O servidor valida tudo:
-- nada aqui confia no cliente, e a moeda só entra por `registrarRun` (fim de uma run).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Servico = {}
Servico.REMOTE = "ContaJogo"
local Transacoes = require(game:GetService("ReplicatedStorage").Shared.Regras.ContaTransacoes)
local padrao

local function copiar(valor)
	if type(valor) ~= "table" then return valor end
	local r = {}
	for k, v in valor do r[k] = copiar(v) end
	return r
end

-- Armazenamento injetável (testes): { atualizar = function(chave, transformar) -> novoValor }.
local function armazenamento()
	if require(script.Parent.PersistenciaDeEstudio).memoriaAtiva() then
		local dados = {}
		return {
			atualizar = function(chave, transformar)
				local novo = transformar(copiar(dados[chave]))
				if novo ~= nil then dados[chave] = copiar(novo) end
				return copiar(dados[chave])
			end,
		}
	end
	local store = DataStoreService:GetDataStore("ContasRun")
	return { atualizar = function(chave, transformar) return store:UpdateAsync(chave, transformar) end }
end

Servico.payloadValido = Transacoes.payloadValido
Servico.criarHandler = Transacoes.criarHandler
function Servico.start(deps)
 if deps == nil and padrao then return padrao end
 local opcoes = deps and table.clone(deps) or {}
 opcoes.store = opcoes.store or armazenamento()
 local api = Transacoes.start(opcoes)
 if deps == nil then padrao = api end
 return api
end

-- Chamar uma única vez na entrada, após inicializar a run. Testes usam criarHandler.
function Servico.ligarRemote(deps)
	local players = game:GetService("Players")
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = Servico.REMOTE, game:GetService("ReplicatedStorage")
	local processar, remover = Servico.criarHandler(Servico.start(), {
		relogio = os.clock,
		entreRuns = deps.entreRuns,
		autenticado = function(player)
			return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == players
				and players:GetPlayerByUserId(player.UserId) == player
		end,
	})
	remote.OnServerEvent:Connect(function(player, pedido)
		local resultado = processar(player, pedido)
		if resultado and player.Parent == players then remote:FireClient(player, resultado) end
	end)
	players.PlayerRemoving:Connect(remover)
	return remote
end

return Servico
