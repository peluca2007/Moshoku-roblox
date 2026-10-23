-- Sigilo da condição é independente do papel de mestre e do desenho do cliente.
local V = {}

function V.escondido(token): boolean
	for _, condicao in token and token.conditions or {} do
		if condicao.id == "escondido" then return true end
	end
	return false
end

function V.podeVer(userId: number, token): boolean
	return token ~= nil and (not V.escondido(token) or token.ownerUserId == userId)
end

return table.freeze(V)
