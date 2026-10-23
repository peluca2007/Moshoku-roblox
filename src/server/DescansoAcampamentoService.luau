-- Interações do acampamento. Regra/limite e persistência ficam em módulos próprios.
local Players = game:GetService("Players")
local Service = {}
local DISTANCIA_MAXIMA = 10

function Service.temLinhaDeVisao(root, ponto, mundo)
	if not root or not root:IsA("BasePart") or not ponto or not ponto:IsA("BasePart") then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent }
	params.IgnoreWater = true
	local direcao = ponto.Position - root.Position
	local resultado = (mundo or workspace):Raycast(root.Position, direcao, params)
	return resultado == nil or resultado.Instance == ponto
end

function Service.start(deps)
	assert(type(deps) == "table" and type(deps.descansar) == "function", "Dependências de descanso inválidas")
	local regiao = workspace:WaitForChild("RegiaoInicial")
	local acampamento = regiao:WaitForChild("Acampamento")
	local ponto = acampamento:FindFirstChild("Fogueira apagada")
	assert(ponto and ponto:IsA("BasePart"), "Ponto do acampamento ausente")
	local ultimoPedido = {}
	for _, tipo in { "curto", "longo" } do
		local prompt = ponto:FindFirstChild("Descanso " .. tipo)
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Descanso " .. tipo
			prompt.Parent = ponto
		end
		prompt.ActionText = if tipo == "curto" then "Descansar 1–2 h" else "Dormir at? amanh?"
		prompt.ObjectText = "Acampamento"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = DISTANCIA_MAXIMA
		prompt.RequiresLineOfSight = true
		prompt.Triggered:Connect(function(player)
			if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end
			if (root.Position - ponto.Position).Magnitude > DISTANCIA_MAXIMA then return end
			if not Service.temLinhaDeVisao(root, ponto) then return end
			if deps.emCombate and deps.emCombate(player) then return end
			local now = os.clock()
			if ultimoPedido[player.UserId] and now - ultimoPedido[player.UserId] < 2 then return end
			ultimoPedido[player.UserId] = now
			local ok, resultado = deps.descansar(player, tipo)
			if ok then
				player:SetAttribute("DescansoResultado", tipo .. ": PV " .. resultado.atuais.pv .. ", PM " .. resultado.atuais.pm
					.. ", PT " .. resultado.atuais.pt .. ", PP " .. resultado.atuais.pp)
			else
				player:SetAttribute("DescansoResultado", tostring(resultado))
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player) ultimoPedido[player.UserId] = nil end)
	return table.freeze({})
end

return Service
