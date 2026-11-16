-- HAB2: palco isolado das magias de Água (cliente, Play). MODO: montar | lancar | limpar.
-- montar: palco no céu (chão, boneco-alvo), avatar teleportado, câmera lateral por atributos, Magias.start com estado falso.
-- lancar: dispara o recibo @ID@ (acertou=@ACERTOU@, crítico=@CRIT@). A câmera lê HabCamDe/HabCamPara do Workspace.
local MODO = "@MODO@"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local S = Vector3.new(6000, 80, 6000)

if MODO == "montar" then
	local velho = workspace:FindFirstChild("HabAguaPalco")
	if velho then velho:Destroy() end
	if shared.HabAgua and shared.HabAgua.fx then pcall(shared.HabAgua.fx.destruir) end
	local palco = Instance.new("Folder"); palco.Name = "HabAguaPalco"; palco.Parent = workspace
	local chao = Instance.new("Part")
	chao.Anchored, chao.Size, chao.Position, chao.Color, chao.Material = true, Vector3.new(160, 1, 160), S - Vector3.new(0, 0.5, 0), Color3.fromRGB(58, 56, 64), Enum.Material.Slate
	chao.Parent = palco
	local fundo = Instance.new("Part")
	fundo.Anchored, fundo.Size, fundo.Position, fundo.Color, fundo.Material = true, Vector3.new(160, 60, 2), S + Vector3.new(0, 30, -40), Color3.fromRGB(24, 26, 36), Enum.Material.Slate
	fundo.Parent = palco
	-- boneco-alvo: torso, cabeça, pernas (só para dar escala)
	local boneco = Instance.new("Model"); boneco.Name = "Alvo"; boneco.Parent = palco
	local function p(nome, tam, pos, cor)
		local x = Instance.new("Part"); x.Name, x.Anchored, x.Size, x.Position, x.Color, x.Material = nome, true, tam, pos, cor, Enum.Material.SmoothPlastic
		x.Parent = boneco
		return x
	end
	local alvoPos = S + Vector3.new(0, 0, -16)
	local raiz = p("HumanoidRootPart", Vector3.new(2, 2, 1), alvoPos + Vector3.new(0, 3.2, 0), Color3.fromRGB(150, 70, 60))
	p("Cabeca", Vector3.new(1.4, 1.4, 1.4), alvoPos + Vector3.new(0, 5, 0), Color3.fromRGB(200, 170, 130))
	p("PernaE", Vector3.new(0.9, 2.2, 0.9), alvoPos + Vector3.new(-0.5, 1.1, 0), Color3.fromRGB(70, 60, 50))
	p("PernaD", Vector3.new(0.9, 2.2, 0.9), alvoPos + Vector3.new(0.5, 1.1, 0), Color3.fromRGB(70, 60, 50))
	boneco.PrimaryPart = raiz
	-- esconde as telas do jogo (guardando quais estavam ligadas) para a captura mostrar só o palco
	shared.HabAguaGuis = shared.HabAguaGuis or {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then table.insert(shared.HabAguaGuis, g); g.Enabled = false end
	end
	local ch = player.Character or player.CharacterAdded:Wait()
	ch:PivotTo(CFrame.lookAt(S + Vector3.new(0, 3.5, 0), alvoPos + Vector3.new(0, 3.5, 0)))
	local rr = ch:FindFirstChild("HumanoidRootPart")
	if rr then rr.Anchored = true end -- o jogo não arrasta o avatar durante a captura
	local fichas = { eu = { ownerUserId = player.UserId, avatar = true }, alvo = { ownerUserId = 0 } }
	local ouvinte
	local fake = {
		posicaoCasa = function(x, z) return S + Vector3.new((x - 1) * 5, 0, (z - 1) * 5) end,
		tamanhoCasa = 5,
		findToken = function(id) return fichas[id] end,
		posicaoDe = function(id)
			if id == "eu" then
				local r = ch:FindFirstChild("HumanoidRootPart")
				return (if r then r.Position else S) + Vector3.new(0, 1, 0)
			end
			return boneco:GetPivot().Position
		end,
		chao = function(pos) return Vector3.new(pos.X, S.Y, pos.Z) end,
		modeloDe = function(id) if id == "eu" then return ch, true end return boneco, false end,
		onSnapshot = function() end,
		onEfeito = function(cb) ouvinte = cb end,
	}
	local Magias = require(player.PlayerScripts.Client.Magias)
	local fx = Magias.start(fake, { nomePasta = "HabAguaFX" })
	shared.HabAgua = { fx = fx, ouvir = function(r) return ouvinte(r) end, alvoPos = alvoPos }
	-- câmera: lateral (3/4), lê os atributos a cada quadro
	workspace:SetAttribute("HabCamDe", S + Vector3.new(11, 6.5, 9))
	workspace:SetAttribute("HabCamPara", S + Vector3.new(0, 3.2, -7))
	workspace:SetAttribute("HabCamFov", 55)
	pcall(function() RunService:UnbindFromRenderStep("HabAguaCam") end)
	RunService:BindToRenderStep("HabAguaCam", Enum.RenderPriority.Camera.Value + 50, function()
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then table.insert(shared.HabAguaGuis, g); g.Enabled = false end
		end
		-- luz de estúdio fixa (o jogo escurece o céu por script); só para a captura
		local L = game:GetService("Lighting")
		L.ClockTime, L.Brightness, L.Ambient, L.OutdoorAmbient, L.ExposureCompensation = 14, 2, Color3.fromRGB(95, 100, 120), Color3.fromRGB(95, 100, 120), 0
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = workspace:GetAttribute("HabCamFov") or 55
		cam.CFrame = CFrame.lookAt(workspace:GetAttribute("HabCamDe"), workspace:GetAttribute("HabCamPara"))
	end)
	return "montado " .. tostring(ch:GetPivot().Position)
elseif MODO == "lancar" then
	local H = shared.HabAgua
	if not H then return "sem palco" end
	local recibo = { habilidadeId = "@ID@", casterId = "eu", origem = { 1, 1 }, encantamento = nil,
		alvos = { { id = "alvo", acertou = @ACERTOU@, critico = @CRIT@, dano = 6 } } }
	H.ouvir(recibo)
	return "lançado @ID@"
elseif MODO == "limpar" then
	pcall(function() RunService:UnbindFromRenderStep("HabAguaCam") end)
	if shared.HabAgua and shared.HabAgua.fx then pcall(shared.HabAgua.fx.destruir) end
	shared.HabAgua = nil
	local c2 = player.Character
	local r2 = c2 and c2:FindFirstChild("HumanoidRootPart")
	if r2 then r2.Anchored = false end
	for _, g in shared.HabAguaGuis or {} do if g.Parent then g.Enabled = true end end
	shared.HabAguaGuis = nil
	local palco = workspace:FindFirstChild("HabAguaPalco")
	if palco then palco:Destroy() end
	workspace:SetAttribute("EscalaDeTempoDasCenas", nil)
	workspace:SetAttribute("CenaTempoFixo", nil)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	return "limpo"
end
return "modo?"
