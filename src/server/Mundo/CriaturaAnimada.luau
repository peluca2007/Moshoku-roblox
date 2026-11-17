-- Monta um modelo de criatura (Mundo/Modelos) e o anima por código em volta dos pivôs de
-- Shared.Mundo.PivosModelos. Só visual: peças ancoradas, sem colisão/consulta, sem regra de jogo.
-- Usado por Mundo/PatrulhaModelo (patrulhas do mundo).
-- Frente do modelo = -Z. `cf` é sempre a base no chão (centro x/z do pivô, y = chão).
local Montar = require(script.Parent.MontarModelo)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pivos = require(Shared.Mundo.PivosModelos)
local Anim = require(Shared.Mundo.AnimacaoCriatura)
local Modelos = require(Shared.Mundo.ModelosCriaturas)
local Amostra = require(Shared.Animacoes.Amostra)
local PASTA_CLIPES = Shared.Animacoes:FindFirstChild("Criaturas")
local FADE = 0.18 -- troca de clipe base (parado/andando) e entrada/saída das ações (s)

-- Dados de clipes do módulo (ANIM2); nil se não houver ou estiverem malformados (cai nas poses por código).
local cacheClipes = {}
local function clipesDe(modulo)
	local c = cacheClipes[modulo]
	if c == nil then
		c = false
		local m = PASTA_CLIPES and PASTA_CLIPES:FindFirstChild(modulo)
		if m and m:IsA("ModuleScript") then
			local ok, dados = pcall(require, m)
			if ok and Anim.validar(dados) then c = dados end
		end
		cacheClipes[modulo] = c
	end
	return c or nil
end

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
	local tipoArma = Modelos.tipoArma(info.modulo)
	local principal, maior = nil, -1
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") and Anim.grupo(p.Name) == "Arma" then
			-- Contrato MOD5: a maior peça do grupo vira `Arma` (as demais, cores do mesmo objeto, ficam `Arma_<Cor>`).
			p:SetAttribute("TipoArma", tipoArma)
			p:SetAttribute("Empunhadura", bracoArma)
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > maior then principal, maior = p, v end
		end
	end
	if principal then principal.Name = "Arma" end
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
		clipes = clipesDe(info.modulo), pivosPorGrupo = pivos,
		modelo = modelo, info = info, escala = escala, partes = partes, grupos = grupos, locais = locais,
		cfs = table.create(#partes), bracoArma = bracoArma,
		ataqueN = 0, alternar = true, fase = 0, mov = 0, t = 0, yaw = 0, golpeDesde = nil, quedaDesde = nil, tipo = info.tipo,
	}, CriaturaAnimada)
end

-- Ação (ataque/dano) com clipe: toca uma vez por cima da base. Sem clipe, usa o golpe por código (só no ataque).
-- `aoImpacto` (opcional) roda no marco `impacto` do clipe de ataque (gancho para aplicar o dano no instante do golpe).
function CriaturaAnimada:golpear(agora, aoImpacto)
	agora = agora or os.clock()
	self.golpeDesde = agora
	if self.clipes then
		local estado = "ataque"
		if self.alternar and Anim.clipeDe(self.clipes, "ataque2") ~= Anim.clipeDe(self.clipes, "ataque") then
			estado = if self.ataqueN % 2 == 1 then "ataque2" else "ataque"
			self.ataqueN += 1
		end
		local nome, clipe = Anim.clipeDe(self.clipes, estado)
		if clipe then
			self.acao = { clipe = clipe, desde = agora, ataque = true, impacto = aoImpacto, ultimo = -1e-6 }
		end
	end
end
function CriaturaAnimada:levarGolpe(agora)
	if self.quedaDesde or not self.clipes then return end
	local _, clipe = Anim.clipeDe(self.clipes, "dano")
	if clipe and not (self.acao and self.acao.ataque) then
		self.acao = { clipe = clipe, desde = agora or os.clock(), ultimo = -1e-6 }
	end
end
-- MOD5: a peça `Arma` (e `Arma_<Cor>`) acompanha o braço pela animação (peças ancoradas, sem Weld). `soltarArma`
-- tira essas peças da animação, as solta com física e devolve {principal, demais}; nil se não há arma (ou já foi solta).
function CriaturaAnimada:soltarArma()
	local soltas = {}
	for i = #self.partes, 1, -1 do
		if self.grupos[i].grupo == "Arma" then
			table.insert(soltas, self.partes[i])
			table.remove(self.partes, i); table.remove(self.grupos, i); table.remove(self.locais, i); table.remove(self.cfs, i)
		end
	end
	if #soltas == 0 then return nil end
	local principal
	for _, p in ipairs(soltas) do
		p.Anchored, p.CanCollide, p.Massless = false, true, false
		if p.Name == "Arma" then principal = p end
	end
	return { principal = principal or soltas[1], demais = soltas }
