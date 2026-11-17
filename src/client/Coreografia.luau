-- Coreografia das árvores: o recibo já foi resolvido pelo servidor.
-- Uma conexão de render, cenas canceláveis e orçamento de peças. Sem assets
-- enviados e sem alterar ficha, colisão, câmera ou posição autoritativa.
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Estilo = require(Shared.Estilo)
local Protocol = require(Shared.MesaProtocol)
local Execucao = require(Shared.Regras.Execucao)
local Efeitos = require(script.Parent.Efeitos)
local Gestos = require(script.Parent.Gestos)
local Sons = require(Shared.Sons)
local Sonorizacao = require(script.Parent.Sonorizacao)
local FX = require(script.Parent.MenuEfeitos)
local Feedback = require(script.Parent.FeedbackCombate)
local ImpactoCamera = require(script.Parent.ImpactoCamera) -- IMP1: câmera, faíscas, rastro, hit-stop
local ImpactoFx = require(script.Parent.ImpactoFx)
local Curvas = require(Shared.ImpactoCurvas)
local ReacoesAlvo = require(Shared.ReacoesAlvo)
local AnimacaoCriatura = require(Shared.Mundo.AnimacaoCriatura)
local CatalogoCriaturas = require(Shared.Animacoes.Criaturas.Catalogo)

-- ANIM3: instante (s após o recibo) em que o golpe de uma criatura encosta: marco `impacto` do clipe de ataque dela
-- (o servidor começa o clipe ao enviar o recibo). nil se não é criatura ou o clipe não marca.
local function impactoDaCriatura(state, casterId)
	local snap = state.snapshot()
	if not snap or not casterId then return nil end
	for _, t in snap.tokens do
		if t.id == casterId then
			local nome = if type(t.criatura) == "string" then t.criatura elseif type(t.modelo) == "string" then t.modelo else nil
			if not nome or nome == "" then return nil end
			local dados = CatalogoCriaturas[string.upper(string.sub(nome, 1, 1)) .. string.sub(nome, 2) .. "Quaternius"]
			local _, clipe = AnimacaoCriatura.clipeDe(dados, "ataque")
			return AnimacaoCriatura.marcoImpacto(clipe)
		end
	end
	return nil
end

local Coreografia = {}
local MAX_CENAS, MAX_PECAS, MAX_POR_CENA = 6, 640, 170
local Y = Vector3.yAxis
local PERFIS = {
	agua = { familia = "corrente", carga = 0.38, viagem = 0.38, peso = 0.35 },
	vento = { familia = "vento", carga = 0.24, viagem = 0.24, peso = 0.2 },
	terra = { familia = "pedra", carga = 0.58, viagem = 0.3, peso = 0.65 },
	cura = { familia = "vida", carga = 0.42, viagem = 0.25, peso = 0 },
	desintoxicacao = { familia = "alquimia", carga = 0.38, viagem = 0.35, peso = 0.15 },
	teorica = { familia = "geometria", carga = 0.42, viagem = 0.24, peso = 0.3 },
	invocacao = { familia = "portal", carga = 0.58, viagem = 0.25, peso = 0.3 },
	["deus-da-espada"] = { familia = "corte", carga = 0.22, viagem = 0.13, peso = 0.5 },
	["deus-da-agua-corpo"] = { familia = "guarda", carga = 0.28, viagem = 0.2, peso = 0.3 },
	["deus-do-norte"] = { familia = "astucia", carga = 0.18, viagem = 0.2, peso = 0.4 },
	["armas-pesadas"] = { familia = "peso", carga = 0.45, viagem = 0.12, peso = 0.8 },
	["cavalaria-e-escudos"] = { familia = "escudo", carga = 0.34, viagem = 0.2, peso = 0.5 },
	arquearia = { familia = "flecha", carga = 0.3, viagem = 0.28, peso = 0.25 },
	basico = { familia = "corte", carga = 0.2, viagem = 0.2, peso = 0.3 },
	fogo = { familia = "chama", carga = 0.35, viagem = 0.3, peso = 0.3 },
	["furtividade-e-armadilhas"] = { familia = "astucia", carga = .2, viagem = .2, peso = .35, nova = true },
	["bardo-e-interacao"] = { familia = "ritmo", carga = .3, viagem = .2, peso = .1, nova = true },
	["navegacao-e-lideranca"] = { familia = "comando", carga = .25, viagem = .2, peso = .1, nova = true },
}
local function arvore(id)
	if id == "mesa/esconder" then return "furtividade-e-armadilhas" end
	if string.sub(id, 1, 5) == "mesa/" and Execucao.MECANICAS[id] and Execucao.MECANICAS[id].arvore then return Execucao.MECANICAS[id].arvore end
	if string.sub(id, 1, 20) == "mesa/lamina-de-gelo-" then return "agua" end
	if string.sub(id, 1, 9) == "invocado/" then return "invocacao" end
	if string.sub(id, 1, 12) == "mesa/ataque-" or string.sub(id, 1, 9) == "criatura/" then return "basico" end
	return string.match(id, "^%a+/([^/]+)/")
end
local function direcao(de, para)
	local delta = para - de
	return if delta.Magnitude > 0.001 then delta.Unit else Vector3.zAxis
end
local function chao(p)
	return Vector3.new(p.X, Protocol.BOARD.origin.Y + 0.22, p.Z)
