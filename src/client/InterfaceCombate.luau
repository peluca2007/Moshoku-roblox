-- Liga o atributo local `InterfaceCombate` enquanto o jogador está numa luta do mundo (arena da mesa).
-- Objetivo, marcador, relógio, atalhos e diálogo de NPC já o observam; o J2 era quem o ligava.
-- Só apresentação local.
local Players = game:GetService("Players")

local InterfaceCombate = {}

function InterfaceCombate.start(state)
	local jogador = Players.LocalPlayer
	state.onSnapshot(function(s)
		local minha = false
		if s.combat.active and s.encontro and s.encontro.mundo then
			for _, t in s.tokens do
				if t.ownerUserId == jogador.UserId then minha = true; break end
			end
		end
		if jogador:GetAttribute("InterfaceCombate") ~= minha then jogador:SetAttribute("InterfaceCombate", minha) end
	end)
end

return InterfaceCombate
