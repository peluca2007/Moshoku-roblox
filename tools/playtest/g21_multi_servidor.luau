local teste=game:GetService("StudioTestService")
if teste:GetTestArgs()~="MoshokuG21" then return end
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local remote=Instance.new("RemoteEvent");remote.Name="G21Teste";remote.Parent=RS
local reports,linhas={},{};local fim=false;local seq=0
remote.OnServerEvent:Connect(function(p,d) if type(d)=="table" then reports[p.UserId..":"..tostring(d.label)]=d end end)
local function terminar(ok,err)
	if fim then return end;fim=true;teste:EndTest({ok=ok,erro=tostring(err),linhas=linhas,jogadores=#Players:GetPlayers()})
end
task.delay(120,function() terminar(false,"timeout global") end)
local function esperar(fn,motivo,segundos)
	local limite=os.clock()+(segundos or 10)
	repeat if fn() then return end;task.wait(.1) until os.clock()>limite
	error(motivo)
end
local function passo(p,d)
	seq+=1;d.label=tostring(seq);local key=p.UserId..":"..d.label
	remote:FireClient(p,d);esperar(function() return reports[key]~=nil end,"sem resposta "..key)
	local r=reports[key];assert(r.ok,r.valor);table.insert(linhas,p.Name.." "..(d.caso or d.comando).." "..r.valor)
end
local function enviar(p,comando,dados,erro) passo(p,{acao="enviar",comando=comando,dados=dados or {},erro=erro}) end
local function pilha(p,visivel) passo(p,{caso="pilha",id="mago-de-fogo",visivel=visivel}) end
task.spawn(function()
	local ok,err=xpcall(function()
		esperar(function() return #Players:GetPlayers()==2 end,"faltou cliente",60)
		for _,p in Players:GetPlayers() do esperar(function() return reports[p.UserId..":pronto"] and reports[p.UserId..":pronto"].ok and p.Character end,"cliente não pronto",45) end
		local lista=Players:GetPlayers();local a=Players:GetPlayerByUserId(reports[lista[1].UserId..":pronto"].mestre);assert(a)
		local b=if lista[1]==a then lista[2] else lista[1]
		local personagens=require(RS.Shared.PersonagensProntos)
		for i,p in {a,b} do enviar(p,"escolherPersonagem",{id=personagens[i].id,arma=personagens[i].armas[1].id}) end
		local function sentar()
			local h=a.Character.Humanoid
			if h.SeatPart then return end
			for _,s in workspace.SalaRPG:GetDescendants() do if s:IsA("Seat") and s:GetAttribute("LugarSala") and not s.Occupant then a.Character:PivotTo(s.CFrame*CFrame.new(0,2,0));s:Sit(h);break end end
			esperar(function() return h.SeatPart~=nil end,"mestre não sentou")
		end
		for rodada=1,2 do
			sentar();enviar(a,"salaConfigurar",{modo="luta",nivel=1,monstros=false})
			enviar(b,"salaPronto",{ativo=true});enviar(a,"salaIniciar");task.wait(4)
			passo(a,{caso="partida",outro=b.UserId});passo(b,{caso="partida",outro=a.UserId})
			passo(a,{caso="finalizar",derrota=rodada==2});task.wait(4)
			for _,p in {a,b} do passo(p,{caso="fim",titulo=if rodada==1 then "VITÓRIA" else "DERROTA"}) end
			-- Ninguém fecha o resultado antes do mestre iniciar a segunda partida.
		end
	end,debug.traceback)
	terminar(ok,err)
end)
