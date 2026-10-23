-- Constrói a vila a partir de shared/Mundo/VilaLayout. Só apresentação física:
-- não contém regras; NPCs, dojo e loja futuros ligam serviços próprios aos marcos.
local Layout = require(game:GetService("ReplicatedStorage").Shared.Mundo.VilaLayout)
local MontarModelo = require(script.Parent.MontarModelo)
local Props = require(script.Parent.Props)
local Povoamento = require(game:GetService("ReplicatedStorage").Shared.Mundo.PropsPovoamento)
local ArvoreMundo = require(script.Parent.ArvoreMundo)

local Terreno = require(game:GetService("ReplicatedStorage").Shared.Mundo.TerrenoLayout)

local Vila = {}

local NOME = "Vila"
local ALTURA_PORTA, LARGURA_PORTA, PAREDE = 7, 5, 1

local CORES = {
	solo = Color3.fromRGB(103, 137, 78),
	estrada = Color3.fromRGB(157, 132, 94),
	praca = Color3.fromRGB(150, 146, 136),
	parede = Color3.fromRGB(214, 196, 160),
	viga = Color3.fromRGB(96, 68, 44),
	telhado = Color3.fromRGB(128, 62, 48),
	telhadoDojo = Color3.fromRGB(52, 58, 72),
	pedra = Color3.fromRGB(112, 109, 98),
	lona = Color3.fromRGB(176, 149, 105),
	tronco = Color3.fromRGB(102, 73, 48),
	copa = Color3.fromRGB(54, 103, 65),
}

local function parte(pai, nome, tamanho, cframe, cor, material, classe)
	local item = Instance.new(classe or "Part")
	item.Name = nome
	item.Size = tamanho
	item.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	item.Color = cor
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = pai
	return item
end

local function piso(pai, nome, ret, y, espessura, cor, material)
	return parte(pai, nome, Vector3.new(ret.sx, espessura, ret.sz), Vector3.new(ret.x, y, ret.z), cor, material)
end

local function marco(item, id, papel)
	item:SetAttribute("AreaId", id)
	item:SetAttribute("AreaRole", papel)
	return item
end

-- Parede de comprimento `comprimento` centrada em `centro`, ao longo do eixo `eixo`;
-- com porta abre um vão central com verga acima.
local function parede(pai, centro, eixo, comprimento, altura, comPorta)
	local function bloco(nome, deslocamento, largura, y0, y1)
		local pos = centro + (if eixo == "x" then Vector3.new(deslocamento, 0, 0) else Vector3.new(0, 0, deslocamento))
		local tamanho = if eixo == "x" then Vector3.new(largura, y1 - y0, PAREDE) else Vector3.new(PAREDE, y1 - y0, largura)
		parte(pai, nome, tamanho, Vector3.new(pos.X, (y0 + y1) / 2, pos.Z), CORES.parede, Enum.Material.Plaster)
	end
	if not comPorta then
		bloco("Parede", 0, comprimento, 0, altura)
		return
	end
	local lateral = (comprimento - LARGURA_PORTA) / 2
	bloco("Parede", -(LARGURA_PORTA + lateral) / 2, lateral, 0, altura)
	bloco("Parede", (LARGURA_PORTA + lateral) / 2, lateral, 0, altura)
	bloco("Verga", 0, LARGURA_PORTA, ALTURA_PORTA, altura)
end

-- Telhado de duas águas com WedgeParts; a cumeeira segue o lado maior.
local function telhado(pai, e, cor)
	local subida = math.max(e.sx, e.sz) * 0.18 + 2
	local y = e.altura + subida / 2
	local aoLongoDeX = e.sx >= e.sz
	local comprimento = (if aoLongoDeX then e.sx else e.sz) + 2
	local meia = (if aoLongoDeX then e.sz else e.sx) / 2 + 1
	for _, lado in ipairs({ 1, -1 }) do
		-- A face alta da cunha fica em +Z local; girar para que aponte à cumeeira.
		local cf
		if aoLongoDeX then
			cf = CFrame.new(e.x, y, e.z + lado * meia / 2) * CFrame.Angles(0, if lado == 1 then math.pi else 0, 0)
		else
			cf = CFrame.new(e.x + lado * meia / 2, y, e.z) * CFrame.Angles(0, if lado == 1 then -math.pi / 2 else math.pi / 2, 0)
		end
		parte(pai, "Telhado", Vector3.new(comprimento, subida, meia), cf, cor, Enum.Material.Slate, "WedgePart")
	end
