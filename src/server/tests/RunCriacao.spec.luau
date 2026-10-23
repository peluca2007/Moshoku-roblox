local Shared = game:GetService("ReplicatedStorage").Shared
local Criacao = require(Shared.Regras.RunCriacao)
local Forca = require(Shared.Regras.RunArvoresForca)
local Prontos = require(Shared.PersonagensProntos)

-- Gerador falso determinístico: sempre o menor valor.
local menor = { NextInteger = function(_, lo) return lo end }
-- Gerador falso: sempre o maior valor.
local maior = { NextInteger = function(_, _, hi) return hi end }

return {
	["todo personagem pronto do jogo tem arvore catalogada na analise de forca"] = function(t)
		t.eq(#Prontos, 17)
		for _, p in Prontos do t.ok(Forca.ARVORES[p.arvore] ~= nil, p.id .. " -> " .. tostring(p.arvore)) end
	end,
	["modo zero sorteia oferta de 6 arvores elegiveis sem repetir, sem PA extra"] = function(t)
		local plano = Criacao.planejar("zero", menor, Prontos)
		t.eq(plano.modo, "zero")
		t.eq(#plano.oferta, 6)
		t.eq(plano.paExtra, 0)
		t.eq(plano.multiplicador, 1)
		local vistos = {}
		for _, id in plano.oferta do
			t.ok(Forca.elegivel(id), id)
			t.ok(not vistos[id], "repetida " .. id)
			vistos[id] = true
		end
	end,
	["escolher arvore aceita so a da oferta e so no modo zero"] = function(t)
		local plano = Criacao.planejar("zero", menor, Prontos)
		local ok = Criacao.escolherArvore(plano, plano.oferta[1])
		t.eq(ok.arvore, plano.oferta[1])
		t.eq((Criacao.escolherArvore(plano, "vendaval")), nil)
		local _, motivo = Criacao.escolherArvore(plano, "inexistente")
		t.ok(motivo ~= nil)
		t.eq((Criacao.escolherArvore(Criacao.planejar("semArvore", menor, Prontos), "agua")), nil)
		t.eq((Criacao.escolherArvore(nil, "agua")), nil)
	end,
	["sem arvore ganha PA extra e nao tem oferta nem defeitos"] = function(t)
		local plano = Criacao.planejar("semArvore", menor, Prontos)
		t.eq(plano.paExtra, Criacao.PA_EXTRA_SEM_ARVORE)
		t.eq(plano.oferta, nil)
		t.eq(plano.defeitos, nil)
		t.eq(plano.multiplicador, 1)
		t.eq(next(Criacao.efeitos(plano).desvantagemEm), nil)
	end,
	["pronto: ficha elegivel, dois defeitos distintos, mais PA e recompensa maior"] = function(t)
		for _, rng in { menor, maior } do
			local plano = Criacao.planejar("pronto", rng, Prontos)
			t.ok(plano ~= nil)
			t.ok(Forca.elegivel(plano.arvore), plano.arvore)
			t.eq(#plano.defeitos, 2)
			t.ok(plano.defeitos[1] ~= plano.defeitos[2], "defeitos repetidos")
			t.eq(plano.paExtra, Criacao.PA_EXTRA_PRONTO_BASE + 2 * Criacao.PA_EXTRA_POR_DEFEITO)
			t.eq(plano.multiplicador, 1.5)
			t.ok(plano.paExtra > Criacao.PA_EXTRA_SEM_ARVORE, "pronto deve dar mais PA que sem arvore")
			t.ok(Criacao.efeitos(plano) ~= nil)
		end
	end,
	["pronto nunca sorteia ficha de arvore sem acao no combate de hoje"] = function(t)
		local so = { { id = "x", arvore = "vendaval" }, { id = "y", arvore = "punho-de-fogo" } }
		local plano, motivo = Criacao.planejar("pronto", menor, so)
		t.eq(plano, nil)
		t.ok(motivo ~= nil)
	end,
	["recompensa final nunca fica abaixo da base e arredonda para baixo"] = function(t)
		local plano = Criacao.planejar("pronto", menor, Prontos)
		t.eq(Criacao.recompensaFinal(100, plano), 150)
		t.eq(Criacao.recompensaFinal(7, plano), 10)
		t.eq(Criacao.recompensaFinal(0, plano), 0)
		t.eq(Criacao.recompensaFinal(100, Criacao.planejar("zero", menor, Prontos)), 100)
		t.eq((Criacao.recompensaFinal(-1, plano)), nil)
		t.eq((Criacao.recompensaFinal(10, {})), nil)
	end,
	["entradas invalidas sao recusadas"] = function(t)
		t.eq((Criacao.planejar("zero", nil, Prontos)), nil)
		t.eq((Criacao.planejar("magico", menor, Prontos)), nil)
		t.eq((Criacao.planejar("pronto", menor, nil)), nil)
	end,
}
