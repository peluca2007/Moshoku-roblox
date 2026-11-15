-- Interface da expedição (cidade -> porta -> área em passos). O que mostrar vem de Regras/ExpedicaoTela
-- (pura, com spec); aqui só montamos Instances e enviamos intenções pelo RemoteEvent "RunJogo":
-- { acao = "votar", opcao }, { acao = "descansar" }, { acao = "consultar" }. O servidor decide tudo.
-- Instances (para playtest): ScreenGui "ExpedicaoJogo" > Faixa | PainelExpedicao | Viajando.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Tela = require(ReplicatedStorage.Shared.Regras.ExpedicaoTela)
local C = require(script.Parent.UI.Componentes)
local T = require(script.Parent.UI.Tema)

local DURACAO_VIAGEM = 1.2

local View = {}

local function nomeDe(userId)
	local jogador = Players:GetPlayerByUserId(userId)
	return if jogador then jogador.DisplayName else "Jogador"
end

function View.start()
	local remoto = ReplicatedStorage:WaitForChild("RunJogo")
	local jogador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ExpedicaoJogo", false, 3
	gui.IgnoreGuiInset, gui.ZIndexBehavior = true, Enum.ZIndexBehavior.Sibling
	gui.Parent = jogador:WaitForChild("PlayerGui")

	-- Faixa do topo: dia/prazo e, dentro da área, o contador de salas.
	local faixa = C.painel({ parent = gui, nome = "Faixa", tamanho = UDim2.fromOffset(340, 0), ancora = Vector2.new(0.5, 0),
		posicao = UDim2.new(0.5, 0, 0, 12 + GuiService:GetGuiInset().Y), padding = 8, ordem = 1 })
	faixa.AutomaticSize = Enum.AutomaticSize.Y
	faixa.Visible = false
	faixa.Conteudo.Size, faixa.Conteudo.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	Instance.new("UIListLayout", faixa.Conteudo).SortOrder = Enum.SortOrder.LayoutOrder
	local textoDia = C.texto({ parent = faixa.Conteudo, nome = "Dia", ordem = 1, subtitulo = true })
	local textoSala = C.texto({ parent = faixa.Conteudo, nome = "Sala", ordem = 2, secundario = true })
	for _, t in { textoDia, textoSala } do t.TextXAlignment = Enum.TextXAlignment.Center end

	local palco = Instance.new("Frame")
	palco.Name, palco.BackgroundTransparency, palco.Size = "Palco", 1, UDim2.fromScale(1, 1)
	palco.Parent = gui

	-- Tela "Viajando…" (cobre tudo por um instante).
	local cobertura = Instance.new("Frame")
	cobertura.Name, cobertura.Size, cobertura.BackgroundColor3 = "Viajando", UDim2.fromScale(1, 1), T.cores.fundoTela
	cobertura.BorderSizePixel, cobertura.Active, cobertura.Visible, cobertura.ZIndex = 0, true, false, 50
	cobertura.Parent = gui
	local rotuloViagem = C.texto({ parent = cobertura, texto = "Viajando…", tamanho = UDim2.fromScale(1, 1) })
	rotuloViagem.TextXAlignment, rotuloViagem.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
	rotuloViagem.TextColor3, rotuloViagem.FontFace, rotuloViagem.TextSize = T.sobreEscuro.texto, T.fontes.italico, T.tamanhos.titulo
	rotuloViagem.ZIndex = 51

	local visao
	local estado = { portaAberta = false, levantadoEm = nil, emCombate = jogador:GetAttribute("InterfaceCombate") == true }
	local memoria
	local viagemAtual = 0

	local redesenhar
	local function votar(id) remoto:FireServer({ acao = "votar", opcao = id }) end

	local function montarPainel(decisao)
		local raiz = C.painel({ parent = palco, nome = "PainelExpedicao", tamanho = UDim2.fromOffset(500, 0), ancora = Vector2.new(0.5, 0.5),
			posicao = UDim2.fromScale(0.5, 0.5), padding = 16 })
		raiz.AutomaticSize = Enum.AutomaticSize.Y
		local c = raiz.Conteudo
		c.Size, c.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		local layout = Instance.new("UIListLayout")
		layout.SortOrder, layout.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, T.espacamentos.pequeno)
		layout.Parent = c
		local ordem = 0
		local function proxima() ordem += 1; return ordem end
		local function titulo(texto) return C.titulo({ parent = c, texto = texto, ordem = proxima() }) end
		local function texto(valor, secundario)
			return C.texto({ parent = c, texto = valor, ordem = proxima(), secundario = secundario })
		end
		local function botao(nome, rotulo, variante, desabilitado, aoClicar)
			return C.botao({ parent = c, nome = nome, texto = rotulo, variante = variante, desabilitado = desabilitado,
				aoClicar = aoClicar, tamanho = UDim2.new(1, 0, 0, if variante == "principal" then 52 else 48), ordem = proxima() })
		end
		local function cartoes()
			for _, cart in decisao.cartoes or {} do
				local caixa = C.cartao({ parent = c, nome = "Cartao_" .. cart.id, tamanho = UDim2.new(1, 0, 0, 0), padding = 10, ordem = proxima() })
				caixa.AutomaticSize = Enum.AutomaticSize.Y
				local cc = caixa.Conteudo
				cc.Size, cc.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
				local lista = Instance.new("UIListLayout")
				lista.SortOrder, lista.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 4)
				lista.Parent = cc
				C.texto({ parent = cc, texto = (if cart.votada then "✔ " else "") .. cart.titulo, subtitulo = true, ordem = 1 })
				if cart.dica then C.texto({ parent = cc, texto = cart.dica, italico = true, secundario = true, ordem = 2 }) end
				local linhas = {}
				if cart.custo then table.insert(linhas, "Custo: " .. cart.custo) end
				if cart.votos then table.insert(linhas, cart.votos .. " voto(s)") end
				if not cart.liberada and cart.motivo then table.insert(linhas, tostring(cart.motivo)) end
				if #linhas > 0 then C.texto({ parent = cc, texto = table.concat(linhas, " · "), secundario = true, ordem = 3 }) end
				C.botao({ parent = cc, nome = "Escolher_" .. cart.id, texto = "Escolher", variante = "principal", desabilitado = not cart.liberada,
					tamanho = UDim2.new(1, 0, 0, 48), ordem = 4, aoClicar = function() votar(cart.id) end })
			end
		end
		local function rodape()
			if decisao.votacao then texto(decisao.votacao, true) end
			if decisao.voltar then
				botao("VoltarCidade", decisao.voltar.texto, "perigo", not decisao.voltar.liberada, function() votar(decisao.voltar.id) end)
			end
		end

		if decisao.tela == "porta" then
			titulo("A porta do esgoto")
			texto("Para onde o grupo vai?", true)
			cartoes()
			if decisao.votacao then texto(decisao.votacao, true) end
			botao("Cancelar", "Cancelar", "secundario", false, function() estado.portaAberta = false; redesenhar() end)
		elseif decisao.tela == "acampamento" then
			titulo("Acampamento")
			if #decisao.grupo > 0 then texto("Grupo: " .. table.concat(decisao.grupo, ", "), true) end
			if decisao.descansar then
				botao("Descansar", decisao.descansar.texto, "secundario", decisao.descansar.desabilitado, function() remoto:FireServer({ acao = "descansar" }) end)
			end
			botao("LevantarAcampamento", "Levantar acampamento", "principal", false, function()
				estado.levantadoEm = visao and visao.galho; redesenhar()
			end)
			rodape()
		elseif decisao.tela == "escolhas" then
			titulo(visao and visao.titulo or "Para onde?")
			cartoes()
			rodape()
		end
		return raiz
	end

	redesenhar = function()
		local decisao = Tela.decidir(visao, estado, nomeDe)
		local f = decisao.faixa
		faixa.Visible = f ~= nil
		if f then
			textoDia.Text = f.dia
			textoSala.Text = f.contador or ""
			textoSala.Visible = f.contador ~= nil
		end
		local velho = palco:FindFirstChild("PainelExpedicao")
		if velho then velho:Destroy() end
		if decisao.tela ~= "nenhuma" and decisao.tela ~= "luta" then montarPainel(decisao) end
	end

	local function viajar()
		viagemAtual += 1
		local meu = viagemAtual
		cobertura.Visible = true
		task.delay(DURACAO_VIAGEM, function() if viagemAtual == meu then cobertura.Visible = false end end)
	end

	remoto.OnClientEvent:Connect(function(tipo, dado)
		if tipo == "porta" then
			estado.portaAberta = true
			remoto:FireServer({ acao = "consultar" })
			redesenhar()
		elseif tipo == "expedicaoConcluida" then
			estado.portaAberta = false
			local a = Tela.avisoConcluida(dado)
			C.aviso({ parent = gui, tipo = "sucesso", titulo = a.titulo, detalhe = a.detalhe, duracao = 4 })
		elseif tipo == "run" and type(dado) == "table" then
			if dado.erro then
				C.aviso({ parent = gui, tipo = "perigo", titulo = "Não foi possível", detalhe = tostring(dado.erro), duracao = 3 })
				return
			end
			local anterior = memoria
			local viaja
			viaja, memoria = Tela.viajar(memoria, dado)
			if anterior and memoria and anterior.galho ~= memoria.galho then estado.portaAberta = false; estado.levantadoEm = nil end
			visao = if dado.semRun then nil else dado
			if dado.semRun then memoria = nil; estado.portaAberta = false; estado.levantadoEm = nil end
			if viaja then viajar() end
			redesenhar()
		end
	end)
	jogador:GetAttributeChangedSignal("InterfaceCombate"):Connect(function()
		estado.emCombate = jogador:GetAttribute("InterfaceCombate") == true
		redesenhar()
	end)
	remoto:FireServer({ acao = "consultar" })
	return gui
end

return View
