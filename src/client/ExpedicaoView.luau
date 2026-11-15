-- Interface da expedição (cidade -> porta -> área em passos). O que mostrar vem de Regras/ExpedicaoTela
-- (pura, com spec); aqui só montamos Instances e enviamos intenções pelo RemoteEvent "RunJogo":
-- { acao = "votar", opcao }, { acao = "retirarVoto" }, { acao = "descansar" }, { acao = "lutar" },
-- { acao = "abandonar" }, { acao = "consultar" }. O servidor decide tudo.
-- Instances (para playtest): ScreenGui "ExpedicaoJogo" > Faixa | Palco > PainelExpedicao | Viajando.
-- PainelExpedicao é recriado a cada tela; dentro dele: Escolher_<id>, VoltarCidade, RetirarVoto, Cancelar/AgoraNao,
-- Descansar, LevantarAcampamento, Exaustao (texto; barra inferior), EntrarNaLuta, AbandonarLuta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Tela = require(ReplicatedStorage.Shared.Regras.ExpedicaoTela)
local C = require(script.Parent.UI.Componentes)
local T = require(script.Parent.UI.Tema)

local DURACAO_VIAGEM = 1.2
local INTERVALO_PEDIDOS = 0.45 -- o servidor recusa pedidos a menos de 0,4 s do anterior
local RECUSA_RITMO = "Aguarde um instante."
local REPETIVEIS = { votar = true, retirarVoto = true, lutar = true } -- seguro reenviar uma vez se recusados por ritmo
local ESPACO = 8

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
	local estado = { portaAberta = false, levantadoEm = nil, emCombate = jogador:GetAttribute("InterfaceCombate") == true,
		esperaLuta = 0, agoraNaoEm = nil, confirmaAbandono = false }
	local memoria
	local viagemAtual = 0
	local lutaDesde -- os.clock() de quando a luta pendente (sem combate) começou a ser vista
	local fichaConfirma = 0

	local redesenhar

	-- Pedidos espaçados: cada um sai pelo menos INTERVALO_PEDIDOS depois do anterior.
	local proximoLivre = 0
	local ultimoPedido -- último pedido de ação ainda sem resposta (visão nova)
	local function enviar(pedido)
		local agora = os.clock()
		local quando = math.max(agora, proximoLivre)
		proximoLivre = quando + INTERVALO_PEDIDOS
		if pedido.acao ~= "consultar" then ultimoPedido = { pedido = pedido, tentativas = 0 } end
		if quando <= agora then remoto:FireServer(pedido) else
			task.delay(quando - agora, function() remoto:FireServer(pedido) end)
		end
	end
	local function votar(id)
		estado.portaAberta = visao ~= nil and visao.tipoDoNo == "hub" -- depois de votar a porta continua aberta
		enviar({ acao = "votar", opcao = id })
	end

	local function larguraDaInterface()
		local camera = workspace.CurrentCamera
		if not camera then return 1280 end
		return camera.ViewportSize.X / T.escala(camera.ViewportSize.Y)
	end

	local function novoPainel(nome, opcoes)
		local raiz = C.painel({ parent = palco, nome = "PainelExpedicao", tamanho = opcoes.tamanho,
			ancora = opcoes.ancora, posicao = opcoes.posicao, padding = 16 })
		raiz.AutomaticSize = Enum.AutomaticSize.Y
		Instance.new("UISizeConstraint", raiz).MaxSize = Vector2.new(opcoes.larguraMax, 4000)
		C.aplicarEscala(raiz)
		local c = raiz.Conteudo
		c.Size, c.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		local layout = Instance.new("UIListLayout")
		layout.SortOrder, layout.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, T.espacamentos.pequeno)
		layout.Parent = c
		return raiz, c
	end

	local function montarPainel(decisao)
		local ordem = 0
		local function proxima() ordem += 1; return ordem end
		local raiz, c
		local function texto(valor, secundario)
			return C.texto({ parent = c, texto = valor, ordem = proxima(), secundario = secundario })
		end
		-- Linha de botões que quebra para a linha de baixo quando falta largura.
		local function linha()
			local l = C.lista({ parent = c, nome = "Linha", horizontal = true, ordem = proxima(), espaco = ESPACO })
			l:FindFirstChildOfClass("UIListLayout").Wraps = true
			return l
		end
		local function botaoEm(pai, nome, rotulo, variante, desabilitado, aoClicar)
			return C.botao({ parent = pai, nome = nome, texto = rotulo, variante = variante, desabilitado = desabilitado,
				aoClicar = aoClicar, ordem = proxima() })
		end
		local function botoesDeVoto(l)
			if decisao.voltar then
				botaoEm(l, "VoltarCidade", decisao.voltar.texto, "perigo", not decisao.voltar.liberada, function() votar(decisao.voltar.id) end)
			end
			if decisao.retirarVoto then
				botaoEm(l, "RetirarVoto", "Retirar voto", "secundario", false, function() enviar({ acao = "retirarVoto" }) end)
			end
		end

		-- Cartões lado a lado (ou empilhados em tela estreita).
		local function cartoes()
			local lista = decisao.cartoes or {}
			local n = math.max(1, #lista)
			local disp = Tela.disposicao(larguraDaInterface(), n)
			local lado = disp.modo == "lado"
			local pai = C.lista({ parent = c, nome = "Cartoes", horizontal = lado, ordem = proxima(), espaco = ESPACO })
			for i, cart in lista do
				local largura = if lado then UDim2.new(1 / n, -ESPACO * (n - 1) / n, 0, 0) else UDim2.new(1, 0, 0, 0)
				local caixa = C.cartao({ parent = pai, nome = "Cartao_" .. cart.id, tamanho = largura, padding = 10, ordem = i })
				caixa.AutomaticSize = Enum.AutomaticSize.Y
				if cart.maisVotada or cart.votada then
					local traco = Instance.new("UIStroke")
					traco.Color = if cart.maisVotada then T.cores.ouro else T.cores.info
					traco.Thickness = T.espessuras.destaque
					traco.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					traco.Parent = caixa
				end
				local cc = caixa.Conteudo
				cc.Size, cc.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
				local interno = Instance.new("UIListLayout")
				interno.SortOrder, interno.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 4)
				interno.Parent = cc
				C.texto({ parent = cc, texto = (if cart.maisVotada then "★ " else "") .. cart.titulo, subtitulo = true, ordem = 1 })
				if cart.dica then C.texto({ parent = cc, texto = cart.dica, italico = true, secundario = true, ordem = 2 }) end
				local detalhes = {}
				if cart.custo then table.insert(detalhes, "Custo: " .. cart.custo) end
				if cart.votosTexto then table.insert(detalhes, cart.votosTexto) end
				if #detalhes > 0 then C.texto({ parent = cc, texto = table.concat(detalhes, " · "), secundario = true, ordem = 3 }) end
				if cart.motivo then C.texto({ parent = cc, texto = cart.motivo, italico = true, secundario = true, ordem = 4 }) end
				C.botao({ parent = cc, nome = "Escolher_" .. cart.id, texto = (if cart.votada then "✔ " else "") .. cart.rotuloVotar,
					variante = "principal", desabilitado = not cart.liberada, tamanho = UDim2.new(1, 0, 0, 48), ordem = 5,
					aoClicar = function() votar(cart.id) end })
			end
			return disp
		end
		local function largura(n)
			return Tela.disposicao(larguraDaInterface(), n).larguraMax + 40
		end

		if decisao.tela == "lutaPendente" then
			raiz, c = novoPainel("lutaPendente", { tamanho = UDim2.new(1, -32, 0, 0), ancora = Vector2.new(0.5, 0.5),
				posicao = UDim2.fromScale(0.5, 0.5), larguraMax = 480 })
			C.titulo({ parent = c, texto = decisao.titulo, ordem = proxima() })
			if decisao.erro then
				local e = texto(decisao.erro)
				e.TextColor3 = T.cores.perigo
			else
				texto("O grupo ainda não entrou na luta.", true)
			end
			botaoEm(c, "EntrarNaLuta", decisao.entrar.texto, "principal", false, function() enviar({ acao = "lutar" }) end).Size = UDim2.new(1, 0, 0, 52)
			botaoEm(c, "AbandonarLuta", decisao.abandonar.texto, "perigo", false, function()
				if estado.confirmaAbandono then
					estado.confirmaAbandono = false
					enviar({ acao = "abandonar" })
					redesenhar()
				else
					estado.confirmaAbandono = true
					fichaConfirma += 1
					local meu = fichaConfirma
					task.delay(5, function()
						if fichaConfirma == meu and estado.confirmaAbandono then estado.confirmaAbandono = false; redesenhar() end
					end)
					redesenhar()
				end
			end).Size = UDim2.new(1, 0, 0, 48)
		elseif decisao.tela == "porta" then
			local n = #decisao.cartoes
			raiz, c = novoPainel("porta", { tamanho = UDim2.new(1, -32, 0, 0), ancora = Vector2.new(0.5, 0.5),
				posicao = UDim2.fromScale(0.5, 0.5), larguraMax = largura(n) })
			C.titulo({ parent = c, texto = "A porta do esgoto", ordem = proxima() })
			texto("Para onde o grupo vai?", true)
			cartoes()
			local l = linha()
			botaoEm(l, decisao.fechar.nome, decisao.fechar.texto, "secundario", false, function()
				estado.portaAberta = false
				estado.agoraNaoEm = Tela.assinaturaVotos(visao)
				redesenhar()
			end)
			botoesDeVoto(l)
			if decisao.votacao then texto(decisao.votacao, true) end
		elseif decisao.tela == "acampamento" then
			-- Sem painel no meio: barra inferior com os botões e a lista curta do grupo.
			raiz, c = novoPainel("acampamento", { tamanho = UDim2.new(1, -32, 0, 0), ancora = Vector2.new(0.5, 1),
				posicao = UDim2.new(0.5, 0, 1, -16), larguraMax = 760 })
			if #decisao.grupo > 0 then texto("Acampamento · grupo: " .. table.concat(decisao.grupo, ", "), true) end
			-- Nível de Exaustão do jogador, junto ao descanso (descansar zera).
			if decisao.exaustao then
				local e = texto(decisao.exaustao .. " · descansar zera")
				e.Name = "Exaustao"
				e.TextColor3 = T.cores.perigo
			end
			local l = linha()
			if decisao.descansar then
				botaoEm(l, "Descansar", decisao.descansar.texto, "secundario", decisao.descansar.desabilitado, function() enviar({ acao = "descansar" }) end)
			end
			botaoEm(l, "LevantarAcampamento", decisao.levantar.texto, "principal", false, function()
				estado.levantadoEm = visao and visao.galho; redesenhar()
			end)
			botoesDeVoto(l)
			if decisao.votacao then texto(decisao.votacao, true) end
		elseif decisao.tela == "escolhas" then
			local n = #decisao.cartoes
			raiz, c = novoPainel("escolhas", { tamanho = UDim2.new(1, -32, 0, 0), ancora = Vector2.new(0.5, 0.5),
				posicao = UDim2.fromScale(0.5, 0.5), larguraMax = largura(n) })
			C.titulo({ parent = c, texto = decisao.titulo, ordem = proxima() })
			if decisao.subtitulo then texto(decisao.subtitulo, true) end
			cartoes()
			local l = linha()
			botoesDeVoto(l)
			if decisao.votacao then texto(decisao.votacao, true) end
		end
		return raiz
	end

	-- Controle da espera antes de mostrar a luta pendente (o servidor inicia a luta sozinho logo após o voto).
	local function atualizarEsperaLuta()
		local pendente = visao ~= nil and not visao.fim and estado.emCombate ~= true and (visao.fase == "luta" or visao.luta ~= nil)
		if not pendente then
			lutaDesde, estado.esperaLuta, estado.confirmaAbandono = nil, 0, false
			return
		end
		if not lutaDesde then
			lutaDesde = os.clock()
			local meu = lutaDesde
			task.delay(Tela.ESPERA_LUTA + 0.05, function() if lutaDesde == meu then redesenhar() end end)
		end
		estado.esperaLuta = os.clock() - lutaDesde
	end

	redesenhar = function()
		atualizarEsperaLuta()
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
			enviar({ acao = "consultar" })
			redesenhar()
		elseif tipo == "expedicaoConcluida" then
			estado.portaAberta = false
			local a = Tela.avisoConcluida(dado)
			C.aviso({ parent = gui, tipo = "sucesso", titulo = a.titulo, detalhe = a.detalhe, duracao = 5 })
		elseif tipo == "run" and type(dado) == "table" then
			if dado.erro then
				if dado.erro == RECUSA_RITMO then
					-- Não é falha do jogador: reenvia uma vez o que for seguro; do resto, só um lembrete discreto.
					local u = ultimoPedido
					if u and REPETIVEIS[u.pedido.acao] and u.tentativas < 1 then
						u.tentativas += 1
						enviar(u.pedido)
						ultimoPedido = u
					else
						C.aviso({ parent = gui, tipo = "info", titulo = "Um instante", detalhe = "Tente de novo.", duracao = 1.5 })
					end
				else
					ultimoPedido = nil
					C.aviso({ parent = gui, tipo = "perigo", titulo = "Não foi possível", detalhe = tostring(dado.erro), duracao = 3 })
				end
				return
			end
			ultimoPedido = nil
			local anterior = memoria
			local viaja
			viaja, memoria = Tela.viajar(memoria, dado)
			if anterior and memoria and anterior.galho ~= memoria.galho then
				estado.portaAberta, estado.levantadoEm, estado.agoraNaoEm = false, nil, nil
			end
			visao = if dado.semRun then nil else dado
			if dado.semRun then memoria = nil; estado.portaAberta, estado.levantadoEm, estado.agoraNaoEm = false, nil, nil end
			if viaja then viajar() end
			redesenhar()
		end
	end)
	jogador:GetAttributeChangedSignal("InterfaceCombate"):Connect(function()
		estado.emCombate = jogador:GetAttribute("InterfaceCombate") == true
		redesenhar()
	end)
	local function aoRedimensionar()
		local camera = workspace.CurrentCamera
		if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() redesenhar() end) end
	end
	aoRedimensionar()
	enviar({ acao = "consultar" })
	return gui
end

return View
