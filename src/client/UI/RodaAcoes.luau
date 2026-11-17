-- RODA1/RODA2: corpo visual da roda de ações da luta (estrutura inspirada na roda de comandos de RPGs de turnos;
-- arte e tema nossos). Só apresentação: não conhece regra nem estado do jogo; quem usa (AcoesDoTurno) diz o que
-- cada cunha mostra e recebe as escolhas por callback, que caem no mesmo fluxo de intenção dos botões antigos.
-- Geometria em shared/Regras/LayoutLuta (L.roda, pura, com spec). Cunhas: PNGs de tools/arte/roda.py (um setor de
-- anel de 116 graus apontando para cima, girado 0/120/240 em volta do centro).
--   Roda.nova(pai, { aoEscolher = function(id) end, aoEncerrar = function() end }) -> api
--   api.raiz            Frame RODA x RODA (o chamador define a Position)
--   api.abrir() / api.fechar() / api.aberta()   abre em leque (cunhas em sequência, 0,18 s cada) e fecha
--   api.definirFatia(id, { custo = string, bloqueada = bool, alerta = bool })
--   api.ativar(id?)     cunha "ativa" (a lista dela está aberta)
--   api.focar(id?) / api.mover(passo) / api.foco()  foco do teclado/cursor
--   api.definirHub({ rotulo = string, pronto = bool })  botão central Encerrar turno
-- Instances: Roda > Hub | Corpo > Cunha_<id> (CanvasGroup) > Arte (ImageLabel girada), Fatia_<id> (TextButton) >
-- Icone, Rotulo, Custo, Tecla, Alerta.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.Regras.LayoutLuta)
local Arte = require(Shared:WaitForChild("UIArteLuta"))
local T = require(script.Parent.Tema)
local P = require(script.Parent.PecasLuta)

local Roda = {}
local new = P.novo

Roda.ORDEM = { "golpear", "habilidades", "acoes" }
Roda.ROTULOS = { golpear = "Golpear", habilidades = "Habilidades", acoes = "Ações" }
local TECLAS = { golpear = "1", habilidades = "2", acoes = "3" }
local ROTACAO = { habilidades = 0, acoes = 120, golpear = 240 } -- da cunha de cima, no sentido horário
local ORDEM_LEQUE = { "habilidades", "acoes", "golpear" } -- surgem em sequência, no sentido horário
local FOLGA = 20 -- a cunha em foco cresce para fora: o grupo é maior que o disco
local FUNDO_ATIVO = Color3.fromRGB(78, 56, 24)
local ENTRADA = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SAIDA = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function rotulo(pai, props)
	local l = new("TextLabel", nil, {
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = P.cor.texto, ZIndex = 5, TextStrokeColor3 = P.cor.trilho, TextStrokeTransparency = 0.4,
	})
	for k, v in props do l[k] = v end
	l.Parent = pai
	return l
end

