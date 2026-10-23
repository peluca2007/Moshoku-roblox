local Shared = game:GetService("ReplicatedStorage").Shared
local Conta = require(Shared.Regras.RunConta)
local Criacao = require(Shared.Regras.RunCriacao)
local Treinadores = require(Shared.Regras.RunTreinadores)

local menor = { NextInteger = function(_, lo) return lo end }

return {
	["conta nova e valida e comeca vazia"] = function(t)
		local c = Conta.nova()
		t.eq(Conta.valida(c), true)
		t.eq(c.moeda, 0)
		t.eq(Conta.valida({}), false)
		t.eq(Conta.valida(nil), false)
		local ruim = Conta.nova()
		ruim.moeda = -1
		t.eq(Conta.valida(ruim), false)
	end,
	["moeda: final paga mais que derrota; regioes e objetivo somam"] = function(t)
		t.eq(Conta.moedaDaRun({ status = "final", regioesVisitadas = 2, objetivoCumprido = true }), 100 + 20 + 30)
		t.eq(Conta.moedaDaRun({ status = "derrota", regioesVisitadas = 1, objetivoCumprido = false }), 20 + 10)
		t.eq((Conta.moedaDaRun({ status = "final", regioesVisitadas = -1 })), nil)
		t.eq((Conta.moedaDaRun({ status = "x", regioesVisitadas = 1 })), nil)
		t.eq((Conta.moedaDaRun(nil)), nil)
	end,
	["personagem pronto multiplica a moeda pelos defeitos"] = function(t)
		local plano = Criacao.planejar("pronto", menor, { { id = "x", arvore = "fogo" } })
		t.eq(Conta.moedaDaRun({ status = "final", regioesVisitadas = 0, plano = plano }), 150) -- 100 * 1,5
	end,
	["registrar a run soma moeda, concede conquistas uma so vez e anota o final no codice"] = function(t)
		local resumo = { status = "final", regioesVisitadas = 3, objetivoCumprido = true }
		local c1, r1 = Conta.registrarRun(Conta.nova(), resumo, "final-bom")
		t.eq(c1.moeda, 100 + 30 + 30)
		t.eq(c1.conquistas["primeiro-final"], true)
		t.eq(c1.conquistas["no-prazo"], true)
		t.eq(c1.conquistas["explorador"], true)
		t.eq(c1.conquistas["com-defeitos"], nil)
		t.eq(#r1.conquistas, 3)
		t.eq(c1.codice.final["final-bom"], true)
		local c2, r2 = Conta.registrarRun(c1, resumo, "final-bom")
		t.eq(#r2.conquistas, 0, "conquista repetida")
		t.eq(c2.moeda, c1.moeda + 160)
		t.eq(Conta.valida(Conta.nova()), true)
		local intacta = Conta.nova()
		Conta.registrarRun(intacta, resumo, "f")
		t.eq(intacta.moeda, 0, "original alterado")
	end,
	["derrota nao da conquista de final nem entrada de final no codice"] = function(t)
		local plano = Criacao.planejar("pronto", menor, { { id = "x", arvore = "fogo" } })
		local c, r = Conta.registrarRun(Conta.nova(), { status = "derrota", regioesVisitadas = 1, plano = plano }, "final-bom")
		t.eq(c.conquistas["primeiro-final"], nil)
		t.eq(c.conquistas["com-defeitos"], nil) -- exige final
		t.eq(next(c.codice.final), nil)
		t.eq(#r.conquistas, 0)
		local _, g = Conta.registrarRun(Conta.nova(), { status = "final", regioesVisitadas = 1, plano = plano }, "f")
		local tem = false
		for _, id in g.conquistas do if id == "com-defeitos" then tem = true end end
		t.eq(tem, true)
	end,
	["comprar: exige moeda, nao repete e desconta"] = function(t)
		local c = Conta.nova()
		t.eq((Conta.comprar(c, "treinador:agua")), nil)
		c.moeda = 200
		local comprada = Conta.comprar(c, "treinador:agua")
		t.eq(comprada.moeda, 50)
		t.eq(comprada.desbloqueios["treinador:agua"], true)
		t.eq(c.moeda, 200, "original alterado")
		local _, motivo = Conta.comprar(comprada, "treinador:agua")
		t.eq(motivo, "Já desbloqueado.")
		t.eq((Conta.comprar(c, "inexistente")), nil)
	end,
	["codice registra por categoria e recusa categoria ou entrada invalida"] = function(t)
		local c = Conta.registrarNoCodice(Conta.nova(), "criatura", "goblin-batedor")
		t.eq(c.codice.criatura["goblin-batedor"], true)
		t.eq((Conta.registrarNoCodice(Conta.nova(), "magia", "x")), nil)
		t.eq((Conta.registrarNoCodice(Conta.nova(), "lore", "")), nil)
	end,
	["comprar treinador raro o libera para o sorteio da taverna"] = function(t)
		local c = Conta.nova()
		t.eq(Conta.treinadoresLiberados(c)["agua"], nil)
		t.eq(Conta.treinadoresLiberados(c)["fogo"], true)
		c.moeda = 500
		c = Conta.comprar(c, "treinador:agua")
		local liberadas = Conta.treinadoresLiberados(c)
		t.eq(liberadas["agua"], true)
		local r = Treinadores.sortearAleatorio(menor, { chanceTaverna = 100, liberadas = liberadas })
		t.eq(r.taverna, "agua")
	end,
}
