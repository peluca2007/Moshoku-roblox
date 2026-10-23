-- Desenha as fichas recebidas no snapshot (Parts locais, nunca replicadas),
-- converte cliques/toques em casas e controla a câmera de mesa. Visual e
-- animações seguem docs/VISUAL.md; nada aqui decide regra.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Protocol = require(Shared:WaitForChild("MesaProtocol"))
local CondicaoRules = require(Shared:WaitForChild("CondicaoRules"))
local Condicoes = require(Shared:WaitForChild("Condicoes"))
local Estilo = require(Shared:WaitForChild("Estilo"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))
local Furtividade = require(Shared.VisibilidadeFurtiva)
local Enquadramento = require(Shared.EnquadramentoMesa)
local Movimento = require(script.Parent.BloqueioMovimento)

local BoardView = {}

-- Estética Livro Noite (Estilo, docs/VISUAL.md): seleção no roxo do destaque,
-- a vez no laranja do capítulo 0, PV em verde/amarelo/vermelho dos capítulos.
local SELECAO = Estilo.DESTAQUE
local VEZ = Estilo.CAPITULOS[1]
local PV_ALTO, PV_MEDIO, PV_BAIXO = Estilo.SUCESSO, Estilo.ALERTA, Estilo.PERIGO
local TINTA = Estilo.TINTA
local SOMBRA_DO_TEXTO = Estilo.SOBRE_COR
local TITULO = Estilo.GRITO
local TEXTO = Estilo.ROTULO_FORTE

local MIN_HEIGHT, MAX_HEIGHT = 35, 300
local PAN_SPEED = 60
local PAINT_BATCH = 0.15 -- segundos entre envios ao arrastar o pincel
local CAMERA_BLEND = 0.6 -- segundos da transição para a Visão da mesa

-- Aparência do mapa (M4). O mestre vê através da névoa; o jogador não.
local TERRAIN_LOOK = {
	parede = { color = Color3.fromHex("#2a2a31"), height = 3, transparency = 0, material = Enum.Material.Slate },
	dificil = { color = Estilo.misturar(Estilo.CAPITULOS[1], Estilo.PAPEL, 0.35), height = 0.12, transparency = 0.15, material = Enum.Material.SmoothPlastic },
	agua = { color = Estilo.misturar(Estilo.CAPITULOS[2], Estilo.PAPEL, 0.45), height = 0.12, transparency = 0.15, material = Enum.Material.Glass },
}
local FOG_COLOR = Estilo.MESA_FUNDO
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- cilindros do Roblox deitam no eixo X

local function ease(t: number): number
	return 1 - (1 - t) ^ 3
end

