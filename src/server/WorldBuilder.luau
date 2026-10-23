local World = {}
function World.create(rng)
local function part(name, size, pos, color, parent)
 local p = Instance.new("Part")
 p.Name = name; p.Size = size; p.Position = pos; p.Color = color
 p.Anchored = true; p.Parent = parent or workspace
 return p
end
part("Campo", Vector3.new(180,1,180), Vector3.new(0,-1,0), Color3.fromRGB(88,125,72))
local zone = part("Zona de encontros", Vector3.new(50,0.2,50), Vector3.new(0,0,35), Color3.fromRGB(49,86,49))
local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(8,1,8); spawn.Position = Vector3.new(0,1,-15)
spawn.Anchored = true; spawn.Neutral = true; spawn.Parent = workspace
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Testar batalha"; prompt.ObjectText = "Campo de treino"
prompt.MaxActivationDistance = 14; prompt.Parent = spawn
for i = 1, 16 do
 local x = (i % 2 == 0 and 1 or -1) * rng:NextInteger(35,75)
 local z = rng:NextInteger(-65,75)
 part("Tronco",Vector3.new(2,10,2),Vector3.new(x,4,z),Color3.fromRGB(90,64,40))
 local crown = part("Copa",Vector3.new(12,12,12),Vector3.new(x,13,z),Color3.fromRGB(38,85,55))
 crown.Shape = Enum.PartType.Ball
end

return {part=part,prompt=prompt,spawn=spawn}
end
return World

