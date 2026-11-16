-- Rig estático A1 compartilhado pelo editor e pela viagem; sem avatar online/Humanoid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Visual = require(Shared.Aparencia.Visual)
local Racas = require(Shared.Aparencia.Racas)
local Personagem = require(Shared.Aparencia.Personagem)

local Players = game:GetService("Players")

local Modelo = {}

function Modelo.criar(aparencia, raceId)
	local escala = Racas.POR_ID[raceId].escala
	local modelo = Instance.new("Model")
	local function bloco(nome, x, y, z, sx, sy, sz, corId)
		local parte = Instance.new("Part")
		parte.Name = nome
		parte.Size = Vector3.new(sx * escala.largura, sy * escala.altura, sz * escala.profundidade)
		parte.CFrame = CFrame.new(x * escala.largura, y * escala.altura, z * escala.profundidade)
		parte.Color = Visual.cor(corId)
		parte.Anchored, parte.CanCollide, parte.Material = true, false, Enum.Material.SmoothPlastic
		parte.Parent = modelo
	end
	bloco("Head", 0, 2.5, 0, 1, 1, 1, aparencia.cores.pele)
	if not Personagem.CABECA_CUBICA then
		-- Cabeça redonda clássica (PERS2): Part 1x1x1 com SpecialMesh Head; Visual.decorar mede a frente pela escala da malha.
		local cabeca = modelo.Head
		local malha = Instance.new("SpecialMesh")
		malha.MeshType, malha.Scale = Enum.MeshType.Head, Vector3.new(1.25, 1.25, 1.25)
		malha.Parent = cabeca
		cabeca.Size = cabeca.Size * (1 / 1.25) * 1.0
		cabeca.Size = Vector3.new(cabeca.Size.X, cabeca.Size.Y, cabeca.Size.Z)
	end
	bloco("UpperTorso", 0, 1.55, 0, 2, 1, 1, aparencia.cores.camisa)
	bloco("LowerTorso", 0, .8, 0, 2, .5, 1, aparencia.cores.camisa)
	for _, lado in {{"Left", -1}, {"Right", 1}} do
		local nome, sinal = lado[1], lado[2]
		bloco(nome .. "UpperArm", sinal * 1.5, 1.65, 0, 1, .8, 1, aparencia.cores.pele)
		bloco(nome .. "LowerArm", sinal * 1.5, .9, 0, 1, .7, 1, aparencia.cores.pele)
		bloco(nome .. "Hand", sinal * 1.5, .35, 0, 1, .4, 1, aparencia.cores.pele)
		bloco(nome .. "UpperLeg", sinal * .5, 0, 0, 1, 1, 1, aparencia.cores.calca)
		bloco(nome .. "LowerLeg", sinal * .5, -.9, 0, 1, .8, 1, aparencia.cores.calca)
		bloco(nome .. "Foot", sinal * .5, -1.5, -.1, 1, .4, 1.2, aparencia.cores.calca)
	end
	local ok, erro = pcall(Visual.decorar, modelo, aparencia, raceId)
	if not ok then modelo:Destroy(); error(erro) end
	for _, parte in modelo:GetDescendants() do
		if parte:IsA("BasePart") then parte.Anchored = true end
	end
	return modelo
end

-- PERS3: o corpo R15 padrão do jogo (o mesmo das fichas: descrição vazia + cores/escala da raça + Visual.decorar), parado.
-- CreateHumanoidModelFromDescription YIELDA (rede): chame numa thread própria. Erra se a criação falhar; quem chama cai em
-- Modelo.criar (blocos). Sem Humanoid ativo: todas as partes ancoradas.
function Modelo.criarR15(aparencia, raceId)
	assert(Racas.POR_ID[raceId], "raça desconhecida")
	local descricao = Visual.descrever(aparencia, raceId)
	local corpo = Players:CreateHumanoidModelFromDescription(descricao, Enum.HumanoidRigType.R15)
	local ok, erro = pcall(Visual.decorar, corpo, aparencia, raceId)
	if not ok then corpo:Destroy(); error(erro) end
	for _, parte in corpo:GetDescendants() do
		if parte:IsA("BasePart") then parte.Anchored = true end
	end
	local humanoide = corpo:FindFirstChildOfClass("Humanoid")
	if humanoide then humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return corpo
end

return Modelo
