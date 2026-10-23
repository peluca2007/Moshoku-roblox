-- Ilustração da viagem e votação: avatares são somente apresentação, nunca fichas.
-- RunJogo continua sendo o canal autoritativo também usado pelo RunView.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local Extra = require(script.Parent.UI.ExtraTelas)
local HistoriaV1 = require(ReplicatedStorage.Shared.Mundo.HistoriaV1)
local Apresentacao = require(ReplicatedStorage.Shared.ApresentacaoAbertura)
local Aparencia = require(ReplicatedStorage.Shared.Aparencia.Aparencia)
local ModeloAparencia = require(script.Parent.ModeloAparencia)
local MesaState = require(script.Parent.MesaState)
local View = {}

local function nomeObjetivo(objetivo)
	return Apresentacao.nomeObjetivo(objetivo, HistoriaV1)
end

function View.start()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ViagemJogo", false, 42
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local conexoes, vivo, geracao = {}, true, 0
	local remote, estado, regiaoAnterior, regiaoAtual, votoPendente, ultimoEvento
	local tinhaEvento = false
	local tituloAnterior, tituloAtual
	local ultimoEnvio = -math.huge
	local perfilPessoal
	local pediuPerfil = false
	local render
	local painel
	MesaState.onPersonagemPessoal(function(perfil)
		perfilPessoal = perfil
		if vivo and painel.Visible and render then render() end
	end)
	local function conectar(sinal, funcao) table.insert(conexoes, sinal:Connect(funcao)) end
	local atalho = Extra.atalho(gui, "AtalhoViagem", "➤", "VIAGEM", 3)
	atalho.Position = UDim2.new(1, -84, 0, 138)
	painel = Extra.painel(gui, "Painel", Vector2.new(800, 780), UDim2.fromScale(.94, .9))
	local titulo = Extra.tituloPainel(painel.Conteudo, "VIAGEM DO GRUPO", 1)
	titulo.Position, titulo.Size = UDim2.fromOffset(0, 0), UDim2.new(1, -104, 0, 36)
	local fechar = Extra.fechar(painel.Conteudo, painel, 2)
	fechar.Position = UDim2.new(1, -96, 0, 0)
	local aviso = Extra.texto(painel.Conteudo, "Consulte a run para planejar a próxima viagem.", 3, "secundario")
	aviso.Position = UDim2.fromOffset(0, 42)
	local lista, layout = Extra.lista(painel.Conteudo, "Conteudo", UDim2.fromOffset(0, 78), UDim2.new(1, 0, 1, -78), 10)
	local function limpar()
		geracao += 1
		Extra.limpar(lista, layout)
	end
	local function avatares(grupo, ordem)
		local viewport = Instance.new("ViewportFrame")
		viewport.Name, viewport.LayoutOrder = "Grupo", ordem
		viewport.ZIndex = 5
		viewport.Size, viewport.BackgroundColor3 = UDim2.new(1, -8, 0, 180), T.cores.painel
		viewport.Ambient, viewport.LightColor = T.cores.secundario, T.cores.titulo
		viewport.LightDirection, viewport.Parent = Vector3.new(-1, -1, -1), lista
		local mundo = Instance.new("WorldModel", viewport)
		local camera = Instance.new("Camera", viewport)
		camera.FieldOfView = 38
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 3.5, 16), Vector3.new(0, 2.5, 0))
		viewport.CurrentCamera = camera
		local function enquadrar()
			local aspecto = math.max(.4, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
			local distancia = math.max(16, math.min(#grupo, 4) * 3.8 / (2 * math.tan(math.rad(19)) * aspecto) + 3)
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 3.5, distancia), Vector3.new(0, 2.5, 0))
		end
		viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(enquadrar)
		enquadrar()
		local versao = geracao
		for indice, membro in grupo do
			if indice > 4 then break end
			task.spawn(function()
				local modelo
				if membro.userId == Players.LocalPlayer.UserId then
					local raceId = perfilPessoal and perfilPessoal.construcao and perfilPessoal.construcao.raceId or "race/humano"
					local aparencia = perfilPessoal and perfilPessoal.aparencia or Aparencia.padrao(raceId, 1)
					local ok, criado = pcall(ModeloAparencia.criar, aparencia, raceId)
					if not ok then warn("[ViagemView] não foi possível montar a aparência: " .. tostring(criado)); return end
					modelo = criado
				else
					local jogador = Players:GetPlayerByUserId(membro.userId)
					local personagem = jogador and jogador.Character
					if personagem then
						local anterior = personagem.Archivable
						personagem.Archivable = true
						local ok, clonada = pcall(function() return personagem:Clone() end)
						personagem.Archivable = anterior
						if ok then modelo = clonada end
					end
					if not modelo then
						local raceId = "race/humano"
					local aparencia = Aparencia.padrao(raceId, 1)
					local ok, criado = pcall(ModeloAparencia.criar, aparencia, raceId)
					if not ok then warn("[ViagemView] não foi possível montar a aparência: " .. tostring(criado)); return end
					modelo = criado
				end
				end
				if not vivo or versao ~= geracao or not painel.Visible then modelo:Destroy(); return end
				for _, objeto in modelo:GetDescendants() do
					if objeto:IsA("BaseScript") then objeto:Destroy()
					elseif objeto:IsA("BasePart") then objeto.Anchored, objeto.CanCollide = true, false end
				end
				local humanoide = modelo:FindFirstChildOfClass("Humanoid")
				if humanoide then humanoide:Destroy() end
				modelo.Parent = mundo
				modelo:PivotTo(CFrame.new((indice - (#grupo + 1) / 2) * 3.4, 0, 0) * CFrame.Angles(0, math.pi, 0))
			end)
		end
	end
	local function enviar(pedido)
		if not remote then aviso.Text = "Viagem indisponível neste servidor."; return false end
		if os.clock() - ultimoEnvio < .4 then aviso.Text = "Aguarde um instante antes de tentar novamente."; return false end
		ultimoEnvio = os.clock()
		remote:FireServer(pedido)
		return true
	end
	render = function()
		limpar()
		local ordem = 0
		local function texto(valor, destaque)
			ordem += 1
			return Extra.texto(lista, valor, ordem, destaque)
		end
		local function botao(nome, valor, ativo, acao)
			ordem += 1
			return Extra.botao(lista, nome, valor, ordem, ativo, acao)
		end
		if not estado or estado.semRun then texto("Inicie uma expedição no painel RUN para viajar."); return end
		local d = estado
		local viagem = d.viagem
		texto(if viagem and viagem.origem and viagem.destino then viagem.origem .. " → " .. viagem.destino
			elseif regiaoAnterior then tostring(tituloAnterior or regiaoAnterior) .. " → " .. tostring(d.regiaoTitulo or d.regiao) else "Em " .. tostring(d.regiaoTitulo or d.regiao or "região atual"), "alerta")
		texto(string.format("Dia %.2f · %.2f dias restantes", d.dia, d.diasRestantes))
		local objetivo = d.objetivo or {}
		texto("Objetivo: " .. nomeObjetivo(objetivo) .. " · " .. tostring(objetivo.status or "em andamento"), "secundario")
		texto("Caixa da viagem: " .. tostring(d.ouroViagem or 0) .. " PO", "secundario")
		local r = d.ultimoEvento
		if r then texto(if r.pericia then string.format("%s %d vs CD %d — %s: %s", r.pericia, r.total, r.cd,
			if r.sucesso then "sucesso" else "falha", r.texto) else r.texto, r.sucesso and "sucesso" or "perigo") end
		ordem += 1
		avatares(d.grupo or {}, ordem)
		for _, m in d.grupo or {} do texto((m.nome or tostring(m.userId)) .. (if not m.presente then " · ausente" elseif m.caido then " · caído" else " · presente"), "secundario") end
		if d.fim then texto("Expedição encerrada. Consulte a conta para ver o progresso."); return end
		if d.luta then texto("Luta pendente: " .. tostring(d.luta.titulo) .. ". Continue pelo painel RUN."); return end
		texto(if d.evento then "NA ESTRADA · " .. tostring(d.evento.titulo) else "Próximo destino · voto do grupo", "alerta")
		local podeVotar = false
		for _, m in d.grupo or {} do if m.userId == Players.LocalPlayer.UserId then podeVotar = m.presente and not m.caido end end
		for _, op in d.opcoes or {} do
			local selecionada = d.votei == op.id
			local rotulo = (if selecionada then "✓ Seu voto · " else "") .. op.texto .. string.format(" · %.2f dia(s)", op.dias or 0)
			local peso = d.contagem and d.contagem[op.id]
			rotulo ..= if type(peso) == "number" then " · peso de votos: " .. tostring(peso) else " · contagem indisponível"
			if not op.liberada then rotulo ..= " · " .. tostring(op.motivo or "Indisponível") end
			local ativo = podeVotar and op.liberada and not votoPendente
			botao(op.id, rotulo, ativo, function()
				if enviar({ acao = "votar", opcao = op.id }) then
					local tentativa = {}
					votoPendente = tentativa
					aviso.Text = "Enviando voto ao grupo…"
					render()
					task.delay(8, function()
						if vivo and votoPendente == tentativa then votoPendente = nil; aviso.Text = "Sem confirmação. Consulte novamente antes de votar."; if painel.Visible then render() end end
					end)
				end
			end)
		end
		texto("Aguardando " .. tostring(#(d.aguardando or {})) .. " voto(s).", "secundario")
	end
	conectar(fechar.Activated, function() painel.Visible = false; limpar() end)
	conectar(atalho.Activated, function() painel.Visible = not painel.Visible; if painel.Visible then render(); enviar({ acao = "consultar" }) else limpar() end end)
	conectar(gui.Destroying, function()
		vivo, geracao = false, geracao + 1
		for _, conexao in conexoes do conexao:Disconnect() end
	end)
	task.spawn(function()
		remote = ReplicatedStorage:WaitForChild("RunJogo", 15)
		if not vivo or not remote then return end
		if not pediuPerfil then
			pediuPerfil = true
			MesaState.send("personagemPessoalConsultar", {})
		end
		conectar(remote.OnClientEvent, function(tipo, dado)
			if tipo ~= "run" or type(dado) ~= "table" then return end
			votoPendente = nil
			if dado.erro then aviso.Text = dado.erro; if painel.Visible then render() end; return end
			if dado.regiao and regiaoAtual and dado.regiao ~= regiaoAtual then regiaoAnterior, tituloAnterior = regiaoAtual, tituloAtual end
			regiaoAtual, tituloAtual, estado = dado.regiao, dado.regiaoTitulo, dado
			if dado.semRun then regiaoAnterior = nil end
			if tinhaEvento and not dado.evento and not dado.semRun then painel.Visible = dado.ultimoEvento ~= nil end
			tinhaEvento = dado.evento ~= nil
			if dado.evento then
				local chave = table.concat({ dado.evento.id or "", dado.galho or "", dado.regiao or "", tostring(dado.dia or 0) }, "/")
				if chave ~= ultimoEvento then painel.Visible = true; ultimoEvento = chave end
			else ultimoEvento = nil end
			aviso.Text = "Escolha uma opção para votar. O servidor confirma o resultado."
			if painel.Visible then render() end
		end)
		task.delay(.5, function() if vivo and os.clock() - ultimoEnvio >= .4 then enviar({ acao = "consultar" }) end end)
	end)
	return gui
end

return View
