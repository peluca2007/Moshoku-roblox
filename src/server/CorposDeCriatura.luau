-- Corpos das criaturas (A8, "tem que parecer um jogo"): no lugar do pino, a
-- criatura ganha um corpo no tabuleiro.
-- - Humanoides, mortos-vivos, demônios e constructos: rig R15 do Roblox gerado
--   por HumanoidDescription (cor, escala), olhos acesos, anda com animação.
-- - Bestas: quadrúpede montado com peças (lobo, rato, urso, aranha).
-- - Monstros (hidras, wyrms...) continuam miniatura por enquanto.
-- Como o avatar do jogador (AvatarFichas): o servidor ancora o corpo e o leva
-- de casa em casa. Ficha secreta (oculta ou na névoa) não tem corpo: a posição de
-- um modelo replica para todos e entregaria a casa.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Visao = require(game.ReplicatedStorage.Shared.VisaoFurtiva)
local Visual = require(script.Parent.VisualCriaturas)

local Corpos = {}
-- O jogo tem uma só mesa. Reutiliza o filtro de névoa já injetado por MesaService
-- para que a apresentação pública de chefes nunca revele fichas secretas.
local filtroSecreto
function Corpos.secreto(token): boolean
	return if filtroSecreto then filtroSecreto(token) else true
end

local VELOCIDADE = 13 -- studs por segundo
local ANIM_ANDAR = "rbxassetid://507777826"
local ANIM_PARADO = "rbxassetid://507766388"

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Aparência humanoide: pele, roupa (tronco), calça, olhos e escalas.
local POR_CATEGORIA = {
	humanoide = { pele = rgb(204, 160, 120), roupa = rgb(84, 70, 58), calca = rgb(52, 46, 42), olhos = rgb(30, 24, 20) },
	["morto-vivo"] = { pele = rgb(222, 216, 196), roupa = rgb(222, 216, 196), calca = rgb(200, 194, 176), olhos = rgb(120, 220, 255), largura = 0.7, profundidade = 0.7 },
	demonio = { pele = rgb(150, 40, 40), roupa = rgb(60, 20, 24), calca = rgb(40, 14, 18), olhos = rgb(255, 200, 60), altura = 1.15, largura = 1.1 },
	construto = { pele = rgb(120, 118, 112), roupa = rgb(104, 102, 96), calca = rgb(90, 88, 84), olhos = rgb(120, 255, 170), altura = 1.3, largura = 1.45, profundidade = 1.3, cabeca = 0.85 },
}
local POR_CRIATURA = {
	["creature/goblin-batedor"] = { pele = rgb(112, 150, 70), roupa = rgb(96, 72, 46), calca = rgb(70, 54, 38), olhos = rgb(255, 210, 60), altura = 0.72, largura = 0.85, cabeca = 1.3 },
	["creature/bandido-de-estrada"] = { roupa = rgb(92, 40, 36), calca = rgb(48, 40, 34) },
	["creature/guerreiro-superd"] = { pele = rgb(170, 130, 96), roupa = rgb(40, 80, 60), calca = rgb(40, 40, 40), altura = 1.08 },
	["creature/cavaleiro-real"] = { roupa = rgb(170, 176, 190), calca = rgb(120, 126, 140), altura = 1.05, largura = 1.1 },
	["creature/mago-renegado"] = { roupa = rgb(80, 50, 120), calca = rgb(60, 36, 90), olhos = rgb(200, 120, 255) },
	["creature/guardiao-sagrado"] = { roupa = rgb(232, 226, 200), calca = rgb(200, 170, 90), olhos = rgb(255, 240, 160), altura = 1.1 },
	["creature/assassino-das-sombras"] = { pele = rgb(60, 56, 60), roupa = rgb(24, 22, 28), calca = rgb(20, 18, 24), olhos = rgb(200, 60, 255), largura = 0.85 },
	["creature/cavaleiro-da-morte"] = { roupa = rgb(30, 30, 36), calca = rgb(20, 20, 26), olhos = rgb(120, 220, 255), altura = 1.15, largura = 1.1 },
	["creature/lanceiro-demoniaco"] = { pele = rgb(120, 36, 44), roupa = rgb(50, 30, 30) },
	["creature/lich-ancestral"] = { roupa = rgb(60, 30, 80), calca = rgb(40, 20, 60), olhos = rgb(140, 255, 200), altura = 1.1 },
	["creature/general-demonio"] = { altura = 1.35, largura = 1.3 },
	["creature/rei-demonio-menor"] = { altura = 1.4, largura = 1.3, olhos = rgb(255, 120, 40) },
	["creature/rei-demonio-imortal"] = { altura = 1.55, largura = 1.4, olhos = rgb(255, 80, 40) },
	["creature/golem-de-pedra-menor"] = {},
}
local BESTAS = {
	["creature/lobo-cinzento"] = { cor = rgb(120, 122, 128), escala = 1, olhos = rgb(255, 210, 80), lobo = true },
	["creature/rato-gigante"] = { cor = rgb(110, 84, 64), escala = 0.75, olhos = rgb(255, 60, 60), cauda = 2.2 },
	["creature/urso-de-presas-vermelhas"] = { cor = rgb(86, 48, 40), escala = 1.45, olhos = rgb(255, 80, 40), cauda = 0.4, urso = true },
	["creature/aranha-da-floresta"] = { cor = rgb(34, 30, 34), escala = 1.1, olhos = rgb(255, 40, 40), aranha = true },
}

