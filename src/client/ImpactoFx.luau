-- IMP1/IMP2: efeitos do golpe na luta: faíscas direcionais, corte desenhado, flash de crítico, hit-stop de corpo
-- animado pelo servidor e rastro da arma. Peças locais (nascem em `pai`, que é o modelo da cena e morre com ela).
-- Texturas nativas do Roblox (rbxasset), nenhum asset enviado.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage").Shared
local Curvas = require(Shared.ImpactoCurvas)
local FX = require(script.Parent.MenuEfeitos)
local Corpo = require(script.Parent.Corpo)
local Sonorizacao = require(script.Parent.Sonorizacao)

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
	local toCam = if cam then (cam.CFrame.Position - ponto).Unit else Vector3.zero
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
				-- fio de fora em plástico liso (sem estourar no Bloom); só o miolo fino é Neon
				p.Material, p.Transparency, p.Size = if camada == 1 then Enum.Material.SmoothPlastic else Enum.Material.Neon, 1, Vector3.one * 0.1
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
		return ponto + Vector3.new(0, 0.5, 0) + toCam * 0.9 + a * ((s - 0.5) * arco.L) - dir * (bow * 0.9)
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
				local larg = largura * (if camada == 1 then 1.0 else 0.14)
				p.Size = Vector3.new(larg, larg, comp)
				p.CFrame = CFrame.lookAt(meio, meio + (b - a))
				p.Transparency = if vida < 0 then 1 else math.clamp(tr + (if camada == 1 then 0.45 else 0.05), 0, 1)
			end
		end
	end)
end

-- Fumaça escura rasteira em volta de `ponto` por `dur` s (Primeiro Golpe: o ladino some na sombra antes de atacar).
function M.fumaca(pai: Instance, ponto: Vector3, dur: number)
	if FX.reduzidos then return end
	local base = Instance.new("Part")
	base.Name, base.Anchored, base.CanCollide, base.CanTouch, base.CanQuery, base.Transparency, base.Size = "Fumaca", true, false, false, false, 1, Vector3.one * 0.2
	base.Position = ponto - Vector3.new(0, 1.8, 0)
	base.Parent = pai
	local at = Instance.new("Attachment")
	at.Parent = base
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.Rate, e.LightEmission = "Sombra", TEX_FUMACA, 28, 0
	e.Color = ColorSequence.new(Color3.fromRGB(18, 16, 24))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.6, 1.0)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = at
	local escala = math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1)
	task.delay(dur * escala, function() e.Enabled = false end)
end

-- Respingo estilizado (sem gore): leque curto de gotas vermelhas esticadas pela velocidade, no sentido do golpe.
function M.gotas(pai: Instance, ponto: Vector3, direcao: Vector3)
	if FX.reduzidos then return end
	local base = Instance.new("Part")
	base.Name, base.Anchored, base.CanCollide, base.CanTouch, base.CanQuery, base.Transparency, base.Size = "Gotas", true, false, false, false, 1, Vector3.one * 0.2
	local u = plano(direcao)
	base.CFrame = CFrame.lookAt(ponto, ponto + u + Vector3.new(0, 0.5, 0))
	base.Parent = pai
	local at = Instance.new("Attachment")
	at.Parent = base
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.Rate, e.Enabled = "Gota", TEX_BRILHO, 0, false
	e.LightEmission, e.LockedToPart, e.Orientation = 0.15, false, Enum.ParticleOrientation.VelocityParallel
	e.Color = ColorSequence.new(Color3.fromRGB(190, 32, 44), Color3.fromRGB(110, 14, 24))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.55)
	e.Speed = NumberRange.new(10, 24)
	e.Acceleration = Vector3.new(0, -44, 0)
	e.EmissionDirection = Enum.NormalId.Front
	e.SpreadAngle = Vector2.new(38, 38)
	e.Parent = at
	e:Emit(8)
end

