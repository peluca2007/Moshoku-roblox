-- Exclusão por arena durante operações que podem ceder no filtro de texto.
-- Não depende de Instances, relógio ou rede. Compartilhar a mesma trava entre modos.
local TravaPartida = {}

function TravaPartida.new()
	local ocupada = false
	local api = {}
	function api.ocupada(): boolean
		return ocupada
	end
	function api.proteger(iniciar)
		return function(...)
			if ocupada then return "A arena está sendo montada; aguarde." end
			ocupada = true
			local resultado = table.pack(pcall(iniciar, ...))
			ocupada = false
			if not resultado[1] then error(resultado[2], 0) end
			return table.unpack(resultado, 2, resultado.n)
		end
	end
	return api
end

return TravaPartida
