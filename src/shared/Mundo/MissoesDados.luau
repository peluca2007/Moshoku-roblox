-- Missões da vila (dados puros; regra em shared/Regras/Missao). Os encontros citados são os
-- marcos reais de shared/EncontrosPorZona; as recompensas em PO são provisórias até a economia
-- (N6) ser calibrada com o Apêndice G.
local MissoesDados = {}

MissoesDados.LISTA = {
	{
		id = "cacada-do-bosque", nome = "Caçada no Bosque", npc = "taverneira",
		texto = "Goblins e lobos atacam quem passa pelo bosque ao norte. Vença dois encontros por lá e volte aqui.",
		objetivo = { tipo = "vencer-encontro", encontroId = "region/encounter/forest", quantidade = 2 },
		recompensa = { ouro = 30 },
	},
	{
		id = "sombra-da-floresta", nome = "Sombra da Floresta", npc = "taverneira",
		texto = "Há algo perigoso na Floresta Sombria, ao sul da vila. Derrote o que ronda a clareira e volte vivo.",
		objetivo = { tipo = "vencer-encontro", encontroId = "region/encounter/dark-forest", quantidade = 1 },
		recompensa = { ouro = 80 },
	},
}

function MissoesDados.porId()
	local mapa = {}
	for _, m in ipairs(MissoesDados.LISTA) do mapa[m.id] = m end
	return mapa
end

return MissoesDados
