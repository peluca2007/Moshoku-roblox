local Shared = game:GetService("ReplicatedStorage").Shared
local Tela = require(Shared.Regras.ExpedicaoTela)

local function visao(over)
	local v = {
		dia = 2, diasRestantes = 9, galho = "esgoto-2", tipoDoNo = "sala", area = "esgoto", passo = 2, totalPassos = 5,
		grupo = { { userId = 1, presente = true } }, aguardando = {}, contagem = {},
		opcoes = {
			{ id = "caminho-a", texto = "Pela esquerda", dica = "Cheiro forte", dias = 0.5, liberada = true },
			{ id = "caminho-b", texto = "Pela direita", dias = 0, liberada = true },
			{ id = "voltar-a-cidade", texto = "Voltar", dias = 2, liberada = true },
		},
	}
	for k, x in over or {} do v[k] = x end
	return v
end

return {
	["faixa mostra dia, prazo e a sala da área"] = function(t)
		local f = Tela.faixa(visao())
		t.eq(f.dia, "Dia 3 · faltam 9 dias")
		t.eq(f.contador, "Sala 2/5 · Esgoto")
		t.eq(Tela.faixa(visao({ diasRestantes = 1.5, area = false })).dia, "Dia 3 · faltam 1,5 dias")
		t.eq(Tela.faixa(visao({ diasRestantes = 1 })).dia, "Dia 3 · falta 1 dia")
		t.eq(Tela.faixa(visao({ area = false })).contador, nil)
		t.eq(Tela.faixa({ semRun = true }), nil)
		t.eq(Tela.faixa(nil), nil)
	end,
	["custo em dias"] = function(t)
		t.eq(Tela.custoEmDias(0), nil)
		t.eq(Tela.custoEmDias(0.5), "meio dia")
		t.eq(Tela.custoEmDias(1), "1 dia")
		t.eq(Tela.custoEmDias(3), "3 dias")
	end,
	["escolhas: cartões, voltar à cidade separado e sem votação em jogo solo"] = function(t)
		local d = Tela.decidir(visao(), {})
		t.eq(d.tela, "escolhas")
		t.eq(#d.cartoes, 2)
		t.eq(d.cartoes[1].titulo, "Pela esquerda")
		t.eq(d.cartoes[1].custo, "meio dia")
		t.eq(d.cartoes[2].custo, nil)
		t.eq(d.voltar.texto, "Voltar à cidade (2 dias)")
		t.eq(d.votacao, nil)
	end,
	["escolhas em grupo mostram quem falta e a contagem"] = function(t)
		local v = visao({ grupo = { { userId = 1, presente = true }, { userId = 2, presente = true } }, aguardando = { 2 },
			contagem = { ["caminho-a"] = 1, ["caminho-b"] = 0 }, votei = "caminho-a" })
		local d = Tela.decidir(v, {}, function(id) return "J" .. id end)
		t.eq(d.votacao, "Aguardando voto: J2")
		t.eq(d.cartoes[1].votos, 1)
		t.ok(d.cartoes[1].votada)
		t.eq(d.cartoes[2].votos, nil)
	end,
	["acampamento oferece descanso e some ao levantar"] = function(t)
		local v = visao({ fase = "acampamento", descansos = { usados = 1, max = 2 },
			grupo = { { userId = 1, presente = true, caido = true } } })
		local d = Tela.decidir(v, {}, function() return "Ana" end)
		t.eq(d.tela, "acampamento")
		t.eq(d.descansar.texto, "Descansar · meio dia · 1/2")
		t.ok(not d.descansar.desabilitado)
		t.eq(d.grupo[1], "Ana (caído)")
		v.descansos.usados = 2
		t.ok(Tela.decidir(v, {}).descansar.desabilitado)
		t.eq(Tela.decidir(v, { levantadoEm = "esgoto-2" }).tela, "escolhas")
		t.eq(Tela.decidir(v, { levantadoEm = "outro" }).tela, "acampamento")
	end,
	["luta esconde tudo menos a faixa"] = function(t)
		for _, caso in { { v = visao({ fase = "luta" }), e = {} }, { v = visao(), e = { emCombate = true } } } do
			local d = Tela.decidir(caso.v, caso.e)
			t.eq(d.tela, "luta")
			t.ok(d.faixa ~= nil)
			t.eq(d.cartoes, nil)
		end
	end,
	["hub só abre a escolha da porta quando pedida"] = function(t)
		local hub = visao({ tipoDoNo = "hub", area = false, passo = false, totalPassos = false, galho = "cidade", opcoes = {
			{ id = "entrar-esgoto", texto = "Entrar no esgoto", dias = 1, liberada = true },
			{ id = "retomar-esgoto-esgoto-3", texto = "Retomar na sala 3", dias = 1, liberada = true },
		} })
		t.eq(Tela.decidir(hub, {}).tela, "nenhuma")
		local d = Tela.decidir(hub, { portaAberta = true })
		t.eq(d.tela, "porta")
		t.eq(#d.cartoes, 2)
		t.eq(d.cartoes[1].custo, "1 dia")
		t.eq(d.faixa.contador, nil)
	end,
	["fim da run e ausência de run não mostram telas"] = function(t)
		t.eq(Tela.decidir(visao({ fim = { motivo = "final" } }), {}).tela, "nenhuma")
		t.eq(Tela.decidir({ semRun = true }, {}).tela, "nenhuma")
		t.eq(Tela.decidir(nil, {}).tela, "nenhuma")
	end,
	["viajando: nó muda ou fase entra/sai da luta, nunca na primeira visão"] = function(t)
		local viaja, mem = Tela.viajar(nil, visao())
		t.ok(not viaja)
		viaja, mem = Tela.viajar(mem, visao())
		t.ok(not viaja)
		viaja, mem = Tela.viajar(mem, visao({ galho = "esgoto-3" }))
		t.ok(viaja)
		viaja, mem = Tela.viajar(mem, visao({ galho = "esgoto-3", fase = "luta" }))
		t.ok(viaja)
		viaja, mem = Tela.viajar(mem, visao({ galho = "esgoto-3", fase = "acampamento" }))
		t.ok(viaja)
		viaja = Tela.viajar(mem, visao({ galho = "esgoto-3", fase = "acampamento", dia = 3 }))
		t.ok(not viaja)
	end,
	["aviso de expedição concluída"] = function(t)
		t.eq(Tela.avisoConcluida({ ouro = 40 }).detalhe, "+40 de ouro")
		t.eq(Tela.avisoConcluida({}).detalhe, "De volta à cidade.")
	end,
}
