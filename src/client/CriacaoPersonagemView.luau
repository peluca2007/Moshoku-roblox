-- Tela de construção própria. Envia somente escolhas; servidor calcula e persiste
-- o perfil pessoal. Escolha de combate envia apenas um ID reservado.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogo = require(Shared.Livro.Catalogo)
local KitsIniciais = require(Shared.KitsIniciais)
local Extra = require(script.Parent.UI.ExtraEntrada)
local T = Extra.T
local Progressao = require(Shared.Regras.Progressao)
local PericiasDeCriacao = require(Shared.Regras.PericiasDeCriacao)
local RunConta = require(Shared.Regras.RunConta)
local AparenciaEstado = require(Shared.Aparencia.EditorEstado)
local Componentes = require(script.Parent.UI.Componentes)
local AparenciaFluxo = require(script.Parent.AparenciaFluxo)
local Preset = require(Shared.Regras.CriacaoPreset)

local CriacaoView = {}
local ATRIBUTOS = {
	{ id = "forca", nome = "Força" },
	{ id = "agilidade", nome = "Agilidade" },
	{ id = "vigor", nome = "Vigor" },
	{ id = "intelecto", nome = "Intelecto" },
	{ id = "espirito", nome = "Espírito" },
}

local function nome(entrada)
	if type(entrada) == "string" then return entrada end
	return entrada and ((entrada.data and (entrada.data.name or entrada.data.rank)) or entrada.nome) or "—"
end

local function ordenar(lista)
	table.sort(lista, function(a, b)
		return nome(a) < nome(b)
	end)
	return lista
end

