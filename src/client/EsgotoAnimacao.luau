-- Vida do esgoto (CEN2), só no cliente: textura da água rolando, luz das tochas piscando com ruído e
-- gotejamento com respingo. O servidor só marca as peças (tags em server/Mundo/Esgoto*); nada aqui toca regra.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EsgotoAnimacao = {}

local TAG_AGUA, TAG_TOCHA, TAG_GOTA = "EsgotoAgua", "EsgotoTocha", "EsgotoGota"
local DISTANCIA_MAX = 260 -- além disso não vale animar

local texturas = {} -- Texture -> { velU, velV }
local tochas = {} -- chama (Part) -> { luz, brilho, alcance, semente }
local gotas = {} -- origem (Part) -> { proxima = tempo }
local iniciado = false

-- Ruído suave em duas oitavas + um raro "sopro" que abafa a chama por um instante.
function EsgotoAnimacao.vento(t: number, semente: number): number
	local n = math.noise(t * 2.3, semente, 0) * 0.9 + math.noise(t * 6.7, semente, 5.3) * 0.5
	local sopro = math.noise(t * 0.45, semente, 9.1)
	if sopro > 0.32 then n -= (sopro - 0.32) * 2.2 end
	return n
end

-- A peça pode chegar ao cliente antes dos filhos (Texture, luz): registra os que existem e os que vierem.
local function registrarTextura(t: Instance)
	if t:IsA("Texture") then texturas[t] = { t:GetAttribute("VelU") or 0, t:GetAttribute("VelV") or 0 } end
end

local function registrarAgua(parte: Instance)
	for _, t in parte:GetChildren() do registrarTextura(t) end
	parte.ChildAdded:Connect(registrarTextura)
end

local function esquecerAgua(parte: Instance)
	for _, t in parte:GetChildren() do texturas[t] = nil end
end

local function luzDaTocha(chama: Instance, l: Instance)
	if l:IsA("PointLight") then
		tochas[chama] = { l, l:GetAttribute("BrilhoBase") or l.Brightness, l:GetAttribute("AlcanceBase") or l.Range, chama:GetAttribute("Semente") or 0 }
	end
end

local function registrarTocha(chama: Instance)
	for _, l in chama:GetChildren() do luzDaTocha(chama, l) end
	chama.ChildAdded:Connect(function(l) luzDaTocha(chama, l) end)
end

local function gotejar(origem: Instance)
	local gota = origem:FindFirstChild("Gota")
	local respingo = origem:FindFirstChild("Chao") and origem.Chao:FindFirstChild("Respingo")
	if not (gota and respingo) then return end
	gota:Emit(1)
	local queda = gota.Lifetime.Min
	task.delay(queda, function()
		if respingo.Parent then respingo:Emit(7) end
	end)
end

function EsgotoAnimacao.start()
	if iniciado then return end
	iniciado = true
	CollectionService:GetInstanceAddedSignal(TAG_AGUA):Connect(registrarAgua)
	CollectionService:GetInstanceRemovedSignal(TAG_AGUA):Connect(esquecerAgua)
	CollectionService:GetInstanceAddedSignal(TAG_TOCHA):Connect(registrarTocha)
	CollectionService:GetInstanceRemovedSignal(TAG_TOCHA):Connect(function(c) tochas[c] = nil end)
	CollectionService:GetInstanceAddedSignal(TAG_GOTA):Connect(function(o) gotas[o] = { proxima = 0 } end)
	CollectionService:GetInstanceRemovedSignal(TAG_GOTA):Connect(function(o) gotas[o] = nil end)
	for _, p in CollectionService:GetTagged(TAG_AGUA) do registrarAgua(p) end
	for _, p in CollectionService:GetTagged(TAG_TOCHA) do registrarTocha(p) end
	for _, p in CollectionService:GetTagged(TAG_GOTA) do gotas[p] = { proxima = 0 } end

	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		if next(texturas) == nil and next(tochas) == nil and next(gotas) == nil then return end
		acumulado += dt
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local foco = camera and camera.CFrame.Position
		for tex, v in texturas do
			local tile = tex.StudsPerTileU
			tex.OffsetStudsU = (acumulado * v[1]) % tile
			tex.OffsetStudsV = (acumulado * v[2]) % tex.StudsPerTileV
		end
		for chama, d in tochas do
			local n = EsgotoAnimacao.vento(t, d[4])
			d[1].Brightness = math.max(0.6, d[2] * (1 + 0.38 * n))
			d[1].Range = d[3] * (1 + 0.08 * n)
			chama.Size = Vector3.new(1.4, 2 * (1 + 0.25 * n), 1.4)
		end
		for origem, d in gotas do
			if t >= d.proxima then
				d.proxima = t + 1.2 + math.random() * 3.2
				if not foco or (origem.Position - foco).Magnitude < DISTANCIA_MAX then gotejar(origem) end
			end
		end
	end)
end

return EsgotoAnimacao
