-- Base V2, exclusivamente cliente. Nenhuma função cria ScreenGui ou envia remotos.
-- Props comuns: parent (obrigatório), nome?, tamanho?, posicao?, ancora?, ordem? (=0).
-- Retorno: Instance raiz; destruir a raiz encerra conexões/tweens associados.
-- painel/cartao: padding?; moldura e sombra vêm da arte (raiz.Arte); conteúdo em raiz.Conteudo.
-- arte: peca (nome em shared/UIArte), sangria?, cor?; retorna holder, ImageLabel.
-- titulo/texto: texto?, secundario?, ornamento? (titulo), italico? (texto).
-- botao: texto?, variante? principal/secundario/perigo/fantasma, icone? (nome em Tema.ICONES ou glifo cru),
--   imagem? (asset autorizado pelo chamador), desabilitado?, aoClicar?; atributo Desabilitado reativo.
--   sobreEscuro? (só fantasma): em repouso não há papel atrás, então o rótulo usa a tinta clara.
-- barra: rotulo?, valor? [0..1], numero?, destaque?; retorna raiz, atualizar(valor, numero?).
-- barraCompacta: barra de recurso (rotulo?, destaque? fixo, posicao, tamanho 38 px); retorna raiz,
--   atualizar(atual, maximo) que mostra "a / m" e esconde a barra sem máximo. Raiz acima da arte do painel pai.
-- lista/grade: horizontal?, espaco?, celula? (grade); filhos precisam de ordem explícita.
-- dialogoNpc: nomeNpc?, fala?, opcoes={{texto, aoClicar}}; usa painel inferior responsivo.
-- iconeBotao: icone?/imagem?, rotulo?, aoClicar?, desabilitado?.
-- aviso: parent=ScreenGui/GuiObject que ocupe a tela (ZIndexBehavior.Sibling), tipo?, titulo?, detalhe?,
--   icone?, duracao?, destaque?; retorna cancelar(). Fila única por parent, só no topo seguro.
-- aplicarEscala(parent, camera?) -> UIScale, desligar(): acompanha ViewportSize,
--   trocar CurrentCamera e destruição. Não aninhar escalas; toque físico >=44.
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local T = require(script.Parent.Tema)
local UIArte = require(game:GetService("ReplicatedStorage").Shared.UIArte)
local C = {}
local cor = T.cores
local function criar(classe, props, parent)
	assert(RunService:IsClient(), "UI V2 cria Instances somente no cliente")
	local obj = Instance.new(classe)
	for k, v in props do obj[k] = v end
	obj.Parent = parent
	return obj
end
local function comum(p, nome, tamanho)
	assert(p.parent, "parent obrigatório")
	return {
		Name = p.nome or nome, Size = p.tamanho or tamanho or UDim2.new(1, 0, 0, 0),
		Position = p.posicao or UDim2.new(), AnchorPoint = p.ancora or Vector2.zero,
		LayoutOrder = p.ordem or 0, BorderSizePixel = 0,
	}
end
local function canto(obj, raio)
	criar("UICorner", { CornerRadius = UDim.new(0, raio) }, obj)
