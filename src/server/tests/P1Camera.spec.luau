local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.CameraMundoCalculo)
return {
 ["E reserva alcance mais seis inclusive na borda e ignora desabilitados"] = function(t)
  t.ok(C.promptReservaE(true, 14, 8))
  t.ok(not C.promptReservaE(true, 14.01, 8))
  t.ok(not C.promptReservaE(false, 0, 8))
  t.ok(C.promptReservaE(true, 26, 20))
  t.ok(C.DURACAO_GIRO < .25)
 end,
}
