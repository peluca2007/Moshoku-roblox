-- HUD2: peças visuais da luta (versão escura do tema Pergaminho: tinta clara sobre o mundo, detalhes
-- dourados finos, sem caixas pesadas). Usadas por Hud, AcoesDoTurno, BarrasLuta e AnuncioLuta.
-- Só apresentação: nada aqui decide regra. Animação com TweenService (0,15–0,3 s; Back/Quad).
--   P.novo(classe, pai, props)            cria Instance (props antes do Parent).
--   P.animar(obj, props, info?, tag?)     tween que cancela o anterior do mesmo objeto/tag.
--   P.placa(pai, nome, tamanho, opcoes?)  Frame escuro translúcido com contorno dourado fino.
--   P.pip(pai, lado)                      losango (Frame girado 45°); P.pipAceso(pip, aceso).
--   P.foco(botao, contorno?, escala?)     hover com leve escala e brilho; devolve setFoco(bool).
--   P.arte(pai, peca, z?)                 ImageLabel pintado (9-slice, SliceScale conforme o tamanho); P.trocarArte(img, peca).
--   P.icone(pai, nome, cor, lado)         ícone branco do atlas (game-icons.net) tingido por ImageColor3.
--   P.tecla(pai, letra, lado)             disco de tinta com a letra da tecla; P.losango(pai, texto, lado) para custos.
--   P.barra({parent, nome, tamanho, ...}) barra de vida/PM com "rastro" de dano; devolve tabela com
--     raiz e definir(atual, maximo, imediato?).
local TweenService = game:GetService("TweenService")
local T = require(script.Parent.Tema)
local Arte = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UIArteLuta"))

local P = {}

P.cor = {
	fundo = T.cores.fundoTela,
	ouro = T.sobreEscuro.ouro,
	ouroVivo = T.sobreEscuro.titulo,
	texto = T.sobreEscuro.texto,
	secundario = T.sobreEscuro.secundario,
	trilho = Color3.fromRGB(14, 11, 9),
	inimigo = T.barras.baixa,
	aliado = T.sobreEscuro.ouro,
	pm = T.barras.mana,
}
P.ENTRADA = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
P.SUAVE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
P.SAIDA = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function P.novo(classe: string, pai: Instance?, props: { [string]: any }): any
	local o = Instance.new(classe)
	for k, v in props do
		o[k] = v
	end
	o.Parent = pai
	return o
end

local ativos: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" })

function P.animar(obj: Instance, props: { [string]: any }, info: TweenInfo?, tag: string?): Tween
	local mapa = ativos[obj]
	if not mapa then
		mapa = {}
		ativos[obj] = mapa
	end
	local chave = tag or "geral"
	if mapa[chave] then mapa[chave]:Cancel() end
	local tween = TweenService:Create(obj, info or P.SUAVE, props)
	mapa[chave] = tween
	tween:Play()
	return tween
end

function P.placa(pai: Instance, nome: string, tamanho: UDim2, opcoes: { [string]: any }?): any
	local o = opcoes or {}
	local classe = o.classe or "Frame"
	local f = P.novo(classe, pai, {
		Name = nome, Size = tamanho, BackgroundColor3 = P.cor.fundo, BackgroundTransparency = o.transparencia or 0.2, BorderSizePixel = 0,
	})
	P.novo("UICorner", f, { CornerRadius = UDim.new(0, o.raio or 8) })
	P.novo("UIStroke", f, { Name = "Contorno", Color = o.cor or P.cor.ouro, Thickness = o.espessura or 1, Transparency = o.transparenciaContorno or 0.35 })
	return f
end

-- Arte pintada (ARTE2). A peça vira o fundo do botão/placa: o pai fica com fundo transparente.
function P.ajustarArte(img: ImageLabel)
	local nome = img:GetAttribute("Peca")
	local peca = nome and Arte.PECAS[nome]
	if peca and peca.corte then
		local tam = img.AbsoluteSize
		img.SliceScale = Arte.escalaPara(nome, tam.X, tam.Y)
	end
