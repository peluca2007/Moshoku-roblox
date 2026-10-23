-- Tela das árvores (pedido do Pedro, 09/10/2026): a árvore de progressão do site
-- (/arvores) dentro do jogo, no estilo Livro Noite. À esquerda a constelação
-- (centro → Magia/Corpo/Utilidade → subgrupos → árvores, selo de cada árvore aceso
-- quando aberta); à direita a página da árvore com os ranks, maestrias,
-- habilidades e talentos. Só intenção: "abrirRank" e "aprender" vão ao servidor,
-- que valida (Regras/Progressao). PA infinito e teto no Intermediário, por ora.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Estilo = require(Shared:WaitForChild("Estilo"))
local Catalogo = require(Shared:WaitForChild("Livro"):WaitForChild("Catalogo"))
local Identidade = require(Shared:WaitForChild("Livro"):WaitForChild("Identidade"))
local Regras = require(Shared:WaitForChild("Livro"):WaitForChild("Regras"))
local Progressao = require(Shared:WaitForChild("Regras"):WaitForChild("Progressao"))
local Execucao = require(Shared:WaitForChild("Regras"):WaitForChild("Execucao"))
local Planos = require(Shared:WaitForChild("PlanosArvores"))

local ArvoresView = {}

local CATEGORIAS = {
	{ id = "corpo", nome = "CORPO", inicio = 195, fim = 290 },
	{ id = "utilidade", nome = "UTILIDADE", inicio = 305, fim = 375 },
	{ id = "magia", nome = "MAGIA", inicio = 25, fim = 165 },
}
local COR_CATEGORIA = {
	corpo = Estilo.CAPITULOS[4],
	utilidade = Estilo.CAPITULOS[6],
	magia = Estilo.CAPITULOS[2],
}
local KANJI_FONTE = Font.fromName("SourceSansPro", Enum.FontWeight.Bold)

local function new(class: string, parent: Instance?, props: { [string]: any }?): any
	local object = Instance.new(class)
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function texto(parent, props)
	local l = new("TextLabel", parent, {
		BackgroundTransparency = 1,
		TextColor3 = Estilo.TINTA,
		FontFace = Estilo.ROTULO,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})
	for k, v in props do
		l[k] = v
	end
	return l
end

local function cantos(parent, raio: number?)
	new("UICorner", parent, { CornerRadius = UDim.new(0, raio or 8) })
end

local function lista(parent, espaco: number?)
	new("UIListLayout", parent, { Padding = UDim.new(0, espaco or 6), SortOrder = Enum.SortOrder.LayoutOrder })
end

local function botao(parent, rotulo: string, fundo: Color3, aoClicar: () -> (), largura: number?)
	local b = new("TextButton", parent, {
		Size = UDim2.fromOffset(largura or 150, 44), BackgroundColor3 = fundo, AutoButtonColor = true,
		Text = rotulo, TextColor3 = Estilo.TINTA, FontFace = Estilo.ROTULO_FORTE, TextSize = 14,
	})
	cantos(b, 6)
	b.Activated:Connect(aoClicar)
	return b
end

local function tem(listaIds: { string }?, id: string): boolean
	return listaIds ~= nil and table.find(listaIds, id) ~= nil
end

-- Linha de custo de uma carta do livro.
local function custos(dados): string
	local partes = {}
	if dados.actions and dados.actions.normal then
		table.insert(partes, dados.actions.normal .. (if dados.actions.normal == 1 then " AÇÃO" else " AÇÕES"))
	end
	for _, campo in { { "pmCost", "PM" }, { "ptCost", "PT" }, { "ppCost", "PP" } } do
		if dados[campo[1]] and dados[campo[1]] > 0 then
			table.insert(partes, dados[campo[1]] .. " " .. campo[2])
		end
	end
	if dados.range then
		table.insert(partes, Estilo.maiusculas(dados.range))
	end
	if dados.paCost then
		table.insert(partes, if dados.paCost == 0 then "GRÁTIS" else dados.paCost .. " PA")
	end
	return table.concat(partes, " • ")
end

