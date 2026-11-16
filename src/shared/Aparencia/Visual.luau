-- Montagem visual com Instances, sem rede ou regras.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Aparencia.Catalogo)
local Racas = require(Shared.Aparencia.Racas)
local Encaixe = require(script.Parent.EncaixeCosmetico)
local Personagem = require(script.Parent.Personagem)
local Montar = require(script.Parent.MontarModelo)
local Visual = {}
local function cor(id)
	local c = Catalogo.CORES[id]
	return Color3.fromRGB(c[1], c[2], c[3])
end
Visual.cor = cor -- cores cosméticas do catálogo; não são tokens de interface

-- extras.cabeloAvatar: ids de HairAccessory do avatar do jogador (só quando Personagem.CABELO_DO_AVATAR).
function Visual.descrever(a, raceId, extras)
	local d = Instance.new("HumanoidDescription") -- vazio: sem roupas/acessórios do usuário
	for _, campo in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face", "Shirt", "Pants", "GraphicTShirt" } do d[campo] = 0 end
	local corpo = Personagem.CORPOS[Personagem.CORPO] -- nil = "caixas" (R15 padrão)
	if corpo then for campo, id in corpo do d[campo] = id end end
	local e = Racas.POR_ID[raceId].escala
	d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = e.altura, e.largura, e.profundidade, e.cabeca
	d.BodyTypeScale, d.ProportionScale = 0, 0
	if Personagem.CABELO_DO_AVATAR and extras and type(extras.cabeloAvatar) == "string" then d.HairAccessory = extras.cabeloAvatar end
	d.HeadColor, d.LeftArmColor, d.RightArmColor = cor(a.cores.pele), cor(a.cores.pele), cor(a.cores.pele)
	-- Corpos oficiais: o pescoço/ombros que a camisa clássica não cobre aparecem na cor do torso; pele evita o "colarinho" azul.
	d.TorsoColor, d.LeftLegColor, d.RightLegColor = cor(if corpo then a.cores.pele else a.cores.camisa), cor(a.cores.calca), cor(a.cores.calca)
	return d
end

-- Cabelo do avatar mantido pela descrição: recolore pela cor da criação (ou deixa como está se não aceitar).
local function recolorirCabelo(corpo, cor3)
	for _, acc in corpo:GetChildren() do
		if acc:IsA("Accessory") and acc.AccessoryType == Enum.AccessoryType.Hair then
			local h = acc:FindFirstChild("Handle")
			if h then
				local m = h:FindFirstChildOfClass("SpecialMesh")
				local classe = if m then "SpecialMesh" else h.ClassName
				local e = Personagem.estrategiaCabelo(classe, h:FindFirstChildOfClass("SurfaceAppearance") ~= nil)
				if e == "vertex" then m.VertexColor = Vector3.new(cor3.R, cor3.G, cor3.B)
				elseif e == "cor" then h.TextureID = ""; h.Color = cor3 end
			end
		end
	end
end

local function limpar(corpo)
	local antiga = corpo:FindFirstChild("AparenciaMoshoku")
	if antiga then antiga:Destroy() end
	for _, obj in corpo:GetChildren() do
		if (obj:IsA("Accessory") and not (Personagem.CABELO_DO_AVATAR and obj.AccessoryType == Enum.AccessoryType.Hair)) or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then obj:Destroy() end
	end
end

