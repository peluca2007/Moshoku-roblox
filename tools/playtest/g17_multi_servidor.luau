-- Só executa na rodada oficial G17, com dois clientes reais do Studio.
local teste=game:GetService("StudioTestService")
local args=teste:GetTestArgs();if args~="MoshokuG17" then return end
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local remote=Instance.new("RemoteEvent");remote.Name="G17Teste";remote.Parent=RS
local reports={};local linhas={};local fim=false;local seq=0
remote.OnServerEvent:Connect(function(p,d) if type(d)=="table" then reports[p.UserId..":"..tostring(d.label)]=d end end)
local function terminar(ok,err)
	if fim then return end;fim=true
	teste:EndTest({ok=ok,erro=tostring(err),linhas=linhas,jogadores=#Players:GetPlayers()})
end
task.delay(150,function() terminar(false,"timeout global") end)
local function esperar(fn,motivo,segundos)
	local limite=os.clock()+(segundos or 8)
	repeat if fn() then return end;task.wait(.1) until os.clock()>limite
	error(motivo)
end
local function passo(p,d)
	seq+=1;d.label=tostring(seq);local key=p.UserId..":"..d.label
	remote:FireClient(p,d);esperar(function() return reports[key]~=nil end,"sem resposta "..key)
	local r=reports[key];assert(r.ok,r.valor);table.insert(linhas,p.Name.." "..(d.caso or d.comando).." "..r.valor)
end
local function enviar(p,comando,dados,erro) passo(p,{acao="enviar",comando=comando,dados=dados or {},erro=erro}) end
local function ver(p,caso,outro,id,mestre) passo(p,{acao="ver",caso=caso,outro=outro,id=id,mestre=mestre}) end
local function posicionar(p,z)
	local h=p.Character.Humanoid;local seat=h.SeatPart
	if seat then local weld=seat:FindFirstChild("SeatWeld");if weld then weld:Destroy() end end
		h.Sit=false;h.Jump=true;p.Character.HumanoidRootPart:SetNetworkOwner(nil);p.Character:PivotTo(CFrame.new(262,4,z)*CFrame.Angles(0,math.pi,0));p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
end
task.spawn(function()
	local ok,err=xpcall(function()
		esperar(function() return #Players:GetPlayers()==2 end,"dois clientes não conectaram",60)
		for _,p in Players:GetPlayers() do esperar(function() return reports[p.UserId..":pronto"] and reports[p.UserId..":pronto"].ok and p.Character end,"cliente não pronto",45) end
		local lista=Players:GetPlayers();local mestre=Players:GetPlayerByUserId(reports[lista[1].UserId..":pronto"].mestre);assert(mestre,"sem mestre confirmado")
		local a=mestre;local b=if lista[1]==a then lista[2] else lista[1]
		-- A suíte completa roda no Play conectado da conta (g17_ui.py).
		-- Reexecutar G8Admin após vincular sala conflita com o papel legado da
		-- identidade ADM fixa quando o mestre conectado é o convidado -1/-2.
		-- Esta rodada mede os remotos/replicação reais sem trocar permissões ADM.
		task.wait(3);posicionar(a,-3);posicionar(b,-6);task.wait(1)
		for _,p in {a,b} do local root=p.Character.HumanoidRootPart;table.insert(linhas,p.Name.." antes: "..tostring(root.Position).." anchored="..tostring(root.Anchored).." health="..p.Character.Humanoid.Health) end
		enviar(a,"salaCarregar",{userId=b.UserId});assert(b.Character.HumanoidRootPart:GetAttribute("CarregadoPor")==a.UserId)
		ver(a,"carregador",b.UserId);ver(b,"observador",a.UserId);ver(b,"carregado",a.UserId)
		enviar(b,"salaCarregar",{soltar=true});assert(not b.Character.HumanoidRootPart.Anchored and not b.Character.Humanoid.PlatformStand);table.insert(linhas,"restauração alvo real ok")
		posicionar(b,-6);task.wait(.4)
		enviar(a,"salaPapel",{id="mago-de-fogo"});enviar(b,"salaDadosPegar")
		enviar(a,"salaPapel",{id="mago-de-fogo",para=b.UserId},"mãos ocupadas");ver(a,"manteve",nil,"mago-de-fogo")
		enviar(b,"salaDadosLancar",{direcao={x=-1,y=.2,z=0},forca=.3});task.wait(3)
		posicionar(b,8);enviar(a,"salaPapel",{id="mago-de-fogo",para=b.UserId},"Aproxime-se");ver(a,"manteve",nil,"mago-de-fogo")
		posicionar(b,-6);task.wait(.4)
		local pedidos=0;local con=RS.Mesa.OnServerEvent:Connect(function(p,cmd) if p==b and cmd=="salaPapel" then pedidos+=1 end end)
		enviar(a,"salaPapel",{id="mago-de-fogo",para=b.UserId});ver(a,"semMao");ver(b,"ficha",nil,"mago-de-fogo");assert(pedidos==0,"receber fez segundo pedido de posse");con:Disconnect()
		enviar(b,"salaPapel",{id=false});ver(b,"semMao")
		-- Primeiro conectado mestra; ele abre Brotos para ambos, sem transferência.
		enviar(mestre,"salaBrotosAbrir")
		for _,p in lista do enviar(p,"salaDadosPegar");enviar(p,"salaDadosLancar",{direcao={x=-1,y=.2,z=0},forca=.4}) end
		task.wait(3)
		for _,p in lista do ver(p,"brotos",nil,nil,mestre.UserId) end
	end,debug.traceback)
	terminar(ok,err)
end)
