local Shared = game:GetService("ReplicatedStorage").Shared
local Sessao = require(Shared.Regras.RunSessao)
local Treinadores = require(Shared.Regras.RunTreinadores)
local Save = require(Shared.Regras.RunSave)
local Conta = require(Shared.Regras.RunConta)
local Provas = require(Shared.Regras.Provacoes)

local function montar()
	local dados = { falhar = false, chamadas = 0 }
	local deps = {
		rng = { NextInteger = function(_, lo) return lo end },
		guardar = function(k, v)
			dados.chamadas += 1
			if dados.durante then dados.durante() end
			if dados.falhar then error("offline") end
			dados[k] = v
		end,
		carregar = function(k) return dados[k] end,
	}
	local s = Sessao.new(deps)
	assert(s:iniciar("f4", { { userId = 7 }, { userId = 8 } }, { [7] = "semArvore", [8] = "semArvore" }))
	return s, dados, deps
end

local function aprovar(s, npcId, userId)
	userId = userId or 7
	s.provacoes = s.provacoes or {}
	local prova = s.provacoes[npcId] or Provas.nova()
	s.provacoes[npcId] = prova
	if Provas.aprovado(prova, userId) then return prova end
	if prova.userId ~= nil then Provas.liberar(prova) end
	assert(Provas.iniciar(prova, userId, 0))
	assert(Provas.aprovar(prova, userId, 1))
	return prova
end

local function comprar(s, id)
	local npc = Treinadores.listar(s.treinadores)[1]
	aprovar(s, npc.id)
	return s:treinar(7, npc.id, npc.arvore, id or "compra")
end

