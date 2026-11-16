-- Menu de comandos da luta (HUD2): losango no canto inferior direito, um comando em cada vértice
-- (Habilidades no topo, Atacar à esquerda, Andar à direita, Encerrar na base) com a tecla visível.
-- Atacar e Habilidades abrem uma lista vertical à esquerda do losango (nome grande, custo em Ações/PM à
-- direita, uma linha de efeito; a habilidade em foco fica destacada; "?" abre o DetalheAcao). Comandos
-- extras (Confirmar, Cancelar mira, Levantar, Apagar o fogo, Pacto) empilham acima do losango.
-- Teclas: R Habilidades, F Atacar, G Andar, V Encerrar turno (Q/E giram a câmera, WASD movem, M alterna
-- a mesa); com a lista aberta, seta para cima/baixo move o foco e Enter usa.
-- Só intenção: escolher a habilidade liga a MIRA (MesaState); o clique no tabuleiro manda o pedido;
-- o servidor valida e resolve. Geometria em shared/Regras/LayoutLuta (pura, com spec).
-- Instances: AcoesDoTurno > Menu (Atacar, Habilidades, Andar, EncerrarTurno, ConfirmarAcao, CancelarMira,
-- Levantar, ApagarFogo, EscolherPacto) | Lista > Grupos | Cartas > Carta_<id> | Dica | TooltipAcao | DetalheAcao.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Estilo = require(Shared:WaitForChild("Estilo"))
local Catalogo = require(Shared:WaitForChild("Livro"):WaitForChild("Catalogo"))
local Execucao = require(Shared:WaitForChild("Regras"):WaitForChild("Execucao"))
local Layout = require(Shared.Regras.LayoutLuta)
local Apresentacao = require(Shared.ApresentacaoAcoes)
local Descricao = require(Shared.DescricaoHabilidade)
local ResumoCarta = require(script.Parent.UI.ResumoCarta)
local Previa = require(script.Parent.PreviaFurtiva)
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local P = require(script.Parent.UI.PecasLuta)
local Arte = require(Shared:WaitForChild("UIArteLuta"))

local AcoesDoTurno = {}
local new = P.novo

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

-- Custo de recursos sob o losango das Ações: "3 PM", "2 PM · 1 PT" ou vazio.
local function custoPm(mec, indisponivel): string
	if indisponivel then return "Consulta" end
	local partes = {}
	if (mec.pm or 0) > 0 then table.insert(partes, mec.pm .. " PM") end
	if (mec.pt or 0) > 0 then table.insert(partes, mec.pt .. " PT") end
	return if #partes == 0 then (if (mec.acoes or 0) == 0 then "Livre" else "") else table.concat(partes, "·")
end

local TECLAS = { habilidades = Enum.KeyCode.R, atacar = Enum.KeyCode.F, andar = Enum.KeyCode.G, encerrar = Enum.KeyCode.V }
local EXTRAS_MAX = 5

