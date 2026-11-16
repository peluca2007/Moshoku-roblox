-- Menu de ação flutuante da luta (LUTA-B), tema Pergaminho (UI/Componentes). Aparece na vez de uma ficha
-- que este jogador controla: lista curta ao lado do personagem que age (reserva no canto inferior
-- esquerdo se ele sair da tela) com Atacar, Habilidades, Andar e Encerrar turno (e Confirmar/Cancelar
-- mira, Levantar, Apagar o fogo, Pacto quando valem). Atacar e Habilidades abrem uma segunda lista
-- (nome + custo); o detalhe completo fica no tooltip/DetalheAcao. Vida, PM e Ações: cartão do Hud.
-- Só intenção: escolher a habilidade liga a MIRA (MesaState); o clique no tabuleiro manda o pedido;
-- o servidor valida e resolve. Geometria em shared/Regras/LayoutLuta (pura, com spec).
-- Instances: AcoesDoTurno > Menu (Atacar, Habilidades, Andar, EncerrarTurno, ...) | Lista > Grupos | Cartas > Carta_<id> | Dica.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Estilo = require(Shared:WaitForChild("Estilo"))
local Catalogo = require(Shared:WaitForChild("Livro"):WaitForChild("Catalogo"))
local Execucao = require(Shared:WaitForChild("Regras"):WaitForChild("Execucao"))
local Layout = require(Shared.Regras.LayoutLuta)
local UIArte = require(Shared.UIArte)
local Protocol = require(Shared:WaitForChild("MesaProtocol"))
local RunService = game:GetService("RunService")
local Apresentacao = require(Shared.ApresentacaoAcoes)
local Descricao = require(Shared.DescricaoHabilidade)
local Previa = require(script.Parent.PreviaFurtiva)
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)

local AcoesDoTurno = {}

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- Texto do kit com tamanho/posição próprios (piso de 14 px garantido por aplicarEscala).
local function texto(parent, props)
	local label = C.texto({ parent = parent })
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextSize = 14
	label.TextTruncate = Enum.TextTruncate.AtEnd
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

