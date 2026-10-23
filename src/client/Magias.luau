-- Animações das habilidades. Só apresentação: cada receita toca o RECIBO que o
-- servidor mandou depois de resolver (evento "efeito"); nada aqui decide acerto,
-- dano ou condição. Peças, luzes, partículas e texturas NATIVAS do Roblox
-- (rbxasset://textures/particles), sem assets enviados (docs/VISUAL.md).
--
-- Etapas de uma magia (PLANO §6): círculo mágico e encantamento sob/sobre quem
-- conjura, preparação, lançamento, trajetória com rastro, impacto (acerto,
-- crítico ou erro) com tremor de câmera e recuo do alvo. Estados que duram (Em
-- Chamas, Muro de Chamas) são desenhados pelo BoardView a partir do snapshot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Protocol = require(Shared:WaitForChild("MesaProtocol"))
local Estilo = require(Shared:WaitForChild("Estilo"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))

local Coreografia = require(script.Parent:WaitForChild("Coreografia"))
local Sonorizacao = require(script.Parent:WaitForChild("Sonorizacao"))
local Magias = {}

local FOGO = Estilo.arvore("fogo").cor
local OURO = Estilo.ALERTA
local BRANCO_QUENTE = Color3.fromRGB(255, 244, 214)
local TEXTURA = {
	fogo = "rbxasset://textures/particles/fire_main.dds",
	fumaca = "rbxasset://textures/particles/smoke_main.dds",
	brilho = "rbxasset://textures/particles/sparkles_main.dds",
}

function Magias.start(state, opcoes)
opcoes = opcoes or {}
-- Cada consumidor tem seu próprio ciclo de vida: mesa e exploração não compartilham cenas.
local pasta: Folder
local encerrado, geracaoVisual = false, 0
local tarefas, conexoes = {}, {}
local function agendar(segundos, callback)
 local geracao, tarefa = geracaoVisual, nil
 tarefa = task.delay(segundos, function()
  tarefas[tarefa] = nil
  if not encerrado and geracao == geracaoVisual then callback() end
 end)
 tarefas[tarefa] = true
 return tarefa
end
local function conectar(sinal, callback)
 local c = sinal:Connect(callback)
 conexoes[c] = true
 return c
end
local centroCasa = state.posicaoCasa or Protocol.cellCenter
local tamanhoCasa = state.tamanhoCasa or Protocol.BOARD.cell
local geracaoSonora = 0
local geracoesDosRecibos = setmetatable({}, { __mode = "k" })
local function somDoRecibo(recibo, chave: string, duracao: number?)
	-- Uma receita com task.delay não pode reabrir áudio depois do fim do combate.
	if geracoesDosRecibos[recibo] == geracaoSonora then
		Sonorizacao.tocar(chave, duracao)
	end
end

-- Peças e partículas -------------------------------------------------------

local function peca(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in props do
		p[k] = v
	end
	p.Parent = pasta
	return p
end

local function bola(cor: Color3, tamanho: number, posicao: Vector3, transparencia: number?): Part
	return peca({ Shape = Enum.PartType.Ball, Color = cor, Size = Vector3.one * tamanho, Position = posicao, Transparency = transparencia or 0 })
end

local function luz(parent: Instance, cor: Color3, alcance: number, brilho: number): PointLight
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = cor, alcance, brilho, false
	l.Parent = parent
	return l
end

-- Emissor com textura nativa. tipo: "fogo" | "fumaca" | "brilho".
local function emissor(parent: Instance, tipo: string, cor: Color3, opcoes: { [string]: any }?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEXTURA[tipo]
	e.Color = ColorSequence.new(cor, if tipo == "fumaca" then Estilo.TINTA_SUAVE else OURO)
	e.LightEmission = if tipo == "fumaca" then 0 else 1
	e.LightInfluence = if tipo == "fumaca" then 0.6 else 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.7)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rate = 0
	e.Drag = 2
	for k, v in opcoes or {} do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function sumir(objeto: BasePart, duracao: number, crescer: number?)
	local alvo = { Transparency = 1 }
	if crescer then
		alvo.Size = objeto.Size * crescer
	end
	TweenService:Create(objeto, TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), alvo):Play()
	agendar(duracao + 1.5, function()
		objeto:Destroy()
	end)
end

-- Rastro de luz entre dois pontos de um projétil.
local function rastro(projetil: BasePart, cor: Color3, largura: number)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, largura / 2, 0), Vector3.new(0, -largura / 2, 0)
	a0.Parent, a1.Parent = projetil, projetil
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(OURO, cor)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime = 0.25
	t.LightEmission = 1
	t.FaceCamera = true
	t.Parent = projetil
	return t
