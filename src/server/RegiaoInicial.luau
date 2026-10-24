-- Blockout físico da primeira região de exploração. Não contém regras de jogo;
-- interações e encontros continuam com autoridade nos serviços próprios.
local RegiaoInicial = {}
local ArvoreMundo = require(script.Parent.Mundo.ArvoreMundo)

local NOME_REGIAO = "RegiaoInicial"

local function parte(pai, nome, tamanho, posicao, cor, material)
	local item = Instance.new("Part")
	item.Name = nome
	item.Size = tamanho
	item.Position = posicao
	item.Color = cor
	item.Material = material or Enum.Material.Grass
	item.Anchored = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = pai
	return item
end

local function arvore(pai, x, z, escala)
	return ArvoreMundo.criar(pai, parte, x, z, escala, nil, "carvalho")
end

local function marco(pai, id, papel)
	pai:SetAttribute("AreaId", id)
	pai:SetAttribute("AreaRole", papel)
	return pai
end

function RegiaoInicial.start(deps)
	deps = deps or {}
	local workspaceAtual = deps.workspace or workspace
	local existente = workspaceAtual:FindFirstChild(NOME_REGIAO)
	if existente then return existente end

	local regiao = Instance.new("Model")
	regiao.Name = NOME_REGIAO
	marco(regiao, "region/clareira-inicial", "region")


	local pontoInicial = parte(regiao, "Entrada da região", Vector3.new(10, 0.3, 10),
		Vector3.new(110, 0.16, 0), Color3.fromRGB(117, 91, 61), Enum.Material.WoodPlanks)
	pontoInicial.CanCollide = false
	marco(pontoInicial, "region/clareira-inicial/entrada", "entry")

	local acampamento = Instance.new("Folder")
	acampamento.Name = "Acampamento"
	marco(acampamento, "region/clareira-inicial/acampamento", "landmark")
	acampamento.Parent = regiao
	parte(acampamento, "Lona", Vector3.new(12, 0.5, 10), Vector3.new(-19, 5, -31),
		Color3.fromRGB(176, 149, 105), Enum.Material.Fabric)
	parte(acampamento, "Mastro", Vector3.new(0.5, 10, 0.5), Vector3.new(-19, 0, -31),
		Color3.fromRGB(104, 75, 48), Enum.Material.Wood)
	for indice = 1, 8 do
		local angulo = math.rad((indice - 1) * 45)
		parte(acampamento, "Pedra da fogueira", Vector3.new(2, 1, 2),
			Vector3.new(-4 + math.cos(angulo) * 5, 0.5, -31 + math.sin(angulo) * 5),
			Color3.fromRGB(112, 109, 98), Enum.Material.Slate)
	end
	parte(acampamento, "Banco de tronco norte", Vector3.new(7, 1.2, 1.5), Vector3.new(-4, 0.6, -40),
		Color3.fromRGB(106, 74, 49), Enum.Material.Wood)
	parte(acampamento, "Banco de tronco sul", Vector3.new(7, 1.2, 1.5), Vector3.new(-4, 0.6, -22),
		Color3.fromRGB(106, 74, 49), Enum.Material.Wood)
	local cama = parte(acampamento, "Esteira de viagem", Vector3.new(4, 0.25, 2), Vector3.new(-28, 0.2, -30),
		Color3.fromRGB(117, 71, 59), Enum.Material.Fabric)
	cama.CanCollide = false
	parte(acampamento, "Caixa de mantimentos", Vector3.new(2.5, 2, 2), Vector3.new(-26, 1, -35),
		Color3.fromRGB(117, 83, 53), Enum.Material.WoodPlanks)
	local poste = parte(acampamento, "Poste da lanterna", Vector3.new(0.5, 7, 0.5), Vector3.new(-30, 3.5, -38),
		Color3.fromRGB(96, 69, 45), Enum.Material.Wood)
	local lanterna = parte(acampamento, "Lanterna do acampamento", Vector3.new(0.9, 1.2, 0.9),
		Vector3.new(-30, 6.5, -38), Color3.fromRGB(255, 211, 125), Enum.Material.Glass)
	lanterna.CanCollide = false
	lanterna.Transparency = 0.2
	local luz = Instance.new("PointLight")
	luz.Name = "Luz quente"
	luz.Color = Color3.fromRGB(255, 196, 120)
	luz.Brightness = 1.1
	luz.Range = 16
	luz.Shadows = false
	luz.Parent = lanterna
	local brasa = parte(acampamento, "Fogueira apagada", Vector3.new(3, 0.5, 3),
		Vector3.new(-4, 0.3, -31), Color3.fromRGB(90, 64, 43), Enum.Material.Wood)
	brasa.Shape = Enum.PartType.Cylinder
	brasa.Orientation = Vector3.new(0, 0, 90)

	local bosque = Instance.new("Folder")
	bosque.Name = "Bosque"
	marco(bosque, "region/clareira-inicial/bosque", "scenery")
	bosque.Parent = regiao
	local arvores = {
		{-105, -60, 1.2}, {-108, -22, 1}, {-105, 23, 1.1}, {-109, 67, 1.3},
		{-75, 105, 1}, {-34, 108, 1.2}, {12, 108, 1.1}, {57, 106, 1.3}, {100, 100, 1.2},
		{108, 64, 1}, {104, 20, 1.3}, {108, -24, 1.1}, {103, -69, 1.2},
		{68, -106, 1}, {25, -108, 1.3}, {-24, -108, 1.1}, {-66, -105, 1.2},
		{-83, 47, 0.85}, {75, 70, 0.9}, {78, -62, 0.85}, {-70, -10, 0.8},
	}
	for _, dados in ipairs(arvores) do
		arvore(bosque, dados[1], dados[2], dados[3])
	end

	local clareira = Instance.new("Folder")
	clareira.Name = "Clareira de encontro"
	marco(clareira, "region/clareira-inicial/encontro", "encounter-area")
	clareira.Parent = regiao
	local marcoEncontro = parte(clareira, "Marco do encontro", Vector3.new(3, 5, 3),
		Vector3.new(42, 2.5, 41), Color3.fromRGB(117, 102, 77), Enum.Material.Slate)
	marco(marcoEncontro, "region/clareira-inicial/encontro/marco", "encounter-trigger")
	marcoEncontro:SetAttribute("EncounterId", "region/encounter/clearing")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Iniciar encontro"
	prompt.ActionText = "Investigar"
	prompt.ObjectText = "Clareira de encontro"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = true
	prompt.Parent = marcoEncontro

	local marcoBosque = parte(regiao, "Marco do bosque", Vector3.new(3, 5, 3),
		Vector3.new(-42, 2.5, 53), Color3.fromRGB(117, 102, 77), Enum.Material.Slate)
	marco(marcoBosque, "region/clareira-inicial/encontro-bosque/marco", "encounter-trigger")
	marcoBosque:SetAttribute("EncounterId", "region/encounter/forest")
	local promptBosque = Instance.new("ProximityPrompt")
	promptBosque.Name = "Investigar trilha"
	promptBosque.ActionText = "Investigar"
	promptBosque.ObjectText = "Trilha do bosque"
	promptBosque.HoldDuration = 0.4
	promptBosque.MaxActivationDistance = 12
	promptBosque.RequiresLineOfSight = true
	promptBosque.Parent = marcoBosque
	for _, dados in ipairs({ {16, 13}, {68, 15}, {16, 68}, {68, 68} }) do
		arvore(bosque, dados[1], dados[2], 0.72)
	end

	regiao.Parent = workspaceAtual
	return regiao
end


-- Apresentacao e adaptador fisico da patrulha; regras de percepcao em Mundo/Patrulha.
-- R2b pode consumir as transicoes perseguindo/em-encontro para surpresa/fuga.
function RegiaoInicial.iniciarPatrulha(deps)
 local config = table.clone(deps)
 config.regiao = (deps.workspace or workspace):FindFirstChild(NOME_REGIAO)
 config.nome = "Patrulha da clareira"
 config.criatura = config.criatura or "creature/goblin-batedor"
 config.pontos = { Vector3.new(54, 1.5, 43), Vector3.new(64, 1.5, 43),
  Vector3.new(64, 1.5, 54), Vector3.new(54, 1.5, 54) }
 return require(script.Parent.Mundo.PatrulhaVisivel).criar(config)
end

return RegiaoInicial
