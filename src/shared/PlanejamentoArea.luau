-- Intenção local; não gasta recursos nem concede validade ao desenho.
local Shared = game:GetService("ReplicatedStorage").Shared
local Area=require(Shared.AreaHabilidade)
local Protocol=require(Shared.MesaProtocol)
local P={}
function P.escolher(mira,mec,x,z)
	if not Protocol.isCell(x,z) then return mira end
	local nova=table.clone(mira)
	if mec.moldavel and not nova.inicio then
		nova.inicio={x,z};nova.ponto=nil
	else
		if mec.moldavel then x,z=Area.finalDaLinha(nova.inicio,x,z,mec.comprimentoCasas) end
		nova.ponto={x,z}
	end
	return nova
end
function P.pedido(mira)
	if not mira.ponto then return nil end
	return {x=mira.ponto[1],z=mira.ponto[2],inicioX=mira.inicio and mira.inicio[1],inicioZ=mira.inicio and mira.inicio[2]}
end
return P
