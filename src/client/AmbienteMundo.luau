-- Iluminação por zona: noite na sala da Mesa, fim de tarde na região e na vila,
-- crepúsculo verde na Floresta Sombria. Os perfis e a mistura são dados puros em
-- shared/Mundo/AmbientePerfis; aqui só se lê a posição e se aplica ao Lighting.
-- Céu (Sky e Clouds) fica em CeuMundo.
-- Só apresentação local; cada cliente decide sozinho e nada disso toca regra.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Perfis = require(ReplicatedStorage.Shared.Mundo.AmbientePerfis)
local ModoCamera = require(script.Parent.ModoCamera)
local CeuMundo = require(script.Parent.CeuMundo)

local AmbienteMundo = {}
local iniciado = false

-- A Mesa (prototipo pausado) fica longe, em z=900; a sala do lobby, em torno de x=250.
local MESA_Z_MIN = 400
local MARGEM_SALA = 5
local INTERVALO_ZONA = 0.2

local function cor(c: { number }): Color3
	return Color3.fromRGB(math.round(c[1]), math.round(c[2]), math.round(c[3]))
end

-- Efeito único do Lighting. O servidor já criou Atmosphere/Bloom (MesaWorld); o clarão
-- de Magias usa outro ColorCorrection e por isso o nosso ganha nome próprio.
local function efeito(classe: string, nome: string): Instance
	local existente = Lighting:FindFirstChild(nome)
	if existente then
		return existente
	end
	local objeto = Lighting:FindFirstChildOfClass(classe) or Instance.new(classe)
	objeto.Name = nome
	objeto.Parent = Lighting
	return objeto
end

-- Arena regional do Modo História (PLANO §13): o tabuleiro fica em z=900, mas a luz segue a
-- região da luta e a hora da run. Devolve o ponto do mundo que a arena representa, ou nil.
local PONTO_DA_ARENA = { cidade = Vector3.new(0, 0, -150) }
local function pontoDaArena(raiz: BasePart): Vector3?
	if raiz.Position.Z <= MESA_Z_MIN then return nil end
	local mesa = workspace:FindFirstChild("Mesa")
	local arena = mesa and mesa:GetAttribute("ArenaRegional")
	return if type(arena) == "string" then PONTO_DA_ARENA[arena] else nil
end

local function naSala(raiz: BasePart): boolean
	if pontoDaArena(raiz) then return false end
	if raiz.Position.Z > MESA_Z_MIN then
		return true
	end
	local sala = workspace:FindFirstChild("SalaRPG")
	local piso = sala and sala:FindFirstChild("Piso")
	if piso and piso:IsA("BasePart") then
		return ModoCamera.dentro(piso.Position, piso.Size, raiz.Position, MARGEM_SALA)
	end
	return false
end

