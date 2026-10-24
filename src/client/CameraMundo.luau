-- Câmera do MUNDO (região, vila, floresta, ruínas) estilo Project Zomboid: Scriptable alta
-- em diagonal (pitch 52°, yaw 45/135/225/315°), segue o personagem com suavização,
-- zoom 22-70 (roda, pinça, analógico), giro de 90° em Q/E, botões na tela do celular e
-- L1/R1 no controle; prédios e árvores entre a câmera e o personagem ficam translúcidos.
-- A matemática pura mora em shared/CameraMundoCalculo (com spec). Só apresentação local.
--
-- QUEM LIGA: ModoCamera decide pelo lugar do personagem (fora da sala = `ligar`,
-- dentro = `desligar`). A 1ª pessoa da sala não é daqui.
--
-- CONTRATO DE PAUSA (outro sistema assume a câmera): `CameraMundo.pausar(motivo)` e
-- `retomar(motivo)` (ou `pausa(motivo, ligado)` por frame). Motivos são um conjunto por
-- nome (idempotente: pausar duas vezes e retomar uma retoma). Enquanto houver algum motivo
-- esta câmera NÃO escreve em CameraType/CFrame e devolve a opacidade da oclusão; quem
-- pausou é dono da câmera. Ao retomar, assume Scriptable de novo e desliza da pose atual.
-- Os motivos ativos aparecem no atributo `CameraMundoPausada` do LocalPlayer (leitura/diagnóstico).
-- Rede de segurança: se alguém trocar o CameraType por conta própria enquanto controlamos,
-- cedemos 1,5 s ("externo") e avisamos no Output, em vez de brigar a cada frame.
-- Motivos em uso: "sobreposicao-sala", "transicao-sala" (SalaView).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Calculo = require(ReplicatedStorage.Shared.CameraMundoCalculo)
local Componentes = require(script.Parent.UI.Componentes)

local CameraMundo = {}

-- Ajustes de sensação (a geometria padrão está em CameraMundoCalculo).
local ALTURA_FOCO = 1.5 -- mira no peito, acima da raiz
local TAU_XZ, TAU_Y, TAU_ZOOM = 0.10, 0.30, 0.08
local TAU_TERRENO_SOBE, TAU_TERRENO_DESCE = 0.05, 0.35 -- terreno encosta rápido, solta devagar
local MARGEM_TERRENO, APROXIMACAO_MIN = 2.5, 8
local DURACAO_ENTRADA = 0.45 -- desliza da câmera anterior ao assumir
local COOLDOWN_EXTERNO = 1.5
local PRIORIDADE = Enum.RenderPriority.Camera.Value + 5 -- depois do SalaView (+3)

-- Oclusão.
local INTERVALO_OCLUSAO = 0.1
local TRANSPARENCIA_OCLUIDO = 0.7
local FADE_ENTRADA, FADE_SAIDA = 0.2, 0.3
local SEGURA_OCLUIDO = 0.35 -- evita piscar na borda do raio
local RAIO_LARGURA, RAIO_ALTURA = 2.2, 2.5
local MAX_CORTES_POR_RAIO = 6
local LIMITE_GRUPO = 50 -- maior Model que vira um bloco só (casa, árvore)
local MAX_PARTES_GRUPO = 300
local TAMANHO_MIN_OCLUSOR = 1.5

-- Botões de giro no celular (≥ 44 px), à esquerda acima do joystick; os atalhos RUN/CONTA/
-- VIAGEM/? ficam no canto direito (y 14-212) e o pulo no canto inferior direito.
local LADO_BOTAO = 48
local MARGEM_BOTAO = 12

local estado = {
	iniciado = false,
	ligada = false,
	controlando = false,
	motivos = {} :: { [string]: boolean },
	externoAte = 0,
	avisouExterno = false,
	passoAcumulado = 0,
	yaw = Calculo.yawDoPasso(0),
	yawDe = Calculo.yawDoPasso(0),
	yawPara = Calculo.yawDoPasso(0),
	giroT = 1,
	zoomAlvo = Calculo.ZOOM_PADRAO,
	zoom = Calculo.ZOOM_PADRAO,
	obstrucao = 0,
	foco = nil :: Vector3?,
	desde = nil :: CFrame?,
	entradaT = 1,
	rotacaoAnterior = nil :: Enum.RotationType?,
	pinca = nil :: number?,
	proximaOclusao = 0,
}
local promptsProximos = {} -- cache incremental, inclui prompts fora da vista
local Efeitos: any = nil
local gui: ScreenGui? = nil
local paramsTerreno: RaycastParams? = nil

