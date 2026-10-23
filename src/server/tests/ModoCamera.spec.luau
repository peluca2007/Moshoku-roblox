-- SOMENTE STUDIO: o módulo mora no cliente (StarterPlayerScripts.Client).
local M = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ModoCamera)
local centro, tamanho = Vector3.new(250, -0.5, 0), Vector3.new(42, 1, 40)

return {
	["dentro da sala usa primeira pessoa e fora usa terceira"] = function(t)
		t.eq(M.decidir(false, centro, tamanho, Vector3.new(250, 3, 0)), true)
		t.eq(M.decidir(false, centro, tamanho, Vector3.new(120, 3, 0)), false)
		t.eq(M.decidir(false, centro, tamanho, Vector3.new(0, 3, -170)), false)
	end,
	["histerese evita piscar na porta oeste"] = function(t)
		-- Porta em x=229 (borda do piso em 229). Recém-saído continua em 1ª pessoa por 5 studs.
		t.eq(M.decidir(false, centro, tamanho, Vector3.new(226, 3, 0)), false)
		t.eq(M.decidir(true, centro, tamanho, Vector3.new(226, 3, 0)), true)
		t.eq(M.decidir(true, centro, tamanho, Vector3.new(220, 3, 0)), false)
	end,
}