end

-- Blockout usado quando o modelo pronto não existe (ex.: antes da exportação).
local function blockout(modelo, e)
	local o = Layout.ocupacao(e)
	local b = { x = o.x, z = o.z, sx = o.sx, sz = o.sz, altura = 12, porta = e.porta, papel = e.papel }
	piso(modelo, "Piso", o, 0.15, 0.3, CORES.viga, Enum.Material.WoodPlanks)
	local meioX, meioZ = b.sx / 2 - PAREDE / 2, b.sz / 2 - PAREDE / 2
	local base = Vector3.new(b.x, 0, b.z)
	parede(modelo, base + Vector3.new(0, 0, meioZ), "x", b.sx, b.altura, b.porta == "norte")
	parede(modelo, base + Vector3.new(0, 0, -meioZ), "x", b.sx, b.altura, b.porta == "sul")
	parede(modelo, base + Vector3.new(meioX, 0, 0), "z", b.sz - 2 * PAREDE, b.altura, b.porta == "leste")
	parede(modelo, base + Vector3.new(-meioX, 0, 0), "z", b.sz - 2 * PAREDE, b.altura, b.porta == "oeste")
	telhado(modelo, b, if b.papel == "dojo" then CORES.telhadoDojo else CORES.telhado)
end

-- Monta o modelo pronto girado para a porta e apoiado no chão (y=0).
local function pronto(pai, nomeModulo, x, z, angulo, escala, altura)
	local modelo = MontarModelo.montar(nomeModulo, pai, CFrame.new(x, 0, z) * CFrame.Angles(0, angulo, 0), escala)
	local caixa, tamanho = modelo:GetBoundingBox()
	modelo:PivotTo(modelo:GetPivot() + Vector3.new(0, (altura or 0) - (caixa.Position.Y - tamanho.Y / 2), 0))
	Props.aplicarMateriaisELuzes(modelo, nomeModulo)
	return modelo
end

local function edificio(pai, e, altura, semente)
	local modelo
	if MontarModelo.existe(e.modelo) then
		modelo = pronto(pai, e.modelo, e.x, e.z, Layout.angulo(e), e.escala or Layout.ESCALA_PREDIOS, altura)
	else
		modelo = Instance.new("Model")
		blockout(modelo, e)
		modelo.Parent = pai
	end
	if semente then
		local rgb = Layout.paleta(e,semente)
		for _,p in modelo:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "Parede" then p.Color=Color3.fromRGB(rgb[1],rgb[2],rgb[3]) end
		end
	end
	modelo.Name = e.nome
	marco(modelo, Layout.ID .. "/" .. e.id, e.papel)
	local porta = Layout.porta(e)
	local entrada = parte(modelo, "Entrada", Vector3.new(2, 0.2, 2), Vector3.new(porta.x, (altura or 0)+0.1, porta.z),
		CORES.viga, Enum.Material.WoodPlanks)
	entrada.CanCollide, entrada.CanQuery, entrada.Transparency = false, false, 1
	marco(entrada, Layout.ID .. "/" .. e.id .. "/entrada", "entry")
	return modelo
end

local function barraca(pai, b)
	if not MontarModelo.existe(b.modelo) then return end
	marco(pronto(pai, b.modelo, b.x, b.z, Layout.angulo(b), 1), Layout.ID .. "/" .. b.id, "stall")
end

