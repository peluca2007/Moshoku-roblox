local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(Shared.Regras.RunTreinadores)
local Sessao = require(Shared.Regras.RunSessao)
local Treinadores = require(Shared.Regras.RunTreinadores)
local Provas = require(Shared.Regras.Provacoes)

local function montar()
	local m = { agora = 0, distancia = 10, conectado = true, combate = false, falhar = false, chamadas = 0, dados = {} }
	m.player = { UserId = 7 }; m.outro = { UserId = 8 }
	m.depsSessao = {
		rng = { NextInteger = function(_, lo) return lo end },
		guardar = function(k, v)
			m.chamadas += 1
			if m.durante then m.durante() end
			if m.falhar then error("store offline") end
			m.dados[k] = v
		end,
		carregar = function(k) return m.dados[k] end,
	}
	m.sessao = Sessao.new(m.depsSessao)
	assert(m.sessao:iniciar("f4", { { userId = 7 }, { userId = 8 } }, { [7] = "semArvore", [8] = "semArvore" }))
	m.deps = {
		sessao = function() return m.sessao end,
		autenticado = function(p) return m.conectado and (p == m.player or p == m.outro) end,
		relogio = function() return m.agora end,
		perto = function(_, _, id) return m.distancia <= 10 and (id ~= "taverna" or m.sessao.treinadores.taverna ~= nil) end,
		emCombate = function() return m.combate end,
		iniciarProvacao = function(player, sessao, npc)
			sessao.provacoes = sessao.provacoes or {}
			local prova = sessao.provacoes[npc.id] or Provas.nova()
			sessao.provacoes[npc.id] = prova
			return Provas.iniciar(prova, player.UserId, m.agora,
				if npc.arvore == "agua" then Provas.DURACAO_AGUA else nil)
		end,
	}
	m.handler, m.remover = Servico.criarHandler(m.deps)
	m.avancar = function() m.agora += 0.5 end
	m.compra = function(id)
		return { acao = "comprar", npcId = "vila-1", arvore = m.sessao.treinadores.vila[1], requestId = id or "a" }
	end
	m.aceitar = function(npcId, id)
		return { acao = "aceitar", npcId = npcId or "vila-1", requestId = id or "aceitar" }
	end
	m.aprovar = function(npcId, userId)
		npcId, userId = npcId or "vila-1", userId or 7
		m.sessao.provacoes = m.sessao.provacoes or {}
		local prova = m.sessao.provacoes[npcId] or Provas.nova()
		m.sessao.provacoes[npcId] = prova
		if prova.userId == nil then assert(Provas.iniciar(prova, userId, m.agora)) end
		return Provas.aprovar(prova, userId, m.agora)
	end
	return m
end

