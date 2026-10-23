-- SOMENTE STUDIO: monta a região e ProximityPrompts reais.
local Service = require(script.Parent.Parent.DescansoAcampamentoService)
local Regiao = require(script.Parent.Parent.RegiaoInicial)

local function comLimpeza(anterior, corpo)
	local ok, erro = pcall(corpo)
	local regiao = workspace:FindFirstChild("RegiaoInicial")
	if regiao and regiao.Parent then regiao:Destroy() end
	if anterior then anterior.Parent = workspace end
	if not ok then error(erro, 0) end
end

return {
	["instala prompts distintos de curto e longo no acampamento"] = function(t)
		local anterior = workspace:FindFirstChild("RegiaoInicial")
		if anterior then anterior.Parent = nil end
		comLimpeza(anterior, function()
		local regiao = Regiao.start({ workspace = workspace })
		local descansos = {}
		local ponto = regiao.Acampamento:FindFirstChild("Fogueira apagada")
		local promptAntigo = Instance.new("ProximityPrompt")
		promptAntigo.Name = "Descanso curto"
		promptAntigo.MaxActivationDistance = 100
		promptAntigo.RequiresLineOfSight = false
		promptAntigo.Parent = ponto
		Service.start({ descansar = function(_, tipo) table.insert(descansos, tipo); return true, { atuais = { pv = 1, pm = 1, pt = 1, pp = 1 } } end })
		local curto, longo = ponto:FindFirstChild("Descanso curto"), ponto:FindFirstChild("Descanso longo")
		t.ok(curto and longo and curto:IsA("ProximityPrompt") and longo:IsA("ProximityPrompt"))
		t.eq(curto.MaxActivationDistance, 10); t.eq(longo.MaxActivationDistance, 10)
		t.eq(curto.RequiresLineOfSight, true, "prompt antigo recebe configuração do servidor")
		t.eq(curto.HoldDuration, 1)
		t.eq(#descansos, 0)
		end)
	end,
	["servidor exige caminho desobstruído até o ponto de descanso"] = function(t)
		local Service = require(script.Parent.Parent.DescansoAcampamentoService)
		local fixture = Instance.new("Folder")
		fixture.Name = "DescansoLinhaDeVisaoSpec"
		fixture.Parent = workspace
		local ok, erro = pcall(function()
		local personagem = Instance.new("Model")
		personagem.Parent = fixture
		local root = Instance.new("Part")
		root.Anchored = true
		root.Position = Vector3.new(5000, 20, 0)
		root.Parent = personagem
		local ponto = Instance.new("Part")
		ponto.Anchored = true
		ponto.Position = Vector3.new(5000, 20, 10)
		ponto.Parent = fixture
		t.eq(Service.temLinhaDeVisao(root, ponto, workspace), true, "o próprio ponto pode ser o primeiro acerto")
		local parede = Instance.new("Part")
		parede.Anchored = true
		parede.Size = Vector3.new(4, 4, 1)
		parede.Position = Vector3.new(5000, 20, 5)
		parede.Parent = fixture
		t.eq(Service.temLinhaDeVisao(root, ponto, workspace), false, "obstáculo entre jogador e fogo bloqueia o pedido")
		end)
		fixture:Destroy()
		if not ok then error(erro, 0) end
	end,
}
