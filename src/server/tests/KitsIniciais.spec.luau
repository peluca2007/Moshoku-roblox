local Shared = game:GetService("ReplicatedStorage").Shared
local Kits = require(Shared.KitsIniciais)

return {
	["preserva dez subgrupos e vinte e tres itens da fonte"] = function(t)
		t.eq(#Kits.LISTA, 10)
		local total, categorias, chaves = 0, {}, 0
		for subgrupo, kit in Kits.POR_SUBGRUPO do
			t.eq(kit.subgroup, subgrupo)
			chaves += 1
		end
		for _, kit in Kits.LISTA do
			t.eq(Kits.obter(kit.subgroup), kit)
			for _, item in kit.items do
				t.ok(type(item.name) == "string" and #item.name > 0)
				t.eq(item.equipped, nil)
				t.eq(item.id, nil)
				total += 1
				categorias[item.type] = (categorias[item.type] or 0) + 1
			end
		end
		t.eq(chaves, 10)
		t.eq(total, 23)
		t.eq(categorias.arma, 11)
		t.eq(categorias.armadura, 2)
		t.eq(categorias.geral, 10)
	end,
	["consulta usa subgrupo exato e nao inventa fallback por arvore"] = function(t)
		t.eq(Kits.obter("fogo"), nil)
		t.eq(Kits.obter("tree/fogo"), nil)
		t.eq(Kits.obter("magia ofensiva"), nil)
		t.eq(Kits.obter("inexistente"), nil)
		t.eq(Kits.obter("Magia Ofensiva").items[1].name, "Cajado / Foco Arcano")
	end,
	["tank preserva escudo dois e armadura leve um sem equipa los"] = function(t)
		local itens = Kits.obter("Tank / Defensor").items
		t.eq(itens[1].name, "Escudo")
		t.eq(itens[1].acBonus, 2)
		t.eq(itens[2].name, "Espada Curta")
		t.eq(itens[2].baseDie, "d6")
		t.eq(itens[3].name, "Armadura Leve")
		t.eq(itens[3].acBonus, 1)
	end,
	["arqueiro preserva flechas e arma reserva catalogada"] = function(t)
		local itens = Kits.obter("Arqueiro").items
		t.eq(itens[1].description, "20 flechas inclusas.")
		t.eq(itens[1].baseDie, "d6")
		t.eq(itens[2].name, "Funda / Dardo")
		t.eq(itens[2].baseDie, "d4")
		t.eq(itens[2].description, "A arma de reserva, quando as flechas acabam.")
	end,
	["preserva alternativas textuais sem materializar escolha"] = function(t)
		local tatico = Kits.obter("Sobrevivência e Táticas").items
		t.eq(#tatico, 2)
		t.eq(tatico[2].name, "Alabarda / Lança")
		t.eq(tatico[2].baseDie, "d10")
		t.eq(tatico[2].description, "Ou troque por Arco Curto com 20 flechas.")
		t.eq(Kits.obter("Bardo").items[1].description, "Escolha o instrumento.")
		t.eq(Kits.obter("Batedor e Ladrão").items[1].description, "Duas: a de mão e a de reserva.")
	end,
	["focos magicos mantem dano improvisado e descricao"] = function(t)
		for _, caso in { { "Magia Ofensiva", 1 }, { "Cura e Suporte", 3 }, { "Invocação", 2 } } do
			local foco = Kits.obter(caso[1]).items[caso[2]]
			t.eq(foco.name, "Cajado / Foco Arcano")
			t.eq(foco.type, "arma")
			t.eq(foco.baseDie, "d6")
			t.eq(foco.description, "Conta como objeto improvisado corpo a corpo.")
		end
	end,
	["catalogo imutavel nao compartilha inventario editavel"] = function(t)
		t.fails(function() Kits.LISTA[1] = {} end)
		t.fails(function() Kits.POR_SUBGRUPO.Espadachim = {} end)
		t.fails(function() Kits.obter("Espadachim").items[1].name = "alterado" end)
		t.fails(function() table.insert(Kits.obter("Espadachim").items, {}) end)
		t.eq(Kits.obter("Espadachim").items[1].name, "Espada Longa")
	end,
	["registra procedencia reproduzivel"] = function(t)
		t.eq(Kits.FONTE, "src/data/startingKits.ts")
		t.eq(#Kits.SHA256_FONTE, 64)
		t.ok(string.match(Kits.SHA256_FONTE, "^[0-9a-f]+$") ~= nil)
	end,
}
