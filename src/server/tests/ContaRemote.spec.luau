local Servico = require(game:GetService("ReplicatedStorage").Shared.Regras.ContaTransacoes)
local Conta = require(game:GetService("ReplicatedStorage").Shared.Regras.RunConta)

local function montar()
	local dados, chamadas = {}, 0
	local store = { atualizar = function(chave, f)
		chamadas += 1
		local novo = f(dados[chave])
		if novo ~= nil then dados[chave] = novo end
		return dados[chave]
	end }
	local api = Servico.start({ store = store })
	local player, outro = { UserId = 71 }, { UserId = 72 }
	local agora, conectado, livre = 0, true, true
	local deps = {
		relogio = function() return agora end,
		autenticado = function(p) return conectado and (p == player or p == outro) end,
		entreRuns = function() return livre end,
	}
	local handler, remover = Servico.criarHandler(api, deps)
	return {
		api = api, handler = handler, remover = remover, deps = deps, player = player, outro = outro, dados = dados,
		avancar = function() agora += 0.5 end,
		conectar = function(v) conectado = v end, livre = function(v) livre = v end,
		chamadas = function() return chamadas end,
		saldo = function(n) local c = Conta.nova(); c.moeda = n; dados["conta/71"] = c end,
	}
end

local function compra(id, item)
	return { acao = "comprar", requestId = id, itemId = item or "item:pocao-menor" }
end

