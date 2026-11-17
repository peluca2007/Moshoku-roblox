-- RODA1: corpo visual da roda de ações da luta (estrutura inspirada na roda de comandos de RPGs de turnos;
-- arte e tema nossos). Só apresentação: não conhece regra nem estado do jogo; quem usa (AcoesDoTurno) diz o que
-- cada fatia mostra e recebe as escolhas por callback, que caem no mesmo fluxo de intenção dos botões antigos.
-- Geometria em shared/Regras/LayoutLuta (L.roda, pura, com spec).
--   Roda.nova(pai, { aoEscolher = function(id) end, aoEncerrar = function() end }) -> api
--   api.raiz            Frame quadrado RODA x RODA (o chamador define a Position)
--   api.abrir() / api.fechar() / api.aberta()   animação curta (0,25 s entra, 0,16 s sai)
--   api.definirFatia(id, { custo = string, bloqueada = bool, alerta = bool })
--   api.ativar(id?)     fatia "ativa" (a lista dela está aberta)
--   api.focar(id?) / api.mover(passo) / api.foco()  foco do teclado/cursor
--   api.definirHub({ rotulo = string, pronto = bool })  botão central Encerrar turno
-- Instances: Roda > Hub | Corpo (CanvasGroup) > Disco, Anel, Fatia_golpear, Fatia_habilidades, Fatia_acoes
-- (cada uma com Icone, Rotulo, Custo, Tecla, Alerta).
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
local FUNDO_ATIVO = Color3.fromRGB(78, 56, 24)
local ENTRADA = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SAIDA = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function rotulo(pai, props)
	local l = new("TextLabel", nil, {
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = P.cor.texto, ZIndex = 5,
	})
	for k, v in props do l[k] = v end
	l.Parent = pai
	return l
end

