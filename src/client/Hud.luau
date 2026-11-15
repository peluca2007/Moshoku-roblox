-- HUD de jogo (A8, refeito na LUTA-B): mínimo, para a cena aparecer. Só lê o snapshot; não decide nada.
-- - Cartões (HudJogo.Cartoes > Cartao_<id>): nome, PV, PM e os marcadores das Ações do turno. Em luta,
--   um por personagem de jogador, empilhados no canto inferior direito; fora da luta, só o seu
--   personagem, no alto à direita (como antes).
-- - Ordem dos turnos (HudJogo.Ordem): fileira discreta sob o anúncio, no topo central, com a rodada
--   (ou o prazo da vez) e um nome por combatente (azul-aliado/vermelho-inimigo, quem age em destaque).
-- - Chefe (HudJogo.Chefe): vida e aviso da fase, abaixo da ordem.
-- Geometria em shared/Regras/LayoutLuta (pura, com spec).
local Players = game:GetService("Players")
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local Shared = game:GetService("ReplicatedStorage").Shared
local OrdemVisivel = require(Shared:WaitForChild("OrdemVisivel"))
local Layout = require(Shared.Regras.LayoutLuta)

local Hud = {}

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function texto(parent, props)
	local l = C.texto({ parent = parent })
	l.AutomaticSize = Enum.AutomaticSize.None
	l.TextSize = 15
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.FontFace = T.fontes.rotulo
	for k, v in props do
		l[k] = v
	end
	return l
end

-- Papel leve (sem a arte pesada do painel) para os cartões.
local function papel(parent, nome: string, tamanho: UDim2)
	local f = new("Frame", parent, { Name = nome, Size = tamanho, BackgroundColor3 = T.cores.painel, BackgroundTransparency = 0.06, BorderSizePixel = 0 })
	new("UICorner", f, { CornerRadius = UDim.new(0, T.raios.painel) })
	new("UIStroke", f, { Color = T.cores.borda, Thickness = T.espessuras.borda })
	return f
end

