local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.CameraMundoCalculo)

local function perto(t, a, b, rotulo)
	t.ok(math.abs(a - b) < 1e-6, (rotulo or "") .. " esperado " .. tostring(b) .. ", obtido " .. tostring(a))
end

return {
	["giro de passo dá a volta em 0..3 nos dois sentidos"] = function(t)
		t.eq(C.girarPasso(0, 1), 1)
		t.eq(C.girarPasso(3, 1), 0)
		t.eq(C.girarPasso(0, -1), 3)
		local passo = 0
		for _ = 1, 4 do
			passo = C.girarPasso(passo, 1)
		end
		t.eq(passo, 0)
	end,
	["yaw começa em 45 graus e anda 90 por passo, também com passo acumulado"] = function(t)
		perto(t, C.yawDoPasso(0), math.rad(45))
		perto(t, C.yawDoPasso(1), math.rad(135))
		perto(t, C.yawDoPasso(2), math.rad(225))
		perto(t, C.yawDoPasso(3), math.rad(315))
		perto(t, C.yawDoPasso(4) - 2 * math.pi, C.yawDoPasso(0))
		perto(t, C.yawDoPasso(-1), math.rad(-45))
	end,
	["zoom respeita 22 a 70 e o padrão fica dentro"] = function(t)
		t.eq(C.limitarZoom(5), C.ZOOM_MIN)
		t.eq(C.limitarZoom(500), C.ZOOM_MAX)
		t.ok(C.ZOOM_PADRAO >= C.ZOOM_MIN and C.ZOOM_PADRAO <= C.ZOOM_MAX)
		t.eq(C.ZOOM_MIN, 22)
		t.eq(C.ZOOM_MAX, 70)
		local z = C.ZOOM_PADRAO
		for _ = 1, 50 do
			z = C.zoomPelaRoda(z, 1)
		end
		t.eq(z, C.ZOOM_MIN)
		for _ = 1, 50 do
			z = C.zoomPelaRoda(z, -1)
		end
		t.eq(z, C.ZOOM_MAX)
	end,
	["roda para frente aproxima e para trás afasta"] = function(t)
		t.ok(C.zoomPelaRoda(40, 1) < 40)
		t.ok(C.zoomPelaRoda(40, -1) > 40)
		perto(t, C.zoomPelaRoda(40, 0), 40)
	end,
	["pinça afastando os dedos aproxima, juntando afasta, e satura"] = function(t)
		t.ok(C.zoomPelaPinca(40, 2) < 40)
		t.ok(C.zoomPelaPinca(40, 0.5) > 40)
		perto(t, C.zoomPelaPinca(40, 1), 40)
		t.eq(C.zoomPelaPinca(40, 100), C.ZOOM_MIN)
		t.eq(C.zoomPelaPinca(40, 0), C.ZOOM_MAX)
	end,
	["analógico: cima aproxima, baixo afasta, zero não mexe"] = function(t)
		t.ok(C.zoomPorEixo(40, 1, 0.1) < 40)
		t.ok(C.zoomPorEixo(40, -1, 0.1) > 40)
		perto(t, C.zoomPorEixo(40, 0, 0.1), 40)
	end,
	["suavização por dt não depende do FPS"] = function(t)
		local tau = 0.12
		local umPasso = C.seguir(0, 10, 1 / 30, tau)
		local doisPassos = C.seguir(C.seguir(0, 10, 1 / 60, tau), 10, 1 / 60, tau)
		perto(t, umPasso, doisPassos, "30 fps contra 2x60 fps")
		local a = 0
		for _ = 1, 240 do
			a = C.seguir(a, 10, 1 / 240, tau)
		end
		perto(t, a, C.seguir(0, 10, 1, tau), "240 passos contra 1 s")
	end,
	["suavização converge sem passar do alvo e dt zero não anda"] = function(t)
		local x = 0
		for _ = 1, 600 do
			x = C.seguir(x, 5, 1 / 60, 0.1)
			t.ok(x <= 5 + 1e-9)
		end
		t.ok(5 - x < 1e-3)
		perto(t, C.seguir(3, 9, 0, 0.1), 3)
		perto(t, C.seguir(3, 9, 0.016, 0), 9)
	end,
	["Y tem folga máxima atrás do alvo"] = function(t)
		t.eq(C.seguirY(0, 100, 0.001, 0.35), 100 - C.FOLGA_Y_MAX)
		t.eq(C.seguirY(100, 0, 0.001, 0.35), C.FOLGA_Y_MAX)
		local pequeno = C.seguirY(5, 6, 1 / 60, 0.35)
		t.ok(pequeno > 5 and pequeno < 6)
	end,
	["salto de teletransporte só passa do raio"] = function(t)
		t.eq(C.deveTeleportar(10, 0, 10), false)
		t.eq(C.deveTeleportar(70, 0, 0), true)
		t.eq(C.deveTeleportar(0, 0, -250), true)
	end,
	["diferença angular escolhe o caminho curto"] = function(t)
		perto(t, C.diferencaAngular(0, math.rad(90)), math.rad(90))
		perto(t, C.diferencaAngular(math.rad(350), math.rad(10)), math.rad(20))
		perto(t, C.diferencaAngular(math.rad(10), math.rad(350)), math.rad(-20))
	end,
	["giro de 90 graus começa e termina parado e passa pelo meio"] = function(t)
		local de, para = C.yawDoPasso(0), C.yawDoPasso(1)
		perto(t, C.yawAnimado(de, para, 0), de)
		perto(t, C.yawAnimado(de, para, 1), para)
		perto(t, C.yawAnimado(de, para, 0.5), (de + para) / 2)
		perto(t, C.yawAnimado(de, para, 3), para, "k acima de 1 satura")
		local anterior = de
		for i = 1, 20 do
			local y = C.yawAnimado(de, para, i / 20)
			t.ok(y >= anterior - 1e-9)
			anterior = y
		end
		t.ok(C.DURACAO_GIRO >= 0.1 and C.DURACAO_GIRO < 0.2)
	end,
	["câmera fica a 52 graus de inclinação na distância pedida, olhando o foco"] = function(t)
		local foco = { x = 10, y = 5, z = -20 }
		for passo = 0, 3 do
			local c = C.camera(foco, C.yawDoPasso(passo), nil, 40)
			local dx, dy, dz = c.x - foco.x, c.y - foco.y, c.z - foco.z
			perto(t, math.sqrt(dx * dx + dy * dy + dz * dz), 40, "distância passo " .. passo)
			perto(t, math.deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz))), 52, "pitch passo " .. passo)
			t.eq(c.alvoX, foco.x)
			t.eq(c.alvoY, foco.y)
			t.eq(c.alvoZ, foco.z)
		end
	end,
	["as quatro diagonais ficam nos quatro quadrantes, a 45 graus dos eixos"] = function(t)
		local foco = { x = 0, y = 0, z = 0 }
		local sinais = { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } }
		for passo = 0, 3 do
			local c = C.camera(foco, C.yawDoPasso(passo), nil, 40)
			t.eq(c.x > 0, sinais[passo + 1][1] > 0, "x passo " .. passo)
			t.eq(c.z > 0, sinais[passo + 1][2] > 0, "z passo " .. passo)
			perto(t, math.abs(c.x), math.abs(c.z), "diagonal exata passo " .. passo)
		end
	end,
	["zoom maior afasta na mesma direção"] = function(t)
		local foco = { x = 0, y = 0, z = 0 }
		local perta = C.camera(foco, C.yawDoPasso(0), nil, 22)
		local longe = C.camera(foco, C.yawDoPasso(0), nil, 70)
		perto(t, longe.x / perta.x, 70 / 22)
		perto(t, longe.y / perta.y, 70 / 22)
		perto(t, longe.z / perta.z, 70 / 22)
	end,
	["terreno no caminho aproxima a câmera sem passar do zoom nem do mínimo"] = function(t)
		t.eq(C.distanciaLivre(40, nil, 2, 8), 40)
		t.eq(C.distanciaLivre(40, 100, 2, 8), 40)
		t.eq(C.distanciaLivre(40, 25, 2, 8), 23)
		t.eq(C.distanciaLivre(40, 3, 2, 8), 8)
		t.eq(C.distanciaLivre(6, 3, 2, 8), 6)
	end,
	["aproximar é rápido e afastar é lento"] = function(t)
		local aproxima = 40 - C.seguirAssimetrico(40, 20, 0.05, 0.3, 0.06)
		local afasta = C.seguirAssimetrico(20, 40, 0.05, 0.3, 0.06) - 20
		t.ok(aproxima > afasta * 2)
	end,
	["fade anda por tempo e para no alvo"] = function(t)
		perto(t, C.passoFade(0, 1, 0.1, 0.2), 0.5)
		perto(t, C.passoFade(0.9, 1, 0.1, 0.2), 1)
		perto(t, C.passoFade(1, 0, 0.1, 0.2), 0.5)
		perto(t, C.passoFade(0.1, 0, 1, 0.2), 0)
		perto(t, C.passoFade(0.4, 0.4, 0.1, 0.2), 0.4)
	end,
}