return {
	["payload fechado recusa tipos campos extras tamanho assinatura e NPC inventado"] = function(t)
		for _, p in { false, {}, { acao = "comprar", npcId = "vila-1", arvore = "cura" },
			{ acao = "consultar", requestId = "a/b", npcId = "vila-1" },
			{ acao = "consultar", requestId = string.rep("a", 65), npcId = "vila-1" },
			{ acao = "consultar", requestId = "a", npcId = "vila-5" },
			{ acao = "comprar", requestId = "a", npcId = "vila-1", arvore = {} },
			{ acao = "consultar", requestId = "a", npcId = "vila-1", arvore = "cura" },
			{ acao = "comprar", requestId = "a", npcId = "vila-1", arvore = "cura", custoPa = 0 },
			{ acao = "comprar", requestId = "a", npcId = "vila-1", arvore = "cura", userId = 8 },
			setmetatable({ acao = "consultar", requestId = "a", npcId = "vila-1" }, {}) } do
			t.eq(Servico.payloadValido(p), false)
		end
		local m = montar(); t.eq(Servico.payloadValido(m.compra()), true)
		t.eq(m.handler({ UserId = 7 }, m.compra()), nil)
		m.conectado = false; t.eq(m.handler(m.player, m.compra()), nil)
	end,
	["consulta mostra termos canonicos sem debitar e nao concede ao outro jogador"] = function(t)
		local m = montar(); local chamadas = m.chamadas
		local r = m.handler(m.player, { acao = "consultar", npcId = "vila-1", requestId = "c" })
		t.eq(r.ok, true); t.eq(r.oferta.custoPa, 0); t.eq(r.oferta.dias, 1)
		t.eq(r.oferta.podeComprar, true); t.eq(m.chamadas, chamadas)
		m.avancar(); t.eq(m.handler(m.player, m.aceitar()).ok, true)
		t.eq(Provas.emCurso(m.sessao.provacoes["vila-1"], 7), true)
		t.eq(m.sessao.planos[7].escolhida, nil)
		t.eq(m.aprovar(), true)
		m.avancar(); t.eq(m.handler(m.player, m.compra()).ok, true)
		t.eq(m.sessao.planos[8].escolhida, nil); t.eq(m.sessao.planos[8].paExtra, 2)
		t.eq(m.sessao.planos[7].paExtra, 2)
	end,
	["compra sem aprovacao ou durante prova recusa e nao gasta dias"] = function(t)
		local m = montar()
		t.eq(m.handler(m.player, m.compra()).ok, false)
		t.eq(m.sessao.run.dia, 0); t.eq(m.sessao.planos[7].paExtra, 2)
		m.avancar(); t.eq(m.handler(m.player, m.aceitar()).ok, true)
		m.avancar(); t.eq(m.handler(m.player, m.compra("em-curso")).ok, false)
		t.eq(m.sessao.run.dia, 0); t.eq(m.sessao.planos[7].escolhida, nil)
		t.eq(m.aprovar(), true)
		m.avancar(); t.eq(m.handler(m.player, m.compra("aprovado")).ok, true)
		t.eq(m.sessao.run.dia, 1)
	end,
	["distancia limite aceita dez recusa mais NPC ausente e arvore trocada"] = function(t)
		local m = montar(); m.distancia = 10.001
		t.eq(m.handler(m.player, m.compra()).ok, false)
		m.distancia = 10; t.eq(m.aprovar(), true); m.avancar(); t.eq(m.handler(m.player, m.compra("b")).ok, true)
		m = montar(); local pedido = m.compra(); pedido.npcId = "vila-4"
		t.eq(m.handler(m.player, pedido).ok, false)
		m = montar(); pedido = m.compra(); pedido.arvore = m.sessao.treinadores.vila[2]
		t.eq(m.handler(m.player, pedido).ok, false); t.eq(m.sessao.run.dia, 0)
	end,
	["combate modo saldo e run ativa sao obrigatorios"] = function(t)
		for _, alterar in {
			function(m) m.combate = true end,
			function(m) m.sessao.planos[7].modo = "pronto" end,
			function(m) m.sessao.run.jogadores[7].presente = false end,
			function(m) m.sessao.run.jogadores[7].caido = true end,
			function(m) m.sessao.run.regiao = "outra" end,
			function(m) m.sessao.run.fim = {} end,
			function(m) m.sessao.run.jogadores[7] = nil end,
		} do
			local m = montar(); m.aprovar(); alterar(m)
			local chamadas = m.chamadas
			t.eq(m.handler(m.player, m.compra()).ok, false); t.eq(m.chamadas, chamadas)
		end
	end,
	["intervalo e replay preservam recusa e assinatura sem cobrar novamente"] = function(t)
		local m = montar(); m.aprovar()
		t.eq(m.handler(m.player, m.compra()).ok, true)
		t.eq(m.handler(m.player, m.compra("b")).ok, false)
		local chamadas = m.chamadas
		m.avancar(); t.eq(m.handler(m.player, m.compra()).ok, true); t.eq(m.chamadas, chamadas)
		m.avancar(); local p = m.compra(); p.npcId = "vila-2"
		t.eq(m.handler(m.player, p).ok, false)
		m = montar(); m.combate = true; t.eq(m.handler(m.player, m.compra()).ok, false)
		m.avancar(); m.combate = false; t.eq(m.handler(m.player, m.compra()).ok, false)
		t.eq(m.sessao.run.dia, 0)
	end,
	["recibo salvo impede segunda cobranca apos reconexao e servidor novo"] = function(t)
		local m = montar(); m.aprovar(); t.eq(m.handler(m.player, m.compra()).ok, true)
		local chamadas = m.chamadas
		m.sessao = Sessao.new(m.depsSessao); t.eq((m.sessao:retomar("f4")), true)
		local handler = Servico.criarHandler(m.deps)
		t.eq(handler(m.player, m.compra()).ok, true); t.eq(m.chamadas, chamadas)
		m.avancar(); local p = m.compra(); p.arvore = "inventada"
		t.eq(handler(m.player, p).ok, false); t.eq(m.sessao.run.dia, 1)
	end,
	["store falha desfaz transacao libera trava e novo pedido pode comprar"] = function(t)
		local m = montar(); m.aprovar(); m.falhar = true
		t.eq(m.handler(m.player, m.compra()).ok, false)
		t.eq(m.sessao.run.dia, 0); t.eq(m.sessao.planos[7].paExtra, 2)
		m.falhar = false; m.avancar()
		t.eq(m.handler(m.player, m.compra("b")).ok, true)
	end,
	["compra concorrente de outro jogador durante store nao sobrescreve dias ou planos"] = function(t)
		local m = montar(); m.aprovar(); local concorrente
		m.durante = function()
			concorrente = m.handler(m.outro, m.compra("outro"))
			t.eq(m.handler(m.player, m.compra("outroId")).ok, false)
		end
		t.eq(m.handler(m.player, m.compra()).ok, true)
		t.eq(concorrente.ok, false); t.eq(m.sessao.run.dia, 1); t.eq(m.sessao.planos[8].paExtra, 2)
	end,
	["limite de recusas nao expulsa IDs antigos e saida limpa cache"] = function(t)
		local m = montar(); m.combate = true
		for i = 1, 128 do t.eq(m.handler(m.player, m.compra(tostring(i))).ok, false); m.avancar() end
		m.combate = false
		t.eq(m.handler(m.player, m.compra("129")).ok, false)
		m.avancar(); t.eq(m.handler(m.player, m.compra("1")).ok, false)
		m.remover(m.player); m.avancar()
		m.aprovar()
		t.eq(m.handler(m.player, m.compra("129")).ok, true)
	end,
}