end

function P.trocarArte(img: ImageLabel, nome: string)
	local peca = Arte.PECAS[nome]
	img:SetAttribute("Peca", nome)
	img.Image = peca.imagem
	if peca.corte then
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = Rect.new(peca.corte[1], peca.corte[2], peca.corte[3], peca.corte[4])
		P.ajustarArte(img)
	else
		img.ScaleType = Enum.ScaleType.Stretch
	end
end

function P.arte(pai: Instance, nome: string, z: number?): ImageLabel
	local img = P.novo("ImageLabel", pai, { Name = "Arte", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z or 2, Active = false })
	P.trocarArte(img, nome)
	img:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() P.ajustarArte(img) end)
	return img
end

function P.icone(pai: Instance, nome: string, cor: Color3, lado: number): ImageLabel
	local pos = Arte.ICONES[nome] or Arte.ICONES.golpe
	return P.novo("ImageLabel", pai, {
		Name = "Icone", BackgroundTransparency = 1, Size = UDim2.fromOffset(lado, lado), Image = Arte.ATLAS.imagem,
		ImageRectOffset = Vector2.new(pos[1], pos[2]), ImageRectSize = Vector2.new(Arte.ATLAS.tamanho, Arte.ATLAS.tamanho),
		ImageColor3 = cor, ZIndex = 5,
	})
end

local function letraSobre(pai: Instance, texto: string, tamanho: number, cor: Color3)
	return P.novo("TextLabel", pai, {
		Name = "Letra", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = texto, ZIndex = 9,
		FontFace = T.fontes.numero, TextSize = tamanho, TextColor3 = cor, TextXAlignment = Enum.TextXAlignment.Center,
	})
end

function P.tecla(pai: Instance, letra: string, lado: number): ImageLabel
	local img = P.novo("ImageLabel", pai, { Name = "Tecla", BackgroundTransparency = 1, Size = UDim2.fromOffset(lado, lado), Image = Arte.PECAS.tecla_disco.imagem, ZIndex = 8 })
	letraSobre(img, letra, math.floor(lado * 0.6), P.cor.ouroVivo)
	return img
end

function P.losango(pai: Instance, texto: string, lado: number): ImageLabel
	local img = P.novo("ImageLabel", pai, { Name = "Losango", BackgroundTransparency = 1, Size = UDim2.fromOffset(lado, lado), Image = Arte.PECAS.tecla_losango.imagem, ZIndex = 8 })
	letraSobre(img, texto, math.floor(lado * 0.52), P.cor.ouroVivo)
	return img
end

function P.pip(pai: Instance, lado: number): Frame
	local f = P.novo("Frame", pai, {
		Name = "Pip", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(lado, lado), Rotation = 45,
		BackgroundColor3 = P.cor.ouroVivo, BorderSizePixel = 0,
	})
	P.novo("UIStroke", f, { Name = "Contorno", Color = P.cor.ouro, Thickness = 1 })
	return f
end

function P.pipAceso(pip: Frame, aceso: boolean)
	P.animar(pip, { BackgroundColor3 = if aceso then P.cor.ouroVivo else P.cor.trilho, BackgroundTransparency = if aceso then 0 else 0.35 }, P.SUAVE, "pip")
end

-- Hover/foco: leve escala (UIScale "Foco") e contorno mais vivo. Devolve setFoco(bool) para o foco por teclado.
function P.foco(botao: GuiObject, contorno: UIStroke?, escala: number?, arte: { img: ImageLabel, normal: string, foco: string }?)
	local alvo = escala or 1.05
	local ui = botao:FindFirstChild("Foco") or P.novo("UIScale", botao, { Name = "Foco", Scale = 1 })
	local dentro, forcado = false, false
	local function aplicar()
		local aceso = dentro or forcado
		P.animar(ui, { Scale = if aceso then alvo else 1 }, P.SUAVE, "foco")
		if arte and not botao:GetAttribute("Desabilitado") then
			P.trocarArte(arte.img, if aceso then arte.foco else arte.normal)
		end
		if contorno then
			P.animar(contorno, { Transparency = if aceso then 0 else 0.15, Color = if aceso then P.cor.ouroVivo else P.cor.ouro }, P.SUAVE, "foco")
		end
	end
	botao.MouseEnter:Connect(function() dentro = true; aplicar() end)
	botao.MouseLeave:Connect(function() dentro = false; aplicar() end)
	return function(v: boolean) forcado = v; aplicar() end
