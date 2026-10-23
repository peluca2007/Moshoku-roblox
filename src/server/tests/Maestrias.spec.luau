local Shared = game:GetService("ReplicatedStorage").Shared
local Maestrias = require(Shared.Regras.Maestrias)

local catalogo = { POR_ID = {} }
local function ficha(ranks, compras, inventario, metros)
	return { construction = { unlockedRankIds = ranks or {}, purchasedIds = compras or {}, inventory = inventario or {} },
		calculated = { movementMeters = metros or 9 } }
end

return {
	["bandeiras vêm do rank (maestria) e das compras (talento/passiva)"] = function(t)
		local f = Maestrias.daFicha(ficha({ "rank/deus-da-espada/Principiante" }, { "ability/deus-da-espada/Principiante/roupa-leve" }), catalogo)
		t.eq(f.quemSeMovePrimeiro, true)
		t.eq(f.roupaLeve, true)
		t.eq(f.pesLeves, nil)
	end,
	["deslocamento: Pés Leves e Roupa Leve não somam (vale o maior)"] = function(t)
		local f = { pesLeves = true, roupaLeve = true }
		t.eq(Maestrias.deslocamentoCasas(ficha(), f), 8)
		t.eq(Maestrias.deslocamentoCasas(ficha(), {}), 6)
	end,
	["Roupa Leve desliga com armadura; escudo não conta como armadura"] = function(t)
		local f = { roupaLeve = true }
		local armadura = ficha({}, {}, { { name = "Armadura Leve", type = "armadura", equipped = true } })
		local escudo = ficha({}, {}, { { name = "Escudo", type = "armadura", equipped = true } })
		t.eq(Maestrias.deslocamentoCasas(armadura, f), 6)
		t.eq(Maestrias.deslocamentoCasas(escudo, f), 8)
		t.eq(Maestrias.caExtra(escudo, f, 2), 2)
		t.eq(Maestrias.caExtra(escudo, f, 1), 0)
		t.eq(Maestrias.caExtra(armadura, f, 4), 0)
	end,
	["imunidades e Base Firme"] = function(t)
		t.eq(Maestrias.imuneA({ semRecuo = true }, "amedrontado"), true)
		t.eq(Maestrias.imuneA({ semRecuo = true }, "provocado"), false)
		t.eq(Maestrias.imuneA({ pacienciaDePedra = true }, "provocado"), true)
		t.eq(Maestrias.resisteDeslocamento({ baseFirme = true }, "forca"), true)
		t.eq(Maestrias.resisteDeslocamento({ baseFirme = true }, "vigor"), false)
	end,
	["empate de iniciativa é de quem tem Quem Se Move Primeiro"] = function(t)
		local e = { { id = "a", initiative = 12 }, { id = "b", initiative = 12 }, { id = "c", initiative = 15 } }
		Maestrias.ordenarEmpates(e, function(id) return id == "b" end)
		t.eq(e[1].id, "c"); t.eq(e[2].id, "b"); t.eq(e[3].id, "a")
	end,
	["O Corpo é a Arma: 1 Quebrantado no primeiro acerto corpo a corpo por criatura no turno"] = function(t)
		t.eq(Maestrias.quebrantaNoAcerto({ corpoEArma = true }, true, false), 1)
		t.eq(Maestrias.quebrantaNoAcerto({ corpoEArma = true }, true, true), nil)
		t.eq(Maestrias.quebrantaNoAcerto({ corpoEArma = true }, false, false), nil)
		t.eq(Maestrias.quebrantaNoAcerto({ corpoEArma = true }, true, false, 2), 2)
	end,
	["Quem Se Move Primeiro só no primeiro ataque do primeiro turno"] = function(t)
		t.eq(Maestrias.primeiroAtaque({ quemSeMovePrimeiro = true }, true, false), true)
		t.eq(Maestrias.primeiroAtaque({ quemSeMovePrimeiro = true }, true, true), false)
		t.eq(Maestrias.primeiroAtaque({ quemSeMovePrimeiro = true }, false, false), false)
	end,
	["Defender: Vigor + metade do Rank de corpo, para cima, nunca negativo"] = function(t)
		t.eq(Maestrias.reducaoDefender(2, 1), 3)
		t.eq(Maestrias.reducaoDefender(-3, 0), 0)
		t.eq(Maestrias.BASICAS["mesa/defender"].acoes, 1)
	end,
	["cartas livres exigem o rank da maestria"] = function(t)
		t.eq(Maestrias.CARTAS["mesa/brisa"].exigeRank, "vento")
		t.eq(Maestrias.CARTAS["mesa/brisa"].acoes, 0)
		t.eq(Maestrias.CARTAS["mesa/marcar"].acoes, 1)
	end,
}
