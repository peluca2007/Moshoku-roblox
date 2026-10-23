-- Fila mínima do encontro: apresenta o estado do servidor e passa a intenção.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Extra = require(script.Parent.UI.ExtraCombate)
local T = Extra.tema
local Apresentacao = require(script.Parent.EncontroAutonomoApresentacao)
local Fogo = require(ReplicatedStorage.Shared.Regras.Fogo)
local ArvoresPrincipiante = require(ReplicatedStorage.Shared.Regras.ArvoresPrincipiante)
local HabilidadesAutonomas = require(ReplicatedStorage.Shared.EncontroAutonomoHabilidades)
local Terreno = require(ReplicatedStorage.Shared.EncontroAutonomoTerreno)
local CombateGrid = require(ReplicatedStorage.Shared.Regras.Combate)
local GradeView = require(script.Parent.EncontroAutonomoGradeView)
local MapaTaticoView = require(script.Parent.EncontroAutonomoMapaTaticoView)
local CURA = "ability/cura/Principiante/cura"
local VIGOR_EMPRESTADO = "ability/cura/Principiante/vigor-emprestado"
local RAJADA_CURTA = "ability/vento/Principiante/rajada-curta"
local PEDRISCO = "ability/terra/Principiante/pedrisco"
local BALA_DE_PEDRA = "ability/terra/Principiante/bala-de-pedra"
local CLARAO = "ability/fogo/Principiante/clarao"
local MURO_DE_TERRA = "ability/terra/Principiante/muro-de-terra"
local ANTEPARO = HabilidadesAutonomas.ANTEPARO_TEORICO
local ESCUDO_AGUA = HabilidadesAutonomas.ESCUDO_DE_AGUA
local NEVOA_DENSA = HabilidadesAutonomas.NEVOA_DENSA
local SOPRO_DE_POEIRA = HabilidadesAutonomas.SOPRO_DE_POEIRA
local PASSO_DE_VENTO = HabilidadesAutonomas.PASSO_DE_VENTO
local VACUO_LOCALIZADO = HabilidadesAutonomas.VACUO_LOCALIZADO
local DARDO_ARCANO = "ability/teorica/Principiante/dardo-arcano"
local MAO_DE_TERRA = HabilidadesAutonomas.MAO_DE_TERRA
local ESCAPAR_MAO = HabilidadesAutonomas.ESCAPAR_MAO
local ARRASTAR_MAO = HabilidadesAutonomas.ARRASTAR_MAO
local SOLTAR_MAO = HabilidadesAutonomas.SOLTAR_MAO
local LAMINA_DE_VENTO = "ability/vento/Principiante/lamina-de-vento"
local RESPINGO = "ability/agua/Principiante/respingo"
local BOLA_DE_AGUA = "ability/agua/Principiante/bola-de-agua"
local FLECHA_DE_AGUA = "ability/agua/Principiante/flecha-de-agua"
local IMPACTO_DE_GELO = "ability/agua/Principiante/impacto-de-gelo"
local EMPURRAO = "ability/vento/Principiante/empurrao"

local function muroNaLinha(atacante, alvo, perigos)
	local linha = CombateGrid.linha(atacante.x, atacante.z, alvo.x, alvo.z)
	for _, casa in ipairs(linha) do
		for _, zona in ipairs(perigos or {}) do
			if (zona.abilityId == MURO_DE_TERRA or zona.abilityId == ANTEPARO)
				and zona.x == casa[1] and zona.z == casa[2]
			then return true end
		end
	end
	return false
end

local View = {}

