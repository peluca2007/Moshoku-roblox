-- Limita a caixa projetada do trio, incluindo profundidade dos vértices.
-- Raio .42 cobre qualquer rotação de um cubo de lado .48; distância 1.6.
local M={}
function M.x(i) return .5+(i-2)*.64 end
M.y=-.55
function M.escala(aspecto,fov)
	local vertical=math.tan(math.rad(fov/2))*.9;local horizontal=vertical*aspecto
	-- Centro extremo + raio de vértice; há espaço entre os três cubos.
	return math.min(1,horizontal*1.6/(M.x(3)+.42+horizontal*.42),vertical*1.6/(-M.y+.42+vertical*.42))
end
return M
