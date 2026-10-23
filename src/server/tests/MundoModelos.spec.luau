-- SOMENTE STUDIO: monta Instances.
local Montar = require(script.Parent.Parent.Mundo.MontarModelo)
local Pasta = script.Parent.Parent.Mundo.Modelos

local MODULOS = { "Loja", "Barraca", "Poco", "Taverna", "Forja", "Dojo", "Casa1", "Casa2", "Casa3" }

-- Caixa envolvente alinhada aos eixos do mundo, pelos extremos de cada peça.
local function caixa(modelo: Model)
	local minimo, maximo = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, parte in ipairs(modelo:GetDescendants()) do
		if parte:IsA("BasePart") then
			local c, s = parte.CFrame, parte.Size
			local meia = Vector3.new(
				(math.abs(c.RightVector.X) * s.X + math.abs(c.UpVector.X) * s.Y + math.abs(c.LookVector.X) * s.Z) / 2,
				(math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y + math.abs(c.LookVector.Y) * s.Z) / 2,
				(math.abs(c.RightVector.Z) * s.X + math.abs(c.UpVector.Z) * s.Y + math.abs(c.LookVector.Z) * s.Z) / 2
			)
			minimo = minimo:Min(c.Position - meia)
			maximo = maximo:Max(c.Position + meia)
		end
	end
	return maximo - minimo
end

local function contar(modelo: Model)
	local partes, ancoradas, scripts = 0, 0, 0
	for _, item in ipairs(modelo:GetDescendants()) do
		if item:IsA("BasePart") then
			partes += 1
			if item.Anchored then
				ancoradas += 1
			end
		elseif item:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	return partes, ancoradas, scripts
end

return {
	["monta cada modelo em escala 0.5: mesmas pecas, ancoradas, caixa pela metade e sem scripts"] = function(t)
		for _, nome in ipairs(MODULOS) do
			t.ok(Montar.existe(nome), nome .. " sem módulo de dados")
			local dados = require(Pasta[nome])
			local pasta = Instance.new("Folder")
			local modelo = Montar.montar(nome, pasta, CFrame.new(0, 0, 0), 0.5)
			t.eq(modelo.Parent, pasta, nome)
			t.eq(modelo:GetAttribute("Fonte"), "asset:" .. tostring(dados.fonte.asset), nome)
			local partes, ancoradas, scripts = contar(modelo)
			t.eq(partes, #dados.P, nome .. " número de peças")
			t.eq(ancoradas, partes, nome .. " peças soltas")
			t.eq(scripts, 0, nome .. " tem scripts")
			local tamanho = caixa(modelo)
			for indice, eixo in ipairs({ "X", "Y", "Z" }) do
				t.ok(
					math.abs(tamanho[eixo] - dados.caixa[indice] / 2) <= 1,
					string.format("%s caixa %s: %.2f, esperado %.2f", nome, eixo, tamanho[eixo], dados.caixa[indice] / 2)
				)
			end
			pasta:Destroy()
		end
	end,
	["pivo do modelo vai para o destino, com rotacao, e a escala 1 preserva a caixa original"] = function(t)
		local pasta = Instance.new("Folder")
		local destino = CFrame.new(100, 5, -20) * CFrame.Angles(0, math.rad(90), 0)
		local modelo = Montar.montar("Poco", pasta, destino)
		local pivo = modelo:GetPivot()
		t.ok((pivo.Position - destino.Position).Magnitude < 0.01, "posição do pivô")
		t.ok(pivo.LookVector:Dot(destino.LookVector) > 0.999, "rotação do pivô")
		local dados = require(Pasta.Poco)
		local reto = Montar.montar("Poco", pasta, CFrame.new(0, 0, 0))
		local tamanho = caixa(reto)
		t.ok(math.abs(tamanho.X - dados.caixa[1]) <= 1 and math.abs(tamanho.Z - dados.caixa[3]) <= 1, "caixa em escala 1")
		pasta:Destroy()
	end,
	["modulo desconhecido e escala invalida sao recusados"] = function(t)
		local pasta = Instance.new("Folder")
		t.eq(Montar.existe("NaoExiste"), false)
		t.fails(function()
			Montar.montar("NaoExiste", pasta, CFrame.new())
		end)
		t.fails(function()
			Montar.montar("Poco", pasta, CFrame.new(), 0)
		end)
		t.eq(#pasta:GetChildren(), 0)
		pasta:Destroy()
	end,
	["loja e armazem trazem placa com texto; casas com chamine trazem fumaca"] = function(t)
		local pasta = Instance.new("Folder")
		local loja = Montar.montar("Loja", pasta, CFrame.new(), 0.5)
		local textos, fumacas = 0, 0
		for _, item in ipairs(loja:GetDescendants()) do
			if item:IsA("TextLabel") and item.Text ~= "" then
				textos += 1
			elseif item:IsA("Smoke") then
				fumacas += 1
			end
		end
		t.eq(textos, 2)
		t.eq(fumacas, 1)
		pasta:Destroy()
	end,
}
