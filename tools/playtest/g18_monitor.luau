-- Fixture persistente: somente StarterPlayerScripts temporário, nunca src/place.
local UIS = game:GetService("UserInputService")
local Http = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local state = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("MesaState"))
local events, changes, connections = {}, {}, {}
connections.textbox = script:GetAttributeChangedSignal("CriarTexto"):Connect(function()
	if not script:GetAttribute("CriarTexto") then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "G18EntradaTexto"
	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(200, 44)
	box.Position = UDim2.fromOffset(200, 100)
	box.Text = ""
	box.Parent = gui
	gui.Parent = player.PlayerGui
	box:CaptureFocus()
end)
connections.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
	local snap = state.snapshot()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local box = player.PlayerGui:FindFirstChild("G18EntradaTexto")
	script:SetAttribute("Estado", Http:JSONEncode({
		snapshot = snap ~= nil, table = state.tableView(), combat = snap and snap.combat.active or false,
		master = snap and snap.salaConceitual and snap.salaConceitual.mestre or 0, me = player.UserId,
		avatar = hum ~= nil, seated = seat ~= nil and seat:GetAttribute("LugarSala") ~= nil,
		text = box and box.TextBox.Text or "", focused = UIS:GetFocusedTextBox() ~= nil,
	}))
end)
script:SetAttribute("Eventos", "[]")
script:SetAttribute("Trocas", "[]")
connections.began = UIS.InputBegan:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local snap = state.snapshot()
	local event = {
		key = input.KeyCode.Name, processed = processed,
		phase = script:GetAttribute("Fase"), focused = UIS:GetFocusedTextBox() ~= nil,
		combat = snap and snap.combat.active or false, before = state.tableView(),
	}
	table.insert(events, event)
	script:SetAttribute("Eventos", Http:JSONEncode(events))
	task.delay(.15, function()
		event.after = state.tableView()
		script:SetAttribute("Eventos", Http:JSONEncode(events))
	end)
end)
state.onTableView(function(value)
	table.insert(changes, { phase = script:GetAttribute("Fase"), value = value })
	script:SetAttribute("Trocas", Http:JSONEncode(changes))
end)
script:SetAttribute("Pronto", true)

