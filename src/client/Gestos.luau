-- Gestos de corpo (A5): o que o corpo de quem age faz para cada técnica, lido do
-- que a carta do livro diz (investida corre, golpe contínuo corta três vezes,
-- provocar grita, disparo duplo puxa a corda...). Só apresentação: o recibo já
-- foi resolvido pelo servidor. O corpo real fica escondido só nesta tela e um
-- fantasma local faz o movimento (Corpo.luau).
local Gestos = {}

local Y = Vector3.yAxis
local Corpo = require(script.Parent.Corpo)

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end
local function unit(v: Vector3): Vector3
	v = plano(v)
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.zAxis
end
local function suave(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end
local function entre(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

-- Especificação por técnica (última parte do ID). g = tipo de gesto.
-- cortes: { { instante, ângulo em graus } } relativos ao fim do preparo.
local ESPEC = {
	["esconder"] = { g = "furtivo" },
	["primeiro-golpe"] = { g = "golpe", cortes = { { 0, -35 }, { .1, 45 } }, peso = .5, preparo = .15 },
	["dissonancia"] = { g = "cancao" },
	["marcha"] = { g = "cancao" },
	["parar-cancao"] = { g = "comando" },
	["inspiracao"] = { g = "comando" },
	["insulto"] = { g = "comando" },
	["apontar"] = { g = "comando" },
	["ataque-basico"] = { g = "golpe", cortes = { { 0, 38 } }, peso = 0.3 },
	["ataque-a-distancia"] = { g = "disparo", peso = 0.25 },
	["corte-de-braco"] = { g = "golpe", cortes = { { 0, 62 } }, peso = 0.4, preparo = 0.26, preciso = true },
	["golpe-continuo"] = { g = "golpe", cortes = { { 0, 28 }, { 0.12, -34 }, { 0.24, 80 } }, peso = 0.35, preparo = 0.16 },
	["golpe-baixo"] = { g = "golpe", cortes = { { 0, 88 } }, peso = 0.3, baixo = true, preparo = 0.24 },
	["golpe-circular"] = { g = "giro", peso = 0.55 },
	["cabecada"] = { g = "cabecada", peso = 0.5 },
	["golpe-de-escudo"] = { g = "escudada", peso = 0.55, prop = "escudo" },
	["lamina-de-gelo-forca"] = { g = "golpe", cortes = { { 0, 40 }, { 0.14, -30 } }, peso = 0.35, prop = "gelo", gelo = true },
	["lamina-de-gelo-intelecto"] = { g = "golpe", cortes = { { 0, 40 }, { 0.14, -30 } }, peso = 0.35, prop = "gelo", gelo = true },
	["ataque"] = { g = "golpe", cortes = { { 0, 20 }, { 0.1, -24 } }, peso = 0.3, semArma = true },
	["derrubar"] = { g = "golpe", cortes = { { 0, 90 } }, peso = 0.3, semArma = true, baixo = true },
	["agarrao"] = { g = "escudada", peso = 0.4, semArma = true },
	["investida-espada"] = { g = "investida", estilo = "espada", peso = 0.5 },
	["forma-quadrupede"] = { g = "investida", estilo = "quadrupede", peso = 0.45 },
	["investida-devastadora"] = { g = "investida", estilo = "devastadora", peso = 0.9, prop = "pesada" },
	["provocar"] = { g = "grito" },
	["provocar-odio"] = { g = "grito" },
	["provocar-odio-soberano"] = { g = "grito", soberano = true },
	["puxar"] = { g = "corrente" },
	["disparo-duplo"] = { g = "disparo", peso = 0.25 },
	["tiro-de-contencao"] = { g = "disparo", peso = 0.25, prende = true },
	["arremesso-de-espada"] = { g = "arremesso", peso = 0.4 },
	["lamina-de-gelo"] = { g = "conjuro", pose = "empunhar", prop = "gelo" },
}
local MAGICAS = {
	agua = true, vento = true, terra = true, cura = true, desintoxicacao = true, teorica = true, invocacao = true, fogo = true,
}

function Gestos.especificar(id: string, mec, arvore: string?)
	local chave = string.match(id, "([^/]+)$")
	local spec = chave and ESPEC[chave]
	if spec then
		return spec
	end
	if arvore and MAGICAS[arvore] then
		local sobreSi = mec.tipo == "zona" or mec.tipo == "invocacao" or mec.tipo == "cura" or mec.tipo == "area" or mec.tipo == "muro"
			or mec.tipo == "utilidade" or mec.alvo == "si" or mec.alvo == "esferaNoConjurador"
		return { g = "conjuro", pose = if sobreSi then "palmas" else "apontar" }
	end
	return nil
end

-- Reação do corpo atingido: só para personagens (as miniaturas já recuam por
-- Efeitos.reagir). O fantasma é jogado para trás, inclina e volta.
function Gestos.reacao(K, cena, alvoId: string, direcao: Vector3, forca: number)
	local modelo, avatar = Corpo.modeloDe(K.state, alvoId)
	if not modelo or not avatar then
		return
	end
	local f = Corpo.fantasma(modelo, cena.modelo)
	if not f then
		return
	end
	Corpo.ocultar(modelo, true)
	f.escondido = true
	local function revelar()
		if f.escondido then
			f.escondido = false
			Corpo.ocultar(modelo, false)
			Corpo.destruir(f)
		end
	end
	table.insert(cena.limpezas, revelar)
	local base = modelo:GetPivot().Position
	local dir = unit(direcao)
	Corpo.por(f, base, -dir)
	K.animar(cena, 0, 0.5, function(t)
		if not f.viva then
			return
		end
		local curva = math.sin(math.min(t * 1.6, 1) * math.pi) * (1 - t)
		Corpo.por(f, base + dir * curva * 2.4 * math.clamp(forca, 0.3, 2) + Y * math.sin(t * math.pi) * 0.4, -dir, 0.7 * curva)
		Corpo.braco(f, "d", 0.6 * curva, 0.9 * curva)
		Corpo.braco(f, "e", 0.6 * curva, 0.9 * curva)
		Corpo.tronco(f, -0.4 * curva)
		if t >= 1 then
			revelar()
		end
	end)
end

-- K = ferramentas da Coreografia (animar, evento, peca, segmento, arco, cena...).
function Gestos.tocar(K, cena, recibo, spec, de: Vector3?, mec)
	local state = K.state
	local cor = cena.cor
	local casterId = recibo.casterId
	if not casterId then
		return nil
	end
	local alvos = recibo.alvos or {}
	local primeiro = alvos[1]
	local alvoPos = primeiro and K.posicaoDe(state, primeiro.id, primeiro.casa) or nil
	local modelo = Corpo.modeloDe(state, casterId)

	-- Fantasma do conjurador: esconde o corpo real até o gesto acabar.
	local f
	local function abrir()
		if not modelo then
			return false
		end
		f = Corpo.fantasma(modelo, cena.modelo)
		if not f then
			return false
		end
		Corpo.ocultar(modelo, true)
		f.escondido = true
		table.insert(cena.limpezas, function()
			if f.escondido then
				f.escondido = false
				Corpo.ocultar(modelo, false)
			end
		end)
		local base = modelo:GetPivot()
		f.base = base.Position
		Corpo.por(f, base.Position, base.LookVector)
		return true
	end
	local function revelar()
		if f and f.escondido then
			f.escondido = false
			Corpo.ocultar(modelo, false)
			Corpo.destruir(f)
		end
	end
	local function rodar(total: number, pose)
		K.animar(cena, 0, total, function(t)
			if not f or not f.viva then
				return
			end
			local s = t * total
			local p = pose(s)
			Corpo.por(f, p.pos, p.olhar, p.pitch, p.rolar, p.giro)
			Corpo.braco(f, "d", p.d or 0, p.dl)
			Corpo.braco(f, "e", p.e or 0, p.el)
			Corpo.tronco(f, p.tr or 0, p.tg)
			if t >= 1 then
				revelar()
			end
		end)
	end
	-- Animação real do personagem no instante `quando` da cena (sem efeito em miniatura).
	local function anim(quando: number, nome: string, opcoes)
		K.evento(cena, quando, function()
			if f then Corpo.animar(f, nome, opcoes) end
		end)
	end
	local function pararAnim(quando: number, nome: string)
		K.evento(cena, quando, function()
			if f then Corpo.parar(f, nome) end
		end)
	end
	local GOLPE = Enum.AnimationPriority.Action4
	local function arma(tipo)
		if f then
			Corpo.arma(f, tipo, cor)
		end
	end
	local function tipoDaArma()
		return Corpo.tipoDeArma(recibo.arma)
	end

	-- Efeitos de impacto reutilizáveis ----------------------------------------
	local function talho(centro: Vector3, dir: Vector3, grau: number, raio: number, quando: number, dur: number?, tom: Color3?)
		dur = dur or 0.24
		raio *= 1.35
		local r = dir:Cross(Y)
		r = if r.Magnitude > 1e-3 then r.Unit else Vector3.xAxis
		local u = r:Cross(dir)
		local a = math.rad(grau)
		local rr, uu = r * math.cos(a) + u * math.sin(a), -r * math.sin(a) + u * math.cos(a)
		local N = 14
		local pecas, sombras = {}, {}
		for _ = 1, N do
			table.insert(pecas, K.peca(cena, "fio", tom or cor))
			table.insert(sombras, K.peca(cena, "fio", Color3.fromRGB(255, 255, 255)))
		end
		local function ponto(frac: number)
			local th = (frac - 0.5) * math.rad(150)
			return centro + rr * (math.sin(th) * raio) + dir * (-(1 - math.cos(th)) * raio * 0.55) + uu * (math.cos(th) - 1) * raio * 0.15
		end
		K.animar(cena, quando, dur, function(t)
			for i, p in pecas do
				local a0, a1 = (i - 1) / N, i / N
				local brilho = sombras[i]
				if not p or not brilho then
					-- orçamento de peças esgotado: o corte sai mais curto, sem erro
				elseif t * 1.35 < a0 then
					p.Transparency = 1
					brilho.Transparency = 1
				else
					local fade = math.clamp((t - a1 * 0.55) * 1.6, 0, 1) ^ 1.5
					local grossura = math.sin(math.pi * (a0 + a1) / 2)
					K.segmento(p, ponto(a0), ponto(a1), 0.35 + 0.9 * grossura, fade)
					K.segmento(brilho, ponto(a0), ponto(a1), 0.12 + 0.3 * grossura, math.clamp(fade + 0.1, 0, 1))
				end
			end
		end)
	end
	local function faiscas(ponto: Vector3, dir: Vector3, quando: number, n: number, tom: Color3?, alcance: number?)
		local r = dir:Cross(Y)
		r = if r.Magnitude > 1e-3 then r.Unit else Vector3.xAxis
		local u = r:Cross(dir)
		for i = 1, n do
			local p = K.peca(cena, "fio", tom or cor)
			local ang = i * math.pi * 2 / n + (i % 2) * 0.3
			local v = (r * math.cos(ang) + u * math.sin(ang) + dir * 0.5).Unit * ((alcance or 3.6) * (0.7 + (i % 3) * 0.25))
			K.animar(cena, quando, 0.34, function(t)
				local a = ponto + v * suave(t * 0.6)
				local b = ponto + v * suave(t) * 1.2
				K.segmento(p, a, b, 0.22 - 0.14 * t, 0.05 + t ^ 2 * 0.95)
			end)
		end
	end
	-- Clarão curto no ponto do golpe: lê-se como "acertou", mesmo de longe.
	local function clarao(ponto: Vector3, quando: number, tamanho: number?, tom: Color3?)
		local bola = K.peca(cena, "gota", tom or Color3.fromRGB(255, 244, 214))
		local anel = K.peca(cena, "gota", tom or cor)
		K.animar(cena, quando, 0.2, function(t)
			if bola then
				bola.Position = ponto
				bola.Size = Vector3.one * ((tamanho or 3) * (0.4 + t))
				bola.Transparency = 0.1 + t * 0.9
			end
			if anel then
				anel.Position = ponto
				anel.Size = Vector3.one * ((tamanho or 3) * (0.8 + 2 * t))
				anel.Transparency = 0.5 + t * 0.5
			end
		end)
	end
	local function poeira(ponto: Vector3, quando: number, n: number, raio: number?)
		for i = 1, n do
			local p = K.peca(cena, "gota", Color3.fromRGB(176, 160, 132), Enum.Material.SmoothPlastic)
			if p then
				local ang = i * math.pi * 2 / n
				local v = Vector3.new(math.cos(ang), 0.5, math.sin(ang)) * (raio or 2.2)
				K.animar(cena, quando, 0.55, function(t)
					p.Position = K.chao(ponto) + v * suave(t) + Y * (0.4 + t * 0.9)
					p.Size = Vector3.one * (0.45 + t * 1.1)
					p.Transparency = 0.45 + t ^ 1.5 * 0.55
				end)
			end
		end
	end
	local function estrelas(centro: Vector3, quando: number)
		for i = 1, 4 do
			local p = K.peca(cena, "gota", Color3.fromRGB(255, 232, 130))
			if p then
				K.animar(cena, quando, 0.8, function(t)
					local ang = i * math.pi / 2 + t * 9
					p.Position = centro + Vector3.new(math.cos(ang) * 1.5, 0, math.sin(ang) * 1.5) + Y * (2.2 + math.sin(t * 6 + i) * 0.2)
					p.Size = Vector3.one * (0.35 + 0.15 * math.sin(t * 14 + i))
					p.Transparency = 0.1 + math.max(0, t - 0.6) * 2.2
				end)
			end
		end
	end
	local function sombra(quando: number, vida: number)
		if not f then
			return
		end
		K.evento(cena, quando, function()
			if not f.viva then
				return
			end
			local m = f.modelo:Clone()
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored, p.Material, p.Color, p.CanCollide = true, Enum.Material.Neon, cor, false
					p.Transparency = 0.55
				end
			end
			m.Name = "Sombra"
			m.Parent = cena.modelo
			K.animar(cena, quando, vida, function(t)
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = 0.55 + 0.45 * t
					end
				end
				if t >= 1 then
					m:Destroy()
				end
			end)
		end)
	end
	local g = spec.g
	local plan = { semCirculo = true, semViagem = true, impactoProprio = true }
	-- Utilidades também têm ação corporal: conduzir uma canção, indicar o alvo,
	-- baixar a postura e se recolher. O efeito já veio confirmado do servidor.
	if g == "cancao" or g == "comando" or g == "furtivo" then
		local ok = abrir()
		local origem = if ok then f.base else (de or Vector3.zero)
		local olho = if alvoPos then unit(alvoPos - origem) else (if modelo then modelo:GetPivot().LookVector else Vector3.zAxis)
		if ok then
			rodar(.85, function(s)
				local pulso = math.sin(math.clamp(s / .85, 0, 1) * math.pi)
				local ritmo = math.sin(s * math.pi * 7) * pulso
				return { pos = origem - Y * (if g == "furtivo" then .7 * pulso else 0), olhar = olho,
					d = if g == "comando" then 1.5 * pulso elseif g == "cancao" then .7 + ritmo * .35 else .3 * pulso,
					e = if g == "cancao" then .9 - ritmo * .35 else .2 * pulso,
					dl = if g == "cancao" then .4 * pulso else 0,
					el = if g == "cancao" then -.4 * pulso else 0,
					tr = if g == "furtivo" then .35 * pulso else -.1 * pulso, tg = if g == "cancao" then ritmo * .12 else 0 }
			end)
		end
		if g == "cancao" then
			for i = 1, 3 do K.arco(cena, K.chao(origem) + Y * .1, 3 + i, .1 + i * .12, .6, false, math.pi * 2, i, cor) end
			for i = 1, 6 do
				local nota = K.peca(cena, "gota", cor)
				if nota then K.animar(cena, .1 + i * .05, .65, function(t)
					local ang = i * math.pi / 3 + t
					nota.Position = origem + Vector3.new(math.cos(ang) * 2, 1 + t * 4, math.sin(ang) * 2)
					nota.Size = Vector3.one * (.25 + .15 * math.sin(t * math.pi))
					nota.Transparency = .15 + t * .85
				end) end
			end
		elseif g == "comando" then
			local ponto = alvoPos or origem
			for i = 1, 2 do K.arco(cena, K.chao(ponto), 2 + i * .6, .2 + i * .08, .5, false, math.pi * 1.6, i, cor) end
		else
			poeira(origem, .1, 8, 1.6)
			K.arco(cena, K.chao(origem), 2.2, .05, .6, false, math.pi * 1.5, 0, cor)
		end
		return { semCirculo = true, semViagem = true, impactoProprio = true, chegada = .35 }
	end

	-- Golpe corpo a corpo -------------------------------------------------------
	if g == "golpe" or g == "giro" or g == "cabecada" or g == "escudada" then
		if not alvoPos then
			return nil
		end
		local ok = abrir()
		local origem = if ok then f.base else (de or alvoPos)
		local dir = unit(alvoPos - origem)
		local dist = plano(alvoPos - origem).Magnitude
		local acertouPrimeiro = primeiro.acertou ~= false
		if not acertouPrimeiro then
			-- O corte passa ao lado: errar não desenha uma colisão sobre a vítima.
			alvoPos += Vector3.new(dir.Z, 0, -dir.X) * 2.8
		end
		local avanco = math.clamp(dist - 3.4, 0.5, 3.2)
		local W = spec.preparo or (if tipoDaArma() == "pesada" then .34 else .26)
		local cortes = spec.cortes or { { 0, 40 } }
		if g == "giro" then cortes = { { 0, 0 } } end
		local ultimo = cortes[#cortes][1]
		local golpeFim = W + ultimo
		local total = golpeFim + 0.1 + 0.28 + 0.2
		local ponto = alvoPos - dir * 1.1
		if ok then
			local tipo = spec.prop or tipoDaArma()
			if g == "escudada" then
				arma("escudo")
			elseif g == "cabecada" or spec.semArma then
				-- sem arma: usa o corpo
			else
				arma(tipo)
			end
			anim(0, "toolnone", { repete = true, prioridade = Enum.AnimationPriority.Action })
			for _, c in cortes do
				if g == "escudada" or g == "cabecada" then
					anim(math.max(0, W + c[1] - 0.08), "toollunge", { velocidade = 1.6, prioridade = GOLPE })
				else
					anim(math.max(0, W + c[1] - 0.06), "toolslash", { velocidade = if #cortes > 1 then 1.8 else 1.35, prioridade = GOLPE })
				end
			end
			rodar(total, function(s)
				local retorno = golpeFim + 0.38
				local recuo = if s < W then 0.5 * suave(s / W) else 0.5 * (1 - suave((s - W) / 0.09))
				local frente = if s < W then 0 else avanco * suave((s - W) / 0.09)
				local pos = f.base - dir * recuo + dir * frente * (1 - suave((s - retorno) / 0.2))
				local d, e, tr, tg, giro = 0, 0, 0, 0, 0
				if g == "cabecada" then
					tr = if s < W + 0.05 then -0.55 * suave(s / (W + 0.05)) else 0.7 * (1 - suave((s - W - 0.2) / 0.3))
					d, e = -0.3, -0.3
				elseif g == "escudada" then
					e = if s < W then entre(0.2, 1.4, s / W) else 1.5
					d = -0.5
					tg = if s < W then 0.3 else -0.2
				elseif g == "giro" then
					giro = math.pi * 2 * suave((s - W + 0.02) / 0.42)
					d, e = 1.5, 1.2
					tr = 0.15
				else
					-- braço da arma: recua, desce rápido a cada corte e relaxa.
					local frente = entre(0, -1.1, s / W)
					for i, c in cortes do
						local ini = W + c[1]
						if s >= ini - 0.02 then
							local u = (s - ini) / 0.09
							frente = if u < 1 then entre(-1.1, 1.75, suave(u)) else entre(1.75, 0.4, (s - ini - 0.09) / 0.3)
						end
					end
					d = frente
					e = -0.35
					tr = if spec.baixo then 0.9 else (if s < W then -0.2 else 0.25)
					tg = if s < W then -0.3 else 0.35
					if spec.baixo then pos -= Y * 0.9 end
				end
				return { pos = pos, olhar = dir, d = d, e = e, tr = tr, tg = tg, giro = giro }
			end)
		end
		-- Marcas dos cortes (existem mesmo sem fantasma).
		if g == "giro" then
			local r = 6.4
			K.arco(cena, origem + Y * 2.2, r, W, 0.4, false, math.pi * 2, 0, cor)
			K.arco(cena, origem + Y * 1.2, r * 0.85, W + 0.06, 0.38, false, math.pi * 2, 1.7, cor)
			poeira(origem, W, 8, 5)
			for i, a in alvos do
				local p = K.posicaoDe(state, a.id, a.casa)
				local d = unit(p - origem)
				if a.acertou ~= false then faiscas(p - d * 1.2, d, W + 0.1 + (i - 1) * 0.04, 8, cor) end
			end
			plan.chegada = W + 0.12
		elseif g == "cabecada" then
			if acertouPrimeiro then
			faiscas(ponto, dir, W + 0.12, 10, Color3.fromRGB(255, 232, 130), 2)
			estrelas(alvoPos, W + 0.12)
			K.evento(cena, W + 0.12, function() K.Efeitos.tremer(0.35, 0.22) end)
			end
			plan.chegada = W + 0.1
		elseif g == "escudada" then
			if acertouPrimeiro then
			K.arco(cena, K.chao(alvoPos), 4, W + 0.08, 0.4, false, math.pi * 2, 0, cor)
			for i = 1, 3 do
				K.arco(cena, alvoPos - dir * 1.5 + Y * (0.6 * i - 1), 2.8, W + 0.08 + i * 0.03, 0.3, true, math.pi * 1.2, i, cor)
			end
			faiscas(ponto, dir, W + 0.08, 8, cor, 3)
			poeira(alvoPos - dir * 1, W + 0.08, 6, 3)
			end
			plan.chegada = W + 0.1
		else
			for i, c in cortes do
				local quando = W + c[1]
				local raio = if spec.baixo then 4.4 else 3.8
				talho(alvoPos - dir * 0.6 + (if spec.baixo then Vector3.new(0, -1.2, 0) else Vector3.zero), dir, c[2], raio, quando + 0.01, 0.2, if spec.gelo then Color3.fromRGB(190, 232, 255) else nil)
				if acertouPrimeiro then
					faiscas(ponto, dir, quando + 0.07, if i == #cortes then 12 else 8, if spec.gelo then Color3.fromRGB(190, 232, 255) else nil)
					clarao(ponto, quando + 0.07, if primeiro.critico then 4.2 elseif i == #cortes then 3.4 else 2.4, if spec.gelo then Color3.fromRGB(190, 232, 255) else nil)
				end
				if spec.gelo then
					K.evento(cena, quando + 0.07, function() K.Efeitos.floatText(alvoPos + Y * 2.5, "❄", Color3.fromRGB(190, 232, 255)) end)
				end
			end
			if spec.baixo then poeira(alvoPos, W + 0.07, 6, 3) end
			if spec.preciso then
				-- Corte de Braço: linha fina e clara sobre o membro.
				talho(alvoPos + Y * 0.4, dir, 62, 2.2, W + 0.02, 0.14, Color3.fromRGB(255, 255, 255))
			end
			plan.chegada = golpeFim + 0.07
		end
		return plan
	end

	-- Investida: o corpo atravessa o campo ---------------------------------------
	if g == "investida" then
		local tr = recibo.trajeto
		local ok = abrir()
		local a, b
		if tr and #tr == 2 then
			a, b = K.celula(tr[1]), K.celula(tr[2])
		elseif de and alvoPos then
			a, b = plano(de), plano(alvoPos)
		else
			return nil
		end
		local y = if ok then f.base.Y else (de and de.Y or 3)
		local A, B = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
		local dir = unit(B - A)
		local dist = plano(B - A).Magnitude
		local est = spec.estilo
		local pesada = est == "devastadora"
		local W = if pesada then 0.34 else 0.14
		local corrida = math.clamp(dist / (if pesada then 34 else 56), 0.22, 0.75)
		local golpe = 0.1
		local total = W + corrida + golpe + 0.3 + 0.2
		local alvoFinal = if alvoPos then alvoPos else B + dir * 2
		local olhar = if alvoPos then unit(alvoPos - B) else dir
		if ok then
			arma(if est == "quadrupede" then "espada" else (spec.prop or tipoDaArma()))
			for i = 1, 3 do sombra(W + corrida * i / 4, 0.28) end
			anim(0, "toolnone", { repete = true, prioridade = Enum.AnimationPriority.Action })
			anim(W * 0.5, "run", { repete = true, velocidade = 1.8, prioridade = Enum.AnimationPriority.Movement })
			pararAnim(W + corrida, "run")
			anim(W + corrida - 0.04, if est == "quadrupede" then "toollunge" else "toolslash", { velocidade = 1.5, prioridade = GOLPE })
			rodar(total, function(s)
				local pos, pitch, d, e, trn = A, 0, -0.9, -0.5, 0
				local look = dir
				if s < W then
					pos = A - dir * 0.7 * suave(s / W)
					d = if pesada then entre(0, 2.6, s / W) else entre(0, -1.4, s / W)
					trn = -0.3
					pitch = 0
				elseif s < W + corrida then
					local u = (s - W) / corrida
					local lat = if est == "quadrupede" then math.sin(u * math.pi * 3) * 1.1 else 0
					local lado = dir:Cross(Y)
					pos = (A - dir * 0.7):Lerp(B, u ^ 0.8) + lado * lat + Y * math.abs(math.sin(u * math.pi * (dist / 8))) * 0.35
					pitch = -(if est == "quadrupede" then 1.15 else 0.45)
					d = if est == "quadrupede" then -1.5 else (if pesada then 2.6 else -1.3)
					e = if est == "quadrupede" then -1.5 else -0.4
					trn = 0.2
				else
					pos = B
					look = olhar
					local u = (s - W - corrida) / golpe
					d = if pesada then entre(2.6, 0.2, suave(u)) else entre(-1.3, 1.7, suave(u))
					e = if est == "quadrupede" then 1.5 else -0.4
					trn = if u < 1 then 0.4 else entre(0.4, 0, (s - W - corrida - golpe) / 0.4)
				end
				return { pos = pos, olhar = look, pitch = pitch, d = d, e = e, tr = trn }
			end)
			-- O corpo real foi levado pelo servidor: some o fantasma só quando
			-- ele chega perto (ou em 2,5 s), para não "voltar" no meio da corrida.
			K.animar(cena, total, 2.5, function(t)
				if not f.escondido then return end
				local raiz = modelo and modelo:FindFirstChild("HumanoidRootPart")
				local perto = not raiz or plano(raiz.Position - B).Magnitude < 3.5
				if perto or t >= 1 then
					revelar()
				end
			end)
		end
		-- Rastro de vento e poeira ao longo do caminho.
		for i = 1, 6 do
			local u = i / 7
			local p = A:Lerp(B, u)
			if i % 2 == 0 then poeira(p, W + corrida * u, 5, 1.8) end
		end
		for i = 1, 4 do
			local seg = K.peca(cena, "fio", cor)
			local lado = dir:Cross(Y) * ((i - 2.5) * 1.1)
			K.animar(cena, W, corrida + 0.1, function(t)
				local a1 = A:Lerp(B, math.clamp(t, 0, 1)) + lado + Y * (0.4 + i * 0.5)
				K.segmento(seg, a1 - dir * (1.8 + 3 * t), a1, 0.08, 0.3 + t * 0.6)
			end)
		end
		local tImp = W + corrida + golpe * 0.6
		if est == "espada" then
			talho(alvoFinal - olhar * 0.5, olhar, 88, 4.8, tImp, 0.22)
			talho(alvoFinal - olhar * 0.5, olhar, 60, 3.6, tImp + 0.05, 0.2)
			faiscas(alvoFinal - olhar * 1.1, olhar, tImp + 0.05, 14)
			clarao(alvoFinal - olhar * 1.1, tImp + 0.05, 4.2)
		elseif est == "quadrupede" then
			for i = 1, 3 do
				talho(alvoFinal - olhar * 0.5 + dir:Cross(Y) * ((i - 2) * 0.9), olhar, 62 + i * 3, 3.2, tImp + i * 0.03, 0.2)
			end
			faiscas(alvoFinal - olhar * 1.1, olhar, tImp + 0.05, 10)
		else
			K.arco(cena, K.chao(alvoFinal), 9, tImp, 0.5, false, math.pi * 2, 0, cor)
			K.arco(cena, K.chao(alvoFinal), 5.5, tImp + 0.05, 0.45, false, math.pi * 2, 0.5, cor)
			poeira(alvoFinal, tImp, 12, 5)
			faiscas(alvoFinal - olhar, olhar, tImp, 14, nil, 3.6)
			for i = 1, 4 do
				local ang = i * math.pi / 2 + 0.4
				local fim = K.chao(alvoFinal) + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 6
				local rachadura = K.peca(cena, "fio", Color3.fromRGB(40, 32, 28), Enum.Material.Slate)
				K.animar(cena, tImp, 0.9, function(t)
					K.segmento(rachadura, K.chao(alvoFinal), K.chao(alvoFinal):Lerp(fim, suave(t * 2)), 0.28, 0.1 + t ^ 2 * 0.9)
				end)
			end
			K.evento(cena, tImp, function() K.Efeitos.tremer(0.6, 0.35) end)
		end
		plan.chegada = tImp
		return plan
	end

	-- Provocar: grito, onda de choque e marca de ódio ----------------------------
	if g == "grito" then
		local ok = abrir()
		local origem = if ok then f.base else (de or Vector3.zero)
		local alcance = 8
		for _, a in alvos do
			alcance = math.max(alcance, plano(K.posicaoDe(state, a.id, a.casa) - origem).Magnitude + 2)
		end
		alcance = math.min(alcance, 70)
		if ok then
			local olho = if alvoPos then unit(alvoPos - origem) else Vector3.zAxis
			arma(if spec.soberano then "escudo" else "espada")
			anim(0, if spec.soberano then "cheer" else "point", { velocidade = 1.4, prioridade = GOLPE })
			rodar(0.9, function(s)
				local u = math.clamp(s / 0.25, 0, 1)
				local salto = math.sin(math.clamp((s - 0.05) / 0.5, 0, 1) * math.pi) * 0.9
				return {
					pos = f.base + Y * salto, olhar = olho,
					d = entre(0, 2.4, suave(u)), dl = 0.25,
					e = if spec.soberano then 1.5 else entre(0, 2.0, suave(u)), el = 0.35,
					tr = -0.35 * (1 - suave((s - 0.3) / 0.4)), pitch = 0,
				}
			end)
		end
		local velocidade = 0.62
		for i = 1, if spec.soberano then 4 else 3 do
			K.arco(cena, K.chao(origem), alcance, 0.12 + i * 0.09, velocidade, false, math.pi * 2, i, cor)
		end
		K.evento(cena, 0.12, function() K.Efeitos.tremer(if spec.soberano then 0.4 else 0.25, 0.3) end)
		poeira(origem, 0.1, 10, 4)
		for i, a in alvos do
			local p = K.posicaoDe(state, a.id, a.casa)
			local quando = 0.12 + math.clamp(plano(p - origem).Magnitude / alcance, 0, 1) * velocidade
			local fio = K.peca(cena, "fio", Color3.fromRGB(230, 70, 70))
			K.animar(cena, quando, 0.7, function(t)
				K.segmento(fio, origem + Y * 2.5, p + Y * 2, 0.07 + 0.08 * math.sin(math.pi * t * 4) ^ 2, 0.2 + t * 0.8)
			end)
			K.evento(cena, quando, function()
				if a.passou then
					K.Efeitos.floatText(p + Y * 5, "RESISTIU", cena.cor)
				else
					K.Efeitos.floatText(p + Y * 5, "!!", Color3.fromRGB(230, 70, 70))
					K.Efeitos.reagir(a.id, origem - p, 0.5)
				end
			end)
		end
		return { semCirculo = true, semViagem = true, impactoProprio = true, chegada = 0.12 + velocidade, semTextos = true }
	end

	-- Puxar: corrente de luz do escudeiro até o aliado ---------------------------
	if g == "corrente" then
		local ok = abrir()
		local origem = if ok then f.base else (de or Vector3.zero)
		for _, a in alvos do
			local p = K.posicaoDe(state, a.id, a.casa)
			local elos = {}
			for _ = 1, 12 do table.insert(elos, K.peca(cena, "bloco", cor, Enum.Material.Metal)) end
			K.animar(cena, 0.1, 0.7, function(t)
				local lanca = suave(t * 3)
				local volta = suave((t - 0.45) * 2.2)
				local alvoX = (origem + Y * 2.5):Lerp(p + Y * 2, lanca * (1 - volta * 0.55))
				for i, elo in elos do
					local u = i / #elos
					elo.CFrame = CFrame.lookAt((origem + Y * 2.5):Lerp(alvoX, u) + Y * math.sin(u * math.pi) * 0.6, alvoX)
					elo.Size = Vector3.new(0.45, 0.45, 0.9)
					elo.Transparency = 0.1 + math.max(0, t - 0.8) * 4.5
				end
			end)
			K.arco(cena, K.chao(p), 3.4, 0.15, 0.5, false, math.pi * 2, 0, cor)
		end
		if ok then
			local olho = if alvoPos then unit(alvoPos - origem) else Vector3.zAxis
			anim(0, "point", { velocidade = 1.5, prioridade = GOLPE })
			rodar(0.9, function(s)
				return { pos = f.base - olho * 0.7 * math.sin(math.clamp((s - 0.4) / 0.4, 0, 1) * math.pi), olhar = olho,
					d = if s < 0.25 then entre(0, 1.5, s / 0.25) else entre(1.5, 0.3, (s - 0.45) / 0.4), e = 0.3,
					tr = if s > 0.35 and s < 0.8 then -0.35 else 0.1 }
			end)
		end
		return { semCirculo = true, semViagem = true, chegada = 0.3 }
	end

	-- Disparo: arco na mão, corda puxada, a flecha sai do Coreografia -----------
	if g == "disparo" then
		local ok = abrir()
		local carga = 0.5
		if ok then
			local origem = f.base
			local olho = if alvoPos then unit(alvoPos - origem) else Vector3.zAxis
			arma("arco")
			anim(0, "point", { velocidade = 0.9, prioridade = GOLPE })
			rodar(carga + 0.45, function(s)
				local puxa = suave(s / carga)
				local solta = if s > carga then suave((s - carga) / 0.08) else 0
				return {
					pos = origem - olho * 0.25 * puxa * (1 - solta), olhar = olho,
					e = 1.5, d = entre(0.6, 1.45, puxa) - solta * 0.6, dl = 0.55 * puxa * (1 - solta),
					tr = 0.1, tg = -0.35 * puxa * (1 - solta),
				}
			end)
		end
		local res = { semCirculo = true, carga = carga }
		if spec.prende then
			res.impactoExtra = function(ponto, quando)
				K.arco(cena, K.chao(ponto), 2.6, quando, 0.6, false, math.pi * 2, 0, cor)
				for i = 1, 3 do
					local p = K.peca(cena, "fio", cor)
					local ang = i * math.pi * 2 / 3
					local b = K.chao(ponto) + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 2.4
					K.animar(cena, quando, 0.8, function(t)
						K.segmento(p, b, K.chao(ponto) + Y * 0.8, 0.1, 0.2 + t * 0.8)
					end)
				end
			end
		end
		return res
	end

	-- Arremesso de espada ------------------------------------------------------
	if g == "arremesso" then
		if not alvoPos then return nil end
		local ok = abrir()
		local origem = if ok then f.base else (de or alvoPos)
		local dir = unit(alvoPos - origem)
		local voo = math.clamp(plano(alvoPos - origem).Magnitude / 85, 0.2, 0.55)
		local lamina = K.peca(cena, "bloco", Color3.fromRGB(215, 220, 232), Enum.Material.Metal)
		local guarda = K.peca(cena, "bloco", Color3.fromRGB(120, 88, 60), Enum.Material.Wood)
		if ok then
			anim(0.12, "toolslash", { velocidade = 1.4, prioridade = GOLPE })
			rodar(0.8, function(s)
				return { pos = origem - dir * 0.4 * (1 - suave(s / 0.2)), olhar = dir,
					d = if s < 0.2 then entre(0, -1.5, s / 0.2) else entre(-1.5, 1.7, (s - 0.2) / 0.08) - (s - 0.28) * 0.3, e = -0.4,
					tr = if s < 0.2 then -0.3 else 0.35 }
			end)
		end
		K.animar(cena, 0.28, voo, function(t)
			local p = (origem + Y * 3.2):Lerp(alvoPos, t) + Y * math.sin(math.pi * t) * 1.3
			local giro = t * math.pi * 2 * 4
			local cf = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, giro)
			if lamina and guarda then
				lamina.Size, guarda.Size = Vector3.new(0.2, 0.5, 3.4), Vector3.new(0.3, 1.2, 0.3)
				lamina.CFrame = cf
				guarda.CFrame = cf * CFrame.new(0, 0, 1.6)
				lamina.Transparency, guarda.Transparency = 0, 0
			end
		end)
		K.evento(cena, 0.28 + voo, function()
			K.Efeitos.tremer(0.2, 0.15)
			if lamina then
				lamina.CFrame = CFrame.lookAt(alvoPos - dir * 0.4, alvoPos + dir) * CFrame.Angles(0.1, 0, 0)
				guarda.CFrame = lamina.CFrame * CFrame.new(0, 0, 1.6)
			end
		end)
		K.animar(cena, 0.28 + voo + 0.05, 0.7, function(t)
			if lamina then lamina.Transparency = math.max(0, (t - 0.7) * 3.3); guarda.Transparency = lamina.Transparency end
		end)
		faiscas(alvoPos - dir, dir, 0.28 + voo, 8)
		return { semCirculo = true, semViagem = true, impactoProprio = true, chegada = 0.28 + voo }
	end

	-- Conjuro: pose de mãos antes de soltar a magia ---------------------------------
	if g == "conjuro" then
		local ok = abrir()
		if not ok then
			return nil
		end
		local carga = cena.perfil.carga
		local origem = f.base
		local olho = if alvoPos then unit(alvoPos - origem) else Vector3.new(0, 0, 1)
		if spec.prop then arma(spec.prop) end
		anim(0, if spec.pose == "palmas" then "cheer" elseif spec.pose == "empunhar" then "toolnone" else "point",
			{ velocidade = 1.2, prioridade = GOLPE })
		local palmas = spec.pose == "palmas"
		local empunhar = spec.pose == "empunhar"
		rodar(carga + 0.5, function(s)
			local u = suave(s / math.max(carga, 0.1))
			local chute = if s > carga then math.sin(math.clamp((s - carga) / 0.2, 0, 1) * math.pi) * 0.4 else 0
			local flutua = if palmas then 0.5 * u * (1 - suave((s - carga - 0.2) / 0.3)) else 0
			return {
				pos = origem + Y * flutua - olho * chute * 0.5, olhar = olho,
				d = if empunhar then entre(0, 1.4, u) else (if palmas then entre(0, 1.2, u) else entre(0.2, 1.55, u)) + chute,
				e = if palmas then entre(0, 1.2, u) else (if empunhar then 0.2 else -0.3),
				dl = if palmas then 0.35 * u else 0, el = if palmas then 0.35 * u else 0,
				tr = if palmas then -0.15 * u else 0.1 * u,
			}
		end)
		return { carga = nil }
	end
	return nil
end

return Gestos
