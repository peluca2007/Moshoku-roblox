-- Geometria física da grade de encontro: miniaturas e avatares compartilham o mesmo centro e escala.
local EncontroAutonomoGeometria = {}

local PASSO_CASA = 1.8
local OFFSET_CENTRO = Vector3.new(0, 0, 8)

function EncontroAutonomoGeometria.centro(marco)
	if not marco or not marco:IsA("BasePart") then return nil end
	return marco.Position + OFFSET_CENTRO
end

function EncontroAutonomoGeometria.posicao(centro, x, z)
	if typeof(centro) ~= "Vector3"
		or type(x) ~= "number" or x % 1 ~= 0 or x < 1 or x > 20
		or type(z) ~= "number" or z % 1 ~= 0 or z < 1 or z > 20
	then return nil end
	return Vector3.new(centro.X + (x - 10.5) * PASSO_CASA, centro.Y, centro.Z + (z - 10.5) * PASSO_CASA)
end

-- Retorna o centro de uma linha de grade, contando os limites como 0 e 20.
function EncontroAutonomoGeometria.posicaoLinha(centro, eixo, indice)
	if typeof(centro) ~= "Vector3"
		or (eixo ~= "x" and eixo ~= "z")
		or type(indice) ~= "number" or indice % 1 ~= 0 or indice < 0 or indice > 20
	then return nil end
	local deslocamento = (indice - 10) * PASSO_CASA
	if eixo == "x" then
		return Vector3.new(centro.X + deslocamento, centro.Y, centro.Z)
	end
	return Vector3.new(centro.X, centro.Y, centro.Z + deslocamento)
end

return EncontroAutonomoGeometria