function CriacaoView.start(state)
	local aparenciaFluxo = AparenciaFluxo.start()
	local aparenciaEstado, aparenciaPendente
	local cosmeticos = {}
	local catalogo = Catalogo
	local eu = Players.LocalPlayer
	local tela = Instance.new("ScreenGui")
	tela.Name, tela.ResetOnSpawn, tela.IgnoreGuiInset = "CriacaoPersonagem", false, true
	tela.DisplayOrder, tela.Enabled = 25, false
	tela.Parent = eu:WaitForChild("PlayerGui")

	local fundo = Instance.new("Frame")
	fundo.Name, fundo.Size = "Fundo", UDim2.fromScale(1, 1)
	fundo.BackgroundColor3, fundo.BackgroundTransparency = T.cores.painel, 0.05
	fundo.Parent = tela
	local painel = Instance.new("Frame")
	painel.Name, painel.AnchorPoint = "Painel", Vector2.new(0.5, 0.5)
	painel.Position, painel.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.92, 0.9)
	painel.BackgroundColor3, painel.Parent = T.cores.painel, fundo
	local borda = Instance.new("UIStroke", painel)
	borda.Color, borda.Thickness = T.cores.borda, T.espessuras.borda
	Instance.new("UICorner", painel).CornerRadius = UDim.new(0, T.raios.painel)
	Instance.new("UISizeConstraint", painel).MaxSize = Vector2.new(760, 900)

	local ordemFormulario = 0
	local conteudo
	local function criar(class, parent, props)
		local objeto = Instance.new(class)
		for chave, valor in props do objeto[chave] = valor end
		if parent == conteudo and objeto:IsA("GuiObject") then
			ordemFormulario += 1; objeto.LayoutOrder = ordemFormulario
		end
		objeto.Parent = parent
		Extra.estilizar(objeto, props.FontFace)
		return objeto
	end
	local titulo = criar("TextLabel", painel, {
		Name = "Titulo", Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -76, 0, 32),
		BackgroundTransparency = 1, Text = "CRIAR PERSONAGEM", TextColor3 = T.cores.texto,
		FontFace = T.fontes.titulo, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local fechar = criar("TextButton", painel, {
		Name = "Fechar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(44, 44), BackgroundColor3 = T.cores.painel, BorderSizePixel = 0, Text = "×",
		TextColor3 = T.cores.texto, FontFace = T.fontes.titulo, TextSize = 28,
	})
	Instance.new("UICorner", fechar).CornerRadius = UDim.new(0, T.raios.botao)
	local aoFechar = nil
	local function fecharTela()
		aparenciaFluxo.fechar()
		tela.Enabled = false
		if aoFechar then aoFechar() end
	end
	fechar.Activated:Connect(fecharTela)
	local passos = criar("TextLabel", painel, {
		Name="Passos", Position=UDim2.fromOffset(18,54), Size=UDim2.new(1,-36,0,64),
		BackgroundTransparency=1, Text="1 Raça → 2 Antecedente → 3 Atributos → 4 Perícias → 5 Árvore → 6 Aparência → 7 Confirmar",
		TextColor3=T.cores.titulo, FontFace=T.fontes.rotulo, TextSize=T.tamanhos.corpo, TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left,
	})
	conteudo = criar("ScrollingFrame", painel, {
		Name = "Conteudo", Position = UDim2.fromOffset(18, 124), Size = UDim2.new(1, -36, 1, -156),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
	})
	Extra.rolagem(conteudo)
	local orientacao = criar("TextLabel", painel, {Name="Rolagem", Position=UDim2.new(0,18,1,-28), Size=UDim2.new(1,-36,0,24),
		BackgroundTransparency=1, Text="Role para percorrer os sete passos", TextColor3=T.cores.secundario, FontFace=T.fontes.rotulo, TextSize=T.tamanhos.corpo})
	local aviso = criar("TextLabel", conteudo, {
		Name="Aviso", Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1, Text="Distribua 2 pontos de atributo. PA são pontos de aprimoramento: a raça escolhida desconta PA. Valide e selecione a ficha para jogar. Itens do kit começam sem equipamento.",
		TextColor3=T.cores.secundario, FontFace=T.fontes.rotulo, TextSize=T.tamanhos.corpo,
		TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left,
	})
	aviso.LayoutOrder = -1
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, T.espacamentos.pequeno), Enum.SortOrder.LayoutOrder, conteudo

	local function label(texto: string, parent: Instance?): TextLabel
		return criar("TextLabel", parent or conteudo, {
			Size = UDim2.new(1, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, BackgroundTransparency = 1, Text = texto,
			TextColor3 = T.cores.texto, FontFace = T.fontes.rotulo, TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local function botao(texto: string, parent: Instance?, altura: number?): TextButton
		local b = criar("TextButton", parent or conteudo, {
			Size = UDim2.new(1, 0, 0, math.max(T.toqueMinimo, altura or 48)), BackgroundColor3 = T.cores.painel,
			BorderSizePixel = 0, Text = texto, TextColor3 = T.cores.texto, FontFace = T.fontes.rotulo,
			TextSize = 14, TextWrapped = true, AutoButtonColor = true,
		})
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, T.raios.botao)
		return b
	end

	local arvoresComKit = {}
	for _, arvore in catalogo.POR_ESPECIE.tree or {} do
		local kit = type(arvore.data.subgroup) == "string" and KitsIniciais.obter(arvore.data.subgroup) or nil
		if type(kit) == "table" and type(kit.items) == "table" and #kit.items > 0 then
			table.insert(arvoresComKit, arvore)
		end
	end
	local especies = {
		racas = ordenar(table.clone(catalogo.POR_ESPECIE.race or {})),
		antecedentes = ordenar(table.clone(catalogo.POR_ESPECIE.background or {})),
		arvores = ordenar(arvoresComKit),
		pericias = ordenar(table.clone(catalogo.POR_ESPECIE.skill or {})),
	}
	local escolha, statusResultado, construirFormulario
	local racasCatalogo = table.clone(especies.racas)
	local racasBase = {}
	for _, raca in racasCatalogo do
		local tier = raca.data and raca.data.tier
		if tier == "comum" or tier == "incomum" then racasBase[raca.id] = true end
	end
	local racasPermitidas = table.clone(racasBase)
	local contaRemote, consultaContaPendente = nil, nil
	local sequenciaConsultaConta = 0
	local function aplicarRacasLiberadas(conta)
		local liberadas = RunConta.racasLiberadas(conta)
		racasPermitidas = table.clone(racasBase)
		for _, raca in racasCatalogo do
			if raca.data and raca.data.tier == "rara" and liberadas[raca.id] == true then racasPermitidas[raca.id] = true end
		end
		local filtradas = {}
		for _, raca in racasCatalogo do
			local tier = raca.data and raca.data.tier
			if racasBase[raca.id] or (tier == "rara" and liberadas[raca.id] == true) then
				table.insert(filtradas, raca)
			end
		end
		if #filtradas == 0 then
			for _, raca in racasCatalogo do if racasBase[raca.id] then table.insert(filtradas, raca) end end
		end
		especies.racas = filtradas
		local selecionada = false
		for _, raca in filtradas do if raca.id == escolha.raceId then selecionada = true; break end end
		if not selecionada then escolha.raceId = filtradas[1] and filtradas[1].id end
		if construirFormulario then construirFormulario() end
	end
	local function consultarRacas()
		if not contaRemote or consultaContaPendente then return end
		sequenciaConsultaConta += 1
		local requestId = string.format("criacao-racas-%d-%s", sequenciaConsultaConta, HttpService:GenerateGUID(false))
		consultaContaPendente = requestId
		contaRemote:FireServer({ acao = "consultar", requestId = requestId })
		task.delay(15, function()
			if consultaContaPendente ~= requestId then return end
			consultaContaPendente = nil
			statusResultado.Text = "N\u{00E3}o foi poss\u{00ED}vel consultar as ra\u{00E7}as da conta. Apenas ra\u{00E7}as comuns e incomuns est\u{00E3}o dispon\u{00ED}veis."
			aplicarRacasLiberadas(nil)
		end)
	end
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild("ContaJogo", 15)
		if not remote or not remote:IsA("RemoteEvent") then
			if tela.Parent then statusResultado.Text = "Conta indispon\u{00ED}vel; apenas ra\u{00E7}as comuns e incomuns est\u{00E3}o dispon\u{00ED}veis." end
			return
		end
		contaRemote = remote
		remote.OnClientEvent:Connect(function(resposta)
			if type(resposta) ~= "table" or type(resposta.requestId) ~= "string"
				or string.sub(resposta.requestId, 1, 14) ~= "criacao-racas-" or resposta.requestId ~= consultaContaPendente then return end
			consultaContaPendente = nil
			if resposta.ok == true and RunConta.valida(resposta.conta) then
				cosmeticos = resposta.conta.cosmeticos or {}
				if aparenciaEstado then aparenciaEstado.possuidos = cosmeticos end
				aplicarRacasLiberadas(resposta.conta)
			else
				aplicarRacasLiberadas(nil)
				statusResultado.Text = resposta.mensagem or "N\u{00E3}o foi poss\u{00ED}vel consultar as ra\u{00E7}as da conta. Apenas ra\u{00E7}as comuns e incomuns est\u{00E3}o dispon\u{00ED}veis."
			end
		end)
		if tela.Enabled then consultarRacas() end
	end)
	local porNomePericia = {}
	for _, pericia in especies.pericias do porNomePericia[pericia.data.name] = pericia end
	-- P2: o ponto de partida é o preset recomendado (sempre válido); o jogador só ajusta a partir dele.
	do
		local sorteio = Random.new()
		local racaInicial = especies.racas[1] and especies.racas[1].id
		local arvoreInicial = especies.arvores[1] and especies.arvores[1].id
		escolha = Preset.criar(catalogo, racaInicial, arvoreInicial)
			or { raceId = racaInicial, backgroundId = "background/plebeu", startingTreeId = arvoreInicial,
				attributeBase = { forca = 1, agilidade = 0, vigor = 1, intelecto = 0, espirito = 0 },
				raceAttributeChoices = {}, freeSkillChoiceIds = {}, treeSkillChoiceIds = {} }
		escolha.nome = Preset.sugerirNome(function(lo, hi) return sorteio:NextInteger(lo, hi) end)
	end
	aparenciaEstado = AparenciaEstado.novo(escolha.raceId, nil, cosmeticos)
	statusResultado = criar("TextLabel", conteudo, {
		Name = "Resultado", AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1,
		Text = "Nenhuma ficha pessoal carregada.", TextColor3 = T.cores.secundario,
		FontFace = T.fontes.rotulo, TextSize = 13, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	})
	statusResultado.LayoutOrder = 10000
	local controles = {}
	local perfilDisponivel, pessoalSelecionado = false, false
	local perfilAtual = nil
	local armaPendente = false
	local operacaoArma = 0
	local TEMPO_LIMITE_ARMA = 8
	local recargaDisponivel, recargaPendente = false, false
	local ERRO_CARGA_RECUPERAVEL = "Não foi possível carregar sua ficha agora. Tente novamente."
	local modalAberto: Frame? = nil
	local function abrirOpcoes(rotulo: string, opcoes, aoEscolher)
		if modalAberto then modalAberto:Destroy() end
		local modal = criar("Frame", painel, {
			Name = "Opcoes", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.88, 0, 0.78, 0), BackgroundColor3 = T.cores.painel, ZIndex = 10,
		})
		modalAberto = modal
		local bordaModal = Instance.new("UIStroke", modal)
		bordaModal.Color, bordaModal.Thickness = T.cores.borda, T.espessuras.borda
		Instance.new("UICorner", modal).CornerRadius = UDim.new(0, T.raios.painel)
		local cabecalho = criar("TextLabel", modal, {
			Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -64, 0, 36),
			BackgroundTransparency = 1, Text = rotulo, TextColor3 = T.cores.texto,
			FontFace = T.fontes.titulo, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11,
		})
		local sair = criar("TextButton", modal, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = T.cores.painel, BorderSizePixel = 0, Text = "×", TextColor3 = T.cores.texto, TextSize = 26, ZIndex = 11,
		})
		sair.Activated:Connect(function() modal:Destroy(); modalAberto = nil end)
		local lista = criar("ScrollingFrame", modal, {
			Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 1, -58),
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true, ZIndex = 11,
		})
		Extra.rolagem(lista)
		local listaLayout = Instance.new("UIListLayout")
		listaLayout.Padding, listaLayout.SortOrder, listaLayout.Parent = UDim.new(0, 5), Enum.SortOrder.LayoutOrder, lista
		for indice, opcao in opcoes do
			local texto = if type(opcao) == "string" then opcao else nome(opcao)
			local b
			if type(opcao) == "table" and (opcao.kind == "race" or opcao.kind == "background") then
				b = Extra.cartao(lista, opcao, indice)
				for _, child in b:GetDescendants() do if child:IsA("GuiObject") then child.ZIndex += 10 end end
				b.ZIndex = 15
			else
				b = criar("TextButton", lista, {LayoutOrder=indice, Size=UDim2.new(1,0,0,48), BackgroundColor3=T.cores.painel, BorderSizePixel=0,
					Text=texto, TextColor3=T.cores.texto, FontFace=T.fontes.rotulo, TextSize=T.tamanhos.corpo, TextWrapped=true, ZIndex=15})
			end
			b.Activated:Connect(function()
				modal:Destroy(); modalAberto = nil; aoEscolher(opcao)
			end)
		end
	end
	local function listarOpcoes(lista, somente)
		local saida = {}
		for _, entrada in lista do
			if not somente or somente(entrada) then table.insert(saida, entrada) end
		end
		return saida
	end
	local function skillId(nomeSkill)
		local pericia = porNomePericia[nomeSkill]
		return pericia and pericia.id
	end
	local function prepararSlots(atual, quantidade, opcoes, transformar)
		local resultado, usados = {}, {}
		for i = 1, quantidade do
			local candidato = atual[i]
			local valido = false
			for _, opcao in opcoes do
				if transformar(opcao) == candidato then valido = true; break end
			end
			if candidato ~= nil and usados[candidato] then valido = false end
			if not valido then
				candidato = nil
				-- Primeira opção ainda não usada (antes repetia a opção i e duplicava perícias como Arcanismo).
				for _, opcao in opcoes do
					local valor = transformar(opcao)
					if not usados[valor] then candidato = valor; break end
				end
			end
			if candidato then table.insert(resultado, candidato); usados[candidato] = true end
		end
		return resultado
	end
	local function pontosDeCriacao()
		local gastos, menosUm, menosDois = 0, 0, 0
		for _, atributo in ATRIBUTOS do
			local valor = escolha.attributeBase[atributo.id]
			gastos += math.max(0, valor)
			if valor == -1 then menosUm += 1 elseif valor == -2 then menosDois += 1 end
		end
		return gastos, 2 + (menosUm > 0 and 1 or 0) + (menosDois > 0 and 2 or 0), menosUm, menosDois
	end
	-- Com uma run ativa a árvore inicial é a da run (o servidor também confere em PersonagemSessao).
	local arvoreDaRun
	local semArvoreForcado, semArvoreRun = false, false -- P2: a ficha nasce sem árvore; o mestre da vila ensina a primeira
	task.spawn(function()
		local remoteRun = ReplicatedStorage:WaitForChild("RunJogo", 10)
		if not remoteRun then return end
		remoteRun.OnClientEvent:Connect(function(tipo, dado)
			if tipo ~= "run" or type(dado) ~= "table" then return end
			local plano = dado.plano
			local nova = if plano and not dado.fim then (plano.escolhida or (plano.modo == "pronto" and plano.arvore or nil)) else nil
			local semArvoreNova = plano ~= nil and not dado.fim and plano.modo == "semArvore" and plano.escolhida == nil
			if nova ~= arvoreDaRun or semArvoreNova ~= semArvoreRun then
				arvoreDaRun, semArvoreRun = nova, semArvoreNova
				if tela.Enabled and construirFormulario then construirFormulario() end
			end
		end)
	end)
	function construirFormulario()
		aparenciaEstado = AparenciaEstado.reajustar(aparenciaEstado, escolha.raceId)
		local semArvore = (semArvoreForcado or semArvoreRun) and not arvoreDaRun
		if semArvore then
			escolha.startingTreeId, escolha.treeSkillChoiceIds = nil, {}
		elseif arvoreDaRun and catalogo.POR_ID["tree/" .. arvoreDaRun] then
			if escolha.startingTreeId ~= "tree/" .. arvoreDaRun then escolha.treeSkillChoiceIds = {} end
			escolha.startingTreeId = "tree/" .. arvoreDaRun
		end
		controles.usar = nil
		table.clear(controles)
		for _, child in conteudo:GetChildren() do if child:IsA("GuiObject") and child ~= layout and child ~= statusResultado and child ~= aviso then child:Destroy() end end
		ordemFormulario = 0
		local raca = catalogo.POR_ID[escolha.raceId]
		local antecedente = catalogo.POR_ID[escolha.backgroundId]
		local arvore = catalogo.POR_ID[escolha.startingTreeId]
		label("NOME DO PERSONAGEM")
		controles.nome = criar("TextBox", conteudo, {
			Name = "NomePersonagem", Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = T.cores.painel, TextColor3 = T.cores.texto,
			PlaceholderText = "Nome da personagem", PlaceholderColor3 = T.cores.secundario,
			Text = escolha.nome, ClearTextOnFocus = false, MultiLine = false,
			FontFace = T.fontes.rotulo, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
		})
		Instance.new("UICorner", controles.nome).CornerRadius = UDim.new(0, T.raios.botao)
		controles.nome:GetPropertyChangedSignal("Text"):Connect(function()
			local texto = controles.nome.Text
			local ok, limite = pcall(utf8.offset, texto, 33)
			if ok and limite then
				texto = string.sub(texto, 1, limite - 1)
				controles.nome.Text = texto
			end
			escolha.nome = texto
		end)
		label("1 · Raça")
		ordemFormulario += 1
		controles.raca = Extra.cartao(conteudo, raca, ordemFormulario)
		label("2 · Antecedente")
		ordemFormulario += 1
		controles.antecedente = Extra.cartao(conteudo, antecedente, ordemFormulario)
		local custosPorTier = { comum = 1, incomum = 1, rara = 2, lendaria = 3, mitica = 3 }
		local custoRaca = raca and custosPorTier[raca.data.tier]
		label(if custoRaca then string.format("PA iniciais: 3 · escolha desta raça: %d PA · restantes: %d", custoRaca, 3 - custoRaca)
			else "PA iniciais: 3 · tier da raça sem custo configurado")
		controles.raca.Activated:Connect(function()
			abrirOpcoes("Escolha uma raça", especies.racas, function(item)
				escolha.raceId = item.id
				escolha.raceAttributeChoices = prepararSlots(escolha.raceAttributeChoices, item.data.attributeChoices or 0, ATRIBUTOS, function(a) return a.id end)
				escolha.freeSkillChoiceIds = prepararSlots(escolha.freeSkillChoiceIds, (item.data.bonusSkillChoices or 0) + (catalogo.POR_ID[escolha.backgroundId].data.bonusSkillChoices or 0), especies.pericias, function(e) return e.id end)
				construirFormulario()
			end)
		end)
		controles.antecedente.Activated:Connect(function()
			abrirOpcoes("Escolha um antecedente", especies.antecedentes, function(item)
				escolha.backgroundId = item.id
				escolha.freeSkillChoiceIds = prepararSlots(escolha.freeSkillChoiceIds, (catalogo.POR_ID[escolha.raceId].data.bonusSkillChoices or 0) + (item.data.bonusSkillChoices or 0), especies.pericias, function(e) return e.id end)
				construirFormulario()
			end)
		end)
		local requires = antecedente and antecedente.data.requiresSubtable
		if requires then
			local sub = catalogo.POR_ID[escolha.subtableEntryId]
			if not sub or sub.data.subtableId ~= requires then
				local choices = listarOpcoes(catalogo.POR_ESPECIE["subtable-entry"] or {}, function(e) return e.data.subtableId == requires end)
				escolha.subtableEntryId = choices[1] and choices[1].id
				sub = catalogo.POR_ID[escolha.subtableEntryId]
			end
			controles.subtabela = botao("Opção do antecedente: " .. nome(sub))
			controles.subtabela.Activated:Connect(function()
				local choices = listarOpcoes(catalogo.POR_ESPECIE["subtable-entry"] or {}, function(e) return e.data.subtableId == requires end)
				abrirOpcoes("Escolha uma opção", choices, function(item) escolha.subtableEntryId = item.id; construirFormulario() end)
			end)
		else
			escolha.subtableEntryId = nil
		end

		label("3 · Atributos")
		local gastos, orcamento, menosUm, menosDois = pontosDeCriacao()
		label(string.format("Pontos usados: %d / %d   ·   defeitos −1: %d/1   ·   −2: %d/1", gastos, orcamento, menosUm, menosDois))
		for _, atributo in ATRIBUTOS do
			local linha = criar("Frame", conteudo, { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 })
			local atual = label(atributo.nome .. ": " .. escolha.attributeBase[atributo.id], linha)
			atual.Position, atual.Size = UDim2.fromOffset(6, 0), UDim2.new(1, -104, 1, 0)
			local menos = criar("TextButton", linha, { Position = UDim2.new(1, -100, 0, 0), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = T.cores.painel, BorderSizePixel = 0, Text = "−", TextColor3 = T.cores.texto, TextSize = 22 })
			local mais = criar("TextButton", linha, { Position = UDim2.new(1, -48, 0, 0), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = T.cores.painel, BorderSizePixel = 0, Text = "+", TextColor3 = T.cores.texto, TextSize = 20 })
			Instance.new("UICorner", menos).CornerRadius = UDim.new(0, T.raios.botao); Instance.new("UICorner", mais).CornerRadius = UDim.new(0, T.raios.botao)
			local function ajustar(delta)
				local valor = escolha.attributeBase[atributo.id] + delta
				local _, limite, n1, n2 = pontosDeCriacao()
				local novos = if valor == -1 then n1 + (if delta > 0 then -1 else 1) elseif valor == -2 then n2 + (if delta > 0 then -1 else 1) else nil
				if valor < -2 or valor > 4 then return end
				if valor == -1 and n1 == 1 and escolha.attributeBase[atributo.id] ~= -1 then return end
				if valor == -2 and n2 == 1 and escolha.attributeBase[atributo.id] ~= -2 then return end
				escolha.attributeBase[atributo.id] = valor
				construirFormulario()
			end
			menos.Activated:Connect(function() ajustar(-1) end)
			mais.Activated:Connect(function() ajustar(1) end)
		end

		label("4 · Perícias e bônus da raça")
		local escolhasAtributo = raca and (raca.data.attributeChoices or 0) or 0
		escolha.raceAttributeChoices = prepararSlots(escolha.raceAttributeChoices, escolhasAtributo, ATRIBUTOS, function(a) return a.id end)
		for i = 1, escolhasAtributo do
			local indice = i
			local nomeAtual = "escolher"
			for _, atributo in ATRIBUTOS do
				if atributo.id == escolha.raceAttributeChoices[indice] then nomeAtual = atributo.nome; break end
			end
			local b = botao("Bônus racial " .. indice .. ": " .. nomeAtual)
			b.Activated:Connect(function() abrirOpcoes("Atributo do bônus racial", ATRIBUTOS, function(item) escolha.raceAttributeChoices[indice] = item.id; construirFormulario() end) end)
		end
		local periciasConcedidas = PericiasDeCriacao.idsJaConcedidos(
			catalogo, escolha.raceId, escolha.backgroundId, escolha.startingTreeId, escolha.treeSkillChoiceIds
		)
		local opcoesLivres = listarOpcoes(especies.pericias, function(e)
			return not periciasConcedidas[e.id]
		end)
		local quantidadeLivres = (raca and raca.data.bonusSkillChoices or 0) + (antecedente and antecedente.data.bonusSkillChoices or 0)
		escolha.freeSkillChoiceIds = prepararSlots(escolha.freeSkillChoiceIds, quantidadeLivres, opcoesLivres, function(e) return e.id end)
		for i = 1, quantidadeLivres do
			local indice = i
			local pericia = catalogo.POR_ID[escolha.freeSkillChoiceIds[indice]]
			local b = botao("Perícia livre " .. indice .. ": " .. nome(pericia))
			b.Activated:Connect(function()
				local disponiveis = listarOpcoes(opcoesLivres, function(e)
					for j, id in escolha.freeSkillChoiceIds do if j ~= indice and id == e.id then return false end end
					return true
				end)
				abrirOpcoes("Escolha uma perícia", disponiveis, function(item) escolha.freeSkillChoiceIds[indice] = item.id; construirFormulario() end)
			end)
		end

		label("5 · Árvore inicial")
		controles.arvore = botao("Árvore inicial: " .. nome(arvore))
		local arvoreBloqueada = perfilAtual ~= nil and #(perfilAtual.habilidadesCompradas or {}) > 0
		if semArvore then
			controles.arvore.Text = "Árvore inicial: um mestre da vila ensina"
			controles.arvore.Active, controles.arvore.AutoButtonColor = false, false
			label("Nesta expedição você aprende seu primeiro caminho passando pela prova de um mestre; a ficha começa sem árvore.")
		elseif arvoreDaRun then
			controles.arvore.Text = "Árvore inicial (definida pela sua run): " .. nome(arvore)
			controles.arvore.Active, controles.arvore.AutoButtonColor = false, false
			label("Sua run deu esta árvore; ela não pode ser trocada durante a expedição.")
		elseif arvoreBloqueada then
			controles.arvore.Text = "Árvore inicial (fixa após a primeira compra): " .. nome(arvore)
			controles.arvore.Active, controles.arvore.AutoButtonColor = false, false
			label("Para preservar as habilidades aprendidas, a árvore inicial não pode ser trocada.")
		end
		controles.arvore.Activated:Connect(function()
			abrirOpcoes("Escolha a árvore inicial", especies.arvores, function(item)
				escolha.startingTreeId = item.id
				escolha.treeSkillChoiceIds = {}
				construirFormulario()
			end)
		end)
		local escolhaArvore = arvore and arvore.data.grantedSkills and arvore.data.grantedSkills.choose
		local nomesPermitidos = escolhaArvore and escolhaArvore.from or {}
		local opcoesArvore = {}
		for _, nomeSkill in nomesPermitidos do
			local id = skillId(nomeSkill)
			if id then table.insert(opcoesArvore, catalogo.POR_ID[id]) end
		end
		escolha.treeSkillChoiceIds = prepararSlots(escolha.treeSkillChoiceIds, escolhaArvore and escolhaArvore.count or 0, opcoesArvore, function(e) return e.id end)
		for i = 1, #escolha.treeSkillChoiceIds do
			local indice = i
			local pericia = catalogo.POR_ID[escolha.treeSkillChoiceIds[indice]]
			local b = botao("Perícia da árvore " .. indice .. ": " .. nome(pericia))
			b.Activated:Connect(function()
				local disponiveis = listarOpcoes(opcoesArvore, function(e)
					for j, id in escolha.treeSkillChoiceIds do if j ~= indice and id == e.id then return false end end
					return true
				end)
				abrirOpcoes("Perícia permitida pela árvore", disponiveis, function(item) escolha.treeSkillChoiceIds[indice] = item.id; construirFormulario() end)
			end)
		end
		label("6 · Aparência")
		ordemFormulario += 1
		local editarAparencia = Componentes.botao({parent=conteudo, texto="APARÊNCIA · personalizar avatar", tamanho=UDim2.new(1,0,0,48), ordem=ordemFormulario,
			aoClicar=function()
				aparenciaFluxo.editar(escolha.raceId, aparenciaEstado.aparencia, cosmeticos, function(a, fecharEditor)
					aparenciaEstado = AparenciaEstado.novo(escolha.raceId, a, cosmeticos)
					fecharEditor()
				end)
			end})
		editarAparencia.Name = "PassoAparencia"
		label("7 · Confirmar")
		controles.enviar = botao("VALIDAR E CRIAR", nil, 46)
		controles.enviar.BackgroundColor3 = T.cores.ouro
		controles.enviar.TextColor3 = T.cores.textoEscuro
		controles.enviar.Activated:Connect(function()
			controles.enviar.Text, controles.enviar.Active = "Aguardando validação do servidor…", false
			if recargaDisponivel then
				recargaDisponivel, recargaPendente = false, true
				statusResultado.Text = "Tentando carregar sua ficha…"
				state.send("personagemPessoalConsultar", {})
				return
			end
			local payload = {
				requestId = HttpService:GenerateGUID(false),
				nome = escolha.nome,
				raceId = escolha.raceId, backgroundId = escolha.backgroundId,
				subtableEntryId = escolha.subtableEntryId, attributeBase = table.clone(escolha.attributeBase),
				raceAttributeChoices = table.clone(escolha.raceAttributeChoices),
				freeSkillChoiceIds = table.clone(escolha.freeSkillChoiceIds), startingTreeId = escolha.startingTreeId,
				treeSkillChoiceIds = table.clone(escolha.treeSkillChoiceIds),
			}
			aparenciaPendente = {raceId=escolha.raceId, aparencia=AparenciaEstado.clone(aparenciaEstado.aparencia)}
			state.send("personagemPessoalCriar", payload)
		end)
		if perfilAtual then
			label("ARMA DO KIT INICIAL")
			local armasDoKit = {}
			for _, item in perfilAtual.inventarioInicial or {} do
				if item.type == "arma" and type(item.sourceLocalId) == "string" then
					table.insert(armasDoKit, item)
				end
			end
			if #armasDoKit == 0 then
				label("Este kit não tem uma arma selecionável; o combate mantém a referência atual.")
			else
				label("Escolha uma arma que já está no kit. Armas corpo a corpo equipam para Ataque; armas de distância ficam priorizadas em Disparo.")
				for _, item in armasDoKit do
					local arma = item
					local selecionada = perfilAtual.armaInicialSourceLocalId == arma.sourceLocalId
					local textoDado = if type(arma.baseDie) == "string" then " · " .. arma.baseDie else ""
					local botaoArma = botao(
						(if selecionada then "ESCOLHIDA: " else "USAR: ") .. tostring(arma.name or "Arma") .. textoDado,
						nil, 40
					)
					botaoArma.Name = "ArmaInicial_" .. arma.sourceLocalId
					if selecionada or armaPendente then
						botaoArma.Active, botaoArma.AutoButtonColor = false, false
						if armaPendente and not selecionada then botaoArma.Text = "Salvando escolha da arma…" end
					end
					botaoArma.Activated:Connect(function()
						if armaPendente or selecionada then return end
						armaPendente = true
						operacaoArma += 1
						local operacaoAtual = operacaoArma
						botaoArma.Text, botaoArma.Active = "Salvando escolha da arma…", false
						state.send("personagemPessoalEquiparArma", {
							sourceLocalId = arma.sourceLocalId,
							requestId = HttpService:GenerateGUID(false),
						})
						task.delay(TEMPO_LIMITE_ARMA, function()
							if not armaPendente or operacaoArma ~= operacaoAtual then return end
							armaPendente = false
							statusResultado.Text = "Sem confirmação da arma. Confira a ficha e tente escolher novamente."
							construirFormulario()
						end)
					end)
				end
			end
			label("PROGRESSÃO DO RANK ABERTO · PA infinito provisório até Intermediário")
			local construcaoProgresso = table.clone(perfilAtual.construcao or {})
			construcaoProgresso.unlockedRankIds = table.clone(construcaoProgresso.unlockedRankIds or {})
			construcaoProgresso.purchasedIds = table.clone(perfilAtual.habilidadesCompradas or {})
			local disponiveis = {}
			for _, entrada in catalogo.POR_ESPECIE.ability or {} do
				if entrada.data.treeId == construcaoProgresso.startingTreeId
					and entrada.data.rank == "Principiante"
					and Progressao.podeComprar(construcaoProgresso, catalogo, entrada.id)
				then table.insert(disponiveis, entrada) end
			end
			if #disponiveis > 0 then
				local aprender = botao("APRENDER HABILIDADE", nil, 42)
				aprender.Activated:Connect(function()
					abrirOpcoes("Habilidades disponíveis no rank aberto", disponiveis, function(entrada)
						state.send("personagemPessoalAprender", {
							habilidadeId = entrada.id, requestId = HttpService:GenerateGUID(false),
						})
					end)
				end)
			else
				label("Nenhuma habilidade comprável no rank Principiante aberto.")
			end
			local nomesAprendidas = {}
			for _, id in perfilAtual.habilidadesCompradas or {} do
				local entrada = catalogo.POR_ID[id]
				if entrada then table.insert(nomesAprendidas, nome(entrada)) end
			end
			label(if #nomesAprendidas > 0 then "Aprendidas: " .. table.concat(nomesAprendidas, ", ") else "Ainda não aprendeu habilidades.")
		end
		if perfilDisponivel then
			controles.usar = botao(if pessoalSelecionado then "FICHA PRÓPRIA SELECIONADA" else "USAR PERSONAGEM", nil, 46)
			controles.usar.Activated:Connect(function()
				state.send("escolherPersonagem", { id = "personagem-pessoal" })
			end)
		end
	end

	construirFormulario()
	aplicarRacasLiberadas(nil)
	state.onPersonagemPessoal(function(perfil)
		recargaDisponivel, recargaPendente = false, false
		armaPendente = false
		operacaoArma += 1
		perfilAtual = perfil
		perfilDisponivel = perfil ~= nil and perfil.kitInicial ~= nil
		if perfil then
			local construcao = perfil.construcao or {}
			local proposta = aparenciaPendente
			aparenciaPendente = nil
			if proposta and proposta.raceId == construcao.raceId then
				aparenciaFluxo.salvar(proposta.aparencia, function(ok)
					if not ok then statusResultado.Text = "Ficha criada; aparência não confirmada. Use o espelho da vila." end
				end)
			elseif perfil.aparencia then
				aparenciaEstado = AparenciaEstado.novo(construcao.raceId, perfil.aparencia, cosmeticos)
			end
			-- A resposta do servidor é a fonte da última ficha aceita. Reabrir a
			-- tela ou recalcular não deve substituir escolhas confirmadas por defaults.
			escolha.nome = perfil.nome or escolha.nome
			local racaSalva = construcao.raceId
			escolha.raceId = if racaSalva and racasPermitidas[racaSalva] then racaSalva else escolha.raceId
			escolha.backgroundId = construcao.backgroundId or escolha.backgroundId
			escolha.subtableEntryId = construcao.subtableEntryId
			escolha.attributeBase = table.clone(construcao.attributeBase or escolha.attributeBase)
			escolha.raceAttributeChoices = table.clone(construcao.raceAttributeChoices or {})
			escolha.freeSkillChoiceIds = table.clone(construcao.skillIds or {})
			escolha.startingTreeId = construcao.startingTreeId or escolha.startingTreeId
			escolha.treeSkillChoiceIds = table.clone(construcao.treeSkillChoiceIds or {})
			construirFormulario()
			local stats = perfil.estatisticas or {}
			local maxima = stats.maxima or {}
			local atributos = perfil.atributos or {}
			local iniciativa = stats.initiative or {}
			local pa = perfil.pontosAprimoramento or {}
			local kit = perfil.kitInicial
			local nomesKit = {}
			for _, item in kit and kit.itens or {} do table.insert(nomesKit, item.name) end
			local linhaKit = if kit then string.format("Kit %s: %s", kit.subgrupo, table.concat(nomesKit, ", "))
				else "Kit inicial sem dados catalogados para esta árvore."
			local armaSelecionada
			for _, item in perfil.inventarioInicial or {} do
				if item.sourceLocalId == perfil.armaInicialSourceLocalId then armaSelecionada = item; break end
			end
			local linhaArma = if armaSelecionada then "Arma escolhida: " .. tostring(armaSelecionada.name)
				else "Arma não selecionada: permanece a referência atual do combate."
			local vantagem = if iniciativa.advantage then " (vantagem)" else ""
			statusResultado.Text = string.format(
				"Ficha validada · sessão atual · %s\nPA restantes %s (escolha de raça: %s)\n%s\n%s\nPV %s · PM %s · PT %s · PP %s\nCA %s · Deslocamento %sm · Iniciativa +%s%s\nFOR %s · AGI %s · VIG %s · INT %s · ESP %s",
				tostring(perfil.nome or "Nome filtrado indisponível"),
				tostring(pa.restantes or "—"), tostring(pa.custoEscolhaRaca or "—"), linhaKit, linhaArma,
				tostring(maxima.pv or "—"), tostring(maxima.pm or "—"), tostring(maxima.pt or "—"), tostring(maxima.pp or "—"),
				tostring(stats.armorClass or "—"), tostring(stats.movementMeters or "—"), tostring(iniciativa.bonus or "—"), vantagem, tostring(atributos.forca or "—"),
				tostring(atributos.agilidade or "—"), tostring(atributos.vigor or "—"), tostring(atributos.intelecto or "—"), tostring(atributos.espirito or "—")
			)
			statusResultado.Size = UDim2.new(1, 0, 0, 40)
					if controles.enviar then controles.enviar.Text, controles.enviar.Active = "ATUALIZAR FICHA PESSOAL", true end
		else
			perfilAtual = nil
			construirFormulario()
			statusResultado.Text, statusResultado.Size = "Nenhuma ficha pessoal carregada.", UDim2.new(1, 0, 0, 40)
			if controles.enviar then controles.enviar.Text, controles.enviar.Active = "VALIDAR E CRIAR", true end
		end
	end)
	state.onSnapshot(function(snapshot)
		pessoalSelecionado = snapshot.you and snapshot.you.personagem == "personagem-pessoal"
		if controles.usar then controles.usar.Text = if pessoalSelecionado then "FICHA PRÓPRIA SELECIONADA" else "USAR PERSONAGEM" end
	end)
	state.onLog(function(evento)
		if evento.tone == "erro" then
			aparenciaPendente = nil
			local texto = evento.text or "O servidor recusou a construção."
			statusResultado.Text = texto
			if armaPendente then
				armaPendente = false
				operacaoArma += 1
				construirFormulario()
			end
			if recargaPendente or texto == ERRO_CARGA_RECUPERAVEL then
				recargaPendente, recargaDisponivel = false, true
				if controles.enviar then controles.enviar.Text, controles.enviar.Active = "TENTAR CARREGAR FICHA", true end
			elseif controles.enviar then
				controles.enviar.Text, controles.enviar.Active = "TENTAR NOVAMENTE", true
			end
		end
	end)
	return {
		definirSemArvore = function(valor)
			semArvoreForcado = valor == true
			if construirFormulario then construirFormulario() end
		end,
		abrir = function(callback)
			aoFechar = callback
			tela.Enabled = true
			statusResultado.Text = "Consultando sua ficha pessoal…"
			state.send("personagemPessoalConsultar", {})
			aplicarRacasLiberadas(nil)
			consultarRacas()
		end,
		fechar = fecharTela,
	}
end

return CriacaoView
