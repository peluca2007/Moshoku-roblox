-- Decide quem é mestre. Só o servidor consulta este módulo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Coloque aqui o UserId de quem pode mestrar fora do Studio (ex.: { 123456 }).
local MESTRES: { number } = {}
-- Conta do autor conferida no Studio/Creator Hub. Mestre de servidor privado
-- não recebe automaticamente os comandos administrativos globais.
local ADMINISTRADORES = { 2287856135 }

local Roles = {}
local joinOrder: { Player } = {}
-- Por enquanto o jogo não tem mestre: todos começam no modo jogador e o ADM
-- escolhe virar mestre (/adm mestre). Guarda só quem escolheu explicitamente.
local escolhaMestre: { [any]: boolean } = {}
local mestreDaSala
function Roles.vincularSala(consulta) mestreDaSala=consulta end

-- Roteiros de teste do Studio (tools/studio_mcp.py) ligam este atributo para
-- manter o primeiro jogador como mestre. Ignorado fora do Studio.
local function padraoMestre(): boolean
	return RunService:IsStudio() and workspace:GetAttribute("MoshokuTesteMestre") == true
end

function Roles.modoJogador(player): boolean
	if mestreDaSala and not padraoMestre() then return mestreDaSala()~=player.UserId end
	local escolha = escolhaMestre[player]
	if escolha == nil then return not padraoMestre() end
	return not escolha
end

function Roles.definirModoJogador(player, ativo: boolean)
	escolhaMestre[player] = not ativo
end

local function eligible(player: Player): boolean
	if table.find(MESTRES, player.UserId) then
		return true
	end
	if game.PrivateServerOwnerId ~= 0 and game.PrivateServerOwnerId == player.UserId then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

function Roles.added(player: Player)
	if not table.find(joinOrder, player) then
		table.insert(joinOrder, player)
	end
end

function Roles.removed(player: Player)
	local index = table.find(joinOrder, player)
	if index then
		table.remove(joinOrder, index)
	end
	escolhaMestre[player] = nil
end

local function primeiroNoStudio(player): boolean
	if not RunService:IsStudio() then return false end
	for _, other in joinOrder do
		if other.Parent == Players then
			return other == player
		end
	end
	return false
end

-- Fora do modo jogador: criador/servidor privado/MESTRES, e no Studio o primeiro
-- jogador presente (testes com vários clientes locais e UserIds negativos).
function Roles.isMaster(player: Player): boolean
	if mestreDaSala and not padraoMestre() then return mestreDaSala()==player.UserId end
	if Roles.modoJogador(player) then
		return false
	end
	-- ADM listado também pode escolher mestrar (place de grupo não tem CreatorId dele).
	return eligible(player) or primeiroNoStudio(player) or table.find(ADMINISTRADORES, player.UserId) ~= nil
end

function Roles.masters(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Roles.isMaster(player) then
			table.insert(list, player)
		end
	end
	return list
end

function Roles.isAdmin(player: Player): boolean
	if table.find(ADMINISTRADORES, player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then return true end
	-- Independe do modo: o ADM continua ADM jogando como jogador.
	return RunService:IsStudio() and (eligible(player) or primeiroNoStudio(player))
end

return Roles
