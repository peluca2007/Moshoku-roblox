local remote = game:GetService("ReplicatedStorage"):WaitForChild("Mesa", 10)
local snapshot
local c = remote.OnClientEvent:Connect(function(kind, data) if kind == "snapshot" then snapshot = data end end)
remote:FireServer("requestSnapshot")
task.wait(0.4)
local id
for _, t in snapshot.tokens do if t.name == "Herói Avatar" then id = t.id end end
remote:FireServer("move", { id = id, x = 13, z = 8 })
task.wait(0.15)
c:Disconnect()
return "movendo " .. tostring(id)
