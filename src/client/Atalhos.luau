-- Barra única de atalhos do canto superior direito: MENU, DIÁRIO, ÁRVORES, CONTA, AJUDA (ordem e medidas
-- em Regras/AtalhosLayout, com spec). Um painel do kit (C.painel) com UIListLayout; os botões ficam
-- lado a lado sem sobreposição.
--
-- Registro explícito, sem varredura periódica:
--   * Atalhos.criar{...}: cria o botão direto na barra (MENU em InicioView, ÁRVORES em ArvoresView);
--   * botões de outras views (Extra.atalho marca `AtalhoMundo`) são adotados uma vez ao iniciar e, depois,
--     pelo evento PlayerGui.DescendantAdded; o nome da Instance (AtalhoRun, AtalhoAjuda, AtalhoConta...)
--     não muda, só o pai passa a ser a barra.
-- A barra reorganiza apenas por eventos (Visible dos atalhos, tela, painéis grandes, atributo
-- `InterfaceCombate`). Fica escondida na luta, com painel grande aberto ou por pedido de uma view
-- (Atalhos.ocultar). Só apresentação local.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(script.Parent.UI.Componentes)
local L = require(ReplicatedStorage.Shared.Regras.AtalhosLayout)

local Atalhos = {}

local FRACAO_X, FRACAO_Y = 0.6, 0.5 -- um painel desse tamanho conta como "painel grande aberto"

local jogador = Players.LocalPlayer
local gui: ScreenGui?, barra: Frame?, conteudo: Frame?
local registrados: { [GuiButton]: string } = {}
local paineis: { [Frame]: boolean } = {}
local guisObservadas: { [Instance]: boolean } = {}
local motivos: { [string]: boolean } = {} -- pedidos de ocultar vindos das views (menu, árvores...)

local function guiVisivel(objeto: GuiObject): boolean
	local atual: Instance? = objeto
	while atual do
		if atual:IsA("GuiObject") and not atual.Visible then return false end
		if atual:IsA("ScreenGui") then return atual.Enabled end
		atual = atual.Parent
	end
	return false
end

local function larguraTela(): number
	local camera = workspace.CurrentCamera
	local daTela = if gui and gui.AbsoluteSize.X > 0 then gui.AbsoluteSize.X else (camera and camera.ViewportSize.X or 1920)
	return daTela
end

local function painelGrandeAberto(): boolean
	local camera = workspace.CurrentCamera
	local tela = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	for painel in paineis do
		if painel.AbsoluteSize.X >= tela.X * FRACAO_X and painel.AbsoluteSize.Y >= tela.Y * FRACAO_Y and guiVisivel(painel) then
			return true
		end
	end
	return false
end

local function escondida(): boolean
	return next(motivos) ~= nil or jogador:GetAttribute("InterfaceCombate") == true or painelGrandeAberto()
end

local function reorganizar()
	if not barra or not conteudo then return end
	local lista: { GuiButton } = {}
	local rotulos: { string } = {}
	for botao, rotulo in registrados do
		if botao.Parent == conteudo and botao.Visible then
			table.insert(lista, botao)
			table.insert(rotulos, rotulo)
		end
	end
	local medidas = L.medidas(#lista, larguraTela())
	for posicao, indice in L.ordem(rotulos) do
		local botao = lista[indice]
		botao.LayoutOrder = posicao
		botao.Size = UDim2.fromOffset(medidas.largura, medidas.altura)
		local rotuloTexto = botao:FindFirstChild("Rotulo")
		if rotuloTexto and rotuloTexto:IsA("TextLabel") then rotuloTexto.TextSize = L.tamanhoTexto(medidas.largura) end
	end
	barra.Size = UDim2.fromOffset(medidas.barra, medidas.altura + 2 * L.PADDING)
	barra.Visible = #lista > 0 and not escondida()
end

local function estilizar(botao: GuiButton)
	local rotulo = botao:FindFirstChild("Rotulo")
	if rotulo and rotulo:IsA("TextLabel") then
		rotulo.Position, rotulo.Size = UDim2.fromScale(0.04, 0.58), UDim2.fromScale(0.92, 0.38)
		rotulo.TextWrapped, rotulo.TextTruncate = false, Enum.TextTruncate.None
		rotulo.TextSize = 14
		rotulo:SetAttribute("TextoBaseUIV2", 14)
	end
	local icone = botao:FindFirstChild("Icone")
	if icone and icone:IsA("TextLabel") then icone.TextScaled = false; icone.TextSize = 22 end
end

local function garantir()
	if barra then return end
	local playerGui = jogador:WaitForChild("PlayerGui")
	local nova = Instance.new("ScreenGui")
	nova.Name, nova.ResetOnSpawn, nova.DisplayOrder = "AtalhosMundo", false, 10
	nova.IgnoreGuiInset = false -- abaixo da faixa de botões do Roblox
	nova.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	nova.Parent = playerGui
	gui = nova
	local moldura = C.painel({ parent = nova, nome = "BarraAtalhos", padding = 0, sombra = false,
		tamanho = UDim2.fromOffset(L.LARGURA + 2 * L.PADDING, L.ALTURA + 2 * L.PADDING),
		posicao = UDim2.new(1, -L.MARGEM, 0, L.MARGEM), ancora = Vector2.new(1, 0) })
	moldura.Visible = false
	barra, conteudo = moldura, moldura.Conteudo
	local lista = Instance.new("UIListLayout")
	lista.FillDirection, lista.SortOrder = Enum.FillDirection.Horizontal, Enum.SortOrder.LayoutOrder
	lista.Padding = UDim.new(0, L.ESPACO)
	lista.HorizontalAlignment, lista.VerticalAlignment = Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
	lista.Parent = conteudo
	nova:GetPropertyChangedSignal("AbsoluteSize"):Connect(reorganizar)
	jogador:GetAttributeChangedSignal("InterfaceCombate"):Connect(reorganizar)
	local function camera()
		local atual = workspace.CurrentCamera
		if atual then atual:GetPropertyChangedSignal("ViewportSize"):Connect(reorganizar) end
	end
	camera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() camera(); reorganizar() end)
