-- Ajuda local; não envia intenção nem consulta remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local Extra = require(script.Parent.UI.ExtraTelas)
local Conteudo = require(ReplicatedStorage.Shared.AjudaConteudo)
local View = {}
local ATRIBUTO_DICA = "AjudaDicaVista"

function View.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existente = playerGui:FindFirstChild("AjudaJogo")
	if existente then return existente end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AjudaJogo", false, 60
	gui.ZIndexBehavior, gui.Parent = Enum.ZIndexBehavior.Sibling, playerGui
	-- A posição do atalho é da barra única (client/Atalhos), que adota este botão pelo atributo AtalhoMundo.
	local atalho = Extra.atalho(gui, "AtalhoAjuda", "?", "?", 1, "AJUDA")
	local painel = Extra.painel(gui, "Painel", Vector2.new(720, 700), UDim2.fromScale(.94, .9))
	local titulo = Extra.tituloPainel(painel.Conteudo, "AJUDA · Moshoku", 1)
	titulo.Position, titulo.Size = UDim2.fromOffset(0, 0), UDim2.new(1, -100, 0, 42)
	local fechar = Extra.fechar(painel.Conteudo, painel, 2)
	fechar.Modal = true -- preserva a captura de mouse do painel original
	fechar.Position = UDim2.new(1, -96, 0, 0)
	local botoes, selecionado = {}, nil
	local abaContainer = Instance.new("Frame")
	abaContainer.Name, abaContainer.Position, abaContainer.Size = "Abas", UDim2.fromOffset(0, 52), UDim2.new(1, 0, 0, 100)
	abaContainer.BackgroundTransparency, abaContainer.Parent = 1, painel.Conteudo
	local texto = Instance.new("ScrollingFrame")
	texto.Name, texto.Position, texto.Size = "Texto", UDim2.fromOffset(0, 160), UDim2.new(1, 0, 1, -160)
	texto.BackgroundTransparency, texto.BorderSizePixel, texto.ScrollBarThickness = 1, 0, 6
	texto.ZIndex = 4
	texto.ScrollBarImageColor3 = T.cores.secundario
	texto.CanvasSize, texto.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
	texto.ScrollingDirection, texto.Active, texto.Selectable = Enum.ScrollingDirection.Y, true, true
	texto.Parent = painel.Conteudo
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, T.espacamentos.medio), Enum.SortOrder.LayoutOrder, texto
	-- A altura do painel acompanha o texto da aba (sem bloco vazio embaixo); limitada pela tela.
	local ALTURA_CABECALHO, ALTURA_MARGEM = 160, 2 * 16 + 14
	local function ajustarAltura()
		local camera = workspace.CurrentCamera
		local escala = painel:FindFirstChildOfClass("UIScale")
		local fator = if escala and escala.Scale > 0 then escala.Scale else 1 -- medidas absolutas já vêm escaladas
		local tela = (camera and camera.ViewportSize.Y or 1080) * .9 / fator
		local desejada = ALTURA_CABECALHO + layout.AbsoluteContentSize.Y / fator + ALTURA_MARGEM
		painel.Size = UDim2.new(.94, 0, 0, math.clamp(desejada, 320, math.max(320, tela)))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ajustarAltura)
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarAltura) end
	local function selecionar(indice)
		selecionado = indice
		for i, b in botoes do
			local ativo = i == indice
			b:SetAttribute("Desabilitado", false)
			b.BackgroundColor3 = T.cores.painel
			b.Rotulo.TextColor3 = if ativo then T.cores.titulo else T.cores.texto
			b.Rotulo.Text = (if ativo then "• " else "") .. Conteudo.abas[i].titulo
		end
		Extra.limpar(texto, layout)
		for ordem, paragrafo in Conteudo.abas[indice].paragrafos do
			Extra.texto(texto, paragrafo, ordem)
		end
		-- Crédito obrigatório (CC BY 3.0) dos ícones da luta; ver docs/ARTE.md.
		Extra.texto(texto, "Créditos · Ícones de habilidades: game-icons.net (CC BY 3.0) por Lorc, Delapouite, Skoll, Willdabeast, Carl Olsen, Zeromancer e sbed.", 200)
		-- Crédito obrigatório (CC BY 3.0) do modelo do Treant; ver tools/blender/kits/FONTES.md.
		Extra.texto(texto, "Créditos · Modelo do Treant: Evil Tree Creature, por Benji Smith (CC BY 3.0, OpenGameArt).", 201)
		if Conteudo.abas[indice].id == "inicio" then
			C.botao({ parent = texto, nome = "ReverAbertura", texto = "Rever abertura", variante = "secundario",
				tamanho = UDim2.new(1, -8, 0, 48), ordem = 100, aoClicar = function()
					painel.Visible = false
					require(script.Parent.AberturaFluxo).rever()
				end })
		end
		texto.CanvasPosition = Vector2.zero
		task.defer(ajustarAltura)
	end
	for i, aba in Conteudo.abas do
		local b = C.botao({ parent = abaContainer, nome = aba.id, texto = aba.titulo, ordem = i, variante = "secundario", tamanho = UDim2.new(.5, -6, 0, 48) }) -- tamanho fixo: o rótulo muda ao selecionar e redimensionaria o botão
		local coluna, linha = (i - 1) % 2, math.floor((i - 1) / 2)
		b.Size, b.Position = UDim2.new(.5, -6, 0, 48), UDim2.new(coluna * .5, if coluna == 0 then 0 else 6, 0, linha * 52)
		b.Activated:Connect(function() selecionar(i) end)
		botoes[i] = b
	end
	fechar.NextSelectionDown = botoes[2]
	for i, b in botoes do
		b.NextSelectionLeft = botoes[if i % 2 == 0 then i - 1 else i]
		b.NextSelectionRight = botoes[if i % 2 == 1 then i + 1 else i]
		b.NextSelectionUp = if i > 2 then botoes[i - 2] else fechar
		b.NextSelectionDown = if i <= 2 then botoes[i + 2] else texto
	end
	texto.NextSelectionUp, texto.NextSelectionDown = botoes[3], fechar
	selecionar(1)
	local focoAnterior
	local dica
	local function fecharPainel()
		painel.Visible = false
		local foco = GuiService.SelectedObject
		if foco and foco:IsDescendantOf(painel) then GuiService.SelectedObject = if focoAnterior and focoAnterior.Parent then focoAnterior else atalho end
	end
	fechar.Activated:Connect(fecharPainel)
	atalho.Activated:Connect(function()
		if painel.Visible then fecharPainel(); return end
		focoAnterior = GuiService.SelectedObject
		painel.Visible = true
		if dica then dica(); dica = nil end
		if string.find(UserInputService:GetLastInputType().Name, "Gamepad") then GuiService.SelectedObject = botoes[1] end
	end)
	local entrada = UserInputService.InputBegan:Connect(function(input)
		if painel.Visible and input.KeyCode == Enum.KeyCode.ButtonB then fecharPainel() end
	end)
	gui.Destroying:Connect(function() fecharPainel(); entrada:Disconnect() end)
	if not player:GetAttribute(ATRIBUTO_DICA) then
		player:SetAttribute(ATRIBUTO_DICA, true)
  dica = C.aviso({parent=gui,tipo="info",titulo="Ajuda",icone="ajuda",detalhe=Conteudo.dica,duracao=Conteudo.duracaoDica})
	end
	return gui
end

return View
