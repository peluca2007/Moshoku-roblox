-- Área de Testes: sala longe do mapa onde administradores, só no Studio, veem modelos, animações e
-- arenas do jogo. Não toca em ficha, run nem recompensa. Cliente: client/AreaDeTestesView.
-- Remoto "AreaDeTestes": cliente -> servidor (acao, dados); servidor -> cliente { tipo = ... }.
-- Atributos no Player: PodeAreaDeTestes (admin no Studio) e NaAreaDeTestes (está na sala).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local Dados = require(Shared.AreaDeTestesDados)
local ModelosCriaturas = require(Shared.Mundo.ModelosCriaturas)
local Protocol = require(Shared.MesaProtocol)
local MontarModelo = require(script.Parent.Mundo.MontarModelo)
local CriaturaAnimada = require(script.Parent.Mundo.CriaturaAnimada)
local Props = require(script.Parent.Mundo.Props)

local AreaDeTestes = {}

local O = Dados.ORIGEM
local TOPO_PISO = Dados.TOPO_PISO -- mesma altura do tabuleiro: a Coreografia desenha no chão da mesa
local PONTO, ENTRADA, BONECO = Dados.CENTRO, Dados.ENTRADA, Dados.BONECO
local MAX_ALTURA = 30 -- props maiores são encolhidos para caber na vista

local function parte(nome, tamanho, cf, cor, material, pai)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = nome, tamanho, cf, cor, material
	p.Anchored, p.CanCollide, p.CanTouch = true, true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = pai
	return p
end

-- Sala: piso, pedestal, luz neutra, placa e boneco-alvo (para os gestos).
local function construirSala()
	local sala = Instance.new("Folder")
	sala.Name = "AreaDeTestes"
	local piso = parte("Piso", Vector3.new(200, 2, 200), CFrame.new(O.x, TOPO_PISO - 1, O.z), Color3.fromRGB(170, 170, 170), Enum.Material.SmoothPlastic, sala)
	piso.CanQuery = true
	local pedestal = parte("Pedestal", Vector3.new(1.2, 12, 12), CFrame.new(O.x, TOPO_PISO + 0.6, O.z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 110, 120), Enum.Material.Concrete, sala)
	pedestal.Shape = Enum.PartType.Cylinder
	local luz = parte("Luz", Vector3.new(1, 1, 1), CFrame.new(O.x, 40, O.z + 10), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, sala)
	luz.Transparency, luz.CanCollide = 1, false
	local ponto = Instance.new("PointLight")
	ponto.Brightness, ponto.Range, ponto.Color = 2, 90, Color3.new(1, 1, 1)
	ponto.Parent = luz
	local placa = parte("Placa", Vector3.new(14, 3, 0.4), CFrame.new(O.x, TOPO_PISO + 6, O.z - 12), Color3.fromRGB(40, 40, 46), Enum.Material.SmoothPlastic, sala)
	placa.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	gui.Parent = placa
	local texto = Instance.new("TextLabel")
	texto.Name, texto.Size, texto.BackgroundTransparency = "Texto", UDim2.fromScale(1, 1), 1
	texto.TextColor3, texto.Font, texto.TextScaled, texto.Text = Color3.new(1, 1, 1), Enum.Font.GothamMedium, true, "Área de Testes"
	texto.Parent = gui
	-- Boneco-alvo simples (sem Humanoid): só recebe os efeitos dos gestos.
	local boneco = Instance.new("Model")
	boneco.Name = "Boneco"
	local cor = Color3.fromRGB(205, 160, 110)
	local tronco = parte("Tronco", Vector3.new(2, 2, 1), CFrame.new(BONECO + Vector3.new(0, 3, 0)), cor, Enum.Material.SmoothPlastic, boneco)
	parte("Cabeca", Vector3.new(1.4, 1.4, 1.4), CFrame.new(BONECO + Vector3.new(0, 4.7, 0)), cor, Enum.Material.SmoothPlastic, boneco)
	parte("BracoE", Vector3.new(1, 2, 1), CFrame.new(BONECO + Vector3.new(-1.5, 3, 0)), cor, Enum.Material.SmoothPlastic, boneco)
	parte("BracoD", Vector3.new(1, 2, 1), CFrame.new(BONECO + Vector3.new(1.5, 3, 0)), cor, Enum.Material.SmoothPlastic, boneco)
	parte("PernaE", Vector3.new(1, 2, 1), CFrame.new(BONECO + Vector3.new(-0.5, 1, 0)), cor, Enum.Material.SmoothPlastic, boneco)
	parte("PernaD", Vector3.new(1, 2, 1), CFrame.new(BONECO + Vector3.new(0.5, 1, 0)), cor, Enum.Material.SmoothPlastic, boneco)
	boneco.PrimaryPart = tronco
	boneco.Parent = sala
	local vitrine = Instance.new("Folder")
	vitrine.Name = "Vitrine" -- o que está sobre o pedestal
	vitrine.Parent = sala
	sala.Parent = workspace
	return sala, pedestal, texto, vitrine
