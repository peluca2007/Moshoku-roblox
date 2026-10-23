-- Livro Noite: apresentação da oferta confirmada pelo servidor; cliente só envia intenção.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local View = {}

function View.start()
	local remote = ReplicatedStorage:WaitForChild("TreinadorJogo")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "TreinadorRun", false, 43, false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local painel = C.dialogoNpc({ parent = gui, nomeNpc = "Treinador", fala = "", padding = 0,
		tamanho = UDim2.fromScale(.92, .85), posicao = UDim2.fromScale(.5, .5), ancora = Vector2.new(.5, .5) })
	painel.AutomaticSize = Enum.AutomaticSize.None
	painel.Conteudo.AutomaticSize = Enum.AutomaticSize.None
	painel.Conteudo.Size = UDim2.fromScale(1, 1)
	local limite = painel:FindFirstChildOfClass("UISizeConstraint"); limite.MaxSize = Vector2.new(560, 510)
	local lista = Instance.new("ScrollingFrame")
	lista.Name, lista.Position, lista.Size = "Conversa", UDim2.fromOffset(16, 12), UDim2.new(1, -32, 1, -24)
	lista.BackgroundTransparency, lista.BorderSizePixel, lista.ScrollBarThickness = 1, 0, 5
	lista.ScrollBarImageColor3 = T.cores.borda
	lista.AutomaticCanvasSize, lista.CanvasSize, lista.Parent = Enum.AutomaticSize.Y, UDim2.new(), painel.Conteudo
	local titulo, fala
	for _, filho in painel.Conteudo:GetChildren() do
		if filho:IsA("UIListLayout") or filho:IsA("TextLabel") then
			filho.Parent = lista
			if filho:IsA("TextLabel") then
				if filho.LayoutOrder == 1 then titulo = filho else fala = filho end
			end
		end
	end
	-- Ordem explícita preservada; a fala do dialogoNpc permanece em itálico.
	titulo.Name, titulo.LayoutOrder = "Titulo", 1
	local identidade = C.texto({ parent = lista, nome = "Arvore", ordem = 2 })
	fala.Name, fala.LayoutOrder = "Fala", 3
	local detalhes = C.texto({ parent = lista, nome = "Oferta", ordem = 4 })
	local mensagem = C.texto({ parent = lista, nome = "Mensagem", secundario = true, ordem = 5 })
	local confirmar = C.botao({ parent = lista, nome = "Confirmar", texto = "Aceitar provação", ordem = 6 })
	local fechar = C.botao({ parent = lista, nome = "Fechar", texto = "Sair", variante = "secundario", ordem = 7 })
	local conteudoLayout = lista:FindFirstChildOfClass("UIListLayout")
	local function ajustarAltura()
		local camera = workspace.CurrentCamera
		local alturaTela = camera and camera.ViewportSize.Y or 720
		local maximo = math.max(180, math.min(510, alturaTela - 32))
		limite.MaxSize = Vector2.new(560, maximo)
		local alturaConteudo = conteudoLayout and conteudoLayout.AbsoluteContentSize.Y or 0
		local altura = math.min(maximo, math.max(180, alturaConteudo + 48))
		painel.Size = UDim2.new(.92, 0, 0, altura)
	end
	if conteudoLayout then conteudoLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ajustarAltura) end
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarAltura) end
	task.defer(ajustarAltura)
	local faixa = Instance.new("Frame", painel)
	faixa.Name, faixa.Size, faixa.BorderSizePixel = "ArvoreDestaque", UDim2.new(0, T.espessuras.destaque, 1, -24), 0
	faixa.Position, faixa.BackgroundColor3 = UDim2.fromOffset(4, 12), T.cores.ouro
	local oferta, confirmado, pendente, aguardando
	fechar.Activated:Connect(function() gui.Enabled = false; confirmado = false end)
	confirmar.Activated:Connect(function()
		if not oferta or not oferta.podeComprar or aguardando then return end
        pendente = pendente or { acao = "aceitar", npcId = oferta.npcId, requestId = HttpService:GenerateGUID(false) }
		aguardando = true
		confirmar.Rotulo.Text = "Salvando treino…"
		remote:FireServer(pendente)
		local pedido = pendente
		task.delay(10, function()
			if pendente == pedido and aguardando then
				aguardando = false; confirmar.Rotulo.Text = "Tentar novamente"
				mensagem.Text = "Sem resposta. Tente novamente com o mesmo pedido."
			end
		end)
	end)
	remote.OnClientEvent:Connect(function(r)
		if type(r) ~= "table" or r.provacao then return end
		if r.oferta then
			if aguardando then return end
			oferta, confirmado, pendente, aguardando = r.oferta, false, nil, false
			titulo.Text = oferta.titulo or "Treinador"
			fala.Text = oferta.fala or ""
			local arvore = if oferta.arvore == "agua" then "Água" else "Furtividade e Armadilhas"
			confirmar.Rotulo.Text = "Aceitar provação"
			local visual = T.arvore(oferta.arvore)
			identidade.Text = (if visual.selo ~= "" then visual.selo else "✦") .. "  " .. arvore
			faixa.BackgroundColor3 = visual.cor
            detalhes.Text = (oferta.resumo or "") .. (if oferta.segunda then "\n\nVocê já tem um caminho: passar na prova lhe ensina um segundo, por 1 dia da expedição e sem custo de pontos. Tentativas não custam dias."
                else "\n\nPassar na prova ensina esta árvore e custa 1 dia da expedição, sem custo de pontos. Tentativas não custam dias. Sua ficha é atualizada sozinha.")
            mensagem.Text = r.mensagem or ""
            confirmar.Visible, confirmar.Rotulo.Text = oferta.podeComprar == true, "Aceitar provação"

			gui.Enabled = true
		elseif pendente and r.requestId == pendente.requestId then
			aguardando, pendente, confirmado = false, nil, false
			mensagem.Text = r.mensagem or "Pedido recusado."
			confirmar.Visible = not r.ok
			confirmar.Rotulo.Text = "Aceitar provação"
			gui.Enabled = not r.ok
		elseif not aguardando and not r.ok then
			titulo.Text, detalhes.Text, mensagem.Text = "Treinador", "", r.mensagem or "Treino indisponível."
			fala.Text, identidade.Text = "", ""
			confirmar.Visible, gui.Enabled = false, true
		end
	end)
	require(script.Parent.ProvacoesView).start(remote, function() gui.Enabled = false end)
	return gui
end

return View
