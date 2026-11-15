local D = require(game:GetService("ReplicatedStorage").Shared.AreaDeTestesDados)

local EXTRA = { props = { "Barril", "Casa1" }, gestos = { "mesa/ataque-basico", "mesa/golpe-baixo" } }

return {
	["toda categoria tem itens e ids unicos"] = function(t)
		for _, c in D.CATEGORIAS do
			local lista = D.itens(c.id, EXTRA)
			t.ok(#lista > 0, c.id .. " vazia")
			local vistos = {}
			for _, it in lista do
				t.ok(type(it.id) == "string" and it.id ~= "" and type(it.nome) == "string", c.id .. " item sem id/nome")
				t.ok(not vistos[it.id], c.id .. " repetido: " .. it.id)
				vistos[it.id] = true
			end
		end
	end,
	["categoria desconhecida e vazia"] = function(t)
		t.eq(#D.itens("lixo", EXTRA), 0)
		t.eq(D.categoriaValida("lixo"), false)
	end,
	["sons e vozes trazem asset valido"] = function(t)
		for _, c in { "sons", "vozes" } do
			for _, it in D.itens(c) do
				t.ok(string.match(it.assetId, "^rbxassetid://%d+$") ~= nil, it.id)
			end
		end
	end,
	["validacao recusa lixo"] = function(t)
		t.eq(D.existe("criaturas", "creature/lobo-cinzento"), true)
		t.eq(D.existe("criaturas", "creature/dragao"), false)
		t.eq(D.existe("props", "Barril", EXTRA), true)
		t.eq(D.existe("props", "Barril"), false)
		t.eq(D.existe(nil, "x"), false)
		t.eq(D.existe("arenas", 5), false)
		local function bom(acao, dados) return (D.validarPedido(acao, dados, EXTRA)) end
		t.eq(bom("mostrar", { categoria = "sons", id = "moedas" }), false)
		t.eq(bom("mostrar", { categoria = "criaturas", id = "creature/lobo-cinzento", animacao = "voar" }), false)
		t.eq(bom("mostrar", { categoria = "criaturas", id = "creature/lobo-cinzento", variante = -1 }), false)
		t.eq(bom("mostrar", { categoria = "criaturas", id = "creature/lobo-cinzento", variante = 0 / 0 }), false)
		t.eq(bom("mostrar", { categoria = "props", id = "Barril", animacao = "ataque" }), false)
		t.eq(bom("arena", { id = "lua" }), false)
		t.eq(bom("arena", "cidade"), false)
		t.eq(bom("destruir", {}), false)
		t.eq(bom("girar", { ligado = "sim" }), false)
	end,
	["validacao aceita pedidos bons"] = function(t)
		local ok, limpo = D.validarPedido("mostrar", { categoria = "criaturas", id = "creature/rato-gigante", animacao = "ataque", variante = 1.7 }, EXTRA)
		t.eq(ok, true)
		t.eq(limpo.animacao, "ataque")
		t.eq(limpo.variante, 1)
		t.eq((D.validarPedido("mostrar", { categoria = "props", id = "Casa1" }, EXTRA)), true)
		t.eq((D.validarPedido("arena", { id = "cidade" }, EXTRA)), true)
		t.eq((D.validarPedido("entrar", nil, EXTRA)), true)
	end,
	["origem fica longe da mesa e do mundo"] = function(t)
		t.ok(D.ORIGEM.x >= 1000)
	end,
}
