-- OBSOLETO desde a integração A17 (golpeDeCriatura): duas checagens esperam o fallback antigo. Use a17_chefe.json.
local remote=game.ReplicatedStorage.Mesa
local R={pronto=false,falhas=0,linhas={}}
shared.A18Chefe=R
local efeito,recibo,snapshot
local conn=remote.OnClientEvent:Connect(function(k,d)
	if k=="snapshot" then snapshot=d elseif k=="chefeEfeito" then efeito=d elseif k=="efeito" and d.habilidadeId=="criatura/ataque" then recibo=d end
end)
local function check(nome,ok)
	table.insert(R.linhas,(if ok then "OK " else "FALHA ")..nome); if not ok then R.falhas+=1 end
end
task.spawn(function()
	local ok,e=pcall(function()
		remote:FireServer("requestSnapshot",{})
		for _=1,20 do if snapshot then break end; task.wait(.1) end
		local s=snapshot; assert(s and s.encontro and s.encontro.chefe,"Inicie nível 3 antes deste roteiro")
		local boss=s.encontro.chefe.id
		local viuAviso=false
		for _=1,60 do
			s=snapshot
			local b=s.encontro and s.encontro.chefe
			if b and b.aviso and not viuAviso then
				viuAviso=true
				local marks=workspace.ArenaTreant:FindFirstChild("AreaChefe")
				check("area marcada no chao um turno antes",marks and #marks:GetChildren()==#b.aviso.casas)
				check("fase 1 tem nove casas",#b.aviso.casas==9)
				check("HUD informa previa visual do fallback",string.find(game.Players.LocalPlayer.PlayerGui.HudJogo.Chefe.Aviso.Text,"Prévia visual",1,true)~=nil)
				check("preparacao nao emite golpe",recibo==nil and efeito==nil)
			end
			if efeito then break end
			if s.combat.active and s.combat.turnId~=boss then
				remote:FireServer("nextTurn",{expectedTurn=s.combat.turn,expectedId=s.combat.turnId})
			end
			task.wait(.25)
		end
		check("aviso foi observado",viuAviso)
		check("proxima vez dispara efeito por fallback",efeito and efeito.id==boss and efeito.integrado==false)
		local roots=0
		local arena=workspace:FindFirstChild("ArenaTreant")
		if arena then for _,p in arena:GetChildren() do if p.Name=="Raiz" then roots+=1 end end end
		check("raizes animadas existem no cliente",roots>0)
		-- Treant anda 6m por Andar: o primeiro fallback pode só aproximar-se.
		-- Aguarda um segundo ciclo para conferir o golpe, sem forçar alcance.
		for _=1,50 do
			if recibo then break end
			s=snapshot
			if s.combat.active and s.combat.turnId~=boss then remote:FireServer("nextTurn",{expectedTurn=s.combat.turn,expectedId=s.combat.turnId}) end
			task.wait(.25)
		end
		check("golpe simples usa recibo do motor ao alcancar",recibo and recibo.casterId==boss)
		remote:FireServer("combatEnd",{}); task.wait(1)
		check("fim destruiu marcas e arena",workspace:FindFirstChild("ArenaTreant")==nil)
	end)
	if not ok then check("execucao: "..tostring(e),false) end
	conn:Disconnect(); R.pronto=true
end)
return "Roteiro real de turno do chefe iniciado."
