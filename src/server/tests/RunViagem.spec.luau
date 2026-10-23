local Shared = game:GetService("ReplicatedStorage").Shared
local V = require(Shared.Regras.RunViagem)
local Run = require(Shared.Regras.Run)
local Votacao = require(Shared.Regras.RunVotacao)

local function fixo(n) return { NextInteger = function(_, lo, hi) return math.clamp(n, lo, hi) end } end

local CATALOGO = {
	{ id = "mercador", tom = "bom", peso = 2, opcoes = { { id = "comprar", dias = 0.25 }, { id = "ignorar" } } },
	{ id = "ponte", tom = "neutro", peso = 2, regioes = { "floresta" }, opcoes = {
		{ id = "atravessar", tags = { "forca" }, dias = 0.5 }, { id = "contornar", dias = 1 } } },
	{ id = "bandidos", tom = "ruim", peso = 4, opcoes = { { id = "lutar", tags = { "confronto" } }, { id = "pagar" } } },
	{ id = "trilha-de-cavalos", tom = "bom", peso = 1, modo = "cavalo", opcoes = { { id = "seguir" } } },
}

local function ids(lista) local s = {} for _, id in lista do s[id] = true end return s end

return {
	["custo em dias: pe, cavalo, Explorador e entradas invalidas"] = function(t)
		t.eq(V.custoEmDias(2, "pe", false), 2)
		t.eq(V.custoEmDias(2, "cavalo", false), 1)
		t.eq(V.custoEmDias(2, "pe", true), 1.5) -- 2 * 0,75
		t.eq(V.custoEmDias(1, "cavalo", true), 0.5) -- 0,375 arredonda a 0,5 (múltiplo de 0,25)
		t.eq(V.custoEmDias(0, "pe", false), nil)
		t.eq(V.custoEmDias(1.5, "pe", false), nil)
		t.eq(V.custoEmDias(1, "voando", false), nil)
	end,
	["todo custo e multiplo de 0,25 e valido para Run.gastarDias"] = function(t)
		local run = Run.nova({ jogadores = { "a" }, objetivo = { id = "x", prazoDias = 30 } })
		for etapas = 1, 6 do
			for _, modo in { "pe", "cavalo" } do
				for _, ex in { true, false } do
					local dias = V.custoEmDias(etapas, modo, ex)
					t.ok(Run.gastarDias(run, dias) ~= nil, etapas .. modo .. tostring(ex))
				end
			end
		end
	end,
	["eventos: regiao e modo filtram; sem repetir"] = function(t)
		local a = V.sortearEventos(CATALOGO, "campo", 10, fixo(1), { modo = "pe" })
		local conjunto = ids(a)
		t.eq(conjunto["ponte"], nil) -- só na floresta
		t.eq(conjunto["trilha-de-cavalos"], nil) -- só a cavalo
		t.eq(#a, 2)
		local b = V.sortearEventos(CATALOGO, "floresta", 10, fixo(1), { modo = "cavalo" })
		t.eq(#b, 4)
		local vistos = ids(b)
		for _, id in b do t.ok(vistos[id], id) end
	end,
	["Explorador favorece eventos bons e reduz ruins"] = function(t)
		-- Alvo 1 cai no primeiro item da lista na ordem do catálogo; conferimos os pesos pelo total.
		-- Sem Explorador: mercador 2 + bandidos 4 = 6; com Explorador: 4 + 2 = 6 (ruim cai de 4 para 2, bom sobe de 2 para 4).
		local contagem = { sem = { mercador = 0, bandidos = 0 }, com = { mercador = 0, bandidos = 0 } }
		for alvo = 1, 6 do
			for chave, ex in { sem = false, com = true } do
				local r = V.sortearEventos(CATALOGO, "campo", 1, fixo(alvo), { modo = "pe", explorador = ex })
				contagem[chave][r[1]] += 1
			end
		end
		t.eq(contagem.sem.mercador, 2) t.eq(contagem.sem.bandidos, 4)
		t.eq(contagem.com.mercador, 4) t.eq(contagem.com.bandidos, 2)
	end,
	["catalogo invalido e recusado"] = function(t)
		t.eq((V.sortearEventos({ { id = "x", peso = 0 } }, "r", 1, fixo(1))), nil)
		t.eq((V.sortearEventos(nil, "r", 1, fixo(1))), nil)
		t.eq((V.sortearEventos(CATALOGO, 5, 1, fixo(1))), nil)
	end,
	["previa so existe com Explorador e arredonda a 5%"] = function(t)
		local c = { { id = "mestre-de-cura", chance = 99 }, { id = "ruinas", chance = 42 }, { id = "ladrao", chance = 42 } }
		t.eq(#V.previaDaRegiao(c, false), 0)
		local p = V.previaDaRegiao(c, true)
		t.eq(p[1].id, "mestre-de-cura") t.eq(p[1].chance, 100)
		t.eq(p[2].id, "ladrao") t.eq(p[2].chance, 40) -- empate ordena por id
		t.eq(p[3].id, "ruinas")
		t.eq(#V.previaDaRegiao({ { id = "x", chance = 150 }, 7 }, true), 0)
	end,
	["defeitos vetam opcoes por tag para quem os tem"] = function(t)
		local lutar = CATALOGO[3].opcoes[1]
		local v = V.vetadosNaOpcao(lutar, { ana = { "medroso" }, beto = { "zangado" }, caio = {} })
		t.eq(#v, 1) t.eq(v[1], "ana")
		t.eq(#V.vetadosNaOpcao(CATALOGO[3].opcoes[2], { ana = { "medroso" } }), 0)
		t.eq(#V.vetadosNaOpcao(nil, {}), 0)
	end,
	["fluxo: evento, votacao e aplicacao gastam o prazo e marcam a escolha"] = function(t)
		local run = Run.nova({ jogadores = { "ana", "beto" }, objetivo = { id = "x", prazoDias = 1 } })
		local evento = CATALOGO[2]
		local eleitores = { ana = { explorador = true }, beto = {} }
		local r = Votacao.resolver({ "atravessar", "contornar" }, { ana = "contornar", beto = "atravessar" }, eleitores, fixo(1))
		t.eq(r.vencedora, "contornar") -- Explorador pesa 2
		local nova, expirou = V.aplicarOpcao(run, evento, r.vencedora)
		t.eq(nova.dia, 1)
		t.eq(expirou, true) -- W1b: expira quando o relógio atinge o prazo
		t.eq(nova.objetivo.status, "expirado")
		t.eq(Run.temFlag(nova, "evento/ponte/contornar"), true)
		t.eq(run.dia, 0, "original alterado")
		local mais, venceu = V.aplicarOpcao(nova, evento, "atravessar")
		t.eq(mais.dia, 1.5)
		t.eq(venceu, false) -- já estava expirado; não sinaliza a transição duas vezes
		t.eq(mais.objetivo.status, "expirado")
		t.eq((V.aplicarOpcao(run, evento, "inexistente")), nil)
		t.eq((V.aplicarOpcao(run, nil, "x")), nil)
	end,
}
