local Shared = game:GetService("ReplicatedStorage").Shared
local Sessao = require(Shared.Regras.RunSessao)
local Run = require(Shared.Regras.Run)
local Prontos = require(Shared.PersonagensProntos)
local Eventos = require(Shared.Mundo.ViagemEventosV1)

local function rngFixo(n) return { NextInteger = function(_, lo, hi) return math.clamp(n, lo, hi) end } end

local function armazenamento()
	local dados = { falhar = false }
	return dados, function(chave, dado)
		if dados.falhar then error("DataStore fora do ar") end
		dados[chave] = dado
	end, function(chave) return dados[chave] end
end

local function nova(opcoes)
	opcoes = opcoes or {}
	local dados, guardar, carregar = armazenamento()
	local s = Sessao.new({
		rng = opcoes.rng or rngFixo(1), guardar = guardar, carregar = carregar,
		ehExplorador = opcoes.ehExplorador, prontos = Prontos, eventos = opcoes.eventos,
	})
	return s, dados
end

local function jogadores(...)
	local lista = {}
	for _, id in { ... } do table.insert(lista, { userId = id, nome = "J" .. id }) end
	return lista
end

return {
	["iniciar cria a run na vila, sorteia um plano por jogador e salva"] = function(t)
		local s, dados = nova()
		t.eq((s:iniciar("g1", jogadores(11, 22), { [22] = "semArvore" })), true)
		t.eq(s.run.galho, "vila")
		t.eq(s.planos[11].modo, "zero")
		t.eq(#s.planos[11].oferta, 6)
		t.eq(s.planos[22].modo, "semArvore")
		t.ok(dados["run/g1"] ~= nil)
		t.eq((s:iniciar("g2", jogadores(1))), false) -- já existe
	end,
	["a viagem traz origem e destino e a contagem de votos por opcao (sem expor quem votou)"] = function(t)
		local s = nova({ eventos = Eventos })
		s:iniciar("gv", jogadores(11, 22))
		local v0 = s:visao(11)
		t.eq(v0.viagem, nil)
		t.eq(v0.contagem["rumo-a-floresta"], 0)
		s:votar(11, "rumo-a-floresta")
		t.eq(s:visao(22).contagem["rumo-a-floresta"], 1)
		t.eq(s:visao(22).contagem["rumo-as-ruinas"], 0)
		s:votar(22, "rumo-a-floresta")
		local v = s:visao(11)
		t.ok(v.viagem ~= nil, "esperava viagem ao mudar de regiao")
		t.eq(v.viagem.origem, "A vila")
		t.eq(v.viagem.destino, "Floresta Sombria")
		t.ok(v.evento ~= nil)
		for _, n in v.contagem do t.eq(n, 0) end -- votos do evento recomecam
	end,
	["a viagem sobrevive a reconexao (save) e some quando o evento e resolvido"] = function(t)
		local a, dados = nova({ eventos = Eventos })
		a:iniciar("gr", jogadores(11))
		a:votar(11, "rumo-as-ruinas")
		t.ok(a:visao(11).viagem ~= nil)
		local b = Sessao.new({ rng = rngFixo(1), guardar = function() end, carregar = function(k) return dados[k] end, eventos = Eventos })
		t.eq((b:retomar("gr")), true)
		local v = b:visao(11)
		t.eq(v.viagem.destino, "Ruínas do Vale")
		local primeira
		for _, o in v.opcoes do if o.liberada then primeira = o.id break end end
		b:votar(11, primeira)
		t.eq(b:visao(11).viagem, nil)
	end,
	["iniciar recusa pedido invalido e desfaz se o save falhar"] = function(t)
		local s, dados = nova()
		t.eq((s:iniciar("", jogadores(1))), false)
		t.eq((s:iniciar("g", jogadores())), false)
		dados.falhar = true
		local ok, motivo = s:iniciar("g", jogadores(1))
		t.eq(ok, false)
		t.ok(motivo:find("Falha ao salvar") ~= nil)
		t.eq(s.run, nil)
	end,
	["retomar recupera run e planos salvos por outra sessao"] = function(t)
		local a, dados = nova()
		a:iniciar("g1", jogadores(11, 22))
		a:votar(11, "rumo-a-floresta")
		local b = Sessao.new({ rng = rngFixo(1), guardar = function() end, carregar = function(k) return dados[k] end })
		t.eq((b:retomar("g1")), true)
		t.eq(b.run.galho, "vila") -- só 11 votou: nada avançou
		t.eq(b.planos[22].modo, "zero")
		t.eq(b.votos[11], nil) -- votos em aberto recomeçam
		t.eq((b:retomar("g1")), false)
		local c = Sessao.new({ rng = rngFixo(1), guardar = function() end, carregar = function() return nil end })
		t.eq((c:retomar("nada")), false)
	end,
	["votacao: espera todos, depois avanca a historia e gasta o prazo"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		local ok, r = s:votar(11, "rumo-a-floresta")
		t.eq(ok, true)
		t.eq(#r.aguardando, 1)
		t.eq(r.aguardando[1], 22)
		local ok2, r2 = s:votar(22, "rumo-a-floresta")
		t.eq(ok2, true)
		t.eq(r2.avancou, true)
		t.eq(r2.opcao, "rumo-a-floresta")
		t.eq(s.run.galho, "floresta-sombria")
		t.eq(s.run.dia, 1)
		t.eq(next(s.votos), nil)
	end,
	["empate rola o dado e Explorador desempata com peso 2"] = function(t)
		local s = nova({ rng = rngFixo(2) })
		s:iniciar("g", jogadores(11, 22))
		s:votar(11, "rumo-a-floresta")
		local _, r = s:votar(22, "rumo-as-ruinas")
		t.eq(r.dado, 2) -- dois empatados, dado 2 = segunda opção
		t.eq(r.opcao, "rumo-as-ruinas")
		local e = nova({ ehExplorador = function(id) return id == 11 end })
		e:iniciar("g", jogadores(11, 22))
		e:votar(11, "rumo-a-floresta")
		local _, r2 = e:votar(22, "rumo-as-ruinas")
		t.eq(r2.opcao, "rumo-a-floresta")
		t.eq(r2.dado, nil)
	end,
	["Explorador vem da arvore escolhida ou da ficha pronta de Navegacao"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		t.eq(s:ehExplorador(11), false)
		s.planos[11] = { modo = "zero", oferta = { "navegacao-e-lideranca" }, paExtra = 0, multiplicador = 1 }
		t.eq((s:escolherArvore(11, "navegacao-e-lideranca")), true)
		t.eq(s:ehExplorador(11), true)
		t.eq(s:ehExplorador(22), false)
		s.planos[22] = { modo = "pronto", arvore = "navegacao-e-lideranca", defeitos = {}, paExtra = 3, multiplicador = 1 }
		t.eq(s:ehExplorador(22), true)
		s:votar(11, "rumo-a-floresta")
		local _, r = s:votar(22, "rumo-as-ruinas")
		t.ok(r.avancou) -- os dois Exploradores pesam 2 cada: empate de 2 a 2 vai ao dado
		t.ok(r.dado ~= nil)
	end,
	["mudar de regiao traz um evento de viagem que o grupo vota e gasta prazo"] = function(t)
		local s, dados = nova({ eventos = Eventos, rng = rngFixo(1) })
		s:iniciar("g", jogadores(11, 22))
		s:votar(11, "rumo-a-floresta")
		local _, r = s:votar(22, "rumo-a-floresta")
		t.eq(r.avancou, true)
		t.ok(r.evento ~= nil, "evento sorteado")
		t.eq(s.run.galho, "floresta-sombria")
		t.eq(s.run.dia, 1)
		local v = s:visao(11)
		t.eq(v.evento.id, r.evento)
		t.ok(#v.opcoes >= 1)
		t.eq(v.opcoes[1].liberada, true)
		-- Opção da história não vale enquanto o evento está pendente.
		t.eq((s:votar(11, "enfrentar-o-guardiao")), false)
		local escolha = v.opcoes[#v.opcoes].id
		s:votar(11, escolha)
		local ok, r2 = s:votar(22, escolha)
		t.eq(ok, true)
		t.eq(r2.avancou, true)
		t.eq(s.evento, nil)
		t.eq(s.run.galho, "floresta-sombria") -- evento não move a história
		t.eq(s.run.flags["evento/" .. r.evento .. "/" .. escolha], true)
		t.ok(dados["run/g"] ~= nil)
	end,
	["evento pendente sobrevive ao salvar e retomar; sem catalogo nao ha eventos"] = function(t)
		local a, dados = nova({ eventos = Eventos })
		a:iniciar("g", jogadores(11))
		local _, r = a:votar(11, "rumo-a-floresta")
		t.ok(r.evento ~= nil)
		local b = Sessao.new({ rng = rngFixo(1), guardar = function() end, carregar = function(k) return dados[k] end, eventos = Eventos })
		t.eq((b:retomar("g")), true)
		t.eq(b.evento.id, r.evento)
		local sem = Sessao.new({ rng = rngFixo(1), guardar = function() end, carregar = function(k) return dados[k] end })
		t.eq((sem:retomar("g")), false) -- evento salvo que o catálogo não conhece
		local c = nova()
		c:iniciar("g", jogadores(11))
		c:votar(11, "rumo-a-floresta")
		t.eq(c.evento, nil)
	end,
	["defeito veta a opcao do evento so para quem o tem"] = function(t)
		local s = nova({ eventos = Eventos })
		s:iniciar("g", jogadores(11, 22), { [22] = "semArvore" })
		s.planos[11] = { modo = "pronto", prontoId = "x", arvore = "fogo", defeitos = { "medroso" }, paExtra = 5, multiplicador = 1.5 }
		s.evento = Eventos[3] -- bandidos: "enfrentar" tem a tag confronto
		local v11, v22 = s:visao(11), s:visao(22)
		local function achar(v, id) for _, o in v.opcoes do if o.id == id then return o end end end
		t.eq(achar(v11, "enfrentar").liberada, false)
		t.ok(achar(v11, "enfrentar").motivo ~= nil)
		t.eq(achar(v22, "enfrentar").liberada, true)
		t.eq((s:votar(11, "enfrentar")), false)
		t.eq((s:votar(22, "enfrentar")), true)
	end,
	["quem tem todas as opcoes do evento vetadas nao trava a votacao"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		s.planos[11] = { modo = "pronto", prontoId = "x", arvore = "fogo", defeitos = { "medroso", "fragil" }, paExtra = 5, multiplicador = 1.5 }
		s.evento = { id = "duelo", titulo = "Duelo", tom = "ruim", peso = 1, opcoes = {
			{ id = "lutar", texto = "Lutar", tags = { "confronto" } }, { id = "forcar", texto = "Forcar", tags = { "forca" } } } }
		local ok, r = s:votar(22, "lutar")
		t.eq(ok, true)
		t.eq(r.avancou, true) -- 11 está vetado em tudo e não bloqueia
		t.eq(s.run.flags["evento/duelo/lutar"], true)
	end,
	["resumo para a conta so existe com a run terminada e a conta e marcada uma vez"] = function(t)
		local s, dados = nova()
		s:iniciar("g", jogadores(11))
		t.eq(s:resumo(11), nil)
		s:votar(11, "rumo-a-floresta")
		s:votar(11, "enfrentar-o-guardiao")
		t.eq((s:lutaTerminou("victory")), true)
		s:votar(11, "pegar-o-selo")
		s:votar(11, "entregar-o-selo")
		local r, final = s:resumo(11)
		t.eq(r.status, "final")
		t.eq(final, "final-selo")
		t.eq(r.objetivoCumprido, true)
		t.eq(r.regioesVisitadas, 1)
		t.eq(r.plano.modo, "zero")
		t.eq(s.contaRegistrada, false)
		t.eq((s:marcarContaRegistrada()), true)
		t.eq(dados["run/g"].extras.contaRegistrada, true)
		local b = Sessao.new({ rng = rngFixo(1), guardar = function() end, carregar = function(k) return dados[k] end })
		b:retomar("g")
		t.eq(b.contaRegistrada, true)
		-- Queda do grupo também gera resumo (derrota).
		local d = nova()
		d:iniciar("h", jogadores(5))
		d:cair(5, true)
		t.eq(d:resumo(5).status, "derrota")
	end,
	["chefe: a run espera a luta, vitoria libera o Selo, derrota encerra, fuga mantem pendente"] = function(t)
		local s, dados = nova()
		s:iniciar("g", jogadores(11, 22))
		s:votar(11, "rumo-a-floresta"); s:votar(22, "rumo-a-floresta")
		local _, r = s:votar(11, "enfrentar-o-guardiao")
		local _, r2 = s:votar(22, "enfrentar-o-guardiao")
		t.eq(r2.avancou, true)
		t.eq(r2.luta, "chefe-floresta")
		local p = s:lutaPendente()
		t.eq(p.no, "chefe-floresta")
		t.eq(p.criaturas[1], "creature/urso-de-presas-vermelhas")
		t.eq(#s:visao(11).opcoes, 0)
		t.ok(s:visao(11).luta ~= nil)
		t.eq((s:votar(11, "pegar-o-selo")), false) -- há luta pendente
		t.eq((s:lutaTerminou("fled")), true)
		t.ok(s:lutaPendente() ~= nil, "fuga mantém a luta")
		-- A luta pendente sobrevive a reiniciar o servidor.
		local b = Sessao.new({ rng = rngFixo(1), guardar = function() end, carregar = function(k) return dados[k] end })
		t.eq((b:retomar("g")), true)
		t.eq(b:lutaPendente().no, "chefe-floresta")
		t.eq((s:lutaTerminou("empate")), false)
		t.eq((s:lutaTerminou("victory")), true)
		t.eq(s:lutaPendente(), nil)
		t.eq(s.run.flags["vencido/chefe-floresta"], true)
		t.eq(#s:visao(11).opcoes, 1)
		t.eq((s:lutaTerminou("victory")), false) -- sem luta pendente
		local ok, r3 = s:votar(11, "pegar-o-selo")
		t.eq(ok, true)
		local _, r4 = s:votar(22, "pegar-o-selo")
		t.eq(r4.avancou, true)
	end,
	["derrota na luta do chefe derruba o grupo e a run termina como queda"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		s:votar(11, "rumo-a-floresta"); s:votar(22, "rumo-a-floresta")
		s:votar(11, "enfrentar-o-guardiao"); s:votar(22, "enfrentar-o-guardiao")
		t.eq((s:lutaTerminou("defeat")), true)
		t.eq(s.run.fim.motivo, "queda")
		t.eq(s.luta, nil)
		t.eq(s:resumo(11).status, "derrota")
	end,
	["queda de um jogador nao trava o grupo: so quem esta de pe vota"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		t.eq((s:cair(11, true)), true)
		t.eq(s.run.fim, nil)
		t.eq((s:votar(11, "rumo-a-floresta")), false) -- caído não vota
		local ok, r = s:votar(22, "rumo-a-floresta")
		t.eq(ok, true)
		t.eq(r.avancou, true) -- o jogador de pé decide sozinho
		t.eq(s:visao(22).grupo[1].caido, true)
		s:cair(22, true)
		t.eq(s.run.fim.motivo, "queda")
	end,
	["voto invalido: opcao trancada, inexistente, ausente ou de estranho"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		s.run = Run.moverPara(s.run, "ruinas-do-vale", "ruinas-do-vale")
		t.eq((s:votar(11, "entrar-na-camara")), false) -- tranca fechada
		t.eq((s:votar(11, "inexistente")), false)
		t.eq((s:votar(999, "voltar")), false)
		s.run = Run.marcarAusente(s.run, 22)
		t.eq((s:votar(22, "voltar")), false)
	end,
	["ausentar quem faltava fecha a votacao pendente"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		s:votar(11, "rumo-a-floresta")
		local ok, r = s:ausentar(22)
		t.eq(ok, true)
		t.eq(r.avancou, true)
		t.eq(s.run.galho, "floresta-sombria")
		local volta, perdidos = s:retornar(22)
		t.eq(volta, true)
		t.eq(perdidos, 1) -- faltou ao dia de viagem que o grupo decidiu sem ele
		t.eq((s:retornar(22)), false)
	end,
	["queda do grupo inteiro encerra a run em derrota e bloqueia votos"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		s:cair(11, true)
		t.eq(Run.encerrada(s.run), false)
		s:cair(22, true)
		t.eq(s.run.fim.motivo, "queda")
		t.eq((s:votar(11, "rumo-a-floresta")), false)
		t.eq(s:visao(11).fim.motivo, "queda")
	end,
	["falha de save ao avancar mantem a run anterior"] = function(t)
		local s, dados = nova()
		s:iniciar("g", jogadores(11))
		dados.falhar = true
		local ok = s:votar(11, "rumo-a-floresta")
		t.eq(ok, false)
		t.eq(s.run.galho, "vila")
		t.eq(s.run.dia, 0)
	end,
	["escolher arvore: so da oferta, so uma vez"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11))
		t.eq((s:escolherArvore(11, "vendaval")), false)
		local escolha = s.planos[11].oferta[1]
		t.eq((s:escolherArvore(11, escolha)), true)
		t.eq(s.planos[11].escolhida, escolha)
		t.eq((s:escolherArvore(11, escolha)), false)
		t.eq((s:escolherArvore(999, escolha)), false)
	end,
	["arvore so pode ser escolhida antes de partir"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11))
		local oferta = s.planos[11].oferta
		s:votar(11, "rumo-a-floresta")
		local ok, motivo = s:escolherArvore(11, oferta[1])
		t.eq(ok, false)
		t.eq(motivo, "A árvore só pode ser escolhida antes de partir.")
		t.eq(s.planos[11].escolhida, nil)
	end,
	["visao nao vaza votos dos outros e informa prazo e opcoes"] = function(t)
		local s = nova()
		s:iniciar("g", jogadores(11, 22))
		s:votar(11, "rumo-a-floresta")
		local v = s:visao(22)
		t.eq(v.votei, nil)
		t.eq(v.aguardando[1], 22)
		t.eq(v.diasRestantes, 12)
		t.eq(#v.opcoes, 2)
		t.eq(v.votos, nil)
		t.eq(v.titulo, "A vila")
		t.eq(v.tipoDoNo, "vila")
		t.eq(#v.grupo, 2)
		t.eq(v.grupo[1].userId, 11)
		t.eq(s:visao(11).votei, "rumo-a-floresta")
		t.eq(nova():visao(1), nil)
	end,
}
