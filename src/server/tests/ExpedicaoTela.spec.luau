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
		t.eq(d.cartoes[1].votosTexto, "Votos: 1")
		t.ok(d.cartoes[1].votada)
		t.ok(d.cartoes[1].maisVotada)
		t.eq(d.cartoes[1].rotuloVotar, "Meu voto")
		t.eq(d.cartoes[2].votosTexto, "Votos: 0")
		t.ok(not d.cartoes[2].maisVotada)
		t.eq(d.cartoes[2].rotuloVotar, "Votar")
		t.ok(d.retirarVoto)
		t.eq(d.titulo, "Para onde seguir?")
		local solo = Tela.decidir(visao(), {})
		t.eq(solo.cartoes[1].votosTexto, nil)
		t.eq(solo.cartoes[1].rotuloVotar, "Escolher")
		t.ok(not solo.retirarVoto)
	end,
	["disposição: cartões lado a lado com teto e pilha em tela estreita"] = function(t)
		t.eq(Tela.disposicao(1200, 3).modo, "lado")
		t.eq(Tela.disposicao(1200, 3).larguraMax, 860)
		t.ok(Tela.disposicao(1200, 2).larguraMax < 860)
		t.eq(Tela.disposicao(500, 3).modo, "pilha")
		t.eq(Tela.disposicao(699, 2).modo, "pilha")
		t.eq(Tela.disposicao(700, 2).modo, "lado")
	end,
	["opção trancada aparece com motivo legível, nunca a flag crua"] = function(t)
		t.eq(Tela.motivoLegivel("Trancado: fragmento/esgoto"), "Precisa do fragmento do esgoto")
		t.eq(Tela.motivoLegivel("Trancado: vencido/x"), "Ainda trancado")
		t.eq(Tela.motivoLegivel("Caixa da viagem insuficiente."), "Caixa da viagem insuficiente.")
		local hub = visao({ tipoDoNo = "hub", area = false, passo = false, totalPassos = false, galho = "cidade", opcoes = {
			{ id = "selar-a-anomalia", texto = "Selar a anomalia (encerrar a campanha)", dias = 0, liberada = false, motivo = "Trancado: fragmento/esgoto" },
		} })
		local d = Tela.decidir(hub, { portaAberta = true })
		t.ok(not d.cartoes[1].liberada)
		t.eq(d.cartoes[1].motivo, "Precisa do fragmento do esgoto")
		hub.opcoes[1].liberada, hub.opcoes[1].motivo = true, nil
		t.eq(Tela.decidir(hub, { portaAberta = true }).cartoes[1].motivo, nil)
	end,
	["luta pendente: espera para não piscar, erro mostra na hora, textos e confirmação"] = function(t)
		local v = visao({ fase = "luta", luta = { titulo = "Ratos no túnel" }, passo = 3 })
		t.eq(Tela.decidir(v, { esperaLuta = 0 }).tela, "luta")
		t.eq(Tela.decidir(v, { esperaLuta = 2.9 }).tela, "luta")
		local d = Tela.decidir(v, { esperaLuta = Tela.ESPERA_LUTA })
		t.eq(d.tela, "lutaPendente")
		t.eq(d.titulo, "Ratos no túnel")
		t.eq(d.erro, nil)
		t.eq(d.entrar.texto, "Entrar na luta")
		t.eq(d.abandonar.texto, "Voltar à cidade (1 dia)")
		t.ok(not d.abandonar.confirmando)
		t.ok(d.faixa ~= nil)
		v.lutaErro = "Mapa indisponível"
		local e = Tela.decidir(v, { esperaLuta = 0 })
		t.eq(e.tela, "lutaPendente")
		t.eq(e.erro, "Mapa indisponível")
		t.eq(e.entrar.texto, "Tentar de novo")
		local c = Tela.decidir(v, { confirmaAbandono = true })
		t.ok(c.abandonar.confirmando)
		t.ok(c.abandonar.texto:find("confirmar", 1, true) ~= nil)
		t.eq(Tela.decidir(v, { emCombate = true }).tela, "luta")
		t.eq(Tela.custoAbandonar(1), 1)
		t.eq(Tela.custoAbandonar(5), 2)
	end,
	["acampamento oferece descanso e some ao levantar"] = function(t)
		local v = visao({ fase = "acampamento", descansos = { usados = 1, max = 2 },
			grupo = { { userId = 1, presente = true, caido = true } } })
		local d = Tela.decidir(v, {}, function() return "Ana" end)
		t.eq(d.tela, "acampamento")
		t.eq(d.descansar.texto, "Descansar · meio dia · 1/2")
		t.ok(not d.descansar.desabilitado)
		t.eq(d.grupo[1], "Ana (caído)")
		t.eq(d.levantar.texto, "Pronto")
		t.eq(d.voltar.texto, "Voltar à cidade (2 dias)")
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
		t.eq(d.fechar.nome, "Cancelar")
	end,
	["hub: voto alheio abre a porta para mim; Agora não dispensa até a contagem mudar"] = function(t)
		local hub = visao({ tipoDoNo = "hub", area = false, passo = false, totalPassos = false, galho = "cidade",
			grupo = { { userId = 1, presente = true }, { userId = 2, presente = true } }, aguardando = { 1 },
			contagem = { ["entrar-esgoto"] = 1 }, opcoes = { { id = "entrar-esgoto", texto = "Entrar no esgoto", dias = 1, liberada = true } } })
		local d = Tela.decidir(hub, {})
		t.eq(d.tela, "porta")
		t.eq(d.fechar.nome, "AgoraNao")
		t.eq(d.cartoes[1].votosTexto, "Votos: 1")
		local sig = Tela.assinaturaVotos(hub)
		t.eq(Tela.decidir(hub, { agoraNaoEm = sig }).tela, "nenhuma")
		hub.contagem["entrar-esgoto"] = 2
		t.eq(Tela.decidir(hub, { agoraNaoEm = sig }).tela, "porta")
		hub.votei = "entrar-esgoto"
		t.eq(Tela.decidir(hub, {}).tela, "nenhuma")
		hub.votei, hub.contagem = nil, { ["entrar-esgoto"] = 0 }
		t.eq(Tela.decidir(hub, {}).tela, "nenhuma")
	end,
	["diário e fim legíveis, sem id cru"] = function(t)
		local g = { { userId = 1, presente = true }, { userId = 2, presente = false } }
		local d = Tela.diario(visao({ grupo = g, descansos = { usados = 1, max = 2 } }), function(id) return "J" .. id end)
		t.eq(d.dia, "Dia 3 · faltam 9 dias")
		t.eq(d.lugar, "Esgoto · sala 2/5")
		t.eq(d.descansos, "Descansos usados: 1/2")
		t.eq(d.grupo[2], "J2 (ausente)")
		local hub = visao({ tipoDoNo = "hub", area = false, galho = "cidade", opcoes = {
			{ id = "selar-a-anomalia", texto = "x", liberada = true } } })
		local h = Tela.diario(hub)
		t.eq(h.lugar, "Na cidade")
		t.ok(h.concluida ~= nil)
		t.eq(Tela.textoFim(visao({ galho = "final-campanha", fim = { motivo = "final", final = "final-campanha" } })), "A anomalia foi selada.")
		t.eq(Tela.textoFim(visao({ fim = { motivo = "queda" } })), "O grupo caiu. A expedição terminou.")
		t.eq(Tela.textoFim(visao({ fim = { motivo = "queda" }, objetivo = { status = "expirado" } })), "O prazo se esgotou. A expedição terminou.")
		t.eq(Tela.textoFim(visao()), nil)
		t.eq(Tela.diario({ semRun = true }), nil)
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
		t.eq(Tela.avisoConcluida({ ouro = 40 }).detalhe, "+40 de ouro · fragmento do esgoto")
		t.ok(Tela.avisoConcluida({}).detalhe:find("Fragmento do esgoto", 1, true) ~= nil)
	end,
}
