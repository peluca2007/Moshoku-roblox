-- Criação enxuta em 3 passos (P2): Raça -> Aparência -> Nome. Atributos, perícias e antecedente vêm do
-- preset recomendado (shared/Regras/CriacaoPreset) e o servidor valida tudo de novo. Só apresentação:
-- quem envia a ficha, inicia a run e salva a aparência é o AberturaFluxo (callbacks de `abrir`).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogo = require(Shared.Livro.Catalogo)
local Preset = require(Shared.Regras.CriacaoPreset)
local AparenciaEstado = require(Shared.Aparencia.EditorEstado)
local Extra = require(script.Parent.UI.ExtraEntrada)
local T, C = Extra.T, Extra.C

local View = {}

local PASSOS = { "Raça", "Aparência", "Nome" }

local function criar(classe, props, pai)
	local o = Instance.new(classe)
	for k, v in props do o[k] = v end
	o.Parent = pai
	return o
end

function View.start(opcoes)
	local aparenciaFluxo = opcoes.aparenciaFluxo
	local sorteio = Random.new()
	local gui = criar("ScreenGui", { Name = "CriacaoRapida", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30,
		Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local fundo = criar("Frame", { Name = "Fundo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.cores.painel,
		BackgroundTransparency = 0.12, BorderSizePixel = 0, Active = true }, gui)
	local moldura = C.painel({ parent = fundo, nome = "Moldura", losangos = true, padding = 16,
		tamanho = UDim2.fromScale(0.94, 0.94), posicao = UDim2.fromScale(0.5, 0.5), ancora = Vector2.new(0.5, 0.5) })
	criar("UISizeConstraint", { MaxSize = Vector2.new(720, 880) }, moldura)
	local corpo = moldura.Conteudo

	C.titulo({ parent = corpo, nome = "Titulo", texto = "Crie seu aventureiro", posicao = UDim2.fromOffset(0, 0), tamanho = UDim2.new(1, 0, 0, 30) })
	-- Indicador de passos: três pílulas; o passo atual fica em ouro.
	local indicador = criar("Frame", { Name = "Passos", Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1 }, corpo)
	criar("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center }, indicador)
	local pilulas = {}
	for i, nome in PASSOS do
		local p = criar("TextLabel", { Name = "Passo" .. i, LayoutOrder = i, Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = T.cores.painel,
			BorderSizePixel = 0, Text = i .. "  " .. nome, TextColor3 = T.cores.secundario, FontFace = T.fontes.rotulo,
			TextSize = T.tamanhos.corpo, TextTruncate = Enum.TextTruncate.AtEnd }, indicador)
		criar("UICorner", { CornerRadius = UDim.new(0, T.raios.botao) }, p)
		criar("UIStroke", { Color = T.cores.borda, Thickness = 1 }, p)
		pilulas[i] = p
	end

	-- Área central e rodapé fixo.
	local area = criar("Frame", { Name = "Area", Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -92 - 64),
		BackgroundTransparency = 1, ClipsDescendants = true }, corpo)
	local rodape = criar("Frame", { Name = "Rodape", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1 }, corpo)
	local voltar = C.botao({ parent = rodape, nome = "Voltar", texto = "Voltar", variante = "secundario",
		tamanho = UDim2.new(0.3, -6, 1, 0), posicao = UDim2.fromScale(0, 0) })
	local avancar = C.botao({ parent = rodape, nome = "Avancar", texto = "Continuar", variante = "principal",
		tamanho = UDim2.new(0.7, -6, 1, 0), posicao = UDim2.fromScale(0.3, 0) })
	avancar.Position = UDim2.new(0.3, 6, 0, 0)

	-- Estado da criação (somente intenção; o servidor confirma).
	local config, passo, ocupado = nil, 1, false
	local escolha = { raceId = nil, nome = "", aparenciaEstado = nil }
	local racas = {}
	local paginas = {}

	local function pagina(nome)
		local f = criar("Frame", { Name = nome, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, area)
		paginas[nome] = f
		return f
	end

	-- Passo 1: cartões grandes de raça (nome, nome no livro, uma frase, selo de bônus).
	local p1 = pagina("Raca")
	criar("TextLabel", { Name = "Dica", Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "Toque na raça do seu aventureiro.",
		TextColor3 = T.cores.secundario, FontFace = T.fontes.rotulo, TextSize = T.tamanhos.corpo, TextXAlignment = Enum.TextXAlignment.Left }, p1)
	local lista = criar("ScrollingFrame", { Name = "Racas", Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y }, p1)
	Extra.rolagem(lista)
	criar("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, lista)

	-- Passo 2: aparência (editor existente, opcional).
	local p2 = pagina("Aparencia")
	local resumoVisual = criar("TextLabel", { Name = "Texto", Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1, TextWrapped = true,
		Text = "", TextColor3 = T.cores.texto, FontFace = T.fontes.rotulo, TextSize = T.tamanhos.corpo,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, p2)
	local personalizar = C.botao({ parent = p2, nome = "Personalizar", texto = "Personalizar aparência", variante = "secundario",
		tamanho = UDim2.new(1, 0, 0, 56), posicao = UDim2.fromOffset(0, 100) })

	-- Passo 3: nome e confirmação.
	local p3 = pagina("Nome")
	criar("TextLabel", { Name = "RotuloNome", Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "Como ele se chama?",
		TextColor3 = T.cores.texto, FontFace = T.fontes.rotulo, TextSize = T.tamanhos.corpo, TextXAlignment = Enum.TextXAlignment.Left }, p3)
	local campo = criar("TextBox", { Name = "NomePersonagem", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -112, 0, 48),
		BackgroundColor3 = T.cores.painel, TextColor3 = T.cores.texto, PlaceholderText = "Nome do personagem", PlaceholderColor3 = T.cores.secundario,
		Text = "", ClearTextOnFocus = false, MultiLine = false, FontFace = T.fontes.rotulo, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left }, p3)
	criar("UICorner", { CornerRadius = UDim.new(0, T.raios.botao) }, campo)
	criar("UIStroke", { Color = T.cores.borda, Thickness = 1 }, campo)
	criar("UIPadding", { PaddingLeft = UDim.new(0, 12) }, campo)
	local dado = C.botao({ parent = p3, nome = "Dado", texto = "Sortear", variante = "secundario",
		tamanho = UDim2.fromOffset(104, 48), posicao = UDim2.new(1, -104, 0, 30) })
	local resumo = criar("TextLabel", { Name = "Resumo", Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1,
		TextWrapped = true, Text = "", TextColor3 = T.cores.secundario, FontFace = T.fontes.rotulo, TextSize = T.tamanhos.corpo,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, p3)
	local erro = criar("TextLabel", { Name = "Erro", Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1,
		TextWrapped = true, Text = "", TextColor3 = T.cores.vinho or Color3.fromRGB(220, 90, 90), FontFace = T.fontes.rotulo,
		TextSize = T.tamanhos.corpo, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Visible = false }, p3)
	local avancado = C.botao({ parent = p3, nome = "Avancado", texto = "Ajustar ficha (avançado)", variante = "fantasma",
		tamanho = UDim2.new(1, 0, 0, 48), posicao = UDim2.new(0, 0, 1, -48) })

	campo:GetPropertyChangedSignal("Text"):Connect(function()
		local texto = campo.Text
		local ok, limite = pcall(utf8.offset, texto, 33)
		if ok and limite then texto = string.sub(texto, 1, limite - 1); campo.Text = texto end
		escolha.nome = texto
	end)

	local function racaAtual() return escolha.raceId and Catalogo.POR_ID[escolha.raceId] end
	local function mostrarErro(texto)
		erro.Text = texto or ""
		erro.Visible = texto ~= nil and texto ~= ""
	end

	local function atualizarResumos()
		local raca = racaAtual()
		if not raca then return end
		resumoVisual.Text = string.format("%s · %s\nSeu visual padrão já está pronto. Personalize se quiser — dá para mudar depois no espelho da vila.",
			Preset.nomeCurto(raca), Preset.selo(raca))
		resumo.Text = string.format("Raça: %s\nBônus: %s\nSua ficha já vem pronta (antecedente e atributos recomendados). Você aprende seu primeiro caminho de poder com um mestre da vila.",
			Preset.nomeCurto(raca), Preset.selo(raca))
	end

	local function irPara(n)
		passo = math.clamp(n, 1, #PASSOS)
		for i, p in pilulas do
			local atual, feito = i == passo, i < passo
			p.BackgroundColor3 = if atual then T.cores.ouro else T.cores.painel
			p.TextColor3 = if atual then T.cores.textoEscuro elseif feito then T.cores.ouro else T.cores.secundario
		end
		paginas.Raca.Visible, paginas.Aparencia.Visible, paginas.Nome.Visible = passo == 1, passo == 2, passo == 3
		voltar.Visible = passo > 1
		avancar.Visible = passo > 1
		avancar.Rotulo.Text = if passo == 3 then "Começar a aventura" else "Continuar"
		avancar.Size = if passo > 1 then UDim2.new(0.7, -6, 1, 0) else UDim2.new(1, 0, 1, 0)
		atualizarResumos()
	end

	local function selecionarRaca(raca)
		escolha.raceId = raca.id
		escolha.aparenciaEstado = AparenciaEstado.novo(raca.id, nil, config and config.cosmeticos or {})
		mostrarErro(nil)
		irPara(2)
	end

	local function montarCartoes()
		for _, filho in lista:GetChildren() do if filho:IsA("GuiObject") then filho:Destroy() end end
		for ordem, raca in racas do
			local b = C.botao({ parent = lista, nome = "Raca_" .. raca.data.id, texto = "", variante = "secundario",
				tamanho = UDim2.new(1, 0, 0, 112), ordem = ordem })
			b.Rotulo.Visible = false
			criar("Frame", { Size = UDim2.new(0, T.espessuras.destaque, 1, -16), Position = UDim2.fromOffset(6, 8),
				BackgroundColor3 = T.cores.ouro, BorderSizePixel = 0, ZIndex = 6 }, b)
			local titulo = C.titulo({ parent = b, texto = Preset.nomeCurto(raca), posicao = UDim2.fromOffset(18, 6), tamanho = UDim2.new(1, -30, 0, 26) })
			titulo.TextSize, titulo.AutomaticSize, titulo.TextTruncate = T.tamanhos.subtitulo, Enum.AutomaticSize.None, Enum.TextTruncate.AtEnd
			local livro = C.texto({ parent = b, texto = "No livro: " .. raca.data.name, secundario = true, posicao = UDim2.fromOffset(18, 34), tamanho = UDim2.new(1, -30, 0, 20) })
			livro.AutomaticSize, livro.TextWrapped, livro.TextTruncate = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
			local frase = C.texto({ parent = b, texto = Preset.frase(raca), posicao = UDim2.fromOffset(18, 56), tamanho = UDim2.new(1, -30, 0, 22) })
			frase.AutomaticSize, frase.TextWrapped, frase.TextTruncate = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
			local selo = C.texto({ parent = b, texto = Preset.selo(raca), posicao = UDim2.fromOffset(18, 82), tamanho = UDim2.new(1, -30, 0, 22) })
			selo.AutomaticSize, selo.TextWrapped, selo.TextTruncate, selo.TextColor3 = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd, T.cores.ouro
			b.Activated:Connect(function() if not ocupado then selecionarRaca(raca) end end)
		end
	end

	local function sortearNome()
		campo.Text = Preset.sugerirNome(function(lo, hi) return sorteio:NextInteger(lo, hi) end)
	end
	dado.Activated:Connect(function() if not ocupado then sortearNome(); mostrarErro(nil) end end)

	personalizar.Activated:Connect(function()
		if ocupado or not aparenciaFluxo or not racaAtual() then return end
		aparenciaFluxo.editar(escolha.raceId, escolha.aparenciaEstado.aparencia, config.cosmeticos or {}, function(a, fecharEditor)
			escolha.aparenciaEstado = AparenciaEstado.novo(escolha.raceId, a, config.cosmeticos or {})
			fecharEditor()
			irPara(3)
		end)
	end)

	voltar.Activated:Connect(function() if not ocupado then irPara(passo - 1) end end)
	avancar.Activated:Connect(function()
		if ocupado then return end
		if passo < 3 then irPara(passo + 1); return end
		local nome, motivo = Preset.nomeValido(escolha.nome)
		if not nome then mostrarErro(motivo); return end
		local ficha, motivoFicha = Preset.criar(Catalogo, escolha.raceId, nil)
		if not ficha then mostrarErro(motivoFicha); return end
		ficha.nome = nome
		ficha.requestId = HttpService:GenerateGUID(false)
		mostrarErro(nil)
		ocupado = true
		avancar.Rotulo.Text = "Criando seu aventureiro…"
		avancar:SetAttribute("Desabilitado", true)
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
		avancar:SetAttribute("Desabilitado", false)
		escolha.raceId = nil
		montarCartoes()
		campo.Text = ""
		sortearNome()
		mostrarErro(nil)
		irPara(1)
		gui.Enabled = true
	end
	function api.fechar()
		if aparenciaFluxo then aparenciaFluxo.fechar() end
		gui.Enabled = false
	end
	function api.aberta() return gui.Enabled end
	-- Resposta ruim do servidor: o texto sempre nomeia o campo e fica no passo 3, ao lado do botão de confirmar.
	function api.falhou(texto)
		ocupado = false
		avancar:SetAttribute("Desabilitado", false)
		local campoErro = string.match(texto or "", "^([^:]+):")
		mostrarErro((if campoErro then "Campo inválido: " .. campoErro .. ". " else "") .. (texto or "O servidor recusou a ficha."))
		irPara(3)
	end
	function api.mensagem(texto) mostrarErro(texto) end
	function api.ocupado(valor) ocupado = valor end
	irPara(1)
	return api
end

return View
