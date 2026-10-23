local E=require(game.ReplicatedStorage.Shared.SalaEspaco)
local W={}
function W.create(deps)
	local workspaceAtual=(deps and deps.workspace) or workspace
	local existente=workspaceAtual:FindFirstChild("SalaRPG")
	if existente then return existente end
	local m=Instance.new("Model");m.Name="SalaRPG"
	local function p(nome,tamanho,cf,cor,material,class)
		local o=Instance.new(class or "Part");o.Name=nome;o.Size=tamanho;o.CFrame=cf;o.Color=cor;o.Material=material or Enum.Material.Wood;o.Anchored=true;o.TopSurface=Enum.SurfaceType.Smooth;o.Parent=m;return o
	end
	local madeira=Color3.fromRGB(88,57,39);local parede=Color3.fromRGB(180,160,133)
	p("Piso",Vector3.new(42,1,40),CFrame.new(250,-.5,0),madeira)
	p("ParedeFundo",Vector3.new(42,15,1),CFrame.new(250,7,-20),parede,Enum.Material.Plaster)
	p("ParedeFrente",Vector3.new(42,15,1),CFrame.new(250,7,20),parede,Enum.Material.Plaster)
	-- A abertura oeste conecta o lobby à primeira área explorável (J4).
	-- Mantém o restante da parede e a viga superior para preservar o abrigo.
	p("ParedeLateralOesteNorte",Vector3.new(1,15,13),CFrame.new(229,7,-13.5),parede,Enum.Material.Plaster)
	p("ParedeLateralOesteSul",Vector3.new(1,15,13),CFrame.new(229,7,13.5),parede,Enum.Material.Plaster)
	p("VigaPortaOeste",Vector3.new(1,4,14),CFrame.new(229,12.5,0),parede,Enum.Material.Plaster)
	p("ParedeLateralLeste",Vector3.new(1,15,40),CFrame.new(271,7,0),parede,Enum.Material.Plaster)
	p("Teto",Vector3.new(42,1,40),CFrame.new(250,15,0),parede)
	p("Tapete",Vector3.new(28,.05,31),CFrame.new(250,.04,0),Color3.fromRGB(78,43,45),Enum.Material.Fabric)
	p("Mesa",Vector3.new(11,1,21),CFrame.new(E.MESA),madeira)
	for _,x in {-4,4} do for _,z in {-8,8} do p("PeMesa",Vector3.new(.7,2.5,.7),CFrame.new(250+x,1.25,z),madeira) end end
	for i=1,10 do
		local cf=E.lugar(i)
		local assento=p("Lugar"..i,Vector3.new(3.2,.5,3.2),cf,Color3.fromRGB(96,68,48),nil,"Seat");assento:SetAttribute("LugarSala",i)
		p("Encosto"..i,Vector3.new(3.2,3,.45),cf*CFrame.new(0,1.4,1.6),madeira)
		for _,x in {-1.2,1.2} do for _,z in {-1.2,1.2} do p("PeCadeira",Vector3.new(.25,1.8,.25),cf*CFrame.new(x,-1,z),madeira) end end
	end
	local function objeto(nome,tamanho,pos,cor,acao)
		local o=p(nome,tamanho,CFrame.new(pos),cor);o:SetAttribute("SalaObjeto",acao);return o
	end
	-- Escudo dobrável: couro escuro, moldura de latão e dobradiças reais.
	local couro=Color3.fromRGB(31,58,57);local latao=Color3.fromRGB(177,141,79)
	local function painel(nome,largura,cf,aba)
		local o=objeto(nome,Vector3.new(largura,1.4,.18),cf.Position,couro,"mestre");o.CFrame=cf;o.Material=Enum.Material.SmoothPlastic
		for _,lado in {-1,1} do
			p("MolduraEscudo",Vector3.new(.06,1.45,.24),cf*CFrame.new(lado*(largura/2-.03),0,0),latao,Enum.Material.Metal)
			p("MolduraEscudo",Vector3.new(largura,.06,.24),cf*CFrame.new(0,lado*.69,0),latao,Enum.Material.Metal)
		end
		if aba then
			local medalhao=p("MedalhaoEscudo",Vector3.new(.68,.68,.06),cf*CFrame.new(0,0,-.13)*CFrame.Angles(0,0,math.pi/4),latao,Enum.Material.Metal);medalhao.CanCollide=false
			p("CentroMedalhao",Vector3.new(.4,.4,.07),cf*CFrame.new(0,0,-.17)*CFrame.Angles(0,0,math.pi/4),couro)
		end
		return o
	end
	painel("EscudoMestre",4.8,CFrame.new(250,4.33,-8.5),false)
	for _,lado in {-1,1} do
		painel("AbaEscudo",2.2,CFrame.new(250+lado*3.32,4.33,-8)*CFrame.Angles(0,math.rad(lado*30),0),true)
		for _,y in {-.4,.4} do p("DobradicaEscudo",Vector3.new(.12,.35,.29),CFrame.new(250+lado*2.42,4.33+y,-8.5),latao,Enum.Material.Metal) end
	end
	p("BaseEscudo",Vector3.new(9.2,.12,1.3),CFrame.new(250,3.66,-8.35),Color3.fromRGB(44,33,29))
	local caderno=objeto("LivroDeAjustes",Vector3.new(2.5,.3,3),Vector3.new(253.5,3.7,-5),Color3.fromRGB(60,75,86),"livro");caderno:SetAttribute("ObjetoId","livro-ajustes")
	objeto("SeloPronto",Vector3.new(2,.2,2),Vector3.new(246.5,3.65,0),Color3.fromRGB(67,129,96),"pronto")
	objeto("SeloEscolha",Vector3.new(1.8,.12,1.8),Vector3.new(253.4,3.65,0),latao,"assumir")
	local expedicao=objeto("ExpedicaoAutonoma",Vector3.new(4,2.6,.2),Vector3.new(238.5,4,-18.8),Color3.fromRGB(104,74,49),"autonomo")
	expedicao.CFrame=CFrame.new(238.5,4,-18.8)*CFrame.Angles(0,math.rad(180),0)
	objeto("SineteAdmin",Vector3.new(.8,.25,.8),Vector3.new(253.6,3.77,-7.3),latao,"admin")
	objeto("TabuleiroDaSala",Vector3.new(6,.12,7),Vector3.new(250,3.57,0),Color3.fromRGB(39,60,53),"tabuleiro")
	for i=0,6 do
		p("Grade",Vector3.new(.025,.02,7),CFrame.new(247+i,3.65,0),Color3.fromRGB(172,161,123),Enum.Material.SmoothPlastic).CanCollide=false
		p("Grade",Vector3.new(6,.02,.025),CFrame.new(250,3.65,-3.5+i*7/6),Color3.fromRGB(172,161,123),Enum.Material.SmoothPlastic).CanCollide=false
	end
	-- Dados são desenhados por SalaObjetos para animar os resultados confirmados.
	for _,x in {237,263} do
		local lamp=p("Luminaria",Vector3.new(1.8,.4,1.8),CFrame.new(x,11,0),Color3.fromRGB(255,213,143),Enum.Material.Neon)
		local luz=Instance.new("PointLight");luz.Color=lamp.Color;luz.Brightness=.7;luz.Range=40;luz.Shadows=true;luz.Parent=lamp
	end
	p("Estante",Vector3.new(12,8,1.5),CFrame.new(250,4,18),madeira)
	for n=1,14 do local livro=p("Livro",Vector3.new(.5,2+(n%3)*.25,1.3),CFrame.new(244+n*.75,3,17.1),Color3.fromHSV(n/17,.4,.45));livro:SetAttribute("SalaObjeto","livro");livro:SetAttribute("ObjetoId","livro-cronicas") end
	require(script.Parent.SalaDecoracao).criar(m)
	m.Parent=workspaceAtual
	return m
end
return W
