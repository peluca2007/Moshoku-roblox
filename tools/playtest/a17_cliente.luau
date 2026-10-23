-- Cliente real A17: cartas renderizadas, mira da barra e remotos no Modo Luta.
-- Mesa descartável; não força dados. Limpa a luta ao terminar.
local player=game.Players.LocalPlayer
local remote=game.ReplicatedStorage:WaitForChild("Mesa")
local State=require(player.PlayerScripts.Client.MesaState)
local R={pronto=false,falhas=0,linhas={},logs={}};shared.A17=R
local snapshot
local conn=remote.OnClientEvent:Connect(function(k,d)
	if k=="snapshot" then snapshot=d elseif k=="log" then table.insert(R.logs,d.text)
	elseif k=="reacao" and not d.fechar then remote:FireServer("reagir",{id=d.id}) end
end)
local function check(n,ok) table.insert(R.linhas,(if ok then "OK " else "FALHA ")..n);if not ok then R.falhas+=1 end end
local function send(k,p,w) remote:FireServer(k,p or {});task.wait(w or 0.4) end
local function eu() for _,t in snapshot.tokens do if t.ownerUserId==player.UserId and t.kind=="jogador" then return t end end end
local function inimigo() for _,t in snapshot.tokens do if t.criatura and not t.derrotado then return t end end end
local function tem(id,c) for _,t in snapshot.tokens do if t.id==id then for _,cond in t.conditions do if cond.id==c then return true end end end end;return false end
local function estado(id,n) for _,t in snapshot.tokens do if t.id==id then return table.find(t.estadosCombate or {},n)~=nil end end;return false end
local function vez()
	local inicio=os.clock()
	while snapshot.combat.active and snapshot.combat.turnId~=eu().id and os.clock()-inicio<12 do task.wait(0.3) end
	assert(snapshot.combat.active and snapshot.combat.turnId==eu().id,"não chegou a vez do personagem")
end
local function preparar(id)
	send("combatEnd");send("tableClear");send("escolherPersonagem",{id=id});send("iniciarLuta",{nivel=1},2.5)
	assert(snapshot and eu() and inimigo(),"Modo Luta não montou "..id)
	vez();State.setTableView(true)
	local h,e=eu(),inimigo()
	local casas={};for x=3,16 do for z=3,8 do table.insert(casas,{x=x,z=z}) end end
	send("paintCells",{brush="limpar",cells=casas});send("paintCells",{brush="revelar",cells=casas})
	send("move",{id=e.id,x=15,z=4});send("move",{id=h.id,x=5,z=5});send("move",{id=e.id,x=6,z=5})
	check(id.." está no Modo Luta",snapshot.encontro and snapshot.encontro.modo=="luta")
	return eu(),inimigo()
end
local function usar(id,alvo)
	local h=eu()
	local carta=player.PlayerGui.AcoesDoTurno:FindFirstChild("Carta_"..id,true)
	check(id.." aparece na barra",carta~=nil)
	State.setMira({tokenId=h.id,habilidadeId=id,tipo="efeito",modo=if alvo then "ficha" else "confirmar"})
	State.dispararMira(alvo);task.wait(0.5)
end
task.spawn(function()
	local ok,erro=pcall(function()
		if State.snapshot()==nil then State.start();State.ready();task.wait(0.5) end
		send("requestSnapshot")
		local h,e=preparar("mago-do-vento")
		check("Pés Leves publica alcance oito de Andar",snapshot.jogo.acoes.deslocamentoCasas==8)
		usar("mesa/brisa",e.id);check("Brisa empurra mesmo com resistência",State.findToken(e.id).x==7);check("Brisa zero Ações",snapshot.jogo.acoes.usadas==0)
		usar("mesa/esquivar",e.id);check("Esquivar registra fonte",estado(h.id,"esquiva"))
		usar("mesa/defender");check("Defender registra estado",estado(h.id,"defender"));check("duas ações básicas cobradas",snapshot.jogo.acoes.usadas==2)
		send("criarPremontado",{id="espadachim",ownerUserId=0,x=5,z=6},1.5)
		local aliado;for _,t in snapshot.tokens do if t.id~=h.id and t.kind=="jogador" then aliado=t end end
		assert(aliado,"aliado descartável não criado")
		usar("mesa/ajudar",aliado.id);check("Ajudar registra auxilio",estado(aliado.id,"auxilio"));check("Ajudar cobra terceira Ação",snapshot.jogo.acoes.usadas==3)
		h,e=preparar("maga-da-agua");usar("mesa/molhar",e.id);check("Afinidade aplica Molhado",tem(e.id,"molhado"));check("Afinidade sem PM/Ação",eu().mana==h.mana and snapshot.jogo.acoes.usadas==0)
		h,e=preparar("mago-da-terra");usar("mesa/moldar",e.id);local achou=false
		for _,z in snapshot.jogo.muros do if z.habilidadeId=="mesa/moldar" and z.casas[1][1]==6 then achou=true end end
		check("Moldar publica chão na casa do alvo",achou);check("Moldar zero Ações",snapshot.jogo.acoes.usadas==0)
		h,e=preparar("arqueira");usar("mesa/marcar",e.id);check("Marcar aplica condição",tem(e.id,"marcado"));check("Marcar cobra uma Ação",snapshot.jogo.acoes.usadas==1)
		send("usarHabilidade",{tokenId=h.id,habilidadeId="mesa/ataque-a-distancia",alvoId=e.id})
		check("disparo marcado registra rolagem",#R.logs>0 and table.concat(R.logs,"|"):find("contra CA",1,true)~=nil)
	end)
	if not ok then check("execução: "..tostring(erro),false) end
	send("combatEnd");send("tableClear");conn:Disconnect();R.pronto=true
	table.insert(R.linhas,"A17 cliente: "..R.falhas.." falha(s)")
end)
return "A17 cliente iniciado"
