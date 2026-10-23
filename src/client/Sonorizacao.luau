-- Apresentação local: nenhum remoto, dano ou regra. Assets sem ID ficam mudos.
local Sons = require(game:GetService("ReplicatedStorage").Shared.Sons)
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Sonorizacao = {}
local ativos = {}
local MAX_SONS = 8
local grupo = Instance.new("SoundGroup")
grupo.Name, grupo.Volume, grupo.Parent = "MoshokuEfeitos", 0.7, SoundService

function Sonorizacao.volume(valor: number?): number
	if type(valor) == "number" and valor == valor then grupo.Volume = math.clamp(valor, 0, 1) end
	return grupo.Volume
end

function Sonorizacao.tocar(chave: string?, duracao: number?): (() -> ())?
	local id = chave and Sons.ARQUIVOS[chave] and Sons.IDS[chave]
	if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then return nil end
	while #ativos >= MAX_SONS do ativos[1].parar() end
	local som = Instance.new("Sound")
	som.Name = "Efeito_" .. chave
	som.SoundId, som.Volume, som.SoundGroup = id, Sons.VOLUMES[chave] or 0.35, grupo
	som.Parent = SoundService
	local item = { som = som }
	local terminou = false
	local function parar()
		if terminou then return end
		terminou = true
		local indice = table.find(ativos, item)
		if indice then table.remove(ativos, indice) end
		som:Destroy()
	end
	item.parar = parar
	table.insert(ativos, item)
	som.Ended:Connect(parar)
	local limite = math.clamp(duracao or 2.5, 0.1, 5)
	task.delay(math.max(0, limite - 0.12), function()
		if not terminou then TweenService:Create(som, TweenInfo.new(0.12), { Volume = 0 }):Play() end
	end)
	-- Limita cauda e limpeza inclusive se carregamento/permissão falhar.
	task.delay(limite, parar)
	som:Play()
	return parar
end

function Sonorizacao.limpar()
	while #ativos > 0 do ativos[1].parar() end
end

function Sonorizacao.estado(): number
	return #ativos
end

return Sonorizacao
