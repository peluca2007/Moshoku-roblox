-- Anúncio da habilidade (HUD2): o NOME da habilidade grande e centralizado no alto, com quem a usa em
-- letras pequenas acima e fios dourados dos lados; entra deslizando e crescendo (Back), some com fade.
-- Logo abaixo, o resultado ("5 de dano", "errou", "Crítico!") com um "pop". Texto sobre o mundo, sem
-- caixa (geometria em shared/Regras/LayoutLuta). Só lê recibos de efeito já filtrados pelo servidor.
-- Instances: ScreenGui "AnuncioLuta" > Anuncio (Quem, Habilidade, FioEsq, FioDir) | Resultado.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)
local Layout = require(Shared.Regras.LayoutLuta)
local T = require(script.Parent.UI.Tema)
local P = require(script.Parent.UI.PecasLuta)

local Anuncio = {}

-- Texto do resultado a partir do recibo (puro).
function Anuncio.resultado(alvos: { any }?): string
	local dano, cura, errou, resistiu, critico = 0, 0, false, false, false
	for _, a in alvos or {} do
		dano += a.dano or 0
		cura += a.cura or 0
		errou = errou or a.acertou == false
		resistiu = resistiu or a.passou == true
		critico = critico or a.critico == true
	end
	local texto = if dano > 0 then dano .. " de dano" elseif cura > 0 then "+" .. cura .. " PV" elseif errou then "errou" elseif resistiu then "resistiu" else ""
	if critico and texto ~= "" then texto = "Crítico! " .. texto end
	return texto
end

-- Tom do resultado (cor): "dano", "cura", "erro" ou "neutro".
function Anuncio.tom(alvos: { any }?): string
	local dano, cura, errou = 0, 0, false
	for _, a in alvos or {} do
		dano += a.dano or 0
		cura += a.cura or 0
		errou = errou or a.acertou == false or a.passou == true
	end
	return if dano > 0 then "dano" elseif cura > 0 then "cura" elseif errou then "erro" else "neutro"
end

local CORES = { dano = Color3.fromRGB(255, 214, 160), cura = T.barras.cheia, erro = T.sobreEscuro.secundario, neutro = T.sobreEscuro.texto }

