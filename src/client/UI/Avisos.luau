-- Implementação privada da fila de Componentes.aviso; nunca cria ScreenGui.
-- Uma fila só para todas as telas: banners de telas diferentes (objetivo, provação, avisos)
-- ocupam a mesma faixa e, com filas separadas, apareciam um por cima do outro.
local GuiService = game:GetService("GuiService")
local T = require(script.Parent.Tema)
return function(C, criar, animador)
	local fila = { itens = {}, ativo = nil }
	local vigiados = setmetatable({}, { __mode = "k" })
	return function(p)
		assert(p.parent, "parent obrigatório")
		local parent = p.parent
		if not vigiados[parent] then
			vigiados[parent] = true
			-- Tela destruída leva junto os banners dela (ativo e pendentes); as outras seguem.
			parent.Destroying:Once(function()
				for _, outro in table.clone(fila.itens) do
					if outro.parent == parent then outro.cancelar() end
				end
				if fila.ativo and fila.ativo.parent == parent then fila.ativo.cancelar() end
			end)
		end
		-- Repetição idêntica (mesmo título/detalhe) do aviso ativo ou do último da fila é ignorada:
		-- sem isso, um evento repetido (ex.: "Pego!" a cada pulso do servidor) empilhava dezenas de banners.
		local chave = tostring(p.tipo) .. "|" .. tostring(p.titulo) .. "|" .. tostring(p.detalhe)
		local ultimo = fila.itens[#fila.itens] or fila.ativo
		if ultimo and not ultimo.cancelado and ultimo.chave == chave then return ultimo.cancelar end
		local item = { cancelado = false, chave = chave, parent = parent }
		local proximo
		local function terminar()
			if item.cancelado then return end
			item.cancelado = true
			if fila.ativo ~= item then
				local i = table.find(fila.itens, item)
				if i then table.remove(fila.itens, i) end
			end
			if item.raiz then item.raiz:Destroy() end
			if fila.ativo == item then fila.ativo = nil; proximo() end
		end
		item.cancelar = terminar
		proximo = function()
			if fila.ativo then return end
			local seguinte = table.remove(fila.itens, 1)
			if not seguinte then return end
			if seguinte.cancelado then proximo(); return end
			seguinte.mostrar()
		end
		item.mostrar = function()
			fila.ativo = item
			local destaque = p.corDestaque or T.cores[p.tipo or "info"] or T.cores.info
			local grande = p.destaque == true
			local faixas = T.faixasAviso(parent.AbsoluteSize.X, grande)
			local altura = faixas.altura
			-- Celular (largura < 700): a faixa de atalhos ocupa o alto; o banner desce abaixo dela.
			-- `topo` vale abaixo da faixa do Roblox; tela com IgnoreGuiInset soma a faixa.
			local tela = if parent:IsA("ScreenGui") then parent else parent:FindFirstAncestorOfClass("ScreenGui")
			local topo = faixas.topo + (if tela and tela.IgnoreGuiInset then GuiService:GetGuiInset().Y else 0)
			local icones = { sucesso = "confirmar", perigo = "fechar", alerta = "mapa", info = "run" }
			local grupo = criar("CanvasGroup", { Name = "AvisoUIV2", BackgroundTransparency = 1,
				Size = UDim2.new(1, -32, 0, altura), Position = UDim2.new(0.5, 0, 0, -altura-24),
				AnchorPoint = Vector2.new(0.5, 0), GroupTransparency = 1, ZIndex = 20 }, parent)
			item.raiz = grupo
			grupo.Destroying:Once(function()
				if item.cancelado then return end
				item.cancelado = true
				if fila.ativo == item then fila.ativo = nil; task.defer(proximo) end
			end)
			criar("UISizeConstraint", { MaxSize = Vector2.new(if grande then 520 else 600, altura) }, grupo)
			local painel = C.painel({ parent = grupo, nome = "Banner", tamanho = UDim2.fromScale(1, 1), padding = 12, sombra = true, losangos = true, zIndex = 20 })
			criar("Frame", { Name = "Destaque", Size = UDim2.new(0, T.espessuras.destaque, 1, -12), Position = UDim2.fromOffset(4, 6),
				BackgroundColor3 = destaque, BorderSizePixel = 0, ZIndex = 22 }, painel)
			local diametro = if grande then 72 else 48
			local circulo = criar("Frame", { Name = "CirculoIcone", BackgroundColor3 = destaque, BackgroundTransparency = 0.82,
				BorderSizePixel = 0, Size = UDim2.fromOffset(diametro, diametro), Position = UDim2.fromOffset(4, if grande then 18 else 12), ZIndex = 22 }, painel.Conteudo)
			criar("UICorner", { CornerRadius = UDim.new(1, 0) }, circulo)
			criar("TextLabel", { Name = "Icone", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				Text = T.icone(p.icone or icones[p.tipo or "info"] or "run"), FontFace = T.FONTE_ICONE,
				TextColor3 = destaque, TextSize = if grande then 46 else 30, ZIndex = 23 }, circulo)
			if grande then
				local brilho = criar("UIStroke", { Color = T.cores.ouroClaro, Thickness = 5, Transparency = 0.6 }, circulo)
				criar("UIGradient", { Transparency = NumberSequence.new(0.2, 0.9), Rotation = 90 }, brilho)
			end
			local inicioTexto = diametro + 18
			local titulo = C.titulo({ parent = painel.Conteudo, texto = p.titulo or "Aviso", ordem = 1, posicao = UDim2.fromOffset(inicioTexto, 0), tamanho = UDim2.new(1, -inicioTexto, 0, 28) })
			titulo.ZIndex = 23; titulo.TextColor3 = destaque; titulo.TextSize = T.tamanhos.subtitulo
			local detalhe = C.texto({ parent = painel.Conteudo, texto = p.detalhe or "", posicao = UDim2.fromOffset(inicioTexto, 30), tamanho = UDim2.new(1, -inicioTexto, 0, altura-58) })
			detalhe.ZIndex = 23; detalhe.AutomaticSize = Enum.AutomaticSize.None; detalhe.TextTruncate = Enum.TextTruncate.AtEnd
			local animar = animador(grupo)
			animar({ Position = UDim2.new(0.5, 0, 0, topo), GroupTransparency = 0 })
			task.delay(math.max(0, p.duracao or T.avisoDuracao) + T.tween, function()
				if item.cancelado then return end
				animar({ Position = UDim2.new(0.5, 0, 0, -altura-24), GroupTransparency = 1 })
				task.delay(T.tween, terminar)
			end)
		end
		table.insert(fila.itens, item)
		proximo()
		return terminar
	end
end
