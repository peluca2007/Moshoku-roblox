-- Fim de partida persistente e navegável, somente após o evento do servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Extra = require(script.Parent.UI.ExtraCombate)
local T = Extra.tema
local Apresentacao = require(Shared.ApresentacaoResultado)
local EstadoResultado = require(Shared.EstadoResultado)
local Objetivos = require(Shared.Regras.Objetivos)
local FX = require(script.Parent.MenuEfeitos)
local View = {}

function View.start(state, inicio, sala)
	local resultado=EstadoResultado.new()
	local inicial=state.snapshot();if inicial then resultado.snapshot(inicial.combat.active) end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ResultadoPartida", false, 28
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local fundo = Instance.new("Frame")
	fundo.Name, fundo.Size, fundo.BackgroundColor3 = "Fundo", UDim2.fromScale(1, 1), T.cores.sombra
	fundo.BackgroundTransparency, fundo.Active, fundo.Visible, fundo.Parent = .2, true, false, gui
	local painel = Instance.new("ScrollingFrame")
	painel.Name, painel.AnchorPoint, painel.Position = "Painel", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	painel.Size, painel.BackgroundColor3, painel.BorderSizePixel = UDim2.new(.9, 0, .8, 0), T.cores.painel, 0
	painel.CanvasSize, painel.AutomaticCanvasSize, painel.ScrollBarThickness = UDim2.new(), Enum.AutomaticSize.Y, 4
	painel.Parent = fundo
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize, limite.Parent = Vector2.new(520, 500), painel -- 360 cortava o botão "Voltar à vila"
	local contornoPainel = Instance.new("UIStroke")
	contornoPainel.ApplyStrokeMode, contornoPainel.Color, contornoPainel.Thickness = Enum.ApplyStrokeMode.Border, T.cores.borda, T.espessuras.borda
	contornoPainel.Parent = painel
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 14), Enum.SortOrder.LayoutOrder, painel
	local margem = Instance.new("UIPadding")
	margem.PaddingTop, margem.PaddingBottom = UDim.new(0, 20), UDim.new(0, 20)
	margem.PaddingLeft, margem.PaddingRight, margem.Parent = UDim.new(0, 20), UDim.new(0, 20), painel
	local canto = Instance.new("UICorner")
	canto.CornerRadius, canto.Parent = UDim.new(0, T.raios.painel), painel
	local function rotulo(nome, altura, tamanho, ordem)
		local t = Instance.new("TextLabel")
		t.Name, t.Size, t.LayoutOrder = nome, UDim2.new(1, -4, 0, altura), ordem
		t.BackgroundTransparency, t.TextWrapped = 1, true
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.FontFace, t.TextSize, t.TextColor3, t.Parent = T.fontes.corpo, tamanho, T.cores.texto, painel
		return t
	end
	local emblema = rotulo("Emblema", 66, 56, 1)
	emblema.FontFace, emblema.TextXAlignment, emblema.TextColor3 = T.FONTE_ICONE, Enum.TextXAlignment.Center, T.cores.ouro
	local titulo = rotulo("Titulo", 54, 38, 2)
	titulo.FontFace = T.fontes.titulo
	local detalhe = rotulo("Detalhe", 56, 20, 3)
	local recursos = rotulo("Recuperacao", 40, 18, 4)
	recursos.Text, recursos.TextColor3 = "♥ Grupo recuperado", T.cores.secundario
	local proximo = rotulo("ProximoObjetivo", 56, 18, 5)
	proximo.TextColor3 = T.cores.alerta
	local function botao(nome, texto, ordem, cor, fn)
		local b = Instance.new("TextButton")
		b.Name, b.Text, b.Size, b.LayoutOrder = nome, texto, UDim2.new(1, -4, 0, 48), ordem
		b.BackgroundColor3, b.TextColor3, b.FontFace, b.TextSize = cor, T.cores.texto, T.fontes.rotulo, 18
		b.TextWrapped, b.AutomaticSize, b.Parent = true, Enum.AutomaticSize.Y, painel
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.Parent = UDim.new(0, 10), UDim.new(0, 10), b
		local c = Instance.new("UICorner")
		c.CornerRadius, c.Parent = UDim.new(0, T.raios.botao), b
		Extra.botao(b, nome == "Proxima", false)
		b.Activated:Connect(function()
			resultado.fechar(); fundo.Visible = false; fn()
		end)
	end
	local mundo = false -- luta do Modo História na arena regional: o servidor já devolveu o grupo ao mapa
	botao("Proxima", "Escolher próxima partida", 6, T.cores.ouro, function()
		if mundo then return end
		if sala and state.snapshot() and state.snapshot().salaConceitual then sala.abrirPreparacao() else inicio.abrirJogar() end
	end)
	botao("Campo", "Continuar", 7, T.cores.painel, function() end)
	local ultimoRun
	local atualizar
	local conexaoRun = ReplicatedStorage:WaitForChild("RunJogo").OnClientEvent:Connect(function(tipo, dado)
		if tipo == "run" and type(dado) == "table" and not dado.erro then
			ultimoRun = dado
			if fundo.Visible and atualizar then atualizar(state.snapshot()) end
		end
	end)
	atualizar = function(s)
		local r=resultado.resultado
		if r then
			local venceu = r.cor == "SUCESSO"
			titulo.Text,titulo.TextColor3,detalhe.Text=r.titulo .. (if venceu then "!" else ""),(if venceu then T.cores.sucesso else T.cores.perigo),r.detalhe
			emblema.Text,emblema.TextColor3=T.icone("combate"),if venceu then T.cores.sucesso else T.cores.perigo
		end
		local objetivo = Objetivos.atual({ run = ultimoRun, semRun = ultimoRun == nil, emEncontro = false })
		proximo.Text = if objetivo then "Próximo: " .. objetivo.titulo .. (if objetivo.linha and objetivo.linha ~= "" then " · " .. objetivo.linha else "") else "Próximo: consulte RUN."
		painel.Campo.Visible=not mundo
		painel.Campo.Text=if s and s.salaConceitual then "Voltar à sala" else "Voltar ao campo"
		painel.Proxima.Text=if mundo then "Continuar" elseif s and s.salaConceitual then "Preparar próxima partida" else "Escolher próxima partida"
		local abrir=resultado.visivel and not fundo.Visible
		fundo.Visible=resultado.visivel
		if abrir then
			painel.CanvasPosition=Vector2.zero
			if not FX.reduzidos then painel.BackgroundTransparency=.4;FX.animar(painel,.25,{BackgroundTransparency=0}) end
		end
	end
	local destruido = false
	gui.Destroying:Connect(function() destruido = true; conexaoRun:Disconnect() end)
	state.onEncontro(function(dados)
		if destruido then return end
		local r = Apresentacao.resumir(dados)
		if not r then return end
		mundo = type(dados) == "table" and dados.mundo == true
		state.setMira(nil)
		resultado.receber(r);atualizar(state.snapshot())
	end)
	state.onSnapshot(function(s)
		if destruido then return end
		resultado.snapshot(s.combat.active);atualizar(s)
	end)
	return gui
end
return View
