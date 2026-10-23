local Arenas = require(game:GetService("ReplicatedStorage").Shared.Mundo.ArenasDados)

-- O tabuleiro ocupa ±50 studs em x e z a partir do centro (MesaProtocol.BOARD: 20 casas de 5 studs).
local MEIO = 50

return {
	["clareira da cidade usa a arena da cidade e outras zonas ficam com o livro"] = function(t)
		t.eq(Arenas.daZona("region/clareira-inicial"), "cidade")
		t.eq(Arenas.daZona("region/floresta-sombria"), nil)
		t.eq(Arenas.daZona(nil), nil)
		t.ok(Arenas.layout("cidade") ~= nil)
		t.eq(Arenas.layout("floresta"), nil)
	end,
	["cenario da cidade nunca invade o tabuleiro"] = function(t)
		local cidade = Arenas.layout("cidade")
		for _, p in cidade.props do
			t.ok(math.abs(p[2]) > MEIO + 4 or math.abs(p[3]) > MEIO + 4, "prop " .. p[1] .. " fora da grade")
		end
		for _, m in cidade.moradores do
			t.ok(math.abs(m[1]) > MEIO + 2 or math.abs(m[2]) > MEIO + 2, "morador fora da grade")
		end
		t.ok(#cidade.moradores >= 8, "torcida em volta")
	end,
}
