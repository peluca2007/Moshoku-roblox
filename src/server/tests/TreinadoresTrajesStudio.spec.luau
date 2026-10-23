-- SOMENTE STUDIO: verifica encaixes e propriedades nos modelos importados disponíveis.
local Aparencia = require(script.Parent.Parent.Mundo.TreinadoresAparencia)
local Shared = game:GetService("ReplicatedStorage").Shared
local Dados = require(Shared.Mundo.TreinadoresAparenciaDados)
local Visual = require(Shared.Aparencia.Visual)
local Montar = require(script.Parent.Parent.Mundo.MontarModelo)

local ESPERADOS = {
	["furtividade-e-armadilhas"] = {
		{ "LadinoCapuz", "Head", 0, 0, 0 },
		{ "LadinoMascara", "Head", 0, 0, 0 },
		{ "LadinoCapa", "UpperTorso", 0, 0.8, 0.5 },
		{ "LadinoCinto", "LowerTorso", 0, 0, 0 },
	},
	agua = {
		{ "MestraTiara", "Head", 0, 0, 0 },
		{ "MestraManto", "UpperTorso", 0, 0.8, 0.5 },
		{ "MestraObi", "LowerTorso", 0, 0, 0 },
		{ "MestraCajado", "RightHand", 0, -0.1, -0.3 },
	},
}

local function montarCorpo()
	local corpo = Instance.new("Model")
	corpo.Name = "CorpoDeTeste"
	for _, nome in { "Head", "UpperTorso", "LowerTorso", "RightHand", "LeftHand" } do
		local parte = Instance.new("Part")
		parte.Name = nome
		parte.Size = Vector3.one
		parte.CFrame = CFrame.new(0, 5, 0)
		parte.Parent = corpo
	end
	return corpo
end

return {
	["T1 contratos de encaixe e escala de avatar preservada"] = function(t)
		for arvore, esperados in ESPERADOS do
			local reais = Aparencia.TRAJES[arvore]
			t.eq(#reais, #esperados)
			for i, contrato in esperados do
				local real = reais[i]
				t.eq(real.modulo, contrato[1])
				t.eq(real.parte, contrato[2])
				t.eq(real.offset, CFrame.new(contrato[3], contrato[4], contrato[5]))
			end
		end

		local ladino = Instance.new("HumanoidDescription")
		local mestra = Instance.new("HumanoidDescription")
		Aparencia.descrever(ladino, "furtividade-e-armadilhas")
		Aparencia.descrever(mestra, "agua")
		t.ok(ladino.HeadColor ~= mestra.HeadColor)
		t.eq(ladino.LeftArmColor, ladino.HeadColor)
		t.eq(ladino.RightArmColor, ladino.HeadColor)
		t.eq(mestra.LeftArmColor, mestra.HeadColor)
		t.eq(mestra.RightArmColor, mestra.HeadColor)
		t.ok(mestra.HeadColor ~= mestra.TorsoColor)
		for arvore, descricao in { ["furtividade-e-armadilhas"] = ladino, agua = mestra } do
			local perfil = Dados.POR_ARVORE[arvore]
			local esperada = Visual.descrever(perfil.aparencia, perfil.raceId)
			for _, campo in { "HeightScale", "WidthScale", "DepthScale", "HeadScale", "HeadColor", "TorsoColor" } do
				t.eq(descricao[campo], esperada[campo], campo)
			end
			t.eq(descricao.BodyTypeScale, 0)
			t.eq(descricao.ProportionScale, 0)
			esperada:Destroy()
		end
		ladino:Destroy()
		mestra:Destroy()
	end,

	["T1 trajes presentes ficam sem colisao, consultaveis ou massa"] = function(t)
		local corpo = montarCorpo()
		local ok, erro = pcall(function()
			-- Ordem explícita: a cor da cabeça é a da última árvore aplicada, e a iteração de dicionário não tem ordem garantida.
			for _, arvore in { "furtividade-e-armadilhas", "agua" } do
				Aparencia.aplicar(corpo, arvore)
			end
			local cabeca = corpo:FindFirstChild("Head")
			t.eq(cabeca.Color, Visual.cor(Dados.POR_ARVORE.agua.aparencia.cores.pele))
			t.eq(cabeca:FindFirstChild("face"), nil)
			local rosto = corpo:FindFirstChild("AparenciaMoshoku")
			t.ok(rosto and rosto:FindFirstChild("olhos1") ~= nil)
			local encontrados = 0
			for _, traje in corpo:GetChildren() do
				if traje:IsA("Model") then
					for _, contrato in ESPERADOS["furtividade-e-armadilhas"] do
						if traje.Name == contrato[1] then encontrados += 1 end
					end
					for _, contrato in ESPERADOS.agua do
						if traje.Name == contrato[1] then encontrados += 1 end
					end
					for _, peca in traje:GetDescendants() do
						if peca:IsA("BasePart") then
							t.eq(peca.Anchored, false)
							t.eq(peca.CanCollide, false)
							t.eq(peca.CanQuery, false)
							t.eq(peca.CanTouch, false)
							t.eq(peca.Massless, true)
							t.ok(peca:FindFirstChildOfClass("WeldConstraint") ~= nil)
						end
						if peca:IsA("BasePart") then
							local grupoGota = if peca.Name == "Gota" then peca else peca:FindFirstAncestor("Gota")
							local grupoOrbe = if peca.Name == "Orbe" then peca else peca:FindFirstAncestor("Orbe")
							if grupoGota then t.eq(peca.Material, Enum.Material.Glass) end
							if grupoOrbe then t.eq(peca.Material, Enum.Material.Neon) end
							if not grupoGota and not grupoOrbe then
								local nome = string.lower(peca.Name)
								if nome == "ferro" or string.find(nome, "lamina", 1, true) or string.find(nome, "lâmina", 1, true) then
									t.eq(peca.Material, Enum.Material.Metal)
								elseif string.find(nome, "dourad", 1, true) or string.find(nome, "ouro", 1, true) then
									t.eq(peca.Material, Enum.Material.SmoothPlastic)
									t.ok(math.abs(peca.Reflectance - 0.1) < 1e-4, "reflexo dourado (float32)")
								else
									t.eq(peca.Material, Enum.Material.SmoothPlastic)
								end
							end
							if grupoOrbe and traje.Name == "MestraCajado" then
								local luzes = 0
								for _, descendente in grupoOrbe:GetDescendants() do
									if descendente:IsA("PointLight") and descendente.Name == "BrilhoOrbe" then
										luzes += 1
										t.ok(descendente.Brightness <= 0.5)
									end
								end
								t.eq(luzes, 1, "uma PointLight por Orbe")
							end
						end
					end
				end
			end
			local importados = 0
			for _, grupo in ESPERADOS do
				for _, contrato in grupo do
					if Montar.existe(contrato[1]) then importados += 1 end
				end
			end
			t.eq(encontrados, importados, "todo modelo importado deve ser anexado")
		end)
		corpo:Destroy()
		if not ok then error(erro) end
	end,
}
