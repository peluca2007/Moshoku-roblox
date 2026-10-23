-- Monta um modelo de criatura (Mundo/Modelos) e o anima por código em volta dos pivôs de
-- Shared.Mundo.PivosModelos. Só visual: peças ancoradas, sem colisão/consulta, sem regra de jogo.
-- Usado por Mundo/PatrulhaModelo (patrulhas) e EncontroAutonomoMiniaturas (combate J2).
-- Frente do modelo = -Z. `cf` é sempre a base no chão (centro x/z do pivô, y = chão).
local Montar = require(script.Parent.MontarModelo)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pivos = require(Shared.Mundo.PivosModelos)
local Anim = require(Shared.Mundo.AnimacaoCriatura)
local Modelos = require(Shared.Mundo.ModelosCriaturas)

local CriaturaAnimada = {}
CriaturaAnimada.__index = CriaturaAnimada

-- info: resultado de ModelosCriaturas.escolher; pai: onde montar; cf: pose inicial (base no chão).
-- Cede (CreateMeshPartAsync) só na primeira montagem de cada malha. Devolve nil se falhar.
function CriaturaAnimada.montar(info, pai, cf, escala)
	if type(info) ~= "table" or not Montar.existe(info.modulo) then return nil end
	escala = escala or 1
	local ok, modelo = pcall(Montar.montar, info.modulo, pai, cf, escala)
	if not ok or not modelo then return nil end
	local pivos = Pivos[info.modulo]
	local base = cf
	local partes, grupos, locais = {}, {}, {}
	local bracoArma = Anim.bracoDaArma(pivos)
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Material = Enum.Material[Modelos.material(p.Name, p.Material.Name)]
			p.MaterialVariant = ""
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = true, false, false, false, true
			local grupo = Anim.grupo(p.Name)
			local dono = if grupo == "Arma" then bracoArma else grupo
			local pv = pivos and dono and pivos[dono]
			table.insert(partes, p)
			table.insert(grupos, {
				grupo = grupo,
				pivo = if pv then Vector3.new(pv[1], pv[2], pv[3]) * escala else nil,
			})
			table.insert(locais, base:ToObjectSpace(p.CFrame))
		end
	end
	if #partes == 0 then modelo:Destroy(); return nil end
	return setmetatable({
		modelo = modelo, info = info, escala = escala, partes = partes, grupos = grupos, locais = locais,
		cfs = table.create(#partes), bracoArma = bracoArma,
		fase = 0, mov = 0, t = 0, yaw = 0, golpeDesde = nil, quedaDesde = nil, tipo = info.tipo,
	}, CriaturaAnimada)
end

function CriaturaAnimada:golpear(agora) self.golpeDesde = agora or os.clock() end
function CriaturaAnimada:cair(agora) self.quedaDesde = agora or os.clock() end
function CriaturaAnimada:caiu() return self.quedaDesde ~= nil end
-- Altura/pegada do modelo na escala usada (studs), para marcadores e seleção.
function CriaturaAnimada:tamanho()
	local _, tam = self.modelo:GetBoundingBox()
	return tam
end

-- Avança o relógio interno e aplica a pose. `andando`: está se deslocando; `velocidade`: studs/s;
-- `olharPara`: posição do mundo que a cabeça acompanha (nil = frente).
function CriaturaAnimada:atualizar(dt, cf, andando, velocidade, olharPara, agora)
	agora = agora or os.clock()
	dt = math.clamp(dt, 0, 0.25)
	self.t += dt
	self.mov += ((if andando then 1 else 0) - self.mov) * math.min(1, 8 * dt)
	local ritmo = if self.tipo == "pesado" then 0.6 elseif self.tipo == "aranha" then 1.4 else 1
	self.fase += dt * (velocidade or 4) * 2.2 / math.max(0.6, self.escala) * ritmo * (if andando then 1 else 0.5)
	local alvoYaw = 0
	if olharPara then
		local local3 = cf:PointToObjectSpace(olharPara)
		if local3.X * local3.X + local3.Z * local3.Z > 0.01 then alvoYaw = math.atan2(-local3.X, -local3.Z) end
	end
	self.yaw += (math.clamp(alvoYaw, -1.2, 1.2) - self.yaw) * math.min(1, 8 * dt)
	local golpe = nil
	if self.golpeDesde then
		golpe = (agora - self.golpeDesde) / Anim.DURACAO_GOLPE
		if golpe >= 1 then self.golpeDesde, golpe = nil, nil end
	end
	local queda = nil
	if self.quedaDesde then queda = math.clamp((agora - self.quedaDesde) / 0.7, 0, 1) end
	local c = {
		tipo = self.tipo, fase = self.fase, mov = self.mov, t = self.t, golpe = golpe,
		yawCabeca = self.yaw, bracoArma = self.bracoArma,
	}
	local dy, dz = Anim.corpo(c)
	local esc = self.escala
	local topo = cf
	if queda then
		local k = queda * queda
		topo = cf * CFrame.new(0, -0.25 * esc * k, 0) * CFrame.Angles(0, 0, math.rad(82) * k)
		dy, dz = 0, 0
	end
	local cfs = self.cfs
	for i, p in ipairs(self.partes) do
		local g = self.grupos[i]
		local deslocamento = CFrame.new(0, if g.grupo == "PernaE" or g.grupo == "PernaD" then 0 else dy * esc, dz * esc)
		local pose
		if queda or not g.pivo then
			pose = CFrame.identity
		else
			local pitch, yaw = Anim.pose(g.grupo, c)
			pose = CFrame.new(g.pivo) * CFrame.Angles(pitch, yaw, 0) * CFrame.new(-g.pivo)
		end
		cfs[i] = topo * deslocamento * pose * self.locais[i]
	end
	local ok = pcall(workspace.BulkMoveTo, workspace, self.partes, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if not ok then
		for i, p in ipairs(self.partes) do p.CFrame = cfs[i] end
	end
end

function CriaturaAnimada:destruir()
	if self.modelo then self.modelo:Destroy(); self.modelo = nil end
end

return CriaturaAnimada
