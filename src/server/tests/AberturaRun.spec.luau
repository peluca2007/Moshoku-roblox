local Shared = game:GetService("ReplicatedStorage").Shared
local Abertura = require(Shared.Regras.AberturaRun)
local Conta = require(Shared.Regras.RunConta)
local Sessao = require(Shared.Regras.RunSessao)
local Objetivos = require(Shared.Regras.Objetivos)
local Povoamento = require(Shared.Mundo.PropsPovoamento)

return {
	["primeira expedicao ignora modo solicitado e nasce no portao sem arvore nem voto"] = function(t)
		local modo = Abertura.modo(Conta.nova(), "pronto")
		t.eq(modo, "semArvore")
		local sessao = Sessao.new({ rng = { NextInteger = function(_, lo) return lo end }, guardar = function() end, carregar = function() end })
		t.ok(sessao:iniciar("p2", {{userId = 1}}, {[1] = modo}))
		local v = sessao:visao(1)
		t.eq(v.plano.modo, "semArvore")
		t.eq(v.plano.escolhida, nil)
		t.eq(v.regiao, "vila")
		t.eq(next(sessao.votos), nil)
		local p = Abertura.nascimento()
		t.eq(p.x, 0); t.eq(p.z, Povoamento.PORTAO_NORTE - Abertura.RECUO_PORTAO)
		t.ok(Abertura.RECUO_PORTAO >= 14) -- câmera do mundo passa por cima do telhado do portão
		local objetivo = Objetivos.atual({run=v,posicao=p,treinadores={{id="vila-1",disponivel=true,posicao={x=65,y=0,z=-252}}}})
		t.eq(objetivo.titulo, "Fale com um mestre da vila")
	end,
	["somente fim ou derrota libera modos e conta antiga continua valida"] = function(t)
		local conta = Conta.nova()
		t.eq(Conta.modosLiberados(conta), false)
		for _, status in {"final", "derrota"} do
			local nova = Conta.registrarRun(conta, {status=status,regioesVisitadas=1})
			t.eq(Conta.modosLiberados(nova), true)
			t.eq(Conta.valida(nova), true)
			for _, modo in Abertura.MODOS do t.eq(Abertura.modo(nova, modo.id), modo.id) end
		end
		t.eq(Conta.modosLiberados(conta), false)
		t.eq(Conta.registrarRun(conta, {status="ativo",regioesVisitadas=1}), nil)
		conta.conquistas["primeiro-final"] = true
		t.eq(Conta.modosLiberados(conta), true)
		conta.primeiraRunTerminada = "sim"
		t.eq(Conta.valida(conta), false)
	end,
	["abertura vista: marca idempotente, conta antiga valida e campo invalido recusado"] = function(t)
		local conta = Conta.nova()
		t.eq(Conta.aberturaVista(conta), false)
		local vista = Conta.marcarAberturaVista(conta)
		t.eq(Conta.aberturaVista(vista), true)
		t.eq(Conta.valida(vista), true)
		t.eq(Conta.marcarAberturaVista(vista), vista) -- idempotente: nada a regravar
		t.eq(conta.aberturaVista, nil) -- imutável
		vista.aberturaVista = "sim"
		t.eq(Conta.valida(vista), false)
	end,
	["remoto da conta aceita abertura vista sem campos extras e grava uma vez"] = function(t)
		local Transacoes = require(Shared.Regras.ContaTransacoes)
		t.eq(Transacoes.payloadValido({ acao = "aberturaVista", requestId = "a1" }), true)
		t.eq(Transacoes.payloadValido({ acao = "aberturaVista", requestId = "a1", itemId = "x" }), false)
		t.eq(Transacoes.payloadValido({ acao = "aberturaVista" }), false)
		local dados = {}
		local api = Transacoes.start({ store = { atualizar = function(chave, f)
			local novo = f(dados[chave]); if novo ~= nil then dados[chave] = novo end; return dados[chave]
		end } })
		local jogador = { UserId = 5 }
		local tempo = 0
		local processar2 = Transacoes.criarHandler(api, { relogio = function() tempo += 1; return tempo end, autenticado = function() return true end, entreRuns = function() return false end })
		local r = processar2(jogador, { acao = "aberturaVista", requestId = "a1" })
		t.eq(r.ok, true); t.eq(r.conta.aberturaVista, true)
		local r2 = processar2(jogador, { acao = "aberturaVista", requestId = "a2" })
		t.eq(r2.ok, true); t.eq(r2.conta.aberturaVista, true)
	end,
}
