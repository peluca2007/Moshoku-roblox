-- SOMENTE STUDIO: módulo servidor; dependências e transporte simulados.
local Shared = game:GetService("ReplicatedStorage").Shared
local PersonagemSessao = require(script.Parent.Parent.PersonagemSessao)
local CriacaoPersonagem = require(Shared.Regras.CriacaoPersonagem)
local Conta = require(Shared.Regras.RunConta)
local Restricao = require(Shared.Regras.RestricaoDeCriacao)

local function catalogo()
	local porId = {
		["race/humano"] = { id = "race/humano", kind = "race", data = { id = "humano", tier = "comum", attributeChoices = 1 } },
		["background/plebeu"] = { id = "background/plebeu", kind = "background", data = { id = "plebeu" } },
		["tree/agua"] = { id = "tree/agua", kind = "tree", data = {
			id = "agua", category = "magia", subgroup = "Magia Ofensiva", ranks = { "rank/agua/Principiante" },
		} },
		["tree/fogo"] = { id = "tree/fogo", kind = "tree", data = {
			id = "fogo", category = "magia", subgroup = "Magia Ofensiva", ranks = { "rank/fogo/Principiante" },
		} },
		["rank/agua/Principiante"] = { id = "rank/agua/Principiante", kind = "rank", data = {
			treeId = "agua", rank = "Principiante", hpDiceFormula = "1d6+1", abilities = {
				"ability/agua/Principiante/onda", "ability/agua/Principiante/corrente",
			},
		} },
		["ability/agua/Principiante/onda"] = { id = "ability/agua/Principiante/onda", kind = "ability", data = {
			treeId = "agua", rank = "Principiante", name = "Onda", paCost = 1,
		} },
		["ability/agua/Principiante/corrente"] = { id = "ability/agua/Principiante/corrente", kind = "ability", data = {
			treeId = "agua", rank = "Principiante", name = "Corrente", paCost = 1,
		} },
		["rank/fogo/Principiante"] = { id = "rank/fogo/Principiante", kind = "rank", data = {
			treeId = "fogo", rank = "Principiante", hpDiceFormula = "1d6+1", abilities = { "ability/fogo/Principiante/brasinha" },
		} },
		["ability/fogo/Principiante/brasinha"] = { id = "ability/fogo/Principiante/brasinha", kind = "ability", data = {
			treeId = "fogo", rank = "Principiante", name = "Brasinha", paCost = 1,
		} },
		["skill/medicina"] = { id = "skill/medicina", kind = "skill", data = { name = "Medicina", attribute = "intelecto" } },
		["weapon-group/desarmado-e-improvisado"] = { id = "weapon-group/desarmado-e-improvisado", kind = "weapon-group", data = {} },
	}
	return { POR_ID = porId, POR_ESPECIE = {
		skill = { porId["skill/medicina"] }, ability = {
			porId["ability/agua/Principiante/onda"], porId["ability/agua/Principiante/corrente"],
			porId["ability/fogo/Principiante/brasinha"],
		},
	} }
end

local sequenciaProposta = 0
local function proposta()
	sequenciaProposta += 1
	return {
		requestId = "criacao-" .. tostring(sequenciaProposta),
		nome = "Ária da Chuva",
		raceId = "race/humano", backgroundId = "background/plebeu", startingTreeId = "tree/agua",
		attributeBase = { forca = 2, agilidade = 0, vigor = 0, intelecto = 0, espirito = 0 },
		raceAttributeChoices = { "agilidade" }, freeSkillChoiceIds = {}, treeSkillChoiceIds = {},
	}
end

local function contexto(calcular, filtrarNome, persistencia)
	local x = { handlers = {}, envios = {}, instante = 0, combate = false, conectado = true, calculos = 0, filtros = 0 }
	x.api = PersonagemSessao.start({
		handlers = x.handlers, catalogo = catalogo(), relogio = function() return x.instante end,
		calcular = function(...)
			x.calculos += 1
			local args = table.pack(...)
			args[1].nome = nil
			return (calcular or CriacaoPersonagem.calcular)(table.unpack(args, 1, args.n))
		end,
		filtrarNome = function(player, nome)
			x.filtros += 1
			return if filtrarNome then filtrarNome(player, nome) else nome
		end,
		emCombate = function() return x.combate end,
		conectado = function() return x.conectado end,
		persistencia = persistencia,
		conta = { obter = function() return if x.falhaConta then nil else (x.conta or Conta.nova()) end },
		runId = function() return x.runId end,
		remote = { FireClient = function(_, player, evento, perfil)
			table.insert(x.envios, { player = player, evento = evento, perfil = perfil })
		end },
	})
	return x
