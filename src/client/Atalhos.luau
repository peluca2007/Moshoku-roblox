-- Esconde os botões de atalho do canto (RUN, CONTA, VIAGEM, ?) enquanto um painel grande
-- está aberto. Em tela estreita (celular) eles ficavam por cima do botão "Fechar" dos
-- painéis. Desacoplado de propósito: só observa o PlayerGui, sem exigir mudança nas views.
-- Só apresentação local.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local C = require(script.Parent.UI.Componentes)
local GuiService = game:GetService("GuiService")
local Atalhos = {}

local ROTULOS = { ["MENU"] = true, ["RUN"] = true, ["CONTA"] = true, ["?"] = true }
local FRACAO_X, FRACAO_Y = 0.6, 0.5 -- um quadro desse tamanho conta como painel aberto
local INTERVALO = 0.2
local TweenService = game:GetService("TweenService")
local FADE = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function guiVisivel(objeto: GuiObject): boolean
	local atual: Instance? = objeto
	while atual do
		if atual:IsA("GuiObject") and not atual.Visible then
			return false
		end
		if atual:IsA("ScreenGui") then
			return atual.Enabled
		end
		atual = atual.Parent
	end
	return false
end

-- Atalhos = botões de texto com o rótulo da lista dentro de um ScreenGui que não é o painel.
local function coletarAtalhos(playerGui: PlayerGui): { TextButton }
	local lista = {}
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			for _, item in ipairs(gui:GetDescendants()) do
				if item:IsA("TextButton") and (item:GetAttribute("AtalhoMundo") or (ROTULOS[item.Text] and item.Size.X.Offset <= 140)) then
					table.insert(lista, item)
				end
			end
		end
	end
	return lista
end

local function painelAberto(playerGui: PlayerGui, atalhos: { [Instance]: boolean }): boolean
	local camera = workspace.CurrentCamera
	local tela = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "Carregamento" then
			for _, item in ipairs(gui:GetDescendants()) do
				if item:IsA("Frame") and item.AbsoluteSize.X >= tela.X * FRACAO_X and item.AbsoluteSize.Y >= tela.Y * FRACAO_Y
					and not atalhos[item] and guiVisivel(item) and item.BackgroundTransparency < 0.95 then
					return true
				end
			end
		end
	end
	return false
end