function AcoesDoTurno.start(state)
	local player = Players.LocalPlayer
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "AcoesDoTurno",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- coordenadas de tela valem direto
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local detalhe = require(script.Parent.DetalheAcao).start(gui)
	local tooltip = require(script.Parent.TooltipAcao).start(gui, function() Previa.set(nil) end)

	local function texto(parent, props)
		local label = new("TextLabel", nil, {
			BackgroundTransparency = 1, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, FontFace = T.fontes.rotulo,
			TextColor3 = P.cor.texto, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
		})
		for key, value in props do
			label[key] = value
		end
		label.Parent = parent
		return label
	end

	-- Posição absoluta dos blocos (a partir do canto, com âncora: o UIScale encolhe em direção ao canto).
	local function geometria()
		local vp = workspace.CurrentCamera.ViewportSize
		local lo = Layout.losango(vp.X, vp.Y)
		local extras = Layout.extras(vp.X, vp.Y, EXTRAS_MAX)
		local topo = extras[EXTRAS_MAX]
		return vp, lo, extras, { x = lo.x, y = topo.y, w = lo.w, h = lo.y + lo.h - topo.y }
	end
	local _, _, _, menuRect0 = geometria()

	-- Menu: contém o losango e a pilha de extras; some fora da vez deste jogador.
	local menu = new("Frame", gui, {
		Name = "Menu", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(menuRect0.w, menuRect0.h),
		BackgroundTransparency = 1, Visible = false,
	})
	-- Enfeite: losango fino no centro do losango de comandos.
	local centro = new("Frame", menu, {
		Name = "Centro", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(34, 34), Rotation = 45,
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	new("UIStroke", centro, { Color = P.cor.ouro, Thickness = 1, Transparency = 0.45 })
	new("Frame", centro, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = P.cor.ouro, BorderSizePixel = 0 })

	-- Lista de habilidades (à esquerda do losango): abas Golpes-Apoio-Tudo (só em Habilidades) e as linhas.
	local lista = new("Frame", gui, { Name = "Lista", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(Layout.LISTA_LARGURA, Layout.LISTA_LINHA), BackgroundTransparency = 1, Visible = false })
	local escalaLista = new("UIScale", lista, { Name = "Entrada", Scale = 1 })
	new("UIListLayout", lista, { Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder })
	local cartasFrame = new("ScrollingFrame", lista, {
		Name = "Cartas", Size = UDim2.new(1, 0, 0, Layout.LISTA_LINHA), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = P.cor.ouro,
		BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 2,
	})
	new("UIListLayout", cartasFrame, { Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder })
	local dica = texto(gui, {
		Name = "Dica", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(340, 28), TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false, TextStrokeColor3 = P.cor.trilho, TextStrokeTransparency = 0.1, ZIndex = 6,
		FontFace = T.fontes.titulo, TextSize = 19, TextColor3 = P.cor.ouroVivo,
	})

	local cliques: { [any]: () -> () } = {} -- ação de cada botão, para as teclas

	-- Botão de comando: placa escura com fio dourado fino, escala e brilho no hover.
	-- rotulo/Marca/Tecla são filhos; atributos Bloqueada/Desabilitado apagam o botão.
	local function botao(parent, nome: string, rotulo: string, tamanho: UDim2, opcoes, aoClicar: () -> ())
		local o = opcoes or {}
		-- Fundo pintado (ARTE2): o botão em si é transparente; "Arte" troca entre normal, foco e bloqueado.
		local b = new("TextButton", parent, { Name = nome, Size = tamanho, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
		local normal = if o.principal then "botao_principal" else "botao_normal"
		local arte = P.arte(b, normal)
		if o.perigo then arte.ImageColor3 = Color3.fromRGB(255, 150, 140) end
		local rot = texto(b, {
			Name = "Rotulo", Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true, TextTruncate = Enum.TextTruncate.None, FontFace = T.fontes.titulo, TextSize = o.tamanhoTexto or 16,
			TextColor3 = if o.principal then P.cor.ouroVivo elseif o.perigo then P.cor.inimigo else P.cor.texto, Text = rotulo, ZIndex = 5,
		})
		new("Frame", b, {
			Name = "Marca", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -30, 0, 2),
			BackgroundColor3 = P.cor.ouroVivo, BorderSizePixel = 0, ZIndex = 6, Visible = false,
		})
		if o.tecla then
			local selo = P.tecla(b, o.tecla, 26)
			selo.AnchorPoint, selo.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(6, 6)
		end
		if o.icone then
			local ic = P.icone(b, o.icone, P.cor.ouro, 20)
			ic.AnchorPoint, ic.Position, ic.ZIndex = Vector2.new(1, 0), UDim2.new(1, -9, 0, 5), 6
		end
		P.foco(b, nil, 1.05, { img = arte, normal = normal, foco = "botao_foco" })
		b:GetAttributeChangedSignal("Desabilitado"):Connect(function()
			local off = b:GetAttribute("Desabilitado") == true
			P.trocarArte(arte, if off then "botao_bloqueado" else normal)
			rot.TextTransparency = if off then 0.5 else 0
		end)
		b.Activated:Connect(aoClicar)
		cliques[b] = aoClicar
		return b
	end

	-- Estado da lista: nil, "atacar" ou "habilidades"; grupo vale só em "habilidades".
	local modoLista: string? = nil
	local grupo, atualizar = "Golpes", nil
	local cartas: { [string]: any } = {}
	local atual = { tokenId = nil :: string?, ficha = nil :: any, assinatura = "", pacto = 1 }
	local focoRegistro: any = nil

	local abas = new("Frame", lista, { Name = "Grupos", Size = UDim2.new(1, 0, 0, Layout.LINHA), BackgroundTransparency = 1, LayoutOrder = 1 })
	new("UIListLayout", abas, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder })
	local botoesGrupo = {}
	for i, nome in { "Golpes", "Apoio", "Tudo" } do
		local b = botao(abas, nome, nome, UDim2.new(1 / 3, -3, 1, 0), { tamanhoTexto = 15 }, function()
			grupo = nome
			detalhe.fechar()
			tooltip.fechar()
			cartasFrame.CanvasPosition = Vector2.zero
			state.setMira(nil)
			if atualizar then atualizar() end
		end)
		b.LayoutOrder = i
		botoesGrupo[nome] = b
	end

	local function alternarLista(modo: string)
		detalhe.fechar(); tooltip.fechar()
		modoLista = if modoLista == modo then nil else modo
		focoRegistro = nil
		state.setMira(nil)
		cartasFrame.CanvasPosition = Vector2.zero
		if atualizar then atualizar() end
	end
	local function tamanhoVertice() return UDim2.fromOffset(Layout.VERTICE_W, Layout.VERTICE_H) end
	local atacar = botao(menu, "Atacar", "Atacar", tamanhoVertice(), { tecla = "F", icone = "atacar" }, function() alternarLista("atacar") end)
	local habilidades = botao(menu, "Habilidades", "Habilidades", tamanhoVertice(), { tecla = "R", icone = "habilidades" }, function() alternarLista("habilidades") end)
	-- Andar (Cap. 4: 1 Ação, até o Deslocamento): acende as casas e um clique move.
	local andar = botao(menu, "Andar", "Andar (1 Ação)", tamanhoVertice(), { tecla = "G", tamanhoTexto = 15, icone = "andar" }, function()
		if not atual.tokenId or (atual.restantes or 0) < 1 and (atual.passosLivres or 0) < 1 then
			return
		end
		local mira = state.mira()
		if mira and mira.habilidadeId == "mesa/andar" then
			state.setMira(nil)
			return
		end
		modoLista = nil
		state.setMira({
			tokenId = atual.tokenId, habilidadeId = "mesa/andar", tipo = "mover", modo = "casa",
			alcanceCasas = if (atual.passosLivres or 0) > 0 then atual.passosLivres else atual.deslocamentoCasas or 6, cor = Estilo.CAPITULOS[3],
		})
	end)
	local encerrar = botao(menu, "EncerrarTurno", "Encerrar turno", tamanhoVertice(), { tecla = "V", principal = true, tamanhoTexto = 15, icone = "encerrar" }, function()
		local snapshot = state.snapshot()
		if snapshot and atual.tokenId then
			modoLista = nil
			state.setMira(nil)
			state.send("nextTurn", { expectedId = atual.tokenId, expectedTurn = snapshot.combat.turn })
		end
	end)
	local vertices = { habilidades = habilidades, atacar = atacar, andar = andar, encerrar = encerrar }
	-- Comandos extras: empilham acima do losango, na ordem abaixo, só os visíveis.
	local tamanhoExtra = UDim2.fromOffset(Layout.EXTRA_W, Layout.EXTRA_H)
	local confirmar = botao(menu, "ConfirmarAcao", "Confirmar ação", tamanhoExtra, { principal = true }, function()
		local mira = state.mira()
		local registro = mira and cartas[mira.habilidadeId]
		if registro and not registro.carta:GetAttribute("Bloqueada") and mira.tokenId == atual.tokenId and (mira.modo == "confirmar" or mira.ponto ~= nil or (mira.modo == "lista" and #(mira.alvoIds or {}) > 0)) then
			state.dispararMira()
		end
	end)
	local cancelar = botao(menu, "CancelarMira", "Cancelar mira", tamanhoExtra, nil, function()
		state.setMira(nil)
	end)
	local levantar = botao(menu, "Levantar", "Levantar (1 Ação)", tamanhoExtra, { tamanhoTexto = 15 }, function()
		tooltip.fechar()
		if atual.tokenId then state.setMira(nil); state.send("usarHabilidade", {tokenId = atual.tokenId, habilidadeId = "mesa/levantar"}) end
	end)
	local apagar = botao(menu, "ApagarFogo", "Apagar o fogo (1 Ação)", tamanhoExtra, { perigo = true, tamanhoTexto = 15 }, function()
		if atual.tokenId then
			state.send("apagarFogo", { tokenId = atual.tokenId })
		end
	end)
	local pacto = botao(menu, "EscolherPacto", "Escolher Pacto", tamanhoExtra, nil, function()
		atual.pacto += 1
		state.setMira(nil)
	end)
	local extras = { confirmar, cancelar, levantar, apagar, pacto }
	for _, b in extras do b.Visible = false end
	C.aplicarEscala(menu)
	C.aplicarEscala(lista)
	C.aplicarEscala(dica)

	local function rotuloDe(b, t: string)
		b.Rotulo.Text = t
	end

	local ultimoTurno = nil
	local linhasLista, comAbasLista = 1, false

	-- Posição dos blocos (só muda com a tela ou com o conteúdo, não por quadro).
	local function posicionar()
		local vp, lo, rectsExtras, mr = geometria()
		menu.Position, menu.Size = UDim2.fromOffset(vp.X - Layout.MARGEM, vp.Y - Layout.MARGEM), UDim2.fromOffset(mr.w, mr.h)
		for nome, b in vertices do
			local v = lo.vertices[nome]
			b.Position, b.Size = UDim2.fromOffset(lo.x - mr.x + v.x, lo.y - mr.y + v.y), UDim2.fromOffset(v.w, v.h)
		end
		centro.Position = UDim2.fromOffset(lo.x - mr.x + lo.w / 2, lo.y - mr.y + lo.h / 2)
		-- extras visíveis, do mais perto do losango para cima
		local k = 0
		for _, b in extras do
			if b.Visible then
				k += 1
				local r = rectsExtras[k]
				b.Position, b.Size = UDim2.fromOffset(r.x - mr.x, r.y - mr.y), UDim2.fromOffset(r.w, r.h)
			end
		end
		local topoPilha = if k > 0 then rectsExtras[k].y else lo.y
		dica.Position = UDim2.fromOffset(vp.X - Layout.MARGEM, topoPilha - 4)
		if lista.Visible then
			local l = Layout.lista(vp.X, vp.Y, linhasLista, comAbasLista)
			lista.Position, lista.Size = UDim2.fromOffset(l.x + l.w, l.y + l.h), UDim2.fromOffset(l.w, l.h)
		end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionar)

	local function criarCarta(habilidadeId: string, ordem: number)
		local indisponivel = Execucao.INDISPONIVEIS[habilidadeId]
		local mec = Execucao.MECANICAS[habilidadeId] or { acoes = 0, pm = 0, pt = 0, tipo = "manual" }
		local entrada = Catalogo.POR_ID[habilidadeId]
		local dados = entrada and entrada.data or {}
		local cor = Estilo.arvore(mec.arvore or arvoreDe(habilidadeId)).cor
		-- Carta pintada (ARTE2): faixa de tinta (normal/foco/bloqueada), ícone da habilidade tingido pela
		-- árvore, nome grande em fonte de título, custo em Ações num losango e PM/PT logo abaixo.
		local carta = new("TextButton", cartasFrame, {
			Name = "Carta_" .. (dados.id or habilidadeId), Size = UDim2.new(1, -4, 0, Layout.LISTA_LINHA), BackgroundTransparency = 1,
			BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = ordem, ZIndex = 3,
		})
		local arte = P.arte(carta, "faixa_normal")
		local escala = new("UIScale", carta, { Name = "Foco", Scale = 1 })
		new("Frame", carta, { Name = "Selo", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 3, 1, -22), Position = UDim2.new(0, 11, 0.5, 0), BackgroundColor3 = cor, BorderSizePixel = 0, ZIndex = 4 })
		local icone = P.icone(carta, Arte.iconeDe(habilidadeId, mec.arvore), cor:Lerp(Color3.new(1, 1, 1), 0.3), 32)
		icone.AnchorPoint, icone.Position = Vector2.new(0, 0.5), UDim2.new(0, 20, 0.5, 0)
		local nome = texto(carta, {
			Name = "Nome", Position = UDim2.fromOffset(58, 2), Size = UDim2.new(1, -58 - 100, 0, 28),
			FontFace = T.fontes.titulo, TextSize = 21, Text = dados.name or mec.nome or habilidadeId, ZIndex = 5,
		})
		local losango = P.losango(carta, if indisponivel then "·" else tostring(mec.acoes or 0), 30)
		losango.AnchorPoint, losango.Position = Vector2.new(0.5, 0), UDim2.new(1, -66, 0, 5)
		local custoLabel = texto(carta, {
			Name = "Custo", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -66, 0, 36), Size = UDim2.fromOffset(62, 14),
			FontFace = T.fontes.numero, TextSize = 12, TextColor3 = P.cor.ouro, TextXAlignment = Enum.TextXAlignment.Center,
			Text = custoPm(mec, indisponivel), ZIndex = 5,
		})
		local efeito = texto(carta, {
			Name = "Efeito", Position = UDim2.fromOffset(58, 30), Size = UDim2.new(1, -58 - 100, 0, 18),
			FontFace = T.fontes.rotulo, TextSize = 13, TextColor3 = P.cor.secundario, ZIndex = 5,
		})
		local resumo = if dados.damage and dados.damage.normal then dados.damage.normal else (dados.effect or "")
		if indisponivel then resumo = indisponivel elseif mec.aviso then resumo = mec.aviso .. " " .. resumo end
		if mec.descricao and not indisponivel then resumo = mec.descricao end
		local custo = if indisponivel then "CONSULTA • VEJA OS DETALHES" else linhaDeCusto(mec)
		local registro = { carta = carta, mec = mec, cor = cor, indisponivel = indisponivel, efeito = efeito, nome = nome, custoLabel = custoLabel,
			custo = custo, resumo = resumo, linhaResumo = ResumoCarta.curto(mec, dados, indisponivel, habilidadeId), grupo = Apresentacao.grupo(mec, indisponivel),
			armada = false, hover = false, foco = false, escala = escala, estado = "",
			ataque = string.sub(habilidadeId, 1, 5) == "mesa/" and Apresentacao.grupo(mec, indisponivel) == "Golpes" }
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
				custo = custo,
				texto = if completo ~= "" then completo else "Consulte os detalhes desta habilidade na ficha.",
				motivo = carta:GetAttribute("Motivo"),
			}
		end
		registro.dadosDetalhe = dadosDetalhe
		-- Linha normal ou acesa (cursor, foco do teclado, mira armada, canção ativa).
		function registro.pintar()
			local acesa = registro.hover or registro.armada or registro.foco
			local bloqueada = carta:GetAttribute("Bloqueada") == true
			local chave = (if acesa then "1" else "0") .. (if registro.armada then "1" else "0") .. (if bloqueada then "1" else "0")
			if registro.estado == chave then return end
			registro.estado = chave
			P.trocarArte(arte, if registro.armada or (acesa and not bloqueada) then "faixa_foco" elseif bloqueada then "faixa_bloqueada" else "faixa_normal")
			icone.ImageTransparency = if bloqueada then 0.55 else 0
			losango.ImageTransparency = if bloqueada then 0.4 else 0
			P.animar(escala, { Scale = if acesa then 1.03 else 1 }, P.SUAVE, "foco")
			P.animar(carta.Selo, { Size = UDim2.new(0, if registro.armada then 6 else 3, 1, -22) }, P.SUAVE, "selo")
		end
		local function consultar()
			tooltip.fechar()
			state.setMira(nil)
			detalhe.abrir(habilidadeId, dadosDetalhe())
		end
		-- "?" no canto direito: não cobre o nome nem o custo (deixam 46 px livres).
		local info = new("TextButton", carta, {
			Name = "Detalhes", Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), ZIndex = 6,
		})
		new("ImageLabel", info, { Name = "Disco", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Arte.PECAS.tecla_disco.imagem, ZIndex = 5 })
		texto(info, { Name = "Interrogacao", Size = UDim2.fromScale(1, 1), Text = "?", TextXAlignment = Enum.TextXAlignment.Center, FontFace = T.fontes.titulo, TextSize = 18, TextColor3 = P.cor.ouroVivo, ZIndex = 7 })
		info.Activated:Connect(consultar)
		carta:SetAttribute("Grupo", registro.grupo)
		function registro.acionar()
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
			modoLista = nil -- a lista fecha; Confirmar/Cancelar aparecem no menu
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
		end
		carta.Activated:Connect(registro.acionar)
		carta.MouseEnter:Connect(function()
			if carta.Visible and menu.Visible then
				tooltip.abrir(habilidadeId, dadosDetalhe(), carta)
				Previa.set(if habilidadeId == "mesa/esconder" then atual.tokenId else nil)
			end
			focoRegistro = registro
			registro.hover = true
			registro.pintar()
		end)
		carta.MouseLeave:Connect(function()
			tooltip.sair()
			registro.hover = false
			registro.pintar()
		end)
		return registro
	end

	-- Foco do teclado na lista: seta para cima/baixo e Enter.
	local function linhasVisiveis()
		local v = {}
		for _, r in cartas do
			if r.carta.Visible then table.insert(v, r) end
		end
		table.sort(v, function(a, b) return a.carta.LayoutOrder < b.carta.LayoutOrder end)
		return v
	end
	local function moverFoco(passo: number)
		local v = linhasVisiveis()
		if #v == 0 then return end
		local i = table.find(v, focoRegistro) or (if passo > 0 then 0 else #v + 1)
		local novo = v[math.clamp(i + passo, 1, #v)]
		if focoRegistro and focoRegistro ~= novo then focoRegistro.foco = false; focoRegistro.pintar() end
		focoRegistro = novo
		novo.foco = true
		novo.pintar()
		-- mantém a linha à vista
		local topo, base = novo.carta.AbsolutePosition.Y, novo.carta.AbsolutePosition.Y + novo.carta.AbsoluteSize.Y
		local area = cartasFrame.AbsolutePosition.Y
		if topo < area then
			cartasFrame.CanvasPosition -= Vector2.new(0, area - topo)
		elseif base > area + cartasFrame.AbsoluteSize.Y then
			cartasFrame.CanvasPosition += Vector2.new(0, base - area - cartasFrame.AbsoluteSize.Y)
		end
	end

	atualizar = function()
		local snapshot = state.snapshot()
		local vez = snapshot and snapshot.combat.active and snapshot.combat.turnId
		local token = if vez then state.findToken(vez) else nil
		local mostrar = token ~= nil and token.habilidades ~= nil and state.canControl(token)
		if mostrar and not menu.Visible then
			-- entrada: os quatro vértices crescem em sequência (Back)
			local i = 0
			for _, b in vertices do
				i += 1
				local foco = b:FindFirstChild("Foco")
				if foco then
					foco.Scale = 0.7
					task.delay((i - 1) * 0.04, function()
						if b.Parent then P.animar(foco, { Scale = 1 }, P.ENTRADA, "foco") end
					end)
				end
			end
		end
		menu.Visible = mostrar
		if not mostrar then
			lista.Visible, dica.Visible = false, false
			modoLista = nil
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
			focoRegistro = nil
			-- Os golpes de todo mundo (ataque básico, disparo, Lâmina de Gelo) vêm primeiro.
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
		local jogo = snapshot.jogo and snapshot.jogo.acoes
		atual.deslocamentoCasas = jogo and jogo.deslocamentoCasas or 6
		atual.passosLivres = jogo and jogo.passosLivres or 0
		local usadas = if jogo and jogo.tokenId == token.id then jogo.usadas else 0
		local total = if jogo then jogo.total else 3
		local restantes = math.max(0, total - usadas)
		atual.restantes = restantes
		local chaveTurno = token.id .. ":" .. tostring(snapshot.combat.turn)
		if ultimoTurno ~= chaveTurno then
			detalhe.fechar()
			tooltip.fechar()
			ultimoTurno = chaveTurno
			modoLista = nil
			if state.mira() then state.setMira(nil) end
			cartasFrame.CanvasPosition = Vector2.zero
		end
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
			rotuloDe(pacto, entradaPacto and entradaPacto.data.name or "Pacto")
		end
		local mira = state.mira()
		cancelar.Visible = mira ~= nil
		rotuloDe(andar, if atual.passosLivres > 0 then "Andar · " .. atual.passosLivres .. " casas" else "Andar (1 Ação)")
		andar:SetAttribute("Bloqueada", restantes < 1 and atual.passosLivres < 1)
		andar:SetAttribute("Desabilitado", restantes < 1 and atual.passosLivres < 1)
		rotuloDe(encerrar, if restantes == 0 then "Pronto · Encerrar" else "Encerrar turno")
		local contagens = { Golpes = 0, Apoio = 0, Tudo = 0 }
		local temAtaque, temHabilidade, visiveis = false, false, 0
		for id, registro in cartas do
			local mec = registro.mec
			local motivo = Apresentacao.motivo(mec, registro.indisponivel, token, jogo, id)
			local apoio = token.apoio
			local ativa = apoio and mec.especial == "cancao" and apoio.cancao == mec.cancao
			if ativa then motivo = "ATIVA • manter não gasta Ação" end
			if apoio and mec.especial == "pararCancao" and not apoio.cancao then motivo = "Nenhuma canção ativa" end
			if apoio and mec.especial == "inspirar" and apoio.inspiracoesUsadas >= apoio.inspiracoesMax then motivo = "Sem usos de Inspiração neste descanso" end
			if registro.ataque then temAtaque = true else
				temHabilidade = true
				contagens.Tudo += 1
				if contagens[registro.grupo] then contagens[registro.grupo] += 1 end
			end
			local naLista = if modoLista == "atacar" then registro.ataque
				elseif modoLista == "habilidades" then not registro.ataque and (grupo == "Tudo" or grupo == registro.grupo) else false
			registro.carta.Visible = naLista
			if naLista then visiveis += 1 end
			registro.carta:SetAttribute("Bloqueada", motivo ~= nil)
			registro.carta:SetAttribute("Motivo", motivo)
			registro.carta:SetAttribute("Ativa", ativa == true)
			detalhe.atualizar(id, registro.dadosDetalhe())
			tooltip.atualizar(id, registro.dadosDetalhe())
			registro.efeito.Text = motivo or registro.linhaResumo
			registro.efeito.TextColor3 = if motivo then P.cor.inimigo else P.cor.secundario
			registro.nome.TextTransparency = if motivo then 0.45 else 0
			registro.custoLabel.TextTransparency = if motivo then 0.45 else 0
			registro.armada = (mira ~= nil and mira.habilidadeId == id) or ativa == true
			registro.foco = registro.foco and naLista
			registro.pintar()
		end
		atacar.Visible, habilidades.Visible = temAtaque, temHabilidade
		-- Aba vazia (ex.: só habilidades de Apoio e a aba é Golpes): passa à primeira aba com cartas em vez de
		-- fechar a lista, que antes sumia no clique em Habilidades sem mostrar nada.
		if modoLista == "habilidades" and visiveis == 0 and contagens.Tudo > 0 then
			grupo = if contagens.Golpes > 0 then "Golpes" elseif contagens.Apoio > 0 then "Apoio" else "Tudo"
			return atualizar()
		end
		atacar.Marca.Visible, habilidades.Marca.Visible = modoLista == "atacar", modoLista == "habilidades"
		local registroMira = mira and cartas[mira.habilidadeId]
		confirmar.Visible = registroMira ~= nil and (mira.modo == "confirmar" or mira.modo == "lista" or mira.ponto ~= nil)
		if confirmar.Visible then
			local quantidade = #(mira.alvoIds or {})
			local pronto = (mira.modo == "confirmar" or mira.ponto ~= nil or quantidade > 0) and not registroMira.carta:GetAttribute("Bloqueada")
			rotuloDe(confirmar, if mira.ponto then "Confirmar área" elseif mira.modo == "lista" then (if quantidade > 0 then "Confirmar "..quantidade..(if quantidade == 1 then " alvo" else " alvos") else "Escolha os alvos") else "Usar habilidade")
			confirmar:SetAttribute("Bloqueada", not pronto)
			confirmar:SetAttribute("Desabilitado", not pronto)
		end
		for nome, b in botoesGrupo do
			rotuloDe(b, nome .. " · " .. contagens[nome])
			b.Rotulo.TextColor3 = if grupo == nome then P.cor.ouroVivo else P.cor.texto
			b.Marca.Visible = grupo == nome
		end
		-- Alturas: a lista pelas cartas visíveis (abas só em Habilidades).
		local comAbas = modoLista == "habilidades"
		abas.Visible = comAbas
		local k = math.max(1, math.min(visiveis, Layout.LISTA_MAX_LINHAS))
		cartasFrame.Size = UDim2.new(1, 0, 0, Layout.alturaLista(k))
		linhasLista, comAbasLista = k, comAbas
		if modoLista ~= nil and visiveis == 0 then modoLista = nil end
		local abrir = modoLista ~= nil and visiveis > 0
		if abrir and not lista.Visible then
			escalaLista.Scale = 0.92
			P.animar(escalaLista, { Scale = 1 }, P.ENTRADA, "entrada")
		end
		lista.Visible = abrir
		dica.Visible = true
		if mira then
			local mec = Execucao.MECANICAS[mira.habilidadeId]
			dica.Text = if mira.modo == "lista" then string.format("%d/%d alvos · toque em Confirmar", #(mira.alvoIds or {}), mira.maxAlvos)
				elseif mira.modo == "ficha" then "Clique no alvo · Cancelar mira volta"
				elseif mira.modo == "confirmar" then "Toque em Usar habilidade"
				elseif mec and mec.moldavel then "Escolha início e fim · Confirmar área"
				elseif mec and (mec.tipo == "zona" or mec.alvo == "cone" or mec.alvo == "esferaNaCasa") then "Fixe a prévia · Confirmar área"
				else "Clique numa casa · Cancelar mira volta"
		else
			dica.Text = if token.estadosCombate and #token.estadosCombate > 0 then "Efeitos: " .. table.concat(token.estadosCombate, ", ") else string.format("Rodada %d · Vez de %s", (state.snapshot() and state.snapshot().combat.round) or 1, token.name)
		end
		posicionar()
	end

	cartasFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function() tooltip.fechar() end)
	-- Teclas dos vértices e foco da lista.
	local teclas = UserInputService.InputBegan:Connect(function(input, processado)
		if processado or not menu.Visible or UserInputService:GetFocusedTextBox() then return end
		local dialogo = gui:FindFirstChild("DetalheAcao")
		if dialogo and dialogo.Visible then return end
		for nome, tecla in TECLAS do
			if input.KeyCode == tecla then
				local b = vertices[nome]
				if b.Visible then cliques[b]() end
				return
			end
		end
		if not lista.Visible then return end
		if input.KeyCode == Enum.KeyCode.Down then
			moverFoco(1)
		elseif input.KeyCode == Enum.KeyCode.Up then
			moverFoco(-1)
		elseif input.KeyCode == Enum.KeyCode.Return and focoRegistro and focoRegistro.carta.Visible then
			focoRegistro.acionar()
		end
	end)
	gui.Destroying:Connect(function()
		teclas:Disconnect()
		tooltip.fechar()
	end)
	if state.onFichaDetalhe then state.onFichaDetalhe(function(id) if id == atual.tokenId then atualizar() end end) end
	state.onSnapshot(atualizar)
	state.onMira(atualizar)
	posicionar()
	atualizar()
	return gui
end

return AcoesDoTurno
