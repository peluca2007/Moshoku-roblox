local M = require(game:GetService("ReplicatedStorage").Shared.Regras.Missao)
local Dados = require(game:GetService("ReplicatedStorage").Shared.Mundo.MissoesDados)
local Zonas = require(game:GetService("ReplicatedStorage").Shared.EncontrosPorZona)

local cacada = {
	id = "cacada-do-bosque", nome = "Caçada no Bosque", npc = "taverneira", texto = "t",
	objetivo = { tipo = "vencer-encontro", encontroId = "region/encounter/forest", quantidade = 2 },
	recompensa = { ouro = 30 },
}
local sombria = {
	id = "floresta-sombria", nome = "Sombra", npc = "taverneira", texto = "t",
	objetivo = { tipo = "vencer-encontro", encontroId = "region/encounter/dark-forest", quantidade = 1 },
	recompensa = { ouro = 100 },
}
local defs = { [cacada.id] = cacada, [sombria.id] = sombria }

return {
	["aceitar cria estado novo, uma vez so, sem alterar o original"] = function(t)
		local inicial = M.novoEstado()
		local e = M.aceitar(inicial, cacada)
		t.eq(e[cacada.id].estado, "aceita")
		t.eq(e[cacada.id].progresso, 0)
		t.eq(inicial[cacada.id], nil)
		local de, motivo = M.aceitar(e, cacada)
		t.eq(de, nil)
		t.eq(motivo, "Você já aceitou esta missão.")
		t.eq(M.situacao(inicial, cacada), "disponivel")
		t.eq(M.situacao(e, cacada), "aceita")
	end,
	["progresso conta so o encontro certo e cumpre ao atingir a quantidade"] = function(t)
		local e = M.aceitar(M.aceitar(M.novoEstado(), cacada), sombria)
		local e1, c1 = M.registrar(e, defs, "region/encounter/forest")
		t.eq(e1[cacada.id].progresso, 1)
		t.eq(#c1, 0)
		t.eq(e1[sombria.id].progresso, 0)
		local e2, c2 = M.registrar(e1, defs, "region/encounter/forest")
		t.eq(e2[cacada.id].estado, "cumprida")
		t.eq(c2[1], cacada.id)
		-- Depois de cumprida, mais vitórias não contam nem repetem o aviso.
		local e3, c3 = M.registrar(e2, defs, "region/encounter/forest")
		t.eq(e3[cacada.id].progresso, 2)
		t.eq(#c3, 0)
		local e4 = M.registrar(e, defs, "region/encounter/clearing")
		t.eq(e4[cacada.id].progresso, 0)
	end,
	["entregar paga uma vez e so se cumprida"] = function(t)
		local e = M.aceitar(M.novoEstado(), sombria)
		local nao, _, motivo = M.entregar(e, sombria)
		t.eq(nao, nil)
		t.eq(motivo, "A missão ainda não foi cumprida.")
		local cumprida = M.registrar(e, defs, "region/encounter/dark-forest")
		local entregue, premio = M.entregar(cumprida, sombria)
		t.eq(premio.ouro, 100)
		t.eq(entregue[sombria.id].estado, "entregue")
		t.eq(cumprida[sombria.id].estado, "cumprida")
		local de, _, m2 = M.entregar(entregue, sombria)
		t.eq(de, nil)
		t.eq(m2, "Missão já entregue.")
		local _, _, m3 = M.entregar(M.novoEstado(), sombria)
		t.eq(m3, "Você não aceitou esta missão.")
	end,
	["limite de missoes ativas e validacao de dados"] = function(t)
		local e = M.novoEstado()
		for i = 1, M.MAX_ATIVAS do
			local m = { id = "m" .. i, nome = "n", npc = "x", texto = "t",
				objetivo = { tipo = "vencer-encontro", encontroId = "e", quantidade = 1 }, recompensa = { ouro = 1 } }
			e = M.aceitar(e, m)
		end
		local de, motivo = M.aceitar(e, cacada)
		t.eq(de, nil)
		t.ok(string.find(motivo, "demais") ~= nil)
		t.eq(M.definicaoValida(cacada), true)
		t.eq(M.definicaoValida({ id = "x" }), false)
		t.eq(M.definicaoValida({ id = "x", nome = "n", npc = "n", objetivo = { tipo = "matar", encontroId = "e", quantidade = 1 }, recompensa = { ouro = 1 } }), false)
		t.eq(M.estadoValido({ a = { estado = "x", progresso = 0 } }), false)
		t.eq(M.estadoValido({ a = { estado = "aceita", progresso = -1 } }), false)
		t.eq(M.estadoValido({ a = { estado = "aceita", progresso = 0 } }, defs), false)
		t.eq(M.estadoValido(e), true)
		t.eq(M.registrar(nil, defs, "e"), nil)
	end,
	["missoes da vila sao validas e apontam para encontros e npcs reais"] = function(t)
		local ids = {}
		for _, m in ipairs(Dados.LISTA) do
			t.ok(M.definicaoValida(m), m.id)
			t.eq(ids[m.id], nil, "duplicada " .. m.id)
			ids[m.id] = true
			t.ok(Zonas.consultar(m.objetivo.encontroId) ~= nil, m.id .. " encontro desconhecido")
			t.ok(#m.texto <= 220, m.id .. " texto longo")
		end
		t.eq(Dados.porId()["cacada-do-bosque"].recompensa.ouro, 30)
	end,
}
