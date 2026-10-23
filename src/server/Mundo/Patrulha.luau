-- Regras puras da percepção e navegação de patrulhas do mundo.
local Patrulha = {}
local VisaoCone = require(game:GetService("ReplicatedStorage").Shared.Regras.VisaoCone)

function Patrulha.dentroDoCone(origem, frente, alvo, alcance, anguloGraus)
	if typeof(origem) ~= "Vector3" or typeof(frente) ~= "Vector3" or typeof(alvo) ~= "Vector3" then return false end
	return VisaoCone.dentro(
		{ x = origem.X, z = origem.Z }, { x = frente.X, z = frente.Z },
		{ x = alvo.X, z = alvo.Z }, alcance, anguloGraus
	)
end

function Patrulha.deveDetectar(agora, proximaVerificacao, dentroDoCone, visaoLivre)
	if type(agora) ~= "number" or type(proximaVerificacao) ~= "number" or agora < proximaVerificacao then
		return false, proximaVerificacao
	end
	return dentroDoCone == true and visaoLivre == true, agora + 0.25
end

function Patrulha.proximoPonto(indice, quantidade)
	if type(indice) ~= "number" or type(quantidade) ~= "number" or quantidade < 2 then return nil end
	return indice % quantidade + 1
end

return Patrulha
