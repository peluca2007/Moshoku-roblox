-- Corpo de cena (A5): um "fantasma" local do personagem ou da miniatura, que
-- faz o gesto (avançar, golpear, gritar) enquanto o corpo real fica escondido
-- só nesta tela. Nada aqui muda posição, ficha ou colisão do corpo real: o
-- servidor continua dono de onde cada ficha está.
local Players = game:GetService("Players")

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
function Corpo.ocultar(modelo: Model, esconder: boolean)
	local antes = ocultos[modelo] or 0
	local depois = math.max(0, antes + (if esconder then 1 else -1))
	ocultos[modelo] = if depois > 0 then depois else nil
	if (antes == 0) == (depois == 0) then
		return
	end
	local valor = if depois > 0 then 1 else 0
	for _, p in partesDe(modelo) do
		p.LocalTransparencyModifier = valor
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
	copia.Parent = pai
	ativos += 1
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
	if not f or not f.viva or not f.animator then
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

-- Pose do braço (R15): ângulos em radianos. frente > 0 levanta o braço para a
-- frente do corpo; lado > 0 abre o braço para fora. Sem R15, ignora.
function Corpo.braco(f, qual: string, frente: number, lado: number?)
	local j = f.juntas[if qual == "d" then "ombroD" else "ombroE"]
	if not j or not f.r15 or f.animado then
		return
	end
	local fora = if qual == "d" then (lado or 0) else -(lado or 0)
	j.Transform = CFrame.Angles(frente, 0, fora)
end

function Corpo.tronco(f, inclina: number, gira: number?)
	local j = f.juntas.cintura
	if j and not f.animado then
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

local METAL = Color3.fromRGB(168, 176, 190)
local MADEIRA = Color3.fromRGB(92, 66, 46)

-- tipo: "espada" | "pesada" | "gelo" | "escudo" | "arco" | "adaga"
function Corpo.arma(f, tipo: string, cor: Color3?)
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
		local disco = nova(Vector3.new(0.3, 2.8, 2.8), cor or Color3.fromRGB(150, 156, 170), Enum.Material.Metal)
		disco.Shape = Enum.PartType.Cylinder
		local borda = nova(Vector3.new(0.34, 1.2, 1.2), cor or METAL, Enum.Material.Neon)
		borda.Shape = Enum.PartType.Cylinder
		-- Cilindro tem o eixo em X: gira para a face olhar para a frente (-Z).
		soldar(maoE :: BasePart, disco, CFrame.new(0, -0.3, -0.9) * CFrame.Angles(0, math.pi / 2, 0))
		soldar(disco, borda, CFrame.new(-0.12, 0, 0))
	elseif tipo == "arco" then
		if not maoE then return pecas end
		local N = 7
		for i = 1, N do
			local a = (i - 0.5) / N * math.pi - math.pi / 2
			local seg = nova(Vector3.new(0.14, 0.9, 0.14), MADEIRA, Enum.Material.Wood)
			soldar(maoE :: BasePart, seg, CFrame.new(0, -0.4, -0.2 - math.cos(a) * 0.4) * CFrame.new(0, math.sin(a) * 1.4, 0) * CFrame.Angles(math.cos(a) * 0.45, 0, 0))
		end
		local corda = nova(Vector3.new(0.04, 3.3, 0.04), METAL, Enum.Material.Neon)
		soldar(maoE :: BasePart, corda, CFrame.new(0, -0.4, 0.2))
	elseif mao then
		local pesada = tipo == "pesada"
		local punho = nova(Vector3.new(0.22, pesada and 1.4 or 0.9, 0.22), MADEIRA, Enum.Material.Wood)
		soldar(mao :: BasePart, punho, CFrame.new(0, -0.25, 0))
		if tipo == "espada" or tipo == "gelo" then
			local gelo = tipo == "gelo"
			local lamina = nova(Vector3.new(0.12, 3.6, 0.42), gelo and Color3.fromRGB(175, 225, 255) or METAL, gelo and Enum.Material.Glass or Enum.Material.Metal)
			soldar(punho, lamina, CFrame.new(0, -2.15, 0))
			local fio = nova(Vector3.new(0.05, 3.5, 0.06), cor or Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
			fio.Transparency = if gelo then 0.3 else 0.2
			soldar(lamina, fio, CFrame.new(0, 0, -0.22)) -- gume brilhante numa borda só
			local guarda = nova(Vector3.new(0.22, 0.22, 1.2), Color3.fromRGB(150, 118, 60), Enum.Material.Metal)
			soldar(punho, guarda, CFrame.new(0, -0.55, 0))
		elseif tipo == "adaga" then
			local lamina = nova(Vector3.new(0.1, 1.6, 0.34), METAL, Enum.Material.Metal)
			soldar(punho, lamina, CFrame.new(0, -1.2, 0))
		else
			local cabo = nova(Vector3.new(0.26, 3.4, 0.26), MADEIRA, Enum.Material.Wood)
			soldar(punho, cabo, CFrame.new(0, -1.4, 0))
			local cabeca = nova(Vector3.new(1.0, 1.1, 2.0), Color3.fromRGB(120, 124, 138), Enum.Material.Metal)
			soldar(cabo, cabeca, CFrame.new(0, -1.7, 0))
		end
	end
	return pecas
end

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
