-- SOMENTE STUDIO: verifica transformação da grade com tipos nativos Roblox.
local Geometria = require(script.Parent.Parent.EncontroAutonomoGeometria)

return {
	["mapeia o centro da grade e as casas extremas com espaçamento único"] = function(t)
		local marco = Instance.new("Part")
		marco.Position = Vector3.new(42, 2.5, 41)
		local centro = Geometria.centro(marco)
		t.eq(centro, Vector3.new(42, 2.5, 49))
		t.eq(Geometria.posicao(centro, 10.5, 10.5), nil, "casas são inteiras")
		t.eq(Geometria.posicao(centro, 10, 10), Vector3.new(41.1, 2.5, 48.1))
		t.eq(Geometria.posicao(centro, 1, 1), Vector3.new(24.9, 2.5, 31.9))
		t.eq(Geometria.posicao(centro, 20, 20), Vector3.new(59.1, 2.5, 66.1))
		t.eq(Geometria.posicao(centro, 21, 10), nil, "fora do mapa não ganha coordenada")
		t.eq(Geometria.posicaoLinha(centro, "x", 0), Vector3.new(24, 2.5, 49))
		t.eq(Geometria.posicaoLinha(centro, "z", 20), Vector3.new(42, 2.5, 67))
		t.eq(Geometria.posicaoLinha(centro, "x", 21), nil, "linha externa não é uma casa")
		t.eq(Geometria.posicaoLinha(centro, "y", 10), nil, "eixo inválido")
		marco:Destroy()
	end,
}