-- ---------------------------------------------------------------- pausa

local function publicarPausa()
	local jogador = Players.LocalPlayer
	if not jogador then
		return
	end
	local lista = {}
	for motivo in estado.motivos do
		table.insert(lista, motivo)
	end
	table.sort(lista)
	local texto = if #lista > 0 then table.concat(lista, ",") else nil
	if jogador:GetAttribute("CameraMundoPausada") ~= texto then
		jogador:SetAttribute("CameraMundoPausada", texto)
	end
end

function CameraMundo.pausar(motivo: string)
	if not estado.motivos[motivo] then
		estado.motivos[motivo] = true
		publicarPausa()
	end
end

function CameraMundo.retomar(motivo: string)
	if estado.motivos[motivo] then
		estado.motivos[motivo] = nil
		publicarPausa()
	end
end

-- Atalho para chamar todo frame: pausa(motivo, condição).
function CameraMundo.pausa(motivo: string, ligado: boolean)
	if ligado then
		CameraMundo.pausar(motivo)
	else
		CameraMundo.retomar(motivo)
	end
end

function CameraMundo.pausada(): boolean
	return next(estado.motivos) ~= nil
end

-- Modo mundo ligado (mesmo pausado): ninguém deve forçar CameraType/mouse por conta própria.
function CameraMundo.ligada(): boolean
	return estado.ligada
end

-- Ligada e sem pausa: esta câmera é a dona agora.
function CameraMundo.ativa(): boolean
	return estado.ligada and next(estado.motivos) == nil
end

-- ---------------------------------------------------------------- oclusão

type Entrada = {
	partes: { BasePart },
	originais: { number },
	alpha: number,
	alvo: number,
	visto: number,
	aplicado: number,
}

local ativos: { [Instance]: Entrada } = {}
local tamanhos: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

local function tamanhoDe(modelo: Model): number
	local guardado = tamanhos[modelo]
	if guardado then
		return guardado
	end
	local tam = modelo:GetExtentsSize()
	local maior = math.max(tam.X, tam.Y, tam.Z)
	tamanhos[modelo] = maior
	return maior
end

-- O bloco que some junto: o maior Model ancestral que ainda cabe em LIMITE_GRUPO
-- (casa, árvore); sem Model pequeno, só a própria peça.
local function grupoDe(parte: BasePart): Instance
	-- Folhagem some separada do tronco e das construções que a contêm.
	if Calculo.folhagem(parte.Name) then return parte end
	local melhor: Instance = parte
	local atual = parte.Parent
	while atual and atual ~= workspace and atual:IsA("Model") do
		if atual:FindFirstChildOfClass("Humanoid") or tamanhoDe(atual) > LIMITE_GRUPO then
			break
		end
		melhor = atual
		atual = atual.Parent
	end
	return melhor
end

local function ignoravel(parte: BasePart): boolean
	if parte.Transparency >= 0.9 or parte.Size.Magnitude < TAMANHO_MIN_OCLUSOR then
		return true
	end
	local modelo = parte:FindFirstAncestorOfClass("Model")
	return modelo ~= nil and modelo:FindFirstChildOfClass("Humanoid") ~= nil -- NPC/jogador não some
end

local function criarEntrada(grupo: Instance): Entrada
	local partes, originais = {}, {}
	local function adicionar(p: Instance)
		-- Copas possuem entrada independente: dois fades nunca escrevem na mesma peça.
		if p ~= grupo and Calculo.folhagem(p.Name) then return end
		if p:IsA("BasePart") and p.Transparency < 1 and #partes < MAX_PARTES_GRUPO then
			table.insert(partes, p)
			table.insert(originais, p.LocalTransparencyModifier)
		end
	end
	adicionar(grupo)
	if not grupo:IsA("BasePart") then
		for _, d in grupo:GetDescendants() do
			adicionar(d)
		end
	end
	return { partes = partes, originais = originais, alpha = 0, alvo = 1, visto = os.clock(), aplicado = 0 }
