-- Entrega de fichas confirmada numa única operação, sem yield entre validação e posse.
local E={}
function E.new(deps)
	local ultimo={};local serial=0;local api={}
	local function corpo(p)
		local char=p and p.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
		local h=char and char:FindFirstChildOfClass("Humanoid")
		if root and h and h.Health>0 and not root:GetAttribute("CarregadoPor") then return root end
		return nil
	end
	function api.entregar(p,id,para)
		if type(para)~="number" or para~=para or math.abs(para)>2^53 or para%1~=0 or para==p.UserId then return "Escolha outro jogador próximo." end
		if type(id)~="string" or not deps.fichas[id] or deps.maos[p.UserId]~=id then return "Pegue a ficha antes de entregar." end
		local alvo=deps.jogador(para)
		if not alvo or deps.permitido(p) or deps.permitido(alvo) then return "Esse jogador não está disponível na sala." end
		if deps.maos[para] then return "Esse jogador está com as mãos ocupadas." end
		local root,ar=corpo(p),corpo(alvo)
		if not root or not ar or (root.Position-ar.Position).Magnitude>8 then return "Aproxime-se do jogador para entregar a ficha." end
		local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={p.Character,alvo.Character}
		local origem=root.Position+Vector3.new(0,1.4,0);local destino=ar.Position+Vector3.new(0,1.4,0)
		if workspace:Raycast(origem,destino-origem,params) then return "Há um obstáculo entre vocês." end
		local agora=deps.agora()
		if ultimo[p.UserId] and agora-ultimo[p.UserId]<.6 then return "Espere um instante antes de entregar outra ficha." end
		ultimo[p.UserId]=agora;serial+=1
		deps.maos[p.UserId]=nil;deps.ofertas[p.UserId]=nil;deps.maos[para]=id
		deps.ofertas[para]={id=id,de=p.UserId,serial=serial}
		return nil
	end
	function api.sair(id) ultimo[id]=nil end
	return api
end
return E
