-- SOMENTE STUDIO: cria MeshParts via AssetService (rede) e Instances.
local ArvoreMundo = require(script.Parent.Parent.Mundo.ArvoreMundo)

local function comLimpeza(pasta, corpo)
	local ok, erro = pcall(corpo)
	pasta:Destroy()
	if not ok then error(erro, 0) end
end

local function parte(pai, nome, tamanho, posicao)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Anchored = nome, tamanho, posicao, true
	p.Parent = pai
	return p
end

return {
	["variante e giro sao deterministicos pela posicao"] = function(t)
		local a, ga = ArvoreMundo.variante("pinheiro", 10, -40)
		local b, gb = ArvoreMundo.variante("pinheiro", 10, -40)
		t.eq(a, b)
		t.eq(ga, gb)
		t.ok(string.match(a, "^Pinheiro[1-5]$") ~= nil, a)
		t.ok(string.match(ArvoreMundo.variante("carvalho", 3, 9), "^CarvalhoB[1-4]$") ~= nil)
		t.eq(ArvoreMundo.variante("palmeira", 0, 0), nil)
	end,
	["arvore pronta fica no chao, sem scripts, e o bloco e a reserva"] = function(t)
		local pasta = Instance.new("Folder")
		comLimpeza(pasta, function()
		pasta.Parent = workspace
		local pronta = ArvoreMundo.criar(pasta, parte, 20, -300, 1, nil, "pinheiro")
		t.ok(pronta:IsA("Model"), "esperava modelo pronto")
		local caixa, tamanho = pronta:GetBoundingBox()
		t.ok(math.abs(caixa.Position.Y - tamanho.Y / 2) < 0.3, "base fora do chao")
		for _, item in ipairs(pronta:GetDescendants()) do
			t.ok(not item:IsA("LuaSourceContainer"))
			if item:IsA("BasePart") then t.eq(item.Anchored, true) end
		end
		local tronco, copa = ArvoreMundo.criar(pasta, parte, 0, 0, 1)
		t.eq(tronco.Name, "Tronco")
		t.eq(copa.Name, "Copa")
		end)
	end,
}
