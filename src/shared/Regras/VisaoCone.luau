-- Teste puro de visao horizontal em XZ; origem, frente e alvo sao {x,z}.
local VisaoCone = {}

function VisaoCone.dentro(origem, frente, alvo, alcance, anguloGraus)
	if type(origem) ~= "table" or type(frente) ~= "table" or type(alvo) ~= "table"
		or type(origem.x) ~= "number" or type(origem.z) ~= "number"
		or type(frente.x) ~= "number" or type(frente.z) ~= "number"
		or type(alvo.x) ~= "number" or type(alvo.z) ~= "number"
		or type(alcance) ~= "number" or alcance < 0
		or type(anguloGraus) ~= "number" or anguloGraus < 0 or anguloGraus > 360 then return false end
	local dx, dz = alvo.x - origem.x, alvo.z - origem.z
	local distancia2 = dx * dx + dz * dz
	if distancia2 > alcance * alcance then return false end
	if distancia2 == 0 then return true end
	local f2 = frente.x * frente.x + frente.z * frente.z
	if f2 == 0 then return false end
	local produto = (frente.x * dx + frente.z * dz) / math.sqrt(f2 * distancia2)
	return produto >= math.cos(math.rad(anguloGraus / 2))
end

-- Acrescenta o teste de oclusao fornecido pelo chamador; o modulo nao depende
-- de raycast/Instances e nao presume como o mundo representa obstaculos.
function VisaoCone.detecta(origem, frente, alvo, alcance, anguloGraus, oclusao)
	if not VisaoCone.dentro(origem, frente, alvo, alcance, anguloGraus) then return false end
	return oclusao == nil or (type(oclusao) == "function" and oclusao() == true)
end

return VisaoCone
