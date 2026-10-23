local Shared = game:GetService("ReplicatedStorage").Shared
local B=require(Shared.Brotos)
local S=require(Shared.SalaRegras)
local function sala(n)
	local r=S.new({a=true,b=true,c=true});for id=1,n do r.entrar(id,"Pessoa "..id) end;return r
end
local function aplicar(r,id,a,p) return r.aplicar(id,a,p,0,false) end
return {
	["Brotos enumera 216 resultados e preserva hierarquia"] = function(t)
		local cont={};local min,max={},{}
		for a=1,6 do for b=1,6 do for c=1,6 do
			local r=B.avaliar({a,b,c});cont[r.categoria]=(cont[r.categoria] or 0)+1;min[r.categoria]=math.min(min[r.categoria] or math.huge,r.pontos);max[r.categoria]=math.max(max[r.categoria] or 0,r.pontos)
		end end end
		t.eq(cont.Trio,6);t.eq(cont["Sequência"],24);t.eq(cont.Dupla,90);t.eq(cont["Sem combinação"],96)
		t.ok(min.Trio>max["Sequência"]);t.ok(min["Sequência"]>max.Dupla);t.ok(min.Dupla>max["Sem combinação"])
		t.ok(B.avaliar({1,1,1}).pontos>B.avaliar({6,6,6}).pontos);t.ok(B.avaliar({4,5,6}).pontos>B.avaliar({3,4,5}).pontos)
		t.eq(B.avaliar({0,1,1}),nil);t.eq(B.avaliar({1,2,0/0}),nil);t.eq(B.avaliar({1,2}),nil)
	end,
	["seis vagas incluem mestre e excedentes exigem autorizacao ate dez"] = function(t)
		local r=sala(11);t.eq(r.estado.mestre,1)
		for id=1,6 do t.ok(r.estado.pessoas[id].admitido) end;t.eq(r.estado.pessoas[7].admitido,false)
		t.ok(aplicar(r,2,"admitir",{userId=7}));for id=7,10 do t.eq(aplicar(r,1,"admitir",{userId=id}),nil) end;t.ok(aplicar(r,1,"admitir",{userId=11}))
		t.eq(r.publico().pessoas[1].lugar,1)
	end,
	["reserva exclusiva copia autorizada e troca libera ficha anterior"] = function(t)
		local r=sala(3);t.eq(aplicar(r,1,"escolher",{id="a"}),nil);t.ok(aplicar(r,2,"escolher",{id="a"}));t.ok(aplicar(r,2,"copia",{id="a"}));t.eq(aplicar(r,1,"copia",{id="a"}),nil);t.eq(aplicar(r,2,"escolher",{id="a"}),nil);t.ok(aplicar(r,3,"escolher",{id="a"}));t.eq(aplicar(r,1,"escolher",{id="b"}),nil);t.eq(aplicar(r,3,"escolher",{id="a"}),nil)
	end,
	["metade arredondada para cima e mestre confirma ao iniciar"] = function(t)
		local r=sala(5);for id=1,5 do aplicar(r,1,"copia",{id="a"});aplicar(r,id,"escolher",{id="a"}) end
		t.eq(select(1,r.podeIniciar(1)),nil);aplicar(r,2,"pronto",{ativo=true});t.eq(select(1,r.podeIniciar(1)),nil);aplicar(r,3,"pronto",{ativo=true});t.eq(#r.podeIniciar(1),5);t.eq(select(1,r.podeIniciar(2)),nil)
		t.eq(aplicar(r,1,"configurar",{modo="duelo",nivel=1,monstros=false}),nil);t.eq(r.estado.pessoas[2].pronto,false);t.ok(aplicar(r,2,"equipe",{userId=1,equipe=1}))
	end,
	["transferencia troca permissao e lugar; ativo bloqueia configuracao"] = function(t)
		local r=sala(2);t.eq(aplicar(r,1,"transferir",{userId=2}),nil);t.eq(r.estado.mestre,2);t.eq(r.publico().pessoas[2].lugar,1);t.ok(aplicar(r,1,"configurar",{modo="luta",nivel=1,monstros=false}));t.ok(r.aplicar(2,"configurar",{modo="luta",nivel=1,monstros=false},0,true))
	end,
	["sucessao empate repete somente empatados e rejeita dados do cliente"] = function(t)
		local r=sala(4);r.sair(1,0);for id=2,4 do t.eq(aplicar(r,id,"candidatar",{sim=true}),nil) end;r.atualizar(12,function() return 1 end);t.eq(r.estado.eleicao.fase,"rolagem")
		for id=2,4 do local valor=if id==4 then 6 else 1;r.rolar(id,function() return valor end) end;r.atualizar(13,function() return 1 end)
		t.eq(r.estado.eleicao.rodada,2);t.eq(r.estado.eleicao.candidatos[4],nil);t.ok(r.rolar(4,function() return 1 end));r.rolar(2,function() return 1 end);r.rolar(3,function() return 6 end);r.atualizar(14,function() return 1 end);t.eq(r.estado.mestre,2);t.eq(r.estado.eleicao,nil)
	end,
	["nenhum voluntario aguarda e candidato unico assume sem disputa"] = function(t)
		local r=sala(2);r.sair(1,0);r.atualizar(12,function() return 1 end);t.eq(r.estado.mestre,nil);t.eq(r.estado.eleicao.fim,nil);r.aplicar(2,"candidatar",{sim=true},20,false);r.atualizar(32,function() return 1 end);t.eq(r.estado.mestre,2)
	end,
	["monstros nao exigem ficha do mestre e pvp exige lados adversarios"] = function(t)
		local r=sala(2);aplicar(r,1,"configurar",{modo="luta",nivel=1,monstros=true});aplicar(r,2,"escolher",{id="a"});t.eq(#r.podeIniciar(1),1)
		aplicar(r,1,"configurar",{modo="duelo",nivel=1,monstros=false});aplicar(r,1,"escolher",{id="b"});for id=1,2 do aplicar(r,1,"equipe",{userId=id,equipe=1}) end;t.eq(select(1,r.podeIniciar(1)),nil);aplicar(r,1,"equipe",{userId=2,equipe=2});t.eq(#r.podeIniciar(1),2)
	end,
}
