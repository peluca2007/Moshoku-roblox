-- Projeção da iniciativa já filtrada pelo servidor; não altera a ordem real.
local OrdemVisivel = {}

function OrdemVisivel.listar(ordem: { string }, turnId: string?, tokens: { any }): { any }
	local porId = {}
	for _, token in tokens do porId[token.id] = token end
	local inicio = 1
	for i, id in ordem do
		if id == turnId then inicio = i; break end
	end
	local lista, vistos = {}, {}
	for deslocamento = 0, #ordem - 1 do
		local id = ordem[(inicio + deslocamento - 1) % #ordem + 1]
		local token = porId[id]
		if token and not vistos[id] then
			vistos[id] = true
			table.insert(lista, token)
		end
	end
	return lista
end

return OrdemVisivel
