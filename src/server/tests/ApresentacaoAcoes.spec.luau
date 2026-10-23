local A = require(game:GetService("ReplicatedStorage").Shared.ApresentacaoAcoes)
return {
	["golpes e perigos separados de cura e apoio"] = function(t)
		t.eq(A.grupo({ tipo = "ataque" }), "Golpes")
		t.eq(A.grupo({ tipo = "zona", danoAoAtravessar = { "3d6" } }), "Golpes")
		t.eq(A.grupo({ tipo = "cura" }), "Apoio")
		t.eq(A.grupo({ tipo = "utilidade" }), "Apoio")
		t.eq(A.grupo({ tipo = "ataque" }, "passiva"), "Consulta")
	end,
	["sem acoes ainda permite cartas gratuitas"] = function(t)
		local token = { id = "a", pv = 10, mana = 3, pt = 2 }
		local jogo = { tokenId = "a", total = 3, usadas = 3 }
		t.eq(A.motivo({ acoes = 0 }, nil, token, jogo, "gratis"), nil)
		t.eq(A.motivo({ acoes = 1 }, nil, token, jogo, "golpe"), "Sem Ações")
	end,
	["recursos e uso por turno geram motivo sem mutar dados"] = function(t)
		local token = { id = "a", pv = 10, mana = 3, pt = 2 }
		local jogo = { tokenId = "a", total = 3, usadas = 1, usos = { "marca" } }
		t.eq(A.motivo({ pm = 4 }, nil, token, jogo, "x"), "Sem PM")
		t.eq(A.motivo({ pt = 3 }, nil, token, jogo, "x"), "Sem PT")
		t.eq(A.motivo({ umaVezPorTurno = true }, nil, token, jogo, "marca"), "Já usada neste turno")
		t.eq(A.motivo({ pm = 3, pt = 2, acoes = 2 }, nil, token, jogo, "x"), nil)
		t.eq(token.mana, 3); t.eq(jogo.usadas, 1)
	end,
	["contagem de outra ficha nao bloqueia a atual e caido nao age"] = function(t)
		local token = { id = "a", pv = 10 }
		t.eq(A.motivo({ acoes = 1 }, nil, token, { tokenId = "b", total = 0, usadas = 0 }, "x"), nil)
		token.derrotado = true
		t.eq(A.motivo({ acoes = 0 }, nil, token, nil, "x"), "0 PV • precisa de cura")
	end,
}