end

-- Onde está a ficha: o avatar do dono (se é avatar) ou a miniatura.
local function posicaoDe(state, tokenId: string?, fallback: { number }?): Vector3
	if state.posicaoDe then return state.posicaoDe(tokenId, fallback) end
	local token = tokenId and state.findToken(tokenId)
	if token and token.avatar then
		local dono = Players:GetPlayerByUserId(token.ownerUserId)
		local root = dono and dono.Character and dono.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root.Position + Vector3.new(0, 1, 0)
		end
	end
	local minis = workspace:FindFirstChild("MesaFichasLocais")
	local mini = tokenId and minis and minis:FindFirstChild(tokenId)
	if mini and mini:IsA("Model") then
		return mini:GetPivot().Position + Vector3.new(0, 3, 0)
	end
	if token then
		return Protocol.cellCenter(token.x, token.z) + Vector3.new(0, 3, 0)
	end
	if fallback then
		return Protocol.cellCenter(fallback[1], fallback[2]) + Vector3.new(0, 3, 0)
	end
	return Protocol.BOARD.origin
end

local function chao(posicao: Vector3): Vector3
	if state.chao then return state.chao(posicao) end
	return Vector3.new(posicao.X, Protocol.BOARD.origin.Y, posicao.Z)
end

local function voar(objeto: BasePart, de: Vector3, para: Vector3, duracao: number, altura: number, aoChegar: () -> ())
	local inicio = os.clock()
	local conexao
	conexao = conectar(RunService.RenderStepped, function()
		local t = math.min((os.clock() - inicio) / duracao, 1)
		local p = de:Lerp(para, t) + Vector3.new(0, math.sin(math.pi * t) * altura, 0)
		objeto.CFrame = CFrame.lookAt(p, p + (para - de))
		if t >= 1 then
			conexao:Disconnect()
			aoChegar()
		end
	end)
end

-- Círculo mágico ---------------------------------------------------------------

