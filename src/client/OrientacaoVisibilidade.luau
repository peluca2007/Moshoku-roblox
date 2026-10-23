-- Cache incremental: não enumera toda a interface a cada batimento.
local V={}
function V.start(pg, propria)
	local quadros, conexoes={},{}
	local function adicionar(o)
		if o:IsA("Frame") or o:IsA("CanvasGroup") or o:IsA("ScrollingFrame") then quadros[o]=true end
	end
	for _, o in pg:GetDescendants() do adicionar(o) end
	table.insert(conexoes,pg.DescendantAdded:Connect(adicionar))
	table.insert(conexoes,pg.DescendantRemoving:Connect(function(o) quadros[o]=nil end))
	local function visivel(o)
		local atual=o
		while atual and atual~=pg do
			if atual:IsA("GuiObject") and not atual.Visible then return false end
			if atual:IsA("ScreenGui") then return atual.Enabled and atual~=propria end
			atual=atual.Parent
		end
		return false
	end
	return function(tela)
		for o in quadros do
			if o.AbsoluteSize.X>=tela.X*.6 and o.AbsoluteSize.Y>=tela.Y*.5 and visivel(o) then
				if o.BackgroundTransparency<.95 or o:IsA("CanvasGroup") then return true end
			end
		end
		return false
	end, function() for _, c in conexoes do c:Disconnect() end; table.clear(quadros) end
end
return V
