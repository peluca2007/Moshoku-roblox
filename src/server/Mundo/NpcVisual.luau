-- Apresentação compartilhada dos rigs; BillboardGui exige tamanho explícito.
local TextService = game:GetService("TextService")
local T = require(game:GetService("ReplicatedStorage").Shared.UITemaDados)
local Visual = {}
local function texto(parent, valor, tamanho, fonte, cor)
 local label = Instance.new("TextLabel")
 label.BackgroundTransparency, label.Text, label.TextSize = 1, valor, tamanho
 label.Font, label.TextColor3, label.Parent = fonte, cor, parent
 label.TextStrokeTransparency, label.TextStrokeColor3 = .6, T.cores.fio
 return label
end
function Visual.nome(corpo, nome, titulo)
 local head = corpo:FindFirstChild("Head")
 if not head then return end
 local gui = Instance.new("BillboardGui")
 gui.Name, gui.Adornee, gui.Size = "NomeNpc", head, UDim2.fromOffset(230, if titulo then 52 else 30)
 gui.StudsOffset, gui.MaxDistance, gui.LightInfluence = Vector3.new(0, 2.4, 0), 24, 0
 local label = texto(gui, nome, 20, Enum.Font.Bodoni, T.cores.titulo)
 label.Size = UDim2.new(1, 0, 0, 28)
 if titulo then
  local sub = texto(gui, titulo, 14, Enum.Font.Garamond, T.cores.texto)
  sub.Position, sub.Size = UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 22)
 end
 gui.Parent = head
end
function Visual.balao(corpo, nome, fala, duracao)
 local head = corpo:FindFirstChild("Head")
 if not head or type(fala) ~= "string" then return end
 local anterior = head:FindFirstChild("Fala")
 if anterior then anterior:Destroy() end
 local altura = TextService:GetTextSize(fala, 16, Enum.Font.Garamond, Vector2.new(256, 10000)).Y + 52
 local gui = Instance.new("BillboardGui")
 gui.Name, gui.Adornee, gui.Size = "Fala", head, UDim2.fromOffset(280, altura)
 gui.StudsOffset, gui.MaxDistance, gui.AlwaysOnTop = Vector3.new(0, 4.5, 0), 28, true
 local frame = Instance.new("Frame")
 frame.Size, frame.BackgroundColor3, frame.BackgroundTransparency = UDim2.fromScale(1, 1), T.cores.painel, T.transparencias.painel
 frame.BorderSizePixel, frame.Parent = 0, gui
 Instance.new("UICorner", frame).CornerRadius = UDim.new(0, T.raios.painel)
 local borda = Instance.new("UIStroke", frame)
 borda.Color, borda.Thickness = T.cores.ouro, T.espessuras.borda
 local titulo = texto(frame, nome, 18, Enum.Font.Bodoni, T.cores.titulo)
 titulo.Position, titulo.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 24)
 local label = texto(frame, fala, 16, Enum.Font.Garamond, T.cores.texto)
 label.Position, label.Size, label.TextWrapped = UDim2.fromOffset(12, 34), UDim2.new(1, -24, 1, -42), true
 gui.Parent = head
 -- Não inventa asset de áudio; toca somente uma voz já configurada no rig.
 local som = corpo:FindFirstChild("Voz", true)
 if som and som:IsA("Sound") and som.SoundId ~= "" then som:Play() end
 task.delay(duracao or 7, function() if gui.Parent then gui:Destroy() end end)
 return gui
end
return Visual