local function aparencia(catalogId: string?, categoria: string?)
	local base = POR_CATEGORIA[categoria or ""]
	if not base then
		return nil
	end
	local ajuste = POR_CRIATURA[catalogId or ""] or {}
	local a = table.clone(base)
	for k, v in ajuste do
		a[k] = v
	end
	return a
end

local function olhos(cabeca: BasePart, cor: Color3, afastamento: number?)
	for _, lado in { -1, 1 } do
		local olho = Instance.new("Part")
		olho.Name = "Olho"
		olho.Shape = Enum.PartType.Ball
		olho.Material = Enum.Material.Neon
		olho.Color = cor
		olho.Size = Vector3.one * math.max(0.14, cabeca.Size.X * 0.13)
		olho.CanCollide, olho.CanTouch, olho.CanQuery, olho.Massless = false, false, false, true
		local w = Instance.new("Weld")
		w.Part0, w.Part1 = cabeca, olho
		w.C0 = CFrame.new(lado * cabeca.Size.X * (afastamento or 0.2), cabeca.Size.Y * 0.08, -cabeca.Size.Z * 0.48)
		w.Parent = olho
		olho.Parent = cabeca
	end
end

local function criarHumanoide(a): Model?
	local d = Instance.new("HumanoidDescription")
	d.HeadColor, d.LeftArmColor, d.RightArmColor = a.pele, a.pele, a.pele
	d.TorsoColor = a.roupa or a.pele
	d.LeftLegColor, d.RightLegColor = a.calca or a.pele, a.calca or a.pele
	d.HeightScale = a.altura or 1
	d.WidthScale = a.largura or 1
	d.DepthScale = a.profundidade or 1
	d.HeadScale = a.cabeca or 1
	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modelo then
		warn("[CorposDeCriatura] rig:", modelo)
		return nil
	end
	for _, s in modelo:GetDescendants() do
		if s:IsA("LuaSourceContainer") then
			s:Destroy()
		end
	end
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoide.BreakJointsOnDeath = false
	if not humanoide:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoide
	end
	local cabeca = modelo:FindFirstChild("Head")
	if cabeca and a.olhos then
		olhos(cabeca, a.olhos)
	end
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		end
	end
	modelo.PrimaryPart = modelo:FindFirstChild("HumanoidRootPart")
	return modelo
end

