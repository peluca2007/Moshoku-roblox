-- Quadro W1b: ofertas pessoais da run, prompts autenticados no servidor.
-- Missões narrativas de Dona Brisa continuam no MissaoService; não duplicam caçadas.
local Shared = game:GetService("ReplicatedStorage").Shared
local Cacadas = require(Shared.Regras.Cacadas)
local Tempo = require(Shared.Mundo.RunTempo)
local Players = game:GetService("Players")
local Service = {}
function Service.start(deps)
 local mundo = deps.workspace or workspace
 local rng = deps.rng or Random.new()
 local function estado(player)
  local sessao = deps.runServico.sessao()
  local run = sessao and sessao.run
  if not run or run.fim or not run.jogadores[player.UserId] then return nil end
  if not run.cacadas then run.cacadas = Cacadas.novo(rng) end
  return run.cacadas
 end
 local api = {}
 function api.reaparecimento(id, derrotar)
  local sessao = deps.runServico.sessao()
  local run = sessao and sessao.run
  if not run then return nil, nil end
  run.patrulhasDerrotadas = run.patrulhasDerrotadas or {}
  if derrotar == true then run.patrulhasDerrotadas[id] = run.dia * Tempo.DIA_SEGUNDOS
  elseif derrotar == "limpar" then run.patrulhasDerrotadas[id] = nil end
  return run.patrulhasDerrotadas[id], run
 end
 function api.bonus(player, id) return Cacadas.bonus(estado(player), player.UserId, id) end
 function api.concluir(player, id, encontroId)
  local e = estado(player)
  if not e then return false end
  local ok = Cacadas.concluir(e, player.UserId, id, encontroId)
  if ok and deps.avisar then deps.avisar(player, "Caçada concluída! Volte ao quadro para outra caçada.") end
  return ok
 end
 local pasta = Instance.new("Model")
 pasta.Name = "Quadro de caçadas"
 pasta:SetAttribute("Procedencia", "Parts originais W1b; substituir por modelo Blender")
 pasta.Parent = mundo:FindFirstChild("Vila") or mundo
 local function parte(nome, size, pos, cor)
  local p = Instance.new("Part")
  p.Name, p.Size, p.Position = nome, size, pos
  p.Anchored, p.CanCollide = true, false
  p.Color, p.Material = cor, Enum.Material.Wood
  p.Parent = pasta
  return p
 end
 -- Borda leste da praça, fora das vias e sem mudar zonas planas/Terrain.
 for _, x in ipairs({18, 24}) do parte("Esteio", Vector3.new(.45, 5, .45), Vector3.new(x, 2.5, -183), Color3.fromRGB(75, 48, 30)) end
 parte("Moldura", Vector3.new(7, 3.5, .5), Vector3.new(21, 3.8, -183), Color3.fromRGB(100, 68, 42))
 local ultima, rotulos = {}, {}
 for i=1,3 do
  local papel = parte("Caçada " .. i, Vector3.new(1.8, 2.5, .1), Vector3.new(17+2*i, 3.8, -182.7), Color3.fromRGB(222, 204, 158))
  local gui = Instance.new("SurfaceGui")
  gui.Face, gui.CanvasSize, gui.Parent = Enum.NormalId.Back, Vector2.new(220,300), papel
  local texto = Instance.new("TextLabel")
  texto.Size, texto.BackgroundTransparency, texto.TextScaled, texto.TextWrapped = UDim2.fromScale(1,1), 1, true, true
  texto.TextColor3, texto.Text, texto.Parent = Color3.fromRGB(54,36,23), "CAÇADA " .. i .. "\nInteraja para aceitar", gui
  rotulos[i] = texto
  local prompt = Instance.new("ProximityPrompt")
  prompt.ActionText, prompt.ObjectText = "Ver / aceitar caçada", "Quadro de caçadas " .. i
  prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = 9, false, papel
  prompt.Triggered:Connect(function(player)
   if player.Parent ~= Players or (deps.emCombate and deps.emCombate()) then return end
   local char = player.Character
   local raiz = char and char:FindFirstChild("HumanoidRootPart")
   local hum = char and char:FindFirstChildOfClass("Humanoid")
   if not raiz or not hum or hum.Health <= 0 or (raiz.Position-papel.Position).Magnitude > 10 then return end
   if ultima[player.UserId] and os.clock()-ultima[player.UserId] < .5 then return end
   ultima[player.UserId] = os.clock()
   local e = estado(player)
   if not e then if deps.avisar then deps.avisar(player,"Comece uma run para aceitar caçadas.") end; return end
   local id = e.ofertas[i]
   if Cacadas.aceitar(e, player.UserId, id) and deps.avisar then
    local d = Cacadas.definicao(id)
    deps.avisar(player, d.nome .. ": encontre a patrulha nos arredores ao norte da vila. Recompensa: " .. d.ouro .. " PO + " .. d.pa .. " PA de aprimoramento.")
   end
  end)
 end
 local ultimaRun
 local function atualizar()
  local sessao = deps.runServico.sessao()
  local run = sessao and sessao.run
  if not run or run.fim then ultimaRun = nil; return end
  if run == ultimaRun then return end
  if not run.cacadas then run.cacadas = Cacadas.novo(rng) end
  ultimaRun = run
  for i, id in ipairs(run.cacadas.ofertas) do
   local d = Cacadas.definicao(id)
   rotulos[i].Text = d.nome .. "\n" .. d.ouro .. " PO + " .. d.pa .. " PA\nNorte da vila\nPerigo: " .. tostring(d.perigo or "médio") .. "\nRepetível"
  end
 end
 local acumulado = 0
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  acumulado += dt
  if acumulado < 1 then return end
  acumulado = 0
  atualizar()
 end)
 Players.PlayerRemoving:Connect(function(p) ultima[p.UserId] = nil end)
 return api
end
return Service
