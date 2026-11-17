-- HAB2: apresentação própria das magias de projétil do Mago da Água (Principiante): respingo, bola de água,
-- flecha de água (assinatura: câmera lenta curta no contato), impacto de gelo, e a aura "Molhado" no alvo.
-- Só apresentação: toca o RECIBO que o servidor mandou (acerto, crítico, erro vêm dele); nada aqui decide regra.
-- Nativo do Roblox (Part, Trail, ParticleEmitter, texturas rbxasset://), sem assets enviados.
--
-- Estrutura: cada magia é uma "cena" com relógio próprio (T, em segundos) que obedece às mesmas regras da
-- Coreografia: CenaTempoFixo congela no instante, EscalaDeTempoDasCenas dilata tudo (QA) e a câmera lenta da
-- flecha de água desacelera o relógio inteiro (peças e partículas), não só um efeito. Curvas: shared/AguaCurvas.
-- FX.reduzidos: menos partículas, sem câmera lenta, sem tremor.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Curvas = require(Shared:WaitForChild("AguaCurvas"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))
local FX = require(script.Parent:WaitForChild("MenuEfeitos"))
local Protocol = require(Shared:WaitForChild("MesaProtocol"))

local MagiasAgua = {}

local TEX = {
	brilho = "rbxasset://textures/particles/sparkles_main.dds",
	fumaca = "rbxasset://textures/particles/smoke_main.dds",
}

local function cor(nome: string): Color3
	local c = Curvas.PALETA[nome]
	return Color3.fromRGB(c[1], c[2], c[3])
end

local AGUA, PROFUNDA, BRILHO, ESPUMA, GELO, GELO_ESCURO =
	cor("agua"), cor("profunda"), cor("brilho"), cor("espuma"), cor("gelo"), cor("gelo_escuro")
-- HAB1c: com o Bloom do esgoto, Neon branco estoura; brilho e espuma ganham tom de água e o Neon vira plástico liso.
BRILHO = BRILHO:Lerp(AGUA, 0.55)
ESPUMA = ESPUMA:Lerp(AGUA, 0.35)

local function qtd(base: number, critico: boolean?): number
	return Curvas.quantidade(base, critico, FX.reduzidos)
end

-- Cena -----------------------------------------------------------------------

local Cena = {}
Cena.__index = Cena

local function novaCena(ctx)
	local self = setmetatable({}, Cena)
	self.ctx = ctx
	self.T = 0
	self.taxa = 1
	self.eventos = {}
	self.anims = {}
	self.lixo = {}
	self.emissores = {}
	self.fimT = 0
	self.freioInicio = nil
	self.freioDur, self.freioMin = 0, 1
	return self
end

function Cena:obj(i: Instance)
	table.insert(self.lixo, i)
	return i
end

function Cena:em(t: number, fn: () -> ())
	table.insert(self.eventos, { t = t, fn = fn, feito = false })
	self.fimT = math.max(self.fimT, t)
end

-- fn(u) roda a cada quadro com u em 0..1 entre t0 e t1 e uma última vez com u = 1.
function Cena:anim(t0: number, t1: number, fn: (number) -> ())
	local a = { t0 = t0, t1 = math.max(t1, t0 + 1e-3), fn = fn, fim = false }
	table.insert(self.anims, a)
	self.fimT = math.max(self.fimT, t1)
	return a -- HAB3: quem cria uma animação longa (zona) pode encerrá-la antes marcando a.fim
end

-- Câmera lenta curta: a partir de agora, `dur` s reais na taxa `minimo`, depois rampa de volta a 1.
function Cena:freio(dur: number, minimo: number)
	if FX.reduzidos then return end
	self.freioInicio, self.freioDur, self.freioMin = os.clock(), dur, minimo
end

function Cena:peca(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Glass
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = self.ctx.pasta()
	return self:obj(p)
end

function Cena:bola(tam: number, pos: Vector3, c: Color3, transp: number?, neon: boolean?): Part
	return self:peca({
		Shape = Enum.PartType.Ball, Size = Vector3.one * tam, Position = pos, Color = c,
		Transparency = transp or 0.3, Material = if neon then Enum.Material.SmoothPlastic else Enum.Material.Glass,
	})
end

-- Elipsoide alongado (flecha, jato, gotas esticadas) com SpecialMesh de esfera.
function Cena:elipse(larg: number, comp: number, c: Color3, transp: number?, neon: boolean?): Part
	local p = self:peca({
		Size = Vector3.new(larg, larg, comp), Color = c, Transparency = transp or 0.25,
		Material = if neon then Enum.Material.SmoothPlastic else Enum.Material.Glass,
	})
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = Vector3.one
	m.Parent = p
	return p
end

-- Disco chato no chão (anel/poça) ou, com `dir`, anel virado para uma direção.
function Cena:disco(centro: Vector3, diam: number, c: Color3, transp: number, dir: Vector3?, neon: boolean?): Part
	local base = if dir
		then CFrame.lookAt(centro, centro + dir) * CFrame.Angles(0, math.rad(90), 0)
		else CFrame.new(centro) * CFrame.Angles(0, 0, math.rad(90))
	local p = self:peca({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, diam, diam), CFrame = base, Color = c,
		Transparency = transp, Material = if neon then Enum.Material.SmoothPlastic else Enum.Material.Glass,
	})
	return p
end

function Cena:emissor(pai: Instance, tipo: string, c: Color3, op: { [string]: any }?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX[tipo]
	e.Color = ColorSequence.new(c, ESPUMA)
	e.LightEmission = if tipo == "fumaca" then 0.1 else 0.3
	e.LightInfluence = if tipo == "fumaca" then 0.5 else 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.7)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.Drag = 2
	for k, v in op or {} do
		e[k] = v
	end
	e.Parent = pai
	table.insert(self.emissores, e)
	return e
end

-- Rastro de água entre dois pontos do projétil.
function Cena:rastro(p: BasePart, c: Color3, largura: number, vida: number, fim: Color3?)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, largura / 2, 0), Vector3.new(0, -largura / 2, 0)
	a0.Parent, a1.Parent = p, p
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(c, fim or PROFUNDA)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime = vida
	t.LightEmission = 0.4
	t.FaceCamera = true
	t.Parent = p
	return t
