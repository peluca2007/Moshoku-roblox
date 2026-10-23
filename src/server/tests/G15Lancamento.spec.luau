local L=require(game:GetService("ReplicatedStorage").Shared.SalaLancamento)
return {
	["trio nas maos cabe em largura e altura com profundidade em telas e FOV distintos"]=function(t)
		local M=require(game:GetService("ReplicatedStorage").Shared.SalaDadosMao)
		for _,aspecto in {.25,.4,.7,1,1.5,2.8} do for _,fov in {40,70,100} do
			local s=M.escala(aspecto,fov);local perto=1.6-.42*s;local meiaAltura=math.tan(math.rad(fov/2))*perto
			t.ok(s>0 and s<=1);t.ok((1.14+.42)*s<=meiaAltura*aspecto*.9+.00001);t.ok((.55+.42)*s<=meiaAltura*.9+.00001)
		end end
	end,
	["saida durante quique nao sorteia por timeout antes do pouso"]=function(t)
		local B=require(game:GetService("ReplicatedStorage").Shared.BrotosRecreativo);local b=B.new();local n=0;b.abrir({1,2},0)
		b.sair(2,20,function() n+=1;return 6 end,true);t.eq(n,0);t.eq(b.publico().fase,"rolagem");b.rolar(1,function() return 2 end);b.atualizar(20,function() n+=1;return 6 end);t.eq(n,0);t.eq(b.publico().dados[1][1],2)
	end,
	["lancamento rejeita campos ausentes NaN infinito e forca fora dos limites"]=function(t)
		for _,d in {false,{}, {direcao={},forca=.5},{direcao={x=1,y=0},forca=.5},{direcao={x=0,y=0,z=0},forca=.5},{direcao={x=0/0,y=0,z=1},forca=.5},{direcao={x=math.huge,y=0,z=1},forca=.5},{direcao={x=0,y=0,z=1},forca=0/0},{direcao={x=0,y=0,z=1},forca=2},{direcao={x=0,y=0,z=1},forca=-1},{direcao={x=1,y="a",z=1},forca=.5}} do t.eq(L.validar(d),nil) end
	end,
	["servidor normaliza direcao e limita energia ignorando origem e velocidade do cliente"]=function(t)
		local r=L.validar({direcao={x=1,y=1,z=0},forca=1,velocidade=10000,origem={x=0,y=0,z=0}})
		t.ok(math.abs(r.x*r.x+r.y*r.y-1)<.00001);t.eq(r.velocidade,23);t.eq(r.subida,12);t.eq(r.origem,nil)
		local fraco=L.validar({direcao={x=0,y=0,z=-1},forca=0});t.eq(fraco.velocidade,9);t.eq(fraco.subida,5)
	end,
}
