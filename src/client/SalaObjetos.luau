-- Papel e dados procedurais; nenhuma autoridade de ficha/rolagem.
local O={}
local P=require(game.ReplicatedStorage.Shared.PapelSolto)
function O.visivel(p,v)
	p.Transparency=if v then 0 else 1;p.CanQuery=v
	for _,g in p:GetChildren() do if g:IsA("SurfaceGui") then g.Enabled=v end end
end
function O.peca(parent,nome,size,cf,cor)
	local p=Instance.new("Part");p.Name=nome;p.Size=size;p.CFrame=cf;p.Color=cor;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CastShadow=true;p.Parent=parent;return p
end
function O.superficie(p,face,w,h)
	local g=Instance.new("SurfaceGui");g.Name="Impressao";g.Face=face or Enum.NormalId.Front;g.CanvasSize=Vector2.new(w or 650,h or 900);g.LightInfluence=0;g.Active=true;g.Parent=p;return g
end
function O.texto(g,text,pos,size,tamanho,cor)
	local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Position=pos;l.Size=size;l.Text=text;l.TextWrapped=true;l.TextColor3=cor or Color3.fromRGB(52,40,32);l.TextSize=tamanho or 28;l.Font=Enum.Font.Garamond;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Top;l.Parent=g;return l
end
function O.papel(parent,nome,cf)
	local p=O.peca(parent,nome,Vector3.new(2.3,3.2,.025),cf,Color3.fromRGB(239,225,190));p.Material=Enum.Material.SmoothPlastic
	local g=O.superficie(p)
	local verso=O.superficie(p,Enum.NormalId.Back)
	O.texto(verso,"MOSHOKU\n\nCRÔNICAS DE UMA NOVA VIDA",UDim2.fromScale(.1,.15),UDim2.fromScale(.8,.5),50)
	for _,gui in {g,verso} do
		local borda=Instance.new("Frame");borda.Name="MolduraPapel";borda.Size=UDim2.fromScale(.94,.96);borda.Position=UDim2.fromScale(.03,.02);borda.BackgroundTransparency=1;borda.BorderColor3=Color3.fromRGB(164,134,86);borda.BorderSizePixel=2;borda.Parent=gui
	end
	return p,g
end
function O.dados(pasta)
 local visual=require(game.ReplicatedStorage.Shared.DadoVisual);local dados={}
 for i=1,3 do
  local p=visual.criar(pasta,i);p.Name="BrotosDado"..i;p.Size=Vector3.one*.65;p.CFrame=CFrame.new(249+i*.8,3.95,-6);p.CanQuery=true;p:SetAttribute("SalaObjeto","dados")
  local l=O.texto(p.Face1,"1",UDim2.new(),UDim2.fromScale(1,1),1);l.Visible=false
  dados[i]={part=p,label=l,base=p.CFrame,rotacao=visual.rotacao}
 end
 return dados
end
function O.soltos(pasta)
	local ativos={};local api={}
	function api.atualizar(lista,visivel)
		local presentes={}
		for _,d in lista or {} do
			presentes[d.objeto]=true
			local o=ativos[d.objeto]
			if not o then
				local p,g=O.papel(pasta,"PapelSolto_"..d.objeto,CFrame.new(250,-10,0))
				p:SetAttribute("SalaObjeto","ficha");p:SetAttribute("FichaId",d.id);p:SetAttribute("PapelObjeto",d.objeto)
				local livro=require(game.ReplicatedStorage.Shared.SalaItens).livros[d.id]
				if livro then p.Size=Vector3.new(1.65,2.3,.24);p.Color=Color3.fromRGB(unpack(livro.cor));p.Material=Enum.Material.SmoothPlastic;p:SetAttribute("SalaObjeto","livro");p:SetAttribute("ObjetoId",d.id) end
				local f;for _,c in require(game.ReplicatedStorage.Shared.PersonagensProntos) do if c.id==d.id then f=c;break end end
				O.texto(g,if livro then livro.nome else f and f.nome or "Ficha",UDim2.fromScale(.07,.08),UDim2.fromScale(.86,.6),62,if livro then Color3.fromRGB(245,224,180) else nil)
				O.texto(g,"Clique e segure • pegar",UDim2.fromScale(.07,.73),UDim2.fromScale(.86,.2),28)
				o={part=p,gui=g,d=d};ativos[d.objeto]=o
			end
			O.visivel(o.part,visivel)
		end
		for id,o in ativos do if not presentes[id] then o.part:Destroy();ativos[id]=nil end end
	end
	function api.animar(agora)
		for id,o in ativos do
			local pos,t,pousou=P.posicao(o.d,agora)
			if agora-o.d.inicio>45 then o.part:Destroy();ativos[id]=nil;continue end
			local flutter=if pousou then 0 else math.sin(t*13+id)*.35
			o.part.CFrame=CFrame.new(pos.x,pos.y,pos.z)*CFrame.Angles(math.pi/2+flutter,0,id*.7+t*2)
		end
	end
	return api
end
return O
