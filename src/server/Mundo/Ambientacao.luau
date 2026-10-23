-- Detalhes de ambiente que dão vida ao cenário sem tocar em regra: manchas de chão
-- (shared/Mundo/ChaoLayout) e partículas — vaga-lumes na Floresta Sombria, poeira dourada
-- na vila. Tudo ancorado, sem colisão, sem scripts. Só apresentação.
local ChaoLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.ChaoLayout)
local FlorestaLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.FlorestaLayout)
local VilaLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.VilaLayout)
local RuinasLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.RuinasLayout)
local RegiaoLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.RegiaoLayout)
local Props = require(script.Parent.Props)

local Ambientacao = {}
local NOME = "Ambientacao"
local TEXTURA_BRILHO = "rbxasset://textures/particles/sparkles_main.dds"

local function inerte(parte: BasePart)
	parte.Anchored, parte.CanCollide, parte.CanQuery, parte.CanTouch, parte.CastShadow = true, false, false, false, false
end

local function manchas(pai: Instance, lista: { { any } })
	local pasta = Instance.new("Folder")
	pasta.Name = "Manchas de chao"
	for i, m in ipairs(lista) do
		local tipo = ChaoLayout.TIPOS[m[4]]
		local mancha = Instance.new("Part")
		mancha.Name = m[4]
		-- Lente achatada (esfera) em vez de disco: a borda some suave no chão em vez de formar degrau.
		mancha.Shape = Enum.PartType.Ball
		local alongamento = 0.55 + ((i * 37) % 45) / 100
		mancha.Size = Vector3.new(m[3] * 2, 0.16, m[3] * 2 * alongamento)
		mancha.CFrame = CFrame.new(m[1], 0.0 + m[5] * 0.012, m[2]) * CFrame.Angles(0, (i * 53 % 180) * math.pi / 180, 0)
		mancha.Color = Color3.fromRGB(tipo.cor[1], tipo.cor[2], tipo.cor[3])
		mancha.Material = Enum.Material[tipo.material]
		inerte(mancha)
		mancha.Parent = pasta
	end
	pasta.Parent = pai
end

local function emissor(pai: Instance, nome: string, centro: Vector3, tamanho: Vector3, config)
	local base = Instance.new("Part")
	base.Name, base.Size, base.Position, base.Transparency = nome, tamanho, centro, 1
	inerte(base)
	local p = Instance.new("ParticleEmitter")
	p.Texture = TEXTURA_BRILHO
	p.Shape, p.ShapeStyle, p.ShapeInOut = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume, Enum.ParticleEmitterShapeInOut.Outward
	p.Color = ColorSequence.new(config.cor)
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, config.tamanho), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, config.opacidade), NumberSequenceKeypoint.new(0.75, config.opacidade), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(config.vida[1], config.vida[2])
	p.Speed = NumberRange.new(config.velocidade[1], config.velocidade[2])
	p.SpreadAngle = Vector2.new(180, 180)
	p.Rate = config.taxa
	p.LightEmission, p.LightInfluence = config.brilho, 0
	p.Acceleration = Vector3.new(0, config.sobe, 0)
	p.RotSpeed = NumberRange.new(-40, 40)
	p.Parent = base
	base.Parent = pai
end

function Ambientacao.start(deps)
	deps = deps or {}
	local raiz = deps.workspace or workspace
	if raiz:FindFirstChild(NOME) then
		return raiz[NOME]
	end
	local pasta = Instance.new("Folder")
	pasta.Name = NOME

	manchas(pasta, ChaoLayout.vila())
	manchas(pasta, ChaoLayout.floresta())
	manchas(pasta, ChaoLayout.ruinas())
	manchas(pasta, ChaoLayout.regiao())
	-- Acampamento e campo da região inicial: tendas, fardos, placa, tripé e vegetação (sem tocar em RegiaoInicial).
	local regiao = raiz:FindFirstChild("RegiaoInicial")
	if regiao then
		local pecas = table.clone(RegiaoLayout.PECAS)
		for _, prop in ipairs(RegiaoLayout.campo()) do table.insert(pecas, prop) end
		Props.criar(regiao, pecas)
	end

	-- Vaga-lumes: uma grade 3x4 de volumes sobre o solo da floresta.
	local solo = FlorestaLayout.SOLO
	for i = 0, 2 do
		for j = 0, 3 do
			local x = solo.x + (i - 1) * 72
			local z = solo.z + (j - 1.5) * 72
			emissor(pasta, "Vagalumes", Vector3.new(x, 3.5, z), Vector3.new(72, 7, 72), {
				cor = Color3.fromRGB(214, 255, 124), tamanho = 0.75, opacidade = 0.06, vida = { 4, 8 },
				velocidade = { 0.2, 1.1 }, taxa = 14, brilho = 1, sobe = 0.15,
			})
		end
	end
	-- Poeira dourada ao sol sobre a vila.
	local vila = VilaLayout.SOLO
	for i = 0, 1 do
		for j = 0, 1 do
			emissor(pasta, "Poeira", Vector3.new(vila.x + (i - 0.5) * 100, 4, vila.z + (j - 0.5) * 90), Vector3.new(100, 7, 90), {
				cor = Color3.fromRGB(255, 236, 170), tamanho = 0.22, opacidade = 0.45, vida = { 6, 10 },
				velocidade = { 0.2, 0.7 }, taxa = 5, brilho = 0.5, sobe = 0.05,
			})
		end
	end
	-- Fiapos de luz violeta sobre as Ruínas do Vale e, mais forte, sobre a câmara do Selo.
	local ruinas = RuinasLayout.SOLO
	emissor(pasta, "Espiritos", Vector3.new(ruinas.x, 4, ruinas.z), Vector3.new(ruinas.sx, 8, ruinas.sz), {
		cor = Color3.fromRGB(186, 160, 255), tamanho = 0.7, opacidade = 0.35, vida = { 6, 10 },
		velocidade = { 0.3, 0.9 }, taxa = 9, brilho = 1, sobe = 0.12,
	})
	emissor(pasta, "Selo", Vector3.new(RuinasLayout.CAMARA.x, 4, RuinasLayout.CAMARA.z), Vector3.new(30, 8, 30), {
		cor = Color3.fromRGB(214, 190, 255), tamanho = 0.9, opacidade = 0.2, vida = { 3, 6 },
		velocidade = { 0.5, 1.5 }, taxa = 12, brilho = 1, sobe = 0.6,
	})
	pasta.Parent = raiz
	return pasta
end

return Ambientacao
