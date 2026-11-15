-- Porta do esgoto na vila (DIRECAO §4): um marco com ProximityPrompt na borda da praça. Nenhuma decisão
-- de jogo aqui: o servidor só avisa o cliente ("porta") e a run (RunServico) valida a votação pela distância
-- ao ponto da porta. Sem run ativa, o jogador recebe um aviso.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VilaLayout = require(ReplicatedStorage.Shared.Mundo.VilaLayout)

local Porta = {}

Porta.AREA = "esgoto"
Porta.ALCANCE_PROMPT = 10 -- studs
Porta.ALCANCE_VOTO = 20 -- studs: distância máxima do avatar à porta para votar entrar/retomar
local FOLGA = 2.5 -- studs livres entre a porta e qualquer construção/adereço
local TAMANHO = { x = 6, z = 1.5 } -- placa da porta

local function retangulos()
	local lista = {}
	for _, e in VilaLayout.predios() do
		local o = VilaLayout.ocupacao(e)
		-- Os NPCs ficam 4 studs à frente das portas dos prédios.
		table.insert(lista, { x = o.x, z = o.z, sx = o.sx + 8, sz = o.sz + 8 })
	end
	for _, b in VilaLayout.BARRACAS do
		local r = VilaLayout.pegadaBarraca(b)
		table.insert(lista, r)
	end
	for _, prop in VilaLayout.DECORACAO do
		for _, r in VilaLayout.pegadasDecoracao(prop, function(p)
			local lado = 4 * (p[4] or 1)
			return { x = p[1], z = p[2], sx = lado, sz = lado }
		end) do table.insert(lista, r) end
	end
	for _, p in VilaLayout.POSTES do table.insert(lista, { x = p.x, z = p.z, sx = 2, sz = 2 }) end
	for _, a in VilaLayout.ACESSOS do table.insert(lista, a) end
	table.insert(lista, VilaLayout.ESTRADA)
	table.insert(lista, VilaLayout.CHAFARIZ)
	table.insert(lista, VilaLayout.POCO_QUINTAL)
	table.insert(lista, { x = VilaLayout.ESPELHO.x, z = VilaLayout.ESPELHO.z, sx = 12, sz = 12 })
	table.insert(lista, { x = VilaLayout.NASCIMENTO.x, z = VilaLayout.NASCIMENTO.z, sx = 4, sz = 4 })
	return lista
end

-- Escolhe o ponto livre da praça mais perto da borda (grade de 2 studs, determinístico); nil se não houver.
function Porta.escolherPonto()
	local p = VilaLayout.PRACA
	local candidatos = {}
	for dx = -p.sx / 2, p.sx / 2, 2 do
		for dz = -p.sz / 2, p.sz / 2, 2 do
			table.insert(candidatos, { x = p.x + dx, z = p.z + dz, borda = math.max(math.abs(dx), math.abs(dz)) })
		end
	end
	table.sort(candidatos, function(a, b)
		if a.borda ~= b.borda then return a.borda > b.borda end
		if a.z ~= b.z then return a.z < b.z end
		return a.x < b.x
	end)
	local obstaculos = retangulos()
	for _, c in candidatos do
		local ret = { x = c.x, z = c.z, sx = TAMANHO.x + 2 * FOLGA, sz = TAMANHO.x + 2 * FOLGA }
		local livre = true
		for _, o in obstaculos do
			if VilaLayout.sobrepoe(ret, o) then livre = false; break end
		end
		if livre then return { x = c.x, z = c.z } end
	end
	return nil
end

local ponto -- { x, z, y } do marco criado
local parte
local prompt
local ativa = true -- o prompt aparece? (definido pelo servidor da run; vale também antes de start())

-- Liga/desliga o ProximityPrompt da porta (o servidor chama ao transmitir a run: só no hub ou sem run ativa).
function Porta.definirAtiva(valor)
	ativa = valor == true
	if prompt then prompt.Enabled = ativa end
end

-- Posição (Vector3) da porta; nil antes de start().
function Porta.ponto()
	return parte and parte.Parent and parte.Position or nil
end

-- A porta e o avatar estão perto o bastante para entrar/retomar? Lê só posições do servidor.
function Porta.pertoDe(player)
	local alvo = Porta.ponto()
	local raiz = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not alvo or not raiz or not raiz:IsA("BasePart") then return false end
	return (Vector3.new(raiz.Position.X, 0, raiz.Position.Z) - Vector3.new(alvo.X, 0, alvo.Z)).Magnitude <= Porta.ALCANCE_VOTO
end

-- deps = { remote = RemoteEvent "RunJogo", temRun = function() -> bool, avisar = function(player, texto) }
function Porta.start(deps)
	assert(type(deps) == "table" and deps.remote and type(deps.temRun) == "function" and type(deps.avisar) == "function", "Dependências da porta inválidas")
	ponto = Porta.escolherPonto() or { x = VilaLayout.PRACA.x, z = VilaLayout.PRACA.z - VilaLayout.PRACA.sz / 2 + 2 }
	local vila = workspace:FindFirstChild("Vila")
	parte = Instance.new("Part")
	parte.Name = "PortaDoEsgoto"
	parte.Anchored = true
	parte.Size = Vector3.new(TAMANHO.x, 7, TAMANHO.z)
	parte.Position = Vector3.new(ponto.x, 3.5, ponto.z)
	parte.Material = Enum.Material.Slate
	parte.Color = Color3.fromRGB(58, 62, 58)
	parte:SetAttribute("Area", Porta.AREA)
	prompt = Instance.new("ProximityPrompt")
	prompt.Enabled = ativa
	prompt.Name = "Entrar no esgoto"
	prompt.ActionText = "Entrar no esgoto"
	prompt.ObjectText = "Esgoto da cidade"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = Porta.ALCANCE_PROMPT
	prompt.RequiresLineOfSight = false
	prompt.Parent = parte
	parte.Parent = vila or workspace
	local ultimo = {}
	prompt.Triggered:Connect(function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return end
		local agora = os.clock()
		if ultimo[player.UserId] and agora - ultimo[player.UserId] < 1 then return end
		ultimo[player.UserId] = agora
		if not deps.temRun() then
			deps.avisar(player, "Inicie a campanha antes de descer ao esgoto.")
			return
		end
		deps.remote:FireClient(player, "porta", { area = Porta.AREA })
	end)
	Players.PlayerRemoving:Connect(function(player) ultimo[player.UserId] = nil end)
	return Porta
end

return Porta
