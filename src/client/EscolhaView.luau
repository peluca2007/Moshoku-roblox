-- Escolha de personagem (A9): um personagem pronto por árvore inicial, montado
-- com as regras do site (tools/fixtures/premontados.mts). Abre sozinha na
-- primeira entrada e pelo botão PERSONAGEM. A escolha vale para Treino, Luta e
-- Duelo; o servidor valida (escolherPersonagem).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Estilo = require(Shared:WaitForChild("Estilo"))
local Catalogo = require(Shared:WaitForChild("Livro"):WaitForChild("Catalogo"))
local Identidade = require(Shared:WaitForChild("Livro"):WaitForChild("Identidade"))
local Personagens = require(Shared:WaitForChild("PersonagensProntos"))
local Execucao = require(Shared:WaitForChild("Regras"):WaitForChild("Execucao"))

local EscolhaView = {}

local KANJI = Font.fromName("SourceSansPro", Enum.FontWeight.Bold)

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function texto(parent, props)
	local l = new("TextLabel", parent, {
		BackgroundTransparency = 1, TextColor3 = Estilo.TINTA, FontFace = Estilo.ROTULO_FORTE, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	})
	for k, v in props do
		l[k] = v
	end
	return l
end

local function nomeDaCarta(id: string): string
	local e = Catalogo.POR_ID[id]
	return if e then e.data.name else (string.match(id, "([^/]+)$") or id)
end

