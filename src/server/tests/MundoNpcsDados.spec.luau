local Shared = game:GetService("ReplicatedStorage").Shared
local N = require(Shared.Mundo.NpcsDados)
local L = require(Shared.Mundo.VilaLayout)

return {
	["dados dos npcs da vila sao consistentes"] = function(t)
		local problemas = N.validar()
		t.eq(#problemas, 0, table.concat(problemas, "; "))
	end,
	["cada npc fica entre a porta e a praca, olhando para ela"] = function(t)
		for _, npc in ipairs(N.LISTA) do
			local p = N.posicao(npc)
			t.ok(p ~= nil, npc.id)
			local porta
			for _, e in ipairs(L.EDIFICIOS) do
				if e.id == npc.edificio then porta = L.porta(e) end
			end
			local d = math.sqrt((p.x - porta.x) ^ 2 + (p.z - porta.z) ^ 2)
			t.ok(math.abs(d - N.DISTANCIA_PORTA) < 0.01, npc.id .. " distancia " .. d)
			t.ok(math.abs(p.olharX ^ 2 + p.olharZ ^ 2 - 1) < 0.001)
		end
	end,
	["fala rotaciona pelo contador do jogador"] = function(t)
		local npc = N.LISTA[1]
		t.eq(N.fala(npc, 1), npc.falas[1])
		t.eq(N.fala(npc, 2), npc.falas[2])
		t.eq(N.fala(npc, #npc.falas + 1), npc.falas[1])
		t.eq(N.fala(npc, 0), npc.falas[1])
	end,
}
