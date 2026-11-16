-- HAB2: curvas puras das magias de Água (freio, hélice, câmera lenta, quantidades).
local C = require(game:GetService("ReplicatedStorage").Shared.AguaCurvas)

local function perto(t, a, b, tol) t.ok(math.abs(a - b) <= tol, "esperado " .. b .. ", veio " .. a) end

return {
	["avanço: extremos fixos e monotônico, mais lento perto do alvo com freio"] = function(t)
		t.eq(C.avanco(0, 1.2), 0)
		t.eq(C.avanco(1, 1.2), 1)
		local ant = 0
		for i = 1, 20 do
			local v = C.avanco(i / 20, 1.2)
			t.ok(v >= ant, "monotônico")
			ant = v
		end
		t.ok(C.avanco(0.5, 1.2) > 0.5, "com freio, adianta no começo e freia no fim")
		t.ok(C.avanco(1, 1.2) - C.avanco(0.9, 1.2) < C.avanco(0.1, 1.2), "passo final menor que o inicial")
		t.eq(C.avanco(0.5, 0), 0.5, "sem freio é reta")
		t.eq(C.avanco(2, 1), 1, "limita")
	end,
	["duração do voo: limitada por mínimo e máximo"] = function(t)
		t.eq(C.duracaoDoVoo(1, 100), 0.25)
		t.eq(C.duracaoDoVoo(500, 10), 0.9)
		perto(t, C.duracaoDoVoo(12, 30), 0.4, 1e-9)
	end,
	["hélice fecha nas pontas e respeita o raio"] = function(t)
		local x0, y0 = C.helice(0, 1, 2)
		perto(t, x0, 0, 1e-9); perto(t, y0, 0, 1e-9)
		local x1, y1 = C.helice(1, 1, 2)
		perto(t, x1, 0, 1e-6); perto(t, y1, 0, 1e-6)
		for i = 0, 10 do
			local x, y = C.helice(i / 10, 0.7, 3, 1)
			t.ok(math.sqrt(x * x + y * y) <= 0.7 + 1e-9)
		end
	end,
	["órbita mantém o raio"] = function(t)
		for i = 0, 4 do
			local x, y = C.orbita(1.3, 0.9, 5, i)
			perto(t, math.sqrt(x * x + y * y), 0.9, 1e-9)
		end
	end,
	["balística: sobe, atinge o pico e cai"] = function(t)
		local _, y0 = C.balistica(0, 0, 0, 1, 10, 0, 0)
		local _, y1 = C.balistica(0, 0, 0, 1, 10, 0, 0.18)
		local _, y2 = C.balistica(0, 0, 0, 1, 10, 0, 0.9)
		t.eq(y0, 0)
		t.ok(y1 > 0 and y2 < y1)
	end,
	["quantidade: crítico aumenta, reduzido corta para 1/4 e nunca zera"] = function(t)
		t.eq(C.quantidade(16), 16)
		t.eq(C.quantidade(16, true), 24)
		t.eq(C.quantidade(16, false, true), 4)
		t.eq(C.quantidade(1, false, true), 1)
	end,
	["taxa de tempo: normal antes, lenta no contato, volta a 1"] = function(t)
		t.eq(C.taxaDeTempo(-0.1, 0.3, 0.2), 1)
		t.eq(C.taxaDeTempo(0, 0.3, 0.2), 0.2)
		t.eq(C.taxaDeTempo(0.3, 0.3, 0.2), 0.2)
		local meio = C.taxaDeTempo(0.45, 0.3, 0.2)
		t.ok(meio > 0.2 and meio < 1)
		t.eq(C.taxaDeTempo(0.6, 0.3, 0.2), 1)
		t.eq(C.taxaDeTempo(0.1, 0, 0.2), 1, "duração zero desliga")
	end,
	["integrar: acumula conforme a taxa e a escala de QA"] = function(t)
		perto(t, C.integrar(1, 0.5, 0.2), 1.1, 1e-9)
		perto(t, C.integrar(1, 0.5, 1, 4), 1.125, 1e-9)
	end,
}
