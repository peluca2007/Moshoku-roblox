-- Comandos contextuais: aparecem apenas com algo na mão, sem botão de pegar.
local UIS=game:GetService("UserInputService")
local D={}
function D.new(pg,acao)
	local gui=Instance.new("ScreenGui");gui.Name="SalaMaoDicas";gui.ResetOnSpawn=false;gui.DisplayOrder=29;gui.Enabled=false;gui.Parent=pg
	local area=Instance.new("Frame");area.Name="AreaUtil";area.Size=UDim2.fromScale(1,1);area.BackgroundTransparency=1;area.Parent=gui
	local frame=Instance.new("Frame");frame.Name="Comandos";frame.AnchorPoint=Vector2.new(0,1);frame.Position=UDim2.new(0,18,1,-24);frame.Size=UDim2.fromOffset(280,230);frame.BackgroundColor3=Color3.fromRGB(27,34,30);frame.BackgroundTransparency=.12;frame.BorderSizePixel=0;frame.Parent=gui
	local canto=Instance.new("UICorner");canto.CornerRadius=UDim.new(0,9);canto.Parent=frame
	local borda=Instance.new("UIStroke");borda.Color=Color3.fromRGB(177,141,79);borda.Transparency=.35;borda.Parent=frame
	local titulo=Instance.new("TextLabel");titulo.Name="Objeto";titulo.BackgroundTransparency=1;titulo.Position=UDim2.fromOffset(12,6);titulo.Size=UDim2.new(1,-24,0,30);titulo.TextColor3=Color3.fromRGB(245,228,190);titulo.Font=Enum.Font.Garamond;titulo.TextSize=22;titulo.TextXAlignment=Enum.TextXAlignment.Left;titulo.Parent=frame
	local lista=Instance.new("ScrollingFrame");lista.Name="Acoes";lista.Position=UDim2.fromOffset(8,38);lista.Size=UDim2.new(1,-16,1,-46);lista.BackgroundTransparency=1;lista.BorderSizePixel=0;lista.ScrollBarThickness=3;lista.AutomaticCanvasSize=Enum.AutomaticSize.Y;lista.CanvasSize=UDim2.new();lista.Parent=frame
	local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,4);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=lista
	local chave=nil;local api={}
	function api.atualizar(mao,apoiado)
		gui.Enabled=mao~=nil
		if not mao then chave=nil;return end
		local controle=UIS:GetLastInputType()==Enum.UserInputType.Gamepad1
		local toque=UIS.TouchEnabled and not controle and UIS:GetLastInputType()==Enum.UserInputType.Touch
		local tipo=if mao=="dados-brotos" then "dados" elseif mao:sub(1,8)=="jogador:" then "amigo" elseif mao:sub(1,6)=="livro-" then "livro" else "ficha"
		local nova=tipo..tostring(controle)..tostring(toque)..tostring(apoiado)
		if nova~=chave then
			chave=nova;for _,p in lista:GetChildren() do if p:IsA("GuiObject") then p:Destroy() end end
			titulo.Text=({dados="Dados na mão",amigo="Amigo na mão",livro="Livro na mão",ficha="Ficha na mão"})[tipo]
			local comandos={}
			if tipo~="amigo" then table.insert(comandos,{"Arremessar","Arremessar",if controle then "X" else "F"}) end
			table.insert(comandos,{"Soltar","Largar sem impulso",if apoiado then (if controle then "B" else "Q") else (if controle then "Soltar RT / B" else "Soltar clique / Q")})
			if tipo=="ficha" or tipo=="livro" then
				table.insert(comandos,{"Ler","Ler / baixar",if controle then "Y" else "R"})
				if tipo=="ficha" then
					for _,a in {{"Folhear","Folhear","V","RB"},{"Assumir","Assumir personagem","Enter","↑"},{"Entregar","Entregar ficha","T","↓"},{"Arma","Trocar arma","B","LB"},{"Anterior","Ficha anterior","Z","←"},{"Proxima","Próxima ficha","X","→"}} do table.insert(comandos,{a[1],a[2],if controle then a[4] else a[3]}) end
				end
			end
			for i,a in comandos do
				local b=Instance.new("TextButton");b.Name=a[1];b.LayoutOrder=i;b.Size=UDim2.new(1,-5,0,if toque then 48 else 26);b.BackgroundTransparency=if toque then .55 else 1;b.BackgroundColor3=Color3.fromRGB(70,81,64);b.BorderSizePixel=0;b.TextColor3=Color3.fromRGB(239,225,190);b.Font=Enum.Font.Gotham;b.TextSize=if toque then 14 else 13;b.TextWrapped=true;b.TextXAlignment=Enum.TextXAlignment.Left;b.Text=if toque then a[2] else a[3].."  ·  "..a[2];b.Active=toque;b.Selectable=false;b.AutoButtonColor=toque;b.Parent=lista
				b.Activated:Connect(function() if toque then acao(a[1]) end end)
				b.AutomaticSize=Enum.AutomaticSize.Y
			end
		end
		-- A área do ScreenGui já desconta barras/notch do Roblox. ViewportSize
		-- sozinho deixava a ficha ultrapassar o topo no toque em paisagem.
		local v=area.AbsoluteSize
		frame.Position=UDim2.new(0,18,1,-(if toque then math.min(170,v.Y*.45) else 24))
		frame.Size=UDim2.fromOffset(math.min(280,math.max(160,v.X*.46)),math.min(if tipo=="ficha" then (if toque then 260 else 320) else (if toque then 160 else 120),v.Y*(if toque then .42 else .6)))
	end
	return api
end
return D