end

-- Segmento fino entre dois pontos (corda do arco).
function Cena:fio(p: Part, a: Vector3, b: Vector3, grossura: number)
	local d = (b - a).Magnitude
	p.Size = Vector3.new(grossura, grossura, math.max(d, 0.01))
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
end

-- Gotas balísticas: n gotas saem de `centro` com velocidade radial, caem com gravidade e somem.
function Cena:gotas(t0: number, centro: Vector3, n: number, vel: number, subida: number, tam: number, c: Color3, dur: number, gelo: boolean?)
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + math.random() * 0.8
		local v = vel * (0.55 + math.random() * 0.6)
		local vx, vz, vy = math.cos(ang) * v, math.sin(ang) * v, subida * (0.5 + math.random() * 0.7)
		local d = tam * (0.6 + math.random() * 0.9)
		local g = self:peca({
			Shape = if gelo then Enum.PartType.Block else Enum.PartType.Ball,
			Size = Vector3.one * d, Color = c, Transparency = 1,
			Material = if gelo then Enum.Material.Ice else Enum.Material.Glass,
		})
		local giro = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local spin = Vector3.new(math.random() * 14 - 7, math.random() * 14 - 7, math.random() * 14 - 7)
		self:anim(t0, t0 + dur, function(u)
			local t = u * dur
			local x, y, z = Curvas.balistica(centro.X, centro.Y, centro.Z, vx, vy, vz, t)
			local chao = self.ctx.chao(centro).Y
			if y < chao then y = chao end
			g.CFrame = CFrame.new(x, y, z) * giro * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
			g.Transparency = if u < 0.55 then 0.15 elseif u >= 1 then 1 else 0.15 + 0.85 * (u - 0.55) / 0.45
			g.Size = Vector3.one * d * (if u > 0.7 then 1 - (u - 0.7) * 1.8 else 1)
		end)
	end
end

function Cena:iniciar()
	local ctx = self.ctx
	local ultimo = os.clock()
	local conexao
	conexao = ctx.conectar(RunService.Heartbeat, function()
		local agora = os.clock()
		local dt = agora - ultimo
		ultimo = agora
		local fixo = workspace:GetAttribute("CenaTempoFixo")
		if type(fixo) == "number" then
			self.T = fixo
		else
			local taxa = 1
			if self.freioInicio then
				taxa = Curvas.taxaDeTempo(agora - self.freioInicio, self.freioDur, self.freioMin)
			end
			self.taxa = taxa
			local esc = tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1
			self.T = Curvas.integrar(self.T, dt, taxa, esc)
		end
		for _, e in self.emissores do
			-- Tempo das partículas acompanha o relógio da cena (câmera lenta de verdade).
			e.TimeScale = math.max(self.taxa / math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1), 0.02)
		end
		-- Índices numéricos: eventos e animações novas nascem durante o laço.
		local i = 1
		while i <= #self.eventos do
			local ev = self.eventos[i]
			if not ev.feito and self.T >= ev.t then
				ev.feito = true
				local ok, erro = pcall(ev.fn)
				if not ok then warn("[MagiasAgua] evento falhou:", erro) end
			end
			i += 1
		end
		local vivas = false
		local j = 1
		while j <= #self.anims do
			local a = self.anims[j]
			j += 1
			if not a.fim and self.T >= a.t0 then
				local u = math.clamp((self.T - a.t0) / (a.t1 - a.t0), 0, 1)
				local ok, erro = pcall(a.fn, u)
				if not ok then warn("[MagiasAgua] animação falhou:", erro) a.fim = true end
				if u >= 1 then a.fim = true end
			end
			if not a.fim then vivas = true end
		end
		local eventosPendentes = false
		for _, ev in self.eventos do
			if not ev.feito then eventosPendentes = true break end
		end
		-- Margem para as partículas terminarem; com CenaTempoFixo a cena fica parada no instante.
		if type(fixo) ~= "number" and not vivas and not eventosPendentes and self.T >= self.fimT + 1.2 then
			conexao:Disconnect()
			for _, i in self.lixo do
				if i.Parent then i:Destroy() end
			end
			table.clear(self.lixo)
		end
	end)
end

-- Peças reutilizáveis ----------------------------------------------------------

local function eixos(dir: Vector3): (Vector3, Vector3)
	local cf = CFrame.lookAt(Vector3.zero, dir)
	return cf.RightVector, cf.UpVector
end

-- Respingo no contato: coroa de gotas, anel de choque, poça, brilho e névoa. `escala` 1 = bola de água.
local function respingo(cena, t: number, ponto: Vector3, escala: number, critico: boolean?, gelo: boolean?)
	local ctx = cena.ctx
	local chao = ctx.chao(ponto)
	cena:em(t, function()
		local nucleo = cena:bola(escala * 1.4, ponto, if gelo then GELO else ESPUMA, 0.2, true)
		cena:anim(t, t + 0.28, function(u)
			nucleo.Size = Vector3.one * escala * (1.4 + 3.4 * u)
			nucleo.Transparency = 0.2 + 0.8 * u
		end)
		local anel = cena:disco(chao + Vector3.new(0, 0.25, 0), escala * 0.8, if gelo then BRILHO else AGUA, 0.2, nil, true)
		cena:anim(t, t + 0.55, function(u)
			local d = escala * (0.8 + 5.2 * u)
			anel.Size = Vector3.new(0.12, d, d)
			anel.Transparency = 0.2 + 0.8 * u
		end)
		local poca = cena:disco(chao + Vector3.new(0, 0.08, 0), escala * 2, if gelo then GELO else PROFUNDA, 0.45)
		cena:anim(t, t + 2.2, function(u)
			local d = escala * (2 + 2.6 * math.min(u * 4, 1))
			poca.Size = Vector3.new(0.1, d, d)
			poca.Transparency = 0.45 + 0.55 * math.max((u - 0.35) / 0.65, 0)
		end)
		cena:gotas(t, ponto, qtd(16 * escala, critico), 7 * escala + 3, 11 * escala + 4, 0.34 * escala + 0.1, if gelo then GELO else AGUA, 0.9, gelo)
		local suporte = cena:peca({ Size = Vector3.one * 0.2, Position = ponto, Transparency = 1 })
		local br = cena:emissor(suporte, "brilho", if gelo then BRILHO else AGUA, {
			Speed = NumberRange.new(6 * escala, 12 * escala), Lifetime = NumberRange.new(0.4, 0.9),
			Acceleration = Vector3.new(0, -30, 0), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * escala), NumberSequenceKeypoint.new(1, 0) }),
		})
		br:Emit(qtd(24, critico))
		local nev = cena:emissor(suporte, "fumaca", if gelo then GELO else ESPUMA, {
			Speed = NumberRange.new(2, 5 * escala), Lifetime = NumberRange.new(0.6, 1.1), Acceleration = Vector3.new(0, if gelo then -2 else 2, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, escala * 1.4), NumberSequenceKeypoint.new(1, escala * 2.6) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		})
		nev:Emit(qtd(7, critico))
		Efeitos.tremer(if critico then 0.8 else 0.25 * escala + 0.1, if critico then 0.45 else 0.22)
	end)