function Anuncio.start(state)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "AnuncioLuta", false, 8, true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function rotulo(pai, nome: string, fonte: Font, tamanho: number, cor: Color3, props)
		local l = P.novo("TextLabel", pai, {
			Name = nome, BackgroundTransparency = 1, Text = "", FontFace = fonte, TextSize = tamanho, TextColor3 = cor,
			TextStrokeColor3 = P.cor.trilho, TextStrokeTransparency = 0.2, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		for k, v in props or {} do l[k] = v end
		return l
	end
	local anuncio = P.novo("Frame", gui, { Name = "Anuncio", BackgroundTransparency = 1, Visible = false, AnchorPoint = Vector2.new(0.5, 0) })
	local quem = rotulo(anuncio, "Quem", T.fontes.rotulo, 15, P.cor.ouro, { Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
	local habilidade = rotulo(anuncio, "Habilidade", T.fontes.titulo, 38, P.cor.ouroVivo, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center })
	local escalaAnuncio = P.novo("UIScale", anuncio, { Scale = 1 })
	local function fio(nome: string, lado: number)
		return P.novo("Frame", anuncio, {
			Name = nome, AnchorPoint = Vector2.new(lado, 0.5), Position = UDim2.new(lado, 0, 0, 42), Size = UDim2.fromOffset(0, 2),
			BackgroundColor3 = P.cor.ouro, BorderSizePixel = 0, BackgroundTransparency = 0.2,
		})
	end
	local fioEsq, fioDir = fio("FioEsq", 0), fio("FioDir", 1)
	local resultado = rotulo(gui, "Resultado", T.fontes.titulo, 24, T.sobreEscuro.texto, { Visible = false, AnchorPoint = Vector2.new(0.5, 0), TextXAlignment = Enum.TextXAlignment.Center })
	local escalaResultado = P.novo("UIScale", resultado, { Scale = 1 })
	local function posicionar()
		local topo = Layout.topo(workspace.CurrentCamera.ViewportSize.X)
		anuncio.Position, anuncio.Size = UDim2.fromOffset(topo.anuncio.x + topo.anuncio.w / 2, topo.anuncio.y), UDim2.fromOffset(topo.anuncio.w, topo.anuncio.h)
		resultado.Position, resultado.Size = UDim2.fromOffset(topo.resultado.x + topo.resultado.w / 2, topo.resultado.y), UDim2.fromOffset(topo.resultado.w, topo.resultado.h)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionar)
	posicionar()

	local serial = 0
	local function ocultar(animado: boolean)
		serial += 1
		local meu = serial
		if not animado then
			anuncio.Visible, resultado.Visible = false, false
			return
		end
		local saida = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, l in { habilidade, quem, resultado } do
			P.animar(l, { TextTransparency = 1, TextStrokeTransparency = 1 }, saida, "texto")
		end
		P.animar(fioEsq, { BackgroundTransparency = 1 }, saida, "fio")
		P.animar(fioDir, { BackgroundTransparency = 1 }, saida, "fio")
		task.delay(0.22, function()
			if gui.Parent and serial == meu then anuncio.Visible, resultado.Visible = false, false end
		end)
	end
	local function mostrar(nomeQuem: string, nomeHabilidade: string, detalhe: string, tom: string, duracao: number)
		serial += 1
		local meu = serial
		quem.Text, habilidade.Text, resultado.Text = string.upper(nomeQuem), nomeHabilidade, detalhe
		resultado.TextColor3 = CORES[tom] or CORES.neutro
		posicionar()
		anuncio.Visible, resultado.Visible = true, detalhe ~= ""
		-- entrada: o nome cresce com Back e desce 14 px; os fios abrem do centro para fora
		for _, l in { quem, habilidade, resultado } do
			l.TextTransparency, l.TextStrokeTransparency = 1, 1
		end
		escalaAnuncio.Scale = 0.8
		local topo = Layout.topo(workspace.CurrentCamera.ViewportSize.X)
		anuncio.Position = UDim2.fromOffset(topo.anuncio.x + topo.anuncio.w / 2, topo.anuncio.y - 14)
		local entrada = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		P.animar(escalaAnuncio, { Scale = 1 }, entrada, "escala")
		P.animar(anuncio, { Position = UDim2.fromOffset(topo.anuncio.x + topo.anuncio.w / 2, topo.anuncio.y) }, entrada, "pos")
		P.animar(habilidade, { TextTransparency = 0, TextStrokeTransparency = 0.2 }, P.SUAVE, "texto")
		P.animar(quem, { TextTransparency = 0, TextStrokeTransparency = 0.2 }, P.SUAVE, "texto")
		fioEsq.Size, fioDir.Size = UDim2.fromOffset(0, 2), UDim2.fromOffset(0, 2)
		fioEsq.BackgroundTransparency, fioDir.BackgroundTransparency = 0.2, 0.2
		local largura = math.clamp(topo.anuncio.w * 0.5 - #nomeHabilidade * 11 - 8, 0, 160)
		P.animar(fioEsq, { Size = UDim2.fromOffset(largura, 2) }, entrada, "fio")
		P.animar(fioDir, { Size = UDim2.fromOffset(largura, 2) }, entrada, "fio")
		if detalhe ~= "" then
			escalaResultado.Scale = 1.35
			P.animar(escalaResultado, { Scale = 1 }, entrada, "escala")
			P.animar(resultado, { TextTransparency = 0, TextStrokeTransparency = 0.15 }, P.SUAVE, "texto")
		end
		task.delay(duracao, function()
			if gui.Parent and serial == meu then ocultar(true) end
		end)
	end
	state.onSnapshot(function(s)
		if not s.combat.active and (anuncio.Visible or resultado.Visible) then ocultar(false) end
	end)
	state.onEncontro(function() ocultar(false) end)
	state.onEfeito(function(r)
		local s = state.snapshot()
		if not s or not s.combat.active then return end
		local quemUsa = state.findToken(r.casterId)
		local entrada, mec = Catalogo.POR_ID[r.habilidadeId], Execucao.MECANICAS[r.habilidadeId]
		local nome = (entrada and entrada.data.name) or (mec and mec.nome) or "Ação"
		local detalhe = Anuncio.resultado(r.alvos)
		if detalhe == "" and type(r.resultado) == "string" then detalhe = r.resultado end
		mostrar(quemUsa and quemUsa.name or "Alguém", nome, detalhe, Anuncio.tom(r.alvos), 2.8)
	end)
	return gui
end

return Anuncio
