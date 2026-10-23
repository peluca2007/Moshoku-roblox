local Shared = game:GetService("ReplicatedStorage").Shared
local A = require(Shared.AreaHabilidade)
local P = require(Shared.PlanejamentoArea)
local C = require(Shared.Regras.Combate)
local U = require(Shared.Regras.Utilidades)
local F = require(Shared.Regras.Fogo)
local function livre() return false end
local fonte={x=10,z=10}
local muro=F.MECANICAS["ability/fogo/Principiante/muro-de-chamas"]
return {
	["linha ajustavel permite uma a seis casas em oito direcoes"] = function(t)
		for _,d in {{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,-1},{1,-1},{-1,1}} do
			for n=1,6 do
				local casas,erro=A.zona(fonte,muro,{inicioX=11,inicioZ=10,x=11+d[1]*(n-1),z=10+d[2]*(n-1)},livre,livre)
				t.eq(erro,nil);t.eq(#casas,n)
			end
		end
	end,
	["desenhos adulterados paredes e comprimento extra recusados"] = function(t)
		for _,p in {{inicioX=11,inicioZ=10,x=18,z=10},{inicioX=11,inicioZ=10,x=14,z=11},{inicioX=15,inicioZ=10,x=16,z=10},{inicioX="11",inicioZ=10,x=12,z=10},{inicioX=11,inicioZ=10,x=21,z=10}} do
			t.eq(A.zona(fonte,muro,p,livre,livre),nil)
		end
		t.eq(A.zona(fonte,muro,{inicioX=11,inicioZ=10,x=14,z=10},function(x) return x==12 end,livre),nil)
		t.eq(A.zona(fonte,muro,{inicioX=11,inicioZ=10,x=14,z=13},function(x,z) return x==12 and z==10 end,livre),nil)
		t.eq(A.zona(fonte,{tipo="zona",forma="casa"},{inicioX=11,inicioZ=10,x=12,z=10},livre,livre),nil)
	end,
	["planejamento requer inicio fim e nao modifica intencao anterior"] = function(t)
		local m={habilidadeId="muro"};local inicio=P.escolher(m,muro,11,10)
		t.eq(m.inicio,nil);t.eq(P.pedido(inicio),nil)
		local fim=P.escolher(inicio,muro,11,20);local p=P.pedido(fim)
		t.eq(p.x,11);t.eq(p.z,15);t.eq(p.inicioX,11);t.eq(inicio.ponto,nil)
	end,
	["previa distingue circulo cone e linha transversal"] = function(t)
		local circulo=A.previa(fonte,{alvo="esferaNoConjurador",raioCasas=2},{},livre,livre)
		t.eq(#circulo,13)
		local cone=A.previa(fonte,{alvo="cone",comprimentoCasas=2},{x=12,z=10},livre,livre)
		for _,c in cone do t.ok(c[1]>10);t.ok(math.abs(c[2]-10)<=c[1]-10) end
		local linha=A.previa(fonte,{tipo="zona",forma="linhaTransversal",alcanceCasas=4,comprimentoCasas=3},{x=12,z=10},livre,livre)
		t.eq(#linha,3);for _,c in linha do t.eq(c[1],12) end
		t.eq(#A.previa(fonte,{alvo="adjacentes"},{},function() return true end,function() return true end),8)
	end,
	["supercobertura fecha cantos e e simetrica"] = function(t)
		local function parede(x,z) return x==11 and z==10 end
		t.eq(C.temVisao(10,10,12,12,parede),false)
		t.eq(C.temVisao(12,12,10,10,parede),false)
		t.eq(C.temVisao(10,10,12,12,livre),true)
		local function obstaculo(x,z) return (x==3 and z==4) or (x==4 and z==3) end
		for x=1,8 do for z=1,8 do t.eq(C.temVisao(2,2,x,z,obstaculo),C.temVisao(x,z,2,2,obstaculo)) end end
	end,
	["supercobertura inclui casa atravessada omitida por bresenham"] = function(t)
		t.eq(C.temVisao(1,1,4,2,function(x,z) return x==3 and z==1 end),false)
		t.eq(C.temVisao(1,1,4,1,function(x,z) return x==2 and z==1 end),false)
		t.eq(C.temVisao(1,1,2,1,function() return true end),true)
	end,
	["esconder somente para rank de furtividade"] = function(t)
		local f={construction={unlockedRankIds={},purchasedIds={}}}
		t.eq(table.find(U.cartasDe(f),"mesa/esconder"),nil)
		f.construction.unlockedRankIds={"rank/furtividade-e-armadilhas/Principiante"}
		t.ok(table.find(U.cartasDe(f),"mesa/esconder")~=nil)
	end,
}
