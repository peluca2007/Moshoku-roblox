-- T26: regressões do adaptador de avatar, executadas em Server num Play novo.
-- Não usa DataStore. Mesa real precisa estar vazia para isolar o adaptador.
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local debug = game.ServerStorage:WaitForChild("MesaDebug", 5)
assert(debug and player, "Play com jogador é necessário")
assert(#debug:Invoke("snapshotOf", player).tokens == 0, "Mesa deve estar vazia")
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart", 10)
local humanoid = character:FindFirstChildOfClass("Humanoid")
assert(root and humanoid and humanoid.Health > 0, "Avatar vivo é necessário")
local original = root.CFrame
local Protocol = require(game.ReplicatedStorage.Shared.MesaProtocol)
local AvatarFichas = require(game.ServerScriptService.Server.AvatarFichas)
local tokens = {}
local api = AvatarFichas.start({
	fichas = function() return tokens end,
	centro = Protocol.cellCenter,
	secreto = function(t) return t.hidden == true end,
	bastidor = function() return Vector3.new(-65, 0, -40) end,
})
local report, failures = {}, 0
local function check(label, condition)
	if not condition then failures += 1 end
	table.insert(report, (if condition then "OK    " else "FALHA ") .. label)
end
local function at(x, z)
	local target = Protocol.cellCenter(x, z)
	return (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(target.X, target.Z)).Magnitude < 0.1
end
local function token(x, z, hidden)
	return { id = "t1", kind = "jogador", ownerUserId = player.UserId, x = x, z = z, hidden = hidden }
end
local ok, failure = pcall(function()
	tokens = { token(8, 8, false) }
	api.sincronizar()
	task.wait(3.3)
	check("vínculo público inicial chega à casa 8,8", root.Anchored and at(8, 8))
	-- importState substitui os objetos, mas ids de salvamento podem se repetir.
	tokens = { token(16, 8, false) }
	api.sincronizar()
	task.wait(3.3)
	check("restaurar mesma ficha/id em outra casa realinha avatar", at(16, 8))
	api.moveu(tokens[1])
	task.wait(3.3)
	check("moveu explícito chega à casa 16,8", at(16, 8))
	tokens = { token(2, 2, false) }
	api.sincronizar()
	task.wait(0.15)
	tokens = { token(12, 12, false) }
	api.sincronizar()
	-- Snapshots durante a rota não podem reiniciá-la indefinidamente.
	for _ = 1, 35 do
		task.wait(0.1)
		api.sincronizar()
	end
	check("carregar durante caminhada troca destino sem reiniciar por snapshot", at(12, 12))
	tokens[1].hidden = true
	api.sincronizar()
	check("ficha secreta estaciona fora do tabuleiro", root.Anchored and root.Position.X < -60 and not api.ehAvatar(tokens[1]))
	tokens = {}
	api.sincronizar()
	check("remover ficha solta avatar", not root.Anchored)
	-- Simula HumanoidRootPart ainda indisponível na chegada do personagem.
	root.CFrame = original
	root.Name = "RaizTemporariamenteIndisponivelT26"
	tokens = { token(3, 3, true) }
	api.sincronizar()
	root.Name = "HumanoidRootPart"
	api.sincronizar()
	check("raiz tardia é estacionada na próxima sincronização", root.Anchored and root.Position.X < -60)
	root.Anchored = false
	api.sincronizar()
	check("estacionamento perdido é reaplicado", root.Anchored and root.Position.X < -60)
end)
root.Name = "HumanoidRootPart"
tokens = {}
api.sincronizar()
root.CFrame = original
if not ok then failures += 1; table.insert(report, "FALHA execução: " .. tostring(failure)) end
table.insert(report, 1, string.format("RESULTADO %d falha(s)", failures))
return table.concat(report, "\n")
