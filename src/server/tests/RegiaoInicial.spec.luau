-- SOMENTE STUDIO: a região monta Instances do mundo.
local RegiaoInicial = require(script.Parent.Parent.RegiaoInicial)
local TerrenoLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.TerrenoLayout)

return {
	["monta a região pequena, nomeia seus marcos e não duplica no segundo start"] = function(t)
		local workspaceFixture = Instance.new("Folder")
		local primeiro = RegiaoInicial.start({ workspace = workspaceFixture })
		local segundo = RegiaoInicial.start({ workspace = workspaceFixture })
		local entrada = primeiro:FindFirstChild("Entrada da região")
		local bosque = primeiro:FindFirstChild("Bosque")
		local acampamento = primeiro:FindFirstChild("Acampamento")
		local clareira = primeiro:FindFirstChild("Clareira de encontro")
		local marcoClareira = clareira and clareira:FindFirstChild("Marco do encontro")
		local marcoBosque = primeiro:FindFirstChild("Marco do bosque")
		local pontosDeEncontroValidos = marcoClareira ~= nil and marcoBosque ~= nil
			and marcoClareira:GetAttribute("AreaRole") == "encounter-trigger"
			and marcoBosque:GetAttribute("AreaRole") == "encounter-trigger"
			and marcoClareira:GetAttribute("EncounterId") == "region/encounter/clearing"
			and marcoBosque:GetAttribute("EncounterId") == "region/encounter/forest"
			and marcoClareira:FindFirstChildWhichIsA("ProximityPrompt") ~= nil
			and marcoBosque:FindFirstChildWhichIsA("ProximityPrompt") ~= nil
		local lanterna = acampamento and acampamento:FindFirstChild("Lanterna do acampamento")
		local esteira = acampamento and acampamento:FindFirstChild("Esteira de viagem")
		-- A grade tática do J2 saiu do mundo (PLANO §13): a luta acontece na arena da mesa.
		local semGrade = clareira ~= nil and clareira:FindFirstChild("Grade tática") == nil
		local dados = {
			mesmaInstancia = primeiro == segundo,
			umModelo = #workspaceFixture:GetChildren() == 1,
			idRegiao = primeiro:GetAttribute("AreaId"),
			entrada = entrada and entrada:GetAttribute("AreaRole"),
			bosque = bosque and bosque:GetAttribute("AreaRole"),
			acampamento = acampamento and acampamento:GetAttribute("AreaRole"),
			clareira = clareira and clareira:GetAttribute("AreaRole"),
			lanternaTemLuz = lanterna and lanterna:FindFirstChildOfClass("PointLight") ~= nil,
		esteiraSemColisao = esteira and not esteira.CanCollide,
		}
		local terrenoRemovido = primeiro:FindFirstChild("Terreno") == nil
		local caminhosRemovidos = primeiro:FindFirstChild("Caminhos") == nil
		workspaceFixture:Destroy()

		t.eq(dados.mesmaInstancia, true)
		t.eq(dados.umModelo, true)
		t.eq(dados.idRegiao, "region/clareira-inicial")
		t.eq(dados.entrada, "entry")
		t.eq(dados.bosque, "scenery")
		t.eq(dados.acampamento, "landmark")
		t.eq(dados.clareira, "encounter-area")
		t.eq(pontosDeEncontroValidos, true, "dois marcos caminháveis expõem prompts com IDs distintos")
		t.eq(semGrade, true)
		t.eq(lanterna and lanterna:IsA("Part"), true)
		t.eq(dados.lanternaTemLuz, true)
		t.eq(dados.esteiraSemColisao, true)
		t.eq(terrenoRemovido, true)
		t.eq(caminhosRemovidos, true)
	end,
}
