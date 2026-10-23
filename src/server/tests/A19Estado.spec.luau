-- SOMENTE STUDIO: controlador servidor isolado; relógio/RNG/execução injetados.
local S=require(script.Parent.Parent.FormulasService)
local P=require(game.ReplicatedStorage.Shared.Regras.Progressao)
local function ambiente(rank,fila)
	local a={id="a",name="Teórico",ownerUserId=1,x=5,z=5,pv=100,pvMax=100,mana=30,manaMax=30,version=1,
		ficha2={construction={unlockedRankIds={P.idDoRank("teorica",rank or "Principiante")},purchasedIds={}},calculated={attributes={espirito=0},highestRankBonus=1}}}
	local b={id="b",name="Outro",ownerUserId=2,x=6,z=5,pv=100,mana=30,manaMax=30,version=1}
	local tokens={a=a,b=b}; local combat={active=true,current="a",turn=1}; local handlers,logs,execs={},{},{}
	local turnos={}; local time=0; local geo=nil; local reacao=true; local incapaz=false; local silencioso=false
	local rng=table.clone(fila or {}); local limite=3
	local ctx={tokens=tokens,tokenOrder={"a","b"},combat=combat,handlers=handlers,agora=function() return time end,
		canSee=function(_,t) return not t.hidden end,semAcoes=function(t) return t==a and incapaz end,
		reacoes={pendente=function() return false end,temReacao=function() return reacao end},currentTurnId=function() return combat.current end,
		turno=function(id) local k=id..combat.turn; turnos[k]=turnos[k] or {usadas=0,usos={}}; return turnos[k] end,
		limiteDeAcoes=function() return limite end,bc=function() return 3 end,condicoesDe=function(t) return t.conds or {} end,
		silenciado=function() return silencioso end,patamar=function() return 1 end,publico=function(t) return not t.hidden end,
		validarAlvo=function() return geo end,executar=function(_,t,m,p,bc) table.insert(execs,{token=t,m=m,p=p,bc=bc}); return nil end,
		logAboutToken=function(_,txt) table.insert(logs,txt) end,random={NextInteger=function() return table.remove(rng,1) or 10 end}}
	local api=S.novo(ctx)
	local x={a=a,b=b,api=api,combat=combat,ctx=ctx,handlers=handlers,execs=execs,logs=logs,tokens=tokens}
	x.send=function(c,p,id) return handlers[c]({UserId=id or 1},p,false) end
	x.desenhar=function(extra)
		local p={tokenId="a",essencia="mana",verbo="lancar",forma="circulo",potencia=rank or "Principiante",alvoId="b"}
		for k,v in extra or {} do p[k]=v end
		return x.send("desenharFormula",p)
	end
	x.vez=function(id) local old=combat.current; combat.current=id; combat.turn+=1; api.aoTrocarVez(old,id) end
	x.now=function(n) time=n end; x.geo=function(e) geo=e end; x.reacao=function(v) reacao=v end; x.incapaz=function(v) incapaz=v end
	x.silencio=function(v) silencioso=v end; x.limite=function(n) limite=n end
	x.preparar=function(meio,v)
		return x.send("prepararFormula",{tokenId="a",essencia="mana",verbo=v or "erguer",forma="quadrado",potencia="Principiante",meio=meio or "giz"})
	end
	return x