function Hud.start(state)
	local eu = Players.LocalPlayer
	local gui = new("ScreenGui", eu:WaitForChild("PlayerGui"), {
		Name = "HudJogo", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Cartões dos personagens.
	local cartoes = new("Frame", gui, { Name = "Cartoes", BackgroundTransparency = 1, Size = UDim2.fromOffset(Layout.CARTAO_LARGURA, Layout.CARTAO_ALTURA), Visible = false })
	local fichas: { [string]: any } = {}
	local function cartaoDe(id: string)
		local f = fichas[id]
		if f then return f end
		local q = papel(cartoes, "Cartao_" .. id, UDim2.fromOffset(Layout.CARTAO_LARGURA, Layout.CARTAO_ALTURA))
		local nome = texto(q, { Name = "Nome", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -92, 0, 24), FontFace = T.fontes.titulo, TextSize = 18, TextColor3 = T.cores.titulo })
		local acoes = texto(q, { Name = "Acoes", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(80, 24),
			TextXAlignment = Enum.TextXAlignment.Right, FontFace = T.fontes.numero, TextSize = 18, TextColor3 = T.cores.titulo })
		local _, pv = C.barraCompacta({ parent = q, nome = "PV", rotulo = "PV", posicao = UDim2.fromOffset(10, 30), tamanho = UDim2.new(0.5, -14, 0, 38) })
		local _, pm = C.barraCompacta({ parent = q, nome = "PM", rotulo = "PM", destaque = T.barras.mana, posicao = UDim2.new(0.5, 4, 0, 30), tamanho = UDim2.new(0.5, -14, 0, 38) })
		local pvBarra, pmBarra = q.PV, q.PM
		f = { q = q, nome = nome, acoes = acoes, pv = pv, pm = pm, pvBarra = pvBarra, pmBarra = pmBarra }
		fichas[id] = f
		return f
	end

	-- Chefe: vida e aviso da fase.
	local chefe = papel(gui, "Chefe", UDim2.fromOffset(360, 84))
	chefe.AnchorPoint, chefe.Visible = Vector2.new(0.5, 0), false
	local chefeNome = texto(chefe, { Name = "Nome", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), FontFace = T.fontes.titulo, TextSize = 18, TextColor3 = T.cores.perigo })
	local _, chefeVida = C.barraCompacta({ parent = chefe, nome = "BarraChefe", rotulo = "CHEFE", destaque = T.barras.baixa, posicao = UDim2.fromOffset(10, 26), tamanho = UDim2.new(1, -20, 0, 38) })
	local chefeAviso = texto(chefe, { Name = "Aviso", Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 18), TextSize = 14, TextColor3 = T.cores.secundario })

	-- Ordem dos turnos: fileira de nomes sobre o mundo (sem caixa).
	local ordem = new("Frame", gui, { Name = "Ordem", BackgroundTransparency = 1, Size = UDim2.fromOffset(Layout.TOPO_MAX, Layout.ORDEM_H), Visible = false, ClipsDescendants = true })
	new("UIListLayout", ordem, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local chips: { [number]: any } = {}
	local function chip(i: number)
		local c = chips[i]
		if c then return c end
		c = new("TextLabel", ordem, { Name = "Vez" .. i, Size = UDim2.fromOffset(Layout.ORDEM_CHIP, Layout.ORDEM_H), BackgroundTransparency = 1, LayoutOrder = i,
			FontFace = T.fontes.rotulo, TextSize = 15, TextStrokeColor3 = T.cores.fundoTela, TextStrokeTransparency = 0.15, TextTruncate = Enum.TextTruncate.AtEnd })
		chips[i] = c
		return c
	end
	-- Rodada, ou o prazo da vez quando há mais de um jogador.
	local prazo = new("TextLabel", ordem, { Name = "Prazo", Size = UDim2.fromOffset(Layout.ORDEM_CHIP, Layout.ORDEM_H), BackgroundTransparency = 1, LayoutOrder = 0,
		FontFace = T.fontes.numero, TextSize = 15, TextColor3 = T.sobreEscuro.texto, Text = "", TextStrokeColor3 = T.cores.fundoTela, TextStrokeTransparency = 0.15 })
	local quantidade = 0

	local function posicionar(vp: Vector2, emLuta: boolean, meusCartoes: number)
		local topo = Layout.topo(vp.X)
		ordem.Position, ordem.Size = UDim2.fromOffset(topo.ordem.x, topo.ordem.y), UDim2.fromOffset(topo.ordem.w, topo.ordem.h)
		chefe.Position = UDim2.fromOffset(vp.X / 2, topo.ordem.y + topo.ordem.h + Layout.GAP)
		if emLuta then
			local rects = Layout.cartoes(vp.X, vp.Y, math.max(1, meusCartoes))
			local primeiro = rects[1]
			-- o contêiner cobre a pilha inteira; Cartao_<id> são posicionados por índice dentro dele
			cartoes.Position = UDim2.fromOffset(primeiro.x, primeiro.y)
			cartoes.Size = UDim2.fromOffset(primeiro.w, rects[#rects].y + rects[#rects].h - primeiro.y)
		else
			cartoes.Position = UDim2.new(1, -(Layout.MARGEM + Layout.CARTAO_LARGURA + 4), 0, 144)
			cartoes.Size = UDim2.fromOffset(Layout.CARTAO_LARGURA, Layout.CARTAO_ALTURA)
		end
	end

	local function atualizar()
		local snap = state.snapshot()
		if not snap then
			return
		end
		local vp = workspace.CurrentCamera.ViewportSize
		local emLuta = snap.combat.active == true
		local boss = snap.encontro and snap.encontro.chefe
		chefe.Visible = emLuta and boss ~= nil
		if boss then
			chefeNome.Text = boss.nome .. " · Fase " .. boss.fase
			chefeVida(boss.pv, boss.pvMax)
			chefeAviso.Text = if boss.aviso then boss.aviso.nome .. (if boss.areaAtiva then " · Saia da área!" else " · Prévia visual") else "O bosque aguarda…"
		end

		-- Quem ganha cartão: em luta, todo personagem de jogador; fora dela, o meu (o da vez, se houver mais de um).
		local doGrupo, meu = {}, nil
		for _, t in snap.tokens do
			if t.kind == "jogador" then
				if emLuta then table.insert(doGrupo, t) end
				if t.ownerUserId == eu.UserId and (not meu or snap.combat.turnId == t.id) then meu = t end
			end
		end
		if not emLuta and meu then doGrupo = { meu } end
		local usadas = if snap.jogo and snap.jogo.acoes then snap.jogo.acoes else nil
		local vistos = {}
		local rects = Layout.cartoes(vp.X, vp.Y, math.max(1, #doGrupo))
		for i, t in doGrupo do
			local f = cartaoDe(t.id)
			vistos[t.id] = true
			f.q.Visible = true
			f.q.Position = UDim2.fromOffset(0, if emLuta then rects[i].y - rects[1].y else 0)
			f.nome.Text = t.name
			f.pv(t.pv, t.pvMax)
			f.pm(t.mana, t.manaMax)
			local daVez = emLuta and snap.combat.turnId == t.id and usadas ~= nil and usadas.tokenId == t.id
			f.acoes.Text = if daVez then string.rep("◆", math.max(0, usadas.total - usadas.usadas)) .. string.rep("◇", usadas.usadas) else ""
			f.q.UIStroke.Color = if emLuta and snap.combat.turnId == t.id then T.cores.ouro else T.cores.borda
			f.q.UIStroke.Thickness = if emLuta and snap.combat.turnId == t.id then T.espessuras.destaque else T.espessuras.borda
		end
		for id, f in fichas do
			if not vistos[id] then f.q:Destroy(); fichas[id] = nil end
		end
		cartoes.Visible = #doGrupo > 0
		posicionar(vp, emLuta, #doGrupo)

		-- Ordem dos turnos.
		ordem.Visible = emLuta
		local usados = 0
		if emLuta then
			local lista = OrdemVisivel.listar(snap.combat.order or {}, snap.combat.turnId, snap.tokens)
			quantidade = #lista
			local cabem = Layout.ordemCabe(Layout.topo(vp.X).ordem.w - Layout.ORDEM_CHIP - Layout.ESPACO, #lista)
			for i = 1, cabem do
				local t = lista[i]
				local c = chip(i)
				local daVez = snap.combat.turnId == t.id
				c.Visible = true
				c.Text = (if daVez then "▶ " else "") .. (if t.criatura then "☠ " else "") .. t.name
				c.TextColor3 = if daVez then T.sobreEscuro.titulo elseif t.criatura then T.barras.baixa else T.barras.cheia
				c.FontFace = if daVez then T.fontes.titulo else T.fontes.rotulo
				usados = i
			end
			if cabem < #lista then
				local c = chip(cabem + 1)
				c.Visible, c.Text, c.TextColor3 = true, "+" .. (#lista - cabem), T.sobreEscuro.secundario
				usados = cabem + 1
			end
		end
		for i, c in chips do
			if i > usados then c.Visible = false end
		end
	end

	state.onSnapshot(atualizar)
	task.spawn(function()
		while gui.Parent do
			local snap = state.snapshot()
			local e = snap and snap.encontro
			if e and e.prazoFim and snap.combat.active then
				local resto = math.max(0, math.ceil(e.prazoFim - workspace:GetServerTimeNow()))
				local dono = nil
				for _, t in snap.tokens do
					if t.id == e.prazoId then dono = t end
				end
				prazo.Text = string.format("%s%d s", if dono and dono.ownerUserId == eu.UserId then "Sua vez · " else "", resto)
				prazo.TextColor3 = if resto <= 10 then T.barras.baixa else T.sobreEscuro.titulo
			else
				prazo.Text = if snap and snap.combat.active and quantidade > 0 then "Rodada " .. (snap.combat.round or 1) else ""
				prazo.TextColor3 = T.sobreEscuro.texto
			end
			task.wait(0.25)
		end
	end)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(atualizar)
	atualizar()
	return gui
end

return Hud
