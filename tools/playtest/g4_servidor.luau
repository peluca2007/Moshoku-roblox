-- Só executado pelo roteiro em Play. Canal isolado, sem alterar a mesa real.
assert(game:GetService("RunService"):IsStudio())
local folder = Instance.new("Folder"); folder.Name = "G4Teste"; folder.Parent = game.ReplicatedStorage
local remote = Instance.new("RemoteEvent"); remote.Name = "Canal"; remote.Parent = folder
local handlers = {}
local api = require(game.ServerScriptService.Server.ReacoesService).novo({ remote = remote, handlers = handlers })
local r = { respostas = {}, resultado = nil, concluido = false }
shared.G4Servidor = r
remote.OnServerEvent:Connect(function(player, kind, data)
	if kind == "visual" then remote:FireClient(player, "reacao", data)
	elseif kind == "reagir" then
		local erro = handlers.reagir(player, data)
		table.insert(r.respostas, { id = data.id, escolha = data.escolha, erro = erro })
	elseif kind == "pendente" then
		r.concluido, r.resultado = false, nil
		r.resultado = api.perguntar({ id = "g4_real", ownerUserId = player.UserId }, "Pergunta real do servidor", {
			{ id = "reacao_real", nome = "Reagir", detalhe = "Escolha validada pelo ReacoesService real, em canal isolado." },
		})
		r.concluido = true
	end
end)
return "Canal G4 isolado pronto"
