-- Prévia das casas vigiadas. Usa somente inimigos visíveis do snapshot filtrado.
local Shared = game.ReplicatedStorage.Shared
local Protocol = require(Shared.MesaProtocol)
local Visao = require(Shared.VisaoFurtiva)
local Estilo = require(Shared.Estilo)
local Previa = require(script.Parent.PreviaFurtiva)
local V = {}
function V.start(state)
	local board = Protocol.BOARD
	local cores = {Color3.fromRGB(255,190,75),Color3.fromRGB(110,195,255),Color3.fromRGB(218,140,255),Color3.fromRGB(255,125,150)}

	local visoes = Instance.new("Folder", workspace); visoes.Name = "VisaoFurtivaLocal"
	local function linha(a, b, cor, nome)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = nome, true, false, false, false, false
		p.Size, p.CFrame = Vector3.new(.16,.1,(b-a).Magnitude), CFrame.lookAt((a+b)/2,b)
		p.Material, p.Color = Enum.Material.Neon, cor
		p.Parent = visoes
	end
	local function renderVisao()
		visoes:ClearAllChildren()
		local snap = state.snapshot()
		local mira = state.mira()
		local id = Previa.get() or (mira and mira.habilidadeId == "mesa/esconder" and mira.tokenId)
		if not snap or not id or snap.combat.turnId ~= id or not snap.combat.active then return end
		local blocos = {}
		for _, muro in snap.jogo and snap.jogo.muros or {} do
			if muro.bloqueiaVisao then for _, casa in muro.casas do blocos[casa[1]..":"..casa[2]] = true end end
		end
		local terrain = snap.map and snap.map.terrain or {}
		local function bloqueia(x, z) return Visao.terrenoBloqueia(terrain, x, z) or blocos[x..":"..z] == true end
		local casas, indice = {}, 0
		for _, inimigo in snap.tokens do
			if inimigo.hostilAoTurno then
				indice += 1
				local minhas = {}
				local cor = cores[(indice-1)%#cores+1]
				for x = math.max(1, inimigo.x - Visao.ALCANCE), math.min(board.width, inimigo.x + Visao.ALCANCE) do
					for z = math.max(1, inimigo.z - Visao.ALCANCE), math.min(board.height, inimigo.z + Visao.ALCANCE) do
						if not bloqueia(x, z) and Visao.contem(inimigo, x, z, bloqueia) then
							casas[x..":"..z] = { x, z }; minhas[x..":"..z] = {x,z}
						end
					end
				end
				for _, c in minhas do
					local centro = Protocol.cellCenter(c[1],c[2]) + Vector3.new(0,.3,0)
					local h = board.cell/2
					for _, d in {{1,0},{-1,0},{0,1},{0,-1}} do
						if not minhas[(c[1]+d[1])..":"..(c[2]+d[2])] then
							local meio = centro + Vector3.new(d[1]*h,0,d[2]*h)
							local lado = Vector3.new(d[2]*h,0,d[1]*h)
							linha(meio-lado,meio+lado,cor,"Limite_"..inimigo.id)
						end
					end
				end
				if next(minhas) then
					local dx,dz = Visao.direcao(inimigo)
					local frente = Vector3.new(dx,0,dz).Unit
					local lado = Vector3.new(-frente.Z,0,frente.X)
					local origem = Protocol.cellCenter(inimigo.x,inimigo.z) + Vector3.new(0,.4,0)
					local ponta = origem + frente*board.cell*.8
					linha(origem,ponta,cor,"Direcao_"..inimigo.id)
					linha(ponta,ponta-frente*.9+lado*.65,cor,"Seta_"..inimigo.id)
					linha(ponta,ponta-frente*.9-lado*.65,cor,"Seta_"..inimigo.id)
				end
			end
		end
		for chave, casa in casas do
			local p = Instance.new("Part")
			p.Name = "Vigiada_"..chave
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
			p.Size = Vector3.new(board.cell - .3, .08, board.cell - .3)
			p.Position = Protocol.cellCenter(casa[1], casa[2]) + Vector3.new(0, .22, 0)
			p.Material, p.Color, p.Transparency = Enum.Material.Neon, Estilo.ALERTA, .88
			p.Parent = visoes
		end
	end
	local pararPrevia = Previa.onChange(renderVisao)
	state.onMira(renderVisao)
	state.onSnapshot(renderVisao)
	visoes.Destroying:Connect(pararPrevia)

	return visoes
end
return V
