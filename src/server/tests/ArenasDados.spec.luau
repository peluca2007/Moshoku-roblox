local Arenas = require(game:GetService("ReplicatedStorage").Shared.Mundo.ArenasDados)
local EncontrosPorZona = require(game:GetService("ReplicatedStorage").Shared.EncontrosPorZona)

-- O tabuleiro ocupa ±50 studs em x e z a partir do centro (MesaProtocol.BOARD: 20 casas de 5 studs).
local MEIO = 50

return {
	["cada patrulha cai na arena da sua regiao"] = function(t)
		local esperado = {
			["ratos-celeiro"] = "cidade", ["ratos-horta"] = "cidade", ["goblin-campo"] = "campo",
			["lobos-estrada"] = "floresta", ["lobos-trilha"] = "floresta", ["aranhas-floresta"] = "floresta",
			["urso-floresta"] = "floresta", ["bandidos-passagem"] = "campo",
			["goblins-ruinas"] = "ruinas", ["golem-ruinas"] = "ruinas",
		}
		for _, patrulha in EncontrosPorZona.patrulhas() do
			t.eq(Arenas.daPatrulha(patrulha), esperado[patrulha.id], patrulha.id)
		end
		t.eq(Arenas.daPatrulha({ arena = "ruinas", zona = "region/clareira-inicial" }), "ruinas", "arena explícita vence a zona")
		t.eq(Arenas.daPatrulha({ arena = "lua", zona = "region/clareira-inicial" }), "cidade", "arena desconhecida é ignorada")
		t.eq(Arenas.daPatrulha(nil), nil)
		t.eq(Arenas.daZona("region/outra"), nil)
	end,
	["toda arena tem piso, ponto do mapa e cenario fora da grade"] = function(t)
		t.eq(#Arenas.ids(), 4)
		for _, id in Arenas.ids() do
			local arena = Arenas.layout(id)
			t.ok(arena.piso and arena.chao, id .. " piso")
			local ponto = Arenas.pontoDoMundo(id)
			t.ok(type(ponto.x) == "number" and type(ponto.z) == "number", id .. " ponto")
			t.ok(#arena.props >= 15, id .. " cenário cheio")
			for _, p in arena.props do
				t.ok(math.abs(p[2]) > MEIO + 4 or math.abs(p[3]) > MEIO + 4, id .. ": " .. p[1] .. " fora da grade")
			end
			for _, m in arena.moradores do
				t.ok(math.abs(m[1]) > MEIO + 2 or math.abs(m[2]) > MEIO + 2, id .. ": morador fora da grade")
			end
		end
		t.eq(Arenas.pontoDoMundo(nil), nil)
		t.ok(#Arenas.layout("cidade").moradores >= 8, "torcida na cidade")
	end,
}
