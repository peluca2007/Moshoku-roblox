local Shared = game:GetService("ReplicatedStorage").Shared
local Fogo = require(Shared.Regras.Fogo)
local H = require(Shared.Regras.Habilidades)
local X = require(Shared.Regras.Execucao)
local Planos = require(Shared.PlanosArvores)
local brasa = Fogo.MECANICAS["ability/fogo/Principiante/brasa"]
local fagulha = Fogo.MECANICAS["ability/fogo/Principiante/fagulha"]
local function rng(valores)
	local i = 0
	return { NextInteger = function(_, lo, hi)
		i += 1; local v = valores[i]
		assert(v and v >= lo and v <= hi, "rolagem inesperada " .. i)
		return v
	end }
end
local function alvo(queima)
	return { id = "b", ca = 10, condicoes = if queima then { ["em-chamas"] = 1 } else {}, resistencia = function() return 0 end }
end
local function resolver(a, dados)
	return H.resolver(rng(dados), brasa, { bc = 3, pv = 20, pvMax = 20, condicoes = {} }, { a }, {})[1]
end
return {
	["G5 Brasa: dano antigo sem preparação"] = function(t)
		t.eq(resolver(alvo(false), { 12, 4 }).dano.total, 7)
	end,
	["G5 Brasa: queimar adiciona dado ígneo sem duplicar BC"] = function(t)
		local e = resolver(alvo(true), { 12, 4, 3 })
		t.eq(e.dano.total, 10); t.eq(e.dano.danoIgneo, 10)
		t.eq(e.notas[1], "Alvo Em Chamas: +1d4")
	end,
	["G5 Brasa: erro contra queimando não rola dano"] = function(t)
		local e = resolver(alvo(true), { 1 }); t.eq(e.dano, nil); t.eq(e.aplica, nil)
	end,
	["G5 Brasa: crítico dobra ambos os dados e soma BC uma vez"] = function(t)
		t.eq(resolver(alvo(true), { 20, 2, 3, 1, 4 }).dano.total, 13)
	end,
	["G5 Brasa: resistência e imunidade também valem no bônus"] = function(t)
		local a = alvo(true); a.resistencias = { "ígneo" }
		t.eq(resolver(a, { 12, 4, 3 }).dano.total, 4) -- arredondamento por parcela já usado pelo resolvedor
		a.resistencias = nil; a.imunidades = { "ígneo" }
		t.eq(resolver(a, { 12, 4, 3 }).dano.total, 0)
	end,
	["G5 Fagulha: perigo sem incendiar, inclusive resistência"] = function(t)
		local a = alvo(false)
		local e = H.atravessar(rng({ 3 }), fagulha, a)
		t.eq(e.dano.total, 3); t.eq(e.aplica, nil)
		a.resistencias = { "ígneo" }; t.eq(H.atravessar(rng({ 3 }), fagulha, a).dano.total, 1)
		a.imunidades = { "ígneo" }; t.eq(H.atravessar(rng({ 3 }), fagulha, a).dano.total, 0)
	end,
	["G5 planos: toda etapa aponta para técnica executável da própria árvore"] = function(t)
		for arvore, plano in Planos do
			for _, passo in plano.passos do
				t.ok(X.MECANICAS[passo.id], passo.id)
				t.eq(string.match(passo.id, "^ability/([^/]+)/"), arvore)
			end
		end
	end,
}
