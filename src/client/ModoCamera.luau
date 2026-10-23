-- Escolhe o modo de câmera pelo lugar onde o personagem está: primeira pessoa
-- dentro da sala (menu, fichas, mesa) e a câmera do mundo (diagonal alta, estilo
-- Project Zomboid, em CameraMundo) fora dela (região, vila, floresta, ruínas).
-- Só apresentação local; não decide regra nem posição.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CameraMundo = require(script.Parent.CameraMundo)

local ModoCamera = {}

local MARGEM_ENTRAR = 0 -- dentro da caixa da sala
local MARGEM_SAIR = 5 -- histerese: só volta à 3ª pessoa depois de passar da porta
-- Zoom do modo Classic: só vale enquanto a câmera do mundo está pausada ou desligada.
local ZOOM_MIN, ZOOM_MAX = 6, 36

-- Ponto (x, z) em relação à caixa (centro, tamanho) com margem.
function ModoCamera.dentro(centro, tamanho, ponto, margem)
	return math.abs(ponto.X - centro.X) <= tamanho.X / 2 + margem
		and math.abs(ponto.Z - centro.Z) <= tamanho.Z / 2 + margem
end

-- Decide o modo com histerese. `estaDentro` é o estado anterior.
function ModoCamera.decidir(estaDentro, centro, tamanho, ponto)
	if estaDentro then
		return ModoCamera.dentro(centro, tamanho, ponto, MARGEM_SAIR)
	end
	return ModoCamera.dentro(centro, tamanho, ponto, MARGEM_ENTRAR)
end

local function aplicar(player, primeiraPessoa)
	-- Antes de mexer no CameraMode: ao entrar na sala a câmera do mundo devolve o controle.
	if primeiraPessoa then CameraMundo.desligar() else CameraMundo.ligar() end
	local desejado = if primeiraPessoa then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	if player.CameraMode ~= desejado then player.CameraMode = desejado end
	if not primeiraPessoa then
		player.CameraMinZoomDistance, player.CameraMaxZoomDistance = ZOOM_MIN, ZOOM_MAX
	end
end

local ligacao
local dentroAgora = false

-- ativo=false devolve o controle à câmera padrão (sessão de sala encerrada).
function ModoCamera.definir(ativo)
	local player = Players.LocalPlayer
	if ligacao then ligacao:Disconnect() ligacao = nil end
	if not ativo then
		CameraMundo.desligar(true)
		player.CameraMode = Enum.CameraMode.Classic
		return
	end
	local ultimo = 0
	ligacao = RunService.Heartbeat:Connect(function()
		local agora = os.clock()
		if agora - ultimo < 0.2 then return end
		ultimo = agora
		local sala = workspace:FindFirstChild("SalaRPG")
		local raiz = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not sala or not raiz then return end
		-- O piso marca o limite da sala; a caixa do modelo inclui peças além da porta oeste.
		local piso = sala:FindFirstChild("Piso")
		if not piso then return end
		dentroAgora = ModoCamera.decidir(dentroAgora, piso.Position, piso.Size, raiz.Position)
		aplicar(player, dentroAgora)
	end)
end

return ModoCamera
