local R = require(game:GetService("ReplicatedStorage").Shared.Regras.RecompensaEncontro)

return {
	["valores do Apêndice G batem com recompensa.test.ts"] = function(t)
		local valores = {}
		for patamar = 1, 6 do valores[patamar] = R.valorCriatura({ patamar = patamar, papel = "padrao", arquetipo = "bruto", subArquetipo = "besta" }) end
		for i, esperado in ipairs({ 10, 20, 40, 80, 160, 320 }) do t.eq(valores[i], esperado) end
		t.eq(R.valorCriatura({ patamar = 3, papel = "lacaio", arquetipo = "bruto", subArquetipo = "besta" }), 20)
		t.eq(R.valorCriatura({ patamar = 3, papel = "chefe", arquetipo = "bruto", subArquetipo = "besta" }), 160)
		t.eq(R.valorCriatura({ patamar = 2, papel = "padrao", arquetipo = "bruto", subArquetipo = "besta", temImunidade = true }), 40)
		t.eq(R.valorCriatura({ patamar = 4, papel = "padrao", arquetipo = "conjurador", subArquetipo = "dragonico" }), 240)
	end,
	["moeda e valor total são determinísticos com RNG injetado"] = function(t)
		local criaturas = {}
		for _ = 1, 4 do table.insert(criaturas, { patamar = 2, papel = "padrao", arquetipo = "bruto", subArquetipo = "besta" }) end
		local a = R.gerar(criaturas, function() return 0 end)
		local b = R.gerar(criaturas, function() return 0 end)
		t.eq(a.valorTotal, 80) t.eq(a.moedas, 0)
		t.eq(a.valorTotal, b.valorTotal) t.eq(a.moedas, b.moedas)
		t.eq(#a.tralhas, #b.tralhas) t.eq(a.tralhas[1].preco, b.tralhas[1].preco)
		local humanoide = R.gerar({ { patamar = 4, papel = "padrao", subArquetipo = "humanoide" } }, function() return 0 end)
		t.eq(humanoide.moedas, 48)
	end,
}
