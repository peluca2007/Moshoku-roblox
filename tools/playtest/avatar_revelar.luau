local remote = game:GetService("ReplicatedStorage"):WaitForChild("Mesa", 10)
remote:FireServer("paintCells", { brush = "revelar", cells = { { x = 9, z = 8 } } })
task.wait(4)
return "névoa revelada"
