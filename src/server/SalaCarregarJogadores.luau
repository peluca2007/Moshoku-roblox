-- Brincadeira de lobby. Nunca usa o agarrão/recurso/dano do combate.
local C={}
function C.new(deps)
	local ativos,alvos,ultimo={},{},{};local api={}
	local function soltar(id)
		local r=ativos[id];if not r then return end
		ativos[id]=nil;alvos[r.alvo.UserId]=nil
		ultimo[r.alvo.UserId]=deps.agora()
		if r.con then r.con:Disconnect() end
		for part,valor in r.colisoes do if part.Parent then part.CanCollide=valor end end
		if r.root.Parent then r.root.Anchored=r.ancorado;r.root.AssemblyLinearVelocity=Vector3.zero;r.root.AssemblyAngularVelocity=Vector3.zero;r.root:SetAttribute("CarregadoPor",nil) end
		if r.h.Parent then r.h.PlatformStand=r.plataforma;r.h.AutoRotate=r.girar end
		if deps.maos[id]=="jogador:"..r.alvo.UserId then deps.maos[id]=nil end
	end
	function api.aplicar(p,d)
		if type(d)~="table" then return "Pedido inválido." end
		if d.soltar==true then soltar(alvos[p.UserId] or p.UserId);return nil end
		local e=deps.permitido(p);if e then return e end
		if type(d.userId)~="number" or d.userId%1~=0 or d.userId==p.UserId then return "Escolha outro jogador próximo." end
		local alvo=deps.jogador(d.userId)
		if not alvo or deps.permitido(alvo) or deps.maos[p.UserId] or deps.maos[alvo.UserId] or ativos[p.UserId] or alvos[p.UserId] or ativos[alvo.UserId] or alvos[alvo.UserId] then return "Esse jogador está ocupado." end
		if ultimo[alvo.UserId] and deps.agora()-ultimo[alvo.UserId]<3 then return "Dê um instante para esse jogador." end
		local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local ar=alvo.Character and alvo.Character:FindFirstChild("HumanoidRootPart");local h=alvo.Character and alvo.Character:FindFirstChildOfClass("Humanoid")
		local ph=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not root or not ar or not h or not ph or ph.Health<=0 or h.Health<=0 or root.Anchored or ar.Anchored or (root.Position-ar.Position).Magnitude>6 or (root.Position-Vector3.new(250,3,0)).Magnitude>24 then return "Aproxime-se do jogador no lobby." end
		local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={p.Character,alvo.Character}
		if workspace:Raycast(root.Position,ar.Position-root.Position,params) then return "Há um obstáculo entre vocês." end
		local r={alvo=alvo,jogador=p,root=ar,h=h,ancorado=ar.Anchored,plataforma=h.PlatformStand,girar=h.AutoRotate,inicio=deps.agora(),char=p.Character,colisoes={}}
		local function colisao(part) if part:IsA("BasePart") then r.colisoes[part]=part.CanCollide;part.CanCollide=false end end
		for _,part in alvo.Character:GetDescendants() do colisao(part) end;r.con=alvo.Character.DescendantAdded:Connect(colisao)
		if h.SeatPart then local weld=h.SeatPart:FindFirstChild("SeatWeld");if weld and weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(alvo.Character) then weld:Destroy() end;h.Sit=false end
		ativos[p.UserId]=r;alvos[alvo.UserId]=p.UserId;deps.maos[p.UserId]="jogador:"..alvo.UserId
		ar.Anchored=true;h.PlatformStand=true;h.AutoRotate=false;ar:SetAttribute("CarregadoPor",p.UserId);return nil
	end
	function api.atualizar()
		for id,r in ativos do
			local root=r.jogador.Character and r.jogador.Character:FindFirstChild("HumanoidRootPart")
			local ph=r.jogador.Character and r.jogador.Character:FindFirstChildOfClass("Humanoid")
			if not root or not ph or ph.Health<=0 or r.char~=r.jogador.Character or r.alvo.Character~=r.root.Parent or r.h.Health<=0 or deps.permitido(r.jogador) or deps.permitido(r.alvo) or deps.maos[id]~="jogador:"..r.alvo.UserId or deps.agora()-r.inicio>4 then soltar(id);deps.mudou();continue end
			local cf=root.CFrame*CFrame.new(0,1,-3)
			local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={r.jogador.Character,r.alvo.Character}
			if (root.Position-Vector3.new(250,3,0)).Magnitude>24 or workspace:Raycast(root.Position,cf.Position-root.Position,params) then soltar(id);deps.mudou();continue end
			r.root.CFrame=cf*CFrame.Angles(0,math.pi,0)
		end
	end
	function api.sair(id) soltar(alvos[id] or id);ultimo[id]=nil end
	function api.arrumar() for id in ativos do soltar(id) end end
	return api
end
return C
