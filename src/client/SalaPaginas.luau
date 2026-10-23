-- Páginas nos objetos de papel, separadas da câmera e das regras da sala.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local P=require(RS.Shared.PersonagensProntos)
local O=require(script.Parent.SalaObjetos)
local Livros=require(RS.Shared.SalaItens).livros
local Leitura=require(RS.Shared.SalaLeitura)
local Consulta=require(RS.Shared.SalaConsultaLayout)
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Som=require(script.Parent.Sonorizacao)
local FX=require(script.Parent.MenuEfeitos)
local V={}
function V.start(pasta,state,entrada)
	entrada=entrada or UIS
	local part,g=O.papel(pasta,"PapelEmMaos",CFrame.new(250,-10,0))
	-- Roblox exige SurfaceGui no PlayerGui para receber cliques dos controles.
	g.Name="SalaPapelInterface";g.Adornee=part;g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;g.AlwaysOnTop=false;g.ResetOnSpawn=false;g.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
	local alca=Instance.new("TextLabel");alca.Name="CabecalhoPapel";alca.Text="";alca.BackgroundTransparency=1;alca.Size=UDim2.new(1,0,0,78);alca.Parent=g
	local scroll=Instance.new("ScrollingFrame");scroll.Name="Pagina";scroll.Position=UDim2.fromOffset(0,80);scroll.Size=UDim2.new(1,0,1,-156);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=7;scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.CanvasSize=UDim2.new();scroll.Parent=g
	local guardar=Instance.new("TextButton");guardar.Name="GuardarPapel";guardar.Text="FECHAR • Q / B DO CONTROLE";guardar.Font=Enum.Font.Garamond;guardar.TextSize=24;guardar.TextColor3=Color3.fromRGB(74,51,32);guardar.BackgroundColor3=Color3.fromRGB(216,194,151);guardar.BorderSizePixel=0;guardar.Position=UDim2.new(0,0,1,-74);guardar.Size=UDim2.new(1,0,0,74);guardar.Parent=g
	local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,35);pad.PaddingRight=UDim.new(0,35);pad.PaddingTop=UDim.new(0,32);pad.PaddingBottom=UDim.new(0,32);pad.Parent=scroll
	scroll.BackgroundTransparency=0;scroll.BackgroundColor3=Color3.fromRGB(239,225,190)
	local layout=Instance.new("UIListLayout");layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Padding=UDim.new(0,12);layout.Parent=scroll
	local aberto,tipo,indice,pagina,arma=false,"ficha",1,1,1
	local snap,ordem,virada=nil,0,0
	local linhasPlacar={"Ainda não houve uma rodada."};local objetoId=nil;local inspecionando=false;local controles;local aba="sessao";local assinatura=nil;local pendente=false;local esperaAte=0;local gesto;local entregando=false;local pedidoMao=nil;local pedidoAte=0
	local api={part=part,gui=g};local sentadoAnterior=nil;local transferencia={};local focoSerial=0
	local function consulta() return tipo~="ficha" and tipo~="livro" end
	local function sentado()
		local char=Players.LocalPlayer.Character;local h=char and char:FindFirstChildOfClass("Humanoid")
		return h~=nil and h.SeatPart~=nil and h.SeatPart:GetAttribute("LugarSala")~=nil
	end
	local function revelar(b)
		if b:IsDescendantOf(scroll) then
			local y=b.AbsolutePosition.Y-scroll.AbsolutePosition.Y
			if y<0 then scroll.CanvasPosition+=Vector2.new(0,y) elseif y+b.AbsoluteSize.Y>scroll.AbsoluteSize.Y then scroll.CanvasPosition+=Vector2.new(0,y+b.AbsoluteSize.Y-scroll.AbsoluteSize.Y) end
		end
	end
	local function focar(nome)
		if not aberto or not consulta() then return end
		local b=nome and g:FindFirstChild(nome,true)
		if not b or not b:IsA("TextButton") or not b.Interactable or not b.Visible then
			b=nil;for _,c in scroll:GetDescendants() do if c:IsA("TextButton") and c.Interactable and c.Visible then b=c;break end end
		end
		if not b then b=guardar end
		revelar(b)
		-- O motor recusa seleção recortada. Primeiro rola e espera o layout assentar.
		focoSerial+=1;local serial=focoSerial
		local anterior=Gui.SelectedObject
		local function valido() return serial==focoSerial and aberto and consulta() and g.Enabled and b:IsDescendantOf(g) and b.Interactable and b.Visible end
		task.defer(function()
			Run.RenderStepped:Wait()
			if not valido() or Gui.SelectedObject and Gui.SelectedObject~=anterior and Gui.SelectedObject~=b then return end
			Gui.SelectedObject=b
			Run.RenderStepped:Wait()
			-- A entrada inicial de SurfaceGui pode ser recusada enquanto o motor atualiza
			-- a navegação. Uma única repetição; nunca disputa uma escolha nova do jogador.
			if valido() and Gui.SelectedObject==nil then
				revelar(b);Run.RenderStepped:Wait()
				if valido() and Gui.SelectedObject==nil then Gui.SelectedObject=b end
			end
		end)
	end
	local function texto(t,tam)
		ordem+=1;local l=O.texto(scroll,t,UDim2.new(),UDim2.new(1,-8,0,0),if consulta() then Consulta.texto(tam or 30) else tam or 30);l.ZIndex=2;l.AutomaticSize=Enum.AutomaticSize.Y;l.LayoutOrder=ordem;return l
	end
	local function botao(nome,t,fn)
		ordem+=1;local b=Instance.new("TextButton");b.Name=nome;b.ZIndex=2;b.Text=t;b.Font=Enum.Font.Garamond;b.TextSize=18;b.TextWrapped=true;b.AutomaticSize=Enum.AutomaticSize.Y;b.TextColor3=Color3.fromRGB(67,44,31);b.BackgroundColor3=Color3.fromRGB(211,192,149);b.BackgroundTransparency=.3;b.BorderSizePixel=0;b.Size=UDim2.new(1,-8,0,52);b.LayoutOrder=ordem;b.Parent=scroll;b.Activated:Connect(fn)
		local pad=Instance.new("UIPadding");pad.PaddingTop=UDim.new(0,8);pad.PaddingBottom=UDim.new(0,8);pad.PaddingLeft=UDim.new(0,10);pad.PaddingRight=UDim.new(0,10);pad.Parent=b;return b
	end
	local function abas(lista,mudar)
		ordem+=1;local linha=Instance.new("Frame");linha.Name="Abas";linha.LayoutOrder=ordem;linha.Size=UDim2.new(1,-8,0,52);linha.BackgroundTransparency=1;linha.Parent=scroll
		for i,a in lista do
			local b=Instance.new("TextButton");b.Name="Aba_"..a[1];b.Text=a[2];b.Font=Enum.Font.Garamond;b.TextSize=18;b.TextWrapped=true;b.Size=UDim2.new(1/#lista,-4,1,0);b.Position=UDim2.new((i-1)/#lista,0,0,0);b.BorderSizePixel=0;b.BackgroundColor3=if aba==a[1] then Color3.fromRGB(66,90,70) else Color3.fromRGB(215,197,159);b.TextColor3=if aba==a[1] then Color3.fromRGB(255,244,219) else Color3.fromRGB(67,44,31);b.Parent=linha;b.Activated:Connect(function() mudar(a[1]) end)
		end
	end
	local render
	local function mudar(i)
		indice=(i-1)%#P+1;pagina=1;arma=1;virada=os.clock();pedidoMao=P[indice].id;pedidoAte=os.clock()+2;state.send("salaPapel",{id=pedidoMao});render()
	end
	local function fechar(liberar)
		focoSerial+=1
		local sala=snap and snap.salaConceitual;local mao=sala and (sala.maos[Players.LocalPlayer.UserId] or sala.maos[tostring(Players.LocalPlayer.UserId)])
		local representa=pedidoMao~=nil or (tipo=="ficha" or tipo=="entregar") and (mao==nil or mao==P[indice].id) or objetoId~=nil and (mao==nil or mao==objetoId)
		local selecionado=game:GetService("GuiService").SelectedObject;if selecionado and selecionado:IsDescendantOf(g) then game:GetService("GuiService").SelectedObject=nil end
		aberto=false;pendente=false;entregando=false;pedidoMao=nil;if controles then controles.visivel(false) end;O.visivel(part,false);g.Enabled=false;if gesto then gesto.reset() end
		if liberar~=false then
			if representa then state.send("salaPapel",{id=false})
			elseif mao and sala and not sala.transicao and not snap.combat.active then
				-- Fechar uma consulta não descarta a ficha recebida enquanto ela estava aberta.
				for _,f in P do if f.id==mao then api.abrir("ficha",mao,nil,true);break end end
				if Livros[mao] then api.abrir("livro",mao,nil,true) end
			end
		end
	end
	guardar.Activated:Connect(function() fechar() end)
	local function arremessar(d,forca,soltar)
		if not aberto or (tipo~="ficha" and tipo~="livro" and tipo~="entregar" and not objetoId) or pendente then return false end
		pendente=true;esperaAte=os.clock()+2
		state.send("salaArremessar",{id=objetoId or P[indice].id,direcao={x=d.X,y=d.Y,z=d.Z},forca=forca,soltar=soltar==true});return true
	end
	function api.lancar(forca,soltar)
		if not aberto or (tipo~="ficha" and tipo~="livro" and tipo~="entregar" and not objetoId) then
			local sala=snap and snap.salaConceitual;local mao=sala and (sala.maos[Players.LocalPlayer.UserId] or sala.maos[tostring(Players.LocalPlayer.UserId)])
			local ficha=false;for _,f in P do if f.id==mao then ficha=true;break end end
			if ficha then api.abrir("ficha",mao,nil,true) elseif Livros[mao] then api.abrir("livro",mao,nil,true) else return false end
		end
		return arremessar(workspace.CurrentCamera.CFrame.LookVector,forca,soltar)
	end
	gesto=require(script.Parent.SalaPapelGesto).new(alca,function() return aberto and (tipo=="ficha" or tipo=="livro") and not pendente end,arremessar,function() inspecionando=not inspecionando;render() end)
	render=function()
		local pos=scroll.CanvasPosition
		local selecionado=Gui.SelectedObject;local focoAnterior=selecionado and selecionado:IsDescendantOf(g) and selecionado.Name
		for _,c in scroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end;ordem=0
		if not aberto then return end
		alca.Visible=false
		guardar.Visible=tipo~="ficha" and tipo~="livro";scroll.ScrollingEnabled=tipo~="ficha" and tipo~="livro";scroll.ScrollBarThickness=if tipo=="ficha" or tipo=="livro" then 0 else 7
		scroll.BackgroundTransparency=if tipo=="ficha" or tipo=="livro" then 1 else 0
		scroll.Position=UDim2.new();scroll.Size=UDim2.new(1,0,1,if tipo=="ficha" or tipo=="livro" then 0 else -76)
		if consulta() then
			guardar.Position=UDim2.new(0,0,1,-52);guardar.Size=UDim2.new(1,0,0,52);guardar.TextSize=17
			scroll.Size=UDim2.new(1,0,1,-54);pad.PaddingLeft=UDim.new(0,16);pad.PaddingRight=UDim.new(0,16);pad.PaddingTop=UDim.new(0,12);pad.PaddingBottom=UDim.new(0,12);layout.Padding=UDim.new(0,8)
		else
			g.CanvasSize=Vector2.new(650,900)
			pad.PaddingLeft=UDim.new(0,35);pad.PaddingRight=UDim.new(0,35);pad.PaddingTop=UDim.new(0,32);pad.PaddingBottom=UDim.new(0,32);layout.Padding=UDim.new(0,12)
		end
		local sala=snap and snap.salaConceitual;local master=sala and sala.mestre==Players.LocalPlayer.UserId
		if tipo=="ficha" then
			local eu;for _,p in sala and sala.pessoas or {} do if p.id==Players.LocalPlayer.UserId then eu=p end end
			require(script.Parent.SalaFichaImpressao).render(texto,P[indice],pagina,arma,eu,sala)
			if controles then controles.status(eu and eu.ficha==P[indice].id,inspecionando) end

		elseif tipo=="livro" then
			local livro=Livros[objetoId];texto("MOSHOKU",42);texto(livro.nome,58);texto("Mantenha a pegada para segurar.\nArremesse ou abra para consultar.",29)
			for _,c in scroll:GetChildren() do if c:IsA("TextLabel") then c.TextColor3=Color3.fromRGB(242,224,181) end end
			controles.status(false,inspecionando,true)
		elseif tipo=="mestre" then
			if sala then require(script.Parent.SalaPreparacaoView).render({texto=texto,botao=botao,abas=abas,sentado=sentado(),transferencia=transferencia,atualizar=render},sala,state,aba,function(a) aba=a;scroll.CanvasPosition=Vector2.zero;render() end) end
		elseif tipo=="entregar" then
			texto(if entregando then "Entregando a ficha…" else "Passar a ficha",42)
			texto("Aproxime-se de alguém com as mãos livres. A ficha continua com você se a entrega não puder ser feita.",25)
			local n=0
			for _,p in sala and sala.pessoas or {} do if p.admitido and p.id~=Players.LocalPlayer.UserId then
				n+=1;local ocupada=sala.maos[p.id] or sala.maos[tostring(p.id)]
				local b=botao("Entregar_"..p.id,p.nome..(if ocupada then " • mãos ocupadas" else " • entregar"),function()
					if entregando or ocupada then return end
					entregando=true;pendente=true;esperaAte=os.clock()+3;state.send("salaPapel",{id=P[indice].id,para=p.id});render()
				end);b.Interactable=not ocupada and not entregando;b.AutoButtonColor=b.Interactable;b.TextTransparency=if b.Interactable then 0 else .35
			end end
			if n==0 then texto("Não há outro jogador na sala.",28) end
			botao("VoltarFicha","Continuar com a ficha",function() tipo="ficha";inspecionando=false;scroll.CanvasPosition=Vector2.zero;controles.visivel(true);render() end)

		elseif tipo=="placar" then
			for i,l in linhasPlacar do texto(l,if i==1 then 42 else 29) end
		elseif tipo=="ajustes" then
			texto("Caderno de ajustes",45)
			botao("Volume","Volume: "..math.floor(Som.volume()*100).."%",function() Som.volume((math.floor(Som.volume()*4+.5)+1)%5/4);render() end)
			botao("Animacoes","Animações: "..(if FX.reduzidos then "reduzidas" else "completas"),function() FX.reduzir(not FX.reduzidos);render() end)
			texto("Use salto para levantar da cadeira.\nClique, RT ou toque mantido para pegar.\nSolte a pegada para largar. F ou X do controle arremessa.")
		end
		task.defer(function()
			if scroll.Parent then
				scroll.CanvasPosition=pos
				if focoAnterior or entrada:GetLastInputType()==Enum.UserInputType.Gamepad1 then focar(focoAnterior) end
			end
		end)
	end
	function api.abrir(t,id,objeto,confirmado)
		focoSerial+=1
		if t=="mestre" then aba="sessao" end
		table.clear(transferencia)
		tipo=t;objetoId=if t=="livro" then id else nil;aberto=true;inspecionando=false;pendente=false;entregando=false;pedidoMao=nil;O.visivel(part,true);g.Enabled=true;pagina=1;arma=1;gesto.reset();scroll.CanvasPosition=Vector2.zero
		controles.visivel(t=="ficha" or t=="livro")
		part.Size=if t=="mestre" then Vector3.new(4.1,3.2,.025) elseif t=="ficha" then Vector3.new(1.65,2.3,.025) elseif t=="livro" then Vector3.new(1.65,2.3,.24) else Vector3.new(2.3,3.2,.025)
		part.Color=if t=="livro" then Color3.fromRGB(unpack(Livros[id].cor)) else Color3.fromRGB(239,225,190)
		part.Material=Enum.Material.SmoothPlastic
		g.CanvasSize=if t=="mestre" then Vector2.new(1100,860) else Vector2.new(650,900)
		guardar.Text="Fechar consulta"
		if id then for i,f in P do if f.id==id then indice=i;break end end end
		if t=="livro" and not confirmado then pedidoMao=id;state.send("salaPapel",{id=id,objeto=objeto}) end
		if t=="ficha" and not confirmado then pedidoMao=P[indice].id;state.send("salaPapel",{id=pedidoMao,objeto=objeto}) end
		if pedidoMao then pedidoAte=os.clock()+2 end
		render()
	end
	local function reconciliar(mao)
		if not aberto or pedidoMao or (tipo~="ficha" and tipo~="livro") then return end
		if mao==(objetoId or P[indice].id) then return end
		fechar(false)
		for _,f in P do if f.id==mao then api.abrir("ficha",mao,nil,true);return end end
		if Livros[mao] then api.abrir("livro",mao,nil,true) end
	end
	function api.atualizar(s)
		if snap and snap.salaConceitual and (not s.salaConceitual or snap.salaConceitual.mestre~=s.salaConceitual.mestre) then table.clear(transferencia) end
		snap=s
		local sala=s.salaConceitual
		local mao=sala and (sala.maos[Players.LocalPlayer.UserId] or sala.maos[tostring(Players.LocalPlayer.UserId)])
		if pedidoMao==mao then pedidoMao=nil end
		reconciliar(mao)
		if aberto and tipo=="entregar" and mao~=P[indice].id then fechar(false) end
		if pendente and sala and not (sala.maos[Players.LocalPlayer.UserId] or sala.maos[tostring(Players.LocalPlayer.UserId)]) then fechar(false) end
		-- Papeis/olhares alheios não reconstroem controles nem interrompem a leitura.
		local campos={sala and sala.mestre,sala and sala.modo,sala and sala.nivel,sala and sala.monstros,sala and sala.pessoas,sala and sala.copias,sala and sala.eleicao,sala and sala.transicao,sala and sala.brincadeiraBrotos,if tipo=="entregar" then sala and sala.maos else nil}
		local chave=game:GetService("HttpService"):JSONEncode(campos)
		if chave~=assinatura then assinatura=chave;if aberto then render() end end
	end
	function api.placar(linhas) linhasPlacar=linhas;if aberto and tipo=="placar" then render() end end
	function api.assumir()
		if aberto and tipo=="ficha" then local f=P[indice];state.send("escolherPersonagem",{id=f.id,arma=f.armas[arma].id}) end
	end
	function api.aberto() return aberto end
	function api.papel() return if aberto and (tipo=="ficha" or tipo=="livro" or tipo=="entregar") then part else nil end
	function api.congelar() return aberto and ((tipo~="ficha" and tipo~="livro") or inspecionando or gesto.arrastando()) end
	function api.dica() return "F / X do controle: arremessar • solte a pegada para largar" end
	function api.fechar(liberar) if aberto then fechar(liberar) end end
	function api.posicionar(camera,dt)
		if pedidoMao and os.clock()>pedidoAte then
			pedidoMao=nil;local sala=snap and snap.salaConceitual;reconciliar(sala and (sala.maos[Players.LocalPlayer.UserId] or sala.maos[tostring(Players.LocalPlayer.UserId)]))
		end
		if not aberto then controles.posicionar(nil);part.CFrame=CFrame.new(250,-10,0);return end
		if tipo=="mestre" and sentadoAnterior~=sentado() then sentadoAnterior=sentado();render() end
		if transferencia.ate and os.clock()>transferencia.ate then table.clear(transferencia);render() end
		if pendente and os.clock()>esperaAte then pendente=false;if entregando then entregando=false;render() end end
		local t=math.clamp((os.clock()-virada)/.25,0,1)
		local aspecto=camera.ViewportSize.X/math.max(camera.ViewportSize.Y,1)
		local cw,ch=Consulta.tamanho(tipo,aspecto)
		local tamanho=if tipo=="ficha" then Vector3.new(1.65,2.3,.025) elseif tipo=="livro" then Vector3.new(1.65,2.3,.24) else Vector3.new(cw,ch,.025)
		local largura=tamanho.X+(if inspecionando and (tipo=="ficha" or tipo=="livro") then .95 else 0)
		local mao=(tipo=="ficha" or tipo=="livro") and not inspecionando
		-- Mantém o tamanho aparente, mas lê perto dos olhos: o escudo e objetos
		-- sobre a mesa não atravessam a página. Nunca altera a cópia no servidor.
		local offset=gesto.offset(dt or 1/60)
		local escala=1;local cf=CFrame.new(.65,-1.1,-1.7)*CFrame.Angles(-.28,-.2,-.15);local centro=CFrame.identity
		if not mao then
			local angulo=math.atan2(offset.RightVector.Y,offset.RightVector.X)
			local r=Leitura.calcular(largura,tamanho.Y,aspecto,camera.FieldOfView,angulo,offset.X,offset.Y,if tipo=="ficha" then 2.1 else 3)
			escala=r.escala;cf=CFrame.new(0,0,-r.distancia);offset=CFrame.new(r.x,r.y,0)*offset.Rotation
			centro=CFrame.new(if tipo=="ficha" or tipo=="livro" then .47*escala else 0,0,0)
		end
		part.Size=tamanho*escala
		part.CFrame=camera.CFrame*cf*offset*centro*CFrame.Angles(0,math.pi+math.sin(t*math.pi)*.18,0)
		if consulta() then
			local a=camera:WorldToViewportPoint(part.CFrame:PointToWorldSpace(Vector3.new(-part.Size.X/2,-part.Size.Y/2,0)))
			local b=camera:WorldToViewportPoint(part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X/2,part.Size.Y/2,0)))
			local w,h=Consulta.canvas(math.abs(a.X-b.X),math.abs(a.Y-b.Y));local canvas=Vector2.new(w,h)
			if (canvas-g.CanvasSize).Magnitude>=8 then g.CanvasSize=canvas;render() end
		end
		controles.posicionar(part)
	end
	local function acionar(acao,forca)
		if not aberto or (tipo~="ficha" and tipo~="livro") or pendente then return end
		local f=P[indice]
		if acao=="Arremessar" then arremessar(workspace.CurrentCamera.CFrame.LookVector,forca or .5)
		elseif acao=="Ler" then
			if tipo=="livro" and objetoId=="livro-ajustes" then tipo="ajustes";inspecionando=true;controles.visivel(false) else inspecionando=not inspecionando end;render()
		elseif tipo=="livro" and acao=="Soltar" then arremessar(workspace.CurrentCamera.CFrame.LookVector,0,true)
		elseif tipo=="livro" then return
		elseif acao=="Folhear" then pagina=pagina%require(script.Parent.SalaFichaImpressao).paginas(f)+1;virada=os.clock();render()
		elseif acao=="Arma" then arma=arma%#f.armas+1;render()
		elseif acao=="Assumir" then state.send("escolherPersonagem",{id=f.id,arma=f.armas[arma].id})
		elseif acao=="Anterior" then mudar(indice-1)
		elseif acao=="Proxima" then mudar(indice+1)
		elseif acao=="Soltar" then arremessar(workspace.CurrentCamera.CFrame.LookVector,0,true)
		elseif acao=="Entregar" then
			-- Lista separada, sem transformar a própria ficha em formulário.
			tipo="entregar";controles.visivel(false);inspecionando=true;render()
		end
		return true
	end
	api.acao=acionar
	Gui:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local b=Gui.SelectedObject
		if b and b:IsDescendantOf(g) then task.defer(function() if Gui.SelectedObject==b then revelar(b) end end) end
	end)
	entrada.LastInputTypeChanged:Connect(function(input) if input==Enum.UserInputType.Gamepad1 and api.congelar() then task.defer(function() local b=Gui.SelectedObject;focar(b and b:IsDescendantOf(g) and b.Name) end) end end)
	controles=require(script.Parent.SalaFichaControles).new(pasta,Players.LocalPlayer.PlayerGui,acionar)
	game:GetService("UserInputService").InputBegan:Connect(function(input,processed)
		if not processed and aberto and tipo~="ficha" and tipo~="livro" and (input.KeyCode==Enum.KeyCode.Q or input.KeyCode==Enum.KeyCode.ButtonB) then
			if objetoId or tipo=="entregar" then api.lancar(0,true) else fechar() end
		end
	end)
	state.onLog(function(e) if e.tone=="erro" then
		if transferencia.para then table.clear(transferencia);if aberto then render() end end
		pendente=false
		if pedidoMao then pedidoMao=nil;local sala=snap and snap.salaConceitual;reconciliar(sala and (sala.maos[Players.LocalPlayer.UserId] or sala.maos[tostring(Players.LocalPlayer.UserId)])) end
		if entregando then entregando=false;render() end
	end end)
	g.Enabled=false;O.visivel(part,false)
	return api
end
return V
