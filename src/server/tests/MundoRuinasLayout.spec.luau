local Shared = game:GetService("ReplicatedStorage").Shared
local R = require(Shared.Mundo.RuinasLayout)
local P = require(Shared.Mundo.PropsLayout)
local TerrenoLayout = require(Shared.Mundo.TerrenoLayout)

return {
	["W1a chegada a pe sem scatter bloqueando a passagem"] = function(t)
		local passagem = TerrenoLayout.PASSAGEM
		for _, p in ipairs(R.pecas()) do
			if p[3] == "arco" then continue end
			local ret = P.retangulo(p)
			local raio = math.sqrt(ret.sx^2 + ret.sz^2) / 2
			t.ok(passagem.distancia(ret.x, ret.z) > raio, "bloqueio na chegada: " .. p[3])
		end
	end,
	["layout das ruinas e consistente: dentro do solo, caminho livre, camara limpa"] = function(t)
		local problemas = R.validar()
		t.eq(TerrenoLayout.altura(R.CAMARA.x, R.CAMARA.z), 0)
		t.eq(TerrenoLayout.altura(R.NASCIMENTO.x, R.NASCIMENTO.z), 0)
		t.eq(#problemas, 0, table.concat(problemas, "; "))
	end,
	["a geracao e deterministica e traz arco, altar e vegetacao"] = function(t)
		local a, b = R.pecas(), R.pecas()
		t.eq(#a, #b)
		local contagem = {}
		for i, p in a do
			t.eq(p[1], b[i][1])
			t.eq(p[2], b[i][2])
			contagem[p[3]] = (contagem[p[3]] or 0) + 1
		end
		t.eq(contagem.arco, 1)
		t.eq(contagem.altar, 1)
		t.ok((contagem.coluna or 0) + (contagem.colunaquebrada or 0) >= 14, "poucas colunas")
		t.ok((contagem.arbusto or 0) >= 8, "pouca vegetacao")
	end,
	["toda familia citada existe com modelos e base positiva"] = function(t)
		for _, p in R.pecas() do
			local f = P.FAMILIAS[p[3]]
			t.ok(f ~= nil, tostring(p[3]))
			t.ok(#f.modelos >= 1 and f.base[1] > 0 and f.base[2] > 0)
		end
	end,
	["ruinas ficam longe da vila, da floresta e da sala (sem sobreposicao de mundo)"] = function(t)
		local s = R.SOLO
		t.ok(s.x - s.sx / 2 > 300, "perto demais da regiao inicial/sala")
		t.ok(s.z + s.sz / 2 <= -100 and s.z - s.sz / 2 >= -300)
	end,
}