end
local function contorno(obj, corBorda, espessura)
	return criar("UIStroke", { Color = corBorda, Thickness = espessura, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, obj)
end
local function animador(obj)
	local atual
	obj.Destroying:Connect(function() if atual then atual:Cancel() end end)
	return function(props)
		if atual then atual:Cancel() end
		atual = TweenService:Create(obj, TweenInfo.new(T.tween), props)
		atual:Play()
	end
end
-- Arte do kit (shared/UIArte) como ImageLabel 9-slice que ocupa o pai. `sangria` estende a imagem além
-- do pai (a arte tem margem para a sombra). O SliceScale acompanha o tamanho: bordas nunca se cruzam.
local function arte(nome, parent, props)
	local peca = UIArte.peca(nome)
	assert(peca, "peça de arte inexistente: " .. tostring(nome))
	local sangria = props and props.sangria or 0
	local img = criar("ImageLabel", { Name = "Arte", BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
		Image = peca.imagem, Position = UDim2.fromOffset(-sangria, -sangria), Size = UDim2.new(1, sangria * 2, 1, sangria * 2),
		ZIndex = parent:IsA("GuiObject") and parent.ZIndex or 1,
		ScaleType = if peca.corte then Enum.ScaleType.Slice else Enum.ScaleType.Stretch }, parent)
	if peca.corte then
		local x0, y0, x1, y1 = table.unpack(peca.corte)
		img.SliceCenter = Rect.new(x0, y0, x1, y1)
		local bordaX, bordaY = x0 + peca.largura - x1, y0 + peca.altura - y1
		local function escala()
			local tam = img.AbsoluteSize
			if tam.X <= 0 or tam.Y <= 0 then img.SliceScale = UIArte.ESCALA; return end
			img.SliceScale = math.min(UIArte.ESCALA, tam.X / bordaX, tam.Y / bordaY)
		end
		img:GetPropertyChangedSignal("AbsoluteSize"):Connect(escala)
		escala()
	end
	for k, v in props or {} do if k ~= "sangria" then img[k] = v end end
	return img
end
-- Público para telas que montam peças próprias (aro do retrato, espaço de equipamento, divisor).
function C.arte(p)
	assert(p.parent, "parent obrigatório")
	local holder = criar("Frame", comum(p, p.nome or "Arte", p.tamanho or UDim2.fromOffset(64, 64)), p.parent)
	holder.BackgroundTransparency = 1
	local img = arte(p.peca, holder, { sangria = p.sangria, ImageColor3 = p.cor or Color3.new(1, 1, 1) })
	img.ZIndex = p.zIndex or holder.ZIndex
	return holder, img
end
function C.painel(p)
	local props = comum(p, "Painel", UDim2.fromOffset(360, 240))
	-- Fundo e moldura vêm da arte (ui_kit.py): Frame transparente marcado para quem precisa saber que é
	-- um painel (Atalhos esconde os atalhos quando um painel grande abre).
	props.BackgroundColor3 = cor.painel
	props.BackgroundTransparency = 1
	props.ZIndex = p.zIndex or 2
	local raiz = criar("Frame", props, p.parent)
	raiz:SetAttribute("PainelUIV2", true)
	arte("painel", raiz, { sangria = 6, ZIndex = raiz.ZIndex })
	local conteudo = criar("Frame", { Name = "Conteudo", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = raiz.ZIndex + 1 }, raiz)
	-- A moldura ocupa ~15 px da borda: o conteúdo começa depois dela.
	local pad = if p.padding == 0 then 0 else math.max(p.padding or T.espacamentos.padrao, 14)
	criar("UIPadding", { PaddingTop = UDim.new(0, pad), PaddingBottom = UDim.new(0, pad),
		PaddingLeft = UDim.new(0, pad), PaddingRight = UDim.new(0, pad) }, conteudo)
	return raiz
end
function C.cartao(p) return C.painel(p) end
local function etiqueta(p, titulo)
	local props = comum(p, if titulo then "Titulo" else "Texto")
	props.Text = if titulo then string.upper(p.texto or "") else p.texto or ""
	if titulo then
		local maiusculas = { ["á"]="Á", ["à"]="À", ["â"]="Â", ["ã"]="Ã", ["é"]="É", ["ê"]="Ê", ["í"]="Í", ["ó"]="Ó", ["ô"]="Ô", ["õ"]="Õ", ["ú"]="Ú", ["ç"]="Ç" }
		local letras = {}; for _, codigo in utf8.codes(props.Text) do
			local letra = utf8.char(codigo); table.insert(letras, maiusculas[letra] or letra)
		end
		props.Text = table.concat(letras, "\u{200A}")
	end
	props.BackgroundTransparency = 1
	-- O título em si nunca recebe uma placa de fundo; a faixa é irmã e ocupa o painel.
	props.TextColor3 = if titulo then cor.titulo elseif p.secundario then cor.secundario else cor.texto
	props.FontFace = if titulo then T.fontes.titulo elseif p.subtitulo then T.fontes.subtitulo elseif p.italico then T.fontes.italico else T.fontes.corpo
	props.TextSize = if titulo then T.tamanhos.titulo elseif p.subtitulo then T.tamanhos.subtitulo else T.tamanhos.corpo
	props.TextWrapped = true
	props.TextXAlignment = Enum.TextXAlignment.Left
	props.TextYAlignment = Enum.TextYAlignment.Top
	props.AutomaticSize = Enum.AutomaticSize.Y
	props.ZIndex = 5
	local label = criar("TextLabel", props, p.parent)
	if titulo and p.ornamento then
		if (p.ordem or 0) == 1 then
		local faixa = criar("Frame", { Name = "FaixaCabecalho", BackgroundColor3 = cor.painel:Lerp(Color3.new(1, 1, 1), 0.06),
			BackgroundTransparency = T.transparencias.painel, BorderSizePixel = 0, Position = UDim2.fromOffset(-8, -4),
			Size = UDim2.new(1, 16, 1, 8), ZIndex = 4 }, label)
		criar("Frame", { Name = "LinhaOuro", BackgroundColor3 = cor.borda, BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), ZIndex = 5 }, faixa)
		criar("TextLabel", { Name = "Ornamento", Text = "—✦—", FontFace = T.FONTE_ICONE,
			TextSize = T.tamanhos.legenda, TextColor3 = cor.ouro, BackgroundColor3 = cor.cabecalho,
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(70, 18), ZIndex = 6 }, faixa)
		end
	end
	return label
