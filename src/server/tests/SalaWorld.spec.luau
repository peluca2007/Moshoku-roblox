-- SOMENTE STUDIO: a sala contém geometria Roblox.
local SalaWorld = require(script.Parent.Parent.SalaWorld)

return {
	["abre passagem física oeste sem remover o abrigo e monta uma só sala"] = function(t)
		local workspaceFixture = Instance.new("Folder")
		local sala = SalaWorld.create({ workspace = workspaceFixture })
		local repetida = SalaWorld.create({ workspace = workspaceFixture })
		local norte = sala and sala:FindFirstChild("ParedeLateralOesteNorte")
		local sul = sala and sala:FindFirstChild("ParedeLateralOesteSul")
		local viga = sala and sala:FindFirstChild("VigaPortaOeste")
		local leste = sala and sala:FindFirstChild("ParedeLateralLeste")
		local registro = {
			idempotente = sala == repetida and #workspaceFixture:GetChildren() == 1,
			norte = norte and norte.Position.Z + norte.Size.Z / 2,
			sul = sul and sul.Position.Z - sul.Size.Z / 2,
			viga = viga and viga.Position.Y - viga.Size.Y / 2,
			leste = leste and leste.Size.Z,
		}
		workspaceFixture:Destroy()

		t.eq(registro.idempotente, true)
		t.eq(registro.norte, -7)
		t.eq(registro.sul, 7)
		t.eq(registro.viga, 10.5)
		t.eq(registro.leste, 40)
	end,
}