end

-- Orbe d'água na mão com círculo girando e gotas em órbita: a conjuração legível.
-- t0..t1: cresce; depois fica até `tFim` (quando a magia sai).
local function orbeNaMao(cena, t0: number, t1: number, mao: Vector3, dir: Vector3, tam: number, nGotas: number, gelo: boolean?)
	local cAgua = if gelo then GELO else AGUA
	local cBrilho = if gelo then ESPUMA else BRILHO
	local direita, cima = eixos(dir)
	cena:em(t0, function()
		local casca = cena:bola(0.1, mao, cAgua, 0.35)
		local nucleo = cena:bola(0.1, mao, cBrilho, 0.35, true)
		local luz = Instance.new("PointLight")
		luz.Color, luz.Range, luz.Brightness, luz.Shadows = cAgua, 12, 2, false
		luz.Parent = casca
		local aro1 = cena:disco(mao, 0.1, cAgua, 1, dir, true)
		local aro2 = cena:disco(mao, 0.1, cBrilho, 1, dir, true)
		local gotas = {}
		for i = 1, nGotas do
			gotas[i] = cena:bola(tam * 0.22, mao, cAgua, 0.2)
		end
		local suga = cena:emissor(casca, "brilho", cBrilho, { Rate = qtd(36), Speed = NumberRange.new(-7, -4), Lifetime = NumberRange.new(0.3, 0.45) })
		cena:anim(t0, t1, function(u)
			if u >= 1 then
				-- último quadro: a saída esconde tudo (o evento de limpeza pode ter rodado antes)
				casca.Transparency, nucleo.Transparency, aro1.Transparency, aro2.Transparency = 1, 1, 1, 1
				for _, g in gotas do g.Transparency = 1 end
				return
			end
			local k = u * u * (3 - 2 * u)
			local giro = (cena.T - t0) * 5
			casca.Size = Vector3.one * tam * k
			nucleo.Size = Vector3.one * tam * 0.55 * k
			luz.Brightness = 2 + 3 * k
			local base = CFrame.lookAt(mao, mao + dir) * CFrame.Angles(0, math.rad(90), 0)
			aro1.Size = Vector3.new(0.08, tam * 2.6 * k, tam * 2.6 * k)
			aro1.CFrame = base * CFrame.Angles(giro, 0, 0)
			aro1.Transparency = 1 - 0.65 * k
			aro2.Size = Vector3.new(0.08, tam * 1.7 * k, tam * 1.7 * k)
			aro2.CFrame = base * CFrame.Angles(-giro * 1.4, 0, 0)
			aro2.Transparency = 1 - 0.5 * k
			for i, g in gotas do
				local dx, dy = Curvas.orbita(cena.T, tam * (1.5 - 0.35 * k), nGotas, i - 1, 5.5)
				g.Position = mao + direita * dx + cima * dy
				g.Size = Vector3.one * tam * 0.22 * k
			end
		end)
		-- Ao terminar a carga o orbe sai da mão (a receita faz o resto); some em seguida.
		cena:em(t1 + 0.05, function()
			suga.Enabled = false
			casca.Transparency = 1
			nucleo.Transparency = 1
			aro1.Transparency = 1
			aro2.Transparency = 1
			luz.Enabled = false
			for _, g in gotas do g.Transparency = 1 end
		end)
	end)
end

-- Aura "Molhado": véu d'água em volta do alvo, gotejando e com poça, que segue o token. Reutilizável (HAB3,
-- BoardView podem chamar para a condição "molhado" do snapshot). Devolve função que encerra antes do prazo.
local function auraMolhado(ctx, alvoId: string, duracao: number, atraso: number?)
	local cena = novaCena(ctx)
	local inicio = (atraso or 0)
	local centro = ctx.posicaoDe(alvoId)
	cena:em(inicio, function()
		centro = ctx.posicaoDe(alvoId)
		local veu = cena:bola(3.6, centro, AGUA, 0.75)
		local suporte = cena:peca({ Size = Vector3.one * 0.3, Position = centro, Transparency = 1 })
		local pinga = cena:emissor(suporte, "brilho", AGUA, {
			Rate = if FX.reduzidos then 4 else 14, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(60, 60),
			Lifetime = NumberRange.new(0.6, 1), Acceleration = Vector3.new(0, -22, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) }),
			EmissionDirection = Enum.NormalId.Bottom,
		})
		local brilho = cena:emissor(suporte, "brilho", BRILHO, {
			Rate = if FX.reduzidos then 2 else 6, Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(0.5, 0.9), Acceleration = Vector3.new(0, 1.5, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) }),
		})
		local poca = cena:disco(ctx.chao(centro) + Vector3.new(0, 0.07, 0), 3, PROFUNDA, 0.5)
		cena:anim(inicio, inicio + duracao, function(u)
			local c = ctx.posicaoDe(alvoId)
			veu.Position, suporte.Position = c, c
			poca.Position = ctx.chao(c) + Vector3.new(0, 0.07, 0)
			local ondula = 1 + 0.05 * math.sin(cena.T * 6)
			veu.Size = Vector3.one * 3.4 * ondula
			local entrada = math.min(u * duracao / 0.35, 1)
			local saida = math.clamp((1 - u) * duracao / 0.9, 0, 1)
			local k = math.min(entrada, saida)
			veu.Transparency = 1 - 0.25 * k
			poca.Transparency = 1 - 0.5 * k
			poca.Size = Vector3.new(0.1, 3 * ondula * (0.6 + 0.4 * k), 3 * ondula * (0.6 + 0.4 * k))
			pinga.Rate = (if FX.reduzidos then 4 else 14) * k
			brilho.Rate = (if FX.reduzidos then 2 else 6) * k
		end)
	end)
	cena:iniciar()
	return function()
		cena.fimT = 0
		for _, i in cena.lixo do
			if i.Parent then i:Destroy() end
		end
	end
