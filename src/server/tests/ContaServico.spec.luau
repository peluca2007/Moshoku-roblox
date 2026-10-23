-- SOMENTE STUDIO: módulos de server/ não são montados pelo harness externo.
local Servico = require(script.Parent.Parent.ContaServico)
local Run = require(script.Parent.Parent.RunServico)

local function memoria()
	local dados = {}
	return { atualizar = function(chave, f)
		local novo = f(dados[chave])
		if novo ~= nil then dados[chave] = novo end
		return dados[chave]
	end, dados = dados }
end

return {
	["obter cria conta vazia e registrarRun soma moeda, conquistas e codice"] = function(t)
		local s = Servico.start({ store = memoria() })
		local c = s.obter(7)
		t.eq(c.moeda, 0)
		local conta, ganhos = s.registrarRun(7, { status = "final", regioesVisitadas = 1, objetivoCumprido = true }, "final-selo")
		t.eq(conta.moeda, 140)
		t.eq(ganhos.moeda, 140)
		t.eq(conta.codice.final["final-selo"], true)
		t.eq(s.obter(7).moeda, 140)
		t.eq(s.obter(8).moeda, 0)
	end,
	["comprar desconta, nao repete e recusa sem moeda"] = function(t)
		local s = Servico.start({ store = memoria() })
		local nada, motivo = s.comprar(1, "treinador:agua")
		t.eq(nada, nil)
		t.eq(motivo, "Moeda insuficiente.")
		s.registrarRun(1, { status = "final", regioesVisitadas = 3, objetivoCumprido = true }, "f") -- 160
		local c = s.comprar(1, "treinador:agua")
		t.eq(c.moeda, 10)
		t.eq(c.desbloqueios["treinador:agua"], true)
		local _, m2 = s.comprar(1, "treinador:agua")
		t.eq(m2, "Já desbloqueado.")
	end,
	["resumo invalido nao altera a conta e conta corrompida e recusada"] = function(t)
		local m = memoria()
		local s = Servico.start({ store = m })
		t.eq((s.registrarRun(2, { status = "?", regioesVisitadas = 0 }, nil)), nil)
		t.eq(s.obter(2).moeda, 0)
		m.dados["conta/3"] = { versao = 99 }
		local c, motivo = s.obter(3)
		t.eq(c, nil)
		t.eq(motivo, "Conta corrompida.")
	end,
	["falha do armazenamento vira recusa sem lancar erro"] = function(t)
		local s = Servico.start({ store = { atualizar = function() error("fora do ar") end } })
		local c, motivo = s.obter(1)
		t.eq(c, nil)
		t.eq(motivo, "Falha ao acessar a conta.")
	end,
	["payload do RunServico: campos fechados e modos validos"] = function(t)
		t.eq(Run.payloadValido({ acao = "consultar" }), true)
		t.eq(Run.payloadValido({ acao = "iniciar", modo = "pronto" }), true)
		t.eq(Run.payloadValido({ acao = "iniciar", modo = "magico" }), false)
		t.eq(Run.payloadValido({ acao = "votar", opcao = "x" }), true)
		t.eq(Run.payloadValido({ acao = "votar", opcao = 5 }), false)
		t.eq(Run.payloadValido({ acao = "votar", opcao = "x", extra = 1 }), false)
		t.eq(Run.payloadValido({ acao = "escolherArvore", arvore = string.rep("a", 65) }), false)
		t.eq(Run.payloadValido({ acao = "desconhecida" }), false)
		t.eq(Run.payloadValido("texto"), false)
		t.eq(Run.payloadValido(setmetatable({ acao = "consultar" }, {})), false)
	end,
}
