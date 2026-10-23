-- A8: corpos das criaturas no tabuleiro (cliente em Play). Corpo nasce para a
-- criatura visível, some quando ela fica oculta (sigilo), volta ao revelar,
-- o pino da miniatura fica invisível e o nome passa para a cabeça do corpo.
local remote = game.ReplicatedStorage:WaitForChild("Mesa")
local snapshot
remote.OnClientEvent:Connect(function(k, d) if k == "snapshot" then snapshot = d end end)
local linhas, falhas = {}, 0
local function check(nome, ok, det)
	table.insert(linhas, (if ok then "OK    " else "FALHA ") .. nome .. ((not ok and det) and (" — " .. tostring(det)) or ""))
	if not ok then falhas += 1 end
end
remote:FireServer("requestSnapshot"); task.wait(0.5)
remote:FireServer("iniciarLuta", { encontro = "lobo" }); task.wait(2)
local pasta = workspace:FindFirstChild("CorposDeCriatura")
local goblin, lobo
for _, t in snapshot.tokens do
	if t.name == "Goblin Batedor" then goblin = t elseif t.name == "Lobo Cinzento" then lobo = t end
end
check("goblin e lobo na mesa", goblin ~= nil and lobo ~= nil)
check("goblin tem corpo humanoide", pasta and pasta:FindFirstChild(goblin.id) and pasta[goblin.id]:FindFirstChildOfClass("Humanoid") ~= nil)
check("lobo tem corpo de quadrúpede", pasta and pasta:FindFirstChild(lobo.id) and pasta[lobo.id]:FindFirstChild("PernaFrente") ~= nil)
check("snapshot marca o corpo", goblin.corpo == true and lobo.corpo == true)
task.wait(0.3)
local mini = workspace.MesaFichasLocais:FindFirstChild(goblin.id)
check("pino do goblin invisível", mini and mini:FindFirstChild("Base") == nil or (mini and mini.PrimaryPart and mini.PrimaryPart.Transparency == 1), mini and mini.PrimaryPart and mini.PrimaryPart.Transparency)
local billboard = mini and mini:FindFirstChildOfClass("BillboardGui")
check("nome preso à cabeça do corpo", billboard and billboard.Adornee and billboard.Adornee:IsDescendantOf(pasta), billboard and billboard.Adornee and billboard.Adornee:GetFullName())
-- Sigilo: ficha oculta não tem corpo replicado.
remote:FireServer("combatEnd", {}); task.wait(0.4)
remote:FireServer("updateToken", { id = goblin.id, hidden = true }); task.wait(0.8)
check("goblin oculto: corpo removido", pasta:FindFirstChild(goblin.id) == nil)
remote:FireServer("updateToken", { id = goblin.id, hidden = false }); task.wait(0.8)
check("goblin revelado: corpo de volta", pasta:FindFirstChild(goblin.id) ~= nil)
-- Andar: o corpo vai até a casa nova.
remote:FireServer("move", { id = lobo.id, x = 3, z = 3 }); task.wait(3.5)
local alvo = Vector3.new((3 - 0.5 - 10) * 5, 0, (3 - 0.5 - 10) * 5)
local p = pasta[lobo.id]:GetPivot().Position
check("lobo andou até a casa nova", (Vector3.new(p.X, 0, p.Z) - alvo).Magnitude < 1, tostring(p))
remote:FireServer("tableClear", {}); task.wait(0.8)
check("mesa limpa remove os corpos", #pasta:GetChildren() == 0, #pasta:GetChildren())
table.insert(linhas, string.format("A8 corpos: %d falha(s)", falhas))
return table.concat(linhas, "\n")