-- Sob quem conjura: dois anéis, o selo da árvore no centro e oito selos em volta,
-- girando. Vale para qualquer árvore (cor e selo vêm da identidade do livro).
local function circuloMagico(posicao: Vector3, cor: Color3, selo: string, duracao: number)
	local base = peca({ Size = Vector3.new(11, 0.05, 11), Position = chao(posicao) + Vector3.new(0, 0.12, 0), Transparency = 1 })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = base
	local raiz = Instance.new("Frame")
	raiz.BackgroundTransparency = 1
	raiz.Size = UDim2.fromScale(1, 1)
	raiz.Parent = gui
	local function anel(escala: number, espessura: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(escala, escala)
		f.BackgroundTransparency = 1
		local canto = Instance.new("UICorner")
		canto.CornerRadius = UDim.new(1, 0)
		canto.Parent = f
		local traco = Instance.new("UIStroke")
		traco.Color, traco.Thickness, traco.Transparency = cor, espessura, 0.15
		traco.Parent = f
		f.Parent = raiz
		return f, traco
	end
	local _, t1 = anel(0.96, 6)
	local _, t2 = anel(0.72, 3)
	local centro = Instance.new("TextLabel")
	centro.AnchorPoint = Vector2.new(0.5, 0.5)
	centro.Position = UDim2.fromScale(0.5, 0.5)
	centro.Size = UDim2.fromScale(0.42, 0.42)
	centro.BackgroundTransparency = 1
	centro.TextScaled = true
	centro.FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold)
	centro.Text = selo
	centro.TextColor3 = cor
	centro.TextTransparency = 0.1
	centro.Parent = raiz
	local runas = {}
	for i = 0, 7 do
		local angulo = i * math.pi / 4
		local r = Instance.new("TextLabel")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5 + math.cos(angulo) * 0.42, 0.5 + math.sin(angulo) * 0.42)
		r.Size = UDim2.fromScale(0.1, 0.1)
		r.BackgroundTransparency = 1
		r.TextScaled = true
		r.FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold)
		r.Text = if i % 2 == 0 then selo else Estilo.ESTRELA
		r.TextColor3 = cor
		r.Rotation = math.deg(angulo) + 90
		r.Parent = raiz
		table.insert(runas, r)
	end
	luz(base, cor, 14, 1.6)
	-- Entra crescendo, gira, sai apagando.
	raiz.Size = UDim2.fromScale(0.2, 0.2)
	raiz.Position = UDim2.fromScale(0.4, 0.4)
	TweenService:Create(raiz, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }):Play()
	local inicio = os.clock()
	local conexao
	conexao = conectar(RunService.RenderStepped, function()
		local t = os.clock() - inicio
		base.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, t * 1.4, 0)
		if t > duracao then
			conexao:Disconnect()
			for _, item in { centro, table.unpack(runas) } do
				TweenService:Create(item, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
			TweenService:Create(t1, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			TweenService:Create(t2, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			agendar(0.5, function()
				base:Destroy()
			end)
		end
	end)
end

-- Encantamento do livro sobre quem conjura, com a última linha gritada.
local function encantamento(posicao: Vector3, textoCompleto: string?, cor: Color3)
	if not textoCompleto then
		return
	end
	local ancora = peca({ Size = Vector3.one, Position = posicao + Vector3.new(0, 4.5, 0), Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(440, 116)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = ancora
	local linhas = string.split(textoCompleto, "\n")
	local grito = table.remove(linhas)
	local corpo = Instance.new("TextLabel")
	corpo.BackgroundTransparency = 1
	corpo.Size = UDim2.new(1, 0, 0, 66)
	corpo.FontFace = Estilo.ELEGANTE
	corpo.TextSize = 14
	corpo.TextWrapped = true
	corpo.TextColor3 = Estilo.TINTA
	corpo.TextStrokeColor3 = Estilo.SOBRE_COR
	corpo.TextStrokeTransparency = 0.25
	corpo.TextYAlignment = Enum.TextYAlignment.Bottom
	corpo.Text = table.concat(linhas, " ")
	corpo.MaxVisibleGraphemes = 0
	corpo.Parent = gui
	local fala = Instance.new("TextLabel")
	fala.BackgroundTransparency = 1
	fala.Position = UDim2.fromOffset(0, 66)
	fala.Size = UDim2.new(1, 0, 0, 40)
	fala.FontFace = Estilo.GRITO
	fala.TextSize = 32
	fala.TextColor3 = cor
	fala.TextStrokeColor3 = Estilo.SOBRE_COR
	fala.TextStrokeTransparency = 0.05
	fala.Text = Estilo.maiusculas(grito or "")
	fala.TextTransparency = 1
	fala.Parent = gui
	local total = utf8.len(corpo.Text) or 200
	local inicio = os.clock()
	local conexao
	conexao = conectar(RunService.RenderStepped, function()
		local t = math.min((os.clock() - inicio) / 0.7, 1)
		corpo.MaxVisibleGraphemes = math.floor(total * t)
		if t >= 1 then
			conexao:Disconnect()
		end
	end)
	agendar(0.55, function()
		somDoRecibo(recibo, "fogo")
		fala.TextTransparency = 0
		fala.TextSize = 48
		TweenService:Create(fala, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = 32 }):Play()
	end)
	agendar(2.3, function()
		TweenService:Create(corpo, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(fala, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		agendar(0.6, function()
			ancora:Destroy()
		end)
	end)
end

-- Gesto de conjurar: o avatar aponta (emote "point" do próprio Animate); a
-- miniatura dá um pulinho no lugar.
local function gesto(state, tokenId: string?, alvo: Vector3?)
	local token = tokenId and state.findToken(tokenId)
	if not token then
		return
	end
	if not token.avatar then
		Efeitos.reagir(tokenId, if alvo then alvo - posicaoDe(state, tokenId) else Vector3.zero, 0.4)
		return
	end
	local dono = Players:GetPlayerByUserId(token.ownerUserId)
	local character = dono and dono.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = character and character:FindFirstChild("Animate")
	local point = animate and animate:FindFirstChild("point")
	local animacao = point and point:FindFirstChildOfClass("Animation")
	if animator and animacao then
		local ok, trilha = pcall(function()
			return animator:LoadAnimation(animacao)
		end)
		if ok and trilha then
			trilha.Priority = Enum.AnimationPriority.Action
			trilha:Play(0.1)
			agendar(1.2, function()
				trilha:Stop(0.3)
			end)
		end
	end
end

-- Impacto --------------------------------------------------------------------

local function queimado(posicao: Vector3, raio: number)
	local mancha = peca({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = Estilo.MESA_FUNDO,
		Size = Vector3.new(0.06, raio * 2, raio * 2),
		CFrame = CFrame.new(chao(posicao) + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.25,
	})
	agendar(1.5, function()
		sumir(mancha, 2.5)
	end)
end

local function fumaca(posicao: Vector3, quanto: number)
	local suporte = peca({ Size = Vector3.one * 0.2, Position = posicao, Transparency = 1 })
	local e = emissor(suporte, "fumaca", Estilo.TINTA_SUAVE, {
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, quanto * 0.6), NumberSequenceKeypoint.new(1, quanto * 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 4, 0),
	})
	e:Emit(math.floor(6 + quanto * 2))
	agendar(3, function()
		suporte:Destroy()
	end)
end

local function explosao(posicao: Vector3, cor: Color3, raio: number, critico: boolean?)
	local nucleo = bola(BRANCO_QUENTE, raio * 0.5, posicao)
	luz(nucleo, cor, raio * 7, if critico then 9 else 6)
	sumir(nucleo, if critico then 0.5 else 0.3, 2.2)
	local onda = bola(cor, raio * 0.7, posicao, 0.25)
	sumir(onda, 0.5, if critico then 4.5 else 3.3)
	local anel = peca({
		Shape = Enum.PartType.Cylinder,
		Color = OURO,
		Size = Vector3.new(0.15, raio, raio),
		CFrame = CFrame.new(chao(posicao) + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.15,
	})
	TweenService:Create(anel, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, raio * 5.5, raio * 5.5), Transparency = 1 }):Play()
	agendar(1.2, function()
		anel:Destroy()
	end)
	local suporte = peca({ Size = Vector3.one * 0.2, Position = posicao, Transparency = 1 })
	local chamas = emissor(suporte, "fogo", cor, {
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, raio * 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Speed = NumberRange.new(raio * 2, raio * 4),
		Lifetime = NumberRange.new(0.35, 0.7),
	})
	chamas:Emit(if critico then 40 else 24)
	local faiscas = emissor(suporte, "brilho", OURO, {
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Speed = NumberRange.new(raio * 4, raio * 8),
		Lifetime = NumberRange.new(0.4, 0.9),
		Acceleration = Vector3.new(0, -25, 0),
	})
	faiscas:Emit(if critico then 50 else 26)
	agendar(2, function()
		suporte:Destroy()
	end)
	fumaca(posicao, raio * 0.6)
	queimado(posicao, raio * 0.8)
	Efeitos.tremer(if critico then 1.1 else 0.45, if critico then 0.5 else 0.3)
end

local function veredito(posicao: Vector3, alvo)
	if alvo.critico then
		Efeitos.floatText(posicao + Vector3.new(0, 4, 0), "CRÍTICO!", OURO)
	elseif alvo.acertou == false then
		Efeitos.floatText(posicao + Vector3.new(0, 4, 0), if alvo.natural == 1 then "FALHA" else "ERROU", Estilo.TINTA_SUAVE)
	elseif alvo.passou == true then
		Efeitos.floatText(posicao + Vector3.new(0, 4, 0), "RESISTIU", Estilo.TINTA_SUAVE)
	end
end

local function recuo(state, alvoId: string, de: Vector3, forca: number)
	Efeitos.reagir(alvoId, posicaoDe(state, alvoId) - de, forca)
end

-- Receitas ---------------------------------------------------------------

local RECEITAS = {}

-- Ponto à frente de quem conjura, na direção do alvo: a magia nasce na mão, não
-- dentro da cabeça.
local function aFrente(de: Vector3, para: Vector3, distancia: number): Vector3
	local d = Vector3.new(para.X - de.X, 0, para.Z - de.Z)
	return if d.Magnitude > 1e-3 then de + d.Unit * distancia else de
end

-- Brasa: a fagulha salta da mão em arco curto, com rastro, e estala no alvo.
RECEITAS["ability/fogo/Principiante/brasa"] = function(state, recibo)
	local de = posicaoDe(state, recibo.casterId, recibo.origem)
	local alvo = recibo.alvos[1]
	if not alvo then
		return
	end
	local para = posicaoDe(state, alvo.id)
	de = aFrente(de, para, 1.8)
	if alvo.acertou == false then
		para += Vector3.new(3, -2.5, 2)
	end
	agendar(0.55, function()
		local brasa = bola(FOGO, 1.4, de)
		luz(brasa, FOGO, 18, 3)
		rastro(brasa, FOGO, 1.2)
		local e = emissor(brasa, "fogo", FOGO, { Rate = 60, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }) })
		voar(brasa, de, para, 0.4, 3.5, function()
			somDoRecibo(recibo, "fogo-impacto", 1.5)
			e.Enabled = false
			brasa.Transparency = 1
			if alvo.acertou ~= false then
				explosao(para, FOGO, 2.8, alvo.critico)
				recuo(state, alvo.id, de, 1)
			else
				fumaca(para, 1.5)
			end
			veredito(para, alvo)
			agendar(1, function()
				brasa:Destroy()
			end)
		end)
	end)
end

-- Bola de Fogo: a esfera cresce na mão entre chamas, parte reta com rastro e explode.
RECEITAS["ability/fogo/Principiante/bola-de-fogo"] = function(state, recibo)
	local de = posicaoDe(state, recibo.casterId, recibo.origem) + Vector3.new(0, 1.5, 0)
	local alvo = recibo.alvos[1]
	if not alvo then
		return
	end
	local para = posicaoDe(state, alvo.id)
	de = aFrente(de - Vector3.new(0, 0.9, 0), para, 3)
	if alvo.acertou == false then
		para += (para - de).Unit * 7 - Vector3.new(0, 2.5, 0)
	end
	local esfera = bola(FOGO, 0.3, de)
	local nucleo = bola(BRANCO_QUENTE, 0.15, de)
	local chamas = emissor(esfera, "fogo", FOGO, {
		Rate = 80,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) }),
		Speed = NumberRange.new(0.5, 2),
		Lifetime = NumberRange.new(0.3, 0.55),
	})
	local l = luz(esfera, FOGO, 26, 3.5)
	-- Partículas convergindo para a mão na carga.
	local suga = emissor(esfera, "brilho", OURO, { Rate = 50, Speed = NumberRange.new(-10, -6), Lifetime = NumberRange.new(0.3, 0.4) })
	TweenService:Create(esfera, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 3.2 }):Play()
	TweenService:Create(nucleo, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 1.8 }):Play()
	agendar(0.8, function()
		somDoRecibo(recibo, "fogo")
		suga.Enabled = false
		nucleo:Destroy()
		rastro(esfera, FOGO, 3)
		Efeitos.tremer(0.2, 0.15)
		voar(esfera, de, para, 0.3, 0.6, function()
			somDoRecibo(recibo, "fogo-impacto", 1.5)
			chamas.Enabled = false
			l.Enabled = false
			esfera.Transparency = 1
			explosao(para, FOGO, if alvo.critico then 6.5 else 5, alvo.critico)
			if alvo.acertou ~= false then
				recuo(state, alvo.id, de, if alvo.critico then 2.4 else 1.6)
			end
			veredito(para, alvo)
			agendar(1.2, function()
				esfera:Destroy()
			end)
		end)
	end)