return {
	["payload fechado recusa tipos IDs limites campos e ações desconhecidas"] = function(t)
		for _, p in { false, "texto", {}, { acao = "consultar" }, { acao = "registrarRun", requestId = "a" },
			{ acao = "consultar", requestId = 5 }, { acao = "consultar", requestId = "" },
			{ acao = "consultar", requestId = string.rep("a", 65) }, { acao = "consultar", requestId = "a/b" },
			{ acao = "consultar", requestId = "a", userId = 72 }, { acao = "consultar", requestId = "a", itemId = "x" },
			{ acao = "comprar", requestId = "a", itemId = {} }, compra("a", "raca:inventada"),
			setmetatable({ acao = "consultar", requestId = "a" }, {}) } do
			t.eq(Servico.payloadValido(p), false)
		end
		t.eq(Servico.payloadValido({ acao = "consultar", requestId = "abc_123-4" }), true)
		t.eq(Servico.payloadValido(compra("a")), true)
		local m = montar()
		m.handler(m.player, { acao = "comprar", requestId = "a", itemId = "item:pocao-menor", moeda = 999 })
		t.eq(m.chamadas(), 0)
	end,
	["somente identidade autenticada pode acessar conta privada"] = function(t)
		local m = montar()
		t.eq(m.handler({ UserId = 71 }, compra("a")), nil)
		m.conectar(false)
		t.eq(m.handler(m.player, { acao = "consultar", requestId = "a" }), nil)
		t.eq(m.chamadas(), 0)
		m.conectar(true); m.saldo(60)
		t.eq(m.handler(m.outro, { acao = "consultar", requestId = "a" }).conta.moeda, 0)
		t.eq(m.dados["conta/71"].moeda, 60)
	end,
	["saldo insuficiente nao debita nem desbloqueia e replay conserva recusa"] = function(t)
		local m = montar(); m.saldo(59)
		local r = m.handler(m.player, compra("a"))
		t.eq(r.ok, false); t.eq(r.mensagem, "Moeda insuficiente.")
		t.eq(m.dados["conta/71"].moeda, 59)
		t.eq(m.dados["conta/71"].desbloqueios["item:pocao-menor"], nil)
		m.saldo(100); m.avancar()
		t.eq(m.handler(m.player, compra("a")).ok, false)
		t.eq(m.dados["conta/71"].moeda, 100)
	end,
	["sucesso replay e reconexao nao debitam duas vezes nem aceitam outra assinatura"] = function(t)
		local m = montar(); m.saldo(100)
		t.eq(m.handler(m.player, compra("a")).conta.moeda, 40)
		m.avancar()
		t.eq(m.handler(m.player, compra("a")).ok, true)
		t.eq(m.dados["conta/71"].moeda, 40)
		m.avancar()
		t.eq(m.handler(m.player, compra("a", "cosmetico:capa-vermelha")).ok, false)
		-- Novo handler simula reconexão/servidor novo, mantendo apenas o armazenamento.
		local novo = Servico.criarHandler(m.api, m.deps)
		t.eq(novo(m.player, compra("a")).ok, true)
		m.avancar()
		t.eq(novo(m.player, compra("a", "cosmetico:capa-vermelha")).ok, false)
		t.eq(m.dados["conta/71"].moeda, 40)
	end,
	["intervalo minimo limita ate consultas sem acessar armazenamento"] = function(t)
		local m = montar()
		t.eq(m.handler(m.player, { acao = "consultar", requestId = "a" }).ok, true)
		local chamadas = m.chamadas()
		t.eq(m.handler(m.player, { acao = "consultar", requestId = "b" }).ok, false)
		t.eq(m.chamadas(), chamadas)
		m.avancar()
		t.eq(m.handler(m.player, { acao = "consultar", requestId = "b" }).ok, true)
	end,
	["contexto de run bloqueia compra mas permite consultar"] = function(t)
		local m = montar(); m.saldo(100); m.livre(false)
		t.eq(m.handler(m.player, compra("a")).ok, false)
		t.eq(m.chamadas(), 0)
		m.avancar()
		t.eq(m.handler(m.player, { acao = "consultar", requestId = "b" }).ok, true)
	end,
	["UpdateAsync revalida contexto depois de esperar armazenamento"] = function(t)
		local livre, c = true, Conta.nova(); c.moeda = 100
		local api = Servico.start({ store = { atualizar = function(_, f) livre = false; local novo = f(c); if novo then c = novo end; return c end } })
		local p = { UserId = 71 }
		local handler = Servico.criarHandler(api, { relogio = function() return 0 end, autenticado = function(v) return v == p end, entreRuns = function() return livre end })
		t.eq(handler(p, compra("a")).ok, false)
		t.eq(c.moeda, 100)
	end,
	["pedido concorrente nao ultrapassa trava durante UpdateAsync"] = function(t)
		local handler, p, simultaneo
		p = { UserId = 71 }
		local c = Conta.nova(); c.moeda = 100
		local agora = 0
		local api = Servico.start({ store = { atualizar = function(_, f)
			agora += 1
			simultaneo = handler(p, compra("b", "cosmetico:capa-vermelha"))
			c = f(c) or c; return c
		end } })
		handler = Servico.criarHandler(api, { relogio = function() return agora end, autenticado = function(v) return v == p end, entreRuns = function() return true end })
		t.eq(handler(p, compra("a")).ok, true)
		t.eq(simultaneo.ok, false); t.eq(c.moeda, 40)
	end,
	["replay devolve saldo atual em vez de regredir snapshot"] = function(t)
		local m = montar(); m.saldo(100)
		t.eq(m.handler(m.player, compra("a")).ok, true)
		m.api.registrarRun(71, { status = "derrota", regioesVisitadas = 1 })
		m.avancar()
		t.eq(m.handler(m.player, compra("a")).conta.moeda, 70)
	end,
	["UpdateAsync repetido usa apenas o resultado da ultima transformacao"] = function(t)
		local c = Conta.nova(); c.moeda = 100
		local api = Servico.start({ store = { atualizar = function(_, f)
			t.eq(f(Conta.nova()), nil) -- primeira tentativa sem saldo perde a corrida
			c = f(c); return c -- segunda transformação já vê o saldo atualizado
		end } })
		local nova = api.comprar(71, "item:pocao-menor", "a")
		t.eq(nova.moeda, 40)
		t.eq(nova.comprasRequests.a, "item:pocao-menor")
	end,
	["falha de armazenamento responde recusa e libera trava"] = function(t)
		local m = montar()
		local api = Servico.start({ store = { atualizar = function() error("indisponivel") end } })
		local handler = Servico.criarHandler(api, m.deps)
		t.eq(handler(m.player, compra("a")).ok, false)
		m.avancar()
		local r = handler(m.player, { acao = "consultar", requestId = "b" })
		t.eq(r.ok, false); t.eq(r.mensagem, "Falha ao acessar a conta.")
	end,
	["limite de recibos preserva IDs antigos e saida limpa sessao"] = function(t)
		local m = montar()
		for i = 1, 128 do
			t.eq(m.handler(m.player, { acao = "consultar", requestId = tostring(i) }).ok, true)
			m.avancar()
		end
		t.eq(m.handler(m.player, { acao = "consultar", requestId = "129" }).ok, false)
		m.remover(m.player)
		t.eq(m.handler(m.player, { acao = "consultar", requestId = "129" }).ok, true)
	end,
}
