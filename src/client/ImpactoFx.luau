-- IMP1/IMP2: efeitos do golpe na luta: faíscas direcionais, corte desenhado, flash de crítico, hit-stop de corpo
-- animado pelo servidor e rastro da arma. Peças locais (nascem em `pai`, que é o modelo da cena e morre com ela).
-- Texturas nativas do Roblox (rbxasset), nenhum asset enviado.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage").Shared
local Curvas = require(Shared.ImpactoCurvas)
local FX = require(script.Parent.MenuEfeitos)

local M = {}
local TEX_BRILHO = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FUMACA = "rbxasset://textures/particles/smoke_main.dds"

local function plano(v: Vector3): Vector3
	local p = Vector3.new(v.X, 0, v.Z)
	return if p.Magnitude > 1e-3 then p.Unit else Vector3.zAxis
end

-- Faíscas direcionais: saem do contato no sentido do golpe (`direcao`: de quem bateu para quem apanhou),
-- riscos esticados pela velocidade, mais algumas estrelas e um pouco de poeira. Sem clarão esférico.
function M.faiscas(pai: Instance, ponto: Vector3, cor: Color3, dano: number?, critico: boolean?, direcao: Vector3?)
	if FX.reduzidos then return end
	local base = Instance.new("Part")
	base.Name, base.Anchored, base.CanCollide, base.CanTouch, base.CanQuery = "Faiscas", true, false, false, false
	base.Transparency, base.Size, base.CastShadow = 1, Vector3.one * 0.2, false
	local u = plano(direcao or Vector3.zAxis)
	base.CFrame = CFrame.lookAt(ponto, ponto + u + Vector3.new(0, 0.3, 0))
	base.Parent = pai
	local at = Instance.new("Attachment")
	at.Parent = base
	local quente = cor:Lerp(Color3.fromRGB(255, 190, 90), 0.5)

	local risco = Instance.new("ParticleEmitter")
	risco.Name, risco.Texture, risco.Rate, risco.Enabled = "Risco", TEX_BRILHO, 0, false
	risco.LightEmission, risco.LockedToPart, risco.Orientation = 1, false, Enum.ParticleOrientation.VelocityParallel
	risco.Color = ColorSequence.new(Color3.fromRGB(255, 250, 225), quente)
	risco.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if critico then 1.1 else 0.8), NumberSequenceKeypoint.new(1, 0.1) })
	risco.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 1) })
	risco.Lifetime = NumberRange.new(0.18, if critico then 0.5 else 0.36)
	risco.Speed = NumberRange.new(if critico then 30 else 22, if critico then 70 else 50)
	risco.Acceleration = Vector3.new(0, -30, 0)
	risco.Drag = 2
	risco.EmissionDirection = Enum.NormalId.Front
	risco.SpreadAngle = Vector2.new(30, 30)
	risco.Parent = at

	local estrela = Instance.new("ParticleEmitter")
	estrela.Name, estrela.Texture, estrela.Rate, estrela.Enabled = "Estrela", TEX_BRILHO, 0, false
	estrela.LightEmission, estrela.LockedToPart = 1, false
	estrela.Color = ColorSequence.new(Color3.new(1, 1, 1), quente)
	estrela.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	estrela.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	estrela.Lifetime = NumberRange.new(0.2, 0.45)
	estrela.Speed = NumberRange.new(8, 24)
	estrela.Acceleration = Vector3.new(0, -34, 0)
	estrela.EmissionDirection = Enum.NormalId.Front
	estrela.SpreadAngle = Vector2.new(75, 75)
	estrela.Rotation = NumberRange.new(0, 360)
	estrela.Parent = at

	local poeira = Instance.new("ParticleEmitter")
	poeira.Name, poeira.Texture, poeira.Rate, poeira.Enabled = "Poeira", TEX_FUMACA, 0, false
	poeira.Color = ColorSequence.new(Color3.fromRGB(150, 140, 125))
	poeira.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
	poeira.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	poeira.Lifetime = NumberRange.new(0.35, 0.6)
	poeira.Speed = NumberRange.new(2, 7)
	poeira.SpreadAngle = Vector2.new(180, 180)
	poeira.Parent = at

	local n = Curvas.faiscas(dano, critico)
	risco:Emit(n)
	estrela:Emit(math.floor(n / 2))
	poeira:Emit(if critico then 5 else 2)
	return base
end

