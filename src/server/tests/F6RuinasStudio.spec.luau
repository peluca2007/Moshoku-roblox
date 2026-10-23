-- SOMENTE STUDIO: arena real, projecao J2 e duas origens R2 no mesmo servidor.
local Server = script.Parent.Parent
local Shared = game:GetService("ReplicatedStorage").Shared
local Ruinas = require(Server.Mundo.Ruinas)
local Regiao = require(Server.RegiaoInicial)
local Service = require(Server.EncontroAutonomoService)
local Geometria = require(Server.EncontroAutonomoGeometria)
local Terreno = require(Shared.EncontroAutonomoTerreno)
local Historia = require(Shared.Mundo.HistoriaV1)

local function comLimpeza(mundo, corpo)
	local ok, erro = pcall(corpo)
	mundo:Destroy()
	if not ok then error(erro, 0) end
end

local function fixture(n, patrulhas)
 local mundo = Instance.new("WorldModel")
 local ok, resultado = pcall(function()
 mundo.Parent = workspace
 -- O mundo real tem Terrain (plano em y=0 nas zonas); o WorldModel de teste nao tem, entao
 -- os raycasts para baixo (grade, patrulha, encontro) precisam deste chao de teste.
 local chao = Instance.new("Part")
 chao.Name, chao.Anchored, chao.Size = "Chao de teste", true, Vector3.new(400, 2, 400)
 chao.Position, chao.Parent = Vector3.new(600, -1, -200), mundo
 local regiao = Ruinas.start({ workspace = mundo })
 local clareira = Instance.new("Folder")
 clareira.Name, clareira.Parent = "RegiaoInicial", mundo
 local grupo, origens, tempo = {}, {}, 10
 for i = 1, n do
  local char = Instance.new("Model")
  char.Parent = mundo
  local hum = Instance.new("Humanoid"); hum.Parent = char
  local root = Instance.new("Part")
  root.Name, root.Anchored, root.CanCollide = "HumanoidRootPart", true, false
  root.Position, root.Parent = Vector3.new(600, 3, -163), char
  char.PrimaryPart = root
  grupo[i] = { UserId = 600 + i, Character = char }
 end
 local function localizar(id)
  for _, p in grupo do if p.UserId == id then return p end end
 end
 local deps = {
  remote = {}, workspace = mundo, localizarJogador = localizar,
  conectado = function(p) return localizar(p.UserId) == p end,
  jogadoresPatrulha = function() return grupo end,
  corpoPessoal = function() return { name = "Teste F6", calculated = {
   attributes = { forca = 0, vigor = 0 }, skills = {}, initiative = { bonus = 50, advantage = false },
   movementMeters = 9, maxima = { pv = 100, pm = 0 }, armorClass = 20,
  }, session = { current = { pv = 100 } } } end,
  agora = function() return tempo end, emitir = function() end,
  novoId = function() return "f6-teste" end,
  agendarPrazo = function() end, cancelarPrazo = function() end,
  rng = { NextInteger = function(_, a, b) return b end, NextNumber = function() return 0 end },
 }
 deps.avatares = require(Server.EncontroAutonomoAvatares).start({ workspace = mundo, localizarJogador = localizar })
 deps.miniaturas = require(Server.EncontroAutonomoMiniaturas).start({ workspace = mundo })
 if patrulhas then
  local function criar(chave, construtor)
   return function(config)
    config = table.clone(config)
    config.heartbeat = nil -- controlado pelo teste, sem conexoes persistentes
    origens[chave] = construtor(config)
    return origens[chave]
   end
  end
  deps.criarPatrulha = criar("clareira", Regiao.iniciarPatrulha)
  deps.criarPatrulhaRuinas = criar("ruinas", Ruinas.iniciarPatrulha)
 end
 return table.pack(Service.start(deps), grupo, mundo, regiao, origens, function() tempo += 1 end)
 end)
 if not ok then mundo:Destroy(); error(resultado, 0) end
 return table.unpack(resultado, 1, resultado.n)
end