end
function C.titulo(p) return etiqueta(p, true) end
function C.texto(p) return etiqueta(p, false) end
function C.lista(p)
	local props = comum(p, "Lista")
	props.BackgroundTransparency = 1
	props.AutomaticSize = Enum.AutomaticSize.Y
	local raiz = criar("Frame", props, p.parent)
	criar("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, p.espaco or T.espacamentos.pequeno),
		FillDirection = if p.horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical }, raiz)
	return raiz
end
function C.grade(p)
	local props = comum(p, "Grade")
	props.BackgroundTransparency = 1
	props.AutomaticSize = Enum.AutomaticSize.Y
	local raiz = criar("Frame", props, p.parent)
	criar("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellSize = p.celula or UDim2.fromOffset(100, 64),
		CellPadding = UDim2.fromOffset(p.espaco or 8, p.espaco or 8) }, raiz)
	return raiz
end
local function escalaAcumulada(obj)
	local escala = 1
	local pai = obj.Parent
	while pai do
		local ui = pai:FindFirstChildOfClass("UIScale")
		if ui then escala *= ui.Scale end
		pai = pai.Parent
	end
	return escala
end
local function ajustarTexto(obj)
	if not obj:IsA("TextLabel") and not obj:IsA("TextButton") and not obj:IsA("TextBox") then return end
	local base = obj:GetAttribute("TextoBaseUIV2") or obj.TextSize
	obj:SetAttribute("TextoBaseUIV2", base)
	obj.TextSize = T.tamanhoTexto(base, escalaAcumulada(obj))
end
local function ajustarToque(obj)
	local escala = escalaAcumulada(obj)
	local min = T.alturaToque(escala)
	local limite = obj:FindFirstChild("ToqueMinimo")
	if limite then limite.MinSize = Vector2.new(min, min) end