end

local A, B = { UserId = 101 }, { UserId = 202 }

local function calcularComArmas(...)
	local perfil, motivo = CriacaoPersonagem.calcular(...)
	if perfil then perfil.inventarioInicial = {
		{ sourceLocalId = "kit-inicial-01", type = "arma", name = "Arco" },
		{ sourceLocalId = "kit-inicial-02", type = "arma", name = "Adaga" },
		{ sourceLocalId = "kit-inicial-03", type = "geral", name = "Poção" },
	} end
	return perfil, motivo
end

local function storePerfilFake()
	local store = { dados = {}, revisoes = {}, gravacoes = 0 }
	function store:load(id) return self.dados[id], self.revisoes[id] or 0, nil end
	function store:save(id, perfil, esperado)
		if self.falha then return self.falha end
		if esperado ~= (self.revisoes[id] or 0) then return "conflito" end
		self.gravacoes += 1
		self.dados[id], self.revisoes[id] = perfil, esperado + 1
		return "ok", esperado + 1
	end
	return store
end

return {
 ["F7 servidor recusa raça bloqueada antes do cálculo e falha de conta fecha criação"] = function(t)
  local x = contexto()
  local p = proposta(); p.raceId = "race/superd"
  t.ok(string.find(x.handlers.personagemPessoalCriar(A, p), "Raça bloqueada", 1, true))
  t.eq(x.calculos, 0)
  x.instante = 1; x.falhaConta = true
  t.ok(string.find(x.handlers.personagemPessoalCriar(A, proposta()), "desbloqueios", 1, true))
  t.eq(x.calculos, 0)
 end,
 ["F7 raça comprada passa pelo gate e segue sujeita ao cálculo do livro"] = function(t)
  local x = contexto(function(construcao)
   t.eq(construcao.raceId, "race/superd")
   return nil, "Sentinela: cálculo do livro foi chamado."
  end)
  x.conta = Conta.nova(); x.conta.desbloqueios["raca:rara"] = true
  local p = proposta(); p.raceId = "race/superd"
  t.eq(x.handlers.personagemPessoalCriar(A, p), "Sentinela: cálculo do livro foi chamado.")
  t.eq(x.calculos, 1)
 end,
 ["F7 kit salvo replay recálculo consumo e reconexão não renovam poção"] = function(t)
  local store = storePerfilFake()
  local x = contexto(nil, nil, store)
  x.conta = Conta.nova(); x.conta.desbloqueios["item:pocao-menor"] = true; x.runId = "u101-7"
  Restricao.definir(function() return "agua" end)
  local ok, erro = pcall(function()
   t.eq(x.api.carregar(A), true)
   local p = proposta()
   t.eq(x.handlers.personagemPessoalCriar(A, p), nil)
   local perfil = x.api.consultar(A)
   t.eq(#perfil.inventarioLoja, 1)
   local id = perfil.inventarioLoja[1].sourceLocalId
   t.eq(x.handlers.personagemPessoalCriar(A, p), nil)
   t.eq(store.gravacoes, 1)
   x.instante = 1; t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
   t.eq(#x.api.consultar(A).inventarioLoja, 1)
   t.eq(x.api.consumirItem(A, "item/pocao_menor_cura", id), true)
   t.eq(x.api.consumirItem(A, "item/pocao_menor_cura", id), false)
   x.instante = 2; t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
   for _, item in x.api.consultar(A).inventarioInicial do t.ok(item.sourceLocalId ~= id) end
   local nova = contexto(nil, nil, store)
   t.eq(nova.api.carregar(A), true)
   for _, item in nova.api.consultar(A).inventarioInicial do t.ok(item.sourceLocalId ~= id) end
  end)
  Restricao.definir(nil)
  if not ok then error(erro) end
 end,
 ["missões contam cada encontro uma vez e entrega salva ouro junto ao estado"] = function(t)
		local x = contexto()
		t.eq(x.api.carregar(A), true)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		local aceitou = x.api.acaoMissao(A, "aceitar", "cacada-do-bosque")
		t.eq(aceitou, true)
		t.eq(x.api.recompensarEncontro(A, "encontro-1", 0, "region/encounter/forest"), true)
		t.eq(x.api.recompensarEncontro(A, "encontro-1", 0, "region/encounter/forest"), true)
		t.eq(x.api.consultar(A).missoes["cacada-do-bosque"].progresso, 1)
		t.eq(x.api.recompensarEncontro(A, "encontro-2", 0, "region/encounter/forest"), true)
		t.eq(x.api.consultar(A).missoes["cacada-do-bosque"].estado, "cumprida")
		local entregou, _, ouro = x.api.acaoMissao(A, "entregar", "cacada-do-bosque")
		t.eq(entregou, true); t.eq(ouro, 30); t.eq(x.api.consultar(A).ouro, 30)
		local repetiu = x.api.acaoMissao(A, "entregar", "cacada-do-bosque")
		t.eq(repetiu, false); t.eq(x.api.consultar(A).ouro, 30)
	end,
	["arma pessoal troca e replay antigo não reverte escolha nem grava novamente"] = function(t)
		local store = storePerfilFake()
		local x = contexto(calcularComArmas, nil, store)
		t.eq(x.api.carregar(A), true)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		local primeiro = { sourceLocalId = "kit-inicial-01", requestId = "quantidade" }
		t.eq(x.handlers.personagemPessoalEquiparArma(A, primeiro), nil)
		t.eq(x.api.consultar(A).armaInicialSourceLocalId, primeiro.sourceLocalId)
		x.instante = 0.5
		t.eq(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "kit-inicial-02", requestId = "troca" }), nil)
		t.eq(store.gravacoes, 3)
		t.eq(x.handlers.personagemPessoalEquiparArma(A, primeiro), nil)
		t.eq(x.api.consultar(A).armaInicialSourceLocalId, "kit-inicial-02")
		t.eq(store.gravacoes, 3)
		t.ok(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "kit-inicial-02", requestId = primeiro.requestId }))
		t.eq(x.envios[#x.envios].player, A)
		t.eq(x.api.consultar(B), nil)
	end,
	["arma selecionada recarrega e recalcular mesma árvore conserva escolha"] = function(t)
		local store = storePerfilFake()
		local x = contexto(calcularComArmas, nil, store)
		x.api.carregar(A)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.eq(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "kit-inicial-01", requestId = "equipar" }), nil)
		t.eq(store.dados[A.UserId].armaInicialSourceLocalId, "kit-inicial-01")
		local y = contexto(calcularComArmas, nil, store)
		t.eq(y.api.carregar(A), true)
		t.eq(y.api.consultar(A).armaInicialSourceLocalId, "kit-inicial-01")
		y.instante = 1
		t.eq(y.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.eq(y.api.consultar(A).armaInicialSourceLocalId, "kit-inicial-01")
		y.instante = 2
		local outra = proposta(); outra.startingTreeId = "tree/fogo"
		t.eq(y.handlers.personagemPessoalCriar(A, outra), nil)
		t.eq(y.api.consultar(A).armaInicialSourceLocalId, nil)
	end,
	["arma recusa itens gerais IDs ausentes payload e contexto inválidos"] = function(t)
		local x = contexto(calcularComArmas)
		local pedido = { sourceLocalId = "kit-inicial-01", requestId = "equipar" }
		t.ok(x.handlers.personagemPessoalEquiparArma(A, pedido))
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.ok(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = pedido.sourceLocalId, requestId = "x", ownerId = B.UserId }))
		t.ok(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "ausente", requestId = "x" }))
		x.instante = 1
		t.ok(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "kit-inicial-03", requestId = "geral" }))
		x.instante, x.combate = 2, true
		t.ok(x.handlers.personagemPessoalEquiparArma(A, pedido))
		x.combate, x.conectado = false, false
		t.ok(x.handlers.personagemPessoalEquiparArma(A, pedido))
		t.eq(x.api.consultar(A).armaInicialSourceLocalId, nil)
		local carregando = contexto(calcularComArmas, nil, storePerfilFake())
		t.ok(carregando.handlers.personagemPessoalEquiparArma(A, pedido))
	end,
	["replay antigo de criação não sobrescreve ficha nova e não repete cálculo nem gravação"] = function(t)
		local store = storePerfilFake()
		local x = contexto(nil, nil, store)
		t.eq(x.api.carregar(A), true)
		local antiga = proposta()
		t.eq(x.handlers.personagemPessoalCriar(A, antiga), nil)
		local nova = proposta()
		nova.nome, nova.startingTreeId = "Ficha Nova", "tree/fogo"
		x.instante = 1
		t.eq(x.handlers.personagemPessoalCriar(A, nova), nil)
		local calculos, filtros, gravacoes = x.calculos, x.filtros, store.gravacoes
		x.instante = 2
		t.eq(x.handlers.personagemPessoalCriar(A, antiga), nil)
		t.eq(x.api.consultar(A).nome, "Ficha Nova")
		t.eq(x.api.consultar(A).construcao.startingTreeId, "tree/fogo")
		t.eq(x.calculos, calculos)
		t.eq(x.filtros, filtros)
		t.eq(store.gravacoes, gravacoes)
		local conflito = table.clone(antiga)
		conflito.nome = "Conteúdo diferente"
		t.eq(x.handlers.personagemPessoalCriar(A, conflito), "ID de pedido já usado com outra criação.")
		t.eq(x.api.consultar(A).nome, "Ficha Nova")
	end,
	["criação exige requestId e rejeita campos remotos desconhecidos"] = function(t)
		local x = contexto()
		local ausente = proposta()
		ausente.requestId = nil
		t.ok(x.handlers.personagemPessoalCriar(A, ausente))
		local extra = proposta()
		extra.ownerId = B.UserId
		t.ok(x.handlers.personagemPessoalCriar(A, extra))
		t.eq(x.api.consultar(A), nil)
	end,
	["falha ou conflito ao salvar arma preserva seleção anterior e permite tentar de novo"] = function(t)
		for _, falha in { "erro", "conflito" } do
			local store = storePerfilFake()
			local x = contexto(calcularComArmas, nil, store)
			x.api.carregar(A)
			t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
			t.eq(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "kit-inicial-01", requestId = "primeira" }), nil)
			store.falha, x.instante = falha, 1
			local pedido = { sourceLocalId = "kit-inicial-02", requestId = "segunda" }
			t.ok(x.handlers.personagemPessoalEquiparArma(A, pedido))
			t.eq(x.api.consultar(A).armaInicialSourceLocalId, "kit-inicial-01")
			t.eq(store.dados[A.UserId].armaInicialSourceLocalId, "kit-inicial-01")
			store.falha, x.instante = nil, 2
			t.eq(x.handlers.personagemPessoalEquiparArma(A, pedido), nil)
			t.eq(x.api.consultar(A).armaInicialSourceLocalId, "kit-inicial-02")
		end
	end,
	["perfil antigo conserva ausência de escolha e arma salva fora do kit bloqueia carga"] = function(t)
		local store = storePerfilFake()
		local x = contexto(calcularComArmas, nil, store)
		x.api.carregar(A)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		local y = contexto(calcularComArmas, nil, store)
		t.eq(y.api.carregar(A), true)
		t.eq(y.api.consultar(A).armaInicialSourceLocalId, nil)
		store.dados[A.UserId].armaInicialSourceLocalId = "kit-inicial-03"
		local z = contexto(calcularComArmas, nil, store)
		t.eq(z.api.carregar(A), false)
		t.eq(z.api.consultar(A), nil)
		t.eq(z.api.estadoCarga(A), "erro")
	end,
	["arma revalida combate e bloqueia pedidos concorrentes durante save"] = function(t)
		local store = storePerfilFake()
		local x = contexto(calcularComArmas, nil, store)
		x.api.carregar(A)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		local salvarOriginal = store.save
		function store:save(id, perfil, esperado)
			t.ok(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "kit-inicial-02", requestId = "concorrente" }))
			t.ok(x.handlers.personagemPessoalCriar(A, proposta()))
			t.ok(x.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/onda", requestId = "concorrente" }))
			x.combate = true
			return salvarOriginal(self, id, perfil, esperado)
		end
		t.ok(x.handlers.personagemPessoalEquiparArma(A, { sourceLocalId = "kit-inicial-01", requestId = "equipar" }))
		t.eq(x.api.consultar(A), nil)
		t.eq(x.api.estadoCarga(A), "erro")
		t.eq(store.dados[A.UserId].armaInicialSourceLocalId, "kit-inicial-01")
	end,
	["consumo da Poção Menor altera apenas a sessão e é idempotente por item"] = function(t)
		local item = {
			sourceLocalId = "kit-inicial-01", name = "Poção Menor de Cura", type = "geral",
			description = "Cura 1d8 + 2 PV. Beber ou dar a um aliado adjacente é Usar Item (1 Ação). Poção não é magia: a Ferida Fresca não a dobra, e nenhuma poção apaga Ferimento Crítico.",
		}
		local x = contexto(function()
			return { inventarioInicial = { table.clone(item) }, nome = "temporario", construcao = { raceId = "race/humano" } }
		end)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.eq(x.api.consumirItem(A, "item/outra-coisa", item.sourceLocalId), false)
		t.eq(x.api.consumirItem(A, "item/pocao_menor_cura", "ausente"), false)
		t.eq(x.api.consumirItem(A, "item/pocao_menor_cura", item.sourceLocalId), true)
		t.eq(#x.api.consultar(A).inventarioInicial, 0)
		t.eq(x.envios[#x.envios].player, A)
		t.eq(#x.envios[#x.envios].perfil.inventarioInicial, 0)
		t.eq(x.api.consumirItem(A, "item/pocao_menor_cura", item.sourceLocalId), false)
		t.eq(x.api.consultar(B), nil)
	end,
	["calcula construção bruta e envia somente ao próprio jogador"] = function(t)
		local x, p = contexto(), proposta()
		t.eq(x.handlers.personagemPessoalCriar(A, p), nil)
		local envio = x.envios[1]
		t.eq(envio.player, A)
		t.eq(envio.evento, "personagemPessoal")
		t.eq(envio.perfil.construcao.unlockedRankIds[1], "rank/agua/Principiante")
		t.eq(envio.perfil.construcao.freeSkillChoiceIds, nil)
		t.eq(envio.perfil.nome, "Ária da Chuva")
		t.eq(envio.perfil.atributos.agilidade, 1)
		t.ok(envio.perfil.estatisticas.maxima.pv > 0)
		t.ok(type(envio.perfil.pericias) == "table")
		p.attributeBase.forca = 0
		x.handlers.personagemPessoalConsultar(A, {})
		t.eq(x.envios[2].perfil.construcao.attributeBase.forca, 2)
	end,
	["compra habilidade do rank aberto uma vez e repete o pedido sem duplicar"] = function(t)
		local x = contexto()
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		local payload = { habilidadeId = "ability/agua/Principiante/onda", requestId = "req-onda-1" }
		t.eq(x.handlers.personagemPessoalAprender(A, payload), nil)
		t.eq(x.envios[2].player, A)
		t.eq(x.envios[2].perfil.habilidadesCompradas[1], payload.habilidadeId)
		t.eq(x.handlers.personagemPessoalAprender(A, payload), nil)
		t.eq(#x.api.consultar(A).habilidadesCompradas, 1)
		t.eq(x.handlers.personagemPessoalAprender(A, { habilidadeId = payload.habilidadeId, requestId = "req-onda-1" }), nil)
		t.eq(#x.api.consultar(A).habilidadesCompradas, 1)
	end,
	["compra recusa payload adulterado combate ficha ausente e reuso conflitante"] = function(t)
		local x = contexto()
		t.ok(x.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/onda", requestId = "x", ownerId = B.UserId }))
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.ok(x.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/onda", requestId = "x", campo = true }))
		t.eq(x.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/onda", requestId = "req-1" }), nil)
		x.instante = 0.5
		t.ok(x.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/onda", requestId = "req-2" }))
		t.eq(x.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/corrente", requestId = "req-1" }), "ID de pedido já usado com outra habilidade.")
		t.eq(x.handlers.personagemPessoalAprender(B, { habilidadeId = "ability/agua/Principiante/onda", requestId = "req-b" }), "Crie um personagem antes de aprender habilidades.")
		x.instante, x.combate = 1, true
		t.eq(x.handlers.personagemPessoalAprender(B, { habilidadeId = "ability/agua/Principiante/onda", requestId = "req-b" }), "Aprenda habilidades antes do combate.")
	end,
	["recalcular preserva compra da mesma árvore e recusa mudar a árvore inicial"] = function(t)
		local x = contexto()
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.eq(x.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/onda", requestId = "compra-aria" }), nil)
		x.instante = 1
		local atualizada = proposta()
		atualizada.nome = "Ária Atualizada"
		t.eq(x.handlers.personagemPessoalCriar(A, atualizada), nil)
		t.eq(x.api.consultar(A).habilidadesCompradas[1], "ability/agua/Principiante/onda")
		x.instante = 1.75
		atualizada.startingTreeId = "tree/fogo"
		atualizada.requestId = "criacao-arvore-bloqueada"
		t.eq(x.handlers.personagemPessoalCriar(A, atualizada), "Esta ficha já aprendeu habilidades; mantenha a árvore inicial para preservar a progressão.")
		t.eq(x.api.consultar(A).construcao.startingTreeId, "tree/agua")
		t.eq(x.api.consultar(A).habilidadesCompradas[1], "ability/agua/Principiante/onda")
	end,
	["filtra nome no servidor e revalida estado depois da espera"] = function(t)
		local x = contexto(nil, function(_, nome) return "Filtrado " .. nome end)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.eq(x.envios[1].perfil.nome, "Filtrado Ária da Chuva")
		local y = contexto()
		t.eq(y.handlers.personagemPessoalCriar(A, proposta()), nil)
		-- O estado pode mudar enquanto a chamada de filtro aguarda.
		local z
		z = contexto(nil, function(_, nome)
			z.combate = true
			return nome
		end)
		t.eq(z.handlers.personagemPessoalCriar(A, proposta()), "Crie ou ajuste o personagem antes do combate.")
		t.eq(z.calculos, 0)
		t.eq(#z.envios, 0)
		t.eq(y.calculos, 1)
	end,
	["A não lê folha de B nem escolhe ownerId na consulta"] = function(t)
		local x = contexto()
		t.eq(x.handlers.personagemPessoalCriar(B, proposta()), nil)
		t.ok(x.handlers.personagemPessoalConsultar(A, { ownerId = B.UserId }))
		t.eq(#x.envios, 1)
		t.eq(x.handlers.personagemPessoalConsultar(A, {}), nil)
		t.eq(x.envios[2].player, A)
		t.eq(x.envios[2].perfil, nil)
	end,
	["ownerId e valores derivados são recusados na criação"] = function(t)
		for _, campo in { "ownerId", "atributos", "estatisticas" } do
			local x, p = contexto(), proposta()
			p[campo] = 202
			t.ok(x.handlers.personagemPessoalCriar(A, p))
			t.eq(#x.envios, 0)
		end
	end,
	["proposta inválida preserva a folha válida"] = function(t)
		local x = contexto()
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		x.instante = 1
		local p = proposta()
		p.attributeBase.forca = 4
		t.ok(x.handlers.personagemPessoalCriar(A, p))
		t.eq(#x.envios, 1)
		x.handlers.personagemPessoalConsultar(A, {})
		t.eq(x.envios[2].perfil.construcao.attributeBase.forca, 2)
	end,
	["recalcula e substitui antes do combate sem referências compartilhadas"] = function(t)
		local x = contexto()
		x.handlers.personagemPessoalCriar(A, proposta())
		x.envios[1].perfil.atributos.forca = 99
		x.instante = 1
		local p = proposta()
		p.attributeBase.forca, p.attributeBase.intelecto = 0, 2
		t.eq(x.handlers.personagemPessoalCriar(A, p), nil)
		x.handlers.personagemPessoalConsultar(A, {})
		t.eq(x.envios[3].perfil.atributos.forca, 0)
		t.eq(x.envios[3].perfil.atributos.intelecto, 2)
	end,
	["combate bloqueia criação e alteração mas permite consultar"] = function(t)
		local x = contexto()
		x.handlers.personagemPessoalCriar(A, proposta())
		x.combate, x.instante = true, 1
		t.ok(x.handlers.personagemPessoalCriar(A, proposta()))
		t.ok(x.handlers.personagemPessoalCriar(B, proposta()))
		t.eq(x.calculos, 1)
		t.eq(x.handlers.personagemPessoalConsultar(A, {}), nil)
		t.ok(x.envios[2].perfil)
	end,
	["throttle de cálculo é dedicado por jogador e inclui proposta recusada"] = function(t)
		local x = contexto()
		local invalida = proposta()
		invalida.raceId = "race/ausente"
		t.ok(x.handlers.personagemPessoalCriar(A, invalida))
		t.eq(x.calculos, 1)
		t.ok(x.handlers.personagemPessoalCriar(A, proposta()))
		t.eq(x.calculos, 1)
		t.eq(x.handlers.personagemPessoalCriar(B, proposta()), nil)
		t.eq(x.calculos, 2)
		x.instante = 0.75
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.eq(x.calculos, 3)
	end,
	["remoção limpa folha e throttle somente do jogador removido"] = function(t)
		local x = contexto()
		x.handlers.personagemPessoalCriar(A, proposta())
		x.handlers.personagemPessoalCriar(B, proposta())
		x.api.remover(A)
		x.handlers.personagemPessoalConsultar(A, {})
		t.eq(x.envios[3].perfil, nil)
		x.handlers.personagemPessoalConsultar(B, {})
		t.ok(x.envios[4].perfil)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
	end,
	["erros de cálculo retornam mensagem segura e preservam folha"] = function(t)
		local quebrar = false
		local x = contexto(function(...)
			if quebrar then error("SEGREDO traceback do servidor") end
			return CriacaoPersonagem.calcular(...)
		end)
		x.handlers.personagemPessoalCriar(A, proposta())
		quebrar, x.instante = true, 1
		local erro = x.handlers.personagemPessoalCriar(A, proposta())
		t.eq(erro, "Erro interno ao calcular o personagem.")
		x.handlers.personagemPessoalConsultar(A, {})
		t.ok(x.envios[2].perfil)
	end,
	["ficha persistida carrega com atributos recalculados e compras validadas"] = function(t)
		local estado, revisao = nil, 0
		local store = {
			load = function() return estado, if estado then revisao else 0, nil end,
			save = function(_, _, perfil, esperado)
				if esperado ~= revisao then return "conflito", revisao end
				estado, revisao = perfil, revisao + 1
				return "ok", revisao
			end,
		}
		local primeiro = contexto(nil, nil, store)
		t.eq(primeiro.api.carregar(A), true)
		t.eq(primeiro.handlers.personagemPessoalCriar(A, proposta()), nil)
		t.eq(estado.atributos, nil)
		t.eq(estado.construcao.unlockedRankIds, nil)
		primeiro.instante = 1
		t.eq(primeiro.handlers.personagemPessoalAprender(A, { habilidadeId = "ability/agua/Principiante/onda", requestId = "persistir-onda" }), nil)
		t.eq(estado.habilidadesCompradas[1], "ability/agua/Principiante/onda")
		local segundo = contexto(nil, nil, store)
		local carregou, motivo = segundo.api.carregar(B)
		t.ok(carregou, motivo)
		local carregado = segundo.api.consultar(B)
		t.eq(carregado.nome, "Ária da Chuva")
		t.eq(carregado.atributos.agilidade, 1)
		t.ok(carregado.estatisticas.maxima.pv > 0)
		t.eq(carregado.habilidadesCompradas[1], "ability/agua/Principiante/onda")
	end,
	["erro de persistência não altera perfil em memória"] = function(t)
		local store = {
			load = function() return nil, 0, nil end,
			save = function() return "erro", "indisponível" end,
		}
		local x = contexto(nil, nil, store)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), "Sua ficha ainda está carregando. Tente novamente.")
		x.api.carregar(A)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), "Não foi possível salvar a ficha. Tente novamente.")
		t.eq(x.api.consultar(A), nil)
		t.eq(#x.envios, 1)
	end,
	["consulta recupera falha transitória de carga sem criar perfil vazio"] = function(t)
		local tentativas = 0
		local store = {
			load = function()
				tentativas += 1
				if tentativas == 1 then return nil, nil, "indisponível temporariamente" end
				return nil, 0, nil
			end,
		}
		local x = contexto(nil, nil, store)
		local ok, motivo = x.api.carregar(A)
		t.eq(ok, false)
		t.eq(motivo, "Não foi possível carregar sua ficha agora. Tente novamente.")
		t.eq(x.api.estadoCarga(A), "erro")
		t.eq(x.handlers.personagemPessoalConsultar(A, {}), nil)
		t.eq(tentativas, 2)
		t.eq(x.api.estadoCarga(A), "pronto")
		t.eq(x.api.consultar(A), nil)
		t.eq(x.envios[1].player, A)
		t.eq(x.envios[1].perfil, nil)
	end,
	["retry de carga tem intervalo e registro inválido continua bloqueado"] = function(t)
		local tentativas = 0
		local store = {
			load = function()
				tentativas += 1
				if tentativas < 3 then return nil, nil, "indisponível temporariamente" end
				return nil, 0, nil
			end,
		}
		local x = contexto(nil, nil, store)
		t.eq(x.api.carregar(A), false)
		t.ok(x.handlers.personagemPessoalConsultar(A, {}))
		t.eq(tentativas, 2)
		t.eq(x.handlers.personagemPessoalConsultar(A, {}), "Aguarde alguns segundos antes de tentar carregar a ficha novamente.")
		t.eq(tentativas, 2)
		x.instante = 5
		t.eq(x.handlers.personagemPessoalConsultar(A, {}), nil)
		t.eq(tentativas, 3)
		t.eq(x.api.estadoCarga(A), "pronto")

		local leituras = 0
		local corrompido = contexto(nil, nil, { load = function()
			leituras += 1
			return { nome = "Ária", construcao = {}, habilidadesCompradas = {} }, 1, nil
		end })
		local ok, motivo = corrompido.api.carregar(A)
		t.eq(ok, false)
		t.eq(corrompido.handlers.personagemPessoalConsultar(A, {}), motivo)
		t.eq(leituras, 1)
	end,
	["load que termina depois da desconexão não recria cache da sessão"] = function(t)
		local x
		local p = proposta(); p.nome = nil
		local store = {
			load = function()
				x.conectado = false
				return { nome = "Ária", construcao = p, habilidadesCompradas = {} }, 1, nil
			end,
		}
		x = contexto(nil, nil, store)
		local carregou = x.api.carregar(A)
		t.eq(carregou, false)
		t.eq(x.api.consultar(A), nil)
		t.eq(x.api.estadoCarga(A), nil)
	end,
	["combate iniciado durante save invalida cache antigo"] = function(t)
		local x
		local store = {
			load = function() return nil, 0, nil end,
			save = function() x.combate = true; return "ok", 1 end,
		}
		x = contexto(nil, nil, store)
		x.api.carregar(A)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), "O combate começou durante o salvamento. Saia e entre novamente para carregar a ficha atualizada.")
		t.eq(x.api.consultar(A), nil)
		t.eq(x.api.estadoCarga(A), "erro")
	end,
	["recusa tipos profundidade tamanho e jogador desconectado antes do cálculo"] = function(t)
		local ciclo = {}; ciclo.self = ciclo
		local enorme = {}
		for i = 1, 1000 do enorme[i] = "x" end
		for _, valor in { { x = function() end }, { x = { y = {} } }, ciclo,
			{ x = string.rep("x", 161) }, enorme, { x = math.huge }, { x = 0 / 0 } } do
			local x = contexto()
			local p = proposta()
			p.treeSkillChoiceIds = valor
			t.ok(x.handlers.personagemPessoalCriar(A, p))
			t.eq(x.calculos, 0)
		end
		local x = contexto()
		x.conectado = false
		t.ok(x.handlers.personagemPessoalCriar(A, proposta()))
		t.ok(x.handlers.personagemPessoalConsultar(A, {}))
		t.eq(x.calculos, 0)
		t.eq(#x.envios, 0)
	end,
	["recusa nome vazio longo ou filtro indisponivel sem substituir ficha"] = function(t)
		local x = contexto()
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		x.instante = 1
		local p = proposta(); p.nome = "   "
		t.ok(x.handlers.personagemPessoalCriar(A, p))
		x.instante = 2
		p = proposta(); p.nome = string.rep("A", 33)
		t.ok(x.handlers.personagemPessoalCriar(A, p))
		t.eq(x.filtros, 1)
		t.eq(#x.envios, 1)
		local y = contexto(nil, function() error("falha interna do filtro") end)
		t.eq(y.handlers.personagemPessoalCriar(A, proposta()), "Não foi possível verificar o nome. Tente novamente.")
		t.eq(y.calculos, 0)
	end,
	["pagamento de encontro persiste uma vez e replay nao duplica ouro"] = function(t)
		local store = storePerfilFake()
		local x = contexto(nil, nil, store)
		t.eq(x.api.carregar(A), true)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		local pago, total = x.api.recompensarEncontro(A, "enc-N6", 9)
		t.eq(pago, true); t.eq(total, 9)
		local replay, totalReplay = x.api.recompensarEncontro(A, "enc-N6", 9)
		t.eq(replay, true); t.eq(totalReplay, 9); t.eq(x.api.consultar(A).ouro, 9)
		t.eq(store.gravacoes, 2)
	end,
	["compra e venda atualizam ouro e inventario pessoal persistido"] = function(t)
		local store = storePerfilFake()
		local x = contexto(nil, nil, store)
		t.eq(x.api.carregar(A), true)
		t.eq(x.handlers.personagemPessoalCriar(A, proposta()), nil)
		x.api.recompensarEncontro(A, "enc-loja", 40)
		local comprado, saldo = x.api.comprarLoja(A, "item/pocao_menor_cura", "loja:teste-pocao")
		t.eq(comprado, true); t.eq(saldo, 25)
		local perfil = x.api.consultar(A)
		local pocao
		for _, item in ipairs(perfil.inventarioInicial) do if item.sourceLocalId == "loja:teste-pocao" then pocao = item end end
		t.ok(pocao ~= nil); t.eq(pocao.name, "Poção Menor de Cura")
		t.eq(pocao.description, "Cura 1d8 + 2 PV. Beber ou dar a um aliado adjacente é Usar Item (1 Ação). Poção não é magia: a Ferida Fresca não a dobra, e nenhuma poção apaga Ferimento Crítico.")
		local segundo = contexto(nil, nil, store)
		t.eq(segundo.api.carregar(A), true)
		local relida = segundo.api.consultar(A)
		local preservada = false
		for _, item in ipairs(relida.inventarioInicial) do if item.sourceLocalId == "loja:teste-pocao" then preservada = true end end
		t.eq(preservada, true)
		local vendeu, recebido = segundo.api.venderLoja(A, "loja:teste-pocao", { pocao = true })
		t.eq(vendeu, true); t.eq(recebido, 7); t.eq(segundo.api.consultar(A).ouro, 32)
		t.eq(#segundo.api.consultar(A).inventarioLoja, 0)
	end,
}
