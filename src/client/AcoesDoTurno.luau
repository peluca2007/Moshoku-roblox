-- Barra de ações do turno (fatia A1), no estilo Livro Noite. Aparece na vez de
-- uma ficha que este jogador controla e que tem habilidades executáveis.
-- Só intenção: escolher a habilidade liga a MIRA (MesaState); o clique no
-- tabuleiro manda o pedido; o servidor valida e resolve.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Estilo = require(Shared:WaitForChild("Estilo"))
local Catalogo = require(Shared:WaitForChild("Livro"):WaitForChild("Catalogo"))
local Execucao = require(Shared:WaitForChild("Regras"):WaitForChild("Execucao"))
local Apresentacao = require(Shared.ApresentacaoAcoes)
local FX = require(script.Parent.MenuEfeitos)
local Descricao = require(Shared.DescricaoHabilidade)
local Previa = require(script.Parent.PreviaFurtiva)

local AcoesDoTurno = {}


local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function texto(parent, props)
	local label = new("TextLabel", parent, {
		BackgroundTransparency = 1,
		TextColor3 = Estilo.TINTA,
		FontFace = Estilo.ROTULO,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	for key, value in props do
		label[key] = value
	end
	return label
end

-- Como a mira escolhe: "ficha" (clique num alvo), "casa" (clique numa casa) ou
-- "confirmar" (segundo clique na carta: em volta de si ou em si).
local function modoDaMira(mec): string
	local alvo = mec.alvo or "unico"
	if alvo == "lista" or alvo == "disparos" then return "lista" end
	if mec.tipo == "zona" then
		return if mec.forma == "esferaNoConjurador" then "confirmar" else "casa"
	elseif mec.tipo == "deslocamento" then
		return "casa"
	elseif mec.tipo == "utilidade" then
		return if mec.alvoCasa then "casa" else "confirmar"
	elseif mec.tipo == "especial" or mec.tipo == "invocacao" then
		-- Se Esconder, canções: sem alvo. Inspirar, Insulto, Ordem de Tiro: uma ficha.
		return if mec.alcanceCasas and mec.alvo ~= "si" then "ficha" else "confirmar"
	elseif alvo == "si" or alvo == "esferaNoConjurador" or alvo == "adjacentes" then
		return "confirmar"
	elseif alvo == "esferaNaCasa" or alvo == "cone" then
		return "casa"
	end
	return "ficha"
end

local function arvoreDe(habilidadeId: string): string?
	return string.match(habilidadeId, "^%a+/([^/]+)/")
end

function AcoesDoTurno.start(state)
	local player = Players.LocalPlayer
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "AcoesDoTurno",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 5,
	})
	local detalhe = require(script.Parent.DetalheAcao).start(gui)
	local tooltip = require(script.Parent.TooltipAcao).start(gui, function() Previa.set(nil) end)
	local cartasFrame
	local barra = new("Frame", gui, {
		Name = "Barra",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.38, 0, 1, -14),
		Size = UDim2.new(0.96, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Estilo.PAPEL,
		BackgroundTransparency = 0.06,
		Visible = false,
	})
	new("UICorner", barra, { CornerRadius = UDim.new(0, 10) })
	local contorno = new("UIStroke", barra, { Color = Estilo.FIO_COR, Thickness = 1.5 })
	new("UIPadding", barra, {
		PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
	})
	new("UIListLayout", barra, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	new("UISizeConstraint", barra, { MaxSize = Vector2.new(760, math.huge) })

	-- Cabeçalho: selo da árvore, de quem é a vez, Ações e PM.
	local cabecalho = new("Frame", barra, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1 })
	local selo = texto(cabecalho, {
		Name = "Selo", Size = UDim2.fromOffset(44, 44), FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
		TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, Text = "",
	})
	local titulo = texto(cabecalho, {
		Name = "Titulo", Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -300, 0, 26),
		FontFace = Estilo.GRITO, TextSize = 24, Text = "",
	})
	local subtitulo = texto(cabecalho, {
		Name = "Dica", Position = UDim2.fromOffset(52, 26), Size = UDim2.new(1, -300, 0, 18),
		TextColor3 = Estilo.TINTA_SUAVE, TextSize = 13, Text = "",
	})
	local acoesRotulo = texto(cabecalho, {
		Name = "Acoes", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(240, 26),
		FontFace = Estilo.GRITO, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	})
	local pmRotulo = texto(cabecalho, {
		Name = "PM", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 26), Size = UDim2.fromOffset(240, 18),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Estilo.CAPITULOS[2], Text = "",
	})

	local grupo, atualizar = "Golpes", nil
	local abas = new("Frame", barra, { Name = "Grupos", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 2 })
	new("UIGridLayout", abas, { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder })
	local botoesGrupo = {}
	for i, nome in { "Golpes", "Apoio", "Tudo" } do
		local b = new("TextButton", abas, { Name = nome, Text = nome, LayoutOrder = i,
			BackgroundColor3 = Estilo.BOTAO, TextColor3 = Estilo.TINTA, FontFace = Estilo.ROTULO_FORTE, TextSize = 15 })
		new("UICorner", b, { CornerRadius = UDim.new(0, 6) })
		b.Activated:Connect(function()
			grupo = nome
			detalhe.fechar()
			tooltip.fechar()
			if cartasFrame then cartasFrame.CanvasPosition = Vector2.zero end
			state.setMira(nil)
			if atualizar then atualizar() end
		end)
		botoesGrupo[nome] = b
	end
	-- Cartas das habilidades.
	cartasFrame = new("ScrollingFrame", barra, { Name = "Cartas", Size = UDim2.new(1, 0, 0, 192), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 3 })
	local grade = new("UIGridLayout", cartasFrame, { CellSize = UDim2.new(1 / 3, -6, 0, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })

	-- Ações extras: apagar o fogo, cancelar a mira, encerrar o turno.
	local extras = new("Frame", barra, { Name = "Controles", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4 })
	local gradeExtras = new("UIGridLayout", extras, { CellSize = UDim2.new(1 / 3, -6, 0, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })

	local function botao(parent, rotulo: string, fundo: Color3, aoClicar: () -> ())
		local b = new("TextButton", parent, {
			Size = UDim2.fromOffset(170, 44), BackgroundColor3 = fundo, AutoButtonColor = true,
			Text = rotulo, TextColor3 = Estilo.TINTA, FontFace = Estilo.ROTULO_FORTE, TextSize = 15, TextWrapped = true,
		})
		new("UICorner", b, { CornerRadius = UDim.new(0, 6) })
		b.Activated:Connect(aoClicar)
		return b
	end

	local atual = { tokenId = nil :: string?, ficha = nil :: any, assinatura = "", pacto = 1 }
	local cartas: { [string]: any } = {}
	local apagar = botao(extras, "Apagar o fogo (1 Ação)", Estilo.PERIGO_FUNDO, function()
		if atual.tokenId then
			state.send("apagarFogo", { tokenId = atual.tokenId })
		end
	end)
	local levantar = botao(extras, "Levantar (1 Ação)", Estilo.DESTAQUE_FUNDO, function()
		tooltip.fechar()
		if atual.tokenId then state.setMira(nil); state.send("usarHabilidade", {tokenId = atual.tokenId, habilidadeId = "mesa/levantar"}) end
	end)
	levantar.Name, levantar.LayoutOrder, levantar.Visible = "Levantar", -3, false

	apagar.Name = "ApagarFogo"
	-- Andar (Cap. 4: 1 Ação, até o Deslocamento): acende as casas e um clique move.
	local andar = botao(extras, "Andar (1 Ação)", Estilo.BOTAO, function()
		if not atual.tokenId or (atual.restantes or 0) < 1 and (atual.passosLivres or 0) < 1 then
			return
		end
		local mira = state.mira()
		if mira and mira.habilidadeId == "mesa/andar" then
			state.setMira(nil)
			return
		end
		state.setMira({
			tokenId = atual.tokenId, habilidadeId = "mesa/andar", tipo = "mover", modo = "casa",
			alcanceCasas = if (atual.passosLivres or 0) > 0 then atual.passosLivres else atual.deslocamentoCasas or 6, cor = Estilo.CAPITULOS[3],
		})
	end)
	andar.Name = "Andar"
	andar.LayoutOrder = -1
	local cancelar = botao(extras, "Cancelar mira", Estilo.BOTAO, function()
		state.setMira(nil)
	end)
	cancelar.Name = "CancelarMira"
	local confirmar = botao(extras, "Confirmar ação", Estilo.DESTAQUE_FUNDO, function()
		local mira = state.mira()
		local registro = mira and cartas[mira.habilidadeId]
		if registro and not registro.carta:GetAttribute("Bloqueada") and mira.tokenId == atual.tokenId and (mira.modo == "confirmar" or mira.ponto ~= nil or (mira.modo == "lista" and #(mira.alvoIds or {}) > 0)) then
			state.dispararMira()
		end
	end)
	confirmar.Name, confirmar.LayoutOrder, confirmar.Visible = "ConfirmarAcao", -2, false
	local encerrar = botao(extras, "Encerrar turno", Estilo.DESTAQUE_FUNDO, function()
		local snapshot = state.snapshot()
		if snapshot and atual.tokenId then
			state.setMira(nil)
			state.send("nextTurn", { expectedId = atual.tokenId, expectedTurn = snapshot.combat.turn })
		end
	end)
	encerrar.Name = "EncerrarTurno"

	local pacto = botao(extras, "Escolher Pacto", Estilo.BOTAO, function()
		atual.pacto += 1
		state.setMira(nil)
	end)
	pacto.Name = "EscolherPacto"
	pacto.Size = UDim2.fromOffset(135, 36)
	local ultimoTurno = nil
	local cartasVisiveis = 0
	local modoBaixo, recolhido = false, false
	local redimensionar
	local expandir = botao(barra, "Escolher ação", Estilo.BOTAO, function()
		recolhido = not recolhido
		detalhe.fechar(); tooltip.fechar()
		redimensionar()
	end)
	expandir.Name, expandir.LayoutOrder, expandir.Visible = "ExpandirAcoes", 0, false
	expandir.Size = UDim2.new(1, 0, 0, 44)
	expandir.TextSize, expandir.TextWrapped = 14, true
	redimensionar = function()
		local compacta = barra.AbsoluteSize.X < 620
		local vp = workspace.CurrentCamera.ViewportSize
		local largura = vp.X
		local baixo = vp.Y < 500 and vp.X > vp.Y
		if baixo ~= modoBaixo then recolhido = baixo; modoBaixo = baixo end
		expandir.Visible = modoBaixo
		expandir.Text = (if recolhido then "Escolher ação" else "Voltar ao tabuleiro")
			.. "  ·  " .. tostring(atual.restantes or 0) .. " ações\n" .. pmRotulo.Text
		cabecalho.Visible = not modoBaixo
		abas.Visible, cartasFrame.Visible = not modoBaixo or not recolhido, not modoBaixo or not recolhido
		extras.Visible = not modoBaixo or not recolhido or state.mira() ~= nil
		barra.Position = UDim2.new(if largura < 1100 then .5 else .38, 0, 1, -14)
		grade.CellSize = UDim2.new(if compacta then .5 else 1 / 3, -6, 0, 92)
		gradeExtras.CellSize = UDim2.new(if compacta then .5 else 1 / 3, -6, 0, 44)
		-- Uma linha basta para poucos golpes e em janelas baixas; o restante continua rolável.
		local colunas = if compacta then 2 else 3
		local limiteLinhas = if compacta or workspace.CurrentCamera.ViewportSize.Y < 800 then 1 else 2
		local linhas = math.clamp(math.ceil(cartasVisiveis / colunas), 1, limiteLinhas)
		cartasFrame.Size = UDim2.new(1, 0, 0, linhas * 100 - 8)
		cabecalho.Size = UDim2.new(1, 0, 0, if compacta then 80 else 44)
		titulo.Size = UDim2.new(1, -52, 0, 26)
		titulo.TextTruncate = Enum.TextTruncate.AtEnd
		subtitulo.Size = UDim2.new(1, -52, 0, 18)
		subtitulo.TextTruncate = Enum.TextTruncate.AtEnd
		acoesRotulo.Position = UDim2.new(1, 0, 0, if compacta then 46 else 0)
		acoesRotulo.Size = UDim2.fromOffset(if compacta then 150 else 240, 22)
		acoesRotulo.TextSize = if compacta then 16 else 20
		pmRotulo.Position = UDim2.new(1, 0, 0, if compacta then 66 else 26)
		pmRotulo.Size = if compacta then UDim2.new(1, 0, 0, 16) else UDim2.fromOffset(240, 16)
		pmRotulo.TextSize = if compacta then 12 else 14
		if not compacta then
			titulo.Size = UDim2.new(1, -300, 0, 26)
			subtitulo.Size = UDim2.new(1, -300, 0, 18)
		end
	end
	barra:GetPropertyChangedSignal("AbsoluteSize"):Connect(redimensionar)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(redimensionar)
	redimensionar()

	local function linhaDeCusto(mec): string
		local partes = { mec.acoes .. (if mec.acoes == 1 then " AÇÃO" else " AÇÕES") }
		if (mec.pm or 0) > 0 then
			table.insert(partes, mec.pm .. " PM")
		end
		if (mec.pt or 0) > 0 then
			table.insert(partes, mec.pt .. " PT")
		end
		if mec.corpoACorpo then
			table.insert(partes, "TOQUE")
		elseif mec.alcanceCasas then
			table.insert(partes, mec.alcanceCasas .. " CASAS")
		elseif mec.raioCasas then
			table.insert(partes, "RAIO " .. mec.raioCasas)
		elseif mec.comprimentoCasas then
			table.insert(partes, "LINHA " .. mec.comprimentoCasas)
		end
		if mec.umaVezPorTurno then
			table.insert(partes, "1×/TURNO")
		end
		return table.concat(partes, " • ")
	end

	local function criarCarta(habilidadeId: string, ordem: number)
		local indisponivel = Execucao.INDISPONIVEIS[habilidadeId]
		local mec = Execucao.MECANICAS[habilidadeId] or { acoes = 0, pm = 0, pt = 0, tipo = "manual" }
		local entrada = Catalogo.POR_ID[habilidadeId]
		local dados = entrada and entrada.data or {}
		local cor = Estilo.arvore(mec.arvore or arvoreDe(habilidadeId)).cor
		local carta = new("TextButton", cartasFrame, {
			Name = "Carta_" .. (dados.id or habilidadeId), LayoutOrder = ordem, AutoButtonColor = false, Text = "",
			BackgroundColor3 = Estilo.PAPEL_2,
		})
		new("UICorner", carta, { CornerRadius = UDim.new(0, 8) })
		local stroke = new("UIStroke", carta, { Color = Estilo.FIO_COR, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		new("Frame", carta, { Size = UDim2.new(0, 4, 1, -16), Position = UDim2.fromOffset(6, 8), BackgroundColor3 = cor, BorderSizePixel = 0 })
		texto(carta, {
			Name = "Nome", Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -22, 0, 24),
			FontFace = Estilo.GRITO, TextSize = 20, Text = Estilo.maiusculas(dados.name or mec.nome or habilidadeId), TextTruncate = Enum.TextTruncate.AtEnd,
		})
		texto(carta, {
			Name = "Custo", Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -22, 0, 16),
			FontFace = Estilo.ROTULO_FORTE, TextSize = 12, TextColor3 = cor, Text = if indisponivel then "CONSULTA • LEIA OS DETALHES" else linhaDeCusto(mec),
		})
		local resumo = if dados.damage and dados.damage.normal then dados.damage.normal else (dados.effect or "")
		if indisponivel then resumo = indisponivel elseif mec.aviso then resumo = mec.aviso .. " " .. resumo end
		if mec.descricao and not indisponivel then resumo = mec.descricao end
		texto(carta, {
			Name = "Resumo", Position = UDim2.fromOffset(16, 48), Size = UDim2.new(1, -72, 0, 38),
			TextSize = 13, TextColor3 = Estilo.TINTA_SUAVE, Text = resumo, TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local registro = { carta = carta, stroke = stroke, mec = mec, cor = cor, indisponivel = indisponivel,
			resumo = resumo, grupo = Apresentacao.grupo(mec, indisponivel), armada = false }
		local function dadosDetalhe()
			local ficha = atual.tokenId and state.fichaDetalhe and state.fichaDetalhe(atual.tokenId)
			local contexto = ficha and Descricao.contexto(mec, ficha, Catalogo, habilidadeId, atual.ficha)
			local completo = if indisponivel then resumo else Descricao.texto(mec, atual.ficha, contexto)
			if mec.especial == "esconder" and atual.ficha and atual.ficha.testeFurtivo then
				local teste = atual.ficha.testeFurtivo
				completo ..= string.format("\n\nSua rolagem: d20 %+d contra CD %d. Falha gasta 1 Ação e mantém você visível. Você precisa sair da visão antes de tentar.", teste.bonus, teste.cd)
			end
			if not mec.descricao and resumo ~= "" then completo ..= "\n\n" .. resumo end
			if type(dados.effect) == "string" and dados.effect ~= "" and not string.find(completo, dados.effect, 1, true) then
				completo ..= "\n\nNo livro\n" .. dados.effect
			end
			return {
				nome = dados.name or mec.nome or habilidadeId,
				custo = if indisponivel then "CONSULTA" else linhaDeCusto(mec),
				texto = if completo ~= "" then completo else "Consulte os detalhes desta habilidade na ficha.",
				motivo = carta:GetAttribute("Motivo"),
			}
		end
		registro.dadosDetalhe = dadosDetalhe
		local function consultar()
			tooltip.fechar()
			state.setMira(nil)
			detalhe.abrir(habilidadeId, dadosDetalhe())
		end
		local info = new("TextButton", carta, {
			Name = "Detalhes", Text = "?", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4),
			Size = UDim2.fromOffset(44, 44), BackgroundColor3 = Estilo.BOTAO, TextColor3 = Estilo.TINTA,
			FontFace = Estilo.ROTULO_FORTE, TextSize = 20, ZIndex = 2,
		})
		new("UICorner", info, { CornerRadius = UDim.new(0, 6) })
		info.Activated:Connect(consultar)
		carta:SetAttribute("Grupo", registro.grupo)
		carta.Activated:Connect(function()
			tooltip.fechar()
			if carta:GetAttribute("Bloqueada") then
				consultar()
				return
			end
			if mec.tipo == "formula" then
				-- Teórica: a fórmula é desenhada no quadro (FormulaView), não mirada.
				state.setMira(nil)
				require(script.Parent.FormulaView).open(atual.tokenId)
				return
			end
			local mira = state.mira()
			if mira and mira.habilidadeId == habilidadeId then
				-- "confirmar": o segundo clique na mesma carta solta a habilidade.
				if mira.modo == "confirmar" or mira.modo == "lista" then
					state.dispararMira()
				else
					state.setMira(nil)
				end
				return
			end
			state.setMira({
				tokenId = atual.tokenId,
				habilidadeId = habilidadeId,
				tipo = mec.tipo,
				modo = modoDaMira(mec),
				alcanceCasas = if mec.corpoACorpo then 1 else mec.alcanceCasas,
				raioCasas = mec.raioCasas,
				comprimentoCasas = mec.comprimentoCasas,
				cor = cor, maxAlvos = mec.maxAlvos, permiteSi = mec.permiteSi,
				pactoId = atual.ficha and atual.ficha.pactos and atual.ficha.pactos[atual.pacto],
			})
		end)
		carta.MouseEnter:Connect(function()
			if carta.Visible and barra.Visible then
				tooltip.abrir(habilidadeId, dadosDetalhe(), carta)
				Previa.set(if habilidadeId == "mesa/esconder" then atual.tokenId else nil)
			end
			TweenService:Create(carta, TweenInfo.new(0.12), { BackgroundColor3 = Estilo.misturar(cor, Estilo.PAPEL_2, 0.12) }):Play()
		end)
		carta.MouseLeave:Connect(function()
			tooltip.sair()
			TweenService:Create(carta, TweenInfo.new(0.12), { BackgroundColor3 = Estilo.PAPEL_2 }):Play()
		end)
		return registro
	end

	atualizar = function()
		local snapshot = state.snapshot()
		local vez = snapshot and snapshot.combat.active and snapshot.combat.turnId
		local token = if vez then state.findToken(vez) else nil
		local mostrar = token ~= nil and token.habilidades ~= nil and state.canControl(token)
		barra.Visible = mostrar
		if not mostrar then
			detalhe.fechar()
			tooltip.fechar()
			if state.mira() then
				state.setMira(nil)
			end
			atual.tokenId = nil
			return
		end
		atual.ficha = token
		local assinatura = table.concat(token.habilidades, "|")
		if atual.tokenId ~= token.id or atual.assinatura ~= assinatura then
			detalhe.fechar()
			tooltip.fechar()
			-- Ficha nova na vez: refaz as cartas.
			for _, registro in cartas do
				registro.carta:Destroy()
			end
			table.clear(cartas)
			-- Os golpes de todo mundo (ataque básico, disparo, Lâmina de Gelo) vêm primeiro:
			-- são o que mais se usa e não podem ficar abaixo da rolagem.
			local ordem = 0
			for _, passe in { true, false } do
				for _, id in token.habilidades do
					if (string.sub(id, 1, 5) == "mesa/") == passe and (Execucao.MECANICAS[id] or Execucao.INDISPONIVEIS[id]) then
						ordem += 1
						cartas[id] = criarCarta(id, ordem)
					end
				end
			end
			atual.tokenId = token.id
			atual.assinatura = assinatura
		end
		local primeira = token.habilidades[1]
		for _, id in token.habilidades do
			if string.sub(id, 1, 5) ~= "mesa/" then
				primeira = id
				break
			end
		end
		local identidade = Estilo.arvore(primeira and arvoreDe(primeira))
		selo.Text, selo.TextColor3 = identidade.selo, identidade.cor
		contorno.Color = Estilo.misturar(identidade.cor, Estilo.FIO_COR, 0.5)
		titulo.Text = "VEZ DE " .. Estilo.maiusculas(token.name)
		local jogo = snapshot.jogo and snapshot.jogo.acoes
		atual.deslocamentoCasas = jogo and jogo.deslocamentoCasas or 6
		atual.passosLivres = jogo and jogo.passosLivres or 0
		local usadas = if jogo and jogo.tokenId == token.id then jogo.usadas else 0
		local total = if jogo then jogo.total else 3
		local restantes = math.max(0, total - usadas)
		atual.restantes = restantes
		local chaveTurno = token.id .. ":" .. tostring(snapshot.combat.turn)
		if ultimoTurno ~= chaveTurno then
			if modoBaixo then recolhido = true end
			detalhe.fechar()
			tooltip.fechar()
			ultimoTurno = chaveTurno
			if state.mira() then state.setMira(nil) end
			cartasFrame.CanvasPosition = Vector2.zero
			barra.BackgroundTransparency = .3
			FX.animar(barra, .3, { BackgroundTransparency = .06 })
		end
		acoesRotulo.Text = string.rep("◆ ", restantes) .. string.rep("◇ ", usadas) .. " AÇÕES"
		acoesRotulo.TextColor3 = Estilo.CAPITULOS[1]
		local recursos = {}
		if token.pv and (token.pvMax or 0) > 0 then
			table.insert(recursos, string.format("PV %d / %d", token.pv, token.pvMax))
		end
		if token.mana and (token.manaMax or 0) > 0 then
			table.insert(recursos, string.format("PM %d / %d", token.mana, token.manaMax))
		end
		if token.pt and (token.ptMax or 0) > 0 then
			table.insert(recursos, string.format("PT %d / %d", token.pt, token.ptMax))
		end
		pmRotulo.Text = table.concat(recursos, "   ")
		local queimando, caido = false, false
		for _, c in token.conditions or {} do
			if c.id == "caido" then caido = true end
			if c.id == "em-chamas" then
				queimando = true
			end
		end
		levantar.Visible = caido and (token.pv or 0) > 0
		apagar.Visible = queimando
		pacto.Visible = token.pactos ~= nil and #token.pactos > 1
		if token.pactos and #token.pactos > 0 then
			atual.pacto = (atual.pacto - 1) % #token.pactos + 1
			local entradaPacto = Catalogo.POR_ID[token.pactos[atual.pacto]]
			pacto.Text = entradaPacto and entradaPacto.data.name or "Pacto"
		end
		local mira = state.mira()
		cancelar.Visible = mira ~= nil
		andar.Text = if atual.passosLivres > 0 then "Andar • " .. atual.passosLivres .. " casas restantes" else "Andar (1 Ação)"
		andar:SetAttribute("Bloqueada", restantes < 1 and atual.passosLivres < 1)
		andar.BackgroundTransparency = if restantes < 1 then .55 else 0
		encerrar.Text = if restantes == 0 then "Pronto • Encerrar turno" else "Encerrar turno"
		local contagens = { Golpes = 0, Apoio = 0, Tudo = 0 }
		for id, registro in cartas do
			local mec = registro.mec
			local motivo = Apresentacao.motivo(mec, registro.indisponivel, token, jogo, id)
			local apoio = token.apoio
			local ativa = apoio and mec.especial == "cancao" and apoio.cancao == mec.cancao
			if ativa then motivo = "ATIVA • manter não gasta Ação" end
			if apoio and mec.especial == "pararCancao" and not apoio.cancao then motivo = "Nenhuma canção ativa" end
			if apoio and mec.especial == "inspirar" and apoio.inspiracoesUsadas >= apoio.inspiracoesMax then motivo = "Sem usos de Inspiração neste descanso" end
			contagens.Tudo += 1
			if contagens[registro.grupo] then contagens[registro.grupo] += 1 end
			registro.carta.Visible = grupo == "Tudo" or grupo == registro.grupo
			registro.carta:SetAttribute("Bloqueada", motivo ~= nil)
			registro.carta:SetAttribute("Motivo", motivo)
			registro.carta:SetAttribute("Ativa", ativa == true)
			detalhe.atualizar(id, registro.dadosDetalhe())
			tooltip.atualizar(id, registro.dadosDetalhe())
			registro.carta.Resumo.Text = motivo or registro.resumo
			registro.carta.Resumo.TextColor3 = if motivo then Estilo.ALERTA else Estilo.TINTA_SUAVE
			registro.carta.BackgroundTransparency = if motivo then 0.55 else 0
			local armada = mira ~= nil and mira.habilidadeId == id
			registro.stroke.Color = if armada or ativa then registro.cor else Estilo.FIO_COR
			registro.stroke.Thickness = if armada or ativa then 3 else 1.5
		end
		local registroMira = mira and cartas[mira.habilidadeId]
		confirmar.Visible = registroMira ~= nil and (mira.modo == "confirmar" or mira.modo == "lista" or mira.ponto ~= nil)
		if confirmar.Visible then
			local quantidade = #(mira.alvoIds or {})
			local pronto = (mira.modo == "confirmar" or mira.ponto ~= nil or quantidade > 0) and not registroMira.carta:GetAttribute("Bloqueada")
			confirmar.Text = if mira.ponto then "Confirmar área" elseif mira.modo == "lista" then (if quantidade > 0 then "Confirmar "..quantidade..(if quantidade == 1 then " alvo" else " alvos") else "Escolha os alvos") else "Usar habilidade"
			confirmar.BackgroundTransparency = if pronto then 0 else .55
			confirmar:SetAttribute("Bloqueada", not pronto)
		end
		for nome, b in botoesGrupo do
			b.Text = nome .. " · " .. contagens[nome]
			b.BackgroundColor3 = if grupo == nome then Estilo.DESTAQUE_FUNDO else Estilo.BOTAO
		end
		cartasVisiveis = contagens[grupo]
		redimensionar()
		if mira then
			local mec = Execucao.MECANICAS[mira.habilidadeId]
			subtitulo.Text = if mira.modo == "lista" then string.format("%d/%d alvos • Escolha as fichas e toque em Confirmar", #(mira.alvoIds or {}), mira.maxAlvos)
				elseif mira.modo == "ficha" then "Clique no alvo (ataque básico também atinge barreiras) • Cancelar mira para voltar"
				elseif mira.modo == "confirmar" then "Toque em Usar habilidade para confirmar • Cancelar mira para voltar"
				elseif mec and mec.moldavel then "Escolha início e fim • veja a prévia • Confirmar área"
				elseif mec and (mec.tipo == "zona" or mec.alvo == "cone" or mec.alvo == "esferaNaCasa") then "Clique para fixar a prévia • Confirmar área • Cancelar mira para voltar"
				else "Clique numa casa • Cancelar mira para voltar"
		else
			subtitulo.Text = if token.estadosCombate and #token.estadosCombate > 0 then "Efeitos: " .. table.concat(token.estadosCombate, ", ") else "Escolha uma habilidade ou Andar. As Ações voltam no seu próximo turno."
		end
	end

	cartasFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function() tooltip.fechar() end)
	gui.Destroying:Connect(function() tooltip.fechar() end)
	if state.onFichaDetalhe then state.onFichaDetalhe(function(id) if id == atual.tokenId then atualizar() end end) end
	state.onSnapshot(atualizar)
	state.onMira(function()
		if modoBaixo and state.mira() then recolhido = true end
		atualizar()
	end)
	atualizar()
	return gui
end

return AcoesDoTurno