end

-- Fagulha: um estalo de dedo; um ponto de calor acende na casa escolhida.
RECEITAS["ability/fogo/Principiante/fagulha"] = function(state, recibo)
	local centro = recibo.centro
	if not centro then
		return
	end
	local ponto = centroCasa(centro[1], centro[2]) + Vector3.new(0, 0.8, 0)
	agendar(0.5, function()
		local faisca = bola(OURO, 1, ponto)
		somDoRecibo(recibo, "fogo", 1.5)
		local l = luz(faisca, FOGO, 14, 5)
		local e = emissor(faisca, "brilho", FOGO, { Speed = NumberRange.new(4, 9), Lifetime = NumberRange.new(0.3, 0.6) })
		e:Emit(30)
		local chama = emissor(faisca, "fogo", FOGO, { Rate = 25, Speed = NumberRange.new(1, 2), Acceleration = Vector3.new(0, 6, 0) })
		TweenService:Create(l, TweenInfo.new(1.4), { Brightness = 0 }):Play()
		agendar(1, function()
			chama.Enabled = false
		end)
		sumir(faisca, 1.4, 0.3)
	end)
end

-- Toque Escaldante: quem conjura avança, a mão incandesce e o calor explode no alvo.
RECEITAS["ability/fogo/Principiante/toque-escaldante"] = function(state, recibo)
	local de = posicaoDe(state, recibo.casterId, recibo.origem)
	local alvo = recibo.alvos[1]
	if not alvo then
		return
	end
	local para = posicaoDe(state, alvo.id)
	local mao = bola(FOGO, 1.2, de + (para - de) * 0.3)
	luz(mao, FOGO, 12, 4)
	local e = emissor(mao, "fogo", FOGO, { Rate = 50, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }) })
	TweenService:Create(mao, TweenInfo.new(0.45), { Size = Vector3.one * 2.6, Color = BRANCO_QUENTE }):Play()
	agendar(0.5, function()
		if recibo.casterId then
			Efeitos.reagir(recibo.casterId, para - de, 2)
		end
	end)
	agendar(0.62, function()
		if alvo.acertou ~= false then somDoRecibo(recibo, "fogo-impacto", 1.5) end
		e.Enabled = false
		mao:Destroy()
		if alvo.acertou ~= false then
			explosao(para, Estilo.PERIGO, 3.4, alvo.critico)
			fumaca(para, 2.5)
			recuo(state, alvo.id, de, 2)
		else
			fumaca(para - Vector3.new(0, 1, 0), 1.2)
		end
		veredito(para, alvo)
	end)