-- Quadrúpede de peças, todas ancoradas e posicionadas a partir da raiz.
local function criarBesta(b): Model
	local modelo = Instance.new("Model")
	local s = b.escala or 1
	local function peca(nome: string, tamanho: Vector3, deslocamento: CFrame, cor: Color3?, material: Enum.Material?, forma: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = nome
		p.Size = tamanho * s
		p.Color = cor or b.cor
		p.Material = material or Enum.Material.SmoothPlastic
		if forma then
			if forma == Enum.PartType.Ball then
				-- Torso arredondado alongado nos três eixos, sem asset externo.
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, p
			else p.Shape = forma end
		end
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p:SetAttribute("Deslocamento", CFrame.new(deslocamento.Position * s) * deslocamento.Rotation)
		p.Parent = modelo
		return p
	end
	local raiz = peca("HumanoidRootPart", Vector3.new(1, 1, 1), CFrame.new(0, 0, 0))
	raiz.Transparency = 1
	local cabecaBase = if b.aranha then CFrame.new(0, 1.2, -1.4) else CFrame.new(0, 2.7, -2.2)
	if b.aranha then
		peca("Corpo", Vector3.new(2.6, 1.6, 3), CFrame.new(0, 1.3, 0.6))
		peca("Head", Vector3.new(1.5, 1.2, 1.4), cabecaBase)
		for i = 1, 4 do
			for _, lado in { -1, 1 } do
				peca("Perna", Vector3.new(0.18, 0.18, 2.6), CFrame.new(lado * 1.6, 0.9, -1 + i * 0.55) * CFrame.Angles(0.5, lado * 1.3, 0))
			end
		end
	else
		peca("Corpo", if b.urso then Vector3.new(2.3, 2, 3.6) else Vector3.new(1.7, 1.6, 3.6), CFrame.new(0, 2.1, 0), nil, nil, Enum.PartType.Ball)
		peca("Head", Vector3.new(1.3, 1.2, 1.4), cabecaBase, nil, nil, Enum.PartType.Ball)
		peca("Focinho", Vector3.new(0.8, 0.6, 0.9), CFrame.new(0, 2.45, -3.2), b.cor:Lerp(Color3.new(0, 0, 0), 0.25))
		for _, lado in { -1, 1 } do
			peca("Orelha", if b.urso then Vector3.new(.5, .5, .25) else Vector3.new(0.3, 0.6, 0.3), CFrame.new(lado * 0.4, 3.45, -2.1), nil, nil, if b.urso then Enum.PartType.Ball else nil)
			peca("PernaFrente", Vector3.new(0.45, 1.5, 0.45), CFrame.new(lado * 0.55, 0.75, -1.25))
			peca("PernaTras", Vector3.new(0.45, 1.5, 0.45), CFrame.new(lado * 0.55, 0.75, 1.25))
			for _, z in { -1.25, 1.25 } do
				peca("Pata", Vector3.new(.65, .35, .85), CFrame.new(lado * .55, .2, z - .12), b.cor:Lerp(Color3.new(0, 0, 0), .3), nil, Enum.PartType.Ball)
			end
			if b.urso then
				peca("PresaVermelha", Vector3.new(.16, .65, .16), CFrame.new(lado * .3, 2.15, -3.5) * CFrame.Angles(-.2, 0, lado * .12), rgb(205, 91, 67))
			end
		end
		peca("Nariz", Vector3.new(.5, .35, .2), CFrame.new(0, 2.5, -3.68), rgb(25, 23, 25), nil, Enum.PartType.Ball)
		if b.lobo then
			peca("Juba", Vector3.new(1.9, 1.8, 1.1), CFrame.new(0, 2.3, -1.3), b.cor:Lerp(Color3.new(0, 0, 0), .17), nil, Enum.PartType.Ball)
		end
		peca("Cauda", Vector3.new(0.3, 0.3, b.cauda or 1.6), CFrame.new(0, 2.4, 2.4) * CFrame.Angles(0.5, 0, 0))
	end
	for _, lado in { -1, 1 } do
		peca("Olho", Vector3.new(0.2, 0.2, 0.2), cabecaBase * CFrame.new(lado * 0.32, 0.15, -0.7), b.olhos, Enum.Material.Neon, Enum.PartType.Ball)
	end
	modelo.PrimaryPart = raiz
	return modelo
end

-- Põe as peças de uma besta em volta da raiz (balanço de passo opcional).
-- Treant do bestiário: tronco, galhos e copa próprios; ocupa uma casa lógica.
local function criarTreant(): Model
	local modelo=Instance.new("Model")
	local function peca(nome,size,pos,cor,material)
		local p=Instance.new("Part"); p.Name=nome; p.Size=size
		p.Color=cor; p.Material=material or Enum.Material.Wood
		p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
		p:SetAttribute("Deslocamento",CFrame.new(pos)); p.Parent=modelo
		return p
	end
	local madeira=rgb(74,52,34)
	local raiz=peca("HumanoidRootPart",Vector3.one,Vector3.zero,madeira); raiz.Transparency=1
	peca("Tronco",Vector3.new(3,7,2.6),Vector3.new(0,5,0),madeira)
	for _,s in {-1,1} do
		peca("Perna",Vector3.new(1.2,3,1.4),Vector3.new(s,1.5,0),madeira)
		peca("Galho",Vector3.new(1.3,5,1.3),Vector3.new(s*2.2,5,0),madeira)
		peca("Olho",Vector3.new(.35,.5,.2),Vector3.new(s*.7,7,-1.4),rgb(206,240,104),Enum.Material.Neon)
		peca("Copa",Vector3.new(3.5,2.5,3.5),Vector3.new(s*2,9,0),rgb(34,91,46),Enum.Material.Grass)
	end
	peca("Coroa",Vector3.new(4,3,4),Vector3.new(0,10,0),rgb(46,118,57),Enum.Material.Grass)
	modelo.PrimaryPart=raiz
	return modelo
end

local function posarBesta(modelo: Model, cf: CFrame, passo: number?)
	local balanco = passo and math.sin(passo * 14) or 0
	for _, p in modelo:GetChildren() do
		if p:IsA("BasePart") then
			local d = p:GetAttribute("Deslocamento") :: CFrame
			if d then
				local extra = CFrame.identity
				if passo and (p.Name == "PernaFrente" or p.Name == "PernaTras" or p.Name == "Perna" or p.Name == "Pata") then
					local frente = p.Name == "PernaFrente" or (p.Name == "Pata" and d.Position.Z < 0)
					local sinal = if frente == (d.Position.X > 0) then 1 else -1
					extra = CFrame.new(0, 0.6, 0) * CFrame.Angles(balanco * 0.6 * sinal, 0, 0) * CFrame.new(0, -0.6, 0)
					if p.Name == "Pata" then
						local escala = p.Size.X / .65
						local perna = CFrame.new(d.Position.X, .75 * escala, (if frente then -1.25 else 1.25) * escala)
						extra = d:Inverse() * perna * extra * perna:Inverse() * d
					end
				elseif passo then
					extra = CFrame.new(0, math.abs(balanco) * 0.15, 0)
				end
				p.CFrame = cf * d * extra
			end
		end
	end
end

-- deps: fichas(), centro(x, z), secreto(ficha), catalogo
function Corpos.start(deps)
	filtroSecreto = deps.secreto
	local pasta = Instance.new("Folder")
	pasta.Name = "CorposDeCriatura"
	pasta.Parent = workspace
	local corpos: { [string]: any } = {} -- id da ficha -> { modelo, tipo, x, z, conexao, andar, parado }

	local function alturaDaRaiz(c): number
		if c.tipo == "besta" then
			return 0.06
		end
		local h = c.modelo:FindFirstChildOfClass("Humanoid")
		local raiz = c.modelo.PrimaryPart
		return h.HipHeight + raiz.Size.Y / 2
	end

	local function colocar(c, posicao: Vector3, olhando: Vector3?, passo: number?)
		local cf = if olhando and (olhando - posicao).Magnitude > 0.05
			then CFrame.lookAt(posicao, Vector3.new(olhando.X, posicao.Y, olhando.Z))
			else CFrame.new(posicao) * c.rumo
		c.rumo = cf.Rotation
		if c.tipo == "besta" then
			posarBesta(c.modelo, cf, passo)
		else
			c.modelo.PrimaryPart.CFrame = cf
		end
	end

	local function pararCaminhada(c)
		if c.conexao then
			c.conexao:Disconnect()
			c.conexao = nil
		end
		if c.andar then
			c.andar:Stop(0.2)
		end
	end

	local function andar(c, x: number, z: number)
		if c.conexao and c.x and c.z then
			colocar(c, deps.centro(c.x,c.z) + Vector3.new(0,alturaDaRaiz(c),0), nil)
		end
		pararCaminhada(c)
		local raiz = c.modelo.PrimaryPart
		local inicio = raiz.Position
		local fim = deps.centro(x, z) + Vector3.new(0, alturaDaRaiz(c), 0)
		c.x, c.z = x, z
		local distancia = (fim - inicio).Magnitude
		if distancia < 0.05 then
			colocar(c, fim, nil)
			return
		end
		local duracao = math.clamp(distancia / VELOCIDADE, 0.25, 3)
		if c.andar then
			c.andar:Play(0.15, 1, 1.2)
		end
		local comeco = os.clock()
		c.conexao = RunService.Heartbeat:Connect(function()
			if not c.modelo.Parent then
				pararCaminhada(c)
				return
			end
			local t = math.min((os.clock() - comeco) / duracao, 1)
			local olhar = if t >= 1 and c.alvoOlhar then deps.centro(c.alvoOlhar[1], c.alvoOlhar[2]) else fim + (fim - inicio).Unit
			colocar(c, inicio:Lerp(fim, t), olhar, if t < 1 then os.clock() else nil)
			if t >= 1 then
				pararCaminhada(c)
			end
		end)
	end

	local function remover(id: string)
		local c = corpos[id]
		if c then
			pararCaminhada(c)
			c.modelo:Destroy()
			corpos[id] = nil
		end
	end

	-- Derrotado: tomba antes de a ficha sair da mesa.
	local function tombar(c)
		if c.tombado then
			return
		end
		c.tombado = true
		pararCaminhada(c)
		if c.parado then
			c.parado:Stop(0.2)
		end
		local cf0 = if c.tipo == "besta" then CFrame.new(c.modelo.PrimaryPart.Position) * c.rumo else c.modelo.PrimaryPart.CFrame
		local comeco = os.clock()
		c.conexao = RunService.Heartbeat:Connect(function()
			if not c.modelo.Parent then
				pararCaminhada(c)
				return
			end
			local t = math.min((os.clock() - comeco) / 0.45, 1)
			local e = 1 - (1 - t) ^ 3
			local cf = cf0 * CFrame.new(0, -alturaDaRaiz(c) * 0.55 * e, 0) * CFrame.Angles(-math.pi / 2 * e, 0, 0)
			if c.tipo == "besta" then
				posarBesta(c.modelo, cf * CFrame.Angles(math.pi / 2 * e, 0, math.pi / 2 * e), nil)
			else
				c.modelo.PrimaryPart.CFrame = cf
			end
			if t >= 1 then
				pararCaminhada(c)
			end
		end)
	end

	local function criar(token)
		local criatura = token.criatura
		local entrada = criatura and criatura.catalogId and deps.catalogo.POR_ID[criatura.catalogId]
		local categoria = criatura and (criatura.categoria or (entrada and entrada.data.categoria))
		local catalogId = criatura and criatura.catalogId
		local modelo, tipo
		if catalogId == "creature/treant-anciao" then
			modelo, tipo = criarTreant(), "besta"
		elseif BESTAS[catalogId or ""] then
			modelo, tipo = criarBesta(BESTAS[catalogId]), "besta"
		else
			local a = aparencia(catalogId, categoria)
			if not a then
				return nil
			end
			modelo, tipo = criarHumanoide(a), "humanoide"
			if modelo then Visual.humanoide(modelo, catalogId) end
		end
		if not modelo then
			return nil
		end
		modelo.Name = token.id
		local c = { modelo = modelo, tipo = tipo, rumo = CFrame.identity }
		modelo.PrimaryPart.Anchored = true
		modelo.Parent = pasta
		local humanoide = modelo:FindFirstChildOfClass("Humanoid")
		local animator = humanoide and humanoide:FindFirstChildOfClass("Animator")
		if animator then
			local function carregar(id: string, prioridade: Enum.AnimationPriority, repete: boolean)
				local a = Instance.new("Animation")
				a.AnimationId = id
				local ok, faixa = pcall(function()
					return animator:LoadAnimation(a)
				end)
				if ok and faixa then
					faixa.Priority, faixa.Looped = prioridade, repete
					return faixa
				end
				return nil
			end
			c.andar = carregar(ANIM_ANDAR, Enum.AnimationPriority.Movement, true)
			c.parado = carregar(ANIM_PARADO, Enum.AnimationPriority.Idle, true)
			if c.parado then
				c.parado:Play()
			end
		end
		-- Nasce já na casa, olhando para o centro do tabuleiro.
		local posicao = deps.centro(token.x, token.z) + Vector3.new(0, alturaDaRaiz(c), 0)
		local dx, dz = Visao.direcao(token)
		colocar(c, posicao, posicao + Vector3.new(dx, 0, dz))
		c.x, c.z = token.x, token.z
		corpos[token.id] = c
		return c
	end

	local api = {}

	function api.sincronizar()
		local vistos = {}
		for _, token in deps.fichas() do
			if token.criatura and not deps.secreto(token) then
				vistos[token.id] = true
				local c = corpos[token.id] or criar(token)
				if c then
					local caido = token.derrotado or token.pv <= 0
					for _, cond in token.conditions or {} do if cond.id == "caido" or cond.id == "inconsciente" then caido = true end end
					if caido then
						tombar(c)
					elseif c.tombado then
						pararCaminhada(c); c.tombado = false
						local p = deps.centro(token.x, token.z) + Vector3.new(0, alturaDaRaiz(c), 0)
						local dx, dz = Visao.direcao(token)
						colocar(c, p, p + Vector3.new(dx, 0, dz))
						if c.parado then c.parado:Play(.2) end
					elseif c.x ~= token.x or c.z ~= token.z then
						andar(c, token.x, token.z)
					elseif not c.conexao then
						local dx, dz = Visao.direcao(token)
						local p = c.modelo.PrimaryPart.Position
						colocar(c, p, p + Vector3.new(dx, 0, dz))
					end
				end
			end
		end
		for id in corpos do
			if not vistos[id] then
				remover(id)
			end
		end
	end

	function api.moveu(token)
		local c = corpos[token.id]
		if c and not deps.secreto(token) and not c.tombado then
			andar(c, token.x, token.z)
		end
	end

	function api.tem(token): boolean
		return corpos[token.id] ~= nil
	end

	-- Vira o corpo para um ponto (ex.: o alvo do golpe).
	function api.olhar(token, x: number, z: number)
		local c = corpos[token.id]
		if c then c.alvoOlhar = {x,z} end
		if c and not c.conexao and not c.tombado then
			local p = c.modelo.PrimaryPart.Position
			colocar(c, p, deps.centro(x, z) + Vector3.new(0, p.Y - deps.centro(x, z).Y, 0))
		end
	end

	return api
end

return Corpos
