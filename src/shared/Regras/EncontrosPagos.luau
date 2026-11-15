-- Lista de ids de pagamento já creditados no perfil pessoal (idempotência de recompensarEncontro).
-- Sem poda a lista crescia para sempre e, passado o teto da persistência (2048), o perfil deixava de salvar.
-- Guardamos só os LIMITE mais recentes, em ordem de chegada (o mais novo no fim). A repetição de um pagamento
-- acontece logo depois do original (reenvio, servidor reiniciado), então os recentes bastam; a área da
-- expedição tem ainda a própria flag na run. Puro: sem Instances nem rede.
local EncontrosPagos = {}

EncontrosPagos.LIMITE = 256

function EncontrosPagos.jaPago(lista, id)
	for _, pago in ipairs(lista or {}) do
		if pago == id then return true end
	end
	return false
end

-- Cópia com no máximo `limite` ids, mantendo os mais recentes (fim da lista).
function EncontrosPagos.podar(lista, limite)
	limite = limite or EncontrosPagos.LIMITE
	local origem = lista or {}
	local inicio = math.max(1, #origem - limite + 1)
	local nova = {}
	for i = inicio, #origem do table.insert(nova, origem[i]) end
	return nova
end

-- Nova lista com `id` no fim (sem repetir) e podada ao limite. Não altera a lista recebida.
function EncontrosPagos.registrar(lista, id, limite)
	local nova = {}
	for _, pago in ipairs(lista or {}) do
		if pago ~= id then table.insert(nova, pago) end
	end
	table.insert(nova, id)
	return EncontrosPagos.podar(nova, limite)
end

return table.freeze(EncontrosPagos)
