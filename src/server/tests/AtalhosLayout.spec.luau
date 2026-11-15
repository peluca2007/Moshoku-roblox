local Shared = game:GetService("ReplicatedStorage").Shared
local L = require(Shared.Regras.AtalhosLayout)

local function sobrepoe(a, b)
	return a.x < b.x + b.largura and b.x < a.x + a.largura and a.y < b.y + b.altura and b.y < a.y + a.altura
end

return {
	["a barra segue a ordem MENU, DIÁRIO, ÁRVORES, CONTA, AJUDA, com os nomes antigos"] = function(t)
		-- chegada fora de ordem e com os rótulos que as views usam hoje ("?" = AJUDA, RUN = DIÁRIO)
		local rotulos = { "?", "CONTA", "MENU", "ÁRVORES", "DIÁRIO" }
		local caixas = L.caixas(rotulos, 1280)
		local vistos = {}
		for _, c in caixas do table.insert(vistos, L.ALIAS[c.rotulo] or c.rotulo) end
		t.eq(table.concat(vistos, ","), "MENU,DIÁRIO,ÁRVORES,CONTA,AJUDA")
		t.eq(L.posicao("RUN"), L.posicao("DIÁRIO"))
		-- desconhecido (ex.: VIAGEM) vai para o fim, sem mexer nos demais
		local com = L.caixas({ "VIAGEM", "AJUDA", "MENU" }, 1280)
		t.eq(com[#com].rotulo, "VIAGEM")
		t.eq(com[1].rotulo, "MENU")
	end,
	["botões do mesmo tamanho, sem sobreposição e dentro da tela em qualquer largura >= 800"] = function(t)
		local rotulos = { "MENU", "DIÁRIO", "ÁRVORES", "CONTA", "AJUDA" }
		for largura = 800, 2560, 40 do
			local caixas, m = L.caixas(rotulos, largura)
			t.eq(#caixas, 5)
			for i, a in caixas do
				t.eq(a.largura, caixas[1].largura, "tamanho diferente em " .. largura)
				t.eq(a.altura, caixas[1].altura)
				t.ok(a.largura >= L.MIN_LARGURA and a.altura >= L.MIN_LARGURA, "abaixo do toque mínimo")
				for j = i + 1, #caixas do
					t.ok(not sobrepoe(a, caixas[j]), ("%s x %s sobrepostos a %d px"):format(a.rotulo, caixas[j].rotulo, largura))
				end
			end
			-- a barra inteira (com a margem da borda) cabe na tela
			t.ok(m.barra + 2 * L.MARGEM <= largura, "barra maior que a tela em " .. largura)
			local ultimo = caixas[#caixas]
			t.ok(ultimo.x + ultimo.largura + L.PADDING <= m.barra, "botão fora da moldura")
		end
	end,
	["a barra é menor que a antiga (5 botões em menos de 400 px, 46 de altura)"] = function(t)
		local m = L.medidas(5, 1920)
		t.ok(m.barra < 400)
		t.ok(m.altura <= 48)
		t.eq(m.largura, L.LARGURA)
	end,
	["tela estreita encolhe os botões até o toque mínimo sem sobrepor"] = function(t)
		local rotulos = { "MENU", "DIÁRIO", "ÁRVORES", "CONTA", "AJUDA" }
		for _, largura in { 360, 375, 667 } do
			local caixas, m = L.caixas(rotulos, largura)
			t.ok(m.largura >= L.MIN_LARGURA)
			t.ok(m.barra + 2 * L.MARGEM <= largura, "estourou a tela de " .. largura)
			for i = 1, #caixas - 1 do t.ok(not sobrepoe(caixas[i], caixas[i + 1])) end
		end
		t.ok(L.medidas(5, 360).largura < L.LARGURA)
	end,
	["menos botões visíveis reduzem a barra; zero botões não ocupa nada"] = function(t)
		t.ok(L.medidas(3, 1280).barra < L.medidas(5, 1280).barra)
		t.eq(L.medidas(0, 1280).barra, 0)
		t.eq(#L.caixas({}, 1280), 0)
	end,
	["empate na ordem mantém a ordem de chegada"] = function(t)
		local ordem = L.ordem({ "X", "Y", "MENU", "Z" })
		t.eq(table.concat(ordem, ","), "3,1,2,4")
	end,
}
