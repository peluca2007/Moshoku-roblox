local P=require(game.ReplicatedStorage.Shared.PapelSolto)
local S={}
function S.new(deps)
	local objetos,ultimo,serial={},{},0
	local api={}
	function api.arremessar(p,d)
		local erro=deps.permitido(p);if erro then return erro end
		if type(d.id)~="string" or deps.maos[p.UserId]~=d.id then return "Pegue essa ficha antes de arremessar." end
		local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not root or math.abs(root.Position.X-250)>20 or math.abs(root.Position.Z)>20 then return "Volte à sala para soltar o papel." end
		local agora=deps.agora()
		-- A largada não prende nova pegada no intervalo de um arremesso.
		-- Frequência remota e limite global de objetos continuam no roteador.
		if not d.soltar and ultimo[p.UserId] and agora-ultimo[p.UserId]<.65 then return "Espere o papel sair da sua mão." end
		local mao=root.CFrame:PointToWorldSpace(Vector3.new(.65,.7,-2.1))
		local o={x=mao.X,y=math.clamp(mao.Y,4,10),z=mao.Z}
		local desc=P.criar(o,d.direcao,d.forca,agora,d.soltar)
		if not desc then return "Arremesso inválido." end
		if not d.soltar then ultimo[p.UserId]=agora end;serial+=1;desc.objeto=serial;desc.id=d.id;desc.autor=p.UserId
		if #objetos>=18 then table.remove(objetos,1) end
		table.insert(objetos,desc);deps.maos[p.UserId]=nil
		return nil
	end
	function api.recolher(p,id,objeto)
		for i,d in objetos do if d.objeto==objeto and d.id==id then
			local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local pos=P.posicao(d,deps.agora())
			if not root or (root.Position-Vector3.new(pos.x,pos.y,pos.z)).Magnitude>22 then return "Aproxime-se do papel." end
			table.remove(objetos,i);return nil
		end end
		return "Esse papel já foi recolhido."
	end
	function api.arrumar() table.clear(objetos) end
	function api.publico()
		for i=#objetos,1,-1 do if deps.agora()-objetos[i].inicio>45 then table.remove(objetos,i) end end
		return table.clone(objetos)
	end
	function api.sair(id) ultimo[id]=nil end
	return api
end
return S