-- Chamado somente depois de aplicar a descrição. Separado para testes do rosto sem rede.
function Visual.decorar(corpo, a, raceId)
	limpar(corpo)
	local head = corpo:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	for _, obj in head:GetChildren() do
		-- Cabeça redonda padrão: só o rosto pintado antigo sai; a malha fica (PERS2).
		if obj:IsA("Decal") or obj:IsA("SurfaceAppearance") or (Personagem.CABECA_CUBICA and obj:IsA("SpecialMesh")) then obj:Destroy() end
	end
	local escala = Racas.POR_ID[raceId].escala.cabeca
	if Personagem.CABECA_CUBICA then head.Size = Vector3.new(escala, escala, escala) end -- boneco antigo
	local malha = head:FindFirstChildOfClass("SpecialMesh")
	local medidas = Personagem.medidasCabeca(head.Size, if malha then malha.Scale else nil)
	head.Color = cor(a.cores.pele)
	local pasta = Instance.new("Folder")
	pasta.Name, pasta.Parent = "AparenciaMoshoku", corpo
	-- Em pele muito escura (ex.: Demônio Imortal, azeviche) sobrancelha/nariz/boca escurecidos sumiam: clareia.
	local pele = cor(a.cores.pele)
	local escura = 0.2126 * pele.R + 0.7152 * pele.G + 0.0722 * pele.B < 0.18
	local cores = { olho = Color3.fromRGB(245,245,235), iris = cor(a.cores.olho),
		peleEscura = if escura then pele:Lerp(Color3.new(1, 1, 1), 0.38) else pele:Lerp(Color3.new(), 0.4),
		boca = if escura then Color3.fromRGB(205,95,105) else Color3.fromRGB(65,30,30), dente = Color3.fromRGB(250,245,225) }
	-- PERS3: rosto pintado (Decal, simétrico e sem blocos vazando da cabeça) quando já enviado; senão blocos.
	local decal = Personagem.rostoDecal(a.rosto, a.cores.olho)
	if decal then
		-- O Decal direto na cabeça R15 sai como uma lasca (UV da malha) e a textura da cabeça traz um rosto preto:
		-- limpa a textura e usa uma placa fina na frente (Decal em Part quase transparente; 1.0 esconderia o Decal).
		head.TextureID = ""
		local placa = Instance.new("Part")
		placa.Name, placa.Transparency = "RostoPlaca", 0.99
		placa.Size = Vector3.new(medidas.largura, medidas.altura, 0.02)
		placa.CFrame = head.CFrame * CFrame.new(0, 0, -(medidas.profundidade / 2 + 0.012))
		local d = Instance.new("Decal")
		d.Name, d.Face, d.Texture, d.Parent = "face", Enum.NormalId.Front, decal, placa
		placa.Parent = pasta
	end
	for categoria, estilo in (if decal then {} else a.rosto) do
		for i, bloco in Catalogo.ROSTO[categoria][estilo] do
			local p = Instance.new("Part")
			p.Name = categoria .. tostring(i)
			local tamanho, posicao = Personagem.blocoDoRosto(bloco, medidas, escala)
			p.Size = tamanho
			p.CFrame = head.CFrame * CFrame.new(posicao)
			p.Color, p.Material = cores[bloco.papel], Enum.Material.SmoothPlastic
			p.Parent = pasta
		end
	end
	-- Roupa do jogo: moldes clássicos pintados, quando já enviados; vazio = cor de torso/pernas (fallback).
	local camisa, calca = Personagem.moldes(Personagem.conjuntoDe(a))
	if camisa then
		local c = Instance.new("Shirt"); c.Name, c.ShirtTemplate, c.Parent = "CamisaMoshoku", camisa, corpo
	end
	if calca then
		local c = Instance.new("Pants"); c.Name, c.PantsTemplate, c.Parent = "CalcaMoshoku", calca, corpo
	end
	-- A mesma configuração de colisão/massa/soldas dos treinadores.
	Encaixe.configurarPecas(pasta, head, "RostoBlocos")
	local function montar(item, tint)
		local nome = Personagem.moduloDe(item, Montar.existe)
		if not nome then return end
		for _, ponto in item.encaixes or { item.encaixe } do
			local c = { modulo = nome, parte = ponto.parte, offset = ponto.offset }
			Encaixe.montar(corpo, c, pasta, if nome == item.malha then medidas.altura / Personagem.CABECA_MALHA else medidas.altura, tint) -- altura real da cabeça (= escala se cúbica)
		end
	end
	if Personagem.CABELO_DO_AVATAR then recolorirCabelo(corpo, cor(a.cores.cabelo)) end
	-- PERS3b: o capuz cobre a cabeça; com cabelo junto, as mechas atravessavam o tecido.
	local capuz = table.find(a.roupas, "RoupaCapuz1") ~= nil or table.find(Racas.POR_ID[raceId].obrigatorias, "RoupaCapuz1") ~= nil
	if not capuz then montar(Catalogo.CABELOS[a.cabelo], cor(a.cores.cabelo)) end
	montar(Catalogo.BARBAS[a.barba], cor(a.cores.cabelo))
	for _, id in Racas.POR_ID[raceId].obrigatorias do
		local item = Catalogo.PECAS[id]
		montar(item, if item and item.tinge == "pele" then cor(a.cores.pele) elseif item and item.tinge == "cabelo" then cor(a.cores.cabelo) else nil)
	end
	for _, id in a.roupas do
		-- Túnica básica segue a camisa selecionada; trajes autorais mantêm suas cores.
		montar(Catalogo.PECAS[id], if id == "RoupaTunica1" or id == "RoupaCapaCurta1" then cor(a.cores.camisa) else nil)
	end
end

return Visual