end

-- Receitas -------------------------------------------------------------------

local function alvoDe(recibo)
	return recibo.alvos and recibo.alvos[1]
end

-- Ponto de saída (mão), de chegada e direção para o primeiro alvo; errar passa ao lado e cai no chão.
local function rota(ctx, recibo, alvo, afastar: number)
	local casterPos = ctx.posicaoDe(recibo.casterId, recibo.origem)
	local para = ctx.posicaoDe(alvo.id)
	local mao = ctx.aFrente(casterPos, para, 1.7) + Vector3.new(0, 0.5, 0)
	local falha = alvo.acertou == false
	local destino = para
	if falha then
		local d = (para - mao)
		local u = if d.Magnitude > 1e-3 then d.Unit else Vector3.new(0, 0, -1)
		destino = para + u * afastar + Vector3.new(1.6, -1.6, 1.2)
	end
	local dir = destino - mao
	return mao, destino, if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(0, 0, -1), falha, para
end

local function finalDoAcerto(ctx, cena, t: number, recibo, alvo, para: Vector3, de: Vector3, forca: number, molhar: boolean)
	cena:em(t, function()
		if alvo.acertou ~= false then
			ctx.recuo(alvo.id, de, forca)
			if molhar then
				auraMolhado(ctx, alvo.id, 4.2)
			end
		end
		for i = 2, #(recibo.alvos or {}) do
			local extra = recibo.alvos[i]
			if extra.acertou ~= false and molhar then auraMolhado(ctx, extra.id, 4.2) end
		end
		ctx.veredito(para, alvo)
	end)
end


-- Zonas persistentes (HAB3): Escudo de Água e Névoa Densa ficam em cena até o prazo (rodadas do combate, lidas do
-- snapshot) e então se desfazem com respingo/dissipação. O servidor decide a zona; aqui só se desenha.

local function geometriaDaZona(ctx, muro)
	local pts = {}
	for _, c in muro.casas or {} do table.insert(pts, ctx.centroCasa(c[1], c[2])) end
	if #pts == 0 then pts = { Vector3.zero } end
	local soma = Vector3.zero
	for _, p in pts do soma += p end
	return soma / #pts, pts
end

-- Escudo de Água: parede d'água de ~3 m (2 casas), translúcida, com correnteza rolando nas duas faces, ondulação,
-- espuma e jato na base; sobe com uma onda, respinga ao ser erguida e ao se desfazer.
local function zonaEscudo(ctx, muro, t0: number)
	local cena = novaCena(ctx)
	local centro, pts = geometriaDaZona(ctx, muro)
	local chaoY = ctx.chao(centro).Y
	local base = Vector3.new(centro.X, chaoY, centro.Z)
	local ao = if #pts >= 2 then Vector3.new(pts[#pts].X - pts[1].X, 0, pts[#pts].Z - pts[1].Z) else Vector3.xAxis
	local normal = if ao.Magnitude > 0.1 then ao.Unit:Cross(Vector3.yAxis) else Vector3.zAxis
	local larg = math.max(#pts, 2) * Protocol.BOARD.cell
	local alto = Protocol.BOARD.cell * 2.6
	local estado = { tFim = nil :: number? }
	local anim
	cena:em(t0, function()
		local parede = cena:peca({ Size = Vector3.new(larg, 0.1, 0.7), Color = Color3.fromRGB(70, 130, 175), Transparency = 0.78, Material = Enum.Material.Glass })
		local texA, texB
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local tx = Instance.new("Texture")
			tx.Texture, tx.Face, tx.Color3 = TEX.fumaca, face, Color3.fromRGB(150, 200, 225)
			tx.StudsPerTileU, tx.StudsPerTileV, tx.Transparency = 3.2, 3.2, 0.72
			tx.Parent = parede
			if face == Enum.NormalId.Front then texA = tx else texB = tx end
		end
		local espuma = cena:peca({ Size = Vector3.new(larg, 0.5, 1.2), Color = ESPUMA, Transparency = 0.45, Material = Enum.Material.Glass })
		local jato = cena:peca({ Size = Vector3.new(larg, 0.3, 0.6), Transparency = 1 })
		local borrifo = cena:emissor(jato, "brilho", ESPUMA, {
			Rate = if FX.reduzidos then 8 else 26, Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(18, 18),
			Lifetime = NumberRange.new(0.5, 0.9), Acceleration = Vector3.new(0, -16, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }),
			EmissionDirection = Enum.NormalId.Top,
		})
		respingo(cena, cena.T + 0.02, base, 0.9)
		ctx.som({ habilidadeId = "ability/agua/Principiante/escudo-de-agua" }, "agua", 1.0)
		anim = cena:anim(t0, t0 + 3600, function()
			local t = cena.T - t0
			local k = math.clamp(t / 0.5, 0, 1)
			k = 1 - (1 - k) ^ 3
			if estado.tFim then k = 1 - math.clamp((cena.T - estado.tFim) / 0.6, 0, 1) end
			local h = math.max(alto * k, 0.05)
			local onda = math.sin(cena.T * 2.4) * 0.12
			local meio = base + Vector3.new(0, h / 2, 0)
			parede.Size = Vector3.new(larg, h, 0.7 + onda * 0.4)
			parede.CFrame = CFrame.lookAt(meio, meio + normal)
			parede.Transparency = 0.78 + 0.06 * math.sin(cena.T * 3.1)
			texA.OffsetStudsV, texB.OffsetStudsV = -cena.T * 2.6, -cena.T * 2.1 -- correnteza descendo, uma face mais rápida
			texA.OffsetStudsU, texB.OffsetStudsU = math.sin(cena.T * 0.9) * 1.2, -cena.T * 0.8
			local pe = base + Vector3.new(0, 0.25, 0)
			espuma.CFrame = CFrame.lookAt(pe, pe + normal)
			espuma.Size = Vector3.new(larg * (0.96 + 0.04 * math.sin(cena.T * 5)), 0.5, 1.2 + onda)
			jato.CFrame = CFrame.lookAt(base + Vector3.new(0, 0.2, 0), base + Vector3.new(0, 0.2, 0) + normal)
			borrifo.Rate = (if FX.reduzidos then 8 else 26) * k
			if estado.tFim and cena.T - estado.tFim > 0.7 then
				for _, i in cena.lixo do if i.Parent then i:Destroy() end end
				table.clear(cena.lixo)
				anim.fim = true
			end
		end)
	end)
	cena:iniciar()
	return function()
		if estado.tFim then return end
		estado.tFim = cena.T
		respingo(cena, cena.T + 0.3, base, 1.3)
	end
