-- Vida cosmética local: C0 compõe com Animator sem disputar Transform do idle/aceno.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Vida = {}
local iniciado = false
local IDENTIDADE = CFrame.new()

local function ang(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

local function pose(tipo, tempo, acenando)
	if acenando then return {} end -- preserva o aceno padrão carregado no servidor
	if tipo == "cruzados" then
		return { LeftShoulder = ang(58, -28, 30), RightShoulder = ang(58, 28, -30),
			LeftElbow = ang(100), RightElbow = ang(100) }
	elseif tipo == "forjar" then
		-- Golpe com subida lenta e descida curta, sem asset externo.
		local ciclo = (tempo % 2.6) / 2.6
		local golpe = if ciclo < 0.75 then ciclo / 0.75 else (1 - ciclo) / 0.25
		return { RightShoulder = ang(25 + 65 * golpe, 0, -12), RightElbow = ang(25 + 35 * golpe),
			LeftShoulder = ang(22, 0, 12) }
	elseif tipo == "acolher" then
		return { LeftShoulder = ang(8, 0, 8), RightShoulder = ang(10, 0, -8) }
	elseif tipo == "vigiar" then
		return { LeftShoulder = ang(-8, 0, 8), RightShoulder = ang(-8, 0, -8) }
	elseif tipo == "canalizar" then
		return { LeftShoulder = ang(28 + math.sin(tempo) * 4, 0, 16), LeftElbow = ang(22) }
	end
	return {}
end

function Vida.start()
	if iniciado then return end
	iniciado = true
	local rigs, acumulado = {}, 0
	local function registrar(corpo)
		if rigs[corpo] or not corpo:IsA("Model") or not corpo:GetAttribute("PoseOficio") then return end
		local juntas = {}
		for _, junta in corpo:GetDescendants() do
			if junta:IsA("Motor6D") then juntas[junta.Name] = { motor = junta, base = junta.C0 } end
		end
		rigs[corpo] = { juntas = juntas }
	end
	RunService.PreSimulation:Connect(function(dt)
		acumulado += dt
		if acumulado >= 0.25 then
			acumulado = 0
			local vila = workspace:FindFirstChild("Vila")
			if vila then
				for _, nome in { "Npcs", "TreinadoresRun" } do
					local pasta = vila:FindFirstChild(nome)
					if pasta then for _, corpo in pasta:GetChildren() do registrar(corpo) end end
				end
			end
			for corpo, dados in rigs do
				local raiz = corpo:FindFirstChild("HumanoidRootPart")
				dados.alvo = nil
				local distancia = 12
				if raiz then
					for _, jogador in Players:GetPlayers() do
						local personagem = jogador.Character
						local alvo = personagem and personagem:FindFirstChild("Head")
						local hum = personagem and personagem:FindFirstChildOfClass("Humanoid")
						if alvo and hum and hum.Health > 0 then
							local d = (alvo.Position - raiz.Position).Magnitude
							if d <= distancia then distancia, dados.alvo = d, alvo end
						end
					end
				end
			end
		end
		local suavidade = 1 - math.exp(-8 * dt)
		for corpo, dados in rigs do
			if not corpo:IsDescendantOf(workspace) then rigs[corpo] = nil; continue end
			local offsets = pose(corpo:GetAttribute("PoseOficio"), os.clock(), corpo:GetAttribute("Acenando"))
			local torso = corpo:FindFirstChild("UpperTorso")
			local head = corpo:FindFirstChild("Head")
			if torso and head and dados.alvo and dados.alvo.Parent then
				local delta = torso.CFrame:VectorToObjectSpace(dados.alvo.Position - head.Position)
				local yaw = math.clamp(math.atan2(-delta.X, -delta.Z), -0.9, 0.9)
				local pitch = math.clamp(math.atan2(delta.Y, math.sqrt(delta.X^2 + delta.Z^2)), -0.3, 0.3)
				offsets.Neck = CFrame.Angles(pitch, yaw, 0)
			end
			for nome, junta in dados.juntas do
				if junta.motor.Parent then
					junta.motor.C0 = junta.motor.C0:Lerp(junta.base * (offsets[nome] or IDENTIDADE), suavidade)
				end
			end
		end
	end)
end

return Vida
