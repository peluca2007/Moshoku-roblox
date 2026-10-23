-- Estados temporários que não são condições do catálogo. Puro: estado e eventos
-- de turno são fornecidos pelo serviço. Fontes separadas evitam remoção cruzada.
local E = {}
function E.novo()
	return { efeitos = {}, ordem = 0 }
end
function E.definir(s, tokenId, nome, valor, fonteId, duracao, rodada)
	s.ordem += 1
	s.efeitos[tokenId] = s.efeitos[tokenId] or {}
	local d = duracao or {}
	local e = { nome = nome, valor = valor, fonteId = fonteId, ordem = s.ordem,
		gatilho = if d.de == "conjurador" then fonteId else tokenId,
		inicio = d.inicio == true, restante = d.turnos or 1, fase = "aplicada",
		rodadaFim = if d.rodadas then rodada + d.rodadas else nil,
		semPrazo = duracao == nil }
	s.efeitos[tokenId][nome .. ":" .. fonteId] = e
	return e
end
function E.entrada(s, tokenId, nome)
	local maisRecente
	for _, e in s.efeitos[tokenId] or {} do
		if e.nome == nome and (not maisRecente or e.ordem > maisRecente.ordem) then maisRecente = e end
	end
	return maisRecente
end
function E.valor(s, tokenId, nome)
	local valor
	for _, e in s.efeitos[tokenId] or {} do
		if e.nome == nome then
			if type(e.valor) == "number" then valor = math.max(valor or 0, e.valor) else valor = e.valor end
		end
	end
	return valor
end
function E.remover(s, tokenId, nome, fonteId)
	for chave, e in s.efeitos[tokenId] or {} do
		if e.nome == nome and (fonteId == nil or e.fonteId == fonteId) then s.efeitos[tokenId][chave] = nil end
	end
end
function E.avancar(s, anteriorId, novoId, rodada)
	local alterados = {}
	for tokenId, efeitos in s.efeitos do
		for chave, e in efeitos do
			local fim = e.rodadaFim ~= nil and rodada >= e.rodadaFim
			if not e.semPrazo and not e.rodadaFim then
				if e.inicio and e.gatilho == novoId then fim = true
				elseif e.fase == "ativa" and e.gatilho == anteriorId then
					e.restante -= 1
					if e.restante <= 0 then fim = true else e.fase = if e.gatilho == novoId then "ativa" else "aplicada" end
				elseif e.fase == "aplicada" and e.gatilho == novoId then e.fase = "ativa" end
			end
			if fim then efeitos[chave] = nil; alterados[tokenId] = true end
		end
	end
	return alterados
end
function E.nomes(s, tokenId)
	local lista, vistos = {}, {}
	for _, e in s.efeitos[tokenId] or {} do
		if not vistos[e.nome] then vistos[e.nome] = true; table.insert(lista, e.nome) end
	end
	table.sort(lista)
	return lista
end
return E
