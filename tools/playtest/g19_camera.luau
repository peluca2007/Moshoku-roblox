-- Fixture temporária persistente: observa a câmera e o estado do jogo real.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local state = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("MesaState"))
local Protocol = require(RS.Shared.MesaProtocol)
local E = require(RS.Shared.EnquadramentoMesa)
local transition = { frames=0, maxY=0, fora=0, escuro=false }
local lastTransition = nil
local keys = {}
local clicks = {}
local menuClicks = 0
local menu = player.PlayerGui:WaitForChild("InicioJogo"):WaitForChild("Navegacao").MENU
menu.Activated:Connect(function() menuClicks+=1 end)
local menuInputs={}
menu.InputBegan:Connect(function(i) table.insert(menuInputs,{type=i.UserInputType.Name,x=i.Position.X,y=i.Position.Y}) end)
UIS.InputBegan:Connect(function(i,p)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		table.insert(clicks,{type=i.UserInputType.Name,x=i.Position.X,y=i.Position.Y,processed=p})
	end
	if i.UserInputType == Enum.UserInputType.Keyboard then
		table.insert(keys,{ key=i.KeyCode.Name, processed=p })
		script:SetAttribute("Teclas",Http:JSONEncode(keys))
	end
end)
script:SetAttribute("Teclas","[]")
Run.RenderStepped:Connect(function()
	local snap = state.snapshot()
	local camera = workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	script:SetAttribute("Estado",Http:JSONEncode({
		ready=snap~=nil and hum~=nil, seated=seat~=nil and seat:GetAttribute("LugarSala")~=nil,
		combat=snap and snap.combat.active or false, table=state.tableView(),
		master=snap and snap.salaConceitual and snap.salaConceitual.mestre or 0, me=player.UserId,
	}))
	if snap and snap.salaConceitual and snap.salaConceitual.transicao then
		local inicio=snap.salaConceitual.transicao.inicio
		if lastTransition~=inicio then
			lastTransition=inicio;transition={inicio=inicio,frames=0,maxY=0,fora=0,escuro=false}
		end
		transition.frames+=1;transition.maxY=math.max(transition.maxY,camera.CFrame.Position.Y)
		if math.abs(camera.CFrame.Position.X-250)>25 then transition.fora+=1 end
		local overlay=player.PlayerGui:FindFirstChild("TransicaoSala")
		local frame=overlay and overlay:FindFirstChildOfClass("Frame")
		if frame and frame.Visible and frame.BackgroundTransparency<.05 then transition.escuro=true end
	end
end)
script:GetAttributeChangedSignal("Medir"):Connect(function()
	Run.RenderStepped:Wait();Run.RenderStepped:Wait()
	local snap=state.snapshot();local camera=workspace.CurrentCamera;local vp=camera.ViewportSize
	local box=E.limites(snap.tokens,snap.combat.order,Protocol.BOARD)
	local center=Protocol.BOARD.origin+Vector3.new(box.x,0,box.z)
	local point=camera:WorldToViewportPoint(center)
	local barra=player.PlayerGui.AcoesDoTurno.Barra
	local cartao=player.PlayerGui.HudJogo.Cartao
	local cartaoVisivel=cartao.Visible and cartao.Parent.Enabled
	local resumo=player.PlayerGui.HudJogo.Resumo
	local base=if barra.Visible then barra.AbsolutePosition.Y+game.GuiService:GetGuiInset().Y-8 else vp.Y
	local topo=64
	if resumo.Visible then topo=math.max(topo,resumo.AbsolutePosition.Y+game.GuiService:GetGuiInset().Y+resumo.AbsoluteSize.Y+8) end
	local area={x1=0,y1=topo,x2=vp.X,y2=math.max(topo+1,base)}
	local function botao(b)
		local p=b.AbsolutePosition;local s=b.AbsoluteSize
		return {name=b.Name,x=p.X+s.X/2,y=p.Y+s.Y/2,w=s.X,h=s.Y,visible=b.Visible,text=b.Text}
	end
	local cartas={}
	for _,b in barra.Cartas:GetChildren() do
		if b:IsA("TextButton") and b.Visible and not b:GetAttribute("Bloqueada") then table.insert(cartas,botao(b)) end
	end
	local ids={};for _,id in snap.combat.order do ids[id]=true end
	local pieces={}
	for _,token in snap.tokens do if ids[token.id] then
		local p,visible=camera:WorldToViewportPoint(Protocol.cellCenter(token.x,token.z)+Vector3.new(0,3,0))
		table.insert(pieces,{id=token.id,x=p.X,y=p.Y,on=visible})
	end end
	local corners={}
	for _,x in {-1,1} do for _,z in {-1,1} do
		local p,visible=camera:WorldToViewportPoint(center+Vector3.new(x*box.largura/2,0,z*box.profundidade/2))
		table.insert(corners,{x=p.X,y=p.Y,on=visible})
	end end
	local overlay=player.PlayerGui.TransicaoSala:FindFirstChildOfClass("Frame")
	local hits={}
	for _,y in {34,92,150} do
		local names={};for _,o in player.PlayerGui:GetGuiObjectsAtPosition(vp.X-38,y) do table.insert(names,o:GetFullName()) end
		table.insert(hits,{y=y,names=names})
	end
	script:SetAttribute("Medida",Http:JSONEncode({
		serial=script:GetAttribute("Medir"),vp={vp.X,vp.Y},area=area,
		center={point.X,point.Y},position={camera.CFrame.X,camera.CFrame.Y,camera.CFrame.Z},
		pieces=pieces,corners=corners,table=state.tableView(),panel=player.PlayerGui.MesaPanel.Enabled,
		fade=overlay.Visible,transition=transition,keys=keys,
		card={visible=cartaoVisivel,x=cartao.AbsolutePosition.X,y=cartao.AbsolutePosition.Y+game.GuiService:GetGuiInset().Y,w=cartao.AbsoluteSize.X,h=cartao.AbsoluteSize.Y},
		tray={open=barra.Cartas.Visible,button=botao(barra.ExpandirAcoes),cards=cartas,cancel=botao(barra.Controles.CancelarMira),
			height=barra.AbsoluteSize.Y,y=barra.AbsolutePosition.Y,extras=barra.Controles.Visible},
		mira=state.mira()~=nil,actions=snap.jogo and snap.jogo.acoes,
		turn=snap.combat.turn,turnId=snap.combat.turnId,summary=resumo.Visible,
		summaryName=botao(resumo.Nome),deadline=botao(player.PlayerGui.HudJogo.Prazo),resources=resumo.Recursos.Text,
		menu=botao(player.PlayerGui.InicioJogo.Navegacao.MENU),menuOpen=player.PlayerGui.InicioJogo.MenuInicial.Visible,
		clicks=clicks,menuClicks=menuClicks,inset=game.GuiService:GetGuiInset().Y,
		menuInputs=menuInputs,hits=hits,menuInteractable=menu.Interactable,menuActive=menu.Active,navVisible=menu.Parent.Visible,menuEnabled=menu.Parent.Parent.Enabled,
	}))
end)