function View.start(state)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "EncontroAutonomo", false, 9
	gui.IgnoreGuiInset, gui.Enabled = true, true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- painéis V2 (z=2) escondiam botões/textos crus (z=1) no modo Global
	gui.Parent = playerGui
	local function menuInicial()
		return playerGui:FindFirstChild("InicioJogo")
	end
	local function salaConceitual()
		return playerGui:FindFirstChild("SalaConceitual")
	end
	local function menuEmPrimeiroPlano(menu)
		local fundo = menu and menu:FindFirstChild("MenuInicial")
		return menu ~= nil and menu.Enabled and fundo ~= nil and fundo.Visible
	end
	local avisoCombate, sequenciaAviso = nil, 0
	local restaurarSala = nil
	local interfacesDesligadas = false
	local desistirConfirmacaoVersao = nil

	local painel = Instance.new("Frame")
	painel.Name, painel.AnchorPoint = "Painel", Vector2.new(.5, 0)
	painel.Position, painel.Size = UDim2.new(.5, 0, 0, 120), UDim2.fromOffset(300, 112)
	painel.BackgroundColor3, painel.BackgroundTransparency = T.cores.painel, .04
	painel.Visible, painel.Parent = false, gui
	local canto = Instance.new("UICorner")
	canto.CornerRadius, canto.Parent = UDim.new(0, T.raios.painel), painel
	local borda = Instance.new("UIStroke")
	borda.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	borda.Color, borda.Thickness, borda.Parent = T.cores.borda, T.espessuras.borda, painel
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize, limite.Parent = Vector2.new(980, 440), painel
	local apresentacao = Apresentacao.start(gui, state)
 require(script.Parent.GradeTaticaVisual).start(gui, state)
	local gradeMovimento = GradeView.start(gui, state)
	local mapaTatico = MapaTaticoView.start(gui, state)

	local titulo = Instance.new("TextLabel")
	titulo.Name, titulo.Position, titulo.Size = "Turno", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 30)
	titulo.BackgroundTransparency, titulo.FontFace = 1, T.fontes.titulo
	titulo.TextColor3, titulo.TextSize, titulo.TextXAlignment = T.cores.texto, 21, Enum.TextXAlignment.Left
	titulo.TextTruncate, titulo.Parent = Enum.TextTruncate.AtEnd, painel

	local prazo = Instance.new("TextLabel")
	prazo.Name, prazo.Position, prazo.Size = "PrazoTurno", UDim2.new(1, -91, 0, 10), UDim2.fromOffset(77, 30)
	prazo.BackgroundTransparency, prazo.FontFace = 1, T.fontes.rotulo
	prazo.TextColor3, prazo.TextSize, prazo.TextXAlignment = T.cores.secundario, 16, Enum.TextXAlignment.Right
	prazo.Visible, prazo.Parent = false, painel
	titulo.Size = UDim2.new(1, -110, 0, 30)
	local deadlineAtual
	local ultimoSegundo
	local function atualizarContador()
		local restante = if deadlineAtual then math.max(0, math.ceil(deadlineAtual - workspace:GetServerTimeNow())) else nil
		if restante == ultimoSegundo then return end
		ultimoSegundo = restante
		prazo.Visible = restante ~= nil
		prazo.Text = if restante == nil then "" elseif restante == 0 then "0 s" else tostring(restante) .. " s"
		prazo.TextColor3 = if restante and restante <= 10 then T.cores.texto else T.cores.secundario
	end

	local detalhe = Instance.new("TextLabel")
	detalhe.Name, detalhe.Position, detalhe.Size = "Detalhe", UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 22)
	detalhe.BackgroundTransparency, detalhe.FontFace = 1, T.fontes.corpo
	detalhe.TextColor3, detalhe.TextSize, detalhe.TextXAlignment = T.cores.secundario, 15, Enum.TextXAlignment.Left
	detalhe.TextWrapped, detalhe.Parent = true, painel
	detalhe.Size = UDim2.new(1, -28, 0, 44)

	local opcoes = Instance.new("ScrollingFrame")
	opcoes.Name, opcoes.Position, opcoes.Size = "Alvos", UDim2.fromOffset(14, 88), UDim2.new(1, -28, 0, 0)
	opcoes.BackgroundTransparency, opcoes.BorderSizePixel, opcoes.ScrollBarThickness = 1, 0, 6
	opcoes.ScrollingDirection, opcoes.AutomaticCanvasSize = Enum.ScrollingDirection.Y, Enum.AutomaticSize.None
	opcoes.CanvasSize, opcoes.Parent = UDim2.new(), painel

	local passar = Instance.new("TextButton")
	passar.Name, passar.Position, passar.Size = "EncerrarTurno", UDim2.new(0, 14, 1, -42), UDim2.new(1, -28, 0, 32)
	passar.BackgroundColor3, passar.TextColor3 = T.cores.painel, T.cores.texto
	passar.FontFace, passar.TextSize, passar.Text = T.fontes.rotulo, 16, "Encerrar turno"
	passar.AutoButtonColor, passar.Parent = true, painel
	passar.Size = UDim2.fromOffset(150, 32)
	local botaoCanto = Instance.new("UICorner")
	botaoCanto.CornerRadius, botaoCanto.Parent = UDim.new(0, T.raios.botao), passar
	local desistir = Instance.new("TextButton")
	desistir.Name, desistir.Position, desistir.Size = "Desistir", UDim2.new(0, 174, 1, -42), UDim2.fromOffset(112, 32)
	desistir.BackgroundColor3, desistir.TextColor3 = T.cores.painel, T.cores.texto
	desistir.FontFace, desistir.TextSize, desistir.Text = T.fontes.rotulo, 14, "Render-se"
	desistir.Visible, desistir.Parent = false, painel
	local desistirCanto = Instance.new("UICorner")
	desistirCanto.CornerRadius, desistirCanto.Parent = UDim.new(0, T.raios.botao), desistir

	local faixa = Instance.new("Frame")
	faixa.Name, faixa.BackgroundTransparency, faixa.Parent = "AcoesPrincipais", 1, painel
	local grupoMobile
	local function atualizar(estado)
		if not estado or estado.version ~= desistirConfirmacaoVersao then desistirConfirmacaoVersao = nil end
		deadlineAtual = if estado and estado.phase == "active" and type(estado.turnDeadline) == "number"
			then estado.turnDeadline else nil
		atualizarContador()
		if not estado then painel.Visible = false; apresentacao.atualizar(nil); return end
		Players.LocalPlayer:SetAttribute("InterfaceCombate", true)
		local scrollAnterior = opcoes.CanvasPosition.Y
		painel.Visible = true
		local menu = menuInicial()
		local menuVisivel = menuEmPrimeiroPlano(menu)
		if menu then menu.Enabled = false end
		local sala = salaConceitual()
		if restaurarSala == nil then
			restaurarSala = sala ~= nil and sala.Enabled and not menuVisivel
		end
		if sala then sala.Enabled = false end
		interfacesDesligadas = true
		titulo.Text = "Turno " .. tostring(estado.turn)
		detalhe.Text = if estado.phase == "victory" then "Vitória · descanso automático"
			elseif estado.phase == "defeat" then "Derrota · descanso automático"
			elseif estado.phase == "fled" then avisoCombate or estado.fleeSummary or "Fugiu · sem recompensa"
			elseif avisoCombate then avisoCombate
			else string.format("Vez de %s · %s Ações", estado.currentActorName or "participante", tostring(estado.actionsRemaining or 0))
		if estado.phase == "fled" and estado.fleeResult then
			local fuga = estado.fleeResult
			detalhe.Text = string.format("Fugiu | d20 %d | total %d / CD %d", fuga.natural, fuga.total, fuga.cd)
		end
		-- Recolhe as Instances emprestadas à faixa antes de reconstruir a apresentação.
		passar.Parent, desistir.Parent = painel, painel
		for _, filho in faixa:GetChildren() do filho:Destroy() end
		for _, filho in opcoes:GetChildren() do filho:Destroy() end
		local atacante
		local alvos, alvosDistancia, paredes = {}, {}, {}
		local alcanceBloqueado = false
		for _, ator in estado.actors or {} do
			if ator.id == estado.controlledActorId then atacante = ator end
		end
		local temSoltarLivre = false
		for _, vinculo in pairs(estado.bindings or {}) do
			if vinculo.sourceId == estado.controlledActorId then temSoltarLivre = true; break end
		end
		if atacante then
			local armaGelo = atacante.states and atacante.states.armaGelo
			local duracao = type(armaGelo) == "table" and armaGelo.duracao or nil
			local rodadaDeExpiracao = type(duracao) == "table" and duracao.rodadaFim or nil
			if estado.phase == "active" and armaGelo and armaGelo.valor == true then
				local terminaApos = if type(rodadaDeExpiracao) == "number"
					then math.max(0, rodadaDeExpiracao - 1) else nil
				detalhe.Text = string.format("Lâmina ativa · %s · %s Ações",
					if terminaApos then "termina após rodada " .. tostring(terminaApos) else "duração ativa",
					tostring(estado.actionsRemaining or 0))
			elseif estado.phase == "active" and estado.isMyTurn then
				local reducao = if atacante.defenderReduction ~= nil
					then " · Defendendo −" .. tostring(atacante.defenderReduction) else ""
				local protecaoTemp = if (atacante.pvTemporarios or 0) > 0
					then " · PV temporários " .. tostring(atacante.pvTemporarios) else ""
				detalhe.Text = avisoCombate or string.format("Vez de %s · %s Ações · %s/%s PM%s", estado.currentActorName or "você",
					tostring(estado.actionsRemaining or 0), tostring(atacante.pm or 0), tostring(atacante.pmMax or 0),
					reducao .. protecaoTemp)
			end
		end
		if estado.phase == "active" and estado.isMyTurn
			and ((estado.actionsRemaining or 0) > 0 or temSoltarLivre)
			and atacante and (atacante.pv or 0) > 0 then
			for _, ator in estado.actors or {} do
				local distancia = if atacante.x and atacante.z and ator.x and ator.z
					then math.max(math.abs(atacante.x - ator.x), math.abs(atacante.z - ator.z)) else nil
				if ator.kind == "criatura" and ator.defeated ~= true and (ator.pv or 0) > 0 then
					local visaoLivre = Terreno.visaoLivre(atacante.x, atacante.z, ator.x, ator.z,
						estado.blockedCells, estado.dangers)
					if distancia and distancia <= 12 then
						if visaoLivre or muroNaLinha(atacante, ator, estado.dangers) then table.insert(alvosDistancia, ator)
						else alcanceBloqueado = true end
					end
					if distancia == 1 and visaoLivre then table.insert(alvos, ator) end
				end
			end
			local paredesPorId = {}
			for _, zona in ipairs(estado.dangers or {}) do
				if (zona.abilityId ~= MURO_DE_TERRA and zona.abilityId ~= ANTEPARO)
					or type(zona.wallId) ~= "string" or (zona.pv or 0) <= 0
				then continue end
				local distancia = math.max(math.abs(atacante.x - zona.x), math.abs(atacante.z - zona.z))
				if distancia <= 12 and Terreno.visaoLivre(atacante.x, atacante.z, zona.x, zona.z,
					estado.blockedCells, estado.dangers) then
					local anterior = paredesPorId[zona.wallId]
					if not anterior or distancia < anterior.distancia then
						paredesPorId[zona.wallId] = { id = string.format("parede:%s:%d:%d", zona.wallId, zona.x, zona.z),
							name = if zona.abilityId == ANTEPARO then "Anteparo Teórico" else "Muro de Terra",
							pv = zona.pv, pvMax = zona.pvMax or 40, distancia = distancia }
					end
				end
			end
			for _, parede in pairs(paredesPorId) do table.insert(paredes, parede) end
		end
		local alturaOpcoes = 0
		if estado.phase == "active" and estado.isMyTurn and (estado.actionsRemaining or 0) > 0 then
			local fugir = Instance.new("TextButton")
			fugir.Name, fugir.Position, fugir.Size = "Fugir", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 30)
			fugir.BackgroundColor3, fugir.TextColor3 = T.cores.painel, T.cores.texto
			fugir.FontFace, fugir.TextSize, fugir.Text = T.fontes.rotulo, 14, "Fugir pela borda | 1 Ação | Atletismo"
			fugir.Parent = opcoes
			fugir.Activated:Connect(function()
				fugir.Active = false
				if not state.fugir() then fugir.Active = true end
			end)
			alturaOpcoes = 34
		end
		if estado.phase == "active" and estado.isMyTurn then
			if #alvos == 0 and #alvosDistancia == 0 and #paredes == 0 then
				local vazio = Instance.new("TextLabel")
				vazio.Position = UDim2.fromOffset(0, alturaOpcoes)
				vazio.Name, vazio.Size, vazio.BackgroundTransparency = "SemAlvo", UDim2.new(1, 0, 0, 22), 1
				vazio.FontFace, vazio.TextSize = T.fontes.corpo, 14
				vazio.TextColor3, vazio.TextXAlignment = T.cores.secundario, Enum.TextXAlignment.Left
				vazio.Text = if (estado.actionsRemaining or 0) > 0
					then if alcanceBloqueado then "Rocha ou Muro bloqueia a visão do inimigo ao alcance."
					else "Nenhum inimigo ao alcance para ataque básico ou disparo."
					else "Sem Ações restantes."
				vazio.Parent = opcoes
				alturaOpcoes += 24
			end
			local function criarBotaoAtaque(alvo, indice, disparo)
				local botao = Instance.new("TextButton")
				botao.MouseEnter:Connect(function() apresentacao.selecionar(alvo.id) end)
				botao.SelectionGained:Connect(function() apresentacao.selecionar(alvo.id) end)
				local prefixo = if disparo then "Disparar_" else "Atacar_"
				botao.Name, botao.Position, botao.Size = prefixo .. tostring(indice),
					UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
				botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
				botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
				botao.TextTruncate, botao.AutoButtonColor = Enum.TextTruncate.AtEnd, true
				botao.Text = string.format("%s %s · %s/%s PV", if disparo then "Disparar" else "Atacar",
					alvo.name or "criatura", tostring(alvo.pv or 0), tostring(alvo.pvMax or "?"))
				botao.Parent = opcoes
				botao.Activated:Connect(function()
					botao.Active = false
					local aceito = if disparo then state.disparar(alvo.id) else state.atacar(alvo.id)
					if not aceito then botao.Active = true end
				end)
				alturaOpcoes += 34
			end
			if (estado.actionsRemaining or 0) > 0 then
				for indice, alvo in ipairs(alvos) do criarBotaoAtaque(alvo, indice, false) end
				for indice, alvo in ipairs(alvosDistancia) do criarBotaoAtaque(alvo, indice, true) end
				for indice, parede in ipairs(paredes) do
					if parede.distancia == 1 then criarBotaoAtaque(parede, indice, false) end
				end
				for indice, parede in ipairs(paredes) do
					if parede.distancia <= 12 then criarBotaoAtaque(parede, indice, true) end
				end
			end
			for alvoId, vinculo in pairs(estado.bindings or {}) do
				local function controle(id, rotulo, ativo)
					local botao = Instance.new("TextButton")
					botao.Name, botao.Position, botao.Size = "MaoDeTerra_" .. id,
						UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
					botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
					botao.FontFace, botao.TextSize, botao.Text = T.fontes.rotulo, 14, rotulo
					botao.Active = ativo
					botao.Parent = opcoes
					botao.Activated:Connect(function()
						botao.Active = false
						if not state.usarHabilidade(id, atacante.id) then botao.Active = true end
					end)
					alturaOpcoes += 34
				end
				if alvoId == atacante.id and (estado.actionsRemaining or 0) > 0 then
					controle(ESCAPAR_MAO, "Escapar de Mão de Terra · 1 Ação · Força", true)
				end
				if vinculo.sourceId == atacante.id then
					if (estado.actionsRemaining or 0) > 0 then
						controle(ARRASTAR_MAO, "Arrastar alvo até 3 m para perto · 1 Ação", true)
					end
					controle(SOLTAR_MAO, "Soltar Mão de Terra · livre", true)
				end
			end
			if (estado.actionsRemaining or 0) > 0 and atacante and (atacante.pv or 0) > 0 then
			local cura = ArvoresPrincipiante.MECANICAS[CURA]
			if table.find(estado.availableAbilities or {}, CURA) and cura
				and (estado.actionsRemaining or 0) >= cura.acoes and (atacante.pm or 0) >= cura.pm then
				for _, aliado in ipairs(estado.actors or {}) do
					local distancia = if atacante.x and atacante.z and aliado.x and aliado.z
						then math.max(math.abs(atacante.x - aliado.x), math.abs(atacante.z - aliado.z)) else math.huge
					if aliado.kind == "jogador" and (aliado.pv or 0) >= 0 and (aliado.pv or 0) < (aliado.pvMax or 0)
						and distancia <= 1 then
						local botao = Instance.new("TextButton")
						botao.Name, botao.Position, botao.Size = "Habilidade_Cura_" .. aliado.id,
							UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
						botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
						botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
						botao.TextTruncate, botao.AutoButtonColor = Enum.TextTruncate.AtEnd, true
						local nomeAlvo = if aliado.id == atacante.id then "você" else (aliado.name or "aliado")
						botao.Text = string.format("Cura · %d Ações/%d PM → %s · %d/%d PV",
							cura.acoes, cura.pm, nomeAlvo, aliado.pv, aliado.pvMax)
						botao.Parent = opcoes
						botao.Activated:Connect(function()
							botao.Active = false
							if not state.usarHabilidade(CURA, aliado.id) then botao.Active = true end
						end)
						alturaOpcoes += 34
					end
				end
			end
			local vigor = ArvoresPrincipiante.MECANICAS[VIGOR_EMPRESTADO]
			if table.find(estado.availableAbilities or {}, VIGOR_EMPRESTADO) and vigor
				and (estado.actionsRemaining or 0) >= vigor.acoes and (atacante.pm or 0) >= vigor.pm then
				for _, aliado in ipairs(estado.actors or {}) do
					local distancia = if atacante.x and atacante.z and aliado.x and aliado.z
						then math.max(math.abs(atacante.x - aliado.x), math.abs(atacante.z - aliado.z)) else math.huge
					if aliado.kind == "jogador" and (aliado.pv or 0) >= 0 and distancia <= 1 then
						local botao = Instance.new("TextButton")
						botao.Name, botao.Position, botao.Size = "Habilidade_VigorEmprestado_" .. aliado.id,
							UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
						botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
						botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
						botao.TextTruncate, botao.AutoButtonColor = Enum.TextTruncate.AtEnd, true
						local nomeAlvo = if aliado.id == atacante.id then "você" else (aliado.name or "aliado")
						local escudoAtual = (aliado.pvTemporarios or 0) > 0
							and string.format(" · atuais %d PV", aliado.pvTemporarios) or ""
						botao.Text = string.format("Vigor Emprestado · %d Ações/%d PM → %s · 2d8 + BC%s",
							vigor.acoes, vigor.pm, nomeAlvo, escudoAtual)
						botao.Parent = opcoes
						botao.Activated:Connect(function()
							botao.Active = false
							if not state.usarHabilidade(VIGOR_EMPRESTADO, aliado.id) then botao.Active = true end
						end)
						alturaOpcoes += 34
					end
				end
			end
			local pocaoMenor = "item/pocao_menor_cura"
			if table.find(estado.availableItems or {}, pocaoMenor) then
				for _, aliado in ipairs(estado.actors or {}) do
					local distancia = if atacante.x and atacante.z and aliado.x and aliado.z
						then math.max(math.abs(atacante.x - aliado.x), math.abs(atacante.z - aliado.z)) else math.huge
					if aliado.kind == "jogador" and (aliado.pv or 0) >= 0
						and (aliado.pv or 0) < (aliado.pvMax or 0) and distancia <= 1 then
						local botao = Instance.new("TextButton")
						botao.Name, botao.Position, botao.Size = "Item_PocaoMenor_" .. aliado.id,
							UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
						botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
						botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
						botao.TextTruncate, botao.AutoButtonColor = Enum.TextTruncate.AtEnd, true
						local nomeAlvo = if aliado.id == atacante.id then "você" else (aliado.name or "aliado")
						botao.Text = string.format("Poção Menor · 1 Ação → %s · %d/%d PV",
							nomeAlvo, aliado.pv, aliado.pvMax)
						botao.Parent = opcoes
						botao.Activated:Connect(function()
							botao.Active = false
							if not state.usarItem(pocaoMenor, aliado.id) then botao.Active = true end
						end)
						alturaOpcoes += 34
					end
				end
			end
				for _, abilityId in ipairs(estado.availableAbilities or {}) do
					if abilityId == "mesa/defender" then
						local botao = Instance.new("TextButton")
						botao.Name, botao.Position, botao.Size = "Habilidade_Defender",
							UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
						botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
						botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
						botao.Text = "Defender · 1 Ação · reduz dano até sua próxima vez"
						botao.Parent = opcoes
						botao.Activated:Connect(function()
							botao.Active = false
							if not state.usarHabilidade(abilityId, atacante.id) then botao.Active = true end
						end)
						alturaOpcoes += 34
					elseif abilityId == "ability/fogo/Principiante/fagulha" then
						local mecanica = Fogo.MECANICAS[abilityId]
						if mecanica and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_Fagulha",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Fagulha · %d Ação/%d PM · escolher casa até 6", mecanica.acoes, mecanica.pm)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Fagulha · escolha uma casa visível na grade"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == "ability/fogo/Principiante/muro-de-chamas" then
						local mecanica = Fogo.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_MuroDeChamas",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Muro de Chamas · %d Ações/%d PM · até 6 casas",
								mecanica.acoes, mecanica.pm)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Muro de Chamas · selecione a ponta e confirme no mapa"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == MURO_DE_TERRA then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_MuroDeTerra",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Muro de Terra · %d Ações/%d PM · 4 casas", mecanica.acoes, mecanica.pm)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Muro de Terra · escolha o centro da linha e confirme"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == ANTEPARO then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_AnteparoTeorico",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Anteparo Teórico · %d Ações/%d PM · 30 PV", mecanica.acoes, mecanica.pm)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Anteparo Teórico · escolha o centro em uma casa vizinha e confirme"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == ESCUDO_AGUA then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_EscudoDeAgua",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Escudo de Água · %d Ações/%d PM · +%d CA",
								mecanica.acoes, mecanica.pm, mecanica.cobertura)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Escudo de Água · escolha o centro e confirme no mapa"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == PASSO_DE_VENTO then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_PassoDeVento",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Passo de Vento · %d Ações/%d PM · até %d casas",
								mecanica.acoes, mecanica.pm, mecanica.alcanceCasas)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Passo de Vento · escolha um destino no mapa"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == SOPRO_DE_POEIRA then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_SoproDePoeira",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Sopro de Poeira · %d Ação/%d PM · cone de %d casas",
								mecanica.acoes, mecanica.pm, mecanica.comprimentoCasas)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Sopro de Poeira · escolha a direção do cone e confirme no mapa"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == NEVOA_DENSA then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_NevoaDensa",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Névoa Densa · %d Ações/%d PM · raio %d",
								mecanica.acoes, mecanica.pm, mecanica.raioCasas)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if not state.usarHabilidade(abilityId, atacante.id) then return end
								avisoCombate = "Névoa Densa · área de obscurecimento por 50 rodadas"
								atualizar(state.estado())
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == MAO_DE_TERRA then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						local sourceJaPrende = false
						for _, vinculo in pairs(estado.bindings or {}) do
							if vinculo.sourceId == atacante.id then sourceJaPrende = true; break end
						end
					if mecanica and not sourceJaPrende and atacante
						and (estado.actionsRemaining or 0) >= mecanica.acoes and (atacante.pm or 0) >= mecanica.pm then
							for _, alvo in ipairs(estado.actors or {}) do
								local distancia = math.max(math.abs(atacante.x - alvo.x), math.abs(atacante.z - alvo.z))
								if alvo.id == atacante.id or (alvo.kind ~= "jogador" and alvo.kind ~= "criatura")
									or (alvo.pv or 0) <= 0 or alvo.downed == true or (alvo.conditions or {}).agarrado == true
									or estado.bindings and estado.bindings[alvo.id] or distancia > mecanica.alcanceCasas
									or not Terreno.visaoLivre(atacante.x, atacante.z, alvo.x, alvo.z,
										estado.blockedCells, estado.dangers, estado.turn)
								then continue end
								local botao = Instance.new("TextButton")
								botao.Name, botao.Position, botao.Size = "Habilidade_MaoDeTerra_" .. alvo.id,
									UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
								botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
								botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
								botao.Text = string.format("Mão de Terra · %d Ações/%d PM → %s · CD Força",
									mecanica.acoes, mecanica.pm, alvo.name or "alvo")
								botao.Parent = opcoes
								botao.Activated:Connect(function()
									botao.Active = false
									if not state.usarHabilidade(abilityId, alvo.id) then botao.Active = true end
								end)
								alturaOpcoes += 34
							end
						end
					elseif abilityId == CLARAO then
						local mecanica = Fogo.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_Clarao",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
			botao.Text = string.format("Clarão · %d Ação/%d PM · círculo de %d casas",
								mecanica.acoes, mecanica.pm, mecanica.raioCasas)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								if state.iniciarMira(abilityId) then
									avisoCombate = "Clarão · escolha qualquer casa visível como centro"
									atualizar(state.estado())
								end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == HabilidadesAutonomas.LANCA_DE_PEDRA then
						local mecanica = HabilidadesAutonomas.mecanica(abilityId)
						if atacante and (estado.actionsRemaining or 0) >= mecanica.acoes and (atacante.pm or 0) >= mecanica.pm then
							local selecionados, botoes = {}, {}
							local confirmar = Instance.new("TextButton")
							confirmar.Name, confirmar.Position, confirmar.Size = "ConfirmarLancaDePedra", UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							confirmar.BackgroundColor3, confirmar.TextColor3 = T.cores.painel, T.cores.texto
							confirmar.FontFace, confirmar.TextSize, confirmar.Parent = T.fontes.rotulo, 14, opcoes
							alturaOpcoes += 34
							local function atualizarSelecao()
								confirmar.Text = string.format("Lança de Pedra · 2 Ações/2 PM · confirmar %d/3", #selecionados)
								confirmar.Active, confirmar.AutoButtonColor = #selecionados > 0, #selecionados > 0
								for id, entrada in botoes do
									entrada.botao.Text = (if table.find(selecionados, id) then "✓ " else "+ ") .. entrada.nome
								end
							end
							for _, alvo in ipairs(estado.actors or {}) do
								local distancia = math.max(math.abs(atacante.x - alvo.x), math.abs(atacante.z - alvo.z))
								if alvo.kind == "criatura" and alvo.defeated ~= true and (alvo.pv or 0) > 0
									and distancia <= mecanica.alcanceCasas and Terreno.visaoLivre(atacante.x, atacante.z, alvo.x, alvo.z, estado.blockedCells, estado.dangers) then
									local botao = Instance.new("TextButton")
									botao.Name, botao.Position, botao.Size = "LancaDePedra_" .. alvo.id, UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
									botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
									botao.FontFace, botao.TextSize, botao.Parent = T.fontes.rotulo, 14, opcoes
									botoes[alvo.id] = { botao = botao, nome = alvo.name or "criatura" }
									botao.Activated:Connect(function()
										local indice = table.find(selecionados, alvo.id)
										if indice then table.remove(selecionados, indice)
										elseif #selecionados < mecanica.maxAlvos then table.insert(selecionados, alvo.id) end
										atualizarSelecao()
									end)
									alturaOpcoes += 34
								end
							end
							confirmar.Activated:Connect(function()
								local lista = HabilidadesAutonomas.codificarLista(selecionados)
								if not lista then return end
								confirmar.Active = false
								if not state.usarHabilidade(abilityId, lista) then atualizarSelecao() end
							end)
							atualizarSelecao()
						end
					elseif abilityId == HabilidadesAutonomas.ATOLEIRO then
						local mecanica = HabilidadesAutonomas.mecanica(abilityId)
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_Atoleiro",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Atoleiro · %d Ações/%d PM · esfera de %d casas · 100 rodadas",
								mecanica.acoes, mecanica.pm, mecanica.raioCasas)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								botao.Active = false
								if not state.usarHabilidade(abilityId, HabilidadesAutonomas.ALVO_ATOLEIRO) then botao.Active = true end
							end)
							alturaOpcoes += 34
						end
					elseif abilityId == HabilidadesAutonomas.LAMINA_DE_GELO then
						local mecanica = ArvoresPrincipiante.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							local botao = Instance.new("TextButton")
							botao.Name, botao.Position, botao.Size = "Habilidade_LaminaDeGelo",
								UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
							botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
							botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
							botao.Text = string.format("Lâmina de Gelo · %d Ações/%d PM → você · 10 rodadas",
								mecanica.acoes, mecanica.pm)
							botao.Parent = opcoes
							botao.Activated:Connect(function()
								botao.Active = false
								if not state.usarHabilidade(abilityId, atacante.id) then botao.Active = true end
							end)
							alturaOpcoes += 34
						end
					else
						local mecanica = if abilityId == DARDO_ARCANO then ArvoresPrincipiante.MECANICAS[abilityId]
							elseif abilityId == HabilidadesAutonomas.LAMINA_GELO_FORCA
							or abilityId == HabilidadesAutonomas.LAMINA_GELO_INTELECTO
							then HabilidadesAutonomas.mecanica(abilityId)
							elseif abilityId == RAJADA_CURTA or abilityId == PEDRISCO or abilityId == BALA_DE_PEDRA
								or abilityId == LAMINA_DE_VENTO
							or abilityId == RESPINGO or abilityId == BOLA_DE_AGUA or abilityId == FLECHA_DE_AGUA
							or abilityId == IMPACTO_DE_GELO or abilityId == EMPURRAO
								or abilityId == VACUO_LOCALIZADO
							then ArvoresPrincipiante.MECANICAS[abilityId] else Fogo.MECANICAS[abilityId]
						if mecanica and atacante and (estado.actionsRemaining or 0) >= mecanica.acoes
							and (atacante.pm or 0) >= mecanica.pm then
							for _, alvo in ipairs(estado.actors or {}) do
								local distancia = if atacante and atacante.x and atacante.z and alvo.x and alvo.z
									then math.max(math.abs(atacante.x - alvo.x), math.abs(atacante.z - alvo.z)) else math.huge
								if alvo.kind == "criatura" and alvo.defeated ~= true and (alvo.pv or 0) > 0
									and (abilityId ~= VACUO_LOCALIZADO or alvo.respira == true)
					and distancia <= mecanica.alcanceCasas
					and Terreno.visaoLivre(atacante.x, atacante.z, alvo.x, alvo.z,
						estado.blockedCells, estado.dangers) then
								local botao = Instance.new("TextButton")
								botao.Name, botao.Position, botao.Size = "Habilidade_" .. abilityId .. "_" .. alvo.id,
									UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
								botao.BackgroundColor3, botao.TextColor3 = T.cores.painel, T.cores.texto
								botao.FontFace, botao.TextSize = T.fontes.rotulo, 14
								botao.TextTruncate, botao.AutoButtonColor = Enum.TextTruncate.AtEnd, true
								local nome = if abilityId == "ability/fogo/Principiante/brasa" then "Brasa"
									elseif abilityId == "ability/fogo/Principiante/bola-de-fogo" then "Bola de Fogo"
									elseif abilityId == RAJADA_CURTA then "Rajada Curta"
									elseif abilityId == PEDRISCO then "Pedrisco"
									elseif abilityId == BALA_DE_PEDRA then "Bala de Pedra"
									elseif abilityId == LAMINA_DE_VENTO then "Lâmina de Vento"
									elseif abilityId == RESPINGO then "Respingo"
									elseif abilityId == BOLA_DE_AGUA then "Bola d’Água"
									elseif abilityId == FLECHA_DE_AGUA then "Flecha d’Água"
									elseif abilityId == IMPACTO_DE_GELO then "Impacto de Gelo"
									elseif abilityId == EMPURRAO then "Empurrão"
									elseif abilityId == VACUO_LOCALIZADO then "Vácuo Localizado"
									elseif abilityId == DARDO_ARCANO then "Dardo Arcano"
									elseif abilityId == HabilidadesAutonomas.LAMINA_GELO_FORCA then "Lâmina de Gelo · Força"
									elseif abilityId == HabilidadesAutonomas.LAMINA_GELO_INTELECTO then "Lâmina de Gelo · Intelecto"
									else "Toque Escaldante"
								local emChamas = alvo.conditions and alvo.conditions["em-chamas"]
								local marcador = if emChamas then " (em chamas)" else ""
								botao.Text = string.format("%s · %s Ações/%s PM → %s%s · %s/%s PV", nome,
									tostring(mecanica.acoes), tostring(mecanica.pm), alvo.name or "criatura",
									marcador, tostring(alvo.pv or 0), tostring(alvo.pvMax or "?"))
								botao.Parent = opcoes
								botao.Activated:Connect(function()
									botao.Active = false
									if not state.usarHabilidade(abilityId, alvo.id) then botao.Active = true end
								end)
								alturaOpcoes += 34
					end
				end
						end
					end
				end
			end
			if (estado.actionsRemaining or 0) > 0 and atacante and (atacante.pv or 0) > 0 then
				local mover = Instance.new("TextButton")
				mover.Name, mover.Position, mover.Size = "Mover", UDim2.fromOffset(0, alturaOpcoes), UDim2.new(1, 0, 0, 30)
				mover.BackgroundColor3, mover.TextColor3 = T.cores.painel, T.cores.texto
				mover.FontFace, mover.TextSize, mover.Text = T.fontes.rotulo, 14, "Mover · escolher destino"
				mover.Parent = opcoes
				mover.Activated:Connect(function()
					gradeMovimento.abrir(state.estado())
				end)
				alturaOpcoes += 34
			end
		end
		local viewport = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
		local largura = math.min(980, viewport.X - 16)
		alturaOpcoes = Extra.acoes(opcoes, largura - 28)
		local compacto = viewport.X < 700 or viewport.Y < 500
		local alturaLista = math.min(alturaOpcoes, 184) -- duas fileiras de cartas (118 px + 8) visíveis no desktop
		opcoes.Size = UDim2.new(1, -28, 0, alturaLista)
		opcoes.CanvasSize = UDim2.new(0, 0, 0, alturaOpcoes)
		painel.AnchorPoint = Vector2.new(.5, 1)
		painel.Size = UDim2.fromOffset(largura, 164 + alturaLista)
		painel.Position = UDim2.new(.5, 0, 1, -8)
		local atalhoMapa = gui:FindFirstChild("AbrirMapaTatico")
		if atalhoMapa then atalhoMapa.Position = UDim2.new(0, 8, 1, -(164 + alturaLista) - 24); atalhoMapa.AnchorPoint = Vector2.new(0,1) end
		opcoes.CanvasPosition = Vector2.new(0, math.clamp(scrollAnterior, 0, math.max(0, alturaOpcoes - alturaLista)))
		passar.Position, passar.Size = UDim2.new(0, 14, 1, -54), UDim2.new(.52, -18, 0, 44)
		desistir.Position, desistir.Size = UDim2.new(.52, 4, 1, -54), UDim2.new(.48, -18, 0, 44)
		Extra.botao(passar, false, false)
		Extra.botao(desistir, false, true)
		apresentacao.atualizar(estado)
		gradeMovimento.atualizar(estado)
		mapaTatico.atualizar(estado)
		local finalizado = estado.phase == "victory" or estado.phase == "defeat" or estado.phase == "fled"
		passar.Visible = finalizado or (estado.phase == "active" and estado.isMyTurn == true)
		passar.Active = passar.Visible
		passar.Size = if finalizado then UDim2.new(1, -28, 0, 44) else UDim2.new(.52, -18, 0, 44)
		passar.Text = if finalizado then "Continuar" else "Encerrar turno"
		passar.TextTransparency = 0
		desistir.Visible = estado.phase == "active" and atacante ~= nil
			and type(atacante.pv) == "number" and atacante.pv > 0 and atacante.defeated ~= true
		desistir.Active = desistir.Visible
		desistir.Text = if desistirConfirmacaoVersao == estado.version then "Confirmar rendição" else "Render-se"
		faixa.Visible = compacto
		opcoes.Visible = true
		if compacto and estado.phase == "active" then
			faixa.Position, faixa.Size = UDim2.fromOffset(8, 68), UDim2.new(1, -16, 0, 64)
			detalhe.Position, detalhe.Size = UDim2.fromOffset(8, 34), UDim2.new(1, -16, 0, 38)
			local function dimensionar(grupo)
				grupoMobile = grupo
				local alturaSubmenu = if grupo then math.min(180, math.floor(viewport.Y * .3)) else 0
				opcoes.Position, opcoes.Size = UDim2.fromOffset(8, 140), UDim2.new(1, -16, 0, alturaSubmenu)
				painel.Size = UDim2.fromOffset(largura, if grupo then 148 + alturaSubmenu else 140)
				if atalhoMapa then atalhoMapa.AnchorPoint=Vector2.new(1,1); atalhoMapa.Position = UDim2.new(1, -8, 1, -painel.Size.Y.Offset - 16) end
			end
			Extra.faixa(opcoes, faixa, passar, desistir, largura - 16, grupoMobile, dimensionar)
		else
			detalhe.Position, detalhe.Size = UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 44)
			opcoes.Position = UDim2.fromOffset(14, 88)
		end
		if estado.phase == "victory" or estado.phase == "defeat" then painel.Visible = false end
	end

	-- Devolve o menu (botão MENU) ou a sala que o combate desligou. Idempotente: roda no botão Continuar do
	-- painel e também no retorno vindo do ResultadoView (17/10: sem isso o MENU sumia depois de todo combate do mundo).
	local function restaurarInterfaces()
		if not interfacesDesligadas then return end
		interfacesDesligadas = false
		local menu = menuInicial()
		local sala = salaConceitual()
		-- O menu (atalho MENU) volta nos dois casos: no lobby a SalaView o mantém ligado com o fundo escondido, e depois
		-- de um combate do mundo nenhum snapshot novo chega para religá-lo (o retorno não muda a mesa).
		if menu then menu.Enabled = true end
		if restaurarSala and sala then sala.Enabled = true end
		restaurarSala = nil
	end
	passar.Activated:Connect(function()
		local atual = state.estado()
		if atual and (atual.phase == "victory" or atual.phase == "defeat" or atual.phase == "fled") then
			gui.Enabled = false
			Players.LocalPlayer:SetAttribute("InterfaceCombate", false)
			apresentacao.atualizar(nil)
			restaurarInterfaces()
			state.avisarRetorno()
			return
		end
		passar.Active = false
		passar.Text = "Aguardando servidor…"
		if not state.encerrarTurno() then
			passar.Text = "Encerrar turno"
		end
	end)
	desistir.Activated:Connect(function()
		local atual = state.estado()
		if not atual or atual.phase ~= "active" then return end
		if desistirConfirmacaoVersao ~= atual.version then
			desistirConfirmacaoVersao = atual.version
			desistir.Text = "Confirmar rendição"
			local temAliadoVivo = false
			for _, ator in atual.actors or {} do
				if ator.kind == "jogador" and ator.id ~= atual.controlledActorId
					and type(ator.pv) == "number" and ator.pv > 0 and ator.defeated ~= true
				then
					temAliadoVivo = true
					break
				end
			end
			detalhe.Text = if temAliadoVivo
				then "Desistir leva seu personagem a 0 PV; a luta continua para o grupo."
				else "Você é o último jogador vivo; desistir encerra em derrota."
			return
		end
		desistir.Active = false
		desistir.Text = "Aguardando…"
		desistirConfirmacaoVersao = nil
		if not state.desistir() then
			desistir.Active = true
			desistir.Text = "Render-se"
		end
	end)
	state.onEstado(atualizar)
	state.onRecusado(function(mensagem)
		apresentacao.registrar(mensagem or "Pedido recusado")
		Extra.componentes.aviso({parent = gui, tipo = "perigo", titulo = "Ação recusada", detalhe = mensagem or "Pedido recusado"})
		passar.Active = true
		mapaTatico.atualizar(state.estado())
		task.delay(2, function()
			if not gui.Parent then return end
			passar.Text = "Encerrar turno"
			local atual = state.estado()
			passar.Active = atual ~= nil and atual.isMyTurn == true
		end)
	end)
	state.onRecibo(function(recibo)
		passar.Text = "Encerrar turno"
		if type(recibo) ~= "table" then return end
		local atual = state.estado()
		local resultado = if type(recibo.result) == "table" then recibo.result else {}
		if type(resultado.joinedActors) == "table" and #resultado.joinedActors > 0 then
			local nomes = {}
			for _, entrada in ipairs(resultado.joinedActors) do table.insert(nomes, entrada.name or "Participante") end
			avisoCombate = table.concat(nomes, ", ") .. " entrou · rodada " .. tostring(recibo.turn)
		elseif recibo.action == "flee-encounter" then
			avisoCombate = string.format("%s · d20 %d · total %d / CD %d", if resultado.fugiu then "Fugiu" else "Falhou · perdeu a vez",
				resultado.natural or 0, resultado.total or 0, resultado.cd or 0)
		elseif recibo.action == "abandon-encounter" then
			if resultado.encounterEnded == "defeat" then
				avisoCombate = "Último jogador desistiu · derrota"
			else
				local nome = "Um participante"
				for _, ator in atual and atual.actors or {} do
					if ator.id == recibo.actorId then nome = ator.name or nome; break end
				end
				avisoCombate = nome .. " desistiu · a luta continua"
			end
		elseif resultado.turnTimedOut == true then
			local nome = if type(resultado.turnTimedOutActorName) == "string" and resultado.turnTimedOutActorName ~= ""
				then resultado.turnTimedOutActorName else "Participante"
			if nome == "Participante" then
				for _, ator in atual and atual.actors or {} do
					if ator.id == recibo.actorId then nome = ator.name or nome; break end
				end
			end
			avisoCombate = string.format("Tempo esgotado · %s encerrou o turno", nome)
		elseif resultado.barrierPv ~= nil then
			local nomeBarreira = if resultado.barrierAbility == ANTEPARO then "Anteparo Teórico" else "Muro de Terra"
			avisoCombate = if resultado.barrierDestroyed == true
				then string.format("%s destruído · %d de dano", nomeBarreira, resultado.damageDealt or 0)
				else string.format("%s atingido · %d de dano · %d PV restantes",
					nomeBarreira, resultado.damageDealt or 0, resultado.barrierPv)
		elseif resultado.abilityId == "ability/fogo/Principiante/fagulha" and type(resultado.zone) == "table" then
			avisoCombate = string.format("Fagulha acendeu (%d, %d) · dura 2 rodadas", resultado.zone.x, resultado.zone.z)
		elseif resultado.abilityId == "ability/fogo/Principiante/muro-de-chamas" and type(resultado.zone) == "table" then
			avisoCombate = string.format("Muro de Chamas erguido · %d casas · dura 10 rodadas",
				#(resultado.zone.cells or {}))
		elseif resultado.abilityId == HabilidadesAutonomas.MURO_DE_TERRA and type(resultado.zone) == "table" then
			avisoCombate = string.format("Muro de Terra erguido · %d casas · %d PV · dura 100 rodadas",
				#(resultado.zone.cells or {}), resultado.zone.pv or 40)
		elseif resultado.abilityId == ANTEPARO and type(resultado.zone) == "table" then
			avisoCombate = string.format("Anteparo Teórico erguido · %d casas · %d PV · dura 10 rodadas",
				#(resultado.zone.cells or {}), resultado.zone.pv or 30)
		elseif resultado.abilityId == ESCUDO_AGUA and type(resultado.zone) == "table" then
			avisoCombate = string.format("Escudo de Água erguido · +%d CA · dura 2 rodadas",
				resultado.zone.coverage or 5)
		elseif resultado.abilityId == NEVOA_DENSA and type(resultado.zone) == "table" then
			avisoCombate = string.format("Névoa Densa · raio %d casas · obscurece a visão por 50 rodadas",
				resultado.radiusHouses or 4)
		elseif resultado.abilityId == MAO_DE_TERRA then
			local alvoNome = "O alvo"
			for _, ator in atual and atual.actors or {} do
				if ator.id == resultado.targetId then alvoNome = ator.name or alvoNome; break end
			end
			avisoCombate = if resultado.resistance and resultado.resistance.passou
				then alvoNome .. " resistiu à Mão de Terra"
				else string.format("%s preso por Mão de Terra · CD %s · escapar ou ser solto", alvoNome,
					tostring(resultado.bindingDc or (resultado.resistance and resultado.resistance.cd) or "Força"))
		elseif resultado.abilityId == ESCAPAR_MAO then
			avisoCombate = if resultado.escaped then "Você escapou da Mão de Terra"
				else string.format("Você continua preso · teste de Força contra CD %s",
					tostring(resultado.resistance and resultado.resistance.cd or "?"))
		elseif resultado.abilityId == SOLTAR_MAO then
			local nome = "O alvo"
			for _, ator in atual and atual.actors or {} do
				if ator.id == resultado.targetId then nome = ator.name or nome; break end
			end
			avisoCombate = nome .. " foi solto da Mão de Terra"
		elseif resultado.abilityId == ARRASTAR_MAO and type(resultado.to) == "table" then
			local nome = "O alvo"
			for _, ator in atual and atual.actors or {} do
				if ator.id == resultado.targetId then nome = ator.name or nome; break end
			end
			avisoCombate = string.format("%s arrastado · (%d, %d)", nome, resultado.to.x, resultado.to.z)
		elseif resultado.abilityId == HabilidadesAutonomas.LANCA_DE_PEDRA then
			local feridos, resistiram, dano = 0, 0, 0
			for _, alvo in ipairs(resultado.targets or {}) do
				if alvo.resistance and alvo.resistance.passou then resistiram += 1 else feridos += 1 end
				dano += alvo.damageDealt or 0
			end
			avisoCombate = string.format("Lança de Pedra · %d atingidos · %d resistiram · %d dano total", feridos, resistiram, dano)
		elseif resultado.abilityId == HabilidadesAutonomas.ATOLEIRO then
			local atolados, resistiram = 0, 0
			for _, alvo in ipairs(resultado.targets or {}) do
				if table.find(alvo.applies or {}, "atolado") then atolados += 1 else resistiram += 1 end
			end
			avisoCombate = string.format("Atoleiro · %d Atolados · %d resistiram · terreno difícil por 100 rodadas", atolados, resistiram)
		elseif resultado.abilityId == "ability/fogo/Principiante/clarao" then
			local nomes = {}
			for _, ator in atual and atual.actors or {} do nomes[ator.id] = ator.name end
			local cegos, resistiram, semEfeito = {}, 0, 0
			for _, alvo in resultado.targets or {} do
				if table.find(alvo.applies or {}, "cego") then
					table.insert(cegos, nomes[alvo.actorId] or "alvo")
				elseif alvo.resistance and alvo.resistance.passou then
					resistiram += 1
				else
					semEfeito += 1
				end
			end
			avisoCombate = if #cegos > 0
				then "Clarão · Cegos: " .. table.concat(cegos, ", ")
				else string.format("Clarão: ninguém ficou Cego · %d resistiram · %d sem efeito", resistiram, semEfeito)
		elseif resultado.turnStartDamage then
			local danoInicio = resultado.turnStartDamage
			local nomes = {}
			for _, ator in atual and atual.actors or {} do nomes[ator.id] = ator.name end
			avisoCombate = string.format("%s sofre %s dano de Em Chamas no início da vez",
				nomes[danoInicio.actorId] or "O alvo", tostring(danoInicio.damage and danoInicio.damage.total or 0))
			if (danoInicio.damage and danoInicio.damage.pvTemporariosAbsorvidos or 0) > 0 then
				avisoCombate ..= string.format(" · %d absorvidos pelos PV temporários",
					danoInicio.damage.pvTemporariosAbsorvidos)
			end
		elseif resultado.defenderReduction ~= nil then
			avisoCombate = string.format("Você se prepara para Defender · redução de %d até sua próxima vez",
				resultado.defenderReduction)
		elseif resultado.abilityId == VIGOR_EMPRESTADO then
			local nomeAlvo = "o aliado"
			for _, ator in atual and atual.actors or {} do
				if ator.id == resultado.targetId then nomeAlvo = ator.id == recibo.actorId and "você" or ator.name or nomeAlvo end
			end
			avisoCombate = string.format("Vigor Emprestado para %s · %d PV temporários%s", nomeAlvo,
				resultado.pvTemporariosAtual or 0,
				resultado.pvTemporariosAtualizado and " por 100 rodadas" or " · proteção maior mantida")
			if resultado.targetDowned then avisoCombate ..= " · permanece Caído" end
			if resultado.freshWound then avisoCombate ..= " · Ferida Fresca dobrou os dados" end
		elseif resultado.healing ~= nil then
			local nomes = {}
			for _, ator in atual and atual.actors or {} do nomes[ator.id] = ator.name end
			local atorId, alvoId = recibo.actorId, resultado.targetId or recibo.targetId
			local atorNome, alvoNome = nomes[atorId] or "Aliado", nomes[alvoId] or "o grupo"
			local notaFerida = if table.find(resultado.notes or {}, "Ferida Fresca: o dobro dos dados")
				then " · Ferida Fresca dobrou os dados" else ""
			if atorId == alvoId then
				avisoCombate = if resultado.itemName
					then string.format("%s usou %s e recuperou %d PV", atorNome, resultado.itemName, resultado.healing)
					else string.format("%s recuperou %d PV%s", atorNome, resultado.healing, notaFerida)
			else
				avisoCombate = string.format("%s%s curou %s · %d PV%s%s", atorNome,
					resultado.itemName and (" usou " .. resultado.itemName .. " e") or "", alvoNome, resultado.healing,
					resultado.targetDowned and " · ainda caído" or "", notaFerida)
			end
		elseif recibo.action == "move" and type(resultado.toX) == "number" and type(resultado.toZ) == "number" then
			avisoCombate = string.format("Movimento confirmado · %d casas · (%d, %d)",
				type(resultado.casas) == "number" and resultado.casas or 0, resultado.toX, resultado.toZ)
			if #(resultado.hazardsTriggered or {}) > 0 then
				local dano = 0
				for _, zona in resultado.hazardsTriggered do dano += zona.damage and zona.damage.total or 0 end
				avisoCombate ..= string.format(" · zona de fogo causou %d dano", dano)
			end
		elseif recibo.action == "creature-move"
			and type(resultado.to) == "table" and type(resultado.to.x) == "number" and type(resultado.to.z) == "number"
		then
			local nomes = {}
			for _, ator in atual and atual.actors or {} do nomes[ator.id] = ator.name end
			local criatura = nomes[resultado.actorId or recibo.actorId] or "A criatura"
			avisoCombate = string.format("%s avançou · (%d, %d)", criatura, resultado.to.x, resultado.to.z)
			if #(resultado.hazardsTriggered or {}) > 0 then
				local dano = 0
				for _, zona in resultado.hazardsTriggered do dano += zona.damage and zona.damage.total or 0 end
				avisoCombate ..= string.format(" · zona de fogo causou %d dano", dano)
			end
		elseif recibo.action == "basic-attack" or recibo.action == "ranged-attack" or recibo.action == "creature-attack"
			or (type(recibo.action) == "string" and string.sub(recibo.action, 1, 8) == "ability:")
		then
			local nomes = {}
			for _, ator in atual and atual.actors or {} do nomes[ator.id] = ator.name end
			local atacante = nomes[recibo.actorId] or "Atacante"
			local alvo = nomes[resultado.targetId or recibo.targetId] or "alvo"
			local acertou = type(resultado.attack) == "table" and resultado.attack.acertou == true
			local acao = if recibo.action == "ranged-attack" then "Disparo"
				elseif resultado.abilityId == "mesa/defender" then "Defender"
				elseif resultado.abilityId == "ability/fogo/Principiante/bola-de-fogo" then "Bola de Fogo"
				elseif resultado.abilityId == "ability/fogo/Principiante/toque-escaldante" then "Toque Escaldante"
				elseif resultado.abilityId == RAJADA_CURTA then "Rajada Curta"
				elseif resultado.abilityId == PEDRISCO then "Pedrisco"
				elseif resultado.abilityId == BALA_DE_PEDRA then "Bala de Pedra"
				elseif resultado.abilityId == LAMINA_DE_VENTO then "Lâmina de Vento"
				elseif resultado.abilityId == RESPINGO then "Respingo"
				elseif resultado.abilityId == BOLA_DE_AGUA then "Bola d’Água"
				elseif resultado.abilityId == FLECHA_DE_AGUA then "Flecha d’Água"
				elseif resultado.abilityId == IMPACTO_DE_GELO then "Impacto de Gelo"
				elseif resultado.abilityId == EMPURRAO then "Empurrão"
				elseif string.sub(recibo.action, 1, 8) == "ability:" then "Brasa" else atacante
			if type(resultado.resistance) == "table" then
				local passou = resultado.resistance.passou == true
				if resultado.abilityId == EMPURRAO then
					avisoCombate = string.format("%s: %s %s resistência", acao, alvo,
						if passou then "passou na" else "falhou na")
					if type(resultado.push) == "table" and resultado.push.houses > 0 then
						avisoCombate ..= string.format(" · empurrado %s casa(s)", tostring(resultado.push.houses))
					elseif type(resultado.push) == "table" then
						avisoCombate ..= " · empurrão bloqueado"
					end
				else
					avisoCombate = string.format("%s: %s %s resistência · %s dano", acao, alvo,
						if passou then "passou na" else "falhou na", tostring(resultado.damageDealt or 0))
					if resultado.abilityId == IMPACTO_DE_GELO and not passou then avisoCombate ..= " · movimento -2 casas" end
				end
			else
				avisoCombate = if acertou
					then string.format("%s acertou %s · %s dano", acao, alvo, tostring(resultado.damageDealt or 0))
					else string.format("%s errou o ataque contra %s", atacante, alvo)
			end
			if resultado.coverageBonus then
				avisoCombate ..= string.format(" · Escudo de Água +%d CA", resultado.coverageBonus)
			end
			if resultado.targetDefeated then avisoCombate ..= " · derrotado" end
			if resultado.targetDowned then avisoCombate ..= " · caído" end
			if type(resultado.push) == "table" and resultado.push.houses > 0 then
				avisoCombate ..= string.format(" · empurrou %s casa(s)", tostring(resultado.push.houses))
			end
		else
			return
		end
		for _, expirado in ipairs(resultado.expiredTemporaryHp or {}) do
			local nome = expirado.actorName or "Participante"
			avisoCombate = (avisoCombate and avisoCombate .. " · " or "") .. nome .. " perdeu PV temporários expirados"
		end
		if (resultado.pvTemporariosAbsorvidos or 0) > 0 then
			avisoCombate ..= string.format(" · %d absorvidos por PV temporários", resultado.pvTemporariosAbsorvidos)
		end
		apresentacao.registrar(avisoCombate, recibo)
		sequenciaAviso += 1
		local estaSequencia = sequenciaAviso
		if atual then atualizar(atual) end
		task.delay(4, function()
			if not gui.Parent or sequenciaAviso ~= estaSequencia then return end
			avisoCombate = nil
			atualizar(state.estado())
		end)
	end)
	local cameraAtual = workspace.CurrentCamera
	local conexaoViewport = if cameraAtual
		then cameraAtual:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if gui.Parent then atualizar(state.estado()) end
		end)
		else nil
	local conexaoPrazo = game:GetService("RunService").Heartbeat:Connect(function()
		if gui.Parent and painel.Visible then atualizarContador() end
	end)
	state.onRetorno(function()
		restaurarInterfaces()
		gui.Enabled = true; painel.Visible = false
		apresentacao.atualizar(nil)
		gradeMovimento.atualizar(nil); mapaTatico.atualizar(nil)
		Players.LocalPlayer:SetAttribute("InterfaceCombate", false)
	end)
	gui.Destroying:Connect(function()
			Players.LocalPlayer:SetAttribute("InterfaceCombate", false)
			apresentacao.destruir()
			conexaoPrazo:Disconnect()
			if conexaoViewport then conexaoViewport:Disconnect() end
		end)
	return gui
end

return View