function ArvoresView.start(state, mostrarAtalhosDeCombate: boolean?)
	local player = Players.LocalPlayer
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "Arvores", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8, Enabled = false,
	})

	-- Botão no canto para abrir.
	local atalhoGui = new("ScreenGui", player.PlayerGui, { Name = "ArvoresAtalho", ResetOnSpawn = false, DisplayOrder = 4 })
	local atalho = botao(atalhoGui, "ÁRVORES", Estilo.DESTAQUE_FUNDO, function()
		gui.Enabled = not gui.Enabled
	end, 132)
	atalho.Name = "AbrirArvores"
	atalho.Position = UDim2.fromOffset(176, 14)
	atalho.FontFace = Estilo.GRITO
	atalho.TextSize = 16
	if mostrarAtalhosDeCombate == true then
		-- Atalhos legados opcionais; reabrir a árvore não deve iniciar encontros.
		local treino = botao(atalhoGui, "TREINO", Estilo.PERIGO_FUNDO, function()
			state.send("iniciarTreino", {})
		end, 110)
		treino.Name = "IniciarTreino"
		treino.Position = UDim2.fromOffset(316, 14)
		treino.FontFace = Estilo.GRITO
		treino.TextSize = 16
		local luta = botao(atalhoGui, "LUTA", Estilo.DESTAQUE_FUNDO, function()
			state.send("iniciarLuta", {})
		end, 90)
		luta.Name = "IniciarLuta"
		luta.Position = UDim2.fromOffset(436, 14)
		luta.FontFace = Estilo.GRITO
		luta.TextSize = 16
		local duelo = botao(atalhoGui, "DUELO", Estilo.PERIGO_FUNDO, function()
			state.send("iniciarDuelo", {})
		end, 96)
		duelo.Name = "IniciarDuelo"
		duelo.Position = UDim2.fromOffset(536, 14)
		duelo.FontFace = Estilo.GRITO
		duelo.TextSize = 16
	end

	-- Fundo: a noite estrelada do mapa do site.
	local fundo = new("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Estilo.MESA_FUNDO, BackgroundTransparency = 0 })
	local aleatorio = Random.new(7)
	for _ = 1, 160 do
		local t = aleatorio:NextInteger(1, 3)
		new("Frame", fundo, {
			Size = UDim2.fromOffset(t, t), Position = UDim2.fromScale(aleatorio:NextNumber(), aleatorio:NextNumber()),
			BackgroundColor3 = Estilo.TINTA, BackgroundTransparency = aleatorio:NextNumber(0.35, 0.85), BorderSizePixel = 0,
		})
	end

	-- Cabeçalho.
	-- Começa depois dos botões do Roblox no canto superior esquerdo.
	local topo = new("Frame", fundo, { Size = UDim2.new(1, -210, 0, 64), Position = UDim2.fromOffset(190, 12), BackgroundTransparency = 1 })
	texto(topo, { Text = "ÁRVORES DE PROGRESSÃO", FontFace = Estilo.GRITO, TextSize = 32, Size = UDim2.new(1, -200, 0, 36), AutomaticSize = Enum.AutomaticSize.None })
	local subtitulo = texto(topo, {
		Name = "Subtitulo", Text = "", Position = UDim2.fromOffset(0, 38), TextColor3 = Estilo.TINTA_SUAVE, Size = UDim2.new(1, -200, 0, 20),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	local fechar = botao(topo, "FECHAR (T)", Estilo.BOTAO, function()
		gui.Enabled = false
	end, 140)
	fechar.AnchorPoint, fechar.Position = Vector2.new(1, 0), UDim2.new(1, 0, 0, 4)

	-- Mapa (esquerda) e página (direita).
	local mapa = new("Frame", fundo, {
		Name = "Mapa", Position = UDim2.new(0, 20, 0, 90), Size = UDim2.new(0.56, -30, 1, -110), BackgroundTransparency = 1,
	})
	local quadro = new("Frame", mapa, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	})
	new("UIAspectRatioConstraint", quadro, { AspectRatio = 1 })
	local pagina = new("ScrollingFrame", fundo, {
		Name = "Pagina", Position = UDim2.new(0.56, 0, 0, 90), Size = UDim2.new(0.44, -20, 1, -110),
		BackgroundColor3 = Estilo.PAPEL, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = Estilo.DESTAQUE,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	cantos(pagina, 10)
	new("UIStroke", pagina, { Color = Estilo.FIO_COR, Thickness = 1.5 })
	new("UIPadding", pagina, { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 24), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) })
	lista(pagina, 10)

	-- Constelação ----------------------------------------------------------

	local arvores = {}
	for _, entrada in Catalogo.POR_ESPECIE.tree do
		table.insert(arvores, entrada)
	end

	local function polar(angulo: number, raio: number): Vector2
		local r = math.rad(angulo)
		return Vector2.new(0.5 + math.cos(r) * raio, 0.5 + math.sin(r) * raio)
	end

	local function linhaEntre(a: Vector2, b: Vector2, cor: Color3, transparencia: number)
		local meio = (a + b) / 2
		local delta = b - a
		return new("Frame", quadro, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(meio.X, meio.Y),
			-- Comprimento em escala do quadro (quadrado): a largura vale para os dois eixos.
			Size = UDim2.new(delta.Magnitude, 0, 0, 2),
			Rotation = math.deg(math.atan2(delta.Y, delta.X)),
			BackgroundColor3 = cor, BackgroundTransparency = transparencia, BorderSizePixel = 0, ZIndex = 1,
		})
	end

	local function no(posicao: Vector2, tamanho: number, cor: Color3, rotulo: string, fonte, tamanhoTexto: number)
		local b = new("TextButton", quadro, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(posicao.X, posicao.Y),
			Size = UDim2.fromOffset(tamanho, tamanho), BackgroundColor3 = Estilo.PAPEL_2, AutoButtonColor = false,
			Text = rotulo, TextColor3 = cor, FontFace = fonte, TextSize = tamanhoTexto, ZIndex = 3,
		})
		cantos(b, tamanho)
		local stroke = new("UIStroke", b, { Color = cor, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		return b, stroke
	end

	local centro = Vector2.new(0.5, 0.5)
	-- O centro do mapa (a coroa do site): 王, "rei".
	no(centro, 58, Estilo.DESTAQUE, "王", KANJI_FONTE, 30)
	local nos: { [string]: { botao: TextButton, stroke: UIStroke, cor: Color3 } } = {}
	local selecionada: string? = nil
	local redesenhar -- definida abaixo

	for _, categoria in CATEGORIAS do
		local daCategoria = {}
		for _, a in arvores do
			if a.data.category == categoria.id then
				table.insert(daCategoria, a)
			end
		end
		table.sort(daCategoria, function(x, y)
			if (x.data.subgroup or "") ~= (y.data.subgroup or "") then
				return (x.data.subgroup or "") < (y.data.subgroup or "")
			end
			return x.data.name < y.data.name
		end)
		local corCat = COR_CATEGORIA[categoria.id]
		local meio = (categoria.inicio + categoria.fim) / 2
		local hub = polar(meio, 0.15)
		linhaEntre(centro, hub, corCat, 0.35)
		local hubNo = no(hub, 40, corCat, "◆", Estilo.GRITO, 18)
		local rotulo = texto(quadro, {
			Text = categoria.nome, FontFace = Estilo.GRITO, TextSize = 15, TextColor3 = corCat,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(hub.X, hub.Y + 0.035), Size = UDim2.fromOffset(110, 18),
			AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
		})
		local _ = hubNo
		local _r = rotulo
		-- Subgrupos: um anel por subgrupo, na média dos ângulos das árvores dele.
		local n = #daCategoria
		local angulos = {}
		for i, a in daCategoria do
			angulos[a.id] = categoria.inicio + (categoria.fim - categoria.inicio) * (if n == 1 then 0.5 else (i - 1) / (n - 1))
		end
		local grupos = {}
		for _, a in daCategoria do
			local g = a.data.subgroup or a.data.name
			grupos[g] = grupos[g] or {}
			table.insert(grupos[g], a)
		end
		for _, membros in grupos do
			local soma = 0
			for _, a in membros do
				soma += angulos[a.id]
			end
			local anelPos = polar(soma / #membros, 0.28)
			linhaEntre(hub, anelPos, corCat, 0.45)
			no(anelPos, 18, corCat, "", Estilo.GRITO, 10)
			for _, a in membros do
				local idLocal = a.data.id
				local ident = Estilo.arvore(idLocal)
				local posicao = polar(angulos[a.id], 0.41)
				linhaEntre(anelPos, posicao, corCat, 0.55)
				local b, stroke = no(posicao, 46, ident.cor, ident.selo, KANJI_FONTE, 24)
				b.Name = "Arvore_" .. idLocal
				texto(quadro, {
					Text = a.data.name, TextSize = 11, TextColor3 = Estilo.TINTA_SUAVE, AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(posicao.X, 0, posicao.Y, 26), Size = UDim2.fromOffset(110, 14),
					AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
				})
				b.MouseEnter:Connect(function()
					TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.fromOffset(54, 54) }):Play()
				end)
				b.MouseLeave:Connect(function()
					TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.fromOffset(46, 46) }):Play()
				end)
				b.Activated:Connect(function()
					selecionada = idLocal
					redesenhar()
				end)
				nos[idLocal] = { botao = b, stroke = stroke, cor = ident.cor }
			end
		end
	end

	-- Ficha alvo -------------------------------------------------------------

	local function fichaAlvo()
		local snapshot = state.snapshot()
		if not snapshot then
			return nil
		end
		local sel = state.findToken(state.selectedToken())
		if sel and sel.ficha2Versao and state.canControl(sel) then
			return sel
		end
		for _, token in snapshot.tokens do
			if token.ficha2Versao and token.ownerUserId == state.localUserId() then
				return token
			end
		end
		return nil
	end

	-- Página da árvore --------------------------------------------------------

	local ordem = 0
	local function proximo()
		ordem += 1
		return ordem
	end

	local function cartao(parent, cor: Color3?)
		local c = new("Frame", parent, {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Estilo.PAPEL_2, LayoutOrder = proximo(),
		})
		cantos(c, 8)
		new("UIPadding", c, { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12) })
		lista(c, 4)
		-- Contorno na cor da árvore (uma barra lateral com altura em escala
		-- inflaria o AutomaticSize do cartão).
		new("UIStroke", c, { Color = cor or Estilo.FIO_COR, Thickness = 1.2, Transparency = if cor then 0.45 else 0 })
		return c
	end

	local function cartaDeHabilidade(parent, id: string, construcao, conhecidas, tokenId: string, cor: Color3)
		local entrada = Catalogo.POR_ID[id]
		if not entrada then
			return
		end
		local d = entrada.data
		local c = cartao(parent, cor)
		c.Name = "Carta_" .. entrada.sourceId
		local titulo = Estilo.maiusculas(d.name) .. (if d.signature then "  ◆" else "")
		texto(c, { Text = titulo, FontFace = Estilo.GRITO, TextSize = 18, LayoutOrder = 1 })
		if entrada.kind == "ability" then
			texto(c, { Text = custos(d), FontFace = Estilo.ROTULO_FORTE, TextSize = 12, TextColor3 = cor, LayoutOrder = 2 })
		else
			texto(c, { Text = "TALENTO • " .. (d.paCost or 0) .. " PA", FontFace = Estilo.ROTULO_FORTE, TextSize = 12, TextColor3 = cor, LayoutOrder = 2 })
		end
		local corpo = d.effect or d.description or ""
		if d.damage and d.damage.normal then
			corpo = "Dano: " .. d.damage.normal .. "\n" .. corpo
		end
		local mec = Execucao.MECANICAS[id]
		if mec and mec.descricao then
			texto(c, { Name = "NoJogo", Text = "NO JOGO\n" .. mec.descricao, FontFace = Estilo.CORPO, TextSize = 14, LayoutOrder = 3 })
			corpo = "NO LIVRO\n" .. corpo
		end
		texto(c, { Text = corpo, FontFace = Estilo.CORPO, TextSize = 13, TextColor3 = Estilo.TINTA_SUAVE, LayoutOrder = 4 })
		local rodape = new("Frame", c, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 5 })
		new("UIListLayout", rodape, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center })
		local function selo(textoSelo: string, corSelo: Color3)
			local s = new("TextLabel", rodape, {
				Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Estilo.misturar(corSelo, Estilo.PAPEL_2, 0.18),
				Text = "  " .. textoSelo .. "  ", TextColor3 = corSelo, FontFace = Estilo.ROTULO_FORTE, TextSize = 12,
			})
			cantos(s, 12)
		end
		if tem(conhecidas, id) then
			selo(if tem(construcao.purchasedIds, id) then "✓ APRENDIDA" else "✓ VEM COM O RANK", cor)
		else
			local ok, motivo = Progressao.podeComprar(construcao, Catalogo, id)
			if ok then
				local b = botao(rodape, "Aprender", Estilo.DESTAQUE_FUNDO, function()
					state.send("aprender", { tokenId = tokenId, habilidadeId = id })
				end, 110)
				b.Name = "Aprender_" .. entrada.sourceId
			else
				texto(rodape, { Text = motivo or "", TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE, Size = UDim2.new(0.7, 0, 0, 0) })
			end
		end
		if entrada.kind == "ability" then
			if Execucao.MECANICAS[id] then
				selo("⚔ JOGÁVEL", Estilo.SUCESSO)
			else
				selo("SÓ NA FICHA", Estilo.TINTA_SUAVE)
			end
		end
	end

	local function desenharPagina(token, ficha2)
		for _, filho in pagina:GetChildren() do
			if filho:IsA("GuiObject") then
				filho:Destroy()
			end
		end
		ordem = 0
		if not token then
			texto(pagina, { Text = "Selecione uma ficha sua com os dados do livro (personagem pronto ou ficha completa importada do site).", LayoutOrder = proximo(), TextColor3 = Estilo.TINTA_SUAVE })
			return
		end
		if not ficha2 then
			texto(pagina, { Text = "Carregando a ficha…", LayoutOrder = proximo(), TextColor3 = Estilo.TINTA_SUAVE })
			return
		end
		local arvore = selecionada or ficha2.construction.startingTreeId and string.match(ficha2.construction.startingTreeId, "^tree/(.+)$") or "fogo"
		selecionada = arvore
		local entrada = Catalogo.POR_ID["tree/" .. Progressao.segmento(arvore)]
		if not entrada then
			return
		end
		local d = entrada.data
		local ident = Estilo.arvore(arvore)
		local kanji = (Identidade["tree/" .. arvore] or {}).kanji or ident.selo
		local construcao = ficha2.construction
		local conhecidas = Progressao.conhecidas(construcao, Catalogo)

		-- Cabeçalho da árvore.
		local cab = new("Frame", pagina, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = proximo() })
		lista(cab, 2)
		texto(cab, { Text = kanji, FontFace = KANJI_FONTE, TextSize = 44, TextColor3 = ident.cor, LayoutOrder = 1 })
		texto(cab, { Text = Estilo.maiusculas(d.name), FontFace = Estilo.GRITO, TextSize = 30, LayoutOrder = 2 })
		texto(cab, {
			Text = string.format("%s • %s • atributo-chave: %s • recurso: %s", Estilo.maiusculas(d.category or ""), d.subgroup or "", d.keyAttributeLabel or "—", d.resourceLabel or "—"),
			TextSize = 12, TextColor3 = ident.cor, FontFace = Estilo.ROTULO_FORTE, LayoutOrder = 3,
		})
		if d.tagline then
			texto(cab, { Text = d.tagline, FontFace = Estilo.ELEGANTE, TextSize = 15, TextColor3 = Estilo.TINTA, LayoutOrder = 4 })
		end
		if d.mechanic and d.mechanic.hook then
			local m = cartao(pagina, ident.cor)
			texto(m, { Text = "NO LIVRO • " .. Estilo.maiusculas(d.mechanic.tag or "MECÂNICA"), FontFace = Estilo.GRITO, TextSize = 16, TextColor3 = ident.cor })
			texto(m, { Text = d.mechanic.hook, FontFace = Estilo.CORPO, TextSize = 13 })
		end
		local plano = Planos[arvore]
		if plano then
			local guia = cartao(pagina, ident.cor)
			guia.Name = "ComoJogar"
			texto(guia, { Text = "COMO JOGAR • " .. plano.estilo, FontFace = Estilo.ROTULO_FORTE, TextColor3 = ident.cor, LayoutOrder = 1 })
			for i, passo in plano.passos do
				texto(guia, { Text = i .. ". " .. passo.dica .. (if tem(conhecidas, passo.id) then "  ✓ Conhecida" else "  ◇ Aprenda abaixo"), FontFace = Estilo.CORPO, TextSize = 14, LayoutOrder = i + 1 })
			end
			texto(guia, { Text = plano.cuidado, TextColor3 = Estilo.TINTA_SUAVE, TextSize = 13, LayoutOrder = 10 })
		end

		-- Ranks.
		local ranks = {}
		for _, r in Catalogo.POR_ESPECIE.rank do
			if r.data.treeId == arvore then
				table.insert(ranks, r)
			end
		end
		for _, r in ranks do
			local nomeRank = r.data.rank
			local aberto = Progressao.rankAberto(construcao, arvore, nomeRank)
			local acima = Progressao.acimaDoTeto(nomeRank)
			local secao = new("Frame", pagina, {
				Name = "Rank_" .. nomeRank, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = proximo(),
			})
			lista(secao, 6)
			local barra = new("Frame", secao, { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = 1 })
			texto(barra, {
				Text = string.format("%s  •  BÔNUS +%d", Estilo.maiusculas(nomeRank), Regras.bonusDeRank[nomeRank] or 0),
				FontFace = Estilo.GRITO, TextSize = 22, TextColor3 = if aberto then ident.cor elseif acima then Estilo.FIO_COR else Estilo.TINTA,
				Size = UDim2.new(0.6, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.None,
			})
			local estado = new("Frame", barra, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 0, 44), BackgroundTransparency = 1 })
			if acima then
				texto(estado, { Text = "EM BREVE", FontFace = Estilo.ROTULO_FORTE, TextColor3 = Estilo.FIO_COR, TextXAlignment = Enum.TextXAlignment.Right })
			elseif aberto then
				texto(estado, { Text = "✓ ABERTO", FontFace = Estilo.ROTULO_FORTE, TextColor3 = ident.cor, TextXAlignment = Enum.TextXAlignment.Right })
			else
				local ok, motivo = Progressao.podeAbrir(construcao, Catalogo, arvore, nomeRank)
				if ok then
					local b = botao(estado, "Abrir patamar", Estilo.DESTAQUE_FUNDO, function()
						state.send("abrirRank", { tokenId = token.id, arvore = arvore, rank = nomeRank })
					end, 140)
					b.Name = "Abrir_" .. nomeRank
					b.AnchorPoint, b.Position = Vector2.new(1, 0), UDim2.fromScale(1, 0)
				else
					texto(estado, { Text = motivo or "", TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE, TextXAlignment = Enum.TextXAlignment.Right })
				end
			end
			if not acima then
				local maestria = r.data.mastery and Catalogo.POR_ID[r.data.mastery]
				if maestria then
					local m = cartao(secao, ident.cor)
					m.LayoutOrder = 2
					texto(m, { Text = "MAESTRIA: " .. Estilo.maiusculas(maestria.data.name or ""), FontFace = Estilo.GRITO, TextSize = 16, TextColor3 = ident.cor })
					texto(m, { Text = maestria.data.description or "", FontFace = Estilo.CORPO, TextSize = 13, TextColor3 = Estilo.TINTA_SUAVE })
					texto(m, { Text = "Grátis ao abrir o patamar.", FontFace = Estilo.ELEGANTE, TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE })
				end
				texto(secao, { Text = "HABILIDADES", FontFace = Estilo.ROTULO_FORTE, TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE, LayoutOrder = 3 })
				local hab = new("Frame", secao, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4 })
				lista(hab, 6)
				for _, id in r.data.abilities or {} do
					cartaDeHabilidade(hab, id, construcao, conhecidas, token.id, ident.cor)
				end
				texto(secao, { Text = "TALENTOS", FontFace = Estilo.ROTULO_FORTE, TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE, LayoutOrder = 5 })
				local tal = new("Frame", secao, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 6 })
				lista(tal, 6)
				for _, id in r.data.talents or {} do
					cartaDeHabilidade(tal, id, construcao, conhecidas, token.id, ident.cor)
				end
			end
		end
	end

	function redesenhar()
		if not gui.Enabled then
			return
		end
		local token = fichaAlvo()
		local ficha2 = token and state.fichaDetalhe(token.id)
		subtitulo.Text = if token
			then string.format("Ficha: %s  •  PA ∞ (provisório)  •  por enquanto até o Intermediário", token.name)
			else "Nenhuma ficha sua com os dados do livro."
		-- Selos acesos nas árvores abertas.
		local construcao = ficha2 and ficha2.construction
		for idLocal, n in nos do
			local aberta = construcao ~= nil and Progressao.maiorRank(construcao, idLocal) ~= nil
			n.stroke.Thickness = if idLocal == selecionada then 4 elseif aberta then 3 else 1.5
			n.stroke.Transparency = if aberta or idLocal == selecionada then 0 else 0.55
			n.botao.TextTransparency = if aberta or idLocal == selecionada then 0 else 0.45
			n.botao.BackgroundColor3 = if aberta then Estilo.misturar(n.cor, Estilo.PAPEL_2, 0.22) else Estilo.PAPEL_2
		end
		desenharPagina(token, ficha2)
	end

	gui:GetPropertyChangedSignal("Enabled"):Connect(redesenhar)
	state.onSnapshot(function()
		local token = fichaAlvo()
		atalho.Visible = token ~= nil
		redesenhar()
	end)
	state.onFichaDetalhe(redesenhar)
end

return ArvoresView
