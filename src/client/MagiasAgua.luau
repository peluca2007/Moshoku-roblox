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
local PlanosCamera = require(script.Parent:WaitForChild("PlanosCamera")) -- CAM1: planos de câmera por habilidade
local Feedback = require(script.Parent:WaitForChild("FeedbackCombate")) -- HAB8: número/barra/faixa esperam o contato
local Fila = require(Shared:WaitForChild("Animacoes"):WaitForChild("FilaApresentacao"))
local Destaques = require(Shared:WaitForChild("DestaquesGolpe"))

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
		-- HAB8: peça pequena colada na lente (gota, bolha, estilhaço) vira borrão que tapa a tela: some só para a câmera
		-- (LocalTransparencyModifier não briga com as animações de Transparency)
		local cam = workspace.CurrentCamera
		if cam then
			local olho = cam.CFrame.Position
			for _, o in self.lixo do
				if o:IsA("BasePart") and o.Parent then
					local tam = o.Size
					if math.max(tam.X, tam.Y, tam.Z) < 4 then
						o.LocalTransparencyModifier = if (o.Position - olho).Magnitude < 3.5 then 1 else 0
					else
						-- peça grande (placa do Escudo) com a câmera dentro ou rente: quase some, em vez de a lente atravessá-la
						local rel = o.CFrame:PointToObjectSpace(olho)
						local dentro = math.abs(rel.X) < tam.X / 2 + 1 and math.abs(rel.Y) < tam.Y / 2 + 1 and math.abs(rel.Z) < tam.Z / 2 + 1
						o.LocalTransparencyModifier = if dentro then 0.85 else 0
					end
				end
			end
		end
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
		workspace:SetAttribute("QaRespingoEm", string.format("%.1f,%.1f,%.1f", ponto.X, ponto.Y, ponto.Z)) -- QA
		local nucleo = cena:bola(escala * 1.2, ponto, if gelo then GELO else ESPUMA, 0.2, true)
		cena:anim(t, t + 0.28, function(u)
			nucleo.Size = Vector3.one * escala * (1.2 + 1.8 * u) -- HAB8: bolha de estouro menor (ia a ~7 studs e engolia o espaço entre os dois)
			nucleo.Transparency = 0.2 + 0.8 * u
		end)
		local anel = cena:disco(chao + Vector3.new(0, 0.25, 0), escala * 0.8, if gelo then BRILHO else AGUA, 0.2, nil, true)
		cena:anim(t, t + 0.55, function(u)
			local d = escala * (0.8 + 5.2 * u)
			anel.Size = Vector3.new(0.12, d, d)
			anel.Transparency = 0.2 + 0.8 * u
		end)
		local poca = cena:disco(chao + Vector3.new(0, 0.08, 0), escala * 1.2, if gelo then GELO else PROFUNDA, 0.6)
		cena:anim(t, t + 1.3, function(u)
			local d = escala * (1.2 + 1.4 * math.min(u * 4, 1)) -- HAB6: poça menor e curta (era um disco liso de 7 studs parado por 2 s)
			poca.Size = Vector3.new(0.1, d, d)
			poca.Transparency = 0.6 + 0.4 * math.max((u - 0.2) / 0.8, 0)
		end)
		-- HAB8: gotas menores e de alcance curto (eram bolhas de até 1,4 stud a 13 studs/s que chegavam na câmera)
		cena:gotas(t, ponto, qtd(12 * escala, critico), 3.5 * escala + 2, 6 * escala + 3, 0.18 * escala + 0.08, if gelo then GELO else AGUA, 0.75, gelo)
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
	local anim
	cena:em(inicio, function()
		centro = ctx.posicaoDe(alvoId)
		-- HAB7: sem esfera de vidro em volta do alvo (parecia uma bolha opaca presa); só gotejar, brilho úmido e poça fina
		local suporte = cena:peca({ Size = Vector3.one * 0.3, Position = centro, Transparency = 1 })
		local pinga = cena:emissor(suporte, "brilho", AGUA, {
			Rate = if FX.reduzidos then 6 else 22, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(80, 80),
			Lifetime = NumberRange.new(0.6, 1), Acceleration = Vector3.new(0, -22, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) }),
			EmissionDirection = Enum.NormalId.Bottom,
		})
		local brilho = cena:emissor(suporte, "brilho", BRILHO, {
			Rate = if FX.reduzidos then 2 else 6, Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(0.5, 0.9), Acceleration = Vector3.new(0, 1.5, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) }),
		})
		local poca = cena:disco(ctx.chao(centro) + Vector3.new(0, 0.07, 0), 2.4, PROFUNDA, 0.8)
		anim = cena:anim(inicio, inicio + duracao, function(u)
			local c = ctx.posicaoDe(alvoId)
			suporte.Position = c
			poca.Position = ctx.chao(c) + Vector3.new(0, 0.07, 0)
			local ondula = 1 + 0.05 * math.sin(cena.T * 6)
			local entrada = math.min(u * duracao / 0.35, 1)
			local saida = math.clamp((1 - u) * duracao / 0.9, 0, 1)
			local k = math.min(entrada, saida)
			poca.Transparency = 1 - 0.2 * k
			poca.Size = Vector3.new(0.1, 2.4 * ondula * (0.6 + 0.4 * k), 2.4 * ondula * (0.6 + 0.4 * k))
			pinga.Rate = (if FX.reduzidos then 6 else 22) * k
			brilho.Rate = (if FX.reduzidos then 3 else 10) * k
		end)
	end)
	cena:iniciar()
	return function()
		cena.fimT = 0
		if anim then anim.fim = true end
		for _, i in cena.lixo do
			if i.Parent then i:Destroy() end
		end
		table.clear(cena.lixo)
	end
