local Shared = game:GetService("ReplicatedStorage").Shared
local G = require(Shared.Regras.ExpedicaoGerador)
local H = require(Shared.Regras.RunHistoria)
local Sessao = require(Shared.Regras.RunSessao)
local Esgoto = require(Shared.Mundo.ExpedicaoEsgoto)
local Eventos = require(Shared.Mundo.ViagemEventosV1)
local AREA = Esgoto.AREA

local function rngFixo(n) return { NextInteger = function(_, lo, hi) return math.clamp(n, lo, hi) end } end

-- Sessão de expedição com armazenamento em memória (`dados` compartilhado permite testar o retomar).
-- `extra` sobrescreve deps (ex.: outro objetivo, outra história, catálogo de eventos). `dados.falhar` derruba o save.
local function nova(semente, dados, extra)
	dados = dados or {}
	local deps = {
		rng = rngFixo(semente or 7), carregar = function(k) return dados[k] end,
		guardar = function(k, v) if dados.falhar then error("DataStore fora do ar") end; dados[k] = v end,
		historiaDaSemente = function(s) return G.gerar(AREA, s) end, objetivo = G.OBJETIVO, area = AREA,
	}
	for k, v in extra or {} do deps[k] = v end
	return Sessao.new(deps), dados
end

local function votar(t, s, opcao)
	local ok, r = s:votar(1, opcao)
	t.ok(ok and type(r) == "table" and r.avancou, opcao .. ": " .. tostring(r))
end

local function ganhar(t, s)
	t.eq(s:visao(1).fase, "luta")
	t.eq((s:lutaTerminou("victory")), true)
	t.eq(s:visao(1).fase, "acampamento")
end

local function achar(lista, id) for _, o in lista do if o.id == id then return o end end end

local function igual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not igual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

