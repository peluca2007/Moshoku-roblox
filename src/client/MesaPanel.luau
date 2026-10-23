-- Interface da mesa. Intenções pela API de MesaState; animações só apresentam.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Condicoes = require(Shared:WaitForChild("Condicoes"))
local CondicaoRules = require(Shared:WaitForChild("CondicaoRules"))
local Catalogo = require(Shared:WaitForChild("Livro"):WaitForChild("Catalogo"))
local FichaDetalhe = require(script.Parent.FichaDetalhe)
local MesaPanel = {}

-- Estética Livro Noite (Estilo, docs/VISUAL.md). "gold" é o destaque roxo do
-- site (títulos, valores, pincel ativo); "primary" é o fundo do botão principal.
local Estilo = require(Shared:WaitForChild("Estilo"))
local COLORS = {
	background = Estilo.PAPEL,
	card = Estilo.PAPEL_2,
	button = Estilo.BOTAO,
	danger = Estilo.PERIGO_FUNDO,
	text = Estilo.TINTA,
	muted = Estilo.TINTA_SUAVE,
	border = Estilo.FIO_COR,
	gold = Estilo.DESTAQUE,
	primary = Estilo.DESTAQUE_FUNDO,
	wine = Estilo.PERIGO,
	publica = Estilo.TINTA,
	secreta = Estilo.ALERTA,
	sistema = Estilo.TINTA_SUAVE,
	erro = Estilo.TINTA,
}
local TEXT_FONT = Estilo.ROTULO
local TITLE_FONT = Estilo.GRITO
local NUMBER_FONT = Estilo.GRITO

local PRIMARY_BUTTONS = {
	["Rolar"] = true,
	["Enviar ficha ao servidor"] = true,
	["Importar na casa selecionada"] = true,
}
local DANGER_BUTTONS = {
	["Remover ficha selecionada…"] = true,
	["Limpar mesa"] = true,
	["Cobrir tudo com névoa"] = true,
	["Salvar mesmo assim"] = true,
	["Carregar"] = true,
	["Atualizar ficha selecionada"] = true,
	["Iniciar / reiniciar o combate"] = true,
	["Encerrar combate"] = true,
}
local COMMON_CONDITIONS = {
	caido = true, agarrado = true, atordoado = true,
	amedrontado = true, cego = true, envenenado = true,
}
local SUGGESTION_LIMIT, SEARCH_LIMIT = 6, 8

local function searchKey(text)
	local result = string.lower(text)
	for _, pair in {
		{ "Á", "a" }, { "À", "a" }, { "Â", "a" }, { "Ã", "a" },
		{ "á", "a" }, { "à", "a" }, { "â", "a" }, { "ã", "a" },
		{ "É", "e" }, { "Ê", "e" }, { "é", "e" }, { "ê", "e" },
		{ "Í", "i" }, { "í", "i" },
		{ "Ó", "o" }, { "Ô", "o" }, { "Õ", "o" },
		{ "ó", "o" }, { "ô", "o" }, { "õ", "o" },
		{ "Ú", "u" }, { "Ü", "u" }, { "ú", "u" }, { "ü", "u" },
		{ "Ç", "c" }, { "ç", "c" },
	} do
		result = string.gsub(result, pair[1], pair[2])
	end
	return result
end

local creationOrder = 0
local runningTweens = setmetatable({}, { __mode = "k" })
local buttonStyles = setmetatable({}, { __mode = "k" })

local function new(class, parent, properties)
	local object = Instance.new(class)
	if object:IsA("GuiObject") and properties.LayoutOrder == nil then
		creationOrder += 1
		object.LayoutOrder = creationOrder
	end
	for key, value in properties do object[key] = value end
	object.Parent = parent
	return object
end

local function animate(object, goals, duration)
	local previous = runningTweens[object]
	if previous then previous:Cancel() end
	local tween = TweenService:Create(object,
		TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goals)
	runningTweens[object] = tween
	tween:Play()
end