end

local function aplicarEntrada(e: Entrada)
	for i, parte in e.partes do
		if parte.Parent then
			local base = e.originais[i]
			parte.LocalTransparencyModifier = base + (TRANSPARENCIA_OCLUIDO - base) * e.alpha
		end
	end
	e.aplicado = e.alpha
end

local function limparOclusao()
	for _, e in ativos do
		e.alpha = 0
		aplicarEntrada(e)
	end
	table.clear(ativos)
end

local function excluidosDaOclusao(): { Instance }
	local lista: { Instance } = { workspace.Terrain }
	for _, jogador in Players:GetPlayers() do
		if jogador.Character then
			table.insert(lista, jogador.Character)
		end
	end
	for _, nome in { "MesaEfeitosLocais", "SalaObjetosLocais" } do
		local pasta = workspace:FindFirstChild(nome)
		if pasta then
			table.insert(lista, pasta)
		end
	end
	return lista
end

-- Raios da câmera até o personagem (centro, lados, cima e baixo). Cada corte vira
-- translúcido; Terrain e personagens ficam de fora (o terreno aproxima a câmera).
local function checarOclusao(origem: Vector3, foco: CFrame, agora: number)
	local visto: { [Instance]: boolean } = {}
	local excluidos = excluidosDaOclusao()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local direita, cima = foco.RightVector, foco.UpVector
	local pontos = {
		foco.Position,
		foco.Position + direita * RAIO_LARGURA,
		foco.Position - direita * RAIO_LARGURA,
		foco.Position + cima * RAIO_ALTURA,
		foco.Position - cima * RAIO_ALTURA,
	}
	for _, ponto in pontos do
		local lista = table.clone(excluidos)
		for _ = 1, MAX_CORTES_POR_RAIO do
			params.FilterDescendantsInstances = lista
			local r = workspace:Raycast(origem, ponto - origem, params)
			if not r then
				break
			end
			table.insert(lista, r.Instance)
			if r.Instance:IsA("BasePart") and not ignoravel(r.Instance) then
				visto[grupoDe(r.Instance)] = true
			end
		end
	end
	-- Consulta local, limitada a 10 Hz: inclui copas sobre o avatar mesmo quando os
	-- cinco raios oblíquos passam entre as malhas. Não percorre a floresta inteira.
	local sobreposicao = OverlapParams.new()
	sobreposicao.FilterType = Enum.RaycastFilterType.Exclude
	sobreposicao.FilterDescendantsInstances = excluidos
	local altura, raio = Calculo.ALTURA_COPAS, Calculo.RAIO_COPAS
	for _, parte in workspace:GetPartBoundsInBox(CFrame.new(foco.Position + Vector3.new(0, altura/2, 0)), Vector3.new(raio*2, altura, raio*2), sobreposicao) do
		if Calculo.folhagem(parte.Name) and not ignoravel(parte) then
			local cf, h = parte.CFrame, parte.Size/2
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local mx = math.abs(r.X)*h.X + math.abs(u.X)*h.Y + math.abs(l.X)*h.Z
			local my = math.abs(r.Y)*h.X + math.abs(u.Y)*h.Y + math.abs(l.Y)*h.Z
			local mz = math.abs(r.Z)*h.X + math.abs(u.Z)*h.Y + math.abs(l.Z)*h.Z
			local d = parte.Position - foco.Position
			if Calculo.copaSobreAvatar(d.X, d.Y, d.Z, mx, my, mz) then visto[parte] = true end
		end
	end
	for grupo in visto do
		local e = ativos[grupo]
		if not e then
			e = criarEntrada(grupo)
			ativos[grupo] = e
		end
		e.alvo, e.visto = 1, agora
	end
	for grupo, e in ativos do
		if not visto[grupo] and agora - e.visto > SEGURA_OCLUIDO then
			e.alvo = 0
		end
	end
end

local function animarOclusao(dt: number)
	for grupo, e in ativos do
		e.alpha = Calculo.passoFade(e.alpha, e.alvo, dt, if e.alvo > e.alpha then FADE_ENTRADA else FADE_SAIDA)
		if e.alpha ~= e.aplicado then
			aplicarEntrada(e)
		end
		if e.alpha == 0 and e.alvo == 0 then
			ativos[grupo] = nil
		end
	end
