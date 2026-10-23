-- Carregamento real dos 19 áudios na experiência. Não substitui escuta humana.
local Sons = require(game:GetService("ReplicatedStorage").Shared.Sons)
local provider = game:GetService("ContentProvider")
local pasta = Instance.new("Folder")
pasta.Name, pasta.Parent = "A10Carregamento", game:GetService("SoundService")
local sons = {}
for nome, id in Sons.IDS do
	local s = Instance.new("Sound")
	s.Name, s.SoundId, s.Volume, s.Parent = nome, id, 0.2, pasta
	table.insert(sons, s)
end
shared.A10Carga = { pronto = false }
task.spawn(function()
	local linhas, falhas = {}, 0
	local ok, err = pcall(function()
		provider:PreloadAsync(sons)
		for _, som in sons do
			local carregou = som.IsLoaded and som.TimeLength > 0
			if not carregou then falhas += 1 end
			table.insert(linhas, string.format("%s %s: carregado=%s duracao=%.2fs", if carregou then "OK" else "FALHA", som.Name, tostring(som.IsLoaded), som.TimeLength))
			if carregou then
				som:Play()
				task.wait(0.12)
				if not som.IsPlaying then falhas += 1; table.insert(linhas, "FALHA Play " .. som.Name) end
				som:Stop()
			end
		end
		local player = game:GetService("Players").LocalPlayer
		local motor = require(player.PlayerScripts.Client.Sonorizacao)
		motor.limpar()
		local parar
		for _ = 1, 12 do parar = motor.tocar("espada-corte", 0.2) end
		local limite = motor.estado() == 8
		if not limite then falhas += 1 end
		table.insert(linhas, (if limite then "OK" else "FALHA") .. " limite de 8 sons simultaneos")
		motor.limpar()
		if parar then parar(); parar() end
		local limpo = motor.estado() == 0
		if not limpo then falhas += 1 end
		table.insert(linhas, (if limpo then "OK" else "FALHA") .. " cancelamento idempotente")
		motor.tocar("espada-corte", 0.2)
		task.wait(0.35)
		local expirou = motor.estado() == 0
		if not expirou then falhas += 1 end
		table.insert(linhas, (if expirou then "OK" else "FALHA") .. " duracao limitada libera som")
	end)
	if not ok then falhas += 1; table.insert(linhas, tostring(err)) end
	pasta:Destroy()
	shared.A10Carga = { pronto = true, linhas = linhas, falhas = falhas, total = #sons }
end)
return "Carregamento real iniciado: " .. #sons .. " assets. Consulte shared.A10Carga."
