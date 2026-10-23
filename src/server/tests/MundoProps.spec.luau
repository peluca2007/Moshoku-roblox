-- SOMENTE STUDIO: monta Instances e le a hierarquia de Mundo/Modelos.
local Montar = require(script.Parent.Parent.Mundo.MontarModelo)
local Props = require(script.Parent.Parent.Mundo.Props)
local PropsLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.PropsLayout)
local Povoamento = require(game:GetService("ReplicatedStorage").Shared.Mundo.PropsPovoamento)
local RuinasLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.RuinasLayout)
local TerrenoLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.TerrenoLayout)

local function comLimpeza(instancia, corpo)
	local ok, erro = pcall(corpo)
	instancia:Destroy()
	if not ok then error(erro, 0) end
end

return {
	["todo modelo citado em PropsLayout existe em Mundo/Modelos"] = function(t)
		for nome, familia in PropsLayout.FAMILIAS do
			for _, modelo in familia.modelos do
				if not familia.opcional then t.ok(Montar.existe(modelo), nome .. " -> " .. modelo) end
			end
		end
	end,
	["Props.criar monta todos os adereços da vila e da floresta sem scripts"] = function(t)
		for rotulo, lista in { vila = Povoamento.vila(), floresta = PropsLayout.floresta(), ruinas = RuinasLayout.pecas() } do
			local pai = Instance.new("Folder")
			comLimpeza(pai, function()
			local pasta = Props.criar(pai, lista)
			local presentes = {}
			for _, prop in ipairs(lista) do
				local nome = PropsLayout.modelo(prop[3], prop[1], prop[2])
				if nome and Montar.existe(nome) then table.insert(presentes, prop) end
			end
			t.eq(#pasta:GetChildren(), #presentes, rotulo .. " sem modelos ausentes")
			for _, d in pasta:GetDescendants() do
				t.ok(not d:IsA("LuaSourceContainer"), rotulo .. " script em " .. d:GetFullName())
				if d:IsA("BasePart") then
					t.ok(d.Anchored, rotulo .. " peça solta em " .. d:GetFullName())
				end
			end
			for _, modelo in ipairs(pasta:GetChildren()) do
				local indice=modelo:GetAttribute("PropIndice")
				local caixa, tamanho = modelo:GetBoundingBox()
				local prop = lista[indice]
				local esperado = if type(prop[6]) == "number" then prop[6] else TerrenoLayout.altura(prop[1], prop[2])
				t.ok(math.abs(caixa.Position.Y - tamanho.Y / 2 - esperado) < 0.05, "prop apoiado no terreno " .. indice)
				local chapeu, luz = nil, nil
				for _, d in modelo:GetDescendants() do
					if d:IsA("BasePart") then t.ok(d.Material ~= Enum.Material.Grass,"folhagem sem textura Grass") end
					if d:IsA("BasePart") and (d.Name == "Copa" or d.Name == "CopaClara" or d.Name == "Folhas") then
						t.eq(d.Material, Enum.Material.SmoothPlastic, "folhagem facetada")
					elseif d:IsA("BasePart") and d.Name == "ChapeuLuz" then
						t.eq(d.Material, Enum.Material.Neon, "ChapeuLuz Neon")
						chapeu = d
					elseif d:IsA("BasePart") and d.Name == "Luz" then
						t.eq(d.Material, Enum.Material.Neon, "Luz Neon")
						luz = d
					end
					if modelo.Name == "portao" and d:IsA("BasePart") then
						t.ok(not d.CanCollide, "malha agrupada do Portao sem colisão")
					end
				end
				local totalLuzes = 0
				for _, d in modelo:GetDescendants() do if d:IsA("PointLight") then totalLuzes += 1 end end
				if chapeu or luz then t.eq(totalLuzes, 1, "uma PointLight por modelo iluminado") end
				if chapeu then
					local ponto = chapeu:FindFirstChildOfClass("PointLight")
					t.ok(ponto ~= nil, "PointLight no ChapeuLuz")
					if ponto then
						t.eq(ponto.Color, Color3.fromRGB(105, 220, 255), "cor azul-ciano")
						t.ok(ponto.Brightness < 1, "luz fraca no ChapeuLuz")
					end
				end
				if luz then
					local ponto = luz:FindFirstChildOfClass("PointLight")
					if ponto then t.eq(ponto.Range, 14, "alcance da luz âmbar") end
				end
			end
			end)
		end
	end,
	["Props aplica água, luz âmbar e respingo sem criar peças no modelo"] = function(t)
		local chafariz = Instance.new("Model")
		comLimpeza(chafariz, function()
		chafariz.Name = "Chafariz"
		local agua = Instance.new("Model")
		agua.Name = "Agua"
		agua.Parent = chafariz
		local superficie = Instance.new("Part")
		superficie.Name = "Superficie"
		superficie.Size = Vector3.new(8, 2, 8)
		superficie.Position = Vector3.new(0, 8, 0)
		superficie.Material = Enum.Material.Plastic
		superficie.CanCollide = true
		superficie.Parent = agua
		local grupoLuz = Instance.new("Model")
		grupoLuz.Name = "Luz"
		grupoLuz.Parent = chafariz
		local lampada = Instance.new("Part")
		lampada.Name = "Lampada"
		-- Tamanho explícito: o padrão de Part varia entre versões do Studio (altura 1 ou 1,2); topo esperado = 12 + 4/2 = 14.
		lampada.Size = Vector3.new(2, 4, 2)
		lampada.Position = Vector3.new(0, 12, 0)
		lampada.Parent = grupoLuz
		local pecasAntes = 2
		Props.aplicarMateriaisELuzes(chafariz)
		t.eq(superficie.Material, Enum.Material.Glass, "Agua em Glass")
		t.ok(math.abs(superficie.Transparency - 0.35) < 1e-4, "transparência da água")
		t.eq(superficie.Color, Color3.fromRGB(80, 220, 210), "cor turquesa")
		t.ok(not superficie.CanCollide, "água sem colisão")
		t.eq(lampada.Material, Enum.Material.Neon, "grupo Luz em Neon")
		local luz = lampada:FindFirstChildOfClass("PointLight")
		t.ok(luz ~= nil, "grupo Luz recebe PointLight")
		if luz then t.eq(luz.Color, Color3.fromRGB(255, 177, 92), "PointLight âmbar") end
		local attachment = superficie:FindFirstChild("Respingo") or lampada:FindFirstChild("Respingo")
		local totalPecas, totalEmissores = 0, 0
		for _, d in chafariz:GetDescendants() do
			if d:IsA("BasePart") then totalPecas += 1 end
			if d:IsA("ParticleEmitter") then totalEmissores += 1 end
		end
		t.eq(totalPecas, pecasAntes, "respingo não adiciona BasePart")
		t.eq(totalEmissores, 1, "um emissor de respingos")
		t.ok(attachment ~= nil, "Attachment no topo do modelo")
		if attachment then
			t.ok(math.abs(attachment.WorldPosition.Y - 14) < 0.01, "topo real do modelo")
			local emissor = attachment:FindFirstChildOfClass("ParticleEmitter")
			t.ok(emissor ~= nil, "emissor ligado ao Attachment")
			if emissor then
				t.ok(emissor.Rate > 0 and emissor.Rate <= 5, "taxa baixa")
				t.ok(emissor.Lifetime.Max <= 1, "vida curta")
				t.ok(emissor.Acceleration.Y < 0, "aceleração da gravidade")
				t.ok(emissor.Speed.Max <= 2, "velocidade baixa")
			end
		end
		end)
	end,
}