end

-- Névoa Densa: volume de névoa de ~6 m de raio (emissor largo de fumaça + véu no chão); nasce devagar, deixa a
-- visibilidade baixa e se dissipa (as partículas vivas se esvaem em alguns segundos).
local function zonaNevoa(ctx, muro, t0: number)
	local cena = novaCena(ctx)
	local c = geometriaDaZona(ctx, muro)
	local chaoY = ctx.chao(c).Y
	local raio = Protocol.BOARD.cell * 4
	local estado = { tFim = nil :: number? }
	local anim
	cena:em(t0, function()
		local vol = cena:peca({ Size = Vector3.new(raio * 1.7, 4.5, raio * 1.7), Position = Vector3.new(c.X, chaoY + 2.4, c.Z), Transparency = 1 })
		local veu = cena:disco(Vector3.new(c.X, chaoY + 0.15, c.Z), raio * 2, ESPUMA, 0.85)
		local cinza = Color3.fromRGB(140, 160, 170)
		local fumo = cena:emissor(vol, "fumaca", cinza, {
			Rate = 0, Speed = NumberRange.new(0.2, 0.9), SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(5, 7), Drag = 0.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-8, 8),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 8) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.93), NumberSequenceKeypoint.new(0.75, 0.94), NumberSequenceKeypoint.new(1, 1) }),
			LightEmission = 0, LightInfluence = 1,
		})
		fumo.Color = ColorSequence.new(cinza, Color3.fromRGB(175, 192, 200))
		ctx.som({ habilidadeId = "ability/agua/Principiante/nevoa-densa" }, "agua", 0.8)
		anim = cena:anim(t0, t0 + 3600, function()
			local t = cena.T - t0
			local k = math.clamp(t / 1.8, 0, 1)
			if estado.tFim then k = 1 - math.clamp((cena.T - estado.tFim) / 1.2, 0, 1) end
			fumo.Rate = (if FX.reduzidos then 4 else 10) * k * (1 + 0.1 * math.sin(cena.T * 0.7))
			veu.Transparency = 1 - 0.1 * k
			if estado.tFim and cena.T - estado.tFim > 1.5 then
				fumo.Enabled = false
				if cena.T - estado.tFim > 10 then
					for _, i in cena.lixo do if i.Parent then i:Destroy() end end
					table.clear(cena.lixo)
					anim.fim = true
				end
			end
		end)
	end)
	cena:iniciar()
	return function()
		if not estado.tFim then estado.tFim = cena.T end
	end
end

local CTX_ZONAS = nil -- contexto guardado em criar(ctx): o BoardView (que desenha os muros do snapshot) usa para as zonas da Água

-- Desenho de um muro/zona do snapshot (`jogo.muros`) de estilo "agua" ou "nevoa". O prazo é do servidor: o BoardView
-- chama a função devolvida quando o muro some do snapshot. Devolve nil se este estilo não tem visual próprio aqui.
function MagiasAgua.zonaDoMuro(muro: any): (() -> ())?
	if not CTX_ZONAS then return nil end
	if muro.estilo == "agua" then return zonaEscudo(CTX_ZONAS, muro, 1.0) end
	if muro.estilo == "nevoa" then return zonaNevoa(CTX_ZONAS, muro, 1.1) end
	return nil
end

