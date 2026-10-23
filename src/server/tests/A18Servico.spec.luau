-- SOMENTE STUDIO: serviço real com mesa/jogadores injetados.
local Encontro = require(script.Parent.Parent.EncontroService)
local ChefesService = require(script.Parent.Parent.ChefesService)
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalogo=require(Shared.Livro.Catalogo)
local Criaturas=require(Shared.Regras.Criaturas)
local C=require(Shared.Regras.Chefes)
local function mesa(n)
	local jogadores,tokens,avisos,handlers={},{},{},{}
	for i=1,n do jogadores[i]={UserId=2000+i,DisplayName="A18_"..i} end
	local combat={active=false,turn=0,order={}}
	local sequencia,tempo,turno,vezes=0,100,nil,0
	handlers.tableClear=function() table.clear(tokens) end
	handlers.combatEnd=function() combat.active=false end
	handlers.combatStart=function(_,p) combat.active=true; combat.turn+=1; combat.order=p.entries end
	handlers.criarPremontado=function(_,p)
		sequencia+=1; local id="a18_"..sequencia
		tokens[id]={id=id,name=p.id,kind="jogador",ownerUserId=p.ownerUserId,x=p.x,z=p.z,pv=30,pvMax=30,mana=10,manaMax=10,version=1,conditions={},ficha2={calculated={initiative={bonus=1}}}}
		return nil,{id=id}
	end
	handlers.criarCriatura=function(_,p)
		sequencia+=1; local id="a18_"..sequencia
		local f=Criaturas.ficha(Catalogo.POR_ID[p.creatureId])
		tokens[id]={id=id,name=f.nome,kind="npc",x=p.x,z=p.z,pv=f.pvMax,pvMax=f.pvMax,mana=0,manaMax=0,version=1,conditions={},criatura=f}
		return nil,{id=id}
	end
	local h={turnoDoInimigo=function() vezes+=1; return true end}
	local deps={handlers=handlers,tokens=tokens,combat=combat,random={NextInteger=function(_,lo) return lo end},
		secreto=function(tk) return tk.hidden==true end,
		remote={FireAllClients=function(_,kind,data) table.insert(avisos,{kind=kind,data=data}) end},habilidades=function() return h end,
		avancarVez=function() end,mudou=function() end,logAll=function() end,currentTurnId=function() return turno end,
		desligarTreino=function() end,jogadores=function() return jogadores end,agora=function() return tempo end,esperaDoFim=0}
	local api=Encontro.start(deps)
	return {api=api,handlers=handlers,tokens=tokens,jogadores=jogadores,combat=combat,avisos=avisos,deps=deps,h=h,
		relogio=function() tempo+=1 end,vez=function(id) turno=id; combat.turn+=1; api.aoTrocarVez(id) end,fallbacks=function() return vezes end}
end
local function equipe(m,i,e) return m.handlers.entrarFila(m.jogadores[i],{modo="duelo",equipe=e}) end
local function esperar(cond)
	for _=1,35 do if cond() then return true end; task.wait(.1) end
	return false
