-- Movimento em grade plana para a primeira fatia autônoma J2.
-- Atores e células fixas do terreno bloqueiam destinos e rotas.
local Movimento = {}
local LIMITE_GRADE = 20

local function coordenadaInteira(valor)
	return type(valor) == "number" and valor % 1 == 0 and valor >= 1 and valor <= LIMITE_GRADE
end

local function chave(x, z)
	return tostring(x) .. ":" .. tostring(z)
end

local function destinosPlanos(inicioX, inicioZ, atores, maximoCasas, celulasBloqueadas)
	if not coordenadaInteira(inicioX) or not coordenadaInteira(inicioZ)
		or type(atores) ~= "table" or type(maximoCasas) ~= "number"
		or maximoCasas % 1 ~= 0 or maximoCasas < 0 or maximoCasas > LIMITE_GRADE
	then
		return nil, "Origem, elenco ou deslocamento inválido."
	end
	local ocupadas = {}
	for _, ator in ipairs(atores) do
		if type(ator) == "table" and coordenadaInteira(ator.x) and coordenadaInteira(ator.z) then
			ocupadas[chave(ator.x, ator.z)] = true
		end
	end
	local origem = chave(inicioX, inicioZ)
	local fila = { { x = inicioX, z = inicioZ, casas = 0, rota = {} } }
	local indice = 1
	local vistos = { [origem] = true }
	local resultado = {}
	while indice <= #fila do
		local atual = fila[indice]
		indice += 1
		if atual.casas < maximoCasas then
			for dx = -1, 1 do
				for dz = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local x, z = atual.x + dx, atual.z + dz
					local id = chave(x, z)
					if coordenadaInteira(x) and coordenadaInteira(z) and not vistos[id]
						and not ocupadas[id] and not (type(celulasBloqueadas) == "table" and celulasBloqueadas[id] == true)
					then
						local rota = table.clone(atual.rota)
						table.insert(rota, { x = x, z = z })
						local destino = { x = x, z = z, casas = atual.casas + 1, rota = rota }
						vistos[id] = true
						resultado[id] = destino
						table.insert(fila, destino)
					end
					end
				end
			end
		end
	end
	return resultado
end

function Movimento.destinos(inicioX, inicioZ, atores, maximoCasas, celulasBloqueadas, celulasDificeis)
	if type(celulasDificeis) ~= "table" or next(celulasDificeis) == nil then
		return destinosPlanos(inicioX, inicioZ, atores, maximoCasas, celulasBloqueadas)
	end
	if not coordenadaInteira(inicioX) or not coordenadaInteira(inicioZ)
		or type(atores) ~= "table" or type(maximoCasas) ~= "number"
		or maximoCasas % 1 ~= 0 or maximoCasas < 0 or maximoCasas > LIMITE_GRADE
	then return nil, "Origem, elenco ou deslocamento inválido." end
	local ocupadas = {}
	for _, ator in ipairs(atores) do
		if type(ator) == "table" and coordenadaInteira(ator.x) and coordenadaInteira(ator.z) then
			ocupadas[chave(ator.x, ator.z)] = true
		end
	end
	local origem = chave(inicioX, inicioZ)
	local inicio = { x = inicioX, z = inicioZ, casas = 0, custoMovimento = 0, rota = {} }
	local abertos, menorCusto, resultado, fechados = { inicio }, { [origem] = 0 }, {}, {}
	while #abertos > 0 do
		-- Grade limitada a 400 casas; a busca linear mantém desempate determinístico.
		local menorIndice = 1
		for indice = 2, #abertos do
			local candidato, menor = abertos[indice], abertos[menorIndice]
			if candidato.custoMovimento < menor.custoMovimento
				or (candidato.custoMovimento == menor.custoMovimento and candidato.casas < menor.casas)
			then menorIndice = indice end
		end
		local atual = table.remove(abertos, menorIndice)
		local atualId = chave(atual.x, atual.z)
		if not fechados[atualId] then
			fechados[atualId] = true
			resultado[atualId] = atual
			if atual.custoMovimento < maximoCasas then
				for dx = -1, 1 do
					for dz = -1, 1 do
						if dx == 0 and dz == 0 then continue end
						local x, z = atual.x + dx, atual.z + dz
						local id = chave(x, z)
						local custoNovo = atual.custoMovimento + (celulasDificeis[id] == true and 2 or 1)
						if not coordenadaInteira(x) or not coordenadaInteira(z) or fechados[id]
							or custoNovo > maximoCasas or (menorCusto[id] ~= nil and custoNovo >= menorCusto[id])
							or ocupadas[id] or (type(celulasBloqueadas) == "table" and celulasBloqueadas[id] == true)
						then continue end
						local rota = table.clone(atual.rota)
						table.insert(rota, { x = x, z = z })
						local destino = { x = x, z = z, casas = atual.casas + 1, custoMovimento = custoNovo, rota = rota }
						menorCusto[id] = custoNovo
						table.insert(abertos, destino)
					end
				end
			end
		end
	end
	return resultado