end

-- ---------------------------------------------------------------- câmera

local function raizDoJogador(): BasePart?
	local jogador = Players.LocalPlayer
	local personagem = jogador and jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	return if raiz and raiz:IsA("BasePart") then raiz else nil
end

-- E pertence à interação mesmo quando o prompt está fora do enquadramento.
local function temPromptProximo(): boolean
 local raiz = raizDoJogador()
 if not raiz then return false end
 for prompt in promptsProximos do
  if prompt.Parent and prompt.Enabled then
   local pai = prompt.Parent
   local pos = if pai:IsA("Attachment") then pai.WorldPosition elseif pai:IsA("BasePart") then pai.Position elseif pai:IsA("Model") then pai:GetPivot().Position else nil
   if pos and Calculo.promptReservaE(true, (pos-raiz.Position).Magnitude, prompt.MaxActivationDistance) then return true end
  end
 end
 return false
end

local function configuracoesDoJogo(): any
	local ok, resultado = pcall(function()
		return UserSettings():GetService("UserGameSettings")
	end)
	return if ok then resultado else nil
end

local function assumir(camera: Camera, raiz: BasePart)
	estado.controlando = true
	camera.CameraType = Enum.CameraType.Scriptable
	-- O movimento é relativo à tela: o personagem vira para onde anda e o mouse fica livre.
	local config = configuracoesDoJogo()
	if config and config.RotationType == Enum.RotationType.CameraRelative then
		estado.rotacaoAnterior = config.RotationType
		config.RotationType = Enum.RotationType.MovementRelative
	end
	estado.foco = raiz.Position + Vector3.new(0, ALTURA_FOCO, 0)
	estado.obstrucao = 0
	estado.desde = camera.CFrame
	estado.entradaT = 0
end

-- `devolver`: entrega a câmera ao padrão (Custom) em vez de só largar (pausa).
local function soltar(devolver: boolean)
	local camera = workspace.CurrentCamera
	if estado.controlando then
		estado.controlando = false
		limparOclusao()
		if estado.rotacaoAnterior then
			local config = configuracoesDoJogo()
			if config then
				config.RotationType = estado.rotacaoAnterior
			end
			estado.rotacaoAnterior = nil
		end
		if devolver and camera and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
			local jogador = Players.LocalPlayer
			local humanoide = jogador and jogador.Character and jogador.Character:FindFirstChildOfClass("Humanoid")
			if humanoide then
				camera.CameraSubject = humanoide
			end
		end
	end
end

-- Distância do foco até o terreno no caminho da câmera (nil = livre).
local function distanciaAteTerreno(foco: Vector3, destino: Vector3): number?
	if not paramsTerreno then
		paramsTerreno = RaycastParams.new()
		paramsTerreno.FilterType = Enum.RaycastFilterType.Include
		paramsTerreno.FilterDescendantsInstances = { workspace.Terrain }
		paramsTerreno.IgnoreWater = true
	end
	local r = workspace:Raycast(foco, destino - foco, paramsTerreno)
	return if r then r.Distance else nil
end

local function eixoZoomDoControle(): number
	local tipo = UserInputService:GetLastInputType()
	if not string.find(tipo.Name, "Gamepad", 1, true) then
		return 0
	end
	for _, estadoDoControle in UserInputService:GetGamepadState(tipo) do
		if estadoDoControle.KeyCode == Enum.KeyCode.Thumbstick2 then
			local y = estadoDoControle.Position.Y
			return if math.abs(y) > 0.3 then y else 0
		end
	end
	return 0
end

local function atualizarBotoes()
	if not gui then
		return
	end
	local visivel = UserInputService.TouchEnabled and CameraMundo.ativa() and GuiService.TouchControlsEnabled
	if gui.Enabled ~= visivel then
		gui.Enabled = visivel
	end
end

