-- Montagem visual com Instances, sem rede ou regras.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Aparencia.Catalogo)
local Racas = require(Shared.Aparencia.Racas)
local Encaixe = require(script.Parent.EncaixeCosmetico)
local Visual = {}
local function cor(id)
	local c = Catalogo.CORES[id]
	return Color3.fromRGB(c[1], c[2], c[3])
end
Visual.cor = cor -- cores cosméticas do catálogo; não são tokens de interface

function Visual.descrever(a, raceId)
	local d = Instance.new("HumanoidDescription") -- vazio: sem roupas/acessórios do usuário
	for _, campo in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face", "Shirt", "Pants", "GraphicTShirt" } do d[campo] = 0 end
	local e = Racas.POR_ID[raceId].escala
	d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = e.altura, e.largura, e.profundidade, e.cabeca
	d.BodyTypeScale, d.ProportionScale = 0, 0
	d.HeadColor, d.LeftArmColor, d.RightArmColor = cor(a.cores.pele), cor(a.cores.pele), cor(a.cores.pele)
	d.TorsoColor, d.LeftLegColor, d.RightLegColor = cor(a.cores.camisa), cor(a.cores.calca), cor(a.cores.calca)
	return d
end

local function limpar(corpo)
	local antiga = corpo:FindFirstChild("AparenciaMoshoku")
	if antiga then antiga:Destroy() end
	for _, obj in corpo:GetChildren() do
		if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then obj:Destroy() end
	end
end

-- Chamado somente depois de aplicar a descrição. Separado para testes do rosto sem rede.
function Visual.decorar(corpo, a, raceId)
	limpar(corpo)
	local head = corpo:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	for _, obj in head:GetChildren() do
		if obj:IsA("Decal") or obj:IsA("SpecialMesh") or obj:IsA("SurfaceAppearance") then obj:Destroy() end
	end
	local escala = Racas.POR_ID[raceId].escala.cabeca
	head.Size = Vector3.new(escala, escala, escala) -- cubo real, inclusive com cabeça clássica
	head.Color = cor(a.cores.pele)
	local pasta = Instance.new("Folder")
	pasta.Name, pasta.Parent = "AparenciaMoshoku", corpo
	-- Em pele muito escura (ex.: Demônio Imortal, azeviche) sobrancelha/nariz/boca escurecidos sumiam: clareia.
	local pele = cor(a.cores.pele)
	local escura = 0.2126 * pele.R + 0.7152 * pele.G + 0.0722 * pele.B < 0.18
	local cores = { olho = Color3.fromRGB(245,245,235), iris = cor(a.cores.olho),
		peleEscura = if escura then pele:Lerp(Color3.new(1, 1, 1), 0.38) else pele:Lerp(Color3.new(), 0.4),
		boca = if escura then Color3.fromRGB(205,95,105) else Color3.fromRGB(65,30,30), dente = Color3.fromRGB(250,245,225) }
	for categoria, estilo in a.rosto do
		for i, bloco in Catalogo.ROSTO[categoria][estilo] do
			local p = Instance.new("Part")
			p.Name = categoria .. tostring(i)
			local t, v = bloco.tamanho, bloco.posicao
			p.Size = Vector3.new(t.x * escala / 2, t.y * escala, t.z * escala)
			p.CFrame = head.CFrame * CFrame.new(v.x * escala / 2, v.y * escala, v.z * escala)
			p.Color, p.Material = cores[bloco.papel], Enum.Material.SmoothPlastic
			p.Parent = pasta
		end
	end
	-- A mesma configuração de colisão/massa/soldas dos treinadores.
	Encaixe.configurarPecas(pasta, head, "RostoBlocos")
	local function montar(item, tint)
		if not item or not item.modulo then return end
		for _, ponto in item.encaixes or { item.encaixe } do
			local c = { modulo = item.modulo, parte = ponto.parte, offset = ponto.offset }
			Encaixe.montar(corpo, c, pasta, escala, tint)
		end
	end
	montar(Catalogo.CABELOS[a.cabelo], cor(a.cores.cabelo))
	montar(Catalogo.BARBAS[a.barba], cor(a.cores.cabelo))
	for _, id in Racas.POR_ID[raceId].obrigatorias do montar(Catalogo.PECAS[id]) end
	for _, id in a.roupas do
		-- Túnica básica segue a camisa selecionada; trajes autorais mantêm suas cores.
		montar(Catalogo.PECAS[id], if id == "RoupaTunica1" then cor(a.cores.camisa) else nil)
	end
end

return Visual
