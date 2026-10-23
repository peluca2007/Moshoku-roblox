-- A19: bancada de cliente (Play). Usa o remoto direto (um require de MesaState
-- aqui seria outra instância do módulo, sem remoto). A tela é aberta depois por
-- clique real na carta (a19_tracar.py).
local player=game.Players.LocalPlayer
local remote=game.ReplicatedStorage:WaitForChild("Mesa")
local R={pronto=false,falhas=0,linhas={}}; shared.A19=R
local snap
remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then snap=d end end)
local State={}
function State.send(c,p) remote:FireServer(c,p or {}) end
function State.snapshot() return snap end
function State.findToken(id) for _,t in (snap and snap.tokens) or {} do if t.id==id then return t end end end
function State.setTableView() end
local View={open=function() end}
local function check(nome,ok)
	table.insert(R.linhas,(if ok then "OK " else "FALHA ")..nome); if not ok then R.falhas+=1 end
end
local function send(c,p,w) State.send(c,p or {}); task.wait(w or .5) end
local function proxima()
	local s=State.snapshot(); send("nextTurn",{expectedId=s.combat.turnId,expectedTurn=s.combat.turn})
end
task.spawn(function()
	local ok,err=pcall(function()
		send("requestSnapshot"); send("combatEnd"); send("tableClear")
		send("escolherPersonagem",{id="teorico"}); send("iniciarTreino",{},1.8); send("combatEnd")
		local a
		for _,t in State.snapshot().tokens do if t.ownerUserId==player.UserId and t.kind=="jogador" then a=t end end
		assert(a,"teórico não criado")
		R.tokenId=a.id
		local cells={}; for x=3,12 do for z=3,10 do table.insert(cells,{x=x,z=z}) end end
		send("paintCells",{brush="limpar",cells=cells}); send("paintCells",{brush="revelar",cells=cells})
		send("move",{id=a.id,x=5,z=5})
		send("criarPremontado",{id="espadachim",ownerUserId=0,x=8,z=5},2)
		local b; for _,t in State.snapshot().tokens do if t.name:find("Kaito",1,true) then b=t end end
		assert(b,"alvo não criado"); R.alvoId=b.id
		send("combatStart",{entries={{id=a.id,initiative=20},{id=b.id,initiative=10}}})
		State.setTableView(true)
		check("carta Desenhar fórmula",player.PlayerGui.AcoesDoTurno:FindFirstChild("Carta_mesa/desenhar-formula",true)~=nil)
		local mana=State.findToken(a.id).mana
		send("desenharFormula",{tokenId=a.id,essencia="mana",verbo="lancar",forma="triangulo",potencia="Principiante",alvoId=b.id})
		check("forma fora do escopo recusada sem PM",State.findToken(a.id).mana==mana)
		send("desenharFormula",{tokenId=a.id,essencia="mana",verbo="sinalizar",forma="circulo",potencia="Principiante",x=5,z=6})
		check("sinal sem condição",#(State.findToken(b.id).conditions or {})==0)
		check("sinal cobra PM e 2 Ações",State.findToken(a.id).mana==mana-1 and State.snapshot().jogo.acoes.usadas==2)
		check("sinal projetado como marca",#State.snapshot().jogo.muros>0 and State.snapshot().jogo.muros[1].estilo=="teorica")
		proxima(); proxima()
		send("desenharFormula",{tokenId=a.id,essencia="mana",verbo="erguer",forma="quadrado",potencia="Principiante",x=5,z=6})
		local muro=State.snapshot().jogo.muros[1]
		check("parede desenhada tem 30 PV",muro and muro.pv==30)
		check("parede no render",muro and workspace.MurosDeFogo:FindFirstChild(muro.id)~=nil)
		proxima(); proxima()
		send("desenharFormula",{tokenId=a.id,essencia="mana",verbo="selar",forma="linha",potencia="Principiante",x=6,z=5})
		muro=State.snapshot().jogo.muros[1]
		check("novo selo substitui sustentação",#State.snapshot().jogo.muros==1 and muro.pv==nil)
		proxima(); proxima()
		R.uiPronta=true
	end)
	if not ok then check(tostring(err),false) end
	R.pronto=true
end)
return "A19 cliente em execução; consultar shared.A19 antes de clicar."
