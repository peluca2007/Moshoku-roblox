-- A19: o contorno vem de um gesto real; botões escolhem somente as runas.
-- O reconhecimento é apresentação. O servidor revalida a intenção inteira.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local F = require(Shared.Regras.Formulas)
local Estilo = require(Shared.Estilo)
local View = {}
local abrir
local function new(class,parent,props)
	local o=Instance.new(class); for k,v in props do o[k]=v end; o.Parent=parent; return o
end
function View.open(tokenId) if abrir then abrir(tokenId) end end
function View.start(state)
	local gui=new("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),{Name="FormulaView",ResetOnSpawn=false,DisplayOrder=35,IgnoreGuiInset=true})
	local fundo=new("Frame",gui,{Name="Fundo",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.3,Visible=false,Active=true})
	local painel=new("ScrollingFrame",fundo,{Name="Painel",Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),Size=UDim2.new(.94,0,.94,0),BackgroundColor3=Estilo.PAPEL,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
	new("UISizeConstraint",painel,{MaxSize=Vector2.new(560,720)})
	new("UICorner",painel,{CornerRadius=UDim.new(0,10)})
	new("UIPadding",painel,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)})
	new("UIListLayout",painel,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
	local function label(nome,txt,h,ordem)
		return new("TextLabel",painel,{Name=nome,Text=txt,Size=UDim2.new(1,-8,0,h),BackgroundTransparency=1,TextColor3=Estilo.TINTA,TextSize=15,FontFace=Estilo.ROTULO,TextWrapped=true,LayoutOrder=ordem})
	end
	label("Titulo","ALFABETO ARCANO · DESENHAR FÓRMULA",30,1)
	label("Instrucao","Trace um círculo, uma linha ou um quadrado com o mouse ou dedo. Escolha as runas; confira o custo e o alvo.",42,2)
	local function button(parent,nome,txt,callback)
		local b=new("TextButton",parent,{Name=nome,Text=txt,Size=UDim2.fromOffset(110,32),BackgroundColor3=Estilo.PAPEL_2,TextColor3=Estilo.TINTA,FontFace=Estilo.ROTULO_FORTE,TextSize=14,TextWrapped=true})
		new("UICorner",b,{CornerRadius=UDim.new(0,5)}); b.Activated:Connect(callback); return b
	end
	local tokenId,ficha,essencia,verbo,potencia,forma,qualidade,meio,alvoId
	local pontos,segmentos={},{}
	local atualiza
	local function row(nome,altura,ordem)
		return new("Frame",painel,{Name=nome,Size=UDim2.new(1,-8,0,altura),BackgroundTransparency=1,LayoutOrder=ordem})
	end
	local erow=row("Essencias",70,3)
	new("UIGridLayout",erow,{CellSize=UDim2.new(.25,-4,0,32),CellPadding=UDim2.fromOffset(4,4),SortOrder=Enum.SortOrder.LayoutOrder})
	local eb={}
	for i,id in {"mana","fogo","agua","vento","terra","som","vida"} do
		eb[id]=button(erow,id,F.ESSENCIAS[id].glifo.." "..F.ESSENCIAS[id].nome,function() essencia=id; atualiza() end); eb[id].LayoutOrder=i
	end
	local vrow=row("Verbos",36,4)
	new("UIGridLayout",vrow,{CellSize=UDim2.new(.25,-4,0,32),CellPadding=UDim2.fromOffset(4,4)})
	local vb={}
	for _,id in {"lancar","erguer","selar","sinalizar"} do vb[id]=button(vrow,id,F.VERBOS[id],function() verbo=id; atualiza() end) end
	local prow=row("Potencia",36,5)
	local pb=button(prow,"Rank","Potência",function()
		local rank=F.rank(ficha); if not rank then return end
		local max=table.find(F.RANKS,rank) or 1
		potencia=F.RANKS[(table.find(F.RANKS,potencia) or 1)%max+1]; atualiza()
	end); pb.Size=UDim2.new(.55,-4,1,0)
	local mb=button(prow,"Meio","No ar",function() meio=if meio=="ar" then "giz" elseif meio=="giz" then "bolso" else "ar"; atualiza() end)
	mb.Position=UDim2.fromScale(.55,0); mb.Size=UDim2.new(.45,-4,1,0)
	local quadro=new("Frame",painel,{Name="Quadro",Size=UDim2.new(1,-8,0,215),BackgroundColor3=Color3.fromRGB(15,25,34),BorderSizePixel=0,Active=true,ClipsDescendants=true,LayoutOrder=6})
	local ajuda=new("TextLabel",quadro,{Name="Ajuda",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="Desenhe aqui",TextColor3=Estilo.TINTA_SUAVE,TextSize=22,FontFace=Estilo.ROTULO})
	local reconhecimento=label("Reconhecimento","Forma: aguardando traço",24,7)
	local custo=label("Custo","",38,8)
	local efeito=label("Efeito","",72,9)
	local arow=row("Alvo",36,10)
	local escolher=button(arow,"EscolherAlvo","Alvo",function()
		local snap=state.snapshot(); local lista={}
		for _,t in (snap and snap.tokens) or {} do if t.pv and t.pvMax then table.insert(lista,t) end end
		local i=0; for n,t in lista do if t.id==alvoId then i=n end end
		if #lista>0 then alvoId=lista[i%#lista+1].id end; atualiza()
	end); escolher.Size=UDim2.new(.5,-4,1,0)
	local function campo(nome,pos)
		return new("TextBox",arow,{Name=nome,PlaceholderText=nome,Text="",Position=UDim2.fromScale(pos,0),Size=UDim2.new(.25,-4,1,0),BackgroundColor3=Estilo.PAPEL_2,TextColor3=Estilo.TINTA,TextSize=15,FontFace=Estilo.ROTULO,ClearTextOnFocus=false})
	end
	local x,z=campo("X",.5),campo("Z",.75)
	local crow=row("Comandos",36,11)
	new("UIGridLayout",crow,{CellSize=UDim2.new(.333,-4,0,32),CellPadding=UDim2.fromOffset(4,4)})
	local confirmar
	local function limpar()
		for _,o in segmentos do o:Destroy() end; table.clear(segmentos); table.clear(pontos)
		forma,qualidade=nil,nil; ajuda.Visible=true; atualiza()
	end
	confirmar=button(crow,"Confirmar","Confirmar",function()
		if not ficha or not forma then return end
		local r=F.validar(ficha,{essencia=essencia,verbo=verbo,forma=forma,potencia=potencia},meio)
		if not r then return end
		local payload={tokenId=tokenId,essencia=essencia,verbo=verbo,forma=forma,potencia=potencia,qualidade=qualidade}
		if meio=="ar" then
			if verbo=="lancar" then payload.alvoId=alvoId
			else payload.x,payload.z=tonumber(x.Text),tonumber(z.Text) end
			state.send("desenharFormula",payload)
		else payload.meio=meio; state.send("prepararFormula",payload) end
		fundo.Visible=false
	end)
	button(crow,"Limpar","Limpar traço",limpar)
	button(crow,"Fechar","Fechar",function() fundo.Visible=false end)
	local brow=row("Preparadas",36,12)
	new("UIGridLayout",brow,{CellSize=UDim2.new(.5,-4,0,32),CellPadding=UDim2.fromOffset(4,4)})
	button(brow,"Ativar","Ativar preparada",function()
		state.send("ativarFormula",{tokenId=tokenId,x=tonumber(x.Text),z=tonumber(z.Text),alvoId=alvoId}); fundo.Visible=false
	end)
	button(brow,"Continuar","Continuar desenho",function() state.send("continuarFormula",{tokenId=tokenId}); fundo.Visible=false end)
	local cr=row("Interrupcao",36,13)
	button(cr,"Cancelar","Cancelar desenho",function() state.send("cancelarFormula",{tokenId=tokenId}); fundo.Visible=false end).Size=UDim2.new(1,-8,1,0)
	atualiza=function()
		for id,b in eb do b.BackgroundTransparency=if F.conheceEssencia(ficha,id) then 0 else .65; b.BackgroundColor3=if id==essencia then Estilo.DESTAQUE_FUNDO else Estilo.PAPEL_2 end
		for id,b in vb do b.BackgroundColor3=if id==verbo then Estilo.DESTAQUE_FUNDO else Estilo.PAPEL_2 end
		pb.Text="Potência: "..(potencia or "Principiante")
		mb.Text=if meio=="giz" then "Giz · 1 minuto" elseif meio=="bolso" then "Bolso · 1 minuto" else "No ar"
		reconhecimento.Text=if forma then "Forma: "..F.FORMAS[forma].." · precisão visual "..math.floor((qualidade or 0)*100).."%" else "Forma: aguardando traço válido"
		local r,err=F.validar(ficha,{essencia=essencia,verbo=verbo,forma=forma or "circulo",potencia=potencia},meio)
		custo.Text=if r then string.format("%d PM · %d Ações%s",r.pm,r.acoes,if r.preparoSegundos>0 then " · preparo 60 s fora de combate" else " · desenhar no ar") else err or "Carregando ficha…"
		efeito.Text=if r then r.descricao else ""
		confirmar.Active=forma~=nil and r~=nil
		confirmar.BackgroundTransparency=if confirmar.Active then 0 else .6
		local alvo=state.findToken(alvoId); escolher.Text=if alvo then "Alvo: "..alvo.name else "Escolher alvo"
	end
	local capturando=nil
	local function ponto(pos)
		local p=Vector2.new(pos.X,pos.Y)-quadro.AbsolutePosition
		p=Vector2.new(math.clamp(p.X,0,quadro.AbsoluteSize.X),math.clamp(p.Y,0,quadro.AbsoluteSize.Y))
		local anterior=pontos[#pontos]
		if anterior and (p-Vector2.new(anterior[1],anterior[2])).Magnitude<2 then return end
		if #pontos>=500 then return end
		table.insert(pontos,{p.X,p.Y}); ajuda.Visible=false
		if anterior then
			local a=Vector2.new(anterior[1],anterior[2]); local delta=p-a
			table.insert(segmentos,new("Frame",quadro,{Name="Traco",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((p.X+a.X)/2,(p.Y+a.Y)/2),Size=UDim2.fromOffset(delta.Magnitude,3),Rotation=math.deg(math.atan2(delta.Y,delta.X)),BackgroundColor3=Estilo.CAPITULOS[2],BorderSizePixel=0}))
		end
	end
	quadro.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			limpar(); capturando=input; ponto(input.Position)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if fundo.Visible and capturando and (input==capturando or input.UserInputType==Enum.UserInputType.MouseMovement and capturando.UserInputType==Enum.UserInputType.MouseButton1) then ponto(input.Position) end
	end)
	UIS.InputEnded:Connect(function(input)
		if capturando and (input==capturando or input.UserInputType==Enum.UserInputType.MouseButton1 and capturando.UserInputType==Enum.UserInputType.MouseButton1) then
			ponto(input.Position); capturando=nil; forma,qualidade=F.reconhecer(pontos); atualiza()
		end
	end)
	abrir=function(id)
		local token=state.findToken(id); if not token or not state.canControl(token) then return end
		capturando=nil
		tokenId=id; ficha=state.fichaDetalhe(id); essencia,verbo,potencia,meio="mana","lancar","Principiante","ar"
		alvoId=nil; x.Text,z.Text=tostring(token.x),tostring(token.z); fundo.Visible=true; painel.CanvasPosition=Vector2.zero; limpar()
	end
	state.onFichaDetalhe(function(id,f) if id==tokenId then ficha=f; atualiza() end end)
	state.onSnapshot(function() if fundo.Visible and not state.findToken(tokenId) then fundo.Visible=false end end)
	local preparar=button(gui,"AbrirFormula","Fórmula · preparar",function() local id=state.selectedToken(); if id then View.open(id) end end)
	preparar.AnchorPoint=Vector2.new(1,0); preparar.Position=UDim2.new(1,-14,0,112); preparar.Size=UDim2.fromOffset(155,32); preparar.Visible=false
	local function selecao()
		local token=state.findToken(state.selectedToken())
		preparar.Visible=token~=nil and state.canControl(token) and table.find(token.habilidades or {},"mesa/desenhar-formula")~=nil
	end
	state.onSelection(selecao); state.onSnapshot(selecao)
end
return View
