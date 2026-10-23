-- Constrói os NPCs da vila (shared/Mundo/NpcsDados) como avatares Roblox R15 parados,
-- com um ProximityPrompt "Falar" e fala em balão acima da cabeça. Sem regra de jogo:
-- o que cada NPC oferece de verdade (dojo, loja) entra em serviços próprios.
local Players = game:GetService("Players")
local Dados = require(game:GetService("ReplicatedStorage").Shared.Mundo.NpcsDados)

local Npcs = {}

local ANIM_PARADO = "rbxassetid://507766388"
local ANIM_ACENO = "rbxassetid://507770239" -- animações padrão do Roblox (R15)
local DISTANCIA_ACENO = 14
local INTERVALO_ACENO = 25

local AparenciaVisual = require(game:GetService("ReplicatedStorage").Shared.Aparencia.Visual)
local Encaixe = require(script.Parent.EncaixeCosmetico)
local function ferramenta(corpo)
	local mao = corpo:FindFirstChild("RightHand")
	if not mao then return end
	local martelo = Instance.new("Model")
	martelo.Name, martelo.Parent = "MarteloOficio", corpo.AparenciaMoshoku
	for _, dado in { { "Cabo", Vector3.new(0.14, 0.9, 0.14), CFrame.new(0, -0.25, 0), Color3.fromRGB(85, 54, 33) },
		{ "Ferro", Vector3.new(0.6, 0.26, 0.28), CFrame.new(0, -0.65, 0), Color3.fromRGB(70, 73, 80) } } do
		local parte = Instance.new("Part")
		parte.Name, parte.Size, parte.CFrame, parte.Color = dado[1], dado[2], mao.CFrame * dado[3], dado[4]
		parte.Parent = martelo
	end
	Encaixe.configurarPecas(martelo, mao, "MarteloOficio")
end
local function criarCorpo(npc)
	local descricao = AparenciaVisual.descrever(npc.aparencia, npc.raceId)
	local ok, corpo = pcall(Players.CreateHumanoidModelFromDescription, Players, descricao, Enum.HumanoidRigType.R15)
	descricao:Destroy()
	if not ok then return nil end
	AparenciaVisual.decorar(corpo, npc.aparencia, npc.raceId)
	if npc.pose == "forjar" then ferramenta(corpo) end
	corpo:SetAttribute("PoseOficio", npc.pose)
	return corpo
end

local Visual = require(script.Parent.NpcVisual)

local acenos = {} -- corpo -> { faixa, ultimo }

