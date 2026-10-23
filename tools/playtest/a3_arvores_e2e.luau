-- Cliente real, mesa de treino descartável. Não grava campanha.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local C = require(game.ReplicatedStorage.Shared.Livro.Catalogo)
local X = require(game.ReplicatedStorage.Shared.Regras.Execucao)
local P = require(game.ReplicatedStorage.Shared.Regras.Progressao)
local State = require(game.Players.LocalPlayer.PlayerScripts.Client.MesaState)
local snapshot, logs, efeitos = nil, {}, {}
local conn = remote.OnClientEvent:Connect(function(k,d)
 if k == "snapshot" then snapshot=d elseif k == "log" then table.insert(logs,d.text) elseif k == "efeito" then table.insert(efeitos,d) end
end)
local report, falhas = {}, 0
local function check(n,ok,d) if ok then table.insert(report,"OK    "..n) else falhas+=1;table.insert(report,"FALHA "..n.." — "..tostring(d)) end end
local function send(c,p,w) remote:FireServer(c,p or {});task.wait(w or 0.2) end
local function eu() for _, t in snapshot.tokens do if t.ownerUserId==game.Players.LocalPlayer.UserId and t.name:find("Ignis",1,true) then return t end end end
local function proxima()
 send("nextTurn",{expectedId=snapshot.combat.turnId,expectedTurn=snapshot.combat.turn},2.2)
end
if State.snapshot() == nil then State.start(); State.ready(); task.wait(0.3) end
send("iniciarTreino",{},1.2)
local jogador = eu(); check("mesa de treino criada",jogador ~= nil)
local arvores={"agua","vento","terra","cura","desintoxicacao","teorica","invocacao","deus-da-espada","deus-da-agua-corpo","deus-do-norte","armas-pesadas","cavalaria-e-escudos","arquearia"}
for _, arvore in arvores do
 send("abrirRank",{tokenId=jogador.id,arvore=arvore,rank="Principiante"})
 local rank=C.POR_ID[P.idDoRank(arvore,"Principiante")]
 for _, id in rank.data.abilities do
  if not P.gratuita(C.POR_ID[id]) then send("aprender",{tokenId=jogador.id,habilidadeId=id}) end
 end
 local presentes=0
 for _, id in eu().habilidades or {} do if X.arvoreDe(id)==arvore then presentes+=1 end end
 check("cartas de "..arvore.." chegam ao cliente",presentes>0,logs[#logs])
end
local gui=game.Players.LocalPlayer.PlayerGui:FindFirstChild("AcoesDoTurno")
check("barra com rolagem para várias árvores",gui and gui:FindFirstChildWhichIsA("ScrollingFrame",true) ~= nil)
local manual=gui and gui:FindFirstChild("Carta_estancar",true)
check("Estancar aparece como controle manual",manual and manual:GetAttribute("Bloqueada")==true)
local b={};for _,t in snapshot.tokens do if t.name=="Boneco de Treino" then table.insert(b,t) end end
for i,t in b do send("move",{id=t.id,x=10+i,z=15}) end
local id="ability/terra/Principiante/lanca-de-pedra"
State.setMira({tokenId=jogador.id,habilidadeId=id,tipo="efeito",modo="lista",maxAlvos=3})
State.dispararMira(b[1].id);State.dispararMira(b[2].id)
check("mira acumula dois alvos sem enviar",#State.mira().alvoIds==2)
local antes=#efeitos;State.dispararMira();task.wait(0.5)
check("lista confirmada gera recibo de dois alvos",#efeitos==antes+1 and #efeitos[#efeitos].alvos==2,logs[#logs])
check("mira limpa após confirmar",State.mira()==nil)
proxima()
send("aprender",{tokenId=jogador.id,habilidadeId="talent/invocacao/Principiante/pacto-cao-de-caca"})
send("aprender",{tokenId=jogador.id,habilidadeId="talent/invocacao/Principiante/pacto-filhote"})
check("dois pactos disponíveis para escolher",eu().pactos and #eu().pactos==2)
check("controle de escolha de pacto aparece",gui:FindFirstChild("EscolherPacto",true).Visible)
antes=#efeitos
send("usarHabilidade",{tokenId=jogador.id,habilidadeId="ability/invocacao/Principiante/chamado",pactoId="talent/invocacao/Principiante/pacto-cao-de-caca"},0.5)
check("Chamado gera recibo",#efeitos==antes+1,logs[#logs])
local inv;for _,t in snapshot.tokens do if t.name=="Cão de Caça" then inv=t end end
check("Pacto nasce com ações próprias",inv and inv.habilidades and #inv.habilidades==2)
send("nextTurn",{expectedId=snapshot.combat.turnId,expectedTurn=snapshot.combat.turn},0.5)
check("turno do invocado vem após conjurador",inv and snapshot.combat.turnId==inv.id and snapshot.jogo.acoes.total==1)
if inv then
 send("move",{id=inv.id,x=11,z=14});send("move",{id=b[1].id,x=12,z=14})
 send("usarHabilidade",{tokenId=inv.id,habilidadeId="invocado/ataque",alvoId=b[1].id},0.5)
 check("Pacto resolve mordida no alvo",efeitos[#efeitos].habilidadeId=="invocado/ataque",logs[#logs])
 send("usarHabilidade",{tokenId=inv.id,habilidadeId="invocado/ataque",alvoId=b[1].id},0.3)
 check("segunda ação do Pacto recusada",logs[#logs]:find("1 Ação",1,true)~=nil,logs[#logs])
end
send("combatEnd",{},0.5)
local restante=false;for _,t in snapshot.tokens do if t.name=="Cão de Caça" then restante=true end end
check("encerrar combate remove invocado",not restante)
local entradas={{id=jogador.id,initiative=20}}
for _,t in snapshot.tokens do if t.name=="Boneco de Treino" then table.insert(entradas,{id=t.id,initiative=5}) end end
send("combatStart",{entries=entradas})
send("usarHabilidade",{tokenId=jogador.id,habilidadeId="ability/agua/Principiante/nevoa-densa"},0.7)
local zona=snapshot.jogo.muros[1]
check("Névoa tem estilo próprio no snapshot",zona and zona.estilo=="nevoa",logs[#logs])
local modelo=zona and workspace.MurosDeFogo:FindFirstChild(zona.id)
check("Névoa renderiza sem partículas de fogo",modelo and modelo:FindFirstChildWhichIsA("BasePart") and not modelo:FindFirstChildWhichIsA("Fire",true))
send("combatEnd",{},0.3)
send("tableClear",{},0.5);conn:Disconnect()
table.insert(report,"RESUMO: "..falhas.." falha(s)")
return table.concat(report,"\n")
