-- Painel enxuto do Dojo; o servidor valida contexto, requisito, prova e recompensa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Estilo = require(ReplicatedStorage.Shared.Estilo)

local View = {}

function View.start()
	local remote = ReplicatedStorage:WaitForChild("Dojo")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.Enabled = "DojoView", false, false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size, frame.Position = UDim2.fromOffset(420, 300), UDim2.new(0.5, -210, 0.5, -150)
	frame.BackgroundColor3 = Estilo.PAPEL
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local function texto(name, value, pos, size, font, color)
		local label = Instance.new("TextLabel")
		label.Name, label.Text = name, value
		label.Position, label.Size = pos, size
		label.BackgroundTransparency, label.TextColor3 = 1, color or Estilo.TINTA
		label.TextWrapped, label.Font, label.TextSize = true, font or Enum.Font.Gotham, 16
		label.Parent = frame
		return label
	end
	texto("Titulo", "DOJO · MESTRE HANZO", UDim2.fromOffset(18, 12), UDim2.new(1, -60, 0, 34), Enum.Font.GothamBold, Estilo.CAPITULOS[6])
	local mensagem = texto("Resumo", "", UDim2.fromOffset(20, 55), UDim2.new(1, -40, 0, 96), Enum.Font.Gotham, Estilo.TINTA)
	local fechar = Instance.new("TextButton")
	fechar.Text, fechar.Size, fechar.Position = "Fechar", UDim2.fromOffset(80, 32), UDim2.new(1, -96, 0, 12)
	fechar.BackgroundColor3, fechar.TextColor3 = Estilo.BOTAO, Estilo.TINTA
	fechar.Parent = frame
	fechar.Activated:Connect(function() gui.Enabled = false end)
	local function botao(textoBotao, x, acao)
		local b = Instance.new("TextButton")
		b.Text, b.Position, b.Size = textoBotao, UDim2.fromOffset(x, 190), UDim2.fromOffset(118, 42)
		b.BackgroundColor3, b.TextColor3 = Estilo.BOTAO, Estilo.TINTA
		b.Parent = frame
		b.Activated:Connect(acao)
		return b
	end
	local iniciar = botao("Iniciar provação", 20, function() remote:FireServer({ acao = "iniciar" }) end)
	local portas = {}
	for i, item in ipairs({ { "PA travado", "travado" }, { "PA livre", "livre" }, { "Marca", "marca" } }) do
		portas[i] = botao(item[1], 20 + (i - 1) * 128, function()
			remote:FireServer({ acao = "escolher", porta = item[2] })
		end)
		portas[i].Visible = false
	end
	remote.OnClientEvent:Connect(function(tipo, dado)
		if tipo ~= "dojo" or type(dado) ~= "table" then return end
		gui.Enabled = true
		if dado.erro then mensagem.Text = dado.erro
		elseif dado.ganho then
			mensagem.Text = string.format("Provação concluída. PA travado: %d · PA livre registrado: %d · Marca: %s", dado.ganho.travados, dado.ganho.livre, if dado.ganho.marca then "sim" else "não")
		elseif dado.iniciada then
			gui.Enabled = false
		elseif dado.podeEscolher then
			mensagem.Text = "Escolha uma das portas do Dilema. A segunda provação da Marca só oferece PA livre."
			iniciar.Visible = false
			for _, b in portas do b.Visible = true end
		else
			local r = dado.recompensa or { travados = 0, livre = 0 }
			mensagem.Text = string.format("Árvore: %s\nRequisito: Hanzo precisa estar dois patamares acima.\nRecompensa: %d PA travados ou %d PA livres, ou Marca do Mestre.", tostring(dado.arvore or "—"), r.travados, r.livre)
			iniciar.Visible = dado.podeIniciar == true
			for _, b in portas do b.Visible = false end
		end
	end)
end

return View
