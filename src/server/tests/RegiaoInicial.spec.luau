-- SOMENTE STUDIO: a região monta Instances do mundo.
local RegiaoInicial = require(script.Parent.Parent.RegiaoInicial)
local Terreno = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTerreno)
local Geometria = require(script.Parent.Parent.EncontroAutonomoGeometria)
local TerrenoLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.TerrenoLayout)

return {
	["grade do bosque projeta as casas das miniaturas e avatares"] = function(t)
		local mundo = Instance.new("Folder")
		local regiao = RegiaoInicial.start({ workspace = mundo })
		local arena = regiao:FindFirstChild("Encontro do bosque")
		local grade = arena:FindFirstChild("Grade tática")
		t.eq(arena:GetAttribute("AreaRole"), "encounter-area")
		t.eq(grade:GetAttribute("AreaId"), "region/clareira-inicial/encontro-bosque/grade-tatica")
		t.eq(#grade:GetChildren(), 42)
		t.eq(grade.X_00.Position, Vector3.new(-60, 0.145, 61))
		t.eq(grade.X_20.Position, Vector3.new(-24, 0.145, 61))
		t.eq(grade.Z_00.Position, Vector3.new(-42, 0.145, 43))
		t.eq(grade.Z_20.Position, Vector3.new(-42, 0.145, 79))
		for _, linha in ipairs(grade:GetChildren()) do
			t.eq(linha.CanCollide or linha.CanTouch or linha.CanQuery, false)
			t.eq(TerrenoLayout.altura(linha.Position.X, linha.Position.Z), 0)
		end
		mundo:Destroy()
	end,
	["rochas do bosque ocupam exatamente as casas declaradas no terreno tatico"] = function(t)
		local mundo = Instance.new("Folder")
		local regiao = RegiaoInicial.start({ workspace = mundo })
		local arena = regiao:FindFirstChild("Encontro do bosque")
		local rochas = arena:FindFirstChild("Obstáculos de terreno")
		local marco = regiao:FindFirstChild("Marco do bosque")
		local celulas = Terreno.celulas("region/encounter/forest")
		t.eq(#rochas:GetChildren(), #celulas)
		local centro = Geometria.centro(marco)
		for indice, celula in ipairs(celulas) do
			local rocha = rochas:FindFirstChild("Rocha " .. indice)
			local casa = Geometria.posicao(centro, celula.x, celula.z)
			t.ok(rocha ~= nil and rocha.CanCollide and rocha.Anchored and not rocha.CanTouch)
			t.eq(rocha:GetAttribute("AreaRole"), "movement-obstacle")
			t.eq(rocha:GetAttribute("GridX"), celula.x)
			t.eq(rocha:GetAttribute("GridZ"), celula.z)
			t.eq(rocha.Position.X, casa.X)
			t.eq(rocha.Position.Z, casa.Z)
		end
		mundo:Destroy()
	end,
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
		local grade = clareira and clareira:FindFirstChild("Grade tática")
		local linhaInicial = grade and grade:FindFirstChild("X_00")
		local linhaFinal = grade and grade:FindFirstChild("Z_20")
		local linhasSemColisao = grade ~= nil
		if grade then
			for _, item in ipairs(grade:GetChildren()) do
				if not item:IsA("BasePart") or item.CanCollide or item.CanTouch or item.CanQuery or not item.Anchored then
					linhasSemColisao = false
					break
				end
			end
		end
		local dados = {
			mesmaInstancia = primeiro == segundo,
			umModelo = #workspaceFixture:GetChildren() == 1,
			idRegiao = primeiro:GetAttribute("AreaId"),
			entrada = entrada and entrada:GetAttribute("AreaRole"),
			bosque = bosque and bosque:GetAttribute("AreaRole"),
			acampamento = acampamento and acampamento:GetAttribute("AreaRole"),
			clareira = clareira and clareira:GetAttribute("AreaRole"),
			gradeLinhas = grade and #grade:GetChildren(),
			gradeInicio = linhaInicial and linhaInicial.Position,
			gradeFim = linhaFinal and linhaFinal.Position,
			gradeSemColisao = linhasSemColisao,
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
		t.eq(dados.gradeLinhas, 42)
		t.eq(dados.gradeInicio, Vector3.new(24, 0.145, 49))
		t.eq(dados.gradeFim, Vector3.new(42, 0.145, 67))
		t.eq(dados.gradeSemColisao, true)
		t.eq(lanterna and lanterna:IsA("Part"), true)
		t.eq(dados.lanternaTemLuz, true)
		t.eq(dados.esteiraSemColisao, true)
		t.eq(terrenoRemovido, true)
		t.eq(caminhosRemovidos, true)
	end,
}
