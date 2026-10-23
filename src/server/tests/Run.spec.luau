local Shared = game:GetService("ReplicatedStorage").Shared
local Run = require(Shared.Regras.Run)
local Votacao = require(Shared.Regras.RunVotacao)
local Sorteios = require(Shared.Regras.RunSorteios)
local Defeitos = require(Shared.Regras.RunDefeitos)

-- RNG falso: devolve os valores da fila (limitados ao intervalo pedido).
local function rngFila(fila)
	return { NextInteger = function(_, lo, hi) return math.clamp(table.remove(fila, 1) or lo, lo, hi) end }
end

local function nova(jogadores)
	local estado = Run.nova({
		semente = 7,
		jogadores = jogadores or { "ana", "beto" },
		objetivo = { id = "entregar-carta", prazoDias = 10 },
	})
	return estado
end

return {
	["run nova valida jogadores e objetivo"] = function(t)
		t.ok(nova() ~= nil)
		t.ok(Run.estadoValido(nova()))
		t.eq((Run.nova({ jogadores = {}, objetivo = { id = "x", prazoDias = 5 } })), nil)
		t.eq((Run.nova({ jogadores = { "a", "a" }, objetivo = { id = "x", prazoDias = 5 } })), nil)
		t.eq((Run.nova({ jogadores = { "a", "b", "c", "d", "e" }, objetivo = { id = "x", prazoDias = 5 } })), nil)
		t.eq((Run.nova({ jogadores = { "a" }, objetivo = { id = "x", prazoDias = 0 } })), nil)
		t.eq((Run.nova({ jogadores = { "a" }, objetivo = { id = "x", prazoDias = 1.1 } })), nil)
	end,
	["estadoValido recusa save com objetivo, jogador ou fim malformados"] = function(t)
		local function com(muda)
			local e = nova()
			muda(e)
			return Run.estadoValido(e)
		end
		t.eq(com(function() end), true)
		t.eq(com(function(e) e.objetivo.prazoFinal = nil end), false)
		t.eq(com(function(e) e.objetivo.status = "qualquer" end), false)
		t.eq(com(function(e) e.objetivo.id = 7 end), false)
		t.eq(com(function(e) e.jogadores.ana.presente = nil end), false)
		t.eq(com(function(e) e.jogadores.ana.caido = "nao" end), false)
		t.eq(com(function(e) e.fim = { motivo = "outra" } end), false)
		t.eq(com(function(e) e.fim = { motivo = "queda", dia = 0 } end), true)
		t.eq(com(function(e) e.regiao = nil end), false)
	end,
	["regioes visitadas contam as distintas alem da vila e saves antigos contam zero"] = function(t)
		local e = nova()
		t.eq(Run.regioesVisitadas(e), 0)
		e = Run.moverPara(e, "floresta", "a")
		e = Run.moverPara(e, "vila", "b")
		e = Run.moverPara(e, "floresta", "c")
		e = Run.moverPara(e, "ruinas", "d")
		t.eq(Run.regioesVisitadas(e), 2)
		local antigo = nova()
		antigo.visitadas = nil
		t.eq(Run.regioesVisitadas(antigo), 0)
		t.eq(Run.estadoValido(antigo), true)
		t.eq(nova().visitadas.vila, true)
	end,
	["gastar dias nao altera o original e expira o objetivo ao passar do prazo"] = function(t)
		local inicial = nova()
		local a, expirou = Run.gastarDias(inicial, 9.75)
		t.eq(inicial.dia, 0, "estado original alterado")
		t.eq(a.dia, 9.75)
		t.eq(expirou, false)
		t.eq(Run.diasRestantes(a), 0.25)
		local b, expirou2 = Run.gastarDias(a, 0.5)
		t.eq(expirou2, true)
		t.eq(b.objetivo.status, "expirado")
		local _, expirou3 = Run.gastarDias(b, 1)
		t.eq(expirou3, false, "expira só uma vez")
		t.eq((Run.gastarDias(a, 0.3)), nil)
		t.eq((Run.gastarDias(a, -1)), nil)
	end,
	["objetivo alternativo so depois de expirar e registra o perdido"] = function(t)
		local ativo = nova()
		t.eq((Run.trocarObjetivo(ativo, "outro", 5)), nil)
		local expirado = Run.gastarDias(ativo, 11)
		local novo = Run.trocarObjetivo(expirado, "resgatar-guarda", 4)
		t.eq(novo.objetivo.id, "resgatar-guarda")
		t.eq(novo.objetivo.prazoFinal, 15)
		t.eq(novo.objetivo.status, "ativo")
		t.eq(novo.objetivosPerdidos[1], "entregar-carta")
		local cumprido = Run.cumprirObjetivo(ativo)
		t.eq(cumprido.objetivo.status, "cumprido")
		t.ok(Run.trocarObjetivo(cumprido, "bonus", 2) ~= nil)
	end,
	["flags abrem trancas sem alterar o original"] = function(t)
		local inicial = nova()
		local novo = Run.definirFlag(inicial, "corda-do-porto")
		t.eq(Run.temFlag(inicial, "corda-do-porto"), false)
		t.eq(Run.temFlag(novo, "corda-do-porto"), true)
		t.eq((Run.definirFlag(inicial, "")), nil)
	end,
	["ausente nao conta para a queda e retorna com os dias perdidos"] = function(t)
		local e = nova()
		e = Run.marcarAusente(e, "beto")
		e = Run.gastarDias(e, 2)
		local caiu = Run.marcarCaido(e, "ana")
		t.eq(Run.grupoCaiu(caiu), true, "so a presente caiu")
		local fim = Run.encerrarPorQueda(caiu)
		t.eq(fim.fim.motivo, "queda")
		t.eq((Run.gastarDias(fim, 1)), nil, "run encerrada nao avanca")
		local volta, perdidos = Run.retornar(e, "beto")
		t.eq(volta.jogadores.beto.presente, true)
		t.eq(perdidos, 2)
		t.eq(Run.grupoCaiu(Run.marcarCaido(volta, "ana")), false, "beto de pe")
		t.eq((Run.marcarAusente(e, "beto")), nil, "ja ausente")
	end,
	["final encerra a run uma vez"] = function(t)
		local e = Run.encerrarComFinal(nova(), "final-ponte")
		t.eq(e.fim.motivo, "final")
		t.eq(e.fim.final, "final-ponte")
		t.eq((Run.encerrarComFinal(e, "outro")), nil)
		t.eq(Run.encerrarPorQueda(e), e)
	end,

	["voto do explorador vale dois"] = function(t)
		local eleitores = { ana = { explorador = true }, beto = {}, cris = {} }
		local r = Votacao.resolver({ "norte", "sul" }, { ana = "norte", beto = "sul" }, eleitores)
		t.eq(r.vencedora, "norte")
		t.eq(r.contagem.norte, 2)
		t.eq(r.contagem.sul, 1)
		local r2 = Votacao.resolver({ "norte", "sul" }, { ana = "norte", beto = "sul", cris = "sul" }, eleitores,
			function() return 1 end)
		t.eq(r2.contagem.sul, 2)
		t.eq(r2.empatadas[2], "sul")
	end,
	["empate rola dado entre as opcoes empatadas e valida o dado"] = function(t)
		local eleitores = { ana = {}, beto = {} }
		local lados
		local r = Votacao.resolver({ "a", "b", "c" }, { ana = "a", beto = "c" }, eleitores, function(n)
			lados = n
			return 2
		end)
		t.eq(lados, 2)
		t.eq(r.dado, 2)
		t.eq(r.vencedora, "c")
		t.eq((Votacao.resolver({ "a", "b" }, { ana = "a", beto = "b" }, eleitores)), nil, "sem dado")
		t.eq((Votacao.resolver({ "a", "b" }, { ana = "a", beto = "b" }, eleitores, function() return 3 end)), nil)
	end,
	["ausente, estranho e opcao inexistente nao votam"] = function(t)
		local eleitores = { ana = {}, beto = { presente = false } }
		local r = Votacao.resolver({ "a", "b" }, { ana = "a", beto = "b", intruso = "b", ana2 = "x" }, eleitores)
		t.eq(r.vencedora, "a")
		t.eq(r.contagem.b, 0)
		t.eq((Votacao.resolver({ "a" }, { beto = "a" }, eleitores)), nil, "so ausente votou")
		local pend = Votacao.pendentes({ "a", "b" }, { ana = "a" }, { ana = {}, beto = {}, cris = { presente = false } })
		t.eq(#pend, 1)
		t.eq(pend[1], "beto")
	end,

	["peso por forca: mais forte, mais rara"] = function(t)
		t.eq(Sorteios.pesoDeForca(1), 10)
		t.eq(Sorteios.pesoDeForca(10), 1)
		t.eq(Sorteios.pesoDeForca(0), nil)
		t.eq(Sorteios.pesoDeForca(11), nil)
		t.eq(Sorteios.pesoDeForca(2.5), nil)
	end,
	["sorteio ponderado nao repete e respeita o peso"] = function(t)
		local itens = { { id = "a", peso = 1 }, { id = "b", peso = 3 } }
		-- total 4: valor 1 cai em a; valor 2..4 cai em b.
		t.eq(Sorteios.ponderado(itens, 1, rngFila({ 1 }))[1], "a")
		t.eq(Sorteios.ponderado(itens, 1, rngFila({ 2 }))[1], "b")
		local dois = Sorteios.ponderado(itens, 2, rngFila({ 4, 1 }))
		t.eq(dois[1], "b")
		t.eq(dois[2], "a")
		t.eq(#Sorteios.ponderado(itens, 5, rngFila({ 1, 1 })), 2, "limitado ao que existe")
		t.eq((Sorteios.ponderado({ { id = "x", peso = 0 } }, 1, rngFila({}))), nil)
	end,
	["oferta de arvores segue a composicao e a forca"] = function(t)
		local arvores = {
			{ id = "espada", categoria = "corpo", forca = 5 },
			{ id = "arco", categoria = "corpo", forca = 5 },
			{ id = "escudo", categoria = "corpo", forca = 5 },
			{ id = "lanca", categoria = "corpo", forca = 5 },
			{ id = "fogo", categoria = "magia", forca = 8 },
			{ id = "agua", categoria = "magia", forca = 4 },
			{ id = "bardo", categoria = "utilidade", forca = 3 },
		}
		local oferta = Sorteios.ofertaDeArvores(arvores, rngFila({ 1, 1, 1, 1, 1, 1 }))
		t.eq(#oferta, 6)
		t.eq(oferta[1], "espada")
		t.eq(oferta[6], "bardo")
		-- Categoria com menos candidatas do que o pedido traz as que existem.
		local pouco = Sorteios.ofertaDeArvores({ { id = "so", categoria = "corpo", forca = 1 } }, rngFila({}))
		t.eq(#pouco, 1)
		t.eq((Sorteios.ofertaDeArvores({ { id = "x", categoria = "corpo", forca = 99 } }, rngFila({}))), nil)
	end,
	["treinadores da vila: sorteio proprio e extra na taverna so de quem ainda nao saiu"] = function(t)
		local cands = {
			{ id = "lutador" }, { id = "mago-fogo" }, { id = "curandeiro" },
			{ id = "bardo", taverna = true }, { id = "mago-agua" },
		}
		-- 3 treinadores (1,1,1 -> lutador, mago-fogo, curandeiro), taverna: 100% sorteia bardo.
		local ids, extra = Sorteios.treinadoresDaVila(cands, 3, 100, rngFila({ 1, 1, 1, 1, 1 }))
		t.eq(#ids, 4)
		t.eq(extra, "bardo")
		t.eq(ids[4], "bardo")
		-- Chance 0: nunca consome dado de taverna.
		local ids2, extra2 = Sorteios.treinadoresDaVila(cands, 3, 0, rngFila({ 1, 1, 1 }))
		t.eq(#ids2, 3)
		t.eq(extra2, nil)
		-- Bardo ja saiu entre os 3: nao ha extra elegivel.
		local ids3, extra3 = Sorteios.treinadoresDaVila({ { id = "bardo", taverna = true }, { id = "b" }, { id = "c" } },
			3, 100, rngFila({ 1, 1, 1, 1 }))
		t.eq(#ids3, 3)
		t.eq(extra3, nil)
	end,

	["defeitos: sorteio distinto e efeitos do livro"] = function(t)
		local ids = Defeitos.sortear(2, rngFila({ 1, 1 }))
		t.eq(#ids, 2)
		t.ok(ids[1] ~= ids[2])
		t.eq((Defeitos.sortear(99, rngFila({}))), nil)
		local ef = Defeitos.efeitos({ "manco", "burro" })
		t.eq(ef.deslocamentoMenos, 3)
		t.eq(ef.desvantagemEm["Investigação"], true)
		t.eq(ef.bloqueia.enigma, true)
		t.eq((Defeitos.efeitos({ "inexistente" })), nil)
	end,
	["defeito bloqueia opcao de evento pela tag"] = function(t)
		t.eq(Defeitos.bloqueiaOpcao({ "burro" }, { "enigma" }), true)
		t.eq(Defeitos.bloqueiaOpcao({ "burro" }, { "forca" }), false)
		t.eq(Defeitos.bloqueiaOpcao({}, { "enigma" }), false)
		t.eq(Defeitos.bloqueiaOpcao({ "zangado", "manco" }, { "escalada", "x" }), true)
	end,
}
