-- Efeitos de brincadeira do ADM: só aparência, temporários e limpos sozinhos.
-- Não tocam em PV, ficha, turno, Ações nem na casa da ficha. Funcionam em combate,
-- quando o avatar é a ficha ancorada pelo AvatarFichas: escala e giro são desfeitos
-- relativos à posição atual, sem devolver o avatar a um lugar antigo.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Diversao = {}
Diversao.DURACAO = 15

local DOURADO, LILAS = Color3.fromRGB(244, 202, 92), Color3.fromRGB(180, 130, 255)
local FAISCA = "rbxasset://textures/particles/sparkles_main.dds"
local FUMACA = "rbxasset://textures/particles/smoke_main.dds"

function Diversao.start(deps)
	-- avatarSecreto(player) -> true quando o efeito revelaria um furtivo/oculto.
	local ativos = {}

	local function limpar(p)
		local atual = ativos[p]
		if not atual then return end
		ativos[p] = nil
		for _, desfazer in atual.desfazer do pcall(desfazer) end
		for _, objeto in atual.objetos do objeto:Destroy() end
	end

	local function novo(p, char)
		limpar(p)
		local atual = { char = char, objetos = {}, desfazer = {} }
		ativos[p] = atual
		local function guardar(o)
			table.insert(atual.objetos, o)
			Debris:AddItem(o, Diversao.DURACAO + 1)
			return o
		end
		return atual, guardar
	end

	local function anexo(raiz, guardar, y)
		local a = guardar(Instance.new("Attachment"))
		a.Name, a.Position, a.Parent = "AdminDiversao", Vector3.new(0, y or 0, 0), raiz
		return a
	end

	local function particulas(a, props, quantos)
		local e = Instance.new("ParticleEmitter")
		e.Rate, e.Texture = 0, props.Texture or FAISCA
		for k, v in props do if k ~= "Texture" then (e :: any)[k] = v end end
		e.Parent = a
		if quantos then e:Emit(quantos) end
		return e
	end

	local function brilho(char, guardar)
		local h = guardar(Instance.new("Highlight"))
		h.Name, h.FillColor, h.OutlineColor = "AdminBrilho", DOURADO, LILAS
		h.FillTransparency, h.DepthMode, h.Adornee, h.Parent = 0.55, Enum.HighlightDepthMode.Occluded, char, char
		return h
	end

	local function confete(raiz, guardar)
		particulas(anexo(raiz, guardar), {
			Color = ColorSequence.new(DOURADO, LILAS), Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(7, 12), SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -10, 0), Size = NumberSequence.new(0.3),
		}, 48)
	end

	-- Escala do modelo inteiro; ancorado (ficha no tabuleiro) mantém os pés no chão.
	local function escalar(p, char, raiz, atual, fator)
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local original = char:GetScale()
		local alturaAntes = (humanoid and humanoid.HipHeight or 0) + raiz.Size.Y / 2
		char:ScaleTo(original * fator)
		local alturaDepois = (humanoid and humanoid.HipHeight or 0) + raiz.Size.Y / 2
		local subir = if raiz.Anchored then alturaDepois - alturaAntes else 0
		if subir ~= 0 then raiz.CFrame += Vector3.new(0, subir, 0) end
		table.insert(atual.desfazer, function()
			if char:GetScale() == original then return end
			local h = (humanoid and humanoid.HipHeight or 0) + raiz.Size.Y / 2
			char:ScaleTo(original)
			local descer = (humanoid and humanoid.HipHeight or 0) + raiz.Size.Y / 2 - h
			if raiz.Anchored and descer ~= 0 then raiz.CFrame += Vector3.new(0, descer, 0) end
		end)
	end

	local function fantasma(char, atual)
		local antes = {}
		for _, parte in char:GetDescendants() do
			if parte:IsA("BasePart") and parte.Name ~= "HumanoidRootPart" and parte.Transparency < 1 then
				antes[parte] = parte.Transparency
				parte.Transparency = 0.6 + parte.Transparency * 0.4
			elseif parte:IsA("Decal") and parte.Transparency < 1 then
				antes[parte] = parte.Transparency
				parte.Transparency = 0.6
			end
		end
		table.insert(atual.desfazer, function()
			for parte, valor in antes do if parte.Parent then parte.Transparency = valor end end
		end)
	end

	-- Laço curto de animação; para sozinho quando o efeito é trocado ou limpo.
	local function enquanto(p, atual, passo)
		local conexao
		local inicio = os.clock()
		conexao = RunService.Heartbeat:Connect(function(dt)
			if ativos[p] ~= atual then conexao:Disconnect(); return end
			passo(os.clock() - inicio, dt)
		end)
		table.insert(atual.desfazer, function() conexao:Disconnect() end)
	end

	local function arcoiris(p, char, atual, guardar)
		local h = brilho(char, guardar)
		h.FillTransparency = 0.45
		enquanto(p, atual, function(t)
			local cor = Color3.fromHSV((t * 0.5) % 1, 0.8, 1)
			h.FillColor, h.OutlineColor = cor, Color3.fromHSV((t * 0.5 + 0.5) % 1, 0.8, 1)
		end)
	end

	local function fogos(p, raiz, atual, guardar)
		local a = anexo(raiz, guardar, 4)
		local cores = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), DOURADO, LILAS, Color3.fromRGB(120, 255, 140) }
		local proximo, n = 0, 0
		enquanto(p, atual, function(t)
			if t < proximo or n >= 10 then return end
			n += 1; proximo = t + 1.2
			local cor = cores[(n - 1) % #cores + 1]
			local e = particulas(a, {
				Color = ColorSequence.new(cor), LightEmission = 1, Lifetime = NumberRange.new(0.8, 1.3),
				Speed = NumberRange.new(14, 18), SpreadAngle = Vector2.new(180, 180), Drag = 3,
				Acceleration = Vector3.new(0, -6, 0), Size = NumberSequence.new(0.5, 0),
			}, 60)
			Debris:AddItem(e, 2)
		end)
	end

	local function raio(raiz, guardar)
		local base = raiz.Position - Vector3.new(0, 2.5, 0)
		local pontos, topo = {}, base + Vector3.new(0, 45, 0)
		for i = 0, 6 do
			local y = 45 - i * 7.5
			table.insert(pontos, base + Vector3.new(if i == 0 or i == 6 then 0 else math.random(-25, 25) / 10, y, if i == 0 or i == 6 then 0 else math.random(-25, 25) / 10))
		end
		pontos[1] = topo
		for i = 1, #pontos - 1 do
			local a, b = pontos[i], pontos[i + 1]
			local seg = guardar(Instance.new("Part"))
			seg.Name, seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch = "AdminRaio", true, false, false, false
			seg.Material, seg.Color = Enum.Material.Neon, Color3.fromRGB(200, 225, 255)
			seg.Size = Vector3.new(0.35, 0.35, (b - a).Magnitude)
			seg.CFrame = CFrame.lookAt((a + b) / 2, b)
			seg.Parent = workspace
			TweenService:Create(seg, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			Debris:AddItem(seg, 0.7)
		end
		local luz = guardar(Instance.new("PointLight"))
		luz.Color, luz.Brightness, luz.Range, luz.Parent = Color3.fromRGB(200, 225, 255), 8, 24, raiz
		TweenService:Create(luz, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		particulas(anexo(raiz, guardar, -2), {
			Color = ColorSequence.new(Color3.fromRGB(200, 225, 255)), LightEmission = 1, Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(90, 90), Size = NumberSequence.new(0.4, 0),
		}, 40)
	end

	local function dados(p, raiz, atual, guardar)
		local caidos = 0
		local proximo = 0
		enquanto(p, atual, function(t)
			if t < proximo or caidos >= 24 then return end
			caidos += 1; proximo = t + 0.35
			local d = guardar(Instance.new("Part"))
			d.Name, d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = "AdminDado", true, false, false, false
			d.Shape, d.Size, d.Material = Enum.PartType.Ball, Vector3.new(1, 1, 1), Enum.Material.SmoothPlastic
			d.Color = if caidos % 2 == 0 then DOURADO else LILAS
			local angulo, raioDado = math.random() * math.pi * 2, 2 + math.random() * 3
			local chao = raiz.Position + Vector3.new(math.cos(angulo) * raioDado, -2.5, math.sin(angulo) * raioDado)
			d.CFrame = CFrame.new(chao + Vector3.new(0, 14, 0))
			local texto = Instance.new("BillboardGui")
			texto.Size, texto.AlwaysOnTop, texto.Parent = UDim2.fromScale(1.4, 1.4), false, d
			texto.LightInfluence = 0
			local rotulo = Instance.new("TextLabel")
			rotulo.Size, rotulo.BackgroundTransparency, rotulo.TextScaled = UDim2.fromScale(1, 1), 1, true
			rotulo.Text, rotulo.Font, rotulo.TextColor3 = tostring(math.random(1, 20)), Enum.Font.GothamBold, Color3.new(1, 1, 1)
			rotulo.Parent = texto
			d.Parent = workspace
			TweenService:Create(d, TweenInfo.new(0.9, Enum.EasingStyle.Bounce), { CFrame = CFrame.new(chao + Vector3.new(0, 0.5, 0)) }):Play()
			Debris:AddItem(d, 4)
		end)
	end

	local function coroa(char, guardar)
		local cabeca = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
		local b = guardar(Instance.new("BillboardGui"))
		b.Name, b.Size, b.StudsOffset, b.AlwaysOnTop = "AdminCoroa", UDim2.fromScale(2.4, 2.4), Vector3.new(0, 2.2, 0), false
		b.LightInfluence, b.Adornee, b.Parent = 0, cabeca, cabeca
		local rotulo = Instance.new("TextLabel")
		rotulo.Size, rotulo.BackgroundTransparency, rotulo.TextScaled = UDim2.fromScale(1, 1), 1, true
		rotulo.Text, rotulo.Parent = "👑", b
	end

	local function fumaca(raiz, guardar)
		particulas(anexo(raiz, guardar, -1), {
			Texture = FUMACA, Color = ColorSequence.new(Color3.fromRGB(220, 220, 230)), Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(180, 180), Drag = 2, RotSpeed = NumberRange.new(-60, 60),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
			Transparency = NumberSequence.new(0.2, 1),
		}, 30)
	end

	-- Quatro voltas completas: no fim a frente é a mesma, mesmo que a ficha tenha andado.
	local function dancar(p, raiz, atual)
		local girado, total, duracao = 0, math.pi * 8, 6
		local function girar(angulo)
			raiz.CFrame *= CFrame.Angles(0, angulo, 0)
			girado += angulo
		end
		enquanto(p, atual, function(t)
			local alvo = math.min(t / duracao, 1) * total
			if alvo > girado then girar(alvo - girado) end
		end)
		table.insert(atual.desfazer, function()
			local falta = (total - girado) % (math.pi * 2)
			if falta > 1e-3 then girar(falta) end
		end)
		local humanoid = raiz.Parent and raiz.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and not raiz.Anchored then humanoid.Jump = true end
	end

	-- Aplica o efeito no avatar de `alvo`. Devolve erro em texto, ou nil.
	local function aplicar(alvo: Player, id: string): string?
		if id == "normal" then limpar(alvo); return nil end
		local char = alvo.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if not raiz then return "Personagem de " .. alvo.DisplayName .. " ainda está carregando." end
		if deps.avatarSecreto and deps.avatarSecreto(alvo) then
			return "Alvo escondido; efeito não aplicado para não revelar a posição."
		end
		local atual, guardar = novo(alvo, char)
		if id == "brilho" then brilho(char, guardar)
		elseif id == "confete" then confete(raiz, guardar)
		elseif id == "festa" then brilho(char, guardar); confete(raiz, guardar)
		elseif id == "gigante" then escalar(alvo, char, raiz, atual, 2)
		elseif id == "mini" then escalar(alvo, char, raiz, atual, 0.5)
		elseif id == "fantasma" then fantasma(char, atual)
		elseif id == "arcoiris" then arcoiris(alvo, char, atual, guardar)
		elseif id == "fogos" then fogos(alvo, raiz, atual, guardar)
		elseif id == "raio" then raio(raiz, guardar)
		elseif id == "dados" then dados(alvo, raiz, atual, guardar)
		elseif id == "coroa" then coroa(char, guardar)
		elseif id == "fumaca" then fumaca(raiz, guardar)
		elseif id == "dancar" then dancar(alvo, raiz, atual)
		else limpar(alvo); return "Efeito desconhecido." end
		task.delay(Diversao.DURACAO, function() if ativos[alvo] == atual then limpar(alvo) end end)
		return nil
	end

	-- Ficou escondido no meio do efeito: some antes de revelar a posição.
	local vigia = 0
	RunService.Heartbeat:Connect(function(dt)
		vigia += dt
		if vigia < 0.3 then return end
		vigia = 0
		for p, atual in ativos do
			if not atual.char.Parent or p.Character ~= atual.char or (deps.avatarSecreto and deps.avatarSecreto(p)) then limpar(p) end
		end
	end)

	return { aplicar = aplicar, limpar = limpar, ativo = function(p) return ativos[p] ~= nil end }
end

return Diversao