end

local function corAuto(r: number): Color3
	return if r > 0.5 then T.barras.cheia elseif r > 0.25 then T.barras.media else T.barras.baixa
end

-- Barra com rastro: ao perder vida, "Cheio" desce rápido e "Rastro" (parte perdida, mais clara) some com atraso.
-- opcoes: parent, nome, tamanho, posicao?, ancora?, cor? (fixa; sem ela muda com a fração), numero? (texto
-- "a / m" por cima), tamanhoTexto?, sufixo?.
function P.barra(o: { [string]: any })
	local raiz = P.novo("Frame", o.parent, {
		Name = o.nome, Size = o.tamanho, Position = o.posicao or UDim2.new(), AnchorPoint = o.ancora or Vector2.zero,
		BackgroundColor3 = P.cor.trilho, BackgroundTransparency = 0.1, BorderSizePixel = 0,
	})
	P.novo("UICorner", raiz, { CornerRadius = UDim.new(0, 3) })
	P.novo("UIStroke", raiz, { Name = "Contorno", Color = P.cor.ouro, Thickness = 1, Transparency = 0.4 })
	local rastro = P.novo("Frame", raiz, { Name = "Rastro", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(245, 226, 184), BackgroundTransparency = 0.2, BorderSizePixel = 0 })
	P.novo("UICorner", rastro, { CornerRadius = UDim.new(0, 3) })
	local cheio = P.novo("Frame", raiz, { Name = "Cheio", Size = UDim2.fromScale(1, 1), BackgroundColor3 = o.cor or T.barras.cheia, BorderSizePixel = 0, ZIndex = 2 })
	P.novo("UICorner", cheio, { CornerRadius = UDim.new(0, 3) })
	local numero = nil
	if o.numero then
		numero = P.novo("TextLabel", raiz, {
			Name = "Numero", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4,
			FontFace = T.fontes.numero, TextSize = o.tamanhoTexto or 15, TextColor3 = P.cor.texto,
			TextStrokeColor3 = P.cor.trilho, TextStrokeTransparency = 0.25, TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	local estado = { r = nil :: number?, serial = 0 }
	local api = { raiz = raiz, cheio = cheio, rastro = rastro, numero = numero }
	function api.definir(atual: number?, maximo: number?, imediato: boolean?)
		if atual == nil or maximo == nil or maximo <= 0 then
			raiz.Visible = false
			return
		end
		raiz.Visible = true
		local r = math.clamp(atual / maximo, 0, 1)
		local cor = o.cor or corAuto(r)
		if numero then numero.Text = string.format("%d / %d", atual, maximo) end
		local anterior = estado.r
		estado.r = r
		estado.serial += 1
		local meu = estado.serial
		local alvo = UDim2.fromScale(r, 1)
		if anterior == nil or imediato then
			cheio.Size, rastro.Size, cheio.BackgroundColor3 = alvo, alvo, cor
			return
		end
		if r == anterior then
			cheio.BackgroundColor3 = cor
			return
		end
		P.animar(cheio, { Size = alvo, BackgroundColor3 = cor }, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), "cheio")
		if r < anterior then
			-- a parte perdida fica clara e some depois de um instante
			task.delay(0.5, function()
				if estado.serial == meu and rastro.Parent then
					P.animar(rastro, { Size = alvo }, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), "rastro")
				end
			end)
		else
			P.animar(rastro, { Size = alvo }, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), "rastro")
		end
	end
	return api
end

return P
