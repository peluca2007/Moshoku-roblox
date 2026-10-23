-- No Studio com o place ainda não publicado (GameId == 0) o DataStore não existe e a ficha pessoal
-- nunca carregaria, impedindo qualquer teste do jogo. Aqui criamos, só nesse caso, a configuração de
-- teste que PersonagemPersistencia já reconhece (memória volátil por sessão de Play). Place publicado
-- ou servidor real: nada muda, o DataStore de verdade é usado.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local PersistenciaDeEstudio = {}

PersistenciaDeEstudio.NOME = "PersonagemTestConfig"

function PersistenciaDeEstudio.deveUsarMemoria(emStudio, gameId)
	return emStudio == true and gameId == 0
end

-- Conta e run (DataStores próprios) seguem a mesma regra: memória no Studio com place não publicado OU
-- quando a IA/Pedro marcou ServerStorage.PersonagemTestConfig com Mode="memory" (place publicado aberto
-- no Studio; evita escrever em dados reais durante um playtest).
function PersistenciaDeEstudio.memoriaAtiva()
	if not RunService:IsStudio() then return false end
	if game.GameId == 0 then return true end
	local config = ServerStorage:FindFirstChild(PersistenciaDeEstudio.NOME)
	return config ~= nil and config:GetAttribute("Mode") == "memory"
end

-- `deps` (testes): { emStudio, gameId, armazenamento, novoGuid }.
function PersistenciaDeEstudio.preparar(deps)
	deps = deps or {}
	local emStudio = if deps.emStudio ~= nil then deps.emStudio else RunService:IsStudio()
	local gameId = if deps.gameId ~= nil then deps.gameId else game.GameId
	if not PersistenciaDeEstudio.deveUsarMemoria(emStudio, gameId) then return nil end
	local armazenamento = deps.armazenamento or ServerStorage
	local existente = armazenamento:FindFirstChild(PersistenciaDeEstudio.NOME)
	if existente then return existente end
	local guid = if deps.novoGuid then deps.novoGuid() else HttpService:GenerateGUID(false)
	local pasta = Instance.new("Folder")
	pasta.Name = PersistenciaDeEstudio.NOME
	pasta:SetAttribute("Scope", "test_" .. string.gsub(guid, "[^%x]", ""))
	pasta:SetAttribute("Mode", "memory")
	pasta.Parent = armazenamento
	return pasta
end

return PersistenciaDeEstudio
