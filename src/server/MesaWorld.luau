-- Cenário estático: o livro aberto sobre a mesa quadriculada, à noite (estética
-- "Livro Noite", pedido do Pedro em 09/10/2026; docs/VISUAL.md). O tabuleiro é a
-- página escura com a grade em tinta; na borda, as abas coloridas dos capítulos;
-- na página, o "caos" do livro em marca-d'água; em volta, no escuro, os selos das
-- árvores flutuam (o cliente os anima: atributo "Selo", ver Ambiente).
-- Fichas não ficam aqui: cada cliente desenha as que pode ver.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.MesaProtocol)
local Estilo = require(ReplicatedStorage.Shared.Estilo)
local Identidade = require(ReplicatedStorage.Shared.Livro.Identidade)

local World = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		p[key] = value
	end
	return p
end

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- Texto da marca-d'água: kanji, estrelas e números vazados.
local function marca(parent: Instance, props: { [string]: any }): TextLabel
	local label = new("TextLabel", nil, {
		BackgroundTransparency = 1,
		TextScaled = true,
		FontFace = Estilo.GRITO,
		TextColor3 = Estilo.TINTA,
		TextTransparency = 0.9,
	})
	for key, value in props do
		label[key] = value
	end
	label.Parent = parent
	return label
end

-- Faixa de listras diagonais, como os rótulos "LEIA ISTO" do livro.
local function listras(parent: Instance, position: UDim2, size: UDim2, color: Color3, transparency: number)
	local faixa = new("Frame", parent, {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})
	for i = 0, 40 do
		new("Frame", faixa, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, i * 26, 0.5, 0),
			Size = UDim2.new(0, 9, 3, 0),
			Rotation = 35,
			BorderSizePixel = 0,
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
		})
	end
end

-- Contorno de um d20 (hexágono com o triângulo da face), em fios.
local function d20(parent: Instance, center: Vector2, raio: number, color: Color3, transparency: number)
	local function fio(a: Vector2, b: Vector2)
		local meio = (a + b) / 2
		local delta = b - a
		new("Frame", parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(meio.X, meio.Y),
			Size = UDim2.fromOffset(delta.Magnitude, 4),
			Rotation = math.deg(math.atan2(delta.Y, delta.X)),
			BorderSizePixel = 0,
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
		})
	end
	local vertices = {}
	for i = 0, 5 do
		local angulo = math.rad(60 * i - 90)
		table.insert(vertices, center + Vector2.new(math.cos(angulo), math.sin(angulo)) * raio)
	end
	for i = 1, 6 do
		fio(vertices[i], vertices[i % 6 + 1])
	end
	-- Face da frente: triângulo apontado para cima, ligado aos vértices.
	local topo = center + Vector2.new(0, -raio * 0.5)
	local esquerda = center + Vector2.new(-raio * 0.45, raio * 0.3)
	local direita = center + Vector2.new(raio * 0.45, raio * 0.3)
	fio(topo, esquerda)
	fio(esquerda, direita)
	fio(direita, topo)
	fio(topo, vertices[1])
	fio(esquerda, vertices[5])
	fio(esquerda, vertices[4])
	fio(direita, vertices[3])
	fio(direita, vertices[4])
	fio(topo, vertices[6])
	fio(topo, vertices[2])
end