end

-- Receitas -------------------------------------------------------------------

local function alvoDe(recibo)
	return recibo.alvos and recibo.alvos[1]
end

-- Ponto de saída (mão), de chegada e direção para o primeiro alvo; errar passa ao lado e cai no chão.
-- HAB8: frente do corpo real do alvo (CorposDeCriatura), como a Coreografia faz nos golpes: a casa do tabuleiro
-- pode não coincidir com o modelo e a bola estourava no meio do caminho. nil se não há corpo.
local function frenteDoCorpo(id: string?, de: Vector3): Vector3?
	local corpos = workspace:FindFirstChild("CorposDeCriatura")
	local m = id and corpos and corpos:FindFirstChild(id)
	if not (m and m:IsA("Model")) then return nil end
	-- XZ do pivô (raiz do corpo): a caixa envolvente inclui arma e peças de colisão e puxava o ponto para o atacante;
	-- altura do meio da caixa; recuo até a frente do corpo limitado a 0,6 stud
	local cf, tam = m:GetBoundingBox()
	local piv = m:GetPivot().Position
	local centro = Vector3.new(piv.X, cf.Position.Y + tam.Y * 0.05, piv.Z)
	local plano = Vector3.new(centro.X - de.X, 0, centro.Z - de.Z)
	if plano.Magnitude < 1e-3 then return centro end
	return centro - plano.Unit * math.min(math.min(tam.X, tam.Z) * 0.3, 0.6)
end