function MagiasAgua.criar(ctx)
	local R = {}
	CTX_ZONAS = ctx

	-- Respingo: truque rápido. Faísca d'água na ponta dos dedos, jato fino de gotas em fila, estalo no alvo.
	R["ability/agua/Principiante/respingo"] = function(_, recibo)
		local alvo = alvoDe(recibo)
		if not alvo then return end
		local mao, destino, dir, falha, para = rota(ctx, recibo, alvo, 4)
		local cena = novaCena(ctx)
		local voo = Curvas.duracaoDoVoo((destino - mao).Magnitude, 40, 0.22, 0.45)
		local t0 = 0.4
		orbeNaMao(cena, 0.05, t0, mao, dir, 1.5, 5)
		local n = if FX.reduzidos then 4 else 9
		local direita, cima = eixos(dir)
		for i = 1, n do
			local gota
			local ini = t0 + (i - 1) * 0.035
			cena:em(ini, function()
				gota = cena:elipse(if i == 1 then 0.8 else 0.55, if i == 1 then 2 else 1.3, if i == 1 then BRILHO else AGUA, 0.1, true)
				if i == 1 then cena:rastro(gota, AGUA, 0.7, 0.28) end
				if i == 1 then ctx.som(recibo, "agua", 1.2) end
			end)
			cena:anim(ini, ini + voo, function(u)
				if not gota then return end
				local p = mao:Lerp(destino, Curvas.avanco(u, 0.2)) + Vector3.new(0, math.sin(math.pi * u) * 0.9, 0)
				local dx, dy = Curvas.helice(u, 0.22, 1.5, i)
				p += direita * dx + cima * dy
				gota.CFrame = CFrame.lookAt(p, p + dir)
				if u >= 1 then gota.Transparency = 1 end
			end)
		end
		local chegada = t0 + (n - 1) * 0.035 + voo
		if falha then
			respingo(cena, t0 + voo, destino, 0.8, false)
		else
			respingo(cena, t0 + voo, destino, 1.0, alvo.critico)
		end
		finalDoAcerto(ctx, cena, t0 + voo, recibo, alvo, para, mao, 0.6, true)
		cena.fimT = math.max(cena.fimT, chegada)
		cena:iniciar()
	end

	-- Bola de Água: esfera viva cresce na mão entre gotas em órbita; sai em arco com hélice de gotas e
	-- rastro; no alvo vira domo, coroa e poça, e empurra.
	R["ability/agua/Principiante/bola-de-agua"] = function(_, recibo)
		local alvo = alvoDe(recibo)
		if not alvo then return end
		local mao, destino, dir, falha, para = rota(ctx, recibo, alvo, 6)
		local cena = novaCena(ctx)
		local voo = Curvas.duracaoDoVoo((destino - mao).Magnitude, 28, 0.35, 0.8)
		local t0 = 0.85
		orbeNaMao(cena, 0.05, t0, mao, dir, 3.2, 5)
		local esfera, nucleo
		local direita, cima = eixos(dir)
		local satelites = {}
		cena:em(t0, function()
			ctx.som(recibo, "agua", 1.5)
			esfera = cena:bola(3.2, mao, AGUA, 0.35, true)
			nucleo = cena:bola(1.8, mao, ESPUMA, 0.4, true)
			local luz = Instance.new("PointLight")
			luz.Color, luz.Range, luz.Brightness, luz.Shadows = AGUA, 14, 4, false
			luz.Parent = esfera
			cena:rastro(esfera, AGUA, 2.2, 0.4, PROFUNDA)
			cena:emissor(esfera, "brilho", BRILHO, { Rate = qtd(34), Speed = NumberRange.new(0.5, 3), Lifetime = NumberRange.new(0.3, 0.6), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }) })
			cena:emissor(esfera, "fumaca", ESPUMA, { Rate = qtd(14), Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(0.4, 0.7),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.4) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }) })
			for i = 1, 3 do
				satelites[i] = cena:bola(0.5, mao, AGUA, 0.2)
			end
		end)
		cena:anim(t0, t0 + voo, function(u)
			if not esfera then return end
			local a = Curvas.avanco(u, 0.25)
			local p = mao:Lerp(destino, a) + Vector3.new(0, math.sin(math.pi * u) * 1.3, 0)
			esfera.CFrame = CFrame.new(p) * CFrame.Angles(cena.T * 3, cena.T * 4, 0)
			nucleo.Position = p
			for i, s in satelites do
				local dx, dy = Curvas.helice(u, 1.4, 3, (i / 3) * 2 * math.pi)
				s.Position = p + direita * dx + cima * dy
			end
			if u >= 1 then
				esfera.Transparency, nucleo.Transparency = 1, 1
				for _, s in satelites do s.Transparency = 1 end
			end
		end)
		respingo(cena, t0 + voo, destino, if alvo.critico then 1.9 else 1.45, alvo.critico)
		if not falha then
			-- Marca o impacto com um empurrão curto na câmera (sem mexer em Coreografia/ImpactoCamera).
			cena:em(t0 + voo, function() Efeitos.tremer(if alvo.critico then 0.9 else 0.4, 0.3) end)
		end
		finalDoAcerto(ctx, cena, t0 + voo, recibo, alvo, para, mao, if alvo.critico then 2.4 else 1.6, true)
		cena:iniciar()
	end

	-- Flecha de Água (assinatura): arco d'água lateral, corda que estica, flecha elíptica que se forma,
	-- solta com estalo, voa em hélice e freia perto do alvo; no contato a cena entra em câmera lenta
	-- curta, a flecha racha em estrias e gotas, e o anel de choque abre.
	R["ability/agua/Principiante/flecha-de-agua"] = function(_, recibo)
		local alvo = alvoDe(recibo)
		if not alvo then return end
		local mao, destino, dir, falha, para = rota(ctx, recibo, alvo, 8)
		local cena = novaCena(ctx)
		local voo = Curvas.duracaoDoVoo((destino - mao).Magnitude, 46, 0.3, 0.75)
		if ctx.camera and not falha then ctx.camera(mao, destino, 0.85 + voo, { escala = 1.1, altura = 0.5 }) end -- câmera segue até o acerto
		local tSolta = 0.85
		local direita, cima = eixos(dir)
		local lado = direita * 0.9
		local centroArco = mao + lado
		local arcoN = 9
		local pontas, gotasArco, corda1, corda2, seta
		cena:em(0.05, function()
			ctx.som(recibo, "agua", 1.2)
			gotasArco = {}
			for i = 1, arcoN do
				gotasArco[i] = cena:bola(0.1, centroArco, BRILHO, 0.1, true)
			end
			corda1 = cena:peca({ Size = Vector3.new(0.06, 0.06, 0.1), Color = BRILHO, Transparency = 0.15, Material = Enum.Material.SmoothPlastic })
			corda2 = cena:peca({ Size = Vector3.new(0.06, 0.06, 0.1), Color = BRILHO, Transparency = 0.15, Material = Enum.Material.SmoothPlastic })
			seta = cena:elipse(0.1, 0.1, BRILHO, 0.05, true)
			local luz = Instance.new("PointLight")
			luz.Color, luz.Range, luz.Brightness, luz.Shadows = AGUA, 12, 3, false
			luz.Parent = seta
			pontas = true
		end)
		-- Tensão: o arco abre, a corda traz a flecha para trás, a flecha se forma e vibra.
		cena:anim(0.05, tSolta, function(u)
			if not pontas then return end
			local k = u * u * (3 - 2 * u)
			local raio = 2 * k
			local topo, base
			for i = 1, arcoN do
				local a = math.rad(-72 + 144 * (i - 1) / (arcoN - 1))
				local p = centroArco + cima * (math.sin(a) * raio) + dir * ((1 - math.cos(a)) * raio * 0.7)
				if i == 1 then base = p elseif i == arcoN then topo = p end
				gotasArco[i].Position = p
				gotasArco[i].Size = Vector3.one * 0.55 * k
			end
			local puxa = centroArco - dir * (1.1 * k)
			cena:fio(corda1, base, puxa, 0.14)
			cena:fio(corda2, topo, puxa, 0.14)
			local comp = 5 * k
			local fr = centroArco + dir * (0.3 - 1.1 * k) + dir * comp * 0.5
			seta.CFrame = CFrame.lookAt(fr, fr + dir)
			seta.Size = Vector3.new(0.8 * k, 0.8 * k, math.max(comp, 0.1))
		end)
		-- Solta: estalo (anel na corda), arco e corda somem, a flecha parte.
		local cauda = mao
		cena:em(tSolta, function()
			ctx.som(recibo, "agua", 1.4)
			if corda1 then corda1.Transparency, corda2.Transparency = 1, 1 end
			for _, g in gotasArco or {} do g.Transparency = 1 end
			local choque = cena:disco(centroArco, 1, ESPUMA, 0.2, dir, true)
			cena:anim(tSolta, tSolta + 0.22, function(u)
				choque.Size = Vector3.new(0.08, 1 + 4 * u, 1 + 4 * u)
				choque.Transparency = 0.2 + 0.8 * u
			end)
			if seta then
				cena:rastro(seta, ESPUMA, 1.7, 0.6, AGUA)
				cena:emissor(seta, "fumaca", ESPUMA, { Rate = qtd(24), Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(0.3, 0.6),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1.6) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }) })
			end
			cauda = centroArco - dir * 0.8
		end)
		local helices = {}
		cena:em(tSolta, function()
			for i = 1, 3 do
				helices[i] = cena:elipse(0.45, 1.5, BRILHO, 0.05, true)
			end
		end)
		cena:anim(tSolta, tSolta + voo, function(u)
			if not seta then return end
			local a = Curvas.avanco(u, 1.3)
			local p = cauda:Lerp(destino, a)
			seta.CFrame = CFrame.lookAt(p, p + dir)
			for i, h in helices do
				local dx, dy = Curvas.helice(a, 1.1, 3.5, (i / 3) * 2 * math.pi)
				local q = p + direita * dx + cima * dy
				h.CFrame = CFrame.lookAt(q, q + dir)
			end
		end)
		-- Contato: câmera lenta curta + estrias + anel + respingo.
		local tHit = tSolta + voo
		cena:em(tHit, function()
			cena:freio(0.32, 0.14)
			if seta then seta.Transparency = 1 end
			for _, h in helices do h.Transparency = 1 end
			local flash = cena:bola(1.2, destino, BRILHO, 0.1, true)
			cena:anim(tHit, tHit + 0.3, function(u)
				flash.Size = Vector3.one * (1.2 + 2.6 * u)
				flash.Transparency = 0.1 + 0.9 * u
			end)
			-- Estrias: gotas esticadas disparadas em leque a partir do ponto de contato.
			local nEstrias = qtd(10, alvo.critico)
			for i = 1, nEstrias do
				local ang = (i / nEstrias) * math.pi * 2
				local d = (direita * math.cos(ang) + cima * math.sin(ang)) * 0.9 + dir * (0.3 + math.random() * 0.5)
				local e = cena:elipse(0.4, 2.4, if i % 2 == 0 then ESPUMA else AGUA, 0.1, true)
				cena:anim(tHit, tHit + 0.7, function(u)
					local p = destino + d.Unit * (u * 5.5)
					e.CFrame = CFrame.lookAt(p, p + d)
					e.Size = Vector3.new(0.4 * (1 - u), 0.4 * (1 - u), 2.4)
					e.Transparency = 0.1 + 0.9 * u
				end)
			end
			-- Anel de choque vertical (perpendicular ao voo), a marca visual da assinatura.
			local choque = cena:disco(destino, 1, ESPUMA, 0.1, dir, true)
			cena:anim(tHit, tHit + 0.5, function(u)
				local d = 1 + 6.5 * u
				choque.Size = Vector3.new(0.1, d, d)
				choque.Transparency = 0.1 + 0.9 * u
			end)
			Efeitos.tremer(if alvo.critico then 1 else 0.55, 0.4)
		end)
		respingo(cena, tHit, destino, if alvo.critico then 1.5 else 1.1, alvo.critico)
		finalDoAcerto(ctx, cena, tHit, recibo, alvo, para, mao, if alvo.critico then 2 else 1.2, true)
		cena.fimT = math.max(cena.fimT, tHit + 1.5)
		cena:iniciar()
	end

	-- Impacto de Gelo: círculo de geada e cacos que se reúnem na mão, estilhaço de gelo disparado reto, e no
	-- alvo cravam espinhos de cristal que estilhaçam; névoa fria e geada no chão.
	R["ability/agua/Principiante/impacto-de-gelo"] = function(_, recibo)
		local alvo = alvoDe(recibo)
		local centro = recibo.centro
		local cena = novaCena(ctx)
		local mao, destino, dir, falha, para
		if alvo then
			mao, destino, dir, falha, para = rota(ctx, recibo, alvo, 6)
		elseif centro and recibo.casterId then
			para = ctx.centroCasa(centro[1], centro[2]) + Vector3.new(0, 1.2, 0)
			local casterPos = ctx.posicaoDe(recibo.casterId, recibo.origem)
			mao = ctx.aFrente(casterPos, para, 1.7) + Vector3.new(0, 0.5, 0)
			destino, falha = para, false
			local d = destino - mao
			dir = if d.Magnitude > 1e-3 then d.Unit else Vector3.new(0, 0, -1)
		else
			return
		end
		local voo = Curvas.duracaoDoVoo((destino - mao).Magnitude, 40, 0.28, 0.6)
		local t0 = 0.75
		local direita, cima = eixos(dir)
		orbeNaMao(cena, 0.05, t0, mao, dir, 1.6, 6, true)
		local cacos = {}
		local cluster
		cena:em(0.05, function()
			ctx.som(recibo, "gelo", 1.4)
			local suporte = cena:peca({ Size = Vector3.one * 0.2, Position = mao, Transparency = 1 })
			local nev = cena:emissor(suporte, "fumaca", GELO, { Rate = qtd(16), Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(0.6, 1),
				Acceleration = Vector3.new(0, -3, 0), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) }) })
			nev.Enabled = true
			cena:em(t0, function() nev.Enabled = false end)
			for i = 1, 5 do
				cacos[i] = cena:peca({ Size = Vector3.one * 0.1, Color = GELO, Transparency = 0.15, Material = Enum.Material.Ice })
			end
		end)
		-- Cacos convergem para a mão e se juntam.
		cena:anim(0.05, t0, function(u)
			for i, c in cacos do
				local ang = (i / #cacos) * math.pi * 2 + cena.T * 4
				local raio = 2.2 * (1 - u * u)
				local p = mao + direita * math.cos(ang) * raio + cima * math.sin(ang) * raio
				c.CFrame = CFrame.new(p) * CFrame.Angles(cena.T * 5 + i, cena.T * 3, i)
				c.Size = Vector3.new(0.3, 0.3, 0.85) * (0.4 + 0.6 * u)
			end
		end)
		cena:em(t0, function()
			ctx.som(recibo, "gelo", 1.3)
			for _, c in cacos do c.Transparency = 1 end
			cluster = {}
			local nucleo = cena:peca({ Size = Vector3.new(0.5, 0.5, 2.4), Color = GELO, Transparency = 0.1, Material = Enum.Material.Ice })
			local cruz = cena:peca({ Size = Vector3.new(0.5, 0.5, 1.9), Color = BRILHO, Transparency = 0.2, Material = Enum.Material.Ice })
			local lado = cena:peca({ Size = Vector3.new(0.42, 0.42, 1.5), Color = GELO_ESCURO, Transparency = 0.2, Material = Enum.Material.Ice })
			cluster = { nucleo, cruz, lado }
			local luz = Instance.new("PointLight")
			luz.Color, luz.Range, luz.Brightness, luz.Shadows = GELO, 14, 3, false
			luz.Parent = nucleo
			cena:rastro(nucleo, ESPUMA, 1.2, 0.35, GELO_ESCURO)
			cena:emissor(nucleo, "fumaca", GELO, { Rate = qtd(26), Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(0.4, 0.8),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 1.8) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }) })
			cena:emissor(nucleo, "brilho", BRILHO, { Rate = qtd(30), Speed = NumberRange.new(1, 4), Lifetime = NumberRange.new(0.3, 0.6) })
		end)
		cena:anim(t0, t0 + voo, function(u)
			if not cluster then return end
			local p = mao:Lerp(destino, Curvas.avanco(u, 0.1))
			local base = CFrame.lookAt(p, p + dir)
			cluster[1].CFrame = base * CFrame.Angles(0, 0, cena.T * 9)
			cluster[2].CFrame = base * CFrame.Angles(0, 0, math.rad(45) + cena.T * 9)
			cluster[3].CFrame = base * CFrame.new(0.35, 0.2, 0.3) * CFrame.Angles(0.3, 0.4, cena.T * 7)
			if u >= 1 then
				for _, c in cluster do c.Transparency = 1 end
			end
		end)
		-- Impacto: espinhos de cristal brotam do chão, seguram e estilhaçam.
		local tHit = t0 + voo
		local function brotar(ponto: Vector3, escala: number, critico: boolean?)
			local chao = ctx.chao(ponto)
			local n = qtd(7, critico)
			for i = 1, n do
				local ang = (i / n) * math.pi * 2 + 0.4
				local alt = (2.2 + (i % 3) * 0.9) * escala
				local inclina = math.rad(18 + (i % 2) * 10)
				local base = chao + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (0.7 * escala)
				local e = cena:peca({ Size = Vector3.new(0.5 * escala, alt, 0.5 * escala), Color = if i % 2 == 0 then GELO else BRILHO,
					Transparency = 1, Material = Enum.Material.Ice })
				local giro = CFrame.Angles(0, -ang, 0) * CFrame.Angles(0, 0, -inclina)
				cena:anim(tHit, tHit + 0.18, function(u)
					local h = alt * u
					e.Size = Vector3.new(0.5 * escala, math.max(h, 0.05), 0.5 * escala)
					e.CFrame = CFrame.new(base) * giro * CFrame.new(0, h / 2, 0)
					e.Transparency = 0.12
				end)
				-- Segura e estilhaça.
				cena:anim(tHit + 0.7, tHit + 0.85, function(u)
					e.Transparency = 0.12 + 0.88 * u
				end)
				cena:gotas(tHit + 0.7, base + Vector3.new(0, alt * 0.5, 0), 2, 4 * escala, 8, 0.3 * escala, GELO, 0.8, true)
			end
		end
		cena:em(tHit, function()
			cena:freio(0.1, 0.3)
			local flash = cena:bola(1.4, destino, ESPUMA, 0.15, true)
			cena:anim(tHit, tHit + 0.25, function(u)
				flash.Size = Vector3.one * (1.4 + 3 * u)
				flash.Transparency = 0.15 + 0.85 * u
			end)
			brotar(destino, if alvo and alvo.critico then 1.35 else 1, alvo and alvo.critico)
			for i = 2, #(recibo.alvos or {}) do
				brotar(ctx.posicaoDe(recibo.alvos[i].id), 0.75)
			end
			Efeitos.tremer(if alvo and alvo.critico then 0.9 else 0.45, 0.3)
		end)
		respingo(cena, tHit, destino, 1.1, alvo and alvo.critico, true)
		if alvo then
			finalDoAcerto(ctx, cena, tHit, recibo, alvo, para, mao, 0.8, false)
		end
		cena.fimT = math.max(cena.fimT, tHit + 1.6)
		cena:iniciar()
	end

	return R
end

MagiasAgua.molhado = auraMolhado

return MagiasAgua
