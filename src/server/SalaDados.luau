local Modelo=require(script.Parent.DadosModelo)
local L=require(game.ReplicatedStorage.Shared.SalaLancamento)
local Mao=require(game.ReplicatedStorage.Shared.SalaDadosMao)
local TweenService=game:GetService("TweenService")
local D={}
function D.new(deps)
	local pasta=Instance.new("Folder");pasta.Name="SalaDadosFisicos";pasta.Parent=deps.parent or workspace
	local grupos,ultimo={},{};local api={}
	local function proteger(g,char)
		if not char or g.chars[char] then return end
		local function parte(p)
			if p:IsA("BasePart") then for _,d in g.partes do local n=Instance.new("NoCollisionConstraint");n.Part0=d;n.Part1=p;n.Parent=g.modelo end end
		end
		for _,p in char:GetDescendants() do parte(p) end;g.chars[char]=char.DescendantAdded:Connect(parte)
	end
	local function limpar(id)
		local g=grupos[id];if g then for _,tw in g.tweens or {} do tw:Cancel() end;local confirmar=g.confirmar;g.confirmar=nil;if confirmar then confirmar() end;for _,con in g.chars do con:Disconnect() end;g.modelo:Destroy();grupos[id]=nil end
		if deps.maos[id]=="dados-brotos" then deps.maos[id]=nil end
	end
	function api.pegar(p)
		local e=deps.permitido(p);if e then return e end
		local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not root or not h or h.Health<=0 or (root.Position-Vector3.new(250.6,4,-5.9)).Magnitude>12 then return "Aproxime-se da bandeja para pegar os dados." end
		if deps.maos[p.UserId] then return "Solte o que está segurando antes de pegar os dados." end
		local anterior=grupos[p.UserId];if anterior and anterior.voo and not anterior.pousou then return "Espere os dados caírem." end
		if ultimo[p.UserId] and deps.agora()-ultimo[p.UserId]<1 then return "Espere os dados caírem." end
		limpar(p.UserId);local m=Instance.new("Model");m.Name="Dados_"..p.UserId;m:SetAttribute("Dono",p.UserId);m:SetAttribute("EmMaos",true)
		local partes={};for i=1,3 do partes[i]=Modelo.criar(m,i) end;m.Parent=pasta
		local g={modelo=m,partes=partes,jogador=p,char=p.Character,inicio=deps.agora(),chars={},tweens={},assentados={}};grupos[p.UserId]=g
		for _,other in deps.jogadores() do proteger(g,other.Character) end
		ultimo[p.UserId]=deps.agora();deps.maos[p.UserId]="dados-brotos";api.atualizar(0);return nil
	end
	function api.lancar(p,d)
		local e=deps.permitido(p);if e then return e end
		local g=grupos[p.UserId];local v=L.validar(d)
		if not g or g.voo or deps.maos[p.UserId]~="dados-brotos" or not v then return "Pegue os dados e escolha um lançamento válido." end
		local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not root or not h or h.Health<=0 or g.char~=p.Character or (root.Position-Vector3.new(250,3,0)).Magnitude>24 then return "Volte à mesa para lançar os dados." end
		local valores,erro,confirmar=deps.rolar(p);if not valores then return erro or "Não foi possível rolar agora." end
		g.valores=valores;g.confirmar=confirmar;g.voo=deps.agora();ultimo[p.UserId]=g.voo;deps.maos[p.UserId]=nil;g.modelo:SetAttribute("EmMaos",false)
		for i,part in g.partes do
			part.Anchored=false;part.CanCollide=true;part:SetNetworkOwner(nil)
			part:ApplyImpulse((Vector3.new(v.x,v.y,v.z)*v.velocidade+Vector3.new(0,v.subida,0))*part.AssemblyMass)
			if not d.soltar then part:ApplyAngularImpulse(Vector3.new(2+i,3-i,4)*part.AssemblyMass*.14) end
		end
		return nil
	end
	function api.atualizar(dt)
		for id,g in grupos do
			local root=g.jogador.Character and g.jogador.Character:FindFirstChild("HumanoidRootPart")
			local h=g.jogador.Character and g.jogador.Character:FindFirstChildOfClass("Humanoid")
			if not root or not h or h.Health<=0 or g.char~=g.jogador.Character or deps.permitido(g.jogador) or (not g.voo and deps.maos[id]~="dados-brotos") then limpar(id);deps.mudou();continue end
			if not g.voo then
				if deps.agora()-g.inicio>20 then limpar(id);deps.mudou();continue end
				local cf=root.CFrame*CFrame.new(0,1.5,0)*CFrame.Angles(g.char:GetAttribute("SalaOlharX") or 0,g.char:GetAttribute("SalaOlharY") or 0,0)
				for i,p in g.partes do p.CFrame=cf*CFrame.new(Mao.x(i),Mao.y,-2.25)*CFrame.Angles(.2*i,.1*i,.1*i) end
			else
				local t=deps.agora()-g.voo
				for i,p in g.partes do
					if not g.assentados[p] and (t>2.4 or p.Position.Y<.2 or math.abs(p.Position.X-250)>20 or math.abs(p.Position.Z)>19) then
						g.assentados[p]=true
						local pos=p.Position
						if math.abs(pos.X-250)>20 or math.abs(pos.Z)>19 or pos.Y<.2 then pos=Vector3.new(249.4+i*.65,4,-5.9) end
						local excluir={pasta};for _,other in deps.jogadores() do if other.Character then table.insert(excluir,other.Character) end end
						local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=excluir
						local chao=workspace:Raycast(pos+Vector3.new(0,1,0),Vector3.new(0,-10,0),params)
						if chao then pos=Vector3.new(pos.X,chao.Position.Y+.24,pos.Z) end
						p.Anchored=true;p.AssemblyLinearVelocity=Vector3.zero;p.AssemblyAngularVelocity=Vector3.zero
						local tw=TweenService:Create(p,TweenInfo.new(.22,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CFrame=CFrame.new(pos)*Modelo.rotacao(g.valores[i])});tw:Play();table.insert(g.tweens,tw)
					end
				end
				if t>2.4 and not g.alinhando then g.alinhando=deps.agora() end
				if g.alinhando and deps.agora()-g.alinhando>=.22 and not g.pousou then
					g.pousou=true;g.modelo:SetAttribute("Pousou",true);for i,p in g.partes do p:SetAttribute("Valor",g.valores[i]) end
					local confirmar=g.confirmar;g.confirmar=nil;if confirmar then confirmar();deps.mudou() end
				end
				if t>12 then limpar(id) end
			end
		end
	end
	function api.sair(id) limpar(id);ultimo[id]=nil end
	function api.personagem(char) for _,g in grupos do proteger(g,char) end end
	function api.pendente(id) local g=grupos[id];return g and g.confirmar~=nil or false end
	function api.pendentes() for _,g in grupos do if g.confirmar then return true end end;return false end
	function api.arrumar() for id in grupos do limpar(id) end end
	function api.destruir() api.arrumar();pasta:Destroy() end
	return api
end
return D
