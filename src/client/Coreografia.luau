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

function Coreografia.start(state, pasta, posicaoDe, chaoDe, centroCasa)
	local chao = chaoDe or chao
	local celula = centroCasa or Protocol.cellCenter
	local cenas, pecas, serial = {}, 0, 0
	local kit = { state = state, posicaoDe = posicaoDe, Efeitos = Efeitos }
	local encerrado = false
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
	local function flecha(cena, de, para, inicio, duracao, familia)
		local p = peca(cena, if familia == "corrente" then "gota" else "fio", nil, if familia == "pedra" then Enum.Material.Slate else nil)
		if not p then return end
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Position, b.Position = Vector3.new(0, 0.2, 0), Vector3.new(0, -0.2, 0)
		a.Parent, b.Parent = p, p
		local rastro = Instance.new("Trail")
		rastro.Attachment0, rastro.Attachment1, rastro.FaceCamera = a, b, true
		rastro.Color = ColorSequence.new(cena.cor, Estilo.TINTA)
		rastro.Transparency = NumberSequence.new(0.15, 1)
		rastro.Lifetime, rastro.LightEmission, rastro.Enabled = 0.18, 0.8, false
		rastro.Parent = p
		animar(cena, inicio, duracao, function(t)
			local ponto = de:Lerp(para, t) + Y * math.sin(math.pi * t) * (if familia == "corrente" then 2.2 else 0.35)
			p.CFrame = CFrame.lookAt(ponto, ponto + direcao(de, para))
			p.Size = if familia == "pedra" then Vector3.new(1.1, 1.1, 2) elseif familia == "corrente" then Vector3.new(0.8, 0.8, 1.8) else Vector3.new(0.16, 0.16, 3)
			p.Transparency = if t >= 1 then 1 else 0.05
			rastro.Enabled = t < 1
		end)
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
				Efeitos.tremer(math.min(0.45, cena.perfil.peso * (if alvo.critico then 0.5 else 0.2)), 0.2)
			end
		end)
	end

	kit.animar, kit.evento, kit.peca, kit.segmento, kit.arco = animar, evento, peca, segmento, arco
	kit.chao = chao
	kit.celula = function(c) return Protocol.cellCenter(c[1], c[2]) end

	local conexao = RunService.RenderStepped:Connect(function()
		for i = #cenas, 1, -1 do
			local cena = cenas[i]
			-- Só para inspeção: atributo CenaTempoFixo do Workspace congela as cenas num instante
			-- (quadro parado); EscalaDeTempoDasCenas > 1 deixa tudo em câmera lenta.
			local fixo = workspace:GetAttribute("CenaTempoFixo")
			local tempo = if type(fixo) == "number" then fixo
				else (os.clock() - cena.inicio) / math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1)
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
		local gelo = string.find(id, "gelo", 1, true) ~= nil
		local de = if recibo.casterId then posicaoDe(state, recibo.casterId, recibo.origem) else nil
		local familia = perfil.familia
		if string.sub(id, 1, 9) == "invocado/" then familia = if id == "invocado/ajudar" then "vida" else "corte" end
		if string.sub(id, 1, 20) == "mesa/lamina-de-gelo-" then familia = "corte" end
		-- Gesto do corpo (A5): define quando o golpe chega e o que o corpo faz.
		local plano = nil
		local spec = Gestos.especificar(id, mec, arv)
		if spec and de then
			local ok, resultado = pcall(Gestos.tocar, kit, cena, recibo, spec, de, mec)
			if ok then plano = resultado else warn("[Gestos]", id, resultado) end
		end
		plano = plano or {}
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
				local destino = if tiro.acertou == false then p + Vector3.new(2.8, 0.5, 1.3) else p
				local lancamento = offset + (n - 1) * 0.18
				local viaja = de ~= nil and recibo.casterId ~= alvo.id and not mec.corpoACorpo and mec.tipo ~= "invocacao" and mec.tipo ~= "cura" and not mec.puxar and not plano.semViagem
				if viaja then flecha(cena, origem, destino, lancamento, perfil.viagem, familia) end
				local quando = if plano.chegada then plano.chegada + (i - 1) * 0.04 else lancamento + (if viaja then perfil.viagem else 0)
				local resultado = if #tiros > 1 then tiro else alvo
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
		if not spec or spec.g ~= "conjuro" then return false end
		local de = posicaoDe(state, recibo.casterId, recibo.origem)
		local cena = nova(id, perfil, Estilo.arvore(arv).cor)
		local ok, erro = pcall(Gestos.tocar, kit, cena, recibo, spec, de, Execucao.MECANICAS[id] or {})
		if not ok then warn("[Gestos]", id, erro) end
		cena.fim = math.max(cena.fim, perfil.carga + 0.5)
		return ok
	end
	function api.limpar() limpar() end
	function api.estado() return { cenas = #cenas, pecas = pecas, maxCenas = MAX_CENAS, maxPecas = MAX_PECAS } end
	function api.destruir() encerrado = true; limpar(); conexao:Disconnect() end
	return api
end

return Coreografia