-- O "caos" da página: marcas d'água na superfície do tabuleiro.
local function caosDaPagina(board: Part, widthStuds: number, heightStuds: number)
	local ppu = 10
	local gui = new("SurfaceGui", board, {
		Name = "Caos",
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = ppu,
		LightInfluence = 0.4,
		ClipsDescendants = true,
	})
	local w, h = widthStuds * ppu, heightStuds * ppu
	local azul, roxo, laranja = Estilo.CAPITULOS[2], Estilo.CAPITULOS[3], Estilo.CAPITULOS[1]
	-- Número de capítulo vazado e o kanji da abertura, como "01 / 第一章".
	local numero = marca(gui, {
		Text = "01",
		Position = UDim2.fromOffset(w * 0.04, h * 0.58),
		Size = UDim2.fromOffset(w * 0.34, h * 0.36),
		TextTransparency = 1,
	})
	-- Número vazado do livro: só o contorno, grosso, na cor do capítulo.
	new("UIStroke", numero, { Color = azul, Thickness = 7, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	marca(gui, {
		Text = "第一章",
		FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
		Position = UDim2.fromOffset(w * 0.9, h * 0.03),
		Size = UDim2.fromOffset(w * 0.08, h * 0.4),
		TextColor3 = Estilo.TINTA,
		TextTransparency = 0.82,
		TextWrapped = true,
	})
	-- Selos de capítulo e estrelas espalhados.
	marca(gui, { Text = "壱", Position = UDim2.fromOffset(w * 0.62, h * 0.62), Size = UDim2.fromOffset(w * 0.32, h * 0.32),
		TextColor3 = azul, TextTransparency = 0.86 })
	marca(gui, { Text = "参", Position = UDim2.fromOffset(w * 0.06, h * 0.06), Size = UDim2.fromOffset(w * 0.2, h * 0.2),
		TextColor3 = roxo, TextTransparency = 0.88 })
	for _, estrela in {
		{ 0.3, 0.18, 0.05 }, { 0.48, 0.08, 0.03 }, { 0.82, 0.45, 0.04 }, { 0.42, 0.86, 0.035 }, { 0.15, 0.42, 0.025 },
	} do
		marca(gui, { Text = Estilo.ESTRELA, Position = UDim2.fromOffset(w * estrela[1], h * estrela[2]),
			Size = UDim2.fromOffset(w * estrela[3], w * estrela[3]), TextTransparency = 0.8 })
	end
	-- Dados d20 em fio e faixas listradas nas margens.
	d20(gui, Vector2.new(w * 0.78, h * 0.22), w * 0.08, Estilo.TINTA, 0.84)
	d20(gui, Vector2.new(w * 0.24, h * 0.74), w * 0.05, laranja, 0.82)
	listras(gui, UDim2.fromOffset(0, h * 0.965), UDim2.fromOffset(w * 0.45, h * 0.035), azul, 0.82)
	listras(gui, UDim2.fromOffset(w * 0.55, 0), UDim2.fromOffset(w * 0.45, h * 0.025), roxo, 0.85)
end

-- As abas coloridas dos capítulos, saindo da borda direita da página.
local function abas(parent: Instance, origin: Vector3, widthStuds: number, heightStuds: number)
	local cores = table.clone(Estilo.CAPITULOS)
	table.insert(cores, Estilo.APENDICES)
	local passo = heightStuds / (#cores + 1.5)
	for i, cor in cores do
		local z = origin.Z - heightStuds / 2 + passo * (i + 0.25)
		local aba = part({ Name = "Aba", Size = Vector3.new(4, 0.5, passo * 0.82), Color = cor, CanCollide = false,
			Position = Vector3.new(origin.X + widthStuds / 2 + 2.4, origin.Y - 0.3, z), Parent = parent })
		local gui = new("SurfaceGui", aba, { Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 20, LightInfluence = 0 })
		marca(gui, { Text = if i == 1 then "0" elseif i == #cores then "Ap" else ({ "I", "II", "III", "IV", "V" })[i - 1],
			Size = UDim2.fromScale(1, 1), TextColor3 = Estilo.SOBRE_COR, TextTransparency = 0.1, Rotation = 90 })
	end
end

-- Selos das árvores flutuando no escuro em volta do livro.
local function selosFlutuantes(parent: Instance, origin: Vector3, raio: number)
	local arvores = {}
	for id, dados in Identidade do
		table.insert(arvores, { id = id, dados = dados })
	end
	table.sort(arvores, function(a, b)
		return a.id < b.id
	end)
	for i, arvore in arvores do
		local angulo = (i / #arvores) * math.pi * 2
		local distancia = raio + (i % 3) * 14
		local altura = 10 + (i % 4) * 6
		local ancora = part({ Name = "Selo", Size = Vector3.one, Transparency = 1, CanCollide = false, CanQuery = false,
			CastShadow = false, Position = origin + Vector3.new(math.cos(angulo) * distancia, altura, math.sin(angulo) * distancia),
			Parent = parent })
		ancora:SetAttribute("Selo", arvore.id)
		local tamanho = 9 + (i % 3) * 3
		local gui = new("BillboardGui", ancora, { Size = UDim2.fromScale(tamanho, tamanho), LightInfluence = 0,
			MaxDistance = 1000, AlwaysOnTop = false })
		marca(gui, { Text = arvore.dados.selo, FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
			Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromHex(arvore.dados.cor), TextTransparency = 0.45 })
		new("PointLight", ancora, { Color = Color3.fromHex(arvore.dados.cor), Range = 22, Brightness = 0.6, Shadows = false })
	end
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(58, 58, 68)
	Lighting.OutdoorAmbient = Color3.fromRGB(46, 46, 56)
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	local function effect(class: string, props: { [string]: any })
		local existing = Lighting:FindFirstChildOfClass(class)
		local object = existing or Instance.new(class)
		for key, value in props do
			object[key] = value
		end
		object.Parent = Lighting
	end
	-- Névoa escura nas bordas: a mesa some no preto, como o fundo do livro.
	effect("Atmosphere", { Density = 0.32, Offset = 0.2, Color = Estilo.MESA, Decay = Estilo.MESA_FUNDO, Glare = 0, Haze = 0.4 })
	effect("BloomEffect", { Intensity = 0.55, Size = 30, Threshold = 1.6 })
	effect("ColorCorrectionEffect", { Brightness = 0, Contrast = 0.12, Saturation = 0.05, TintColor = Color3.fromRGB(236, 238, 255) })
end

function World.create()
	local board = Protocol.BOARD
	local folder = Instance.new("Folder")
	folder.Name = "Mesa"

	local widthStuds = board.width * board.cell
	local heightStuds = board.height * board.cell
	local salao = math.max(widthStuds, heightStuds) + 220

	-- A mesa quadriculada, escura, que some na névoa.
	part({ Name = "Piso", Size = Vector3.new(salao, 1, salao), Position = Vector3.new(board.origin.X, -0.5, board.origin.Z),
		Color = Estilo.MESA, Parent = folder })
	local quadricula = Instance.new("Folder")
	quadricula.Name = "Quadricula"
	quadricula.Parent = folder
	local passo = 10
	for i = -math.floor(salao / passo / 2), math.floor(salao / passo / 2) do
		local d = i * passo
		part({ Name = "Fio", Size = Vector3.new(0.14, 0.02, salao), Position = Vector3.new(board.origin.X + d, 0.01, board.origin.Z),
			Color = Estilo.TINTA, Transparency = 0.93, CanCollide = false, CanQuery = false, CastShadow = false, Parent = quadricula })
		part({ Name = "Fio", Size = Vector3.new(salao, 0.02, 0.14), Position = Vector3.new(board.origin.X, 0.01, board.origin.Z + d),
			Color = Estilo.TINTA, Transparency = 0.93, CanCollide = false, CanQuery = false, CastShadow = false, Parent = quadricula })
	end

	-- O livro: capa, maço de páginas e a página (o tabuleiro).
	part({ Name = "Capa", Size = Vector3.new(widthStuds + 10, 0.6, heightStuds + 10), Position = board.origin - Vector3.new(0, 1.3, 0),
		Color = Color3.fromHex("#1b1b20"), Parent = folder })
	for i, cor in { "#2a2a31", "#18181d", "#25252b" } do
		part({ Name = "Maco", Size = Vector3.new(widthStuds + 4 - i, 0.25, heightStuds + 4 - i),
			Position = board.origin - Vector3.new(0, 1.05 - i * 0.12, 0), Color = Color3.fromHex(cor), Parent = folder })
	end
	local pagina = part({ Name = "Tabuleiro", Size = Vector3.new(widthStuds, 1, heightStuds), Position = board.origin - Vector3.new(0, 0.5, 0),
		Color = Estilo.PAPEL, Parent = folder })
	caosDaPagina(pagina, widthStuds, heightStuds)
	abas(folder, board.origin, widthStuds, heightStuds)

	-- Fio de margem em tinta, por dentro da página.
	for _, fio in {
		{ Vector3.new(0, 0, -(heightStuds / 2 + 0.9)), Vector3.new(widthStuds + 1.8, 0.05, 0.22) },
		{ Vector3.new(0, 0, heightStuds / 2 + 0.9), Vector3.new(widthStuds + 1.8, 0.05, 0.22) },
		{ Vector3.new(-(widthStuds / 2 + 0.9), 0, 0), Vector3.new(0.22, 0.05, heightStuds + 1.8) },
		{ Vector3.new(widthStuds / 2 + 0.9, 0, 0), Vector3.new(0.22, 0.05, heightStuds + 1.8) },
	} do
		part({ Name = "Margem", Size = fio[2], Position = board.origin + fio[1] - Vector3.new(0, 0.62, 0), Color = Estilo.TINTA,
			Transparency = 0.55, CanCollide = false, CanQuery = false, CastShadow = false, Parent = folder })
	end

	-- Luz de leitura sobre a página: neutra, para a grade e as fichas ficarem legíveis.
	for _, x in { -0.25, 0.25 } do
		for _, z in { -0.25, 0.25 } do
			local anchor = part({ Name = "LuzDaPagina", Size = Vector3.one, Transparency = 1, CanCollide = false, CanQuery = false,
				CastShadow = false, Position = board.origin + Vector3.new(x * widthStuds, 34, z * heightStuds), Parent = folder })
			new("PointLight", anchor, { Color = Estilo.TINTA, Range = 62, Brightness = 0.7, Shadows = false })
		end
	end
	-- Luz colorida rasante nos cantos, nas cores dos capítulos.
	for i, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1) } do
		local anchor = part({ Name = "LuzDoCaos", Size = Vector3.one, Transparency = 1, CanCollide = false, CanQuery = false,
			CastShadow = false, Position = board.origin + corner * Vector3.new(widthStuds / 2 + 6, 0, heightStuds / 2 + 6) + Vector3.new(0, 4, 0),
			Parent = folder })
		new("PointLight", anchor, { Color = Estilo.CAPITULOS[i + 1], Range = 30, Brightness = 0.9, Shadows = false })
	end

	local lines = Instance.new("Folder")
	lines.Name = "Grade"
	lines.Parent = folder
	for i = 0, board.width do
		local x = board.origin.X + (i - board.width / 2) * board.cell
		part({ Name = "Linha", Size = Vector3.new(0.12, 0.04, heightStuds), Position = Vector3.new(x, board.origin.Y + 0.02, board.origin.Z),
			Color = Estilo.TINTA, Transparency = Estilo.FIO_TRANSPARENCIA - 0.12, CanCollide = false, CanQuery = false, CastShadow = false,
			Parent = lines })
	end
	for i = 0, board.height do
		local z = board.origin.Z + (i - board.height / 2) * board.cell
		part({ Name = "Linha", Size = Vector3.new(widthStuds, 0.04, 0.12), Position = Vector3.new(board.origin.X, board.origin.Y + 0.02, z),
			Color = Estilo.TINTA, Transparency = Estilo.FIO_TRANSPARENCIA - 0.12, CanCollide = false, CanQuery = false, CastShadow = false,
			Parent = lines })
	end

	selosFlutuantes(folder, board.origin, math.max(widthStuds, heightStuds) / 2 + 34)

	local entrada = Vector3.new(board.origin.X, 0.2, board.origin.Z + heightStuds / 2 + 18)
	-- Marca de entrada: placa escura com fio roxo, como o botão do site.
	part({ Name = "Entrada", Size = Vector3.new(14, 0.1, 10), Position = entrada + Vector3.new(0, -0.15, 0),
		Color = Estilo.PAPEL_2, CanCollide = false, Parent = folder })
	part({ Name = "EntradaFio", Size = Vector3.new(14.4, 0.08, 10.4), Position = entrada + Vector3.new(0, -0.19, 0),
		Color = Estilo.DESTAQUE_FUNDO, Transparency = 0.2, CanCollide = false, Parent = folder })

	folder.Parent = workspace
	setupLighting()
end

return World