function Roda.nova(pai: Instance, opcoes: { aoEscolher: (string) -> (), aoEncerrar: () -> () })
	local g = Layout.roda(0, 0)
	local lado = Layout.RODA
	local raiz = new("Frame", pai, { Name = "Roda", Size = UDim2.fromOffset(lado, lado), BackgroundTransparency = 1 })
	local corpo = new("Frame", raiz, { Name = "Corpo", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
	local centro = lado / 2

	local api: any = { raiz = raiz, fatias = {} }
	local estado = { aberta = false, foco = nil :: string?, ativa = nil :: string?, serial = 0 }

	local function pintar(id: string)
		local f = api.fatias[id]
		local ativa = estado.ativa == id
		local acesa = estado.foco == id or ativa
		P.trocarArte(f.arte, if f.bloqueada and not acesa then "cunha_bloqueada" elseif acesa then "cunha_foco" else "cunha_normal")
		P.animar(f.escala, { Scale = if ativa then 1.07 elseif acesa then 1.05 else 1 }, P.SUAVE, "foco")
		f.arte.ImageColor3 = if ativa then Color3.fromRGB(255, 235, 190) else Color3.new(1, 1, 1)
		P.animar(f.rotulo, { TextColor3 = if acesa then P.cor.ouroVivo else P.cor.texto }, P.SUAVE, "cor")
	end
	local function pintarTodas() for _, id in Roda.ORDEM do pintar(id) end end

	for _, id in Roda.ORDEM do
		local r = g.fatias[id]
		local grupo = new("CanvasGroup", corpo, {
			Name = "Cunha_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(centro, centro),
			Size = UDim2.fromOffset(lado + 2 * FOLGA, lado + 2 * FOLGA), BackgroundTransparency = 1, GroupTransparency = 0,
		})
		local arte = P.arte(grupo, "cunha_normal", 1)
		arte.AnchorPoint, arte.Position, arte.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(lado, lado)
		arte.Rotation = ROTACAO[id]
		local esc = new("UIScale", arte, { Name = "Foco", Scale = 1 })
		local b = new("TextButton", grupo, {
			Name = "Fatia_" .. id, Position = UDim2.fromOffset(r.x + FOLGA, r.y + FOLGA), Size = UDim2.fromOffset(r.w, r.h),
			Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
		})
		-- Conteúdo: ícone grande no meio da cunha, nome e custo (16 px) logo abaixo.
		local icone = P.icone(b, Arte.ICONES_RODA[id], P.cor.ouroVivo, 36)
		icone.AnchorPoint, icone.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 1)
		local nome = rotulo(b, {
			Name = "Rotulo", Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 22), Text = Roda.ROTULOS[id],
			FontFace = T.fontes.titulo, TextSize = 19,
		})
		local custo = rotulo(b, {
			Name = "Custo", Position = UDim2.fromOffset(0, 61), Size = UDim2.new(1, 0, 0, 20), Text = "",
			FontFace = T.fontes.numero, TextSize = 16, TextColor3 = P.cor.ouroVivo,
		})
		local tecla = P.tecla(b, TECLAS[id], 22)
		tecla.AnchorPoint, tecla.Position = Vector2.new(0, 0), UDim2.fromOffset(2, 2)
		local alerta = new("Frame", b, {
			Name = "Alerta", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = P.cor.inimigo, BorderSizePixel = 0, ZIndex = 8, Visible = false,
		})
		new("UICorner", alerta, { CornerRadius = UDim.new(0.5, 0) })
		new("UIStroke", alerta, { Color = P.cor.trilho, Thickness = 1.5 })
		api.fatias[id] = { grupo = grupo, arte = arte, botao = b, escala = esc, icone = icone, rotulo = nome, custo = custo, alerta = alerta, bloqueada = false }
		b.MouseEnter:Connect(function() estado.foco = id; pintarTodas() end)
		b.MouseLeave:Connect(function()
			if estado.foco == id then estado.foco = nil end
			pintarTodas()
		end)
		b.Activated:Connect(function() opcoes.aoEscolher(id) end)
	end

	-- Hub: Encerrar turno no centro (sempre visível, também com a roda fechada).
	local hub = new("TextButton", raiz, {
		Name = "Hub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(centro, centro), Size = UDim2.fromOffset(g.hub.w, g.hub.h),
		Text = "", AutoButtonColor = false, BackgroundColor3 = P.cor.fundo, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 4,
	})
	new("UICorner", hub, { CornerRadius = UDim.new(0.5, 0) })
	local contornoHub = new("UIStroke", hub, { Color = P.cor.ouro, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local escHub = new("UIScale", hub, { Name = "Foco", Scale = 1 })
	local iconeHub = P.icone(hub, Arte.ICONES_RODA.encerrar, P.cor.ouroVivo, 32)
	iconeHub.AnchorPoint, iconeHub.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 14)
	local nomeHub = rotulo(hub, {
		Name = "Rotulo", Position = UDim2.fromOffset(4, 50), Size = UDim2.new(1, -8, 0, 24), Text = "Encerrar", FontFace = T.fontes.titulo,
		TextSize = 17, TextTruncate = Enum.TextTruncate.None,
	})
	local teclaHub = P.tecla(hub, "V", 22)
	teclaHub.AnchorPoint, teclaHub.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(14, 14)
	hub.MouseEnter:Connect(function()
		P.animar(escHub, { Scale = 1.06 }, P.SUAVE, "foco")
		P.animar(contornoHub, { Color = P.cor.ouroVivo }, P.SUAVE, "cor")
	end)
	hub.MouseLeave:Connect(function()
		P.animar(escHub, { Scale = 1 }, P.SUAVE, "foco")
		P.animar(contornoHub, { Color = P.cor.ouro }, P.SUAVE, "cor")
	end)
	hub.Activated:Connect(opcoes.aoEncerrar)
	api.hub = hub

	function api.definirHub(p: { rotulo: string?, pronto: boolean? })
		if p.rotulo then nomeHub.Text = p.rotulo end
		contornoHub.Thickness = if p.pronto then 4 else 2.5
		nomeHub.TextColor3 = if p.pronto then P.cor.ouroVivo else P.cor.texto
		hub.BackgroundColor3 = if p.pronto then FUNDO_ATIVO else P.cor.fundo
	end

	function api.definirFatia(id: string, p: { custo: string?, bloqueada: boolean?, alerta: boolean? })
		local f = api.fatias[id]
		if p.custo then f.custo.Text = p.custo end
		local apagada = p.bloqueada == true
		f.bloqueada = apagada
		f.botao:SetAttribute("Bloqueada", apagada)
		f.icone.ImageTransparency = if apagada then 0.6 else 0
		f.rotulo.TextTransparency = if apagada then 0.5 else 0
		f.custo.TextColor3 = if apagada then P.cor.inimigo else P.cor.ouroVivo
		f.custo.TextTransparency = if apagada then 0.15 else 0
		f.alerta.Visible = p.alerta == true
		pintar(id)
	end

	function api.ativar(id: string?)
		estado.ativa = id
		pintarTodas()
	end
	function api.focar(id: string?)
		estado.foco = id
		pintarTodas()
	end
	function api.foco(): string? return estado.foco end
	function api.mover(passo: number)
		local i = table.find(Roda.ORDEM, estado.foco) or (if passo > 0 then 0 else #Roda.ORDEM + 1)
		api.focar(Roda.ORDEM[(i + passo - 1) % #Roda.ORDEM + 1])
	end

	function api.aberta(): boolean return estado.aberta end
	-- Leque: cada cunha gira uns graus para o lugar enquanto aparece, uma depois da outra.
	function api.abrir()
		if estado.aberta then return end
		estado.aberta = true
		estado.serial += 1
		local meu = estado.serial
		corpo.Visible = true
		pintarTodas()
		for i, id in ORDEM_LEQUE do
			local f = api.fatias[id]
			f.grupo.GroupTransparency, f.grupo.Rotation = 1, -26
			task.delay((i - 1) * 0.06, function()
				if estado.serial ~= meu then return end
				P.animar(f.grupo, { GroupTransparency = 0, Rotation = 0 }, ENTRADA, "leque")
			end)
		end
	end
	function api.fechar()
		if not estado.aberta then return end
		estado.aberta = false
		estado.serial += 1
		local meu = estado.serial
		estado.foco = nil
		for i, id in ORDEM_LEQUE do
			local f = api.fatias[id]
			task.delay((#ORDEM_LEQUE - i) * 0.03, function()
				if estado.serial ~= meu then return end
				P.animar(f.grupo, { GroupTransparency = 1, Rotation = 18 }, SAIDA, "leque")
			end)
		end
		task.delay(0.3, function()
			if estado.serial == meu then corpo.Visible = false end
		end)
	end

	return api
end

return Roda
