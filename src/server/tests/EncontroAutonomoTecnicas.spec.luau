local Shared = game:GetService("ReplicatedStorage").Shared
local Tecnicas = require(Shared.EncontroAutonomoTecnicas)
local Catalogo = require(Shared.Livro.Catalogo)
local Arma = require(Shared.Regras.Arma)
local id = Tecnicas.GOLPE_CONTINUO

local function atores()
	return { id = "jogador", kind = "jogador", x = 10, z = 10, pv = 30, pvMax = 30, pm = 0, pt = 2,
		ficha = { construction = { unlockedRankIds = { "rank/deus-da-espada/Principiante" }, purchasedIds = { id },
			inventory = { { type = "arma", name = "Espada longa", baseDie = "d8", equipped = true, damageAttribute = "forca" } } },
			calculated = { attributes = { forca = 3, agilidade = 1 } } },
	}, { id = "criatura", kind = "criatura", x = 10, z = 11, pv = 100, ca = 15,
		fichaCriatura = { patamar = 1, bonusAtaque = 0 } }
end

local function rng(natural)
	return { NextInteger = function(_, _, maximo) return if maximo == 20 then natural else maximo end }
end

return {
	["conhecimento exige compra e rank da técnica, sem liberar cartas incompletas"] = function(t)
		local ator = atores()
		t.eq(Tecnicas.disponiveis(ator)[1], id)
		ator.ficha.construction.purchasedIds = {}
		t.eq(#Tecnicas.disponiveis(ator), 0)
		ator.ficha.construction.purchasedIds = { id }
		ator.ficha.construction.unlockedRankIds = { "rank/fogo/Principiante" }
		t.eq(#Tecnicas.disponiveis(ator), 0)
		t.eq(Tecnicas.mecanica("ability/deus-da-espada/Principiante/corte-de-braco"), nil)
		t.eq(Tecnicas.mecanica("ability/deus-do-norte/Principiante/golpe-baixo"), nil)
	end,
	["custos e bônus vêm da carta canônica, com arma e acerto confirmado na vez"] = function(t)
		local ator, alvo = atores()
		local carta = Catalogo.POR_ID[id].data
		local mec = Tecnicas.mecanica(id)
		t.eq(mec.acoes, carta.actions.normal)
		t.eq(mec.pt, carta.ptCost)
		t.eq(mec.pm, 0)
		local semBonus, erro = Tecnicas.usar(rng(9), id, ator, alvo, Catalogo)
		t.eq(erro, nil)
		ator.jaAcertouNestaVez = true
		local comBonus = Tecnicas.usar(rng(9), id, ator, alvo, Catalogo)
		t.eq(comBonus.attack.bonus - semBonus.attack.bonus, 4)
		t.eq(comBonus.attack.acertou, true)
		t.eq(comBonus.ptCost, 1)
		t.eq(comBonus.pmCost, 0)
		t.eq(comBonus.weapon, "Espada longa")
		local arma = Arma.daFicha(ator.ficha, Catalogo)
		local _, fixo = Arma.formula(arma.dado)
		-- RNG máximo no dado, com atributo e rank vindos de Arma.
		local faces = tonumber(string.match(arma.dado, "d(%d+)"))
		t.eq(comBonus.damageDealt, faces + fixo + 3 + arma.bonusDeRank)
		t.eq(ator.pt, 2, "regra pura não consome estado")
		t.eq(alvo.pv, 100, "regra pura não aplica dano")
	end,
	["erros não causam dano mas preservam o custo, crítico reutiliza os dados canônicos"] = function(t)
		local ator, alvo = atores()
		local erro = Tecnicas.usar(rng(1), id, ator, alvo, Catalogo)
		t.eq(erro.attack.acertou, false)
		t.eq(erro.damageDealt, 0)
		t.eq(erro.ptCost, 1)
		local normal = Tecnicas.usar(rng(19), id, ator, alvo, Catalogo)
		local critico = Tecnicas.usar(rng(20), id, ator, alvo, Catalogo)
		t.eq(critico.attack.critico, true)
		t.ok(critico.damageDealt > normal.damageDealt)
	end,
	["recusa alcance, aliado, alvo derrotado e recursos inválidos sem rolar"] = function(t)
		local chamado = false
		local nunca = { NextInteger = function() chamado = true; error("não devia rolar") end }
		local ator, alvo = atores()
		ator.pt = 0
		t.eq(Tecnicas.usar(nunca, id, ator, alvo, Catalogo), nil)
		ator.pt = 0/0
		t.eq(Tecnicas.usar(nunca, id, ator, alvo, Catalogo), nil)
		ator.pt = 2
		alvo.z = 12
		t.eq(Tecnicas.usar(nunca, id, ator, alvo, Catalogo), nil)
		alvo.z, alvo.kind = 11, "jogador"
		t.eq(Tecnicas.usar(nunca, id, ator, alvo, Catalogo), nil)
		alvo.kind, alvo.defeated = "criatura", true
		t.eq(Tecnicas.usar(nunca, id, ator, alvo, Catalogo), nil)
		t.eq(chamado, false)
	end,
	["arma ausente, ambígua, indisponível ou de disparo não vira arma de referência"] = function(t)
		local ator, alvo = atores()
		local inv = ator.ficha.construction.inventory
		inv[1].equipped = false
		t.eq(Tecnicas.usar(rng(20), id, ator, alvo, Catalogo), nil)
		inv[1].equipped, inv[1].a16Indisponivel = true, true
		t.eq(Tecnicas.usar(rng(20), id, ator, alvo, Catalogo), nil)
		inv[1].a16Indisponivel, inv[1].name = nil, "Arco curto"
		t.eq(Tecnicas.usar(rng(20), id, ator, alvo, Catalogo), nil)
		inv[1].name = "Espada longa"
		table.insert(inv, table.clone(inv[1]))
		t.eq(Tecnicas.usar(rng(20), id, ator, alvo, Catalogo), nil)
	end,
	["condições canônicas afetam o ataque e estado incapaz impede execução"] = function(t)
		local ator, alvo = atores()
		ator.condicoes = { cego = true }
		local resultado = Tecnicas.usar(rng(10), id, ator, alvo, Catalogo)
		t.ok(table.find(resultado.notes, "Desvantagem") ~= nil)
		ator.condicoes = { inconsciente = true }
		t.eq(Tecnicas.usar(rng(20), id, ator, alvo, Catalogo), nil)
	end,
}
