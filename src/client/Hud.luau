-- HUD de jogo (A8): o que um jogador precisa ver sem abrir painel nenhum.
-- - Cartão do seu personagem: PV, PM e PT, sempre visível (a barra de ações some
--   fora da sua vez, e antes a vida só aparecia no registro).
-- - Ordem dos turnos durante o combate: quem age, quem vem depois e a vida de
--   cada um que você pode ver. Só lê o snapshot; não decide nada.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local OrdemVisivel = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("OrdemVisivel"))

local Hud = {}

local AZUL_PM = T.cores.info
local function corDaVida(r: number): Color3
	return if r > 0.5 then T.cores.sucesso elseif r > 0.25 then T.cores.alerta else T.cores.perigo
end

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local o
	if class == "Frame" and props.BackgroundColor3 == T.cores.painel then
		o = C.painel({ parent = parent, padding = 0, sombra = false })
		o.Conteudo:Destroy()
	elseif class == "TextLabel" then
		o = C.texto({ parent = parent })
		o.AutomaticSize = Enum.AutomaticSize.None
	else o = Instance.new(class) end
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function cantos(o: Instance, r: number)
	if o:FindFirstChildOfClass("UICorner") then return end
	new("UICorner", o, { CornerRadius = UDim.new(0, T.raios.painel) })
