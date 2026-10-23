-- Grade pura de encanamentos da provacao das comportas.
-- aberturas exporta conjunto numerico: 1=N, 2=E, 3=S, 4=O.
-- gerar(rng) exige rng:NextInteger(min, max), devolve (gradeEmbaralhada, solucao).
-- conexoes devolve (conjunto alcancado, profundidades BFS por chave "i:j"); bacias devolve
-- {linha1, linha3, linha5}. girar devolve uma copia da grade com uma peca girada.

local M = {}
local LADO = 5
local DIRECOES = { 1, 2, 3, 4 }
local PASSO = { { -1, 0 }, { 0, 1 }, { 1, 0 }, { 0, -1 } }
local BASE = {
	tampao = { [1] = true },
	reto = { [1] = true, [3] = true },
	curva = { [1] = true, [2] = true },
	T = { [1] = true, [2] = true, [4] = true },
	cruz = { [1] = true, [2] = true, [3] = true, [4] = true },
}

local function girarDirecao(direcao, vezes)
	return ((direcao - 1 + vezes) % 4) + 1
end

function M.aberturas(celula)
	if type(celula) ~= "table" or BASE[celula.tipo] == nil
		or type(celula.rotacao) ~= "number" or celula.rotacao % 1 ~= 0
		or celula.rotacao < 0 or celula.rotacao > 3 then
		return nil
	end
	local resultado = {}
	for direcao in BASE[celula.tipo] do
		resultado[girarDirecao(direcao, celula.rotacao)] = true
	end
	return resultado
end

local function chave(i, j)
	return tostring(i) .. ":" .. tostring(j)
end

local function gradeValida(grade)
	if type(grade) ~= "table" then return false end
	for i = 1, LADO do
		if type(grade[i]) ~= "table" then return false end
		for j = 1, LADO do
			if M.aberturas(grade[i][j]) == nil then return false end
		end
	end
	return true
end

function M.conexoes(grade)
	if not gradeValida(grade) then return nil, nil end
	local inicio = grade[3][1]
	local ab = M.aberturas(inicio)
	if not ab[4] then return {}, {} end
	local origem = chave(3, 1)
	local alcancadas, profundidades = { [origem] = true }, { [origem] = 0 }
	local fila = { { 3, 1 } }
	local proximo = 1
	while proximo <= #fila do
		local pos = fila[proximo]
		proximo += 1
		local i, j = pos[1], pos[2]
		local daqui = M.aberturas(grade[i][j])
		for _, direcao in DIRECOES do
			if daqui[direcao] then
				local delta = PASSO[direcao]
				local ni, nj = i + delta[1], j + delta[2]
				if ni >= 1 and ni <= LADO and nj >= 1 and nj <= LADO then
					local volta = girarDirecao(direcao, 2)
					local vizinho = M.aberturas(grade[ni][nj])
					local k = chave(ni, nj)
					if vizinho[volta] and not alcancadas[k] then
						alcancadas[k] = true
						profundidades[k] = profundidades[chave(i, j)] + 1
						table.insert(fila, { ni, nj })
					end
				end
			end
		end
	end
	return alcancadas, profundidades
end

function M.bacias(grade)
	local alcancadas = M.conexoes(grade)
	if alcancadas == nil then return nil end
	local resultado = {}
	for indice, linha in { 1, 3, 5 } do
		local ab = M.aberturas(grade[linha][5])
		resultado[indice] = alcancadas[chave(linha, 5)] == true and ab[2] == true
	end
	return resultado
end

function M.girar(grade, i, j)
	if not gradeValida(grade) or type(i) ~= "number" or i % 1 ~= 0 or i < 1 or i > LADO
		or type(j) ~= "number" or j % 1 ~= 0 or j < 1 or j > LADO then
		return nil
	end
	local copia = {}
	for linha = 1, LADO do
		copia[linha] = {}
		for coluna = 1, LADO do
			local peca = grade[linha][coluna]
			copia[linha][coluna] = { tipo = peca.tipo, rotacao = peca.rotacao }
		end
	end
	local celula = copia[i][j]
	celula.rotacao = (celula.rotacao + 1) % 4
	return copia
end