end
function C.botao(p)
	local variante = p.variante or "principal"
	assert(table.find({ "principal", "secundario", "perigo", "fantasma" }, variante), "variante inválida")
	local altura = if variante == "principal" then 52 else 48
	local larguraTexto = TextService:GetTextSize(p.texto or "", T.tamanhos.rotulo, Enum.Font.SourceSansSemibold, Vector2.new(10000, altura)).X
	local largura = math.max(180, math.ceil(larguraTexto) + 48 + (if p.icone or p.imagem then 38 else 0))
	local props = comum(p, "Botao", UDim2.fromOffset(largura, altura))
	local principal = variante == "principal"
	props.Text = ""
	props.AutoButtonColor = false
	props.BackgroundColor3 = if principal then cor.ouro else cor.painel
	props.BackgroundTransparency = 1 -- fundo e moldura vêm da arte
	props.ZIndex = 5
	local b = criar("TextButton", props, p.parent)
	b:SetAttribute("BotaoUIV2", true)
	criar("UISizeConstraint", { Name = "ToqueMinimo", MinSize = Vector2.new(44, 44) }, b)
	ajustarToque(b)
	local fundo = arte(if principal then "botao_principal" else "botao", b, { sangria = 3, ZIndex = 5 })
	-- Perigo: a mesma moldura puxada para o vinho; fantasma: só aparece sob o cursor.
	local tinta = if variante == "perigo" then Color3.fromRGB(255, 170, 160) else Color3.new(1, 1, 1)
	local temIcone = p.icone or p.imagem
	local label = criar("TextLabel", { Name = "Rotulo", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(if temIcone then 62 else 24, 0), Size = UDim2.new(1, if temIcone then -86 else -48, 1, 0),
		Text = p.texto or "", TextWrapped = true, TextColor3 = if principal then cor.textoEscuro else cor.texto,
		FontFace = T.fontes.rotulo, TextSize = T.tamanhos.rotulo, ZIndex = 6 }, b)
	if not p.tamanho then
		label:GetPropertyChangedSignal("Text"):Connect(function()
			local medida = TextService:GetTextSize(label.Text, label.TextSize, Enum.Font.SourceSansSemibold, Vector2.new(10000, altura))
			b.Size = UDim2.fromOffset(math.max(180, math.ceil(medida.X) + 48 + (if temIcone then 38 else 0)), altura)
		end)
	end
	local icone
	if temIcone then
		icone = criar(if p.imagem then "ImageLabel" else "TextLabel", {
			Name = "Icone", BackgroundTransparency = 1, Position = UDim2.new(0, 24, 0.5, -13), Size = UDim2.fromOffset(26, 26), ZIndex = 6,
		}, b)
		if p.imagem then icone.Image = p.imagem else
			icone.Text = T.icone(p.icone); icone.FontFace = T.FONTE_ICONE; icone.TextSize = T.tamanhos.subtitulo; icone.TextColor3 = if principal then cor.textoEscuro elseif variante == "perigo" then cor.texto else cor.ouro
		end
	end
	local hover, pressionado = false, false
	local animar = animador(fundo)
	local function estado()
		local desabilitado = b:GetAttribute("Desabilitado") == true
		b.Active = not desabilitado
		b.Selectable = not desabilitado
		label.TextTransparency = if desabilitado then T.transparencias.desabilitado else 0
		local ativo = not desabilitado and (hover or pressionado)
		if not principal then fundo.Image = UIArte.peca(if ativo then "botao_ativo" else "botao").imagem end
		if variante == "fantasma" and p.sobreEscuro then
			label.TextColor3 = if ativo then cor.texto else T.sobreEscuro.texto
			if icone and icone:IsA("TextLabel") then icone.TextColor3 = if ativo then cor.ouro else T.sobreEscuro.ouro end
		end
		-- A arte é a cor plena; repouso um pouco mais apagado, cursor acende e clique afunda.
		local luz = if pressionado and ativo then 0.78 elseif ativo then 1 else 0.9
		animar({ ImageColor3 = Color3.new(tinta.R * luz, tinta.G * luz, tinta.B * luz),
			ImageTransparency = if desabilitado then 0.45 elseif variante == "fantasma" and not ativo then 1 else 0 })
	end
	b:SetAttribute("Desabilitado", p.desabilitado == true)
	b:GetAttributeChangedSignal("Desabilitado"):Connect(estado)
	b.MouseEnter:Connect(function() hover = true; estado() end)
	b.MouseLeave:Connect(function() hover = false; pressionado = false; estado() end)
	b.SelectionGained:Connect(function() hover = true; estado() end)
	b.SelectionLost:Connect(function() hover = false; pressionado = false; estado() end)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pressionado = true; estado() end
	end)
	b.InputEnded:Connect(function() pressionado = false; estado() end)
	b.Activated:Connect(function() if b:GetAttribute("Desabilitado") ~= true and p.aoClicar then p.aoClicar() end end)
	b.AncestryChanged:Connect(function() ajustarToque(b) end)
	estado()
	return b
