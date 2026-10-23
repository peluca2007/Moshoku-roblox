-- Apresenta no mundo as posições já confirmadas pelo estado J2 do servidor.
-- As miniaturas são visuais: não colidem, não recebem comandos e não alteram regras.
local RunService = game:GetService("RunService")
local Geometria = require(script.Parent.EncontroAutonomoGeometria)
local Modelos = require(game:GetService("ReplicatedStorage").Shared.Mundo.ModelosCriaturas)
local CriaturaAnimada = require(script.Parent.Mundo.CriaturaAnimada)
local EncontroAutonomoMiniaturas = {}

-- Ações que não são golpe: o ator só anda, passa a vez ou foge.
local SEM_GOLPE = { ["move"] = true, ["creature-move"] = true, ["spend-action"] = true, ["flee-encounter"] = true, ["defend"] = true }
local VELOCIDADE_ANDAR = 7 -- studs/s entre casas (visual)

local function parte(parent, name, size, color, shape)
	local item = Instance.new("Part")
	item.Name = name
	item.Shape = shape or Enum.PartType.Block
	item.Size = size
	item.Color = color
	item.Material = Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function criarSilhueta(pasta, nome, x, z, tipo, cor)
	local base = parte(pasta, nome .. "_Base", Vector3.new(0.16, 1.15, 1.15), cor, Enum.PartType.Cylinder)
	base.Orientation = Vector3.new(0, 0, 90)
	base.Position = Vector3.new(x, 0.08, z)

	local function peca(sufixo, tamanho, deslocamento, forma, corPeca)
		local item = parte(pasta, nome .. "_" .. sufixo, tamanho, corPeca or cor, forma)
		item.Position = Vector3.new(x + deslocamento.X, deslocamento.Y, z + deslocamento.Z)
		return item
	end

	local principal
	if tipo == "lobo" then
		local tronco = peca("Corpo", Vector3.new(1.05, 0.62, 0.48), Vector3.new(0, 0.72, 0), Enum.PartType.Ball)
		principal = tronco
		tronco.Orientation = Vector3.new(0, 0, 90)
		peca("Cabeca", Vector3.new(0.48, 0.46, 0.42), Vector3.new(0.34, 1.03, 0), Enum.PartType.Ball)
		peca("Focinho", Vector3.new(0.38, 0.24, 0.28), Vector3.new(0.62, 0.91, 0), Enum.PartType.Ball, Color3.fromRGB(202, 183, 156))
		for indice, pos in ipairs({
			Vector3.new(-0.32, 0.3, -0.19), Vector3.new(-0.32, 0.3, 0.19),
			Vector3.new(0.32, 0.3, -0.19), Vector3.new(0.32, 0.3, 0.19),
		}) do
			peca("Pata" .. indice, Vector3.new(0.2, 0.52, 0.2), pos, Enum.PartType.Cylinder)
		end
	elseif tipo == "treant" then
		principal = peca("Tronco", Vector3.new(0.66, 1.22, 0.66), Vector3.new(0, 0.88, 0), Enum.PartType.Cylinder,
			Color3.fromRGB(112, 78, 49))
		peca("Copa", Vector3.new(1.15, 0.76, 1.05), Vector3.new(0, 1.57, 0), Enum.PartType.Ball,
			Color3.fromRGB(68, 119, 65))
		for indice, lado in ipairs({ -1, 1 }) do
			local braco = peca("Galho" .. indice, Vector3.new(0.22, 0.92, 0.22),
				Vector3.new(lado * 0.55, 1.12, 0), Enum.PartType.Cylinder, Color3.fromRGB(112, 78, 49))
			braco.Orientation = Vector3.new(0, 0, lado * -35)
		end
	else
		-- Silhueta humanoide para goblins e personagens: cabeça, tronco e braços.
		local goblin = tipo == "goblin"
		local corpo = if goblin then Color3.fromRGB(91, 142, 73) else cor
		principal = peca("Tronco", Vector3.new(0.58, 0.72, 0.42), Vector3.new(0, 0.91, 0), Enum.PartType.Block,
			if goblin then Color3.fromRGB(91, 72, 55) else corpo)
		peca("Cabeca", Vector3.new(0.48, 0.48, 0.48), Vector3.new(0, 1.54, 0), Enum.PartType.Ball, corpo)
		for indice, lado in ipairs({ -1, 1 }) do
			local braco = peca("Braco" .. indice, Vector3.new(0.19, 0.68, 0.2),
				Vector3.new(lado * 0.4, 0.9, 0), Enum.PartType.Cylinder, corpo)
			braco.Orientation = Vector3.new(0, 0, lado * 12)
			peca("Perna" .. indice, Vector3.new(0.22, 0.56, 0.24),
				Vector3.new(lado * 0.17, 0.35, 0), Enum.PartType.Cylinder, corpo)
		end
		if goblin then
			for indice, lado in ipairs({ -1, 1 }) do
				local orelha = peca("Orelha" .. indice, Vector3.new(0.42, 0.18, 0.18),
					Vector3.new(lado * 0.34, 1.65, 0), Enum.PartType.Wedge, corpo)
				orelha.Orientation = Vector3.new(0, 0, lado * -12)
			end
		end
	end
	principal = principal or base
	principal.Name = nome
	return principal
