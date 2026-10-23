-- Inventário físico: cada papel está na pilha, em uma mão ou solto.
local F = {}
function F.disponiveis(sala, id, ignorar)
	local usados = 0
	for dono, ficha in sala.maos or {} do
		if ficha == id and tostring(dono) ~= tostring(ignorar) then usados += 1 end
	end
	for _, papel in sala.papeisSoltos or {} do
		if papel.id == id then usados += 1 end
	end
	return math.max(0, ((sala.copias or {})[id] or 1) - usados)
end
return F