end
function C.iconeBotao(p)
	local cp = table.clone(p)
	cp.texto = ""; cp.icone = nil; cp.imagem = nil; cp.variante = "secundario"
	cp.tamanho = p.tamanho or UDim2.fromOffset(64, 64)
	local b = C.botao(cp)
	local icon = criar(if p.imagem then "ImageLabel" else "TextLabel", { Name = "Icone", BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.15, 0.05), Size = UDim2.fromScale(0.7, 0.55), ZIndex = 6 }, b)
	if p.imagem then icon.Image = p.imagem else
		icon.Text = T.icone(p.icone or "run"); icon.TextColor3 = cor.titulo; icon.FontFace = T.FONTE_ICONE; icon.TextSize = T.tamanhos.titulo
	end
	local label = b.Rotulo
	label.Text = p.rotulo or ""
	label.Position = UDim2.fromScale(0.05, 0.6); label.Size = UDim2.fromScale(0.9, 0.35)
	return b
end
function C.barra(p)
	local props = comum(p, "Barra", UDim2.new(1, 0, 0, 60))
	props.BackgroundTransparency = 1
	local raiz = criar("Frame", props, p.parent)
	local rotulo = C.texto({ parent = raiz, texto = p.rotulo or "", tamanho = UDim2.new(0.7, 0, 0, 20) })
	local numero = C.texto({ parent = raiz, nome = "Numero", tamanho = UDim2.new(0.3, 0, 0, 20), posicao = UDim2.new(0.7, 0, 0, 0) })
	rotulo.TextYAlignment = Enum.TextYAlignment.Center
	numero.TextYAlignment = Enum.TextYAlignment.Center
	numero.FontFace = T.fontes.numero; numero.TextSize = T.tamanhos.numero; numero.TextXAlignment = Enum.TextXAlignment.Right
	-- Trilho e preenchimento são arte; o preenchimento segue a própria BackgroundColor3 (quem já
	-- mudava a cor da barra continua mudando, agora pela tinta da imagem).
	local trilho = criar("Frame", { Name = "Trilho", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = cor.fio, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4 }, raiz)
	arte("barra_fundo", trilho, { ZIndex = 4 })
	local mascara = criar("Frame", { Name = "Mascara", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5 }, trilho)
	local preenchimento = criar("Frame", { Name = "Preenchimento", Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = p.destaque or cor.ouro, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5 }, mascara)
	local tinta = arte("barra_cheia", preenchimento, { ZIndex = 5, ImageColor3 = preenchimento.BackgroundColor3 })
	preenchimento:GetPropertyChangedSignal("BackgroundColor3"):Connect(function() tinta.ImageColor3 = preenchimento.BackgroundColor3 end)
	local animar = animador(preenchimento)
	local function atualizar(valor, textoNumero)
		if not raiz.Parent then return end
		valor = if valor == valor then math.clamp(valor, 0, 1) else 0
		numero.Text = textoNumero or string.format("%d%%", math.floor(valor * 100 + 0.5))
		animar({ Size = UDim2.fromScale(valor, 1) })
	end
	atualizar(p.valor or 0, p.numero)
	return raiz, atualizar
