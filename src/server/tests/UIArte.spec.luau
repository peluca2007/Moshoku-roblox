local UIArte = require(game:GetService("ReplicatedStorage").Shared.UIArte)

return {
	["pecas do kit tem imagem e corte dentro do png"] = function(t)
		local n = 0
		for nome, p in UIArte.PECAS do
			n += 1
			t.ok(string.match(p.imagem, "^rbxassetid://%d+$") ~= nil, nome)
			t.ok(p.largura > 0 and p.altura > 0, nome)
			if p.corte then
				local x0, y0, x1, y1 = table.unpack(p.corte)
				t.ok(x0 > 0 and y0 > 0 and x1 < p.largura and y1 < p.altura and x0 < x1 and y0 < y1, nome)
			end
		end
		t.ok(n >= 9)
		for _, nome in { "painel", "botao", "botao_principal", "barra_fundo", "barra_cheia", "espaco" } do
			t.ok(UIArte.peca(nome).corte ~= nil, nome .. " precisa de 9-slice")
		end
	end,
	["escala das bordas cabe na altura e nao passa da escala de desenho"] = function(t)
		t.eq(UIArte.escalaPara("botao", 200), UIArte.ESCALA)
		local e = UIArte.escalaPara("barra_fundo", 12)
		local p = UIArte.peca("barra_fundo")
		t.ok((p.corte[2] + p.altura - p.corte[4]) * e <= 12 + 1e-9)
		t.eq(UIArte.escalaPara("aro", 10), UIArte.ESCALA, "sem corte usa a escala de desenho")
		t.eq(UIArte.escalaPara("inexistente", 10), UIArte.ESCALA)
	end,
}