function Roda.nova(pai: Instance, opcoes: { aoEscolher: (string) -> (), aoEncerrar: () -> () })
	local g = Layout.roda(0, 0)
	local raiz = new("Frame", pai, { Name = "Roda", Size = UDim2.fromOffset(g.w, g.h), BackgroundTransparency = 1 })
	local corpo = new("CanvasGroup", raiz, { Name = "Corpo", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false })
	local escala = new("UIScale", corpo, { Name = "Entrada", Scale = 0.8 })
	local cx, cy = g.hub.x + g.hub.w / 2, g.hub.y + g.hub.h / 2

	-- Disco de tinta e o anel onde as fatias assentam.
	local diametro = 2 * Layout.RODA_RAIO + 52
	local disco = new("Frame", corpo, {
		Name = "Disco", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(diametro, diametro),
		BackgroundColor3 = P.cor.trilho, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 1,
	})
	new("UICorner", disco, { CornerRadius = UDim.new(0.5, 0) })
	new("UIStroke", disco, { Color = P.cor.ouro, Thickness = 1.5, Transparency = 0.45 })
	local anel = new("Frame", corpo, {
		Name = "Anel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(2 * Layout.RODA_RAIO, 2 * Layout.RODA_RAIO),
		BackgroundTransparency = 1, ZIndex = 1,
	})
	new("UICorner", anel, { CornerRadius = UDim.new(0.5, 0) })
	new("UIStroke", anel, { Color = P.cor.ouro, Thickness = 1, Transparency = 0.65 })

	local api: any = { raiz = raiz, fatias = {} }
	local estado = { aberta = false, foco = nil :: string?, ativa = nil :: string?, serial = 0 }

	local function pintar(id: string)
		local f = api.fatias[id]
		local acesa = estado.foco == id or estado.ativa == id
		P.animar(f.escala, { Scale = if acesa then 1.08 else 1 }, P.SUAVE, "foco")
		P.animar(f.botao, { BackgroundColor3 = if estado.ativa == id then FUNDO_ATIVO else P.cor.fundo }, P.SUAVE, "fundo")
		P.animar(f.contorno, {
			Color = if acesa then P.cor.ouroVivo else P.cor.ouro, Thickness = if estado.ativa == id then 3 elseif acesa then 2.5 else 1.5,
			Transparency = if f.bloqueada and not acesa then 0.6 else 0,
		}, P.SUAVE, "contorno")
	end

	for _, id in Roda.ORDEM do
		local r = g.fatias[id]
		local b = new("TextButton", corpo, {
			Name = "Fatia_" .. id, Position = UDim2.fromOffset(r.x, r.y), Size = UDim2.fromOffset(r.w, r.h), Text = "", AutoButtonColor = false,
			BackgroundColor3 = P.cor.fundo, BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 3,
		})
		new("UICorner", b, { CornerRadius = UDim.new(0.5, 0) })
		local contorno = new("UIStroke", b, { Name = "Contorno", Color = P.cor.ouro, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		local esc = new("UIScale", b, { Name = "Foco", Scale = 1 })
		local icone = P.icone(b, Arte.ICONES_RODA[id], P.cor.ouroVivo, 30)
		icone.AnchorPoint, icone.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 9)
		local nome = rotulo(b, {
			Name = "Rotulo", Position = UDim2.fromOffset(4, 41), Size = UDim2.new(1, -8, 0, 18), Text = Roda.ROTULOS[id],
			FontFace = T.fontes.titulo, TextSize = 15, TextScaled = true, TextTruncate = Enum.TextTruncate.None,
		})
		new("UITextSizeConstraint", nome, { MaxTextSize = 16, MinTextSize = 11 })
		local custo = rotulo(b, {
			Name = "Custo", Position = UDim2.fromOffset(6, 60), Size = UDim2.new(1, -12, 0, 14), Text = "",
			FontFace = T.fontes.numero, TextSize = 12, TextColor3 = P.cor.ouro, TextScaled = true, TextTruncate = Enum.TextTruncate.None,
		})
		new("UITextSizeConstraint", custo, { MaxTextSize = 12, MinTextSize = 9 })
		local tecla = P.tecla(b, TECLAS[id], 22)
		tecla.AnchorPoint, tecla.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(13, 13)
		local alerta = new("Frame", b, {
			Name = "Alerta", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(r.w - 13, 13), Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = P.cor.inimigo, BorderSizePixel = 0, ZIndex = 8, Visible = false,
		})
		new("UICorner", alerta, { CornerRadius = UDim.new(0.5, 0) })
		new("UIStroke", alerta, { Color = P.cor.trilho, Thickness = 1.5 })
		api.fatias[id] = { botao = b, escala = esc, contorno = contorno, icone = icone, nome = nome, custo = custo, alerta = alerta, bloqueada = false }
		b.MouseEnter:Connect(function() estado.foco = id; for _, outro in Roda.ORDEM do pintar(outro) end end)
		b.MouseLeave:Connect(function()
			if estado.foco == id then estado.foco = nil end
			for _, outro in Roda.ORDEM do pintar(outro) end
		end)
		b.Activated:Connect(function() opcoes.aoEscolher(id) end)
	end

	-- Hub: Encerrar turno no centro (sempre visível, também com a roda fechada).
	local hub = new("TextButton", raiz, {
		Name = "Hub", Position = UDim2.fromOffset(g.hub.x, g.hub.y), Size = UDim2.fromOffset(g.hub.w, g.hub.h), Text = "", AutoButtonColor = false,
		BackgroundColor3 = P.cor.fundo, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 4,
	})
	new("UICorner", hub, { CornerRadius = UDim.new(0.5, 0) })
	local contornoHub = new("UIStroke", hub, { Color = P.cor.ouro, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local escHub = new("UIScale", hub, { Name = "Foco", Scale = 1 })
	local iconeHub = P.icone(hub, Arte.ICONES_RODA.encerrar, P.cor.ouroVivo, 26)
	iconeHub.AnchorPoint, iconeHub.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 10)
	local nomeHub = rotulo(hub, {
		Name = "Rotulo", Position = UDim2.fromOffset(4, 38), Size = UDim2.new(1, -8, 0, 22), Text = "Encerrar", FontFace = T.fontes.titulo,
		TextSize = 14, TextScaled = true, TextTruncate = Enum.TextTruncate.None, TextWrapped = true,
	})
	new("UITextSizeConstraint", nomeHub, { MaxTextSize = 14, MinTextSize = 10 })
	local teclaHub = P.tecla(hub, "V", 20)
	teclaHub.AnchorPoint, teclaHub.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(11, 11)
	hub.MouseEnter:Connect(function()
		P.animar(escHub, { Scale = 1.08 }, P.SUAVE, "foco")
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
		contornoHub.Thickness = if p.pronto then 3.5 else 2
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
		f.nome.TextTransparency = if apagada then 0.5 else 0
		f.custo.TextColor3 = if apagada then P.cor.inimigo else P.cor.ouro
		f.custo.TextTransparency = if apagada then 0.2 else 0
		f.botao.BackgroundTransparency = if apagada then 0.3 else 0.08
		f.alerta.Visible = p.alerta == true
		pintar(id)
	end

	function api.ativar(id: string?)
		estado.ativa = id
		for _, outro in Roda.ORDEM do pintar(outro) end
	end

	function api.focar(id: string?)
		estado.foco = id
		for _, outro in Roda.ORDEM do pintar(outro) end
	end
	function api.foco(): string? return estado.foco end
	function api.mover(passo: number)
		local i = table.find(Roda.ORDEM, estado.foco) or (if passo > 0 then 0 else #Roda.ORDEM + 1)
		api.focar(Roda.ORDEM[(i + passo - 1) % #Roda.ORDEM + 1])
	end

	function api.aberta(): boolean return estado.aberta end
	function api.abrir()
		if estado.aberta then return end
		estado.aberta = true
		estado.serial += 1
		corpo.Visible = true
		P.animar(corpo, { GroupTransparency = 0 }, TweenInfo.new(0.2, Enum.EasingStyle.Quad), "alfa")
		P.animar(escala, { Scale = 1 }, ENTRADA, "escala")
	end
	function api.fechar()
		if not estado.aberta then return end
		estado.aberta = false
		estado.serial += 1
		local meu = estado.serial
		estado.foco = nil
		P.animar(corpo, { GroupTransparency = 1 }, SAIDA, "alfa")
		P.animar(escala, { Scale = 0.85 }, SAIDA, "escala")
		task.delay(0.18, function()
			if estado.serial == meu then corpo.Visible = false end
		end)
	end

	return api
end

return Roda
