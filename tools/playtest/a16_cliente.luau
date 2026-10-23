-- Cliente real, mesa descartável, pedidos remotos e renderização A16.
local remote=game.ReplicatedStorage:WaitForChild("Mesa")
local player=game.Players.LocalPlayer
local State=require(player.PlayerScripts.Client.MesaState)
local R={pronto=false,falhas=0,linhas={}}
shared.A16=R
local snapshot,logs=nil,{}
local conn=remote.OnClientEvent:Connect(function(k,d)
	if k=="snapshot" then snapshot=d elseif k=="log" then table.insert(logs,d.text) end
end)
local function check(n,ok) table.insert(R.linhas,(if ok then "OK " else "FALHA ")..n);if not ok then R.falhas+=1 end end
local function send(c,p,w) remote:FireServer(c,p or {});task.wait(w or 0.45) end
local function proxima() send("nextTurn",{expectedId=snapshot.combat.turnId,expectedTurn=snapshot.combat.turn}) end
local function carta(arvore,id) return "ability/"..arvore.."/Principiante/"..id end
task.spawn(function()
	local ok,erro=pcall(function()
		if State.snapshot()==nil then State.start();State.ready();task.wait(0.5) end
		send("requestSnapshot");send("combatEnd");send("tableClear")
		send("escolherPersonagem",{id="guerreiro-do-norte"});send("iniciarTreino",{},1.5);send("combatEnd")
		local a
		for _,token in snapshot.tokens do if token.ownerUserId==player.UserId and token.kind=="jogador" then a=token end end
		assert(a,"Norte não criado")
		local limpar={};for x=3,11 do for z=3,9 do table.insert(limpar,{x=x,z=z}) end end
		send("paintCells",{brush="limpar",cells=limpar});send("paintCells",{brush="revelar",cells=limpar})
		send("move",{id=a.id,x=5,z=5})
		for _, arvore in {"terra","teorica"} do send("abrirRank",{tokenId=a.id,arvore=arvore,rank="Principiante"}) end
		for _, id in {carta("deus-do-norte","arremesso-de-espada"),carta("terra","mao-de-terra"),carta("teorica","anteparo-teorico")} do send("aprender",{tokenId=a.id,habilidadeId=id}) end
		send("criarPremontado",{id="espadachim",ownerUserId=0,x=6,z=5},3)
		local b;for _,token in snapshot.tokens do if token.name:find("Kaito",1,true) then b=token end end
		assert(b,"alvo não criado: "..table.concat(logs," | ",math.max(1,#logs-4)))
		send("move",{id=b.id,x=6,z=5})
		send("combatStart",{entries={{id=a.id,initiative=20},{id=b.id,initiative=10}}})
		State.setTableView(true)
		send("usarHabilidade",{tokenId=a.id,habilidadeId=carta("deus-do-norte","arremesso-de-espada"),alvoId=b.id})
		check("arremesso gera objeto no snapshot",#snapshot.jogo.objetos==1)
		check("arma aparece no tabuleiro",workspace.ArmasNoChao:FindFirstChild(snapshot.jogo.objetos[1].id)~=nil)
		local gui=player.PlayerGui.AcoesDoTurno
		check("recuperar aparece na barra",gui:FindFirstChild("Carta_mesa/pegar-arma",true)~=nil)
		State.setMira({tokenId=a.id,habilidadeId="mesa/pegar-arma",tipo="utilidade",modo="casa"});State.dispararMira(nil,6,5);task.wait(0.6)
		check("recuperação por mira remove arma",#snapshot.jogo.objetos==0 and #workspace.ArmasNoChao:GetChildren()==0)
		check("recuperação custa uma Ação",snapshot.jogo.acoes.usadas==2)
		proxima();proxima()
		-- A resistência pode passar: respeita o dado e prepara uma nova tentativa.
  local preso=false
  for tentativa=1,20 do
   send("adjust",{id=a.id,field="mana",delta=999}) -- bancada descartável, sem alterar ficha persistente
   send("usarHabilidade",{tokenId=a.id,habilidadeId=carta("terra","mao-de-terra"),alvoId=b.id})
   for _,cond in State.findToken(b.id).conditions do if cond.id=="agarrado" then preso=true end end
   if preso then break end
   proxima();proxima()
  end
  assert(preso,"alvo resistiu às 20 tentativas; nenhum resultado foi forçado")
		check("alvo recebe controle escapar",table.find(State.findToken(b.id).habilidades,"mesa/escapar")~=nil)
		check("conjurador recebe arrastar e soltar",gui:FindFirstChild("Carta_mesa/arrastar",true)~=nil and gui:FindFirstChild("Carta_mesa/soltar",true)~=nil)
		proxima()
		check("escapar aparece na vez do alvo",gui:FindFirstChild("Carta_mesa/escapar",true)~=nil)
		State.setMira({tokenId=b.id,habilidadeId="mesa/escapar",tipo="utilidade",modo="confirmar"});State.dispararMira();task.wait(0.6)
		check("escape por mira custa uma Ação",snapshot.jogo.acoes.usadas==1)
		proxima();send("usarHabilidade",{tokenId=a.id,habilidadeId="mesa/soltar"})
		send("usarHabilidade",{tokenId=a.id,habilidadeId=carta("teorica","anteparo-teorico"),x=5,z=6})
		local muro=snapshot.jogo.muros[1]
		check("anteparo 30 PV chega ao cliente",muro and muro.pv==30)
		local modelo=muro and workspace.MurosDeFogo:FindFirstChild(muro.id)
		check("PV da barreira é desenhado",modelo and modelo:FindFirstChild("PV",true)~=nil)
		proxima();proxima()
		State.setMira({tokenId=a.id,habilidadeId="mesa/ataque-basico",tipo="ataque",modo="ficha"});State.dispararMira(nil,5,6);task.wait(0.6)
		check("ataque na casa reduz PV da barreira",snapshot.jogo.muros[1].pv<30)
		check("sem erro interno",not table.concat(logs,"\n"):find("Erro interno",1,true))
		send("combatEnd");send("tableClear")
	end)
	if not ok then check(tostring(erro),false) end
	conn:Disconnect();R.pronto=true
end)
return "A16 cliente iniciado"
