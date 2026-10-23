-- Ambiente no cliente (estética Livro Noite): os selos das árvores que flutuam no
-- escuro em volta do livro (peças com atributo "Selo", criadas por MesaWorld)
-- sobem e descem devagar e pulsam o brilho. Luzes com atributo "Chama", se
-- houver, tremulam. Só apresentação; cada cliente anima por conta própria.
local RunService = game:GetService("RunService")

local Ambiente = {}

function Ambiente.start()
	local flames: { { light: PointLight, base: number, seed: number } } = {}
	local selos: { { part: BasePart, base: Vector3, seed: number, light: PointLight?, label: TextLabel? } } = {}

	local function track(object: Instance)
		if object:IsA("PointLight") and object:GetAttribute("Chama") then
			table.insert(flames, { light = object, base = object.Brightness, seed = math.random() * 100 })
		elseif object:IsA("BasePart") and object:GetAttribute("Selo") then
			-- O conteúdo do selo pode chegar depois da peça.
			task.defer(function()
				table.insert(selos, {
					part = object,
					base = object.Position,
					seed = math.random() * 100,
					light = object:FindFirstChildOfClass("PointLight"),
					label = object:FindFirstChildWhichIsA("TextLabel", true),
				})
			end)
		end
	end

	-- O cenário é replicado aos poucos; acompanha o que chegar depois.
	local mesa = workspace:WaitForChild("Mesa", 30)
	if not mesa then
		return
	end
	for _, descendant in mesa:GetDescendants() do
		track(descendant)
	end
	mesa.DescendantAdded:Connect(track)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for index = #flames, 1, -1 do
			local flame = flames[index]
			if not flame.light.Parent then
				table.remove(flames, index)
			else
				local wave = math.noise(t * 2.2, flame.seed) * 0.35 + math.noise(t * 7, flame.seed + 31) * 0.12
				flame.light.Brightness = math.max(0.2, flame.base * (1 + wave))
			end
		end
		for index = #selos, 1, -1 do
			local selo = selos[index]
			if not selo.part.Parent then
				table.remove(selos, index)
			else
				local fase = t * 0.35 + selo.seed
				selo.part.Position = selo.base + Vector3.new(0, math.sin(fase) * 1.6, 0)
				local pulso = (math.sin(fase * 1.7) + 1) / 2
				if selo.label then
					selo.label.TextTransparency = 0.35 + pulso * 0.25
				end
				if selo.light then
					selo.light.Brightness = 0.35 + (1 - pulso) * 0.5
				end
			end
		end
	end)
end

return Ambiente