return {
	["sessao usa treinadores fixos e persiste os extras v1"] = function(t)
		local s, dados, deps = montar()
		t.eq(Treinadores.validarSorteio(s.treinadores), true)
		t.eq(#s.treinadores.vila, 2)
		t.eq(s.treinadores.vila[1], "furtividade-e-armadilhas")
		t.eq(s.treinadores.vila[2], "agua")
		local copia = Sessao.new(deps); t.eq((copia:retomar("f4")), true)
		t.eq(table.concat(copia.treinadores.vila, ","), "furtividade-e-armadilhas,agua")
		t.eq(copia.treinadores.taverna, nil)
		t.ok(Save.chavesSaoTexto(dados["run/f4"]))
		t.eq(dados["run/f4"].versao, 1)
	end,
	["sorteio legado valido e aceito mas listagem default permanece fixa"] = function(t)
		local legado = { vila = { "bardo-e-interacao", "cura", "fogo" }, taverna = nil }
		t.eq(Treinadores.validarSorteio(legado), true)
		local lista = Treinadores.listar(legado)
		t.eq(#lista, 2)
		t.eq(lista[1].arvore, "furtividade-e-armadilhas")
		t.eq(lista[2].arvore, "agua")
	end,
	["liberacoes da conta nao alteram treinadores fixos"] = function(t)
		local liberadas = { vento = true, cura = true, fogo = true }
		local s = Sessao.new({ rng = { NextInteger = function(_, lo) return lo end }, guardar = function() end })
		t.eq((s:iniciar("limitada", { { userId = 7 } }, nil, liberadas)), true)
		t.eq(s.treinadores.vila[1], "furtividade-e-armadilhas")
		t.eq(s.treinadores.vila[2], "agua")
		local comuns = Conta.treinadoresLiberados(Conta.nova())
		for _, c in Treinadores.candidatos() do t.eq(comuns[c.id] == true, not c.soTaverna) end
	end,
	["treino recusa sem prova aprovada; prova aprovada permite PA zero e custa um dia"] = function(t)
		local s = montar()
		local npc = Treinadores.listar(s.treinadores)[1]
		t.eq((s:treinar(7, npc.id, npc.arvore, "sem-prova")), false)
		t.eq(s.run.dia, 0); t.eq(s.planos[7].paExtra, 2); t.eq(s.planos[7].escolhida, nil)
		s.planos[7].paExtra = 0
		local prova = s.provacoes and s.provacoes[npc.id]
		if not prova then s.provacoes = s.provacoes or {}; prova = Provas.nova(); s.provacoes[npc.id] = prova end
		assert(Provas.iniciar(prova, 7, 0))
		t.eq((s:treinar(7, npc.id, npc.arvore, "em-curso")), false)
		t.eq(s.run.dia, 0)
		assert(Provas.aprovar(prova, 7, 1))
		t.eq((s:treinar(7, npc.id, npc.arvore, "compra")), true)
		t.eq(s.planos[7].escolhida, npc.arvore)
		t.eq(s.planos[7].paExtra, 0)
		t.eq(s.run.dia, 1)
		t.eq(Provas.aprovado(s.provacoes[npc.id], 7), false, "prova consumida")
	end,
	["recibo corrompido na retomada e requestId invalido recusam sem erro"] = function(t)
		local s, dados, deps = montar()
		t.eq((s:treinar(7, "vila-1", s.treinadores.vila[1], nil)), false)
		t.eq((comprar(s)), true)
		dados["run/f4"].planos["7"].treino = { requestId = "compra", npcId = "inventado", arvore = s.planos[7].escolhida }
		t.eq((Sessao.new(deps):retomar("f4")), false)
		dados["run/f4"].planos["7"].treino = "corrompido"
		t.eq((Sessao.new(deps):retomar("f4")), false)
	end,
	["save antigo migra sem consumir rng e rejeita extras corrompidos"] = function(t)
		local _, dados, deps = montar()
		dados["run/f4"].extras.treinadoresVila = nil; dados["run/f4"].extras.treinadorTaverna = nil
		deps.rng.NextInteger = function() error("nao rerrolar criacao") end
		local a, b = Sessao.new(deps), Sessao.new(deps)
		t.eq((a:retomar("f4")), true); t.eq((b:retomar("f4")), true)
		t.eq(table.concat(a.treinadores.vila, ","), "furtividade-e-armadilhas,agua")
		t.eq(table.concat(a.treinadores.vila, ","), table.concat(b.treinadores.vila, ","))
		dados["run/f4"].extras.treinadoresVila = "agua,agua,inventada"
		t.eq((Sessao.new(deps):retomar("f4")), false)
	end,
	["compra concede escolha grava recibo consome prova e replay nao cobra novamente"] = function(t)
		local s, dados, deps = montar()
		local npc = Treinadores.listar(s.treinadores)[1]
		local prova = aprovar(s, npc.id)
		t.eq((s:treinar(7, npc.id, npc.arvore, "compra")), true)
		t.eq(s.planos[7].escolhida, npc.arvore)
		t.eq(s.planos[7].paExtra, 2)
		t.eq(s.run.dia, 1)
		t.eq(Provas.aprovado(prova, 7), false)
		local novo = Sessao.new(deps); t.eq((novo:retomar("f4")), true)
		local chamadas = dados.chamadas
		t.eq((novo:treinar(7, npc.id, npc.arvore, "compra")), true)
		t.eq(dados.chamadas, chamadas)
		t.eq(novo.planos[7].treino.requestId, "compra")
		t.eq((comprar(novo, "outra")), false)
	end,
	["falha no save desfaz arvore saldo e prazo e permite reaprovacao"] = function(t)
		local s, dados = montar()
		local npc = Treinadores.listar(s.treinadores)[1]
		local prova = aprovar(s, npc.id)
		local plano, run = s.planos[7], s.run
		dados.falhar = true
		t.eq((s:treinar(7, npc.id, npc.arvore, "compra")), false)
		t.eq(s.planos[7], plano); t.eq(s.run, run); t.eq(s.ocupada, false)
		t.eq(Provas.aprovado(prova, 7), true)
		dados.falhar = false
		t.eq((s:treinar(7, npc.id, npc.arvore, "compra")), true)
	end,
	["save em andamento impede voto queda retorno e outra compra sem sobrescrever"] = function(t)
		local s, dados = montar()
		dados.durante = function()
			t.eq(s.ocupada, true)
			t.eq((s:votar(8, "rumo-a-floresta")), false)
			t.eq((s:cair(8, true)), false)
			t.eq((s:ausentar(8)), false)
			t.eq((s:retornar(8)), false)
			t.eq((comprar(s, "concorrente")), false)
		end
		t.eq((comprar(s)), true)
		t.eq(s.run.dia, 1)
	end,
	["contexto invalido e request invalido nao cobram nem gastam dias"] = function(t)
		local mutacoes = {
			function(s) s.planos[7].modo = "zero" end,
			function(s) s.planos[7].paExtra = 0/0 end,
			function(s) s.planos[7].escolhida = "furtividade-e-armadilhas" end, -- já conhece a árvore deste mestre
			function(s) s.run.jogadores[7].presente = false end,
			function(s) s.run.jogadores[7].caido = true end,
			function(s) s.run.regiao = "floresta-sombria" end,
			function(s) s.evento = {} end,
			function(s) s.luta = "chefe" end,
			function(s) s.votos[8] = "rumo-a-floresta" end,
			function(s) s.run.fim = { motivo = "queda", dia = 0 } end,
		}
		for _, mudar in mutacoes do
			local s, dados = montar(); aprovar(s, "vila-1"); mudar(s)
			local chamadas = dados.chamadas
			t.eq((comprar(s)), false); t.eq(s.run.dia, 0); t.eq(dados.chamadas, chamadas)
		end
		local s = montar()
		t.eq((s:treinar(7, "vila-1", "inventada", "a")), false)
		t.eq((s:treinar(999, "vila-1", s.treinadores.vila[1], "a")), false)
	end,
	["utilidade elegivel permite escolher explorador pelo mesmo plano"] = function(t)
		local s = montar()
		local escolha = Treinadores.escolher(s.planos[7], "navegacao-e-lideranca")
		t.ok(escolha)
		t.eq(escolha.arvore, "navegacao-e-lideranca")
	end,
	["segunda arvore pela provacao de outro mestre: 1 dia, 0 PA, sem repetir e uma por run"] = function(t)
		local s, dados, deps = montar()
		local lista = Treinadores.listar(s.treinadores)
		local primeiro, outro = lista[1], lista[2]
		t.eq((comprar(s)), true)
		local dia, pa = s.run.dia, s.planos[7].paExtra
		-- mesma árvore: recusa (já conhece), sem gastar dia
		aprovar(s, primeiro.id)
		t.eq((s:treinar(7, primeiro.id, primeiro.arvore, "repete")), false)
		t.eq(s.run.dia, dia)
		-- outro mestre: aprende como segunda
		aprovar(s, outro.id)
		local oferta = Treinadores.escolher(s.planos[7], outro.arvore)
		t.eq(oferta.segunda, true)
		t.eq((s:treinar(7, outro.id, outro.arvore, "segunda")), true)
		t.eq(s.planos[7].escolhida, primeiro.arvore)
		t.eq(s.planos[7].segunda, outro.arvore)
		t.eq(s.run.dia, dia + Treinadores.diasDeTreino(outro.arvore))
		t.eq(s.planos[7].paExtra, pa)
		-- replay do mesmo pedido não cobra de novo; sobrevive ao save/retomada
		local chamadas = dados.chamadas
		t.eq((s:treinar(7, outro.id, outro.arvore, "segunda")), true)
		t.eq(dados.chamadas, chamadas)
		local novo = Sessao.new(deps); t.eq((novo:retomar("f4")), true)
		t.eq(novo.planos[7].segunda, outro.arvore)
		t.eq(novo.planos[7].treinoSegunda.requestId, "segunda")
		t.eq((novo:treinar(7, outro.id, outro.arvore, "segunda")), true)
		-- uma segunda por run: terceira recusa
		local terceiro = Treinadores.escolher(novo.planos[7], "fogo")
		t.eq(terceiro, nil)
	end,
	["segunda arvore tambem vale para modo pronto e recibo corrompido bloqueia retomada"] = function(t)
		local plano = { modo = "pronto", arvore = "vendaval" }
		local escolha = Treinadores.escolher(plano, "agua")
		t.eq(escolha.segunda, true)
		t.eq((Treinadores.escolher(plano, "vendaval")), nil)
		t.eq((Treinadores.escolher({ modo = "zero", oferta = { "agua" } }, "agua")), nil) -- sem árvore da oferta ainda
		local s, dados, deps = montar()
		local lista = Treinadores.listar(s.treinadores)
		t.eq((comprar(s)), true)
		aprovar(s, lista[2].id)
		t.eq((s:treinar(7, lista[2].id, lista[2].arvore, "segunda")), true)
		dados["run/f4"].planos["7"].treinoSegunda = { requestId = "segunda", npcId = "inventado", arvore = lista[2].arvore }
		t.eq((Sessao.new(deps):retomar("f4")), false)
		dados["run/f4"].planos["7"].treinoSegunda = { requestId = "segunda", npcId = lista[2].id, arvore = lista[2].arvore }
		dados["run/f4"].planos["7"].segunda = lista[1].arvore -- igual à primeira
		t.eq((Sessao.new(deps):retomar("f4")), false)
	end,
}
