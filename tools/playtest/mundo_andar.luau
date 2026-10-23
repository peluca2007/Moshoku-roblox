-- (Mundo aberto, 17/10) Cliente (execute_luau): anda a pé por uma lista de pontos com Humanoid:MoveTo (sem teleporte).
-- O pathfinding do MCP (character_navigation) falha na trilha da floresta ("Can not find a route"); este andador reto
-- pula quando trava. Edite ROTA e TIMEOUT. Devolve o tempo e a posição final; para se um combate/diálogo prender o avatar.
local ROTA = { {0, -305}, {2, -312}, {3, -318} }
local TIMEOUT = 30
local h = game.Players.LocalPlayer.Character.Humanoid
local r = game.Players.LocalPlayer.Character.HumanoidRootPart
local t0, log = os.clock(), {}
for i, p in ROTA do
	local alvo = Vector3.new(p[1], r.Position.Y, p[2])
	h:MoveTo(alvo)
	local ultimo, parado = r.Position, 0
	while os.clock() - t0 < TIMEOUT do
		task.wait(0.25)
		local pos = r.Position
		if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(p[1], 0, p[2])).Magnitude < 3 then break end
		if h.WalkSpeed == 0 or r.Anchored then table.insert(log, "PRESO (combate/dialogo) em " .. i); return string.format("%.1f s | %s | preso em (%.0f,%.0f)", os.clock() - t0, table.concat(log, ","), pos.X, pos.Z) end
		if (pos - ultimo).Magnitude < 0.3 then parado += 1 else parado = 0 end
		ultimo = pos
		if parado >= 6 then h.Jump = true; h:MoveTo(alvo); parado = 0; table.insert(log, string.format("trava %d (%.0f,%.0f)", i, pos.X, pos.Z)) end
	end
	table.insert(log, string.format("p%d %.1fs", i, os.clock() - t0))
end
local pos = r.Position
return string.format("%.1f s | %s | final (%.0f,%.0f)", os.clock() - t0, table.concat(log, ", "), pos.X, pos.Z)
