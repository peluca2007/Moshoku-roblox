local Shared = game:GetService("ReplicatedStorage").Shared
local Marcadores = require(Shared.Regras.MarcadoresOrientacao)

return {
	["glifos seguem elegibilidade por tipo e estado"] = function(t)
		local estado = { run = { plano = { modo = "semArvore" }, diasRestantes = 2 } }
		t.eq(Marcadores.glifo({ id = "vila-1", tipo = "treinador", disponivel = true }, estado), "!")
		t.eq(Marcadores.glifo({ tipo = "treinador", disponivel = false }, estado), nil)
		t.eq(Marcadores.glifo({ id = "vila-1", tipo = "treinador", disponivel = true }, { run = { plano = { modo = "semArvore" }, diasRestantes = 2 }, provacao = { estado = "em-curso", npcId = "vila-1" } }), nil)
		t.eq(Marcadores.glifo({ id = "vila-2", tipo = "treinador", disponivel = true }, { run = { plano = { modo = "semArvore" }, diasRestantes = 2 }, provacao = { estado = "em-curso", npcId = "vila-1" } }), nil)
		t.eq(Marcadores.glifo({ tipo = "treinador", disponivel = true }, { run = { plano = { modo = "semArvore" }, diasRestantes = 0 } }), nil)
		t.eq(Marcadores.glifo({ tipo = "treinador", disponivel = true }, { run = { plano = { modo = "semArvore" }, diasRestantes = 2, fim = { motivo = "final" } } }), nil)
		estado.run.plano.escolhida = "agua"
		t.eq(Marcadores.glifo({ tipo = "treinador", disponivel = true }, estado), nil)
		t.eq(Marcadores.glifo({ tipo = "missao", concluir = true, novo = true }, estado), "?")
		t.eq(Marcadores.glifo({ tipo = "missao", novo = true }, estado), "!")
		t.eq(Marcadores.glifo({ tipo = "loja", novo = true }, estado), "!")
		t.eq(Marcadores.glifo({ tipo = "loja", novo = false }, estado), nil)
	end,
	["seta oculta alvos dentro da viewport e prende fora na borda"] = function(t)
		t.eq(Marcadores.borda(20, 10, 5, 800, 600), nil)
		t.eq(Marcadores.borda(390, 0, 5, 800, 600, 20), nil, "margem não muda visibilidade dentro da tela")
		local seta = Marcadores.borda(500, 100, 5, 800, 600, 20)
		t.ok(seta ~= nil)
		t.eq(seta.x, 780)
		t.ok(math.abs(seta.y - 376) < 0.01)
		t.eq(Marcadores.borda(500, 0, 5, 800, 600, 20).rotacao, 0, "▶ aponta para a direita")
		t.eq(Marcadores.borda(0, 0, -1, 800, 600).y, 24)
	end,
	["projeção para trás inverte direção e vetor zero usa fallback"] = function(t)
		local atras = Marcadores.borda(100, 0, -1, 800, 600, 20)
		t.eq(atras.x, 20)
		local zero = Marcadores.borda(0, 0, 0, 800, 600, 20)
		t.ok(zero ~= nil)
		t.eq(zero.y, 20)
	end,
	["dimensões inválidas não produzem seta"] = function(t)
		t.eq(Marcadores.borda(1, 1, 1, 0, 600), nil)
		t.eq(Marcadores.borda("x", 1, 1, 800, 600), nil)
	end,
}
