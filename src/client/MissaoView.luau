-- Painel mínimo das missões oferecidas por Dona Brisa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Estilo = require(ReplicatedStorage.Shared.Estilo)

local Dialogo = require(script.Parent.DialogoNpcEstado)
local View = {}

function View.start(state)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "MissoesPessoais", false, 36, false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local painel = Instance.new("Frame")
	painel.Name, painel.AnchorPoint, painel.Position = "Painel", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	painel.Size, painel.BackgroundColor3, painel.Parent = UDim2.new(.9, 0, .76, 0), Estilo.PAPEL, gui
	Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 12)
	local titulo = Instance.new("TextLabel")
	titulo.Name, titulo.Size, titulo.Position = "Titulo", UDim2.new(1, -112, 0, 44), UDim2.fromOffset(16, 8)
	titulo.BackgroundTransparency, titulo.FontFace, titulo.TextSize, titulo.TextColor3 = 1, Estilo.GRITO, 26, Estilo.TINTA
	titulo.Text, titulo.Parent = "Missões de Dona Brisa", painel
	local fechar = Instance.new("TextButton")
	fechar.Name, fechar.Text, fechar.Size, fechar.Position = "Fechar", "Fechar", UDim2.fromOffset(82, 36), UDim2.new(1, -96, 0, 10)
	fechar.BackgroundColor3, fechar.FontFace, fechar.TextSize, fechar.Parent = Estilo.BOTAO, Estilo.ROTULO_FORTE, 15, painel
	fechar.Activated:Connect(function() gui.Enabled = false; Dialogo.fechar() end)
	local lista = Instance.new("ScrollingFrame")
	lista.Name, lista.Position, lista.Size = "Lista", UDim2.fromOffset(14, 62), UDim2.new(1, -28, 1, -76)
	lista.BackgroundTransparency, lista.BorderSizePixel, lista.ScrollBarThickness = 1, 0, 5
	lista.AutomaticCanvasSize, lista.CanvasSize, lista.Parent = Enum.AutomaticSize.Y, UDim2.new(), painel
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.Parent = UDim.new(0, 10), lista
	local dados
	local function render()
		if not dados then return end
		for _, child in ipairs(lista:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		for indice, missao in ipairs(dados) do
			local linha = Instance.new("Frame")
			linha.Name, linha.LayoutOrder = missao.id, indice
			linha.Size, linha.AutomaticSize, linha.BackgroundColor3 = UDim2.new(1, -8, 0, 0), Enum.AutomaticSize.Y, Estilo.BOTAO
			linha.Parent = lista
			Instance.new("UICorner", linha).CornerRadius = UDim.new(0, 8)
			local margem = Instance.new("UIPadding", linha)
			margem.PaddingTop, margem.PaddingBottom, margem.PaddingLeft, margem.PaddingRight = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 12), UDim.new(0, 12)
			local coluna = Instance.new("UIListLayout")
			coluna.Padding, coluna.Parent = UDim.new(0, 4), linha
			local nome = Instance.new("TextLabel")
			nome.Size, nome.AutomaticSize, nome.BackgroundTransparency = UDim2.new(1, 0, 0, 24), Enum.AutomaticSize.Y, 1
			nome.FontFace, nome.TextSize, nome.TextColor3, nome.TextWrapped = Estilo.ROTULO_FORTE, 18, Estilo.TINTA, true
			nome.TextXAlignment, nome.Text = Enum.TextXAlignment.Left, missao.nome
			nome.Parent = linha
			local descricao = Instance.new("TextLabel")
			descricao.Size, descricao.AutomaticSize, descricao.BackgroundTransparency = UDim2.new(1, 0, 0, 30), Enum.AutomaticSize.Y, 1
			descricao.FontFace, descricao.TextSize, descricao.TextColor3, descricao.TextWrapped = Estilo.ROTULO, 15, Estilo.TINTA_SUAVE, true
			descricao.TextXAlignment, descricao.Text = Enum.TextXAlignment.Left, missao.texto
			descricao.Parent = linha
			local situacao = missao.situacao
			local estadoTexto = if situacao == "aceita" then string.format("Aceita %d/%d", missao.progresso, missao.objetivo)
				elseif situacao == "cumprida" then "Cumprida — volte para entregar"
				elseif situacao == "entregue" then "Entregue"
				else "Disponível"
			local status = Instance.new("TextLabel")
			status.Size, status.BackgroundTransparency = UDim2.new(1, 0, 0, 24), 1
			status.FontFace, status.TextSize, status.TextColor3 = Estilo.ROTULO_FORTE, 15, Estilo.TINTA
			status.TextXAlignment, status.Text = Enum.TextXAlignment.Left, string.format("%s  ·  Recompensa: %d PO", estadoTexto, missao.recompensa)
			status.Parent = linha
			if situacao == "disponivel" or situacao == "cumprida" then
				local aceitar = situacao == "disponivel"
				local botao = Instance.new("TextButton")
				botao.Size, botao.BackgroundColor3 = UDim2.new(1, 0, 0, 38), Estilo.DESTAQUE_FUNDO
				botao.FontFace, botao.TextSize, botao.TextColor3 = Estilo.ROTULO_FORTE, 16, Estilo.TINTA
				botao.Text, botao.Parent = if aceitar then "Aceitar missão" else "Entregar missão", linha
				botao.Activated:Connect(function()
					state.send("missaoAcao", { acao = if aceitar then "aceitar" else "entregar", missaoId = missao.id })
				end)
			end
		end
	end
	state.onMissoes(function(novas)
		dados = novas
		gui.Enabled = Dialogo.receber()
		render()
	end)
	return gui
end

return View