end

local function adotar(botao: GuiButton)
	if registrados[botao] or not conteudo then return end
	local rotulo = botao:GetAttribute("AtalhoMundo")
	if type(rotulo) ~= "string" then return end
	registrados[botao] = rotulo
	botao.AnchorPoint, botao.Position = Vector2.zero, UDim2.new()
	estilizar(botao)
	botao.Parent = conteudo
	botao:GetPropertyChangedSignal("Visible"):Connect(reorganizar)
	botao.Destroying:Connect(function() registrados[botao] = nil; reorganizar() end)
	reorganizar()
end

-- Painel grande do kit (C.painel marca PainelUIV2): observa o que muda a sua visibilidade e tamanho.
local function observarPainel(painel: Frame)
	if paineis[painel] or (gui and painel:IsDescendantOf(gui)) then return end
	paineis[painel] = true
	painel:GetPropertyChangedSignal("AbsoluteSize"):Connect(reorganizar)
	painel.Destroying:Connect(function() paineis[painel] = nil; reorganizar() end)
	local atual: Instance? = painel
	while atual do
		if atual:IsA("GuiObject") and not guisObservadas[atual] then
			guisObservadas[atual] = true
			atual:GetPropertyChangedSignal("Visible"):Connect(reorganizar)
		elseif atual:IsA("ScreenGui") and not guisObservadas[atual] then
			guisObservadas[atual] = true
			atual:GetPropertyChangedSignal("Enabled"):Connect(reorganizar)
		end
		atual = atual.Parent
	end
	reorganizar()
end

local function tratar(objeto: Instance)
	if not objeto:IsA("GuiObject") then return end
	if objeto:IsA("GuiButton") and objeto:GetAttribute("AtalhoMundo") ~= nil then
		adotar(objeto)
	elseif objeto:IsA("Frame") and objeto:GetAttribute("PainelUIV2") == true then
		observarPainel(objeto)
	end
end

-- Cria um atalho direto na barra. def: { nome, rotulo (chave da ordem), texto (opcional), icone, aoClicar }.
function Atalhos.criar(def: { nome: string, rotulo: string, texto: string?, icone: string?, aoClicar: (() -> ())? }): GuiButton
	garantir()
	local botao = C.iconeBotao({ parent = conteudo, nome = def.nome, icone = def.icone or "run", rotulo = def.texto or def.rotulo,
		tamanho = UDim2.fromOffset(L.LARGURA, L.ALTURA), aoClicar = def.aoClicar })
	botao:SetAttribute("AtalhoMundo", def.rotulo)
	adotar(botao)
	return botao
end

-- Uma view pede para esconder (ou mostrar de novo) a barra enquanto algo ocupa a tela (`motivo` livre).
function Atalhos.ocultar(motivo: string, oculto: boolean)
	motivos[motivo] = if oculto then true else nil
	reorganizar()
end

-- A barra poderia aparecer agora (sem luta nem painel grande)? Ignora o pedido do próprio menu.
function Atalhos.livre(): boolean
	if jogador:GetAttribute("InterfaceCombate") == true or painelGrandeAberto() then return false end
	for motivo in motivos do
		if motivo ~= "menu" then return false end
	end
	return true
end

function Atalhos.start()
	garantir()
	local playerGui = jogador:WaitForChild("PlayerGui")
	for _, tela in playerGui:GetChildren() do
		if tela:IsA("ScreenGui") and tela ~= gui then
			for _, item in tela:GetDescendants() do tratar(item) end
		end
	end
	playerGui.DescendantAdded:Connect(function(item)
		-- O atributo é marcado logo depois de criar a Instance: lê no próximo ciclo.
		if item:IsA("GuiObject") then task.defer(tratar, item) end
	end)
	reorganizar()
end

return Atalhos