end
function C.barraCompacta(p)
	local raiz, atualizarBarra = C.barra(p)
	raiz.ZIndex = 5 -- o painel pai tem arte em ZIndex 2: sem isto a barra some atrás dela (Sibling)
	raiz.Size = p.tamanho or UDim2.new(1, 0, 0, 38)
	for _, filho in raiz:GetChildren() do
		if filho:IsA("TextLabel") then
			local numero = filho.Name == "Numero"
			filho.AutomaticSize = Enum.AutomaticSize.None
			filho.TextSize = T.tamanhos.legenda
			filho.TextTruncate = Enum.TextTruncate.AtEnd
			filho.Size = UDim2.new(if numero then 0.75 else 0.25, 0, 0, 20)
			if numero then filho.Position = UDim2.fromScale(0.25, 0) end
		end
	end
	raiz.Trilho.Position, raiz.Trilho.Size = UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 12)
	return raiz, function(atual: number?, maximo: number?)
		raiz.Visible = atual ~= nil and maximo ~= nil and maximo > 0
		if not raiz.Visible then return end
		local r = math.clamp(atual / maximo, 0, 1)
		raiz.Trilho.Mascara.Preenchimento.BackgroundColor3 = p.destaque
			or (if r > 0.5 then T.barras.cheia elseif r > 0.25 then T.barras.media else T.barras.baixa)
		atualizarBarra(r, string.format("%d / %d", atual, maximo))
	end
end
function C.dialogoNpc(p)
	local cp = table.clone(p)
	cp.nome = p.nome or "DialogoNpc"
	cp.tamanho = p.tamanho or UDim2.new(1, -32, 0, 0)
	cp.posicao = p.posicao or UDim2.new(0.5, 0, 1, -16)
	cp.ancora = p.ancora or Vector2.new(0.5, 1)
	local raiz = C.painel(cp)
	raiz.AutomaticSize = Enum.AutomaticSize.Y
	criar("UISizeConstraint", { MaxSize = Vector2.new(760, math.huge) }, raiz)
	local conteudo = raiz.Conteudo
	conteudo.Size = UDim2.new(1, 0, 0, 0); conteudo.AutomaticSize = Enum.AutomaticSize.Y
	criar("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, conteudo)
	C.titulo({ parent = conteudo, texto = p.nomeNpc or "", ordem = 1 })
	C.texto({ parent = conteudo, texto = p.fala or "", italico = true, ordem = 2 })
	for i, opcao in p.opcoes or {} do
		C.botao({ parent = conteudo, texto = opcao.texto, aoClicar = opcao.aoClicar, variante = "secundario", tamanho = UDim2.new(1, 0, 0, 48), ordem = i + 2 })
	end
	return raiz
end
function C.aplicarEscala(parent, camera)
	local ui = criar("UIScale", { Scale = 1 }, parent)
	local conexoes, viewport = {}, nil
	table.insert(conexoes, parent.DescendantAdded:Connect(function(obj) task.defer(function() if obj.Parent then ajustarTexto(obj) end end) end))
	local function atualizar()
		if camera then ui.Scale = T.escala(camera.ViewportSize.Y) end
		for _, obj in parent:GetDescendants() do
			if obj:GetAttribute("BotaoUIV2") then ajustarToque(obj) end
			ajustarTexto(obj)
		end
	end
	local function observar(cam)
		if viewport then viewport:Disconnect() end
		camera = cam
		if cam then viewport = cam:GetPropertyChangedSignal("ViewportSize"):Connect(atualizar) end
		atualizar()
	end
	local function desligar()
		if viewport then viewport:Disconnect() end
		for _, conexao in conexoes do conexao:Disconnect() end
	end
	if not camera then
		table.insert(conexoes, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() observar(workspace.CurrentCamera) end))
		camera = workspace.CurrentCamera
	end
	table.insert(conexoes, parent.Destroying:Connect(desligar))
	table.insert(conexoes, ui.Destroying:Connect(desligar))
	observar(camera)
	return ui, desligar
end

local montarAviso = require(script.Parent.Avisos)
C.aviso = montarAviso(C, criar, animador)
return C
