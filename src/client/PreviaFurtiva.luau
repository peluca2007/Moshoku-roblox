-- Intenção local de consulta; nunca envia comandos nem autoriza furtividade.
local P, ouvintes, atual = {}, {}, nil
function P.set(id)
	if atual == id then return end
	atual = id
	for _, fn in ouvintes do fn(id) end
end
function P.get() return atual end
function P.onChange(fn)
	table.insert(ouvintes, fn)
	return function() local i = table.find(ouvintes, fn); if i then table.remove(ouvintes, i) end end
end
return P
