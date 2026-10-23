local Shared = game:GetService("ReplicatedStorage").Shared
local D = require(Shared.CenaAberturaDados)
local Terreno = require(Shared.Mundo.TerrenoLayout)
local Vila = require(Shared.Mundo.VilaLayout)

local PASSO = 0.05 -- s entre amostras do trajeto
local VEL_MAX = 140 -- studs/s: voo de câmera rápido mas legível
local GIRO_MAX = 75 -- graus/s de giro do olhar (yaw/pitch)

local function olhar(p)
	local dx, dy, dz = p.ax - p.x, p.ay - p.y, p.az - p.z
	local h = math.sqrt(dx * dx + dz * dz)
	return math.deg(math.atan2(dx, dz)), math.deg(math.atan2(dy, h))
end
local function diferenca(a, b)
	local d = (b - a + 180) % 360 - 180
	return math.abs(d)
end

return {
	["pontos do trajeto existem, em ordem e cobrem montanhas, lago, floresta, vila e portão"] = function(t)
		local q = D.QUADROS
		t.ok(#q >= 8, "poucos quadros-chave")
		local nomes = {}
		for i, k in ipairs(q) do
			nomes[k.nome] = true
			t.ok(k.cam and k.alvo and k.fov, "quadro incompleto " .. i)
			for _, v in { k.cam.x, k.cam.y, k.cam.z, k.alvo.x, k.alvo.y, k.alvo.z, k.fov } do
				t.ok(v == v and math.abs(v) < 5000, "valor inválido no quadro " .. i)
			end
			t.ok(k.fov >= 40 and k.fov <= 80, "FOV fora de 40..80 no quadro " .. i)
			if i > 1 then t.ok(k.t > q[i - 1].t, "tempos precisam crescer (quadro " .. i .. ")") end
		end
		for _, nome in { "montanhas", "lago", "floresta", "trilha", "vila", "praca", "portao" } do
			t.ok(nomes[nome], "falta o ponto " .. nome)
		end
		t.eq(q[1].t, 0)
		t.eq(q[#q].t, D.DURACAO)
	end,

	["âncoras vêm dos layouts: pico nevado acima da linha de neve, lago, clareira e portão"] = function(t)
		local A = D.ANCORAS
		t.ok(Terreno.altura(A.pico.x, A.pico.z) > Terreno.NEVE + 20, "o pico precisa ter neve")
		t.eq(A.lago.x, Terreno.AGUA[1].x)
		t.eq(A.lago.z, Terreno.AGUA[1].z)
		t.eq(A.praca.x, Vila.PRACA.x)
		t.eq(A.praca.z, Vila.PRACA.z)
		t.ok(A.portaoNorte.z > A.praca.z and A.portaoNorte.z > A.portaoSul.z, "o portão norte fica ao norte (+z) da praça e do portão sul")
	end,

	["cena começa nas montanhas, olhando o pico, e termina junto ao portão norte olhando para fora"] = function(t)
		local ini = D.amostrar(0)
		t.ok(math.abs(ini.ax - D.ANCORAS.pico.x) < 1 and math.abs(ini.az - D.ANCORAS.pico.z) < 1, "abertura precisa mirar o pico")
		local fim = D.amostrar(D.DURACAO)
		local g = D.ANCORAS.portaoNorte
		local dist = math.sqrt((fim.x - g.x) ^ 2 + (fim.z - g.z) ^ 2)
		t.ok(dist <= 30, "câmera final longe do portão norte: " .. dist)
		t.ok(fim.az > fim.z, "o final olha para o norte, para fora do portão")
		t.ok(math.abs(fim.x) < 12, "o final fica na linha da estrada")
	end,

	["duração total entre 18 e 28 s"] = function(t)
		t.ok(D.DURACAO >= 18 and D.DURACAO <= 28, "duração " .. D.DURACAO)
	end,

	["o trajeto nunca atravessa o terreno: folga mínima sobre o relevo em toda a curva"] = function(t)
		local pior, quando = math.huge, 0
		local n = math.floor(D.DURACAO / PASSO)
		for i = 0, n do
			local tempo = i * PASSO
			local p = D.amostrar(tempo)
			local folga = p.y - Terreno.altura(p.x, p.z)
			if folga < pior then pior, quando = folga, tempo end
		end
		t.ok(pior >= D.FOLGA_MINIMA, string.format("folga %.1f stud(s) em t=%.2f (mínimo %d)", pior, quando, D.FOLGA_MINIMA))
	end,

	["movimento suave: sem saltos de posição, velocidade e giro limitados"] = function(t)
		local anterior = D.amostrar(0)
		local ya, pa = olhar(anterior)
		local maiorV, maiorG, quandoV, quandoG = 0, 0, 0, 0
		for i = 1, math.floor(D.DURACAO / PASSO) do
			local p = D.amostrar(i * PASSO)
			local dx, dy, dz = p.x - anterior.x, p.y - anterior.y, p.z - anterior.z
			local v = math.sqrt(dx * dx + dy * dy + dz * dz) / PASSO
			local yaw, pitch = olhar(p)
			local giro = math.max(diferenca(ya, yaw), diferenca(pa, pitch)) / PASSO
			if v > maiorV then maiorV, quandoV = v, i * PASSO end
			if giro > maiorG then maiorG, quandoG = giro, i * PASSO end
			anterior, ya, pa = p, yaw, pitch
		end
		t.ok(maiorV <= VEL_MAX, string.format("velocidade máxima %.0f studs/s em t=%.2f", maiorV, quandoV))
		t.ok(maiorG <= GIRO_MAX, string.format("giro máximo %.0f graus/s em t=%.2f", maiorG, quandoG))
		-- Partida e chegada suaves (tangente nula nas pontas): quase parada nos primeiros 50 ms.
		local a, b = D.amostrar(0), D.amostrar(0.05)
		t.ok(math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2) / 0.05 < 4, "partida brusca")
	end,

	["falas: 4 a 6, dentro da cena, em ordem, sem sobreposição e legíveis no tempo"] = function(t)
		local f = D.FALAS
		t.ok(#f >= 4 and #f <= 6, "número de falas " .. #f)
		local chaves = {}
		for i, fala in ipairs(f) do
			t.ok(not chaves[fala.chave], "chave repetida " .. fala.chave)
			chaves[fala.chave] = true
			t.ok(#fala.texto > 0 and #fala.chave > 0)
			t.ok(fala.inicio >= 0 and fala.inicio + fala.duracao <= D.DURACAO, "fala fora da cena: " .. fala.chave)
			if i > 1 then t.ok(fala.inicio >= f[i - 1].inicio + f[i - 1].duracao, "falas se sobrepõem: " .. fala.chave) end
			local ritmo = D.palavras(fala.texto) / fala.duracao
			t.ok(ritmo <= D.PALAVRAS_POR_SEGUNDO, string.format("%s não cabe no tempo (%.2f palavras/s)", fala.chave, ritmo))
			t.ok(fala.duracao >= 2 * D.FADE_FALA, "fala curta demais para o fade")
		end
	end,

	["título dura cerca de 3 s, cabe na cena e não cobre uma legenda"] = function(t)
		local ti = D.TITULO
		t.ok(ti.duracao >= 2.5 and ti.duracao <= 3.5, "duração do título " .. ti.duracao)
		t.ok(ti.inicio >= 0 and ti.inicio + ti.duracao <= D.DURACAO)
		for _, fala in ipairs(D.FALAS) do
			t.ok(ti.inicio + ti.duracao <= fala.inicio or fala.inicio + fala.duracao <= ti.inicio, "título sobre a fala " .. fala.chave)
		end
		t.eq(D.tituloEm(ti.inicio - 0.1), 0)
		t.ok(D.tituloEm(ti.inicio + ti.duracao / 2) > 0.99)
		t.eq(D.tituloEm(ti.inicio + ti.duracao + 0.1), 0)
	end,

	["funções de tempo: legenda faz fade, barras fecham no começo e o preto abre e fecha a cena"] = function(t)
		local f = D.FALAS[1]
		local _, a0 = D.falaEm(f.inicio)
		local fala, a1 = D.falaEm(f.inicio + f.duracao / 2)
		t.eq(a0, 0)
		t.eq(fala, f)
		t.ok(a1 > 0.99)
		t.eq(D.falaEm(0.1), nil)
		t.eq(D.barrasEm(0), 0)
		t.eq(D.barrasEm(D.ENTRADA_BARRAS), 1)
		t.eq(D.barrasEm(D.DURACAO), 1)
		t.eq(D.veuEm(0), 1)
		t.eq(D.veuEm(D.DURACAO / 2), 0)
		t.eq(D.veuEm(D.DURACAO), 1)
	end,
}
