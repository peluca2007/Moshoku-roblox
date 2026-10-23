local Shared = game:GetService("ReplicatedStorage").Shared
local E=require(Shared.EstadoResultado)
return {
	["evento antes do snapshot aguarda encerramento sem perder resultado"]=function(t)
		local s=E.new();s.snapshot(true);s.receber("vitoria");t.eq(s.visivel,false)
		s.snapshot(true);t.eq(s.visivel,false);s.snapshot(false);t.eq(s.resultado,"vitoria");t.eq(s.visivel,true)
	end,
	["snapshot antes do evento tambem abre resultado"]=function(t)
		local s=E.new();s.snapshot(true);s.snapshot(false);t.eq(s.visivel,false)
		s.receber("derrota");t.eq(s.visivel,true);t.eq(s.resultado,"derrota")
	end,
	["fechar nao reabre com snapshots repetidos e proxima partida limpa"]=function(t)
		local s=E.new();s.snapshot(false);s.receber("duelo");s.fechar();s.snapshot(false);t.eq(s.visivel,false)
		s.snapshot(true);t.eq(s.resultado,nil);s.snapshot(false);t.eq(s.visivel,false)
	end,
	["primeiro snapshot tardio nao perde evento recebido"]=function(t)
		local s=E.new();s.receber("vitoria");t.eq(s.visivel,false);s.snapshot(false);t.eq(s.visivel,true)
	end,
}
