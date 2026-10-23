local Shared = game:GetService("ReplicatedStorage").Shared
local B = require(Shared.Regras.Barreiras)
local A = require(Shared.Regras.Agarrar)
local D = require(Shared.Regras.Desarme)
local H = require(Shared.Regras.Habilidades)
local function rng(lista)
	local fila = table.clone(lista)
	return { NextInteger = function(_, lo, hi) return math.clamp(table.remove(fila, 1) or 3, lo, hi) end }
end
return {
	["barreira intercepta a primeira casa física; magia atravessa"] = function(t)
		local z = { pv = 40, casas = { ["2:1"] = true } }
		local chave = function(x,y) return x .. ":" .. y end
		t.eq(B.intercepta({z}, {{2,1},{3,1}}, chave, true), z)
		t.eq(B.intercepta({z}, {{2,1}}, chave, false), nil)
		t.eq(B.ferir(z, 15), false); t.eq(z.pv,25)
		t.eq(B.ferir(z, 50), true); t.eq(z.pv,0)
		t.eq(B.intercepta({z}, {{2,1}}, chave, true), nil)
	end,
	["agarrão: empate conserva situação e naturais não vencem bônus"] = function(t)
		local venceu, total = A.disputa(rng({20,1}),0,30)
		t.eq(venceu,false); t.eq(total,20)
		t.eq(A.disputa(rng({10,10}),3,3),false)
		t.eq(A.disputa(rng({10,9}),3,3),true)
	end,
	["sustentação exige fonte viva; agarrão físico exige adjacência"] = function(t)
		t.eq(A.valido({}, {pv=10}, {pv=10}, 2),false)
		t.eq(A.valido({sustenta=true}, {pv=10}, {pv=10}, 12),true)
		t.eq(A.valido({sustenta=true}, {pv=0}, {pv=10}, 12),false)
	end,
	["desarme recupera a mesma referência sem duplicar o inventário"] = function(t)
		local item = {type="arma",name="Espada",equipped=true}
		local ficha = {construction={inventory={item}}}
		D.largar(item); t.eq(D.arma(ficha),nil)
		D.pegar(ficha,item); t.eq(D.arma(ficha),item); t.eq(#ficha.construction.inventory,1)
		t.eq(D.danoDaCriatura(17,true),8); t.eq(D.danoDaCriatura(17,false),17)
	end,
	["barreira imóvel recebe dano no 1 sem crítico nem efeitos de criatura"] = function(t)
		local e = H.resolver(rng({1,4}), {tipo="ataque",partes={{dados="1d8"}},efeitoNoAcerto={resistencia={atributo="forca",cdBase=8},desarmar=true}},
			{bc=0,pv=10,pvMax=10,condicoes={}},{{id="z",ca=10,condicoes={},barreira=true,resistencia=function() return 0 end}}, {})[1]
		t.eq(e.ataque.acertou,true); t.eq(e.ataque.critico,false); t.eq(e.dano.total,4); t.eq(e.desarmar,nil)
	end,
	["punhos acertam agarrado mesmo no 1 e desvantagem contra outros tem fonte"] = function(t)
		local alvo = {id="b",ca=99,condicoes={},acertoDesarmadoAutomatico=true,resistencia=function() return 0 end}
		local e = H.resolver(rng({1,1,3}),{tipo="ataque",partes={{dados="1d6"}}}, {bc=0,pv=10,pvMax=10,condicoes={},agarradoPor="a"},{alvo},{})[1]
		t.eq(e.ataque.acertou,true); t.eq(#e.ataque.d20.dados,2); t.eq(e.dano.total,3)
	end,
}
