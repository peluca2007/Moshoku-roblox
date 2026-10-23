-- Geometria compartilhada: servidor valida; cliente projeta intenção.
local Shared = game:GetService("ReplicatedStorage").Shared
local Protocol = require(Shared.MesaProtocol)
local Combate = require(Shared.Regras.Combate)
local A = {}
function A.eArea(mec)
	return mec and (mec.tipo == "zona" or table.find({"esferaNoConjurador","esferaNaCasa","cone","adjacentes"},mec.alvo or "") ~= nil)
end
function A.finalDaLinha(inicio,x,z,limite)
	local dx,dz=Combate.direcao8(x-inicio[1],z-inicio[2])
	local n=math.clamp(Protocol.distance(inicio[1],inicio[2],x,z)+1,1,limite)
	return inicio[1]+dx*(n-1),inicio[2]+dz*(n-1)
end
-- Casas de uma zona, pela forma.
function A.zona(token, mec, payload, bloqueada, bloqueiaVisao)
	if payload.inicioX ~= nil or payload.inicioZ ~= nil then
		if not mec.moldavel or not Protocol.isCell(payload.inicioX,payload.inicioZ) or not Protocol.isCell(payload.x,payload.z) then return nil,"Desenho de área inválido." end
		local ax,az,x,z=payload.inicioX,payload.inicioZ,payload.x,payload.z
		if Protocol.distance(token.x,token.z,ax,az) ~= 1 then return nil,"A muralha precisa começar numa casa vizinha." end
		local dx,dz=x-ax,z-az
		if dx~=0 and dz~=0 and math.abs(dx)~=math.abs(dz) then return nil,"A muralha precisa ser uma linha reta." end
		if math.max(math.abs(dx),math.abs(dz))+1 > mec.comprimentoCasas then return nil,"A muralha excede o comprimento máximo." end
		local casas={{ax,az}}
		for _,c in Combate.linha(ax,az,x,z) do table.insert(casas,c) end
		for _,c in casas do if bloqueada(c[1],c[2]) then return nil,"A muralha não pode atravessar parede." end end
		if not Combate.temVisao(ax,az,x,z,bloqueada) then return nil,"A muralha não pode atravessar a quina da parede." end
		if not Combate.temVisao(token.x,token.z,ax,az,bloqueiaVisao) then return nil,"Início fora da linha de visão." end
		return casas,nil
	end
	local forma = mec.forma or "linhaDoConjurador"
	local casas = {}
	local function pode(x, z)
		return Protocol.isCell(x, z) and not bloqueada(x, z)
	end
	if forma == "esferaNoConjurador" then
		for x = token.x - mec.raioCasas, token.x + mec.raioCasas do
			for z = token.z - mec.raioCasas, token.z + mec.raioCasas do
				if pode(x, z) and Combate.distanciaEuclidiana(token.x, token.z, x, z) <= mec.raioCasas then
					table.insert(casas, { x, z })
				end
			end
		end
		return casas, nil
	end
	local x, z = payload.x, payload.z
	if forma == "casa" then
		if not Protocol.isCell(x, z) or not pode(x, z) then return nil, "Escolha uma casa livre de parede." end
		if Combate.distancia(token.x, token.z, x, z) > (mec.alcanceCasas or 1) then return nil, "Casa fora de alcance." end
		if not Combate.temVisao(token.x, token.z, x, z, bloqueiaVisao) then return nil, "Casa fora da linha de visão." end
		return { { x, z } }, nil
	end
	if not Protocol.isCell(x, z) or (x == token.x and z == token.z) then
		return nil, "Escolha uma casa no tabuleiro."
	end
	if forma == "linhaDoConjurador" then
		local dx, dz = Combate.direcao8(x - token.x, z - token.z)
		local anteriorX,anteriorZ=token.x,token.z
		for _, casa in Combate.linha(token.x, token.z, token.x + dx * mec.comprimentoCasas, token.z + dz * mec.comprimentoCasas) do
			if #casas >= mec.comprimentoCasas or not pode(casa[1], casa[2]) or not Combate.temVisao(anteriorX,anteriorZ,casa[1],casa[2],bloqueada) then
				break
			end
			table.insert(casas, casa)
			anteriorX,anteriorZ=casa[1],casa[2]
		end
	elseif forma == "linhaTransversal" then
		-- Centro na casa escolhida, perpendicular à direção conjurador → casa.
		if Combate.distancia(token.x, token.z, x, z) > (mec.alcanceCasas or 1) then
			return nil, "Casa fora de alcance."
		end
		local dx, dz = Combate.direcao8(x - token.x, z - token.z)
		local px, pz = -dz, dx
		local metade = (mec.comprimentoCasas - 1) / 2
		for i = -math.floor(metade), math.ceil(metade) do
			local cx, cz = x + px * i, z + pz * i
			if pode(cx, cz) then
				table.insert(casas, { cx, cz })
			end
		end
	end
	if #casas == 0 then
		return nil, "Não há espaço para isso nessa direção."
	end
	return casas, nil
end
function A.previa(token,mec,payload,bloqueada,bloqueiaVisao)
	if mec.tipo=="zona" then return A.zona(token,mec,payload,bloqueada,bloqueiaVisao) end
	local forma=mec.alvo
	local cx,cz=token.x,token.z
	if forma=="esferaNaCasa" then
		cx,cz=payload.x,payload.z
		if not Protocol.isCell(cx,cz) then return {},"Escolha o centro da área." end
		if Protocol.distance(token.x,token.z,cx,cz)>(mec.alcanceCasas or 0) then return {},"Casa fora de alcance." end
		if not Combate.temVisao(token.x,token.z,cx,cz,bloqueiaVisao) then return {},"Visão bloqueada." end
	end
	local casas={}
	local raio=mec.raioCasas or mec.comprimentoCasas or 1
	local dx,dz=(payload.x or cx)-cx,(payload.z or cz)-cz
	if forma=="cone" and dx==0 and dz==0 then return {},"Escolha a direção do cone." end
	for x=math.max(1,cx-raio),math.min(Protocol.BOARD.width,cx+raio) do
		for z=math.max(1,cz-raio),math.min(Protocol.BOARD.height,cz+raio) do
			local vx,vz=x-cx,z-cz
			local dentro=if forma=="adjacentes" then Protocol.distance(cx,cz,x,z)==1 elseif forma=="cone" then Protocol.distance(cx,cz,x,z)<=raio and vx*vx+vz*vz>0 and (vx*dx+vz*dz)/math.sqrt((vx*vx+vz*vz)*(dx*dx+dz*dz))>=math.cos(math.rad(45))-1e-6 else vx*vx+vz*vz<=raio*raio
			if dentro and (forma=="adjacentes" or (not bloqueada(x,z) and Combate.temVisao(cx,cz,x,z,bloqueiaVisao))) then table.insert(casas,{x,z}) end
		end
	end
	return casas,nil
end
return A
