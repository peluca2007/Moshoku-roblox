-- Diário da expedição: só apresenta o estado confirmado (dia e prazo, grupo, lugar, descansos, fim da run).
-- A escolha de caminhos, o acampamento e a luta pendente são da ExpedicaoView; o texto vem de Regras/ExpedicaoTela.
-- Instances (para playtest): ScreenGui "RunJogo" > AtalhoRun | Painel (Conteudo > Corpo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Extra = require(script.Parent.UI.ExtraTelas)
local C = require(script.Parent.UI.Componentes)
local T = require(script.Parent.UI.Tema)
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)
local PersonagensProntos = require(ReplicatedStorage.Shared.PersonagensProntos)
local Apresentacao = require(ReplicatedStorage.Shared.ApresentacaoAbertura)
local Tela = require(ReplicatedStorage.Shared.Regras.ExpedicaoTela)

local RECUSA_RITMO = "Aguarde um instante." -- ritmo do servidor, não é erro para mostrar

local View = {}

local function nomeDe(userId)
	local jogador = Players:GetPlayerByUserId(userId)
	return if jogador then jogador.DisplayName else "Jogador"
end

function View.start()
	local remote = ReplicatedStorage:WaitForChild("RunJogo")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "RunJogo", false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local atalho = Extra.atalho(gui, "AtalhoRun", "⚔", "DIÁRIO", 1)
	atalho.Position = UDim2.new(1, -84, 0, 14)

	local painel = C.painel({ parent = gui, nome = "Painel", tamanho = UDim2.new(0.94, 0, 0, 0), ancora = Vector2.new(0.5, 0.5),
		posicao = UDim2.fromScale(0.5, 0.5), padding = T.espacamentos.padrao })
	painel.AutomaticSize = Enum.AutomaticSize.Y
	painel.Visible = false
	Instance.new("UISizeConstraint", painel).MaxSize = Vector2.new(620, 4000)
	C.aplicarEscala(painel)
	local conteudo = painel.Conteudo
	conteudo.Size, conteudo.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	local raiz = Instance.new("UIListLayout")
	raiz.SortOrder, raiz.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, T.espacamentos.pequeno)
	raiz.Parent = conteudo
	C.titulo({ parent = conteudo, nome = "Titulo", texto = "Diário da expedição", ordem = 1 })
	local corpo = C.lista({ parent = conteudo, nome = "Corpo", ordem = 2 })
	C.botao({ parent = conteudo, nome = "Fechar", texto = "Fechar", variante = "secundario", ordem = 3,
		aoClicar = function() painel.Visible = false end })

	local ordem = 0
	local function texto(valor, estilo)
		ordem += 1
		local t = C.texto({ parent = corpo, texto = valor, ordem = ordem, secundario = estilo == "secundario" })
		if estilo and estilo ~= "secundario" then t.TextColor3 = T.cores[estilo] or T.cores.texto end
		return t
	end
	local function botao(valor, acao)
		ordem += 1
		return C.botao({ parent = corpo, nome = "Opcao", texto = valor, variante = "secundario", ordem = ordem,
			tamanho = UDim2.new(1, 0, 0, 48), aoClicar = acao })
	end
	local function novaExpedicao()
		painel.Visible = false
		require(script.Parent.AberturaFluxo).novaExpedicao()
	end

	local ultimoEstado
	local ganhoDaConta
	-- Recusa do servidor fica visível por 8 s, mesmo que um novo estado redesenhe o painel logo depois.
	local avisoRecente, avisoAte = nil, 0
	local function desenhar(dado, aviso)
		for _, filho in corpo:GetChildren() do
			if filho:IsA("GuiObject") then filho:Destroy() end
		end
		ordem = 0
		if aviso then avisoRecente, avisoAte = aviso, os.clock() + 8 end
		if avisoRecente and os.clock() < avisoAte then texto(avisoRecente, "perigo") end
		if dado.erro then texto(dado.erro, "perigo"); return end
		ultimoEstado = dado
		if dado.semRun then
			texto("Uma expedição é uma aventura em grupo, com prazo em dias. Comece pelo botão abaixo; o jogo mostra como começar.")
			botao("Nova expedição", novaExpedicao)
			return
		end
		local d = Tela.diario(dado, nomeDe)
		if d then
			texto(d.dia, "alerta")
			if d.lugar then texto(d.lugar) end
			if d.descansos then texto(d.descansos, "secundario") end
			if d.concluida then texto(d.concluida, "sucesso") end
			if #d.grupo > 0 then texto("Grupo: " .. table.concat(d.grupo, ", "), "secundario") end
		end
		local plano = dado.plano
		if plano then
			if plano.modo == "zero" and not plano.escolhida then
				texto("Escolha sua árvore inicial:")
				for _, id in plano.oferta or {} do
					botao(Apresentacao.nomeArvore(id, Catalogo), function() remote:FireServer({ acao = "escolherArvore", arvore = id }) end)
				end
			elseif plano.escolhida then texto("Árvore inicial: " .. Apresentacao.nomeArvore(plano.escolhida, Catalogo), "secundario")
			elseif plano.modo == "pronto" then texto("Personagem pronto: " .. Apresentacao.nomePronto(plano.prontoId, PersonagensProntos) .. " · defeitos: " .. table.concat(plano.defeitos or {}, ", "), "secundario")
			elseif plano.modo == "semArvore" then texto("Você ainda não tem um caminho: fale com um mestre da vila e passe na prova dele.", "secundario") end
			if plano.segunda then texto("Segundo caminho aprendido: " .. Apresentacao.nomeArvore(plano.segunda, Catalogo), "secundario") end
		end
		if dado.fim then
			texto(Tela.textoFim(dado), "sucesso")
			if ganhoDaConta then
				local conquistas = if #ganhoDaConta.conquistas > 0 then " · conquistas: " .. table.concat(ganhoDaConta.conquistas, ", ") else ""
				texto(string.format("Conta: +%d moedas (total %d)%s", ganhoDaConta.ganho, ganhoDaConta.total, conquistas), "alerta")
			end
			botao("Nova expedição", novaExpedicao)
		end
	end
	remote.OnClientEvent:Connect(function(tipo, dado)
		if tipo == "conta" and type(dado) == "table" then ganhoDaConta = dado; if ultimoEstado then desenhar(ultimoEstado) end; return end
		if tipo ~= "run" or type(dado) ~= "table" then return end
		if dado.erro == RECUSA_RITMO then return end
		if dado.erro and ultimoEstado then desenhar(ultimoEstado, dado.erro) else desenhar(dado) end
	end)
	atalho.Activated:Connect(function()
		painel.Visible = not painel.Visible
		if painel.Visible then remote:FireServer({ acao = "consultar" }) end
	end)
	return gui
end

return View