end
local function suave(t) return 1 - (1 - t) ^ 3 end
-- Ponto na frente do corpo do alvo (modelo de criatura), visto de `de`: o projétil crava na superfície,
-- não no centro (senão a flecha some dentro do corpo).
local function meioDoCorpo(id, de)
	local corpos = workspace:FindFirstChild("CorposDeCriatura")
	local m = corpos and corpos:FindFirstChild(id)
	if m and m:IsA("Model") then
		local cf, tam = m:GetBoundingBox()
		local centro = cf.Position + Vector3.new(0, tam.Y * 0.05, 0)
		local plano = Vector3.new(centro.X - de.X, 0, centro.Z - de.Z)
		if plano.Magnitude < 1e-3 then return centro end
		return centro - plano.Unit * math.min(tam.X, tam.Z) * 0.4
	end
	return nil
end

function Coreografia.start(state, pasta, posicaoDe, chaoDe, centroCasa)
	local chao = chaoDe or chao
	local celula = centroCasa or Protocol.cellCenter
	local cenas, pecas, serial = {}, 0, 0
	local kit = { state = state, posicaoDe = posicaoDe, Efeitos = Efeitos }
	local encerrado = false
	local pausar, golpeFinal -- IMP1/IMP2: definidas junto de tempoDe
	local function destruir(cena)
		if cena.viva then
			cena.viva = false
			for _, fn in cena.limpezas do pcall(fn) end
			pecas -= cena.pecas
			cena.modelo:Destroy()
			table.clear(cena.jobs)
		end
	end
	local function limpar()
		for _, cena in cenas do destruir(cena) end
		table.clear(cenas)
	end
	local function nova(id, perfil, cor)
		while #cenas >= MAX_CENAS do destruir(table.remove(cenas, 1)) end
		serial += 1
		local modelo = Instance.new("Model")
		modelo.Name = "Cena_" .. serial
		modelo:SetAttribute("Habilidade", id)
		modelo:SetAttribute("Familia", perfil.familia)
		modelo:SetAttribute("Fase", "preparacao")
		modelo.Parent = pasta
		local cena = { modelo = modelo, viva = true, pecas = 0, jobs = {}, limpezas = {}, inicio = os.clock(), fim = 0, cor = cor, perfil = perfil }
		table.insert(cenas, cena)
		return cena
	end
	local function animar(cena, inicio, duracao, atualizar)
		cena.fim = math.max(cena.fim, inicio + duracao + 0.1)
		table.insert(cena.jobs, { inicio = inicio, duracao = math.max(0.001, duracao), atualizar = atualizar })
	end
	local function evento(cena, quando, callback)
		animar(cena, quando, 0.001, function(_, job)
			if not job.executado then job.executado = true; callback() end
		end)
	end
	local function peca(cena, forma, cor, material)
		if cena.pecas >= MAX_POR_CENA or pecas >= MAX_PECAS then return nil end
		local p = Instance.new(if forma == "cunha" then "WedgePart" else "Part")
		p.Name = forma
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Material, p.Color, p.Transparency = material or Enum.Material.Neon, cor or cena.cor, 1
		p.Size = Vector3.one * 0.2
		if forma == "gota" then p.Shape = Enum.PartType.Ball end
		p.Parent = cena.modelo
		cena.pecas += 1; pecas += 1
		return p
	end
	local function segmento(p, a, b, largura, transpar)
		if not p then return end
		local dist = (b - a).Magnitude
		p.Size = Vector3.new(largura, largura, math.max(0.02, dist))
		p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + direcao(a, b))
		p.Transparency = math.clamp(transpar, 0, 1)
	end
	-- Arco em fita: contorno aberto, preserva a leitura do tabuleiro no centro.
	local function arco(cena, centro, raio, inicio, duracao, vertical, abertura, giro, cor)
		local pontos = {}
		for _ = 1, 12 do table.insert(pontos, peca(cena, "fio", cor)) end
		animar(cena, inicio, duracao, function(t)
			local r = raio * (0.4 + 0.6 * suave(t))
			local base = CFrame.new(centro) * CFrame.Angles(if vertical then math.pi / 2 else 0, giro + t * 0.9, 0)
			for i, p in pontos do
				local a = (i - 1) / 12 * abertura
				local b = i / 12 * abertura
				segmento(p, base:PointToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)), base:PointToWorldSpace(Vector3.new(math.cos(b) * r, 0, math.sin(b) * r)), 0.1 + (1 - t) * 0.12, 0.1 + t ^ 2 * 0.9)
			end
		end)
	end
	local function fragmentos(cena, centro, inicio, peso, cor, cristal)
		for i = 1, 8 do
			local p = peca(cena, if cristal then "cunha" else "gota", cor, if cristal then Enum.Material.Glass else Enum.Material.Neon)
			if p then
				local angulo = i * math.pi / 4
				local vetor = Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * (2 + peso * 2)
				animar(cena, inicio, 0.58, function(t)
					p.CFrame = CFrame.new(centro + vetor * suave(t) + Y * (math.sin(t * math.pi) * (1 + peso) - t * 1.3)) * CFrame.Angles(t * 4, angulo + t * 3, t)
					p.Size = Vector3.new(0.2, if cristal then 1.3 else 0.35, 0.3) * (1 - 0.7 * t)
					p.Transparency = 0.15 + t ^ 2 * 0.85
				end)
			end
		end
	end
	local function espiral(cena, ponto, inicio, cor)
		for i = 1, 12 do
			local p = peca(cena, "gota", cor)
			if p then
				animar(cena, inicio + (i % 3) * 0.04, 1.1, function(t)
					local angulo = i * math.pi / 6 + t * math.pi * 2
					local r = 2.1 * (1 - t * 0.65)
					p.Position = ponto + Vector3.new(math.cos(angulo) * r, -2 + t * 6, math.sin(angulo) * r)
					p.Size = Vector3.one * (0.2 + math.sin(math.pi * t) * 0.35)
					p.Transparency = 0.2 + t ^ 3 * 0.8
				end)
			end
		end
		arco(cena, chao(ponto), 3, inicio, 0.9, false, math.pi * 2, 0, cor)
	end
	local function cristal(cena, ponto, inicio)
		for i = 1, 3 do
			local p = peca(cena, "cunha", Estilo.misturar(cena.cor, Estilo.TINTA, 0.3), Enum.Material.Glass)
			if p then
				local angulo = i * math.pi * 2 / 3
				local base = chao(ponto) + Vector3.new(math.cos(angulo) * 1.5, 0, math.sin(angulo) * 1.5)
				animar(cena, inicio + i * 0.03, 0.75, function(t)
					local h = 5 * suave(math.min(t / 0.35, 1))
					p.Size = Vector3.new(0.65, math.max(0.05, h), 1.1)
					p.CFrame = CFrame.new(base + Y * h / 2) * CFrame.Angles(0, angulo, math.rad(12))
					p.Transparency = 0.22 + math.max(0, (t - 0.5) * 1.56)
				end)
			end
		end
	end
	local function pedra(cena, ponto, inicio)
		for i = 1, 5 do
			local p = peca(cena, "bloco", Estilo.misturar(cena.cor, Estilo.PAPEL_2, 0.5), Enum.Material.Slate)
			if p then
				local angulo = i * math.pi * 2 / 5
				local base = chao(ponto) + Vector3.new(math.cos(angulo) * 2, 0, math.sin(angulo) * 2)
				animar(cena, inicio + i * 0.025, 0.75, function(t)
					local h = (3 + i % 2) * math.sin(math.min(1, t * 2) * math.pi / 2)
					p.CFrame = CFrame.new(base + Y * (h / 2 - math.max(0, t - 0.6) * 3)) * CFrame.Angles(0.2, angulo, 0.15)
					p.Size = Vector3.new(1.25, math.max(0.1, h), 1.25)
					p.Transparency = math.max(0, (t - 0.55) / 0.45)
				end)
			end
		end
		arco(cena, chao(ponto), 4, inicio + 0.12, 0.55, false, math.pi * 2, 0)
	end
	-- Projéteis (LUTA-A): cada família tem forma, velocidade, arco e rastro próprios. Voo em bezier
	-- quadrática (altura = ARCO x distância), alinhado à tangente. A flecha crava no alvo (ou no chão, se
	-- errou), fica ~1,5 s e some; as magias somem no impacto (os efeitos de `impacto` assumem dali).
	local VOO = {
		flecha = { vel = 60, arco = 0.15, rastro = 0.12, largura = 0.12 },
		corrente = { vel = 38, arco = 0.22, rastro = 0.22, largura = 0.45 },
		pedra = { vel = 46, arco = 0.12, rastro = 0.2, largura = 0.5 },
		vento = { vel = 58, arco = 0.03, rastro = 0.18, largura = 0.6 },
		chama = { vel = 34, arco = 0.1, rastro = 0.25, largura = 0.7 },
		padrao = { vel = 40, arco = 0.12, rastro = 0.2, largura = 0.4 },
	}
	local function voo(familia) return VOO[familia] or VOO.padrao end
	local function duracaoDoVoo(familia, distancia)
		return math.clamp(distancia / voo(familia).vel, 0.1, 0.9)
	end
	-- Peças da forma de cada família, em volta de um quadro que olha para a frente (-Z).
	local MADEIRA, PENA, ACO = Color3.fromRGB(120, 84, 52), Color3.fromRGB(236, 230, 214), Color3.fromRGB(215, 220, 232)
	local function forma(cena, familia)
		local partes = {}
		local function por(p, tamanho, desloc, transp)
			if not p then return nil end
			p.Size = tamanho
			table.insert(partes, { p = p, d = desloc, transp = transp or 0 })
			return p
		end
		if familia == "flecha" then
			por(peca(cena, "haste", MADEIRA, Enum.Material.Wood), Vector3.new(0.12, 0.12, 2.7), CFrame.identity)
			por(peca(cena, "ponta", ACO, Enum.Material.Metal), Vector3.new(0.24, 0.24, 0.42), CFrame.new(0, 0, -1.5) * CFrame.Angles(0, 0, math.rad(45)))
			for i = 0, 2 do
				local giro = CFrame.Angles(0, 0, i * math.pi * 2 / 3)
				por(peca(cena, "cunha", if i == 0 then Color3.fromRGB(196, 64, 52) else PENA, Enum.Material.SmoothPlastic),
					Vector3.new(0.04, 0.3, 0.62), giro * CFrame.new(0, 0.2, 1.05) * CFrame.Angles(0, math.pi, 0))
			end
		elseif familia == "corrente" then
			local gota = por(peca(cena, "gota", cena.cor, Enum.Material.Glass), Vector3.new(0.7, 0.7, 0.7), CFrame.identity, 0.15)
			if gota then
				local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Scale = Vector3.new(1, 1, 1.9); m.Parent = gota
			end
			por(peca(cena, "gota", Color3.fromRGB(230, 248, 255)), Vector3.new(0.32, 0.32, 0.32), CFrame.new(0, 0, -0.15))
		elseif familia == "pedra" then
			por(peca(cena, "bloco", Estilo.misturar(cena.cor, Color3.fromRGB(110, 96, 80), 0.55), Enum.Material.Slate), Vector3.new(0.75, 0.75, 1.0), CFrame.Angles(0.4, 0.3, 0.2))
			por(peca(cena, "cunha", Color3.fromRGB(140, 124, 104), Enum.Material.Slate), Vector3.new(0.6, 0.5, 0.9), CFrame.new(0, 0, -0.75) * CFrame.Angles(math.pi / 2, 0, 0))
		elseif familia == "vento" then
			local disco = por(peca(cena, "disco", cena.cor), Vector3.new(0.08, 1.8, 1.8), CFrame.Angles(0, 0, math.pi / 2), 0.35)
			if disco then disco.Shape = Enum.PartType.Cylinder end
		else
			por(peca(cena, "gota", Color3.fromRGB(255, 244, 214)), Vector3.new(0.55, 0.55, 0.55), CFrame.identity)
			por(peca(cena, "gota", cena.cor), Vector3.new(1.1, 1.1, 1.1), CFrame.identity, 0.45)
		end
		return partes
	end
	local function estilhacos(cena, ponto, dir, quando, cor, n, poeira)
		for i = 1, n do
			local p = peca(cena, if poeira then "gota" else "fio", cor, if poeira then Enum.Material.SmoothPlastic else nil)
			if p then
				local ang = i * math.pi * 2 / n
				local lado = dir:Cross(Y)
				lado = if lado.Magnitude > 1e-3 then lado.Unit else Vector3.xAxis
				local v = (-dir * 0.7 + lado * math.cos(ang) + Y * (0.6 + math.sin(ang) * 0.5)).Unit * (if poeira then 1.6 else 2.2)
				animar(cena, quando, if poeira then 0.5 else 0.25, function(t)
					if poeira then
						p.Position = ponto + v * suave(t)
						p.Size = Vector3.one * (0.3 + t * 0.8)
						p.Transparency = 0.4 + t * 0.6
					else
						segmento(p, ponto + v * suave(t) * 0.5, ponto + v * suave(t), 0.1 - 0.06 * t, 0.05 + t ^ 2 * 0.95)
					end
				end)
			end
		end
	end
	-- de/para: pontos do mundo; origem(): ponto de saída na hora do disparo (mão), se houver.
	local function flecha(cena, de, para, inicio, duracao, familia, acertou, origem)
		local v = voo(familia)
		local partes = forma(cena, familia)
		if #partes == 0 then return end
		local principal = partes[1].p
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, v.largura / 2, 0.4), Vector3.new(0, -v.largura / 2, 0.4)
		a0.Parent, a1.Parent = principal, principal
		local rastro = Instance.new("Trail")
		rastro.Attachment0, rastro.Attachment1, rastro.FaceCamera = a0, a1, true
		rastro.Color = if familia == "flecha" then ColorSequence.new(Color3.fromRGB(255, 246, 220)) else ColorSequence.new(cena.cor, Estilo.TINTA)
		rastro.Transparency = NumberSequence.new(if familia == "flecha" then 0.45 else 0.15, 1)
		rastro.Lifetime, rastro.LightEmission, rastro.Enabled = v.rastro, 0.7, false
		rastro.Parent = principal
		local saida, controle
		local ultimo = CFrame.new(para)
		local function posar(cf, transpExtra)
			for _, q in partes do
				q.p.CFrame = cf * q.d
				q.p.Transparency = math.clamp(q.transp + (transpExtra or 0), 0, 1)
			end
		end
		animar(cena, inicio, duracao, function(t)
			if not saida then
				saida = if origem then (origem() or de) else de
				local d = (para - saida).Magnitude
				controle = (saida + para) / 2 + Y * (2 * math.min(v.arco * d, 3)) -- teto: câmera perto
			end
			local u = 1 - t
			local ponto = saida * u * u + controle * 2 * u * t + para * t * t
			local tangente = (controle - saida) * 2 * u + (para - controle) * 2 * t
			if tangente.Magnitude < 1e-3 then tangente = direcao(saida, para) end
			local giro = if familia == "pedra" or familia == "vento" then CFrame.Angles(0, 0, t * 14) else CFrame.identity
			ultimo = CFrame.lookAt(ponto, ponto + tangente.Unit)
			posar(ultimo * giro)
			rastro.Enabled = t < 1
			if t >= 1 and familia ~= "flecha" then posar(ultimo, 1) end
		end)
		if familia == "flecha" then
			-- crava: entra ~0,9 stud na direção do voo, treme de leve, fica 1,5 s e some
			local fim = inicio + duracao
			animar(cena, fim, 1.8, function(t)
				local s = t * 1.8
				local tremor = math.sin(s * 60) * math.max(0, 0.25 - s) * 0.25
				posar(ultimo * CFrame.new(0, 0, -0.55) * CFrame.Angles(tremor, tremor * 0.6, 0), math.clamp((s - 1.5) / 0.3, 0, 1))
			end)
			evento(cena, fim, function()
				local ponta = ultimo.Position + ultimo.LookVector * 0.6
				if acertou then
					estilhacos(cena, ponta, ultimo.LookVector, fim, Color3.fromRGB(255, 226, 150), 7)
					Efeitos.tremer(0.18, 0.14)
				else
					estilhacos(cena, ponta, ultimo.LookVector, fim, Color3.fromRGB(150, 132, 108), 6, true)
				end
			end)
		elseif familia == "pedra" then
			evento(cena, inicio + duracao, function()
				estilhacos(cena, para, direcao(de, para), inicio + duracao, Color3.fromRGB(150, 132, 108), 7, true)
			end)
		end
	end
	local function escudo(cena, ponto, inicio)
		arco(cena, ponto, 3.3, inicio, 0.9, true, math.pi * 2, 0)
		local pontos = { Vector3.new(-1.8, 1.4, 0), Vector3.new(1.8, 1.4, 0), Vector3.new(1.3, -0.9, 0), Vector3.new(0, -2.1, 0), Vector3.new(-1.3, -0.9, 0) }
		for i = 1, 5 do
			local p = peca(cena, "fio")
			animar(cena, inicio + 0.1, 0.8, function(t)
				local cf = CFrame.new(ponto) * CFrame.Angles(0, t * 0.5, 0)
				segmento(p, cf:PointToWorldSpace(pontos[i]), cf:PointToWorldSpace(pontos[i % 5 + 1]), 0.14, t ^ 2)
			end)
		end
	end
	local function impacto(cena, ponto, de, inicio, alvo, familia, gelo, proprio, semTextos)
		local acertou = alvo.acertou ~= false
		if proprio then
			-- o gesto do corpo já desenhou o golpe
		elseif not acertou then
			arco(cena, ponto, 1.6, inicio, 0.3, false, math.pi * 0.7, 0, Estilo.TINTA_SUAVE)
		elseif familia == "vida" then espiral(cena, ponto, inicio, cena.cor)
		elseif familia == "portal" then
			arco(cena, chao(ponto), 4.5, inicio, 1.1, false, math.pi * 2, 0)
			arco(cena, ponto, 3, inicio + 0.1, 0.9, true, math.pi * 2, 1)
			espiral(cena, ponto, inicio + 0.15, Estilo.misturar(cena.cor, Estilo.TINTA, 0.6))
		elseif familia == "escudo" or familia == "guarda" then escudo(cena, ponto, inicio)
		elseif gelo then
			if familia == "corte" then arco(cena, ponto, 4, inicio, 0.3, true, math.pi * 1.5, 0.7) end
			cristal(cena, ponto, inicio); fragmentos(cena, ponto, inicio + 0.1, 0.4, cena.cor, true)
		elseif familia == "pedra" or familia == "peso" then pedra(cena, ponto, inicio)
		elseif familia == "vento" or familia == "corte" or familia == "astucia" then
			arco(cena, ponto, if familia == "corte" then 4 else 3, inicio, 0.36, true, math.pi * 1.4, 0.7)
			if familia == "vento" then arco(cena, ponto + Y * 0.8, 2.5, inicio + 0.08, 0.38, false, math.pi * 1.6, 2) end
		elseif familia == "flecha" then -- a própria flecha crava e solta as lascas (função flecha)
		elseif familia == "alquimia" then espiral(cena, ponto, inicio, cena.cor)
		elseif familia == "geometria" then
			for j = 1, 2 do arco(cena, ponto, 2.4 + j, inicio + j * 0.05, 0.55, j == 1, math.pi * 1.6, j) end
		else fragmentos(cena, ponto, inicio, 0.4, cena.cor, false); arco(cena, chao(ponto), 3, inicio, 0.55, false, math.pi * 2, 0) end
		evento(cena, inicio, function()
			cena.modelo:SetAttribute("Fase", "impacto")
			if semTextos then
			elseif alvo.critico then Efeitos.floatText(ponto + Y * 4, "CRÍTICO!", Estilo.ALERTA)
			elseif not acertou then Efeitos.floatText(ponto + Y * 4, "ERROU", Estilo.TINTA_SUAVE)
			elseif alvo.passou then Efeitos.floatText(ponto + Y * 4, "RESISTIU", Estilo.TINTA_SUAVE) end
			if acertou and (alvo.dano or 0) > 0 then
				Efeitos.reagir(alvo.id, ponto - de, cena.perfil.peso * (if alvo.critico then 2 else 1))
				Gestos.reacao(kit, cena, alvo.id, ponto - de, cena.perfil.peso * (if alvo.critico then 2 else 1))
				-- IMP1/IMP2: corte desenhado, faíscas no sentido do golpe, tremor direcional e pausa (hit-stop) que
				-- também segura o corpo das criaturas; câmera lenta no crítico e no golpe final da luta.
				local golpe = ponto - de
				local crit = alvo.critico == true or workspace:GetAttribute("QaCritico") == true -- QaCritico: só para a QA forçar o crítico
				local amp, dur = Curvas.tremor(alvo.dano, crit, cena.perfil.peso)
				Efeitos.tremer(amp, dur, golpe)
				Efeitos.aproximar(if crit then 0.14 else 0.08, if crit then 0.55 else 0.4)
				-- Corte de Braço: a arma do alvo voa da mão (só apresentação; o efeito real vem do servidor)
				-- REA1: a reação do corpo do alvo vem de ReacoesAlvo (habilidade x tipo do alvo x resultado do recibo)
				local tokenAlvo = state.findToken(alvo.id)
				local corpos = workspace:FindFirstChild("CorposDeCriatura")
				local corpoAlvo = corpos and corpos:FindFirstChild(alvo.id)
				local armado = #ImpactoFx.pecasDaArma(corpoAlvo) > 0
				local nomeAlvo = tokenAlvo and ((if type(tokenAlvo.criatura) == "string" then tokenAlvo.criatura else nil) or tokenAlvo.modelo or tokenAlvo.name) -- REA4: `criatura` costuma ser `true` no snapshot; o nome ("Lobo Cinzento") dá o tipo
				local reac = ReacoesAlvo.decidir(cena.habilidade, ReacoesAlvo.tipoDoAlvo(if type(nomeAlvo) == "string" then nomeAlvo else nil), armado, alvo)
				if reac.solta then
					-- a arma cai de verdade pelo servidor (CorposDeCriatura.soltarArma); o cliente só põe o respingo
					-- câmera: segura ~0,6 s na mão do alvo até a arma tocar o chão
					-- REA2: a câmera sai da dupla e segura ~0,7 s na peça `Arma` real (solta pelo servidor, filha do workspace) até o chão
					ImpactoCamera.foco(ponto + Y * 2.4, 0.7, function()
						local a = workspace:FindFirstChild("Arma")
						return if a and a:IsA("BasePart") then a.Position else nil
					end)
					ImpactoFx.gotas(cena.modelo, ponto + Y * 2.2, golpe)
				end
				-- REA4: corpo com reação Mixamo no servidor (atributo ReacaoMx) já recua pelo clipe; o tranco procedural é dos bichos
				if corpoAlvo and corpoAlvo:IsA("Model") and not corpoAlvo:FindFirstChildOfClass("Humanoid") and not corpoAlvo:GetAttribute("ReacaoMx") then
					ImpactoFx.tranco(corpoAlvo, golpe, reac.forca, reac.reacao == "membro-atingido")
				end
				if not cena.temRastro and not cena.semCorte then ImpactoFx.corte(cena.modelo, ponto, golpe, cena.cor, crit) end -- com arma, o rastro real da ponta é o corte
				ImpactoFx.faiscas(cena.modelo, ponto, cena.cor, alvo.dano, crit, golpe)
				if crit and Efeitos.tremorAtivo() then ImpactoFx.flash(0.2) end
				workspace:SetAttribute(if crit then "ImpactoCriticoEm" else "ImpactoAcertoEm", os.clock()) -- QA: prova do efeito
				if not cena.pausada and not FX.reduzidos and Efeitos.tremorAtivo() then
					cena.pausada = true
					local parada = Curvas.hitStop(alvo.dano, crit)
					local lentoDur, taxa = Curvas.lento(crit, golpeFinal(alvo.id), cena.assinatura)
					pausar(parada, lentoDur, taxa)
					local corpos = workspace:FindFirstChild("CorposDeCriatura")
					if corpos then
						ImpactoFx.congelar(if cena.casterId then corpos:FindFirstChild(cena.casterId) else nil, parada)
						ImpactoFx.congelar(corpos:FindFirstChild(alvo.id), parada)
					end
				end
			elseif not acertou then
				Gestos.reacao(kit, cena, alvo.id, ponto - de, 0.3, "esquiva")
				-- esquiva perceptível: criaturas de peças rígidas dão um passo lateral (tranco para o lado)
				local cAlvo = workspace:FindFirstChild("CorposDeCriatura")
				cAlvo = cAlvo and cAlvo:FindFirstChild(alvo.id)
				if cAlvo and cAlvo:IsA("Model") and not cAlvo:FindFirstChildOfClass("Humanoid") and not cAlvo:GetAttribute("ReacaoMx") then
					local tk = state.findToken(alvo.id)
					local nm = tk and ((if type(tk.criatura) == "string" then tk.criatura else nil) or tk.modelo or tk.name)
					ImpactoFx.tranco(cAlvo, ponto - de, 1.0, false, true, ReacoesAlvo.tipoDoAlvo(if type(nm) == "string" then nm else nil) == "humanoide")
				end
			elseif alvo.dano == 0 and not alvo.passou then
				Gestos.reacao(kit, cena, alvo.id, ponto - de, 0.3, "bloqueio") -- acertou sem dano: aparou
			end
		end)
	end

	-- Relógio da cena (segundos desde o início), com CenaTempoFixo e EscalaDeTempoDasCenas.
	-- IMP2: o relógio é integrado por janelas (ImpactoCurvas.avanco): `pausar` abre uma janela de hit-stop (taxa 0)
	-- seguida de câmera lenta (taxa < 1) em todas as cenas vivas; fora delas corre normal.
	local function tempoDe(cena)
		local fixo = workspace:GetAttribute("CenaTempoFixo")
		if type(fixo) == "number" then return fixo end
		local agora = os.clock()
		cena.t = (cena.t or 0) + Curvas.avanco(cena.ultimoReal or cena.inicio, agora,
			1 / math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1), cena.janelas or {})
		cena.ultimoReal = agora
		return cena.t
	end
	function pausar(dur, lentoDur, taxa)
		if dur <= 0 and (lentoDur or 0) <= 0 then return end
		local agora = os.clock()
		for _, c in cenas do
			if c.viva and not c.janelas then
				tempoDe(c)
				c.janelas = { { agora, agora + dur, 0 }, { agora + dur, agora + dur + (lentoDur or 0), taxa or 1 } }
			end
		end
	end
	-- Último inimigo caindo: o snapshot já traz o PV do alvo em 0 e nenhuma criatura de pé.
	function golpeFinal(alvoId)
		local snap = state.snapshot()
		if not snap or not snap.combat or not snap.combat.active then return false end
		local caiu = false
		for _, t in snap.tokens do
			if t.criatura then
				if t.id == alvoId then caiu = (t.pv or 1) <= 0 or t.derrotado == true
				elseif (t.pv or 0) > 0 and not t.derrotado then return false end
			end
		end
		return caiu
	end
	kit.agora = tempoDe
	kit.animar, kit.evento, kit.peca, kit.segmento, kit.arco = animar, evento, peca, segmento, arco
	kit.chao = chao
	kit.celula = function(c) return Protocol.cellCenter(c[1], c[2]) end

	local conexao = RunService.RenderStepped:Connect(function()
		for i = #cenas, 1, -1 do
			local cena = cenas[i]
			-- Só para inspeção: atributo CenaTempoFixo do Workspace congela as cenas num instante
			-- (quadro parado); EscalaDeTempoDasCenas > 1 deixa tudo em câmera lenta.
			local tempo = tempoDe(cena)
			if not cena.modelo.Parent or tempo > cena.fim then
				destruir(cena); table.remove(cenas, i)
			else
				for j = #cena.jobs, 1, -1 do
					local job = cena.jobs[j]
					if tempo >= job.inicio then
						local t = math.clamp((tempo - job.inicio) / job.duracao, 0, 1)
						local ok, erro = pcall(job.atualizar, t, job)
						if not ok then warn("[Coreografia]", erro); destruir(cena); break end
						if t >= 1 then table.remove(cena.jobs, j) end
					end
				end
			end
		end
	end)
	local api = {}
	function api.tocar(recibo)
		if encerrado or type(recibo.habilidadeId) ~= "string" then return false end
		local id, arv = recibo.habilidadeId, arvore(recibo.habilidadeId)
		local perfil = PERFIS[arv]
		if not perfil then return false end
		if perfil.nova and FX.reduzidos then return false end
		local mec = Execucao.MECANICAS[id] or {}
		-- Golpes de todo mundo (ataque básico, criaturas): dourado claro, legível no escuro.
		local cor = if arv == "basico" then Color3.fromRGB(255, 232, 170) else Estilo.arvore(arv).cor
		local cena = nova(id, perfil, cor)
		cena.casterId = recibo.casterId
		cena.habilidade = id
		cena.bracoCortado = string.find(id, "corte-de-braco", 1, true) ~= nil
		cena.emboscada = string.find(id, "primeiro-golpe", 1, true) ~= nil
		local gelo = string.find(id, "gelo", 1, true) ~= nil
		local de = if recibo.casterId then posicaoDe(state, recibo.casterId, recibo.origem) else nil
		local familia = perfil.familia
		if string.sub(id, 1, 9) == "invocado/" then familia = if id == "invocado/ajudar" then "vida" else "corte" end
		if string.sub(id, 1, 20) == "mesa/lamina-de-gelo-" then familia = "corte" end
		-- Gesto do corpo (A5): define quando o golpe chega e o que o corpo faz.
		local plano = nil
		local spec = Gestos.especificar(id, mec, arv)
		if spec and spec.g == "disparo" then familia = "flecha" end -- arco de qualquer árvore: flecha de verdade
		if spec and de then
			local ok, resultado = pcall(Gestos.tocar, kit, cena, recibo, spec, de, mec)
			if ok then plano = resultado else warn("[Gestos]", id, resultado) end
		end
		plano = plano or {}
		-- IMP1: rastro da arma no fantasma do atacante, ligado do começo do golpe até logo depois do contato
		if de and not FX.reduzidos then
			for _, filho in cena.modelo:GetChildren() do
				if filho:IsA("Model") then
					local liga = ImpactoFx.rastro(filho, cena.cor, cena.modelo)
					if liga then cena.temRastro = true end
					if liga then
						local contato = plano.chegada or perfil.carga
						evento(cena, math.max(0, contato - 0.5), function() liga(true) end)
						evento(cena, contato + 0.15, function() liga(false) end)
					end
				end
			end
		end
		if cena.emboscada and de and not FX.reduzidos then
			-- Primeiro Golpe: sombra e fumaça escura em volta do ladino durante a antecipação longa
			evento(cena, 0, function() ImpactoFx.fumaca(cena.modelo, de, 0.9) end)
		end
		local chave = Sons.lancamento(id, arv, spec)
		if chave then
			evento(cena, plano.carga or perfil.carga, function()
				local parar = Sonorizacao.tocar(chave)
				if parar then table.insert(cena.limpezas, parar) end
			end)
		end
		if de and recibo.casterId and not plano.semCirculo then
			arco(cena, chao(de), 2.5, 0, perfil.carga + 0.2, false, math.pi * 1.7, 0)
		end
		if de and recibo.casterId then
			evento(cena, perfil.carga, function() cena.modelo:SetAttribute("Fase", "lancamento") end)
		end
		if recibo.trajeto and #recibo.trajeto == 2 and not plano.chegada then
			local a, b = recibo.trajeto[1], recibo.trajeto[2]
			local inicio, fim = celula(a[1], a[2]), celula(b[1], b[2])
			for i = 1, 5 do arco(cena, inicio:Lerp(fim, i / 5) + Y * 0.3, 1.6, i * 0.045, 0.35, false, math.pi, i) end
		end
		if mec.tipo == "zona" or mec.zonaApos then
			local casas = recibo.casas or {}
			for i = 1, math.min(#casas, 6) do
				local casa = casas[math.max(1, math.floor(i * #casas / math.min(#casas, 6)))]
				arco(cena, celula(casa[1], casa[2]) + Y * 0.25, 2.2, perfil.carga + i * 0.04, 0.7, false, math.pi * 2, i)
			end
		end
		for i, alvo in recibo.alvos or {} do
			if i > 6 then break end -- Os demais alvos continuam integralmente resolvidos pelo servidor.
			local p = posicaoDe(state, alvo.id, alvo.casa)
			local origem = de or p
			local offset = (plano.carga or perfil.carga) + (i - 1) * 0.075
			local tiros = alvo.disparos or { alvo }
			for n, tiro in tiros do
				local errou = tiro.acertou == false
				local destino = if errou then p + Vector3.new(2.8, 0.5, 1.3) else p
				local lancamento = offset + (n - 1) * 0.18
				local viaja = de ~= nil and recibo.casterId ~= alvo.id and not mec.corpoACorpo and mec.tipo ~= "invocacao" and mec.tipo ~= "cura" and not mec.puxar and not plano.semViagem
				local viagem = perfil.viagem
				if viaja then
					local ponto = destino
					if familia == "flecha" then
						if errou then
							-- passa ao lado e crava no chão um pouco além do alvo
							local d = direcao(Vector3.new(origem.X, 0, origem.Z), Vector3.new(p.X, 0, p.Z))
							ponto = chao(p + d * 3.2 + d:Cross(Y) * 1.4) - Y * 0.1
						else
							ponto = meioDoCorpo(alvo.id, origem) or p
						end
					elseif not errou then
						ponto = meioDoCorpo(alvo.id, origem) or p
					end
					viagem = duracaoDoVoo(familia, (ponto - origem).Magnitude)
					flecha(cena, origem, ponto, lancamento, viagem, familia, not errou, plano.origem)
				end
				local quando = if plano.chegada then plano.chegada + (i - 1) * 0.04 else lancamento + (if viaja then viagem else 0)
				local resultado = if #tiros > 1 then tiro else alvo
				-- IMP2: criatura atacando: o contato cai no marco `impacto` do clipe dela (o servidor começa o clipe com o recibo)
				quando = math.max(quando, impactoDaCriatura(state, recibo.casterId) or 0)
				if de and i == 1 and n == 1 and not plano.semCamera then
					-- IMP1: a câmera de luta acompanha este golpe (antecipação, contato, volta)
					ImpactoCamera.golpe(de + Y * 2, destino + Y * 2, quando,
						if spec and spec.assinatura then { escala = if cena.bracoCortado then 0.9 else 0.85, altura = if cena.bracoCortado then 1.4 else nil, orbita = if cena.bracoCortado then math.rad(12) else nil, dolly = 0.1 } else nil)
					cena.assinatura = spec and spec.assinatura == true
					cena.fim = math.max(cena.fim, quando + 0.9)
				end
				-- ANIM3: número, barra e queda do alvo esperam o golpe encostar (limite de segurança na fila)
				if resultado.acertou ~= false and not FX.reduzidos then
					local atraso = quando
					atraso = math.max(atraso, impactoDaCriatura(state, recibo.casterId) or 0)
					Feedback.fila:reter(alvo.id, os.clock(), atraso)
				end
				local somImpacto = Sons.impacto(id, arv, spec, resultado)
				if somImpacto then
					evento(cena, quando, function()
						local parar = Sonorizacao.tocar(somImpacto, 1.5)
						if parar then table.insert(cena.limpezas, parar) end
					end)
				end
				impacto(cena, destino, origem, quando, resultado, familia, gelo, plano.impactoProprio, plano.semTextos)
				if plano.impactoExtra and resultado.acertou ~= false then plano.impactoExtra(destino, quando) end
			end
		end
		cena.fim = math.max(cena.fim, 0.5)
		return true
	end
	-- Só o corpo conjurando (as magias de Fogo desenham o resto em Magias).
	function api.gesto(recibo)
		if encerrado or type(recibo.habilidadeId) ~= "string" or not recibo.casterId then return false end
		local id, arv = recibo.habilidadeId, arvore(recibo.habilidadeId)
		local perfil = PERFIS[arv]
		local spec = perfil and Gestos.especificar(id, Execucao.MECANICAS[id] or {}, arv)
		if not spec or (spec.g ~= "conjuro" and spec.g ~= "disparo") then return false end -- HAB2: flecha de água também arma o arco
		local de = posicaoDe(state, recibo.casterId, recibo.origem)
		local cena = nova(id, perfil, Estilo.arvore(arv).cor)
		local ok, erro = pcall(Gestos.tocar, kit, cena, recibo, spec, de, Execucao.MECANICAS[id] or {})
		if not ok then warn("[Gestos]", id, erro) end
		cena.fim = math.max(cena.fim, perfil.carga + (if spec.g == "disparo" then 1.3 else 0.5))
		return ok
	end
	-- HAB2: o alvo de uma magia reage como num golpe (ReacaoGolpe/Esquiva/Bloqueio no corpo), além do recuo.
	-- tipo: nil/"golpe" | "esquiva" | "bloqueio".
	function api.reacao(alvoId, direcao: Vector3, forca: number?, tipo: string?)
		if encerrado or type(alvoId) ~= "string" then return false end
		local cena = nova("reacao", PERFIS.basico, Estilo.TINTA)
		local ok, erro = pcall(Gestos.reacao, kit, cena, alvoId, direcao, forca or 1, tipo)
		if not ok then warn("[Gestos] reacao", erro) end
		cena.fim = math.max(cena.fim, 1.2)
		return ok
	end
	function api.limpar() limpar() end
	function api.estado() return { cenas = #cenas, pecas = pecas, maxCenas = MAX_CENAS, maxPecas = MAX_PECAS } end
	function api.destruir() encerrado = true; limpar(); conexao:Disconnect() end
	return api
end

return Coreografia
