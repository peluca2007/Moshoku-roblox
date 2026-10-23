-- Consulta local da carta. Não seleciona alvos nem envia pedidos.
local UserInputService = game:GetService("UserInputService")
local Estilo = require(game:GetService("ReplicatedStorage").Shared.Estilo)
local Detalhe = {}

local function new(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

function Detalhe.start(parent)
	local fundo = new("TextButton", parent, {
		Name = "DetalheAcao", Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Estilo.SOBRE_COR, BackgroundTransparency = .25, BorderSizePixel = 0,
		Visible = false, ZIndex = 10, Modal = true,
	})
	local painel = new("Frame", fundo, {
		Name = "Painel", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromScale(.92, .8), BackgroundColor3 = Estilo.PAPEL, BorderSizePixel = 0, Active = true, ZIndex = 11,
	})
	new("UISizeConstraint", painel, { MaxSize = Vector2.new(560, 500) })
	new("UICorner", painel, { CornerRadius = UDim.new(0, 10) })
	new("UIStroke", painel, { Color = Estilo.DESTAQUE, Thickness = 2 })
	local function rotulo(nome, props)
		local t = new("TextLabel", painel, {
			Name = nome, BackgroundTransparency = 1, FontFace = Estilo.ROTULO, TextSize = 15,
			TextColor3 = Estilo.TINTA, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12,
		})
		for k, v in props do t[k] = v end
		return t
	end
	local titulo = rotulo("Titulo", { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -80, 0, 52), FontFace = Estilo.GRITO, TextSize = 23 })
	local custo = rotulo("Custo", { Position = UDim2.fromOffset(16, 66), Size = UDim2.new(1, -32, 0, 38), TextSize = 14, TextColor3 = Estilo.ALERTA })
	local scroll = new("ScrollingFrame", painel, {
		Name = "Texto", Position = UDim2.fromOffset(16, 112), Size = UDim2.new(1, -32, 1, -218),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4, BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 12,
	})
	local corpo = new("TextLabel", scroll, {
		Name = "Conteudo", Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, FontFace = Estilo.ROTULO, TextSize = 16, TextColor3 = Estilo.TINTA,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 12,
	})
	local situacao = rotulo("Situacao", {
		Position = UDim2.new(0, 16, 1, -100), Size = UDim2.new(1, -32, 0, 40), TextSize = 14,
	})
	local function fechar() fundo.Visible = false end
	local function botao(nome, texto, props)
		local b = new("TextButton", painel, {
			Name = nome, Text = texto, FontFace = Estilo.ROTULO_FORTE, TextSize = 16,
			TextColor3 = Estilo.TINTA, BackgroundColor3 = Estilo.BOTAO, ZIndex = 12,
		})
		for k, v in props do b[k] = v end
		new("UICorner", b, { CornerRadius = UDim.new(0, 6) })
		b.Activated:Connect(fechar)
	end
	botao("Fechar", "×", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(44, 44), TextSize = 26 })
	botao("Voltar", "Voltar às ações", { Position = UDim2.new(0, 16, 1, -56), Size = UDim2.new(1, -32, 0, 44) })
	fundo.Activated:Connect(function(input)
		-- Activated também pode subir de um descendente; ler/rolar não fecha.
		local ponto = input.Position
		local origem, tamanho = painel.AbsolutePosition, painel.AbsoluteSize
		local dentro = ponto.X >= origem.X and ponto.X <= origem.X + tamanho.X
			and ponto.Y >= origem.Y and ponto.Y <= origem.Y + tamanho.Y
		if not dentro then fechar() end
	end)
	local conexao = UserInputService.InputBegan:Connect(function(input)
		if fundo.Visible and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB) and not UserInputService:GetFocusedTextBox() then fechar() end
	end)
	fundo.Destroying:Connect(function() conexao:Disconnect() end)
	local idAberto = nil
	local function atualizar(dados)
		titulo.Text, custo.Text, corpo.Text = dados.nome, dados.custo, dados.texto
		situacao.Text = dados.motivo or "Disponível. Volte às ações para escolher o alvo."
		situacao.TextColor3 = if dados.motivo then Estilo.ALERTA else Estilo.SUCESSO
	end
	return {
		abrir = function(id, dados)
			idAberto = id; atualizar(dados); scroll.CanvasPosition = Vector2.zero; fundo.Visible = true
		end,
		atualizar = function(id, dados) if fundo.Visible and idAberto == id then atualizar(dados) end end,
		fechar = fechar,
	}
end

return Detalhe
