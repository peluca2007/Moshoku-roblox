local L = require(game:GetService("ReplicatedStorage").Shared.Regras.Loja)

local espada = { id = "arma_espada-curta", name = "Espada Curta", category = "arma", type = "arma", description = "d", guildRankRequired = "F", baseDie = "d6", price = 15, aVenda = true }
local armaduraB = { id = "armadura_x", name = "Placas", category = "armadura", type = "armadura", description = "d", guildRankRequired = "B", price = 400, aVenda = true, acBonus = 6 }
local presa = { id = "tralha_presa", name = "Presa de Lobo", category = "tralha", type = "geral", description = "d", guildRankRequired = "F", price = 10, aVenda = true }
local pocao = { id = "pocao_menor", name = "Poção Menor de Cura", category = "pocao", type = "geral", description = "d", guildRankRequired = "F", price = 25, aVenda = true }
local contrabando = { id = "veneno_x", name = "Fel", category = "veneno", type = "geral", description = "d", guildRankRequired = "F", price = 80, aVenda = true, disponibilidade = "restrito" }
local reliquia = { id = "rel", name = "Lança", category = "arma", type = "arma", description = "d", guildRankRequired = "F", aVenda = false, disponibilidade = "inestimavel" }

return {
	["prateleira respeita rank de guilda, disponibilidade e preco"] = function(t)
		t.eq(L.naPrateleira(espada, "F"), true)
		t.eq(L.naPrateleira(espada), true) -- rank inicial F
		t.eq(L.naPrateleira(armaduraB, "F"), false)
		t.eq(L.naPrateleira(armaduraB, "B"), true)
		t.eq(L.naPrateleira(armaduraB, "S"), true)
		t.eq(L.naPrateleira(contrabando, "S"), false)
		t.eq(L.naPrateleira(reliquia, "S"), false)
		t.eq(L.naPrateleira({ price = 0, name = "x" }, "F"), false)
		t.eq(L.naPrateleira(nil, "F"), false)
	end,
	["lista fica ordenada por categoria, preco e nome e esconde o que nao pode comprar"] = function(t)
		local lista = L.listar({ presa, pocao, armaduraB, espada, contrabando, reliquia }, "F")
		t.eq(#lista, 3)
		t.eq(lista[1].id, "arma_espada-curta")
		t.eq(lista[2].id, "pocao_menor")
		t.eq(lista[3].id, "tralha_presa")
		t.eq(#L.listar({ presa, pocao, armaduraB, espada }, "B"), 4)
	end,
	["comprar debita o ouro e devolve o item no formato do inventario"] = function(t)
		local ouro, inv = L.comprar(40, espada, "F")
		t.eq(ouro, 25)
		t.eq(inv.name, "Espada Curta")
		t.eq(inv.baseDie, "d6")
		t.eq(inv.id, nil)
		local sem, _, motivo = L.comprar(14, espada, "F")
		t.eq(sem, nil)
		t.eq(motivo, "Ouro insuficiente.")
		t.eq((L.comprar(15, espada, "F")), 0)
		t.eq((L.comprar(1000, armaduraB, "F")), nil)
		t.eq((L.comprar(-1, espada, "F")), nil)
		t.eq((L.comprar(1.5, espada, "F")), nil)
		t.eq((L.comprar(100, reliquia, "S")), nil)
	end,
	["venda paga 100% de tralha e 50% dos demais, e nada de reliquia"] = function(t)
		t.eq(L.valorDeVenda(presa), 10)
		t.eq(L.valorDeVenda(pocao), 12)
		t.eq(L.valorDeVenda(espada), 7)
		t.eq(L.valorDeVenda(reliquia), nil)
		t.eq(L.vender(5, presa), 15)
		t.eq(L.vender(0, pocao), 12)
		local sem, motivo = L.vender(0, reliquia)
		t.eq(sem, nil)
		t.eq(motivo, "A loja não compra este item.")
		-- Contrabando tem preço e pode ser revendido, mas não está na prateleira.
		t.eq(L.valorDeVenda(contrabando), 40)
	end,
	["ranks conhecidos e comparacao"] = function(t)
		t.eq(L.rankValido("F"), true)
		t.eq(L.rankValido("Z"), false)
		t.eq(L.atingeRank("C", "D"), true)
		t.eq(L.atingeRank("D", "C"), false)
		t.eq(L.atingeRank("Z", "F"), false)
	end,
}
