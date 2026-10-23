-- Texto do resultado confirmado; não deduz vencedor de PV nem concede recursos.
local A = {}
function A.resumir(dados)
	if type(dados) ~= "table" then return nil end
	if dados.modo == "duelo" and (dados.resultado == "duelo" or dados.resultado == "empate") then
		return { titulo = "FIM DO PVP", detalhe = if dados.vencedor then dados.vencedor .. " venceu!" else "Empate • ninguém ficou de pé.", cor = "DESTAQUE" }
	elseif dados.resultado == "vitoria" then
		return { titulo = "VITÓRIA", detalhe = "O grupo superou o desafio.", cor = "SUCESSO" }
	elseif dados.resultado == "derrota" then
		return { titulo = "DERROTA", detalhe = "O grupo caiu. Reúna-se e tente outra estratégia.", cor = "PERIGO" }
	end
	return nil
end
return table.freeze(A)
