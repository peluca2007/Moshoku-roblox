-- Votação do grupo nas escolhas da run (PLANO §12). Pura: o dado é injetado.
-- Quem tem a árvore Navegação e Liderança (rank Explorador) vota com peso 2.
-- Empate: rola-se um dado com um lado por opção empatada, e o recibo mostra o resultado.
local Votacao = {}

Votacao.PESO_EXPLORADOR = 2

-- eleitores = { [id] = { explorador = bool, presente = bool|nil } }; ausente não vota.
function Votacao.peso(eleitor)
	if type(eleitor) ~= "table" or eleitor.presente == false then return 0 end
	return if eleitor.explorador == true then Votacao.PESO_EXPLORADOR else 1
end

-- Quem ainda precisa votar (para mostrar "aguardando" e fechar quando todos votarem).
function Votacao.pendentes(opcoes, votos, eleitores)
	local validas = {}
	for _, o in opcoes do validas[o] = true end
	local lista = {}
	for id, e in eleitores do
		if Votacao.peso(e) > 0 and not validas[votos[id]] then table.insert(lista, id) end
	end
	table.sort(lista, function(a, b) return tostring(a) < tostring(b) end)
	return lista
end

-- opcoes = { "id"... } (ordem estável); votos = { [idEleitor] = opcao };
-- rolar(lados) -> inteiro de 1 a lados. Voto de quem não é eleitor ou em opção inexistente é ignorado.
-- Devolve { vencedora, contagem, empatadas, dado } ou nil, motivo.
function Votacao.resolver(opcoes, votos, eleitores, rolar)
	if type(opcoes) ~= "table" or #opcoes < 1 or type(votos) ~= "table" or type(eleitores) ~= "table" then
		return nil, "Votação inválida."
	end
	local contagem = {}
	for _, o in opcoes do contagem[o] = 0 end
	local votou = false
	for id, opcao in votos do
		local peso = Votacao.peso(eleitores[id])
		if peso > 0 and contagem[opcao] ~= nil then
			contagem[opcao] += peso
			votou = true
		end
	end
	if not votou then return nil, "Nenhum voto válido." end
	local maior = 0
	for _, o in opcoes do maior = math.max(maior, contagem[o]) end
	local empatadas = {}
	for _, o in opcoes do
		if contagem[o] == maior then table.insert(empatadas, o) end
	end
	local resultado = { contagem = contagem, empatadas = empatadas }
	if #empatadas == 1 then
		resultado.vencedora = empatadas[1]
		return resultado
	end
	if type(rolar) ~= "function" then return nil, "Empate exige dado." end
	local dado = rolar(#empatadas)
	if type(dado) ~= "number" or dado % 1 ~= 0 or dado < 1 or dado > #empatadas then
		return nil, "Dado inválido."
	end
	resultado.dado = dado
	resultado.vencedora = empatadas[dado]
	return resultado
end

return Votacao
