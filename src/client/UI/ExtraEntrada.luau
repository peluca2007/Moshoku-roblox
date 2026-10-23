-- Complementos exclusivos da entrada U4; cores/fontes/geometria vêm do tema V2.
local T = require(script.Parent.Tema)
local C = require(script.Parent.Componentes)
local E = {}
E.T = T
E.C = C
function E.estilizar(obj, fonte)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		obj.FontFace = fonte or T.fontes.rotulo
		obj.TextSize = math.max(T.tamanhos.corpo, obj.TextSize)
	end
	if obj:IsA("TextButton") or obj:IsA("TextBox") then
		local limite = Instance.new("UISizeConstraint")
		limite.Name = "ToqueMinimoEntrada"
		limite.MinSize = Vector2.new(T.toqueMinimo, T.toqueMinimo)
		limite.Parent = obj
	end
end
function E.rolagem(lista)
	lista.ScrollBarThickness = 8
	lista.ScrollBarImageColor3 = T.cores.ouro
	lista.ScrollingDirection = Enum.ScrollingDirection.Y
	lista.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.Parent = lista
end
-- Cartão usa o nome canônico completo e descrição do catálogo, sem inventar regras.
function E.cartao(parent, entrada, ordem)
	local data = entrada and entrada.data or {}
	local completo = data.name or "Escolher"
	local curto = string.match(completo, "^(.-) %(") or string.match(completo, "^(.-) /") or completo
	local b = C.botao({parent=parent, nome="CartaoEscolha", texto="", variante="secundario",
		tamanho=UDim2.new(1, 0, 0, 116), ordem=ordem})
	b.Rotulo.Visible = false
	local faixa = Instance.new("Frame")
	faixa.Size, faixa.Position = UDim2.new(0, T.espessuras.destaque, 1, -16), UDim2.fromOffset(6, 8)
	faixa.BackgroundColor3, faixa.BorderSizePixel, faixa.ZIndex = T.cores.ouro, 0, 6
	faixa.Parent = b
	local titulo = C.titulo({parent=b, texto=curto, posicao=UDim2.fromOffset(18,8), tamanho=UDim2.new(1,-30,0,28)})
	titulo.TextSize = T.tamanhos.subtitulo
	titulo.AutomaticSize = Enum.AutomaticSize.None
	titulo.TextWrapped = false
	titulo.TextTruncate = Enum.TextTruncate.AtEnd
	local livro = C.texto({parent=b, texto="Livro · " .. completo, secundario=true,
		posicao=UDim2.fromOffset(18,38), tamanho=UDim2.new(1,-30,0,24)})
	livro.AutomaticSize = Enum.AutomaticSize.None
	livro.TextTruncate = Enum.TextTruncate.AtEnd
	livro.TextWrapped = false
	local descricao = data.description or (data.traits and data.traits[1]) or data.effect or "Consulte esta escolha no livro."
	if type(descricao) ~= "string" then descricao = "Consulte esta escolha no livro." end
	local linha = C.texto({parent=b, texto=descricao, posicao=UDim2.fromOffset(18,70), tamanho=UDim2.new(1,-30,0,34)})
	linha.AutomaticSize = Enum.AutomaticSize.None
	linha.TextWrapped = false
	linha.TextTruncate = Enum.TextTruncate.AtEnd
	return b
end
function E.ornamento(parent)
	local fio = Instance.new("Frame")
	fio.Name, fio.Size = "Ornamento", UDim2.new(1,0,0,1)
	fio.BackgroundColor3, fio.BorderSizePixel = T.cores.ouro, 0
	fio.Parent = parent
	for _,x in {0, .5, 1} do
		local d = Instance.new("Frame")
		d.Size, d.Rotation = UDim2.fromOffset(6,6), 45
		d.Position, d.AnchorPoint = UDim2.fromScale(x,0), Vector2.new(.5,.5)
		d.BackgroundColor3, d.BorderSizePixel, d.Parent = T.cores.ouro, 0, fio
	end
	return fio
end
return E
