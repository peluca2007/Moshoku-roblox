-- Adaptadores pequenos para telas V2 com listas roláveis. Estilo vem de Tema/Componentes.
local T = require(script.Parent.Tema)
local C = require(script.Parent.Componentes)

local Extra = {}

-- `rotulo` é a chave do atalho (ordem na faixa); `texto` é o que aparece (padrão = rotulo).
function Extra.atalho(parent, nome, icone, rotulo, ordem, texto)
	local botao = C.iconeBotao({ parent = parent, nome = nome, icone = icone, rotulo = texto or rotulo,
		tamanho = UDim2.fromOffset(68, 56), ordem = ordem })
	botao:SetAttribute("AtalhoMundo", rotulo)
	-- O rótulo de 20 px quebrava "VIAGEM" em duas linhas dentro de ~57 px: uma linha só, 14 px.
	botao.Rotulo.Position, botao.Rotulo.Size = UDim2.new(0, 1, .6, 0), UDim2.new(1, -2, .35, 0)
	botao.Rotulo.TextWrapped = false
	botao.Rotulo.TextSize = 14
	botao.Rotulo:SetAttribute("TextoBaseUIV2", 14)
	return botao
end

function Extra.painel(parent, nome, maximo, tamanho)
	local painel = C.painel({ parent = parent, nome = nome, tamanho = tamanho or UDim2.fromScale(.94, .86),
		posicao = UDim2.fromScale(.5, .5), ancora = Vector2.new(.5, .5), padding = T.espacamentos.padrao,
		losangos = true })
	C.aplicarEscala(painel)
	painel.Visible = false
	Instance.new("UISizeConstraint", painel).MaxSize = maximo
	return painel
end

function Extra.lista(parent, nome, posicao, tamanho, espaco)
	local lista = Instance.new("ScrollingFrame")
	lista.Name, lista.Position, lista.Size = nome, posicao, tamanho
	lista.BackgroundTransparency, lista.BorderSizePixel = 1, 0
	lista.ClipsDescendants = true
	lista.ZIndex = 4
	lista.ScrollBarThickness, lista.ScrollBarImageColor3 = 6, T.cores.secundario
	lista.CanvasSize, lista.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
	lista.ScrollingDirection, lista.Active = Enum.ScrollingDirection.Y, true
	lista.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder = UDim.new(0, espaco or T.espacamentos.pequeno), Enum.SortOrder.LayoutOrder
	layout.Parent = lista
	return lista, layout
end

function Extra.limpar(lista, layout)
	for _, filho in lista:GetChildren() do
		if filho ~= layout then filho:Destroy() end
	end
end

function Extra.texto(parent, valor, ordem, destaque)
	local label = C.texto({ parent = parent, texto = tostring(valor), ordem = ordem,
		secundario = destaque == "secundario", tamanho = UDim2.new(1, -8, 0, 0) })
	if type(destaque) == "string" then label.TextColor3 = T.cores[destaque] or T.cores.texto end
	return label
end

function Extra.titulo(parent, valor, ordem)
	return C.titulo({ parent = parent, texto = tostring(valor), ordem = ordem,
		tamanho = UDim2.new(1, -8, 0, 0) })
end

function Extra.botao(parent, nome, valor, ordem, ativo, acao)
	-- Largura da lista (não a do texto): o texto quebra linha e o botão cresce na altura.
	local botao = C.botao({ parent = parent, nome = nome, texto = tostring(valor), ordem = ordem,
		variante = "secundario", tamanho = UDim2.new(1, -8, 0, 0), aoClicar = if ativo then acao else nil })
	local rotulo = botao.Rotulo
 local titulo, descricao = tostring(valor):match("^(.-) · (.+)$")
 if not titulo then titulo, descricao = tostring(valor):match("^(.-) %((.+)%)$") end
 if titulo then rotulo.Text = titulo .. "\n" .. descricao end
	-- Mede o conteúdo na largura real; o rótulo ocupa toda a altura útil e fica centrado.
	rotulo.AutomaticSize = Enum.AutomaticSize.None
	rotulo.Position, rotulo.Size = UDim2.fromOffset(16, 8), UDim2.new(1, -32, 1, -16)
	rotulo.TextWrapped, rotulo.TextYAlignment, rotulo.TextXAlignment = true, Enum.TextYAlignment.Center, Enum.TextXAlignment.Left
	local function medir()
		local largura = math.max(44, parent.AbsoluteSize.X - 40)
		local altura = game:GetService("TextService"):GetTextSize(rotulo.Text, rotulo.TextSize, Enum.Font.SourceSansSemibold, Vector2.new(largura, 10000)).Y
		botao.Size = UDim2.new(1, -8, 0, math.max(48, altura + 16))
	end
	botao:GetPropertyChangedSignal("AbsoluteSize"):Connect(medir)
	rotulo:GetPropertyChangedSignal("Text"):Connect(medir)
	rotulo:GetPropertyChangedSignal("TextSize"):Connect(medir)
	medir()
	botao:SetAttribute("Desabilitado", not ativo)
	botao.Active, botao.Selectable = ativo, ativo
	return botao
end

function Extra.fechar(parent, alvo, ordem)
	local b = C.botao({ parent = parent, nome = "Fechar", texto = "Fechar", ordem = ordem,
		tamanho = UDim2.fromOffset(88, 48), variante = "secundario", aoClicar = function() alvo.Visible = false end })
	-- 88 px não comportam o recuo padrão do rótulo (24+24): centraliza o texto no botão todo.
	b.Rotulo.Position, b.Rotulo.Size, b.Rotulo.TextWrapped = UDim2.new(), UDim2.fromScale(1, 1), false
	return b
end

function Extra.tituloPainel(parent, texto, ordem)
	return C.titulo({ parent = parent, texto = texto, ordem = ordem,
		tamanho = UDim2.new(1, 0, 0, 0) })
end

return Extra