end

-- Muro de Chamas: uma linha de ignição corre pelas casas; o muro sobe no BoardView.
RECEITAS["ability/fogo/Principiante/muro-de-chamas"] = function(_, recibo)
	agendar(0.4, function() somDoRecibo(recibo, "fogo") end)
	for i, casa in recibo.casas or {} do
		agendar(0.35 + i * 0.07, function()
			local p = centroCasa(casa[1], casa[2]) + Vector3.new(0, 0.4, 0)
			local chispa = bola(OURO, 2, p)
			luz(chispa, FOGO, 12, 2.5)
			local e = emissor(chispa, "fogo", FOGO, { Speed = NumberRange.new(6, 12), Acceleration = Vector3.new(0, 20, 0), SpreadAngle = Vector2.new(25, 25) })
			e:Emit(16)
			sumir(chispa, 0.5, 2.5)
		end)
	end
	agendar(0.4, function()
		Efeitos.tremer(0.35, 0.6)
	end)
end

-- Clarão: a luz estoura em esfera; um anel varre o chão; lampejo na tela de quem está perto.
RECEITAS["ability/fogo/Principiante/clarao"] = function(state, recibo)
	local centro = if recibo.centro then centroCasa(recibo.centro[1], recibo.centro[2]) + Vector3.new(0, 3, 0) else posicaoDe(state, recibo.casterId, recibo.origem)
	local raio = 4 * tamanhoCasa
	agendar(0.4, function()
		local esfera = bola(BRANCO_QUENTE, 2, centro, 0.05)
		somDoRecibo(recibo, "brilho", 1.5)
		local l = luz(esfera, BRANCO_QUENTE, raio * 2, 14)
		TweenService:Create(esfera, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * raio * 2, Transparency = 1 }):Play()
		TweenService:Create(l, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		local anel = peca({
			Shape = Enum.PartType.Cylinder,
			Color = BRANCO_QUENTE,
			Size = Vector3.new(0.1, 2, 2),
			CFrame = CFrame.new(chao(centro) + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.1,
		})
		TweenService:Create(anel, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, raio * 2, raio * 2), Transparency = 1 }):Play()
		local e = emissor(esfera, "brilho", BRANCO_QUENTE, { Speed = NumberRange.new(15, 30), Lifetime = NumberRange.new(0.3, 0.6) })
		e:Emit(60)
		agendar(1.4, function()
			esfera:Destroy()
			anel:Destroy()
		end)
		for _, alvo in recibo.alvos do
			local p = posicaoDe(state, alvo.id)
			veredito(p, alvo)
			if alvo.aplica == "cego" then
				Efeitos.floatText(p + Vector3.new(0, 6, 0), "CEGO", Estilo.TINTA)
				recuo(state, alvo.id, centro, 0.7)
			end
		end
		Efeitos.tremer(0.3, 0.25)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - centro).Magnitude < raio * 3 then
			local lampejo = Instance.new("ColorCorrectionEffect")
			lampejo.Brightness = 0.15
			lampejo.Contrast = -0.25
			lampejo.Parent = Lighting
			TweenService:Create(lampejo, TweenInfo.new(0.75, Enum.EasingStyle.Quad), { Brightness = 0, Contrast = 0 }):Play()
			agendar(0.9, function()
				lampejo:Destroy()
			end)
		end
	end)
