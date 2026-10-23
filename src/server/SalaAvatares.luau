-- Posiciona cada pessoa uma vez por entrada/papel/retorno; permite levantar.
local Players=game:GetService("Players")
local E=require(game.ReplicatedStorage.Shared.SalaEspaco)
local A={}
function A.start(deps)
	local aplicados={};local anterior=false
	local function dentroDaSala(root)
		local sala=workspace:FindFirstChild("SalaRPG")
		local piso=sala and sala:FindFirstChild("Piso")
		if not piso then return false end
		return math.abs(root.Position.X-piso.Position.X)<=piso.Size.X/2+5
			and math.abs(root.Position.Z-piso.Position.Z)<=piso.Size.Z/2+5
	end
	task.spawn(function()
		while true do
			task.wait(.5)
			if deps.combat.active then anterior=true;continue end
			if anterior then table.clear(aplicados);anterior=false end
			local sala=deps.sala();if not sala then continue end
			for _,p in sala.pessoas do
				local player=Players:GetPlayerByUserId(p.id);local char=player and player.Character
				local root=char and char:FindFirstChild("HumanoidRootPart");local hum=char and char:FindFirstChildOfClass("Humanoid")
				local marca=aplicados[p.id]
				-- Mestre atribuído sozinho é o lobby padrão, não uma sessão que force
				-- quem acabou de entrar no mundo de volta à sala. Eleição/transição ou
				-- prontidão confirmada indicam preparação que ainda exige a sala.
				local sessaoExigeSala=sala.eleicao~=nil or sala.transicao~=nil or p.pronto==true
				if root and hum and (dentroDaSala(root) or sessaoExigeSala)
					and (not marca or marca.char~=char or marca.lugar~=p.lugar) then
					root.Anchored=false;hum.Sit=false
					char:PivotTo(if p.lugar then E.lugar(p.lugar)*CFrame.new(0,2,0) else CFrame.new(267,3,14))
					aplicados[p.id]={char=char,lugar=p.lugar}
					if p.lugar then
						local seat=workspace.SalaRPG:FindFirstChild("Lugar"..p.lugar)
						if seat and not seat.Occupant then seat:Sit(hum) end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p) aplicados[p.UserId]=nil end)
end
return A
