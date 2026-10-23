-- Devolve o centro (em pixels da janela) de botões do painel, pelo texto.
-- Usado pelo teste de cliques reais (tools/playtest/ui_cliques.py).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("MesaPanel", 10)
local inset = GuiService:GetGuiInset()
local out = {}
for _, object in gui:GetDescendants() do
	if object:IsA("TextButton") and object.Visible and object.Text ~= "" then
		local center = object.AbsolutePosition + object.AbsoluteSize / 2
		table.insert(out, string.format("%s|%d|%d", object.Text, math.round(center.X), math.round(center.Y + inset.Y)))
	end
end
return string.format("inset=%d\n", inset.Y) .. table.concat(out, "\n")
