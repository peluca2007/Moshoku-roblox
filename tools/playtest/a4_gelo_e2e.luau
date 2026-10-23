-- Rede e barra reais na mesa descartável de treino. Não salva campanha.
local remote=game.ReplicatedStorage:WaitForChild("Mesa")
local snapshot,efeitos,logs=nil,{},{}
local conn=remote.OnClientEvent:Connect(function(k,d)
 if k=="snapshot" then snapshot=d elseif k=="efeito" then table.insert(efeitos,d) elseif k=="log" then table.insert(logs,d.text) end
end)
local report,failures={},0
local function check(n,ok) table.insert(report,(if ok then "OK " else "FALHA ")..n);if not ok then failures+=1 end end
local function send(k,p,w) remote:FireServer(k,p or {});task.wait(w or 0.3) end
local function eu() for _,t in snapshot.tokens do if t.name:find("Ignis",1,true) then return t end end end
send("iniciarTreino",{},1.2)
local id=eu().id
send("abrirRank",{tokenId=id,arvore="agua",rank="Principiante"})
send("aprender",{tokenId=id,habilidadeId="ability/agua/Principiante/lamina-de-gelo"})
local alvo;for _,t in snapshot.tokens do if t.name=="Boneco de Treino" then alvo=t;break end end
send("move",{id=alvo.id,x=eu().x+1,z=eu().z})
local pm=eu().mana
send("usarHabilidade",{tokenId=id,habilidadeId="ability/agua/Principiante/lamina-de-gelo"},0.4)
check("conjuração custa dois PM",eu().mana==pm-2)
check("duas escolhas aparecem no snapshot",table.find(eu().habilidades,"mesa/lamina-de-gelo-forca") and table.find(eu().habilidades,"mesa/lamina-de-gelo-intelecto"))
local gui=game.Players.LocalPlayer.PlayerGui:FindFirstChild("AcoesDoTurno")
check("barra cria carta de Força",gui and gui:FindFirstChild("Carta_mesa/lamina-de-gelo-forca",true))
check("barra cria carta de Intelecto",gui and gui:FindFirstChild("Carta_mesa/lamina-de-gelo-intelecto",true))
local mini=workspace.MesaFichasLocais:FindFirstChild(id)
check("lâmina permanece junto da ficha",mini and mini:FindFirstChild("LaminaDeGelo"))
local antes=#efeitos
send("usarHabilidade",{tokenId=id,habilidadeId="mesa/lamina-de-gelo-intelecto",alvoId=alvo.id},0.5)
check("ataque chega pelo recibo real",#efeitos==antes+1 and efeitos[#efeitos].habilidadeId=="mesa/lamina-de-gelo-intelecto")
check("ataque usa última ação sem PM adicional",eu().mana==pm-2 and snapshot.jogo.acoes.usadas==3)
local pasta=workspace:FindFirstChild("MagiasLocais");local animado=false
for _,m in pasta and pasta:GetChildren() or {} do if m:GetAttribute("Habilidade")=="mesa/lamina-de-gelo-intelecto" then animado=true end end
check("recibo inicia coreografia na aplicação",animado)
send("combatEnd",{},0.4)
check("fim do combate retira as duas cartas",not table.find(eu().habilidades,"mesa/lamina-de-gelo-forca") and not table.find(eu().habilidades,"mesa/lamina-de-gelo-intelecto"))
check("fim do combate remove arma visual",mini and not mini:FindFirstChild("LaminaDeGelo"))
local cenas=0;for _,m in pasta and pasta:GetChildren() or {} do if m:GetAttribute("Habilidade") then cenas+=1 end end
check("fim do combate cancela coreografias",cenas==0)
conn:Disconnect()
table.insert(report,string.format("A4 rede: %d verificações, %d falhas",#report,failures))
if failures>0 then table.insert(report,logs[#logs] or "") end
return table.concat(report,"\n")