end

-- Em Chamas no início do turno: o fogo do alvo dá um salto.
RECEITAS["em-chamas"] = function(state, recibo)
	local alvo = recibo.alvos[1]
	if alvo then
		local p = posicaoDe(state, alvo.id)
		explosao(p, FOGO, 2.2)
		Efeitos.reagir(alvo.id, Vector3.new(0, 0, 0), 0)
	end
end

RECEITAS["atravessar-muro"] = function(state, recibo)
	local alvo = recibo.alvos[1]
	if alvo then
		explosao(posicaoDe(state, alvo.id), FOGO, 3.6)
	end
end

RECEITAS["apagar-fogo"] = function(state, recibo)
	local alvo = recibo.alvos[1]
	if alvo then
		local p = posicaoDe(state, alvo.id)
		fumaca(p - Vector3.new(0, 2, 0), 3)
		Efeitos.floatText(p + Vector3.new(0, 4, 0), if alvo.passou then "APAGOU" else "AINDA QUEIMA", if alvo.passou then Estilo.TINTA else FOGO)
	end
end

-- Entrada ------------------------------------------------------------------

-- Efeitos sem receita ficam discretos; nunca herdam partículas de fogo.
local function reserva(state, recibo, cor: Color3)
	for _, alvo in recibo.alvos or {} do
		veredito(posicaoDe(state, alvo.id, alvo.casa), alvo)
	end