local function poste(pai, p)
	parte(pai, "Poste", Vector3.new(0.6, 9, 0.6), Vector3.new(p.x, 4.5, p.z), CORES.viga, Enum.Material.Wood)
	local lampiao = parte(pai, "Lampiao", Vector3.new(1, 1.3, 1), Vector3.new(p.x, 9.6, p.z),
		Color3.fromRGB(255, 211, 125), Enum.Material.Neon)
	lampiao.CanCollide = false
	local luz = Instance.new("PointLight")
	luz.Color, luz.Brightness, luz.Range, luz.Shadows = Color3.fromRGB(255, 196, 120), 1.2, 22, false
	luz.Parent = lampiao
end

local function arvore(pai, x, z, escala)
	ArvoreMundo.criar(pai, parte, x, z, escala, CORES.copa, "carvalho")
end

-- Fundação nivelada sem alterar zonas do terreno. Até o coordenador nivelar os
-- lotes registrados, o piso fica no maior ponto amostrado da pegada.
local function nivel(e)
	local r=Layout.ocupacao(e)
	local baixo,alto=math.huge,-math.huge
	for ix=0,4 do for iz=0,4 do
		local h=Terreno.altura(r.x+(ix/4-0.5)*r.sx,r.z+(iz/4-0.5)*r.sz)
		baixo,alto=math.min(baixo,h),math.max(alto,h)
	end end
	return baixo,alto
end

local function jardineiras(pai,e,altura,casa)
	if not MontarModelo.existe("Jardineira") then return end
	-- Dados locais das janelas térreas dos geradores casas.py/predios.py.
	-- Exportação espelha Y: a mão-francesa do asset fica em -Z (não +Z).
	local dados=Layout.JARDINEIRAS[e.modelo]
	if not dados then return end
	local xs,paredeZ,pe=dados.xs,dados.paredeZ,dados.pe
	local cf=CFrame.new(e.x,altura,e.z)*CFrame.Angles(0,Layout.angulo(e),0)
	if casa then
		for _,p in casa:GetDescendants() do
			if p:IsA("BasePart") and p.Name=="Parede" then
				local localCF=cf:ToObjectSpace(p.CFrame)
				paredeZ=localCF.Position.Z+p.Size.Z/2
				break
			end
		end
	end
	for _,x in ipairs(xs) do
		local ponto=cf:PointToWorldSpace(Vector3.new(x,pe,paredeZ+0.45))
		local modelo=pronto(pai,"Jardineira",ponto.X,ponto.Z,Layout.angulo(e),0.65,ponto.Y)
		modelo.Name="Jardineira"
		for _,p in modelo:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end
	end
end

local function acabamentos(pai,semente)
	local casas=Instance.new("Folder")
	casas.Name="CasasNovas"; casas.Parent=pai
	for _,e in ipairs(Layout.CASAS_NOVAS) do
		if MontarModelo.existe(e.modelo) then
			local baixo,alto=nivel(e)
			local modelo=edificio(casas,e,alto,semente)
			local r=Layout.ocupacao(e)
			if alto-baixo>0.05 then
				piso(modelo,"Fundacao",r,(alto+baixo)/2-0.1,alto-baixo+0.2,CORES.pedra,Enum.Material.Slate)
			end
			jardineiras(modelo,e,alto,modelo)
		end
	end
	for _,e in ipairs(Layout.EDIFICIOS) do
		if e.papel=="house" then
			local casa
			for _,m in pai.Edificios:GetChildren() do if m:GetAttribute("AreaId")==Layout.ID.."/"..e.id then casa=m break end end
			jardineiras(pai,e,0,casa)
		end
	end
	local decor=Props.criar(pai,Layout.DECORACAO)
	decor.Name="Praca e quintais"
	local caminhos=Instance.new("Folder")
	caminhos.Name="Pedras de acesso"; caminhos.Parent=pai
	for _,p in ipairs(Layout.pedras(semente)) do
		local pedra=parte(caminhos,"Pedra "..p.acesso,Vector3.new(p.sx,0.15,p.sz),
			CFrame.new(p.x,Terreno.altura(p.x,p.z)+0.075,p.z)*CFrame.Angles(0,math.rad(p.giro),0),
			CORES.pedra,Enum.Material.Slate)
		pedra.CanCollide=false
	end
