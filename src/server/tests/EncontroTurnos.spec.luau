local Turnos = require(game:GetService("ReplicatedStorage").Shared.EncontroTurnos)

return {
	["cria ordem valida sem alterar a entrada"] = function(t)
		local ordem = {"jogador-1", "criatura-1"}
		local estado, erro = Turnos.criar("encontro-1", ordem)
		t.eq(erro, nil)
		t.eq(estado.version, 1)
		t.eq(estado.turn, 1)
		t.eq(estado.actionsRemaining, 3)
		t.eq(Turnos.consultar(estado).currentActorId, "jogador-1")
		ordem[1] = "alterado"
		t.eq(Turnos.consultar(estado).currentActorId, "jogador-1")
	end,
	["consome tres acoes com versao, turno e replay idempotente"] = function(t)
		local estado = Turnos.criar("e", {"j", "c"})
		for esperado = 1, 3 do
			local novo, recibo = Turnos.consumirAcao(estado, {
				actorId = "j", expectedVersion = esperado, requestId = "acao-" .. esperado,
			})
			t.eq(recibo.actionsRemaining, 3 - esperado)
			local replay, reciboReplay, mensagem = Turnos.consumirAcao(novo, {
				actorId = "j", expectedVersion = esperado, requestId = "acao-" .. esperado,
			})
			t.eq(mensagem, "Pedido já aplicado.")
			t.eq(reciboReplay.version, recibo.version)
			t.eq(replay.version, novo.version)
			estado = novo
		end
		local semAcao, _, erro = Turnos.consumirAcao(estado, {
			actorId = "j", expectedVersion = estado.version, requestId = "quarta",
		})
		t.eq(semAcao, nil)
		t.eq(erro, "Sem Ações restantes neste turno.")
		local fim = Turnos.encerrarTurno(estado, { actorId = "j", expectedVersion = estado.version, requestId = "fim" })
		t.eq(fim.actionsRemaining, 3)
		t.eq(fim.version, 5)
	end,
	["acao livre avanca a versao sem reduzir o saldo de acoes"] = function(t)
		local estado = Turnos.criar("e", { "j", "c" })
		local novo, recibo = Turnos.consumirAcao(estado, { actorId = "j", expectedVersion = 1,
			requestId = "soltar", action = "ability:mesa/mao-de-terra-soltar", targetId = "j", actionsCost = 0 })
		t.eq(recibo.actionsRemaining, 3)
		t.eq(novo.version, 2)
		local replay, copia, mensagem = Turnos.consumirAcao(novo, { actorId = "j", expectedVersion = 1,
			requestId = "soltar", action = "ability:mesa/mao-de-terra-soltar", targetId = "j", actionsCost = 0 })
		t.eq(mensagem, "Pedido já aplicado.")
		t.eq(copia.version, 2)
		t.eq(replay.actionsRemaining, 3)
	end,
	["recusa ordem vazia curta longa ou repetida"] = function(t)
		local estado = Turnos.criar("e", {"a"})
		t.eq(estado, nil)
		estado = Turnos.criar("e", {"a", "a"})
		t.eq(estado, nil)
		local ordem = table.create(17, "ator")
		estado = Turnos.criar("e", ordem)
		t.eq(estado, nil)
	end,
	["encerra a vez avanca a versao e conta volta completa"] = function(t)
		local estado = Turnos.criar("e", {"j", "c"})
		local proximo, recibo = Turnos.encerrarTurno(estado, {
			actorId = "j", expectedVersion = 1, requestId = "r1",
		})
		t.eq(recibo.version, 2)
		t.eq(recibo.nextActorId, "c")
		t.eq(proximo.turn, 1)
		local fim, segundoRecibo = Turnos.encerrarTurno(proximo, {
			actorId = "c", expectedVersion = 2, requestId = "r2",
		})
		t.eq(segundoRecibo.nextActorId, "j")
		t.eq(fim.turn, 2)
		t.eq(fim.version, 3)
		t.eq(estado.version, 1)
	end,
	["repeticao exata retorna recibo sem aplicar duas vezes"] = function(t)
		local estado = Turnos.criar("e", {"j", "c"})
		local proximo, recibo = Turnos.encerrarTurno(estado, {
			actorId = "j", expectedVersion = 1, requestId = "mesmo",
		})
		local repetido, reciboRepetido, mensagem = Turnos.encerrarTurno(proximo, {
			actorId = "j", expectedVersion = 1, requestId = "mesmo",
		})
		t.eq(mensagem, "Pedido já aplicado.")
		t.eq(reciboRepetido.version, recibo.version)
		t.eq(repetido.version, 2)
		t.eq(repetido.currentIndex, 2)
	end,
	["recusa versao antiga e participante fora da vez"] = function(t)
		local estado = Turnos.criar("e", {"j", "c"})
		local errado, _, erro = Turnos.encerrarTurno(estado, {
			actorId = "c", expectedVersion = 1, requestId = "r1",
		})
		t.eq(errado, nil)
		t.eq(erro, "Não é a vez deste participante.")
		local proximo = Turnos.encerrarTurno(estado, {
			actorId = "j", expectedVersion = 1, requestId = "r2",
		})
		local velho, _, erroVelho = Turnos.encerrarTurno(proximo, {
			actorId = "c", expectedVersion = 1, requestId = "r3",
		})
		t.eq(velho, nil)
		t.eq(erroVelho, "Versão desatualizada.")
	end,
	["custo de varias acoes e validado, debitado e incluido no replay"] = function(t)
		local estado = Turnos.criar("e", {"j", "c"})
		local insuficiente, _, erro = Turnos.consumirAcao(estado, {
			actorId = "j", expectedVersion = 1, requestId = "bola", action = "bola", actionsCost = 4,
		})
		t.eq(insuficiente, nil)
		t.ok(type(erro) == "string")
		local novo, recibo = Turnos.consumirAcao(estado, {
			actorId = "j", expectedVersion = 1, requestId = "bola", action = "bola", actionsCost = 2,
		})
		t.eq(novo.actionsRemaining, 1)
		t.eq(recibo.actionsSpent, 2)
		local replay, repetido, mensagem = Turnos.consumirAcao(novo, {
			actorId = "j", expectedVersion = 1, requestId = "bola", action = "bola", actionsCost = 2,
		})
		t.eq(mensagem, "Pedido já aplicado.")
		t.eq(repetido.version, recibo.version)
		t.eq(replay.actionsRemaining, 1)
		local conflito, _, conflitoErro = Turnos.consumirAcao(novo, {
			actorId = "j", expectedVersion = 1, requestId = "bola", action = "bola", actionsCost = 1,
		})
		t.eq(conflito, nil)
		t.eq(conflitoErro, "ID de pedido já usado com outro conteúdo.")
	end,
	["id de pedido nao pode trocar o conteudo"] = function(t)
		local estado = Turnos.criar("e", {"j", "c"})
		local proximo = Turnos.encerrarTurno(estado, {
			actorId = "j", expectedVersion = 1, requestId = "r1",
		})
		local conflitante, _, erro = Turnos.encerrarTurno(proximo, {
			actorId = "c", expectedVersion = 1, requestId = "r1",
		})
		t.eq(conflitante, nil)
		t.eq(erro, "ID de pedido já usado com outro conteúdo.")
	end,
	["retira derrotado preserva ator atual e conclui ao zerar a fila inimiga"] = function(t)
		local estado = Turnos.criar("e", {"j", "c1", "c2"})
		estado.currentIndex = 3
	local novo = Turnos.removerDerrotado(estado, "c1")
		t.eq(table.concat(novo.order, ","), "j,c2")
		t.eq(novo.currentIndex, 2)
		t.eq(Turnos.consultar(novo).currentActorId, "c2")
		local ultimo = Turnos.criar("e2", {"j", "c"})
		local vitoria = Turnos.removerDerrotado(ultimo, "c")
		t.eq(vitoria.phase, "victory")
		t.eq(#vitoria.order, 1)
		t.eq(ultimo.phase, "active", "estado original permanece imutavel")
	end,
	["desistencia versionada retira o ator ativo sem cobrar acao e aceita replay"] = function(t)
		local estado = Turnos.criar("e", { "jogador", "criatura-a", "criatura-b" })
		local novo, recibo = Turnos.desistir(estado, {
			actorId = "jogador", expectedVersion = 1, requestId = "desistir-1",
		})
		t.eq(table.concat(novo.order, ","), "criatura-a,criatura-b")
		t.eq(novo.currentIndex, 1)
		t.eq(novo.actionsRemaining, 3)
		t.eq(novo.version, 2)
		t.eq(recibo.action, "abandon-encounter")
		t.eq(recibo.nextActorId, "criatura-a")
		local replay, reciboReplay, mensagem = Turnos.desistir(novo, {
			actorId = "jogador", expectedVersion = 1, requestId = "desistir-1",
		})
		t.eq(mensagem, "Pedido já aplicado.")
		t.eq(replay.version, 2)
		t.eq(reciboReplay.version, recibo.version)
		t.eq(#novo.order, 2)
		t.eq(#estado.order, 3, "transição não altera a ordem original")
	end,
	["desistencia fora da vez ajusta indice e desistir no fim avanca rodada"] = function(t)
		local estado = Turnos.criar("e", { "jogador", "criatura-a", "criatura-b" })
		estado.currentIndex, estado.actionsRemaining = 3, 2
		local novo, recibo = Turnos.desistir(estado, {
			actorId = "criatura-a", expectedVersion = 1, requestId = "desistir-fora-da-vez",
		})
		t.eq(novo.currentIndex, 2)
		t.eq(novo.actionsRemaining, 2)
		t.eq(novo.turn, 1)
		t.eq(recibo.nextActorId, "criatura-b")
		local ultimaVez = Turnos.criar("e2", { "criatura", "jogador" })
		ultimaVez.currentIndex = 2
		local fim, reciboFim = Turnos.desistir(ultimaVez, {
			actorId = "jogador", expectedVersion = 1, requestId = "desistir-fim",
		})
		t.eq(fim.currentIndex, 1)
		t.eq(fim.turn, 2)
		t.eq(reciboFim.nextActorId, "criatura")
	end,
}
