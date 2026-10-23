-- Apresentação J2: decora botões existentes sem substituir seus comandos.
local T = require(script.Parent.Tema)
local C = require(script.Parent.Componentes)
local E = { tema = T, componentes = C }
function E.botao(b, principal, perigo)
	b.TextWrapped, b.TextTruncate = true, Enum.TextTruncate.None
	b.FontFace, b.TextSize = T.fontes.rotulo, 17 -- cartas usam labels separados; botoes simples mantem este rotulo
	b.BackgroundColor3 = if principal then T.cores.ouro else T.cores.painel
	b.TextColor3 = if principal then T.cores.textoEscuro else T.cores.texto
	b.TextTransparency = if b.Active then 0 else T.transparencias.desabilitado
	local canto = b:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	canto.CornerRadius, canto.Parent = UDim.new(0, T.raios.botao), b
	local borda = b:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	borda.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- sem isto o contorno dourado era aplicado ao TEXTO (letras grossas/duplicadas)
	borda.Color, borda.Thickness, borda.Parent = if perigo then T.cores.vinho else T.cores.borda, T.espessuras.borda, b
	local limite = b:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	limite.MinSize, limite.Parent = Vector2.new(T.toqueMinimo, T.toqueMinimo), b
	if not b:GetAttribute("DecoradoCombate") then
		b:SetAttribute("DecoradoCombate", true)
		b:GetPropertyChangedSignal("Active"):Connect(function()
			b.TextTransparency = if b:GetAttribute("CartaAcao") and not b:GetAttribute("CartaCompacta") then 1
				elseif b.Active then 0 else T.transparencias.desabilitado
			b.BackgroundTransparency = if b.Active then 0 else T.transparencias.desabilitado
		end)
	end
end
function E.acoes(lista, largura)
	local indice = 0
	local colunas = math.max(1, math.floor(largura / 240))
	local larguraBotao = math.floor((largura - (colunas - 1) * 8) / colunas)
	local botoes, notas, perigos = {}, {}, {}
	for _, b in lista:GetChildren() do
		if b:IsA("TextButton") then
			if b.Name == "Fugir" then table.insert(perigos, b) else table.insert(botoes, b) end
		elseif b:IsA("TextLabel") then table.insert(notas, b) end
	end
	for _, b in perigos do table.insert(botoes, b) end
	for _, b in botoes do
		local principal = b.Name:match("^Atacar_") ~= nil or (b.Name:match("^Habilidade_") ~= nil and b.Name ~= "Habilidade_Defender")
		b:SetAttribute("CartaAcao", true)
		E.botao(b, principal, b.Name == "Fugir")
		local function desenharTexto()
			if b:GetAttribute("CartaCompacta") then return end
			local texto = b.Text
			local custo = texto:match("(%d+ Ações/%d+ PM)") or texto:match("(%d+ Ação/%d+ PM)") or texto:match("(%d+ Ações)") or texto:match("(%d+ Ação)")
			if not custo and (principal or b.Name:match("^Disparar_") or b.Name == "Mover") then custo = "1 Ação" end
			local limpo = texto
			if custo then limpo = limpo:gsub(custo, "") end
			limpo = limpo:gsub("%s*·%s*·%s*", " · "):gsub("%s*|%s*|%s*", " | "):gsub("%s*·%s*→%s*", " · ")
			local nome, efeito = limpo:match("^(.-)%s*·%s*(.*)$")
			if not nome then nome, efeito = limpo:match("^(.-)%s*|%s*(.*)$") end
			nome, efeito = nome or limpo, efeito or ""
   if b.Name:match("^Atacar_") or b.Name:match("^Disparar_") then
    nome, efeito = limpo:match("^(%S+)%s+(.+)$")
    nome, efeito = nome or limpo, efeito or ""
   end
			nome = nome:gsub("%s+$", "")
			efeito = efeito:gsub("^%s*→%s*", ""):gsub("^%s*|%s*", ""):gsub("%s*·%s*$", ""):gsub("%s*|%s*$", "")
			local function label(id, valor, y, altura, fonte, tamanho)
				local l = b:FindFirstChild(id)
				if not l then l = Instance.new("TextLabel"); l.Name, l.Parent = id, b end
				l.BackgroundTransparency, l.Text = 1, valor
				l.Position, l.Size = UDim2.fromOffset(8, y), UDim2.new(1, -16, 0, altura)
				l.FontFace, l.TextSize, l.TextColor3 = fonte, tamanho, b.TextColor3
				l.TextWrapped, l.TextXAlignment, l.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
				l.TextTruncate = Enum.TextTruncate.AtEnd
				l.TextTransparency = if b.Active then 0 else T.transparencias.desabilitado
				return l
			end
			-- Faixas verticais exclusivas: título 6..46, efeito 48..88, custo 92..112.
			label("NomeAcao", nome, 4, 24, T.fontes.rotulo, 18)
			local secundario = label("EfeitoAcao", efeito, 28, 30, T.fontes.rotulo, 15)
			secundario.TextColor3 = if principal then T.cores.textoEscuro else T.cores.secundario
			local selo = label("Custo", custo or "", 60, 20, T.fontes.rotulo, 14)
			selo.TextXAlignment = Enum.TextXAlignment.Right
		end
		b.TextTransparency = 1
		b.Size = UDim2.fromOffset(larguraBotao, 84)
		b.Position = UDim2.fromOffset((indice % colunas) * (larguraBotao + 8), math.floor(indice / colunas) * 92)
		desenharTexto()
		-- Algumas seleções (Lança de Pedra) alteram o texto sem reconstruir a lista.
		b:GetPropertyChangedSignal("Text"):Connect(desenharTexto)
		b:GetPropertyChangedSignal("Active"):Connect(function()
   if b:GetAttribute("CartaCompacta") then return end
   b.TextTransparency = 1; desenharTexto()
  end)
		indice += 1
	end
	local hauteur = math.ceil(indice / colunas) * 92
	for _, nota in notas do
		nota.Position, nota.Size = UDim2.fromOffset(0, hauteur), UDim2.fromOffset(largura, 44)
		nota.TextWrapped, nota.TextTruncate = true, Enum.TextTruncate.None
		hauteur += 48
	end
	return hauteur
