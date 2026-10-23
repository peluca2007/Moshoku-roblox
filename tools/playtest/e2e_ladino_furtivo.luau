-- Cliente (execute_luau, Play): joga o Pátio do Ladino como um jogador cuidadoso, sem teleporte.
-- Pré-requisito: run ativa, provação do Ladino aceita e jogador agachado (tecla C) dentro do pátio.
-- Planeja em tempo-espaço (passo de 0,5 s) as posições seguras contra o cone dos 3 guardas, previstos pela mesma
-- fórmula de PatioLadinoLayout.guarda, e replaneja a cada passo a partir da posição real. Só usa Humanoid:MoveTo
-- e o ProximityPrompt do sino/portão. Progresso em _G.LADINO (log, fase, fim).
local RS = game:GetService("ReplicatedStorage")
local Layout = require(RS.Shared.Mundo.PatioLadinoLayout)
local TL = require(RS.Shared.Mundo.TreinadoresLayout)
local P = game.Players.LocalPlayer
local patio = workspace.ProvacoesTreinadores["Pátio do Ladino"]
local DT, PASSOS, MARGEM_ALC, MARGEM_ANG = 0.5, 90, 2.0, 12
local ALCANCE = 10 -- agachado
local COS = math.cos(math.rad(35 + MARGEM_ANG))
local X0, Z0, N = 45, -270, 21
_G.LADINO = { log = {}, fase = "inicio", fim = false }
local function log(m) table.insert(_G.LADINO.log, string.format("%.1f %s", os.clock() % 1000, m)) end

-- fase de cada guarda (equivalente a "tempo" da fórmula)
local function tempoGuarda(i)
	local m = patio:FindFirstChild("Guarda " .. i)
	local hrp = m.HumanoidRootPart
	local r = Layout.ROTAS[i]
	local dx, dz = r.b.x - r.a.x, r.b.z - r.a.z
	local d = math.sqrt(dx * dx + dz * dz)
	local u = ((hrp.Position.X - r.a.x) * dx + (hrp.Position.Z - r.a.z) * dz) / (d * d)
	u = math.clamp(u, 0, 1)
	local ida = (hrp.CFrame.LookVector.X * dx + hrp.CFrame.LookVector.Z * dz) > 0
	local fase = if ida then u else 2 - u
	return fase * d / Layout.VELOCIDADE
end

local function celulaPos(i, j) return Vector3.new(X0 + 2 * i, 0, Z0 + 2 * j) end
-- Além das coberturas: a folha aberta do portão (x=69,5, z de -235,2 a -230,8) e o muro da entrada deixam só x 61..68 livre perto do portão.
local function bloqueada(x, z)
	if z > -236.5 and (x < 61 or x > 67.6) then return true end
	return Layout.ocupado(x, z, 1.3)
end

local function segRet(ax, az, bx, bz, c)
	local x0, x1, z0, z1 = c.x - c.sx / 2 + 0.2, c.x + c.sx / 2 - 0.2, c.z - c.sz / 2 + 0.2, c.z + c.sz / 2 - 0.2
	local t0, t1 = 0, 1
	local dx, dz = bx - ax, bz - az
	for _, par in { { -dx, ax - x0 }, { dx, x1 - ax }, { -dz, az - z0 }, { dz, z1 - az } } do
		local p, q = par[1], par[2]
		if p == 0 then if q < 0 then return false end
		else
			local r = q / p
			if p < 0 then if r > t1 then return false elseif r > t0 then t0 = r end
			else if r < t0 then return false elseif r < t1 then t1 = r end end
		end
	end
	return true
end

local function visto(px, pz, tg) -- tg = tempo absoluto "equivalente" de cada guarda no instante
	for i = 1, 3 do
		local pos, f = Layout.guarda(i, tg[i])
		local dx, dz = px - pos.x, pz - pos.z
		local d2 = dx * dx + dz * dz
		local alc = ALCANCE + MARGEM_ALC
		if d2 <= alc * alc then
			local ok = true
			if d2 > 0.01 then
				local cosv = (f.x * dx + f.z * dz) / math.sqrt(d2)
				ok = cosv >= COS
			end
			if ok then
				local oculto = false
				for _, c in Layout.COBERTURAS do
					if segRet(pos.x, pos.z, px, pz, c) then oculto = true break end
				end
				if not oculto then return true end
			end
		end
	end
	return false
end

