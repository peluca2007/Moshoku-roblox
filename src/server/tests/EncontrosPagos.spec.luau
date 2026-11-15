local P = require(game:GetService("ReplicatedStorage").Shared.Regras.EncontrosPagos)

return {
	["registrar nunca passa do limite e guarda os mais recentes"] = function(t)
		local lista = {}
		for i = 1, P.LIMITE + 40 do lista = P.registrar(lista, "e" .. i) end
		t.eq(#lista, P.LIMITE)
		t.eq(lista[#lista], "e" .. (P.LIMITE + 40))
		t.eq(lista[1], "e41")
		t.ok(not P.jaPago(lista, "e40"), "o mais antigo saiu")
		t.ok(P.jaPago(lista, "e" .. (P.LIMITE + 40)))
	end,
	["pagamento recente continua idempotente"] = function(t)
		local lista = P.registrar(P.registrar({}, "a"), "b")
		t.ok(P.jaPago(lista, "a"))
		local de = P.registrar(lista, "a")
		t.eq(#de, 2) -- não duplica
		t.eq(de[2], "a")
		t.eq(#lista, 2) -- não altera a lista recebida
		t.eq(lista[2], "b")
	end,
	["podar perfil antigo grande mantém o fim e cabe na persistência"] = function(t)
		local antiga = {}
		for i = 1, 2048 do antiga[i] = "x" .. i end
		local podada = P.podar(antiga)
		t.eq(#podada, P.LIMITE)
		t.eq(podada[#podada], "x2048")
		t.ok(P.LIMITE <= 2048, "limite acima do teto da persistência")
		t.eq(#P.podar(nil), 0)
		t.eq(#P.podar({ "a" }), 1)
	end,
}