function Atalhos.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local grupoGui = Instance.new("ScreenGui")
	grupoGui.Name, grupoGui.ResetOnSpawn, grupoGui.DisplayOrder = "AtalhosMundo", false, -1
	grupoGui.Parent = playerGui
	local grupo = C.painel({ parent = grupoGui, nome = "GrupoAtalhos", padding = 0, sombra = false,
		tamanho = UDim2.fromOffset(360, 72), posicao = UDim2.new(1, -8, 0, 8), ancora = Vector2.new(1, 0) })
	local indices = { MENU = 1, RUN = 2, CONTA = 3, ["?"] = 4 }
	local function organizar()
		local algum = false
		for _, b in coletarAtalhos(playerGui) do
			local rotulo = b:GetAttribute("AtalhoMundo") or b.Text
			if not indices[rotulo] then continue end
			if not b:GetAttribute("AtalhoMundo") then
				-- MENU pertence ao fluxo de início: preserva a própria Instance e suas conexões.
				b:SetAttribute("AtalhoMundo", rotulo)
				local visual = C.iconeBotao({ parent = b, nome = "VisualV2", icone = "≡", rotulo = rotulo,
					tamanho = UDim2.fromScale(1, 1) })
				visual.Interactable, visual.Selectable = false, false
				visual.Rotulo.Position, visual.Rotulo.Size = UDim2.new(0, 1, .6, 0), UDim2.new(1, -2, .35, 0)
				visual.Rotulo.TextWrapped, visual.Rotulo.TextSize = false, 14 -- mesmo tamanho dos demais atalhos
				visual.Rotulo:SetAttribute("TextoBaseUIV2", 14)
				b.TextTransparency, b.BackgroundTransparency, b.AutoButtonColor = 1, 1, false
				for _, filho in b:GetChildren() do
					if filho:IsA("UIStroke") then filho.Enabled = false end
				end
			end
			local gui = b:FindFirstAncestorOfClass("ScreenGui")
			if not gui then continue end
			local inset = GuiService:GetGuiInset()
			-- Faixa superior direita: nunca ocupa joystick ou a borda esquerda a 40% da altura.
			local largura = math.min(360, grupoGui.AbsoluteSize.X - 16)
			local passo = largura / 4
			local alvo = if rotulo == "MENU" and b.Parent:IsA("GuiObject") then b.Parent else b
			alvo.AnchorPoint = Vector2.zero
			alvo.Position = UDim2.new(1, -8 - largura + (indices[rotulo] - 1) * passo + 4, 0, 12 + (if gui.IgnoreGuiInset then inset.Y else 0))
			alvo.Size = UDim2.fromOffset(passo - 8, 64)
			if alvo ~= b then b.AnchorPoint = Vector2.zero; b.Position = UDim2.new(); b.Size = UDim2.fromScale(1, 1) end
			if guiVisivel(b) then algum = true end
		end
		grupo.Size = UDim2.fromOffset(math.min(360, grupoGui.AbsoluteSize.X - 16), 72)
		grupo.Visible = algum
	end
	local escondidos: { TextButton } = {}
	local ultimo = 0
	RunService.Heartbeat:Connect(function()
		local agora = os.clock()
		if agora - ultimo < INTERVALO then
			return
		end
		ultimo = agora
		organizar()
		local conjunto = {}
		local combate = Players.LocalPlayer:GetAttribute("InterfaceCombate") == true
		local aberto = combate or painelAberto(playerGui, conjunto)
		if aberto and #escondidos == 0 then
			for _, botao in ipairs(coletarAtalhos(playerGui)) do
				if botao.Visible then
					table.insert(escondidos, botao)
					for _, item in ipairs({botao, table.unpack(botao:GetDescendants())}) do
						if item:IsA("GuiObject") then
							if item:GetAttribute("U5BackgroundTransparency") == nil then item:SetAttribute("U5BackgroundTransparency", item.BackgroundTransparency) end
							if item:GetAttribute("U5BackgroundColor3") == nil then item:SetAttribute("U5BackgroundColor3", item.BackgroundColor3) end
							if (item:IsA("TextLabel") or item:IsA("TextButton")) and item:GetAttribute("U5TextTransparency") == nil then item:SetAttribute("U5TextTransparency", item.TextTransparency) end
							if (item:IsA("TextLabel") or item:IsA("TextButton")) and item:GetAttribute("U5TextColor3") == nil then item:SetAttribute("U5TextColor3", item.TextColor3) end
							if item:IsA("TextLabel") or item:IsA("TextButton") then TweenService:Create(item, FADE, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
							else TweenService:Create(item, FADE, {BackgroundTransparency = 1}):Play() end
						end
					end
					task.delay(0.17, function() if botao.Parent and (combate or painelAberto(playerGui, conjunto)) then botao.Visible = false end end)
				end
			end
		elseif not aberto and #escondidos > 0 then
			for _, botao in ipairs(escondidos) do
				if botao.Parent then
					for _, item in ipairs({botao, table.unpack(botao:GetDescendants())}) do
						if item:IsA("GuiObject") then
							local original = item:GetAttribute("U5BackgroundTransparency") or 0
							local corFundo = item:GetAttribute("U5BackgroundColor3")
							if corFundo then item.BackgroundColor3 = corFundo end
							if item:IsA("TextLabel") or item:IsA("TextButton") then
								local corTexto = item:GetAttribute("U5TextColor3")
								if corTexto then item.TextColor3 = corTexto end
								item.TextTransparency = item:GetAttribute("U5TextTransparency") or 0
								TweenService:Create(item, FADE, {BackgroundTransparency = original}):Play()
							else TweenService:Create(item, FADE, {BackgroundTransparency = original}):Play() end
						end
					end
					botao.Visible = true
				end
			end
			escondidos = {}
		end
	end)
end

return Atalhos
