-- Prévia 3D do personagem da criação: gira devagar, arrasta com o mouse, refaz o modelo a cada mudança.
-- Usa o mesmo rig estático e o mesmo enquadramento do editor de aparência (ModeloAparencia + T.distanciaPrevia).
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ModeloAparencia = require(script.Parent.ModeloAparencia)
local T = require(script.Parent.UI.Tema)

local Previa = {}

local FOV = 38
local ANGULO_INICIAL = 0.24
local GIRO_REPOUSO = 0.35 -- rad/s
local SENSIBILIDADE_ARRASTE = 0.012
local PEDESTAL = { altura = 0.25, diametro = 5 }
local SOMBRA = { altura = 0.03, diametro = 3.4, transparencia = 0.25 }

-- pai: GuiObject que recebe o ViewportFrame. Devolve { definir(aparencia, raceId), limpar(), ligar(bool), destruir() }.
function Previa.nova(pai)
	local v = Instance.new("ViewportFrame")
	v.Name = "Previa3D"; v.Size = UDim2.fromScale(1, 1); v.BackgroundTransparency = 1; v.Active = true
	v.Ambient = T.sobreEscuro.texto; v.LightColor = T.sobreEscuro.texto; v.LightDirection = Vector3.new(-1, -1, -1)
	v.Parent = pai
	local cam = Instance.new("Camera"); cam.FieldOfView = FOV; cam.Parent = v
	v.CurrentCamera = cam

	local angulo, arrastando = ANGULO_INICIAL, false
	local mundo, enquadre -- enquadre = { alvo, altura, largura, profundidade }
	local conexoes, ligada = {}, false

	local function posicionar()
		if not enquadre or not cam.Parent then return end
		local tam = v.AbsoluteSize
		local aspecto = if tam.Y > 0 then tam.X / tam.Y else 1
		local d = T.distanciaPrevia(enquadre.altura, enquadre.largura, enquadre.profundidade, aspecto, angulo, FOV, false)
		cam.CFrame = CFrame.lookAt(enquadre.alvo + Vector3.new(math.sin(angulo) * d, 0, -math.cos(angulo) * d), enquadre.alvo)
	end

	local function peca(nome, forma, tamanho, cframe, cor, transparencia)
		local p = Instance.new("Part")
		p.Name = nome; p.Shape = forma; p.Size = tamanho; p.CFrame = cframe; p.Color = cor; p.Anchored = true
		p.CanCollide = false; p.Material = Enum.Material.SmoothPlastic; p.Transparency = transparencia or 0
		return p
	end

	local api = {}
	local geracao = 0 -- descarta resultado de uma criação R15 que chegou depois de outra mudança
	function api.limpar()
		geracao += 1
		if mundo then mundo:Destroy() end
		mundo, enquadre = nil, nil
	end
	-- Corpo novo (R15 padrão + roupa do jogo) criado em segundo plano; o modelo anterior fica até o novo chegar.
	-- Se a criação falhar (rede/serviço), cai no rig estático de blocos.
	function api.definir(aparencia, raceId)
		geracao += 1
		local minha = geracao
		task.spawn(function()
			local ok, modelo = pcall(ModeloAparencia.criarR15, aparencia, raceId)
			if minha ~= geracao or not v.Parent then
				if ok then modelo:Destroy() end
				return
			end
			if not ok then
				warn("[CriacaoPrevia] R15 indisponível, usando blocos: " .. tostring(modelo))
				ok, modelo = pcall(ModeloAparencia.criar, aparencia, raceId)
				if not ok then warn("[CriacaoPrevia] " .. tostring(modelo)); return end
			end
			api.montar(modelo)
		end)
	end
	function api.montar(modelo)
		if mundo then mundo:Destroy() end
		mundo, enquadre = nil, nil
		mundo = Instance.new("WorldModel"); mundo.Parent = v
		modelo.Parent = mundo
		local caixa, tamanho = modelo:GetBoundingBox()
		local base = caixa.Position.Y - tamanho.Y / 2
		-- Chão simples: pedestal escuro com sombra suave sob os pés.
		peca("Pedestal", Enum.PartType.Cylinder, Vector3.new(PEDESTAL.altura, PEDESTAL.diametro, PEDESTAL.diametro),
			CFrame.new(0, base - PEDESTAL.altura / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), T.cores.fio).Parent = mundo
		peca("Sombra", Enum.PartType.Cylinder, Vector3.new(SOMBRA.altura, SOMBRA.diametro, SOMBRA.diametro),
			CFrame.new(0, base + SOMBRA.altura / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), T.cores.sombra, SOMBRA.transparencia).Parent = mundo
		enquadre = { alvo = caixa.Position, altura = tamanho.Y, largura = tamanho.X, profundidade = tamanho.Z }
		posicionar()
	end
	function api.ligar(valor)
		if valor == ligada then return end
		ligada = valor
		for _, c in conexoes do c:Disconnect() end
		table.clear(conexoes)
		arrastando = false
		if not valor then return end
		table.insert(conexoes, RunService.RenderStepped:Connect(function(dt)
			if not arrastando then angulo += dt * GIRO_REPOUSO end
			posicionar()
		end))
		table.insert(conexoes, UserInputService.InputChanged:Connect(function(entrada)
			if arrastando and entrada.UserInputType == Enum.UserInputType.MouseMovement then
				angulo += entrada.Delta.X * SENSIBILIDADE_ARRASTE
			end
		end))
		table.insert(conexoes, UserInputService.InputEnded:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.MouseButton1 then arrastando = false end
		end))
	end
	v.InputBegan:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.UserInputType == Enum.UserInputType.Touch then arrastando = true end
	end)
	v:GetPropertyChangedSignal("AbsoluteSize"):Connect(posicionar)
	function api.destruir() api.ligar(false); v:Destroy() end
	return api
end

return Previa
