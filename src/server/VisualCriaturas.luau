-- Detalhes decorativos soldados ao rig. Sem colisão, hitbox ou efeito de regra.
local V = {}
function V.humanoide(modelo, catalogId)
	if catalogId ~= "creature/goblin-batedor" and catalogId ~= "creature/bandido-de-estrada" then return end
	local head = modelo:FindFirstChild("Head")
	local torso = modelo:FindFirstChild("UpperTorso")
	if not head or not torso then return end
	local function detalhe(nome, base, size, cf, cor, classe)
		local p = Instance.new(classe or "Part")
		p.Name, p.Size, p.Color = nome, size, cor
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		p.Material, p.CFrame = Enum.Material.SmoothPlastic, base.CFrame * cf
		p.Parent = modelo
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1, weld.C0, weld.Parent = base, p, cf, p
		return p
	end
	local couro = Color3.fromRGB(79, 53, 33)
	local metal = Color3.fromRGB(106, 113, 119)
	local tamanho = torso.Size
	detalhe("Cinto", torso, Vector3.new(tamanho.X * 1.04, .18, tamanho.Z * 1.08), CFrame.new(0, -tamanho.Y * .38, 0), couro)
	detalhe("Fivela", torso, Vector3.new(.25, .25, .12), CFrame.new(0, -tamanho.Y * .38, -tamanho.Z * .56), metal)
	detalhe("TiraPeitoral", torso, Vector3.new(.25, tamanho.Y * .95, .12), CFrame.new(0, 0, -tamanho.Z * .54) * CFrame.Angles(0, 0, math.rad(-25)), couro)
	if catalogId == "creature/goblin-batedor" then
		for _, lado in { -1, 1 } do
			detalhe("OrelhaGoblin", head, Vector3.new(head.Size.X * .45, head.Size.Y * .55, .22), CFrame.new(lado * head.Size.X * .6, .1, 0) * CFrame.Angles(0, 0, lado * math.rad(-24)), head.Color, "WedgePart")
		end
		local braco = modelo:FindFirstChild("LeftUpperArm")
		if braco then detalhe("Ombreira", braco, braco.Size * Vector3.new(1.18, .38, 1.18), CFrame.new(0, braco.Size.Y * .3, 0), couro) end
	else
		detalhe("MascaraBandido", head, Vector3.new(head.Size.X * 1.02, head.Size.Y * .35, .12), CFrame.new(0, -head.Size.Y * .2, -head.Size.Z * .51), Color3.fromRGB(65, 27, 27))
	end
	modelo:SetAttribute("DetalhesVisuais", true)
end
return V
