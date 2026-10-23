local Shared = game:GetService("ReplicatedStorage").Shared
local F = require(Shared.Regras.Formulas)
local P = require(Shared.Regras.Progressao)
local function ficha(rank, escola, talentos)
	local ids = { P.idDoRank("teorica", rank or "Principiante") }
	if escola then table.insert(ids, P.idDoRank(escola, "Principiante")) end
	return { construction = { unlockedRankIds = ids, purchasedIds = talentos or {} } }
end
local function pedido(e,v,f,p) return { essencia=e or "mana",verbo=v or "lancar",forma=f or "circulo",potencia=p or "Principiante" } end
local specs = {}
specs["tabela do Cap.2 §8: números independentes dos cálculos"] = function(t)
	local linhas={{1,20,9,3,2},{2,40,18,6,2},{5,60,27,9,3},{6,80,45,12,3},{10,100,90,18,4},{12,120,150,30,4}}
	for i,rank in F.RANKS do
		local p=F.POTENCIA[rank]; local v=linhas[i]
		t.eq(p.pm,v[1]); t.eq(p.dados,v[1]); t.eq(p.pv,v[2]); t.eq(p.alcance,v[3]); t.eq(p.tamanho,v[4]); t.eq(p.acoes,v[5])
	end
end
for _,rank in F.RANKS do
	for essencia,e in F.ESSENCIAS do
		for verbo in F.VERBOS do
			for forma in F.FORMAS do
				specs[rank.." · "..essencia.." · "..verbo.." · "..forma] = function(t)
					local r,err=F.validar(ficha(rank,e.arvore),pedido(essencia,verbo,forma,rank))
					t.ok(r,err); local p=F.POTENCIA[rank]
					t.eq(r.pm,p.pm+(if essencia=="mana" then 0 else 1)+(if forma=="circulo" then 0 else 1))
					t.eq(r.acoes,p.acoes); t.eq(r.dados,p.dados)
					t.eq(r.fere,verbo=="lancar" and essencia~="vida"); t.eq(r.cura,verbo=="lancar" and essencia=="vida")
					if verbo=="erguer" then t.eq(r.pv,math.ceil(p.pv*(1+(if forma=="quadrado" then .5 else 0)+(if essencia=="terra" then .5 else 0)))) end
					t.eq(r.alcanceMetros,if verbo=="lancar" then math.floor(p.alcance*(if forma=="linha" then 1.5 else 1)/1.5)*1.5 else 1.5)
					t.ok(#r.descricao>0)
				end
			end
		end
	end
end
specs["recusa payload inválido, palavras desconhecidas e potência acima"] = function(t)
	for _,q in {false,{},pedido("raio"),pedido(nil,"explodir"),pedido(nil,nil,"estrela"),pedido(nil,nil,nil,"Deus"),pedido(nil,nil,nil,"Rei")} do
		local r,err=F.validar(ficha(),q); t.eq(r,nil); t.ok(err)
	end
	t.eq(F.validar(nil,pedido()),nil)
	t.eq(F.validar({construction={unlockedRankIds={},purchasedIds={}}},pedido()),nil)
end
specs["essências exigem origem aberta OU talento, não habilidade nem talento alheio"] = function(t)
	for id,e in F.ESSENCIAS do if id~="mana" then
		t.eq(F.validar(ficha(),pedido(id)),nil)
		t.ok(F.validar(ficha(nil,e.arvore),pedido(id)))
		t.ok(F.validar(ficha(nil,nil,{"talent/teorica/Principiante/simbolo-"..id}),pedido(id)))
		t.eq(F.validar(ficha(nil,nil,{"ability/teorica/Principiante/simbolo-"..id}),pedido(id)),nil)
	end end
end
specs["giz e bolso levam 60 segundos, ativam 1 Ação; Lançar nunca prepara"] = function(t)
	local f=ficha(nil,nil,{"talent/teorica/Principiante/simbolo-rejeitar"})
	for _,meio in {"giz","bolso"} do
		for _,v in {"erguer","selar","sinalizar"} do
			local r=F.validar(f,pedido(nil,v),meio); t.eq(r.preparoSegundos,60); t.eq(r.acoes,1)
			t.eq(r.duracaoRodadas,if v=="sinalizar" then 1 else 100)
		end
		t.eq(F.validar(f,pedido(),meio),nil)
		t.eq(F.validar(ficha(nil,"cura"),pedido("vida"),meio),nil)
	end
	t.eq(F.validar(ficha(),pedido(nil,"selar"),"bolso"),nil)
	t.eq(F.validar(f,pedido(nil,"selar"),"pedra"),nil)
end
specs["efeitos próprios de contato e adição Terra + Quadrado"] = function(t)
	local terra=F.validar(ficha(nil,"terra"),pedido("terra","erguer","quadrado")); t.eq(terra.pv,40)
	local fogo=F.validar(ficha("Avançado","fogo"),pedido("fogo","erguer",nil,"Avançado")); t.eq(fogo.contatoDados,3)
	local vida=F.validar(ficha(nil,"cura"),pedido("vida","erguer")); t.eq(vida.pvTemp,5)
	local mana=F.validar(ficha(),pedido(nil,"erguer")); t.eq(mana.contato,nil)
end
specs["qualidade não altera nenhuma regra e Quadrado não muda Lançar"] = function(t)
	local q=pedido(nil,nil,"quadrado"); q.qualidade=0/0
	local r=F.validar(ficha(),q); t.eq(r.pm,2); t.eq(r.dados,1); t.eq(r.acoes,2)
end
specs["régua Mana bloqueia igual, reduz um acima e deixa dois acima"] = function(t)
	local r=F.validar(ficha(),pedido(nil,"selar"))
	t.eq(F.fatorSelo(r,"Principiante","terra",true),0)
	t.eq(F.fatorSelo(r,"Intermediário","terra",true),.5)
	t.eq(F.fatorSelo(r,"Avançado","terra",true),1)
	t.eq(F.fatorSelo(r,"Principiante","terra",false),1)
	t.eq(F.fatorSelo(r,"errado","terra",true),nil)
end
specs["selo elemental ganha um rank mas só barra sua escola"] = function(t)
	local r=F.validar(ficha(nil,"fogo"),pedido("fogo","selar"))
	t.eq(F.fatorSelo(r,"Intermediário","fogo",true),0)
	t.eq(F.fatorSelo(r,"Avançado","fogo",true),.5)
	t.eq(F.fatorSelo(r,"Principiante","terra",true),1)
end
specs["concentração usa Espírito + metade para cima e rank do atacante, não dano"] = function(t)
	local random={NextInteger=function() return 8 end}
	local r=F.concentracao(random,2,3,3); t.eq(r.total,12); t.eq(r.cd,13); t.eq(r.passou,false)
	t.eq(F.concentracao(random,2,3,nil).passou,true)
	for pm=1,15 do t.eq(pm-F.reembolsoInterrupcao(pm),math.floor(pm/2)) end
end
specs["concentração com Desvantagem usa menor d20; sem críticos automáticos"] = function(t)
	local dados={20,1}; local random={NextInteger=function() return table.remove(dados,1) end}
	local r=F.concentracao(random,0,1,1,true); t.eq(r.dado,1); t.eq(r.passou,false)
	t.eq(F.concentracao({NextInteger=function() return 1 end},20,6,1).passou,true)
end
specs["mecânica de cura sem BC, parede com PV e selo sem colisão"] = function(t)
	local m=F.mecanica(F.validar(ficha(nil,"cura"),pedido("vida")))
	t.eq(m.tipo,"cura"); t.eq(m.partes[1].bc,false); t.eq(m.partes[1].dados,"1d8")
	m=F.mecanica(F.validar(ficha(),pedido(nil,"erguer","quadrado")))
	t.eq(m.pvZona,30); t.eq(m.comprimentoCasas,2); t.eq(m.bloqueiaMovimento,true); t.eq(m.bloqueiaVisao,nil)
	m=F.mecanica(F.validar(ficha(),pedido(nil,"selar"))); t.eq(m.pvZona,nil); t.eq(m.bloqueiaMovimento,false)
end
specs["selo reduz dados e área/duração, conserva BC/CD e não muda original"] = function(t)
	local m={partes={{dados="5d8",bc=true}},resistencia={cdBase=8},raioCasas=6,duracaoRodadas=10}
	local r=F.reduzirMecanica(m,.5)
	t.eq(r.partes[1].dados,"2d8"); t.eq(r.partes[1].bc,true); t.eq(r.resistencia.cdBase,8)
	t.eq(r.raioCasas,3); t.eq(r.duracaoRodadas,5); t.eq(m.partes[1].dados,"5d8")
	t.eq(F.reduzirMecanica({partes={{dados="1d8",bc=true}}},.5).partes[1].dados,nil)
	t.eq(F.reduzirMecanica({partes={{dados="1d8+4d6"}}},.5).partes[1].dados,"2d6")
end
local function caminho(vertices)
	local pts={}
	for i=1,#vertices-1 do for j=0,12 do
		local a,b=vertices[i],vertices[i+1]; table.insert(pts,{a[1]+(b[1]-a[1])*j/12,a[2]+(b[2]-a[2])*j/12})
	end end
	return pts
end
specs["traços reais: linha, quadrado, quadrado rotacionado, círculo"] = function(t)
	t.eq(F.reconhecer(caminho({{10,10},{170,90}})),"linha")
	t.eq(F.reconhecer(caminho({{20,20},{180,20},{180,180},{20,180},{20,20}})),"quadrado")
	t.eq(F.reconhecer(caminho({{100,10},{190,100},{100,190},{10,100},{100,10}})),"quadrado")
	local pts={}; for i=0,60 do local a=i/60*2*math.pi; table.insert(pts,{100+80*math.cos(a),100+80*math.sin(a)}) end
	t.eq(F.reconhecer(pts),"circulo")
end
specs["não reconhece clique, rabisco, triângulo, retângulo estreito nem infinito"] = function(t)
	t.eq(F.reconhecer({}),nil)
	t.eq(F.reconhecer(caminho({{10,10},{15,15}})),nil)
	t.eq(F.reconhecer(caminho({{20,20},{180,20},{100,180},{20,20}})),nil)
	t.eq(F.reconhecer(caminho({{20,20},{200,20},{200,55},{20,55},{20,20}})),nil)
	t.eq(F.reconhecer(caminho({{0,0},{math.huge,0}})),nil)
end
specs["reconhecimento tolera traço irregular e quadrado iniciado no meio do lado"] = function(t)
	local pts=caminho({{100,20},{180,20},{180,180},{20,180},{20,20},{100,20}})
	for i,p in pts do p[1]+=math.sin(i*1.7)*2; p[2]+=math.cos(i*1.1)*2 end
	t.eq(F.reconhecer(pts),"quadrado")
	pts={}; for i=0,90 do local a=i/90*2*math.pi; local r=80+math.sin(i)*3; table.insert(pts,{100+r*math.cos(a),100+r*math.sin(a)}) end
	t.eq(F.reconhecer(pts),"circulo")
	pts=caminho({{20,20},{180,140}})
	for i,p in pts do p[2]+=math.sin(i)*2 end
	t.eq(F.reconhecer(pts),"linha")
end
return specs