-- Corte desenhado: arco de lâmina (peças neon finas, afinando nas pontas) que varre rápido e some em ~0,2 s.
-- Fica num plano de frente para a câmera (sempre legível), inclinado na diagonal e curvado para quem bateu.
-- `direcao`: de quem bateu para quem apanhou. No crítico, um segundo arco cruza o primeiro.
function M.corte(pai: Instance, ponto: Vector3, direcao: Vector3, cor: Color3, critico: boolean?)
	if FX.reduzidos then return end
	local cam = workspace.CurrentCamera
	local dir = plano(direcao)
	local direita = if cam then cam.CFrame.RightVector else Vector3.xAxis
	local cima = if cam then cam.CFrame.UpVector else Vector3.yAxis
	local sinal = if direita:Dot(dir) >= 0 then 1 else -1 -- varre no sentido do golpe visto pela câmera
	local arcos = { { roll = math.rad(32), L = 5.6 } }
	if critico then
		arcos[1].L = 6.8
		table.insert(arcos, { roll = math.rad(-30), L = 6 })
	end
	local N = 14
	local pecas = {}
	for ai, arco in arcos do
		local a = (direita * math.cos(arco.roll) + cima * math.sin(arco.roll)) * sinal
		for k = 1, N do
			local par = {}
			for camada = 1, 2 do
				local p = Instance.new("Part")
				p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = "Corte", true, false, false, false, false
				p.Material, p.Transparency, p.Size = Enum.Material.Neon, 1, Vector3.one * 0.1
				p.Color = if camada == 1 then Color3.fromRGB(255, 150, 50) else Color3.fromRGB(255, 236, 190)
				p.Parent = pai
				par[camada] = p
			end
			table.insert(pecas, { par = par, a = a, k = k, arco = arco, atraso = (ai - 1) * 0.04 })
		end
	end
	local DUR = (if critico then 0.26 else 0.2) * math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1) -- escala: só inspeção
	local inicio = os.clock()
	local function pontoDe(arco, a, s)
		local bow = 1 - (2 * s - 1) ^ 2
		return ponto + Vector3.new(0, 0.5, 0) + a * ((s - 0.5) * arco.L) - dir * (bow * 0.9)
	end
	local con
	con = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - inicio) / DUR
		if u >= 1 or not pai.Parent then
			con:Disconnect()
			for _, e in pecas do
				for _, p in e.par do p:Destroy() end
			end
			return
		end
		for _, e in pecas do
			local s0, s1 = (e.k - 1) / N, e.k / N
			local nascer = (s0 * 0.4) + e.atraso / DUR
			local vida = (u - nascer) / 0.6
			local tr = math.clamp(vida, 0, 1)
			local largura = math.sin((s0 + s1) * math.pi / 2) ^ 0.8 * (if critico then 0.36 else 0.24)
			local a, b = pontoDe(e.arco, e.a, s0), pontoDe(e.arco, e.a, s1)
			local meio = (a + b) / 2
			local comp = math.max((b - a).Magnitude * 1.15, 0.05)
			for camada, p in e.par do
				local larg = largura * (if camada == 1 then 1.3 else 0.25)
				p.Size = Vector3.new(larg, larg, comp)
				p.CFrame = CFrame.lookAt(meio, meio + (b - a))
				p.Transparency = if vida < 0 then 1 else math.clamp(tr + (if camada == 1 then 0.45 else 0.05), 0, 1)
			end
		end
	end)
end

-- Flash curto de tela (crítico): ColorCorrection que clareia e volta em ~0,14 s.
function M.flash(forca: number?)
	if FX.reduzidos then return end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name, cc.Brightness, cc.Contrast = "ImpactoFlash", forca or 0.22, 0.18
	cc.Parent = Lighting
	local tw = TweenService:Create(cc, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, Contrast = 0 })
	tw.Completed:Once(function() cc:Destroy() end)
	tw:Play()
end

-- Hit-stop de um corpo animado pelo servidor (criatura): segura as juntas na pose do instante por `dur` s.
-- Reescreve Motor6D.Transform a cada quadro, depois do Animator; só apresentação local.
function M.congelar(modelo: Instance?, dur: number)
	if not modelo or dur <= 0 or FX.reduzidos then return end
	local juntas: { [Motor6D]: CFrame } = {}
	for _, o in modelo:GetDescendants() do
		if o:IsA("Motor6D") then juntas[o] = o.Transform end
	end
	local fim = os.clock() + dur
	local con
	con = RunService.RenderStepped:Connect(function()
		if os.clock() >= fim or not modelo.Parent then
			con:Disconnect()
			return
		end
		for j, cf in juntas do
			if j.Parent then j.Transform = cf end
		end
	end)
end

-- Rastro na arma do fantasma `modelo`: acha a maior peça soldada (lâmina/cabo) e liga um Trail entre as pontas.
-- Devolve uma função que liga/desliga o rastro (ele some sozinho depois do `Lifetime`).
function M.rastro(modelo: Instance, cor: Color3): ((boolean?) -> ())?
	if FX.reduzidos then return nil end
	local melhor: BasePart? = nil
	local maior = 0
	for _, o in modelo:GetDescendants() do
		if o:IsA("Weld") and o.Part1 and o.Part1.Parent == modelo and o.Part1.Name ~= "HumanoidRootPart" then
			local p = o.Part1
			local m = math.max(p.Size.X, p.Size.Y, p.Size.Z)
			if m > maior and m >= 1.4 and m <= 4.5 and not p:FindFirstChildWhichIsA("Trail") then
				melhor, maior = p, m
			end
		end
	end
	if not melhor then return nil end
	local eixo = if melhor.Size.Y >= melhor.Size.X and melhor.Size.Y >= melhor.Size.Z then Vector3.yAxis
		elseif melhor.Size.Z >= melhor.Size.X then Vector3.zAxis else Vector3.xAxis
	local meia = maior / 2
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "RastroPonta", "RastroBase"
	a0.Position, a1.Position = -eixo * meia, eixo * meia * 0.2 -- ponta (lado -Y da peça) e perto do punho
	a0.Parent, a1.Parent = melhor, melhor
	local t = Instance.new("Trail")
	t.Name = "RastroDaArma"
	t.Attachment0, t.Attachment1 = a0, a1
	t.Lifetime, t.LightEmission, t.FaceCamera = 0.32, 1, true
	t.MinLength = 0.02
	t.Color = ColorSequence.new(Color3.fromRGB(255, 244, 205), cor:Lerp(Color3.fromRGB(255, 160, 60), 0.5))
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
	t.Enabled = false
	t.Parent = melhor
	modelo:SetAttribute("RastroNaArma", melhor.Name)
	return function(ligado: boolean?)
		if t.Parent then t.Enabled = ligado == true end
	end
end

return M
