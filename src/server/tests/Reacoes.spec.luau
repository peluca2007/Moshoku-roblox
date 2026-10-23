local Shared = game:GetService("ReplicatedStorage").Shared
local Reacoes = require(Shared.Regras.Reacoes)

local function ataque(total, defesa, natural)
	local n = natural or 10
	return { d20 = { natural = n, dados = { n }, ajuste = "normal" }, bonus = total - n, total = total, defesa = defesa,
		acertou = n ~= 1 and (n == 20 or total >= defesa), critico = n == 20 }
end

return {
	["Aparar só vira erro quando o Bônus de Rank basta, e nunca contra 20 natural"] = function(t)
		t.eq(Reacoes.apararViraErro(ataque(14, 14), 1), true)
		t.eq(Reacoes.apararViraErro(ataque(15, 14), 1), false)
		t.eq(Reacoes.apararViraErro(ataque(14, 14, 20), 5), false)
		t.eq(Reacoes.apararViraErro(ataque(10, 14), 1), false, "golpe que já errou não conta")
	end,
	["Bloquear com Escudo: +5 proficiente, +2 sem; se ainda acerta, reduz 2 × Rank"] = function(t)
		local erra, reducao = Reacoes.bloqueio(ataque(18, 14), true, 1)
		t.eq(erra, true); t.eq(reducao, 0)
		erra, reducao = Reacoes.bloqueio(ataque(18, 14), false, 1)
		t.eq(erra, false); t.eq(reducao, 2)
		erra = Reacoes.bloqueio(ataque(14, 14, 20), true, 1)
		t.eq(erra, false, "crítico acerta sempre")
	end,
	["anular tira dano, condições e empurrão do acerto"] = function(t)
		local e = { ataque = ataque(15, 14), dano = { total = 9 }, aplica = { "caido" }, empurrar = 2, estados = {}, notas = {} }
		Reacoes.anular(e, "Aparar")
		t.eq(e.ataque.acertou, false)
		t.eq(e.dano, nil); t.eq(e.aplica, nil); t.eq(e.empurrar, nil)
		t.eq(e.notas[1], "Aparar")
	end,
	["reduzir nunca deixa dano negativo"] = function(t)
		local e = { dano = { total = 5 }, notas = {} }
		t.eq(Reacoes.reduzir(e, 8), 5)
		t.eq(e.dano.total, 0)
	end,
	["físico e corpo a corpo"] = function(t)
		t.eq(Reacoes.fisico({ partes = { { dados = "1d8", tipo = "ígneo" } } }), false)
		t.eq(Reacoes.fisico({ partes = { { dados = "1d6", tipo = "cortante" } } }), true)
		t.eq(Reacoes.fisico({ arma = true }), true)
		t.eq(Reacoes.fisico({ criatura = true }), true)
		t.eq(Reacoes.corpoACorpo({ arma = true, armaADistancia = true }), false)
		t.eq(Reacoes.corpoACorpo({ corpoACorpo = true }), true)
		t.eq(Reacoes.danoFisico({ dano = { total = 3, tipo = "ígneo" } }, { partes = {} }), false)
		t.eq(Reacoes.danoFisico({ dano = { total = 3 } }, { criatura = true }), true)
	end,
	["escudo é o item equipado com escudo no nome"] = function(t)
		local ficha = { construction = { inventory = { { name = "Escudo", type = "armadura", equipped = true } } } }
		t.eq(Reacoes.escudo(ficha), "Escudo")
		ficha.construction.inventory[1].equipped = false
		t.eq(Reacoes.escudo(ficha), nil)
	end,
}
