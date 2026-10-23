-- Convite transitório, rolável em telas baixas e navegável pelo controle.
local Players=game:GetService("Players")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local V={}
function V.new(parent,state)
	local frame=Instance.new("Frame");frame.Name="Eleicao";frame.AnchorPoint=Vector2.new(.5,0);frame.Position=UDim2.new(.5,0,.12,0);frame.Size=UDim2.new(1,-32,0,270);frame.BackgroundColor3=Color3.fromRGB(238,221,184);frame.BorderSizePixel=0;frame.Visible=false;frame.Parent=parent
	local limite=Instance.new("UISizeConstraint");limite.MaxSize=Vector2.new(510,310);limite.Parent=frame
	local canto=Instance.new("UICorner");canto.CornerRadius=UDim.new(0,10);canto.Parent=frame
	local linha=Instance.new("UIStroke");linha.Color=Color3.fromRGB(130,107,70);linha.Transparency=.25;linha.Parent=frame
	local scroll=Instance.new("ScrollingFrame");scroll.Name="Opcoes";scroll.Size=UDim2.fromScale(1,1);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=5;scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.CanvasSize=UDim2.new();scroll.Parent=frame
	local pad=Instance.new("UIPadding");pad.PaddingTop=UDim.new(0,18);pad.PaddingBottom=UDim.new(0,18);pad.PaddingLeft=UDim.new(0,18);pad.PaddingRight=UDim.new(0,18);pad.Parent=scroll
	local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,10);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=scroll
	local function texto(nome,tamanho,ordem)
		local l=Instance.new("TextLabel");l.Name=nome;l.Size=UDim2.new(1,-6,0,0);l.AutomaticSize=Enum.AutomaticSize.Y;l.BackgroundTransparency=1;l.Font=Enum.Font.Garamond;l.TextSize=tamanho;l.TextWrapped=true;l.TextColor3=Color3.fromRGB(65,47,31);l.LayoutOrder=ordem;l.Parent=scroll;return l
	end
	local titulo=texto("Titulo",29,1);local status=texto("Estado",21,2)
	local function botao(nome,texto,ordem,fn)
		local b=Instance.new("TextButton");b.Name=nome;b.Text=texto;b.Size=UDim2.new(1,-6,0,50);b.Font=Enum.Font.Garamond;b.TextSize=22;b.TextWrapped=true;b.TextColor3=Color3.fromRGB(56,43,29);b.BackgroundColor3=Color3.fromRGB(208,187,142);b.BorderSizePixel=0;b.LayoutOrder=ordem;b.Parent=scroll;b.Activated:Connect(fn)
		local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=b;return b
	end
	local e=nil;local admitido=false;local ultimoVisible=false;local minimizado=false;local chave=nil;local api={}
	local function recolher()
		minimizado=true;frame.Visible=false
		if Gui.SelectedObject and Gui.SelectedObject:IsDescendantOf(frame) then Gui.SelectedObject=nil end
	end
	local sim=botao("Aceitar","Quero mestrar",3,function() state.send("salaCandidatar",{sim=true}) end)
	local nao=botao("Recusar","Continuar como jogador",4,function() state.send("salaCandidatar",{sim=false});recolher() end)
	local rolar=botao("RolarBrotos","Lançar meus três dados",3,function() state.send("salaRolar",{}) end)
	local mesa=botao("VoltarMesa","Pegar os dados na mesa",4,recolher)
	function api.atualizar(eleicao,permitido)
		e=eleicao;admitido=permitido==true
		local nova=e and e.fase..":"..e.rodada
		if nova~=chave then chave=nova;minimizado=false end
		local id=Players.LocalPlayer.UserId;local candidato=e and (e.candidatos[id] or e.candidatos[tostring(id)])
		local dados=e and (e.dados[id] or e.dados[tostring(id)])
		frame.Visible=e~=nil and admitido and not minimizado and (e.fase=="convite" or (candidato==true and dados==nil))
		if not frame.Visible then
			if Gui.SelectedObject and Gui.SelectedObject:IsDescendantOf(frame) then Gui.SelectedObject=nil end
			ultimoVisible=false;return
		end
		sim.Visible=e.fase=="convite";nao.Visible=sim.Visible;rolar.Visible=e.fase=="rolagem" and candidato==true and dados==nil
		mesa.Visible=rolar.Visible
		titulo.Text=if e.fase=="convite" then "Quem vai mestrar?" else "Dados do Brotos • rodada "..e.rodada
		status.Text=if e.fase=="convite" then (if candidato then "✓ Você se candidatou. Aguarde os demais." else "Candidate-se ou continue como jogador.") elseif dados then "✓ Seus dados foram confirmados. Aguardando os outros." elseif candidato then "Pegue os dados na mesa e arremesse, ou lance abaixo." else "Aguardando os candidatos lançarem os dados."
		sim.Text=if candidato then "✓ Quero mestrar" else "Quero mestrar"
		local selecionado=Gui.SelectedObject
		if UIS:GetLastInputType()==Enum.UserInputType.Gamepad1 and (not ultimoVisible or not selecionado or not selecionado.Parent or (selecionado:IsDescendantOf(frame) and not selecionado.Visible)) then Gui.SelectedObject=if sim.Visible then sim elseif rolar.Visible then rolar else nil end
		ultimoVisible=true
	end
	function api.congelar() return frame.Visible end
	function api.abrir() minimizado=false;api.atualizar(e,admitido) end
	function api.redimensionar()
		local h=workspace.CurrentCamera.ViewportSize.Y
		frame.Size=UDim2.new(1,-32,0,math.clamp(h*.72,100,310))
	end
	return api
end
return V