local function sortearArvore(rng)
	local visitado, pai, pilha = {}, {}, { { 3, 1 } }
	visitado[chave(3, 1)] = true
	while #pilha > 0 do
		local pos = pilha[#pilha]
		local vizinhos = {}
		for _, d in DIRECOES do
			local delta = PASSO[d]
			local ni, nj = pos[1] + delta[1], pos[2] + delta[2]
			if ni >= 1 and ni <= LADO and nj >= 1 and nj <= LADO and not visitado[chave(ni, nj)] then
				table.insert(vizinhos, { ni, nj })
			end
		end
		if #vizinhos == 0 then
			table.remove(pilha)
		else
			local proximo = vizinhos[rng:NextInteger(1, #vizinhos)]
			local k = chave(proximo[1], proximo[2])
			visitado[k] = true
			pai[k] = pos
			table.insert(pilha, proximo)
		end
	end
	return pai
end

local function montarSolucao(pai)
	local ligacoes = {}
	local function incluir(i, j)
		ligacoes[chave(i, j)] = ligacoes[chave(i, j)] or {}
	end
	local function caminhoAte(i, j)
		local atual = { i, j }
		while true do
			local k = chave(atual[1], atual[2])
			incluir(atual[1], atual[2])
			if atual[1] == 3 and atual[2] == 1 then break end
			local anterior = pai[k]
			local ai, aj = anterior[1], anterior[2]
			incluir(ai, aj)
			local di, dj = atual[1] - ai, atual[2] - aj
			local direcao = if di == -1 then 1 elseif dj == 1 then 2 elseif di == 1 then 3 else 4
			local volta = girarDirecao(direcao, 2)
			ligacoes[k][volta] = true
			ligacoes[chave(ai, aj)][direcao] = true
			atual = anterior
		end
	end
	for _, linha in { 1, 3, 5 } do caminhoAte(linha, 5) end
	ligacoes[chave(3, 1)][4] = true
	for _, linha in { 1, 3, 5 } do ligacoes[chave(linha, 5)][2] = true end

	local solucao = {}
	for i = 1, LADO do
		solucao[i] = {}
		for j = 1, LADO do
			local mascara = ligacoes[chave(i, j)]
			local tipo = "tampao"
			if mascara then
				local n = 0
				for _ in mascara do n += 1 end
				if n == 2 then
					local reto = (mascara[1] and mascara[3]) or (mascara[2] and mascara[4])
					tipo = if reto then "reto" else "curva"
				elseif n == 3 then tipo = "T"
				elseif n == 4 then tipo = "cruz"
				end
			end
			local rotacao
			for r = 0, 3 do
				local candidata = M.aberturas({ tipo = tipo, rotacao = r })
				local igual = true
				for _, d in DIRECOES do if (candidata[d] == true) ~= (mascara ~= nil and mascara[d] == true) then igual = false end end
				if igual then rotacao = r; break end
			end
			solucao[i][j] = { tipo = tipo, rotacao = rotacao or 0 }
		end
	end
	return solucao
end

function M.gerar(rng)
	local rngType = type(rng)
	if (rngType ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function" then return nil end
	local pai
	for _ = 1, 128 do
		pai = sortearArvore(rng)
		local vizinhosOrigem = 0
		for _, d in DIRECOES do
			local paiDoVizinho = pai[chave(3 + PASSO[d][1], 1 + PASSO[d][2])]
			if paiDoVizinho and paiDoVizinho[1] == 3 and paiDoVizinho[2] == 1 then vizinhosOrigem += 1 end
		end
		if vizinhosOrigem <= 2 then break end
		pai = nil
	end
	if pai == nil then return nil end
	local solucao = montarSolucao(pai)
	local grade = {}
	for i = 1, LADO do
		grade[i] = {}
		for j = 1, LADO do
			local peca = solucao[i][j]
			local rotacao = rng:NextInteger(0, 3)
			-- A bica sempre fica sem abertura oeste: o arranjo inicial nunca esta resolvido.
			if i == 3 and j == 1 then
				for tentativa = 1, 4 do
					if not M.aberturas({ tipo = peca.tipo, rotacao = rotacao })[4] then break end
					rotacao = (rotacao + 1) % 4
				end
			end
			grade[i][j] = { tipo = peca.tipo, rotacao = rotacao }
		end
	end
	return grade, solucao
end

return M
