-- IMP1: curvas puras do impacto (peso da câmera, hit-stop, tremor, enquadramento).
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.ImpactoCurvas)

return {
	["peso da câmera: 0 antes, sobe até o impacto, segura e volta"] = function(t)
		t.eq(C.peso(0, 0.8), 0)
		t.eq(C.peso(0.2, 1.6), 0, "ainda fora da janela de antecipação")
		local meio = C.peso(0.55, 0.8)
		t.ok(meio > 0 and meio < 1, "sobe suave")
		t.eq(C.peso(0.8, 0.8), 1)
		t.eq(C.peso(0.8 + C.SEGURA, 0.8), 1)
		local saida = C.peso(0.8 + C.SEGURA + C.SAIDA / 2, 0.8)
		t.ok(saida > 0 and saida < 1)
		t.eq(C.peso(5, 0.8), 0)
	end,
	["peso sobe sem saltos e nunca sai de 0..1"] = function(t)
		local ant = 0
		for i = 0, 100 do
			local p = C.peso(i * 0.02, 1)
			t.ok(p >= 0 and p <= 1)
			if i * 0.02 <= 1 then
				t.ok(p >= ant - 1e-9, "não decresce até o impacto")
				t.ok(p - ant < 0.15, "sem salto")
			end
			ant = p
		end
	end,
	["impacto curto encaixa a entrada"] = function(t)
		t.eq(C.peso(0.1, 0.1), 1)
		t.ok(C.peso(0.05, 0.1) < 1)
	end,
	["hit-stop fica entre 60 e 90 ms e é zero sem dano"] = function(t)
		t.eq(C.hitStop(0, false), 0)
		t.eq(C.hitStop(nil, true), 0)
		for _, d in { 1, 5, 12, 40 } do
			local h = C.hitStop(d, false)
			t.ok(h >= C.HITSTOP_MIN - 1e-9 and h <= C.HITSTOP_MAX + 1e-9)
		end
		t.eq(C.hitStop(3, true), C.HITSTOP_MAX)
		t.ok(C.hitStop(18, false) > C.hitStop(2, false))
	end,
	["tremor proporcional ao dano, maior no crítico e limitado"] = function(t)
		local a0 = C.tremor(0, false, 0)
		t.eq(a0, 0)
		local a1, d1 = C.tremor(4, false, 0.3)
		local a2 = C.tremor(20, false, 0.3)
		local a3, d3 = C.tremor(4, true, 0.3)
		t.ok(a2 > a1)
		t.ok(a3 > a1 and d3 > d1)
		t.ok(C.tremor(999, true, 2) <= 0.75)
		t.eq(C.envoltoriaTremor(1), 1)
		t.eq(C.envoltoriaTremor(0), 0)
		t.ok(C.envoltoriaTremor(0.5) < 0.5, "amortecimento")
	end,
	["faíscas crescem com dano e crítico"] = function(t)
		t.ok(C.faiscas(2, false) >= 8)
		t.ok(C.faiscas(20, false) > C.faiscas(2, false))
		t.ok(C.faiscas(5, true) > C.faiscas(5, false))
	end,
	["enquadramento 3/4: ao lado, acima e com o alvo fora da linha de visão do atacante"] = function(t)
		local pos, olhar = C.enquadre({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = -10 }, 1)
		t.ok(pos.y > olhar.y)
		t.ok(math.abs(pos.x) > 5, "de lado")
		t.ok(pos.z > olhar.z, "atrás do meio da dupla (3/4, não de perfil)")
		t.eq(olhar.z, -5)
		local pos2 = C.enquadre({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = -10 }, -1)
		t.eq(pos2.x, -pos.x)
		local pos3 = C.enquadre({ x = 1, y = 0, z = 1 }, { x = 1, y = 0, z = 1 }, 1)
		t.ok(pos3.x == pos3.x, "sem NaN com a dupla no mesmo ponto")
		for _, d in { 2, 3, 5, 8, 15 } do
			t.ok(C.separacaoLateral(d) >= C.SEPARACAO_MIN, "alvo não fica atrás do atacante a " .. d)
		end
	end,
	["candidatos encurtam a distância e abrem o ângulo, sem perder o lado"] = function(t)
		local base = C.enquadre({ x = 0, y = 0, z = 0 }, { x = 5, y = 0, z = 0 }, 1)
		local curto = C.enquadre({ x = 0, y = 0, z = 0 }, { x = 5, y = 0, z = 0 }, 1, 0.5, 0.6)
		local d0 = math.sqrt((base.x - 2.5) ^ 2 + (base.z) ^ 2)
		local d1 = math.sqrt((curto.x - 2.5) ^ 2 + (curto.z) ^ 2)
		t.ok(d1 < d0)
		t.ok(#C.CANDIDATOS >= 4)
	end,
	["caixa da sala: a câmera encolhe pelo caminho até caber, sem mudar de direção"] = function(t)
		local c = { x = 0, z = 0, meia = 58, teto = 30 }
		t.eq(C.fracaoDentro({ x = 0, y = 2, z = 0 }, { x = 10, y = 8, z = 10 }, c), 1)
		local f = C.fracaoDentro({ x = 50, y = 2, z = 0 }, { x = 70, y = 8, z = 0 }, c)
		t.ok(math.abs(f - 0.4) < 1e-9, "sai em x=58")
		local alto = C.fracaoDentro({ x = 0, y = 20, z = 0 }, { x = 0, y = 40, z = 0 }, c)
		t.ok(math.abs(alto - 0.5) < 1e-9, "teto")
		t.eq(C.fracaoDentro({ x = 0, y = 2, z = 0 }, { x = -100, y = 2, z = 0 }, c), 0.58)
		t.eq(C.fracaoDentro({ x = 70, y = 2, z = 0 }, { x = 90, y = 2, z = 0 }, c), 0, "olhar fora da caixa: não aproxima")
	end,
	["câmera lenta só no crítico e no golpe final"] = function(t)
		local d0, r0 = C.lento(false, false)
		t.eq(d0, 0)
		t.eq(r0, 1)
		local d1, r1 = C.lento(true, false)
		t.ok(d1 > 0 and r1 < 1)
		local d2, r2 = C.lento(false, true)
		t.ok(d2 >= d1 and r2 <= r1)
	end,
	["empurrão direcional começa forte, amortece e acaba"] = function(t)
		t.eq(C.empurrao(0), 0)
		t.ok(C.empurrao(0.02) > 0.9)
		t.eq(C.empurrao(1), 0)
		t.ok(math.abs(C.empurrao(0.8)) < 0.1)
	end,
	["avanço do relógio da cena: pausa para, lento reduz, resto corre"] = function(t)
		local j = { { 1, 1.07, 0 }, { 1.07, 1.47, 0.3 } }
		t.eq(C.avanco(0, 1, 1, j), 1)
		t.ok(math.abs(C.avanco(1, 1.07, 1, j)) < 1e-9, "parado no hit-stop")
		t.ok(math.abs(C.avanco(1.07, 1.47, 1, j) - 0.12) < 1e-9)
		t.ok(math.abs(C.avanco(0.5, 2, 1, j) - (0.5 + 0.12 + 0.53)) < 1e-9)
		t.eq(C.avanco(2, 1, 1, j), 0)
	end,
}
