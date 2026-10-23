-- SOMENTE STUDIO: raycast real, fronteira do servico e ciclo do encontro.
local Server = script.Parent.Parent
local Service = require(Server.EncontroAutonomoService)
local Regiao = require(Server.RegiaoInicial)
local Terreno = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTerreno)
local function comLimpeza(mundo, corpo)
 local ok, erro = pcall(corpo)
 mundo:Destroy()
 if not ok then error(erro, 0) end
end
local function fixture()
 local mundo = Instance.new("WorldModel")
 mundo.Parent = workspace
 local piso = Instance.new("Part")
 piso.Size, piso.Position, piso.Anchored = Vector3.new(100, 2, 100), Vector3.new(0, -1, 0), true
 piso.Parent = mundo
 local char = Instance.new("Model")
 char.Parent = mundo
 local root = Instance.new("Part")
 root.Name, root.Position, root.Anchored, root.Parent = "HumanoidRootPart", Vector3.new(2, 3, 0), true, char
 local hum = Instance.new("Humanoid")
 hum.Parent = char
 local player = { UserId = 101, Character = char }
 local conectado, ocupado, visivel, tempo, num = true, false, true, 10, 0
 local npc = Instance.new("Part")
 npc.Anchored, npc.Position, npc.CanCollide, npc.Parent = true, Vector3.new(0, 1.5, 0), false, mundo
 local origem = { corpo = npc, modelo = npc, alvo = function() return player end,
  visivel = function() return visivel end, ocupar = function() end }
 local chamadas, projecoes = 0, {}
 local api = Service.start({
  remote = {}, workspace = mundo, localizarJogador = function(id) return if id == 101 and conectado then player else nil end,
  conectado = function(p) return conectado and p == player end,
  emCombate = function() return ocupado end, agora = function() return tempo end,
  novoId = function() num += 1; return "r2-" .. num end,
  corpoPessoal = function() chamadas += 1; return { name = "Teste R2", calculated = {
   initiative = { bonus = 0, advantage = false }, movementMeters = 9 } } end,
  criarPatrulha = function() return origem end,
  emitir = function() end, agendarPrazo = function() end, cancelarPrazo = function() end,
  avatares = { sincronizar = function(_, _, _, areaId) table.insert(projecoes, areaId) end },
 })
 return api, player, origem, mundo, function(c, o, v, t)
  conectado, ocupado, visivel = c, o, v
  tempo += t or 0
 end, function() return chamadas end, root, projecoes