end

local function arvoreDe(habilidadeId: any): string?
	return if type(habilidadeId) == "string" then string.match(habilidadeId, "^%a+/([^/]+)/") else nil
end

-- Fala dublada do recibo: quem age fala (gritos/nome da magia) e quem apanha
-- reage, mas só os personagens deste jogador; inimigos não têm voz humana.
local function falarDoEfeito(state, recibo)
	local meu = Players.LocalPlayer.UserId
	local function dono(id)
		local token = id and state.findToken(id)
		return token ~= nil and token.ownerUserId == meu
	end
	local id = recibo.habilidadeId
	if recibo.casterId and dono(recibo.casterId) and type(id) == "string" then
		local arv, tec = string.match(id, "^ability/([^/]+)/[^/]+/([^/]+)$")
		if not arv then
			tec = string.match(id, "^mesa/(.+)$")
			arv = tec and "mesa"
		end
		if arv and tec then
			local base = arv .. "__" .. tec
			local _ = Efeitos.falar("nome__" .. base) or Efeitos.falar("cantico__" .. base) or Efeitos.falar("grito__" .. base)
		end
	end
	for _, alvo in recibo.alvos or {} do
		if alvo.id ~= recibo.casterId and dono(alvo.id) then
			if alvo.acertou == false or alvo.passou then
				Efeitos.falar("geral__esquiva")
			elseif (alvo.dano or 0) > 0 then
				Efeitos.falar(if alvo.critico then "geral__dor-forte" else "geral__dor-leve")
			elseif (alvo.cura or 0) > 0 then
				Efeitos.falar("geral__cura-recebida")
			end
		end
	end
