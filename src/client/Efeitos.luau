-- Efeitos de apresentação (docs/VISUAL.md): dados 3D sobre o mapa, números
-- flutuantes de dano/cura e letreiro de turno. Nada aqui decide regra: tudo
-- reage a eventos que o servidor já confirmou. Peças são locais, nunca replicadas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MesaProtocol"))
local Dublagem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dublagem"))

local Efeitos = {}

-- Estética Livro Noite (Estilo): crítico no amarelo do capítulo 5, falha e dano
-- no vermelho do capítulo 4, cura no verde do capítulo 3, dado no papel escuro
-- com fio roxo (secreto: fio vermelho escuro).
local Estilo = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Estilo"))
local OURO = Estilo.ALERTA
local OURO_ESCURO = Estilo.DESTAQUE
local VINHO = Estilo.PERIGO
local VINHO_ESCURO = Estilo.misturar(Estilo.PERIGO, Estilo.PAPEL, 0.45)
local OLIVA = Estilo.SUCESSO
local PERGAMINHO = Estilo.TINTA
local TITULO = Estilo.GRITO

local folder: Folder
local overlay: ScreenGui
local activeDice = 0
local MAX_DICE = 6 -- rolagens em rajada não enchem a mesa de dados
local offsetBase=Vector3.zero
-- SalaCorpo escolhe o enquadramento; este módulo compõe com o tremor antes da câmera.
function Efeitos.offsetCamera(valor) offsetBase=valor end

function Efeitos.start()
	RunService:BindToRenderStep("MesaTremor", Enum.RenderPriority.Camera.Value - 1, function()
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.CameraOffset = offsetBase + Efeitos.tremorCFrame().Position
		end
	end)
	folder = Instance.new("Folder")
	folder.Name = "MesaEfeitosLocais"
	folder.Parent = workspace
	overlay = Instance.new("ScreenGui")
	overlay.Name = "MesaAvisos"
	overlay.ResetOnSpawn = false
	overlay.IgnoreGuiInset = true
	overlay.DisplayOrder = 5
	overlay.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = TITULO
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeColor3 = Estilo.SOBRE_COR
	l.TextStrokeTransparency = 0.2
	l.Parent = parent
	return l
end

local function ease(t: number): number
	return 1 - (1 - t) ^ 3
end

-- Número que sobe e some sobre um ponto do mapa (dano em vinho, cura em oliva).
function Efeitos.floatText(position: Vector3, text: string, color: Color3)
	if not folder then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 48)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local l = label(gui, text, 30, color)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / 1.4, 1)
		gui.StudsOffset = Vector3.new(0, 1 + ease(t) * 4, 0)
		l.TextTransparency = math.max(0, (t - 0.5) * 2)
		l.TextStrokeTransparency = 0.2 + math.max(0, (t - 0.5) * 1.6)
		if t >= 1 then
			connection:Disconnect()
			anchor:Destroy()
		end
	end)
end

-- Tremor de câmera (impactos). Na Visão da mesa o BoardView aplica
-- Efeitos.tremorCFrame() à câmera; fora dela, usa o CameraOffset do avatar.
local tremor = { fim = 0, inicio = 0, forca = 0 }
function Efeitos.tremer(forca: number, duracao: number?)
	local agora = os.clock()
	if agora > tremor.fim or forca > tremor.forca then
		tremor.inicio, tremor.fim, tremor.forca = agora, agora + (duracao or 0.3), forca
	end
end

function Efeitos.tremorCFrame(): CFrame
	local agora = os.clock()
	if agora >= tremor.fim then
		return CFrame.identity
	end
	local resto = (tremor.fim - agora) / math.max(tremor.fim - tremor.inicio, 1e-3)
	local f = tremor.forca * resto
	return CFrame.new(math.noise(agora * 40, 1) * f, math.noise(agora * 40, 2) * f, math.noise(agora * 40, 3) * f)
		* CFrame.Angles(0, 0, math.noise(agora * 30, 4) * f * 0.02)
end

-- Recuo de quem foi atingido: a miniatura dá um tranco na direção do golpe e volta.
local reacoes: { [string]: { inicio: number, direcao: Vector3 } } = {}
function Efeitos.reagir(tokenId: string, direcao: Vector3, forca: number?)
	local plana = Vector3.new(direcao.X, 0, direcao.Z)
	plana = if plana.Magnitude > 1e-3 then plana.Unit else Vector3.zero
	reacoes[tokenId] = { inicio = os.clock(), direcao = plana * (forca or 1.2) }
end

function Efeitos.deslocamentoDe(tokenId: string): Vector3
	local r = reacoes[tokenId]
	if not r then
		return Vector3.zero
	end
	local t = (os.clock() - r.inicio) / 0.45
	if t >= 1 then
		reacoes[tokenId] = nil
		return Vector3.zero
	end
	-- Sobe rápido, volta com um quique amortecido.
	local curva = math.sin(t * math.pi) * (1 - t) * 2.2
	return r.direcao * curva + Vector3.new(0, math.sin(t * math.pi) * 0.35, 0)
end