end
return {
 ["patrulha autentica inicia no centro real, projeta grade e bloqueia segunda luta"] = function(t)
  local api, player, origem, mundo, _, _, _, projecoes = fixture()
  comLimpeza(mundo, function()
  local ok, id = api.iniciarPorPatrulha(player, origem)
  t.eq(ok, true)
  t.ok(api.estado(id) ~= nil)
  local arena = mundo:FindFirstChild("Encontro da patrulha")
  t.ok(arena ~= nil)
  local ancora = arena:FindFirstChild("Centro privado J2")
  t.eq(ancora.Position, Vector3.new(0, 0, -8))
  t.eq(projecoes[1], "region/encounter/patrol")
  t.eq(#arena:FindFirstChild("Grade t\u{00e1}tica"):GetChildren(), 400)
  t.eq(api.iniciarPorPatrulha(player, origem), false)
  end)
 end,
 ["distancia, identidade, combate, obstrucao e frequencia recusam inicio"] = function(t)
  local api, player, origem, mundo, configurar, chamadas, root = fixture()
  comLimpeza(mundo, function()
  t.eq(api.iniciarPorPatrulha(player, {}), false)
  root.Position = Vector3.new(20, 3, 0)
  t.eq(api.iniciarPorPatrulha(player, origem), false)
  root.Position = Vector3.new(2, 3, 0)
  t.eq(api.iniciarPorPatrulha(player, origem), false)
  configurar(false, false, true, 1)
  t.eq(api.iniciarPorPatrulha(player, origem), false)
  configurar(true, true, true, 1)
  t.eq(api.iniciarPorPatrulha(player, origem), false)
  configurar(true, false, false, 1)
  t.eq(api.iniciarPorPatrulha(player, origem), false)
  t.eq(chamadas(), 0)
  configurar(true, false, true, 1)
  t.eq(api.iniciarPorPatrulha(player, origem), true)
  end)
 end,
 ["amostra inclinada e degrau viram bloqueios reais e impedem spawn inseguro"] = function(t)
  local api, player, origem, mundo = fixture()
  comLimpeza(mundo, function()
  local rampa = Instance.new("Part")
  rampa.Size, rampa.CFrame, rampa.Anchored, rampa.Parent = Vector3.new(8, 1, 8),
   CFrame.new(-0.9, 0, -0.9) * CFrame.Angles(0, 0, math.rad(30)), true, mundo
  local arena = Regiao.criarArenaPatrulha(mundo, origem.corpo.Position, { origem.modelo, player.Character })
  t.eq(Terreno.chaves(arena.areaId, arena.bloqueadas)["10:10"], true)
  t.eq(arena.pasta:FindFirstChild("Grade t\u{00e1}tica").Casa_10_10:GetAttribute("Blocked"), true)
  arena.pasta:Destroy()
  -- 17/10: o servico tenta centros vizinhos antes de desistir; o inicio so pode ocorrer se a arena escolhida
  -- NAO ficar sobre a rampa (centro original bloqueado).
  local ok = api.iniciarPorPatrulha(player, origem)
  local nova = mundo:FindFirstChild("Encontro da patrulha")
  if ok then
   t.ok(nova ~= nil)
   t.ok(nova:FindFirstChild("Centro privado J2").Position ~= Vector3.new(0, 0, -8))
  else
   t.eq(nova, nil)
  end
  end)
 end,
 ["raycast da percepcao respeita parede e patrulha se move sem alvo"] = function(t)
  local mundo = Instance.new("WorldModel")
  mundo.Parent = workspace
  comLimpeza(mundo, function()
  local regiao = Instance.new("Folder")
  regiao.Name, regiao.Parent = "RegiaoInicial", mundo
  local piso = Instance.new("Part")
  piso.Size, piso.Position, piso.Anchored, piso.Parent = Vector3.new(200, 2, 200), Vector3.new(0,-1,0), true, mundo
  local char = Instance.new("Model")
  char.Parent = mundo
  local root = Instance.new("Part")
  root.Name, root.Anchored, root.Position, root.Parent = "HumanoidRootPart", true, Vector3.new(54, 2, 35), char
  local hum = Instance.new("Humanoid")
  hum.Parent = char
  local player = { Character = char }
  local tempo, inicios = 0, 0
  local patrol = Regiao.iniciarPatrulha({ workspace = mundo, agora = function() return tempo end,
   elegivel = function() return true end, ocupado = function() return false end,
   jogadores = function() return { player } end, encontrar = function() inicios += 1; return true end })
  local parede = Instance.new("Part")
  parede.Size, parede.Position, parede.Anchored, parede.Parent = Vector3.new(5,8,1), Vector3.new(54,3,39), true, mundo
  t.eq(patrol.visivel(player), false)
  patrol.atualizar(0.1)
  t.eq(patrol.alvo(), nil)
  parede:Destroy()
  -- Restaura a direcao inicial para isolar a prova do cone.
  patrol.corpo.CFrame = CFrame.new(54, 1.5, 43)
  tempo = 1
  patrol.atualizar(0.1)
  t.eq(patrol.alvo(), player)
  t.eq(patrol.modelo:GetAttribute("Estado"), "perseguindo")
  root.Position = patrol.corpo.Position + Vector3.new(0, 1, -3)
  tempo = 2
  patrol.atualizar(0.1)
  t.eq(inicios, 1)
  t.eq(patrol.corpo.Transparency, 1)
  end)
 end,
}
