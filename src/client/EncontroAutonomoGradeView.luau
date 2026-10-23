-- Grade de movimento local; o servidor revalida cada destino.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tema = require(script.Parent.UI.Tema)
local cores = Tema.cores
local Movimento = require(ReplicatedStorage.Shared.EncontroAutonomoMovimento)
local Terreno = require(ReplicatedStorage.Shared.EncontroAutonomoTerreno)

local GradeView = {}
local LADO = 13

local function arredondar(obj, raio)
 local c = Instance.new("UICorner")
 c.CornerRadius, c.Parent = UDim.new(0, raio), obj
end

function GradeView.start(parent, state)
 local overlay = Instance.new("Frame")
 overlay.Name, overlay.Size, overlay.Position = "MapaMovimento", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0)
 overlay.BackgroundColor3, overlay.BackgroundTransparency = cores.fio, .18
 overlay.Visible, overlay.ZIndex, overlay.Parent = false, 20, parent
 overlay.Active = true
 local cartao = Instance.new("Frame")
 cartao.Name, cartao.AnchorPoint, cartao.Position = "Cartao", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 cartao.BackgroundColor3, cartao.BorderSizePixel, cartao.ZIndex = cores.painel, 0, 21
 cartao.Parent = overlay
 arredondar(cartao, Tema.raios.painel)
 local borda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)()
 borda.Color, borda.Thickness, borda.Parent = cores.borda, Tema.espessuras.borda, cartao
 local titulo = Instance.new("TextLabel")
 titulo.Name, titulo.Position, titulo.Size = "Titulo", UDim2.fromOffset(12, 8), UDim2.new(1, -120, 0, 36)
 titulo.BackgroundTransparency, titulo.TextColor3, titulo.FontFace = 1, cores.titulo, Tema.fontes.titulo
 titulo.TextSize, titulo.TextXAlignment, titulo.ZIndex, titulo.Parent = Tema.tamanhos.subtitulo, Enum.TextXAlignment.Left, 22, cartao
 local fechar = Instance.new("TextButton")
 fechar.Name, fechar.Position, fechar.Size = "Fechar", UDim2.new(1, -52, 0, 6), UDim2.fromOffset(44, 44)
 fechar.Text, fechar.TextSize, fechar.FontFace = "X", Tema.tamanhos.titulo, Tema.fontes.rotulo
 fechar.BackgroundColor3, fechar.TextColor3, fechar.ZIndex, fechar.Parent = cores.painel, cores.texto, 22, cartao
 arredondar(fechar, Tema.raios.botao)
 local fecharBorda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)()
 fecharBorda.Color, fecharBorda.Thickness, fecharBorda.Parent = cores.borda, Tema.espessuras.borda, fechar
 fechar.Activated:Connect(function() overlay.Visible = false end)
 local detalhe = Instance.new("TextLabel")
 detalhe.Name, detalhe.Position, detalhe.Size = "Detalhe", UDim2.fromOffset(12, 54), UDim2.new(1, -24, 0, 44)
 detalhe.BackgroundTransparency, detalhe.TextColor3, detalhe.FontFace = 1, cores.secundario, Tema.fontes.corpo
 detalhe.TextSize, detalhe.TextXAlignment, detalhe.TextWrapped = Tema.tamanhos.rotulo, Enum.TextXAlignment.Left, true
 detalhe.ZIndex, detalhe.Parent = 22, cartao
 detalhe.AutomaticSize = Enum.AutomaticSize.Y
 detalhe.Size = UDim2.new(1, -24, 0, 0)
 detalhe.Visible = false
 local legenda = Instance.new("TextButton")
 legenda.Name,legenda.Text,legenda.TextSize,legenda.FontFace="Legenda","?",24,Tema.fontes.rotulo
 legenda.Position,legenda.Size=UDim2.new(1,-104,0,6),UDim2.fromOffset(44,44)
 legenda.BackgroundColor3,legenda.TextColor3,legenda.ZIndex,legenda.Parent=cores.painel,cores.ouro,22,cartao
 arredondar(legenda,Tema.raios.botao)
 local area = Instance.new("ScrollingFrame")
 area.Name, area.Position = "AreaRolavel", UDim2.fromOffset(12, 92)
 area.BackgroundTransparency, area.BorderSizePixel = 1, 0
 area.ScrollBarThickness, area.ScrollingDirection = 8, Enum.ScrollingDirection.XY
 area.AutomaticCanvasSize, area.CanvasSize, area.ZIndex = Enum.AutomaticSize.XY, UDim2.new(), 22
 area.Parent = cartao
 local grade = Instance.new("Frame")
 grade.Name, grade.BackgroundTransparency, grade.ZIndex, grade.Parent = "Casas", 1, 23, area
 local layout = Instance.new("UIGridLayout")
 layout.SortOrder, layout.Parent = Enum.SortOrder.LayoutOrder, grade
 detalhe:GetPropertyChangedSignal("TextBounds"):Connect(function()
  local topo = if detalhe.Visible then 54 + math.max(44, detalhe.TextBounds.Y) + 12 else 58
  area.Position, area.Size = UDim2.fromOffset(12, topo), UDim2.new(1, -24, 1, -topo - 12)
 end)
 legenda.Activated:Connect(function()
  detalhe.Visible=not detalhe.Visible
  local topo=if detalhe.Visible then 54+math.max(44,detalhe.TextBounds.Y)+12 else 58
  area.Position,area.Size=UDim2.fromOffset(12,topo),UDim2.new(1,-24,1,-topo-12)
 end)
 local atual
 local function desenhar(estado)
  atual = estado
  if not estado or estado.phase ~= "active" then overlay.Visible = false; return end
  if not overlay.Visible then return end
  local controlado
  for _, ator in ipairs(estado and estado.actors or {}) do
   if ator.id == estado.controlledActorId then controlado = ator; break end
  end
  if not controlado or type(controlado.x) ~= "number" or type(controlado.z) ~= "number" then overlay.Visible = false; return end
  local maximo = math.max(0, math.min(LADO - 1, controlado.movementCasas or 0))
  titulo.Text = string.format("Mover até %d casas", maximo)
  detalhe.Text = "Verde: destino | Ouro: você | Azul: aliados | Vinho: criatura | 1 ação | diagonal vale 1 casa"
  local destinos = Movimento.destinos(controlado.x, controlado.z, estado.actors or {}, maximo,
   Terreno.chavesDe(estado.blockedCells)) or {}
  local porCasa = {}
  for _, ator in ipairs(estado.actors or {}) do porCasa[tostring(ator.x) .. ":" .. tostring(ator.z)] = ator end
  for _, child in grade:GetChildren() do if child:IsA("TextButton") then child:Destroy() end end
  for linha = 1, LADO do
   for coluna = 1, LADO do
    local x, z = controlado.x + coluna - 7, controlado.z + linha - 7
    local dentro = x >= 1 and x <= 20 and z >= 1 and z <= 20
    local id = tostring(x) .. ":" .. tostring(z)
    local ator, destino = porCasa[id], destinos[id]
    local casa = Instance.new("TextButton")
    casa.Name, casa.LayoutOrder = "Casa_" .. tostring(linha) .. "_" .. tostring(coluna), (linha - 1) * LADO + coluna
    casa.BackgroundColor3 = if not dentro then cores.fio elseif ator == controlado then cores.ouro elseif ator and ator.kind == "criatura" then cores.vinho elseif ator then cores.info elseif destino then cores.sucesso else cores.painel
    casa.Text = if not dentro then "" elseif ator == controlado then "EU" elseif ator then string.sub(ator.name or "?", 1, 1) else ""
    casa.TextColor3, casa.TextSize, casa.FontFace = cores.texto, Tema.tamanhos.rotulo, Tema.fontes.rotulo
    casa.AutoButtonColor, casa.Active, casa.Selectable, casa.ZIndex = true, destino ~= nil and estado.isMyTurn == true, destino ~= nil and estado.isMyTurn == true, 24
    casa.Parent = grade
    arredondar(casa, Tema.raios.botao)
    local stroke = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)()
    stroke.Color, stroke.Thickness, stroke.Parent = cores.borda, Tema.espessuras.borda, casa
    if destino then casa.Activated:Connect(function() if state.mover(destino.x, destino.z) then overlay.Visible = false end end) end
   end
  end
 end
 local function abrir(estado)
  atual = estado or atual or state.estado()
  if not atual or atual.phase ~= "active" or not atual.isMyTurn or (atual.actionsRemaining or 0) <= 0 then return false end
  local camera = workspace.CurrentCamera
  local vp = if camera then camera.ViewportSize else Vector2.new(800, 600)
  -- Casas cabem na altura também (antes só na largura: a grade saía com rolagem vertical); toque mínimo 44 px.
  local ladoCasa = math.max(Tema.toqueMinimo, math.floor(math.min(56, (vp.X - 56) / LADO, (vp.Y - 130) / LADO)))
  local largura, altura = ladoCasa * LADO + LADO - 1, ladoCasa * LADO + LADO - 1
  layout.CellSize, layout.CellPadding = UDim2.fromOffset(ladoCasa, ladoCasa), UDim2.fromOffset(1, 1)
  grade.Size = UDim2.fromOffset(largura, altura)
  -- Cartão do tamanho da grade, centralizado: o mundo 3D continua visível em volta.
  cartao.Size = UDim2.fromOffset(math.min(vp.X - 16, math.max(largura + 40, 420)), math.min(vp.Y - 16, altura + 112))
  local function ajustarLegenda()
   local topo = if detalhe.Visible then 54 + math.max(44, detalhe.TextBounds.Y) + 12 else 58
   area.Position = UDim2.fromOffset(12, topo)
   area.Size = UDim2.new(1, -24, 1, -topo - 12)
  end
  ajustarLegenda()
  task.defer(ajustarLegenda)
  overlay.Visible = true
  desenhar(atual)
  task.defer(function()
   if area.Parent then
    local centro = 6 * (ladoCasa + 1) + ladoCasa / 2
    area.CanvasPosition = Vector2.new(math.max(0, centro - area.AbsoluteSize.X / 2), math.max(0, centro - area.AbsoluteSize.Y / 2))
   end
  end)
  return true
 end
 state.onEstado(desenhar)
 return { abrir = abrir, atualizar = desenhar }
end

return GradeView
