-- ANIM2: clipes por peça rígida das criaturas Quaternius (formato, amostragem, marcos, fallback).
local Shared = game:GetService("ReplicatedStorage").Shared
local Anim = require(Shared.Mundo.AnimacaoCriatura)
local Amostra = require(Shared.Animacoes.Amostra)
local Catalogo = require(Shared.Animacoes.Criaturas.Catalogo)
local Pivos = require(Shared.Mundo.PivosModelos)

local MODULOS = { "RatoQuaternius", "AranhaQuaternius", "SerpenteQuaternius", "SapoQuaternius", "VespaQuaternius",
	"EsqueletoQuaternius", "SlimeQuaternius", "MorcegoQuaternius", "DragaoQuaternius" }
local VOADORES = { VespaQuaternius = true, MorcegoQuaternius = true, DragaoQuaternius = true }

local function perto(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-6)
end

local teste = {
	duracao = 1, laco = false, marcos = { impacto = 0.5, fim = 1 },
	pecas = { Corpo = { { 0, 0, 0, 0, 1, 0, 0, 0 }, { 1, 0, math.sin(math.rad(45)), 0, math.cos(math.rad(45)), 2, 4, -6 } } },
}

return {
	["toda criatura tem clipes válidos e pivôs para as peças animadas"] = function(t)
		for _, modulo in MODULOS do
			local dados = Catalogo[modulo]
			t.ok(dados ~= nil, modulo)
			local ok, motivo = Anim.validar(dados)
			t.ok(ok, modulo .. ": " .. tostring(motivo))
			for nome, clipe in dados.clipes do
				for grupo in clipe.pecas do
					t.ok(Pivos[modulo][grupo] ~= nil, modulo .. "." .. nome .. ": peça sem pivô " .. grupo)
				end
			end
		end
	end,
	["todo estado visual tem clipe ou cai nas poses por código"] = function(t)
		for _, modulo in MODULOS do
			local dados = Catalogo[modulo]
			for _, estado in { "parado", "andando", "ataque", "dano", "morte" } do
				local nome, clipe = Anim.clipeDe(dados, estado)
				t.ok(nome ~= nil and clipe ~= nil, modulo .. " sem clipe de " .. estado)
			end
			local _, parado = Anim.clipeDe(dados, "parado")
			t.ok(parado.laco, modulo .. ": parado precisa ser laço")
			local _, andando = Anim.clipeDe(dados, "andando")
			t.ok(andando.laco, modulo .. ": andando precisa ser laço")
			local _, morte = Anim.clipeDe(dados, "morte")
			t.ok(morte.segurar and not morte.laco, modulo .. ": morte segura o último quadro")
			local _, ataque = Anim.clipeDe(dados, "ataque")
			local impacto = Anim.marcoImpacto(ataque)
			t.ok(impacto ~= nil and impacto > 0 and impacto < ataque.duracao, modulo .. ": marco de impacto no meio do golpe")
			t.eq(VOADORES[modulo] == true, dados.clipes.Voar ~= nil, modulo .. ": só voador tem Voar")
		end
		t.eq(Anim.clipeDe({}, "parado"), nil)
		t.eq(Anim.clipeDe(Catalogo.RatoQuaternius, "inexistente"), nil)
	end,
	["laço fecha: primeiro e último quadro de cada peça coincidem"] = function(t)
		for _, modulo in MODULOS do
			for nome, c in Catalogo[modulo].clipes do
				if c.laco then
					for grupo, chaves in c.pecas do
						local a, b = chaves[1], chaves[#chaves]
						t.ok(perto(b[1], c.duracao, 1e-3), modulo .. "." .. nome .. "." .. grupo .. ": termina na duração")
						for k = 2, 8 do
							t.ok(perto(a[k], b[k], 1e-4), modulo .. "." .. nome .. "." .. grupo .. " k=" .. k)
						end
					end
				end
			end
		end
	end,
	["amostra interpola rotação (slerp) e deslocamento e respeita os limites"] = function(t)
		local qx, qy, qz, qw, dx, dy, dz = Anim.peca(teste, "Corpo", 0.5)
		t.ok(perto(qy, math.sin(math.rad(22.5)), 1e-5) and perto(qw, math.cos(math.rad(22.5)), 1e-5))
		t.ok(perto(qx, 0) and perto(qz, 0))
		t.ok(perto(dx, 1) and perto(dy, 2) and perto(dz, -3))
		local _, _, _, w0 = Anim.peca(teste, "Corpo", -5)
		t.ok(perto(w0, 1))
		local _, y1, _, _, dx1 = Anim.peca(teste, "Corpo", 99)
		t.ok(perto(y1, math.sin(math.rad(45)), 1e-6) and perto(dx1, 2))
		t.eq(Anim.peca(teste, "BracoD", 0.5), nil)
	end,
	["tempo de laço e marcos usam o Amostra"] = function(t)
		local c = Catalogo.RatoQuaternius.clipes.Respirar
		local local1 = Amostra.tempoLocal(c, c.duracao * 2.25)
		t.ok(perto(local1, c.duracao * 0.25, 1e-6))
		local ataque = Catalogo.RatoQuaternius.clipes.Atacar
		local nomes = Amostra.marcosEntre(ataque, -1e-6, ataque.duracao)
		t.ok(table.find(nomes, "impacto") ~= nil)
		local antes = Amostra.marcosEntre(ataque, -1e-6, ataque.marcos.impacto - 0.01)
		t.eq(table.find(antes, "impacto"), nil)
	end,
	["misturar cruza de uma pose a outra sem salto"] = function(t)
		local s = math.sin(math.rad(45))
		local _, _, _, qw, dx = Anim.misturar(0, 0, 0, 0, 1, 0, 0, 0, 0, s, 0, s, 4, 0, 0)
		t.ok(perto(qw, 1) and perto(dx, 0))
		local _, my, _, mw, mdx = Anim.misturar(0.5, 0, 0, 0, 1, 0, 0, 0, 0, s, 0, s, 4, 0, 0)
		t.ok(perto(my, math.sin(math.rad(22.5)), 1e-5) and perto(mw, math.cos(math.rad(22.5)), 1e-5) and perto(mdx, 2))
		local _, by, _, _, bdx = Anim.misturar(1, 0, 0, 0, 1, 0, 0, 0, 0, s, 0, s, 4, 0, 0)
		t.ok(perto(by, s, 1e-6) and perto(bdx, 4))
	end,
	["validar recusa clipe malformado"] = function(t)
		t.ok(not Anim.validar(nil))
		t.ok(not Anim.validar({ clipes = {} }))
		t.ok(not Anim.validar({ clipes = { A = { duracao = 1, pecas = { Corpo = { { 0, 0, 0, 0, 2, 0, 0, 0 } } } } } }))
		t.ok(not Anim.validar({ clipes = { A = { duracao = 1, pecas = { Corpo = { { 0, 0, 0, 0, 1, 0, 0 } } } } } }))
		t.ok(not Anim.validar({ clipes = { A = { duracao = 1, marcos = { impacto = 3 }, pecas = { Corpo = { { 0, 0, 0, 0, 1, 0, 0, 0 } } } } } }))
		t.ok(Anim.validar({ clipes = { A = { duracao = 1, pecas = { Corpo = { { 0, 0, 0, 0, 1, 0, 0, 0 } } } } } }))
	end,
}
