-- O avatar é a ficha (pedido do Pedro, docs/PLANO.md): a primeira ficha de
-- jogador de cada jogador presente usa o próprio avatar do Roblox no tabuleiro.
-- O servidor ancora o avatar na casa da ficha e o faz andar até a casa nova,
-- com a animação de caminhada do próprio avatar. NPCs continuam miniaturas.
--
-- Sigilo (revisão do Codex): a posição de um personagem replica para todos e
-- pode ser lida por um cliente modificado. Então ficha SECRETA (oculta ou na
-- névoa) nunca usa o avatar: ele é estacionado no bastidor, fora do tabuleiro,
-- e o mestre e o dono veem a miniatura na casa certa (só no cliente deles).
-- Só fichas de JOGADOR viram avatar; NPCs do mestre são sempre miniatura.
-- Várias fichas do mesmo jogador: só a primeira (ordem da mesa) vira avatar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Visao = require(game.ReplicatedStorage.Shared.VisaoFurtiva)
local function caido(t)
	if t.derrotado or (t.pv ~= nil and t.pv <= 0) then return true end
	for _, c in t.conditions or {} do if c.id == "caido" or c.id == "inconsciente" then return true end end
	return false
end

local AvatarFichas = {}

local VELOCIDADE = 14 -- studs por segundo ao andar entre casas

