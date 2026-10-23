-- Adaptador f?sico R2 compartilhado: cone, persegui??o, contato e espera ap?s retorno.
-- Sem sorteio ou decis?es de combate; o servi?o autentica a origem e inicia J2.
local Patrulha = require(script.Parent.Patrulha)
local Encontros = require(game:GetService("ReplicatedStorage").Shared.EncontrosPorZona)
local PatrulhaVisivel = {}

function PatrulhaVisivel.criar(deps)
 local mundo = deps.workspace or workspace
 local regiao = deps.regiao
 if not regiao then return nil end
 local modelo = Instance.new("Model")
 modelo.Name = deps.nome or "Patrulha"
 modelo.Parent = regiao
 local pontos = deps.pontos
 local parte = function(pai, nome, tamanho, posicao, cor, material)
  local item = Instance.new("Part")
  item.Name, item.Size, item.Position = nome, tamanho, posicao
  item.Color, item.Material, item.Anchored = cor, material, true
  item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  item.Parent = pai
  return item
 end
 local corpo = parte(modelo, "Goblin batedor", Vector3.new(1.5, 2, 1), pontos[1],
  Color3.fromRGB(87, 126, 60), Enum.Material.SmoothPlastic)
 corpo.CanCollide, corpo.CanTouch = false, false
 local cabeca = parte(modelo, "Cabeca", Vector3.new(1.1, 1.1, 1.1), pontos[1] + Vector3.new(0, 1.5, 0),
  Color3.fromRGB(116, 160, 79), Enum.Material.SmoothPlastic)
 cabeca.Shape = Enum.PartType.Ball
 cabeca.CanCollide, cabeca.CanTouch, cabeca.CanQuery = false, false, false
 local nariz = parte(modelo, "Direcao do olhar", Vector3.new(0.35, 0.35, 0.5), pontos[1],
  Color3.fromRGB(56, 71, 39), Enum.Material.SmoothPlastic)
 nariz.CanCollide, nariz.CanTouch, nariz.CanQuery = false, false, false
 modelo.PrimaryPart = corpo
 -- Mapa criatura -> modelo no Shared.Mundo.ModelosCriaturas; `deps.criatura` tem prioridade
 -- sobre o prefixo legado `deps.modelo`. Sem modelo, fica o visual R2 (esfera + bloco).
 local animar = require(script.Parent.PatrulhaModelo).criar(modelo, corpo, deps.criatura or deps.modelo, pontos[1], deps.nome)
 if animar then cabeca.Transparency, nariz.Transparency = 1, 1 end
 local perto, velocidadeAtual = true, 0
 local chaoParams
 local function chaoEm(x, z)
  local terreno = mundo:FindFirstChildOfClass("Terrain")
  if not terreno or not mundo.Raycast then return nil end
  if not chaoParams then
   chaoParams = RaycastParams.new()
   chaoParams.FilterType = Enum.RaycastFilterType.Include
   chaoParams.FilterDescendantsInstances = { terreno }
  end
  local r = mundo:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), chaoParams)
  return if r then r.Position.Y else nil
 end
 local indice, alvo, proxima, ultimoVisto, espera = 2, nil, 0, 0, 0
 local ocupado = false
 local derrotadaEm
 local runAnterior
 local tempoMundo = deps.tempoMundo or deps.agora
 local contato
 local vistos = {}
 local api = { modelo = modelo, corpo = corpo }
 local function raizValida(player)
  if not player or not deps.elegivel(player) then return nil end
  local char = player.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  local root = char and char:FindFirstChild("HumanoidRootPart")
  return if hum and hum.Health > 0 and root and root:IsA("BasePart") then root else nil
 end
 function api.visivel(player)
  local root = raizValida(player)
  if not root then return false end
  local params = RaycastParams.new()
  params.FilterType = Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances = { modelo, player.Character }
  params.RespectCanCollide = true
  return mundo:Raycast(corpo.Position, root.Position - corpo.Position, params) == nil
 end
 function api.alvo() return alvo end
 -- Só apresentação (cabeça acompanha, animação perto): vale qualquer avatar vivo, mesmo sem ficha
 -- elegível para combate; `raizValida` continua decidindo detecção e contato.
 local function jogadorProximo(raio)
  local melhor, dist = nil, raio
  for _, player in ipairs(deps.jogadores()) do
   local char = player.Character
   local hum = char and char:FindFirstChildOfClass("Humanoid")
   local root = char and char:FindFirstChild("HumanoidRootPart")
   if hum and hum.Health > 0 and root and root:IsA("BasePart") then
    local d = (root.Position - corpo.Position).Magnitude
    if d <= dist then melhor, dist = root.Position + Vector3.new(0, 2, 0), d end
   end
  end
  return melhor
 end
 local function animarParado(dt)
  if animar and perto then animar(dt, corpo.Position, corpo.CFrame.LookVector, false, 0, jogadorProximo(24)) end
 end
 -- Contexto privado, disponível só durante o callback servidor de contato.
 function api.contextoContato(player)
  return if contato and contato.player == player then contato else nil
 end
 function api.derrotada()
  derrotadaEm = tempoMundo()
  if deps.reaparecimento then deps.reaparecimento(true) end
 end
 local function mostrar(valor)
  for _, item in ipairs(modelo:GetDescendants()) do
   if item:IsA("BasePart") then
    if item:GetAttribute("PatrulhaTransparencia") == nil then item:SetAttribute("PatrulhaTransparencia", item.Transparency) end
    item.Transparency = if valor then item:GetAttribute("PatrulhaTransparencia") else 1
   end
  end
 end
 function api.ocupar(valor)
  ocupado, alvo = valor, nil
  modelo:SetAttribute("Estado", if valor then "em-encontro" else "patrulhando")
  contato = nil
  table.clear(vistos)
  espera = deps.agora() + 15
  mostrar(not valor and derrotadaEm == nil)
 end
 function api.atualizar(dt)
  if not modelo.Parent or ocupado then return end
  if deps.ocupado() then
   if derrotadaEm == nil then animarParado(dt) end
   return
  end
  if deps.reaparecimento then
   local guardada, run = deps.reaparecimento(false)
   if run ~= runAnterior then
    runAnterior, derrotadaEm = run, guardada
    mostrar(derrotadaEm == nil)
   elseif guardada then derrotadaEm = guardada end
  end
  if derrotadaEm then
   mostrar(false)
   if not Encontros.podeReaparecer(tempoMundo(), derrotadaEm) then return end
   derrotadaEm = nil
   if deps.reaparecimento then deps.reaparecimento("limpar") end
   corpo.CFrame = CFrame.new(pontos[1])
   mostrar(true)
  end
  local agora = deps.agora()
  if agora < espera then animarParado(dt); return end
  local root = raizValida(alvo)
  if alvo and (not root or (root.Position - pontos[1]).Magnitude > 30 or agora - ultimoVisto > 5) then
   alvo, root = nil, nil
  end
  if agora >= proxima then
   local candidatos = if alvo then { alvo } else deps.jogadores()
   for _, player in ipairs(candidatos) do
    local candidato = raizValida(player)
    if candidato then
     local cone = Patrulha.dentroDoCone(corpo.Position, corpo.CFrame.LookVector, candidato.Position, 20, 100)
     local detectar = Patrulha.deveDetectar(agora, proxima, cone, api.visivel(player))
     if detectar then
      alvo, root, ultimoVisto = player, candidato, agora
      vistos[player] = agora
      break
     end
    end
   end
   proxima = agora + 0.25
  end
  -- Contato também pode começar pelas costas. Recheca o cone no instante
  -- do toque: a janela de percepção de 250 ms não concede surpresa frontal.
  if not alvo then
   for _, player in ipairs(deps.jogadores()) do
    local candidato = raizValida(player)
    if candidato and (candidato.Position - corpo.Position).Magnitude <= 5 and api.visivel(player) then
     alvo, root = player, candidato
     local cone = Patrulha.dentroDoCone(corpo.Position, corpo.CFrame.LookVector, candidato.Position, 20, 100)
     if cone then vistos[player], ultimoVisto = agora, agora end
     break
    end
   end
  end
  modelo:SetAttribute("Estado", if alvo then "perseguindo" else "patrulhando")
  if alvo and root and (root.Position - corpo.Position).Magnitude <= 5 and api.visivel(alvo) then
   local visto = vistos[alvo] ~= nil and agora - vistos[alvo] <= 5
   contato = table.freeze({ player = alvo, visto = visto, iniciouPeloJogador = not visto })
   local sucesso = deps.encontrar(alvo, api)
   contato = nil
   if sucesso then api.ocupar(true) else espera = agora + 1 end
   return
  end
  local destino = if root then Vector3.new(root.Position.X, corpo.Position.Y, root.Position.Z)
   else Vector3.new(pontos[indice].X, corpo.Position.Y, pontos[indice].Z)
  local delta = destino - corpo.Position
  if delta.Magnitude < 0.4 then indice = Patrulha.proximoPonto(indice, #pontos); animarParado(dt); return end
  velocidadeAtual = if alvo then 9 else 4
  local passo = delta.Unit * math.min(delta.Magnitude, velocidadeAtual * math.clamp(dt, 0, 0.25))
  local params = RaycastParams.new()
  params.FilterType = Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances = { modelo }
  params.RespectCanCollide = true
  -- Nao atravessa paredes; pathfinding/contorno ficam para outra regiao.
  if mundo:Raycast(corpo.Position, passo + delta.Unit, params) then
   alvo = nil; indice = Patrulha.proximoPonto(indice, #pontos); return
  end
  local pos = corpo.Position + passo
  -- Acompanha o relevo (só quando há Terrain sob o ponto): sem afundar nem flutuar.
  local chao = chaoEm(pos.X, pos.Z)
  if chao then pos = Vector3.new(pos.X, chao + 1.5, pos.Z) end
  corpo.CFrame = CFrame.lookAt(pos, pos + delta.Unit)
  cabeca.CFrame = corpo.CFrame + Vector3.new(0, 1.5, 0)
  nariz.CFrame = corpo.CFrame * CFrame.new(0, 0, -0.65)
  if animar and perto then
   -- A cabeça acompanha o jogador detectado ou, perto, o mais próximo (alerta).
   local olhar = if root then root.Position + Vector3.new(0, 2, 0) else jogadorProximo(24)
   animar(dt, corpo.Position, delta.Unit, true, velocidadeAtual, olhar)
  end
 end
 -- Relogio limitado a 10 Hz; percepcao usa ainda sua janela pura de 250 ms.
 -- Com modelo e jogador a menos de 110 studs, 20 Hz (passada fluida); longe, 10 Hz sem animar.
 local acumulado, limite, checarPerto = 0, 0.1, 0
 if deps.heartbeat then
  api.conexao = deps.heartbeat:Connect(function(dt)
   acumulado += dt
   checarPerto -= dt
   if checarPerto <= 0 then
    checarPerto = 0.5
    perto = jogadorProximo(110) ~= nil
    limite = if animar and perto then 0.05 else 0.1
   end
   if acumulado < limite then return end
   local passo = acumulado; acumulado = 0
   api.atualizar(passo)
  end)
 end
 return api
end

return PatrulhaVisivel
