-- LUTA-A: câmera de luta (EnquadramentoMesa.plano), pura.
local E = require(game:GetService("ReplicatedStorage").Shared.EnquadramentoMesa)
local board = { width = 20, height = 20, cell = 5 }
local VP = { x = 1280, y = 720 }
local AREA = { x1 = 0, y1 = 64, x2 = 1280, y2 = 400 } -- painel de ações ocupa a parte de baixo

local function opcoes(pontos, ator, yaw)
	return { pontos = pontos, ator = ator, yaw = yaw or 0, fov = 70, viewport = VP, area = AREA }
end
local function dentro(plano, p, o)
	for _, dy in { 0, E.ALTURA_FIGURA } do
		local x, y = E.projetar(plano, { x = p.x, y = dy, z = p.z }, o)
		if math.abs(x) > 1.001 or math.abs(y) > 1.001 then return false end
	end
	return true
end

return {
	["vivos ignora derrotados, ocultos e quem não está na ordem; centro igual ao cellCenter"] = function(t)
		local tokens = { { id = "a", x = 1, z = 1 }, { id = "b", x = 2, z = 1, derrotado = true }, { id = "c", x = 3, z = 1, pv = 0 },
			{ id = "d", x = 4, z = 1, hidden = true }, { id = "e", x = 5, z = 1 } }
		local v = E.vivos(tokens, { "a", "b", "c", "d" }, board)
		t.eq(#v, 1); t.eq(v[1].x, -47.5); t.eq(v[1].z, -47.5)
	end,
	["luta 1x1: figura ocupa ao menos 1/8 da tela e os dois cabem"] = function(t)
		local pts = { { x = 0, z = 0 }, { x = 0, z = -5 } }
		for _, yaw in { 0, math.pi / 4, math.pi / 2, math.pi } do
			local o = opcoes(pts, pts[1], yaw)
			local pl = E.plano(o)
			t.ok(pl.fracao >= 1 / 8, "fração " .. pl.fracao)
			t.ok(pl.cabe)
			for _, p in pts do t.ok(dentro(pl, p, o), "ponto fora") end
		end
	end,
	["luta cheia: nunca menos de 1/12 e quem age fica na tela"] = function(t)
		local pts = {}
		for i = 0, 7 do table.insert(pts, { x = -40 + i * 11, z = (i % 3) * 15 - 15 }) end
		for _, ator in { pts[1], pts[8], pts[4] } do
			local o = opcoes(pts, ator, 0)
			local pl = E.plano(o)
			t.ok(pl.fracao >= 1 / 12 - 1e-9, "fração " .. pl.fracao)
			t.ok(not pl.cabe)
			t.ok(dentro(pl, ator, o), "quem age saiu da tela")
		end
	end,
	["inclinação de 50 graus e base ortonormal"] = function(t)
		t.eq(E.INCLINACAO, 50)
		local f, d, c = E.base(0.7, 50)
		local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
		t.ok(math.abs(dot(f, d)) < 1e-9 and math.abs(dot(f, c)) < 1e-9 and math.abs(dot(d, c)) < 1e-9)
		t.ok(math.abs(math.deg(math.asin(-f.y)) - 50) < 1e-6)
		local f0 = E.base(0, 50)
		t.ok(f0.z < 0 and math.abs(f0.x) < 1e-9) -- yaw 0 olha para -Z, como a mesa antiga
	end,
	["giro não muda a distância de um arranjo simétrico"] = function(t)
		local pts = { { x = 5, z = 5 }, { x = -5, z = 5 }, { x = 5, z = -5 }, { x = -5, z = -5 } }
		local a = E.plano(opcoes(pts, pts[1], 0)).distancia
		local b = E.plano(opcoes(pts, pts[1], math.pi / 2)).distancia
		t.ok(math.abs(a - b) < 1e-6)
	end,
	["giro inicial olha de lado para a linha grupo x inimigos"] = function(t)
		for _, alvo in { { x = 0, z = -10 }, { x = 10, z = 0 }, { x = -7, z = 7 } } do
			local yaw = E.yawLateral({ { x = 0, z = 0 } }, { alvo })
			local f = E.base(yaw, 50)
			local h = math.sqrt(f.x * f.x + f.z * f.z)
			local n = math.sqrt(alvo.x * alvo.x + alvo.z * alvo.z)
			local cos = (f.x * alvo.x + f.z * alvo.z) / (h * n)
			t.ok(math.abs(cos - math.cos(math.rad(E.ANGULO_LATERAL))) < 1e-6, "cos " .. cos)
		end
		t.eq(E.yawLateral({}, { { x = 1, z = 1 } }), 0)
	end,
}
