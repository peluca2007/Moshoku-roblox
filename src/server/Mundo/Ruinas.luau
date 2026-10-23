-- Constrói as Ruínas do Vale (shared/Mundo/RuinasLayout): solo, caminho de lajes, praça
-- circular da câmara do guardião e as peças (arco, colunas, muros, altar, lápides,
-- vegetação). Região só de cenário: o combate do guardião roda no J2 pela run, e a
-- viagem ainda leva o grupo até aqui; a passagem W1a também permite chegada a pé.
local Layout = require(game:GetService("ReplicatedStorage").Shared.Mundo.RuinasLayout)
local Passagem = require(game:GetService("ReplicatedStorage").Shared.Mundo.PassagemLayout)
local Props = require(script.Parent.Props)
local Grade = require(script.Parent.GradeTatica)

local Ruinas = {}
local NOME = "RuinasDoVale"

local function parte(pai, nome, tamanho, cframe, cor, material)
	local item = Instance.new("Part")
	item.Name, item.Size, item.CFrame = nome, tamanho, cframe
	item.Color, item.Material = cor, material
	item.Anchored = true
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.Parent = pai
	return item
end

function Ruinas.start(deps)
	deps = deps or {}
	local raiz = deps.workspace or workspace
	local existente = raiz:FindFirstChild(NOME)
	if existente then return existente end

	local regiao = Instance.new("Model")
	regiao.Name = NOME
	regiao:SetAttribute("AreaId", Layout.ID)
	regiao:SetAttribute("AreaRole", "region")
	-- marcador de nascimento (a viagem posiciona o grupo aqui)
	local ponto = parte(regiao, "Chegada", Vector3.new(2, 0.2, 2), CFrame.new(Layout.NASCIMENTO.x, 0.1, Layout.NASCIMENTO.z), Color3.fromRGB(142, 138, 128), Enum.Material.Slate)
	ponto.CanCollide, ponto.CanQuery, ponto.Transparency = false, false, 1
	ponto:SetAttribute("AreaRole", "arrival")

	Props.criar(regiao, Layout.pecas())
	-- Sinalização fora do eixo caminhável, sem scripts/prompts/teleporte.
	for _, p in ipairs(Passagem.placas) do
		local cf = CFrame.new(p.x, 0, p.z) * CFrame.Angles(0, math.rad(p.giro), 0)
		parte(regiao, p.id .. "-poste", Vector3.new(0.6, 4, 0.6), cf * CFrame.new(0, 2, 0),
			Color3.fromRGB(100, 76, 52), Enum.Material.Wood)
		local placa = parte(regiao, p.id, Vector3.new(7, 2.4, 0.4), cf * CFrame.new(0, 4, 0),
			Color3.fromRGB(100, 76, 52), Enum.Material.Wood)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local gui = Instance.new("SurfaceGui")
			gui.Face, gui.CanvasSize = face, Vector2.new(560, 192)
			local texto = Instance.new("TextLabel")
			texto.Size, texto.BackgroundTransparency = UDim2.fromScale(1, 1), 1
			texto.Text, texto.TextSize, texto.TextWrapped = p.texto, 40, true
			texto.Font, texto.TextColor3 = Enum.Font.Garamond, Color3.fromRGB(240, 226, 190)
			texto.Parent, gui.Parent = gui, placa
		end
	end
 regiao.Parent = raiz
 local a = Layout.ARENA
 local marco = parte(regiao, "Marco do guardiao", Vector3.one, CFrame.new(a.x, 0, a.z - 8),
  Color3.new(), Enum.Material.Slate)
 marco.Transparency = 1
 marco.CanCollide, marco.CanTouch, marco.CanQuery = false, false, false
 marco:SetAttribute("AreaId", a.marco)
 marco:SetAttribute("AreaRole", "encounter-trigger")
 marco:SetAttribute("EncounterId", a.id)
 -- Terreno compartilhado plano em y=0; grade apenas visual.
 Grade.criar(regiao, marco, "region/ruinas-do-vale/grade-tatica", function(pai, nome, tamanho, pos, cor, material)
  return parte(pai, nome, tamanho, CFrame.new(pos), cor, material)
 end, function(item, id, papel)
  item:SetAttribute("AreaId", id); item:SetAttribute("AreaRole", papel)
 end)
 return regiao
end

function Ruinas.iniciarPatrulha(deps)
 local config = table.clone(deps)
 config.regiao = (deps.workspace or workspace):FindFirstChild(NOME)
 config.nome = "Patrulha das ruinas"
 config.criatura = config.criatura or "creature/goblin-batedor"
 config.pontos = {}
 for _, p in ipairs(Layout.PATRULHA) do table.insert(config.pontos, Vector3.new(p.x, 1.5, p.z)) end
 return require(script.Parent.PatrulhaVisivel).criar(config)
end

return Ruinas
