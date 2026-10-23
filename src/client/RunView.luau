-- Painel da run: cliente apresenta o estado confirmado e envia intenções ao RunServico.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Extra = require(script.Parent.UI.ExtraTelas)
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)
local HistoriaV1 = require(ReplicatedStorage.Shared.Mundo.HistoriaV1)
local PersonagensProntos = require(ReplicatedStorage.Shared.PersonagensProntos)
local Apresentacao = require(ReplicatedStorage.Shared.ApresentacaoAbertura)

local View = {}

function View.start()
	local remote = ReplicatedStorage:WaitForChild("RunJogo")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "RunJogo", false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local atalho = Extra.atalho(gui, "AtalhoRun", "⚔", "RUN", 1)
	atalho.Position = UDim2.new(1, -84, 0, 14)
	local painel = Extra.painel(gui, "Painel", Vector2.new(620, 700), UDim2.new(.94, 0, 0, 0))
	painel.AutomaticSize = Enum.AutomaticSize.Y
 local conteudo = painel.Conteudo
 conteudo.Size, conteudo.AutomaticSize = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y
	local titulo = Extra.tituloPainel(conteudo, "RUN", 1)
	titulo.Position, titulo.Size = UDim2.fromOffset(0, 0), UDim2.new(1, -104, 0, 36)
	local fechar = Extra.fechar(conteudo, painel, 2)
	fechar.Position = UDim2.new(1, -96, 0, 0)
	local lista, layout = Extra.lista(conteudo, "Conteudo", UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 0), 8)
	local function ajustarConteudo()
  local altura=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
  local escala=painel:FindFirstChildOfClass("UIScale")
  local limite=math.max(100,altura*.82/(escala and escala.Scale or 1)-88)
  lista.Size=UDim2.new(1,0,0,math.min(layout.AbsoluteContentSize.Y+12,limite))
 end
 layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ajustarConteudo)
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarConteudo)
 local function limpar()
		Extra.limpar(lista, layout)
	end
	local function texto(valor, destaque)
		local ordem = #lista:GetChildren()
		return Extra.texto(lista, valor, ordem, destaque)
	end
	local function botao(valor, ativo, acao)
		local ordem = #lista:GetChildren()
		return Extra.botao(lista, "Opcao", valor, ordem, ativo, acao)
	end
	local ultimoEstado
	local ganhoDaConta
	-- Recusa do servidor fica visível por 8 s, mesmo que um novo estado redesenhe o painel logo depois.
	local avisoRecente, avisoAte = nil, 0
	local function desenhar(dado, aviso)
		limpar()
		if aviso then avisoRecente, avisoAte = aviso, os.clock() + 8 end
		if avisoRecente and os.clock() < avisoAte then texto(avisoRecente, "perigo") end
		if dado.erro then texto(dado.erro, "perigo"); return end
		ultimoEstado = dado
		if dado.semRun then
			titulo.Text = "RUN · nova"
			texto("Uma expedição é uma aventura em grupo, com prazo em dias. Comece pelo botão abaixo; o jogo mostra como começar.")
			botao("Nova expedição", true, function() painel.Visible = false; require(script.Parent.AberturaFluxo).novaExpedicao() end)
			return
		end
		local nodo = HistoriaV1.HISTORIA.nos[dado.galho]
		if dado.mundoAberto then texto("Explore a pé. Caçadas no quadro da praça; Floresta Sombria pela trilha, Ruínas pela passagem das montanhas.", "secundario") end
		titulo.Text = "RUN · " .. tostring(dado.titulo or (nodo and nodo.titulo) or "Expedição")
		texto(string.format("Dia %d · %s · restam %.2f dias · objetivo: %s%s", math.floor(dado.dia)+1, dado.relogio and dado.relogio.periodo or "amanhecer", dado.diasRestantes, Apresentacao.nomeObjetivo(dado.objetivo, HistoriaV1),
			if dado.objetivo.status == "expirado" then " (PRAZO ESGOTADO)" elseif dado.objetivo.status == "cumprido" then " (cumprido)" else ""), "alerta")
		local linhas = {}
		for _, m in dado.grupo or {} do
			table.insert(linhas, m.nome .. (if not m.presente then " (ausente)" elseif m.caido then " (caído)" else ""))
		end
		texto("Grupo: " .. table.concat(linhas, ", "), "secundario")
		local plano = dado.plano
		if plano then
			if plano.modo == "zero" and not plano.escolhida then
				texto("Escolha sua árvore inicial:")
				for _, id in plano.oferta or {} do
					botao(Apresentacao.nomeArvore(id, Catalogo), true, function() remote:FireServer({ acao = "escolherArvore", arvore = id }) end)
				end
			elseif plano.escolhida then texto("Árvore inicial: " .. Apresentacao.nomeArvore(plano.escolhida, Catalogo), "secundario")
			elseif plano.modo == "pronto" then texto("Personagem pronto: " .. Apresentacao.nomePronto(plano.prontoId, PersonagensProntos) .. " · defeitos: " .. table.concat(plano.defeitos or {}, ", "), "secundario")
			elseif plano.modo == "semArvore" then texto("Você ainda não tem um caminho: fale com um mestre da vila e passe na prova dele.", "secundario") end
			if plano.segunda then texto("Segundo caminho aprendido: " .. Apresentacao.nomeArvore(plano.segunda, Catalogo), "secundario") end
		end
		if dado.fim then
			texto(if dado.fim.motivo == "final" then "A run chegou ao fim: " .. tostring(dado.fim.final) else "O grupo caiu. A run terminou.", "sucesso")
			if ganhoDaConta then
				local conquistas = if #ganhoDaConta.conquistas > 0 then " · conquistas: " .. table.concat(ganhoDaConta.conquistas, ", ") else ""
				texto(string.format("Conta: +%d moedas (total %d)%s", ganhoDaConta.ganho, ganhoDaConta.total, conquistas), "alerta")
			end
			botao("Nova expedição", true, function() painel.Visible = false; require(script.Parent.AberturaFluxo).novaExpedicao() end)
			return
		end
		if dado.luta then
			texto("LUTA: " .. tostring(dado.luta.titulo), "perigo")
			botao("Entrar na luta", true, function() remote:FireServer({ acao = "lutar" }) end)
			return
		end
		if dado.evento then texto("NA ESTRADA: " .. tostring(dado.evento.titulo), "alerta"); texto("O que o grupo faz? (voto)")
		else texto(if dado.mundoAberto then "Explore o mundo a pé. Decisões da história aparecem ao alcançar cada local." else "Para onde ir? (voto do grupo)") end
		for _, op in dado.opcoes or {} do
			local marca = if dado.votei == op.id then "✔ " else ""
			local custo = if op.dias > 0 then string.format(" · %.2f dia(s)", op.dias) else ""
			local rotulo = marca .. op.texto .. custo .. (if op.liberada then "" else " · " .. tostring(op.motivo))
			botao(rotulo, op.liberada, function() remote:FireServer({ acao = "votar", opcao = op.id }) end)
		end
		if dado.aguardando and #dado.aguardando > 0 then texto("Aguardando voto de " .. #dado.aguardando .. " jogador(es).", "secundario") end
	end
	remote.OnClientEvent:Connect(function(tipo, dado)
		if tipo == "conta" and type(dado) == "table" then ganhoDaConta = dado; if ultimoEstado then desenhar(ultimoEstado) end; return end
		if tipo ~= "run" or type(dado) ~= "table" then return end
		if dado.evento and (not ultimoEstado or not ultimoEstado.evento or ultimoEstado.evento.id ~= dado.evento.id) then painel.Visible = true end
		if dado.erro and ultimoEstado then desenhar(ultimoEstado, dado.erro) else desenhar(dado) end
	end)
	atalho.Activated:Connect(function()
		painel.Visible = not painel.Visible
		if painel.Visible then remote:FireServer({ acao = "consultar" }) end
	end)
	return gui
end

return View
