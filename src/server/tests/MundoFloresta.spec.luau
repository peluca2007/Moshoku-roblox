-- SOMENTE STUDIO: a floresta monta Instances do mundo.
local Floresta = require(script.Parent.Parent.Mundo.Floresta)
local Layout = require(game:GetService("ReplicatedStorage").Shared.Mundo.FlorestaLayout)
local TerrenoLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.TerrenoLayout)

return {
	["floresta monta marco catalogado sem grade nem rochas do J2"] = function(t)
		local mundo = Instance.new("Folder")
		local floresta = Floresta.start({ workspace = mundo })
		local segunda = Floresta.start({ workspace = mundo })
		local clareira = floresta:FindFirstChild("Clareira de combate")
		local marco = clareira and clareira:FindFirstChild("Marco da Floresta Sombria")
		local prompt = marco and marco:FindFirstChildWhichIsA("ProximityPrompt")
		local grade = clareira and clareira:FindFirstChild("Grade tática")
		local rochas = clareira and clareira:FindFirstChild("Obstaculos")
		t.eq(segunda, floresta)
		t.eq(#mundo:GetChildren(), 1)
		t.eq(floresta:FindFirstChild("Trilha da vila"), nil)
		t.eq(floresta:FindFirstChild("Solo"), nil)
		t.eq(marco:GetAttribute("EncounterId"), "region/encounter/dark-forest")
		t.eq(marco:GetAttribute("AreaRole"), "encounter-trigger")
		t.eq(TerrenoLayout.altura(Layout.MARCO.x, Layout.MARCO.z), 0)
		t.ok(prompt ~= nil and prompt.Enabled and prompt.RequiresLineOfSight)
		t.eq(grade, nil)
		t.eq(rochas, nil)
		mundo:Destroy()
	end,
}