function BoardView.start(state)
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local board = Protocol.BOARD

	local folder = Instance.new("Folder")
	folder.Name = "MesaFichasLocais"
	folder.Parent = workspace

	local views: { [string]: any } = {}

	local cellMarker = Instance.new("Part")
	cellMarker.Name = "CasaSelecionada"
	cellMarker.Size = Vector3.new(board.cell - 0.4, 0.08, board.cell - 0.4)
	cellMarker.Anchored = true
	cellMarker.CanCollide = false
	cellMarker.CanQuery = false
	cellMarker.Material = Enum.Material.Neon
	cellMarker.Color = SELECAO
	cellMarker.Transparency = 0.55
	cellMarker.Parent = nil

	-- Fichas: miniaturas ---------------------------------------------------------

	local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size
		part.Color = color
		part.Material = material
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = true
		part.Parent = model
		return part
	end

	local function createView(token)
		local model = Instance.new("Model")
		model.Name = token.id
		local parts = {
			base = piece(model, "Base", Enum.PartType.Cylinder, Vector3.new(0.5, 4.2, 4.2), Estilo.PAPEL_2, Enum.Material.SmoothPlastic),
			rim = piece(model, "Aro", Enum.PartType.Cylinder, Vector3.new(0.26, 4.6, 4.6), token.color, Enum.Material.SmoothPlastic),
			body = piece(model, "Corpo", Enum.PartType.Cylinder, Vector3.new(3.2, 2.2, 2.2), token.color, Enum.Material.SmoothPlastic),
			head = piece(model, "Cabeca", Enum.PartType.Ball, Vector3.one * 2.3, token.color, Enum.Material.SmoothPlastic),
			select = piece(model, "AnelSelecao", Enum.PartType.Cylinder, Vector3.new(0.06, 5.6, 5.6), SELECAO, Enum.Material.Neon),
			turn = piece(model, "AnelVez", Enum.PartType.Cylinder, Vector3.new(0.08, 5.1, 5.1), VEZ, Enum.Material.Neon),
		}
		parts.select.CastShadow, parts.turn.CastShadow = false, false
		parts.select.Transparency, parts.turn.Transparency = 1, 1
		local offsets = {
			base = CFrame.new(0, 0.25, 0) * VERTICAL,
			rim = CFrame.new(0, 0.13, 0) * VERTICAL,
			body = CFrame.new(0, 2.1, 0) * VERTICAL,
			head = CFrame.new(0, 4.3, 0),
			select = CFrame.new(0, 0.04, 0) * VERTICAL,
			turn = CFrame.new(0, 0.06, 0) * VERTICAL,
		}
		model.PrimaryPart = parts.base

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(170, 58)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = parts.head
		billboard.Parent = model

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.TextColor3 = TINTA
		label.TextStrokeColor3 = SOMBRA_DO_TEXTO
		label.TextStrokeTransparency = 0.15
		label.FontFace = TITULO
		label.TextSize = 17
		label.Parent = billboard

		local barBack = Instance.new("Frame")
		barBack.Name = "BarraPV"
		barBack.Size = UDim2.new(0.62, 0, 0, 7)
		barBack.Position = UDim2.new(0.19, 0, 0, 25)
		barBack.BackgroundColor3 = Estilo.PAPEL_2
		barBack.BorderSizePixel = 0
		barBack.Parent = billboard
		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = barBack
		local barStroke = Instance.new("UIStroke")
		barStroke.Color = TINTA
		barStroke.Transparency = 0.6
		barStroke.Thickness = 1
		barStroke.Parent = barBack

		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = PV_ALTO
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, 1)
		bar.Parent = barBack
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = bar

		-- Condições do livro abaixo da barra de PV (M5).
		local conditions = Instance.new("TextLabel")
		conditions.Name = "Condicoes"
		conditions.Size = UDim2.new(1, 0, 0, 18)
		conditions.Position = UDim2.fromOffset(0, 36)
		conditions.BackgroundTransparency = 1
		conditions.TextColor3 = Estilo.ALERTA
		conditions.TextStrokeColor3 = SOMBRA_DO_TEXTO
		conditions.TextStrokeTransparency = 0.2
		conditions.FontFace = TEXTO
		conditions.TextSize = 14
		conditions.TextTruncate = Enum.TextTruncate.AtEnd
		conditions.Text = ""
		conditions.Parent = billboard

		model.Parent = folder
		local view = {
			model = model,
			parts = parts,
			offsets = offsets,
			label = label,
			bar = bar,
			conditions = conditions,
			cframe = CFrame.new(),
			anim = nil,
			lastPv = nil,
			hidden = false,
			seed = math.random() * 10,
		}
		views[token.id] = view
		return view, true
	end

	local function pose(view, cf: CFrame)
		for name, part in view.parts do
			part.CFrame = cf * view.offsets[name]
		end
	end

	-- O avatar é a ficha: a ficha de jogador vinculada usa o personagem do dono.
	local function rootDe(userId: number?): BasePart?
		local dono = userId and Players:GetPlayerByUserId(userId)
		local character = dono and dono.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	-- Criatura com corpo no tabuleiro (CorposDeCriatura, servidor): o corpo é a ficha.
	local function corpoRoot(id: string): BasePart?
		local pasta = workspace:FindFirstChild("CorposDeCriatura")
		local modelo = pasta and pasta:FindFirstChild(id)
		local root = modelo and modelo:IsA("Model") and modelo.PrimaryPart
		return if root and root:IsA("BasePart") then root else nil
	end

	local MINI = { "base", "rim", "body", "head" }
	local escondidos: { [Model]: boolean } = {}
	local propriedadesOcultas = setmetatable({}, { __mode = "k" })
	-- Avatar de ficha que este jogador não pode ver (oculta/na névoa): some só aqui.
	local function esconderPersonagem(character: Model, esconder: boolean)
		for _, parte in character:GetDescendants() do
			if parte:IsA("BasePart") or parte:IsA("Decal") then
				parte.LocalTransparencyModifier = if esconder then 1 else 0
			elseif parte:IsA("Humanoid") then
				if esconder then
					if propriedadesOcultas[parte] == nil then propriedadesOcultas[parte] = parte.DisplayDistanceType end
					parte.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				elseif propriedadesOcultas[parte] ~= nil then parte.DisplayDistanceType = propriedadesOcultas[parte]; propriedadesOcultas[parte] = nil end
			elseif parte:IsA("Highlight") or parte:IsA("ParticleEmitter") or parte:IsA("Trail") or parte:IsA("Beam") or parte:IsA("Fire") or parte:IsA("Smoke") or parte:IsA("Sparkles") or parte:IsA("BillboardGui") then
				if esconder then
					if propriedadesOcultas[parte] == nil then propriedadesOcultas[parte] = parte.Enabled end
					parte.Enabled = false
				elseif propriedadesOcultas[parte] ~= nil then parte.Enabled = propriedadesOcultas[parte]; propriedadesOcultas[parte] = nil end
			end
		end
		escondidos[character] = if esconder then true else nil
	end

	-- Em Chamas é estado, não evento: quem entra depois também vê o fogo.
	local FOGO = Estilo.arvore("fogo").cor
	local function atualizarChamas(view, queimando: boolean, root: BasePart?)
		local ancora = root or view.parts.body
		if queimando then
			if not view.fogo or view.fogo.Parent ~= ancora then
				if view.fogo then
					view.fogo:Destroy()
				end
				local fogo = Instance.new("Fire")
				fogo.Name = "EmChamasLocal"
				fogo.Size = if root then 8 else 9
				fogo.Heat = 9
				fogo.Color = FOGO
				fogo.SecondaryColor = Estilo.ALERTA
				fogo.Parent = ancora
				local luz = Instance.new("PointLight")
				luz.Color = FOGO
				luz.Range = 12
				luz.Brightness = 1.4
				luz.Parent = fogo
				view.fogo = fogo
			end
		elseif view.fogo then
			view.fogo.Enabled = false
			local velho = view.fogo
			view.fogo = nil
			task.delay(1.2, function()
				velho:Destroy()
			end)
		end
	end

	-- Arma conjurada é estado: aparece para quem recebe o snapshot, inclusive
	-- depois da animação de conjuração, e some na expiração/fim do combate.
	local function atualizarLamina(view, ativa)
		if ativa and not view.parts.laminaGelo then
			local lamina = Instance.new("WedgePart")
			lamina.Name = "LaminaDeGelo"
			lamina.Size = Vector3.new(0.22, 3.3, 0.7)
			lamina.Material, lamina.Color = Enum.Material.Glass, Estilo.arvore("agua").cor
			lamina.Anchored, lamina.CanCollide, lamina.CanTouch, lamina.CanQuery = true, false, false, false
			lamina.CastShadow = false
			lamina.Parent = view.model
			view.parts.laminaGelo = lamina
			view.offsets.laminaGelo = CFrame.new(1.7, 3.2, -0.4) * CFrame.Angles(0, 0, math.rad(-18))
		elseif not ativa and view.parts.laminaGelo then
			view.parts.laminaGelo:Destroy()
			view.parts.laminaGelo, view.offsets.laminaGelo = nil, nil
		end
		if view.parts.laminaGelo then view.parts.laminaGelo.Transparency = if view.hidden then 0.65 else 0.18 end
	end

	local function cellCFrame(x: number, z: number): CFrame
		return CFrame.new(Protocol.cellCenter(x, z))
	end

	local function barColor(ratio: number): Color3
		return if ratio > 0.5 then PV_ALTO elseif ratio > 0.25 then PV_MEDIO else PV_BAIXO
	end

	-- Um só laço anima saltos, anéis e flutuação de todas as fichas.
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local snapshot = state.snapshot()
		local turnId = snapshot and snapshot.combat.turnId
		local selected = state.selectedToken()
		for id, view in views do
			local cf = view.cframe
			local avatarRoot = (view.avatarUserId and rootDe(view.avatarUserId)) or (view.corpo and corpoRoot(id)) or nil
			if avatarRoot and view.corpo and view.parts.base.Transparency < 1 then
				-- O corpo chegou depois do snapshot: some o pino e o nome passa para a cabeça.
				for _, nome in MINI do
					view.parts[nome].Transparency = 1
				end
				local billboard = view.model:FindFirstChildOfClass("BillboardGui")
				local cabeca = avatarRoot.Parent and avatarRoot.Parent:FindFirstChild("Head")
				if billboard then
					billboard.Adornee = if cabeca and cabeca:IsA("BasePart") then cabeca else avatarRoot
					billboard.StudsOffset = Vector3.new(0, 2.2, 0)
				end
			end
			if avatarRoot then
				local p = avatarRoot.Position
				view.anim = nil
				cf = CFrame.new(p.X, board.origin.Y, p.Z)
			end
			local anim = view.anim
			if anim then
				local t = math.min((now - anim.start) / anim.duration, 1)
				local p = ease(t)
				local position = anim.from.Position:Lerp(anim.to.Position, p)
				cf = CFrame.new(position + Vector3.new(0, math.sin(math.pi * t) * anim.height, 0))
				if t >= 1 then
					view.anim = nil
					cf = anim.to
				end
			end
			cf += Efeitos.deslocamentoDe(id)
			local isTurn = id == turnId
			if isTurn and not avatarRoot then
				cf *= CFrame.new(0, 0.18 + math.sin(now * 3 + view.seed) * 0.18, 0)
			end
			pose(view, cf)
			view.parts.select.Transparency = if id == selected then 0.25 + math.sin(now * 5) * 0.2 else 1
			view.parts.turn.Transparency = if isTurn then 0.3 + math.sin(now * 3) * 0.2 else 1
			if view.hidden and not view.avatarUserId then
				local pulse = 0.55 + math.sin(now * 2 + view.seed) * 0.12
				view.parts.body.Transparency, view.parts.head.Transparency, view.parts.rim.Transparency = pulse, pulse, pulse
			end
		end
	end)

	local murosFolder = Instance.new("Folder")
	murosFolder.Name = "MurosDeFogo"
	murosFolder.Parent = workspace
	local murosVistos: { [string]: Model } = {}
	-- Rótulo na interface, projetado sobre a casa: mantém leitura em qualquer zoom.
	local avisos = {}
	local avisosGui = Instance.new("ScreenGui")
	avisosGui.Name, avisosGui.ResetOnSpawn, avisosGui.IgnoreGuiInset, avisosGui.DisplayOrder = "PerigosMesa", false, true, 3
	avisosGui.Parent = player:WaitForChild("PlayerGui")
	local seguirAvisos = RunService.RenderStepped:Connect(function()
		for chama, rotulo in avisos do
			if chama.Parent then
				local p, visivel = camera:WorldToViewportPoint(chama.Position + Vector3.new(0, 2.5, 0))
				rotulo.Visible = visivel and p.Z > 0
				rotulo.Position = UDim2.fromOffset(p.X, p.Y)
			end
		end
	end)
	avisosGui.Destroying:Connect(function() seguirAvisos:Disconnect() end)
	local ALTURA_DO_MURO = board.cell * 2 -- 3 m = 2 casas de 1,5 m
	local function renderMuros(lista)
		local vivos = {}
		for _, muro in lista or {} do
			vivos[muro.id] = true
			if not murosVistos[muro.id] then
				local modelo = Instance.new("Model")
				local estilo = muro.estilo or "fogo"
				local cores = { agua = Color3.fromRGB(68, 160, 220), terra = Color3.fromRGB(133, 97, 66), anteparo = Color3.fromRGB(160, 128, 210), nevoa = Color3.fromRGB(193, 201, 208), atoleiro = Color3.fromRGB(110, 83, 57) }
				local cor = cores[estilo] or FOGO
				local altura = if estilo == "atoleiro" or estilo == "braseiro" then 0.3 else ALTURA_DO_MURO
				local largura = if estilo == "terra" then board.cell else board.cell - .8
				modelo.Name = muro.id
				for i, casa in muro.casas do
					local centro = Protocol.cellCenter(casa[1], casa[2])
					local chama = Instance.new("Part")
					chama.Name = "Chama"
					chama.Anchored, chama.CanCollide, chama.CanQuery, chama.CastShadow = true, false, false, false
					chama.Material = if estilo == "terra" then Enum.Material.Slate else Enum.Material.Neon
					chama.Color = cor
					chama.Transparency = if estilo == "terra" then .08 else .62
					chama.Size = Vector3.new(largura, 0.2, largura)
					chama.Position = centro + Vector3.new(0, 0.1, 0)
					chama.Parent = modelo
					if estilo == "fogo" or estilo == "braseiro" then
					local fogo = Instance.new("Fire")
					fogo.Size, fogo.Heat, fogo.Color, fogo.SecondaryColor = if estilo == "braseiro" then 3 else 9, if estilo == "braseiro" then 2 else 18, FOGO, Estilo.ALERTA
					fogo.Parent = chama
					if estilo == "braseiro" then
						local rotulo = Instance.new("TextLabel")
						rotulo.Name = "Perigo_" .. muro.id
						rotulo.AnchorPoint = Vector2.new(0.5, 1)
						rotulo.Size, rotulo.BackgroundTransparency, rotulo.TextSize = UDim2.fromOffset(180, 32), 0.15, 14
						rotulo.BackgroundColor3, rotulo.TextColor3, rotulo.FontFace = Estilo.PAPEL, Estilo.ALERTA, Estilo.ROTULO_FORTE
						rotulo.Text = "Fagulha • 1d4 ao entrar"
						rotulo.Parent = avisosGui
						avisos[chama] = rotulo
						chama.Destroying:Connect(function() avisos[chama] = nil; rotulo:Destroy() end)
					end
					if i % 2 == 1 then
						local luz = Instance.new("PointLight")
						luz.Color, luz.Range, luz.Brightness = FOGO, 16, 1.6
						luz.Parent = chama
					end
					end
					-- O muro sobe casa a casa, a partir de quem conjurou.
					task.delay(i * 0.07, function()
						if not chama.Parent then return end
						TweenService:Create(chama, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							Size = Vector3.new(largura, altura, largura),
							Position = centro + Vector3.new(0, altura / 2, 0),
						}):Play()
					end)
				end
				modelo.Parent = murosFolder
				murosVistos[muro.id] = modelo
			end
   local modelo = murosVistos[muro.id]
   if modelo and muro.pv then
    local ancora = modelo:FindFirstChild("Chama")
    if ancora then
     local gui = ancora:FindFirstChild("PV")
     if not gui then
      gui = Instance.new("BillboardGui"); gui.Name = "PV"; gui.Size = UDim2.fromOffset(160, 26); gui.StudsOffset = Vector3.new(0, 7, 0); gui.AlwaysOnTop = true; gui.Parent = ancora
      local texto = Instance.new("TextLabel"); texto.Name = "Texto"; texto.Size = UDim2.fromScale(1, 1); texto.BackgroundTransparency = 1; texto.TextColor3 = Color3.new(1,1,1); texto.TextSize = 17; texto.Parent = gui
     end
     gui.Texto.Text = string.format("Barreira %d/%d PV", muro.pv, muro.pvMax)
    end
   end
		end
		for id, modelo in murosVistos do
			if not vivos[id] then
				murosVistos[id] = nil
				for _, parte in modelo:GetChildren() do
					if parte:IsA("BasePart") then
						local fogo = parte:FindFirstChildOfClass("Fire")
						if fogo then
							fogo.Enabled = false
						end
						TweenService:Create(parte, TweenInfo.new(0.8), { Transparency = 1, Size = parte.Size * Vector3.new(1, 0.05, 1) }):Play()
					end
				end
				task.delay(1.5, function()
					modelo:Destroy()
				end)
			end
		end
	end

	local armas = require(script.Parent.ArmasNoChaoView).start()

	require(script.Parent.VisaoFurtivaView).start(state)

	local function render(snapshot)
		-- A mesa legada conserva as peças; a sala social não desenha o combate encerrado.
		if snapshot.salaConceitual and not snapshot.combat.active then
			snapshot=table.clone(snapshot);snapshot.tokens={};snapshot.avatares={};snapshot.jogo=nil
		end
		renderMuros(snapshot.jogo and snapshot.jogo.muros)
  armas.render(snapshot.jogo and snapshot.jogo.objetos)
		local seen = {}
		for _, token in snapshot.tokens do
			seen[token.id] = true
			local view = views[token.id]
			local fresh = false
			if not view then
				view, fresh = createView(token)
			end
			local target = cellCFrame(token.x, token.z)
			if fresh then
				view.cframe = target
				pose(view, target)
			elseif (view.cframe.Position - target.Position).Magnitude > 0.01 then
				-- Salto em arco, mais longo e mais alto para distâncias maiores.
				local cells = (view.cframe.Position - target.Position).Magnitude / board.cell
				view.anim = {
					from = view.cframe,
					to = target,
					start = os.clock(),
					duration = math.clamp(0.22 + cells * 0.07, 0.25, 0.7),
					height = math.clamp(1 + cells * 0.4, 1.2, 4),
				}
				view.cframe = target
			end
			for _, name in { "rim", "body", "head" } do
				view.parts[name].Color = token.color
			end
			view.hidden = token.hidden == true or Furtividade.escondido(token)
			view.avatarUserId = if token.avatar then token.ownerUserId else nil
			view.corpo = token.corpo == true
			local root = rootDe(view.avatarUserId) or (if view.corpo then corpoRoot(token.id) else nil)
			local billboard = view.model:FindFirstChildOfClass("BillboardGui")
			if root then
				for _, nome in MINI do
					view.parts[nome].Transparency = 1
				end
				local cabeca = root.Parent and root.Parent:FindFirstChild("Head")
				if billboard then
					billboard.Adornee = if cabeca and cabeca:IsA("BasePart") then cabeca else root
					billboard.StudsOffset = Vector3.new(0, 2.2, 0)
				end
			else
				view.parts.base.Transparency = 0
				if billboard then
					billboard.Adornee = view.parts.head
					billboard.StudsOffset = Vector3.new(0, 2.5, 0)
				end
				if not view.hidden then
					view.parts.body.Transparency, view.parts.head.Transparency, view.parts.rim.Transparency = 0, 0, 0
				end
			end
			view.label.Text = (if Furtividade.escondido(token) then "FURTIVO • " elseif token.hidden then "(oculto) " else "") .. token.name .. (if token.pv == 0 then " • 0 PV: precisa de cura" else "")
			local barBack = view.bar.Parent :: Frame
			if token.pv and token.pvMax and token.pvMax > 0 then
				barBack.Visible = true
				local ratio = math.clamp(token.pv / token.pvMax, 0, 1)
				TweenService:Create(view.bar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
					Size = UDim2.fromScale(ratio, 1),
					BackgroundColor3 = barColor(ratio),
				}):Play()
				if not fresh and view.lastPv and token.pv ~= view.lastPv then
					Efeitos.damageText(target.Position + Vector3.new(0, 5, 0), token.pv - view.lastPv)
				end
				view.lastPv = token.pv
			else
				barBack.Visible = false
				view.lastPv = nil
			end
			atualizarLamina(view, table.find(token.estadosCombate or {}, "armaGelo") ~= nil)
			view.conditions.Text = table.concat(CondicaoRules.labels(token.conditions or {}, Condicoes), " · ")
			local queimando = false
			for _, condicao in token.conditions or {} do
				if condicao.id == "em-chamas" then
					queimando = true
				end
			end
			atualizarChamas(view, queimando, root)
			-- Criatura derrotada: some em cinzas antes de o servidor removê-la.
			if token.derrotado and not view.derrotado then
				view.derrotado = true
				for _, nome in MINI do
					TweenService:Create(view.parts[nome], TweenInfo.new(1.8, Enum.EasingStyle.Quad), { Transparency = 1, Color = Estilo.MESA }):Play()
				end
				Efeitos.floatText(target.Position + Vector3.new(0, 6, 0), "DERROTADO", Estilo.PERIGO)
			elseif not token.derrotado and view.derrotado then
				-- Boneco de treino levantando: volta inteiro.
				view.derrotado = false
				view.parts.base.Color = Estilo.PAPEL_2
				for _, nome in { "rim", "body", "head" } do
					view.parts[nome].Color = token.color
				end
				if not root then
					for _, nome in MINI do
						TweenService:Create(view.parts[nome], TweenInfo.new(0.4), { Transparency = 0 }):Play()
					end
				end
				Efeitos.floatText(target.Position + Vector3.new(0, 6, 0), "DE PÉ", Estilo.SUCESSO)
			end
		end
		for id, view in views do
			if not seen[id] then
				view.model:Destroy()
				views[id] = nil
			end
		end
		local visiveis = {}
		for _, token in snapshot.tokens do
			if token.avatar then
				visiveis[token.ownerUserId] = true
			end
		end
		local vinculados = {}
		for _, userId in snapshot.avatares or {} do
			vinculados[userId] = true
			local dono = Players:GetPlayerByUserId(userId)
			if dono and dono ~= player and dono.Character then
				local esconder = not visiveis[userId]
				if esconder ~= (escondidos[dono.Character] == true) then
					esconderPersonagem(dono.Character, esconder)
				end
			end
		end
		for character in escondidos do
			local dono = Players:GetPlayerFromCharacter(character)
			if not dono or not vinculados[dono.UserId] then
				esconderPersonagem(character, false)
			end
		end

		-- Ator/rodada ficam no HUD; RitmoCombate anuncia a própria vez.
		-- Um segundo letreiro aqui encobria a mesma vinheta.
	end

	-- Mapa -------------------------------------------------------------------

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "MesaMapaLocal"
	mapFolder.Parent = workspace
	local terrainParts: { [string]: Part } = {}
	local fogParts: { [string]: Part } = {}

	local function cellFromKey(key: string): (number, number)
		local x, z = string.match(key, "^(%d+),(%d+)$")
		return tonumber(x) :: number, tonumber(z) :: number
	end

	local function tile(name: string, key: string, height: number, color: Color3, material: Enum.Material?): Part
		local x, z = cellFromKey(key)
		local part = Instance.new("Part")
		part.Name = name .. "_" .. key
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.Material = material or Enum.Material.SmoothPlastic
		part.Size = Vector3.new(board.cell - 0.15, height, board.cell - 0.15)
		part.Position = Protocol.cellCenter(x, z) + Vector3.new(0, height / 2 + 0.03, 0)
		part.Color = color
		part.Transparency = 1
		part.Parent = mapFolder
		return part
	end

	-- Sumir com transição antes de destruir.
	local function fadeOut(part: Part)
		part:SetAttribute("Saindo", true)
		local tween = TweenService:Create(part, TweenInfo.new(0.35), { Transparency = 1 })
		tween.Completed:Connect(function()
			part:Destroy()
		end)
		tween:Play()
	end

	local function renderMap(snapshot)
		local map = snapshot.map or {}
		local terrainNow, fogNow = map.terrain or {}, map.fog or {}
		for key, part in terrainParts do
			if terrainNow[key] ~= part:GetAttribute("Tipo") then
				fadeOut(part)
				terrainParts[key] = nil
			end
		end
		for key, kind in terrainNow do
			local look = TERRAIN_LOOK[kind]
			if look and not terrainParts[key] then
				local part = tile("Terreno", key, look.height, look.color, look.material)
				if kind == "parede" then part.Size = Vector3.new(board.cell, look.height, board.cell) end
				part:SetAttribute("Tipo", kind)
				-- Pequeno "pop" ao pintar.
				local full = part.Size
				part.Size = full * Vector3.new(0.4, 0.4, 0.4)
				TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = full,
					Transparency = look.transparency,
				}):Play()
				terrainParts[key] = part
			end
		end
		-- Névoa: opaca para o jogador; translúcida para o mestre, que precisa ver o que esconde.
		local master = snapshot.you and snapshot.you.master
		-- Para o jogador, só a própria ficha chega dentro da névoa; ela fica à
		-- vista sob uma névoa translúcida (D-23).
		local ownCells = {}
		for _, token in snapshot.tokens do
			ownCells[token.x .. "," .. token.z] = true
		end
		local function fogTransparencyAt(key: string): number
			if master then
				return 0.55
			end
			return if ownCells[key] then 0.6 else 0
		end
		for key, part in fogParts do
			if not fogNow[key] or part:GetAttribute("Alvo") ~= fogTransparencyAt(key) then
				fadeOut(part)
				fogParts[key] = nil
			end
		end
		for key in fogNow do
			if not fogParts[key] then
				local target = fogTransparencyAt(key)
				local part = tile("Nevoa", key, 3.4, FOG_COLOR, Enum.Material.SmoothPlastic)
				part:SetAttribute("Alvo", target)
				TweenService:Create(part, TweenInfo.new(0.4), { Transparency = target }):Play()
				fogParts[key] = part
			end
		end
	end

	state.onSnapshot(render)
	state.onSnapshot(renderMap)
	state.onRoll(Efeitos.dice)
	state.onSelection(function(_, x, z)
		if x and z then
			cellMarker.Position = Protocol.cellCenter(x, z) + Vector3.new(0, 0.06, 0)
			cellMarker.Parent = workspace
		else
			cellMarker.Parent = nil
		end
	end)

	-- Câmera de mesa -----------------------------------------------------------

	local focus = board.origin
	local height = 148
	local heightTarget = 148 -- roda e pinça mudam o alvo; a câmera chega suave
	local blendFrom: CFrame? = nil
	local blendStart = 0
	local combateAnterior = false
	local enquadrarAte = 0
	local enquadrarPendente = false

	local function humanoid(): Humanoid?
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end
	local function propriaFichaFurtiva(): boolean
		local snap = state.snapshot()
		if snap and snap.salaConceitual and not snap.combat.active then return false end
		for _, token in snap and snap.tokens or {} do
			if token.ownerUserId == player.UserId and Furtividade.escondido(token) then return true end
		end
		return false
	end

	state.onTableView(function(enabled)
		if not enabled and propriaFichaFurtiva() then state.setTableView(true); return end
		local hum = humanoid()
		Movimento.definir("tabuleiro",enabled)
		if enabled then
			blendFrom, blendStart = camera.CFrame, os.clock()
			camera.CameraType = Enum.CameraType.Scriptable
		else
			camera.CameraType = Enum.CameraType.Custom
			if hum then
				camera.CameraSubject = hum
			end
		end
	end)
	state.onSnapshot(function()
		local snap = state.snapshot()
		local ativo = snap ~= nil and snap.combat.active
		if ativo and not combateAnterior then
			-- O HUD termina seu layout sob o corte escuro; não seguir peças depois.
			enquadrarAte = os.clock() + .2
			enquadrarPendente = true
		elseif not ativo then
			enquadrarAte = 0
			enquadrarPendente = false
		end
		combateAnterior = ativo
		if snap and snap.salaConceitual and not ativo then
			state.setMira(nil);state.selectToken(nil);state.setTableView(false)
		elseif propriaFichaFurtiva() then state.setTableView(true) end
	end)

	player.CharacterAdded:Connect(function()
		state.setTableView(false)
	end)

	-- O tabuleiro aparece no meio da área livre: sem o painel da direita e sem a
	-- barra de ações de baixo, que antes escondiam as casas de baixo.
	local GuiService = game:GetService("GuiService")
	local deslocamento = Vector2.zero
	local function visivelNaTela(objeto): boolean
		if not objeto then return false end
		local atual = objeto
		while atual and atual ~= player.PlayerGui do
			if atual:IsA("GuiObject") and not atual.Visible then return false end
			if atual:IsA("ScreenGui") and not atual.Enabled then return false end
			atual = atual.Parent
		end
		return atual == player.PlayerGui
	end
	local function areaLivre(): (Vector2, any)
		local vp = camera.ViewportSize
		local esquerda, direita, topo, base = 0, vp.X, 64, vp.Y
		local inset = GuiService:GetGuiInset().Y
		local pg = player:FindFirstChild("PlayerGui")
		local painel = pg and pg:FindFirstChild("PanelRoot", true)
		if painel and painel:IsA("GuiObject") and visivelNaTela(painel) and painel.AbsoluteSize.X > 0 then
			if painel.AbsolutePosition.X > vp.X * 0.45 then
				direita = math.min(direita, painel.AbsolutePosition.X - 8)
			else
				base = math.min(base, painel.AbsolutePosition.Y + inset - 8)
			end
		end
		local acoes = pg and pg:FindFirstChild("AcoesDoTurno")
		local barra = acoes and acoes:FindFirstChild("Barra")
		if barra and barra:IsA("GuiObject") and visivelNaTela(barra) then
			base = math.min(base, barra.AbsolutePosition.Y + inset - 8)
		end
		local hud = pg and pg:FindFirstChild("HudJogo")
		local resumo = hud and hud:FindFirstChild("Resumo")
		if resumo and visivelNaTela(resumo) then
			topo = math.max(topo, resumo.AbsolutePosition.Y + inset + resumo.AbsoluteSize.Y + 8)
		end
		local chefe = hud and hud:FindFirstChild("Chefe")
		if chefe and visivelNaTela(chefe) then
			topo = math.max(topo, chefe.AbsolutePosition.Y + inset + chefe.AbsoluteSize.Y + 8)
		end
		base = math.max(topo + 1, base)
		return Vector2.new((esquerda + direita) / 2, (topo + base) / 2), { x1 = esquerda, y1 = topo, x2 = direita, y2 = base }
	end

	local halfWidth = board.width * board.cell / 2
	local halfHeight = board.height * board.cell / 2
	RunService.RenderStepped:Connect(function(dt)
		local snapAtual=state.snapshot()
		if snapAtual and snapAtual.salaConceitual and not snapAtual.combat.active then return end
		if not state.tableView() then
			return
		end
		if enquadrarPendente or os.clock() < enquadrarAte then
			local snap = state.snapshot()
			if snap and snap.combat.active then
				local limites = Enquadramento.limites(snap.tokens, snap.combat.order, board)
				local centro, area = areaLivre()
				local vp = camera.ViewportSize
				focus = board.origin + Vector3.new(limites.x, 0, limites.z)
				heightTarget = math.clamp(Enquadramento.altura(limites, { x = vp.X, y = vp.Y }, area, camera.FieldOfView), MIN_HEIGHT, MAX_HEIGHT)
				height = heightTarget
				deslocamento = centro - vp / 2
				enquadrarPendente = false
			end
		end
		if not UserInputService:GetFocusedTextBox() then
			local move = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				move -= Vector3.zAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				move += Vector3.zAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				move -= Vector3.xAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				move += Vector3.xAxis
			end
			focus += move * PAN_SPEED * dt
			focus = Vector3.new(
				math.clamp(focus.X, board.origin.X - halfWidth, board.origin.X + halfWidth),
				board.origin.Y,
				math.clamp(focus.Z, board.origin.Z - halfHeight, board.origin.Z + halfHeight)
			)
		end
		height += (heightTarget - height) * math.min(1, dt * 10)
		local target = CFrame.lookAt(focus + Vector3.new(0, height, height * Enquadramento.INCLINACAO), focus)
		do
			local vp = camera.ViewportSize
			local alvoPx = areaLivre() - vp / 2
			deslocamento = deslocamento:Lerp(alvoPx, math.min(1, dt * 8))
			local distancia = (target.Position - focus).Magnitude
			local porPixel = 2 * distancia * math.tan(math.rad(camera.FieldOfView / 2)) / math.max(vp.Y, 1)
			target = target * CFrame.new(-deslocamento.X * porPixel, deslocamento.Y * porPixel, 0)
		end
		-- Transição suave da câmera do avatar para a Visão da mesa.
		local t = if blendFrom then (os.clock() - blendStart) / CAMERA_BLEND else 1
		if blendFrom and t < 1 then
			camera.CFrame = blendFrom:Lerp(target, ease(t)) * Efeitos.tremorCFrame()
		else
			blendFrom = nil
			camera.CFrame = target * Efeitos.tremorCFrame()
		end
	end)

	-- Entrada ------------------------------------------------------------------

	-- Mouse: GetMouseLocation inclui a barra superior, como ViewportPointToRay.
	-- Toque: InputObject.Position desconta a barra, como ScreenPointToRay.
	-- Confirmar no playtest (docs/DISCUSSOES.md D-1).
	local function cellFromRay(ray: Ray): (number?, number?)
		if math.abs(ray.Direction.Y) < 1e-5 then
			return nil, nil
		end
		-- Interseção com o plano do tabuleiro: avatares e fichas não bloqueiam o clique.
		local distance = (board.origin.Y - ray.Origin.Y) / ray.Direction.Y
		if distance <= 0 then
			return nil, nil
		end
		return Protocol.cellAt(ray.Origin + ray.Direction * distance)
	end

	-- Pincel (M4): casas pendentes são enviadas em lotes enquanto o mouse arrasta.
	local pending: { [string]: { x: number, z: number } } = {}
	local pendingCount = 0
	local pendingBrush: string? = nil -- pincel que começou o lote (D-24)
	local painting = false
	local lastFlush = 0

	local function flushPaint()
		local brushName = pendingBrush
		pendingBrush = nil
		if pendingCount == 0 or not brushName then
			table.clear(pending)
			pendingCount = 0
			return
		end
		local cells = {}
		for _, cell in pending do
			table.insert(cells, cell)
		end
		table.clear(pending)
		pendingCount = 0
		lastFlush = os.clock()
		state.send("paintCells", { brush = brushName, cells = cells })
	end

	local function paintAt(ray: Ray)
		local brushName = state.brush()
		if not brushName or not state.tableView() or not state.isMaster() then
			return
		end
		local x, z = cellFromRay(ray)
		if not x or not z then
			return
		end
		if pendingBrush and pendingBrush ~= brushName then
			flushPaint()
		end
		pendingBrush = brushName
		local key = x .. "," .. z
		if not pending[key] then
			pending[key] = { x = x, z = z }
			pendingCount += 1
		end
		if pendingCount >= 150 or os.clock() - lastFlush >= PAINT_BATCH then
			flushPaint()
		end
	end

	-- Trocar de pincel, sair da visão da mesa ou perder o foco encerra o
	-- arraste e envia o lote com o pincel que o começou.
	local function stopPainting()
		painting = false
		flushPaint()
	end
	state.onBrush(stopPainting)
	state.onTableView(function(enabled)
		if not enabled then
			stopPainting()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(stopPainting)

	-- Apresentação da mira separada da entrada/câmera; o servidor mantém a validação.
	require(script.Parent.MiraView).start(state, function()
		local mouse = UserInputService:GetMouseLocation()
		return cellFromRay(camera:ViewportPointToRay(mouse.X, mouse.Y))
	end)
	state.onMira(function(mira)
		if mira and not state.tableView() then state.setTableView(true) end
	end)

	local function select(ray: Ray)
		local x, z = cellFromRay(ray)
		if not x or not z then
			return
		end
		local mira = state.mira()
		if mira then
			-- Com mira: o clique escolhe o alvo (ficha) ou a casa; o servidor valida.
			local alvo = state.tokenAt(x, z)
			if (mira.modo == "ficha" or mira.modo == "lista") then
				-- Cura pode mirar a si mesmo; o servidor decide o que vale.
				if alvo and (alvo.id ~= mira.tokenId or mira.tipo == "cura" or mira.permiteSi) then
					state.dispararMira(alvo.id)
				elseif mira.habilidadeId == "mesa/ataque-basico" or mira.habilidadeId == "mesa/ataque-a-distancia" then
     local snap = state.snapshot()
     for _, muro in (snap.jogo and snap.jogo.muros) or {} do
      if muro.pv then for _, casa in muro.casas do if casa[1] == x and casa[2] == z then state.dispararMira(nil, x, z); return end end end
     end
    end
			elseif mira.modo == "casa" then
				state.escolherCasaDaMira(x, z)
			end
			return
		end
		local token = state.tokenAt(x, z)
		local selected = state.findToken(state.selectedToken())
		if token then
			state.selectToken(if token.id == state.selectedToken() then nil else token.id)
		elseif selected and state.canControl(selected) then
			local snap = state.snapshot()
			local naVez = snap ~= nil and snap.combat.active and snap.combat.turnId == selected.id
			state.send("move", { id = selected.id, x = x, z = z, andar = naVez or nil })
		else
			state.selectCell(x, z)
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local snap = state.snapshot()
		if snap and snap.salaConceitual and not snap.combat.active then return end
		if input.KeyCode == Enum.KeyCode.M then
			state.setTableView(not state.tableView())
		elseif not state.tableView() then
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mouse = UserInputService:GetMouseLocation()
			if state.brush() then
				painting = true
				paintAt(camera:ViewportPointToRay(mouse.X, mouse.Y))
			else
				select(camera:ViewportPointToRay(mouse.X, mouse.Y))
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
			if state.mira() then
				state.setMira(nil)
			else
				state.selectToken(nil)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if painting and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mouse = UserInputService:GetMouseLocation()
			paintAt(camera:ViewportPointToRay(mouse.X, mouse.Y))
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if painting and input.UserInputType == Enum.UserInputType.MouseButton1 then
			painting = false
			flushPaint()
		end
	end)

	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and state.tableView() and input.UserInputType == Enum.UserInputType.MouseWheel then
			heightTarget = math.clamp(heightTarget - input.Position.Z * 10, MIN_HEIGHT, MAX_HEIGHT)
		end
	end)

	-- Toque: um dedo que quase não se move seleciona; arrastar move a câmera.
	-- Qualquer segundo dedo (mesmo sobre a interface) cancela a seleção dos atuais.
	local touches: { [InputObject]: { start: Vector3, focus: Vector3, moved: boolean } } = {}
	local fingers = 0 -- todos os dedos na tela, inclusive sobre a interface
	local TAP_TOLERANCE = 12

	local function studsPerPixel(): number
		local visible = 2 * height * math.tan(math.rad(camera.FieldOfView) / 2)
		return visible / math.max(camera.ViewportSize.Y, 1)
	end

	state.onTableView(function(enabled)
		if not enabled then
			table.clear(touches)
		end
	end)
	-- Toques perdidos ao trocar de app não geram InputEnded; zera a contagem.
	UserInputService.WindowFocusReleased:Connect(function()
		fingers = 0
		table.clear(touches)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		fingers += 1
		if fingers > 1 then
			for _, other in touches do
				other.moved = true
			end
		end
		if not processed and state.tableView() then
			touches[input] = { start = input.Position, focus = focus, moved = fingers > 1 }
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		local touch = touches[input]
		if not touch or fingers ~= 1 or not state.tableView() then
			return
		end
		local delta = input.Position - touch.start
		if delta.Magnitude > TAP_TOLERANCE then
			touch.moved = true
		end
		if touch.moved then
			if state.brush() then
				paintAt(camera:ScreenPointToRay(input.Position.X, input.Position.Y))
			else
				local scale = studsPerPixel()
				focus = touch.focus - Vector3.new(delta.X * scale, 0, delta.Y * scale)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		fingers = math.max(fingers - 1, 0)
		local touch = touches[input]
		touches[input] = nil
		-- Ao sair da pinça, o dedo restante recomeça o arraste daqui, sem salto.
		for other, remaining in touches do
			remaining.start = other.Position
			remaining.focus = focus
		end
		if touch and state.brush() then
			-- Com pincel: toque curto pinta uma casa; arraste já pintou no caminho.
			if not touch.moved and state.tableView() then
				paintAt(camera:ScreenPointToRay(input.Position.X, input.Position.Y))
			end
			flushPaint()
		elseif touch and not touch.moved and state.tableView() then
			select(camera:ScreenPointToRay(input.Position.X, input.Position.Y))
		end
	end)

	-- scale é acumulado desde o início da pinça; parte da altura inicial.
	local pinchStart = height
	UserInputService.TouchPinch:Connect(function(_, scale, _, inputState, processed)
		if processed or not state.tableView() then
			return
		end
		if inputState == Enum.UserInputState.Begin then
			pinchStart = heightTarget
		elseif inputState == Enum.UserInputState.Change and scale > 0 then
			heightTarget = math.clamp(pinchStart / scale, MIN_HEIGHT, MAX_HEIGHT)
		end
	end)
end

return BoardView
