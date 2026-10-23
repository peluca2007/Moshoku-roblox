-- Geometria e PV de barreiras. Puro; linha/cellKey são injetados.
local B = {}
function B.intercepta(zonas, linha, chave, fisico)
	if not fisico then return nil end
	for _, casa in linha do
		for _, zona in zonas do
			if zona.pv and zona.pv > 0 and zona.casas[chave(casa[1], casa[2])] then return zona end
		end
	end
	return nil
end
function B.ferir(zona, dano)
	zona.pv = math.max(0, zona.pv - math.max(0, dano))
	return zona.pv == 0
end
return B
