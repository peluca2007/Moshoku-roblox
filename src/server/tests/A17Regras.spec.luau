-- A17: dados e ajustes puros do resolver, com RNG injetado.
local R = require(game:GetService("ReplicatedStorage").Shared.Regras.Habilidades)
local M = require(game:GetService("ReplicatedStorage").Shared.Regras.Maestrias)
local function rng()
	return { NextInteger = function(_, lo, hi) return math.clamp(3, lo, hi) end }
end
local function conj(extra)
	local c = { id = "a", bc = 2, pv = 20, pvMax = 20, condicoes = {}, arma = { dado = "d8", bonus = 2 } }
	for k,v in extra or {} do c[k] = v end
	return c
end
local function alvo(extra)
	local a = { id = "b", ca = 1, condicoes = {}, resistencia = function() return 0 end }
	for k,v in extra or {} do a[k] = v end
	return a
end
return {
	["A17 registro Maestrias contém todas as cartas e ações básicas"] = function(t)
		for _, grupo in {M.CARTAS,M.BASICAS} do for id,mec in grupo do t.eq(M.MECANICAS[id],mec) end end
	end,
	["A17 Brisa empurra no sucesso e falha aplica Desequilibrado"] = function(t)
		local m = {tipo="efeito",resistencia={atributo="forca",cdBase=8},empurraSempre=1,aplica="desequilibrado"}
		local e=R.resolver(rng(),m,conj(),{alvo({resistencia=function() return 20 end})},{})[1]
		t.eq(e.resistencia.passou,true);t.eq(e.empurrar,1);t.eq(e.aplica,nil)
		e=R.resolver(rng(),m,conj(),{alvo()},{})[1];t.eq(e.empurrar,1);t.eq(e.aplica[1],"desequilibrado")
	end,
	["A17 Esquivar só ajusta ataques e testes da fonte designada"] = function(t)
		local m={tipo="ataque",arma=true,partes={{arma=true}}}
		local a=alvo({esquivaContra="a"})
		local e=R.resolver(rng(),m,conj(),{a},{})[1];t.eq(e.ataque.d20.ajuste,"desvantagem")
		e=R.resolver(rng(),m,conj({id="c"}),{a},{})[1];t.eq(#e.ataque.d20.dados,1)
		m={tipo="efeito",resistencia={atributo="vigor",cdBase=8}}
		e=R.resolver(rng(),m,conj(),{a},{})[1];t.eq(e.resistencia.d20.ajuste,"vantagem")
		e=R.resolver(rng(),m,conj({id="c"}),{a},{})[1];t.eq(#e.resistencia.d20.dados,1)
	end,
	["A17 primeiro ataque soma um dado da arma sem repetir fixos"] = function(t)
		local e=R.resolver(rng(),{tipo="ataque",arma=true,partes={{arma=true,bc=true}}},conj({primeiroAtaque=true}),{alvo()},{})[1]
		t.eq(e.ataque.d20.ajuste,"vantagem");t.eq(e.dano.total,8);t.eq(#e.dano.partes,2)
	end,
	["A17 primeiro ataque não concede abertura ao segundo disparo nem ao segundo alvo"] = function(t)
		local m={tipo="ataque",arma=true,partes={{arma=true,bc=true}},segundoDisparo={{arma=true,bc=true}}}
		local e=R.resolver(rng(),m,conj({primeiroAtaque=true}),{alvo()},{})[1]
		t.eq(e.ataque.d20.ajuste,"vantagem");t.eq(e.segundoAtaque.d20.ajuste,"normal");t.eq(e.dano.total,13)
		m.segundoDisparo=nil
		local es=R.resolver(rng(),m,conj({primeiroAtaque=true}),{alvo(),alvo({id="c"})},{})
		t.eq(es[1].dano.total,8);t.eq(es[2].dano.total,5);t.eq(es[2].ataque.d20.ajuste,"normal")
	end,
	["A17 marca concede um ponto no acerto por alvo"] = function(t)
		local e=R.resolver(rng(),{tipo="ataque",arma=true},conj(),{alvo({bonusContraMarcado=1})},{})[1]
		t.eq(e.ataque.bonus,3)
	end,
	["A17 Condutor usa maior frio uma vez, sem dobrar extra, antes de resistência"] = function(t)
		local m={tipo="efeito",semTeste=true,partes={{dados="1d4",tipo="frio"},{dados="1d8",tipo="frio"},{fixo=2,tipo="contundente"}}}
		local e=R.resolver(rng(),m,conj({condutorDeGelo=true}),{alvo({condicoes={molhado=1}})},{})[1]
		t.eq(e.dano.total,17);t.eq(#e.dano.partes,3);t.eq(e.dano.partes[2].formula,"1d8")
		e=R.resolver(rng(),m,conj({condutorDeGelo=true}),{alvo({condicoes={molhado=1},resistencias={"frio"}})},{})[1]
		t.eq(e.dano.total,9)
		e=R.resolver(rng(),m,conj({condutorDeGelo=true}),{alvo({condicoes={molhado=1},imunidades={"frio"}})},{})[1]
		t.eq(e.dano.total,2)
	end,
	["A17 Condutor não inventa frio nem extra contra alvo seco"] = function(t)
		local m={tipo="efeito",semTeste=true,partes={{dados="1d8",tipo="frio"}}}
		t.eq(R.resolver(rng(),m,conj({condutorDeGelo=true}),{alvo()},{})[1].dano.total,3)
		m.partes={{dados="1d8",tipo="ígneo"}}
		t.eq(R.resolver(rng(),m,conj({condutorDeGelo=true}),{alvo({condicoes={molhado=1}})},{})[1].dano.total,3)
	end,
}
