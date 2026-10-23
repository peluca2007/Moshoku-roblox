-- Recusas e missões confirmadas pelo servidor; fila V2 sem bloquear ações.
local Players = game:GetService("Players")
local C = require(script.Parent.UI.Componentes)
local Avisos = {}
function Avisos.start(state)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AvisosJogo", false, 65
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local destruido = false
	gui.Destroying:Connect(function() destruido = true end)
	state.onLog(function(entry)
		local texto = type(entry) == "table" and type(entry.text) == "string" and entry.text or ""
		local erro = entry and entry.tone == "erro"
		local missao = entry and entry.tone == "sistema" and (string.match(texto, "^Missão cumprida:") or string.match(texto, "^Missão entregue:"))
		-- Quadro de caçadas (W1b): aceite e conclusão chegam como log de sistema; viram banner.
		local cacadaFeita = entry and entry.tone == "sistema" and string.match(texto, "^Caçada concluída") ~= nil
		local cacadaAceita = entry and entry.tone == "sistema" and string.find(texto, "encontre a patrulha", 1, true) ~= nil
		if destruido or (not erro and not missao and not cacadaFeita and not cacadaAceita) or texto == "" then return end
		C.aviso({ parent = gui, tipo = if missao or cacadaFeita then "sucesso" elseif cacadaAceita then "info" else "perigo",
			titulo = if cacadaFeita then "Caçada concluída" elseif cacadaAceita then "Caçada aceita" elseif missao then "Missão" else "Aviso", detalhe = texto,
			duracao = math.clamp(5 + utf8.len(texto) / 35, 7, 16) })
	end)
	return gui
end
return Avisos
