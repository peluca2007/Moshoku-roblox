-- HAB1: palco isolado das habilidades de espada/ladino (cliente, Play). MODO: montar | lancar | limpar.
-- montar: palco no céu (chão, boneco-alvo), avatar teleportado, Coreografia.start com estado falso, câmera lateral
-- (base) passada por ImpactoCamera.aplicar (câmera própria das assinaturas) e pelo tremor de tela.
-- lancar: dispara o recibo @ID@ (acertou, crítico=@CRIT@, distância do alvo @DIST@ studs).
local MODO = "@MODO@"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local S = Vector3.new(6000, 80, 6000)
local Scripts = player.PlayerScripts.Client

if MODO == "montar" then
	local velho = workspace:FindFirstChild("HabEspadaPalco")
	if velho then velho:Destroy() end
	if shared.HabEspada and shared.HabEspada.api then pcall(shared.HabEspada.api.destruir) end
	local palco = Instance.new("Folder"); palco.Name = "HabEspadaPalco"; palco.Parent = workspace
	local chao = Instance.new("Part")
	chao.Anchored, chao.Size, chao.Position, chao.Color, chao.Material = true, Vector3.new(200, 1, 200), S - Vector3.new(0, 0.5, 0), Color3.fromRGB(70, 68, 74), Enum.Material.Slate
	chao.Parent = palco
	local fundo = Instance.new("Part")
	fundo.Anchored, fundo.Size, fundo.Position, fundo.Color, fundo.Material = true, Vector3.new(200, 60, 2), S + Vector3.new(0, 30, -50), Color3.fromRGB(30, 34, 44), Enum.Material.Slate
	fundo.Parent = palco
	local boneco = Instance.new("Model"); boneco.Name = "Alvo"; boneco.Parent = palco
	local function p(nome, tam, pos, cor)
		local x = Instance.new("Part"); x.Name, x.Anchored, x.Size, x.Position, x.Color, x.Material = nome, true, tam, pos, cor, Enum.Material.SmoothPlastic
		x.Parent = boneco
		return x
	end
	local dist = @DIST@
	local alvoPos = S + Vector3.new(0, 0, -dist)
	local raiz = p("HumanoidRootPart", Vector3.new(2, 2, 1), alvoPos + Vector3.new(0, 3.2, 0), Color3.fromRGB(150, 70, 60))
	p("Cabeca", Vector3.new(1.4, 1.4, 1.4), alvoPos + Vector3.new(0, 5, 0), Color3.fromRGB(200, 170, 130))
	p("BracoD", Vector3.new(0.7, 2, 0.7), alvoPos + Vector3.new(1.4, 3.4, 0), Color3.fromRGB(190, 150, 110))
	p("PernaE", Vector3.new(0.9, 2.2, 0.9), alvoPos + Vector3.new(-0.5, 1.1, 0), Color3.fromRGB(70, 60, 50))
	p("PernaD", Vector3.new(0.9, 2.2, 0.9), alvoPos + Vector3.new(0.5, 1.1, 0), Color3.fromRGB(70, 60, 50))
	boneco.PrimaryPart = raiz
	shared.HabEspadaGuis = shared.HabEspadaGuis or {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then table.insert(shared.HabEspadaGuis, g); g.Enabled = false end
	end
	-- atacante: rig R15 padrão (aparência controlada, igual para todo QA); sem isso o avatar do jogador de Studio varia
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor, desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor =
		Color3.fromRGB(214, 170, 130), Color3.fromRGB(120, 78, 52), Color3.fromRGB(214, 170, 130), Color3.fromRGB(214, 170, 130), Color3.fromRGB(92, 84, 60), Color3.fromRGB(92, 84, 60)
	local ch = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	ch.Name = "AtacanteQA"
	ch.Parent = palco
	for _, d in ch:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = (d.Name == "HumanoidRootPart") end
	end
	ch:PivotTo(CFrame.lookAt(S + Vector3.new(0, 3.5, 0), alvoPos + Vector3.new(0, 3.5, 0)))
	local fichas = { eu = { ownerUserId = player.UserId, avatar = true }, alvo = { ownerUserId = 0 } }
	local state = {
		snapshot = function() return { tokens = {}, combat = { active = false } } end,
		findToken = function(id) return fichas[id] end,
		modeloDe = function(id) if id == "eu" then return ch, true end return boneco, false end,
	}
	local Efeitos = require(Scripts.Efeitos)
	pcall(Efeitos.start)
	local Coreografia = require(Scripts.Coreografia)
	local ImpactoCamera = require(Scripts.ImpactoCamera)
	local pasta = Instance.new("Folder"); pasta.Name = "HabEspadaFX"; pasta.Parent = palco
	local function posicaoDe(_, id)
		if id == "eu" then
			local r = ch:FindFirstChild("HumanoidRootPart")
			return (if r then r.Position else S) + Vector3.new(0, 1, 0)
		end
		return boneco:GetPivot().Position
	end
	local api = Coreografia.start(state, pasta, posicaoDe, function(pos) return Vector3.new(pos.X, S.Y, pos.Z) end, function(x, z) return S + Vector3.new((x - 1) * 5, 0, (z - 1) * 5) end)
	shared.HabEspada = { api = api, alvoPos = alvoPos }
	pcall(function() RunService:UnbindFromRenderStep("HabEspadaCam") end)
	RunService:BindToRenderStep("HabEspadaCam", Enum.RenderPriority.Last.Value, function()
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then table.insert(shared.HabEspadaGuis, g); g.Enabled = false end
		end
		local L = game:GetService("Lighting")
		L.ClockTime, L.Brightness, L.Ambient, L.OutdoorAmbient, L.ExposureCompensation = 14, 2, Color3.fromRGB(95, 100, 120), Color3.fromRGB(95, 100, 120), 0
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 70
		local meio = (S + alvoPos) / 2 + Vector3.new(0, 3, 0)
		local base = CFrame.lookAt(meio + Vector3.new(9, 4.5, 8), meio)
		cam.CFrame = ImpactoCamera.aplicar(base) * Efeitos.tremorCFrame()
	end)
	return "montado"
elseif MODO == "lancar" then
	local H = shared.HabEspada
	if not H then return "sem palco" end
	H.api.tocar({ habilidadeId = "@ID@", casterId = "eu", origem = { 1, 1 }, alvos = { { id = "alvo", acertou = true, critico = @CRIT@, dano = 6 } } })
	return "lançado @ID@"
elseif MODO == "limpar" then
	pcall(function() RunService:UnbindFromRenderStep("HabEspadaCam") end)
	if shared.HabEspada and shared.HabEspada.api then pcall(shared.HabEspada.api.destruir) end
	shared.HabEspada = nil
	for _, g in shared.HabEspadaGuis or {} do if g.Parent then g.Enabled = true end end
	shared.HabEspadaGuis = nil
	local palco = workspace:FindFirstChild("HabEspadaPalco")
	if palco then palco:Destroy() end
	workspace:SetAttribute("EscalaDeTempoDasCenas", nil)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	return "limpo"
end
return "modo?"
