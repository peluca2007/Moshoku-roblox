-- Cenografia nativa: objetos sem scripts embarcados nem dependências de assets.
local D={}
function D.criar(m)
	local ouro=Color3.fromRGB(174,136,74);local madeira=Color3.fromRGB(57,39,31);local verde=Color3.fromRGB(32,62,58)
	local function p(nome,size,cf,cor,material,forma)
		local o=Instance.new("Part");o.Name=nome;o.Size=size;o.CFrame=cf;o.Color=cor;o.Material=material or Enum.Material.Wood;o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false;o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth
		if forma then o.Shape=forma end;o.Parent=m;return o
	end
	-- Borda e feltro central deixam as áreas de papel e o tabuleiro legíveis.
	for _,lado in {-1,1} do
		p("BordaMesa",Vector3.new(.18,.14,21),CFrame.new(250+lado*5.48,3.58,0),ouro,Enum.Material.Metal)
		p("BordaMesa",Vector3.new(11,.14,.18),CFrame.new(250,3.58,lado*10.48),ouro,Enum.Material.Metal)
	end
	p("FeltroMesa",Vector3.new(9.8,.035,18.9),CFrame.new(250,3.52,0),verde,Enum.Material.Fabric)
	-- Bandeja dos dados: borda baixa, interior de veludo, sem bloquear a interação.
	p("BandejaDados",Vector3.new(4.2,.12,2.25),CFrame.new(250.6,3.63,-5.9),madeira)
	local veludo=p("VeludoDados",Vector3.new(3.8,.03,1.85),CFrame.new(250.6,3.705,-5.9),Color3.fromRGB(83,38,47),Enum.Material.Fabric);veludo.CanCollide=true;veludo.CanQuery=true;veludo:SetAttribute("SalaObjeto","dados")
	for _,lado in {-1,1} do
		p("BordaBandeja",Vector3.new(4.25,.25,.12),CFrame.new(250.6,3.78,-5.9+lado*1.1),ouro,Enum.Material.Metal).CanCollide=true
		p("BordaBandeja",Vector3.new(.12,.25,2.25),CFrame.new(250.6+lado*2.1,3.78,-5.9),ouro,Enum.Material.Metal).CanCollide=true
	end
	-- Caderno costurado e folhas, com lápis e tinteiro ao lado.
	p("FolhasCaderno",Vector3.new(2.25,.12,2.75),CFrame.new(253.5,3.89,-5),Color3.fromRGB(224,211,177),Enum.Material.SmoothPlastic)
	p("CapaCaderno",Vector3.new(2.5,.045,3),CFrame.new(253.5,3.98,-5),Color3.fromRGB(46,66,78),Enum.Material.Fabric)
	for i=1,6 do p("CosturaCaderno",Vector3.new(.12,.03,.06),CFrame.new(252.3,4.01,-6.2+i*.33),ouro,Enum.Material.Metal) end
	p("Lapis",Vector3.new(.08,.08,2),CFrame.new(254.9,3.7,-4.9)*CFrame.Angles(0,.2,0),ouro)
	p("Tinteiro",Vector3.new(.5,.55,.5),CFrame.new(254.6,3.89,-6.5),Color3.fromRGB(27,37,43),Enum.Material.Glass,Enum.PartType.Ball)
	-- Selo de prontidão com aro de latão, em vez de um bloco pintado.
	p("AroSelo",Vector3.new(.1,2.2,2.2),CFrame.new(246.5,3.61,0)*CFrame.Angles(0,0,math.pi/2),ouro,Enum.Material.Metal,Enum.PartType.Cylinder)
	-- Ripas, rodapés e painéis dão escala à sala sem disputar com os objetos.
	for _,z in {-19.4,19.4} do
		p("Rodape",Vector3.new(41,.65,.25),CFrame.new(250,.32,z),madeira)
		p("FrisoParede",Vector3.new(41,.18,.25),CFrame.new(250,3.3,z),ouro)
		for i=0,8 do p("PainelParede",Vector3.new(.18,3,.25),CFrame.new(230+i*5,1.7,z),madeira) end
	end
	for _,x in {229.6,270.4} do
		p("Rodape",Vector3.new(.25,.65,39),CFrame.new(x,.32,0),madeira)
		for _,z in {-12,0,12} do
			local cf=CFrame.new(x,7,z)*CFrame.Angles(0,if x<250 then math.pi/2 else -math.pi/2,0)
			p("MolduraTapeçaria",Vector3.new(3.3,4.6,.15),cf,ouro,Enum.Material.Metal)
			p("Tapeçaria",Vector3.new(3.05,4.35,.2),cf,verde,Enum.Material.Fabric)
			p("SeloTapeçaria",Vector3.new(1.2,1.2,.25),cf*CFrame.Angles(0,0,math.pi/4),ouro,Enum.Material.Metal)
		end
	end
	-- Prateleiras sustentam os livros, com volumes em várias alturas.
	for _,y in {1.5,4.5,7} do p("Prateleira",Vector3.new(12.4,.18,2),CFrame.new(250,y,17.5),madeira) end
	for nivel=1,2 do for i=1,15 do
		local altura=1.3+(i%4)*.2;local x=244.4+i*.7;local y=if nivel==1 then 1.6 else 4.6
		local volume=p("VolumeEncadernado",Vector3.new(.5,altura,1.2),CFrame.new(x,y+altura/2,17.1),Color3.fromHSV(i/19,.35,.32),Enum.Material.Fabric);volume.CanQuery=true;volume:SetAttribute("SalaObjeto","livro");volume:SetAttribute("ObjetoId","livro-cronicas")
		for _,dy in {-.4,.4} do p("FaixaLivro",Vector3.new(.51,.04,.02),CFrame.new(x,y+altura/2+dy,16.49),ouro,Enum.Material.Metal) end
	end end
	-- Velas em suportes, iluminação quente localizada.
	for _,z in {-14,14} do for _,x in {237,263} do
		p("MesaLateral",Vector3.new(2.8,.25,2.8),CFrame.new(x,2.8,z),madeira)
		p("PeLateral",Vector3.new(.5,2.7,.5),CFrame.new(x,1.35,z),madeira)
		p("BaseVela",Vector3.new(.1,.8,.8),CFrame.new(x,2.99,z)*CFrame.Angles(0,0,math.pi/2),ouro,Enum.Material.Metal,Enum.PartType.Cylinder)
		p("Vela",Vector3.new(.3,1,.3),CFrame.new(x,3.5,z),Color3.fromRGB(229,211,171),Enum.Material.SmoothPlastic)
		local chama=p("ChamaVela",Vector3.new(.16,.28,.16),CFrame.new(x,4.13,z),Color3.fromRGB(255,187,91),Enum.Material.Neon,Enum.PartType.Ball)
		local luz=Instance.new("PointLight");luz.Color=chama.Color;luz.Brightness=.5;luz.Range=13;luz.Parent=chama
	end end
end
return D
