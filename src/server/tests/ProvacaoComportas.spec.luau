local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Regras.ProvacaoComportas)

local function rngComSemente(semente)
	local estado = semente
	return {
		NextInteger = function(_, minimo, maximo)
			estado = (estado * 48271) % 2147483647
			return minimo + (estado % (maximo - minimo + 1))
		end,
	}
end

local function igualMascara(a, b)
	for _, direcao in { 1, 2, 3, 4 } do
		if a[direcao] ~= b[direcao] then return false end
	end
	return true
end

return {
	["100 sementes produzem grades validas com as tres bacias resolvidas"] = function(t)
		local assinaturas = {}
		for semente = 1, 100 do
			local grade, solucao = C.gerar(rngComSemente(semente))
			t.ok(grade ~= nil and solucao ~= nil, "semente " .. semente)
			local bacias = C.bacias(solucao)
			t.eq(#bacias, 3)
			for _, aberta in bacias do t.eq(aberta, true, "solucao semente " .. semente) end
			local ligadas, profundidades = C.conexoes(solucao)
			t.ok(ligadas["3:1"])
			t.eq(profundidades["3:1"], 0, "origem BFS")
			for _, linha in { 1, 3, 5 } do
				local saida = tostring(linha) .. ":5"
				t.ok(ligadas[saida], "saida " .. linha)
				t.ok(profundidades[saida] >= 4, "profundidade da saida " .. linha)
			end
			for chave, _ in ligadas do t.ok(type(profundidades[chave]) == "number", "profundidade " .. chave) end
			local inicio = C.aberturas(grade[3][1])
			t.eq(inicio[4], nil, "bica embaralhada semente " .. semente)
			local semLigacoes, semProfundidades = C.conexoes(grade)
			t.eq(semLigacoes["3:1"], nil); t.eq(semProfundidades["3:1"], nil)
			for _, aberta in C.bacias(grade) do
				-- A bica sem abertura oeste impede qualquer fluxo inicial.
				t.eq(aberta, false, "grade embaralhada semente " .. semente)
			end
			local partes = {}
			for i = 1, 5 do for j = 1, 5 do
				local p = solucao[i][j]
				t.ok(C.aberturas(p) ~= nil)
				table.insert(partes, p.tipo .. p.rotacao)
			end end
			assinaturas[table.concat(partes, ",")] = true
		end
		local distintas = 0
		for _ in assinaturas do distintas += 1 end
		t.ok(distintas > 10, "gerador deve variar entre sementes")
	end,
	["aberturas representam orientacoes base e cada giro e copia pura"] = function(t)
		local peca = { tipo = "curva", rotacao = 0 }
		local norteLeste = C.aberturas(peca)
		t.eq(norteLeste[1], true); t.eq(norteLeste[2], true)
		t.eq(norteLeste[3], nil); t.eq(norteLeste[4], nil)
		local grade, solucao = C.gerar(rngComSemente(531))
		local original = grade[3][1].rotacao
		local girada = C.girar(grade, 3, 1)
		t.eq(grade[3][1].rotacao, original)
		t.eq(girada[3][1].rotacao, (original + 1) % 4)
		local restaurada = girada
		for _ = 1, 3 do restaurada = C.girar(restaurada, 3, 1) end
		t.eq(igualMascara(C.aberturas(restaurada[3][1]), C.aberturas(grade[3][1])), true)
		local bloqueada = C.girar(solucao, 3, 1)
		for _, aberta in C.bacias(solucao) do t.eq(aberta, true) end
		for _, aberta in C.bacias(bloqueada) do t.eq(aberta, false) end
	end,
	["tipos invalidos e indices fora da grade sao recusados"] = function(t)
		local grade = C.gerar(rngComSemente(14))
		t.eq(C.aberturas({ tipo = "inventado", rotacao = 0 }), nil)
		t.eq(C.aberturas({ tipo = "reto", rotacao = 4 }), nil)
		local invalida, profInvalida = C.conexoes({})
		t.eq(invalida, nil); t.eq(profInvalida, nil)
		t.eq(C.girar(grade, 0, 1), nil)
		t.eq(C.girar(grade, 1, 6), nil)
		t.eq(C.girar(grade, 1.5, 1), nil)
		t.eq(C.gerar(nil), nil)
	end,
}