local function criar(pasta, npc, deps)
	local posicao = Dados.posicao(npc)
	if not posicao then return nil end
	local corpo = criarCorpo(npc)
	if not corpo then return nil end
	corpo.Name = npc.nome
	-- O rig vem com o script Animate (cliente); NPCs parados não usam, e não se aceita script de fora.
	for _, item in ipairs(corpo:GetDescendants()) do
		if item:IsA("LuaSourceContainer") then item:Destroy() end
	end
	local humanoide = corpo:FindFirstChildOfClass("Humanoid")
	humanoide.DisplayName = npc.nome
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	Visual.nome(corpo, npc.nome)
	local raiz = corpo:WaitForChild("HumanoidRootPart")
	-- Os pés apoiam no chão: o pivô fica à altura do quadril (HipHeight + metade da raiz).
	local altura = humanoide.HipHeight + raiz.Size.Y / 2
	local alvo = Vector3.new(posicao.x, altura, posicao.z)
	corpo:PivotTo(CFrame.lookAt(alvo, alvo + Vector3.new(posicao.olharX, 0, posicao.olharZ)))
	-- Só a raiz fica ancorada: com todas as peças ancoradas as juntas não se movem e a
	-- animação não aparece (o NPC ficava de braços abertos).
	for _, parte in ipairs(corpo:GetDescendants()) do
		if parte:IsA("BasePart") then parte.Anchored = parte == raiz end
	end
	corpo:SetAttribute("AreaId", "region/vila/npc/" .. npc.id)
	corpo:SetAttribute("AreaRole", "npc")
	local animador = humanoide:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoide)
	local animacao = Instance.new("Animation")
	animacao.AnimationId = ANIM_PARADO
	local ok, faixa = pcall(function() return animador:LoadAnimation(animacao) end)
	if ok and faixa then
		faixa.Looped = true
		faixa:Play()
	end
	local aceno = Instance.new("Animation")
	aceno.AnimationId = ANIM_ACENO
	local okAceno, faixaAceno = pcall(function() return animador:LoadAnimation(aceno) end)
	if okAceno and faixaAceno then
		faixaAceno.Looped = false
		faixaAceno.Priority = Enum.AnimationPriority.Action
		faixaAceno.Stopped:Connect(function()
			if corpo.Parent then corpo:SetAttribute("Acenando", false) end
		end)
		corpo:SetAttribute("TemAceno", true)
		acenos[corpo] = { faixa = faixaAceno, ultimo = -INTERVALO_ACENO }
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "Falar", "Falar", npc.nome
	corpo:SetAttribute("NpcId", npc.id)
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, 8, false
	prompt.Parent = raiz
	local contadores, ultimo = {}, {}
	prompt.Triggered:Connect(function(jogador)
		local personagem = jogador.Character
		local raizJogador = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local vivo = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if not raizJogador or not vivo or vivo.Health <= 0 then return end
		if (raizJogador.Position - raiz.Position).Magnitude > prompt.MaxActivationDistance + 2 then return end
		local agora = (deps and deps.relogio or os.clock)()
		if ultimo[jogador] and agora - ultimo[jogador] < Dados.COOLDOWN then return end
		ultimo[jogador] = agora
		contadores[jogador] = (contadores[jogador] or 0) + 1
		Visual.balao(corpo, npc.nome, Dados.fala(npc, contadores[jogador]), Dados.DURACAO_BALAO)
		-- Consulta antecipada: o cliente só apresenta as missões ao escolher a opção.
		if npc.id == "taverneira" and deps and deps.abrirMissoes then deps.abrirMissoes(jogador) end
	end)
	Players.PlayerRemoving:Connect(function(jogador)
		contadores[jogador], ultimo[jogador] = nil, nil
	end)
	corpo.Parent = pasta
	return corpo
end

function Npcs.start(deps)
	deps = deps or {}
	local vila = (deps.workspace or workspace):FindFirstChild("Vila")
	if not vila then return nil end
	local existente = vila:FindFirstChild("Npcs")
	if existente then return existente end
	local pasta = Instance.new("Folder")
	pasta.Name = "Npcs"
	pasta.Parent = vila
	for _, npc in ipairs(Dados.LISTA) do criar(pasta, npc, deps) end
	-- Aceno quando um jogador vivo chega perto; um por NPC a cada INTERVALO_ACENO segundos.
	task.spawn(function()
		while pasta.Parent do
			task.wait(1)
			local agora = os.clock()
			for corpo, dados in pairs(acenos) do
				if not corpo.Parent then acenos[corpo] = nil; continue end
				local raiz = corpo.Parent and corpo:FindFirstChild("HumanoidRootPart")
				if raiz and agora - dados.ultimo >= INTERVALO_ACENO then
					for _, jogador in ipairs(Players:GetPlayers()) do
						local personagem = jogador.Character
						local alvo = personagem and personagem:FindFirstChild("HumanoidRootPart")
						local vivo = personagem and personagem:FindFirstChildOfClass("Humanoid")
						if alvo and vivo and vivo.Health > 0 and (alvo.Position - raiz.Position).Magnitude <= DISTANCIA_ACENO then
							dados.ultimo = agora
							corpo:SetAttribute("Acenando", true)
							dados.faixa:Play()
							break
						end
					end
				end
			end
		end
	end)
	return pasta
end

-- Corpo R15 com a aparência do jogo, sem prompt nem animação: também serve aos moradores das arenas.
Npcs.criarCorpo = criarCorpo

return Npcs
