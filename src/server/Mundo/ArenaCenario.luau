-- Veste o tabuleiro da mesa com o cenário da região da luta do Modo História (PLANO §13).
-- A grade, as casas e a geometria do combate não mudam: só piso, decoração e moradores em volta.
-- aplicar(nil) devolve o livro da mesa usado pela sala (Desafios/PvP).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Protocol = require(ReplicatedStorage.Shared.MesaProtocol)
local Arenas = require(ReplicatedStorage.Shared.Mundo.ArenasDados)
local NpcsDados = require(ReplicatedStorage.Shared.Mundo.NpcsDados)
local MontarModelo = require(script.Parent.MontarModelo)
local Props = require(script.Parent.Props)
local Npcs = require(script.Parent.Npcs)

local ArenaCenario = {}

local ANIM_PARADO = "rbxassetid://507766388"
local ANIM_ACENO = "rbxassetid://507770239"
-- Peças do livro que somem quando a arena é de uma região (a página continua sendo o tabuleiro).
local DO_LIVRO = { Capa = true, Maco = true, Aba = true, Selo = true, LuzDoCaos = true, Margem = true,
	Entrada = true, EntradaFio = true, Quadricula = true }

local construidas = {} -- arenaId -> Folder (guardada em ServerStorage enquanto não está em uso)
local atual = nil
local originais = nil -- { [Instance] = { propriedade = valor } }

local function guardar(objeto, props)
	originais[objeto] = originais[objeto] or {}
	for nome, valor in props do
		if originais[objeto][nome] == nil then originais[objeto][nome] = objeto[nome] end
		objeto[nome] = valor
	end
end

local function morador(pasta, i, x, z, origem)
	local lista = NpcsDados.LISTA
	local base = lista[(i - 1) % #lista + 1]
	local corpo = Npcs.criarCorpo({ aparencia = base.aparencia, raceId = base.raceId or "race/humano" })
	if not corpo then return end
	corpo.Name = "Morador"
	for _, item in corpo:GetDescendants() do
		if item:IsA("LuaSourceContainer") then item:Destroy() end
	end
	local humanoide = corpo:FindFirstChildOfClass("Humanoid")
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local raiz = corpo:WaitForChild("HumanoidRootPart")
	local altura = origem.Y + humanoide.HipHeight + raiz.Size.Y / 2
	local ponto = Vector3.new(origem.X + x, altura, origem.Z + z)
	corpo:PivotTo(CFrame.lookAt(ponto, Vector3.new(origem.X, altura, origem.Z)))
	for _, parte in corpo:GetDescendants() do
		if parte:IsA("BasePart") then
			parte.Anchored = parte == raiz
			parte.CanQuery, parte.CanCollide = false, false
		end
	end
	corpo.Parent = pasta
	local animador = humanoide:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoide)
	for _, dado in { { ANIM_PARADO, true, "Parado" }, { ANIM_ACENO, false, "Aceno" } } do
		local animacao = Instance.new("Animation")
		animacao.AnimationId = dado[1]
		local ok, faixa = pcall(animador.LoadAnimation, animador, animacao)
		if ok and faixa then
			faixa.Looped = dado[2]
			if dado[2] then faixa:Play() else faixa.Priority = Enum.AnimationPriority.Action; corpo:SetAttribute("TemAceno", true) end
			corpo:SetAttribute("Faixa" .. dado[3], true)
			if not dado[2] then
				-- Torcida: cada morador acena de vez em quando enquanto a arena está montada.
				task.spawn(function()
					task.wait(1 + (i % 5))
					while corpo.Parent do
						if corpo:IsDescendantOf(workspace) then faixa:Play() end
						task.wait(6 + (i * 1.7) % 6)
					end
				end)
			end
		end
	end
end

local function construir(arenaId)
	local layout = Arenas.layout(arenaId)
	if not layout then return nil end
	local origem = Protocol.BOARD.origin
	local pasta = Instance.new("Folder")
	pasta.Name = "Arena_" .. arenaId
	local props = Instance.new("Folder")
	props.Name, props.Parent = "Props", pasta
	for _, p in layout.props do
		if MontarModelo.existe(p[1]) then
			local cf = CFrame.new(origem.X + p[2], 0, origem.Z + p[3]) * CFrame.Angles(0, math.rad(p[4]), 0)
			local ok, modelo = pcall(MontarModelo.montar, p[1], props, cf, p[5])
			if ok and modelo then
				local caixa, tamanho = modelo:GetBoundingBox()
				modelo:PivotTo(modelo:GetPivot() + Vector3.new(0, -(caixa.Position.Y - tamanho.Y / 2), 0))
				Props.aplicarMateriaisELuzes(modelo, p[1])
				for _, parte in modelo:GetDescendants() do
					if parte:IsA("BasePart") then parte.CanQuery = false end
				end
			end
		end
	end
	local moradores = Instance.new("Folder")
	moradores.Name, moradores.Parent = "Moradores", pasta
	for i, m in layout.moradores do morador(moradores, i, m[1], m[2], origem) end
	pasta.Parent = ServerStorage
	return pasta
end

-- Monta antes (pré-aquecimento): a primeira luta não espera malhas nem avatares.
function ArenaCenario.preparar()
	if not construidas.cidade then construidas.cidade = construir("cidade") end
end

function ArenaCenario.aplicar(arenaId)
	if arenaId == atual then return end
	local mesa = workspace:FindFirstChild("Mesa")
	if atual and construidas[atual] then construidas[atual].Parent = ServerStorage end
	if originais then
		for objeto, props in originais do
			for nome, valor in props do objeto[nome] = valor end
		end
		originais = nil
	end
	atual = nil
	if mesa then mesa:SetAttribute("ArenaRegional", nil) end
	local layout = Arenas.layout(arenaId)
	if not layout or not mesa then return end
	if not construidas[arenaId] then construidas[arenaId] = construir(arenaId) end
	originais = {}
	for _, item in mesa:GetDescendants() do
		local raiz = item
		while raiz.Parent and raiz.Parent ~= mesa do raiz = raiz.Parent end
		if DO_LIVRO[raiz.Name] then
			if item:IsA("BasePart") then guardar(item, { Transparency = 1 })
			elseif item:IsA("Light") or item:IsA("GuiBase3d") or item:IsA("LayerCollector") then guardar(item, { Enabled = false }) end
		end
	end
	local pagina = mesa:FindFirstChild("Tabuleiro")
	if pagina then
		guardar(pagina, { Material = Enum.Material[layout.piso.material], Color = Color3.fromRGB(table.unpack(layout.piso.cor)) })
		local caos = pagina:FindFirstChild("Caos")
		if caos then guardar(caos, { Enabled = false }) end
	end
	local piso = mesa:FindFirstChild("Piso")
	if piso then guardar(piso, { Material = Enum.Material[layout.chao.material], Color = Color3.fromRGB(table.unpack(layout.chao.cor)) }) end
	construidas[arenaId].Parent = workspace
	atual = arenaId
	mesa:SetAttribute("ArenaRegional", arenaId)
end

function ArenaCenario.atual() return atual end

return ArenaCenario
