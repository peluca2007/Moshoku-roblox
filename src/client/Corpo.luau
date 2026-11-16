-- Corpo de cena (A5): um "fantasma" local do personagem ou da miniatura, que
-- faz o gesto (avançar, golpear, gritar) enquanto o corpo real fica escondido
-- só nesta tela. Nada aqui muda posição, ficha ou colisão do corpo real: o
-- servidor continua dono de onde cada ficha está.
local Players = game:GetService("Players")
local Tocador = require(script.Parent.TocadorClipe)

local Corpo = {}

local MAX_FANTASMAS = 6
local ativos = 0
-- modelo real -> quantos gestos o escondem agora (contador evita reaparecer cedo).
local ocultos: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Modelo da ficha: o personagem do dono (se a ficha é avatar) ou a miniatura.
function Corpo.modeloDe(state, tokenId: string?): (Model?, boolean)
	if not tokenId then
		return nil, false
	end
	if state.modeloDe then return state.modeloDe(tokenId) end
	local token = state.findToken and state.findToken(tokenId)
	if token and token.avatar then
		local dono = Players:GetPlayerByUserId(token.ownerUserId)
		local personagem = dono and dono.Character
		if personagem and personagem.Parent and personagem:FindFirstChild("HumanoidRootPart") then
			return personagem, true
		end
	end
	-- Criatura com corpo: o gesto copia o corpo (com Humanoid, reage como personagem).
	local corpos = workspace:FindFirstChild("CorposDeCriatura")
	local corpo = corpos and corpos:FindFirstChild(tokenId)
	if corpo and corpo:IsA("Model") and corpo.PrimaryPart then
		return corpo, corpo:FindFirstChildOfClass("Humanoid") ~= nil
	end
	local minis = workspace:FindFirstChild("MesaFichasLocais")
	local mini = minis and minis:FindFirstChild(tokenId)
	if mini and mini:IsA("Model") then
		return mini, false
	end
	return nil, false
end

local function partesDe(modelo: Instance)
	local lista = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(lista, d)
		end
	end
	return lista
end

-- Esconde (ou mostra) o corpo real só no cliente local. Conta pedidos.
-- IMP3: o corpo real aparecia junto do fantasma ("duas cabeças") quando a contagem já estava acima de zero (pedido
-- anterior sem reveal) e o pedido novo não reaplicava nada, ou quando peças nascem depois (cabelo/arma da
-- aparência). Agora cada pedido reaplica e, enquanto houver corpo escondido, um laço de render mantém todas as
-- peças (inclusive as novas) com LocalTransparencyModifier = 1.
local guarda: RBXScriptConnection? = nil
-- fantasmas vivos por corpo real: sem fantasma, nada justifica o corpo escondido (cura vazamento de contagem)
local vivos: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local function aplicar(modelo: Instance, valor: number)
	for _, p in partesDe(modelo) do
		if p.LocalTransparencyModifier ~= valor then
			p.LocalTransparencyModifier = valor
		end
	end
end
local function manterEscondidos()
	if guarda or next(ocultos) == nil then
		return
	end
	guarda = game:GetService("RunService").RenderStepped:Connect(function()
		local algum = false
		for modelo in ocultos do
			if modelo.Parent and (vivos[modelo] or 0) > 0 then
				algum = true
				aplicar(modelo, 1)
			else
				ocultos[modelo] = nil
				aplicar(modelo, 0)
			end
		end
		if not algum and guarda then
			guarda:Disconnect()
			guarda = nil
		end
	end)
end

function Corpo.ocultar(modelo: Model, esconder: boolean)
	local antes = ocultos[modelo] or 0
	local depois = math.max(0, antes + (if esconder then 1 else -1))
	ocultos[modelo] = if depois > 0 then depois else nil
	aplicar(modelo, if depois > 0 then 1 else 0)
	if depois > 0 then
		manterEscondidos()
	end
end

function Corpo.escondidos(): number
	local n = 0
	for _ in ocultos do
		n += 1
	end
	return n
end

function Corpo.ativos(): number
	return ativos
end

local function juntaDe(modelo: Instance, nomes: { string }): Motor6D?
	for _, nome in nomes do
		local j = modelo:FindFirstChild(nome, true)
		if j and j:IsA("Motor6D") then
			return j
		end
	end
	return nil
end

