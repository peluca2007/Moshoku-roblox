-- Monta adereços de cenário a partir das posições puras de shared/Mundo/PropsLayout.
-- Sem o modelo, o adereço simplesmente não aparece (é só enfeite, nunca bloqueia regra).
local MontarModelo = require(script.Parent.MontarModelo)
local Shared = game:GetService("ReplicatedStorage").Shared
local PropsLayout = require(Shared.Mundo.PropsLayout)
local TerrenoLayout = require(Shared.Mundo.TerrenoLayout)

local Props = {}

local function pertenceAoGrupo(instancia: Instance, nome: string, raiz: Instance): boolean
	local atual = instancia.Parent
	while atual and atual ~= raiz do
		if atual:IsA("Model") and atual.Name == nome then return true end
		atual = atual.Parent
	end
	return false
end

local function aplicarMateriaisELuzes(modelo: Model, nomeModelo: string?)
	local chapeu, parteLuz = nil, nil
	for _, parte in modelo:GetDescendants() do
		if parte:IsA("BasePart") then
			local dentroAgua = parte.Name == "Agua" or pertenceAoGrupo(parte, "Agua", modelo)
			if dentroAgua then
				parte.Material = Enum.Material.Glass
				parte.Transparency = 0.35
				parte.Color = Color3.fromRGB(80, 220, 210)
				parte.CanCollide = false
			elseif parte.Material == Enum.Material.Grass then
				parte.Material = Enum.Material.SmoothPlastic
			end
			if parte.Name == "ChapeuLuz" and not chapeu then
				parte.Material = Enum.Material.Neon
				chapeu = parte
			end
			if parte.Name == "Luz" or pertenceAoGrupo(parte, "Luz", modelo) then
				parte.Material = Enum.Material.Neon
				parteLuz = parteLuz or parte
			end
		end
	end
	local function pontoDeLuz(parte, nome, cor, alcance, brilho)
		if not parte then return end
		local ponto = Instance.new("PointLight")
		ponto.Name, ponto.Color, ponto.Range, ponto.Brightness = nome, cor, alcance, brilho
		ponto.Parent = parte
	end
	-- ChapeuLuz mantém sua luz fria e fraca histórica; cada modelo pode ter também uma luz âmbar.
	pontoDeLuz(chapeu, "LuzChapeu", Color3.fromRGB(105, 220, 255), 8, 0.45)
	pontoDeLuz(parteLuz, "LuzAmbiente", Color3.fromRGB(255, 177, 92), 14, 0.8)

	if (nomeModelo or modelo.Name) == "Chafariz" then
		local topo, pontoTopo, yMax = nil, nil, -math.huge
		for _, parte in modelo:GetDescendants() do
			if parte:IsA("BasePart") then
				local meio = parte.Size / 2
				for _, x in { -meio.X, meio.X } do
					for _, y in { -meio.Y, meio.Y } do
						for _, z in { -meio.Z, meio.Z } do
							local canto = parte.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
							if canto.Y > yMax then topo, pontoTopo, yMax = parte, canto, canto.Y end
						end
					end
				end
			end
		end
		if topo then
			local attachment = Instance.new("Attachment")
			attachment.Name = "Respingo"
			attachment.Position = topo.CFrame:PointToObjectSpace(Vector3.new(topo.Position.X,pontoTopo.Y,topo.Position.Z))
			attachment.Parent = topo
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "AguaRespingo"
			emitter.Rate = 4
			emitter.Color = ColorSequence.new(Color3.fromRGB(125,235,230))
			emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.10),NumberSequenceKeypoint.new(1,0.03)})
			emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.35),NumberSequenceKeypoint.new(1,1)})
			emitter.Lifetime = NumberRange.new(0.35, 0.7)
			emitter.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
			emitter.Speed = NumberRange.new(1, 2)
			emitter.SpreadAngle = Vector2.new(18, 18)
			emitter.Parent = attachment
		end
	end
end

Props.aplicarMateriaisELuzes = aplicarMateriaisELuzes

local COPAS = { Copa = true, CopaClara = true, Folhas = true, FolhasClaras = true, Leaves1 = true }

-- Monta um adereço apoiado no chão (y=0). Devolve o Model ou nil se faltar o modelo.
local function montar(pai, prop)
	local familia = PropsLayout.FAMILIAS[prop[3]]
	local nome = familia and PropsLayout.modelo(prop[3], prop[1], prop[2])
	if not nome or not MontarModelo.existe(nome) then
		return nil
	end
	local escala = familia.escala * prop[4]
	local altura = if type(prop[6]) == "number" then prop[6] else TerrenoLayout.altura(prop[1], prop[2])
	local modelo = MontarModelo.montar(nome, pai, CFrame.new(prop[1], altura, prop[2]) * CFrame.Angles(0, math.rad(prop[5]), 0), escala)
	if familia.cor then
		local cor = Color3.fromRGB(familia.cor[1], familia.cor[2], familia.cor[3])
		for _, parte in modelo:GetDescendants() do
			if parte:IsA("BasePart") then parte.Color = cor end
		end
	end
	aplicarMateriaisELuzes(modelo, nome)
	-- Copas e folhagem não colidem (17/10): a borda baixa da copa fica a ~3,5 studs do chão e prendia a cabeça do
	-- avatar nas trilhas da floresta (abetos nas duas margens). O tronco continua sólido; CanQuery segue ligado
	-- para a oclusão da câmera.
	for _, parte in modelo:GetDescendants() do
		if parte:IsA("BasePart") and COPAS[parte.Name] then parte.CanCollide = false end
	end
	-- Mastros foram exportados numa malha única que cruza o vão: sem colisão
	-- também no fallback de rede, para não virar uma parede invisível na praça.
	if not PropsLayout.colide(prop[3]) or nome == "Portao" or prop[3] == "bandeirolas" then
		for _, parte in modelo:GetDescendants() do
			if parte:IsA("BasePart") then
    parte.CanCollide = false
    if not PropsLayout.colide(prop[3]) then parte.CanQuery, parte.CanTouch = false, false end
   end
		end
	end
	local caixa, tamanho = modelo:GetBoundingBox()
	modelo:PivotTo(modelo:GetPivot() + Vector3.new(0, altura - (caixa.Position.Y - tamanho.Y / 2), 0))
	modelo.Name = prop[3]
	return modelo
end

-- `lista` vem de PropsLayout.VILA ou PropsLayout.floresta(). Cria uma pasta "Props" em `pai`.
function Props.criar(pai: Instance, lista: { { any } }): Folder
	local pasta = Instance.new("Folder")
	pasta.Name = "Props"
	for indice, prop in ipairs(lista) do
		local modelo=montar(pasta, prop)
		if modelo then modelo:SetAttribute("PropIndice",indice) end
	end
	pasta.Parent = pai
	return pasta
end

return Props
