local L=require(game:GetService("ReplicatedStorage").Shared.SalaLancamento)
local P=require(game:GetService("ReplicatedStorage").Shared.PapelSolto)
return {
	["largar dados nao adiciona impulso e arremessar continua limitado"]=function(t)
		local d={direcao={x=0,y=.5,z=1},forca=.65,soltar=true};local v=L.validar(d);t.eq(v.velocidade,0);t.eq(v.subida,0)
		d.soltar=false;v=L.validar(d);t.ok(v.velocidade>15 and v.velocidade<=23);t.ok(v.subida>5)
		for _,s in {0,1,"true",{}} do d.soltar=s;t.eq(L.validar(d),nil) end
	end,
	["largada de papel cai no mesmo lugar sem impulso do arremesso"]=function(t)
		local o={x=250,y=6,z=-5};local d={x=1,y=0,z=0};local a=P.criar(o,d,.65,0,true)
		t.eq(a.velocidade.x,0);t.eq(a.velocidade.y,0);t.eq(a.velocidade.z,0)
		local p,_,pousou=P.posicao(a,4);t.eq(p.x,250);t.eq(p.z,-5);t.eq(pousou,true)
		local b=P.criar(o,d,.65,0,false);t.ok(b.velocidade.x>15);t.ok(P.posicao(b,.15).x>252)
		t.eq(P.criar(o,d,.65,0,"sim"),nil)
	end,
}
