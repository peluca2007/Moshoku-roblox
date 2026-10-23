-- Feedback discreto dos recursos confirmados pelo servidor; sem tremor ou flash.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local T=require(script.Parent.UI.Tema)
local FX=require(script.Parent.MenuEfeitos)
local Feedback={}
function Feedback.start(state)
	local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.IgnoreGuiInset="FeedbackCombate",false,12,true
	gui.Parent=pg
	local bordas={}
	for i=1,2 do
		local f=Instance.new("Frame"); f.Name="Borda"..i; f.BorderSizePixel=0
		f.Size=UDim2.new(0,9,1,0); f.Position=UDim2.new(i-1,if i==2 then -9 else 0,0,0)
		f.BackgroundTransparency=1; f.Parent=gui; bordas[i]=f
	end
	local anterior={}; local ativos={}
	state.onSnapshot(function(s)
		local proximos={}
		local delta=0
		for _,t in s.tokens do
			if t.ownerUserId==state.localUserId() then
				proximos[t.id]=t.pv
				if anterior[t.id] and type(t.pv)=="number" then delta+=t.pv-anterior[t.id] end
			end
		end
		anterior=proximos
		local menu=pg:FindFirstChild("InicioJogo")
		local oculto=menu and menu.MenuInicial.Visible
		if not s.combat.active or oculto or FX.reduzidos then
			for _,f in bordas do if ativos[f] then ativos[f]:Cancel() end; f.BackgroundTransparency=1 end
			return
		end
		if delta==0 then return end
		for _,f in bordas do
			if ativos[f] then ativos[f]:Cancel() end
			f.BackgroundColor3=if delta<0 then T.cores.perigo else T.cores.sucesso
			f.BackgroundTransparency=.3
			local t=TweenService:Create(f,TweenInfo.new(.8,Enum.EasingStyle.Quad),{BackgroundTransparency=1})
			ativos[f]=t; t:Play()
		end
	end)
	return gui
end
return Feedback
