local Shared = game:GetService("ReplicatedStorage").Shared
local Objetivos = require(Shared.Regras.Objetivos)
local Historia = require(Shared.Mundo.HistoriaV1)
local RunHistoria = require(Shared.Regras.RunHistoria)

local function run(overrides)
	local r = {
		galho = "vila", regiao = "vila", plano = { modo = "zero" },
		objetivo = { id = "levar-o-selo-a-vila", status = "ativo", prazoFinal = 12 },
		dia = 0, diasRestantes = 12, opcoes = {
			{ id = "rumo-a-floresta", texto = "Seguir para a Floresta Sombria", liberada = true },
			{ id = "rumo-as-ruinas", texto = "Seguir para as Ruínas do Vale", liberada = true },
		},
	}
	for k, v in overrides or {} do r[k] = v end
	return r
end

return {
	["mundo aberto oferece caçada com recompensas reais antes da floresta"] = function(t)
		local r = run({ mundoAberto = true, plano = { modo = "pronto" }, opcoes = {} })
		local o = Objetivos.atual({ run = r })
		t.eq(o.chave, "fazer-cacada")
		t.eq(o.alvo.id, "quadro-cacadas")
		t.ok(o.linha:find("ouro e PA de aprimoramento", 1, true) ~= nil)
		t.ok(not o.titulo:find("experiência", 1, true))
		for _, caso in { { cacadaConcluida = true }, { dia = 2 }, { diasRestantes = 3 } } do
			local outra = table.clone(r)
			for k, v in caso do outra[k] = v end
			local proximo = Objetivos.atual({ run = outra })
			t.eq(proximo.chave, "seguir-floresta")
			t.eq(proximo.alvo.id, "floresta")
			t.ok(proximo.linha:find("a pé", 1, true) ~= nil)
		end
	end,
	["mundo aberto leva selo a pé sem antecipar entrega por voto"] = function(t)
		local r = run({ mundoAberto = true, seloObtido = true, galho = "chefe-floresta",
			regiao = "floresta-sombria", plano = { modo = "pronto" }, opcoes = {} })
		local o = Objetivos.atual({ run = r })
		t.eq(o.chave, "voltar-vila")
		t.eq(o.alvo.id, "vila")
		t.ok(o.linha:find("Volte a pé", 1, true) ~= nil)
		r.galho, r.regiao = "retorno", "vila"
		r.opcoes = { { id = "entregar-o-selo", texto = "Entregar o Selo na vila", liberada = true } }
		o = Objetivos.atual({ run = r })
		t.eq(o.chave, "entregar-selo")
		t.eq(o.alvo, nil)
	end,
	["caçada não substitui combate evento prazo ou aprendizado inicial"] = function(t)
		local r = run({ mundoAberto = true, opcoes = {} })
		t.eq(Objetivos.atual({ run = r }).chave, "escolher-arvore")
		t.eq(Objetivos.atual({ run = r, emEncontro = true }), nil)
		r.evento = { id = "caminho" }
		t.eq(Objetivos.atual({ run = r }).chave, "resolver-evento")
		r.evento = nil
		r.objetivo = { status = "expirado" }
		t.eq(Objetivos.atual({ run = r }).chave, "prazo-esgotado")
	end,
	["combate e fim têm precedência sobre objetivos de preparação"] = function(t)
		t.eq(Objetivos.atual({ emEncontro = true, run = run() }), nil)
		local o = Objetivos.atual({ run = run({ fim = { motivo = "final" } }), semRun = true })
		t.eq(o.chave, "final-concluido")
	end,
	["sem RUN oferece iniciar e árvore zero aponta ao painel"] = function(t)
		t.eq(Objetivos.atual({ semRun = true }).chave, "iniciar-run")
		t.eq(Objetivos.atual({ run = { semRun = true } }).chave, "iniciar-run")
		local o = Objetivos.atual({ run = run() })
		t.eq(o.chave, "escolher-arvore")
		t.ok(not o.titulo:find("navegacao", 1, true))
	end,
	["prazo expirado informa painel sem encerrar a RUN"] = function(t)
		local o = Objetivos.atual({ run = run({ objetivo = { status = "expirado" }, diasRestantes = 0 }) })
		t.eq(o.chave, "prazo-esgotado")
		t.ok(o ~= nil)
	end,
	["próximo passo de história respeita opções liberadas"] = function(t)
		local opcoes = {
			{ id = "rumo-a-floresta", texto = "Seguir para a Floresta Sombria", liberada = false },
			{ id = "rumo-as-ruinas", texto = "Seguir para as Ruínas do Vale", liberada = true },
		}
		local o = Objetivos.atual({ run = run({ galho = "vila", plano = { modo = "pronto" }, opcoes = opcoes }) })
		t.eq(o.chave, "seguir-historia")
		t.ok(o.linha:find("Abra a RUN e vote: Seguir para as Ruínas do Vale", 1, true) ~= nil)
		t.ok(o.linha:find("Restam 12.0 dias", 1, true) ~= nil)
		local floresta = Objetivos.atual({ run = run({ galho = "floresta-sombria", plano = { modo = "pronto" }, opcoes = {
			{ id = "enfrentar-o-guardiao", texto = "Enfrentar o guardião da floresta", liberada = true },
		} }) })
		t.eq(floresta.alvo, nil)
	end,
	["provação tem prioridade e escolhe destino correto"] = function(t)
		local o = Objetivos.atual({
			run = run({ plano = { modo = "pronto" }, evento = { id = "evento" } }),
			provacao = { estado = "em-curso", npcId = "vila-2" }, destinos = { agua = { x = 3, y = 1, z = 4 } },
		})
		t.eq(o.chave, "prova-vila-2")
		t.eq(o.alvo.id, "agua")
		t.eq(o.alvo.posicao.x, 3)
		local ladino = Objetivos.atual({ run = run({ plano = { modo = "pronto" } }), provacao = { estado = "em-curso", npcId = "vila-1", sino = false }, destinos = { sino = { x = 1, y = 0, z = 2 }, portao = { x = 9, y = 0, z = 8 } } })
		t.eq(ladino.chave, "prova-vila-1-sino"); t.eq(ladino.alvo.id, "sino")
		ladino = Objetivos.atual({ run = run({ plano = { modo = "pronto" } }), provacao = { estado = "em-curso", npcId = "vila-1", sino = true }, destinos = { portao = { x = 9, y = 0, z = 8 } } })
		t.eq(ladino.chave, "prova-vila-1-portao"); t.eq(ladino.alvo.id, "portao")
	end,
	["treinador elegível mais próximo e conversado vira convite"] = function(t)
		local estado = {
			run = run({ plano = { modo = "semArvore" }, diasRestantes = 1 }), posicao = { x = 0, y = 0, z = 0 },
			treinadores = {
				{ id = "vila-1", posicao = { x = 8, y = 0, z = 0 }, disponivel = true },
				{ id = "vila-2", posicao = { x = 2, y = 0, z = 0 }, disponivel = true },
				{ id = "vila-3", posicao = { x = 1, y = 0, z = 0 }, disponivel = false },
			},
		}
		local o = Objetivos.atual(estado)
		t.eq(o.alvo.id, "vila-2")
		estado.conversados = { ["vila-2"] = true }
		o = Objetivos.atual(estado)
		t.eq(o.chave, "iniciar-provacao")
		t.eq(o.alvo.id, "vila-2")
	end,
	["não recomenda treino sem dia, com árvore ou oferta inelegível"] = function(t)
		local base = { run = run({ plano = { modo = "semArvore" }, diasRestantes = 0 }), posicao = { x = 0, y = 0, z = 0 },
			treinadores = { { id = "vila-1", posicao = { x = 1, y = 0, z = 0 }, disponivel = true } } }
		t.eq(Objetivos.atual(base).chave, "seguir-historia")
		base.run.diasRestantes = 2; base.arvore = "agua"
		t.eq(Objetivos.atual(base).chave, "seguir-historia")
		base.arvore = nil; base.conversados = { ["vila-1"] = true }; base.ofertas = { ["vila-1"] = { podeComprar = false } }
		t.eq(Objetivos.atual(base).chave, "seguir-historia")
	end,
	["história preserva texto de prazo real e instruções de selo"] = function(t)
		local opcoes = { { id = "pegar-o-selo", texto = "Pegar o Selo e voltar", liberada = true } }
		local o = Objetivos.atual({ run = run({ galho = "chefe-floresta", plano = {}, opcoes = opcoes }) })
		t.ok(o.linha:find("Abra a RUN e vote: Pegar o Selo e voltar", 1, true) ~= nil)
		t.eq(o.alvo, nil)
		local retorno = Objetivos.atual({ run = run({ galho = "retorno", regiao = "vila", plano = {}, opcoes = {
			{ id = "entregar-o-selo", texto = "Entregar o Selo na vila", liberada = true },
		} }) })
		t.eq(retorno.chave, "entregar-selo")
	end,
	["objetivo do selo não antecipa entrega enquanto a run ainda está na vila"] = function(t)
		local o = Objetivos.atual({ run = run({ galho = "vila", regiao = "vila", plano = { modo = "zero" } }) })
		t.eq(o.chave, "escolher-arvore")
	end,
	["cada nó real da HistoriaV1 tem orientação coerente com suas opções"] = function(t)
		local esperado = {
			vila = "seguir-historia",
			["floresta-sombria"] = "enfrentar-guardiao",
			["ruinas-do-vale"] = "abrir-caminho",
			["chefe-floresta"] = "pegar-selo",
			["chefe-ruinas"] = "pegar-selo",
			retorno = "entregar-selo",
			["final-selo"] = "final-concluido",
		}
		for galho, no in Historia.HISTORIA.nos do
			local r = run({ galho = galho, regiao = no.regiao or "vila", titulo = no.titulo, plano = { modo = "pronto" }, flags = {} })
			if galho == "chefe-floresta" then r.flags["vencido/chefe-floresta"] = true; r.luta = { ativo = true } end
			if galho == "chefe-ruinas" then r.flags["vencido/chefe-ruinas"] = true; r.luta = { ativo = true } end
			if galho == "retorno" then r.flags["selo-obtido"] = true end
			if galho == "final-selo" then r.fim = { motivo = "final" } end
			r.opcoes = RunHistoria.opcoes(Historia.HISTORIA, r)
			local o = Objetivos.atual({ run = r })
			t.ok(o ~= nil, "sem objetivo no nó " .. galho)
			t.eq(o.chave, esperado[galho], "objetivo no nó " .. galho)
			t.ok(not o.titulo:find(galho, 1, true), "ID vazou no título: " .. galho)
			t.ok(not o.linha:find(galho, 1, true), "ID vazou na linha: " .. galho)
			if o.chave ~= "final-concluido" then
				t.ok(o.linha:find("Abra a RUN e vote:", 1, true) ~= nil, "opção deve indicar voto: " .. galho)
				t.eq(o.alvo, nil, "história por votação não deve criar alvo físico: " .. galho)
			end
		end
	end,
	["luta aponta apenas para destino fornecido na mesma região"] = function(t)
		local r = run({ galho = "chefe-floresta", regiao = "floresta-sombria", plano = {}, opcoes = {}, luta = { ativo = true } })
		local semPonto = Objetivos.atual({ run = r })
		t.eq(semPonto.chave, "vencer-guardiao"); t.eq(semPonto.alvo, nil)
		local comPonto = Objetivos.atual({ run = r, destinos = { ["chefe-floresta"] = { x = 10, y = 0, z = 20 } } })
		t.eq(comPonto.alvo.id, "chefe-floresta")
		r.regiao = "vila"
		t.eq(Objetivos.atual({ run = r, destinos = { ["chefe-floresta"] = { x = 10, y = 0, z = 20 } } }).alvo, nil)
	end,
}
