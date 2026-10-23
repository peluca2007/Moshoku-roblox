-- Rig estático A1 compartilhado pelo editor e pela viagem; sem avatar online/Humanoid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Visual = require(Shared.Aparencia.Visual)
local Racas = require(Shared.Aparencia.Racas)

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

return Modelo
