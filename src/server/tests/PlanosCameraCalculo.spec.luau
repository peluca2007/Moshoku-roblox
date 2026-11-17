-- CAM1: matemática pura dos planos de câmera.
local C = require(game:GetService("ReplicatedStorage").Shared.PlanosCameraCalculo)
local plano = { tomadas = {
	{ t = -1, f = "de", ang = 40, dist = 6, alt = 1.5 },
	{ t = -0.3, f = "proj", ang = 60, dist = 8 },
	{ t = 0, f = "para", ang = 20, dist = 6, alt = 1 },
	{ t = 0.4, f = "para", ang = 10, dist = 9 },
} }

return {
	["valida plano bom e recusa foco, ordem, distância e ângulo ruins"] = function(t)
		t.eq(C.validar(plano), nil)
		t.ok(C.validar({ tomadas = {} }) ~= nil)
		t.ok(C.validar({ tomadas = { { t = 0, f = "x", ang = 0, dist = 5 } } }) ~= nil)
		t.ok(C.validar({ tomadas = { { t = 0, f = "de", ang = 0, dist = 5 }, { t = -1, f = "de", ang = 0, dist = 5 } } }) ~= nil)
		t.ok(C.validar({ tomadas = { { t = 0, f = "de", ang = 0, dist = 1 } } }) ~= nil)
		t.ok(C.validar({ tomadas = { { t = 0, f = "de", ang = 170, dist = 5 } } }) ~= nil)
	end,
	["peso: 0 antes, 1 nas tomadas, volta a 0 depois"] = function(t)
		t.eq(C.amostrar(plano, 0, 2).w, 0)
		t.eq(C.amostrar(plano, 1.0, 2).w, 1)
		t.eq(C.amostrar(plano, 2.0, 2).w, 1)
		t.eq(C.amostrar(plano, 2.4 + C.SAI + 0.01, 2).w, 0)
		t.ok(math.abs(C.fim(plano, 2) - (2.4 + C.SAI)) < 1e-6)
	end,
	["interpola entre tomadas sem salto e passa exatamente pelas tomadas"] = function(t)
		local a = C.amostrar(plano, 1.0, 2) -- tomada 1
		t.eq(a.f1, "de"); t.ok(math.abs(a.ang - 40) < 1e-6); t.ok(math.abs(a.dist - 6) < 1e-6)
		local b = C.amostrar(plano, 2.0, 2) -- tomada 3
		t.eq(b.f1, "para"); t.ok(math.abs(b.dist - 6) < 1e-6)
		local ant = C.amostrar(plano, 0.9, 2)
		for i = 1, 300 do
			local s = C.amostrar(plano, 0.9 + i * 0.005, 2)
			t.ok(math.abs(s.dist - ant.dist) < 0.25 and math.abs(s.ang - ant.ang) < 2.5, "passo pequeno")
			ant = s
		end
	end,
	["tomadas antes de 0 s colapsam em 0 (plano começa com a cena)"] = function(t)
		local s = C.amostrar(plano, 0.1, 0.5) -- contato em 0,5: tomada 1 cairia em -0,5
		t.eq(s.f1, "de")
		t.ok(s.w >= 0 and s.w <= 1)
	end,
}
