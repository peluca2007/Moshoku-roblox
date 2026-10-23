-- Fixture temporária: cliente conectado real. Não entra em src/place gerado.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local remote=RS:WaitForChild("G16Teste",90);if not remote then return end
local mesa=RS:WaitForChild("Mesa",30);local snap=nil;local erro=nil
mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then snap=d elseif k=="log" and d.tone=="erro" then erro=d.text end end)
local function mao(id) return snap and (snap.salaConceitual.maos[id] or snap.salaConceitual.maos[tostring(id)]) end
remote.OnClientEvent:Connect(function(d)
	local ok,valor=xpcall(function()
		if d.acao=="enviar" then
			erro=nil;mesa:FireServer(d.comando,d.dados);task.wait(.65)
			if d.erro then assert(erro and erro:find(d.erro,1,true),tostring(erro));return erro end
			assert(not erro,tostring(erro));return "aceito"
		elseif d.acao=="ver" then
			local root=player.Character.HumanoidRootPart;local pg=player.PlayerGui
			if d.caso=="carregado" then assert(root:GetAttribute("CarregadoPor")==d.outro);assert(pg.SalaSoltura.Enabled)
			elseif d.caso=="carregador" then
				assert(mao(player.UserId)=="jogador:"..d.outro);local br=workspace.SalaObjetosLocais:FindFirstChild("Bracos_"..player.Name);assert(br and br.RightHand.Transparency<.1)
			elseif d.caso=="observador" then
				local outro=Players:GetPlayerByUserId(d.outro);local br=workspace.SalaObjetosLocais:FindFirstChild("Bracos_"..outro.Name);assert(br and br.RightHand.Transparency<.1)
			elseif d.caso=="ficha" then assert(mao(player.UserId)==d.id);assert(pg.SalaPapelInterface.Enabled)
			elseif d.caso=="semMao" then assert(mao(player.UserId)==nil)
			elseif d.caso=="manteve" then assert(mao(player.UserId)==d.id)
			elseif d.caso=="brotos" then
				local br=snap.salaConceitual.brincadeiraBrotos;assert(br.fase=="resultado");assert(snap.salaConceitual.mestre==d.mestre)
				for _,p in Players:GetPlayers() do local v=br.dados[p.UserId] or br.dados[tostring(p.UserId)];local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..p.UserId);assert(v and m and m:GetAttribute("Pousou"));for i=1,3 do assert(m["Dado"..i]:GetAttribute("Valor")==v[i]) end end
			end
			return "ok"
		end
	end,debug.traceback)
	remote:FireServer({label=d.label,ok=ok,valor=tostring(valor)})
end)
task.spawn(function()
	local fim=os.clock()+45
	repeat mesa:FireServer("requestSnapshot",{});task.wait(.5) until (snap and player.PlayerGui:FindFirstChild("SalaConceitual")) or os.clock()>fim
	remote:FireServer({label="pronto",ok=snap~=nil,mestre=snap and snap.salaConceitual.mestre})
end)