local function planejar(inicio, alvo, ficar)
	local t0 = os.clock()
	local base = {}
	for i = 1, 3 do base[i] = tempoGuarda(i) end
	local function tg(k) local t = {} for i = 1, 3 do t[i] = base[i] + k * DT end return t end
	local memo = {}
	local function seguro(i, j, k)
		local chave = (k * 64 + i) * 64 + j
		local v = memo[chave]
		if v == nil then
			local c = celulaPos(i, j)
			v = not visto(c.X, c.Z, tg(k))
			memo[chave] = v
		end
		return v
	end
	local si, sj = math.clamp(math.round((inicio.X - X0) / 2), 0, N - 1), math.clamp(math.round((inicio.Z - Z0) / 2), 0, N - 1)
	local camada = { [si * 64 + sj] = false }
	local pais = { [0] = camada }
	local atual = camada
	local hist = { atual }
	for k = 1, PASSOS do
		local prox = {}
		for chave in atual do
			local i, j = chave // 64, chave % 64
			for di = -1, 1 do for dj = -1, 1 do
				local ni, nj = i + di, j + dj
				if ni >= 0 and ni < N and nj >= 0 and nj < N then
					local nc = celulaPos(ni, nj)
					local nk = ni * 64 + nj
					if not prox[nk] and not bloqueada(nc.X, nc.Z) and seguro(ni, nj, k) and seguro(ni, nj, k - 0.5) and seguro(i, j, k - 0.5) then
						prox[nk] = chave
					end
				end
			end end
		end
		table.insert(hist, prox)
		if next(prox) == nil then return nil, "sem caminho seguro no passo " .. k end
		for nk in prox do
			local i, j = nk // 64, nk % 64
			local c = celulaPos(i, j)
			if alvo(c) then
				local ok = true
				for e = 1, ficar do if not seguro(i, j, k + e) then ok = false break end end
				if ok then
					-- reconstrói
					local rota, ch = {}, nk
					for kk = k, 1, -1 do
						table.insert(rota, 1, ch)
						ch = hist[kk + 1][ch]
					end
					return rota, k, os.clock() - t0
				end
			end
		end
		atual = prox
	end
	return nil, "sem alvo em " .. PASSOS .. " passos"
end

local function mover(alvo, ficar, rotulo, maxSeg)
	local h = P.Character.Humanoid
	local fim = os.clock() + maxSeg
	while os.clock() < fim do
		local r = P.Character.HumanoidRootPart
		local rota, k, gasto = planejar(r.Position, alvo, ficar)
		if not rota then log(rotulo .. ": " .. tostring(k)) ; task.wait(DT) ; continue end
		local c = celulaPos(rota[1] // 64, rota[1] % 64)
		h:MoveTo(Vector3.new(c.X, r.Position.Y, c.Z))
		task.wait(DT)
		local a = alvo(Vector3.new(P.Character.HumanoidRootPart.Position.X, 0, P.Character.HumanoidRootPart.Position.Z))
		if a then
			-- confere se ficou perto o bastante (alvo vale p/ posição real)
			return true
		end
	end
	return false
end

task.spawn(function()
	local ok, err = pcall(function()
		local sino = patio:FindFirstChild("Sino")
		local portao = patio:FindFirstChild("Portão")
		local rs = TL
		-- fase 1: sino
		_G.LADINO.fase = "ate-sino"
		local function pertoSino(c) return (Vector3.new(c.X, 0, c.Z) - Vector3.new(rs.SINO.x, 0, rs.SINO.z)).Magnitude <= 5.5 end
		local prompt0 = sino.ProximityPrompt
		local mostrado = false
		prompt0.PromptShown:Connect(function() mostrado = true; log("prompt do sino visivel") end)
		prompt0.PromptHidden:Connect(function() mostrado = false end)
		prompt0.PromptButtonHoldBegan:Connect(function() log("cliente: hold began") end)
		prompt0.Triggered:Connect(function() log("cliente: triggered") end)
		local chegou = if _G.LADINO_SO_VOLTA then true else mover(pertoSino, 6, "sino", 120)
		log("chegou ao sino: " .. tostring(chegou))
		if not chegou then _G.LADINO.fase = "falhou-sino" ; return end
		P.Character.Humanoid:MoveTo(P.Character.HumanoidRootPart.Position)
		local prompt = sino.ProximityPrompt
		if not _G.LADINO_SO_VOLTA then
		_G.LADINO.fase = "segurando"
		local espera = os.clock() + 1
		while not mostrado and os.clock() < espera do task.wait(0.05) end
		log("antes do hold: prompt visivel=" .. tostring(mostrado) .. " pos=" .. tostring(P.Character.HumanoidRootPart.Position))
		prompt:InputHoldBegin()
		task.wait(1.7)
		prompt:InputHoldEnd()
		task.wait(0.4)
		log("sino solto; prompt enabled=" .. tostring(prompt.Enabled))
		end
		-- fase 2: portão
		_G.LADINO.fase = "ate-portao"
		local function pertoPortao(c) return (Vector3.new(c.X, 0, c.Z) - Vector3.new(rs.PORTAO.x, 0, rs.PORTAO.z)).Magnitude <= 5 end
		local volta = mover(pertoPortao, 1, "portao", 120)
		log("chegou ao portao: " .. tostring(volta))
		if not volta then _G.LADINO.fase = "falhou-portao" ; return end
		_G.LADINO.fase = "acionando-portao"
		portao.ProximityPrompt:InputHoldBegin()
		task.wait(0.3)
		portao.ProximityPrompt:InputHoldEnd()
		task.wait(1)
		_G.LADINO.fase = "fim"
	end)
	if not ok then log("ERRO " .. tostring(err)); _G.LADINO.fase = "erro" end
	_G.LADINO.fim = true
end)
return "iniciado"
