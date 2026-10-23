-- Equipamento transitório de combate. O objeto conserva a referência ao item:
-- pegar/encerrar restaura, sem copiar itens ou confiar em inventário do cliente.
local D = {}
function D.arma(ficha)
	for _, item in (ficha and ficha.construction.inventory) or {} do
		if item.type == "arma" and item.equipped and not item.a16Indisponivel then return item end
	end
	return nil
end
function D.equipamento(ficha, escolha)
	for _, item in (ficha and ficha.construction.inventory) or {} do
		local escudo = type(item.name) == "string" and string.find(string.lower(item.name), "escudo", 1, true)
		if item.equipped and not item.a16Indisponivel and ((escolha == "escudo" and escudo) or (escolha ~= "escudo" and item.type == "arma")) then return item end
	end
	return nil
end
function D.largar(item)
	if item then item.equipped = false; item.a16Indisponivel = true end
end
function D.pegar(ficha, item)
	for _, outro in ficha.construction.inventory or {} do
		if outro.type == "arma" then outro.equipped = false end
	end
	item.a16Indisponivel = nil; item.equipped = true
end
function D.danoDaCriatura(dano, desarmado)
	return if desarmado then math.max(1, math.floor(dano / 2)) else dano
end
return D