-- Fala dublada (docs/DUBLAGEM.md). Escolhe uma variante com ID cujo nome começa
-- por `prefixo`; sem áudio enviado, não toca nada. No máximo duas vozes ao mesmo tempo.
local falando = 0
function Efeitos.falar(prefixo: string, volume: number?): boolean
	local lista = Dublagem.variantes(prefixo)
	if #lista == 0 or falando >= 2 then
		return false
	end
	local chave = lista[math.random(#lista)]
	local som = Instance.new("Sound")
	som.Name = "Fala_" .. chave
	som.SoundId = Dublagem.IDS[chave]
	som.Volume = volume or 0.9
	som.Parent = game:GetService("SoundService")
	falando += 1
	local function fim()
		if som.Parent then
			falando -= 1
			som:Destroy()
		end
	end
	som.Ended:Connect(fim)
	task.delay((Dublagem.SEGUNDOS[chave] or 4) * 1.5 + 2, fim)
	som:Play()
	return true
end

function Efeitos.damageText(position: Vector3, delta: number)
	if delta ~= 0 then
		Efeitos.floatText(position, string.format("%+d", delta), if delta < 0 then VINHO else OLIVA)
	end
end

-- Letreiro no topo da tela ("Rodada 2 — vez de Kade").
local bannerToken = 0
function Efeitos.banner(text: string)
	if not overlay then
		return
	end
	bannerToken += 1
	local mine = bannerToken
	for _, old in overlay:GetChildren() do
		if old.Name == "Letreiro" then
			old:Destroy()
		end
	end
	local frame = Instance.new("Frame")
	frame.Name = "Letreiro"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -70)
	frame.Size = UDim2.fromOffset(460, 58)
	frame.BackgroundColor3 = Estilo.PAPEL_2
	frame.BackgroundTransparency = 0.12
	frame.Parent = overlay
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = OURO_ESCURO
	stroke.Thickness = 2
	stroke.Parent = frame
	label(frame, text, 26, OURO)
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 72),
	}):Play()
	task.delay(2.4, function()
		if mine ~= bannerToken or not frame.Parent then
			return
		end
		local out = TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -70),
		})
		out.Completed:Connect(function()
			frame:Destroy()
		end)
		out:Play()
	end)
end

-- Dado 3D: cai girando num ponto do mapa e para mostrando o resultado.
-- O número final é o d20 escolhido quando houver; senão, o total.
function Efeitos.dice(data)
	if not folder or activeDice >= MAX_DICE then
		return
	end
	activeDice += 1
	local board = Protocol.BOARD
	local spread = board.cell * 4
	local landing = board.origin + Vector3.new((math.random() - 0.5) * spread, 1.3, (math.random() - 0.5) * spread)
	if data.tokenId then
		-- Iniciativa: o dado cai ao lado da ficha que rolou, se ela estiver no mapa.
		local mini = workspace:FindFirstChild("MesaFichasLocais") and workspace.MesaFichasLocais:FindFirstChild(data.tokenId)
		if mini and mini:IsA("Model") then
			landing = mini:GetPivot().Position * Vector3.new(1, 0, 1) + Vector3.new(2.6, 1.3, -2.6)
		end
	end
	local color = if data.secret then VINHO_ESCURO else OURO_ESCURO
	local die = Instance.new("Part")
	die.Name = "Dado"
	die.Size = Vector3.one * 2.4
	die.Anchored, die.CanCollide, die.CanQuery = true, false, false
	die.Color = color
	die.Material = Enum.Material.SmoothPlastic
	die.Parent = folder
	local bevel = Instance.new("SpecialMesh")
	bevel.MeshType = Enum.MeshType.Brick
	bevel.Parent = die
	local faceGui = Instance.new("BillboardGui")
	faceGui.Size = UDim2.fromOffset(90, 60)
	faceGui.StudsOffset = Vector3.new(0, 2.6, 0)
	faceGui.AlwaysOnTop = true
	faceGui.Adornee = die
	faceGui.Parent = die
	local face = label(faceGui, "", 34, PERGAMINHO)
	local final = data.natural or data.total
	local sides = if data.natural then 20 else math.max(6, math.abs(final))

	local from = landing + Vector3.new(0, 9, 0)
	local spin = Vector3.new(math.random(5, 9), math.random(4, 8), math.random(5, 9)) * math.pi
	local duration = 1.05
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / duration, 1)
		-- Queda com um quique perto do fim; rotação desacelerando.
		local height = if t < 0.7 then (1 - (t / 0.7) ^ 2) * 9 else math.sin((t - 0.7) / 0.3 * math.pi) * 0.9
		local r = spin * (1 - (1 - t) ^ 2)
		die.CFrame = CFrame.new(landing + Vector3.new(0, height, 0)) * CFrame.Angles(r.X, r.Y, r.Z)
		if t < 1 then
			face.Text = tostring(math.random(1, sides))
			return
		end
		connection:Disconnect()
		die.CFrame = CFrame.new(landing) * CFrame.Angles(0, math.random() * math.pi, 0)
		face.Text = tostring(final)
		if data.critical == "sucesso" then
			face.TextColor3 = OURO
			die.Material = Enum.Material.Neon
			Efeitos.floatText(landing + Vector3.new(0, 3, 0), "CRÍTICO!", OURO)
		elseif data.critical == "falha" then
			face.TextColor3 = VINHO
			Efeitos.floatText(landing + Vector3.new(0, 3, 0), "FALHA", VINHO)
		end
		-- Total da rolagem (com modificadores) abaixo do número do dado.
		if data.natural and data.total ~= data.natural then
			local totalGui = Instance.new("BillboardGui")
			totalGui.Size = UDim2.fromOffset(160, 30)
			totalGui.StudsOffset = Vector3.new(0, 4.3, 0)
			totalGui.AlwaysOnTop = true
			totalGui.Adornee = die
			totalGui.Parent = die
			label(totalGui, (if data.label then data.label .. ": " else "") .. "total " .. data.total, 18, PERGAMINHO)
		end
		task.delay(2.6, function()
			local fade = TweenService:Create(die, TweenInfo.new(0.5), { Transparency = 1 })
			fade.Completed:Connect(function()
				die:Destroy()
				activeDice -= 1
			end)
			fade:Play()
			for _, gui in die:GetChildren() do
				if gui:IsA("BillboardGui") then
					gui.Enabled = false
				end
			end
		end)
	end)
end

return Efeitos
