-- HUD2: retrato (cabeça e ombros) de um combatente, num ViewportFrame com um clone do corpo que já
-- está no mundo: o avatar do jogador dono da ficha ou o corpo da criatura (workspace.CorposDeCriatura).
-- Sem corpo encontrado (ainda carregando, ficha sem dono), mostra a inicial do nome; `tentar` refaz o
-- retrato quando o corpo aparece ou muda. Só apresentação; o clone não tem scripts nem Humanoid.
-- Instances: <pai> > Retrato (Frame) > Vista (ViewportFrame) | Inicial (TextLabel).
local Players = game:GetService("Players")
local T = require(script.Parent.UI.Tema)

local Retrato = {}

local FOV = 28

local function corpoDe(token): Model?
	if token.ownerUserId then
		local jogador = Players:GetPlayerByUserId(token.ownerUserId)
		local personagem = jogador and jogador.Character
		if personagem and personagem.Parent then return personagem end
		return nil
	end
	local pasta = workspace:FindFirstChild("CorposDeCriatura")
	local modelo = pasta and pasta:FindFirstChild(token.id)
	return if modelo and modelo:IsA("Model") then modelo else nil
end

local function limparClone(clone: Model)
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("Humanoid") or d:IsA("Animator") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

-- Câmera de frente para o rosto, enquadrando cabeça e ombros.
local function enquadrar(clone: Model, cam: Camera)
	local cabeca = clone:FindFirstChild("Head", true)
	local frente = Vector3.new(0, 0, 1)
	local alvo, altura
	if cabeca and cabeca:IsA("BasePart") then
		frente = cabeca.CFrame.LookVector
		altura = cabeca.Size.Y * 2.6
		alvo = cabeca.Position - Vector3.new(0, cabeca.Size.Y * 0.45, 0)
	else
		local caixa, tamanho = clone:GetBoundingBox()
		if clone.PrimaryPart then frente = clone.PrimaryPart.CFrame.LookVector end
		altura = math.max(1.5, tamanho.Y * 0.36)
		alvo = caixa.Position + Vector3.new(0, tamanho.Y * 0.5 - altura * 0.5, 0)
	end
	local distancia = altura / (2 * math.tan(math.rad(FOV / 2)))
	cam.CFrame = CFrame.lookAt(alvo + frente * distancia, alvo)
end

-- pai: GuiObject; o retrato preenche `tamanho`. Devolve { raiz, definir(token), tentar(token) }.
function Retrato.novo(pai: Instance, nome: string, tamanho: UDim2)
	local raiz = Instance.new("Frame")
	raiz.Name, raiz.Size, raiz.BackgroundColor3, raiz.BackgroundTransparency, raiz.BorderSizePixel = nome, tamanho, T.cores.fundoTela, 0.1, 0
	raiz.ClipsDescendants = true
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, 6)
	canto.Parent = raiz
	local inicial = Instance.new("TextLabel")
	inicial.Name, inicial.Size, inicial.BackgroundTransparency, inicial.Text = "Inicial", UDim2.fromScale(1, 1), 1, ""
	inicial.FontFace, inicial.TextSize, inicial.TextColor3 = T.fontes.titulo, 24, T.sobreEscuro.ouro
	inicial.Parent = raiz
	local vista = Instance.new("ViewportFrame")
	vista.Name, vista.Size, vista.BackgroundTransparency, vista.Visible = "Vista", UDim2.fromScale(1, 1), 1, false
	vista.Ambient, vista.LightColor, vista.LightDirection = Color3.fromRGB(190, 180, 160), Color3.fromRGB(255, 240, 215), Vector3.new(-0.4, -0.5, -1)
	vista.Parent = raiz
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.Parent = vista
	vista.CurrentCamera = cam
	local api = { raiz = raiz }
	local origem: Model? = nil
	local mundo: WorldModel? = nil
	local chave: string? = nil

	function api.definir(token)
		local nomeToken = token.name or "?"
		inicial.Text = string.upper(string.sub(nomeToken, 1, 1))
		if chave ~= token.id then
			chave = token.id
			origem = nil
			if mundo then mundo:Destroy(); mundo = nil end
			vista.Visible = false
		end
		api.tentar(token)
	end

	-- Refaz o clone quando o corpo mudou (respawn) ou ainda não foi montado. Barato quando nada mudou.
	function api.tentar(token): boolean
		local corpo = corpoDe(token)
		if corpo == nil then return mundo ~= nil end
		if corpo == origem and mundo then return true end
		local arquivavel = corpo.Archivable
		corpo.Archivable = true
		local ok, clone = pcall(function() return corpo:Clone() end)
		corpo.Archivable = arquivavel
		if not ok or not clone then return false end
		if mundo then mundo:Destroy() end
		limparClone(clone)
		mundo = Instance.new("WorldModel")
		mundo.Parent = vista
		clone.Parent = mundo
		local bom = pcall(enquadrar, clone, cam)
		if not bom then
			mundo:Destroy(); mundo = nil
			return false
		end
		origem = corpo
		vista.Visible = true
		return true
	end
	raiz.Parent = pai
	return api
end

return Retrato
