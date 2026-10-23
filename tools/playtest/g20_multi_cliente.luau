local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local remote=RS:WaitForChild("G20Teste",90);if not remote then return end
local mesa=RS:WaitForChild("Mesa",30);local snap=nil;local erro=nil
mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then snap=d elseif k=="log" and d.tone=="erro" then erro=d.text end end)
remote.OnClientEvent:Connect(function(d)
	local ok,valor=xpcall(function()
		if d.acao=="enviar" then
			erro=nil;mesa:FireServer(d.comando,d.dados);task.wait(.7)
			if d.erro then assert(erro and erro:find(d.erro,1,true),tostring(erro));return erro end
			assert(not erro,tostring(erro));return "aceito"
		elseif d.caso=="pilha" then
			local folha=workspace.SalaObjetosLocais:FindFirstChild("Ficha_"..d.id)
			assert(folha and folha.CanQuery==d.visivel);assert(folha.Transparency==(if d.visivel then 0 else 1));return "pilha confirmada"
		elseif d.caso=="partida" then
			assert(snap and snap.combat.active,"combate não chegou")
			local UIS=game:GetService("UserInputService")
			assert(UIS.MouseIconEnabled,"cursor oculto");assert(UIS.MouseBehavior==Enum.MouseBehavior.Default,"cursor preso")
			local donos={};for _,t in snap.tokens do if t.kind=="jogador" and not t.ia then donos[t.ownerUserId]=true end end
			assert(donos[player.UserId] and donos[d.outro],"snapshot não contém ambos os personagens")
			assert(not player.PlayerGui.SalaConceitual.Enabled,"lobby ainda aberto")
			return "dois personagens, cursor visível e livre"
		end
	end,debug.traceback)
	remote:FireServer({label=d.label,ok=ok,valor=tostring(valor)})
end)
task.spawn(function()
	local fim=os.clock()+45
	repeat mesa:FireServer("requestSnapshot",{});task.wait(.5) until (snap and player.PlayerGui:FindFirstChild("SalaConceitual")) or os.clock()>fim
	remote:FireServer({label="pronto",ok=snap~=nil,mestre=snap and snap.salaConceitual.mestre})
end)