-- Arma que voa da mão do alvo (Corte de Braço): uma espada de apresentação lançada em arco, gira e cai no chão.
function M.soltaArma(pai: Instance, mao: Vector3, direcao: Vector3)
	if FX.reduzidos then return end
	local modelo = Instance.new("Model")
	modelo.Name = "ArmaSolta"
	local raiz = Instance.new("Part")
	raiz.Name, raiz.Anchored, raiz.CanCollide, raiz.CanTouch, raiz.CanQuery, raiz.Transparency, raiz.Size = "RightHand", true, false, false, false, 1, Vector3.one * 0.3
	raiz.CFrame = CFrame.new(mao)
	raiz.Parent = modelo
	modelo.Parent = pai
	local pecas = Corpo.arma({ modelo = modelo, clipes = true }, "espada")
	for _, p in pecas do p.Massless = true end
	local dir = Vector3.new(direcao.X, 0, direcao.Z)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.zAxis
	local lado = dir:Cross(Vector3.yAxis)
	local chao = mao.Y - 2.2
	local pousou = false
	local inicio = os.clock()
	local con
	con = RunService.RenderStepped:Connect(function()
		local escala = math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1)
		local t = (os.clock() - inicio) / escala
		if t > 1.6 or not modelo.Parent then
			con:Disconnect()
			modelo:Destroy()
			return
		end
		if t >= 0.62 and not pousou then
			pousou = true
			pcall(function() local parar = Sonorizacao.tocar("espada-metal", 1.0) end) -- arma batendo no chão (som existente do site)
		end
		local tv = math.min(t, 0.62) -- no ar até pousar
		local pos = mao + dir * (3.2 * tv) + lado * (0.8 * tv) + Vector3.new(0, 4.2 * tv - 9 * tv * tv, 0)
		pos = Vector3.new(pos.X, math.max(pos.Y, chao + 0.15), pos.Z)
		local giro = if t < 0.62 then t * 14 else 0.62 * 14 + math.min(t - 0.62, 0.1) * 2
		raiz.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0.6, 0) * CFrame.Angles(giro, 0, math.pi / 2 * math.min(t / 0.62, 1))
		if t > 1.2 then
			for _, p in pecas do p.Transparency = math.clamp((t - 1.2) / 0.4, 0, 1) end
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

-- Rastro da arma: fita desenhada com a posição REAL do Attachment "Ponta" da arma do fantasma, quadro a quadro
-- (segmentos finos entre amostras consecutivas que somem em ~0,25 s). Segue a trajetória verdadeira da ponta
-- e aparece em tempo real, não só em câmera lenta. Devolve `liga(boolean)`; nil se a arma não tem "Ponta".
local VIDA_RASTRO = 0.30
local LARG_FORA, LARG_MIOLO = 0.26, 0.07 -- fita fina: afina com a idade
function M.rastro(modelo: Instance, cor: Color3, pai: Instance?): ((boolean?) -> ())?
	if FX.reduzidos then return nil end
	local ponta: Attachment? = nil
	for _, o in modelo:GetDescendants() do
		if o:IsA("Attachment") and o.Name == "Ponta" then
			ponta = o
			break
		end
	end
	if not ponta then return nil end
	local destino = pai or modelo
	local ligado = false
	local ultimo: Vector3? = nil
	local itens: { { fora: BasePart, miolo: BasePart, nasceu: number, comp: number } } = {}
	local con: RBXScriptConnection? = nil
	local escala = 1
	local function novo(cf: CFrame, comp: number)
		local fora = Instance.new("Part")
		fora.Name, fora.Anchored, fora.CanCollide, fora.CanTouch, fora.CanQuery, fora.CastShadow = "Rastro", true, false, false, false, false
		fora.Material, fora.Color, fora.Size, fora.CFrame = Enum.Material.SmoothPlastic, Color3.fromRGB(255, 150, 50), Vector3.new(LARG_FORA, LARG_FORA, comp), cf
		local miolo = Instance.new("Part")
		miolo.Name, miolo.Anchored, miolo.CanCollide, miolo.CanTouch, miolo.CanQuery, miolo.CastShadow = "RastroMiolo", true, false, false, false, false
		miolo.Material, miolo.Color, miolo.Size, miolo.CFrame = Enum.Material.Neon, Color3.fromRGB(255, 205, 130), Vector3.new(LARG_MIOLO, LARG_MIOLO, comp), cf
		fora.Parent, miolo.Parent = destino, destino
		table.insert(itens, { fora = fora, miolo = miolo, nasceu = os.clock(), comp = comp })
	end
	local function passo()
		local agora = os.clock()
		escala = math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1)
		if ligado and ponta.Parent then
			local p = ponta.WorldPosition
			if ultimo and (p - ultimo).Magnitude > 0.03 then
				local meio = (p + ultimo) / 2
				novo(CFrame.lookAt(meio, p), (p - ultimo).Magnitude * 1.08)
			end
			ultimo = p
		else
			ultimo = nil
		end
		for i = #itens, 1, -1 do
			local it = itens[i]
			local idade = (agora - it.nasceu) / (VIDA_RASTRO * escala)
			if idade >= 1 or not it.fora.Parent then
				it.fora:Destroy()
				it.miolo:Destroy()
				table.remove(itens, i)
			else
				local f = 1 - 0.8 * idade -- afina até 20% da largura
				it.fora.Size = Vector3.new(LARG_FORA * f, LARG_FORA * f, it.comp)
				it.miolo.Size = Vector3.new(LARG_MIOLO * f, LARG_MIOLO * f, it.comp)
				it.fora.Transparency = math.clamp(0.4 + idade * 0.6, 0, 1)
				it.miolo.Transparency = math.clamp(0.1 + idade * 0.9, 0, 1)
			end
		end
		if not ligado and #itens == 0 and con then
			con:Disconnect()
			con = nil
		end
	end
	modelo:SetAttribute("RastroNaArma", "Ponta")
	return function(on: boolean?)
		ligado = on == true
		if not con then con = RunService.RenderStepped:Connect(passo) end
	end
end

return M
