-- Mantém os avatares dos participantes sobre as coordenadas confirmadas pelo
-- servidor durante J2 e devolve controles/posição ao limpar o encontro.
local Geometria = require(script.Parent.EncontroAutonomoGeometria)
local EncontroAutonomoAvatares = {}

local ALTURA_RAIZ = 3

local function salvarEstado(character)
	local humanoide = character:FindFirstChildOfClass("Humanoid")
	local raiz = character:FindFirstChild("HumanoidRootPart")
	if not humanoide or humanoide.Health <= 0 or not raiz or not raiz:IsA("BasePart") then
		return nil
	end
	return {
		character = character,
		pivot = character:GetPivot(),
		raiz = raiz,
		cframeRaiz = raiz.CFrame,
		ancorada = raiz.Anchored,
		humanoide = humanoide,
		walkSpeed = humanoide.WalkSpeed,
		jumpPower = humanoide.JumpPower,
		jumpHeight = humanoide.JumpHeight,
		autoRotate = humanoide.AutoRotate,
	}
end

local function restaurar(registro)
	if not registro then return end
	local character = registro.character
	if not character or character.Parent == nil then return end
	local humanoide = character:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.WalkSpeed = registro.walkSpeed
		humanoide.JumpPower = registro.jumpPower
		humanoide.JumpHeight = registro.jumpHeight
		humanoide.AutoRotate = registro.autoRotate
	end
	-- O root pode estar temporariamente fora do Model durante um respawn. Ainda
	-- devolvemos o humanoide e restauramos a peça salva para que reapareça livre.
	local raiz = registro.raiz
	if not raiz or not raiz:IsA("BasePart") then return end
	raiz.Anchored = registro.ancorada
	if raiz:IsDescendantOf(character) then
		character:PivotTo(registro.pivot)
	else
		raiz.CFrame = registro.cframeRaiz
	end
end

function EncontroAutonomoAvatares.start(deps)
	deps = deps or {}
	local workspaceAtual = deps.workspace or workspace
	local localizarJogador = deps.localizarJogador or function(userId)
		return game:GetService("Players"):GetPlayerByUserId(userId)
	end
	local encontros = {}
	local api = {}

	local function centroDoMapa(areaId)
		local id = areaId or "region/encounter/clearing"
		for _, item in ipairs(workspaceAtual:GetDescendants()) do
			if item:IsA("BasePart") and item:GetAttribute("AreaRole") == "encounter-trigger"
				and item:GetAttribute("EncounterId") == id
			then return Geometria.centro(item) end
		end
		return nil
	end

	function api.sincronizar(encounterId, atores, phase, areaId)
		if type(encounterId) ~= "string" or #encounterId == 0 or #encounterId > 96
			or type(atores) ~= "table" or #atores > 16
		then return false end
		local centro = centroDoMapa(areaId)
		if not centro then return false end
		local registros = encontros[encounterId]
		if not registros then registros = {}; encontros[encounterId] = registros end
		if phase ~= "active" then return true end

		for _, ator in ipairs(atores) do
			if type(ator) ~= "table" or ator.kind ~= "jogador"
				or type(ator.userId) ~= "number" or ator.userId % 1 ~= 0
				or type(ator.x) ~= "number" or ator.x % 1 ~= 0 or ator.x < 1 or ator.x > 20
				or type(ator.z) ~= "number" or ator.z % 1 ~= 0 or ator.z < 1 or ator.z > 20
			then continue end
			local player = localizarJogador(ator.userId)
			local character = player and player.Character
			if not character then continue end
			local registro = registros[ator.userId]
			if not registro or registro.character ~= character or registro.character.Parent == nil then
				registro = salvarEstado(character)
				if not registro then continue end
				registros[ator.userId] = registro
			end
			local humanoide = registro.humanoide
			local raiz = character:FindFirstChild("HumanoidRootPart")
			if not humanoide or humanoide.Health <= 0 or not raiz or not raiz:IsA("BasePart") then continue end
			local posicao = Geometria.posicao(centro, ator.x, ator.z)
			if not posicao then continue end
			humanoide.WalkSpeed, humanoide.JumpPower, humanoide.JumpHeight = 0, 0, 0
			humanoide.AutoRotate = false
			raiz.Anchored = true
			character:PivotTo(CFrame.new(posicao.X, ALTURA_RAIZ, posicao.Z) * registro.pivot.Rotation)
		end
		return true
	end

	function api.limpar(encounterId)
		local registros = encontros[encounterId]
		if not registros then return true end
		for _, registro in registros do restaurar(registro) end
		encontros[encounterId] = nil
		return true
	end

	return api
end

return EncontroAutonomoAvatares
