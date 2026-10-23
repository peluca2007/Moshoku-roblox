-- Relógio somente de apresentação: todos os valores vêm do servidor.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local C = require(script.Parent.UI.Componentes)
local T = require(script.Parent.UI.Tema)
local View = {}
function View.start()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "RelogioRun", false, 9
	-- Sibling (como as demais telas V2): em Global o painel (z 2) cobria o texto (z 1) e o apagava.
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local painel = C.painel({parent=gui, nome="Relogio", tamanho=UDim2.fromOffset(250,72), posicao=UDim2.new(.5,0,0,8), ancora=Vector2.new(.5,0), padding=8, sombra=false})
	-- Texto e barra vão em `Conteudo`: filhos diretos do painel ficam sob a borda/brilho (texto apagado).
	local zona = painel:FindFirstChild("Conteudo") or painel
	local titulo = Instance.new("TextLabel")
	titulo.Name, titulo.BackgroundTransparency, titulo.FontFace, titulo.TextSize = "Hora", 1, T.fontes.rotulo, 19
	titulo.TextColor3, titulo.Size, titulo.Parent = T.cores.titulo, UDim2.new(1,0,0,24), zona
	local prazo = titulo:Clone()
	prazo.Name, prazo.Position, prazo.TextSize, prazo.Parent = "Prazo", UDim2.fromOffset(0,25), 15, zona
	prazo.TextColor3 = T.cores.texto
	local trilho = Instance.new("Frame")
	trilho.Name, trilho.BorderSizePixel, trilho.BackgroundColor3 = "Dia", 0, T.cores.painel
	trilho.Position, trilho.Size, trilho.Parent = UDim2.new(0,0,1,-5), UDim2.new(1,0,0,3), zona
	local barra = trilho:Clone()
	barra.Name, barra.Position, barra.BackgroundColor3, barra.Parent = "Progresso", UDim2.new(), T.cores.titulo, trilho
	local function atualizar()
		local dia = RS:GetAttribute("RunDia")
		painel.Visible = type(dia) == "number"
		if not painel.Visible then return end
		titulo.Text = string.format("Dia %d · %s", dia, RS:GetAttribute("RunPeriodo") or "amanhecer")
		local restantes = RS:GetAttribute("RunDiasRestantes") or 0
		prazo.Text = string.format("faltam %d dias%s", math.ceil(restantes), if RS:GetAttribute("RunRelogioPausado") then " · pausado" else "")
		barra.Size = UDim2.new(math.clamp(RS:GetAttribute("RunFracaoDia") or 0,0,1),0,1,0)
		local camera = workspace.CurrentCamera
		local largura = camera and camera.ViewportSize.X or 1920
		local inset = game:GetService("GuiService"):GetGuiInset()
		local topoObjetivo = if largura < 700 then math.max(90,inset.Y+80) else inset.Y+12
		local combate = Players.LocalPlayer:GetAttribute("InterfaceCombate") == true
		local topo = if combate then 76 elseif largura < 1100 then topoObjetivo+112-inset.Y else 8
		painel.Position = UDim2.new(.5,0,0,topo)
	end
	for _, nome in {"RunDia","RunPeriodo","RunFracaoDia","RunDiasRestantes","RunRelogioPausado"} do RS:GetAttributeChangedSignal(nome):Connect(atualizar) end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(atualizar) end
	Players.LocalPlayer:GetAttributeChangedSignal("InterfaceCombate"):Connect(atualizar)
	atualizar()
end
return View
