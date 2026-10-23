-- Arena e avisos locais, dirigidos pelo snapshot. Nunca causam dano.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Protocol = require(RS.Shared.MesaProtocol)
local Estilo = require(RS.Shared.Estilo)
local FX = require(script.Parent.MenuEfeitos)
local ChefeView = {}
function ChefeView.start(state)
	local arena, marcas, avisoId, chefeId
	local tweens = {}
	local function part(parent,nome,pos,size,cor,transparencia)
		local p=Instance.new("Part")
		p.Name=nome; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
		p.Position=pos; p.Size=size; p.Color=cor; p.Material=Enum.Material.Neon; p.Transparency=transparencia or 0
		p.Parent=parent; return p
	end
	local function limparMarcas()
		for _,t in tweens do t:Cancel() end; table.clear(tweens)
		if marcas then marcas:Destroy(); marcas=nil end
		avisoId=nil
	end
	local function limpar()
		limparMarcas()
		if arena then arena:Destroy(); arena=nil end
		chefeId=nil
	end
	local gui=Instance.new("ScreenGui")
	gui.Name="EntradaChefe"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=8
	gui.Parent=game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local letreiro=Instance.new("TextLabel")
	letreiro.Name="Letreiro"; letreiro.AnchorPoint=Vector2.new(.5,.5); letreiro.Position=UDim2.fromScale(.5,.4)
	letreiro.Size=UDim2.new(.9,0,0,96); letreiro.BackgroundColor3=Estilo.PAPEL; letreiro.BackgroundTransparency=.15
	letreiro.TextColor3=Estilo.ALERTA; letreiro.FontFace=Estilo.CORPO; letreiro.TextSize=28; letreiro.TextWrapped=true
	letreiro.Visible=false; letreiro.Parent=gui
	local limite=Instance.new("UISizeConstraint"); limite.MaxSize=Vector2.new(580,96); limite.Parent=letreiro
	local versao=0
	state.onSnapshot(function(s)
		if state.snapshot and state.snapshot() ~= s then return end
		local chefe=s.combat.active and s.encontro and s.encontro.chefe
		if not chefe then
			limpar(); versao+=1; letreiro.Visible=false; return
		end
		if chefeId~=chefe.id then
			limpar(); chefeId=chefe.id; versao+=1
			local atual=versao
			arena=Instance.new("Folder"); arena.Name="ArenaTreant"; arena.Parent=workspace
			local board=Protocol.BOARD
			part(arena,"Bosque",board.origin+Vector3.new(0,.07,0),Vector3.new(board.width*board.cell,.08,board.height*board.cell),Color3.fromRGB(23,62,43),.7)
			for i=0,11 do
				local ang=i*math.pi/6
				local pos=board.origin+Vector3.new(math.cos(ang)*76,10,math.sin(ang)*76)
				local coluna=part(arena,"Pilar",pos,Vector3.new(3,20,3),Color3.fromRGB(63,103,65),.25)
				local luz=Instance.new("PointLight"); luz.Color=Color3.fromRGB(112,220,138); luz.Range=36; luz.Brightness=1.4; luz.Parent=coluna
				part(arena,"Copa",pos+Vector3.new(0,13,0),Vector3.new(12,3,12),Color3.fromRGB(35,80,50),.1)
			end
			letreiro.Text="NÍVEL 3\n"..chefe.nome; letreiro.TextTransparency=0; letreiro.Visible=true
			task.delay(3,function()
				if atual~=versao then return end
				if not FX.reduzidos then TweenService:Create(letreiro,TweenInfo.new(.5),{TextTransparency=1}):Play() end
				task.delay(.5,function() if atual==versao then letreiro.Visible=false end end)
			end)
		end
		local aviso=chefe.aviso
		if not aviso then limparMarcas(); return end
		if avisoId==aviso.id then return end
		limparMarcas(); avisoId=aviso.id
		marcas=Instance.new("Folder"); marcas.Name="AreaChefe"; marcas.Parent=arena
		for _,c in aviso.casas do
			local p=part(marcas,"Aviso",Protocol.cellCenter(c[1],c[2])+Vector3.new(0,.18,0),Vector3.new(4.5,.12,4.5),Estilo.ALERTA,.35)
			if not FX.reduzidos then
				local t=TweenService:Create(p,TweenInfo.new(.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.7})
				table.insert(tweens,t); t:Play()
			end
		end
	end)
	RS:WaitForChild(Protocol.REMOTE).OnClientEvent:Connect(function(tipo,d)
		if tipo~="chefeEfeito" or not arena or d.id~=chefeId or not d.agiu then return end
		-- O dano só é confirmado pelos recibos do motor. Este efeito é cenário.
		for _,c in d.aviso.casas do
			local p=part(arena,"Raiz",Protocol.cellCenter(c[1],c[2])+Vector3.new(0,.2,0),Vector3.new(.7,.4,.7),Color3.fromRGB(119,190,95),.1)
			if not FX.reduzidos then TweenService:Create(p,TweenInfo.new(.65),{Size=Vector3.new(1,6,1),Position=p.Position+Vector3.new(0,3,0),Transparency=1}):Play() end
			Debris:AddItem(p,.8)
		end
	end)
	return { limpar=limpar }
end
return ChefeView
