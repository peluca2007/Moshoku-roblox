-- Criação enxuta em 3 passos (P2): Raça -> Aparência -> Nome. Atributos, perícias e antecedente vêm do
-- preset recomendado (shared/Regras/CriacaoPreset) e o servidor valida tudo de novo. Só apresentação:
-- quem envia a ficha, inicia a run e salva a aparência é o AberturaFluxo (callbacks de `abrir`).
-- Desenho: personagem 3D (CriacaoPrevia) à esquerda, painel de pergaminho com as escolhas da etapa à direita,
-- barra de etapas e botões embaixo. Regras de etapa (validade, rótulos) ficam em Regras/CriacaoRapidaTela.
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogo = require(Shared.Livro.Catalogo)
local Preset = require(Shared.Regras.CriacaoPreset)
local Tela = require(Shared.Regras.CriacaoRapidaTela)
local AparenciaEstado = require(Shared.Aparencia.EditorEstado)
local Extra = require(script.Parent.UI.ExtraEntrada)
local Previa = require(script.Parent.CriacaoPrevia)
local T, C = Extra.T, Extra.C

local View = {}

-- Layout (pixels). Nada de posições soltas fora desta tabela.
local L = {
	margem = 24, -- borda da tela (o topo soma o GuiInset do Roblox)
	painelLargura = 420,
	folga = 16, -- entre prévia, painel e barra de baixo
	rodapeAltura = 56,
	tituloAltura = 40,
	passoLargura = 150, passoAltura = 40, passoFolga = 8,
	voltarLargura = 140, avancarLargura = 260, botoesFolga = 12,
	paginaPadding = 26, -- além da moldura de arte do painel
	paginaTitulo = 40, -- altura reservada ao cabeçalho de cada página
	linhaRaca = 52, linhaRacaFolga = 6, racasFracao = 0.5, detalheFolga = 12,
	campoAltura = 48, dadoLargura = 104,
}

local function criar(classe, props, pai)
	local o = Instance.new(classe)
	for k, v in props do o[k] = v end
	o.Parent = pai
	return o
end

local function texto(pai, props)
	local p = { BackgroundTransparency = 1, TextWrapped = true, TextColor3 = T.cores.texto, FontFace = T.fontes.rotulo,
		TextSize = T.tamanhos.corpo, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 }
	for k, v in props do p[k] = v end
	return criar("TextLabel", p, pai)
end