function AmbienteMundo.start()
	if iniciado then return end
	iniciado = true
	-- Instance criada só neste cliente, ligada à raiz atual e destruída ao trocar
	-- personagem ou sair da noite/floresta. Não replica nem altera combate/visibilidade.
	local luzPessoal: PointLight? = nil
	local function atualizarLuz(raiz: BasePart?, ligada: boolean)
		if luzPessoal and (not ligada or luzPessoal.Parent ~= raiz) then
			luzPessoal:Destroy()
			luzPessoal = nil
		end
		if ligada and raiz and not luzPessoal then
			local luz = Instance.new("PointLight")
			luz.Name = "LuzPessoalMundo"
			luz.Color = Color3.fromRGB(255, 221, 176)
			luz.Brightness = 0.65
			luz.Range = 14
			luz.Shadows = false
			luz.Parent = raiz
			luzPessoal = luz
		end
	end
	Players.LocalPlayer.CharacterRemoving:Connect(function() atualizarLuz(nil, false) end)
	local atmosfera = efeito("Atmosphere", "AtmosferaMundo") :: Atmosphere
	local brilho = efeito("BloomEffect", "BrilhoMundo") :: BloomEffect
	local correcao = efeito("ColorCorrectionEffect", "CorMundo") :: ColorCorrectionEffect
	local raios = efeito("SunRaysEffect", "RaiosMundo") :: SunRaysEffect
	raios.Spread = 0.55
	-- Desfoque só ao longe (Near=0): suaviza o horizonte sem borrar o chão de jogo.
	local foco = efeito("DepthOfFieldEffect", "FocoMundo") :: DepthOfFieldEffect
	foco.NearIntensity = 0
	local ceu = CeuMundo.criar(cor)

	local function aplicar(p)
		Lighting.ClockTime = p.clock
		Lighting.Brightness = p.brilho
		Lighting.EnvironmentDiffuseScale = p.difuso
		Lighting.EnvironmentSpecularScale = p.especular
		Lighting.Ambient = cor(p.ambiente)
		Lighting.OutdoorAmbient = cor(p.ambienteExterno)
		Lighting.ColorShift_Top = cor(p.deslocaCima)
		atmosfera.Density = p.atmDensidade
		atmosfera.Offset = p.atmOffset
		atmosfera.Glare = p.atmGlare
		atmosfera.Haze = p.atmHaze
		atmosfera.Color = cor(p.atmCor)
		atmosfera.Decay = cor(p.atmDecay)
		brilho.Intensity = p.bloomIntensidade
		brilho.Size = p.bloomTamanho
		brilho.Threshold = p.bloomLimiar
		correcao.Contrast = p.ccContraste
		correcao.Saturation = p.ccSaturacao
		correcao.TintColor = cor(p.ccTint)
		raios.Intensity = p.raios
		foco.FarIntensity = p.dofLonge
		foco.FocusDistance = p.dofDistancia
		foco.InFocusRadius = p.dofRaio
		foco.Enabled = p.dofLonge > 0.001
		ceu.aplicar(p)
	end

	-- Ponto de partida: o spawn é na praça da vila; a primeira leitura da posição
	-- corrige se o jogador começou noutro lugar, sem esperar a transição.
	local atual = Perfis.alvo(0, 0, false)
	local alvo = atual
	local tau = Perfis.TAU_ZONA
	local mudouEm = os.clock()
	local chaveAlvo = ""
	local primeira = true
	local ultimoZona = 0
	aplicar(atual)

	RunService.Heartbeat:Connect(function(dt)
		local agora = os.clock()
		if agora - ultimoZona >= INTERVALO_ZONA then
			ultimoZona = agora
			local personagem = Players.LocalPlayer.Character
			local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") then
				local dentro = naSala(raiz)
				local ponto = pontoDaArena(raiz) or raiz.Position
				-- O alvo só muda de verdade quando a zona (ou a mistura da trilha) muda.
				local pesos = Perfis.pesos(ponto.X, ponto.Z, dentro)
				local hora = if dentro then nil else ReplicatedStorage:GetAttribute("RunHora")
				atualizarLuz(raiz, Perfis.luzPessoal(ponto.X, ponto.Z, dentro, hora))
				local chave = tostring(hora) .. (if dentro then "sala" elseif pesos.ruinas >= 1 then "ruinas" else tostring(math.floor(pesos.floresta * 500)))
				if chave ~= chaveAlvo then
					chaveAlvo = chave
					alvo = Perfis.modularHora(Perfis.alvo(ponto.X, ponto.Z, dentro), hora)
					tau = if dentro then Perfis.TAU_SALA else Perfis.TAU_ZONA
					mudouEm = agora
				end
				if primeira then
					primeira = false
					atual = alvo
					aplicar(atual)
				end
			else
				atualizarLuz(nil, false)
			end
		end
		-- Depois de ~6 constantes de tempo o perfil já convergiu; para de escrever.
		if agora - mudouEm > tau * 6 and not primeira then
			return
		end
		atual = Perfis.passo(atual, alvo, dt, tau)
		aplicar(atual)
	end)
end

return AmbienteMundo
