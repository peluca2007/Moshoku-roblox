-- Amostragem unica para apresentacao fisica e bloqueios autoritativos do J2.
local Geometria = require(script.Parent.Parent.EncontroAutonomoGeometria)
local GradeTatica = {}
GradeTatica.LIMITE_INCLINACAO = 18
-- Dois centros de casa (3 m táticos) definem quem já está perto no contato.
GradeTatica.RAIO_ENTRADA_METROS = 3

function GradeTatica.casaNaPosicao(centro, posicao)
 if typeof(centro) ~= "Vector3" or typeof(posicao) ~= "Vector3" then return nil end
 local dx, dz = posicao.X - centro.X, posicao.Z - centro.Z
 -- Mesma escala de Geometria.posicao; distância L-infinito descreve o quadrado,
 -- incluindo os cantos, em vez de inscrever um círculo que perderia casas.
 local passo = (Geometria.posicao(centro, 2, 1) - Geometria.posicao(centro, 1, 1)).Magnitude
 if dx ~= dx or dz ~= dz or posicao.Y ~= posicao.Y or math.abs(dx) > passo * 10 or math.abs(dz) > passo * 10
  or math.abs(posicao.Y - centro.Y) > 6 then return nil end
 return { x = dx / passo + 10.5, z = dz / passo + 10.5,
  distanciaMetros = math.max(math.abs(dx), math.abs(dz)) / passo * 1.5 }
end

function GradeTatica.criar(clareira, marcoEncontro, idGrade, criarParte, marcar, centroEncontro, opcoes)
 local centro = if typeof(centroEncontro) == "Vector3" then centroEncontro else Geometria.centro(marcoEncontro)
 if not centro then return nil end
 opcoes = opcoes or {}
 local mundo = opcoes.workspace or workspace
 local pasta = Instance.new("Folder")
 pasta.Name = "Grade t\u{00e1}tica"
 marcar(pasta, idGrade, "presentation")
 pasta:SetAttribute("GradeCentro", centro) -- identificação cosmética para o cliente
 pasta.Parent = clareira
 -- Marcos de reserva conservam sua apresentacao e terreno fixos.
 if centroEncontro == nil then
  for indice = 0, 20 do
   for _, eixo in ipairs({ "x", "z" }) do
    local ponto = Geometria.posicaoLinha(centro, eixo, indice)
    local borda = indice == 0 or indice == 20
    local tamanho = if eixo == "x" then Vector3.new(if borda then 0.18 else 0.11, 0.025, 36)
     else Vector3.new(36, 0.025, if borda then 0.18 else 0.11)
    local linha = criarParte(pasta, string.upper(eixo) .. "_" .. string.format("%02d", indice), tamanho,
     Vector3.new(ponto.X, 0.145, ponto.Z), Color3.fromRGB(210, 183, 112), Enum.Material.SmoothPlastic)
    linha.CanCollide, linha.CanTouch, linha.CanQuery = false, false, false
    linha.Transparency = if borda then 0.08 else 0.18
    linha:SetAttribute("GridAxis", eixo)
    linha:SetAttribute("GridIndex", indice)
    linha:SetAttribute("Boundary", borda)
   end
  end
  return pasta
 end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 local ignorar = { pasta }
 for _, item in ipairs(opcoes.ignorar or {}) do table.insert(ignorar, item) end
 params.FilterDescendantsInstances = ignorar
 params.RespectCanCollide = true
 local bloqueadas = {}
 for x = 1, 20 do
  for z = 1, 20 do
   local ponto = Geometria.posicao(centro, x, z)
   local hit = mundo:Raycast(ponto + Vector3.new(0, 32, 0), Vector3.new(0, -80, 0), params)
   local bloqueada = not hit or hit.Normal:Dot(Vector3.yAxis) < math.cos(math.rad(GradeTatica.LIMITE_INCLINACAO))
    or hit.Instance:GetAttribute("AreaRole") == "movement-obstacle"
    -- Avatares/miniaturas J2 ainda usam o plano y=0. Nao aceite degraus
    -- ou outro andar como piso acessivel enquanto essa projecao for plana.
    or math.abs(hit.Position.Y) > 0.75
   if bloqueada then table.insert(bloqueadas, { x = x, z = z }) end
   local y = if hit then hit.Position.Y + 0.045 else 0.045
   local tile = criarParte(pasta, "Casa_" .. x .. "_" .. z, Vector3.new(1.73, 0.025, 1.73),
    Vector3.new(ponto.X, y, ponto.Z),
    if bloqueada then Color3.fromRGB(151, 65, 48) else Color3.fromRGB(196, 186, 119),
    Enum.Material.SmoothPlastic)
   tile.CanCollide, tile.CanTouch, tile.CanQuery = false, false, false
   tile.Transparency = if bloqueada then 0.38 else 0.72
   tile:SetAttribute("GridX", x)
   tile:SetAttribute("GridZ", z)
   tile:SetAttribute("Blocked", bloqueada)
  end
 end
 return pasta, bloqueadas
end

return GradeTatica
