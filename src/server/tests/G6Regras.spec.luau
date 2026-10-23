local Shared = game:GetService("ReplicatedStorage").Shared
local V = require(Shared.VisaoFurtiva)
local H = require(Shared.Regras.Habilidades)
local B = require(Shared.BalanceamentoJogo)
local D = require(Shared.DescricaoHabilidade)
local A = require(Shared.ApresentacaoAcoes)
return {
	["G6 Caído permite agir; incapacitação e zero têm motivos distintos"] = function(t)
		local token={id="a",pv=10,conditions={{id="caido"}}}
		t.eq(A.motivo({acoes=1},nil,token,nil,"x"),nil)
		token.conditions={{id="atordoado"}};t.eq(A.motivo({acoes=1},nil,token,nil,"x"),"Atordoado • sem Ações")
		token.pv=0;t.eq(A.motivo({acoes=1},nil,token,nil,"x"),"0 PV • precisa de cura")
	end,
	["G6 visão curta: frente, costas, borda, diagonal e alcance"] = function(t)
		local o = {x=5,z=5,olharX=1,olharZ=0}
		local livre = function() return false end
		t.ok(V.contem(o,9,5,livre)); t.ok(not V.contem(o,10,5,livre))
		t.ok(not V.contem(o,4,5,livre)); t.ok(not V.contem(o,5,6,livre))
		t.ok(V.contem(o,7,7,livre)); t.ok(not V.contem(o,7,8,livre))
		V.virar(o,5,8); t.ok(V.contem(o,5,8,livre)); t.ok(not V.contem(o,8,5,livre))
		V.virar(o,5,5); t.eq(o.olharZ,1)
	end,
	["G6 visão: obstáculos, cego, inconsciente e derrotado não vigiam"] = function(t)
		local o = {x=5,z=5,olharX=1,olharZ=0,pv=10}
		t.ok(not V.contem(o,8,5,function(x) return x==6 end))
		for _, id in {"cego","inconsciente"} do o.conditions={{id=id}}; t.ok(not V.contem(o,7,5,function() return false end)) end
		o.conditions={}; o.pv=0; t.ok(not V.contem(o,7,5,function() return false end))
		o.pv=10; o.derrotado=true; t.ok(not V.contem(o,7,5,function() return false end))
	end,
	["G6 balanceamento: perfil não altera a mesa e chances enumeradas são 70 e 55 por cento"] = function(t)
		t.eq(B.acerto({}),0); t.eq(B.cd({}),0)
		local acertos, efeitos = 0, 0
		for d=1,20 do
			local rng={NextInteger=function() return d end}
			local c={bc=3,pv=10,pvMax=10,condicoes={},bonusAcertoJogo=B.acerto({balanceamentoJogo=true}),bonusCDJogo=B.cd({balanceamentoJogo=true})}
			local alvo={id="b",ca=12,condicoes={},resistencia=function() return 2 end}
			local a=H.resolver(rng,{tipo="ataque",partes={}},c,{alvo},{})[1]
			if a.ataque.acertou then acertos+=1 end
			t.eq(a.ataque.critico,d==20)
			local e=H.resolver(rng,{tipo="efeito",resistencia={atributo="forca",cdBase=8},aplica="caido"},c,{alvo},{})[1]
			t.eq(e.resistencia.cd,14)
			if not e.resistencia.passou then efeitos+=1 end
		end
		t.eq(acertos,14); t.eq(efeitos,11)
	end,
	["G6 consulta: dano, alcance, CD, bônus e consequência do arremesso"] = function(t)
		local s=D.texto({tipo="ataque",arma=true,desarmaConjurador=true,alcanceCasas=12,partes={{arma=true,bc=true}},efeitoNoAcerto={resistencia={atributo="forca",cdBase=8,cdAtributo="agilidade"}}},{balanceamentoJogo=true})
		for _, texto in {"12 casas (18 m)","dado da arma","+ 2 do jogo","CD 11 + agilidade + Rank","acertando ou errando"} do t.ok(string.find(s,texto,1,true)~=nil,s) end
	end,
}
