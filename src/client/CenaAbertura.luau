-- Cena de abertura (primeira vez que alguém joga): câmera cinematográfica sobre o mundo
-- real, letterbox, legendas da narração e o título. Só apresentação local; não decide nada.
--
-- API:
--   CenaAbertura.tocar(opcoes?) -> concluiu: boolean   (BLOQUEIA até acabar ou ser pulada;
--       true = viu até o fim, false = pulou ou já havia uma cena tocando)
--   CenaAbertura.pular()        pede o fim imediato (fade para preto curto)
--   CenaAbertura.ativa() -> boolean
-- opcoes: cameraMundo? (módulo com pausar/retomar; padrão = CameraMundo real),
--   esconderInterface? (padrão true: desliga as outras ScreenGuis durante a cena e as devolve),
--   inicioEm? / velocidade? (ferramentas de ajuste: começar em t segundos e escalar o tempo;
--   velocidade 0 congela o quadro `inicioEm`).
--
-- PULAR: botão "Pular ▶" discreto na barra inferior, Espaço / A do controle, ou segurar a
-- tela (toque longo ou botão do mouse) por 0,9 s. Espaço fica consumido durante a cena.
--
-- CÂMERA: pausa a CameraMundo com o contrato dela (`pausar("abertura")`) e, sob o preto
-- do fim (natural ou por pulo), `retomar("abertura")`; ela desliza da pose atual. O trajeto,
-- as falas e o título são dados puros em shared/CenaAberturaDados (função do tempo da cena).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Dados = require(ReplicatedStorage.Shared.CenaAberturaDados)
local Componentes = require(script.Parent.UI.Componentes)
local BloqueioMovimento = require(script.Parent.BloqueioMovimento)
local T = require(script.Parent.UI.Tema)

local CenaAbertura = {}

local MOTIVO_CAMERA = "abertura"
local ACAO_PULAR = "CenaAberturaPular"
local PASSO_RENDER = "CenaAbertura"
local PRIORIDADE = Enum.RenderPriority.Camera.Value + 10 -- depois da CameraMundo (+5) e da SalaView
local ALTURA_BARRA = 0.115 -- fração da tela por barra do letterbox
local TOQUE_LONGO = 0.9 -- s segurando a tela para pular
local FADE_PULO = 0.4 -- s até o preto ao pular
local PRETO_FINAL = 0.55 -- s em preto, com a câmera já devolvida, antes de revelar o jogo
local REVELAR = 0.6 -- s para o preto sumir e as barras saírem

local ativo = nil -- estado da cena em curso

local cor = T.cores

local function criar(classe, props, pai)
	local obj = Instance.new(classe)
	for k, v in props do obj[k] = v end
	obj.Parent = pai
	return obj
end

-- Fio dourado que some nas pontas; `sentido` 0 = some dos dois lados, 1 = some à direita, -1 = à esquerda.
local function fio(pai, largura, sentido, ordem)
	local f = criar("Frame", { Name = "Fio", Size = UDim2.fromOffset(largura, 2), BackgroundColor3 = cor.ouroClaro,
		BorderSizePixel = 0, LayoutOrder = ordem }, pai)
	local seq = if sentido == 0 then NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		elseif sentido > 0 then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	criar("UIGradient", { Transparency = seq }, f)
	return f
end

