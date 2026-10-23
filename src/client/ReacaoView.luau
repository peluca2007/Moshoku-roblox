-- Pergunta com prazo; servidor oferece opções e decide validade/efeitos.
-- O canal opcional permite verificar a UI com um RemoteEvent isolado no Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Estilo = require(Shared:WaitForChild("Estilo"))
local Protocol = require(Shared:WaitForChild("MesaProtocol"))
local ReacaoView = {}

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

function ReacaoView.start(state, canal: RemoteEvent?)
	local gui = new("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"), {
		Name = "ReacaoJogo", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 32,
	})
	-- Sem dispensar por toque externo: há uma escolha com prazo em andamento.
	local fundo = new("TextButton", gui, {
		Name = "Fundo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Estilo.SOBRE_COR,
		BackgroundTransparency = .3, Text = "", AutoButtonColor = false, Modal = true, Visible = false,
	})
	local caixa = new("Frame", fundo, {
		Name = "Caixa", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(.92, .82),
		BackgroundColor3 = Estilo.PAPEL_2, BorderSizePixel = 0, Active = true, ZIndex = 2,
	})
	new("UISizeConstraint", caixa, { MaxSize = Vector2.new(480, 520) })
	new("UICorner", caixa, { CornerRadius = UDim.new(0, 10) })
	new("UIStroke", caixa, { Color = Estilo.DESTAQUE, Thickness = 2 })
	local function texto(parent, props)
		local o = new("TextLabel", parent, {
			BackgroundTransparency = 1, FontFace = Estilo.ROTULO, TextSize = 15, TextColor3 = Estilo.TINTA,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
		})
		for k, v in props do o[k] = v end
		return o
	end
	texto(caixa, { Name = "Titulo", Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 28), Text = "REAÇÃO", FontFace = Estilo.GRITO, TextSize = 24, TextColor3 = Estilo.DESTAQUE })
	local contagem = texto(caixa, { Name = "Contagem", Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 22), Text = "" })
	local prazoFundo = new("Frame", caixa, { Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 4), BackgroundColor3 = Estilo.FIO_COR, BorderSizePixel = 0, ZIndex = 3 })
	local prazoBarra = new("Frame", prazoFundo, { Name = "Barra", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Estilo.DESTAQUE, BorderSizePixel = 0, ZIndex = 3 })
	local scroll = new("ScrollingFrame", caixa, {
		Name = "Opcoes", Position = UDim2.fromOffset(16, 90), Size = UDim2.new(1, -32, 1, -184),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
	})
	new("UIListLayout", scroll, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local descricao = texto(scroll, { Name = "Descricao", LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "" })
	texto(caixa, {
		Name = "Atalhos", Position = UDim2.new(0, 16, 1, -86), Size = UDim2.new(1, -32, 0, 24), TextSize = 12,
		Text = "1–9: escolher • 0 / Espaço: passar", TextColor3 = Estilo.TINTA_SUAVE,
	})
	local passar = new("TextButton", caixa, {
		Name = "Passar", Position = UDim2.new(0, 16, 1, -56), Size = UDim2.new(1, -32, 0, 44),
		Text = "Deixar passar", FontFace = Estilo.ROTULO_FORTE, TextSize = 16,
		BackgroundColor3 = Estilo.BOTAO, TextColor3 = Estilo.TINTA, ZIndex = 3,
	})
	new("UICorner", passar, { CornerRadius = UDim.new(0, 8) })
	local atual = nil -- { id, opcoes, fim, prazo }
	local function fechar(id)
		if atual and (id == nil or atual.id == id) then atual = nil; fundo.Visible = false end
	end
	local function responder(escolha)
		if not atual then return end
		if os.clock() >= atual.fim then fechar(atual.id); return end
		local id = atual.id
		fechar(id) -- Duplo clique/tecla não envia duas respostas.
		state.send("reagir", { id = id, escolha = escolha })
	end
	passar.Activated:Connect(function() responder(nil) end)
	local function atualizarTempo()
		if not atual then return end
		local resto = math.max(0, atual.fim - os.clock())
		if resto <= 0 then fechar(atual.id); return end
		contagem.Text = string.format("%d s para escolher", math.ceil(resto))
		contagem.TextColor3 = if resto <= 3 then Estilo.PERIGO else Estilo.TINTA
		prazoBarra.Size = UDim2.fromScale(math.clamp(resto / atual.prazo, 0, 1), 1)
		prazoBarra.BackgroundColor3 = contagem.TextColor3
	end
	local function abrir(dados)
		fechar(nil)
		for _, filho in scroll:GetChildren() do
			if filho:IsA("TextButton") then filho:Destroy() end
		end
		local prazo = tonumber(dados.prazo) or 8
		if prazo ~= prazo or prazo <= 0 or prazo == math.huge then return end
		atual = { id = dados.id, opcoes = dados.opcoes, prazo = prazo, fim = os.clock() + prazo }
		descricao.Text = tostring(dados.texto or "")
		for i, opcao in dados.opcoes do
			local b = new("TextButton", scroll, {
				Name = "Opcao_"..i, LayoutOrder = i, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				Text = "", BackgroundColor3 = Estilo.DESTAQUE_FUNDO, BorderSizePixel = 0, ZIndex = 3,
			})
			new("UISizeConstraint", b, { MinSize = Vector2.new(0, 44) })
			new("UICorner", b, { CornerRadius = UDim.new(0, 8) })
			new("UIPadding", b, { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
			new("UIListLayout", b, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
			texto(b, { Name = "Nome", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
				Text = (if i <= 9 then i.." · " else "")..tostring(opcao.nome), FontFace = Estilo.ROTULO_FORTE, TextSize = 16 })
			if opcao.detalhe then
				texto(b, { Name = "Detalhe", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
					Text = tostring(opcao.detalhe), TextSize = 14, TextColor3 = Estilo.TINTA_SUAVE })
			end
			b.Activated:Connect(function() responder(opcao.id) end)
		end
		scroll.CanvasPosition = Vector2.zero
		fundo.Visible = true
		atualizarTempo()
	end
	local remote = canal or ReplicatedStorage:WaitForChild(Protocol.REMOTE) :: RemoteEvent
	local evento = remote.OnClientEvent:Connect(function(kind, dados)
		if kind ~= "reacao" or type(dados) ~= "table" or type(dados.id) ~= "number" then return end
		if dados.fechar then fechar(dados.id)
		elseif type(dados.opcoes) == "table" and #dados.opcoes > 0 then abrir(dados) end
	end)
	local teclas = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
		Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
	local entrada = UserInputService.InputBegan:Connect(function(input, processado)
		if processado or not atual or UserInputService:GetFocusedTextBox() then return end
		local i = table.find(teclas, input.KeyCode)
		if i and atual.opcoes[i] then responder(atual.opcoes[i].id)
		elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Zero then responder(nil) end
	end)
	state.onSnapshot(function(snapshot)
		if gui.Parent and snapshot.combat and not snapshot.combat.active then fechar(nil) end
	end)
	gui.Destroying:Connect(function() evento:Disconnect(); entrada:Disconnect(); atual = nil end)
	task.spawn(function()
		while gui.Parent do atualizarTempo(); task.wait(.1) end
	end)
	return gui
end

return ReacaoView
