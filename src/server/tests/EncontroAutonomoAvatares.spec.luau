-- SOMENTE STUDIO: transforma/sincroniza personagens Roblox e restaura após retorno.
local Avatares = require(script.Parent.Parent.EncontroAutonomoAvatares)

local function comLimpeza(mundo, corpo)
	local ok, erro = pcall(corpo)
	mundo:Destroy()
	if not ok then error(erro, 0) end
end

local function fixture()
	local mundo = Instance.new("Folder")
	mundo.Name = "AvataresSpec"
	mundo.Parent = workspace
	local regiao = Instance.new("Folder")
	regiao.Name = "RegiaoInicial"
	regiao.Parent = mundo
	local marco = Instance.new("Part")
	marco.Name, marco.Position, marco.Anchored = "Marco do encontro", Vector3.new(42, 2.5, 41), true
	marco:SetAttribute("EncounterId", "region/encounter/clearing")
	marco:SetAttribute("AreaRole", "encounter-trigger")
	marco.Parent = regiao
	local marcoBosque = marco:Clone()
	marcoBosque.Name, marcoBosque.Position = "Marco do bosque", Vector3.new(-42, 2.5, 53)
	marcoBosque:SetAttribute("EncounterId", "region/encounter/forest")
	marcoBosque.Parent = regiao
	local floresta = Instance.new("Folder")
	floresta.Name, floresta.Parent = "FlorestaSombria", mundo
	local marcoSombrio = marco:Clone()
	marcoSombrio.Name, marcoSombrio.Position = "Marco da Floresta Sombria", Vector3.new(0, 2.5, -485)
	marcoSombrio:SetAttribute("EncounterId", "region/encounter/dark-forest")
	marcoSombrio.Parent = floresta
	local character = Instance.new("Model")
	character.Name = "PersonagemSpec"
	character.Parent = mundo
	local root = Instance.new("Part")
	root.Name, root.Size, root.Position = "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(100, 4, 100)
	root.Anchored, root.Parent = false, character
	character.PrimaryPart = root
	local humanoide = Instance.new("Humanoid")
	humanoide.Health, humanoide.WalkSpeed, humanoide.JumpPower, humanoide.JumpHeight = 100, 16, 50, 7.2
	humanoide.AutoRotate, humanoide.Parent = true, character
	local player = { Character = character }
	local api = Avatares.start({ workspace = mundo, localizarJogador = function(userId)
		return if userId == 123 then player else nil
	end })
	return mundo, player, root, humanoide, api
end

return {
	["seleciona o centro do bosque por ID e restaura a origem ao limpar"] = function(t)
		local mundo, _, root, _, api = fixture()
		comLimpeza(mundo, function()
		local original = root.CFrame
		local atores = { { kind = "jogador", userId = 123, x = 10, z = 10 } }
		t.eq(api.sincronizar("bosque", atores, "active", "region/encounter/forest"), true)
		t.ok(math.abs(root.Position.X + 42.9) < 0.001)
		t.ok(math.abs(root.Position.Z - 60.1) < 0.001)
		t.eq(root.Position.Y, 3)
		local posicao = root.Position
		t.eq(api.sincronizar("falso", atores, "active", "region/encounter/forged"), false)
		t.eq(root.Position, posicao)
		api.limpar("bosque")
		t.eq(root.CFrame, original)
		t.eq(api.sincronizar("floresta-sombria", atores, "active", "region/encounter/dark-forest"), true)
		t.ok(math.abs(root.Position.X + 0.9) < 0.001)
		t.ok(math.abs(root.Position.Z + 477.9) < 0.001)
		api.limpar("floresta-sombria")
		end)
	end,
	["sincroniza avatar na casa do servidor e restaura controles/posicao ao limpar"] = function(t)
		local mundo, _, root, humanoide, api = fixture()
		comLimpeza(mundo, function()
		local original = root.CFrame
		local ok = api.sincronizar("encounter-avatar", {
			{ kind = "jogador", userId = 123, x = 10, z = 10 },
		}, "active")
		t.eq(ok, true)
		t.eq(root.Anchored, true)
		t.eq(humanoide.WalkSpeed, 0)
		t.eq(humanoide.JumpPower, 0)
		t.ok(math.abs(root.Position.X - 41.1) < 0.001)
		t.ok(math.abs(root.Position.Z - 48.1) < 0.001)
		api.limpar("encounter-avatar")
		t.eq(root.Anchored, false)
		t.eq(humanoide.WalkSpeed, 16)
		t.eq(humanoide.JumpPower, 50)
		t.eq(root.CFrame, original)
		end)
	end,
	["mantem o avatar imobilizado no resultado ate o retorno"] = function(t)
		local mundo, _, root, humanoide, api = fixture()
		comLimpeza(mundo, function()
		api.sincronizar("encounter-terminal", { { kind = "jogador", userId = 123, x = 9, z = 10 } }, "active")
		local posicao = root.Position
		api.sincronizar("encounter-terminal", { { kind = "jogador", userId = 123, x = 11, z = 10 } }, "victory")
		t.eq(root.Position, posicao)
		t.eq(root.Anchored, true)
		api.limpar("encounter-terminal")
		t.eq(humanoide.WalkSpeed, 16)
		end)
	end,
	["devolve controles mesmo se a raiz estiver fora do personagem ao limpar"] = function(t)
		local mundo, player, root, humanoide, api = fixture()
		comLimpeza(mundo, function()
		local original = root.CFrame
		api.sincronizar("encounter-respawn", { { kind = "jogador", userId = 123, x = 10, z = 10 } }, "active")
		root.Parent = nil
		api.limpar("encounter-respawn")
		t.eq(root.Anchored, false)
		t.eq(root.CFrame, original)
		t.eq(humanoide.WalkSpeed, 16)
		t.eq(humanoide.JumpPower, 50)
		t.ok(math.abs(humanoide.JumpHeight - 7.2) < 0.001)
		t.eq(humanoide.AutoRotate, true)
		root.Parent = player.Character
		t.eq(root.Anchored, false)
		end)
	end,
}