function EscolhaView.start(state)
	local aoFechar = nil
	local eu = Players.LocalPlayer
	local gui = new("ScreenGui", eu:WaitForChild("PlayerGui"), {
		Name = "EscolhaDePersonagem", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 21, Enabled = false,
	})
	local fundo = new("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Estilo.MESA_FUNDO, BackgroundTransparency = 0 })
	texto(fundo, {
		Position = UDim2.fromOffset(24, 64), Size = UDim2.new(1, -48, 0, 40), Text = "ESCOLHA SEU PERSONAGEM",
		FontFace = Estilo.GRITO, TextSize = 23,
	})
	texto(fundo, {
		Position = UDim2.fromOffset(24, 108), Size = UDim2.new(1, -48, 0, 52), TextColor3 = Estilo.TINTA_SUAVE, TextSize = 14,
		Text = "Compare atributos, vida, mana e CD da árvore. PA gasto = pontos de aprimoramento investidos. Toque para escolher personagem e arma; durante uma partida, a troca vale para a próxima.",
	})
	local fechar = new("TextButton", fundo, {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -16), Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = Estilo.BOTAO, Text = "VOLTAR", TextColor3 = Estilo.TINTA, FontFace = Estilo.GRITO, TextSize = 18,
	})
	new("UICorner", fechar, { CornerRadius = UDim.new(0, 8) })
	fechar.Activated:Connect(function()
		gui.Enabled = false
		if aoFechar then aoFechar() end
	end)

	local grade = new("ScrollingFrame", fundo, {
		Position = UDim2.fromOffset(24, 168), Size = UDim2.new(1, -48, 1, -236), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
	})
	local layout = new("UIGridLayout", grade, { CellSize = UDim2.fromOffset(300, 290), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	local function ajustar()
		local largura = math.max(1, grade.AbsoluteSize.X - 10)
		local colunas = math.max(1, math.floor((largura + 12) / 300))
		layout.CellSize = UDim2.fromOffset(math.floor((largura - (colunas - 1) * 12) / colunas), 290)
	end
	grade:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustar)
	task.defer(ajustar)

	local cartoes: { [string]: { borda: UIStroke, marca: TextLabel, cor: Color3, arma: TextLabel } } = {}
	local armasConfirmadas = {}
	local personagemAberto
	local seletor = new("Frame", fundo, {
		Name = "EscolhaDeArma", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.92, 0.8),
		BackgroundColor3 = Estilo.PAPEL_2, ZIndex = 5,
	})
	new("UISizeConstraint", seletor, { MaxSize = Vector2.new(680, 650) })
	new("UICorner", seletor, { CornerRadius = UDim.new(0, 10) })
	new("UIStroke", seletor, { Color = Estilo.ALERTA, Thickness = 2 })
	local tituloArma = texto(seletor, { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 52), TextSize = 18, FontFace = Estilo.GRITO, ZIndex = 6 })
	local listaArmas = new("ScrollingFrame", seletor, {
		Name = "Armas", Position = UDim2.fromOffset(12, 68), Size = UDim2.new(1, -24, 1, -168),
		BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), ScrollBarThickness = 5, ZIndex = 6,
	})
	new("UIListLayout", listaArmas, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local statusArma = texto(seletor, { Name = "Status", Position = UDim2.new(0, 14, 1, -94), Size = UDim2.new(1, -28, 0, 38), TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE, ZIndex = 6 })
	local voltarArmas = new("TextButton", seletor, {
		Name = "Voltar", Position = UDim2.new(0, 12, 1, -50), Size = UDim2.new(1, -24, 0, 40),
		BackgroundColor3 = Estilo.BOTAO, Text = "VOLTAR AOS PERSONAGENS", TextColor3 = Estilo.TINTA,
		FontFace = Estilo.GRITO, TextSize = 16, ZIndex = 6,
	})
	new("UICorner", voltarArmas, { CornerRadius = UDim.new(0, 6) })
	voltarArmas.Activated:Connect(function() seletor.Visible = false; grade.Visible = true end)
	local function abrirArmas(p)
		personagemAberto = p
		grade.Visible, seletor.Visible = false, true
		tituloArma.Text = p.nome .. "\nESCOLHA SUA ARMA"
		statusArma.Text = "A troca vale para a próxima partida. Aguardando o servidor."
		for _, filho in listaArmas:GetChildren() do if filho:IsA("TextButton") then filho:Destroy() end end
		for ordem, arma in p.armas do
			local b = new("TextButton", listaArmas, {
				Name = "Arma_" .. ordem, LayoutOrder = ordem, Size = UDim2.new(1, -8, 0, 48),
				BackgroundColor3 = Estilo.BOTAO, TextColor3 = if arma.indisponivel then Estilo.TINTA_SUAVE else Estilo.TINTA,
				Text = arma.nome .. " · " .. arma.dado .. " · " .. arma.grupoNome,
				FontFace = Estilo.ROTULO_FORTE, TextSize = 12, TextWrapped = false, ZIndex = 6,
				AutoButtonColor = not arma.indisponivel,
			})
			local function tamanhoDaLinha()
				b.TextSize = if b.AbsoluteSize.X < 350 then 12 else 14
			end
			b:GetPropertyChangedSignal("AbsoluteSize"):Connect(tamanhoDaLinha)
			task.defer(tamanhoDaLinha)
			new("UICorner", b, { CornerRadius = UDim.new(0, 6) })
			new("UIPadding", b, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
			b.Activated:Connect(function()
				if arma.indisponivel then statusArma.Text = arma.indisponivel; return end
				statusArma.Text = "Aguardando o servidor."
				state.send("escolherPersonagem", { id = p.id, arma = arma.id })
			end)
		end
	end
	game:GetService("ReplicatedStorage"):WaitForChild("Mesa").OnClientEvent:Connect(function(tipo, escolha)
		if tipo ~= "escolhaPersonagem" then return end
		local c = cartoes[escolha.id]
		if not c then return end
		armasConfirmadas[escolha.id] = escolha.arma
		for _, p in Personagens do
			if p.id == escolha.id then
				for _, a in p.armas do
					if a.id == escolha.arma then
						c.arma.Text = "Arma: " .. a.nome .. " · " .. a.dado
						if personagemAberto == p then statusArma.Text = "Escolhida: " .. a.nome .. ". Vale para a próxima partida." end
					end
				end
			end
		end
	end)
	state.onLog(function(entry)
		if seletor.Visible and entry.tone == "erro" then statusArma.Text = entry.text end
	end)
	for i, p in Personagens do
		local arvore = Catalogo.POR_ID["tree/" .. p.arvore]
		local d = arvore and arvore.data or {}
		local ident = Estilo.arvore(p.arvore)
		local atributos = p.atributos
		local ficha = { calculated = { attributes = atributos }, construction = { unlockedRankIds = p.ranks } }
		local cd = 8 + Execucao.bc(ficha, p.arvore, Catalogo)
		local kanji = (Identidade["tree/" .. p.arvore] or {}).kanji or ident.selo
		local cartao = new("TextButton", grade, {
			Name = "Personagem_" .. p.id, LayoutOrder = i, AutoButtonColor = false, Text = "",
			BackgroundColor3 = Estilo.PAPEL_2,
		})
		new("UICorner", cartao, { CornerRadius = UDim.new(0, 10) })
		local borda = new("UIStroke", cartao, { Color = Estilo.FIO_COR, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		new("Frame", cartao, { Size = UDim2.new(0, 5, 1, -20), Position = UDim2.fromOffset(8, 10), BackgroundColor3 = ident.cor, BorderSizePixel = 0 })
		texto(cartao, { Position = UDim2.new(1, -62, 0, 6), Size = UDim2.fromOffset(54, 54), Text = kanji, FontFace = KANJI, TextSize = 46, TextColor3 = ident.cor, TextXAlignment = Enum.TextXAlignment.Center })
		texto(cartao, { Position = UDim2.fromOffset(22, 8), Size = UDim2.new(1, -90, 0, 24), Text = Estilo.maiusculas(p.nome), FontFace = Estilo.GRITO, TextSize = 18, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
		texto(cartao, { Position = UDim2.fromOffset(22, 32), Size = UDim2.new(1, -90, 0, 16), Text = string.format("%s · %d", d.keyAttributeLabel or "Atributo-chave", Execucao.atributoChave(d.keyAttributeLabel, atributos)), TextSize = 12, TextColor3 = ident.cor, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
		texto(cartao, { Name = "Recursos", Position = UDim2.fromOffset(22, 56), Size = UDim2.new(1, -36, 0, 40), Text = string.format("Vida %d   Mana %d   PT %d\nCA %d   CD da árvore %d", p.pv, p.pm, p.pt, p.ca, cd), TextSize = 14 })
		texto(cartao, { Name = "Atributos", Position = UDim2.fromOffset(22, 102), Size = UDim2.new(1, -145, 0, 38), Text = string.format("FOR %d  AGI %d  VIG %d\nINT %d  ESP %d", atributos.forca, atributos.agilidade, atributos.vigor, atributos.intelecto, atributos.espirito), TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE })
		local pa = texto(cartao, { Name = "PaGasto", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 103), Size = UDim2.fromOffset(100, 36), Text = string.format("PA gasto\n%d", p.paGasto), TextSize = 14, TextColor3 = Estilo.ALERTA, TextXAlignment = Enum.TextXAlignment.Center })
		pa.BackgroundColor3, pa.BackgroundTransparency = Estilo.BOTAO, 0
		new("UICorner", pa, { CornerRadius = UDim.new(0, 6) })
		local cartas = {}
		for _, id in p.cartas do
			table.insert(cartas, nomeDaCarta(id))
		end
		texto(cartao, { Position = UDim2.fromOffset(22, 150), Size = UDim2.new(1, -36, 0, 54), Text = table.concat(cartas, " • "), TextSize = 13, TextColor3 = Estilo.TINTA_SUAVE, FontFace = Estilo.ROTULO, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd })
		texto(cartao, { Position = UDim2.fromOffset(22, 206), Size = UDim2.new(1, -36, 0, 30), Text = d.tagline or "", TextSize = 12, TextColor3 = Estilo.TINTA_SUAVE, FontFace = Estilo.ELEGANTE, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd })
		local marca = texto(cartao, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -6), Size = UDim2.fromOffset(120, 18), Text = "", TextSize = 13, TextColor3 = Estilo.ALERTA, TextXAlignment = Enum.TextXAlignment.Right, FontFace = Estilo.GRITO })
		local armaLabel = texto(cartao, { Name = "ArmaEscolhida", Position = UDim2.fromOffset(22, 237), Size = UDim2.new(1, -36, 0, 22), Text = "Arma: " .. p.armas[1].nome .. " · " .. p.armas[1].dado, TextSize = 12, TextColor3 = ident.cor, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
		cartoes[p.id] = { borda = borda, marca = marca, cor = ident.cor, arma = armaLabel }
		cartao.Activated:Connect(function()
			abrirArmas(p)
			state.send("escolherPersonagem", { id = p.id, arma = armasConfirmadas[p.id] })
		end)
		cartao.MouseEnter:Connect(function()
			TweenService:Create(cartao, TweenInfo.new(0.12), { BackgroundColor3 = Estilo.misturar(ident.cor, Estilo.PAPEL_2, 0.12) }):Play()
		end)
		cartao.MouseLeave:Connect(function()
			TweenService:Create(cartao, TweenInfo.new(0.12), { BackgroundColor3 = Estilo.PAPEL_2 }):Play()
		end)
	end

	state.onSnapshot(function(snap)
		local atual = snap.you and snap.you.personagem
		for id, c in cartoes do
			local escolhido = id == atual
			c.borda.Color = if escolhido then c.cor else Estilo.FIO_COR
			c.borda.Thickness = if escolhido then 3 else 1.5
			c.marca.Text = if escolhido then "✔ ESCOLHIDO" else ""
		end
	end)
	return { abrir = function(callback) aoFechar = callback; seletor.Visible = false; grade.Visible = true; gui.Enabled = true end }
end

return EscolhaView
