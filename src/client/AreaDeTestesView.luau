-- Área de Testes (cliente): painel F6 / botão TESTES, só para quem o servidor marcou com o atributo
-- PodeAreaDeTestes (administrador no Studio). Só apresenta e pede; o servidor monta a sala
-- (server/AreaDeTestes). Sons, vozes, gestos e interface rodam localmente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage.Shared
local Dados = require(Shared.AreaDeTestesDados)
local Protocol = require(Shared.MesaProtocol)
local Execucao = require(Shared.Regras.Execucao)
local C = require(script.Parent.UI.Componentes)
local T = require(script.Parent.UI.Tema)

local View = {}
local LARGURA = 390

-- Gestos: técnicas do livro que a Coreografia sabe animar (Gestos.especificar não devolve nil).
local function listarGestos()
	local Gestos = require(script.Parent.Gestos)
	local lista = {}
	for id, mec in Execucao.MECANICAS do
		local arv = string.match(id, "^%a+/([^/]+)/")
		if Gestos.especificar(id, mec, arv) then table.insert(lista, id) end
	end
	return lista
end

function View.start()
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("AreaDeTestes", 15)
	if not remote then return end -- fora do Studio o servidor não cria a sala

	local extra = { props = {}, gestos = nil }
	local dentro, aberto, aba, girando = false, false, "criaturas", true
	local camera = { yaw = 0.6, elev = 0.35, zoom = 1, modo = "pedestal", altura = 6, raio = 6, arena = nil }
	local somAtual, fx, fake, ouvinte

	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "AreaDeTestes", false, 70, false
	gui.ZIndexBehavior, gui.Parent = Enum.ZIndexBehavior.Sibling, player:WaitForChild("PlayerGui")
	local raiz = Instance.new("Frame")
	raiz.Name, raiz.BackgroundTransparency = "Tela", 1
	raiz.Parent = gui
	local escala = C.aplicarEscala(raiz)
	local function ajustarTela() raiz.Size = UDim2.fromScale(1 / escala.Scale, 1 / escala.Scale) end
	escala:GetPropertyChangedSignal("Scale"):Connect(ajustarTela)
	ajustarTela()

	-- Botão discreto no canto inferior esquerdo.
	local entrada = C.botao({ parent = raiz, nome = "BotaoTestes", texto = "TESTES", variante = "fantasma", sobreEscuro = true,
		tamanho = UDim2.fromOffset(110, 40), posicao = UDim2.new(0, 12, 1, -52), aoClicar = function() View.alternar() end })

	local painel = C.painel({ parent = raiz, nome = "Painel", tamanho = UDim2.new(0, LARGURA, 1, -24),
		posicao = UDim2.new(1, -12, 0, 12), ancora = Vector2.new(1, 0) })
	painel.Visible = false
	local conteudo = painel.Conteudo

	local titulo = C.titulo({ parent = conteudo, texto = "Área de Testes", tamanho = UDim2.new(1, -170, 0, 34) })
	local botaoSala
	local status = C.texto({ parent = conteudo, texto = "", secundario = true, posicao = UDim2.fromOffset(0, 40), tamanho = UDim2.new(1, 0, 0, 22) })
	local abas = Instance.new("ScrollingFrame")
	abas.Name, abas.BackgroundTransparency, abas.BorderSizePixel = "Abas", 1, 0
	abas.Position, abas.Size = UDim2.fromOffset(0, 66), UDim2.new(1, 0, 0, 50)
	abas.ScrollBarThickness, abas.ScrollingDirection = 4, Enum.ScrollingDirection.X
	abas.AutomaticCanvasSize, abas.CanvasSize = Enum.AutomaticSize.X, UDim2.new()
	abas.Parent = conteudo
	local lista = Instance.new("ScrollingFrame")
	lista.Name, lista.BackgroundTransparency, lista.BorderSizePixel = "Lista", 1, 0
	lista.Position, lista.Size = UDim2.fromOffset(0, 124), UDim2.new(1, 0, 1, -124 - 150)
	lista.ScrollBarThickness, lista.ClipsDescendants = 6, true
	lista.AutomaticCanvasSize, lista.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
	lista.Parent = conteudo
	local rodape = Instance.new("Frame")
	rodape.Name, rodape.BackgroundTransparency = "Rodape", 1
	rodape.AnchorPoint, rodape.Position, rodape.Size = Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 144)
	rodape.Parent = conteudo
	local vitrine = Instance.new("Frame") -- peças da aba Interface (à esquerda do painel)
	vitrine.Name, vitrine.BackgroundTransparency = "VitrineInterface", 1
	vitrine.Position, vitrine.Size = UDim2.fromOffset(16, 16), UDim2.new(1, -LARGURA - 48, 1, -80)
	vitrine.Parent = raiz

	local function limparFilhos(pai)
		for _, f in pai:GetChildren() do
			if not f:IsA("UIListLayout") and not f:IsA("UIGridLayout") then f:Destroy() end
		end
	end
	local function aviso(texto, tipo) C.aviso({ parent = gui, titulo = "Testes", detalhe = texto, tipo = tipo or "info", duracao = 2.5 }) end
	local function pedir(acao, d) remote:FireServer(acao, d) end

	-- Sons e vozes: tocam localmente pelo id; um por vez.
	local function parar()
		if somAtual then somAtual:Destroy(); somAtual = nil end
	end
	local function tocar(assetId, volume)
		parar()
		local som = Instance.new("Sound")
		som.Name, som.SoundId, som.Volume, som.Parent = "TesteSom", assetId, volume, SoundService
		som.Ended:Connect(function() if somAtual == som then somAtual = nil end som:Destroy() end)
		somAtual = som
		som:Play()
	end

	-- Gestos: Magias com um estado de demonstração (avatar -> boneco), sem combate real.
	local function prepararGestos()
		if fx then return true end
		local ok, erro = pcall(function()
			local sala = workspace:WaitForChild("AreaDeTestes", 5)
			local boneco = sala and sala:FindFirstChild("Boneco")
			assert(boneco, "boneco-alvo ausente")
			local fichas = { eu = { ownerUserId = player.UserId, avatar = true }, alvo = { ownerUserId = 0 } }
			fake = {
				posicaoCasa = function(x, z) return Dados.BONECO + Vector3.new((x - 1) * 5, 0, (z - 1) * 5) end,
				tamanhoCasa = Protocol.BOARD.cell,
				findToken = function(id) return fichas[id] end,
				posicaoDe = function(id)
					if id == "eu" then
						local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						return (if r then r.Position else Dados.ENTRADA) + Vector3.new(0, 1, 0)
					end
					return boneco:GetPivot().Position
				end,
				modeloDe = function(id) if id == "eu" then return player.Character, true end return boneco, false end,
				onSnapshot = function() end,
				onEfeito = function(cb) ouvinte = cb end,
			}
			fx = require(script.Parent.Magias).start(fake, { nomePasta = "AreaDeTestesFX" })
		end)
		if not ok then warn("[AreaDeTestes] gestos:", erro); fx = nil end
		return ok and ouvinte ~= nil
	end
	local function tocarGesto(id)
		if not dentro then aviso("Entre na sala primeiro.", "alerta"); return end
		if not prepararGestos() then aviso("Gestos indisponíveis (veja o Output).", "perigo"); return end
		camera.modo = "gestos"
		local mec = Execucao.MECANICAS[id] or {}
		local sobreSi = mec.tipo == "cura" or mec.alvo == "si"
		local alvo = { id = if sobreSi then "eu" else "alvo", acertou = true, dano = if mec.tipo == "cura" then 0 else 6, cura = if mec.tipo == "cura" then 6 else 0 }
		local ok, erro = pcall(ouvinte, { habilidadeId = id, casterId = "eu", alvos = { alvo }, casas = { { 1, 1 }, { 2, 1 }, { 1, 2 } } })
		if not ok then warn("[AreaDeTestes] gesto", id, erro) end
	end

	-- Interface: peças do kit, como em tools/playtest/ui_vitrine.luau.
	local function mostrarInterface(id)
		limparFilhos(vitrine)
		local col = C.lista({ parent = vitrine, espaco = 12, tamanho = UDim2.fromOffset(420, 0) })
		if id == "painel" then
			local p = C.painel({ parent = col, tamanho = UDim2.fromOffset(420, 150), losangos = true })
			C.titulo({ parent = p.Conteudo, texto = "Moshoku", ornamento = true })
			C.texto({ parent = p.Conteudo, texto = "Pergaminho: título, subtítulo e corpo.", posicao = UDim2.fromOffset(0, 54) })
		elseif id == "botoes" then
			for i, v in { "principal", "secundario", "perigo", "fantasma" } do
				C.botao({ parent = col, ordem = i, texto = v, variante = v, aoClicar = function() aviso("Botão " .. v) end })
			end
			C.botao({ parent = col, ordem = 5, texto = "Indisponível", variante = "secundario", desabilitado = true })
		elseif id == "barra" then
			local _, atualizar = C.barra({ parent = col, rotulo = "Tempo", valor = 1, numero = "100%", destaque = T.cores.alerta })
			task.spawn(function()
				for i = 20, 0, -1 do
					if not col.Parent then return end
					atualizar(i / 20, i * 5 .. "%")
					task.wait(0.5)
				end
			end)
		elseif id == "aviso" then
			for _, tipo in { "info", "sucesso", "perigo", "alerta" } do
				C.aviso({ parent = gui, tipo = tipo, titulo = string.upper(tipo), detalhe = "Banner no alto", duracao = 2 })
			end
		elseif id == "dialogo" then
			C.dialogoNpc({ parent = col, ancora = Vector2.zero, posicao = UDim2.new(), tamanho = UDim2.new(1, 0, 0, 0), nomeNpc = "Hanzo",
				fala = "Todo caminho começa com um primeiro treino.", opcoes = {
					{ texto = "Quero treinar", aoClicar = function() aviso("Opção 1") end },
					{ texto = "Até logo", aoClicar = function() aviso("Opção 2") end },
				} })
		end
	end

	-- Rodapé por aba: animações da criatura, câmera, parar som.
	local function botaoRodape(txt, ordem, x, y, w, clique)
		C.botao({ parent = rodape, texto = txt, variante = "secundario", tamanho = UDim2.fromOffset(w, 40),
			posicao = UDim2.fromOffset(x, y), aoClicar = clique })
	end
	local selecionado = { criaturas = nil, props = nil }
	local function reconstruirRodape()
		limparFilhos(rodape)
		local y = 0
		if aba == "criaturas" or aba == "props" then
			if aba == "criaturas" then
				for i, a in Dados.ANIMACOES do
					botaoRodape(a, i, ((i - 1) % 2) * 92, math.floor((i - 1) / 2) * 44, 88, function()
						local s = selecionado.criaturas
						if s then pedir("mostrar", { categoria = "criaturas", id = s.id, variante = s.variante, animacao = a }) end
					end)
				end
				botaoRodape("Modelo", 5, 0, 88, 180, function()
					local s = selecionado.criaturas
					if s and s.variantes > 1 then
						s.variante = (s.variante + 1) % s.variantes
						pedir("mostrar", { categoria = "criaturas", id = s.id, variante = s.variante })
					end
				end)
			end
			botaoRodape("◀", 6, 196, 0, 56, function() camera.yaw -= 0.4 end)
			botaoRodape("▶", 7, 256, 0, 56, function() camera.yaw += 0.4 end)
			botaoRodape("+", 8, 196, 44, 56, function() camera.zoom = math.max(0.4, camera.zoom * 0.8) end)
			botaoRodape("−", 9, 256, 44, 56, function() camera.zoom = math.min(3, camera.zoom * 1.25) end)
			botaoRodape("Girar", 10, 196, 88, 116, function() girando = not girando; pedir("girar", { ligado = girando }) end)
		elseif aba == "sons" or aba == "vozes" then
			botaoRodape("Parar", 1, 0, 0, 180, parar)
		elseif aba == "gestos" then
			botaoRodape("Limpar", 1, 0, 0, 120, function() if fx then fx.limpar() end end)
			C.texto({ parent = rodape, texto = "Avatar → boneco. Receitas de Fogo e Teórica usam a Magias.", secundario = true, posicao = UDim2.fromOffset(0, 48), tamanho = UDim2.new(1, 0, 0, 60) })
		elseif aba == "arenas" then
			C.texto({ parent = rodape, texto = "Leva o avatar para olhar a arena; ao sair da sala ela é desvestida.", secundario = true, tamanho = UDim2.new(1, 0, 0, 60) })
		end
	end

	local function rotuloDe(it) return it.nome end
	local reconstruirLista
	local function escolher(it)
		if aba == "criaturas" then
			selecionado.criaturas = { id = it.id, variante = 0, variantes = it.variantes or 1 }
			camera.modo, camera.arena = "pedestal", nil
			pedir("mostrar", { categoria = "criaturas", id = it.id, variante = 0 })
		elseif aba == "props" then
			camera.modo, camera.arena = "pedestal", nil
			pedir("mostrar", { categoria = "props", id = it.id })
		elseif aba == "arenas" then
			pedir("arena", { id = it.id })
		elseif aba == "sons" then
			tocar(it.assetId, 0.7)
		elseif aba == "vozes" then
			tocar(it.assetId, 0.8)
			status.Text = string.format("%s (%.1fs)", it.nome, it.segundos or 0)
		elseif aba == "gestos" then
			tocarGesto(it.id)
		elseif aba == "interface" then
			mostrarInterface(it.id)
		end
	end
	function reconstruirLista()
		limparFilhos(lista)
		if not lista:FindFirstChildOfClass("UIListLayout") then
			Instance.new("UIListLayout", lista).Padding = UDim.new(0, 4)
		end
		if aba == "gestos" and not extra.gestos then extra.gestos = listarGestos() end
		for i, it in Dados.itens(aba, extra) do
			C.botao({ parent = lista, ordem = i, texto = rotuloDe(it), variante = "secundario",
				tamanho = UDim2.new(1, -10, 0, 40), aoClicar = function() escolher(it) end })
		end
		limparFilhos(vitrine)
		reconstruirRodape()
	end
	local function reconstruirAbas()
		limparFilhos(abas)
		if not abas:FindFirstChildOfClass("UIListLayout") then
			local l = Instance.new("UIListLayout")
			l.FillDirection, l.Padding, l.Parent = Enum.FillDirection.Horizontal, UDim.new(0, 4), abas
		end
		for i, c in Dados.CATEGORIAS do
			C.botao({ parent = abas, ordem = i, texto = (if c.id == aba then "● " else "") .. c.nome,
				variante = if c.id == aba then "principal" else "secundario", tamanho = UDim2.fromOffset(120, 44),
				aoClicar = function()
					aba = c.id
					if aba == "gestos" then camera.modo = "gestos" elseif aba ~= "arenas" then camera.modo = "pedestal" end
					reconstruirAbas(); reconstruirLista()
				end })
		end
	end

	local function atualizarSala()
		if botaoSala then botaoSala:Destroy() end
		botaoSala = C.botao({ parent = conteudo, texto = if dentro then "Sair" else "Entrar", variante = if dentro then "perigo" else "principal",
			tamanho = UDim2.fromOffset(150, 40), ancora = Vector2.new(1, 0), posicao = UDim2.new(1, 0, 0, 0),
			aoClicar = function() pedir(if dentro then "sair" else "entrar") end })
		status.Text = if dentro then "Na sala de testes." else "Fora da sala. Entre para ver os itens."
	end

	-- Câmera orbital simples olhando o pedestal (ou o par avatar/boneco, ou a mesa).
	RunService:BindToRenderStep("AreaDeTestesCamera", Enum.RenderPriority.Camera.Value + 2, function()
		local cam = workspace.CurrentCamera
		if not dentro or not cam then return end
		local alvo, dist
		if camera.modo == "arena" and camera.arena then
			alvo, dist = camera.arena + Vector3.new(0, 2, 0), 95 * camera.zoom
		elseif camera.modo == "gestos" then
			alvo, dist = (Dados.ENTRADA + Dados.BONECO) / 2 + Vector3.new(0, 1, 0), 30 * camera.zoom
		else
			alvo = Dados.CENTRO + Vector3.new(0, camera.altura / 2, 0)
			dist = math.max(14, camera.raio * 2 + camera.altura) * camera.zoom
		end
		cam.CameraType = Enum.CameraType.Scriptable
		local dir = CFrame.Angles(0, camera.yaw, 0) * CFrame.Angles(-camera.elev, 0, 0)
		cam.CFrame = CFrame.lookAt(alvo + dir:VectorToWorldSpace(Vector3.new(0, 0, dist)), alvo)
	end)
	UserInputService.InputChanged:Connect(function(input, processado)
		if not dentro or processado then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			camera.zoom = math.clamp(camera.zoom * (1 - input.Position.Z * 0.1), 0.4, 3)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			camera.yaw -= input.Delta.X * 0.01
			camera.elev = math.clamp(camera.elev + input.Delta.Y * 0.005, -0.2, 1.3)
		end
	end)

	local function permitido() return player:GetAttribute("PodeAreaDeTestes") == true end
	function View.alternar()
		if not permitido() then return end
		aberto = not aberto
		painel.Visible = aberto
		if aberto then reconstruirAbas(); reconstruirLista(); atualizarSala() end
	end
	local function aoPermissao()
		gui.Enabled = permitido()
		if not permitido() then aberto, painel.Visible = false, false end
	end
	player:GetAttributeChangedSignal("PodeAreaDeTestes"):Connect(aoPermissao)
	aoPermissao()
	UserInputService.InputBegan:Connect(function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.F6 then View.alternar() end
	end)

	remote.OnClientEvent:Connect(function(m)
		if type(m) ~= "table" then return end
		if m.tipo == "catalogo" then
			extra.props = m.props or {}
			if type(m.girar) == "boolean" then girando = m.girar end
			if aberto then reconstruirLista() end
		elseif m.tipo == "estado" then
			dentro = m.dentro == true
			if not dentro then
				local cam = workspace.CurrentCamera
				if cam then cam.CameraType = Enum.CameraType.Custom end
				parar(); limparFilhos(vitrine)
				if fx then fx.limpar() end
				camera.modo, camera.arena = "pedestal", nil
			end
			atualizarSala()
		elseif m.tipo == "mostrado" then
			camera.altura, camera.raio = m.altura or 6, m.raio or 6
			camera.modo, camera.arena = "pedestal", nil
		elseif m.tipo == "arena" then
			camera.modo, camera.arena, camera.zoom = "arena", m.centro, 1
			status.Text = "Arena: " .. tostring(m.id)
		elseif m.tipo == "erro" then
			aviso(tostring(m.texto), "alerta")
		end
	end)
	-- O servidor marca a permissão logo após a entrada; pedimos o catálogo (e a marca) algumas vezes.
	task.spawn(function()
		for _ = 1, 4 do
			pedir("catalogo")
			task.wait(2)
			if permitido() then break end
		end
	end)
	return View
end

return View
