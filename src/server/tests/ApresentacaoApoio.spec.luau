local A = require(game:GetService("ReplicatedStorage").Shared.ApresentacaoApoio)
local function token(id, nome, dono, aliado, bardo)
	return { id = id, name = nome, ownerUserId = dono, aliadoSeu = aliado,
		apoio = { bardo = bardo, marcha = 0, pvTemp = 0, inspiracoesMax = 3, inspiracoesUsadas = 1, dadoInspiracao = "d6", beneficiados = {} } }
end
local function snap(tokens, ativo)
	return { you = { userId = 7 }, tokens = tokens, combat = { active = ativo ~= false } }
end
return {
	["ficha propria recebe apoio mesmo sem flag aliadoSeu"] = function(t)
		local b = token("b", "Bardo", 7, false, true)
		b.apoio.cancao, b.apoio.marcha, b.apoio.beneficiados = "marcha", 1, { "b" }
		local r = A.resumir(snap({ b }))
		t.eq(r.afetados, 1); t.ok(r.visivel)
		t.ok(string.find(r.texto, "Bardo: Marcha +1 casa", 1, true))
		t.ok(string.find(r.resumo, "Marcha • Inspiração d6: 2/3", 1, true))
	end,
	["beneficiados ausentes nao revelam ids e repetidos nao duplicam nomes"] = function(t)
		local b, a = token("b", "Bardo", 7, true, true), token("a", "Aria", 8, true, false)
		b.apoio.cancao, b.apoio.beneficiados = "marcha", { "ausente-secreto", "a", "a" }
		local r = A.resumir(snap({ b, a }))
		t.ok(not string.find(r.texto, "ausente-secreto", 1, true))
		t.ok(not string.find(r.texto, "Aria, Aria", 1, true))
		t.ok(string.find(r.texto, "+1 casa de movimento: Aria.", 1, true))
	end,
	["inimigo com apoio nao abre painel e fim de combate oculta"] = function(t)
		local e = token("e", "Inimigo", 9, false, true)
		e.apoio.inspiracao = "d8"
		t.eq(A.resumir(snap({ e })).visivel, false)
		local a = token("a", "Aria", 8, true, false)
		a.apoio.inspiracao, a.apoio.pvTemp = "d6", 5
		local r = A.resumir(snap({ e, a }))
		t.eq(r.afetados, 1); t.ok(r.visivel)
		t.ok(not string.find(r.texto, "Inimigo", 1, true))
		t.eq(A.resumir(snap({ a }, false)).visivel, false)
	end,
	["ordem do snapshot nao muda leitura nem modifica lista original"] = function(t)
		local a, b = token("a", "Aria", 7, true, true), token("b", "Bardo", 7, true, true)
		a.apoio.cancao, a.apoio.dissonancia, a.apoio.limiteDissonancia = "dissonancia", "1d6", 1
		local s = snap({ b, a })
		local r = A.resumir(s)
		t.eq(r.texto, A.resumir(snap({ a, b })).texto)
		t.eq(s.tokens[1], b)
		t.ok(string.find(r.resumo, "2 bardos • 1 canções ativas", 1, true))
		t.ok(string.find(r.texto, "1d6 sônico", 1, true))
	end,
	["sem cancoes ou usos ainda explica combinacoes e ausencia de apoio"] = function(t)
		local b = token("b", "Bardo", 7, false, true)
		b.apoio.inspiracoesUsadas = 6
		local r = A.resumir(snap({ b }))
		t.ok(string.find(r.resumo, "Sem canção • Inspiração d6: 0/3", 1, true))
		t.ok(string.find(r.texto, "Nenhuma ficha visível recebe bônus agora.", 1, true))
		t.ok(string.find(r.texto, "Trocar substitui a anterior", 1, true))
	end,
}