function AcoesDoTurno.start(state)
	local player = Players.LocalPlayer
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "AcoesDoTurno",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- coordenadas de WorldToViewportPoint valem direto
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local detalhe = require(script.Parent.DetalheAcao).start(gui)
	local tooltip = require(script.Parent.TooltipAcao).start(gui, function() Previa.set(nil) end)

	-- Menu principal: lista vertical curta; some fora da vez deste jogador.
	local menu = new("Frame", gui, { Name = "Menu", Size = UDim2.fromOffset(Layout.MENU_LARGURA, Layout.alturaLista(4)), BackgroundTransparency = 1, Visible = false })
	new("UIListLayout", menu, { Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder })
	-- Segunda lista (Atacar / Habilidades): abas Golpes-Apoio-Tudo (só em Habilidades) e as cartas.
	local lista = new("Frame", gui, { Name = "Lista", Size = UDim2.fromOffset(Layout.LISTA_LARGURA, Layout.LINHA), BackgroundTransparency = 1, Visible = false })
	new("UIListLayout", lista, { Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder })
	local cartasFrame = new("ScrollingFrame", lista, {
		Name = "Cartas", Size = UDim2.new(1, 0, 0, Layout.LINHA), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 2,
	})
	new("UIListLayout", cartasFrame, { Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder })
	local dica = texto(gui, {
		Name = "Dica", Size = UDim2.fromOffset(Layout.LISTA_LARGURA, 20), TextColor3 = T.sobreEscuro.texto, Text = "", Visible = false,
		TextStrokeColor3 = T.cores.fundoTela, TextStrokeTransparency = 0.2, ZIndex = 6,
	})

	local function botao(parent, rotulo: string, variante: string, largura: number, aoClicar: () -> ())
		local b = C.botao({
			parent = parent, texto = rotulo, variante = variante, tamanho = UDim2.fromOffset(largura, Layout.LINHA), aoClicar = aoClicar,
		})
		b.Rotulo.TextSize = 16
		b.Rotulo.Position, b.Rotulo.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0)
		new("Frame", b, { Name = "Marca", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.new(1, -34, 0, 3),
			BackgroundColor3 = T.cores.titulo, BorderSizePixel = 0, ZIndex = 8, Visible = false })
		return b
	end
	local function rotuloDe(b, t: string)
		b.Rotulo.Text = t
	end

	-- Estado da segunda lista: nil, "atacar" ou "habilidades"; grupo vale só em "habilidades".
	local modoLista: string? = nil
	local grupo, atualizar = "Golpes", nil
	local cartas: { [string]: any } = {}
	local atual = { tokenId = nil :: string?, ficha = nil :: any, assinatura = "", pacto = 1 }

	local abas = new("Frame", lista, { Name = "Grupos", Size = UDim2.new(1, 0, 0, Layout.LINHA), BackgroundTransparency = 1, LayoutOrder = 1 })
	new("UIListLayout", abas, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Layout.ESPACO), SortOrder = Enum.SortOrder.LayoutOrder })
	local botoesGrupo = {}
	for i, nome in { "Golpes", "Apoio", "Tudo" } do
		local b = botao(abas, nome, "secundario", (Layout.LISTA_LARGURA - 2 * Layout.ESPACO) / 3, function()
			grupo = nome
			detalhe.fechar()
			tooltip.fechar()
			cartasFrame.CanvasPosition = Vector2.zero
			state.setMira(nil)
			if atualizar then atualizar() end
		end)
		b.Name, b.LayoutOrder = nome, i
		b.Rotulo.TextSize = 15
		botoesGrupo[nome] = b
	end

	local function alternarLista(modo: string)
		detalhe.fechar(); tooltip.fechar()
		modoLista = if modoLista == modo then nil else modo
		state.setMira(nil)
		cartasFrame.CanvasPosition = Vector2.zero
		if atualizar then atualizar() end
	end
	local atacar = botao(menu, "Atacar", "secundario", Layout.MENU_LARGURA, function() alternarLista("atacar") end)
	atacar.Name, atacar.LayoutOrder = "Atacar", 10
	local habilidades = botao(menu, "Habilidades", "secundario", Layout.MENU_LARGURA, function() alternarLista("habilidades") end)
	habilidades.Name, habilidades.LayoutOrder = "Habilidades", 11
	-- Andar (Cap. 4: 1 Ação, até o Deslocamento): acende as casas e um clique move.
	local andar = botao(menu, "Andar (1 Ação)", "secundario", Layout.MENU_LARGURA, function()
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
	andar.Name, andar.LayoutOrder = "Andar", 12
	local encerrar = botao(menu, "Encerrar turno", "principal", Layout.MENU_LARGURA, function()
		local snapshot = state.snapshot()
		if snapshot and atual.tokenId then
			modoLista = nil
			state.setMira(nil)
			state.send("nextTurn", { expectedId = atual.tokenId, expectedTurn = snapshot.combat.turn })
		end
	end)
	encerrar.Name, encerrar.LayoutOrder = "EncerrarTurno", 13
	local confirmar = botao(menu, "Confirmar ação", "principal", Layout.MENU_LARGURA, function()
		local mira = state.mira()
		local registro = mira and cartas[mira.habilidadeId]
		if registro and not registro.carta:GetAttribute("Bloqueada") and mira.tokenId == atual.tokenId and (mira.modo == "confirmar" or mira.ponto ~= nil or (mira.modo == "lista" and #(mira.alvoIds or {}) > 0)) then
			state.dispararMira()
		end
	end)
	confirmar.Name, confirmar.LayoutOrder, confirmar.Visible = "ConfirmarAcao", 1, false
	local cancelar = botao(menu, "Cancelar mira", "secundario", Layout.MENU_LARGURA, function()
		state.setMira(nil)
	end)
	cancelar.Name, cancelar.LayoutOrder, cancelar.Visible = "CancelarMira", 2, false
	local levantar = botao(menu, "Levantar (1 Ação)", "secundario", Layout.MENU_LARGURA, function()
		tooltip.fechar()
		if atual.tokenId then state.setMira(nil); state.send("usarHabilidade", {tokenId = atual.tokenId, habilidadeId = "mesa/levantar"}) end
	end)
	levantar.Name, levantar.LayoutOrder, levantar.Visible = "Levantar", 3, false
	local apagar = botao(menu, "Apagar o fogo (1 Ação)", "perigo", Layout.MENU_LARGURA, function()
		if atual.tokenId then
			state.send("apagarFogo", { tokenId = atual.tokenId })
		end
	end)
	apagar.Name, apagar.LayoutOrder, apagar.Visible = "ApagarFogo", 4, false
	local pacto = botao(menu, "Escolher Pacto", "secundario", Layout.MENU_LARGURA, function()
		atual.pacto += 1
		state.setMira(nil)
	end)
	pacto.Name, pacto.LayoutOrder, pacto.Visible = "EscolherPacto", 5, false
	C.aplicarEscala(menu)
	C.aplicarEscala(lista)

	local ultimoTurno = nil
	local linhasMenu, linhasLista = 4, 1

	-- Posição: ao lado do personagem que age; reserva no canto inferior esquerdo.
	local function posicionar()
		if not menu.Visible then return end
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		local ponto = nil
		local token = atual.tokenId and state.findToken(atual.tokenId)
		if token and token.x and token.z then
			local p, visivel = cam:WorldToViewportPoint(Protocol.cellCenter(token.x, token.z) + Vector3.new(0, 3, 0))
			if visivel then ponto = { x = p.X, y = p.Y } end
		end
		local m = Layout.menu(vp.X, vp.Y, ponto, linhasMenu)
		menu.Position, menu.Size = UDim2.fromOffset(m.x, m.y), UDim2.fromOffset(m.w, m.h)
		dica.Position = UDim2.fromOffset(m.x, m.y - 24)
		dica.TextXAlignment = Enum.TextXAlignment.Left
		if lista.Visible then
			local l = Layout.lista(vp.X, vp.Y, m, linhasLista)
			lista.Position, lista.Size = UDim2.fromOffset(l.x, l.y), UDim2.fromOffset(l.w, l.h)
		end
	end
	RunService.RenderStepped:Connect(posicionar)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionar)

	local function criarCarta(habilidadeId: string, ordem: number)
		local indisponivel = Execucao.INDISPONIVEIS[habilidadeId]
		local mec = Execucao.MECANICAS[habilidadeId] or { acoes = 0, pm = 0, pt = 0, tipo = "manual" }
		local entrada = Catalogo.POR_ID[habilidadeId]
		local dados = entrada and entrada.data or {}
		local cor = Estilo.arvore(mec.arvore or arvoreDe(habilidadeId)).cor
		local carta = new("TextButton", cartasFrame, {
			Name = "Carta_" .. (dados.id or habilidadeId), LayoutOrder = ordem, AutoButtonColor = false, Text = "",
			Size = UDim2.new(1, -4, 0, Layout.LINHA), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
		})
		local _, arte = C.arte({ parent = carta, nome = "Moldura", peca = "botao", tamanho = UDim2.fromScale(1, 1), zIndex = 3 })
		new("Frame", carta, { Name = "Selo", Size = UDim2.new(0, 4, 1, -16), Position = UDim2.fromOffset(12, 8), BackgroundColor3 = cor, BorderSizePixel = 0, ZIndex = 4 })
		texto(carta, {
			Name = "Nome", Position = UDim2.fromOffset(24, 3), Size = UDim2.new(1, -68, 0, 22),
			FontFace = T.fontes.titulo, TextSize = 16, TextColor3 = T.cores.texto, Text = dados.name or mec.nome or habilidadeId, ZIndex = 5,
		})
		local efeito = texto(carta, {
			Name = "Custo", Position = UDim2.fromOffset(24, 23), Size = UDim2.new(1, -68, 0, 18),
			FontFace = T.fontes.rotulo, TextSize = 14, TextColor3 = T.cores.secundario,
			Text = if indisponivel then "CONSULTA • VEJA OS DETALHES" else linhaDeCusto(mec), ZIndex = 5,
		})
		local resumo = if dados.damage and dados.damage.normal then dados.damage.normal else (dados.effect or "")
		if indisponivel then resumo = indisponivel elseif mec.aviso then resumo = mec.aviso .. " " .. resumo end
		if mec.descricao and not indisponivel then resumo = mec.descricao end
		local custo = if indisponivel then "CONSULTA • VEJA OS DETALHES" else linhaDeCusto(mec)
		local registro = { carta = carta, arte = arte, mec = mec, cor = cor, indisponivel = indisponivel, efeito = efeito,
			custo = custo, resumo = resumo, grupo = Apresentacao.grupo(mec, indisponivel), armada = false, hover = false,
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
		-- Moldura normal ou acesa (cursor, mira armada, canção ativa).
		function registro.pintar()
			local acesa = registro.hover or registro.armada
			arte.Image = UIArte.peca(if acesa then "botao_ativo" else "botao").imagem
			carta.Selo.Size = UDim2.new(0, if registro.armada then 7 else 4, 1, -16)
		end
		local function consultar()
			tooltip.fechar()
			state.setMira(nil)
			detalhe.abrir(habilidadeId, dadosDetalhe())
		end
		-- "?" pequeno no canto direito: não cobre o texto (nome e custo deixam 44 px livres).
		local info = new("TextButton", carta, {
			Name = "Detalhes", Text = "?", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(32, 32), BackgroundColor3 = T.cores.cabecalho, TextColor3 = T.cores.titulo,
			FontFace = T.fontes.titulo, TextSize = 18, ZIndex = 6,
		})
		new("UICorner", info, { CornerRadius = UDim.new(1, 0) })
		new("UIStroke", info, { Color = T.cores.borda, Thickness = 1.5 })
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
		end)
		carta.MouseEnter:Connect(function()
			if carta.Visible and menu.Visible then
				tooltip.abrir(habilidadeId, dadosDetalhe(), carta)
				Previa.set(if habilidadeId == "mesa/esconder" then atual.tokenId else nil)
			end
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

	atualizar = function()
		local snapshot = state.snapshot()
		local vez = snapshot and snapshot.combat.active and snapshot.combat.turnId
		local token = if vez then state.findToken(vez) else nil
		local mostrar = token ~= nil and token.habilidades ~= nil and state.canControl(token)
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
			registro.efeito.Text = motivo or registro.custo
			registro.efeito.TextColor3 = if motivo then T.cores.alerta else T.cores.secundario
			registro.arte.ImageTransparency = if motivo then 0.45 else 0
			registro.armada = (mira ~= nil and mira.habilidadeId == id) or ativa == true
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
			b.Rotulo.TextColor3 = if grupo == nome then T.cores.titulo else T.cores.texto
			b.Marca.Visible = grupo == nome
		end
		-- Alturas: menu pelas entradas visíveis; lista pelas cartas (abas só em Habilidades).
		linhasMenu = 0
		for _, filho in menu:GetChildren() do
			if filho:IsA("TextButton") and filho.Visible then linhasMenu += 1 end
		end
		local comAbas = modoLista == "habilidades"
		abas.Visible = comAbas
		local maxCartas = Layout.LISTA_MAX_LINHAS - (if comAbas then 1 else 0)
		local k = math.max(1, math.min(visiveis, maxCartas))
		cartasFrame.Size = UDim2.new(1, 0, 0, Layout.alturaLista(k))
		linhasLista = k + (if comAbas then 1 else 0)
		lista.Visible = modoLista ~= nil and visiveis > 0
		if modoLista ~= nil and visiveis == 0 then modoLista = nil end
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
			dica.Text = if token.estadosCombate and #token.estadosCombate > 0 then "Efeitos: " .. table.concat(token.estadosCombate, ", ") else "Vez de " .. token.name
		end
		posicionar()
	end

	cartasFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function() tooltip.fechar() end)
	gui.Destroying:Connect(function() tooltip.fechar() end)
	if state.onFichaDetalhe then state.onFichaDetalhe(function(id) if id == atual.tokenId then atualizar() end end) end
	state.onSnapshot(atualizar)
	state.onMira(atualizar)
	atualizar()
	return gui
end

return AcoesDoTurno
