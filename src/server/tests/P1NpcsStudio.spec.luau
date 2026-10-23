-- SOMENTE STUDIO: geometria de balão e colisão real dos modelos.
local Visual = require(script.Parent.Parent.Mundo.NpcVisual)
local Props = require(script.Parent.Parent.Mundo.Props)
return {
 ["balão possui dimensão explícita e nome sem AutomaticSize no Billboard"] = function(t)
  local rig = Instance.new("Model")
  local head = Instance.new("Part", rig); head.Name = "Head"
  local ok, erro = pcall(function()
   Visual.nome(rig, "Ladino", "Furtividade e Armadilhas")
   local gui = Visual.balao(rig, "Dona Brisa", "Uma fala longa que deve caber na área disponível.", 7)
   t.ok(gui.Size.Y.Offset > 52)
   t.eq(head.NomeNpc.MaxDistance, 24)
   t.eq(gui:FindFirstChildOfClass("Frame"):FindFirstChildOfClass("TextLabel").Text, "Dona Brisa")
  end)
  rig:Destroy(); if not ok then error(erro, 0) end
 end,
 ["plantas montadas não colidem e rocha conserva colisão"] = function(t)
  local pai = Instance.new("Folder")
  local ok, erro = pcall(function()
   local lista = {}
   for i, familia in { "tufo", "flores", "samambaia", "cogumelos", "cogumelosluz", "juncos", "rocha" } do
    table.insert(lista, { i * 10, 0, familia, 1, 0 })
   end
   local pasta = Props.criar(pai, lista)
   t.eq(#pasta:GetChildren(), 7)
   for _, modelo in pasta:GetChildren() do
    local colide = false
    for _, parte in modelo:GetDescendants() do
     if parte:IsA("BasePart") then
      if modelo.Name ~= "rocha" then t.eq(parte.CanCollide, false, modelo.Name) end
      colide = colide or parte:IsA("BasePart") and parte.CanCollide
     end
    end
    if modelo.Name == "rocha" then t.ok(colide, "rocha continua sólida") end
   end
  end)
  pai:Destroy(); if not ok then error(erro, 0) end
 end,
}