end

local function tipoVisual(ator)
	if ator.kind ~= "criatura" or type(ator.name) ~= "string" then return "humanoide" end
	local nome = string.lower(ator.name)
	if string.find(nome, "lobo", 1, true) then return "lobo" end
	if string.find(nome, "treant", 1, true) then return "treant" end
	if string.find(nome, "goblin", 1, true) then return "goblin" end
	return "criatura"
end

local function nomeSeguro(id)
	return (string.gsub(id, "[^%w%-_]", "_"))
end

local function maisProximo(pos, lista)
	local melhor, dist = nil, math.huge
	for _, p in ipairs(lista) do
		local d = (p - pos).Magnitude
		if d < dist then melhor, dist = p, d end
	end
	return melhor
end

function EncontroAutonomoMiniaturas.start(deps)
	deps = deps or {}
	local workspaceAtual = deps.workspace or workspace
	local pastas = {}
	local api = {}
	-- Criaturas com modelo do Blender: encounterId -> actorId -> entrada animada (persiste entre renders).
	local entradas = {}
	local conexao

	local function chaoEm(x, z)
		local ok, y = pcall(function()
			local terreno = workspaceAtual:FindFirstChildOfClass("Terrain")
			if not terreno then return nil end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { terreno }
			local r = workspaceAtual:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
			return if r then r.Position.Y else nil
		end)
		return if ok and y then y else 0
	end

	local function vazio()
		for _, mapa in entradas do if next(mapa) ~= nil then return false end end
		return true
	end

	local function suavizar(atual, alvo, k)
		local v = atual:Lerp(alvo, math.clamp(k, 0, 1))
		return if v.Magnitude < 0.05 then alvo else v.Unit
	end

	local function passo(dt)
		local agora = os.clock()
		for _, mapa in entradas do
			for _, e in mapa do
				if not e.anim.modelo then continue end
				local delta = Vector3.new(e.alvoPos.X - e.pos.X, 0, e.alvoPos.Z - e.pos.Z)
				local andando = delta.Magnitude > 0.05
				local direcao = e.dir
				if andando then
					local avanco = math.min(delta.Magnitude, VELOCIDADE_ANDAR * dt)
					local novo = e.pos + delta.Unit * avanco
					e.pos = Vector3.new(novo.X, e.alvoPos.Y, novo.Z)
					direcao = delta.Unit
				elseif e.olhar then
					local para = Vector3.new(e.olhar.X - e.pos.X, 0, e.olhar.Z - e.pos.Z)
					if para.Magnitude > 0.1 then direcao = para.Unit end
				end
				e.dir = suavizar(e.dir, direcao, dt * 9)
				local cf = CFrame.lookAt(e.pos, e.pos + e.dir)
				e.anim:atualizar(dt, cf, andando, VELOCIDADE_ANDAR, e.olhar, agora)
			end
		end
	end

	local function garantirRelogio()
		if conexao then return end
		local fonte = deps.heartbeat or RunService.Heartbeat
		local acumulado = 0
		conexao = fonte:Connect(function(dt)
			acumulado += dt
			if acumulado < 0.05 then return end
			local d = acumulado; acumulado = 0
			passo(d)
		end)
	end

	local function soltarRelogio()
		if conexao and vazio() then conexao:Disconnect(); conexao = nil end
	end

	-- Criatura com modelo do Blender: mantém/atualiza a entrada animada e devolve o token invisível
	-- (peça direta `Ator_<id>`, lida pelo cliente para etiqueta, seleção e centro da grade).
	-- Devolve nil quando não há modelo: o chamador cai na silhueta antiga.
	local function tokenDoModelo(pasta, mapa, ator, nomeToken, x, z, cor, ultimaAcao, posicaoMundo, jogadoresMundo)
		if ator.kind ~= "criatura" or type(ator.criaturaId) ~= "string" then return nil end
		local indice = tonumber(string.match(ator.id, "(%d+)$")) or 0
		local info = Modelos.escolher(ator.criaturaId, indice)
		if not info then return nil end
		local chao = chaoEm(x, z)
		local alvoPos = Vector3.new(x, chao, z)
		local e = mapa[ator.id]
		if e and e.anim:caiu() then return nil end
		if not e then
			local anim = CriaturaAnimada.montar(info, pasta, CFrame.new(alvoPos), info.escalaCombate)
			if not anim then return nil end
			anim.modelo.Name = "Criatura_" .. nomeSeguro(ator.id)
			anim.modelo:SetAttribute("CriaturaAnimada", true)
			local tam = anim:tamanho()
			e = {
				anim = anim, pos = alvoPos, alvoPos = alvoPos, dir = Vector3.new(0, 0, -1), tam = tam,
				ultimoPedido = if ultimaAcao then ultimaAcao.requestId else nil,
			}
			mapa[ator.id] = e
			local primeiro = maisProximo(alvoPos, jogadoresMundo)
			if primeiro then
				local para = Vector3.new(primeiro.X - x, 0, primeiro.Z - z)
				if para.Magnitude > 0.1 then e.dir = para.Unit end
			end
			anim:atualizar(0, CFrame.lookAt(alvoPos, alvoPos + e.dir), false, 0, nil)
			garantirRelogio()
		end
		e.alvoPos = alvoPos
		e.olhar = maisProximo(alvoPos, jogadoresMundo)
		if ultimaAcao and ultimaAcao.actorId == ator.id and ultimaAcao.requestId ~= e.ultimoPedido
			and not SEM_GOLPE[ultimaAcao.action]
		then
			e.ultimoPedido = ultimaAcao.requestId
			local alvoGolpe = posicaoMundo[ultimaAcao.targetId]
			if alvoGolpe then e.olhar = alvoGolpe + Vector3.new(0, 2.5, 0) end
			e.anim:golpear()
		end
		local tam = e.tam
		local pegada = math.clamp((tam.X + tam.Z) / 2, 1.5, 6)
		local token = Instance.new("Part")
		token.Name, token.Size, token.Transparency = nomeToken, Vector3.new(pegada, tam.Y, pegada), 1
		token.Anchored, token.CanCollide, token.CanTouch, token.CanQuery = true, false, false, false
		token.Position = Vector3.new(x, chao + tam.Y / 2, z)
		token:SetAttribute("AlturaEtiqueta", tam.Y / 2 + 1.6)
		token.Parent = pasta
		local anel = Instance.new("Part")
		anel.Name, anel.Shape, anel.Size = nomeToken .. "_Base", Enum.PartType.Cylinder, Vector3.new(0.14, pegada * 0.95, pegada * 0.95)
		anel.Orientation, anel.Position = Vector3.new(0, 0, 90), Vector3.new(x, chao + 0.08, z)
		anel.Color, anel.Material, anel.Transparency = cor, Enum.Material.Neon, 0.45
		anel.Anchored, anel.CanCollide, anel.CanTouch, anel.CanQuery = true, false, false, false
		anel.Parent = pasta
		return token
	end

	local function obterCentro(areaId)
		local id = areaId or "region/encounter/clearing"
		for _, item in ipairs(workspaceAtual:GetDescendants()) do
			if item:IsA("BasePart") and item:GetAttribute("AreaRole") == "encounter-trigger"
				and item:GetAttribute("EncounterId") == id
			then return Geometria.centro(item) end
		end
		return nil
	end

	function api.render(encounterId, atores, atorAtualId, phase, areaId, ultimaAcao)
		if type(encounterId) ~= "string" or #encounterId == 0 or #encounterId > 96
			or type(atores) ~= "table" or #atores > 16
		then
			return false
		end
		local marco = obterCentro(areaId)
		if not marco then return false end

		local pasta = pastas[encounterId]
		if not pasta or pasta.Parent == nil then
			pasta = Instance.new("Folder")
			pasta.Name = "MiniaturasJ2_" .. nomeSeguro(encounterId)
			pasta:SetAttribute("EncounterId", encounterId)
			pasta.Parent = workspaceAtual
			pastas[encounterId] = pasta
		end
		-- Mantém os modelos animados entre renders; recria só as peças auxiliares (tokens/silhuetas).
		for _, filho in ipairs(pasta:GetChildren()) do
			if not filho:GetAttribute("CriaturaAnimada") then filho:Destroy() end
		end
		local mapa = entradas[encounterId]
		if not mapa then mapa = {}; entradas[encounterId] = mapa end
		local vistos = {}
		local posicaoMundo = {}
		local jogadoresMundo = {}
		for _, ator in ipairs(atores) do
			if type(ator) == "table" and type(ator.id) == "string" and type(ator.x) == "number" and type(ator.z) == "number" then
				local p = Geometria.posicao(marco, ator.x, ator.z)
				if p then
					local pos = Vector3.new(p.X, 0, p.Z)
					posicaoMundo[ator.id] = pos
					if ator.kind == "jogador" and ator.downed ~= true then table.insert(jogadoresMundo, pos + Vector3.new(0, 2.5, 0)) end
				end
			end
		end

		for _, ator in ipairs(atores) do
			if type(ator) ~= "table" or type(ator.id) ~= "string"
				or type(ator.x) ~= "number" or type(ator.z) ~= "number"
				or ator.x % 1 ~= 0 or ator.z % 1 ~= 0
				or ator.x < 1 or ator.x > 20 or ator.z < 1 or ator.z > 20
			then
				continue
			end
			if ator.kind == "criatura" and ator.defeated == true then
				local caida = mapa[ator.id]
				if caida and not caida.anim:caiu() then
					caida.anim:cair()
					vistos[ator.id] = true
					task.delay(1.8, function()
						caida.anim:destruir()
						if mapa[ator.id] == caida then mapa[ator.id] = nil end
						soltarRelogio()
					end)
				elseif caida then
					vistos[ator.id] = true
				end
				continue
			end

			local ativa = ator.id == atorAtualId and phase == "active"
			local cor = if ativa then Color3.fromRGB(236, 183, 71)
				elseif ator.downed == true then Color3.fromRGB(108, 72, 72)
				elseif ator.kind == "criatura" then Color3.fromRGB(167, 72, 64)
				else Color3.fromRGB(65, 119, 164)
			local nomeToken = "Ator_" .. nomeSeguro(ator.id)
			local posicao = Geometria.posicao(marco, ator.x, ator.z)
			if not posicao then continue end
			local x, z = posicao.X, posicao.Z
			local token = tokenDoModelo(pasta, mapa, ator, nomeToken, x, z, cor, ultimaAcao, posicaoMundo, jogadoresMundo)
			if token then vistos[ator.id] = true
			else token = criarSilhueta(pasta, nomeToken, x, z, tipoVisual(ator), cor) end
			token:SetAttribute("ActorId", ator.id)
			token:SetAttribute("Kind", ator.kind)
			token:SetAttribute("Active", ativa)
			local etiqueta = Instance.new("BillboardGui")
			etiqueta.Name = "Estado"
			etiqueta.Size = UDim2.fromOffset(112, 34)
			etiqueta.StudsOffset = Vector3.new(0, 1.2, 0)
			etiqueta.AlwaysOnTop = true
			etiqueta.MaxDistance = 90
			etiqueta.Adornee = token
			etiqueta.Parent = token
			local texto = Instance.new("TextLabel")
			texto.BackgroundColor3 = Color3.fromRGB(30, 28, 24)
			texto.BackgroundTransparency = 0.18
			texto.Size = UDim2.fromScale(1, 1)
			texto.Font = Enum.Font.GothamSemibold
			texto.TextColor3 = Color3.fromRGB(255, 248, 225)
			texto.TextScaled = true
			texto.TextWrapped = true
			local nome = if type(ator.name) == "string" then string.sub(ator.name, 1, 24) else "Ator"
			local pv = if type(ator.pv) == "number" then tostring(math.max(0, math.floor(ator.pv))) else "?"
			local pvMax = if type(ator.pvMax) == "number" then tostring(math.max(0, math.floor(ator.pvMax))) else "?"
			texto.Text = nome .. "  " .. pv .. "/" .. pvMax
			texto.Parent = etiqueta
		end
		-- Modelos de atores que saíram do encontro (ex.: fuga) não ficam órfãos.
		for id, e in mapa do
			if not vistos[id] then
				e.anim:destruir()
				mapa[id] = nil
			end
		end
		if vazio() then soltarRelogio() end
		return true
	end

	function api.limpar(encounterId)
		local mapa = entradas[encounterId]
		if mapa then
			for _, e in mapa do e.anim:destruir() end
			entradas[encounterId] = nil
		end
		soltarRelogio()
		local pasta = pastas[encounterId]
		if pasta then pasta:Destroy(); pastas[encounterId] = nil end
		return true
	end

	return api
end

return EncontroAutonomoMiniaturas