local function decorate(object, radius, transparency)
	new("UICorner", object, { CornerRadius = UDim.new(0, radius or 8) })
	return new("UIStroke", object, {
		Color = COLORS.border, Thickness = 1,
		Transparency = transparency or 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function stack(parent)
	return new("UIListLayout", parent, {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function label(parent, text, height)
	return new("TextLabel", parent, {
		Size = UDim2.new(1, 0, 0, height or 44), BackgroundTransparency = 1,
		Text = text, TextSize = 16, FontFace = TEXT_FONT,
		TextColor3 = COLORS.text, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function section(parent, title)
	local frame = new("Frame", parent, {
		Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.card, BorderSizePixel = 0,
	})
	decorate(frame, 8, 0.6)
	new("UIPadding", frame, {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
	})
	stack(frame)
	local heading = label(frame, title, 40)
	heading.FontFace, heading.TextSize, heading.TextColor3 = TITLE_FONT, 21, COLORS.gold
	return frame
end

local function row(parent, count)
	local frame = new("Frame", parent, {
		Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1,
	})
	new("UIListLayout", frame, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return frame, UDim2.new(1 / count, -4, 1, 0)
end

local function renderButton(object)
	local style = buttonStyles[object]
	if not style then return end
	local amount = if style.pressed then 0.18 elseif style.hovered then 0.1 else 0
	-- Ouro com texto escuro escurece um pouco; os demais clareiam um pouco.
	local target = if style.primary then COLORS.card else COLORS.gold
	animate(object, {
		BackgroundColor3 = style.background:Lerp(target, amount),
		TextColor3 = style.foreground,
	}, 0.1)
	animate(style.stroke, {
		Color = if style.hovered or style.pressed then COLORS.gold else style.border,
		Transparency = if style.hovered or style.pressed then 0.05 else 0.45,
	}, 0.1)
end

local function setButtonStyle(object, background, foreground, border, primary)
	local style = buttonStyles[object]
	if not style then return end
	style.background, style.foreground = background, foreground
	style.border, style.primary = border or COLORS.border, primary == true
	renderButton(object)
end

local function button(parent, title, callback, size, kind)
	local primary = kind == "primary" or (kind == nil and PRIMARY_BUTTONS[title] == true)
	local danger = kind == "danger" or (kind == nil and DANGER_BUTTONS[title] == true)
	local background = if primary then COLORS.primary elseif danger then COLORS.danger else COLORS.button
	local foreground = COLORS.text
	local object = new("TextButton", parent, {
		Size = size or UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = background, BorderSizePixel = 0,
		Text = title, TextColor3 = foreground, FontFace = TEXT_FONT,
		TextSize = 16, TextWrapped = true, AutoButtonColor = false,
	})
	buttonStyles[object] = {
		background = background, foreground = foreground, primary = primary,
		border = COLORS.border, stroke = decorate(object, 6, 0.45),
		hovered = false, pressed = false,
	}
	object.Activated:Connect(callback)
	object.MouseEnter:Connect(function()
		buttonStyles[object].hovered = true
		renderButton(object)
	end)
	object.MouseLeave:Connect(function()
		buttonStyles[object].hovered, buttonStyles[object].pressed = false, false
		renderButton(object)
	end)
	object.InputBegan:Connect(function(event)
		if event.UserInputType == Enum.UserInputType.MouseButton1
			or event.UserInputType == Enum.UserInputType.Touch then
			buttonStyles[object].pressed = true
			renderButton(object)
		end
	end)
	object.InputEnded:Connect(function(event)
		if event.UserInputType == Enum.UserInputType.MouseButton1
			or event.UserInputType == Enum.UserInputType.Touch then
			buttonStyles[object].pressed = false
			renderButton(object)
		end
	end)
	return object
end

local function input(parent, title, value)
	local caption = label(parent, title, 24)
	caption.TextColor3 = COLORS.muted
	local box = new("TextBox", parent, {
		Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0, Text = value or "", PlaceholderText = title,
		ClearTextOnFocus = false, FontFace = TEXT_FONT, TextSize = 16,
		TextColor3 = COLORS.text, PlaceholderColor3 = COLORS.muted,
	})
	decorate(box, 6, 0.65)
	return box, caption
end

local function listFrame(parent)
	local frame = new("Frame", parent, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	stack(frame)
	return frame
end

function MesaPanel.start(state)
	local gui = new("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"), {
		Name = "MesaPanel", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local root = new("Frame", gui, {
		Name = "PanelRoot", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.98, 0.03), Size = UDim2.fromOffset(400, 600),
		BackgroundColor3 = COLORS.background, BorderSizePixel = 0,
		Active = true, ClipsDescendants = true,
	})
	decorate(root, 10, 0.15)
	local titleRow = new("Frame", root, {
		Size = UDim2.new(1, -16, 0, 46), Position = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
	})
	local collapse = button(titleRow, "Recolher", function() end)
	collapse.Size, collapse.Position = UDim2.new(0, 88, 1, 0), UDim2.new(1, -88, 0, 0)
	local header = label(titleRow, "Mesa • conectando…", 46)
	header.Size, header.TextSize = UDim2.new(1, -96, 1, 0), 15
	local tabs = new("Frame", root, {
		Name = "Tabs", Position = UDim2.fromOffset(8, 56),
		Size = UDim2.new(1, -16, 0, 46), BackgroundTransparency = 1,
	})
	new("UIListLayout", tabs, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local notice = label(root, "Selecione uma ficha ou casa no tabuleiro.", 44)
	notice.Name, notice.Position = "PanelNotice", UDim2.fromOffset(12, 108)
	notice.Size, notice.TextSize = UDim2.new(1, -24, 0, 44), 14
	notice.TextColor3 = COLORS.muted
	local content = new("Frame", root, {
		Name = "TabContent", Position = UDim2.fromOffset(8, 158),
		Size = UDim2.new(1, -16, 1, -166),
		BackgroundTransparency = 1, ClipsDescendants = true,
	})
	local pages, tabButtons = {}, {}
	local activeTab, collapsed = "Mesa", false
	local tabNames = { "Mesa", "Ficha", "Mestre", "Campanha" }
	local panelWidth, panelHeight = 400, 600
	local updateMesaLayout

	local function permittedTab(name)
		return name == "Mesa" or name == "Ficha" or state.isMaster()
	end
	local function showTab(name, transition)
		if not permittedTab(name) then return end
		activeTab = name
		for _, candidate in tabNames do
			local page = pages[candidate]
			if page then
				page.Visible = candidate == name
				if candidate == name then
					local previous = runningTweens[page]
					if previous then previous:Cancel() end
					page.Position = UDim2.fromOffset(if transition then 8 else 0, 0)
					if transition then animate(page, { Position = UDim2.fromOffset(0, 0) }, 0.14) end
				end
			end
			local object = tabButtons[candidate]
			if object then
				local active = candidate == name
				setButtonStyle(object,
					if active then COLORS.gold else COLORS.button,
					if active then COLORS.card else COLORS.text,
					nil, active)
			end
		end
	end
	for _, name in tabNames do
		local page
		if name == "Mesa" or name == "Ficha" then
			page = new("Frame", content, {
				Name = "Page_" .. name, Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				ClipsDescendants = true, Visible = true,
			})
		else
			page = new("ScrollingFrame", content, {
				Name = "Page_" .. name, Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				BorderSizePixel = 0, ScrollBarThickness = 5,
				ScrollBarImageColor3 = COLORS.gold,
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Active = true, Visible = false,
			})
			new("UIPadding", page, {
				PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2),
			})
			stack(page)
		end
		pages[name] = page
		local object = button(tabs, name, function()
			if permittedTab(name) then showTab(name, true) end
		end, UDim2.new(0.25, -4, 1, 0))
		object.Name, tabButtons[name] = "Tab_" .. name, object
	end
	local function syncTabs()
		local count = if state.isMaster() then 4 else 2
		for _, name in tabNames do
			tabButtons[name].Visible = permittedTab(name)
			tabButtons[name].Size = UDim2.new(1 / count, -4, 1, 0)
		end
		if not permittedTab(activeTab) then activeTab = "Mesa" end
		showTab(activeTab, false)
	end
	local function resize(transition)
		local camera = workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X else 1000
		local height = if camera then camera.ViewportSize.Y else 740
		local narrow = width < 700
		panelWidth = math.max(1, math.min(width - 16, if narrow then width - 16 else 480))
		local position
		if narrow then
			root.AnchorPoint = Vector2.new(0.5, 1)
			-- O registro precisa continuar legível com os controles acima dele.
			panelHeight = if collapsed then 54 else math.max(54, math.min(height - 16, height * 0.85))
			position = UDim2.new(0.5, 0, 1, -8)
		else
			root.AnchorPoint = Vector2.new(1, 0)
			if collapsed then panelWidth = math.min(panelWidth, 280) end
			panelHeight = if collapsed then 54 else math.max(54, height * 0.92)
			position = UDim2.new(1, -12, 0, 12)
		end
		local goals = { Size = UDim2.fromOffset(panelWidth, panelHeight), Position = position }
		if transition then
			animate(root, goals, 0.2)
		else
			local previous = runningTweens[root]
			if previous then previous:Cancel() end
			root.Size, root.Position = goals.Size, goals.Position
		end
		tabs.Visible, notice.Visible, content.Visible = not collapsed, not collapsed, not collapsed
		collapse.Text = if collapsed then "Abrir" else "Recolher"
		if updateMesaLayout and not collapsed then updateMesaLayout() end
	end
	collapse.Activated:Connect(function() collapsed = not collapsed; resize(true) end)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() resize(false) end)
	end
	resize(false)
	syncTabs()

	local function explain(text) notice.Text = text end
	local function loading()
		local snapshot = state.snapshot()
		return snapshot and snapshot.campaign and snapshot.campaign.status == "carregando"
	end
	local function canMutate()
		if loading() then explain("Aguarde o carregamento da campanha terminar."); return false end
		return true
	end
	local function canChangeTable() return state.isMaster() and canMutate() end

	-- Mesa é fixa. Só os controles rolam em telas de pouca altura.
	local controls = new("ScrollingFrame", pages.Mesa, {
		Name = "MesaControls", Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 232), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0, ScrollBarImageColor3 = COLORS.gold,
		ScrollingEnabled = false, Active = true,
	})
	local cameraButton = button(controls, "Visão da mesa (M)", function()
		state.setTableView(not state.tableView())
	end)
	cameraButton.Position, cameraButton.Size = UDim2.fromOffset(0, 0), UDim2.new(1, -4, 0, 46)
	cameraButton.Text = if state.tableView() then "Voltar ao avatar (M)" else "Visão da mesa (M)"
	state.onTableView(function(enabled)
		cameraButton.Text = if enabled then "Voltar ao avatar (M)" else "Visão da mesa (M)"
	end)

	local dice = new("Frame", controls, {
		Name = "DiceSection", Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, -4, 0, 180), BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
	})
	decorate(dice, 8, 0.6)
	local diceHeading = label(dice, "Dados", 24)
	diceHeading.Position, diceHeading.Size = UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 24)
	diceHeading.FontFace, diceHeading.TextSize, diceHeading.TextColor3 = TITLE_FONT, 21, COLORS.gold

	local quickDice = new("ScrollingFrame", dice, {
		Name = "DiceChoices", Position = UDim2.fromOffset(8, 32),
		Size = UDim2.new(1, -16, 0, 44), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0, Active = true,
	})
	new("UIListLayout", quickDice, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local formulaLine = new("Frame", dice, {
		Name = "FormulaRow", Position = UDim2.fromOffset(8, 128),
		Size = UDim2.new(1, -16, 0, 44), BackgroundTransparency = 1,
	})
	local formula = new("TextBox", formulaLine, {
		Name = "DiceFormula", Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0.72, -4, 1, 0),
		BackgroundColor3 = COLORS.background, BorderSizePixel = 0,
		Text = "1d20", PlaceholderText = "Fórmula (ex.: 1d20+4)",
		ClearTextOnFocus = false, FontFace = TEXT_FONT, TextSize = 16,
		TextColor3 = COLORS.text, PlaceholderColor3 = COLORS.muted,
	})
	decorate(formula, 6, 0.65)
	local quickButtons = {}
	for _, sides in { 4, 6, 8, 10, 12, 20, 100 } do
		local object = button(quickDice, "d" .. sides, function()
			formula.Text = "1d" .. sides
		end, UDim2.fromOffset(44, 44))
		object.TextSize = 14
		table.insert(quickButtons, object)
	end

	local optionLine, optionSize = row(dice, 2)
	optionLine.Name, optionLine.Position = "DiceOptions", UDim2.fromOffset(8, 80)
	optionLine.Size = UDim2.new(1, -16, 0, 44)
	local modes = { "normal", "vantagem", "desvantagem", "vantagemAbsoluta", "desvantagemAbsoluta" }
	local modeLabels = { "Normal", "Vantagem", "Desvantagem", "Vantagem absoluta", "Desvantagem absoluta" }
	local modeIndex, secret = 1, false
	local modeButton
	modeButton = button(optionLine, "Modo: Normal", function()
		modeIndex = modeIndex % #modes + 1
		modeButton.Text = "Modo: " .. modeLabels[modeIndex]
	end, optionSize)
	modeButton.TextSize = 14
	local secretButton
	secretButton = button(optionLine, "Rolagem pública", function()
		secret = not secret
		secretButton.Text = if secret then "Secreta: só você e o mestre" else "Rolagem pública"
	end, optionSize)
	secretButton.TextSize = 14
	local rollButton = button(formulaLine, "Rolar", function()
		state.send("roll", {
			formula = formula.Text, mode = modes[modeIndex],
			visibility = if secret then "mestre" else "publica",
		})
	end, UDim2.new(0.28, 0, 1, 0))
	rollButton.Position = UDim2.fromScale(0.72, 0)

	local history = new("Frame", pages.Mesa, {
		Name = "HistorySection", Position = UDim2.fromOffset(0, 238),
		Size = UDim2.new(1, -4, 1, -238),
		BackgroundColor3 = COLORS.card, BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	decorate(history, 8, 0.6)
	local historyHeading = label(history, "Registro da mesa", 28)
	historyHeading.Position, historyHeading.Size = UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 28)
	historyHeading.FontFace, historyHeading.TextSize, historyHeading.TextColor3 = TITLE_FONT, 21, COLORS.gold

	-- O cartão não tenta parear roll com log por ordem de chegada.
	local rollCard = new("Frame", history, {
		Name = "LastRoll", Position = UDim2.fromOffset(8, 36),
		Size = UDim2.new(1, -16, 0, 72),
		BackgroundColor3 = COLORS.background, BorderSizePixel = 0,
		ClipsDescendants = true, Visible = false,
	})
	local rollStroke = decorate(rollCard, 8, 0.2)
	local rollTitle = label(rollCard, "", 20)
	rollTitle.Name, rollTitle.Position = "LastRollTitle", UDim2.fromOffset(8, 2)
	rollTitle.Size, rollTitle.TextSize = UDim2.new(1, -16, 0, 20), 14
	rollTitle.TextWrapped, rollTitle.TextTruncate = false, Enum.TextTruncate.AtEnd
	rollTitle.TextColor3 = COLORS.muted
	local rollTotal = label(rollCard, "", 30)
	rollTotal.Name, rollTotal.Position = "LastRollTotal", UDim2.fromOffset(8, 22)
	rollTotal.Size = UDim2.new(1, -16, 0, 30)
	rollTotal.FontFace, rollTotal.TextSize = NUMBER_FONT, 24
	local rollText = label(rollCard, "", 18)
	rollText.Name, rollText.Position = "LastRollText", UDim2.fromOffset(8, 52)
	rollText.Size, rollText.TextSize = UDim2.new(1, -16, 0, 18), 13
	rollText.TextWrapped, rollText.TextTruncate = false, Enum.TextTruncate.AtEnd

	local log = new("ScrollingFrame", history, {
		Name = "MesaLog", Position = UDim2.fromOffset(8, 36),
		Size = UDim2.new(1, -16, 1, -44),
		BackgroundColor3 = COLORS.background, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = COLORS.gold,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	decorate(log, 6, 0.65)
	local function sizeLog()
		local top = if rollCard.Visible then 114 else 36
		log.Position, log.Size = UDim2.fromOffset(8, top), UDim2.new(1, -16, 1, -(top + 8))
	end
	updateMesaLayout = function()
		local pageHeight = math.max(0, panelHeight - 166)
		local controlsHeight = math.min(232, math.max(46, pageHeight - 126))
		controls.Size = UDim2.new(1, 0, 0, controlsHeight)
		controls.ScrollingEnabled = controlsHeight < 232
		controls.ScrollBarThickness = if controlsHeight < 232 then 5 else 0
		if controlsHeight == 232 then controls.CanvasPosition = Vector2.new(0, 0) end
		local top = controlsHeight + 6
		history.Position, history.Size = UDim2.fromOffset(0, top), UDim2.new(1, -4, 1, -top)
		local available = math.max(0, panelWidth - 36)
		local width = math.max(44, (available - 24) / 7)
		for _, object in quickButtons do object.Size = UDim2.fromOffset(width, 44) end
		sizeLog()
	end
	updateMesaLayout()

	state.onRoll(function(data)
		if type(data) ~= "table" or type(data.total) ~= "number"
			or data.total ~= data.total or math.abs(data.total) == math.huge then return end
		local failure, critical = data.critical == "falha", data.critical == "sucesso"
		rollCard.Visible = true
		rollCard.BackgroundColor3 = if failure then COLORS.danger else COLORS.background
		rollStroke.Color = if failure then COLORS.wine else COLORS.gold
		rollTitle.TextColor3 = if failure then COLORS.text else COLORS.muted
		rollTitle.Text = tostring(data.by or "Rolagem")
			.. (if data.label then " • " .. tostring(data.label) else "")
			.. (if data.secret then " • secreta" else " • pública")
		rollTotal.TextColor3 = if critical then COLORS.gold else COLORS.text
		rollTotal.Text = tostring(data.total)
			.. (if critical then " • Crítico" elseif failure then " • Falha" else "")
		rollText.Text = if type(data.text) == "string" then data.text else ""
		sizeLog()
		rollTotal.TextTransparency = 1
		animate(rollTotal, { TextTransparency = 0 }, 0.18)
	end)

	local logLayout = stack(log)
	local entries, serial = {}, 0
	local function scrollLog()
		task.defer(function()
			if log.Parent then
				log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteSize.Y))
			end
		end)
	end
	logLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(scrollLog)
	log:GetPropertyChangedSignal("AbsoluteSize"):Connect(scrollLog)
	state.onLog(function(entry)
		serial += 1
		local item = label(log, entry.text, 24)
		item.Size, item.AutomaticSize = UDim2.new(1, -12, 0, 24), Enum.AutomaticSize.Y
		item.TextSize, item.TextColor3, item.LayoutOrder = 14, COLORS[entry.tone] or COLORS.text, serial
		if entry.tone == "erro" then
			item.BackgroundTransparency, item.BackgroundColor3 = 0, COLORS.danger
			decorate(item, 4, 0.5).Color = COLORS.wine
		end
		item.TextTransparency = 1
		animate(item, { TextTransparency = 0 }, 0.18)
		table.insert(entries, item)
		if #entries > 50 then table.remove(entries, 1):Destroy() end
		scrollLog()
	end)

	local fichaControls = new("ScrollingFrame", pages.Ficha, {
		Name = "FichaControls", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 5,
		ScrollBarImageColor3 = COLORS.gold, Active = true,
	})
	new("UIPadding", fichaControls, { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
	stack(fichaControls)
	local detailHost = new("Frame", pages.Ficha, {
		Name = "FichaCompleta", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Visible = false,
	})
	local detailOpen, detailRenderer = false, nil
	local function closeDetail()
		detailOpen = false
		detailHost.Visible, fichaControls.Visible = false, true
		if detailRenderer then detailRenderer.destruir(); detailRenderer = nil end
	end
	button(detailHost, "Voltar aos controles", closeDetail).Size = UDim2.new(1, 0, 0, 44)
	local detailBody = new("Frame", detailHost, {
		Name = "FichaCompletaConteudo", Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1,
	})
	local detailStatus = label(detailBody, "Carregando ficha…", 60)
	detailStatus.Name = "FichaDetalheStatus"
	local function refreshDetail()
		if not detailOpen then return end
		local token = state.findToken(state.selectedToken())
		if not token or not token.ficha2Versao then closeDetail(); return end
		local ficha = state.fichaDetalhe(token.id)
		detailStatus.Visible = ficha == nil
		if not ficha then
			if detailRenderer then detailRenderer.destruir(); detailRenderer = nil end
			return
		end
		if detailRenderer then detailRenderer.atualizar(ficha)
		else detailRenderer = FichaDetalhe.montar(detailBody, ficha, Catalogo) end
	end
	local selectedSection = section(fichaControls, "Ficha selecionada")
	local selectedInfo = label(selectedSection, "Nenhuma ficha selecionada.", 84)
	local selectedSheet = label(selectedSection, "", 24)
	selectedSheet.Name, selectedSheet.AutomaticSize = "SelectedSheet", Enum.AutomaticSize.Y
	selectedSheet.TextSize, selectedSheet.Visible = 14, false
	local openDetail = button(selectedSection, "Abrir ficha completa", function()
		detailOpen = true
		detailHost.Visible, fichaControls.Visible = true, false
		refreshDetail()
	end)
	openDetail.Name, openDetail.Visible = "AbrirFichaCompleta", false
	local adjustRows = {}
	for _, stat in { { "pv", "PV" }, { "mana", "Mana" } } do
		local line, size = row(selectedSection, 4)
		adjustRows[stat[1]] = line
		for _, delta in { -5, -1, 1, 5 } do
			button(line, stat[2] .. " " .. (if delta > 0 then "+" else "") .. delta, function()
				local token = state.findToken(state.selectedToken())
				if token and state.canControl(token) and token[stat[1]] ~= nil and canMutate() then
					state.send("adjust", { id = token.id, field = stat[1], delta = delta })
				end
			end, size)
		end
	end
	local myTurn = button(selectedSection, "Encerrar meu turno", function()
		local snapshot = state.snapshot()
		local id = snapshot and snapshot.combat.turnId
		local token = state.findToken(id)
		if token and token.ownerUserId == state.localUserId() and canMutate() then
			state.send("nextTurn", { expectedId = id, expectedTurn = snapshot.combat.turn })
		end
	end)

	local conditionSection = section(selectedSection, "Condições")
	conditionSection.Name, conditionSection.Visible = "ConditionsSection", false
	local activeConditions, conditionRows = listFrame(conditionSection), {}
	local conditionSearch = input(conditionSection, "Buscar condição", "")
	conditionSearch.Name = "ConditionSearch"
	local conditionHint = label(conditionSection, "", 24)
	conditionHint.Name, conditionHint.AutomaticSize = "ConditionSearchHint", Enum.AutomaticSize.Y
	conditionHint.TextSize, conditionHint.TextColor3 = 14, COLORS.muted
	local conditionChoices = listFrame(conditionSection)
	local selectedCondition = nil
	local conditionDetails = label(conditionSection, "Escolha uma condição do livro.", 24)
	conditionDetails.Name, conditionDetails.AutomaticSize = "ConditionDetails", Enum.AutomaticSize.Y
	conditionDetails.TextSize = 14
	local conditionNote = input(conditionSection, "Nota da condição (opcional)", "")
	conditionNote.Name = "ConditionNote"
	local conditionChoiceRows = {}
	local function controlledSelection()
		local token = state.findToken(state.selectedToken())
		if not token or not state.canControl(token) or not canMutate() then return nil end
		return token
	end
	for _, entry in Condicoes.LISTA do
		local choice
		choice = button(conditionChoices, entry.nome, function()
			if not choice.Visible or not controlledSelection() then return end
			selectedCondition = entry.id
			conditionDetails.Text = entry.nome .. "\n" .. entry.efeito
				.. "\nDuração: " .. (entry.duracao or "Não especificada; consulte a fonte.")
		end)
		choice.Name = "ConditionChoice_" .. entry.id
		table.insert(conditionChoiceRows, {
			object = choice, entry = entry,
			searchName = searchKey(entry.nome), searchId = searchKey(entry.id),
		})
	end
	local function filterConditions()
		local query = searchKey(string.match(conditionSearch.Text, "^%s*(.-)%s*$"))
		local shown, matches = 0, 0
		local limit = if query == "" then SUGGESTION_LIMIT else SEARCH_LIMIT
		for _, record in conditionChoiceRows do
			local matchesQuery
			if query == "" then
				matchesQuery = COMMON_CONDITIONS[record.entry.id] == true
			else
				matchesQuery = string.find(record.searchName, query, 1, true) ~= nil
					or string.find(record.searchId, query, 1, true) ~= nil
			end
			if matchesQuery then matches += 1 end
			local visible = matchesQuery and shown < limit
			record.object.Visible = visible
			if visible then shown += 1 end
		end
		if query == "" then
			conditionHint.Text = "Sugestões de combate. Digite para buscar qualquer condição do livro."
		elseif matches == 0 then
			conditionHint.Text = "Nenhuma condição encontrada. Tente outro nome."
		elseif matches > limit then
			conditionHint.Text = string.format("%d resultados; mostrando %d. Refine a busca.", matches, shown)
		else
			conditionHint.Text = string.format("%d resultado(s).", matches)
		end
	end
	conditionSearch:GetPropertyChangedSignal("Text"):Connect(filterConditions)
	filterConditions()
	button(conditionSection, "Adicionar condição", function()
		local token = controlledSelection()
		if not token then return end
		if not selectedCondition then explain("Escolha uma condição do livro."); return end
		local payload = { id = token.id, condition = selectedCondition }
		if conditionNote.Text ~= "" then payload.note = conditionNote.Text end
		state.send("conditionAdd", payload)
	end).Name = "ConditionAdd"

	local function refreshConditions(token)
		local allowed = token ~= nil and state.canControl(token)
		conditionSection.Visible = allowed
		for _, object in conditionRows do object:Destroy() end
		conditionRows = {}
		if not allowed then
			conditionNote.Text, selectedCondition = "", nil
			conditionDetails.Text = "Escolha uma condição do livro."
			return
		end
		local conditions = token.conditions or {}
		local labels = CondicaoRules.labels(conditions, Condicoes)
		if #conditions == 0 then table.insert(conditionRows, label(activeConditions, "Nenhuma condição.", 24)) end
		for index, item in conditions do
			local entry = Condicoes.POR_ID[item.id]
			if not entry then continue end
			local card = listFrame(activeConditions)
			table.insert(conditionRows, card)
			local text = labels[index] or entry.nome
			if item.note ~= nil and item.note ~= "" then text ..= "\nNota: " .. item.note end
			local description = label(card, text, 24)
			description.AutomaticSize, description.Name = Enum.AutomaticSize.Y, "ConditionLabel_" .. item.id
			local function send(command, stacks)
				local current = controlledSelection()
				if not current or current.id ~= token.id then return end
				local present = false
				for _, candidate in (current.conditions or {}) do
					if candidate.id == item.id then present = true; break end
				end
				if not present then return end
				local payload = { id = current.id, condition = item.id }
				if stacks then payload.stacks = stacks end
				state.send(command, payload)
			end
			button(card, "Remover " .. entry.nome, function()
				send("conditionRemove", nil)
			end, nil, "danger").Name = "ConditionRemove_" .. item.id
			if entry.acumulavel then
				local line, size = row(card, 2)
				button(line, "− acúmulo", function() send("conditionRemove", 1) end, size).Name = "ConditionMinus_" .. item.id
				button(line, "+ acúmulo", function() send("conditionAdd", 1) end, size).Name = "ConditionPlus_" .. item.id
			end
		end
	end

	local campaignSection = section(pages.Campanha, "Campanha")
	campaignSection.Visible = false
	local selectedSlot, observedSlot = 1, nil
	local pendingAction, pendingSlot, pendingUntil = nil, nil, 0
	local CONFIRM_SECONDS = 5
	local slotButton, loadButton, clearButton
	local campaignInfo = label(campaignSection, "livre • nenhum espaço atual", 24)
	campaignInfo.AutomaticSize, campaignInfo.TextSize = Enum.AutomaticSize.Y, 14
	local function validSlot(slot)
		return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= 5
	end
	local function campaignBusy()
		local snapshot = state.snapshot()
		local campaign = snapshot and snapshot.campaign
		return campaign and (campaign.status == "salvando" or campaign.status == "carregando")
	end
	local function resetConfirmation()
		pendingAction, pendingSlot, pendingUntil = nil, nil, 0
		if loadButton then loadButton.Text = "Carregar" end
		if clearButton then clearButton.Text = "Limpar mesa" end
	end
	local function canRequestCampaign()
		if not state.isMaster() then resetConfirmation(); return false end
		if campaignBusy() then
			resetConfirmation()
			explain("Aguarde a operação da campanha terminar.")
			return false
		end
		return true
	end
	local function confirmationMatches(action, slot)
		return pendingAction == action and pendingSlot == slot and os.clock() < pendingUntil
	end
	local function armConfirmation(action, slot)
		resetConfirmation()
		pendingAction, pendingSlot, pendingUntil = action, slot, os.clock() + CONFIRM_SECONDS
	end
	slotButton = button(campaignSection, "Espaço: 1 / 5", function()
		if not state.isMaster() then return end
		selectedSlot = selectedSlot % 5 + 1
		slotButton.Text = "Espaço: " .. selectedSlot .. " / 5"
		resetConfirmation()
	end)
	button(campaignSection, "Salvar", function()
		if not canRequestCampaign() then return end
		resetConfirmation()
		state.send("campaignSave", { slot = selectedSlot })
		explain("Salvamento solicitado no espaço " .. selectedSlot .. ". Confira o estado da campanha.")
	end)
	loadButton = button(campaignSection, "Carregar", function()
		if not canRequestCampaign() then return end
		if not confirmationMatches("load", selectedSlot) then
			armConfirmation("load", selectedSlot)
			loadButton.Text = "Confirmar carregar espaço " .. selectedSlot
			explain("Carregar substitui a mesa atual. Clique novamente em até 5 segundos para confirmar.")
			return
		end
		local slot = selectedSlot
		resetConfirmation()
		state.send("campaignLoad", { slot = slot })
	end)
	clearButton = button(campaignSection, "Limpar mesa", function()
		if not canRequestCampaign() then return end
		if not confirmationMatches("clear", nil) then
			armConfirmation("clear", nil)
			clearButton.Text = "Confirmar limpar mesa"
			explain("Limpar remove as fichas e encerra o combate. Clique novamente em até 5 segundos.")
			return
		end
		resetConfirmation()
		state.send("tableClear")
	end)
	button(campaignSection, "Cancelar confirmação", resetConfirmation)
	local forceButton = button(campaignSection, "Salvar mesmo assim", function()
		if not canRequestCampaign() then return end
		local snapshot = state.snapshot()
		local campaign = snapshot and snapshot.campaign
		if not campaign or campaign.status ~= "conflito" or not validSlot(campaign.slot) then
			explain("Não há um espaço em conflito para sobrescrever.")
			return
		end
		resetConfirmation()
		state.send("campaignSave", { slot = campaign.slot, force = true })
	end)
	forceButton.Visible = false
	local function refreshCampaign(snapshot)
		campaignSection.Visible = state.isMaster()
		if not state.isMaster() then forceButton.Visible = false; resetConfirmation(); return end
		local campaign = snapshot.campaign or { status = "livre", dirty = false }
		if campaign.slot ~= observedSlot then
			observedSlot = campaign.slot
			if validSlot(campaign.slot) then selectedSlot = campaign.slot end
			slotButton.Text = "Espaço: " .. selectedSlot .. " / 5"
			resetConfirmation()
		end
		if campaignBusy() or (pendingAction and os.clock() >= pendingUntil) then resetConfirmation() end
		local parts = {
			campaign.status or "livre",
			if validSlot(campaign.slot) then "espaço atual " .. campaign.slot else "nenhum espaço atual",
		}
		if type(campaign.revision) == "number" then table.insert(parts, "revisão " .. campaign.revision) end
		if type(campaign.savedAt) == "number" and campaign.savedAt == campaign.savedAt
			and campaign.savedAt >= 0 and campaign.savedAt < math.huge then
			local ok, time = pcall(os.date, "%H:%M", campaign.savedAt)
			if ok and type(time) == "string" then table.insert(parts, "salvo às " .. time) end
		end
		if campaign.dirty then table.insert(parts, "alterações não salvas") end
		campaignInfo.Text = table.concat(parts, " • ")
		campaignInfo.TextColor3 = if campaign.status == "conflito" or campaign.status == "indisponivel"
			then COLORS.text else COLORS.muted
		forceButton.Visible = campaign.status == "conflito"
	end

	local master = section(pages.Mestre, "Ferramentas do mestre")
	master.Visible = false
	local formMode, boundId = "create", nil
	local dirty, filling = {}, false
	local fields, captions = {}, {}
	local values = { kind = "npc", ownerUserId = 0, hidden = false, showStats = false }
	local formTitle = label(master, "Nova ficha", 32)
	local choices, choiceSize = row(master, 2)
	local hydrate
	button(choices, "Nova ficha", function() if state.isMaster() then hydrate(nil) end end, choiceSize)
	button(choices, "Editar seleção", function()
		if not state.isMaster() then return end
		local token = state.findToken(state.selectedToken())
		if token then hydrate(token) else explain("Selecione uma ficha para editar.") end
	end, choiceSize)
	for _, field in {
		{ "name", "Nome" }, { "pvMax", "PV máximo" }, { "manaMax", "Mana máxima" },
		{ "pv", "PV atual (edição)" }, { "mana", "Mana atual (edição)" },
		{ "color", "Cor RGB, ex.: 70,120,200" },
	} do
		local box, caption = input(master, field[2], "")
		fields[field[1]], captions[field[1]] = box, caption
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if not filling then dirty[field[1]] = true end
		end)
	end
	local kindButton, ownerButton, hiddenButton, statsButton
	kindButton = button(master, "Tipo: NPC", function()
		if not state.isMaster() then return end
		values.kind = if values.kind == "npc" then "jogador" else "npc"
		dirty.kind, kindButton.Text = true, "Tipo: " .. values.kind
	end)
	local function ownerText()
		if values.ownerUserId == 0 then return "Dono: sem dono" end
		local snapshot = state.snapshot()
		for _, other in (snapshot and snapshot.players or {}) do
			if other.userId == values.ownerUserId then return "Dono: " .. other.name end
		end
		return "Dono: ausente (" .. values.ownerUserId .. ")"
	end
	ownerButton = button(master, "Dono: sem dono", function()
		if not state.isMaster() then return end
		local ids, snapshot = { 0 }, state.snapshot()
		for _, other in (snapshot and snapshot.players or {}) do table.insert(ids, other.userId) end
		local index = table.find(ids, values.ownerUserId) or 0
		values.ownerUserId = ids[index % #ids + 1]
		dirty.ownerUserId, ownerButton.Text = true, ownerText()
	end)
	hiddenButton = button(master, "Oculta: não", function()
		if not state.isMaster() then return end
		values.hidden, dirty.hidden = not values.hidden, true
		hiddenButton.Text = "Oculta: " .. (if values.hidden then "sim" else "não")
	end)
	statsButton = button(master, "Mostrar atributos: não", function()
		if not state.isMaster() then return end
		values.showStats, dirty.showStats = not values.showStats, true
		statsButton.Text = "Mostrar atributos: " .. (if values.showStats then "sim" else "não")
	end)
	hydrate = function(token)
		filling, dirty = true, {}
		formMode, boundId = if token then "edit" else "create", token and token.id or nil
		formTitle.Text = if token then "Editar: " .. token.name else "Nova ficha na casa selecionada (ou centro)"
		fields.name.Text = token and token.name or "Nova ficha"
		fields.pvMax.Text = tostring(token and token.pvMax or 10)
		fields.manaMax.Text = tostring(token and token.manaMax or 0)
		fields.pv.Text = tostring(token and token.pv or 10)
		fields.mana.Text = tostring(token and token.mana or 0)
		local color = token and token.color or Color3.fromRGB(185, 74, 70)
		fields.color.Text = string.format("%d,%d,%d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
		values.kind, values.ownerUserId = token and token.kind or "npc", token and token.ownerUserId or 0
		values.hidden, values.showStats = token ~= nil and token.hidden == true, token ~= nil and token.showStats == true
		kindButton.Text, ownerButton.Text = "Tipo: " .. values.kind, ownerText()
		hiddenButton.Text = "Oculta: " .. (if values.hidden then "sim" else "não")
		statsButton.Text = "Mostrar atributos: " .. (if values.showStats then "sim" else "não")
		statsButton.Visible = token ~= nil
		fields.pv.Visible, fields.mana.Visible = token ~= nil, token ~= nil
		captions.pv.Visible, captions.mana.Visible = token ~= nil, token ~= nil
		filling = false
	end
	local function readForm()
		local payload = {}
		for _, field in { "name", "pvMax", "manaMax", "pv", "mana", "color", "kind", "ownerUserId", "hidden", "showStats" } do
			local include = formMode == "create" or dirty[field]
			if formMode == "create" and (field == "pv" or field == "mana" or field == "showStats") then include = false end
			if not include then continue end
			if field == "name" then
				payload.name = fields.name.Text
			elseif field == "color" then
				local r, g, b = string.match(fields.color.Text, "^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
				if not r or tonumber(r) > 255 or tonumber(g) > 255 or tonumber(b) > 255 then
					explain("Use três inteiros RGB entre 0 e 255.")
					return nil
				end
				payload.color = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
			elseif fields[field] then
				local number = tonumber(fields[field].Text)
				if not number or number ~= number or number % 1 ~= 0 then
					explain("Informe um inteiro em " .. field .. ".")
					return nil
				end
				payload[field] = number
			else
				payload[field] = values[field]
			end
		end
		return payload
	end
	button(master, "Enviar ficha ao servidor", function()
		if not canChangeTable() then return end
		local payload = readForm()
		if not payload then return end
		if formMode == "edit" then
			if not state.findToken(boundId) then explain("A ficha editada não está mais na mesa."); return end
			payload.id = boundId
			state.send("updateToken", payload)
		else
			local x, z = state.selectedCell()
			if x and z then payload.x, payload.z = x, z end
			state.send("createToken", payload)
		end
		explain("Pedido enviado. Confira a resposta no registro.")
	end)
	local removeId, removeButton
	removeButton = button(master, "Remover ficha selecionada…", function()
		if not canChangeTable() then return end
		local token = state.findToken(state.selectedToken())
		if not token then explain("Selecione uma ficha para remover."); return end
		if removeId ~= token.id then
			removeId, removeButton.Text = token.id, "Confirmar remoção: " .. token.name
		else
			state.send("removeToken", { id = token.id })
			removeId, removeButton.Text = nil, "Remover ficha selecionada…"
		end
	end)
	button(master, "Cancelar remoção", function()
		removeId, removeButton.Text = nil, "Remover ficha selecionada…"
	end)
	hydrate(nil)

	local importSection = section(master, "Importar ficha do site")
	local importCode = input(importSection, "Colar código de ficha", "")
	importCode.Name, importCode.Size = "FichaImportCode", UDim2.new(1, 0, 0, 120)
	importCode.MultiLine, importCode.TextWrapped = true, true
	importCode.TextXAlignment, importCode.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	local function hasImportCode()
		if not string.find(importCode.Text, "%S") then explain("Cole o código de ficha antes de importar."); return false end
		return true
	end
	-- Código v2 (ficha completa, "mesa": 2) vai em partes e vira proposta para aprovar;
	-- o código v1 (curto) continua aplicando direto, como antes.
	local importStatus = label(importSection, "", 0)
	importStatus.Name, importStatus.AutomaticSize, importStatus.Visible = "FichaImportStatus", Enum.AutomaticSize.Y, false
	importStatus.TextColor3 = COLORS.muted
	local function sendV2(options)
		importStatus.Visible, importStatus.Text = true, "Preparando o envio…"
		state.enviarFichaV2(importCode.Text, options, function(text, finished, failed)
			importStatus.Text = text
			importStatus.TextColor3 = if failed then COLORS.wine elseif finished then COLORS.gold else COLORS.muted
		end)
	end
	local sessionPolicy = "preserve"
	button(importSection, "Importar na casa selecionada", function()
		if not canChangeTable() or not hasImportCode() then return end
		local x, z = state.selectedCell()
		if state.ehFichaV2(importCode.Text) then
			sendV2({ ownerUserId = values.ownerUserId, x = x, z = z })
			return
		end
		local payload = { code = importCode.Text, ownerUserId = values.ownerUserId }
		if x and z then payload.x, payload.z = x, z end
		state.send("importToken", payload)
	end)
	button(importSection, "Atualizar ficha selecionada", function()
		if not canChangeTable() then return end
		local token = state.findToken(state.selectedToken())
		if not token then explain("Selecione uma ficha para atualizar pelo código."); return end
		if not hasImportCode() then return end
		if state.ehFichaV2(importCode.Text) then
			sendV2({ targetId = token.id, sessionPolicy = sessionPolicy })
			return
		end
		state.send("importToken", { code = importCode.Text, id = token.id })
	end)
	local policyButton
	policyButton = button(importSection, "Ao atualizar: manter PV, mana e condições da mesa", function()
		sessionPolicy = if sessionPolicy == "preserve" then "replace" else "preserve"
		policyButton.Text = if sessionPolicy == "preserve"
			then "Ao atualizar: manter PV, mana e condições da mesa"
			else "Ao atualizar: usar PV, mana e condições do site"
	end)
	policyButton.Name = "FichaSessionPolicy"

	-- Propostas de ficha v2: o servidor validou; o mestre confere e decide.
	local proposalSection = section(master, "Propostas de ficha")
	proposalSection.Name = "FichaPropostas"
	local proposalEmpty = label(proposalSection, "Nenhuma proposta pendente.", 26)
	proposalEmpty.TextColor3 = COLORS.muted
	local proposalList = listFrame(proposalSection)
	local proposalKey, proposalCards = "", {}
	local function signed(value) return string.format("%+d", value) end
	local function proposalText(p)
		local r = p.resumo
		local a = r.atributos
		local meters = string.gsub(string.gsub(string.format("%.1f", r.deslocamento), "%.0$", ""), "%.", ",")
		local lines = {
			p.name .. " — " .. (if p.targetId
				then "atualiza " .. (p.targetName or p.targetId) .. (if p.sessionPolicy == "replace" then " (sessão do site)" else " (mantém a sessão da mesa)")
				else "nova ficha"),
			string.format("PV %d • PM %d • PT %d • PP %d   (atuais %d/%d/%d/%d)", r.pv, r.pm, r.pt, r.pp, r.atuais.pv, r.atuais.pm, r.atuais.pt, r.atuais.pp),
			string.format("CA %d • Iniciativa %s%s • Deslocamento %s m", r.ca, signed(r.iniciativa), if r.vantagemIniciativa then " (vantagem)" else "", meters),
			string.format("FOR %s • AGI %s • VIG %s • INT %s • ESP %s", signed(a.forca), signed(a.agilidade), signed(a.vigor), signed(a.intelecto), signed(a.espirito)),
			string.format("%d compras • %d ranks • %d itens • %d condições%s", r.compras, r.ranks, r.inventario, r.condicoes, if r.completa then "" else " • construção INCOMPLETA"),
		}
		if #p.avisos > 0 then
			table.insert(lines, "Avisos:")
			for _, aviso in p.avisos do table.insert(lines, "• " .. aviso) end
		end
		table.insert(lines, string.format("Vence em %d min.", math.ceil(p.venceEm / 60)))
		return table.concat(lines, "\n")
	end
	local function refreshProposals(snapshot)
		local list = snapshot.fichaPropostas or {}
		local keyParts = {}
		for _, p in list do table.insert(keyParts, p.id .. ":" .. p.version) end
		local key = table.concat(keyParts, ",")
		proposalSection.Visible = state.isMaster()
		if key == proposalKey then return end
		proposalKey = key
		for _, card in proposalCards do card:Destroy() end
		table.clear(proposalCards)
		proposalEmpty.Visible = #list == 0
		for _, p in list do
			local card = new("Frame", proposalList, {
				Name = "Proposta_" .. p.id, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = COLORS.background, BorderSizePixel = 0,
			})
			table.insert(proposalCards, card)
			decorate(card, 6, 0.6)
			new("UIPadding", card, {
				PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
			})
			stack(card)
			local text = label(card, proposalText(p), 0)
			text.AutomaticSize, text.TextSize = Enum.AutomaticSize.Y, 15
			local line, size = row(card, 2)
			button(line, "Aprovar", function()
				if canChangeTable() then state.send("fichaImportApply", { proposalId = p.id, version = p.version }) end
			end, size, "primary").Name = "Aprovar_" .. p.id
			button(line, "Recusar", function()
				if canChangeTable() then state.send("fichaImportReject", { proposalId = p.id }) end
			end, size, "danger").Name = "Recusar_" .. p.id
		end
	end

	-- Fatia A1 (jogo por turnos): personagem pronto e criaturas do bestiário na casa selecionada.
	local jogoSection = section(master, "Jogo: Árvore do Fogo")
	jogoSection.Name = "JogoFogo"
	label(jogoSection, "Selecione uma casa vazia e crie. O dono escolhido acima controla o Ignis.", 36).TextColor3 = COLORS.muted
	local function naCasa(payload)
		local x, z = state.selectedCell()
		if x and z then payload.x, payload.z = x, z end
		return payload
	end
	button(jogoSection, "Ignis, Aprendiz de Fogo (pronto)", function()
		if canChangeTable() then state.send("criarPremontado", naCasa({ id = "mago-de-fogo", ownerUserId = values.ownerUserId })) end
	end, nil, "primary").Name = "CriarIgnis"
	for _, criatura in {
		{ "creature/lobo-cinzento", "Lobo Cinzento" },
		{ "creature/goblin-batedor", "Goblin Batedor" },
		{ "creature/bandido-de-estrada", "Bandido de Estrada" },
	} do
		button(jogoSection, "Criatura: " .. criatura[2], function()
			if canChangeTable() then state.send("criarCriatura", naCasa({ creatureId = criatura[1] })) end
		end).Name = "Criar_" .. criatura[1]
	end

	local mapSection = section(master, "Mapa")
	mapSection.Name = "MapSection"
	local brushInfo = label(mapSection, "Pincel: desligado", 46)
	brushInfo.Name = "BrushInfo"
	local brushButtons = {}
	local brushes = {
		{ "parede", "Parede" }, { "dificil", "Terreno difícil" }, { "agua", "Água" },
		{ "limpar", "Apagar terreno" }, { "nevoa", "Névoa" }, { "revelar", "Revelar" },
	}
	local function refreshBrush()
		local current, title = state.brush(), "desligado"
		for _, brush in brushes do
			local object, active = brushButtons[brush[1]], current == brush[1]
			if object then
				object.Text = (if active then "✓ " else "") .. brush[2]
				setButtonStyle(object,
					if active then COLORS.gold else COLORS.button,
					if active then COLORS.card else COLORS.text,
					nil, active)
			end
			if active then title = brush[2] end
		end
		brushInfo.Text = "Pincel: " .. title
	end
	for _, brush in brushes do
		local object = button(mapSection, brush[2], function()
			if not canChangeTable() then return end
			state.setBrush(if state.brush() == brush[1] then nil else brush[1])
			refreshBrush()
		end)
		object.Name, brushButtons[brush[1]] = "Brush_" .. brush[1], object
	end
	state.onBrush(refreshBrush)
	local fogPending, fogUntil = nil, 0
	local coverButton, revealButton
	local function resetFogConfirmation()
		fogPending, fogUntil = nil, 0
		if coverButton then coverButton.Text = "Cobrir tudo com névoa" end
		if revealButton then revealButton.Text = "Revelar tudo" end
	end
	local function requestFog(covered)
		if not canChangeTable() then resetFogConfirmation(); return end
		if fogPending ~= covered or os.clock() >= fogUntil then
			resetFogConfirmation()
			fogPending, fogUntil = covered, os.clock() + CONFIRM_SECONDS
			local object = if covered then coverButton else revealButton
			object.Text = if covered then "Confirmar cobrir tudo com névoa" else "Confirmar revelar tudo"
			explain("Isso muda a névoa de todo o tabuleiro. Clique novamente em até 5 segundos.")
			return
		end
		resetFogConfirmation()
		state.send("fogAll", { covered = covered })
	end
	coverButton = button(mapSection, "Cobrir tudo com névoa", function() requestFog(true) end)
	revealButton = button(mapSection, "Revelar tudo", function() requestFog(false) end)
	button(mapSection, "Cancelar confirmação da névoa", resetFogConfirmation)
	refreshBrush()

	local initiative = section(master, "Iniciativa")
	local initiativeRows, initiativeDrafts = {}, {}
	local participants = listFrame(initiative)
	local function syncInitiative(snapshot)
		local seen = {}
		for index, token in snapshot.tokens do
			seen[token.id] = true
			local record = initiativeRows[token.id]
			if not record then
				local draft = { enabled = true, value = "0" }
				initiativeDrafts[token.id] = draft
				local line, size = row(participants, 2)
				local toggle
				toggle = button(line, "", function()
					draft.enabled = not draft.enabled
					local current = state.findToken(token.id)
					toggle.Text = (if draft.enabled then "✓ " else "— ") .. (current and current.name or token.name)
				end, size)
				local box = new("TextBox", line, {
					Size = size, Text = "0", ClearTextOnFocus = false,
					BackgroundColor3 = COLORS.background, TextColor3 = COLORS.text,
					FontFace = TEXT_FONT, TextSize = 16,
				})
				decorate(box, 6, 0.65)
				box:GetPropertyChangedSignal("Text"):Connect(function() draft.value = box.Text end)
				record = { line = line, toggle = toggle, box = box }
				initiativeRows[token.id] = record
			end
			record.line.LayoutOrder = index
			record.toggle.Text = (if initiativeDrafts[token.id].enabled then "✓ " else "— ") .. token.name
		end
		for id, record in initiativeRows do
			if not seen[id] then
				record.line:Destroy()
				initiativeRows[id], initiativeDrafts[id] = nil, nil
			end
		end
	end
	button(initiative, "Rolar iniciativa", function()
		if not canChangeTable() then return end
		local snapshot, ids = state.snapshot(), {}
		for _, token in (snapshot and snapshot.tokens or {}) do
			local draft = initiativeDrafts[token.id]
			if draft and draft.enabled then table.insert(ids, token.id) end
		end
		if #ids == 0 then explain("Marque pelo menos uma ficha para rolar iniciativa."); return end
		state.send("rollInitiative", { ids = ids })
	end)
	button(initiative, "Iniciar / reiniciar o combate", function()
		if not canChangeTable() then return end
		local snapshot, list = state.snapshot(), {}
		for _, token in (snapshot and snapshot.tokens or {}) do
			local draft = initiativeDrafts[token.id]
			if draft and draft.enabled then
				local number = tonumber(draft.value)
				if not number or number ~= number or number % 1 ~= 0 then
					explain("Iniciativa inválida para " .. token.name)
					return
				end
				table.insert(list, { id = token.id, initiative = number })
			end
		end
		state.send("combatStart", { entries = list })
	end)
	button(initiative, "Próximo turno", function()
		local snapshot = state.snapshot()
		if canChangeTable() and snapshot and snapshot.combat.turnId then
			state.send("nextTurn", { expectedId = snapshot.combat.turnId, expectedTurn = snapshot.combat.turn })
		end
	end)
	button(initiative, "Encerrar combate", function()
		if canChangeTable() then state.send("combatEnd") end
	end)

	local function refresh()
		local snapshot = state.snapshot()
		if not snapshot then return end
		refreshCampaign(snapshot)
		syncTabs()
		local combat, turn = snapshot.combat, state.findToken(snapshot.combat.turnId)
		local turnText = if combat.masterTurn then "vez do mestre" elseif turn then turn.name else "sem vez"
		header.Text = (if state.isMaster() then "Mestre" else "Jogador")
			.. (if combat.active then " • R" .. combat.round .. " • " .. turnText else " • exploração")
		local token = state.findToken(state.selectedToken())
		selectedInfo.Text = if token then token.name
			.. "\n" .. (if token.pv ~= nil then string.format("PV %d/%d", token.pv, token.pvMax) else "PV não revelados")
			.. " • " .. (if token.mana ~= nil then string.format("Mana %d/%d", token.mana, token.manaMax) else "Mana não revelada")
			else "Nenhuma ficha selecionada."
		openDetail.Visible = token ~= nil and token.ficha2Versao ~= nil
		refreshDetail()
		local sheet = token and token.sheet
		local meters = if sheet then (string.gsub(string.format("%.1f", sheet.deslocamento), "%.0$", "")) else ""
		meters = string.gsub(meters, "%.", ",")
		selectedSheet.Visible = sheet ~= nil
		selectedSheet.Text = if sheet then string.format(
			"FOR %+d • AGI %+d • VIG %+d • INT %+d • ESP %+d\nCA %d • Deslocamento %s m\nIniciativa %+d%s",
			sheet.forca, sheet.agilidade, sheet.vigor, sheet.intelecto, sheet.espirito,
			sheet.ca, meters, sheet.iniciativa, if sheet.vantagemIniciativa then " • vantagem" else ""
		) else ""
		for stat, line in adjustRows do
			line.Visible = token ~= nil and state.canControl(token) and token[stat] ~= nil
		end
		refreshConditions(token)
		myTurn.Visible = combat.active and turn ~= nil and turn.ownerUserId == state.localUserId()
		master.Visible = state.isMaster()
		if not state.isMaster() then
			if state.brush() ~= nil then state.setBrush(nil) end
			resetFogConfirmation()
			removeId, removeButton.Text = nil, "Remover ficha selecionada…"
		elseif loading() or (fogPending ~= nil and os.clock() >= fogUntil) then
			resetFogConfirmation()
		end
		refreshBrush()
		if state.isMaster() then syncInitiative(snapshot); ownerButton.Text = ownerText() end
		refreshProposals(snapshot)
		if boundId and not state.findToken(boundId) then hydrate(nil) end
	end
	state.onSnapshot(refresh)
	state.onSelection(function(id, x, z)
		closeDetail()
		removeId, removeButton.Text = nil, "Remover ficha selecionada…"
		conditionNote.Text, selectedCondition = "", nil
		conditionDetails.Text = "Escolha uma condição do livro."
		if id and formMode == "edit" and id ~= boundId then hydrate(state.findToken(id)) end
		if x and z then
			explain(string.format("Casa selecionada: %d, %d. Nova ficha será criada aqui.", x, z))
		end
		refresh()
	end)
	state.onFichaDetalhe(function(id)
		if id == state.selectedToken() then refreshDetail() end
	end)
	refresh()
end

return MesaPanel