end
return {
	["equipes permitem 1x1 2x1 2x2 3x3 e 31x1"] = function(t)
		for _,par in {{1,1},{2,1},{2,2},{3,3},{31,1}} do
			local m=mesa(par[1]+par[2]); for i=1,#m.jogadores do t.eq(equipe(m,i,if i<=par[1] then 1 else 2),nil) end
			t.eq(m.handlers.iniciarDuelo(m.jogadores[1],{},false),nil); t.eq(#m.combat.order,#m.jogadores)
			t.eq(m.api.publico().equipes[2001],1); t.ok(m.api.emDuelo()); m.api.desligar()
		end
	end,
	["contexto frequencia e payload nao alteram equipe"] = function(t)
		local m=mesa(2); t.eq(equipe(m,1,1),nil); t.ok(equipe(m,1,2)~=nil); t.eq(m.api.sala(m.jogadores[1]).equipe,1)
		m.relogio(); t.ok(m.handlers.entrarFila(m.jogadores[1],{modo="duelo",equipe=1,alvo=2002})~=nil)
		equipe(m,2,2); m.handlers.iniciarDuelo(m.jogadores[1],{},false)
		t.ok(equipe(m,1,2)~=nil); t.eq(m.api.publico().equipes[2001],1); m.api.desligar()
	end,
	["uma so equipe aguarda adversario sem apagar mesa"] = function(t)
		local m=mesa(2); equipe(m,1,1); equipe(m,2,1)
		t.ok(m.handlers.iniciarDuelo(m.jogadores[1],{},false)~=nil); t.eq(m.combat.active,false)
	end,
	["mesmaEquipe exposta inclui aliados e invocados"] = function(t)
		local m=mesa(3); equipe(m,1,1); equipe(m,2,1); equipe(m,3,2); m.handlers.iniciarDuelo(m.jogadores[1],{},false)
		t.ok(m.api.mesmaEquipe({ownerUserId=2001},{ownerUserId=2002})); t.ok(not m.api.mesmaEquipe({ownerUserId=2001},{ownerUserId=2003}))
		t.eq(m.api.equipeDe({ownerUserId=2002}),1); m.api.desligar(); t.ok(not m.api.mesmaEquipe({ownerUserId=2001},{ownerUserId=2002}))
	end,
	["vitoria de equipe aguarda todos os adversarios cairem"] = function(t)
		local m=mesa(3); equipe(m,1,1); equipe(m,2,1); equipe(m,3,2); m.handlers.iniciarDuelo(m.jogadores[1],{},false)
		for _,tk in m.tokens do if tk.ownerUserId==2001 then tk.pv=0 end end
		task.wait(.6); t.eq(#m.avisos,0)
		for _,tk in m.tokens do if tk.ownerUserId==2003 then tk.pv=0 end end
		t.ok(esperar(function() return #m.avisos>0 end)); t.eq(m.avisos[1].data.vencedor,"Equipe 1"); t.eq(m.api.publico(),nil)
	end,
	["desconexao retira fila e derrota todo dono"] = function(t)
		local m=mesa(3); equipe(m,1,1); equipe(m,2,1); equipe(m,3,2); m.handlers.iniciarDuelo(m.jogadores[1],{},false)
		m.api.remover(m.jogadores[3]); t.ok(esperar(function() return #m.avisos>0 end)); t.eq(m.avisos[1].data.vencedor,"Equipe 1")
	end,
	["cada nivel cria desafio e chefe conforme catalogo"] = function(t)
		for n=1,3 do
			local m=mesa(4); for i=2,4 do m.handlers.entrarFila(m.jogadores[i],{modo="luta"}) end
			t.eq(m.handlers.iniciarLuta(m.jogadores[1],{nivel=n},false),nil)
			t.eq(m.api.publico().nivel,n)
			if n==3 then local b=m.api.publico().chefe; t.eq(b.nome,C.NOME); t.eq(b.pv,Criaturas.ficha(Catalogo.POR_ID[C.ID]).pvMax) else t.eq(m.api.publico().chefe,nil) end
			m.api.desligar()
		end
	end,
	["nivel invalido ou excesso PvE preserva mesa"] = function(t)
		local m=mesa(5); t.ok(m.handlers.iniciarLuta(m.jogadores[1],{nivel="3"},false)~=nil); t.eq(next(m.tokens),nil)
		for i=2,5 do m.handlers.entrarFila(m.jogadores[i],{modo="luta"}) end
		t.ok(m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)~=nil); t.eq(next(m.tokens),nil)
	end,
	["chefe prepara um turno antes sem dano e resolve pelo fallback"] = function(t)
		local m=mesa(1); m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)
		local b; for _,tk in m.tokens do if tk.ia then b=tk end end
		local serv=ChefesService.start(m.deps)
		t.ok(serv.turno(b)); t.ok(serv.publico(b).aviso); t.eq(m.fallbacks(),0)
		t.ok(serv.turno(b)); t.eq(m.fallbacks(),1); t.eq(serv.publico(b).aviso,nil); t.eq(m.avisos[1].data.integrado,false)
		m.api.desligar()
	end,
	["gancho recebe so os alvos ainda na area congelada"] = function(t)
		local m=mesa(1); m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)
		local b,j; for _,tk in m.tokens do if tk.ia then b=tk else j=tk end end
		local recebidos
		m.h.golpeDeCriatura=function(a,alvos,mec,estilo) recebidos=alvos; t.eq(a,b); t.eq(mec.tipo,"ataque"); t.eq(mec.partes[1].fixo,b.criatura.danoPorTurno); t.eq(estilo.estilo,"raizes"); return true end
		local serv=ChefesService.start(m.deps); serv.turno(b); j.x=1; j.z=1; serv.turno(b)
		t.eq(#recebidos,0); t.eq(m.fallbacks(),0); t.eq(m.avisos[1].data.integrado,true); m.api.desligar()
	end,
	["limpeza e incapacidade cancelam area pendente"] = function(t)
		local m=mesa(1); m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)
		local b; for _,tk in m.tokens do if tk.ia then b=tk end end
		local serv=ChefesService.start(m.deps); serv.turno(b); serv.limpar(); t.eq(serv.publico(b).aviso,nil)
		serv.turno(b); b.conditions={{id="inconsciente"}}; serv.turno(b); t.eq(serv.publico(b).aviso,nil); t.eq(m.fallbacks(),1)
		m.api.desligar()
	end,
	["troca real de vez despacha chefe em vez da IA comum"] = function(t)
		local m=mesa(1); m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)
		local b; for _,tk in m.tokens do if tk.ia then b=tk end end
		m.vez(b.id); t.ok(esperar(function() return m.api.publico().chefe.aviso~=nil end)); t.eq(m.fallbacks(),0); m.api.desligar()
	end,
	["chefe ou alvo oculto nao vaza vida nem centro do aviso"] = function(t)
		local m=mesa(1); m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)
		local b,j; for _,tk in m.tokens do if tk.ia then b=tk else j=tk end end
		local serv=ChefesService.start(m.deps)
		j.hidden=true; t.eq(serv.turno(b),false); t.eq(serv.publico(b).aviso,nil)
		j.hidden=false; serv.turno(b); b.hidden=true
		t.eq(serv.publico(b),nil); serv.turno(b); t.eq(#m.avisos,0)
		b.hidden=false; b.showStats=false; t.eq(serv.publico(b),nil); m.api.desligar()
	end,
	["inicios simultaneos nao substituem arena durante montagem"] = function(t)
		local m=mesa(1); local criar=m.handlers.criarPremontado
		local entrou=false
		m.handlers.criarPremontado=function(...)
			entrou=true; task.wait(.2); return criar(...)
		end
		local primeiro,terminou
		task.spawn(function() primeiro=m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false); terminou=true end)
		t.ok(esperar(function() return entrou end))
		t.ok(m.handlers.iniciarLuta(m.jogadores[1],{nivel=2},false)~=nil)
		t.ok(esperar(function() return terminou end)); t.eq(primeiro,nil); t.eq(m.api.publico().nivel,3); m.api.desligar()
	end,
	["zero Acoes do motor cancela aviso sem golpe especial"] = function(t)
		local m=mesa(1); m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)
		local b; for _,tk in m.tokens do if tk.ia then b=tk end end
		local serv=ChefesService.start(m.deps); serv.turno(b)
		m.h.estado=function() return {acoes={tokenId=b.id,total=0}} end
		serv.turno(b); t.eq(serv.publico(b).aviso,nil); t.eq(m.fallbacks(),1); t.eq(#m.avisos,0); m.api.desligar()
	end,
	["fim durante fallback nao envia efeito atrasado"] = function(t)
		local m=mesa(1); m.handlers.iniciarLuta(m.jogadores[1],{nivel=3},false)
		local b; for _,tk in m.tokens do if tk.ia then b=tk end end
		local serv=ChefesService.start(m.deps); serv.turno(b)
		m.h.turnoDoInimigo=function() serv.limpar(); return true end
		serv.turno(b); t.eq(#m.avisos,0); m.api.desligar()
	end,
}