-- Cria o fantasma como filho de `pai` (quem destrói `pai` destrói o fantasma).
-- Devolve nil se o orçamento acabou ou o modelo não pode ser copiado.
function Corpo.fantasma(modelo: Model, pai: Instance)
	if ativos >= MAX_FANTASMAS then
		return nil
	end
	local arquivavel = modelo.Archivable
	modelo.Archivable = true
	local ok, copia = pcall(function()
		return modelo:Clone()
	end)
	modelo.Archivable = arquivavel
	if not ok or not copia then
		return nil
	end
	for _, d in copia:GetDescendants() do
		-- O Humanoid fica: sem ele a roupa (Shirt/Pants, roupa em camadas) e as cores
		-- do corpo não aparecem e o fantasma "fica pelado".
		if d:IsA("LuaSourceContainer") or d:IsA("Sound")
			or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("Tool") then
			d:Destroy()
		end
	end
	-- Rigs novos usam AnimationConstraint/RigidConstraint, que dependem da física.
	-- No fantasma (raiz ancorada) viram Motor6D/Weld: mesma geometria, e o Animator
	-- continua tocando animações neles.
	for _, d in copia:GetDescendants() do
		if d:IsA("AnimationConstraint") or d:IsA("RigidConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			local p0, p1 = a0 and a0.Parent, a1 and a1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local junta = Instance.new(if d:IsA("AnimationConstraint") then "Motor6D" else "Weld")
				junta.Name = d.Name
				junta.Part0, junta.Part1, junta.C0, junta.C1 = p0, p1, a0.CFrame, a1.CFrame
				junta.Parent = p1
			end
		end
	end
	for _, d in copia:GetDescendants() do
		if d:IsA("Constraint") then
			d:Destroy()
		end
	end
	local raiz = copia:FindFirstChild("HumanoidRootPart") or copia.PrimaryPart
	local temJunta = false
	for _, d in copia:GetDescendants() do
		if d:IsA("Motor6D") then
			temJunta = true
			break
		end
	end
	for _, p in partesDe(copia) do
		p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
		p.LocalTransparencyModifier = 0
		if temJunta and raiz then
			p.Anchored = p == raiz
			p.Massless = p ~= raiz
		else
			p.Anchored = true
		end
	end
	if raiz then
		raiz.Transparency = 1
	end
	local humanoide = copia:FindFirstChildOfClass("Humanoid")
	local animator = nil
	if humanoide then
		humanoide.EvaluateStateMachine = false
		humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoide.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoide.BreakJointsOnDeath = false
		humanoide.RequiresNeck = false
		animator = humanoide:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoide
	end
	copia.Name = "Fantasma"
	copia:SetAttribute("FantasmaDe", modelo.Name) -- QA: conta corpos visíveis por personagem
	copia.Parent = pai
	ativos += 1
	vivos[modelo] = (vivos[modelo] or 0) + 1
	local f = {
		modelo = copia,
		raiz = raiz,
		original = modelo,
		viva = true,
		juntas = {
			ombroD = juntaDe(copia, { "RightShoulder", "Right Shoulder" }),
			ombroE = juntaDe(copia, { "LeftShoulder", "Left Shoulder" }),
			cintura = juntaDe(copia, { "Waist" }),
			pescoco = juntaDe(copia, { "Neck" }),
		},
		r15 = juntaDe(copia, { "RightShoulder" }) ~= nil,
		animator = animator,
		faixas = {},
	}
	copia.Destroying:Connect(function()
		if f.viva then
			f.viva = false
			ativos -= 1
		end
		vivos[modelo] = math.max((vivos[modelo] or 1) - 1, 0)
	end)
	return f
end

function Corpo.destruir(f)
	if f and f.viva then
		f.viva = false
		ativos -= 1
		f.modelo:Destroy()
	end
end

-- Animações padrão do Roblox (as mesmas do script Animate de todo personagem).
-- O ID vem do próprio personagem, para respeitar o pacote de animações dele.
local PADRAO = {
	toolslash = "rbxassetid://522635514", toollunge = "rbxassetid://522638767", toolnone = "rbxassetid://507768375",
	point = "rbxassetid://507770453", cheer = "rbxassetid://507770677", wave = "rbxassetid://507770239",
	laugh = "rbxassetid://507770818", run = "rbxassetid://913376220", jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968", idle = "rbxassetid://507766388",
}
local function idDaAnimacao(original: Instance?, nome: string): string?
	local animate = original and original:FindFirstChild("Animate")
	local pasta = animate and animate:FindFirstChild(nome)
	if pasta then
		for _, a in pasta:GetChildren() do
			if a:IsA("Animation") and a.AnimationId ~= "" then
				return a.AnimationId
			end
		end
	end
	return PADRAO[nome]
end

-- Toca uma animação no fantasma. Sem Animator (miniatura), devolve nil e os gestos
-- usam a pose por código. Opções: velocidade, repete, prioridade, peso.
function Corpo.animar(f, nome: string, opcoes: { velocidade: number?, repete: boolean?, prioridade: Enum.AnimationPriority? }?)
	if not f or not f.viva or not f.animator or f.clipes then
		return nil
	end
	local o = opcoes or {}
	local faixa = f.faixas[nome]
	if not faixa then
		local id = idDaAnimacao(f.original, nome)
		if not id then
			return nil
		end
		local animacao = Instance.new("Animation")
		animacao.AnimationId = id
		local ok, carregada = pcall(function()
			return f.animator:LoadAnimation(animacao)
		end)
		if not ok or not carregada then
			return nil
		end
		faixa = carregada
		f.faixas[nome] = faixa
	end
	faixa.Looped = o.repete == true
	faixa.Priority = o.prioridade or Enum.AnimationPriority.Action
	faixa:Play(0.06, 1, o.velocidade or 1)
	f.animado = true
	return faixa
end

function Corpo.parar(f, nome: string)
	local faixa = f and f.faixas and f.faixas[nome]
	if faixa then
		faixa:Stop(0.1)
	end
end

-- Clipes por dados (LUTA-A) no fantasma R15: devolve o TocadorClipe do fantasma (criado na primeira
-- chamada) ou nil sem R15. A partir daí as poses por código (braco/tronco) e as animações do Roblox
-- (animar) deixam de mexer nas juntas: quem manda é o clipe.
function Corpo.tocador(f)
	if not f or not f.viva or not f.r15 then
		return nil
	end
	if not f.clipes then
		local ok, t = pcall(Tocador.novo, f.modelo)
		if not ok then
			warn("[Corpo] tocador:", t)
			return nil
		end
		f.clipes = t
		for _, faixa in f.faixas do
			faixa:Stop(0)
		end
	end
	return f.clipes
end

-- Pose do braço (R15): ângulos em radianos. frente > 0 levanta o braço para a
-- frente do corpo; lado > 0 abre o braço para fora. Sem R15, ignora.
function Corpo.braco(f, qual: string, frente: number, lado: number?)
	local j = f.juntas[if qual == "d" then "ombroD" else "ombroE"]
	if not j or not f.r15 or f.animado or f.clipes then
		return
	end
	local fora = if qual == "d" then (lado or 0) else -(lado or 0)
	j.Transform = CFrame.Angles(frente, 0, fora)
end

function Corpo.tronco(f, inclina: number, gira: number?)
	local j = f.juntas.cintura
	if j and not f.animado and not f.clipes then
		j.Transform = CFrame.Angles(-inclina, gira or 0, 0)
	end
end

-- Posiciona o fantasma: posição no mundo, olhando para `olhar` (plano) e
-- inclinado `pitch` (negativo = para a frente) e rolando `rolar` sobre o eixo de frente.
function Corpo.por(f, posicao: Vector3, olhar: Vector3?, pitch: number?, rolar: number?, giro: number?)
	local dir = olhar
	local base
	if dir and Vector3.new(dir.X, 0, dir.Z).Magnitude > 1e-3 then
		base = CFrame.lookAt(posicao, posicao + Vector3.new(dir.X, 0, dir.Z))
	else
		base = CFrame.new(posicao) * (f.rumo or CFrame.identity).Rotation
	end
	f.rumo = base.Rotation
	f.modelo:PivotTo(base * CFrame.Angles(pitch or 0, giro or 0, rolar or 0))
end

-- Peças de arma na mão do fantasma. A lâmina nasce ao longo de -Y da mão: com o
-- braço levantado para a frente, aponta para a frente.
local function peca(f, tamanho: Vector3, cor: Color3, material: Enum.Material, brilho: boolean?)
	local p = Instance.new("Part")
	p.Size, p.Color, p.Material = tamanho, cor, material
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow, p.Massless = false, false, false, false, true
	p.Anchored = false
	if brilho then
		p.Material = Enum.Material.Neon
	end
	p.Parent = f.modelo
	return p
end
local function soldar(a: BasePart, b: BasePart, deslocamento: CFrame)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = a, b, deslocamento
	w.Parent = b
end

local METAL = Color3.fromRGB(205, 212, 226)
local MADEIRA = Color3.fromRGB(92, 66, 46)

-- tipo: "espada" | "pesada" | "gelo" | "escudo" | "arco" | "adaga"
-- Com clipe (f.clipes), a pega é a dos clipes do ANIM1 (tools/animacao/README.md): a lâmina sai do punho
-- para -Z da mão (perpendicular ao antebraço) e o arco fica vertical na mão esquerda, curvado para a frente.
function Corpo.arma(f, tipo: string, cor: Color3?)
	local pegaClipe = f.clipes ~= nil
	local mao = f.modelo:FindFirstChild("RightHand") or f.modelo:FindFirstChild("Right Arm")
	local maoE = f.modelo:FindFirstChild("LeftHand") or f.modelo:FindFirstChild("Left Arm")
	local pecas = {}
	local function nova(...)
		local p = peca(f, ...)
		table.insert(pecas, p)
		return p
	end
	if tipo == "escudo" then
		if not maoE then return pecas end
		local disco = nova(Vector3.new(0.25, 2.1, 2.1), cor or Color3.fromRGB(150, 156, 170), Enum.Material.Metal)
		disco.Shape = Enum.PartType.Cylinder
		local borda = nova(Vector3.new(0.29, 0.9, 0.9), cor or METAL, Enum.Material.Metal)
		borda.Shape = Enum.PartType.Cylinder
		-- Cilindro tem o eixo em X: gira para a face olhar para a frente (-Z).
		soldar(maoE :: BasePart, disco, CFrame.new(0, -0.3, -0.9) * CFrame.Angles(0, math.pi / 2, 0))
		soldar(disco, borda, CFrame.new(-0.12, 0, 0))
	elseif tipo == "arco" then
		if not maoE then return pecas end
		if pegaClipe then
			-- Mão fechada no meio do arco; o arco se estende ao longo de Z da mão (vertical com o braço
			-- estendido) e a curva vai para -Y da mão (para o alvo). A corda é desenhada pelo gesto.
			local N, meio, curva = 9, 1.4, 0.45
			local function ponto(a)
				return Vector3.new(0, -0.15 - math.cos(a) * curva, math.sin(a) * meio)
			end
			for i = 1, N do
				local a0 = ((i - 1) / N - 0.5) * math.pi * 0.9
				local a1 = (i / N - 0.5) * math.pi * 0.9
				local p0, p1 = ponto(a0), ponto(a1)
				local meioSeg = (p0 + p1) / 2
				local eixo = (p1 - p0).Unit
				local seg = nova(Vector3.new(0.16, (p1 - p0).Magnitude + 0.05, 0.2), MADEIRA, Enum.Material.Wood)
				soldar(maoE :: BasePart, seg, CFrame.fromMatrix(meioSeg, Vector3.xAxis, eixo, Vector3.xAxis:Cross(eixo)))
			end
			f.pontasArco = { ponto(-math.pi * 0.45), ponto(math.pi * 0.45) }
			f.maoArco = maoE
		else
		local N = 7
		for i = 1, N do
			local a = (i - 0.5) / N * math.pi - math.pi / 2
			local seg = nova(Vector3.new(0.14, 0.9, 0.14), MADEIRA, Enum.Material.Wood)
			soldar(maoE :: BasePart, seg, CFrame.new(0, -0.4, -0.2 - math.cos(a) * 0.4) * CFrame.new(0, math.sin(a) * 1.4, 0) * CFrame.Angles(math.cos(a) * 0.45, 0, 0))
		end
		local corda = nova(Vector3.new(0.04, 3.3, 0.04), METAL, Enum.Material.Neon)
		soldar(maoE :: BasePart, corda, CFrame.new(0, -0.4, 0.2))
		end
	elseif mao then
		-- IMP5: armas proporcionais ao corpo R15 (~5 studs de altura): espada de uma mão com ~3 studs no total
		-- (cabo, pomo, guarda, lâmina estreita com ponta chanfrada e fio mais claro), sem Neon (estourava no Bloom).
		-- Convenção: a arma nasce ao longo de -Y do punho; "Ponta" e "BaseLamina" são Attachments para o rastro do golpe.
		local pesada = tipo == "pesada"
		local AACO = Color3.fromRGB(168, 174, 188)
		local OURO = Color3.fromRGB(176, 140, 70)
		local punho = nova(Vector3.new(0.17, if pesada then 1.0 else 0.7, 0.17), MADEIRA, Enum.Material.Wood)
		soldar(mao :: BasePart, punho, if pegaClipe then CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(90), 0, 0) else CFrame.new(0, -0.25, 0))
		if tipo == "espada" or tipo == "gelo" or tipo == "adaga" then
			local gelo = tipo == "gelo"
			local adaga = tipo == "adaga"
			local compMain = if adaga then 0.8 else 2.0
			local larg = if adaga then 0.18 else 0.2
			local corLamina = if gelo then Color3.fromRGB(170, 220, 250) else AACO
			local mat = if gelo then Enum.Material.Glass else Enum.Material.Metal
			local pomo = nova(Vector3.new(0.26, 0.26, 0.26), OURO, Enum.Material.Metal)
			pomo.Shape = Enum.PartType.Ball
			soldar(punho, pomo, CFrame.new(0, 0.43, 0))
			local guarda = nova(Vector3.new(0.12, 0.12, if adaga then 0.5 else 0.8), OURO, Enum.Material.Metal)
			soldar(punho, guarda, CFrame.new(0, -0.4, 0))
			local lamina = nova(Vector3.new(0.07, compMain, larg), corLamina, mat)
			soldar(punho, lamina, CFrame.new(0, -0.46 - compMain / 2, 0))
			-- fio: tira mais clara na borda de baixo (gume), sem brilho
			local fio = nova(Vector3.new(0.075, compMain, 0.05), Color3.fromRGB(226, 230, 240), mat)
			soldar(lamina, fio, CFrame.new(0, 0, larg / 2 - 0.025))
			-- ponta chanfrada: cunha com a altura ao longo da largura da lâmina e o comprimento rumo à ponta
			local compPonta = if adaga then 0.3 else 0.5
			local ponta = Instance.new("WedgePart")
			ponta.Size = Vector3.new(0.07, larg, compPonta)
			ponta.Color, ponta.Material = corLamina, mat
			ponta.CanCollide, ponta.CanTouch, ponta.CanQuery, ponta.CastShadow, ponta.Massless, ponta.Anchored = false, false, false, false, true, false
			ponta.Parent = f.modelo
			table.insert(pecas, ponta)
			soldar(lamina, ponta, CFrame.fromMatrix(Vector3.new(0, -(compMain + compPonta) / 2, 0), Vector3.xAxis, Vector3.zAxis, -Vector3.yAxis))
			local aPonta, aBase = Instance.new("Attachment"), Instance.new("Attachment")
			aPonta.Name, aBase.Name = "Ponta", "BaseLamina"
			aPonta.Position, aBase.Position = Vector3.new(0, -(compMain / 2 + compPonta), 0), Vector3.new(0, compMain / 2, 0)
			aPonta.Parent, aBase.Parent = lamina, lamina
		else
			-- machado/martelo: cabo de ~2,5 studs e cabeça compacta
			local cabo = nova(Vector3.new(0.2, 2.2, 0.2), MADEIRA, Enum.Material.Wood)
			soldar(punho, cabo, CFrame.new(0, -1.15, 0))
			local cabeca = nova(Vector3.new(0.35, 0.8, 1.3), Color3.fromRGB(120, 124, 138), Enum.Material.Metal)
			soldar(cabo, cabeca, CFrame.new(0, -1.0, 0))
			local aPonta, aBase = Instance.new("Attachment"), Instance.new("Attachment")
			aPonta.Name, aBase.Name = "Ponta", "BaseLamina"
			aPonta.Position, aBase.Position = Vector3.new(0, -1.0, 0.65), Vector3.new(0, -1.0, -0.65)
			aPonta.Parent, aBase.Parent = cabeca, cabeca
		end
	end
	return pecas
end

-- Última arma vista nos recibos de cada personagem (LUTA-A): AnimacaoLuta põe essa arma na mão do avatar
-- em postura de combate. Chave fraca: some com o personagem.
Corpo.armasVistas = setmetatable({}, { __mode = "k" }) :: { [Instance]: string }

-- Arma dos golpes: pelo nome da arma do inventário (vem no recibo).
function Corpo.tipoDeArma(nome: string?): string
	local n = string.lower(nome or "")
	for _, chave in { "arco", "besta" } do
		if string.find(n, chave, 1, true) then return "arco" end
	end
	for _, chave in { "machado", "martelo", "maça", "maca", "montante", "clava", "alabarda", "marreta", "mangual", "glaive" } do
		if string.find(n, chave, 1, true) then return "pesada" end
	end
	for _, chave in { "adaga", "punhal", "faca", "estilete" } do
		if string.find(n, chave, 1, true) then return "adaga" end
	end
	return "espada"
end

return Corpo
