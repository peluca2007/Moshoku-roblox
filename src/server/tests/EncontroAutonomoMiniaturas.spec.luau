-- SOMENTE STUDIO: monta e inspeciona Instances cosméticas no Workspace.
local Miniaturas = require(script.Parent.Parent.EncontroAutonomoMiniaturas)

return {
	["miniaturas usam o marco do bosque e recusam ID ausente no mundo"] = function(t)
		local mundo = Instance.new("Folder")
		local regiao = Instance.new("Folder")
		regiao.Name, regiao.Parent = "RegiaoInicial", mundo
		for id, posicao in pairs({
			["region/encounter/clearing"] = Vector3.new(42, 2.5, 41),
			["region/encounter/forest"] = Vector3.new(-42, 2.5, 53),
		}) do
			local marco = Instance.new("Part")
			marco.Position, marco.Parent = posicao, regiao
			marco:SetAttribute("EncounterId", id)
			marco:SetAttribute("AreaRole", "encounter-trigger")
		end
		local floresta = Instance.new("Folder")
		floresta.Name, floresta.Parent = "FlorestaSombria", mundo
		local marcoSombrio = Instance.new("Part")
		marcoSombrio.Position, marcoSombrio.Parent = Vector3.new(0, 2.5, -485), floresta
		marcoSombrio:SetAttribute("EncounterId", "region/encounter/dark-forest")
		marcoSombrio:SetAttribute("AreaRole", "encounter-trigger")
		local palco = Miniaturas.start({ workspace = mundo })
		local atores = { { id = "lobo", kind = "criatura", name = "Lobo", x = 10, z = 10 } }
		t.eq(palco.render("forest", atores, "lobo", "active", "region/encounter/forest"), true)
		local pasta = mundo:FindFirstChild("MiniaturasJ2_forest")
		local base = pasta:FindFirstChild("Ator_lobo_Base")
		t.ok(math.abs(base.Position.X + 42.9) < 0.001)
		t.ok(math.abs(base.Position.Z - 60.1) < 0.001)
		t.eq(palco.render("dark", atores, "lobo", "active", "region/encounter/dark-forest"), true)
		local baseSombria = mundo.MiniaturasJ2_dark:FindFirstChild("Ator_lobo_Base")
		t.ok(math.abs(baseSombria.Position.X + 0.9) < 0.001)
		t.ok(math.abs(baseSombria.Position.Z + 477.9) < 0.001)
		t.eq(palco.render("forged", atores, "lobo", "active", "region/encounter/forged"), false)
		t.eq(mundo:FindFirstChild("MiniaturasJ2_forged"), nil)
		palco.limpar("forest")
		palco.limpar("dark")
		t.eq(mundo:FindFirstChild("MiniaturasJ2_forest"), nil)
		mundo:Destroy()
	end,
	["miniaturas mostram posicao e PV sem colisao e limpam no retorno"] = function(t)
		local workspaceTeste = Instance.new("Folder")
		local regiao = Instance.new("Folder")
		regiao.Name = "RegiaoInicial"
		regiao.Parent = workspaceTeste
		local marco = Instance.new("Part")
		marco.Name = "Marco do encontro"
		marco.Position = Vector3.new(42, 2.5, 41)
		marco:SetAttribute("EncounterId", "region/encounter/clearing")
		marco:SetAttribute("AreaRole", "encounter-trigger")
		marco.Parent = regiao
		local palco = Miniaturas.start({ workspace = workspaceTeste })
		local atores = {
			{ id = "jogador:101", kind = "jogador", name = "Aventureiro", x = 10, z = 10, pv = 12, pvMax = 18 },
			{ id = "criatura:1", kind = "criatura", name = "Goblin batedor", x = 11, z = 10, pv = 5, pvMax = 5 },
			{ id = "criatura:2", kind = "criatura", name = "Lobo", x = 12, z = 10, pv = 8, pvMax = 8 },
			{ id = "criatura:3", kind = "criatura", name = "Treant", x = 13, z = 10, pv = 10, pvMax = 10 },
			{ id = "criatura:4", kind = "criatura", name = "Goblin derrotado", x = 14, z = 10, pv = 0, pvMax = 5, defeated = true },
		}
		t.eq(palco.render("teste/1", atores, "jogador:101", "active"), true)
		local pasta = workspaceTeste:FindFirstChild("MiniaturasJ2_teste_1")
		local token = pasta and pasta:FindFirstChild("Ator_jogador_101")
		t.ok(token ~= nil)
		t.eq(token.CanCollide, false)
		t.eq(token.CanTouch, false)
		t.eq(token.CanQuery, false)
		t.eq(token:GetAttribute("Active"), true)
		t.ok(math.abs(token.Position.X - 41.1) < 0.001)
		t.ok(math.abs(token.Position.Z - 48.1) < 0.001)
		t.ok(math.abs(token.Position.Y - 0.91) < 0.001)
		local base = pasta:FindFirstChild("Ator_jogador_101_Base")
		local cabeca = pasta:FindFirstChild("Ator_jogador_101_Cabeca")
		t.ok(base ~= nil and not base.CanCollide)
		t.ok(cabeca ~= nil and not cabeca.CanCollide)
		t.ok(pasta:FindFirstChild("Ator_criatura_1_Orelha1") ~= nil)
		t.ok(pasta:FindFirstChild("Ator_criatura_1_Orelha2") ~= nil)
		t.ok(pasta:FindFirstChild("Ator_criatura_2_Focinho") ~= nil)
		t.ok(pasta:FindFirstChild("Ator_criatura_2_Pata4") ~= nil)
		t.ok(pasta:FindFirstChild("Ator_criatura_3_Copa") ~= nil)
		t.eq(pasta:FindFirstChild("Ator_criatura_4"), nil)
		for _, item in ipairs(pasta:GetDescendants()) do
			if item:IsA("BasePart") then
				t.eq(item.CanCollide, false)
				t.eq(item.CanTouch, false)
				t.eq(item.CanQuery, false)
			end
		end
		local posicaoInicial = token.Position
		atores[1].x = 12
		palco.render("teste/1", atores, "jogador:101", "active")
		t.ok(pasta:FindFirstChild("Ator_jogador_101").Position.X ~= posicaoInicial.X)
		palco.limpar("teste/1")
		t.eq(workspaceTeste:FindFirstChild("MiniaturasJ2_teste_1"), nil)
		workspaceTeste:Destroy()
	end,
}
