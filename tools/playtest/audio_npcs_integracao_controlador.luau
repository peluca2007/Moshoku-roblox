local View=require(game.Players.LocalPlayer.PlayerScripts.Client.VozesNPCsView)
local Sonorizacao=require(game.Players.LocalPlayer.PlayerScripts.Client.Sonorizacao)
local linhas, falhas={},0
local function check(nome,ok) table.insert(linhas,(if ok then "OK " else "FALHA ")..nome);if not ok then falhas+=1 end end
local function fixture(s)
	local listeners={};local state={}
	state.snapshot=function()return s end
	state.findToken=function(id)for _,t in s.tokens do if t.id==id then return t end end end
	state.onSnapshot=function(f)listeners.snapshot=f;f(s)end
	state.onEfeito=function(f)listeners.efeito=f end
	state.onEncontro=function(f)listeners.encontro=f end
	return state,listeners
end
local boss={id="bancada-boss",vozNPC="boss__treant-anciao",pv=100,pvMax=100}
local s={combat={active=true,turn=1},tokens={boss},encontro={chefe={id=boss.id,fase=1}}}
local state,listeners=fixture(s);local api=View.start(state)
check("entrada cria voz no motor",api.estado().ativos==1 and string.find(api.estado().historico[1],"entrada")~=nil)
s.encontro.chefe.fase=2;listeners.snapshot(s)
check("fase de mesma prioridade espera sem perder ou sobrepor",api.estado().ativos==1 and api.estado().fila==1)
table.insert(s.tokens,{id="bancada-goblin",vozNPC="npc__goblin-batedor",pv=10,pvMax=10});listeners.snapshot(s)
check("fase pendente do chefe nao bloqueia segundo canal de outro NPC",api.estado().ativos==2 and api.estado().fila==1)
s.encontro.chefe.aviso={id=1,fase=2};listeners.snapshot(s)
local h=api.estado().historico
check("aviso interrompe entrada e tem precedencia",string.find(h[#h],"ruptura%-aviso")~=nil and api.estado().ativos==2)
listeners.snapshot(s);check("snapshot repetido nao repete aviso",#api.estado().historico==#h)
s.tokens={};listeners.snapshot(s);check("ocultacao interrompe audio e fila",api.estado().ativos==0 and api.estado().fila==0)
s.tokens={boss};api.destruir();local n=#api.estado().historico
listeners.snapshot(s);listeners.efeito({casterId=boss.id,habilidadeId="criatura/ataque",alvos={}});listeners.encontro({})
task.wait(.15);check("destruir impede callbacks registrados de recriar sons",api.estado().ativos==0 and #api.estado().historico==n)
local original=Sonorizacao.volume();Sonorizacao.volume(0)
local muted=View.start(fixture({combat={active=true,turn=1},tokens={boss}}))
check("volume zero respeitado sem fila futura",muted.estado().ativos==0 and muted.estado().fila==0);muted.destruir();Sonorizacao.volume(original)
local many={combat={active=true,turn=1},tokens={}}
for i=1,10 do table.insert(many.tokens,{id="bancada"..i,vozNPC="npc__goblin-batedor",pv=10,pvMax=10}) end
local st,ls=fixture(many);local crowd=View.start(st)
check("dez criaturas respeitam duas vozes e quatro pendentes",crowd.estado().ativos<=2 and crowd.estado().fila<=4)
many.combat.active=false;ls.snapshot(many)
check("fim de combate cancela sons e pendencias",crowd.estado().ativos==0 and crowd.estado().fila==0);crowd.destruir()
return game.HttpService:JSONEncode({falhas=falhas,linhas=linhas})