local function construirInterface(gui, vy: number)
	local ui = {}
	ui.veu = criar("Frame", { Name = "Veu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 50 }, gui)
	-- Quadro inteiro, transparente: recebe o toque longo (pular).
	ui.toque = criar("TextButton", { Name = "Toque", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, ZIndex = 1 }, gui)
	ui.sombra = criar("Frame", { Name = "SombraLegenda", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.34), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2 }, gui)
	criar("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.35) }) }, ui.sombra)
	ui.barraSup = criar("Frame", { Name = "BarraSuperior", Size = UDim2.fromScale(1, ALTURA_BARRA), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 20 }, gui)
	ui.barraInf = criar("Frame", { Name = "BarraInferior", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, ALTURA_BARRA), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20 }, gui)

	-- Legenda: Merriweather itálico, centralizada logo acima da barra inferior.
	local tamanhoFala = math.clamp(math.floor(vy * 0.048), 20, 38)
	ui.fala = criar("TextLabel", { Name = "Legenda", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1 - ALTURA_BARRA, -vy * 0.03),
		Size = UDim2.fromScale(0.76, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "",
		FontFace = T.fontes.italico, TextSize = tamanhoFala, TextColor3 = cor.texto, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 25 }, gui)
	ui.falaContorno = criar("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Transparency = 1 }, ui.fala)
	ui.falaLimite = criar("UISizeConstraint", { MaxSize = Vector2.new(1100, math.huge) }, ui.fala)

	-- Título: MOSHOKU em Bodoni com fios dourados e a legenda de subtítulo.
	local tamanhoTitulo = math.clamp(math.floor(vy * 0.17), 56, 132)
	ui.titulo = criar("Frame", { Name = "Titulo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.9, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 30 }, gui)
	criar("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, math.floor(vy * 0.012)) }, ui.titulo)
	ui.fiosTitulo = {}
	local ornamento = function(ordem)
		local linha = criar("Frame", { Name = "Ornamento" .. ordem, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
			LayoutOrder = ordem, ZIndex = 30 }, ui.titulo)
		criar("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) }, linha)
		table.insert(ui.fiosTitulo, fio(linha, math.floor(vy * 0.42), -1, 1))
		ui.glifo = criar("TextLabel", { Name = "Glifo", Size = UDim2.fromOffset(34, 30), BackgroundTransparency = 1, Text = T.icone("run"),
			FontFace = T.FONTE_ICONE, TextSize = 28, TextColor3 = cor.ouroClaro, LayoutOrder = 2, ZIndex = 30 }, linha)
		table.insert(ui.fiosTitulo, fio(linha, math.floor(vy * 0.42), 1, 3))
		return ui.glifo
	end
	ui.glifoTopo = ornamento(1)
	ui.nome = criar("TextLabel", { Name = "Nome", Size = UDim2.new(1, 0, 0, tamanhoTitulo * 1.15), BackgroundTransparency = 1,
		Text = table.concat(string.split(Dados.TITULO.texto, ""), "\u{2009}"), FontFace = T.fontes.titulo, TextSize = tamanhoTitulo,
		TextColor3 = Color3.new(1, 1, 1), LayoutOrder = 2, ZIndex = 31 }, ui.titulo)
	criar("UIGradient", { Color = ColorSequence.new(cor.ouroClaro, cor.ouroEscuro), Rotation = 90 }, ui.nome)
	ui.nomeContorno = criar("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, ui.nome)
	ui.glifoBase = ornamento(3)
	ui.subtitulo = criar("TextLabel", { Name = "Subtitulo", Size = UDim2.new(1, 0, 0, math.clamp(math.floor(vy * 0.045), 22, 36)),
		BackgroundTransparency = 1, Text = Dados.TITULO.subtitulo, FontFace = T.fontes.subtitulo, TextSize = math.clamp(math.floor(vy * 0.04), 20, 32),
		TextColor3 = cor.titulo, LayoutOrder = 4, ZIndex = 31 }, ui.titulo)
	ui.subtituloContorno = criar("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, ui.subtitulo)
	return ui
end

-- Aplica a opacidade `a` (0..1) ao grupo do título.
local function opacidadeTitulo(ui, a: number)
	local t = 1 - a
	ui.titulo.Visible = a > 0.001
	ui.nome.TextTransparency = t
	ui.nomeContorno.Transparency = t
	ui.subtitulo.TextTransparency = t
	ui.subtituloContorno.Transparency = t
	ui.glifoTopo.TextTransparency = t
	ui.glifoBase.TextTransparency = t
	for _, f in ui.fiosTitulo do f.BackgroundTransparency = t end
end

local function aplicarTempo(ui, t: number)
	local barras = Dados.barrasEm(t)
	ui.barraSup.Position = UDim2.fromScale(0, -ALTURA_BARRA * (1 - barras))
	ui.barraInf.Position = UDim2.fromScale(0, 1 + ALTURA_BARRA * (1 - barras))
	ui.sombra.BackgroundTransparency = 1 - barras
	-- O botão e a dica moram na barra inferior e acompanham o movimento dela.
	local descida = ALTURA_BARRA * (1 - barras)
	if ui.botao then
		ui.botao.Position = UDim2.new(1, -20, 1 - ALTURA_BARRA / 2 + descida, 0)
		ui.dica.Position = UDim2.new(1, -(ui.botao.Size.X.Offset + 36), 1 - ALTURA_BARRA / 2 + descida, 0)
	end
	local fala, opacidade = Dados.falaEm(t)
	if fala then
		if ui.fala.Text ~= fala.texto then ui.fala.Text = fala.texto end
		ui.fala.TextTransparency = 1 - opacidade
		ui.falaContorno.Transparency = 1 - opacidade * 0.85
	else
		ui.fala.TextTransparency = 1
		ui.falaContorno.Transparency = 1
	end
	opacidadeTitulo(ui, Dados.tituloEm(t))
end

local function esconderOutrasInterfaces(minha: ScreenGui)
	local jogador = Players.LocalPlayer
	local pg = jogador:WaitForChild("PlayerGui")
	local ocultas = {}
	local function ocultar(g)
		if g:IsA("ScreenGui") and g ~= minha and g.Enabled and g.Name ~= "Carregamento" then
			ocultas[g] = true
			g.Enabled = false
		end
	end
	for _, g in pg:GetChildren() do ocultar(g) end
	local ligacao = pg.ChildAdded:Connect(function(g) task.defer(ocultar, g) end)
	return function()
		ligacao:Disconnect()
		for g in ocultas do
			if g.Parent then g.Enabled = true end
		end
	end
end

function CenaAbertura.ativa(): boolean
	return ativo ~= nil
end

function CenaAbertura.pular()
	if ativo and not ativo.pulou then
		ativo.pulou = true
		ativo.pulouEm = os.clock()
	end
end

function CenaAbertura.tocar(opcoes)
	if ativo then
		warn("[CenaAbertura] já há uma cena em curso")
		return false
	end
	opcoes = opcoes or {}
	local jogador = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local cameraMundo = opcoes.cameraMundo or require(script.Parent.CameraMundo)
	local velocidade = if opcoes.velocidade ~= nil then opcoes.velocidade else 1
	local estado = { t = opcoes.inicioEm or 0, pulou = false, pulouEm = 0, concluiu = false, fim = false }
	ativo = estado

	local gui = criar("ScreenGui", { Name = "CenaAbertura", DisplayOrder = 900, IgnoreGuiInset = true, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, jogador:WaitForChild("PlayerGui"))
	local vy = math.max(480, camera.ViewportSize.Y)
	local ui = construirInterface(gui, vy)
	ui.veu.BackgroundTransparency = 1 - Dados.veuEm(estado.t)

	local botao = Componentes.botao({ parent = gui, nome = "Pular", texto = "Pular", icone = "seta", variante = "fantasma",
		ancora = Vector2.new(1, 0.5), posicao = UDim2.new(1, -20, 1 - ALTURA_BARRA / 2, 0), tamanho = UDim2.fromOffset(150, 44), aoClicar = function() CenaAbertura.pular() end })
	botao.ZIndex = 40
	local dica = criar("TextLabel", { Name = "DicaPular", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(botao.Size.X.Offset + 36), 1 - ALTURA_BARRA / 2, 0),
		Size = UDim2.fromOffset(math.min(260, camera.ViewportSize.X - 150 - 64), 24), BackgroundTransparency = 1, Text = if UserInputService.TouchEnabled then "ou segure a tela" else "Espaço ou segure a tela",
		FontFace = T.fontes.corpo, TextSize = T.tamanhos.legenda, TextColor3 = cor.secundario, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 40 }, gui)
	dica.Visible = dica.Size.X.Offset >= 110
	ui.botao, ui.dica = botao, dica

	-- Entradas de pulo.
	local conexoes = {}
	ContextActionService:BindActionAtPriority(ACAO_PULAR, function(_, fase)
		if fase == Enum.UserInputState.Begin then CenaAbertura.pular() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	local segurando = nil
	table.insert(conexoes, ui.toque.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			segurando = os.clock()
		end
	end))
	table.insert(conexoes, ui.toque.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			segurando = nil
		end
	end))

	-- Dono da câmera e do personagem durante a cena.
	local fovAnterior = camera.FieldOfView
	local tipoAnterior = camera.CameraType
	cameraMundo.pausar(MOTIVO_CAMERA)
	camera.CameraType = Enum.CameraType.Scriptable
	BloqueioMovimento.definir(MOTIVO_CAMERA, true)
	local devolverInterface = if opcoes.esconderInterface == false then function() end else esconderOutrasInterfaces(gui)

	-- Fala com áudio (dublagem futura): toca uma vez, na primeira vez que a linha aparece.
	local tocouFala = {}
	local sons = {}
	local function tocarAudio(fala)
		if fala and fala.audio and not tocouFala[fala.chave] then
			tocouFala[fala.chave] = true
			local som = criar("Sound", { Name = fala.chave, SoundId = fala.audio, Volume = 1 }, gui)
			table.insert(sons, som)
			som:Play()
		end
	end

	local thread = coroutine.running()
	local esperando = true
	RunService:BindToRenderStep(PASSO_RENDER, PRIORIDADE, function(dt)
		if estado.fim then return end
		if segurando and os.clock() - segurando >= TOQUE_LONGO then
			segurando = nil
			CenaAbertura.pular()
		end
		if not estado.pulou then
			estado.t += dt * velocidade
			if estado.t >= Dados.DURACAO then
				estado.concluiu = true
				estado.fim = true
			end
		end
		local t = math.min(estado.t, Dados.DURACAO)
		local veu = Dados.veuEm(t)
		if estado.pulou then
			-- Pulo: o preto sobe em FADE_PULO s a partir do quadro em que estava.
			local k = math.clamp((os.clock() - estado.pulouEm) / FADE_PULO, 0, 1)
			veu = math.max(veu, k)
			if k >= 1 then estado.fim = true end
		end
		ui.veu.BackgroundTransparency = 1 - veu
		local p = Dados.amostrar(t)
		camera.CFrame = CFrame.lookAt(Vector3.new(p.x, p.y, p.z), Vector3.new(p.ax, p.ay, p.az))
		camera.FieldOfView = p.fov
		aplicarTempo(ui, t)
		tocarAudio((Dados.falaEm(t)))
		if estado.fim and esperando then
			esperando = false
			task.spawn(thread)
		end
	end)
	coroutine.yield()
	RunService:UnbindFromRenderStep(PASSO_RENDER)

	-- Sob o preto: devolve câmera, personagem, interface e controles.
	for _, c in conexoes do c:Disconnect() end
	ContextActionService:UnbindAction(ACAO_PULAR)
	for _, s in sons do s:Destroy() end
	ui.veu.BackgroundTransparency = 0
	BloqueioMovimento.definir(MOTIVO_CAMERA, false)
	devolverInterface()
	camera.FieldOfView = fovAnterior
	if camera.CameraType == Enum.CameraType.Scriptable and tipoAnterior ~= Enum.CameraType.Scriptable then
		camera.CameraType = tipoAnterior
	end
	cameraMundo.retomar(MOTIVO_CAMERA)
	botao.Visible, dica.Visible = false, false
	opacidadeTitulo(ui, 0)
	ui.fala.TextTransparency = 1
	ui.falaContorno.Transparency = 1
	ativo = nil
	local concluiu = estado.concluiu
	task.wait(PRETO_FINAL)
	-- Revela o jogo: preto some e as barras saem; a interface é destruída ao final.
	local info = TweenInfo.new(REVELAR, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(ui.veu, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(ui.barraSup, info, { Position = UDim2.fromScale(0, -ALTURA_BARRA) }):Play()
	TweenService:Create(ui.barraInf, info, { Position = UDim2.fromScale(0, 1 + ALTURA_BARRA) }):Play()
	TweenService:Create(ui.sombra, info, { BackgroundTransparency = 1 }):Play()
	task.delay(REVELAR + 0.1, function() gui:Destroy() end)
	return concluiu
end

return CenaAbertura
