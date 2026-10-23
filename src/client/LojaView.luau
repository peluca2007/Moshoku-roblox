-- Painel mínimo de compra/venda; a prateleira e os preços recebidos são do servidor.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Estilo = require(ReplicatedStorage.Shared.Estilo)
local View = {}

function View.start(state)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "LojaPessoal", false, 35
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local painel = Instance.new("Frame")
	painel.Name, painel.AnchorPoint, painel.Position = "Painel", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	painel.Size, painel.BackgroundColor3, painel.Parent = UDim2.new(.88, 0, .76, 0), Estilo.PAPEL, gui
	Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 12)
	local titulo = Instance.new("TextLabel")
	titulo.Name, titulo.Size, titulo.Position = "Titulo", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 8)
	titulo.BackgroundTransparency, titulo.FontFace, titulo.TextSize, titulo.TextColor3 = 1, Estilo.GRITO, 28, Estilo.TINTA
	titulo.Parent = painel
	local saldo = Instance.new("TextLabel")
	saldo.Name, saldo.Size, saldo.Position = "Saldo", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 48)
	saldo.BackgroundTransparency, saldo.FontFace, saldo.TextSize, saldo.TextColor3 = 1, Estilo.ROTULO, 17, Estilo.TINTA
	saldo.Parent = painel
	local fechar = Instance.new("TextButton")
	fechar.Name, fechar.Text, fechar.Size, fechar.Position = "Fechar", "Fechar", UDim2.fromOffset(90, 36), UDim2.new(1, -102, 0, 8)
	fechar.BackgroundColor3, fechar.FontFace, fechar.TextSize, fechar.Parent = Estilo.BOTAO, Estilo.ROTULO_FORTE, 15, painel
	fechar.Activated:Connect(function() gui.Enabled = false end)
	local comprar = Instance.new("TextButton")
	comprar.Name, comprar.Text, comprar.Size, comprar.Position = "AbaComprar", "Comprar", UDim2.new(.5, -8, 0, 38), UDim2.fromOffset(12, 82)
	comprar.BackgroundColor3, comprar.FontFace, comprar.TextSize, comprar.Parent = Estilo.DESTAQUE_FUNDO, Estilo.ROTULO_FORTE, 16, painel
	local vender = Instance.new("TextButton")
	vender.Name, vender.Text, vender.Size, vender.Position = "AbaVender", "Vender", UDim2.new(.5, -8, 0, 38), UDim2.new(.5, 4, 0, 82)
	vender.BackgroundColor3, vender.FontFace, vender.TextSize, vender.Parent = Estilo.BOTAO, Estilo.ROTULO_FORTE, 16, painel
	local lista = Instance.new("ScrollingFrame")
	lista.Name, lista.Position, lista.Size = "Lista", UDim2.fromOffset(12, 128), UDim2.new(1, -24, 1, -140)
	lista.BackgroundTransparency, lista.BorderSizePixel, lista.ScrollBarThickness, lista.AutomaticCanvasSize, lista.Parent = 1, 0, 5, Enum.AutomaticSize.Y, painel
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.Parent = UDim.new(0, 6), lista
	local estado, modo = nil, "comprar"
	local function render()
		if not estado then return end
		comprar.BackgroundColor3 = if modo == "comprar" then Estilo.DESTAQUE_FUNDO else Estilo.BOTAO
		vender.BackgroundColor3 = if modo == "vender" then Estilo.DESTAQUE_FUNDO else Estilo.BOTAO
		saldo.Text = string.format("Saldo: %d PO", estado.ouro or 0)
		for _, child in ipairs(lista:GetChildren()) do if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end end
		local entries = if modo == "comprar" then estado.prateleira or {} else estado.inventario or {}
		for _, item in ipairs(entries) do
			local row = Instance.new("TextButton")
			row.Size, row.BackgroundColor3, row.TextColor3 = UDim2.new(1, -8, 0, 48), Estilo.BOTAO, Estilo.TINTA
			row.FontFace, row.TextSize, row.TextWrapped = Estilo.ROTULO, 15, true
			row.Text = string.format("%s  ·  %d PO%s", item.name, item.price or 0, if modo == "comprar" then " · Comprar" else " · Vender")
			row.Parent = lista
			row.Activated:Connect(function()
				if not estado then return end
				local requestId = HttpService:GenerateGUID(false)
				if modo == "comprar" then
					state.send("lojaComprar", { npcId = estado.npcId, itemId = item.id, requestId = requestId })
				else
					state.send("lojaVender", { npcId = estado.npcId, sourceLocalId = item.sourceLocalId, requestId = requestId })
				end
			end)
		end
		lista.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end
	comprar.Activated:Connect(function() modo = "comprar"; render() end)
	vender.Activated:Connect(function() modo = "vender"; render() end)
	state.onLoja(function(dados) estado = dados; modo = "comprar"; titulo.Text = dados.nome or "Loja"; gui.Enabled = true; render() end)
	return gui
end

return View
