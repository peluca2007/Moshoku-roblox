local Estilo = require(game.ReplicatedStorage.Shared.Estilo)
local TextService = game:GetService("TextService")
local T = {}
function T.start(gui, aoFechar)
	local frame = Instance.new("Frame")
	frame.Name, frame.Visible, frame.ZIndex = "TooltipAcao", false, 15
	frame.BackgroundColor3, frame.BorderSizePixel = Estilo.PAPEL, 0
	frame.Parent = gui
	local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", frame); stroke.Color = Estilo.DESTAQUE
	local scroll = Instance.new("ScrollingFrame", frame)
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.ZIndex = "Conteudo", 1, 0, 16
	scroll.Position, scroll.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -24, 1, -20)
	scroll.CanvasSize, scroll.ScrollBarThickness = UDim2.new(), 4
	local label = Instance.new("TextLabel", scroll)
	label.Name, label.BackgroundTransparency, label.ZIndex = "Texto", 1, 17
	label.Size = UDim2.new(1, -8, 0, 0)
	label.TextWrapped, label.TextSize, label.FontFace, label.TextColor3 = true, 15, Estilo.ROTULO, Estilo.TINTA
	label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	local id, serial, dentro, ancora = nil, 0, false, nil
	local medicao, alturaTexto = 0, 0
	local function largura()
		return math.max(80, math.min(360, workspace.CurrentCamera.ViewportSize.X - 24))
	end
	local function posicionar()
		if not ancora or not ancora.Parent then return end
		local vp = workspace.CurrentCamera.ViewportSize
		local w, limite = largura(), math.max(80, math.min(380, vp.Y - 80))
		local h = math.clamp(alturaTexto + 24, math.min(110, limite), limite)
		frame.Size = UDim2.fromOffset(w, h)
		frame.Position = UDim2.fromOffset(math.clamp(ancora.AbsolutePosition.X, 12, math.max(12, vp.X - w - 12)), math.clamp(ancora.AbsolutePosition.Y - h - 8, 12, math.max(12, vp.Y - h - 40)))
	end
	local function medir()
		medicao += 1
		local revisao, texto, w = medicao, label.Text, largura() - 32
		-- Medição explícita evita o ciclo entre AutomaticSize e a altura do scroll.
		task.spawn(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text, params.Font, params.Size, params.Width = texto, label.FontFace, label.TextSize, w
			local ok, bounds = pcall(function() return TextService:GetTextBoundsAsync(params) end)
			params:Destroy()
			if revisao ~= medicao or not id or not frame.Parent then return end
			if not ok then
				label.Font = Enum.Font.SourceSans
				bounds = TextService:GetTextSize(texto, label.TextSize, label.Font, Vector2.new(w, 10000))
			end
			alturaTexto = math.ceil(bounds.Y) + 4
			label.Size = UDim2.new(1, -8, 0, alturaTexto)
			scroll.CanvasSize = UDim2.fromOffset(0, alturaTexto)
			posicionar()
		end)
	end
	local api = {}
	function api.fechar()
		serial += 1; id = nil; frame.Visible = false; dentro = false; ancora = nil
		if aoFechar then aoFechar() end
	end
	function api.atualizar(chave, dados)
		if id ~= chave then return end
		label.Text = dados.nome .. "\n" .. dados.custo .. "\n\n" .. (if dados.motivo then dados.motivo .. "\n\n" else "") .. dados.texto
		medir()
	end
	function api.abrir(chave, dados, carta)
		serial += 1; id = chave; ancora = carta
		api.atualizar(chave, dados)
		posicionar()
		scroll.CanvasPosition = Vector2.zero; frame.Visible = true
	end
	function api.sair()
		serial += 1; local n = serial
		task.delay(.15, function() if n == serial and not dentro then api.fechar() end end)
	end
	frame.MouseEnter:Connect(function() dentro = true; serial += 1 end)
	frame.MouseLeave:Connect(function() dentro = false; api.sair() end)
	local viewport = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if id then posicionar(); medir() end
	end)
	frame.Destroying:Connect(function()
		medicao += 1
		viewport:Disconnect()
	end)
	return api
end
return T
