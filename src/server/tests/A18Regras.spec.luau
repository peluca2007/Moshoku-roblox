local Shared = game:GetService("ReplicatedStorage").Shared
local E = require(Shared.Regras.Equipes)
local C = require(Shared.Regras.Chefes)
local Dados = require(Shared.Livro.Dados.Criaturas)
local Catalogo = { POR_ID = {} }
for _, c in Dados do Catalogo.POR_ID[c.id] = c end
local Criaturas = require(Shared.Regras.Criaturas)
local function token(id,dono,pv,x,z) return {id=id,ownerUserId=dono,pv=pv or 10,x=x or 10,z=z or 10} end
return {
	["fila recusa tipos valores e chaves extras"] = function(t)
		for _,p in {false,1,"duelo",{}, {modo="x"},{modo="duelo",equipe="1"},{modo="duelo",equipe=false},{modo="duelo",equipe=3},{modo="duelo",equipe=0/0},{modo="luta",equipe=1},{modo="sair",equipe=0},{modo="duelo",ownerUserId=2}} do t.ok(E.validarFila(p)~=nil) end
	end,
	["fila aceita tres lados e modos antigos"] = function(t)
		for _,e in {0,1,2} do t.eq(E.validarFila({modo="duelo",equipe=e}),nil) end
		for _,m in {"sair","luta","duelo"} do t.eq(E.validarFila({modo=m}),nil) end
	end,
	["iniciar PvP nao aceita campos de autoridade"] = function(t) t.eq(E.validarDuelo({}),nil); t.ok(E.validarDuelo({equipes={}})~=nil) end,
	["aliado vem da equipe incluindo invocado"] = function(t)
		local e={[1]=1,[2]=1,[3]=2}
		t.ok(E.aliados(token("a",1),token("b",2),e)); t.ok(not E.aliados(token("a",1),token("c",3),e))
		t.ok(E.aliados(token("inv",2),token("a",1),e))
	end,
	["sem equipe mantem todos contra todos e mesmo dono aliado"] = function(t)
		local e={[1]=0,[2]=0}; t.ok(not E.aliados(token("a",1),token("b",2),e)); t.ok(E.aliados(token("a",1),token("inv",1),e))
	end,
	["npc e espectadores nao formam alianca"] = function(t)
		local e={[1]=1}; t.ok(not E.aliados(token("a",1),token("b",2),e)); t.eq(E.lado(token("npc",0),e),nil)
	end,
	["vitoria conta lados vivos e invocado sustenta equipe"] = function(t)
		local e={[1]=1,[2]=1,[3]=2}
		local ts={token("a",1,0),token("b",2,10),token("c",3,0),token("inv",3,10)}
		t.eq(#E.dePe(ts,e),2); ts[4].pv=0; t.eq(E.dePe(ts,e)[1],"e:1"); ts[2].pv=0; t.eq(#E.dePe(ts,e),0)
	end,
	["derrotado boneco e IA nao sustentam lado"] = function(t)
		for _,flag in {"derrotado","boneco","ia"} do local a=token("a",1); a[flag]=true; t.eq(#E.dePe({a},{[1]=1}),0) end
	end,
	["lados desiguais e mistos exigem adversario"] = function(t)
		local g={{UserId=1},{UserId=2},{UserId=3}}; t.ok(E.temOponentes(g,{[1]=1,[2]=1,[3]=2})); t.ok(not E.temOponentes(g,{[1]=1,[2]=1,[3]=1})); t.ok(E.temOponentes(g,{[1]=1,[2]=1,[3]=0}))
	end,
	["32 participantes cabem sem colisao em qualquer lado"] = function(t)
		for _,modo in {0,1,2,3} do
			local g,e={},{}; for i=1,32 do table.insert(g,{UserId=i}); e[i]=if modo==3 then i%3 else modo end
			local visto={}; for _,c in E.casas(g,e) do
				t.ok(c[1]>=1 and c[1]<=20 and c[2]>=1 and c[2]<=20); local k=c[1]..":"..c[2]; t.ok(not visto[k]); visto[k]=true
			end
		end
	end,
	["niveis validam tipo inteiros e ausencia"] = function(t)
		t.eq(C.validarNivel({},false),1)
		for _,n in {false,"1",0,4,1.5,0/0} do local nivel,erro=C.validarNivel({nivel=n},false); t.eq(nivel,nil); t.ok(erro) end
		for n=1,3 do t.eq(C.validarNivel({nivel=n},false),n) end
	end,
	["desafio recusa autoridade enviada pelo cliente"] = function(t)
		for _,p in {{pv=999},{encontro="bando"},{nivel=3,chefao="x"}} do local n=C.validarNivel(p,false); t.eq(n,nil) end
		t.eq(C.validarNivel({encontro="bando"},true),1)
	end,
	["desafios escalam de um a quatro sem inventar fichas"] = function(t)
		for n=1,4 do
			t.eq(C.desafio(1,n).nivel,1)
			local d2,d3=C.desafio(2,n),C.desafio(3,n)
			t.ok(#d2.criaturas>=n+1); t.eq(#d3.criaturas,n)
			for _,d in {d2,d3} do for _,c in d.criaturas do t.eq(Catalogo.POR_ID[c[1]].kind,"creature") end end
		end
		t.eq(C.desafio(3,5),nil); t.eq(C.desafio(4,1),nil)
	end,
	["Treant preserva patamar e papel chefe do livro"] = function(t)
		local f=Criaturas.ficha(Catalogo.POR_ID[C.ID]); local p=Criaturas.aplicarPapel(3,"chefe")
		t.eq(f.patamar,3); t.eq(f.papel,"chefe"); t.eq(f.pvMax,p.pv); t.eq(f.danoPorTurno,p.danoPorTurno)
	end,
	["fases mudam exatamente em 60 e 30 por cento"] = function(t)
		t.eq(C.fase(61,100),1); t.eq(C.fase(60,100),2); t.eq(C.fase(31,100),2); t.eq(C.fase(30,100),3); t.eq(C.fase(0,0),3)
	end,
	["padroes quadrado cruz e furia com centro congelado"] = function(t)
		local chefe={pv=100,pvMax=100}; local alvo=token("a",1,10,10,10)
		local a=C.preparar(chefe,alvo,1,20,20); t.eq(#a.casas,9)
		chefe.pv=50; local b=C.preparar(chefe,alvo,2,20,20); t.eq(#b.casas,5)
		chefe.pv=20; local c=C.preparar(chefe,alvo,3,20,20); t.eq(#c.casas,25)
		alvo.x=18; t.eq(a.x,10); t.eq(#C.alvos(a,{alvo}),0)
	end,
	["avisos respeitam bordas e alvos vivos"] = function(t)
		local a=C.preparar({pv=1,pvMax=100},token("a",1,10,1,1),1,20,20); t.eq(#a.casas,9)
		local mortos=token("m",1,0,1,1); local npc=token("n",0,10,1,1)
		t.eq(#C.alvos(a,{mortos,npc,token("v",1,10,1,1)}),1)
	end,
}