end

function Movimento.validar(inicioX, inicioZ, alvoX, alvoZ, atores, maximoCasas, celulasBloqueadas, celulasDificeis)
	if not coordenadaInteira(alvoX) or not coordenadaInteira(alvoZ) then
		return nil, "A casa de destino precisa estar dentro da grade."
	end
	if alvoX == inicioX and alvoZ == inicioZ then
		return nil, "Escolha uma casa diferente da posição atual."
	end
	if type(celulasBloqueadas) == "table" and celulasBloqueadas[chave(alvoX, alvoZ)] == true then
		return nil, "Essa casa está bloqueada pelo terreno."
	end
	for _, ator in ipairs(atores or {}) do
		if type(ator) == "table" and ator.x == alvoX and ator.z == alvoZ then
			return nil, "Essa casa já está ocupada."
		end
	end
	local alcancaveis, erro = Movimento.destinos(inicioX, inicioZ, atores, maximoCasas, celulasBloqueadas, celulasDificeis)
	if not alcancaveis then return nil, erro end
	local destino = alcancaveis[chave(alvoX, alvoZ)]
	if not destino then return nil, "O destino não é alcançável neste movimento." end
	return destino
end

-- Seleciona uma casa alcançável que aproxime o ator do alvo mais próximo.
-- Empates são resolvidos por custo do caminho e coordenadas, sem RNG.
function Movimento.aproximar(inicioX, inicioZ, atores, alvos, maximoCasas, celulasBloqueadas, celulasDificeis)
	if type(alvos) ~= "table" or #alvos == 0 then
		return nil, "Não há alvos para aproximar."
	end
	local destinos, erro = Movimento.destinos(inicioX, inicioZ, atores, maximoCasas, celulasBloqueadas, celulasDificeis)
	if not destinos then return nil, erro end
	local melhor
	local function distanciaMinima(x, z)
		local menor
		for _, alvo in ipairs(alvos) do
			if type(alvo) == "table" and coordenadaInteira(alvo.x) and coordenadaInteira(alvo.z) then
				local distancia = math.max(math.abs(x - alvo.x), math.abs(z - alvo.z))
				if menor == nil or distancia < menor then menor = distancia end
			end
		end
		return menor
	end
	local distanciaInicial = distanciaMinima(inicioX, inicioZ)
	if distanciaInicial == nil then return nil, "Nenhum alvo tem posição válida." end
	for _, destino in destinos do
		local distancia = distanciaMinima(destino.x, destino.z)
		local custoMovimento = destino.custoMovimento or destino.casas
		local custoMelhor = if melhor then (melhor.custoMovimento or melhor.casas) else math.huge
		if distancia and distancia < distanciaInicial and (melhor == nil
			or distancia < melhor.distancia
			or (distancia == melhor.distancia and custoMovimento < custoMelhor)
			or (distancia == melhor.distancia and custoMovimento == custoMelhor and destino.x < melhor.x)
			or (distancia == melhor.distancia and custoMovimento == custoMelhor and destino.x == melhor.x and destino.z < melhor.z))
		then
			melhor = { x = destino.x, z = destino.z, casas = destino.casas, custoMovimento = custoMovimento, distancia = distancia, rota = destino.rota }
		end
	end
	if not melhor then return nil, "Nenhuma casa alcançável aproxima o ator do alvo." end
	return melhor
end

return Movimento