end

	pasta = Instance.new("Folder")
	pasta.Name = opcoes.nomePasta or "MagiasLocais"
	pasta.Parent = workspace
	local coreografia = Coreografia.start(state, pasta, posicaoDe, chao, centroCasa)
	local function limpar()
		geracaoVisual += 1
		geracaoSonora += 1
		for tarefa in tarefas do pcall(task.cancel, tarefa) end
		table.clear(tarefas)
		for c in conexoes do c:Disconnect() end
		table.clear(conexoes)
		coreografia.limpar()
		pasta:ClearAllChildren()
		Sonorizacao.limpar()
	end
	local ativo = false
	state.onSnapshot(function(snapshot)
		if encerrado then return end
		local agora = snapshot.combat and snapshot.combat.active == true
		if ativo and not agora then
			limpar()
		end
		ativo = agora
	end)

	state.onEfeito(function(recibo)
		if encerrado then return end
		geracoesDosRecibos[recibo] = geracaoSonora
		local id = recibo.habilidadeId
		local identidade = Estilo.arvore(arvoreDe(id))
		if recibo.casterId and recibo.encantamento then
			local posicao = posicaoDe(state, recibo.casterId, recibo.origem)
			local alvo = recibo.alvos[1] and posicaoDe(state, recibo.alvos[1].id)
			if RECEITAS[id] then circuloMagico(posicao, identidade.cor, if identidade.selo ~= "" then identidade.selo else Estilo.ESTRELA, 1.3) end
			encantamento(posicao, recibo.encantamento, identidade.cor)
			gesto(state, recibo.casterId, alvo)
		end
		falarDoEfeito(state, recibo)
		local receita = RECEITAS[id]
		if receita and recibo.casterId then coreografia.gesto(recibo) end
		local ok, erro = pcall(function()
			if receita then
				receita(state, recibo)
			elseif not coreografia.tocar(recibo) then
				reserva(state, recibo, identidade.cor)
			end
		end)
		if not ok then
			warn("[Magias] receita falhou:", id, erro)
		end
	end)
	return {
		limpar = limpar,
		destruir = function()
			if encerrado then return end
			limpar(); encerrado = true; coreografia.destruir(); pasta:Destroy()
		end,
		pasta = pasta,
	}
end

return Magias