-- deps:
--   fichas(): lista ordenada das fichas (tabelas do servidor)
--   centro(x, z): Vector3 do centro da casa, na superfície do tabuleiro
--   secreto(ficha): true se a ficha está oculta ou na névoa
--   bastidor(i): Vector3 no chão do salão, fora do tabuleiro, para estacionar
function AvatarFichas.start(deps)
	local vinculos: { [Player]: string } = {} -- jogador -> id da ficha (pública)
	local estacionados: { [Player]: any } = {} -- estacionamento aplicado, com raiz e posição
	local destinos: { [Player]: any } = {} -- destino aplicado, inclusive durante caminhada
	local caminhadas: { [Player]: { conexao: RBXScriptConnection, trilha: AnimationTrack? } } = {}
	local poses = {}
	-- Inclina só o corpo, preservando a raiz vertical da câmera e do Humanoid.
	local function posarCorpo(player, root, deitado)
		local p = poses[player]
		if not p or p.root ~= root then
			if p and p.joint.Parent then if p.tween then p.tween:Cancel() end; p.joint[p.propriedade] = p.original end
			p = nil
			for _, j in root.Parent:GetDescendants() do
				if j:IsA("Motor6D") and j.Part0 == root and j.Part1 then p = {root=root,joint=j,propriedade="C0",original=j.C0}; break end
				if j:IsA("AnimationConstraint") or j:IsA("RigidConstraint") then
					local a0, a1 = j.Attachment0, j.Attachment1
					local a = if a0 and a0.Parent == root then a0 elseif a1 and a1.Parent == root then a1 else nil
					if a then p = {root=root,joint=a,propriedade="CFrame",original=a.CFrame}; break end
				end
			end
			poses[player] = p
		end
		if not p or p.deitado == deitado then return end
		p.deitado = deitado
		if p.tween then p.tween:Cancel() end
		p.tween = TweenService:Create(p.joint, TweenInfo.new(.3, Enum.EasingStyle.Quad), {[p.propriedade] = (if deitado then CFrame.Angles(-math.pi/2,0,0) else CFrame.identity) * p.original})
		p.tween:Play()
	end

	local function raiz(player: Player): (BasePart?, Humanoid?)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			return root, humanoid
		end
		return nil, nil
	end

	-- Altura do HumanoidRootPart para os pés tocarem o tabuleiro.
	local function poseNaCasa(root: BasePart, humanoid: Humanoid, x: number, z: number, token): CFrame
		local centro = deps.centro(x, z)
		local deitado = token and caido(token)
		local posicao = centro + Vector3.new(0, if deitado then .85 else humanoid.HipHeight + root.Size.Y / 2, 0)
		local dx, dz = 0, -1
		if token then dx, dz = Visao.direcao(token) end
		local base = CFrame.lookAt(posicao, posicao + Vector3.new(dx, 0, dz))
		return base
	end

	local function pararCaminhada(player: Player)
		local caminhada = caminhadas[player]
		if caminhada then
			caminhada.conexao:Disconnect()
			if caminhada.trilha then
				caminhada.trilha:Stop(0.2)
			end
			caminhadas[player] = nil
		end
	end

	local function soltar(player: Player)
		pararCaminhada(player)
		local p = poses[player]
		if p then if p.tween then p.tween:Cancel() end; if p.joint.Parent then p.joint[p.propriedade] = p.original end; poses[player] = nil end
		vinculos[player] = nil
		estacionados[player] = nil
		destinos[player] = nil
		local root = raiz(player)
		if root then
			local v = root.CFrame.LookVector
			local dir = Vector3.new(v.X, 0, v.Z)
			if dir.Magnitude < .01 then dir = -Vector3.zAxis end
			root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
			root.Anchored = false
		end
	end

	-- Animação de caminhada do próprio avatar (objeto do script Animate do personagem).
	local function trilhaDeCaminhada(humanoid: Humanoid): AnimationTrack?
		local animate = humanoid.Parent and humanoid.Parent:FindFirstChild("Animate")
		local walk = animate and animate:FindFirstChild("walk")
		local animacao = walk and walk:FindFirstChildOfClass("Animation")
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animacao or not animator then
			return nil
		end
		local ok, trilha = pcall(function()
			return animator:LoadAnimation(animacao)
		end)
		if ok and trilha then
			trilha.Priority = Enum.AnimationPriority.Movement
			return trilha
		end
		return nil
	end

	-- Anda do ponto atual até a casa (x, z), ancorado, com a animação de caminhada.
	local function andar(player: Player, x: number, z: number, token)
		local root, humanoid = raiz(player)
		if not root or not humanoid then
			return
		end
		-- Pedidos consecutivos terminam a etapa anterior antes de iniciar a próxima.
		-- Interpolar do meio da primeira rota até o fim da segunda cortava muros.
		local anterior = destinos[player]
		if caminhadas[player] and anterior and anterior.token and (anterior.x ~= x or anterior.z ~= z) then
			root.CFrame = poseNaCasa(root, humanoid, anterior.x, anterior.z, anterior.token)
		end
		pararCaminhada(player)
		root.Anchored = true
		destinos[player] = { root = root, x = x, z = z, caido = caido(token), dx = token.olharX, dz = token.olharZ, token = table.clone(token) }
		local inicio = root.CFrame
		posarCorpo(player, root, caido(token))
		local destino = poseNaCasa(root, humanoid, x, z, token)
		local distancia = (destino.Position - inicio.Position).Magnitude
		
		local final = destino
		local duracao = math.clamp(distancia / VELOCIDADE, 0.25, 3)
		local trilha = if distancia > .05 and not caido(token) then trilhaDeCaminhada(humanoid) else nil
		if trilha then
			trilha:Play(0.15)
		end
		local comeco = os.clock()
		local conexao
		conexao = RunService.Heartbeat:Connect(function()
			if root.Parent == nil then
				pararCaminhada(player)
				return
			end
			local t = math.min((os.clock() - comeco) / duracao, 1)
			root.CFrame = inicio:Lerp(final, 1 - (1 - t) ^ 2)
			if t >= 1 then
				pararCaminhada(player)
			end
		end)
		caminhadas[player] = { conexao = conexao, trilha = trilha }
	end

	-- Leva o avatar ao bastidor, sem caminhar: a rota revelaria a casa de origem.
	local function estacionar(player: Player, indice: number): boolean
		local root, humanoid = raiz(player)
		if not root or not humanoid then
			return false
		end
		pararCaminhada(player)
		root.Anchored = true
		local base = deps.bastidor(indice)
		root.CFrame = CFrame.new(base + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		return true
	end

	-- Recalcula quem está vinculado a qual ficha e ajeita os avatares.
	local function sincronizar()
		if deps.ativo and not deps.ativo() then
			for player in vinculos do soltar(player) end
			for player in estacionados do soltar(player) end
			return
		end
		local desejado: { [Player]: any } = {}
		for _, token in deps.fichas() do
			if token.kind == "jogador" and token.ownerUserId and token.ownerUserId ~= 0 then
				local player = Players:GetPlayerByUserId(token.ownerUserId)
				if player and not desejado[player] then
					desejado[player] = token
				end
			end
		end
		for player in vinculos do
			if not desejado[player] then
				soltar(player)
			end
		end
		for player in estacionados do
			if not desejado[player] then
				soltar(player)
			end
		end
		local indice = 0
		for player, token in desejado do
			if deps.secreto(token) then
				-- Ficha secreta: avatar fora do tabuleiro; a miniatura (local) assume.
				indice += 1
				vinculos[player] = nil
				destinos[player] = nil
				local root = raiz(player)
				local anterior = estacionados[player]
				if not anterior or anterior.id ~= token.id or anterior.root ~= root
					or anterior.indice ~= indice or not root or not root.Anchored then
					-- Não guardar sucesso antes de existir um personagem utilizável.
					pararCaminhada(player)
					estacionados[player] = nil
					if estacionar(player, indice) then
						estacionados[player] = { id = token.id, root = root, indice = indice }
					end
				end
				continue
			end
			estacionados[player] = nil
			local anterior = vinculos[player]
			vinculos[player] = token.id
			local root, humanoid = raiz(player)
			if root and humanoid then
				local destino = destinos[player]
				if anterior ~= token.id or not root.Anchored or not destino
					or destino.root ~= root or destino.x ~= token.x or destino.z ~= token.z
					or destino.caido ~= caido(token) or destino.dx ~= token.olharX or destino.dz ~= token.olharZ then
					-- Novo estado invalida a rota anterior; broadcasts iguais não a reiniciam.
					andar(player, token.x, token.z, token)
				end
			end
		end
	end

	local api = {}

	function api.sincronizar()
		sincronizar()
	end

	-- A ficha mudou de casa: se for avatar, ele anda até lá.
	function api.moveu(token)
		-- Entrou na névoa ou está oculta: nem começa a andar (a rota revelaria a casa).
		if deps.secreto(token) then
			return
		end
		for player, id in vinculos do
			if id == token.id then
				andar(player, token.x, token.z, token)
			end
		end
	end

	-- Ficha usa avatar? (para o snapshot)
	function api.ehAvatar(token): boolean
		for _, id in vinculos do
			if id == token.id then
				return true
			end
		end
		return false
	end

	function api.donosVinculados(): { number }
		local lista = {}
		for player in vinculos do
			table.insert(lista, player.UserId)
		end
		for player in estacionados do
			table.insert(lista, player.UserId)
		end
		table.sort(lista)
		return lista
	end

	local function aoPersonagem(player: Player)
		player.CharacterAdded:Connect(function(character)
			pararCaminhada(player)
			vinculos[player] = nil -- personagem novo: refaz o vínculo
			estacionados[player] = nil
			destinos[player] = nil
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Humanoid", 10)
			if player.Character == character then
				task.defer(sincronizar)
			end
		end)
	end
	Players.PlayerAdded:Connect(aoPersonagem)
	for _, player in Players:GetPlayers() do
		aoPersonagem(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		soltar(player)
	end)

	return api
end

return AvatarFichas