end

function Vila.start(deps)
	deps = deps or {}
	local raiz = deps.workspace or workspace
	local existente = raiz:FindFirstChild(NOME)
	if existente then return existente end

	local vila = Instance.new("Model")
	vila.Name = NOME
	marco(vila, Layout.ID, "region")
	local placaPoste = Instance.new("Folder")
	placaPoste.Name = "Saida da Floresta Sombria"
	placaPoste.Parent = vila
	parte(placaPoste, "Poste da placa", Vector3.new(0.5, 5, 0.5), Vector3.new(Layout.PLACA_FLORESTA.x, 2.5, Layout.PLACA_FLORESTA.z), CORES.viga, Enum.Material.Wood)
	local placa = parte(placaPoste, "Placa", Vector3.new(8, 2.2, 0.35), Vector3.new(Layout.PLACA_FLORESTA.x, 4.4, Layout.PLACA_FLORESTA.z), Color3.fromRGB(92, 57, 36), Enum.Material.WoodPlanks)
	local superficie = Instance.new("SurfaceGui")
	superficie.Name = "Texto da placa"
	superficie.Face = Enum.NormalId.Back
	superficie.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	superficie.PixelsPerStud = 40
	superficie.Parent = placa
	local textoPlaca = Instance.new("TextLabel")
	textoPlaca.Name = "Aviso"
	textoPlaca.Size = UDim2.fromScale(1, 1)
	textoPlaca.BackgroundTransparency = 1
	textoPlaca.Text = "Floresta Sombria — perigo"
	textoPlaca.TextColor3 = Color3.fromRGB(255, 224, 164)
	textoPlaca.TextScaled = true
	textoPlaca.Font = Enum.Font.GothamBold
	textoPlaca.Parent = superficie
	local praca = Instance.new("Folder")
	praca.Name = "Praca"
	marco(praca, Layout.ID .. "/praca", "landmark")
	praca.Parent = vila
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Nascimento"
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.Position = Vector3.new(Layout.NASCIMENTO.x, 0.2, Layout.NASCIMENTO.z)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = vila

	if MontarModelo.existe(Layout.CHAFARIZ.modelo) then
		marco(pronto(praca, Layout.CHAFARIZ.modelo, Layout.CHAFARIZ.x, Layout.CHAFARIZ.z, 0, 1),
			Layout.ID .. "/chafariz", "landmark")
	end
	if MontarModelo.existe(Layout.POCO_QUINTAL.modelo) then
		marco(pronto(vila, Layout.POCO_QUINTAL.modelo, Layout.POCO_QUINTAL.x, Layout.POCO_QUINTAL.z, 0, 1,
			Terreno.altura(Layout.POCO_QUINTAL.x,Layout.POCO_QUINTAL.z)), Layout.ID .. "/poco", "landmark")
	end

	local edificios = Instance.new("Folder")
	edificios.Name = "Edificios"
	edificios.Parent = vila
	for _, e in ipairs(Layout.EDIFICIOS) do edificio(edificios, e) end

	local aderecos = Instance.new("Folder")
	aderecos.Name = "Aderecos"
	aderecos.Parent = vila
	for _, b in ipairs(Layout.BARRACAS) do barraca(aderecos, b) end
	for _, p in ipairs(Layout.POSTES) do poste(aderecos, p) end
	for _, a in ipairs(Layout.ARVORES) do arvore(aderecos, a[1], a[2], a[3]) end
	acabamentos(vila,deps.semente or 41636)
	Props.criar(vila, Povoamento.vila())

	vila.Parent = raiz
	return vila
end

return Vila
