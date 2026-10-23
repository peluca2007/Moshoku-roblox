-- A7: botão Andar pelo caminho real do cliente (MesaState: mira "mesa/andar" ->
-- clique numa casa -> pedido move). Modo Luta; não altera campanha salva.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local MesaState = require(game.Players.LocalPlayer.PlayerScripts.Client.MesaState)
MesaState.start() -- instância deste teste (a do jogo é outra)
local snapshot
remote.OnClientEvent:Connect(function(k, d) if k == "snapshot" then snapshot = d end end)
local linhas, falhas = {}, 0
local function check(nome, ok, det)
	table.insert(linhas, (if ok then "OK    " else "FALHA ") .. nome .. ((not ok and det) and (" — " .. tostring(det)) or ""))
	if not ok then falhas += 1 end
end
remote:FireServer("requestSnapshot"); task.wait(0.5)
remote:FireServer("iniciarLuta", {}); task.wait(2)
local function eu()
	for _, t in snapshot.tokens do if t.ownerUserId == game.Players.LocalPlayer.UserId then return t end end
end
-- espera a vez do herói (o goblin pode ter iniciativa maior)
local inicio = os.clock()
while snapshot.combat.turnId ~= eu().id and os.clock() - inicio < 12 do task.wait(0.3) end
local h = eu()
check("vez do herói", snapshot.combat.turnId == h.id)
local x0, z0 = h.x, h.z
-- direção livre: nenhuma ficha nas 3 casas do caminho
local function livre(dx, dz)
	for i = 1, 3 do
		local x, z = x0 + dx * i, z0 + dz * i
		if x < 1 or x > 20 or z < 1 or z > 20 then return false end
		for _, t in snapshot.tokens do if t.x == x and t.z == z then return false end end
	end
	return true
end
local dx, dz = 0, -1
for _, d in { { 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 } } do
	if livre(d[1], d[2]) then dx, dz = d[1], d[2]; break end
end
MesaState.setMira({ tokenId = h.id, habilidadeId = "mesa/andar", tipo = "mover", modo = "casa", alcanceCasas = 6 })
MesaState.dispararMira(nil, x0 + dx * 3, z0 + dz * 3)
task.wait(1)
h = eu()
check("andou 3 casas", h.x == x0 + dx * 3 and h.z == z0 + dz * 3, h.x .. "," .. h.z)
check("gastou 1 Ação", snapshot.jogo and snapshot.jogo.acoes and snapshot.jogo.acoes.usadas == 1, snapshot.jogo and snapshot.jogo.acoes and snapshot.jogo.acoes.usadas)
check("mira limpa depois de andar", MesaState.mira() == nil)
MesaState.setMira({ tokenId = h.id, habilidadeId = "mesa/andar", tipo = "mover", modo = "casa", alcanceCasas = 6 })
MesaState.dispararMira(nil, h.x + dx * 9, h.z + dz * 9)
task.wait(1)
check("longe demais é recusado", eu().x == h.x and eu().z == h.z)
remote:FireServer("combatEnd", {}); task.wait(0.5)
table.insert(linhas, string.format("A7 andar: %d falha(s)", falhas))
return table.concat(linhas, "\n")