function View.start(opcoes)
	local aparenciaFluxo = opcoes.aparenciaFluxo
	local sorteio = Random.new()
	local gui = criar("ScreenGui", { Name = "CriacaoRapida", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30,
		Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local fundo = criar("Frame", { Name = "Fundo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.cores.fundoTela,
		BorderSizePixel = 0, Active = true }, gui)
	-- Moldura/Conteudo: contêiner transparente (nomes mantidos para os roteiros de playtest). O topo começa
	-- abaixo da barra do Roblox (GuiInset), para nada ficar sob os botões do canto.
	local moldura = criar("Frame", { Name = "Moldura", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, fundo)
	local corpo = criar("Frame", { Name = "Conteudo", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, moldura)
	local margemCorpo = criar("UIPadding", { PaddingLeft = UDim.new(0, L.margem), PaddingRight = UDim.new(0, L.margem),
		PaddingBottom = UDim.new(0, L.margem) }, corpo)
	local function ajustarTopo() margemCorpo.PaddingTop = UDim.new(0, GuiService:GetGuiInset().Y + L.margem) end
	ajustarTopo()

	-- Prévia 3D (esquerda) + título por cima dela.
	local areaPrevia = criar("Frame", { Name = "Previa", Size = UDim2.new(1, -(L.painelLargura + L.folga), 1, -(L.rodapeAltura + L.folga)),
		BackgroundTransparency = 1 }, corpo)
	local previa = Previa.nova(areaPrevia)
	local dicaPrevia = texto(areaPrevia, { Name = "Dica", Size = UDim2.fromScale(1, 1), Text = "Escolha uma raça para ver seu aventureiro.",
		TextColor3 = T.sobreEscuro.secundario, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	local titulo = C.titulo({ parent = corpo, nome = "Titulo", texto = "Crie seu aventureiro", posicao = UDim2.new(),
		tamanho = UDim2.new(1, -(L.painelLargura + L.folga), 0, L.tituloAltura) })
	titulo.TextColor3 = T.sobreEscuro.titulo
	titulo.ZIndex = 8

	-- Painel de pergaminho (direita): as escolhas da etapa. Cada página é irmã do papel, acima dele.
	local area = criar("Frame", { Name = "Area", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, L.painelLargura, 1, -(L.rodapeAltura + L.folga)), BackgroundTransparency = 1 }, corpo)
	C.painel({ parent = area, nome = "Pergaminho", tamanho = UDim2.fromScale(1, 1), padding = 0 })

	-- Barra de baixo: etapas à esquerda, Voltar/Continuar à direita.
	local rodape = criar("Frame", { Name = "Rodape", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, L.rodapeAltura), BackgroundTransparency = 1 }, corpo)
	local indicador = criar("Frame", { Name = "Passos", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, #Tela.PASSOS * (L.passoLargura + L.passoFolga), 0, L.passoAltura), BackgroundTransparency = 1 }, rodape)
	criar("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, L.passoFolga),
		SortOrder = Enum.SortOrder.LayoutOrder }, indicador)
	local pilulas = {}
	for i = 1, #Tela.PASSOS do
		local p = criar("TextLabel", { Name = "Passo" .. i, LayoutOrder = i, Size = UDim2.fromOffset(L.passoLargura, L.passoAltura),
			BackgroundColor3 = T.cores.painel, BorderSizePixel = 0, Text = "", TextColor3 = T.cores.secundario, FontFace = T.fontes.rotulo,
			TextSize = T.tamanhos.corpo, TextTruncate = Enum.TextTruncate.AtEnd }, indicador)
		criar("UICorner", { CornerRadius = UDim.new(0, T.raios.botao) }, p)
		criar("UIStroke", { Color = T.cores.borda, Thickness = T.espessuras.fio }, p)
		pilulas[i] = p
	end
	local avancar = C.botao({ parent = rodape, nome = "Avancar", texto = "Continuar", variante = "principal",
		tamanho = UDim2.fromOffset(L.avancarLargura, L.rodapeAltura), ancora = Vector2.new(1, 0), posicao = UDim2.fromScale(1, 0) })
	local voltar = C.botao({ parent = rodape, nome = "Voltar", texto = "Voltar", variante = "secundario",
		tamanho = UDim2.fromOffset(L.voltarLargura, L.rodapeAltura), ancora = Vector2.new(1, 0),
		posicao = UDim2.new(1, -(L.avancarLargura + L.botoesFolga), 0, 0) })

	-- Estado da criação (somente intenção; o servidor confirma).
	local config, passo, ocupado = nil, 1, false
	local escolha = { raceId = nil, nome = "", aparenciaEstado = nil }
	local racas = {}
	local paginas = {}
	local marcas = {} -- raceId -> { selo, faixa } do cartão

	local function pagina(nome, rotulo)
		local f = criar("Frame", { Name = nome, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5 }, area)
		criar("UIPadding", { PaddingTop = UDim.new(0, L.paginaPadding), PaddingBottom = UDim.new(0, L.paginaPadding),
			PaddingLeft = UDim.new(0, L.paginaPadding), PaddingRight = UDim.new(0, L.paginaPadding) }, f)
		C.titulo({ parent = f, nome = "Cabecalho", texto = rotulo, tamanho = UDim2.new(1, 0, 0, L.paginaTitulo) }).ZIndex = 6
		paginas[nome] = f
		return f
	end

	-- Passo 1: lista compacta de raças + detalhe da raça escolhida (bônus em destaque, descrição curta).
	local p1 = pagina("Raca", "Raça")
	local lista = criar("ScrollingFrame", { Name = "Racas", Position = UDim2.fromOffset(0, L.paginaTitulo),
		Size = UDim2.new(1, 0, L.racasFracao, -L.paginaTitulo), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 5 }, p1)
	Extra.rolagem(lista)
	criar("UIListLayout", { Padding = UDim.new(0, L.linhaRacaFolga), SortOrder = Enum.SortOrder.LayoutOrder }, lista)
	local detalhe = criar("ScrollingFrame", { Name = "Detalhe", Position = UDim2.new(0, 0, L.racasFracao, L.detalheFolga),
		Size = UDim2.new(1, 0, 1 - L.racasFracao, -L.detalheFolga), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 5 }, p1)
	Extra.rolagem(detalhe)
	criar("UIListLayout", { Padding = UDim.new(0, T.espacamentos.pequeno), SortOrder = Enum.SortOrder.LayoutOrder }, detalhe)
	local dNome = texto(detalhe, { Name = "Nome", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Text = "Escolha uma raça na lista.", TextColor3 = T.cores.titulo, FontFace = T.fontes.subtitulo, TextSize = T.tamanhos.subtitulo })
	local dBonus = texto(detalhe, { Name = "Bonus", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Text = "", TextColor3 = T.cores.ouro, TextSize = T.tamanhos.rotulo })
	local dFrase = texto(detalhe, { Name = "Descricao", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "" })
	local dLivro = texto(detalhe, { Name = "NoLivro", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Text = "", TextColor3 = T.cores.secundario })

	-- Passo 2: aparência (editor existente, opcional).
	local p2 = pagina("Aparencia", "Aparência")
	local resumoVisual = texto(p2, { Name = "Texto", Position = UDim2.fromOffset(0, L.paginaTitulo), Size = UDim2.new(1, 0, 0, 120), Text = "" })
	local personalizar = C.botao({ parent = p2, nome = "Personalizar", texto = "Personalizar aparência", variante = "secundario",
		tamanho = UDim2.new(1, 0, 0, 56), posicao = UDim2.fromOffset(0, L.paginaTitulo + 130) })

	-- Passo 3: nome e confirmação.
	local p3 = pagina("Nome", "Nome")
	texto(p3, { Name = "RotuloNome", Position = UDim2.fromOffset(0, L.paginaTitulo), Size = UDim2.new(1, 0, 0, 24), Text = "Como ele se chama?", TextWrapped = false })
	local campoY = L.paginaTitulo + 30
	local campo = criar("TextBox", { Name = "NomePersonagem", Position = UDim2.fromOffset(0, campoY), Size = UDim2.new(1, -(L.dadoLargura + 8), 0, L.campoAltura),
		BackgroundColor3 = T.cores.cabecalho, TextColor3 = T.cores.texto, PlaceholderText = "Nome do personagem", PlaceholderColor3 = T.cores.secundario,
		Text = "", ClearTextOnFocus = false, MultiLine = false, FontFace = T.fontes.rotulo, TextSize = T.tamanhos.rotulo,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 }, p3)
	criar("UICorner", { CornerRadius = UDim.new(0, T.raios.botao) }, campo)
	criar("UIStroke", { Color = T.cores.borda, Thickness = T.espessuras.botao }, campo)
	criar("UIPadding", { PaddingLeft = UDim.new(0, 12) }, campo)
	local dado = C.botao({ parent = p3, nome = "Dado", texto = "Sortear", variante = "secundario",
		tamanho = UDim2.fromOffset(L.dadoLargura, L.campoAltura), ancora = Vector2.new(1, 0), posicao = UDim2.new(1, 0, 0, campoY) })
	local resumo = texto(p3, { Name = "Resumo", Position = UDim2.fromOffset(0, campoY + L.campoAltura + 16), Size = UDim2.new(1, 0, 0, 150),
		Text = "", TextColor3 = T.cores.secundario })
	local erro = texto(p3, { Name = "Erro", Position = UDim2.fromOffset(0, campoY + L.campoAltura + 16 + 156), Size = UDim2.new(1, 0, 0, 52),
		Text = "", TextColor3 = T.cores.perigo, Visible = false })
	local avancado = C.botao({ parent = p3, nome = "Avancado", texto = "Ajustar ficha (avançado)", variante = "fantasma",
		tamanho = UDim2.new(1, 0, 0, 48), ancora = Vector2.new(0, 1), posicao = UDim2.fromScale(0, 1) })

	local function racaAtual() return escolha.raceId and Catalogo.POR_ID[escolha.raceId] end
	local function mostrarErro(msg)
		erro.Text = msg or ""
		erro.Visible = msg ~= nil and msg ~= ""
	end

	local function atualizarPrevia()
		local raca = racaAtual()
		dicaPrevia.Visible = raca == nil
		if raca and escolha.aparenciaEstado then
			previa.definir(AparenciaEstado.clone(escolha.aparenciaEstado.aparencia), escolha.raceId)
		else
			previa.limpar()
		end
	end

	local function atualizarBotao()
		avancar.Rotulo.Text = Tela.rotuloAvancar(passo, ocupado)
		avancar:SetAttribute("Desabilitado", ocupado or not Tela.passoValido(passo, escolha, Preset.nomeValido))
	end

	local function atualizarResumos()
		local raca = racaAtual()
		if raca then
			dNome.Text = Preset.nomeCurto(raca)
			dBonus.Text = "Bônus: " .. Preset.selo(raca)
			dFrase.Text = Preset.frase(raca)
			dLivro.Text = "No livro: " .. raca.data.name
			resumoVisual.Text = string.format("%s · %s\nSeu visual padrão já está pronto. Personalize se quiser — dá para mudar depois no espelho da vila. Arraste o personagem para girá-lo.",
				Preset.nomeCurto(raca), Preset.selo(raca))
			resumo.Text = string.format("Raça: %s\nBônus: %s\nSua ficha já vem pronta (antecedente e atributos recomendados). Você aprende seu primeiro caminho de poder com um mestre da vila.",
				Preset.nomeCurto(raca), Preset.selo(raca))
		else
			dNome.Text, dBonus.Text, dFrase.Text, dLivro.Text = "Escolha uma raça na lista.", "", "", ""
		end
		for id, m in marcas do
			m.selo.Visible, m.faixa.Visible = id == escolha.raceId, id == escolha.raceId
		end
	end

	local function irPara(n)
		passo = Tela.limitar(n)
		local estados = Tela.estadoDosPassos(passo)
		for i, p in pilulas do
			local e = estados[i]
			p.BackgroundColor3 = if e == "atual" then T.cores.ouro else T.cores.painel
			p.TextColor3 = if e == "atual" then T.cores.textoEscuro elseif e == "feito" then T.cores.sucesso else T.cores.secundario
			p.Text = (if e == "feito" then "✓" else tostring(i)) .. "  " .. Tela.PASSOS[i]
		end
		paginas.Raca.Visible, paginas.Aparencia.Visible, paginas.Nome.Visible = passo == 1, passo == 2, passo == 3
		voltar.Visible = Tela.mostraVoltar(passo)
		atualizarResumos()
		atualizarPrevia()
		atualizarBotao()
	end

	local function selecionarRaca(raca)
		escolha.raceId = raca.id
		escolha.aparenciaEstado = AparenciaEstado.novo(raca.id, nil, config and config.cosmeticos or {})
		mostrarErro(nil)
		atualizarResumos()
		atualizarPrevia()
		atualizarBotao()
	end

	local function montarCartoes()
		for _, filho in lista:GetChildren() do if filho:IsA("GuiObject") then filho:Destroy() end end
		table.clear(marcas)
		for ordem, raca in racas do
			local b = C.botao({ parent = lista, nome = "Raca_" .. raca.data.id, texto = Preset.nomeCurto(raca), variante = "secundario",
				tamanho = UDim2.new(1, 0, 0, L.linhaRaca), ordem = ordem })
			-- Selecionada: fundo `botao_ativo` + faixa lateral em destaque (o botão só repinta no hover).
			local selo = C.arte({ parent = b, nome = "Selecionada", peca = "botao_ativo", sangria = 3, zIndex = 5, tamanho = UDim2.fromScale(1, 1) })
			selo.Visible, selo.ZIndex = false, 5
			local faixa = criar("Frame", { Name = "Faixa", Size = UDim2.new(0, T.espessuras.destaque, 1, -16), Position = UDim2.fromOffset(6, 8),
				BackgroundColor3 = T.cores.ouro, BorderSizePixel = 0, ZIndex = 7, Visible = false }, b)
			b.Rotulo.Position, b.Rotulo.Size = UDim2.fromOffset(20, 0), UDim2.new(1, -32, 1, 0)
			b.Rotulo.TextXAlignment, b.Rotulo.TextWrapped = Enum.TextXAlignment.Left, false
			marcas[raca.id] = { selo = selo, faixa = faixa }
			b.Activated:Connect(function() if not ocupado then selecionarRaca(raca) end end)
		end
	end

	local function sortearNome()
		campo.Text = Preset.sugerirNome(function(lo, hi) return sorteio:NextInteger(lo, hi) end)
	end
	campo:GetPropertyChangedSignal("Text"):Connect(function()
		local conteudo = campo.Text
		local ok, limite = pcall(utf8.offset, conteudo, 33)
		if ok and limite then conteudo = string.sub(conteudo, 1, limite - 1); campo.Text = conteudo end
		escolha.nome = conteudo
		if passo == Tela.NOME and not ocupado then
			local _, motivo = Preset.nomeValido(conteudo)
			mostrarErro(if conteudo ~= "" then motivo else nil)
		end
		atualizarBotao()
	end)
	dado.Activated:Connect(function() if not ocupado then sortearNome(); mostrarErro(nil) end end)

	personalizar.Activated:Connect(function()
		if ocupado or not aparenciaFluxo or not racaAtual() then return end
		aparenciaFluxo.editar(escolha.raceId, escolha.aparenciaEstado.aparencia, config.cosmeticos or {}, function(a, fecharEditor)
			escolha.aparenciaEstado = AparenciaEstado.novo(escolha.raceId, a, config.cosmeticos or {})
			fecharEditor()
			irPara(3) -- a prévia central é refeita com a aparência nova
		end)
	end)

	voltar.Activated:Connect(function() if not ocupado then irPara(passo - 1) end end)
	avancar.Activated:Connect(function()
		if ocupado or not Tela.passoValido(passo, escolha, Preset.nomeValido) then return end
		if passo < #Tela.PASSOS then irPara(passo + 1); return end
		local nome, motivo = Preset.nomeValido(escolha.nome)
		if not nome then mostrarErro(motivo); return end
		local ficha, motivoFicha = Preset.criar(Catalogo, escolha.raceId, nil)
		if not ficha then mostrarErro(motivoFicha); return end
		ficha.nome = nome
		ficha.requestId = HttpService:GenerateGUID(false)
		mostrarErro(nil)
		ocupado = true
		atualizarBotao()
		config.aoConfirmar(ficha, AparenciaEstado.clone(escolha.aparenciaEstado.aparencia), escolha.raceId)
	end)
	avancado.Activated:Connect(function()
		if ocupado then return end
		config.aoAvancado()
	end)

	local api = {}
	-- config = { racas = lista de raças liberadas, cosmeticos, aoConfirmar(ficha, aparencia, raceId), aoAvancado() }
	function api.abrir(c)
		config = c
		racas = c.racas
		ocupado = false
		escolha.raceId, escolha.aparenciaEstado = nil, nil
		ajustarTopo()
		montarCartoes()
		campo.Text = ""
		sortearNome()
		mostrarErro(nil)
		irPara(1)
		gui.Enabled = true
		previa.ligar(true)
	end
	function api.fechar()
		if aparenciaFluxo then aparenciaFluxo.fechar() end
		previa.ligar(false)
		gui.Enabled = false
	end
	function api.aberta() return gui.Enabled end
	-- Resposta ruim do servidor: o texto sempre nomeia o campo e fica no passo 3, ao lado do botão de confirmar.
	function api.falhou(msg)
		ocupado = false
		local campoErro = string.match(msg or "", "^([^:]+):")
		irPara(3)
		mostrarErro((if campoErro then "Campo inválido: " .. campoErro .. ". " else "") .. (msg or "O servidor recusou a ficha."))
	end
	function api.mensagem(msg) mostrarErro(msg) end
	function api.ocupado(valor) ocupado = valor; atualizarBotao() end
	irPara(1)
	return api
end

return View
