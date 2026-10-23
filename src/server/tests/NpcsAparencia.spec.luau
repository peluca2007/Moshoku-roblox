local Shared = game:GetService("ReplicatedStorage").Shared
local Npcs = require(Shared.Mundo.NpcsDados)
local Treinadores = require(Shared.Mundo.TreinadoresAparenciaDados)
local Aparencia = require(Shared.Aparencia.Aparencia)
local Catalogo = require(Shared.Aparencia.Catalogo)

local function idsUnicos(t, label)
	local vistos = {}
	for _, npc in t do
		assert(not vistos[npc.id], label .. " ID duplicado: " .. npc.id)
		vistos[npc.id] = true
	end
end

return {
	["NPCs têm raça, aparência A1 válida, identidade facial e pose fixas"] = function(t)
		local esperados = {
		taverneira = { "race/humano", "acolher", "OlhoFeliz", "BocaSorriso" },
		ferreiro = { "race/anao", "forjar", "OlhoQuadrado", "BocaReta" },
		["mestre-dojo"] = { "race/humano", "cruzados", "OlhoRetangular", "BocaReta" },
		}
		idsUnicos(Npcs.LISTA, "NPC")
		t.eq(#Npcs.LISTA, 3)
		for _, npc in Npcs.LISTA do
			local e = esperados[npc.id]
			t.ok(e, npc.id)
			t.eq(npc.raceId, e[1]); t.eq(npc.pose, e[2])
			t.eq(npc.aparencia.rosto.olhos, e[3]); t.eq(npc.aparencia.rosto.boca, e[4])
			t.ok(Aparencia.validar(npc.aparencia, npc.raceId, {}), npc.id .. " inválido")
		end
		local torr = Npcs.LISTA[2]
		t.eq(torr.aparencia.barba, "BarbaLonga1")
		t.eq(torr.aparencia.roupas.corpo, "RoupaTunica1")
		t.eq(torr.aparencia.roupas.cintura, "RoupaCinto1")
		local brisa = Npcs.LISTA[1].aparencia.roupas
		local hanzo = Npcs.LISTA[3].aparencia.roupas
		t.eq(brisa.corpo, "RoupaTunica1"); t.eq(brisa.cintura, "RoupaCinto1")
		t.eq(hanzo.corpo, "RoupaTunica1"); t.eq(hanzo.cintura, "RoupaCinto1")
	end,
	["perfis por árvore validam, são únicos e não embutem trajes raros"] = function(t)
		local ids = {}
		for arvore, perfil in Treinadores.POR_ARVORE do
			t.ok(not ids[arvore], arvore .. " duplicada"); ids[arvore] = true
			t.ok(perfil.raceId and perfil.pose and perfil.aparencia, arvore .. " contrato incompleto")
			t.ok(Aparencia.validar(perfil.aparencia, perfil.raceId, {}), arvore .. " inválida")
			for _, id in perfil.aparencia.roupas do
				t.eq(Catalogo.PECAS[id].raridade, "basica", arvore .. " contém traje raro")
			end
		end
		t.eq(ids["furtividade-e-armadilhas"], true); t.eq(ids.agua, true); t.eq((function() local n=0; for _ in ids do n+=1 end; return n end)(), 2)
		local mestra = Treinadores.POR_ARVORE.agua.aparencia
		t.eq(Treinadores.POR_ARVORE.agua.pose, "canalizar")
		t.eq(mestra.cabelo, "CabeloTrancado1")
		t.eq(mestra.roupas.cabeca, nil)
		for arvore, traje in Treinadores.TRAJES do
			local n = 0
			for _, id in traje do
				n += 1
				t.ok(Catalogo.PECAS[id], arvore .. " peça ausente: " .. id)
				t.eq(Catalogo.PECAS[id].raridade, "rara", arvore .. " peça não é traje raro")
			end
			t.eq(n, 4, arvore .. " precisa de quatro peças de traje")
			t.ok(Treinadores.POR_ARVORE[arvore], arvore .. " sem perfil")
		end
		t.eq(Treinadores.TRAJES["furtividade-e-armadilhas"][1], "LadinoCapuz")
		t.eq(Treinadores.TRAJES.agua[1], "MestraTiara")
	end,
}
