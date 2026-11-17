-- ANIM3: fila de apresentação pura (segura PV/número/queda até o marco `impacto`) e marcos dos clipes de golpe.
local Shared = game:GetService("ReplicatedStorage").Shared
local Fila = require(Shared.Animacoes.FilaApresentacao)
local Catalogo = require(Shared.Animacoes.Catalogo)

return {
	["HAB8: soltar no contato vence antes da estimativa; teto próprio segura magia lenta"] = function(t)
		local f = Fila.nova()
		f:observar("a", 10, 0)
		f:reter("a", 0, 3.0, nil, 6) -- magia lenta: estimativa 3 s, teto pedido 6 (fica em TETO_COM_SINAL)
		t.ok(f:retido("a", 2.5), "passa do teto padrão de 1,6 s")
		t.ok(f:soltar("a", 2.0), "o contato aconteceu")
		t.ok(not f:retido("a", 2.0))
		t.eq(#f:expirados(2.0), 1)
		t.ok(not f:soltar("a", 2.1), "sem retenção, soltar não faz nada")
		f:observar("b", 8, 0)
		f:reter("b", 0, 9, nil, 9)
		t.ok(not f:retido("b", Fila.TETO_COM_SINAL), "o teto com sinal também tem limite")
	end,
	["atraso do impacto sai do marco e da velocidade, com padrão"] = function(t)
		t.eq(Fila.atrasoDoImpacto({ marcos = { impacto = 0.6 } }, 1), 0.6)
		t.eq(Fila.atrasoDoImpacto({ marcos = { impacto = 0.6 } }, 2), 0.3)
		t.eq(Fila.atrasoDoImpacto({ marcos = {} }, 1), Fila.IMPACTO_PADRAO)
		t.eq(Fila.atrasoDoImpacto(nil, nil, 0.7), 0.7)
		t.eq(Fila.atrasoDoImpacto({ marcos = { impacto = 0.5 } }, -3), 0.5, "velocidade inválida vale 1")
	end,
	["segura o PV antigo até o impacto e depois mostra o real"] = function(t)
		local f = Fila.nova()
		f:observar("a", 10, 0)
		f:observar("a", 4, 5) -- snapshot já veio com o PV novo
		local r = f:reter("a", 5, 0.5)
		t.eq(r.pvAntes, 10, "usa o valor anterior recente")
		t.eq(f:pvExibido("a", 4, 5.2), 10)
		t.ok(f:retido("a", 5.2))
		t.eq(f:pvExibido("a", 4, 5.5), 4, "no marco já mostra o real")
		local venc = f:expirados(5.6)
		t.eq(#venc, 1)
		t.eq(venc[1].pvAntes, 10)
		t.eq(venc[1].pvReal, 4)
		t.eq(#f:expirados(9), 0, "só solta uma vez")
	end,
	["recibo antes do snapshot: o atual ainda é o PV de antes"] = function(t)
		local f = Fila.nova()
		f:observar("a", 10, 0)
		f:reter("a", 3, 0.4)
		f:observar("a", 6, 3.05)
		t.eq(f:pvExibido("a", 6, 3.1), 10)
		t.eq(f:pvExibido("a", 6, 3.5), 6)
	end,
	["limite de segurança nunca esconde o PV por mais que o teto"] = function(t)
		local f = Fila.nova(1.0)
		f:observar("a", 10, 0)
		f:observar("a", 3, 1)
		f:reter("a", 1, 99)
		t.eq(f:pvExibido("a", 3, 1.9), 10)
		t.eq(f:pvExibido("a", 3, 2.0), 3)
	end,
	["visto troca pv e derrotado enquanto retido e devolve o mesmo token depois"] = function(t)
		local f = Fila.nova()
		f:observar("a", 5, 0)
		f:observar("a", 0, 1)
		f:reter("a", 1, 0.5)
		local token = { id = "a", pv = 0, derrotado = true, nome = "x" }
		local v = f:visto(token, 1.2)
		t.eq(v.pv, 5)
		t.eq(v.derrotado, false)
		t.eq(token.pv, 0, "o original não muda")
		t.ok(f:visto(token, 1.5) == token, "passado o prazo, o próprio token")
		t.ok(f:visto({ id = "z", pv = 1 }, 1.2).pv == 1)
	end,
	["carência segura uma queda de PV até o recibo e é trocada pelo prazo do impacto"] = function(t)
		local f = Fila.nova()
		f:observar("a", 10, 0, Fila.CARENCIA)
		f:observar("a", 7, 1, Fila.CARENCIA) -- snapshot antes do recibo
		t.eq(f:pvExibido("a", 7, 1.1), 10)
		f:reter("a", 1.1, 0.6)
		t.eq(f:pvExibido("a", 7, 1.5), 10, "passou da carência mas o impacto ainda não chegou")
		t.eq(f:pvExibido("a", 7, 1.71), 7)
		-- sem recibo, a carência expira sozinha
		local g = Fila.nova()
		g:observar("b", 10, 0, Fila.CARENCIA)
		g:observar("b", 8, 1, Fila.CARENCIA)
		t.eq(g:pvExibido("b", 8, 1 + Fila.CARENCIA + 0.01), 8)
	end,
	["clipes de golpe do personagem têm o marco que a fila usa"] = function(t)
		for _, nome in { "CorteLeve", "CortePesado", "Estocada" } do
			local atraso = Fila.atrasoDoImpacto(Catalogo.CLIPES[nome], 1, -1)
			t.ok(atraso > 0.2 and atraso < Catalogo.CLIPES[nome].duracao, nome .. " sem marco impacto plausível")
		end
		t.ok(Catalogo.CLIPES.DisparoArco.marcos.soltar ~= nil, "arco solta a flecha em `soltar`")
		t.ok(Catalogo.CLIPES.CortePesado.marcos.impacto > Catalogo.CLIPES.CorteLeve.marcos.impacto, "pesado demora mais")
	end,
}