local function terminar(t, api, player, id)
 local estado = api.estado(id)
 t.ok(api.solicitarDesistencia(player, { command = "abandon-encounter", encounterId = id,
  expectedVersion = estado.version, requestId = "f6-desistir" }))
 t.ok(api.solicitarRetorno(player, { command = "return-autonomous", encounterId = id, requestId = "f6-retornar" }))
end

return {
 ["arena e idempotente e grade fica sobre a praca com centro na camara"] = function(t)
  local _, _, mundo, regiao = fixture(1)
  comLimpeza(mundo, function()
  t.eq(Ruinas.start({ workspace = mundo }), regiao)
  local marco = regiao:FindFirstChild("Marco do guardiao")
  t.eq(marco:GetAttribute("EncounterId"), "region/encounter/ruinas")
  t.eq(Geometria.centro(marco), Vector3.new(600, 0, -262))
  local grade
  for _, item in regiao:GetChildren() do
   if item:GetAttribute("AreaId") == "region/ruinas-do-vale/grade-tatica" then grade = item end
  end
  t.ok(grade); t.eq(#grade:GetChildren(), 42)
  for _, linha in grade:GetChildren() do
   t.ok(linha.Position.Y > 0)
   t.eq(linha.CanCollide, false); t.eq(linha.CanQuery, false)
  end
  end)
 end,
 ["run projeta um a quatro avatares e goblins na camara sem casas bloqueadas"] = function(t)
  for n = 1, 4 do
   local api, grupo, mundo = fixture(n)
   comLimpeza(mundo, function()
   local id = api.criarEncontroDaRun(grupo, Historia.HISTORIA.nos["chefe-ruinas"].luta)
   t.ok(id)
   local atores = api.atores(id)
   t.eq(#atores, n * 3)
   t.ok(Terreno.posicoesIniciaisLivres(atores, Terreno.celulas("region/encounter/ruinas")))
   for _, ator in atores do
    local pos = Geometria.posicao(Vector3.new(600, 0, -262), ator.x, ator.z)
    if ator.kind == "jogador" then
     local root = grupo[ator.userId - 600].Character.PrimaryPart
     t.ok((Vector3.new(root.Position.X, 0, root.Position.Z) - pos).Magnitude < 0.01)
     t.eq(root.Anchored, true)
    end
   end
   local miniaturas
   for _, item in mundo:GetChildren() do
    if item:GetAttribute("EncounterId") == id then miniaturas = item end
   end
   t.ok(miniaturas)
   local tokens = 0
   for _, item in miniaturas:GetChildren() do
    if item:GetAttribute("ActorId") then
     tokens += 1; t.ok(math.abs(item.Position.X - 600) < 18); t.ok(math.abs(item.Position.Z + 262) < 18)
    end
   end
   t.eq(tokens, #atores)
   t.eq(api.criarEncontroDaRun(grupo, Historia.HISTORIA.nos["chefe-floresta"].luta), nil)
   end)
  end
 end,
 ["contato pelas costas inicia J2 local e retorno libera so a patrulha de origem"] = function(t)
  local api, grupo, mundo, _, origens = fixture(1, true)
  -- Com o modelo do Blender montado o corpo R2 fica sempre invisivel (Transparency 1): compara com o valor inicial.
  local baseRuinas, baseClareira = origens.ruinas.corpo.Transparency, origens.clareira.corpo.Transparency
  comLimpeza(mundo, function()
  t.ok(origens.clareira and origens.ruinas)
  t.eq(api.iniciarPorPatrulha(grupo[1], {}), false)
  origens.ruinas.atualizar(0.1)
  local estado = api.estado("f6-teste")
  t.ok(estado)
  local arena = mundo:FindFirstChild("Encontro da patrulha")
  t.ok(arena)
  t.eq(Geometria.centro(arena:FindFirstChild("Centro privado J2")), Vector3.new(600, 0, -166))
  t.eq(origens.ruinas.modelo:GetAttribute("Estado"), "em-encontro")
  t.eq(origens.ruinas.corpo.Transparency, 1)
  t.eq(origens.clareira.corpo.Transparency, baseClareira)
  for _, ator in api.atores(estado.encounterId) do
   if ator.kind == "criatura" then t.ok(ator.condicoes.desprevenido) end
  end
  t.eq(api.iniciarPorPatrulha(grupo[1], origens.clareira), false)
  t.eq(api.criarEncontroDaRun(grupo, Historia.HISTORIA.nos["chefe-ruinas"].luta), nil)
  terminar(t, api, grupo[1], estado.encounterId)
  t.eq(mundo:FindFirstChild("Encontro da patrulha"), nil)
  t.eq(origens.ruinas.corpo.Transparency, baseRuinas)
  t.eq(origens.ruinas.modelo:GetAttribute("Estado"), "patrulhando")
  t.eq(origens.clareira.modelo:GetAttribute("Estado"), nil)
  t.eq(grupo[1].Character.PrimaryPart.Position, Vector3.new(600, 3, -163))
  end)
 end,
 ["cone e perseguicao das ruinas usam o mesmo adaptador R2 e pausa global"] = function(t)
  local api, grupo, mundo, _, origens, avancar = fixture(1, true)
  comLimpeza(mundo, function()
  local root = grupo[1].Character.PrimaryPart
  root.Position = Vector3.new(600, 3, -176)
  origens.ruinas.atualizar(0.1)
  t.eq(origens.ruinas.alvo(), grupo[1])
  t.eq(origens.ruinas.modelo:GetAttribute("Estado"), "perseguindo")
  for _ = 1, 15 do
   avancar(); origens.ruinas.atualizar(0.1)
   if origens.ruinas.modelo:GetAttribute("Estado") == "em-encontro" then break end
  end
  t.eq(origens.ruinas.modelo:GetAttribute("Estado"), "em-encontro")
  local antes = origens.clareira.corpo.Position
  origens.clareira.atualizar(0.2)
  t.eq(origens.clareira.corpo.Position, antes)
  local estado = api.estado("f6-teste"); t.ok(estado)
  terminar(t, api, grupo[1], estado.encounterId)
  end)
 end,
 ["fuga na borda da arena local preserva retorno e limpa a origem correta"] = function(t)
  local api, grupo, mundo, _, origens, avancar = fixture(1, true)
  local baseRuinas = origens.ruinas.corpo.Transparency
  comLimpeza(mundo, function()
  origens.ruinas.atualizar(0.1)
  local id = "f6-teste"
  t.ok(api.estado(id))
  for i, z in { 4, 1 } do
   avancar()
   t.ok(api.solicitarMovimento(grupo[1], { command = "move", encounterId = id,
    expectedVersion = api.estado(id).version, requestId = "f6-borda" .. i, x = 10, z = z }))
  end
  avancar()
  t.ok(api.solicitarFuga(grupo[1], { command = "flee-encounter", encounterId = id,
   expectedVersion = api.estado(id).version, requestId = "f6-fuga" }))
  t.eq(api.estado(id).phase, "fled")
  t.ok(api.solicitarRetorno(grupo[1], { command = "return-autonomous", encounterId = id, requestId = "f6-retorno-fuga" }))
  t.eq(api.estado(id), nil)
  t.eq(mundo:FindFirstChild("Encontro da patrulha"), nil)
  t.eq(origens.ruinas.corpo.Transparency, baseRuinas)
  t.eq(origens.clareira.modelo:GetAttribute("Estado"), nil)
  end)
 end,
 ["patrulha das ruinas escala goblins lacaios pela ameaca baixa do grupo"] = function(t)
  for n = 2, 4 do
   local api, _, mundo, _, origens = fixture(n, true)
   comLimpeza(mundo, function()
   origens.ruinas.atualizar(0.1)
   local atores = api.atores("f6-teste")
   t.ok(atores); t.eq(#atores, n * 2)
   local criaturas = 0
   for _, ator in atores do
    if ator.kind == "criatura" then
     criaturas += 1
     t.eq(ator.fichaCriatura.catalogId, "creature/goblin-batedor")
     t.eq(ator.recompensa.papel, "lacaio")
    end
   end
   t.eq(criaturas, n)
   end)
  end
 end,
}
