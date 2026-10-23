-- SOMENTE STUDIO: integração A17 com serviço real, mesa isolada e RNG controlado.
local Shared=game.ReplicatedStorage.Shared
local Servico=require(script.Parent.Parent.HabilidadeService)
local Catalogo=require(Shared.Livro.Catalogo)
local Execucao=require(Shared.Regras.Execucao)
local function rank(tree) return "rank/"..tree.."/Principiante" end
local function ab(tree,id) return "ability/"..tree.."/Principiante/"..id end
local function tal(tree,id) return "talent/"..tree.."/Principiante/"..id end
local function ficha(id,x,z,dono)
	return {id=id,name=id,x=x,z=z,kind="jogador",ownerUserId=dono,pv=100,pvMax=100,mana=50,manaMax=50,version=1,conditions={},sheet={ca=14,forca=2,agilidade=2,vigor=2},
		ficha2={construction={unlockedRankIds={},purchasedIds={},inventory={{name="Espada Longa",type="arma",equipped=true,baseDie="d8"}}},
		calculated={highestRankBonus=1,attributes={forca=2,agilidade=2,vigor=2,intelecto=2,espirito=2},maxima={pt=20}},session={current={pt=20}}}}
end
local function tem(a,id)
	for _,c in a.conditions do if c.id==id then return c.stacks or 1 end end
	return nil
end
local function contexto(d20,extras)
	local a,b,c=ficha("a",5,5,123),ficha("b",6,5,124),ficha("c",5,6,125)
	local tokens={a=a,b=b,c=c};local combat={active=true,round=1,turn=1,current="a",order={"a","b","c"}}
	local handlers,logs,recibos,terrain,rolagens={},{},{},{},{}
	local fila=table.clone(d20 or {});local api
	local registro=table.clone(Execucao);registro.MECANICAS=table.clone(Execucao.MECANICAS)
	for k,v in extras or {} do registro.MECANICAS[k]=v end
	local original=registro.habilidadesDe
	registro.habilidadesDe=function(f,catalogo) local ids=original(f,catalogo);for k in extras or {} do table.insert(ids,k) end;return ids end
	api=Servico.start({execucao=registro,handlers=handlers,tokens=tokens,tokenOrder={"a","b","c"},combat=combat,catalogo=Catalogo,terrain=terrain,
		cellKey=function(x,z) return x..":"..z end,random={NextInteger=function(_,lo,hi) local n=math.clamp(if hi==20 then table.remove(fila,1) or 15 else 3,lo,hi);table.insert(rolagens,{hi=hi,n=n});return n end},
		remote={FireClient=function(_,_,k,d) if k=="efeito" then table.insert(recibos,d) end end},
		canSee=function(_,t) return not t.hidden end,currentTurnId=function() return combat.current end,
		emDuelo=function() return true end,mesmaEquipe=function(u,v) return u.ownerUserId~=nil and v.ownerUserId~=nil and (u.ownerUserId~=124 and v.ownerUserId~=124 or u.ownerUserId==v.ownerUserId) end,
		logAboutToken=function(_,texto) table.insert(logs,texto) end,
		moverFicha=function(t,x,z) local ox,oz=t.x,t.z;t.x,t.z=x,z;api.moveu(t,ox,oz) end,
		removerFicha=function(id) tokens[id]=nil end,reviverBoneco=function() end})
	api.reacoes.decidir=function() return nil end
	local x={a=a,b=b,c=c,tokens=tokens,api=api,combat=combat,handlers=handlers,logs=logs,recibos=recibos,terrain=terrain,rolagens=rolagens}
	x.usar=function(id,alvo,extra) local p={tokenId=combat.current,habilidadeId=id,alvoId=alvo};for k,v in extra or {} do p[k]=v end;return handlers.usarHabilidade({UserId=tokens[combat.current].ownerUserId},p,false) end
	x.vez=function(id) local anterior=combat.current;combat.current=id;combat.turn+=1;api.aoTrocarVez(anterior,id) end
	x.abrir=function(t,tree,compras) table.insert(t.ficha2.construction.unlockedRankIds,rank(tree));for _,id in compras or {} do table.insert(t.ficha2.construction.purchasedIds,id) end end
	x.move=function(t,x,z) local ox,oz=t.x,t.z;t.x,t.z=x,z;api.moveu(t,ox,oz) end
	x.log=function() return table.concat(logs,"\n") end
	return x
