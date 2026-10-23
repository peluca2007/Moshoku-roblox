-- Mostra apenas apoio confirmado e aliados presentes no snapshot filtrado.
local Players=game:GetService("Players")
local E=require(game:GetService("ReplicatedStorage").Shared.Estilo)
local Apoio=require(game:GetService("ReplicatedStorage").Shared.ApresentacaoApoio)
local B={}
function B.start(state)
 local gui=Instance.new("ScreenGui")
 gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="ApoioBardo",false,25
 gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
 local painel=Instance.new("Frame")
 painel.Name,painel.AnchorPoint,painel.Position="Painel",Vector2.new(1,0),UDim2.new(1,-12,0,112)
 painel.Size,painel.BackgroundColor3,painel.Visible,painel.Parent=UDim2.fromOffset(304,44),E.PAPEL,false,gui
 painel.Active=true
 local canto=Instance.new("UICorner");canto.CornerRadius=UDim.new(0,8);canto.Parent=painel
 local cab=Instance.new("TextButton")
 cab.Name,cab.Size,cab.BackgroundTransparency="Alternar",UDim2.new(1,0,0,44),1
 cab.FontFace,cab.TextSize,cab.TextColor3,cab.Parent=E.ROTULO_FORTE,16,E.TINTA,painel
 local resumo=Instance.new("TextLabel")
 resumo.Name,resumo.Position,resumo.Size="Estado",UDim2.fromOffset(10,44),UDim2.new(1,-20,0,58)
 resumo.BackgroundTransparency,resumo.TextWrapped,resumo.TextXAlignment=1,true,Enum.TextXAlignment.Left
 resumo.FontFace,resumo.TextSize,resumo.TextColor3,resumo.Parent=E.ROTULO,15,E.DESTAQUE,painel
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name,scroll.Position,scroll.Size="Efeitos",UDim2.fromOffset(10,110),UDim2.new(1,-20,0,222)
 scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ScrollBarThickness=1,0,4
 scroll.CanvasSize,scroll.AutomaticCanvasSize,scroll.Parent=UDim2.new(),Enum.AutomaticSize.Y,painel
 local texto=Instance.new("TextLabel")
 texto.Name,texto.Size,texto.AutomaticSize="Resumo",UDim2.new(1,-8,0,0),Enum.AutomaticSize.Y
 texto.BackgroundTransparency,texto.TextWrapped,texto.TextXAlignment,texto.TextYAlignment=1,true,Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
 texto.FontFace,texto.TextSize,texto.TextColor3,texto.Parent=E.ROTULO,15,E.TINTA,scroll
 local aberto,destruido=false,false
 local conexoes,cameraCon={},nil
 local function tamanho()
  if destruido then return end
  local camera=workspace.CurrentCamera
  local viewport=if camera then camera.ViewportSize else Vector2.new(800,700)
  local altura=math.clamp(viewport.Y-440,60,222)
  painel.Size=UDim2.fromOffset(math.clamp(viewport.X-24,180,340),if aberto then altura+120 else 110)
  scroll.Size=UDim2.new(1,-20,0,altura);scroll.Visible=aberto
  cab.Text=if aberto then "APOIO • recolher" else "APOIO • detalhes"
 end
 local function observarCamera()
  if cameraCon then cameraCon:Disconnect() end
  local camera=workspace.CurrentCamera
  cameraCon=if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(tamanho) else nil
  tamanho()
 end
 table.insert(conexoes,cab.Activated:Connect(function() aberto=not aberto;tamanho() end))
 table.insert(conexoes,workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(observarCamera))
 gui.Destroying:Connect(function()
  destruido=true
  if cameraCon then cameraCon:Disconnect() end
  for _,con in conexoes do con:Disconnect() end
 end)
 observarCamera()
 state.onSnapshot(function(snap)
  if destruido then return end
  local dados=Apoio.resumir(snap)
  -- Atualizar PV não interrompe a leitura nem reabre os detalhes.
  if texto.Text~=dados.texto then texto.Text=dados.texto;scroll.CanvasPosition=Vector2.zero end
  painel.Visible,resumo.Text=dados.visivel,dados.resumo
  tamanho()
 end)
 return gui
end
return B