local function passo(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Rede de segurança: alguém trocou o CameraType sem pausar.
	if estado.controlando and camera.CameraType ~= Enum.CameraType.Scriptable then
		if not estado.avisouExterno then
			estado.avisouExterno = true
			warn("[CameraMundo] outro sistema trocou o CameraType sem pausar; cedendo 1,5 s. Use CameraMundo.pausar(motivo).")
		end
		estado.motivos.externo = true
		estado.externoAte = os.clock() + COOLDOWN_EXTERNO
		publicarPausa()
		soltar(false)
	end
	if estado.motivos.externo and os.clock() >= estado.externoAte then
		CameraMundo.retomar("externo")
	end
	atualizarBotoes()

	if not CameraMundo.ativa() then
		soltar(false)
		return
	end
	local raiz = raizDoJogador()
	if not raiz then
		return -- sem personagem (respawn): segura a pose atual
	end
	if not estado.controlando then
		assumir(camera, raiz)
	end

	-- Foco: X/Z seguem rápido, Y devagar (degraus do terreno não chacoalham a vista).
	local alvoFoco = raiz.Position + Vector3.new(0, ALTURA_FOCO, 0)
	local foco = estado.foco :: Vector3
	if Calculo.deveTeleportar(alvoFoco.X - foco.X, alvoFoco.Y - foco.Y, alvoFoco.Z - foco.Z) then
		foco = alvoFoco
	else
		foco = Vector3.new(
			Calculo.seguir(foco.X, alvoFoco.X, dt, TAU_XZ),
			Calculo.seguirY(foco.Y, alvoFoco.Y, dt, TAU_Y),
			Calculo.seguir(foco.Z, alvoFoco.Z, dt, TAU_XZ)
		)
	end
	estado.foco = foco

	-- Giro de 90° em passos e zoom suave.
	if estado.giroT < 1 then
		estado.giroT = math.min(1, estado.giroT + dt / Calculo.DURACAO_GIRO)
		estado.yaw = Calculo.yawAnimado(estado.yawDe, estado.yawPara, estado.giroT)
	else
		estado.yaw = estado.yawPara
	end
	local eixo = eixoZoomDoControle()
	if eixo ~= 0 then
		estado.zoomAlvo = Calculo.zoomPorEixo(estado.zoomAlvo, eixo, dt)
	end
	estado.zoom = Calculo.seguir(estado.zoom, estado.zoomAlvo, dt, TAU_ZOOM)

	-- Terreno que tampa a vista aproxima a câmera (não some com o relevo).
	local pose = Calculo.camera({ x = foco.X, y = foco.Y, z = foco.Z }, estado.yaw, nil, estado.zoom)
	local livre = distanciaAteTerreno(foco, Vector3.new(pose.x, pose.y, pose.z))
	local alvoDistancia = Calculo.distanciaLivre(estado.zoom, livre, MARGEM_TERRENO, APROXIMACAO_MIN)
	estado.obstrucao = Calculo.seguirAssimetrico(
		estado.obstrucao, estado.zoom - alvoDistancia, dt, TAU_TERRENO_SOBE, TAU_TERRENO_DESCE
	)
	local distancia = math.max(estado.zoom - estado.obstrucao, math.min(APROXIMACAO_MIN, estado.zoom))
	pose = Calculo.camera({ x = foco.X, y = foco.Y, z = foco.Z }, estado.yaw, nil, distancia)

	local posicao = Vector3.new(pose.x, pose.y, pose.z)
	local cf = CFrame.lookAt(posicao, foco)
	if Efeitos then
		local tremor = Efeitos.tremorCFrame()
		if tremor ~= CFrame.identity then
			cf = cf * CFrame.new(tremor.Position)
		end
	end
	if estado.entradaT < 1 and estado.desde then
		estado.entradaT = math.min(1, estado.entradaT + dt / DURACAO_ENTRADA)
		cf = estado.desde:Lerp(cf, Calculo.suavizarGiro(estado.entradaT))
	end
	camera.CFrame = cf
	camera.Focus = CFrame.new(foco)

	local agora = os.clock()
	if agora >= estado.proximaOclusao then
		estado.proximaOclusao = agora + INTERVALO_OCLUSAO
		checarOclusao(cf.Position, CFrame.lookAt(foco, foco + cf.LookVector), agora)
	end
	animarOclusao(dt)
end

-- ---------------------------------------------------------------- entrada

-- direcao +1 = a câmera orbita para a direita (E), -1 para a esquerda (Q).
function CameraMundo.girar(direcao: number)
	if direcao ~= 1 and direcao ~= -1 then
		return
	end
	estado.passoAcumulado += direcao
	estado.yawDe = estado.yaw
	estado.yawPara = Calculo.yawDoPasso(estado.passoAcumulado)
	estado.giroT = 0
end

-- Passo visível 0..3 (0 = 45°).
function CameraMundo.passo(): number
	return estado.passoAcumulado % Calculo.PASSOS
end

local function criarBotoes()
	local jogador = Players.LocalPlayer
	local novo = Instance.new("ScreenGui")
	novo.Name = "CameraMundoBotoes"
	novo.ResetOnSpawn = false
	novo.DisplayOrder = -1 -- abaixo do RUN e de todos os painéis de tela cheia
	novo.Enabled = false
	local function botao(nome: string, texto: string, direcao: number, deslocamento: number)
		Componentes.iconeBotao({parent=novo, nome=nome, icone=texto, rotulo="Girar",
			ancora=Vector2.new(0,.5), posicao=UDim2.new(0,MARGEM_BOTAO+deslocamento,.4,0),
			tamanho=UDim2.fromOffset(LADO_BOTAO,LADO_BOTAO), aoClicar=function()
				if CameraMundo.ativa() then CameraMundo.girar(direcao) end
			end})
	end
	botao("GirarEsquerda", "<", -1, 0)
	botao("GirarDireita", ">", 1, LADO_BOTAO + 6)
	novo.Parent = jogador:WaitForChild("PlayerGui")
	gui = novo
end

local function iniciar()
	if estado.iniciado then
		return
	end
	estado.iniciado = true
	local okEfeitos, modulo = pcall(require, script.Parent.Efeitos)
	Efeitos = if okEfeitos then modulo else nil

 local function indexar(item)
  if item:IsA("ProximityPrompt") then promptsProximos[item] = true end
 end
 for _, item in workspace:GetDescendants() do indexar(item) end
 workspace.DescendantAdded:Connect(indexar)
 workspace.DescendantRemoving:Connect(function(item) promptsProximos[item] = nil end)

	UserInputService.InputBegan:Connect(function(input, processado)
		if processado or not CameraMundo.ativa() or UserInputService:GetFocusedTextBox() then
			return
		end
		local tecla = input.KeyCode
		if tecla == Enum.KeyCode.Q or tecla == Enum.KeyCode.ButtonL1 then
			CameraMundo.girar(-1)
		elseif tecla == Enum.KeyCode.ButtonR1 or (tecla == Enum.KeyCode.E and not temPromptProximo()) then
			-- E é a tecla padrão dos prompts de interação (NPCs, acampamento): com um prompt na
			-- tela ela pertence ao prompt; Q e os botões continuam girando.
			CameraMundo.girar(1)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processado)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processado and CameraMundo.ativa() then
			estado.zoomAlvo = Calculo.zoomPelaRoda(estado.zoomAlvo, input.Position.Z)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, escala, _, fase, processado)
		if processado or not CameraMundo.ativa() then
			return
		end
		if fase == Enum.UserInputState.Begin or estado.pinca == nil then
			estado.pinca = estado.zoomAlvo
		end
		estado.zoomAlvo = Calculo.zoomPelaPinca(estado.pinca :: number, escala)
		if fase == Enum.UserInputState.End or fase == Enum.UserInputState.Cancel then
			estado.pinca = nil
		end
	end)

	if UserInputService.TouchEnabled then
		task.spawn(criarBotoes)
	end
	RunService:BindToRenderStep("CameraMundo", PRIORIDADE, passo)
end

-- ---------------------------------------------------------------- ligar/desligar

-- Chamado por ModoCamera quando o personagem está no mundo.
function CameraMundo.ligar()
	iniciar()
	estado.ligada = true
end

-- Chamado por ModoCamera dentro da sala (1ª pessoa) ou ao encerrar a sessão.
-- `limparPausas` esquece os motivos (fim da sessão de sala).
function CameraMundo.desligar(limparPausas: boolean?)
	estado.ligada = false
	if limparPausas then
		table.clear(estado.motivos)
		publicarPausa()
	end
	soltar(true)
	atualizarBotoes()
end

return CameraMundo
