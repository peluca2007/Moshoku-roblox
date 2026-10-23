local Shared = game:GetService("ReplicatedStorage").Shared
local B=require(Shared.BrotosRecreativo)
local P=require(Shared.PapelSolto)
local S=require(Shared.SalaRegras)
local Prep=require(Shared.PreparacaoSala)
return {
	["leitura arrastada e girada cabe em tela estreita"] = function(t)
		local L=require(Shared.SalaLeitura)
		for _,aspecto in {.25,.4,1,1.5,2.8} do for _,fov in {40,70,100} do
			for passo=-8,8 do for _,x in {-.8,0,.8} do for _,y in {-.65,0,.65} do
				local r=L.calcular(2.6,2.3,aspecto,fov,passo*math.pi/8,x,y,2.1)
				t.ok(math.abs(r.x)+r.largura/2<=r.limiteX+.00001)
				t.ok(math.abs(r.y)+r.altura/2<=r.limiteY+.00001)
				t.ok(r.distancia<=1.2+.00001 and r.escala>0 and r.escala<=1)
			end end end
		end end
	end,
	["placar ordena resultados sem alterar a rodada"] = function(t)
		local A=require(Shared.ApresentacaoBrotos)
		local r={serial=2,dados={[2]={6,6,6},[1]={1,1,1},[3]={4,5,6}},vencedores={1}}
		local l=A.linhas(r,{{id=1,nome="A"},{id=2,nome="B"},{id=3,nome="C"}},true)
		t.ok(l[3]:find("A:",1,true)==1);t.ok(l[4]:find("B:",1,true)==1);t.eq(l[#l],"Venceu: A");t.eq(r.dados[2][1],6)
	end,
	["Brotos social nao repete dados e preserva empates"] = function(t)
		local r=B.new();t.eq(r.abrir({},0),"Não há participantes na sala.")
		t.eq(r.abrir({1,2,3},0),nil);t.ok(r.abrir({1},0));t.ok(r.rolar(4,function() return 1 end))
		t.eq(r.rolar(1,function() return 1 end),nil);t.ok(r.rolar(1,function() return 6 end));r.rolar(2,function() return 1 end)
		t.eq(r.atualizar(14,function() return 6 end),false);t.eq(r.atualizar(15,function() return 6 end),true)
		local s=r.publico();t.eq(s.fase,"resultado");t.eq(#s.vencedores,2);t.eq(s.vencedores[1],1);t.eq(s.vencedores[2],2);t.eq(s.dados[3][1],6)
		t.eq(r.abrir({2},16),nil);t.eq(r.publico().serial,2)
	end,
	["saida libera rodada e exclui dados do ausente"] = function(t)
		local r=B.new();r.abrir({1,2},0);r.rolar(1,function() return 2 end);r.sair(2,1,function() return 6 end)
		t.eq(r.publico().fase,"resultado");t.eq(r.publico().vencedores[1],1);t.eq(r.publico().dados[2],nil)
	end,
	["arremesso rejeita vetores invalidos e nao recebe origem externa"] = function(t)
		local o={x=250,y=5,z=-12}
		for _,d in {{x=0,y=0,z=0},{x=0/0,y=1,z=0},{x=math.huge,y=0,z=0},{x=4,y=0,z=0}} do t.eq(P.criar(o,d,.5,0),nil) end
		t.eq(P.criar(o,{x=0,y=1,z=0},-1,0),nil);t.eq(P.criar(o,{x=0,y=1,z=0},0/0,0),nil)
	end,
	["papeis pousam sem sair da sala e ficam estaveis"] = function(t)
		for _,d in {{x=0,y=0,z=1},{x=1,y=1,z=0},{x=-1,y=-1,z=0},{x=0,y=0,z=-1}} do
			local r=P.criar({x=250,y=5,z=-12},d,1,10);t.ok(r)
			for i=0,100 do local p=P.posicao(r,10+i*.1);t.ok(p.x>=231 and p.x<=269 and p.z>=-18 and p.z<=18 and p.y>=.12) end
			local a,_,fim=P.posicao(r,20);local b=P.posicao(r,30);t.ok(fim);t.eq(a.x,b.x);t.eq(a.y,b.y);t.eq(a.z,b.z)
		end
	end,
	["checklist e inicio compartilham pendencias reais"] = function(t)
		local r=S.new({a=true,b=true});r.entrar(1,"Mestre");r.entrar(2,"Jogador")
		local info=Prep.resumo(r.publico());t.eq(info.podeIniciar,false);t.eq(#info.pendencias,2)
		r.aplicar(1,"escolher",{id="a"},0,false);r.aplicar(2,"escolher",{id="b"},0,false)
		t.ok(Prep.resumo(r.publico()).podeIniciar);t.eq(#r.podeIniciar(1),2)
		r.aplicar(1,"configurar",{modo="duelo",nivel=1,monstros=false},0,false)
		for id=1,2 do r.aplicar(1,"equipe",{userId=id,equipe=1},0,false) end
		t.eq(Prep.resumo(r.publico()).podeIniciar,false);t.ok(select(2,r.podeIniciar(1)))
	end,
}