return {
	["o gerador e deterministico e valido para varias sementes"] = function(t)
		for semente = 1, 40 do
			local h = G.gerar(AREA, semente)
			local ok, problemas = H.validar(h)
			t.ok(ok, semente .. ": " .. table.concat(problemas, "; ")) -- validar também exige todos os nós alcançáveis
			t.ok(igual(h, G.gerar(AREA, semente)), "mesma semente, mesma história")
		end
		local diferentes = false
		for semente = 2, 40 do
			if not igual(G.gerar(AREA, 1), G.gerar(AREA, semente)) then diferentes = true end
		end
		t.ok(diferentes, "sementes diferentes variam os encontros")
	end,
	["estrutura: salas, alternativas distintas, custos de voltar e retomadas"] = function(t)
		local h = G.gerar(AREA, 11)
		t.eq(h.nos["cidade"].tipo, "hub")
		t.eq(achar(h.nos["cidade"].opcoes, "entrar-esgoto").dias, 1)
		t.eq(achar(h.nos["cidade"].opcoes, "entrar-esgoto").para, "esgoto-1")
		t.eq(#h.nos["cidade"].opcoes, 1 + 1 + 9) -- entrar + selar + uma retomada por sala (1 + 4*2)
		t.eq(achar(h.nos["cidade"].opcoes, "entrar-esgoto").ocultaCom, "expedicao/esgoto/concluida")
		local selar = achar(h.nos["cidade"].opcoes, "selar-a-anomalia")
		t.eq(selar.para, "final-campanha")
		t.eq(selar.exige.flag, "fragmento/esgoto")
		t.eq(selar.texto, "Selar a anomalia (encerrar a campanha)")
		local r = achar(h.nos["cidade"].opcoes, "retomar-esgoto-esgoto-3a")
		t.eq(r.dias, 1 + 3 * 0.5)
		t.eq(r.exige.flag, "vencido/esgoto-3a")
		for passo = 2, 5 do
			local a, b = h.nos["esgoto-" .. passo .. "a"], h.nos["esgoto-" .. passo .. "b"]
			t.eq(a.passo, passo)
			t.eq(a.total, 5)
			t.eq(a.area, "esgoto")
			t.ok(a.luta.criaturas[1] ~= b.luta.criaturas[1], "alternativas com encontros diferentes")
			t.eq(achar(a.opcoes, "voltar-a-cidade").dias, math.max(1, passo * 0.5))
			t.eq(achar(a.opcoes, "voltar-a-cidade").exige.flag, "vencido/esgoto-" .. passo .. "a")
		end
		local primeira = h.nos["esgoto-1"]
		t.eq(achar(primeira.opcoes, "caminho-a").para, "esgoto-2a")
		t.ok(achar(primeira.opcoes, "caminho-a").dica ~= nil)
		t.eq(achar(primeira.opcoes, "voltar-a-cidade").dias, 1)
		t.eq(achar(h.nos["esgoto-5b"].opcoes, "enfrentar-o-chefe").para, "esgoto-chefe")
		t.eq(h.nos["esgoto-chefe"].tipo, "chefe")
		t.eq(h.nos["final-esgoto"], nil)
		t.eq(h.nos["final-campanha"].tipo, "final")
		t.eq(h.nos["final-campanha"].cumpreObjetivo, true)
		local volta = achar(h.nos["esgoto-chefe"].opcoes, "voltar-com-a-recompensa")
		t.eq(volta.para, "cidade")
		t.eq(volta.dias, 2.5) -- passo 5: como voltar-a-cidade
		t.eq(volta.marca, "expedicao/esgoto/concluida")
		t.eq(volta.marcas[1], "fragmento/esgoto")
		t.eq(G.OBJETIVO.id, "limpar-o-esgoto")
		t.eq(G.OBJETIVO.prazoDias, 30)
	end,
	["percurso completo: lutas, descanso sem limite, chefe e final cumprem o objetivo"] = function(t)
		local s = nova()
		t.eq((s:iniciar("g", { { userId = 1 } })), true)
		t.eq(s:visao(1).area, nil)
		votar(t, s, "entrar-esgoto")
		local v = s:visao(1)
		t.eq(v.passo, 1)
		t.eq(v.totalPassos, 5)
		t.eq(v.area, "esgoto")
		t.eq(v.fase, "luta")
		t.eq(#v.opcoes, 0)
		t.eq((s:descansarNoAcampamento(1)), false) -- em luta não descansa
		ganhar(t, s)
		v = s:visao(1)
		t.eq(v.descansos.usados, 0)
		t.eq(v.descansos.max, nil) -- sem limite fixo (decisão de 14/11)
		t.eq(achar(v.opcoes, "caminho-a").dias, 0)
		t.ok(achar(v.opcoes, "caminho-b").dica ~= nil)
		t.eq(s.run.dia, 1)
		t.eq((s:descansarNoAcampamento(1)), true)
		t.eq((s:descansarNoAcampamento(1)), true)
		t.eq((s:descansarNoAcampamento(1)), true) -- sem teto: cada descanso só custa meio dia
		t.eq(s.run.dia, 2.5)
		t.eq(s:visao(1).descansos.usados, 3)
		for passo = 2, 5 do
			votar(t, s, if passo % 2 == 0 then "caminho-a" else "caminho-b")
			t.eq(s:visao(1).passo, passo)
			ganhar(t, s)
		end
		votar(t, s, "enfrentar-o-chefe")
		t.eq(s:visao(1).tipoDoNo, "chefe")
		ganhar(t, s)
		local diaAntes = s.run.dia
		votar(t, s, "voltar-com-a-recompensa")
		-- A área acabou, a campanha não: o grupo volta à cidade e o prazo continua.
		t.eq(s.run.fim, nil)
		t.eq(s.run.galho, "cidade")
		t.eq(s.run.dia, diaAntes + 2.5)
		t.eq(s.run.flags["expedicao/esgoto/concluida"], true)
		t.eq(s.run.flags["fragmento/esgoto"], true)
		t.eq(s:resumo(1), nil)
		v = s:visao(1)
		t.eq(#v.opcoes, 1) -- entrar e retomadas somem; só selar
		t.eq(v.opcoes[1].id, "selar-a-anomalia")
		t.eq(v.opcoes[1].liberada, true)
		t.eq((s:votar(1, "entrar-esgoto")), false)
		votar(t, s, "selar-a-anomalia")
		local r = s:resumo(1)
		t.eq(r.status, "final")
		t.eq(r.objetivoCumprido, true)
		t.eq(s.run.fim.final, "final-campanha")
	end,
	["voltar a cidade custa pelo passo; so a retomada mais funda aparece e nao repete luta"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		votar(t, s, "caminho-a")
		ganhar(t, s)
		votar(t, s, "caminho-a")
		ganhar(t, s)
		t.eq(s.run.dia, 1)
		votar(t, s, "voltar-a-cidade")
		t.eq(s.run.galho, "cidade")
		t.eq(s.run.dia, 2.5) -- passo 3: 1,5 dia
		local v = s:visao(1)
		t.eq(#v.opcoes, 3)
		t.ok(achar(v.opcoes, "entrar-esgoto") ~= nil)
		t.eq(achar(v.opcoes, "selar-a-anomalia").liberada, false) -- sem fragmento, trancada
		local retomada = achar(v.opcoes, "retomar-esgoto-esgoto-3a")
		t.ok(retomada ~= nil and retomada.liberada, "a retomada mais funda")
		t.eq(retomada.dias, 2.5)
		t.eq(v.fase, nil)
		votar(t, s, "retomar-esgoto-esgoto-3a")
		t.eq(s.run.dia, 5)
		t.eq(s:visao(1).fase, "acampamento")
		t.eq(s:lutaPendente(), nil)
		-- Voltar e entrar de novo na primeira sala (já vencida) também não luta.
		votar(t, s, "voltar-a-cidade")
		votar(t, s, "entrar-esgoto")
		t.eq(s:visao(1).fase, "acampamento")
	end,
	["derrota na expedicao volta a cidade sem encerrar a run nem vencer a sala"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		votar(t, s, "caminho-a")
		local no = s.run.galho
		local ouro = s.run.ouroViagem
		t.eq(no, "esgoto-2a")
		t.eq((s:lutaTerminou("defeat")), true)
		t.eq(s.run.fim, nil)
		t.eq(s.run.galho, "cidade")
		t.eq(s.run.dia, 2) -- entrar 1 + voltar do passo 2 (1)
		t.ok(not s.run.jogadores[1].caido)
		t.eq(s.run.flags["vencido/" .. no], nil)
		t.eq(s.run.ouroViagem, ouro)
		t.eq(s.luta, nil)
		t.eq(s:visao(1).tipoDoNo, "hub")
		t.ok(achar(s:visao(1).opcoes, "retomar-esgoto-esgoto-1").liberada) -- o progresso do passo 1 segue
	end,
	["salvar e retomar no meio regenera a mesma historia"] = function(t)
		local s, dados = nova(123)
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		votar(t, s, "caminho-b")
		local s2 = nova(999, dados) -- rng diferente: a história vem da semente salva
		t.eq((s2:retomar("g")), true)
		t.ok(igual(s.historia, s2.historia))
		t.eq(s2.run.galho, "esgoto-2b")
		t.eq(s2:visao(1).fase, "luta")
		t.eq((s2:lutaTerminou("victory")), true)
		t.eq(s2:visao(1).fase, "acampamento")
	end,
	-- P1: travamentos da run/expedição.
	["lutaErro aparece na visao so com luta pendente e some quando a luta acaba"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		t.eq(s:visao(1).lutaErro, nil)
		s:definirErroDaLuta("A mesa está ocupada por outro modo.")
		t.eq(s:visao(1).lutaErro, "A mesa está ocupada por outro modo.")
		t.eq((s:lutaTerminou("victory")), true)
		t.eq(s:visao(1).lutaErro, nil)
		s:definirErroDaLuta("sem luta")
		t.eq(s.lutaErro, nil) -- sem luta pendente não guarda erro
	end,
	["abandonar a luta pendente volta a cidade pagando (passo - 1) e salva"] = function(t)
		local s, dados = nova()
		s:iniciar("g", { { userId = 1 } })
		t.eq((s:abandonarLuta(1, false)), false) -- no hub não há luta
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		for _ = 2, 3 do votar(t, s, "caminho-a"); ganhar(t, s) end
		votar(t, s, "caminho-a")
		t.eq(s.run.galho, "esgoto-4a")
		t.eq(s:visao(1).fase, "luta")
		s:definirErroDaLuta("A mesa recusou.")
		t.eq((s:abandonarLuta(1, true)), false) -- encontro em curso
		t.eq((s:abandonarLuta(99, false)), false) -- fora da run
		dados.falhar = true
		t.eq((s:abandonarLuta(1, false)), false) -- save falhou: nada muda
		t.eq(s.run.galho, "esgoto-4a")
		t.eq(s.luta, "esgoto-4a")
		t.eq(s.lutaErro, "A mesa recusou.")
		dados.falhar = false
		t.eq(s.run.dia, 1)
		t.eq((s:abandonarLuta(1, false)), true)
		t.eq(s.run.galho, "cidade")
		t.eq(s.run.dia, 1 + 1.5) -- max(1, (4 - 1) * 0,5)
		t.eq(s.luta, nil)
		t.eq(s:visao(1).lutaErro, nil)
		t.eq(s:visao(1).tipoDoNo, "hub")
		t.eq(s.run.flags["vencido/esgoto-4a"], nil)
		t.eq(s.run.fim, nil)
		t.ok(achar(s:visao(1).opcoes, "retomar-esgoto-esgoto-3a").liberada)
		local s2 = nova(1, dados)
		t.eq((s2:retomar("g")), true)
		t.eq(s2.run.galho, "cidade")
		t.eq(s2.luta, nil)
		-- Na primeira sala também custa ao menos 1 dia.
		local p = nova()
		p:iniciar("g", { { userId = 1 } })
		votar(t, p, "entrar-esgoto")
		t.eq((p:abandonarLuta(1, false)), true)
		t.eq(p.run.dia, 2)
	end,
	["retirarVoto desfaz so o proprio voto; treino com voto em aberto explica o motivo"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 }, { userId = 2 } })
		t.eq((s:retirarVoto(1)), false) -- sem voto
		local ok, r = s:votar(1, "entrar-esgoto")
		t.eq(ok, true)
		t.eq(r.aguardando[1], 2)
		t.eq(s:visao(1).votei, "entrar-esgoto")
		local treinou, motivo = s:treinar(2, "vila-1", "x", "req1")
		t.eq(treinou, false)
		t.ok(string.find(motivo, "votos em aberto", 1, true) ~= nil, motivo)
		local proprio, motivoProprio = s:treinar(1, "vila-1", "x", "req1")
		t.eq(proprio, false)
		t.eq(motivoProprio, "Retire seu voto antes de treinar.")
		t.eq((s:retirarVoto(2)), false) -- o 2 não votou
		t.eq((s:retirarVoto(1)), true)
		t.eq(s.votos[1], nil)
		t.eq(s:visao(1).votei, nil)
		t.eq(s:visao(1).contagem["entrar-esgoto"], 0)
		t.eq(s.run.galho, "cidade")
		-- O voto do 2 sozinho não decide: o 1 continua faltando.
		local ok2, r2 = s:votar(2, "entrar-esgoto")
		t.eq(ok2, true)
		t.eq(r2.aguardando[1], 1)
	end,
	["expedicao nao sorteia evento de viagem ao voltar nem ao retomar (mesmo com catalogo)"] = function(t)
		local s, dados = nova(7, nil, { eventos = Eventos })
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		t.eq(s.evento, nil)
		ganhar(t, s)
		votar(t, s, "voltar-a-cidade")
		t.eq(s.run.galho, "cidade")
		t.eq(s.evento, nil)
		t.eq(s:visao(1).evento, nil)
		t.eq(s:visao(1).viagem, nil)
		votar(t, s, "retomar-esgoto-esgoto-1")
		t.eq(s.evento, nil)
		-- Um evento salvo por versão antiga é descartado ao retomar a expedição.
		s.evento = Eventos[1]
		t.eq((s:_salvar()), true)
		local s2 = nova(7, dados, { eventos = Eventos })
		t.eq((s2:retomar("g")), true)
		t.eq(s2.evento, nil)
		t.eq(s2:visao(1).evento, nil)
	end,
	["retomar recusa save incompativel com a historia gerada (galho ou objetivo)"] = function(t)
		local s, dados = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		votar(t, s, "caminho-b")
		local outro = nova(1, dados, { objetivo = { id = "outro-objetivo", prazoDias = 30 } })
		local ok, motivo, detalhe = outro:retomar("g")
		t.eq(ok, false)
		t.eq(motivo, "Nenhuma run salva.")
		t.ok(type(detalhe) == "string" and string.find(detalhe, "objetivo", 1, true) ~= nil, tostring(detalhe))
		t.eq(outro.run, nil)
		local semGalho = nova(1, dados, { historiaDaSemente = function(semente)
			local h = G.gerar(AREA, semente)
			h.nos["esgoto-2b"] = nil
			return h
		end })
		ok, motivo, detalhe = semGalho:retomar("g")
		t.eq(ok, false)
		t.eq(motivo, "Nenhuma run salva.")
		t.ok(type(detalhe) == "string" and string.find(detalhe, "esgoto-2b", 1, true) ~= nil, tostring(detalhe))
		t.eq(semGalho.run, nil)
		-- Pelos membros: o save incompatível vira aviso e não trava o jogador.
		local m = nova(1, dados, { objetivo = { id = "outro-objetivo", prazoDias = 30 } })
		local okM, motivoM, avisos = m:retomarDeMembros({ 1 }, function() return "g" end)
		t.eq(okM, false)
		t.eq(motivoM, "Nenhuma run salva.")
		t.eq(#avisos, 1)
		t.eq(m.run, nil)
	end,
	["qualquer membro retoma a run pelo ponteiro; save antigo pela chave de quem iniciou"] = function(t)
		local s, dados = nova()
		t.eq((s:iniciar("u1", { { userId = 1 }, { userId = 2 } })), true)
		t.eq(dados["membro/2"], nil) -- o ponteiro é gravado pelo servidor depois de iniciar
		s:gravarPonteiros()
		t.eq(dados["membro/1"], "u1")
		t.eq(dados["membro/2"], "u1")
		local padrao = function(id) return "u" .. id end
		local s2 = nova(1, dados)
		local ok, grupo = s2:retomarDeMembros({ 2 }, padrao)
		t.eq(ok, true)
		t.eq(grupo, "u1")
		t.ok(s2.run.jogadores[1] ~= nil and s2.run.jogadores[2] ~= nil)
		t.eq((s2:retomarDeMembros({ 2 }, padrao)), false) -- já há run
		-- Save sem ponteiro (anterior a ele): acha pela chave de quem iniciou e grava o ponteiro dos outros.
		dados["membro/1"], dados["membro/2"] = nil, nil
		local s3 = nova(1, dados)
		t.eq((s3:retomarDeMembros({ 2, 1 }, padrao)), true)
		t.eq(dados["membro/2"], "u1")
		local vazio = nova(1, {})
		t.eq((vazio:retomarDeMembros({ 5 }, padrao)), false)
	end,
	["pagamento da area concluida fica marcado na run e sobrevive ao retomar"] = function(t)
		local s, dados = nova()
		s:iniciar("g", { { userId = 1 } })
		t.eq(s:areaPaga("esgoto", 1), false)
		t.eq((s:marcarAreaPaga("esgoto", 99)), false)
		dados.falhar = true
		t.eq((s:marcarAreaPaga("esgoto", 1)), false)
		t.eq(s:areaPaga("esgoto", 1), false)
		dados.falhar = false
		t.eq((s:marcarAreaPaga("esgoto", 1)), true)
		t.eq(s:areaPaga("esgoto", 1), true)
		local s2 = nova(1, dados)
		t.eq((s2:retomar("g")), true)
		t.eq(s2:areaPaga("esgoto", 1), true)
	end,
	["conferir o descanso do acampamento nao gasta o dia"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		t.eq((s:podeDescansarNoAcampamento(1)), false) -- em luta
		ganhar(t, s)
		local dia = s.run.dia
		t.eq((s:podeDescansarNoAcampamento(1)), true)
		t.eq(s.run.dia, dia)
		t.eq(s:visao(1).descansos.usados, 0)
		t.eq((s:podeDescansarNoAcampamento(99)), false)
	end,
	["descansosMax opcional: area com teto ainda limita"] = function(t)
		local comTeto = table.clone(AREA)
		comTeto.descansosMax = 1
		local s = nova(7, nil, { area = comTeto, historiaDaSemente = function(sem) return G.gerar(comTeto, sem) end })
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		t.eq(s:visao(1).descansos.max, 1)
		t.eq((s:descansarNoAcampamento(1)), true)
		t.eq((s:descansarNoAcampamento(1)), false)
	end,
}