end
return {
	["A19 custo reservado uma vez, intenção canônica, executor sem custo duplicado"] = function(t)
		local x=ambiente(); t.eq(x.desenhar({qualidade=.01}),nil); t.eq(x.a.mana,29); t.eq(x.ctx.turno("a").usadas,2)
		t.eq(#x.execs,1); t.eq(x.execs[1].m.pm,0); t.eq(x.execs[1].m.acoes,0); t.eq(x.execs[1].p.qualidade,nil)
		t.eq(x.desenhar(),"Só uma fórmula desenhada que fere por turno."); t.eq(x.a.mana,29)
	end,
	["A19 tipos/contexto/forma/rank/essência/alvo recusados antes do custo"] = function(t)
		local x=ambiente(); t.ok(x.send("desenharFormula",false)); t.ok(x.desenhar({forma="triangulo"})); t.ok(x.desenhar({potencia="Rei"})); t.ok(x.desenhar({essencia="fogo"}))
		t.ok(x.desenhar({qualidade=0/0})); t.ok(x.desenhar({alvoId={}})); t.ok(x.desenhar({x=0,z=5}))
		t.ok(x.send("desenharFormula",{tokenId="a"},2)); x.a.hidden=true; t.ok(x.desenhar()); x.a.hidden=nil
		x.geo("Sem visão"); t.ok(x.desenhar()); t.eq(x.a.mana,30); t.eq(x.ctx.turno("a").usadas,0); t.eq(#x.execs,0)
	end,
	["A19 Rei divide 3+1 Ações e só paga PM ao começar"] = function(t)
		local x=ambiente("Rei"); t.eq(x.desenhar(),nil); t.eq(x.a.mana,20); t.eq(#x.execs,0); t.eq(x.api.desenhando(x.a),true)
		t.ok(x.desenhar()); x.vez("b"); t.ok(x.send("continuarFormula",{tokenId="a"})); x.vez("a")
		t.eq(x.send("continuarFormula",{tokenId="a"}),nil); t.eq(x.ctx.turno("a").usadas,1); t.eq(x.a.mana,20); t.eq(#x.execs,1)
		t.eq(x.api.ocupado(x.a),false); t.ok(x.desenhar())
	end,
	["A19 Principiante pode dividir se só restar 1 Ação"] = function(t)
		local x=ambiente(); x.ctx.turno("a").usadas=2; t.eq(x.desenhar(),nil); t.eq(#x.execs,0)
		x.vez("b"); x.vez("a"); t.eq(x.send("continuarFormula",{tokenId="a"}),nil); t.eq(#x.execs,1); t.eq(x.a.mana,29)
	end,
	["A19 Perda de Foco perde metade PM e Ações sem efeito"] = function(t)
		local x=ambiente("Rei"); x.desenhar(); x.vez("b"); x.vez("a"); x.vez("b")
		t.eq(x.api.desenhando(x.a),false); t.eq(x.a.mana,25); t.eq(#x.execs,0); t.eq(x.ctx.turno("a").usadas,0)
	end,
	["A19 concentração falha reembolsa teto da metade; preserva as 3 Ações"] = function(t)
		local x=ambiente("Avançado",{1}); x.limite(2); x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{},5)
		t.eq(x.api.desenhando(x.a),false); t.eq(x.a.mana,28); t.eq(x.ctx.turno("a").usadas,2); t.eq(#x.execs,0)
	end,
	["A19 concentração sucesso e zero dano conservam progresso"] = function(t)
		local x=ambiente("Rei",{20}); x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{},0); t.eq(x.api.desenhando(x.a),true)
		x.api.aoSofrerDano(x.a,x.b,{},1); t.eq(x.api.desenhando(x.a),true); t.eq(x.a.mana,20)
	end,
	["A19 Traço Firme refaz uma falha por combate, sem novo custo"] = function(t)
		local x=ambiente("Rei",{1,20,1}); table.insert(x.a.ficha2.construction.purchasedIds,"talent/teorica/Principiante/traco-firme")
		x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{},3); t.eq(x.api.desenhando(x.a),true)
		x.api.aoSofrerDano(x.a,x.b,{},3); t.eq(x.api.desenhando(x.a),false); t.eq(x.a.mana,25)
	end,
	["A19 Corte de Braço dá Desvantagem ao teste daquele golpe"] = function(t)
		local x=ambiente("Rei",{20,1}); x.desenhar(); x.api.aoSofrerDano(x.a,x.b,{corteBraco=true},1)
		t.eq(x.api.desenhando(x.a),false)
	end,
	["A19 usar Reação interrompe, cancelamento livre não exige sua vez"] = function(t)
		local x=ambiente("Rei"); x.desenhar(); x.vez("b"); x.reacao(false); x.api.revalidar(); t.eq(x.api.desenhando(x.a),false)
		x.vez("a"); x.reacao(true); x.desenhar(); x.vez("b"); t.eq(x.send("cancelarFormula",{tokenId="a"}),nil); t.eq(x.api.desenhando(x.a),false)
	end,
	["A19 incapacidade e perda de alcance interrompem sem teste"] = function(t)
		local x=ambiente("Rei"); x.desenhar(); x.geo("Alvo saiu do alcance"); x.api.revalidar(); t.eq(x.api.desenhando(x.a),false)
		x=ambiente("Rei"); x.desenhar(); x.incapaz(true); x.api.revalidar(); t.eq(x.api.desenhando(x.a),false)
	end,
	["A19 PM/Ações insuficientes e silêncio não iniciam conjuração"] = function(t)
		local x=ambiente(); x.a.mana=0; t.ok(x.desenhar()); t.eq(x.api.desenhando(x.a),false)
		x.a.mana=30; x.ctx.turno("a").usadas=3; t.ok(x.desenhar()); t.eq(x.a.mana,30)
		x.ctx.turno("a").usadas=0; x.silencio(true); t.ok(x.desenhar()); t.eq(#x.execs,0)
	end,
	["A19 preparo só fora de combate, sem PM; Lançar/Vida não prepara"] = function(t)
		local x=ambiente(); t.ok(x.preparar()); x.combat.active=false; t.eq(x.preparar(),nil); t.eq(x.a.mana,30)
		t.ok(x.preparar("giz","lancar")); t.ok(x.preparar("bolso")); t.eq(#x.execs,0)
	end,
	["A19 alimentador sem Teórica paga PM/1 Ação; BC fica na fórmula"] = function(t)
		local x=ambiente(); x.combat.active=false; t.eq(x.preparar(),nil); x.now(60); x.combat.active=true; x.vez("b")
		t.eq(x.send("ativarFormula",{tokenId="b",x=7,z=5},2),nil); t.eq(x.b.mana,28); t.eq(x.a.mana,30); t.eq(x.ctx.turno("b").usadas,1)
		t.eq(x.execs[1].bc,3); t.eq(x.api.temPreparada(x.a),false); t.ok(x.send("ativarFormula",{tokenId="b",x=7,z=5},2))
	end,
	["A19 um minuto real e contexto de toque; preparo incompleto cancela ao lutar"] = function(t)
		local x=ambiente(); x.combat.active=false; x.preparar(); x.now(59); x.combat.active=true
		t.ok(x.send("ativarFormula",{tokenId="a",x=5,z=6})); t.eq(x.a.mana,30)
		x.vez("b"); x.now(61); t.eq(x.api.temPreparada(x.a),false)
		x.combat.active=false; x.preparar(); x.now(121); x.combat.active=true; x.vez("b"); x.b.x=9
		t.ok(x.send("ativarFormula",{tokenId="b",x=9,z=6},2)); t.eq(x.b.mana,30)
	end,
	["A19 Bolso sobrevive descanso; giz expira; descartar limpa ambos"] = function(t)
		local x=ambiente(); table.insert(x.a.ficha2.construction.purchasedIds,"talent/teorica/Principiante/simbolo-rejeitar")
		x.combat.active=false; x.preparar("bolso"); x.now(60); x.api.descanso(); t.eq(x.api.temPreparada(x.a),true)
		x.api.descartar(); t.eq(x.api.temPreparada(x.a),false)
		x.preparar("giz"); x.now(120); x.api.descanso(); t.eq(x.api.temPreparada(x.a),false)
	end,
	["A19 falha de alvo/recursos na ativação preserva pergaminho"] = function(t)
		local x=ambiente(); x.combat.active=false; x.preparar(); x.now(60); x.combat.active=true
		x.geo("Sem visão"); t.ok(x.send("ativarFormula",{tokenId="a",x=5,z=6})); t.eq(x.api.temPreparada(x.a),true)
		x.geo(nil); x.a.mana=0; t.ok(x.send("ativarFormula",{tokenId="a",x=5,z=6})); t.eq(x.api.temPreparada(x.a),true)
	end,
}