-- HAB8: no erro, quem chama a câmera passa `para` (o alvo), não `destino` (o chão além dele): a tomada de contato
-- descia ao rés do chão e mostrava o piso escuro.
local function rota(ctx, recibo, alvo, afastar: number)
	local casterPos = ctx.posicaoDe(recibo.casterId, recibo.origem)
	local para = frenteDoCorpo(alvo.id, casterPos) or ctx.posicaoDe(alvo.id)
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
	-- HAB8: PV, número de dano e "N de dano" da faixa ficam no valor de antes até o projétil encostar (relógio da cena,
	-- que obedece à câmera lenta); o teto da fila cobre cena cancelada.
	local ids = {}
	if not FX.reduzidos then
		for _, a in recibo.alvos or {} do
			if type(a.id) == "string" then -- erros também: o "errou" da faixa espera a bola passar
				table.insert(ids, a.id)
				Feedback.fila:reter(a.id, os.clock(), t + 0.6, nil, Fila.TETO_COM_SINAL)
			end
		end
	end
	cena:em(t, function()
		for _, id in ids do Feedback.fila:soltar(id, os.clock()) end
		if alvo.acertou ~= false then
			ctx.som(recibo, if molhar then "agua" else "gelo", 1.0) -- HAB8: o acerto também soa (antes só o lançamento)
			for k, d in Destaques.listar(alvo) do -- HAB8: furtivo/combo também nas magias (a faixa já dizia)
				Efeitos.destaque(para + Vector3.new(0, 2 + k, 0), d.texto, if d.forte then Color3.fromRGB(200, 60, 60) else Color3.fromRGB(240, 196, 92), d.forte)
			end
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

-- Escudo de Água (HAB3b): muro de água CURVO (arco de ~2 casas; placas finas desde a HAB8) virado para os inimigos.
-- Camadas por segmento: núcleo azul translúcido, superfície com textura rolando PARA CIMA, espuma ondulando no topo;
-- por cima, gotas escorrendo pela face e respingo contínuo na base. Sobe em onda, respinga ao subir e ao se desfazer.
local function zonaEscudo(ctx, muro, t0: number, frente: Vector3?)
	local cena = novaCena(ctx)
	local centro, pts = geometriaDaZona(ctx, muro)
	local chaoY = ctx.chao(centro).Y
	local base = Vector3.new(centro.X, chaoY, centro.Z)
	local ao = if #pts >= 2 then Vector3.new(pts[#pts].X - pts[1].X, 0, pts[#pts].Z - pts[1].Z) else Vector3.xAxis
	local lateral = if ao.Magnitude > 0.1 then ao.Unit else Vector3.xAxis
	local normal = lateral:Cross(Vector3.yAxis)
	if frente and frente.Magnitude > 0.1 and normal:Dot(frente) < 0 then normal = -normal end
	local larg = math.max(#pts, 2) * Protocol.BOARD.cell * 1.5 -- HAB7: mais largo, para ler como muro também de lado
	local alto = Protocol.BOARD.cell * 1.7
	local espessura = 0.3 -- HAB8: placas finas: as faces laterais de blocos grossos translúcidos eram as emendas verticais
	local curva = 3.0 -- o arco abaulado para os inimigos
	local N = if FX.reduzidos then 7 else 13
	local estado = { tFim = nil :: number? }
	local anim
	-- HAB5: água em pé: azul-esverdeado translúcido, borda mais clara, correnteza para BAIXO, espuma no topo e reflexo.
	local AZUL_NUCLEO, AZUL_SUP, AZUL_TEX = Color3.fromRGB(66, 118, 128), Color3.fromRGB(112, 160, 166), Color3.fromRGB(170, 214, 212)
	local BORDA = Color3.fromRGB(206, 240, 232)
	cena:em(t0, function()
		local segs = {}
		-- HAB8: cada bloco tem a largura da corda da curva entre suas bordas (+3%), sem a sobreposição de 18% que fazia
		-- faixas escuras; `arco` = distância ao longo do muro, para a textura continuar de um bloco para o outro
		local function naCurva(s: number): Vector3
			return base + lateral * (s * larg / 2) + normal * (curva * (1 - s * s))
		end
		local arco = 0
		for i = 1, N do
			local s = ((i - 0.5) / N) * 2 - 1
			local pos = naCurva(s)
			local tang = (lateral * (larg / 2) + normal * (-2 * curva * s)).Unit
			local face = tang:Cross(Vector3.yAxis)
			if face:Dot(normal) < 0 then face = -face end
			local corda = (naCurva((i / N) * 2 - 1) - naCurva(((i - 1) / N) * 2 - 1)).Magnitude
			local w = corda * 1.03
			local arcoMeio = arco + corda / 2
			arco += corda
			local nucleo = cena:peca({ Size = Vector3.new(w, 0.1, espessura), Color = AZUL_NUCLEO, Transparency = 0.78, Material = Enum.Material.SmoothPlastic })
			local sup = cena:peca({ Size = Vector3.new(w, 0.1, espessura + 0.06), Color = AZUL_SUP, Transparency = 0.8, Material = Enum.Material.SmoothPlastic })
			local tex = {}
			for _, f in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local tx = Instance.new("Texture")
				tx.Texture, tx.Face, tx.Color3, tx.Transparency = TEX.fumaca, f, AZUL_TEX:Lerp(AZUL_NUCLEO, 0.4), 0.9
				tx.StudsPerTileU, tx.StudsPerTileV = 1.4, 4.2
				tx.Parent = sup
				table.insert(tex, tx)
			end
			local espuma = cena:peca({ Size = Vector3.new(w * 0.95, 0.4, espessura + 0.3), Color = ESPUMA:Lerp(AZUL_SUP, 0.5), Transparency = 0.6, Material = Enum.Material.SmoothPlastic })
			local reflexo = cena:peca({ Size = Vector3.new(0.16, 1, 0.05), Color = BORDA, Transparency = 0.75, Material = Enum.Material.SmoothPlastic })
			local fita = nil
			if i == 1 or i == N then
				fita = cena:peca({ Size = Vector3.new(0.22, 1, espessura + 0.35), Color = AZUL_TEX, Transparency = 0.72, Material = Enum.Material.SmoothPlastic })
			end
			local fonte = cena:peca({ Size = Vector3.new(w * 0.8, 0.2, 0.4), Transparency = 1 })
			local gotas = cena:emissor(fonte, "brilho", AZUL_TEX, {
				Rate = if FX.reduzidos then 8 else 24, Speed = NumberRange.new(0.05, 0.25), SpreadAngle = Vector2.new(4, 4),
				Lifetime = NumberRange.new(0.9, 1.5), Acceleration = Vector3.new(0, -5, 0),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.12) }),
				EmissionDirection = Enum.NormalId.Front, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) }),
			})
			gotas.Orientation = Enum.ParticleOrientation.VelocityParallel
			gotas.Squash = NumberSequence.new(-1.5)
			local borrifo = cena:emissor(fonte, "brilho", ESPUMA, {
				Rate = if FX.reduzidos then 4 else 11, Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(22, 22),
				Lifetime = NumberRange.new(0.4, 0.8), Acceleration = Vector3.new(0, -18, 0),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }),
				EmissionDirection = Enum.NormalId.Top,
			})
			segs[i] = { arco = arcoMeio, pos = pos, face = face, tang = tang, w = w, reflexo = reflexo, fita = fita, nucleo = nucleo, sup = sup, tex = tex, espuma = espuma, fonte = fonte, gotas = gotas, borrifo = borrifo }
		end
		for i = 1, N, 2 do
			respingo(cena, cena.T + 0.02 + i * 0.03, segs[i].pos, 0.8)
		end
		ctx.som({ habilidadeId = "ability/agua/Principiante/escudo-de-agua" }, "agua", 1.0)
		-- câmera curta mostrando o muro subir
		-- CAM1: 3/4 pela face do muro, do lado dos aliados, recuando e subindo (aliados em `-normal`, inimigos em `normal`)
		if ctx.camera then
			local meio = base + normal * curva * 0.6 + Vector3.new(0, alto * 0.45, 0)
			ctx.camera(meio - normal * 6, meio, 0, PlanosCamera.opc("escudo-de-agua", true))
		end
		anim = cena:anim(t0, t0 + 3600, function()
			local t = cena.T - t0
			local sumindo = estado.tFim ~= nil
			for i, g in segs do
				local ki = math.clamp((t - i * 0.045) / 0.5, 0, 1)
				ki = 1 - (1 - ki) ^ 3
				if sumindo then ki = 1 - math.clamp((cena.T - estado.tFim - i * 0.03) / 0.55, 0, 1) end
				local h = math.max(alto * ki, 0.05)
				local onda = math.sin(cena.T * 2.2 + g.arco * 0.35) * 0.18 -- HAB8: fase pelo arco (contínua), não pelo índice
				local cf = CFrame.lookAt(g.pos + Vector3.new(0, h / 2, 0), g.pos + Vector3.new(0, h / 2, 0) + g.face)
				g.nucleo.Size = Vector3.new(g.nucleo.Size.X, h, espessura)
				g.nucleo.CFrame = cf
				g.nucleo.Transparency = 0.78 + 0.04 * math.sin(cena.T * 2.6) -- HAB8: igual em todos (fase por bloco fazia listras)
				g.sup.Size = Vector3.new(g.sup.Size.X, h, espessura + 0.06 + math.abs(onda) * 0.1)
				g.sup.CFrame = cf
				g.tex[1].OffsetStudsV, g.tex[2].OffsetStudsV = -cena.T * 2.6, -cena.T * 2.0 -- correnteza descendo
				-- HAB8: a textura continua entre blocos: o deslocamento U começa onde o bloco começa no arco do muro
				local u0 = g.arco - g.w / 2
				g.tex[1].OffsetStudsU, g.tex[2].OffsetStudsU = -u0 + math.sin(cena.T * 0.8) * 0.8, -u0 - cena.T * 0.5
				local topo = g.pos + Vector3.new(0, h + 0.05 + onda * 0.5, 0)
				g.espuma.CFrame = CFrame.lookAt(topo, topo + g.face)
				g.espuma.Size = Vector3.new(g.espuma.Size.X, 0.3 + 0.12 * math.sin(cena.T * 4 + i * 1.7), espessura + 0.3)
				local alto2 = g.pos + g.face * (espessura / 2 + 0.1) + Vector3.new(0, h - 0.2, 0)
				g.fonte.CFrame = CFrame.lookAt(alto2, alto2 + g.face)
				g.gotas.Rate = (if FX.reduzidos then 8 else 24) * ki
				-- reflexo: faixa clara que varre a face
				local varre = ((cena.T * 0.3 + i * 0.37) % 1 - 0.5) * g.w * 0.9
				local pr = g.pos + g.face * (espessura / 2 + 0.16) + g.tang * varre + Vector3.new(0, h * 0.5, 0)
				g.reflexo.Size = Vector3.new(0.16, math.max(h * 0.7, 0.05), 0.05)
				g.reflexo.CFrame = CFrame.lookAt(pr, pr + g.face)
				g.reflexo.Transparency = 0.6 + 0.4 * math.abs(varre) / (g.w * 0.45) + (1 - ki) * 0.5
				if g.fita then
					local lado = if i == 1 then -1 else 1
					local pf = g.pos + g.tang * (lado * g.w * 0.45) + Vector3.new(0, h / 2, 0)
					g.fita.Size = Vector3.new(0.22, math.max(h, 0.05), espessura + 0.35)
					g.fita.CFrame = CFrame.lookAt(pf, pf + g.face)
				end
				g.borrifo.Rate = (if FX.reduzidos then 4 else 11) * ki
				if ki < 0.95 or t < 0 then g.espuma.Transparency = 1 else g.espuma.Transparency = 0.6 end -- a espuma só aparece com o muro de pé (de lado, as espumas escalonadas viravam uma coluna branca)
			end
			if sumindo and cena.T - estado.tFim > 1.1 then
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
		for i = 1, 3 do
			respingo(cena, cena.T + 0.2 + i * 0.1, base + lateral * ((i - 2) * larg / 3) + normal * curva, 1.1)
		end
	end
end

-- Névoa Densa (HAB3b): volume de bruma de ~6 m de raio e ~7 studs de altura que cobre os lutadores parcialmente:
-- bolhas de névoa translúcidas à deriva (volume), emissor largo de fumaça, véu no chão; nasce em ~2 s e se dissipa.
local function zonaNevoa(ctx, muro, t0: number)
	local cena = novaCena(ctx)
	local c = geometriaDaZona(ctx, muro)
	local chaoY = ctx.chao(c).Y
	local raio = Protocol.BOARD.cell * 4
	local estado = { tFim = nil :: number? }
	local anim
	local cinza = Color3.fromRGB(150, 168, 178)
	cena:em(t0, function()
		-- HAB5: mais densa rente ao chão (até a cintura), com rolos rasteiros em movimento; acima, só um véu leve
		-- (os lutadores aparecem da cintura para cima como silhuetas) e sem lavar o cenário inteiro.
		-- HAB8: partículas nascem espalhadas no volume da peça (rente ao chão) e mal sobem; antes jorravam de um ponto
		-- a 70 graus e chegavam à altura da câmera, lavando a tela de branco nas rodadas seguintes
		local opacos = {}
		local function emissorNevoa(pai, tam0, tam1, transp0, vida, vel)
			local e = cena:emissor(pai, "fumaca", cinza, {
				Rate = 0, Speed = NumberRange.new(vel * 0.2, vel * 0.5), SpreadAngle = Vector2.new(180, 0),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				Acceleration = Vector3.new(0, -0.15, 0),
				Lifetime = NumberRange.new(vida * 0.7, vida), Drag = 0.6, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-6, 6),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, tam0), NumberSequenceKeypoint.new(1, tam1) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, transp0), NumberSequenceKeypoint.new(0.7, transp0 + 0.04), NumberSequenceKeypoint.new(1, 1) }),
				LightEmission = 0, LightInfluence = 1,
			})
			e.Color = ColorSequence.new(cinza, Color3.fromRGB(185, 200, 208))
			table.insert(opacos, { e = e, base = transp0 })
			return e
		end
		local rasteira = cena:peca({ Size = Vector3.new(raio * 1.8, 0.6, raio * 1.8), Position = Vector3.new(c.X, chaoY + 0.5, c.Z), Transparency = 1 })
		local fumo = emissorNevoa(rasteira, 4, 6.5, 0.38, 5, 0.8) -- HAB8: mais densa rente ao chão (no lançamento quase não aparecia)
		local alta = cena:peca({ Size = Vector3.new(raio * 1.6, 1, raio * 1.6), Position = Vector3.new(c.X, chaoY + 2.2, c.Z), Transparency = 1 })
		local veu = emissorNevoa(alta, 5, 7, 0.94, 5, 0.5)
		-- HAB8: câmera dentro da névoa (a da luta costuma ficar a ~3 studs do chão, dentro da área): a opacidade de TODAS
		-- as partículas vivas cai na hora (Transparency do emissor vale para as já emitidas); fora dela, volta.
		local fatorAtual = 1
		local function ajustarPelaCamera()
			local cam = workspace.CurrentCamera
			if not cam then return end
			local p = cam.CFrame.Position
			local dh = Vector2.new(p.X - c.X, p.Z - c.Z).Magnitude
			local dentro = math.clamp((raio * 1.15 - dh) / (raio * 0.35), 0, 1) * math.clamp((chaoY + 7 - p.Y) / 3, 0, 1)
			local fator = 1 - 0.75 * dentro
			if math.abs(fator - fatorAtual) < 0.04 then return end
			fatorAtual = fator
			for _, o in opacos do
				local tr = 1 - (1 - o.base) * fator
				o.e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, tr), NumberSequenceKeypoint.new(0.7, math.min(1, tr + 0.04)), NumberSequenceKeypoint.new(1, 1) })
			end
		end
		local rolos = {}
		for i = 1, 3 do
			local pr = cena:peca({ Size = Vector3.new(raio * 0.7, 0.5, raio * 0.7), Position = Vector3.new(c.X, chaoY + 0.3, c.Z), Transparency = 1 })
			rolos[i] = { parte = pr, em = emissorNevoa(pr, 3, 5, 0.5, 3.2, 1.6) }
		end
		ctx.som({ habilidadeId = "ability/agua/Principiante/nevoa-densa" }, "agua", 0.8)
		if ctx.camera then ctx.camera(Vector3.new(c.X, chaoY + 2, c.Z), Vector3.new(c.X, chaoY + 2, c.Z), 0, PlanosCamera.opc("nevoa-densa", true)) end -- CAM1: sobe e mostra a área
		anim = cena:anim(t0, t0 + 3600, function()
			local t = cena.T - t0
			local k = math.clamp(t / 2, 0, 1)
			if estado.tFim then k = 1 - math.clamp((cena.T - estado.tFim) / 1.4, 0, 1) end
			ajustarPelaCamera()
			fumo.Rate = (if FX.reduzidos then 14 else 60) * k * (1 + 0.1 * math.sin(cena.T * 0.7))
			veu.Rate = (if FX.reduzidos then 2 else 6) * k
			for i, r in rolos do
				local ang = cena.T * (0.35 + i * 0.1) + i * 2.1
				r.parte.Position = Vector3.new(c.X + math.cos(ang) * raio * 0.7, chaoY + 0.35, c.Z + math.sin(ang * 1.3) * raio * 0.7)
				r.em.Rate = (if FX.reduzidos then 4 else 14) * k
			end
			if estado.tFim and cena.T - estado.tFim > 1.5 then
				fumo.Enabled = false
				veu.Enabled = false
				for _, r in rolos do r.em.Enabled = false end
				if cena.T - estado.tFim > 9 then
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
function MagiasAgua.zonaDoMuro(muro: any, frente: Vector3?): (() -> ())?
	if not CTX_ZONAS then return nil end
	if muro.estilo == "agua" then return zonaEscudo(CTX_ZONAS, muro, 1.0, frente) end
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
		if ctx.camera then ctx.camera(mao, if falha then para else destino, t0 + voo, PlanosCamera.opc("respingo")) end -- CAM1: plano próprio (HAB6: mostra o acerto, mesmo de longe)
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
		if ctx.camera then ctx.camera(mao, if falha then para else destino, t0 + voo, PlanosCamera.opc("bola-de-agua")) end -- CAM1
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
		if ctx.camera then ctx.camera(mao, if falha then para else destino, 0.85 + voo, PlanosCamera.opc("flecha-de-agua")) end -- CAM1: segue a flecha até o acerto
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
		if ctx.camera then ctx.camera(mao, if falha then para else destino, t0 + voo + 0.2, PlanosCamera.opc("impacto-de-gelo")) end -- HAB8: plano próprio; o contato é o cristal crescendo
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
			finalDoAcerto(ctx, cena, tHit + 0.2, recibo, alvo, para, mao, 0.8, false) -- HAB8: número junto com os cristais (+0,2 s), não antes
		end
		cena.fimT = math.max(cena.fimT, tHit + 1.6)
		cena:iniciar()
	end

	return R
end

MagiasAgua.molhado = auraMolhado

return MagiasAgua
