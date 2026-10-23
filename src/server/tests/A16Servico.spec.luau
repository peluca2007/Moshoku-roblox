-- SOMENTE STUDIO: serviço real isolado, RNG e dependências controlados.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)
local function id(arvore, carta) return "ability/" .. arvore .. "/Principiante/" .. carta end
local function ficha(nome,x,z)
	local atributos = {forca=3,agilidade=3,vigor=3,intelecto=3,espirito=3}
	return { id=nome,name=nome,x=x,z=z,kind="jogador",ownerUserId=123,pv=60,pvMax=60,mana=50,manaMax=50,version=1,conditions={},sheet={ca=10,forca=3,agilidade=3,vigor=3},
		ficha2={construction={unlockedRankIds={},purchasedIds={},inventory={{name="Espada Longa",type="arma",equipped=true,baseDie="d8",sourceLocalId=nome.."-arma"}}},
		calculated={highestRankBonus=1,attributes=atributos,maxima={pt=10}},session={current={pt=10}}} }
end
local function tem(token,idCond)
	for _,c in token.conditions do if c.id==idCond then return true end end
	return false
end
local function contexto(rolagens, extras)
	local a,b,c=ficha("a",5,5),ficha("b",6,5),ficha("c",7,7)
	for _, arvore in {"terra","teorica","cura","desintoxicacao","armas-pesadas","deus-do-norte","deus-da-espada","cavalaria-e-escudos"} do
		table.insert(a.ficha2.construction.unlockedRankIds,"rank/"..arvore.."/Principiante")
	end
	for key in Execucao.MECANICAS do if string.sub(key,1,8)=="ability/" then table.insert(a.ficha2.construction.purchasedIds,key) end end
	local tokens={a=a,b=b,c=c}; local handlers,logs={},{}
	local combat={active=true,round=1,turn=1,current="a",order={"a","b","c"},turnIndex=1}
	local fila=table.clone(rolagens or {}); local terrain={}; local api
	local registro=Execucao
 if extras then registro=table.clone(Execucao);registro.MECANICAS=table.clone(Execucao.MECANICAS);for key,m in extras do registro.MECANICAS[key]=m end end
 api=Servico.start({execucao=registro,handlers=handlers,tokens=tokens,tokenOrder={"a","b","c"},combat=combat,catalogo=Catalogo,terrain=terrain,
		cellKey=function(x,z) return x..":"..z end,random={NextInteger=function(_,lo,hi) return math.clamp(if hi==20 then (table.remove(fila,1) or 15) else 3,lo,hi) end},
		remote={FireClient=function() end},canSee=function(_,token) return not token.hidden end,currentTurnId=function() return combat.current end,
		logAboutToken=function(_,texto) table.insert(logs,texto) end,moverFicha=function(token,x,z) local ox,oz=token.x,token.z; token.x,token.z=x,z; api.moveu(token,ox,oz) end,
		removerFicha=function(key) tokens[key]=nil end,reviverBoneco=function() end})
	api.reacoes.decidir=function() return nil end
	local x={a=a,b=b,c=c,api=api,combat=combat,tokens=tokens,handlers=handlers,terrain=terrain,logs=logs}
	x.usar=function(key,alvo,extra,user)
		local p={tokenId=combat.current,habilidadeId=key,alvoId=alvo}; for k,v in extra or {} do p[k]=v end
		return handlers.usarHabilidade({UserId=user or 123},p,false)
	end
	x.vez=function(key) local anterior=combat.current; combat.current=key; combat.turn+=1; api.aoTrocarVez(anterior,key) end
	return x
