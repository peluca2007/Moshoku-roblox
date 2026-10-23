-- SOMENTE STUDIO: montagem dos serviços em mesa isolada, sem jogadores reais extras.
local Encontro=require(script.Parent.Parent.EncontroService)
local Treino=require(script.Parent.Parent.TreinoService)
local function ambiente(n,manual)
	local handlers,tokens,players={}, {},{}
	for i=1,n do players[i]={UserId=i,DisplayName="P"..i} end
	local combat={active=false,turn=0};local num=0
	handlers.combatEnd=function() combat.active=false end
	handlers.tableClear=function() table.clear(tokens) end
	local function criar(_,p)
		num+=1;local id="f"..num;tokens[id]={id=id,name=id,kind=if p.creatureId then "npc" else "jogador",ownerUserId=p.ownerUserId,pv=100,pvMax=100,mana=10,manaMax=10,conditions={},version=1,x=p.x,z=p.z};return nil,{id=id}
	end
	handlers.criarPremontado=criar;handlers.criarCriatura=criar
	handlers.createToken=function(_,p) local e,r=criar(nil,p);return e,r.id end
	handlers.combatStart=function(_,p) combat.active=true;combat.order=p.entries end
	local deps={handlers=handlers,tokens=tokens,combat=combat,jogadores=function() return players end,limiteGrupo=10,monstrosManuais=function() return manual end,solicitanteParticipa=function(p) return not manual or p.UserId~=1 end,
		random=Random.new(19),remote={FireClient=function() end},habilidades=function() return nil end,logAll=function() end,mudou=function() end,desligarTreino=function() end,currentTurnId=function() return nil end,avancarVez=function() end}
	return deps,players
end
return {
	["seis e dez personagens entram nos niveis dois e tres sem truncar"] = function(t)
		for _,n in {6,10} do for _,nivel in {2,3} do
			local d,p=ambiente(n,false);local api=Encontro.start(d)
			for _,player in p do t.eq(d.handlers.entrarFila(player,{modo="luta"}),nil) end
			t.eq(d.handlers.iniciarLuta(p[1],{nivel=nivel},true),nil)
			local jogadores=0;local casas={};for _,token in d.tokens do if token.kind=="jogador" then jogadores+=1;local k=token.x..","..token.z;t.eq(casas[k],nil);casas[k]=true end end
			t.eq(jogadores,n);t.ok(d.combat.active);api.desligar();d.combat.active=false
		end end
	end,
	["mestre de monstros nao ganha personagem e inimigos ficam manuais"] = function(t)
		local d,p=ambiente(3,true);local api=Encontro.start(d)
		for i=2,3 do d.handlers.entrarFila(p[i],{modo="luta"}) end
		t.eq(d.handlers.iniciarLuta(p[1],{nivel=2},true),nil)
		local jogadores,monstros=0,0;for _,token in d.tokens do if token.kind=="jogador" then jogadores+=1;t.ok(token.ownerUserId~=1) else monstros+=1;t.eq(token.ia,false);t.eq(token.monstroDoMestre,true) end end
		t.eq(jogadores,2);t.ok(monstros>0);api.desligar();d.combat.active=false
	end,
	["treino cria o grupo inteiro e recarrega cada personagem"] = function(t)
		local d,p=ambiente(6,false);d.personagemDe=function() return "mago-de-fogo" end;d.grupo=function() return p end
		local api=Treino.start(d);t.eq(d.handlers.iniciarTreino(p[1],{},true),nil)
		local n=0;for id,token in d.tokens do if not token.boneco then n+=1;token.mana=0;api.aoTrocarVez(id);t.eq(token.mana,10) end end;t.eq(n,6);api.desligar();d.combat.active=false
	end,
}