end

-- Nomes dos módulos de Mundo/Modelos que não são criaturas (props, casas, árvores, cosméticos).
local function listarProps()
	local usados = {}
	for _, entrada in ModelosCriaturas.POR_CRIATURA do
		for _, m in entrada.modulos do usados[m] = true end
	end
	local lista = {}
	for _, m in script.Parent.Mundo.Modelos:GetChildren() do
		if m:IsA("ModuleScript") and not usados[m.Name] then table.insert(lista, m.Name) end
	end
	table.sort(lista)
	return lista
end

-- deps: isAdmin(player), emLuta(player?) -> boolean, arenaCenario (Mundo/ArenaCenario), agora?
function AreaDeTestes.start(deps)
	if not RunService:IsStudio() then return nil end
	local agora = deps.agora or os.clock
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = "AreaDeTestes", ReplicatedStorage
	local sala, pedestal, placaTexto, vitrine = construirSala()
	local props = listarProps()
	local extra = { props = props }
	local sessoes, ultimo = {}, {}
	local girar, yaw, geracao = true, 0, 0
	local atual = nil -- { criatura?, modelo?, animacao, golpeEm?, off? }

	local function pode(player): boolean
		local ok = deps.isAdmin(player) == true
		if player:GetAttribute("PodeAreaDeTestes") ~= ok then player:SetAttribute("PodeAreaDeTestes", ok) end
		return ok
	end
	local function avisar(player, tipo, mais)
		local m = mais or {}
		m.tipo = tipo
		remote:FireClient(player, m)
	end
	local function raiz(player)
		local c = player.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end

	-- Limpa o que está sobre o pedestal.
	local function limpar()
		geracao += 1
		if atual and atual.criatura then atual.criatura:destruir() end
		vitrine:ClearAllChildren()
		atual = nil
		placaTexto.Text = "Área de Testes"
	end

	local function restaurarArena(sessao)
		if sessao.arenaAntes ~= nil then
			local antes = sessao.arenaAntes.id
			sessao.arenaAntes = nil
			pcall(deps.arenaCenario.aplicar, antes)
		end
	end

	local function irPara(player, onde: Vector3, olhar: Vector3)
		local r = raiz(player)
		if r then player.Character:PivotTo(CFrame.lookAt(onde, Vector3.new(olhar.X, onde.Y, olhar.Z))) end
	end

	local function sair(player)
		local sessao = sessoes[player]
		if not sessao then return end
		sessoes[player] = nil
		restaurarArena(sessao)
		local r = raiz(player)
		if r then player.Character:PivotTo(sessao.origem) end
		player:SetAttribute("NaAreaDeTestes", false)
		if next(sessoes) == nil then limpar() end
		avisar(player, "estado", { dentro = false })
	end

	local function estaNaSala(player) return sessoes[player] ~= nil end

	local function mostrarCriatura(d)
		local info = ModelosCriaturas.escolher(d.id, d.variante)
		if not info then return nil, "criatura sem modelo" end
		local minha = geracao
		local criatura = CriaturaAnimada.montar(info, vitrine, CFrame.new(PONTO), info.escalaMundo)
		if not criatura then return nil, "modelo indisponível" end
		if minha ~= geracao then criatura:destruir(); return nil, "substituído" end
		atual = { criatura = criatura, animacao = d.animacao, golpeEm = 0 }
		local tam = criatura:tamanho()
		sala:SetAttribute("Altura", tam.Y)
		sala:SetAttribute("Raio", math.max(tam.X, tam.Z))
		placaTexto.Text = string.format("%s · %s · %s", string.gsub(d.id, "^creature/", ""), info.modulo, d.animacao)
		return true
	end

	local function mostrarProp(d)
		if not MontarModelo.existe(d.id) then return nil, "modelo indisponível" end
		local minha = geracao
		local ok, modelo = pcall(MontarModelo.montar, d.id, vitrine, CFrame.new(PONTO), 1)
		if not ok or not modelo then return nil, "falha ao montar" end
		if minha ~= geracao then modelo:Destroy(); return nil, "substituído" end
		pcall(Props.aplicarMateriaisELuzes, modelo, d.id)
		for _, p in modelo:GetDescendants() do
			if p:IsA("BasePart") then p.CanQuery, p.CanCollide = false, false end
		end
		-- Casas e árvores grandes: encolhe para a câmera pegar tudo.
		local _, tam = modelo:GetBoundingBox()
		local maior = math.max(tam.X, tam.Y, tam.Z)
		if maior > MAX_ALTURA then pcall(modelo.ScaleTo, modelo, modelo:GetScale() * MAX_ALTURA / maior) end
		local caixa, t2 = modelo:GetBoundingBox()
		local off = modelo:GetPivot():ToObjectSpace(caixa).Position
		atual = { modelo = modelo, animacao = "parado", off = off, meia = t2.Y / 2 }
		sala:SetAttribute("Altura", t2.Y)
		sala:SetAttribute("Raio", math.max(t2.X, t2.Z))
		placaTexto.Text = d.id
		return true
	end

	local function tratar(player, acao, dados)
		if type(acao) ~= "string" then return end
		local autorizado = pode(player)
		if not autorizado then return end
		local t = agora()
		if ultimo[player] and t - ultimo[player] < Dados.INTERVALO then return end
		ultimo[player] = t
		local ok, d = Dados.validarPedido(acao, dados, extra)
		if not ok then avisar(player, "erro", { texto = d }); return end
		if acao == "catalogo" then
			avisar(player, "catalogo", { props = props, dentro = estaNaSala(player), girar = girar })
		elseif acao == "entrar" then
			if estaNaSala(player) then return end
			if deps.emLuta(player) then avisar(player, "erro", { texto = "Há uma luta em andamento." }); return end
			local r = raiz(player)
			if not r then avisar(player, "erro", { texto = "Sem personagem." }); return end
			sessoes[player] = { origem = r.CFrame }
			player:SetAttribute("NaAreaDeTestes", true)
			irPara(player, ENTRADA, PONTO)
			avisar(player, "estado", { dentro = true })
		elseif acao == "sair" then
			sair(player)
		elseif not estaNaSala(player) then
			avisar(player, "erro", { texto = "Entre na sala primeiro." })
		elseif acao == "girar" then
			girar = d.ligado
		elseif acao == "mostrar" then
			if deps.emLuta(player) then avisar(player, "erro", { texto = "Há uma luta em andamento." }); return end
			restaurarArena(sessoes[player])
			irPara(player, ENTRADA, PONTO)
			-- Se o mesmo item já está montado, só troca a animação.
			if atual and atual.criatura and d.categoria == "criaturas" and atual.id == d.id and atual.variante == d.variante then
				atual.animacao = d.animacao
				atual.criatura.quedaDesde = nil
				placaTexto.Text = string.format("%s · %s · %s", string.gsub(d.id, "^creature/", ""), atual.criatura.info.modulo, d.animacao)
				avisar(player, "mostrado", { categoria = d.categoria, id = d.id, altura = sala:GetAttribute("Altura"), raio = sala:GetAttribute("Raio") })
				return
			end
			limpar()
			local feito, erro
			if d.categoria == "criaturas" then feito, erro = mostrarCriatura(d) else feito, erro = mostrarProp(d) end
			if not feito then avisar(player, "erro", { texto = erro or "falha" }); return end
			if atual then atual.id, atual.variante = d.id, d.variante end
			avisar(player, "mostrado", { categoria = d.categoria, id = d.id, altura = sala:GetAttribute("Altura"), raio = sala:GetAttribute("Raio") })
		elseif acao == "arena" then
			if deps.emLuta(player) then avisar(player, "erro", { texto = "Há uma luta em andamento." }); return end
			local sessao = sessoes[player]
			if sessao.arenaAntes == nil then sessao.arenaAntes = { id = deps.arenaCenario.atual() } end
			local aplicado = pcall(deps.arenaCenario.aplicar, d.id)
			if not aplicado or deps.arenaCenario.atual() ~= d.id then
				avisar(player, "erro", { texto = "Arena indisponível (a mesa não está montada?)." })
				return
			end
			local o = Protocol.BOARD.origin
			irPara(player, o + Vector3.new(0, 8, -75), o)
			avisar(player, "arena", { id = d.id, centro = o })
		end
	end

	remote.OnServerEvent:Connect(function(player, acao, dados)
		local ok, erro = pcall(tratar, player, acao, dados)
		if not ok then warn("[AreaDeTestes]", erro) end
	end)

	-- Pedestal e criatura: giro lento e animação por código.
	RunService.Heartbeat:Connect(function(dt)
		if girar then yaw = (yaw + dt * 0.6) % (math.pi * 2) end
		if not atual then return end
		local t = agora()
		local base = CFrame.new(PONTO) * CFrame.Angles(0, yaw, 0)
		pedestal.CFrame = CFrame.new(O.x, TOPO_PISO + 0.6, O.z) * CFrame.Angles(0, yaw, math.pi / 2)
		if atual.criatura then
			local c = atual.criatura
			if atual.animacao == "ataque" and t - atual.golpeEm > 1.8 then
				atual.golpeEm = t
				c:golpear(t)
			elseif atual.animacao == "queda" then
				if not c:caiu() then c:cair(t)
				elseif t - c.quedaDesde > 2.5 then c.quedaDesde = nil end
			end
			c:atualizar(dt, base, atual.animacao == "andando", 4, nil, t)
		elseif atual.modelo and atual.modelo.Parent then
			local o = atual.off
			atual.modelo:PivotTo(base * CFrame.new(-o.X, atual.meia - o.Y, -o.Z))
		end
	end)

	local function ligar(player)
		task.delay(0.5, function() if player.Parent then pode(player) end end)
		task.delay(3, function() if player.Parent then pode(player) end end)
		-- Renascer (ex.: queda) tira o avatar da sala: encerra a sessão sem teleporte.
		player.CharacterAdded:Connect(function()
			local sessao = sessoes[player]
			if sessao then
				sessoes[player] = nil
				restaurarArena(sessao)
				player:SetAttribute("NaAreaDeTestes", false)
				if next(sessoes) == nil then limpar() end
				avisar(player, "estado", { dentro = false })
			end
		end)
	end
	Players.PlayerAdded:Connect(ligar)
	for _, p in Players:GetPlayers() do ligar(p) end
	Players.PlayerRemoving:Connect(function(player)
		local sessao = sessoes[player]
		sessoes[player], ultimo[player] = nil, nil
		if sessao then restaurarArena(sessao) end
		if next(sessoes) == nil then limpar() end
	end)

	return { sala = sala, estaNaSala = estaNaSala }
end

return AreaDeTestes