end
local function efeito(campos)
	local m={tipo="efeito",acoes=1,pm=0,pt=0,basico=true,alcanceCasas=20,semTeste=true}
	for k,v in campos do m[k]=v end;return m
end
local function criatura(x)
	x.b.ficha2=nil;x.b.sheet=nil;x.b.kind="npc";x.b.ownerUserId=nil;x.b.ia=true
	x.b.criatura={ca=14,bonusResistencia=2,bonusAtaque=3,patamar=1,danoPorTurno=16,deslocamentoMetros=9,categoria="besta",resistencias={},imunidades={}}
	return x.b
end
local especial={tipo="ataque",criatura=true,area=true,corpoACorpo=false,alcanceCasas=20,partes={{fixo=16,tipo="contundente"}}}
return {
	["A17 barra básica universal e cartas só de ranks abertos"] = function(t)
		local x=contexto();local ids=x.api.habilidadesDe(x.a)
		for _,id in {"mesa/esquivar","mesa/defender","mesa/ajudar"} do t.ok(table.find(ids,id));t.ok(Execucao.MECANICAS[id]) end
		for _,id in {"mesa/brisa","mesa/molhar","mesa/moldar","mesa/marcar"} do t.eq(table.find(ids,id),nil);t.ok(x.usar(id,"b")~=nil) end
		for _,tree in {"agua","vento","terra","arquearia","cavalaria-e-escudos"} do x.abrir(x.a,tree) end
		ids=x.api.habilidadesDe(x.a);for _,id in {"mesa/brisa","mesa/molhar","mesa/moldar","mesa/marcar","mesa/sob-minha-guarda"} do t.ok(table.find(ids,id)) end
	end,
	["A17 Brisa sucesso empurra, sem custo e uma vez por turno; recusa aliados"] = function(t)
		local x=contexto({20});x.abrir(x.a,"vento")
		t.ok(x.usar("mesa/brisa","c")~=nil);t.eq(x.api.estado().acoes.usadas,0)
		t.eq(x.usar("mesa/brisa","b"),nil);t.eq(x.b.x,7);t.eq(tem(x.b,"desequilibrado"),nil)
		t.eq(x.api.estado().acoes.usadas,0);t.eq(x.a.mana,50);t.ok(x.usar("mesa/brisa","b")~=nil)
		x.vez("b");x.vez("a");t.eq(x.usar("mesa/brisa","b"),nil)
	end,
	["A17 Brisa falha Desequilibrado até fim da próxima vez do alvo"] = function(t)
		local x=contexto({1});x.abrir(x.a,"vento");t.eq(x.usar("mesa/brisa","b"),nil);t.ok(tem(x.b,"desequilibrado"))
		x.vez("b");t.ok(tem(x.b,"desequilibrado"));x.vez("a");t.eq(tem(x.b,"desequilibrado"),nil)
	end,
	["A17 Molhar exige adjacência e não custa recursos"] = function(t)
		local x=contexto();x.abrir(x.a,"agua");x.b.x=7;t.ok(x.usar("mesa/molhar","b")~=nil)
		x.b.x=6;t.eq(x.usar("mesa/molhar","b"),nil);t.ok(tem(x.b,"molhado"));t.eq(x.a.mana,50);t.eq(x.api.estado().acoes.usadas,0)
	end,
	["A17 Moldar sucesso cria chão hostil, falha Atolado e prazo da fonte"] = function(t)
		local x=contexto({20,1});x.abrir(x.a,"terra")
		t.ok(x.usar("mesa/moldar","c")~=nil);t.eq(x.usar("mesa/moldar","b"),nil)
		t.eq(tem(x.b,"atolado"),nil);t.eq(#x.api.estado().muros,1)
		x.vez("b");x.vez("a");t.eq(#x.api.estado().muros,1)
		t.eq(x.usar("mesa/moldar","b"),nil);t.ok(tem(x.b,"atolado"))
		x.vez("b");t.eq(#x.api.estado().muros,1,"primeiro chão termina ao fim da próxima vez; segundo conserva")
		x.vez("a");x.vez("c");t.eq(#x.api.estado().muros,0)
	end,
	["A17 Esquivar aplica Desvantagem da criatura e expira no início da vez"] = function(t)
		local x=contexto({15,2});criatura(x);t.eq(x.usar("mesa/esquivar"),nil);t.ok(table.find(x.api.estadosDe(x.a),"esquiva"))
		x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,100);t.ok(x.log():find("Desvantagem",1,true))
		x.vez("a");t.eq(table.find(x.api.estadosDe(x.a),"esquiva"),nil)
	end,
	["A17 Esquivar concede Vantagem em resistência enquanto ativo"] = function(t)
		local x=contexto({1,20},{["mesa/teste"]=efeito({semTeste=false,resistencia={atributo="vigor",cdBase=8},aplica="amedrontado"})})
		t.eq(x.usar("mesa/esquivar"),nil);x.vez("b");t.eq(x.usar("mesa/teste","a"),nil);t.eq(tem(x.a,"amedrontado"),nil)
	end,
	["A17 Defender reduz golpe por Vigor + metade de rank de corpo"] = function(t)
		local x=contexto({15});criatura(x);x.abrir(x.a,"deus-do-norte");t.eq(x.usar("mesa/defender"),nil)
		x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,87);t.ok(x.log():find("Defender",1,true))
		x.vez("a");t.eq(table.find(x.api.estadosDe(x.a),"defender"),nil)
	end,
	["A17 Ajudar entre donos aliados consome vantagem no próximo ataque"] = function(t)
		local x=contexto({15,1});t.eq(x.usar("mesa/ajudar","c"),nil);t.ok(table.find(x.api.estadosDe(x.c),"auxilio"))
		x.c.x=7;x.c.z=5;x.vez("c");t.eq(x.usar("mesa/ataque-basico","b"),nil);t.ok(x.log():find("Vantagem",1,true))
		t.eq(table.find(x.api.estadosDe(x.c),"auxilio"),nil)
	end,
	["A17 Ajudar recusa inimigo sem custo e expira na vez de quem ajudou"] = function(t)
		local x=contexto();t.ok(x.usar("mesa/ajudar","b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
		t.eq(x.usar("mesa/ajudar","c"),nil);x.vez("b");x.vez("a");t.eq(table.find(x.api.estadosDe(x.c),"auxilio"),nil)
	end,
	["A17 Marcar registra fonte, +1 exclusivo do arqueiro que marcou"] = function(t)
		local x=contexto({15});x.abrir(x.a,"arquearia");t.eq(x.usar("mesa/marcar","b"),nil);t.ok(tem(x.b,"marcado"))
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.ok(x.log():find("+4 =",1,true),x.log())
		x.abrir(x.c,"arquearia");x.c.x=7;x.c.z=5;x.vez("c");t.eq(x.usar("mesa/ataque-basico","b"),nil)
		t.ok(x.logs[#x.logs-1]:find("+3 =",1,true),x.log())
	end,
	["A17 deslocamento da ficha e Pés Leves; não soma com Roupa Leve"] = function(t)
		local x=contexto();x.c.x=12;x.a.ficha2.calculated.movementMeters=6
		t.ok(x.api.validarMovimento(x.a,5,10,false)~=nil)
		x.abrir(x.a,"vento",{tal("vento","pes-leves")});t.eq(x.api.validarMovimento(x.a,5,11,false),nil)
		x.abrir(x.a,"deus-da-espada",{ab("deus-da-espada","roupa-leve")});t.ok(x.api.validarMovimento(x.a,5,12,false)~=nil)
	end,
	["A17 Pés no Chão ignora terreno difícil mas Caído ainda custa dobro"] = function(t)
		local x=contexto({20});x.abrir(x.a,"terra");x.b.x=7;x.b.z=5;t.eq(x.usar("mesa/moldar","b"),nil);x.vez("b")
		x.a.z=3;x.b.x=1;x.b.z=5;t.ok(x.api.validarMovimento(x.b,7,5,false)~=nil)
		x.abrir(x.b,"deus-do-norte",{tal("deus-do-norte","pes-no-chao")});t.eq(x.api.validarMovimento(x.b,7,5,false),nil)
		x.b.conditions={{id="caido",stacks=1}};t.ok(x.api.validarMovimento(x.b,7,5,false)~=nil)
	end,
	["A17 Roupa Leve soma duas casas, preserva fora da vez e zera ao iniciar"] = function(t)
		local x=contexto({11,11,11});criatura(x);x.abrir(x.a,"deus-da-espada",{ab("deus-da-espada","roupa-leve")})
		x.move(x.a,5,7);x.b.x=6;x.b.z=7;x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,100,"14 erra CA16")
		x.vez("a");x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,84,"novo turno sem andar: CA14")
	end,
	["A17 Roupa Leve desliga com armadura de corpo, escudo não desliga"] = function(t)
		local x=contexto({11});criatura(x);x.abrir(x.a,"deus-da-espada",{ab("deus-da-espada","roupa-leve")});table.insert(x.a.ficha2.construction.inventory,{type="armadura",name="Couro",equipped=true})
		x.move(x.a,5,7);x.b.x=6;x.b.z=7;x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,84)
	end,
	["A17 Sem Recuo imune Amedrontado, Paciência imune também Provocado"] = function(t)
		local x=contexto(nil,{["mesa/medo"]=efeito({aplica="amedrontado",estados={{nome="provocado",valor=true}}})})
		x.abrir(x.b,"deus-da-espada",{ab("deus-da-espada","sem-recuo")});t.eq(x.usar("mesa/medo","b"),nil);t.eq(tem(x.b,"amedrontado"),nil);t.ok(table.find(x.api.estadosDe(x.b),"provocado"))
		x.abrir(x.c,"deus-da-agua-corpo",{tal("deus-da-agua-corpo","paciencia-de-pedra")});t.eq(x.usar("mesa/medo","c"),nil);t.eq(tem(x.c,"amedrontado"),nil);t.eq(table.find(x.api.estadosDe(x.c),"provocado"),nil)
	end,
	["A17 Base Firme ignora empurrão e Caído de Força/Agilidade mas não Vigor"] = function(t)
		local x=contexto({1,1,1},{["mesa/forca"]=efeito({semTeste=false,resistencia={atributo="forca",cdBase=8},aplica="caido",empurraCasas=1}),["mesa/agi"]=efeito({semTeste=false,resistencia={atributo="agilidade",cdBase=8},aplica="caido",empurraCasas=1}),["mesa/vigor"]=efeito({semTeste=false,resistencia={atributo="vigor",cdBase=8},aplica="caido",empurraCasas=1})})
		x.abrir(x.b,"deus-da-agua-corpo",{ab("deus-da-agua-corpo","base-firme")})
		t.eq(x.usar("mesa/forca","b"),nil);t.eq(x.b.x,6);t.eq(tem(x.b,"caido"),nil)
		t.eq(x.usar("mesa/agi","b"),nil);t.eq(x.b.x,6);t.eq(tem(x.b,"caido"),nil)
		t.eq(x.usar("mesa/vigor","b"),nil);t.eq(x.b.x,7);t.ok(tem(x.b,"caido"))
	end,
	["A17 Base Firme também ignora puxão de efeito com teste de Agilidade"] = function(t)
		local x=contexto({1},{["mesa/puxao"]=efeito({semTeste=false,resistencia={atributo="agilidade",cdBase=8},puxar=true})})
		x.b.x=8;x.abrir(x.b,"deus-da-agua-corpo",{ab("deus-da-agua-corpo","base-firme")})
		t.eq(x.usar("mesa/puxao","b"),nil);t.eq(x.b.x,8)
	end,
	["A17 primeiro ataque com arma só na primeira vez, inclusive erro consome"] = function(t)
		local x=contexto({1,1,15,15});x.abrir(x.a,"deus-da-espada")
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(x.b.pv,100);t.eq(#x.rolagens,2)
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(#x.rolagens,4,"segundo golpe um d20 e um dado")
		x.vez("b");x.vez("a");local antes=#x.rolagens;t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(#x.rolagens-antes,2)
	end,
	["A17 Corpo é Arma primeiro acerto por alvo e por turno; erro não consome"] = function(t)
		local x=contexto({1,15,15});x.abrir(x.a,"armas-pesadas")
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(tem(x.b,"quebrantado"),nil)
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(tem(x.b,"quebrantado"),1)
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(tem(x.b,"quebrantado"),1)
		x.vez("b");x.vez("a");t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(tem(x.b,"quebrantado"),2)
		t.eq(x.usar("mesa/ataque-basico","c"),nil);t.eq(tem(x.c,"quebrantado"),1)
	end,
	["A17 Condutor conserva Molhado após fogo e fim da duração normal"] = function(t)
		local x=contexto(nil,{["mesa/fogo"]=efeito({partes={{fixo=2,tipo="ígneo"}}})});x.abrir(x.a,"agua",{tal("agua","condutor-de-gelo")})
		t.eq(x.usar("mesa/molhar","b"),nil);t.eq(x.usar("mesa/fogo","b"),nil);t.ok(tem(x.b,"molhado"))
		x.combat.round=20;x.vez("b");x.vez("a");t.ok(tem(x.b,"molhado"));x.api.combateEncerrado();t.eq(tem(x.b,"molhado"),nil)
	end,
	["A17 Molhado sem Condutor seca com dano ígneo"] = function(t)
		local x=contexto(nil,{["mesa/fogo"]=efeito({partes={{fixo=2,tipo="ígneo"}}})});x.abrir(x.a,"agua")
		t.eq(x.usar("mesa/molhar","b"),nil);t.eq(x.usar("mesa/fogo","b"),nil);t.eq(tem(x.b,"molhado"),nil)
	end,
	["A17 Molhado persistente não perde proteção ao ser reaplicado por outro mago"] = function(t)
		local x=contexto(nil,{["mesa/fogo"]=efeito({partes={{fixo=2,tipo="ígneo"}}})});x.abrir(x.a,"agua",{tal("agua","condutor-de-gelo")});x.abrir(x.c,"agua")
		t.eq(x.usar("mesa/molhar","b"),nil);x.vez("c");t.eq(x.usar("mesa/molhar","b"),nil);x.vez("a")
		t.eq(x.usar("mesa/fogo","b"),nil);t.ok(tem(x.b,"molhado"));x.combat.round=20;x.vez("b");t.ok(tem(x.b,"molhado"))
	end,
	["A17 equipes cura, Puxar e Sob Minha Guarda aceitam outro dono"] = function(t)
		local x=contexto();x.abrir(x.a,"cavalaria-e-escudos",{ab("cavalaria-e-escudos","puxar")});x.abrir(x.a,"cura",{ab("cura","cura")});x.c.pv=50
		t.eq(x.usar(ab("cura","cura"),"c"),nil);t.ok(x.c.pv>50)
		t.eq(x.usar("mesa/sob-minha-guarda","c"),nil);t.eq(x.api.reacoes.designadoDe("a"),"c")
		x.c.x=7;x.c.z=7;t.eq(x.usar(ab("cavalaria-e-escudos","puxar"),"c"),nil);t.ok(math.abs(x.c.x-x.a.x)<=1)
	end,
	["A17 Puxar marca guarda e Interpor transfere o golpe ao protetor"] = function(t)
		local x=contexto({20});x.abrir(x.a,"cavalaria-e-escudos",{ab("cavalaria-e-escudos","puxar")})
		x.c.x,x.c.z=9,9
		t.eq(x.usar(ab("cavalaria-e-escudos","puxar"),"c"),nil)
		t.ok(table.find(x.api.estadosDe(x.c),"guarda"))
		x.api.reacoes.decidir=function() return "interpor" end
		x.vez("b")
		local pvAliado,pvProtetor=x.c.pv,x.a.pv
		t.eq(x.usar("mesa/ataque-basico","c"),nil)
		t.eq(x.c.pv,pvAliado);t.ok(x.a.pv<pvProtetor)
	end,
	["A17 chefão usa defesas, PV temporários e recibo; uma execução por vez"] = function(t)
		local x=contexto({15});criatura(x);x.a.pvTemp=5;x.vez("b")
		t.eq(x.api.golpeDeCriatura(x.b,{x.a},especial,{estilo="raizes",casas={{5,5}},nome="Raízes"}),true)
		t.eq(x.a.pv,89);t.eq(x.a.pvTemp,0);t.ok(x.log():find("PV temporários absorvem 5",1,true));t.eq(x.api.estado().acoes.usadas,1)
		if #x.recibos>0 then t.eq(x.recibos[#x.recibos].estilo,"raizes");t.eq(x.recibos[#x.recibos].alvos[1].dano,16) end
		t.eq(x.api.golpeDeCriatura(x.b,{x.a},especial),false);t.eq(x.a.pv,89)
	end,
	["A17 chefão área vazia consome execução; inválido não cobra"] = function(t)
		local x=contexto();criatura(x);t.eq(x.api.golpeDeCriatura(x.b,{},especial),false)
		x.vez("b");t.eq(x.api.golpeDeCriatura(x.b,{x.a,x.a},especial),false);t.eq(x.api.estado().acoes.usadas,0)
		t.eq(x.api.golpeDeCriatura(x.b,{},especial),true);t.eq(x.api.estado().acoes.usadas,1);t.eq(x.api.golpeDeCriatura(x.b,{},especial),false)
	end,
	["A17 chefão cancela incapaz e revalida vez após janela de Reação"] = function(t)
		local x=contexto({15});criatura(x);x.abrir(x.a,"terra",{ab("terra","couraca-de-barro")});x.vez("b")
		x.b.conditions={{id="incapacitado",stacks=1}};t.eq(x.api.golpeDeCriatura(x.b,{x.a},especial),false);t.eq(x.api.estado().acoes.usadas,0)
		x.b.conditions={};x.api.reacoes.decidir=function() x.vez("c");return nil end
		t.eq(x.api.golpeDeCriatura(x.b,{x.a},especial),false);t.eq(x.a.pv,100)
	end,
	["A17 chefão revalida alvo removido na janela e filtra alcance/parede/aliados"] = function(t)
		local x=contexto({15});criatura(x);x.abrir(x.a,"terra",{ab("terra","couraca-de-barro")});x.vez("b")
		x.api.reacoes.decidir=function() x.tokens.a=nil;return nil end
		t.eq(x.api.golpeDeCriatura(x.b,{x.a},especial),true);t.eq(x.a.pv,100)
		x.vez("c");x.vez("b");x.c.x=30;t.eq(x.api.golpeDeCriatura(x.b,{x.c},especial),true);t.eq(x.c.pv,100)
	end,
	["A17 Parede real conserva PV e expira no começo da vez da fonte"] = function(t)
		local x=contexto({15});criatura(x);x.b.criatura.danoPorTurno=5;x.abrir(x.a,"teorica",{ab("teorica","parede-de-emergencia")})
		x.api.reacoes.decidir=function(_,_,opcoes) for _,o in opcoes do if o.id=="parede" then return "parede" end end end
		x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,100);t.eq(x.a.mana,46);t.eq(x.api.estado().muros[1].pv,10)
		x.vez("a");t.eq(#x.api.estado().muros,0)
	end,
	["A17 Parede não é oferecida para magia mesmo com dano físico"] = function(t)
		local x=contexto({15});x.abrir(x.a,"terra",{ab("terra","bala-de-pedra")});x.abrir(x.b,"teorica",{ab("teorica","parede-de-emergencia")})
		local perguntas=0;x.api.reacoes.decidir=function() perguntas+=1;return "parede" end
		t.eq(x.usar(ab("terra","bala-de-pedra"),"b"),nil);t.eq(perguntas,0);t.eq(x.b.mana,50);t.eq(#x.api.estado().muros,0);t.ok(x.b.pv<100)
	end,
	["A17 Pés no Chão permite investida cujo terreno custa além do limite"] = function(t)
		local x=contexto({20,20});x.abrir(x.a,"terra");x.b.x=7;x.b.z=5;t.eq(x.usar("mesa/moldar","b"),nil)
		x.abrir(x.b,"deus-da-espada",{ab("deus-da-espada","investida-espada")});x.b.ficha2.calculated.movementMeters=4.5;x.a.x=8;x.a.z=5;x.b.x=1;x.b.z=5;x.vez("b")
		t.ok(x.usar(ab("deus-da-espada","investida-espada"),"a")~=nil);t.eq(x.api.estado().acoes.usadas,0)
		x.abrir(x.b,"deus-do-norte",{tal("deus-do-norte","pes-no-chao")});t.eq(x.usar(ab("deus-da-espada","investida-espada"),"a"),nil)
		t.eq(x.b.x,7)
	end,
	["A17 Roupa Leve não conta deslocamento fora da vez nem soma escudo como armadura"] = function(t)
		local x=contexto({11,11});criatura(x);x.abrir(x.a,"deus-da-espada",{ab("deus-da-espada","roupa-leve")})
		x.vez("b");x.move(x.a,5,7);x.b.x=6;x.b.z=7;x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,84)
		x.vez("a");table.insert(x.a.ficha2.construction.inventory,{type="armadura",name="Escudo",equipped=true})
		x.move(x.a,5,9);x.b.x=6;x.b.z=9;x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,84)
	end,
	["A17 Corpo é Arma técnica usa seu número, sem somar um"] = function(t)
		local m={tipo="ataque",acoes=1,basico=true,pm=0,pt=0,alcanceCasas=1,corpoACorpo=true,efeitoNoAcerto={resistencia={atributo="forca",cdBase=8},quebrantado=true}}
		local x=contexto({15,1},{["mesa/tecnica"]=m});x.abrir(x.a,"armas-pesadas");x.a.ficha2.construction.unlockedRankIds={"rank/armas-pesadas/Intermedi%C3%A1rio",rank("armas-pesadas")}
		t.eq(x.usar("mesa/tecnica","b"),nil);t.eq(tem(x.b,"quebrantado"),2)
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(tem(x.b,"quebrantado"),2)
	end,
	["A17 Corpo é Arma não aplica em disparo nem contra-ataque fora da vez"] = function(t)
		local x=contexto({15});x.abrir(x.a,"armas-pesadas");t.eq(x.usar("mesa/ataque-a-distancia","b"),nil);t.eq(tem(x.b,"quebrantado"),nil)
	end,
	["A17 Condutor integrado soma frio sem dobrar extra"] = function(t)
		local x=contexto({1});x.abrir(x.a,"agua",{tal("agua","condutor-de-gelo"),ab("agua","impacto-de-gelo")})
		t.eq(x.usar("mesa/molhar","b"),nil);t.eq(x.usar(ab("agua","impacto-de-gelo"),"b"),nil)
		t.eq(x.b.pv,88,"frio3 x2 + extra3 + BC3 =12")
	end,
	["A17 Guarda do Corpo entre donos de mesma equipe e Interpor funcionam"] = function(t)
		local x=contexto({15,15});criatura(x);x.abrir(x.c,"deus-da-agua-corpo",{ab("deus-da-agua-corpo","guarda-do-corpo")})
		x.api.reacoes.decidir=function(_,_,opcoes) for _,o in opcoes do if o.id=="guardaDoCorpo" then return o.id end end end
		x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,100);t.eq(x.c.pv,84)
		x.vez("a");x.abrir(x.a,"cavalaria-e-escudos");t.eq(x.usar("mesa/sob-minha-guarda","c"),nil)
		x.b.x=6;x.b.z=6;x.c.x=5;x.c.z=6;x.a.x=5;x.a.z=7
		x.api.reacoes.decidir=function(_,_,opcoes) for _,o in opcoes do if o.id=="interpor" then return o.id end end end
		x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.c.pv,84);t.eq(x.a.pv,84)
	end,
	["A17 chefão passa por Couraça, resistência e queda a zero"] = function(t)
		local x=contexto({15});criatura(x);x.abrir(x.a,"terra",{ab("terra","couraca-de-barro")});x.a.pv=5
		x.api.reacoes.decidir=function() return "couraca" end;x.vez("b")
		t.eq(x.api.golpeDeCriatura(x.b,{x.a},especial),true);t.eq(x.a.mana,48);t.eq(x.a.pv,0);t.ok(tem(x.a,"caido"))
	end,
	["A17 chefão cancela aplicação se alvo sair da área durante Reação"] = function(t)
		local x=contexto({15});criatura(x);x.abrir(x.a,"terra",{ab("terra","couraca-de-barro")});x.vez("b")
		x.api.reacoes.decidir=function() x.a.x=8;return nil end
		t.eq(x.api.golpeDeCriatura(x.b,{x.a},especial,{casas={{5,5}}}),true);t.eq(x.a.pv,100);t.eq(x.b.x,6,"não persegue")
	end,
	["A17 chefão ignora alvo aliado, linha bloqueada e esgotamento de Ações"] = function(t)
		local x=contexto({15},{["mesa/esgotar"]=efeito({estados={{nome="perdeAcao",valor=3}}})});criatura(x);x.vez("b");x.c.ownerUserId=nil;x.c.kind="npc";x.c.ia=true
		x.a.x=3;x.terrain["4:5"]="parede"
		t.eq(x.api.golpeDeCriatura(x.b,{x.a,x.c},especial),true);t.eq(x.a.pv,100);t.eq(x.c.pv,100)
		x.terrain["4:5"]=nil;x.vez("a");t.eq(x.usar("mesa/esgotar","b"),nil);x.vez("b")
		t.eq(x.api.golpeDeCriatura(x.b,{},especial),false)
	end,
	["A17 fim limpa primeira vez, esquiva, marcas e chão sem recurso permanente"] = function(t)
		local x=contexto({15,15});x.abrir(x.a,"deus-da-espada");t.eq(x.usar("mesa/ataque-basico","b"),nil)
		x.api.combateEncerrado();x.vez("a");local antes=#x.rolagens;t.eq(x.usar("mesa/ataque-basico","b"),nil)
		t.eq(#x.rolagens-antes,4,"novo combate: dois d20 e dois dados de arma")
	end,
}