end
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
	local temMorte = self.clipes ~= nil and select(2, Anim.clipeDe(self.clipes, "morte")) ~= nil
	if queda and not temMorte then
		local k = queda * queda
		topo = cf * CFrame.new(0, -0.25 * esc * k, 0) * CFrame.Angles(0, 0, math.rad(82) * k)
		dy, dz = 0, 0
	end
	local cfs = self.cfs
	if self.clipes then
		self:aplicarClipes(dt, topo, agora, queda ~= nil, velocidade)
		return
	end
	for i, p in ipairs(self.partes) do
		local g = self.grupos[i]
		local deslocamento = CFrame.new(0, if g.grupo == "PernaE" or g.grupo == "PernaD" then 0 else dy * esc, dz * esc)
		local pose
		if queda or not g.pivo then
			pose = CFrame.identity
		else
			local pitch, yaw, roll = Anim.pose(g.grupo, c)
			pose = CFrame.new(g.pivo) * CFrame.Angles(pitch, yaw, roll or 0) * CFrame.new(-g.pivo)
		end
		cfs[i] = topo * deslocamento * pose * self.locais[i]
	end
	local ok = pcall(workspace.BulkMoveTo, workspace, self.partes, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if not ok then
		for i, p in ipairs(self.partes) do p.CFrame = cfs[i] end
	end
end

local IDENT = { 0, 0, 0, 1, 0, 0, 0 }

-- Pose do grupo no clipe `c` em `t`; peça sem curva: repouso.
local function poseDe(clipe, grupo, dono, t)
	local qx, qy, qz, qw, dx, dy, dz = Anim.peca(clipe, grupo, t)
	if not qx and dono and dono ~= grupo then
		qx, qy, qz, qw, dx, dy, dz = Anim.peca(clipe, dono, t)
	end
	if not qx then return 0, 0, 0, 1, 0, 0, 0 end
	return qx, qy, qz, qw, dx, dy, dz
end

-- Pose por clipes (ANIM2): base parado/andando com mistura por `mov`, queda = Morrer (segura o último quadro),
-- ação (ataque/dano) por cima com fade. d é multiplicado pela escala do modelo montado.
function CriaturaAnimada:aplicarClipes(dt, topo, agora, caindo, velocidade)
	local esc = self.escala
	local dados = self.clipes
	local ritmo = math.clamp((velocidade or 4) / 4, 0.6, 1.6)
	self.tClipe = (self.tClipe or 0) + dt
	local tc = self.tClipe
	local _, parado = Anim.clipeDe(dados, "parado")
	local _, andando = Anim.clipeDe(dados, "andando")
	andando = andando or parado
	parado = parado or andando
	local tp = parado and (Amostra.tempoLocal(parado, tc)) or 0
	local ta = andando and (Amostra.tempoLocal(andando, tc * ritmo)) or 0
	local morte
	if caindo then
		local _, m = Anim.clipeDe(dados, "morte")
		if m then
			if not self.morteDesde then self.morteDesde = self.quedaDesde or agora end
			morte = m
		end
	else
		self.morteDesde = nil
	end
	local acao = self.acao
	local ta2, wAcao, ativo = 0, 0, nil
	if acao and not caindo then
		local dec = agora - acao.desde
		local tl, fim = Amostra.tempoLocal(acao.clipe, dec)
		if fim and dec > acao.clipe.duracao + 0.05 then
			self.acao = nil
		else
			ativo, ta2 = acao.clipe, tl
			wAcao = Amostra.peso(dec, acao.clipe.duracao, 0.06, FADE, false, false)
			if acao.impacto then
				for _, nome in Amostra.marcosEntre(acao.clipe, acao.ultimo, math.min(dec, acao.clipe.duracao)) do
					if nome == "impacto" then pcall(acao.impacto) end
				end
				acao.ultimo = math.min(dec, acao.clipe.duracao)
			end
		end
	elseif acao then
		self.acao = nil
	end
	local wMorte = if morte then math.clamp((agora - self.morteDesde) / FADE, 0, 1) else 0
	local tm = if morte then (Amostra.tempoLocal(morte, agora - self.morteDesde)) else 0
	local cache = {}
	local cfs = self.cfs
	for i = 1, #self.partes do
		local g = self.grupos[i]
		local pose = cache[g.grupo]
		if pose == nil then
			pose = CFrame.identity
			if g.pivo and g.grupo then
				local dono = if g.grupo == "Arma" then self.bracoArma else nil
				local qx, qy, qz, qw, dx, dy, dz = 0, 0, 0, 1, 0, 0, 0
				if parado then
					local ax, ay, az, aw, adx, ady, adz = poseDe(parado, g.grupo, dono, tp)
					if andando ~= parado and self.mov > 0.001 then
						local bx, by, bz, bw, bdx, bdy, bdz = poseDe(andando, g.grupo, dono, ta)
						qx, qy, qz, qw, dx, dy, dz = Anim.misturar(self.mov, ax, ay, az, aw, adx, ady, adz, bx, by, bz, bw, bdx, bdy, bdz)
					else
						qx, qy, qz, qw, dx, dy, dz = ax, ay, az, aw, adx, ady, adz
					end
				end
				if ativo and wAcao > 0 then
					local bx, by, bz, bw, bdx, bdy, bdz = poseDe(ativo, g.grupo, dono, ta2)
					qx, qy, qz, qw, dx, dy, dz = Anim.misturar(wAcao, qx, qy, qz, qw, dx, dy, dz, bx, by, bz, bw, bdx, bdy, bdz)
				end
				if morte then
					local bx, by, bz, bw, bdx, bdy, bdz = poseDe(morte, g.grupo, dono, tm)
					qx, qy, qz, qw, dx, dy, dz = Anim.misturar(wMorte, qx, qy, qz, qw, dx, dy, dz, bx, by, bz, bw, bdx, bdy, bdz)
				end
				local r = CFrame.new(0, 0, 0, qx, qy, qz, qw)
				if g.grupo == "Cabeca" and not morte and self.yaw ~= 0 then r = CFrame.Angles(0, self.yaw, 0) * r end
				pose = CFrame.new(g.pivo + Vector3.new(dx, dy, dz) * esc) * r * CFrame.new(-g.pivo)
			end
			cache[g.grupo or ""] = pose
		end
		cfs[i] = topo * pose * self.locais[i]
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