end
local function texto(parent, props)
	local l = new("TextLabel", parent, {
		BackgroundTransparency = 1, TextColor3 = T.cores.texto, FontFace = T.fontes.rotulo, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	for k, v in props do
		l[k] = v
	end
	return l
end

-- Barra com rótulo: devolve a função que a atualiza.
local function barra(parent, y: number, rotulo: string, cor: Color3?)
	local raiz, atualizar = C.barra({ parent = parent, rotulo = rotulo, destaque = cor,
		posicao = UDim2.fromOffset(12, y), tamanho = UDim2.new(1, -24, 0, 36) })
	-- Versão compacta da mesma barra; números permanecem legíveis no cartão do HUD.
	for _, filho in raiz:GetChildren() do
		if filho:IsA("TextLabel") then
			filho.AutomaticSize = Enum.AutomaticSize.None
			filho.TextSize = T.tamanhos.corpo
			filho.Size = UDim2.new(if filho.Name == "Numero" then .7 else .3, 0, 0, 18)
			if filho.Name == "Numero" then filho.Position = UDim2.fromScale(.3, 0) end
		end
	end
	raiz.Trilho.Position, raiz.Trilho.Size = UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 10)
	return function(atual: number?, maximo: number?)
		raiz.Visible = atual ~= nil and maximo ~= nil and maximo > 0
		if not raiz.Visible then return end
		local r = math.clamp(atual / maximo, 0, 1)
		raiz.Trilho.Preenchimento.BackgroundColor3 = cor or corDaVida(r)
		atualizar(r, string.format("%d / %d", atual, maximo))
	end
end

function Hud.start(state)
	local eu = Players.LocalPlayer
	local gui = new("ScreenGui", eu:WaitForChild("PlayerGui"), {
		Name = "HudJogo", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, -- barras (z=1) ficavam sob o painel (z=2) no modo Global
	})

	-- Cartão do personagem (alto à esquerda, abaixo dos botões).
	local cartao = new("Frame", gui, {
		Name = "Cartao", Position = UDim2.new(1, -296, 0, 144), Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.cores.painel, BackgroundTransparency = 0.08, Visible = false,
	})
	cantos(cartao, 10)
	local contorno = new("UIStroke", cartao, { Color = T.cores.borda, Thickness = T.espessuras.borda })
	new("UIPadding", cartao, { PaddingBottom = UDim.new(0, 10) })
	local nome = texto(cartao, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), FontFace = T.fontes.titulo, TextSize = 20 })
	local estado = texto(cartao, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 16), TextSize = 12, TextColor3 = T.cores.secundario })
	local pv = barra(cartao, 50, "PV")
	local pm = barra(cartao, 76, "PM", AZUL_PM)
	local pt = barra(cartao, 102, "PT", T.cores.alerta)
	-- No celular, recursos e condições ficam em uma faixa curta e estável entre turnos.
	local resumo = new("Frame", gui, {
		Name = "Resumo", Position = UDim2.fromOffset(136, 140), Size = UDim2.new(1, -152, 0, 80),
		BackgroundColor3 = T.cores.painel, BackgroundTransparency = .08, Visible = false,
	})
	cantos(resumo, 8)
	local resumoNome = texto(resumo, { Name="Nome", Position=UDim2.fromOffset(8, 3), Size=UDim2.new(1,-16,0,16), TextSize=13 })
	local resumoRecursos = texto(resumo, { Name="Recursos", Position=UDim2.fromOffset(8, 20), Size=UDim2.new(1,-16,0,16), TextSize=13 })
	local resumoPV = barra(resumo, 54, "PV")
	local resumoEstado = texto(resumo, { Name="Estado", Position=UDim2.fromOffset(8, 37), Size=UDim2.new(1,-16,0,16), TextSize=12, TextColor3=T.cores.secundario })
	local chefe = new("Frame",gui,{Name="Chefe",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,142),Size=UDim2.new(.9,0,0,78),BackgroundColor3=T.cores.painel,Visible=false,BorderSizePixel=0})
	new("UISizeConstraint",chefe,{MaxSize=Vector2.new(460,78)})
	cantos(chefe,8)
	local chefeNome=texto(chefe,{Name="Nome",Position=UDim2.fromOffset(12,5),Size=UDim2.new(1,-24,0,22),TextSize=18,TextColor3=T.cores.alerta})
	local chefeVida=barra(chefe,30,"CHEFE",T.cores.perigo)
	local chefeAviso=texto(chefe,{Name="Aviso",Position=UDim2.fromOffset(12,51),Size=UDim2.new(1,-24,0,22),TextSize=12})

	-- Ordem dos turnos (no alto, no centro).
	local ordem = new("ScrollingFrame", gui, {
		Name = "Ordem", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.38, 0, 0, 8), Size = UDim2.new(.92, 0, 0, 52),
		AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4, ScrollBarImageColor3 = T.cores.secundario, BorderSizePixel = 0,
		BackgroundTransparency = 1, Visible = false, ClipsDescendants = true,
	})
	new("UISizeConstraint", ordem, { MaxSize = Vector2.new(760, 52) })
	new("UIPadding", ordem, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 3) })
	local layout = new("UIListLayout", ordem, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local fichas: { [string]: any } = {}
	local ultimoTurno = nil
	local quantidade = 0

	local function fichaDaOrdem(id: string)
		local f = fichas[id]
		if f then
			return f
		end
		local quadro = new("Frame", ordem, { Name = id, Size = UDim2.fromOffset(128, 44), BackgroundColor3 = T.cores.painel, BackgroundTransparency = 0.08 })
		cantos(quadro, 8)
		local borda = new("UIStroke", quadro, { Color = T.cores.borda, Thickness = T.espessuras.borda })
		local papel = texto(quadro, { Name = "Vez", Position = UDim2.fromOffset(8, 1), Size = UDim2.new(1, -16, 0, 12), TextSize = 10, TextColor3 = T.cores.secundario })
		local rotulo = texto(quadro, { Name = "Nome", Position = UDim2.fromOffset(8, 13), Size = UDim2.new(1, -16, 0, 18), TextSize = 13 })
		local fundo = C.barra({ parent = quadro, posicao = UDim2.fromOffset(8, 34), tamanho = UDim2.new(1, -16, 0, 6) })
		for _, filho in fundo:GetChildren() do if filho:IsA("TextLabel") then filho.Visible = false end end
		fundo.Trilho.Position, fundo.Trilho.Size = UDim2.new(), UDim2.fromScale(1, 1)
		local cheio = fundo.Trilho.Preenchimento
		f = { quadro = quadro, borda = borda, rotulo = rotulo, papel = papel, fundo = fundo, cheio = cheio }
		fichas[id] = f
		return f
	end

	local function atualizar()
		local snap = state.snapshot()
		if not snap then
			return
		end
		local boss=snap.encontro and snap.encontro.chefe
		chefe.Visible=snap.combat.active and boss~=nil
		cartao.Position=UDim2.new(1, -296, 0, if boss then 230 else 144)
		if boss then
			chefeNome.Text=boss.nome.." · Fase "..boss.fase
			chefeVida(boss.pv,boss.pvMax)
			chefeAviso.Text=if boss.aviso then boss.aviso.nome..(if boss.areaAtiva then " · Saia da área!" else " · Prévia visual") else "O bosque aguarda…"
		end
		-- Meu personagem: a ficha de jogador que é minha (a da vez, se houver mais de uma).
		local meu = nil
		for _, t in snap.tokens do
			if t.ownerUserId == eu.UserId and t.kind == "jogador" then
				if not meu or snap.combat.turnId == t.id then
					meu = t
				end
			end
		end
		local vp = workspace.CurrentCamera.ViewportSize
		local compacta = vp.X < 700 or vp.Y < 500
		cartao.Size = if compacta then UDim2.new(1, -152, 0, 0) else UDim2.fromOffset(280, 0)
		if compacta then cartao.Position = UDim2.fromOffset(136, 140) end
		chefe.AnchorPoint = if compacta then Vector2.zero else Vector2.new(.5, 0)
		chefe.Position = if compacta then UDim2.fromOffset(136, 230) else UDim2.new(.5, 0, 0, 142)
		chefe.Size = if compacta then UDim2.new(1, -152, 0, 78) else UDim2.new(.9, 0, 0, 78)
		resumo.Visible = meu ~= nil and compacta and snap.combat.active
		cartao.Visible = meu ~= nil and not resumo.Visible
		if meu then
			nome.Text = meu.name
			local partes = {}
			if snap.combat.active then
				table.insert(partes, if snap.combat.turnId == meu.id then "SUA VEZ" else "aguarde a sua vez")
			end
			if snap.encontro and snap.encontro.modo == "duelo" then
				local times=snap.encontro.equipes or {}
				local equipe=times[eu.UserId] or times[tostring(eu.UserId)]
				table.insert(partes, if equipe and equipe>0 then "EQUIPE "..equipe else "CADA UM POR SI")
			end
			for _, e in meu.estadosCombate or {} do
				table.insert(partes, e)
			end
			for _, c in meu.conditions or {} do
				table.insert(partes, (string.gsub(c.id, "-", " ")))
			end
			estado.Text = table.concat(partes, " • ")
			resumoNome.Text, resumoEstado.Text = nome.Text, estado.Text
			resumoPV(meu.pv, meu.pvMax)
			local recursos = {}
			for _, r in {{"PV",meu.pv,meu.pvMax},{"PM",meu.mana,meu.manaMax},{"PT",meu.pt,meu.ptMax}} do
				if r[2] ~= nil and r[3] ~= nil and r[3] > 0 then table.insert(recursos, string.format("%s %d/%d", r[1],r[2],r[3])) end
			end
			resumoRecursos.Text = table.concat(recursos, "  ·  ")
			contorno.Color = if snap.combat.active and snap.combat.turnId == meu.id then T.cores.alerta else T.cores.borda
			pv(meu.pv, meu.pvMax)
			pm(meu.mana, meu.manaMax)
			pt(meu.pt, meu.ptMax)
		end

		-- Ordem dos turnos.
		ordem.Visible = snap.combat.active == true
		local vistos = {}
		if snap.combat.active then
			local lista = OrdemVisivel.listar(snap.combat.order or {}, snap.combat.turnId, snap.tokens)
			quantidade = #lista
			for i, t in lista do
				local id = t.id
				vistos[id] = true
				local f = fichaDaOrdem(id)
				f.quadro.LayoutOrder = i
				f.rotulo.Text = (if t.criatura then "☠ " else "") .. t.name
				local daVez = snap.combat.turnId == id
				f.papel.Text = if daVez then "AGORA" elseif i == 1 then "PRÓXIMO VISÍVEL" elseif i == 2 then "DEPOIS" else "A SEGUIR"
				f.papel.TextColor3 = if daVez then T.cores.alerta else T.cores.secundario
				f.borda.Color = if daVez then T.cores.alerta elseif t.criatura then T.cores.perigo else T.cores.borda
				f.borda.Thickness = if daVez then T.espessuras.destaque else T.espessuras.borda
				local caido = t.derrotado or (t.pv ~= nil and t.pv <= 0)
				f.quadro.BackgroundTransparency = if caido then 0.6 else 0.08
				f.rotulo.TextTransparency = if caido then 0.5 else 0
				local temVida = t.pv ~= nil and t.pvMax ~= nil and t.pvMax > 0
				f.fundo.Visible = temVida
				if temVida then
					local r = math.clamp(t.pv / t.pvMax, 0, 1)
					TweenService:Create(f.cheio, TweenInfo.new(0.35), { Size = UDim2.fromScale(r, 1), BackgroundColor3 = corDaVida(r) }):Play()
				end
			end
		end
		if ultimoTurno ~= snap.combat.turnId or not snap.combat.active then
			ordem.CanvasPosition = Vector2.zero
		end
		ultimoTurno = if snap.combat.active then snap.combat.turnId else nil
		for id, f in fichas do
			if not vistos[id] then
				f.quadro:Destroy()
				fichas[id] = nil
			end
		end
	end

	-- Prazo da vez (só com mais de um jogador): contagem no cartão e na ordem.
	local prazo = texto(gui, {
		Name = "Prazo", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.38, 0, 0, 60), Size = UDim2.new(.92, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center, FontFace = T.fontes.titulo, TextSize = 18, Text = "", TextColor3 = T.cores.alerta,
		TextStrokeColor3 = T.cores.textoEscuro, TextStrokeTransparency = 0.3,
	})
	new("UISizeConstraint", prazo, { MaxSize = Vector2.new(760, 22) })
	local function redimensionar()
		local largura = gui.AbsoluteSize.X
		local centro = if largura < 1100 then .5 else .38
		local vp = workspace.CurrentCamera.ViewportSize
		local baixa = vp.Y < 500
		ordem.AnchorPoint = if baixa then Vector2.zero else Vector2.new(.5, 0)
		ordem.Position = if baixa then UDim2.fromOffset(136, 82) else UDim2.new(centro, 0, 0, 82)
		ordem.Size = if baixa then UDim2.new(1, -152, 0, 52) else UDim2.new(.92, 0, 0, 52)
		-- Prazo usa a metade direita da primeira linha do resumo compacto.
		prazo.AnchorPoint = Vector2.new(if resumo.Visible then 1 else .5, 0)
		prazo.Position = if resumo.Visible then UDim2.new(1, -16, 0, 118) else UDim2.new(centro, 0, 0, 134)
		prazo.Size = if resumo.Visible then UDim2.new(.5, -54, 0, 16) else UDim2.new(.92, 0, 0, 22)
		resumoNome.Size = UDim2.new(1, -16, 0, 16)
		for _, f in fichas do
			f.quadro.Size = UDim2.fromOffset(if ordem.AbsoluteSize.X < 620 then 104 else 128, 44)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() atualizar(); redimensionar() end)
	ordem:GetPropertyChangedSignal("AbsoluteSize"):Connect(redimensionar)
	state.onSnapshot(function() atualizar(); redimensionar() end)
	atualizar(); redimensionar()
	task.spawn(function()
		while gui.Parent do
			local snap = state.snapshot()
			local e = snap and snap.encontro
			if e and e.prazoFim and snap.combat.active then
				local resto = math.max(0, math.ceil(e.prazoFim - workspace:GetServerTimeNow()))
				local dono = nil
				for _, t in snap.tokens do
					if t.id == e.prazoId then
						dono = t
					end
				end
				local minha = dono and dono.ownerUserId == eu.UserId
				prazo.Text = string.format("%s%d s", if minha then "SUA VEZ • " else "", resto)
				prazo.TextSize = if resumo.Visible then 12 else 18
				prazo.TextColor3 = if resto <= 10 then T.cores.perigo else T.cores.alerta
			else
				local deslizar = layout.AbsoluteContentSize.X > ordem.AbsoluteSize.X
				local rodada = if snap and snap.combat.round then "Rodada "..snap.combat.round.." • " else ""
				prazo.Text = if snap and snap.combat.active and quantidade > 0 then rodada..tostring(quantidade).." na ordem"..(if deslizar then " • deslize para ver mais →" else "") else ""
				prazo.TextSize = 12
				prazo.TextColor3 = T.cores.secundario
			end
			task.wait(0.25)
		end
	end)
	return gui
end

return Hud
