-- SOMENTE STUDIO: cria rigs R15 e ProximityPrompts.
local Vila = require(script.Parent.Parent.Mundo.Vila)
local Npcs = require(script.Parent.Parent.Mundo.Npcs)
local Dados = require(game:GetService("ReplicatedStorage").Shared.Mundo.NpcsDados)

local function comLimpeza(pasta, corpo)
	local ok, erro = pcall(corpo)
	pasta:Destroy()
	if not ok then error(erro, 0) end
end

return {
	["npcs da vila nascem ancorados, perto da porta, com prompt e sem scripts"] = function(t)
		local mundo = Instance.new("Folder")
		comLimpeza(mundo, function()
		mundo.Parent = workspace
		Vila.start({ workspace = mundo })
		local pasta = Npcs.start({ workspace = mundo })
		t.eq(#pasta:GetChildren(), #Dados.LISTA)
		t.eq(Npcs.start({ workspace = mundo }), pasta)
		for _, npc in ipairs(Dados.LISTA) do
			local corpo = pasta:FindFirstChild(npc.nome)
			t.ok(corpo ~= nil, npc.id)
			local pos = Dados.posicao(npc)
			local raiz = corpo.HumanoidRootPart
			t.ok(math.abs(raiz.Position.X - pos.x) < 0.01 and math.abs(raiz.Position.Z - pos.z) < 0.01, npc.id)
			t.ok(raiz.Anchored)
			local rosto = corpo:FindFirstChild("AparenciaMoshoku")
			t.ok(rosto ~= nil and rosto:FindFirstChild("olhos1") ~= nil, npc.id .. " rosto A1")
			for _, parte in rosto:GetDescendants() do
				if parte:IsA("BasePart") then
					t.eq(parte.Anchored, false)
					t.eq(parte.CanCollide, false)
					t.eq(parte.CanQuery, false)
					t.eq(parte.CanTouch, false)
					t.eq(parte.Massless, true)
				end
			end
			local prompt = raiz:FindFirstChildOfClass("ProximityPrompt")
			t.ok(prompt ~= nil and prompt.ActionText == "Falar", npc.id)
   local quantidade = 0
			for _, item in ipairs(corpo:GetDescendants()) do
				t.ok(not item:IsA("LuaSourceContainer"), item:GetFullName())
    if item:IsA("ProximityPrompt") then quantidade += 1 end
			end
   t.eq(quantidade,1,npc.id)
		end
		end)
	end,
	["sem vila nao cria npcs"] = function(t)
		local mundo = Instance.new("Folder")
		t.eq(Npcs.start({ workspace = mundo }), nil)
		mundo:Destroy()
	end,
}
