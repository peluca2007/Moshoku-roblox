-- Projeção local: cada jogador vê apenas a interação da sua tentativa confirmada.
local P={}
function P.habilitado(tipo,estado)
	local ativo=estado and estado.npcId=="vila-1" and estado.estado=="em-curso"
	if tipo=="falar" then return not ativo end
	if tipo=="sino" then return ativo==true and estado.sino~=true end
	if tipo=="portao" then return ativo==true end
	return nil
end
return P
