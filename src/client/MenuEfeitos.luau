-- Animações locais, limitadas, sem assets externos ou ligação com regras.
local TweenService = game:GetService("TweenService")
local M = { reduzidos = false }
local tweens = {}
function M.reduzir(valor)
	M.reduzidos = valor == true
	if M.aoReduzir then M.aoReduzir() end
end
function M.animar(o, tempo, props)
	if tweens[o] then tweens[o]:Cancel() end
	local t = TweenService:Create(o, TweenInfo.new(if M.reduzidos then 0 else tempo, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tweens[o] = t
	t.Completed:Once(function() if tweens[o] == t then tweens[o] = nil end end)
	t:Play()
end
function M.botao(b, cor, destaque)
	local escala = Instance.new("UIScale"); escala.Parent = b
	b.AutoButtonColor = false
	b.MouseEnter:Connect(function() M.animar(b, 0.16, {BackgroundColor3 = destaque}) end)
	b.MouseLeave:Connect(function() M.animar(b, 0.2, {BackgroundColor3 = cor}); M.animar(escala, 0.15, {Scale = 1}) end)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then M.animar(escala, 0.09, {Scale = 0.975}) end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then M.animar(escala, 0.16, {Scale = 1}) end
	end)
end
function M.fundo(parent, cor)
	local selo = Instance.new("Frame")
	selo.Name, selo.AnchorPoint, selo.Position, selo.Size = "SeloMagico", Vector2.new(.5,.5), UDim2.fromScale(.82,.48), UDim2.fromOffset(520,520)
	selo.BackgroundTransparency, selo.Parent = 1, parent
	for i = 1, 3 do
		local aro = Instance.new("Frame"); aro.AnchorPoint, aro.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
		aro.Size, aro.BackgroundTransparency, aro.Rotation, aro.Parent = UDim2.fromScale(1-i*.14,1-i*.14), 1, i*25, selo
		local canto=Instance.new("UICorner"); canto.CornerRadius, canto.Parent = UDim.new(if i==2 then 0 else 1,0), aro
		local fio=Instance.new("UIStroke"); fio.Color, fio.Transparency, fio.Thickness, fio.Parent = cor, .85, 1, aro
	end
	local runa=Instance.new("Frame"); runa.BackgroundTransparency=1; runa.AnchorPoint=Vector2.new(.5,.5)
	runa.Position, runa.Size, runa.Rotation, runa.Parent=UDim2.fromScale(.5,.5),UDim2.fromOffset(72,72),45,selo
	local fio=Instance.new("UIStroke"); fio.Color,fio.Transparency,fio.Thickness,fio.Parent=cor,.55,2,runa
	local pontos = {}
	for i=1,12 do
		local p=Instance.new("Frame"); p.Name="Centelha"..i; p.BorderSizePixel=0; p.BackgroundColor3=cor
		p.BackgroundTransparency=.5; p.Size=UDim2.fromOffset(if i%3==0 then 3 else 2,if i%3==0 then 3 else 2)
		p.Parent=parent; pontos[i]=p
	end
	M.aoReduzir=function()
		if not M.reduzidos then return end
		if tweens[selo] then tweens[selo]:Cancel() end
		for _,p in pontos do if tweens[p] then tweens[p]:Cancel() end; p.Visible=false end
	end
	local ciclo=0
	task.spawn(function()
		while parent.Parent do
			if parent.Visible and not M.reduzidos then
				ciclo+=1
				M.animar(selo,6,{Rotation=selo.Rotation+12})
				for i,p in pontos do
					p.Visible=true
					p.Position=UDim2.fromScale(((i*37+ciclo*11)%100)/100,1.04)
					M.animar(p,5.5,{Position=UDim2.fromScale(p.Position.X.Scale+.025,-.04),BackgroundTransparency=.9})
				end
			else
				for _,p in pontos do p.Visible=false end
				if tweens[selo] then tweens[selo]:Cancel() end
			end
			task.wait(6)
		end
	end)
	return selo
end
return M
