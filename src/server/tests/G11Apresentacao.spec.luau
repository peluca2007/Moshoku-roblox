local M = require(game:GetService("ReplicatedStorage").Shared.MiraTatica)
local R = require(game:GetService("ReplicatedStorage").Shared.ApresentacaoResultado)
local function snap()
	return { tokens = { { id = "a", name = "Aria", x = 2, z = 2 }, { id = "b", name = "Bardo", x = 5, z = 5 } }, map = { terrain = {} }, jogo = { muros = {} } }
end
local function mira()
	return { tokenId = "a", habilidadeId = "mesa/ataque-basico", modo = "ficha", alcanceCasas = 3 }
end
return {
	["previa inclui diagonal no limite e rejeita fora do tabuleiro"] = function(t)
		local s, m = snap(), mira()
		t.eq(M.avaliar(s, m, 5, 5).motivo, nil)
		t.eq(M.avaliar(s, m, 5, 5).distancia, 3)
		t.eq(M.avaliar(s, m, 6, 5).motivo, "Fora do alcance")
		t.eq(M.avaliar(s, m, 21, 5), nil)
	end,
	["previa nao inventa ficha ausente e cura permite mirar a si"] = function(t)
		local s, m = snap(), mira()
		t.eq(M.avaliar(s, m, 3, 3).alvo, nil)
		t.eq(M.avaliar(s, m, 2, 2).motivo, "Escolha outra ficha")
		m.tipo = "cura"
		t.eq(M.avaliar(s, m, 2, 2).motivo, nil)
		t.eq(#s.tokens, 2)
	end,
	["paredes e muros visiveis bloqueiam previa sem confundir movimento"] = function(t)
		local s, m = snap(), mira()
		s.map.terrain["3,3"] = "parede"
		t.eq(M.avaliar(s, m, 5, 5).motivo, "Visão bloqueada")
		s.map.terrain = {}
		s.jogo.muros = { { bloqueiaVisao = true, casas = { { 3, 3 } } } }
		t.eq(M.avaliar(s, m, 5, 5).motivo, "Visão bloqueada")
		m.tipo, m.modo = "mover", "casa"
		t.eq(M.avaliar(s, m, 5, 5).motivo, nil)
	end,
	["lista destaca apenas alvos presentes e nao altera escolha"] = function(t)
		local s, m = snap(), mira()
		m.modo, m.alvoIds = "lista", { "b", "id-ausente" }
		t.eq(M.avaliar(s, m, 5, 5).selecionado, true)
		t.eq(M.avaliar(s, m, 3, 3).selecionado, false)
		t.eq(#m.alvoIds, 2)
	end,
	["barreira e alvo valido e pode interceptar ataque fisico"] = function(t)
		local s, m = snap(), mira()
		s.jogo.muros = {{pv=10,bloqueiaVisao=true,casas={{3,3}}}}
		t.eq(M.avaliar(s,m,3,3).motivo,nil)
		t.eq(M.avaliar(s,m,3,3).barreira.pv,10)
		m.habilidadeId="mesa/ataque-a-distancia"
		t.eq(M.avaliar(s,m,5,5).motivo,nil)
	end,
	["resultado distingue grupo duelo empate e evento desconhecido"] = function(t)
		t.eq(R.resumir({ resultado = "vitoria" }).titulo, "VITÓRIA")
		t.eq(R.resumir({ resultado = "derrota" }).cor, "PERIGO")
		t.eq(R.resumir({ resultado = "duelo", modo = "duelo", vencedor = "Equipe 2" }).detalhe, "Equipe 2 venceu!")
		t.eq(R.resumir({ resultado = "empate", modo = "duelo" }).detalhe, "Empate • ninguém ficou de pé.")
		t.eq(R.resumir({ resultado = "inventado" }), nil)
		t.eq(R.resumir(nil), nil)
	end,
}