end
-- Navega apenas na apresentação: mantém as mesmas Instances e conexões das ações.
function E.faixa(lista, faixa, passar, desistir, largura, grupoInicial, aoMudar)
	local originais = lista:GetChildren()
	local podeDesistir = desistir.Visible
	local mover, defender
	for _, b in originais do
		if b.Name == "Mover" then mover = b elseif b.Name == "Habilidade_Defender" then defender = b end
	end
	local grupo = grupoInicial
	local function selecionar(valor)
		grupo = if grupo == valor then nil else valor
		aoMudar(grupo)
		local y = 0
		for _, b in originais do
			if b == mover or b == defender then continue end
			local ataque = b.Name:match("^Atacar_") or b.Name:match("^Disparar_")
			b.Visible = grupo ~= nil and (if grupo == "ataque" then ataque ~= nil else ataque == nil)
			if b.Visible then
    for _,label in b:GetChildren() do
     if label:IsA("TextLabel") then label.TextSize=math.max(16,label.TextSize) end
    end
				b.Position, b.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(largura, if b:IsA("TextButton") then 84 else 44)
				y += b.Size.Y.Offset + 8
			end
		end
		desistir.Parent, desistir.Visible = lista, podeDesistir and grupo == "habilidades"
		if desistir.Visible then desistir.Position, desistir.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(largura, 44); y += 52 end
		lista.Visible = grupo ~= nil
		lista.CanvasSize, lista.CanvasPosition = UDim2.fromOffset(0, y), Vector2.new(0, 0)
	end
	local function navegacao(nome, texto, valor)
		local b = Instance.new("TextButton")
		b.Name, b.Text, b.Parent = nome, texto, faixa
		b.Activated:Connect(function() selecionar(valor) end)
		return b
	end
	local atacar = navegacao("AbrirAtaques", "Atacar", "ataque")
	local habilidades = navegacao("AbrirHabilidades", "Habilid.", "habilidades")
	local function preparar(b, nome)
		if not b then b = Instance.new("TextButton"); b.Active = false end
		b:SetAttribute("CartaCompacta", true)
		b.Parent, b.Text = faixa, nome
		return b
	end
	mover, defender = preparar(mover, "Mover"), preparar(defender, "Defender")
	passar.Parent, passar.Text = faixa, "Encerrar"
 local icones = {"combate", "estrela", "mapa", "losangoVazio", "confirmar"}
 for i, b in {atacar, habilidades, mover, defender, passar} do
  E.botao(b, false, false)
  for _, filho in b:GetChildren() do if filho:IsA("TextLabel") then filho:Destroy() end end
  b.TextTransparency, b.TextSize, b.TextWrapped = 1, 16, false
  b.Size, b.Position = UDim2.fromOffset((largura - 16) / 5, 64), UDim2.fromOffset((i - 1) * ((largura - 16) / 5 + 4), 0)
  local icone = Instance.new("TextLabel")
  icone.Name, icone.Text, icone.FontFace = "IconeCompacto", T.icone(icones[i]), T.FONTE_ICONE
  icone.BackgroundTransparency, icone.TextSize = 1, 28
  icone.Size, icone.Position, icone.Parent = UDim2.new(1,0,0,34), UDim2.fromOffset(0,2), b
  local rotulo = Instance.new("TextLabel")
  rotulo.Name, rotulo.Text, rotulo.FontFace = "RotuloCompacto", b.Text, T.fontes.rotulo
  rotulo.BackgroundTransparency, rotulo.TextSize, rotulo.TextWrapped = 1, 16, false
  rotulo.Size, rotulo.Position, rotulo.Parent = UDim2.new(1,0,0,24), UDim2.fromOffset(0,36), b
  local function atualizar()
   b.TextTransparency = 1
   rotulo.Text = if b == passar then "Encerrar" else b.Text
   for _, l in {icone,rotulo} do l.TextColor3=b.TextColor3; l.TextTransparency=if b.Active then 0 else T.transparencias.desabilitado end
  end
  b:GetPropertyChangedSignal("Text"):Connect(atualizar)
  b:GetPropertyChangedSignal("Active"):Connect(atualizar)
  atualizar()
 end
	grupo = nil
	if grupoInicial then selecionar(grupoInicial) else selecionar(nil) end
end
return E