end
return {
	["anteparo intercepta disparo, perde PV e magia atravessa"] = function(t)
		local x=contexto({15,15}); x.b.x=9
		t.eq(x.usar(id("teorica","anteparo-teorico"),nil,{x=6,z=5}),nil)
		x.vez("b"); x.vez("a")
		t.eq(x.usar("mesa/ataque-a-distancia","b"),nil); t.eq(x.b.pv,60)
		t.ok(x.api.estado().muros[1].pv<30)
		x.vez("b");x.vez("a")
		local pvBarreira=x.api.estado().muros[1].pv
		t.eq(x.usar(id("teorica","dardo-arcano"),"b"),nil);t.ok(x.b.pv<60);t.eq(x.api.estado().muros[1].pv,pvBarreira)
	end,
	["muro 40 PV: ataque na casa destrói e libera passagem"] = function(t)
		local x=contexto(); t.eq(x.usar(id("terra","muro-de-terra"),nil,{x=6,z=5}),nil)
		t.eq(x.api.estado().muros[1].pv,40); t.eq(x.api.bloqueiaMovimento(6,5),true)
		for _=1,10 do if #x.api.estado().muros==0 then break end; x.vez("b");x.vez("a"); t.eq(x.usar("mesa/ataque-basico",nil,{x=6,z=5}),nil) end
		t.eq(#x.api.estado().muros,0);t.eq(x.api.bloqueiaMovimento(6,5),false)
	end,
	["agarrão tem escape na barra, conserva CD da disputa e punhos acertam"] = function(t)
		local x=contexto({15,1,1,1,1}); x.a.ficha2.construction.inventory={} -- ataque inicial com Vantagem usa dois d20
		t.eq(x.usar(id("armas-pesadas","agarrao"),"b"),nil);t.ok(tem(x.b,"agarrado"))
		t.ok(table.find(x.api.habilidadesDe(x.b),"mesa/escapar"))
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.ok(x.b.pv<60)
		x.vez("b");t.eq(x.usar("mesa/escapar"),nil);t.ok(tem(x.b,"agarrado"));t.eq(x.api.estado().acoes.usadas,1)
	end,
	["Mão de Terra: falha/sucesso de escape custa uma Ação e limpa as duas condições"] = function(t)
		local x=contexto({1,1,20});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		x.vez("b");t.eq(x.usar("mesa/escapar"),nil);t.ok(tem(x.b,"agarrado"))
		t.eq(x.usar("mesa/escapar"),nil);t.eq(tem(x.b,"agarrado"),false);t.eq(tem(x.b,"atolado"),false)
		t.eq(x.api.estado().acoes.usadas,2)
	end,
	["Mão de Terra: soltar é livre e fonte caída encerra sustentação"] = function(t)
		local x=contexto({1,1});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		t.eq(x.usar("mesa/soltar"),nil);t.eq(tem(x.b,"agarrado"),false)
		x.vez("b");x.vez("a");t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		x.a.pv=0;x.vez("b");t.eq(tem(x.b,"agarrado"),false);t.eq(tem(x.b,"atolado"),false)
	end,
	["arrastar Mão 3 m custa uma Ação e rejeita parede sem cobrar"] = function(t)
		local x=contexto({1});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		t.eq(x.usar("mesa/arrastar",nil,{x=8,z=5}),nil);t.eq(x.b.x,8);t.eq(x.api.estado().acoes.usadas,3)
		x.vez("b");x.vez("a");x.terrain["9:5"]="parede"
		t.ok(x.usar("mesa/arrastar",nil,{x=10,z=5})~=nil);t.eq(x.api.estado().acoes.usadas,0)
	end,
	["arrastar Agarrão desloca os dois juntos e separação solta"] = function(t)
		local x=contexto({15,1});t.eq(x.usar(id("armas-pesadas","agarrao"),"b"),nil)
		t.eq(x.usar("mesa/arrastar",nil,{x=6,z=7}),nil);t.eq(x.a.z,7);t.eq(x.b.z,7);t.ok(tem(x.b,"agarrado"))
		x.a.x=1;x.api.moveu(x.a,5,7);t.eq(tem(x.b,"agarrado"),false)
	end,
	["Corte: arma no chão, braço até fim do próximo turno e recuperar uma Ação"] = function(t)
		local x=contexto({15,15,1});t.eq(x.usar(id("deus-da-espada","corte-de-braco"),"b"),nil)
		t.eq(x.b.ficha2.construction.inventory[1].equipped,false);t.eq(#x.api.estado().objetos,1)
		x.vez("b");t.ok(x.usar("mesa/pegar-arma",nil,{x=7,z=5})~=nil)
		t.eq(x.api.estado().acoes.usadas,0)
		x.vez("a");x.vez("b");t.eq(x.usar("mesa/pegar-arma",nil,{x=7,z=5}),nil)
		t.eq(x.b.ficha2.construction.inventory[1].equipped,true);t.eq(#x.api.estado().objetos,0);t.eq(x.api.estado().acoes.usadas,1)
	end,
	["Corte Santo apenas desarma, sem bloquear o braço"] = function(t)
		local x=contexto({15,15,1});x.b.ficha2.calculated.highestRankBonus=4
		t.eq(x.usar(id("deus-da-espada","corte-de-braco"),"b"),nil);x.vez("b")
		t.eq(x.usar("mesa/pegar-arma",nil,{x=7,z=5}),nil)
		t.eq(table.find(x.api.estadosDe(x.b),"bracoInutil"),nil)
	end,
	["arremesso larga até errando; desarmado não usa referência nem duplica recuperação"] = function(t)
		local x=contexto({1});x.a.ficha2.construction.unlockedRankIds={"rank/deus-do-norte/Principiante"};t.eq(x.usar(id("deus-do-norte","arremesso-de-espada"),"b"),nil)
		t.eq(x.b.pv,60);t.eq(#x.api.estado().objetos,1)
		t.ok(x.usar("mesa/ataque-basico","b")~=nil)
		t.eq(x.usar("mesa/pegar-arma",nil,{x=6,z=5}),nil);t.eq(x.api.estado().acoes.usadas,2)
		t.ok(x.usar("mesa/pegar-arma",nil,{x=6,z=5})~=nil);t.eq(#x.a.ficha2.construction.inventory,1)
	end,
	["Três Bainhas repõe livremente sem permanecer desarmado; fim remove reserva"] = function(t)
		local x=contexto({15});table.insert(x.a.ficha2.construction.purchasedIds,"talent/deus-do-norte/Principiante/tres-bainhas")
		t.eq(x.usar(id("deus-do-norte","arremesso-de-espada"),"b"),nil)
		t.eq(table.find(x.api.estadosDe(x.a),"desarmado"),nil);t.eq(#x.a.ficha2.construction.inventory,2)
		x.api.combateEncerrado();t.eq(#x.a.ficha2.construction.inventory,1);t.eq(x.a.ficha2.construction.inventory[1].equipped,true)
	end,
	["Primeiros Socorros levanta 0 PV e limite é da criatura, entre dois curadores"] = function(t)
		local x=contexto();x.b.pv=0;x.b.conditions={{id="caido",stacks=1}}
		t.eq(x.usar(id("deus-do-norte","primeiros-socorros-de-campo"),"b"),nil);t.eq(x.b.pv,4);t.eq(tem(x.b,"caido"),false)
		x.c.x=6;x.c.z=6;x.c.ficha2.construction=x.a.ficha2.construction;x.vez("c")
		t.ok(x.usar(id("deus-do-norte","primeiros-socorros-de-campo"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
		x.api.combateEncerrado();x.combat.active=true;x.vez("a");t.eq(x.usar(id("deus-do-norte","primeiros-socorros-de-campo"),"b"),nil)
	end,
	["Escudo armadura funciona; teste falho empurra e derruba"] = function(t)
		local x=contexto({15,1});table.insert(x.a.ficha2.construction.inventory,{name="Escudo",type="armadura",equipped=true,armorClassBonus=2})
		t.eq(x.usar(id("cavalaria-e-escudos","golpe-de-escudo"),"b"),nil);t.eq(x.b.x,8);t.ok(tem(x.b,"caido"))
	end,
	["Soberano exige Puro Escudo antes de cobrar; empurra 6 m"] = function(t)
		local x=contexto({15,1});table.insert(x.a.ficha2.construction.inventory,{name="Escudo",type="armadura",equipped=true})
		t.ok(x.usar(id("cavalaria-e-escudos","golpe-de-escudo-soberano"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
		table.insert(x.a.ficha2.construction.purchasedIds,"talent/cavalaria-e-escudos/Principiante/puro-escudo")
		t.eq(x.usar(id("cavalaria-e-escudos","golpe-de-escudo-soberano"),"b"),nil);t.eq(x.b.x,10)
	end,
	["Estancar apaga não mágico e não cobra para fogo mágico ativo"] = function(t)
		local x=contexto();x.b.conditions={{id="em-chamas",stacks=1}}
		t.eq(x.usar(id("cura","estancar"),"b"),nil);t.eq(tem(x.b,"em-chamas"),false)
	end,
	["IA tenta escapar com sua Ação; desarme/braço reduzem dano"] = function(t)
		local x=contexto({1,1,15,1});x.b.ficha2=nil;x.b.kind="npc";x.b.ia=true
		x.b.criatura={ca=10,bonusResistencia=0,bonusAtaque=3,patamar=1,danoPorTurno=16,deslocamentoMetros=9,categoria="humanoide",resistencias={},imunidades={}}
		t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil);x.vez("b");t.eq(x.api.turnoDoInimigo(x.b),true)
		t.ok(string.find(table.concat(x.logs,"\n"),"tenta escapar",1,true));t.ok(tem(x.b,"agarrado"))
	end,
	["Quebrar arma mundana desativa e descanso restaura; besta sem inventário recusa"] = function(t)
		local x=contexto({1});t.eq(x.usar(id("armas-pesadas","quebrar-equipamento"),"b"),nil)
		t.eq(x.b.ficha2.construction.inventory[1].equipped,false);x.api.combateEncerrado();t.eq(x.b.ficha2.construction.inventory[1].equipped,true)
	end,
	["Sangria não opera a 0 nem sem origem e não cobra nesses casos"] = function(t)
		local x=contexto();x.b.conditions={{id="envenenado",stacks=1}}
		t.ok(x.usar(id("desintoxicacao","sangria"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0);t.eq(x.a.mana,50)
		x.b.pv=0;t.ok(x.usar(id("desintoxicacao","sangria"),"b")~=nil)
	end,
 ["Sangria purga rank 2, ignora PV temp e limita aflição após reaplicar"] = function(t)
  local x=contexto();x.b.conditions={{id="envenenado",stacks=1}};x.b.ficha2.session.conditions={{conditionId="condition/envenenado",sourceRankBonus=2}};x.b.pvTemp=20
  t.eq(x.usar(id("desintoxicacao","sangria"),"b"),nil);t.eq(x.b.pv,51);t.eq(x.b.pvTemp,20);t.eq(tem(x.b,"envenenado"),false)
  x.b.conditions={{id="envenenado",stacks=1}};x.vez("b");x.vez("a")
  t.ok(x.usar(id("desintoxicacao","sangria"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
 end,
 ["Estancar recusa Em Chamas de Bola de Fogo sem gastar"] = function(t)
  local x=contexto({15});table.insert(x.a.ficha2.construction.unlockedRankIds,"rank/fogo/Principiante")
  t.eq(x.usar(id("fogo","bola-de-fogo"),"b"),nil);t.ok(tem(x.b,"em-chamas"))
  x.vez("c");x.vez("a");local mana=x.a.mana
  t.ok(x.usar(id("cura","estancar"),"b")~=nil);t.eq(x.a.mana,mana);t.eq(x.api.estado().acoes.usadas,0);t.ok(tem(x.b,"em-chamas"))
 end,
 ["IA com arma quebrada dá metade de dano, sem reduzir garras"] = function(t)
  local x=contexto({1,15});x.b.ficha2=nil;x.b.kind="npc";x.b.ia=true
  x.b.criatura={ca=10,bonusResistencia=0,bonusAtaque=3,patamar=1,danoPorTurno=16,deslocamentoMetros=9,categoria="humanoide",resistencias={},imunidades={}}
  t.eq(x.usar(id("armas-pesadas","quebrar-equipamento"),"b"),nil);x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,52)
  x.vez("a");x.b.criatura.categoria="besta"
  t.ok(x.usar("mesa/desarmar","b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
 end,
 ["Quebrar escudo retira bônus CA e bloqueio; alias exige compra"] = function(t)
  local x=contexto({1});local escudo={name="Escudo",type="armadura",equipped=true,armorClassBonus=2};table.insert(x.b.ficha2.construction.inventory,escudo)
  t.eq(x.usar("mesa/quebrar-escudo","b"),nil);t.eq(escudo.equipped,false);t.eq(x.b.a16CaQuebrada,2)
  x.vez("b");t.ok(x.usar("mesa/quebrar-escudo","a")~=nil);t.eq(x.api.estado().acoes.usadas,0)
  x.api.descartarTudo();t.eq(escudo.equipped,true);t.eq(x.b.a16CaQuebrada,nil)
 end,
 ["Soberano deixa cobertura parcial de um ataque e expira posição na próxima vez"] = function(t)
  local x=contexto({15,1,8,8});table.insert(x.a.ficha2.construction.inventory,{name="Escudo",type="armadura",equipped=true})
  table.insert(x.a.ficha2.construction.purchasedIds,"talent/cavalaria-e-escudos/Principiante/puro-escudo")
  t.eq(x.usar(id("cavalaria-e-escudos","golpe-de-escudo-soberano"),"b"),nil)
  x.a.x=4;x.c.x=6;x.c.z=5;x.api.moveu(x.c,7,5);x.c.x=5;x.c.z=5;x.api.moveu(x.c,6,5)
  t.ok(table.find(x.api.estadosDe(x.c),"coberturaProximoAtaque"))
  x.b.x=6;x.vez("b");t.eq(x.usar("mesa/ataque-basico","c"),nil);t.eq(x.c.pv,60)
  t.eq(table.find(x.api.estadosDe(x.c),"coberturaProximoAtaque"),nil)
  t.eq(x.usar("mesa/ataque-basico","c"),nil);t.ok(x.c.pv<60)
 end,

 ["Corte aparado não desarma apesar de teste pré-rolado falho"] = function(t)
  local x=contexto({6,1});x.b.ficha2.construction.unlockedRankIds={"rank/deus-da-agua-corpo/Principiante"};x.b.ficha2.construction.purchasedIds={id("deus-da-agua-corpo","aparar")}
  x.api.reacoes.decidir=function() return "aparar" end
  t.eq(x.usar(id("deus-da-espada","corte-de-braco"),"b"),nil)
  t.eq(x.b.pv,60);t.eq(x.b.ficha2.construction.inventory[1].equipped,true);t.eq(#x.api.estado().objetos,0)
 end,
 ["Arremesso não oferece Aparar de corpo a corpo"] = function(t)
  local x=contexto({6});x.b.ficha2.construction.unlockedRankIds={"rank/deus-da-agua-corpo/Principiante"};x.b.ficha2.construction.purchasedIds={id("deus-da-agua-corpo","aparar")}
  local perguntas=0;x.api.reacoes.decidir=function() perguntas+=1;return "aparar" end
  t.eq(x.usar(id("deus-do-norte","arremesso-de-espada"),"b"),nil);t.eq(perguntas,0);t.ok(x.b.pv<60)
 end,

 ["IA abre corredor golpeando barreira que não consegue contornar"] = function(t)
  local x=contexto({15});x.b.x=8;x.b.ficha2=nil;x.b.kind="npc";x.b.ia=true;x.c.pv=0
  x.b.criatura={ca=10,bonusResistencia=0,bonusAtaque=3,patamar=1,danoPorTurno=16,deslocamentoMetros=9,categoria="humanoide",resistencias={},imunidades={}}
  for i=1,100 do x.terrain[i..":4"]="parede";x.terrain[i..":6"]="parede" end
  t.eq(x.usar(id("terra","muro-de-terra"),nil,{x=6,z=5}),nil);x.vez("b");x.api.turnoDoInimigo(x.b)
  t.eq(x.a.pv,60);t.eq(x.api.estado().muros[1].pv,24)
 end,

 ["arrastar físico em frente não trata a casa antiga do par como obstáculo"] = function(t)
  local x=contexto({15,1});t.eq(x.usar(id("armas-pesadas","agarrao"),"b"),nil)
  t.eq(x.usar("mesa/arrastar",nil,{x=8,z=5}),nil);t.eq(x.a.x,7);t.eq(x.b.x,8);t.ok(tem(x.b,"agarrado"))
 end,

 ["Estancar encerra marcador de sangramento do resolvedor genérico"] = function(t)
  local x=contexto({}, { ["teste/sangramento"]={tipo="efeito",basico=true,acoes=0,alvo="si",estados={{nome="sangramento",valor=true}}} })
  t.eq(x.usar("teste/sangramento"),nil);t.ok(table.find(x.api.estadosDe(x.a),"sangramento"))
  t.eq(x.usar(id("cura","estancar"),"a"),nil);t.eq(table.find(x.api.estadosDe(x.a),"sangramento"),nil);t.eq(x.api.estado().acoes.usadas,2)
 end,

 ["Mão de Terra termina se conjurador ficar Caído ainda com PV"] = function(t)
  local x=contexto({1});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
  x.a.conditions={{id="caido",stacks=1}};x.vez("b");t.eq(tem(x.b,"agarrado"),false);t.eq(tem(x.b,"atolado"),false)
 end,

	["pedidos inválidos/fora da vez/não dono não cobram"] = function(t)
		local x=contexto();t.ok(x.handlers.usarHabilidade({UserId=123},false,false)~=nil)
		t.ok(x.usar(id("terra","mao-de-terra"),"b",nil,999)~=nil);t.eq(x.api.estado().acoes.usadas,0)
		t.ok(x.usar("mesa/arrastar",nil,{x=0/0,z=5})~=nil);t.eq(x.api.estado().acoes.usadas,0)
		t.eq(x.handlers.usarHabilidade({UserId=123},{tokenId="b",habilidadeId="mesa/escapar"},false),"Aguarde a vez dessa ficha.")
	end,
}
