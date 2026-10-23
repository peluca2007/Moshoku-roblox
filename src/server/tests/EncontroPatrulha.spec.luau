local Shared = game:GetService("ReplicatedStorage").Shared
local P = require(Shared.Regras.EncontroPatrulha)

local function fixo(n) return { NextInteger = function() return n end } end

return {
	["surpresa: jogador nao visto surpreende; emboscada so vale sem Explorador"] = function(t)
		t.eq(P.surpresa(false, true, false, false), "jogadores")
		t.eq(P.surpresa(true, true, false, false), nil) -- já tinha sido visto
		t.eq(P.surpresa(true, false, false, false), nil) -- a criatura iniciou o contato
		t.eq(P.surpresa(false, false, false, true), "inimigos")
		t.eq(P.surpresa(false, false, true, true), nil) -- grupo com Explorador nunca é emboscado
		t.eq(P.surpresa(false, true, true, false), "jogadores") -- Explorador não tira a surpresa a favor
	end,
	["ordem com surpresa poe o lado surpreendente primeiro, preserva ordem interna e marca desprevenidos"] = function(t)
		local ordem = {
			{ id = "g1", lado = "criatura" }, { id = "p1", lado = "jogador" },
			{ id = "g2", lado = "criatura" }, { id = "p2", lado = "jogador" },
		}
		local nova, desp = P.ordemComSurpresa(ordem, "criatura")
		t.eq(#nova, 4)
		t.eq(nova[1].id, "p1") t.eq(nova[2].id, "p2") t.eq(nova[3].id, "g1") t.eq(nova[4].id, "g2")
		t.eq(desp.g1, true) t.eq(desp.g2, true) t.eq(desp.p1, nil)
		t.eq(ordem[1].id, "g1", "original alterado")
		local sem, vazio = P.ordemComSurpresa(ordem, nil)
		t.eq(sem[1].id, "g1")
		t.eq(next(vazio), nil)
		t.eq((P.ordemComSurpresa({ { id = 1, lado = "jogador" } }, "jogador")), nil)
		t.eq((P.ordemComSurpresa({ { id = "x", lado = "outro" } }, "jogador")), nil)
		t.eq((P.ordemComSurpresa("x", "jogador")), nil)
	end,
	["CD da fuga cresce com o perseguidor mais rapido, tem teto e piso"] = function(t)
		t.eq(P.cdDeFuga(9, { 9 }), 10) -- mesma velocidade
		t.eq(P.cdDeFuga(9, { 6 }), 10) -- mais lento não reduz abaixo da base
		t.eq(P.cdDeFuga(9, { 12 }), 12) -- 3 m = 2 casas
		t.eq(P.cdDeFuga(9, { 9, 12, 7.5 }), 12) -- manda o mais rápido
		t.eq(P.cdDeFuga(0, { 300 }), 25) -- teto
		t.eq(P.cdDeFuga(9, {}), nil)
		t.eq(P.cdDeFuga(9, { -1 }), nil)
		t.eq(P.cdDeFuga("x", { 9 }), nil)
	end,
	["fuga: bonus decide, 20 natural foge sempre e 1 natural sempre falha"] = function(t)
		local ok = P.fuga(fixo(10), 3, 9, { 12 }) -- 13 contra 12
		t.eq(ok.fugiu, true) t.eq(ok.cd, 12) t.eq(ok.total, 13) t.eq(ok.perdeTurno, false)
		local falha = P.fuga(fixo(8), 3, 9, { 12 }) -- 11 contra 12
		t.eq(falha.fugiu, false) t.eq(falha.perdeTurno, true)
		t.eq(P.fuga(fixo(20), -10, 9, { 300 }).fugiu, true)
		t.eq(P.fuga(fixo(1), 50, 9, { 6 }).fugiu, false)
		t.eq(P.fuga(fixo(12), 0, 9, { 12 }).fugiu, true) -- empate no CD foge
	end,
	["fuga recusa entradas invalidas sem rolar"] = function(t)
		local rolou = false
		local rng = { NextInteger = function() rolou = true return 10 end }
		t.eq((P.fuga(nil, 0, 9, { 9 })), nil)
		t.eq((P.fuga(rng, 1.5, 9, { 9 })), nil)
		t.eq((P.fuga(rng, 0, 9, {})), nil)
		t.eq((P.fuga(rng, 99, 9, { 9 })), nil)
		t.eq(rolou, false)
	end,
	["situacao na grade: dentro, ao pisar, fora e argumentos invalidos"] = function(t)
		t.eq(P.situacaoNaGrade(5, 15, 8), "dentro")
		t.eq(P.situacaoNaGrade(8, 15, 8), "dentro")
		t.eq(P.situacaoNaGrade(12, 15, 8), "ao-pisar")
		t.eq(P.situacaoNaGrade(15, 15, 8), "ao-pisar")
		t.eq(P.situacaoNaGrade(15.1, 15, 8), "fora")
		t.eq(P.situacaoNaGrade(-1, 15, 8), nil)
		t.eq(P.situacaoNaGrade(5, 8, 15), nil)
		t.eq(P.situacaoNaGrade("a", 15, 8), nil)
	end,
}
