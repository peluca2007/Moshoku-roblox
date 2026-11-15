-- ANIM1: amostragem pura dos clipes de animação por dados e sanidade de todos os clipes gerados.
local Amostra = require(game:GetService("ReplicatedStorage").Shared.Animacoes.Amostra)
local Catalogo = require(game:GetService("ReplicatedStorage").Shared.Animacoes.Catalogo)

local function perto(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-6)
end

local S45 = math.sin(math.rad(22.5)) -- quatérnio de 45 graus em Y: (0, sin 22,5, 0, cos 22,5)
local S90 = math.sin(math.rad(45))

local function clipeTeste(laco)
	return {
		fps = 30,
		duracao = 2,
		laco = laco,
		marcos = { impacto = 0.5, fim = 1.9 },
		juntas = {
			Waist = { { 0, 0, 0, 0, 1 }, { 1, 0, S90, 0, S90 }, { 2, 0, 0, 0, 1 } },
		},
		raiz = { { 0, 0, 0, 0 }, { 2, 0, -1, 2 } },
	}
end

local GOLPES = { CorteLeve = "impacto", CortePesado = "impacto", Estocada = "impacto", Conjurar = "impacto", DisparoArco = "soltar" }
local ESPERADOS = { "PosturaCombate", "CorteLeve", "CortePesado", "Estocada", "DisparoArco", "Conjurar", "Canalizar",
	"ReacaoGolpe", "Esquiva", "Bloqueio", "Queda", "Vitoria" }

