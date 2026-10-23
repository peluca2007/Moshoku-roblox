-- A17/A18 cliente real: área congelada evita dano; exposição usa golpe comum.
local player=game.Players.LocalPlayer
local remote=game.ReplicatedStorage.Mesa
local R={pronto=false,falhas=0,linhas={}};shared.A17Chefe=R
local s,efeito,recibo
local conn=remote.OnClientEvent:Connect(function(k,d)
	if k=="snapshot" then s=d elseif k=="chefeEfeito" then efeito=d elseif k=="efeito" and d.habilidadeId=="criatura/ataque" then recibo=d
	elseif k=="reacao" and not d.fechar then remote:FireServer("reagir",{id=d.id}) end
end)
local function check(n,ok) table.insert(R.linhas,(if ok then "OK " else "FALHA ")..n);if not ok then R.falhas+=1 end end
local function send(k,p,w) remote:FireServer(k,p or {});task.wait(w or 0.35) end
local function heroi() for _,t in s.tokens do if t.kind=="jogador" and t.ownerUserId==player.UserId then return t end end end
local function esperar(f)
	local inicio=os.clock();while not f() and os.clock()-inicio<15 do task.wait(.2) end;assert(f(),"tempo esgotado")
end
local function passa() send("nextTurn",{expectedId=s.combat.turnId,expectedTurn=s.combat.turn}) end
task.spawn(function()
	local ok,erro=pcall(function()
		send("requestSnapshot");send("combatEnd");send("tableClear");send("escolherPersonagem",{id="espadachim"});send("iniciarLuta",{nivel=3},2)
		assert(s and heroi() and s.encontro and s.encontro.chefe,"desafio 3 não iniciou")
		local h=heroi();local boss=s.encontro.chefe.id
		-- PV altos só na mesa descartável: dados/dano/CA do livro permanecem.
		send("updateToken",{id=h.id,pvMax=1000,pv=1000})
		check("gancho especial está ativo no snapshot",s.encontro.chefe.areaAtiva==true)
		if not s.encontro.chefe.aviso then esperar(function() return s.combat.turnId==h.id end);passa() end
		esperar(function() return s.encontro.chefe.aviso~=nil and s.combat.turnId==h.id end)
		local aviso=s.encontro.chefe.aviso;local antes=heroi().pv
		check("fase um anuncia nove casas",#aviso.casas==9)
		check("preparar não aplica dano",antes==1000)
		check("arena renderiza a marca",workspace:FindFirstChild("ArenaTreant") and workspace.ArenaTreant:FindFirstChild("AreaChefe"))
		local fora
		for dx=-5,5 do for dz=-5,5 do
			local x,z=h.x+dx,h.z+dz;local dentro=false
			for _,c in aviso.casas do if c[1]==x and c[2]==z then dentro=true end end
			if not dentro and math.max(math.abs(dx),math.abs(dz))<=6 and x>=1 and x<=20 and z>=1 and z<=20 then fora={x,z};break end
		end;if fora then break end end
		assert(fora,"sem destino fora da marca")
		send("move",{id=h.id,x=fora[1],z=fora[2],andar=true})
		check("Andar sai da área e cobra uma Ação",heroi().x==fora[1] and heroi().z==fora[2] and s.jogo.acoes.usadas==1)
		passa();esperar(function() return efeito~=nil end)
		check("área vazia executa sem perseguir",efeito.integrado==true and efeito.agiu==true)
		check("sair da marca evita dano",heroi().pv==antes)
		check("área vazia não inventa golpe corpo a corpo",recibo==nil)
		-- Novo preparo mira a casa atual. Permanece dentro para conferir recibo/dano.
		esperar(function() return s.combat.turnId==h.id end);efeito=nil;passa()
		esperar(function() return s.encontro.chefe.aviso~=nil and s.combat.turnId==h.id end)
		local pv=heroi().pv;passa();esperar(function() return efeito~=nil end)
		check("golpe na área usa recibo do motor",recibo and recibo.casterId==boss and recibo.estilo=="raizes")
		local acerto=recibo and recibo.alvos[1]
		check("PV condiz com o recibo inclusive erro",acerto and heroi().pv==pv-(acerto.dano or 0))
		check("execução informa integração real",efeito.integrado==true)
	end)
	if not ok then check("execução: "..tostring(erro),false) end
	send("combatEnd");send("tableClear");check("fim limpa arena",workspace:FindFirstChild("ArenaTreant")==nil)
	conn:Disconnect();R.pronto=true
end)
return "A17 chefe iniciado"