return {
	["busca binária acha o quadro e respeita os limites"] = function(t)
		local chaves = { { 0 }, { 0.5 }, { 1 }, { 1.5 }, { 2 } }
		t.eq(Amostra.indice(chaves, -1), 1)
		t.eq(Amostra.indice(chaves, 0), 1)
		t.eq(Amostra.indice(chaves, 0.49), 1)
		t.eq(Amostra.indice(chaves, 0.5), 2)
		t.eq(Amostra.indice(chaves, 1.75), 4)
		t.eq(Amostra.indice(chaves, 2), 5)
		t.eq(Amostra.indice(chaves, 9), 5)
		t.eq(Amostra.indice({ { 0 } }, 3), 1)
	end,
	["slerp no meio do caminho e pelo caminho curto"] = function(t)
		local x, y, z, w = Amostra.slerp(0, 0, 0, 1, 0, S90, 0, S90, 0.5)
		t.ok(perto(x, 0) and perto(y, S45, 1e-6) and perto(z, 0) and perto(w, math.cos(math.rad(22.5)), 1e-6), "45 graus")
		-- o mesmo destino com sinal trocado (mesma rotação) dá o mesmo resultado
		local x2, y2, z2, w2 = Amostra.slerp(0, 0, 0, 1, 0, -S90, 0, -S90, 0.5)
		t.ok(perto(x, x2) and perto(y, y2) and perto(z, z2) and perto(w, w2), "caminho curto")
		local a, b, c, d = Amostra.slerp(0, S90, 0, S90, 0, S90, 0, S90, 0.3)
		t.ok(perto(a, 0) and perto(b, S90) and perto(c, 0) and perto(d, S90), "iguais")
	end,
	["interpola junta e raiz e segura nas pontas"] = function(t)
		local clipe = clipeTeste(false)
		local _, y, _, w = Amostra.junta(clipe.juntas.Waist, 0.5)
		t.ok(perto(y, S45, 1e-6) and perto(w, math.cos(math.rad(22.5)), 1e-6), "meio do primeiro trecho")
		local _, y1 = Amostra.junta(clipe.juntas.Waist, -3)
		t.ok(perto(y1, 0), "antes do início = primeiro quadro")
		local _, y2 = Amostra.junta(clipe.juntas.Waist, 99)
		t.ok(perto(y2, 0), "depois do fim = último quadro")
		local rx, ry, rz = Amostra.raiz(clipe.raiz, 1)
		t.ok(perto(rx, 0) and perto(ry, -0.5) and perto(rz, 1), "raiz linear")
		local ax, ay, az = Amostra.raiz(nil, 1)
		t.ok(ax == 0 and ay == 0 and az == 0, "sem raiz = zero")
	end,
	["tempo local com e sem laço"] = function(t)
		local t1, fim1 = Amostra.tempoLocal(clipeTeste(true), 2.5)
		t.ok(perto(t1, 0.5) and not fim1, "laço volta ao início")
		local t2, fim2 = Amostra.tempoLocal(clipeTeste(false), 2.5)
		t.ok(perto(t2, 2) and fim2, "sem laço para no fim")
		local t3, fim3 = Amostra.tempoLocal(clipeTeste(false), 1.2)
		t.ok(perto(t3, 1.2) and not fim3)
	end,
	["peso com fade de entrada e de saída"] = function(t)
		t.ok(perto(Amostra.peso(0.05, 2, 0.1, 0.2, false), 0.5), "metade do fade de entrada")
		t.ok(perto(Amostra.peso(1, 2, 0.1, 0.2, false), 1), "meio do clipe")
		t.ok(perto(Amostra.peso(1.9, 2, 0.1, 0.2, false), 0.5, 1e-9), "metade do fade de saída")
		t.ok(perto(Amostra.peso(2.5, 2, 0.1, 0.2, false), 0), "depois do fim")
		t.ok(perto(Amostra.peso(2.5, 2, 0.1, 0.2, true), 1), "laço não sai")
		t.ok(perto(Amostra.peso(2.5, 2, 0.1, 0.2, false, true), 1), "segurar não sai")
		t.ok(perto(Amostra.peso(3, 2, 0, 0, false), 0), "sem fade, some no fim")
	end,
	["marcos cruzados entre dois instantes, inclusive no laço"] = function(t)
		local c = clipeTeste(false)
		local m = Amostra.marcosEntre(c, 0.4, 0.5)
		t.eq(#m, 1); t.eq(m[1], "impacto")
		t.eq(#Amostra.marcosEntre(c, 0.5, 0.6), 0, "intervalo aberto à esquerda")
		local dois = Amostra.marcosEntre(c, 0, 2)
		t.eq(#dois, 2); t.eq(dois[1], "impacto"); t.eq(dois[2], "fim")
		local l = clipeTeste(true)
		local volta = Amostra.marcosEntre(l, 1.8, 2.6) -- fim em 1,9 e impacto em 2,5 (segunda volta)
		t.eq(#volta, 2); t.eq(volta[1], "fim"); t.eq(volta[2], "impacto")
		t.eq(#Amostra.marcosEntre(l, 0, 6), 6, "três voltas, dois marcos por volta")
		local zero = { fps = 30, duracao = 1, marcos = { impacto = 0 }, juntas = {} }
		t.eq(#Amostra.marcosEntre(zero, -1e-6, 0), 1, "marco em t = 0 com início negativo")
		t.eq(#Amostra.marcosEntre(c, 1, 0.5), 0, "intervalo invertido")
	end,
	["validar recusa clipes malformados"] = function(t)
		t.ok(Amostra.validar(clipeTeste(false)), "clipe de teste válido")
		local ruim = clipeTeste(false); ruim.juntas.Barriga = ruim.juntas.Waist
		t.ok(not Amostra.validar(ruim), "junta inexistente")
		ruim = clipeTeste(false); ruim.juntas.Waist[2] = { 1, 0, 1, 0, 1 }
		t.ok(not Amostra.validar(ruim), "quatérnio não unitário")
		ruim = clipeTeste(false); ruim.juntas.Waist[3][1] = 0.5
		t.ok(not Amostra.validar(ruim), "tempo decrescente")
		ruim = clipeTeste(false); ruim.marcos.impacto = 5
		t.ok(not Amostra.validar(ruim), "marco fora da duração")
		ruim = clipeTeste(false); ruim.raiz[2] = { 3, 0, 0, 0 }
		t.ok(not Amostra.validar(ruim), "raiz além da duração")
		t.ok(not Amostra.validar(nil), "nil")
	end,
	["todos os clipes do catálogo são sãos"] = function(t)
		for _, nome in ESPERADOS do
			t.ok(Catalogo.CLIPES[nome] ~= nil, "falta o clipe " .. nome)
		end
		t.eq(#Catalogo.NOMES, #ESPERADOS, "quantidade de clipes")
		for _, nome in Catalogo.NOMES do
			local clipe = Catalogo.CLIPES[nome]
			local ok, erro = Amostra.validar(clipe)
			t.ok(ok, nome .. ": " .. tostring(erro))
			t.eq(clipe.nome, nome, "nome interno")
			for _, junta in Amostra.JUNTAS do
				t.ok(clipe.juntas[junta] ~= nil, nome .. " sem a junta " .. junta)
				local chaves = clipe.juntas[junta]
				t.ok(perto(chaves[1][1], 0) and perto(chaves[#chaves][1], clipe.duracao, 1e-3), nome .. "/" .. junta .. " cobre a duração")
			end
			t.ok(clipe.raiz and #clipe.raiz >= 1, nome .. " sem raiz")
			for _, ch in clipe.raiz do
				-- o personagem fica na casa: deslocamento da raiz limitado
				t.ok(math.abs(ch[2]) <= 1.5 and math.abs(ch[4]) <= 1.5 and ch[3] >= -2 and ch[3] <= 0.5, nome .. ": raiz fora da casa")
			end
		end
	end,
	["golpes têm impacto, disparo tem soltar e laços fecham"] = function(t)
		for nome, marco in GOLPES do
			local clipe = Catalogo.CLIPES[nome]
			t.ok(clipe.marcos and clipe.marcos[marco] ~= nil, nome .. " sem o marco " .. marco)
		end
		for _, nome in { "PosturaCombate", "Canalizar" } do
			local clipe = Catalogo.CLIPES[nome]
			t.ok(clipe.laco == true, nome .. " deveria ser laço")
			for junta, chaves in clipe.juntas do
				local a, b = chaves[1], chaves[#chaves]
				local d = math.abs(a[2] * b[2] + a[3] * b[3] + a[4] * b[4] + a[5] * b[5])
				t.ok(d > 0.9999, nome .. "/" .. junta .. ": laço com salto")
			end
		end
		t.ok(Catalogo.CLIPES.Queda.segurar == true, "Queda termina caído e fica")
		-- clipes de ação começam na postura (mistura sem salto)
		local postura = Catalogo.CLIPES.PosturaCombate
		for _, nome in { "CorteLeve", "CortePesado", "Estocada", "DisparoArco", "Conjurar", "Esquiva", "Bloqueio" } do
			for junta, chaves in Catalogo.CLIPES[nome].juntas do
				local a = chaves[1]
				local qx, qy, qz, qw = Amostra.junta(postura.juntas[junta], 0)
				local d = math.abs(a[2] * qx + a[3] * qy + a[4] * qz + a[5] * qw)
				t.ok(d > 0.999, nome .. "/" .. junta .. " não começa na postura")
			end
		end
	end,
}
