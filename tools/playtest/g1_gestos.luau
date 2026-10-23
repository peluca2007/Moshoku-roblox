local p = game.Players.LocalPlayer
local C = p.PlayerScripts.Client
local Corpo = require(C.Corpo)
local Protocol = require(game.ReplicatedStorage.Shared.MesaProtocol)
local FX = require(C.MenuEfeitos)
local pasta = Instance.new("Folder"); pasta.Name = "G1GestosTeste"; pasta.Parent = workspace
local state = { findToken = function(id)
	return if id == "a" then { avatar = true, ownerUserId = p.UserId, x = 8, z = 10 } else { x = 11, z = 10 }
end }
local function posicao(_, id)
	if id == "a" then return p.Character:GetPivot().Position end
	return Protocol.cellCenter(11, 10) + Vector3.yAxis * 3
end
local api = require(C.Coreografia).start(state, pasta, posicao)
local R = shared.G1
task.spawn(function()
	local ok, erro = pcall(function()
		for _, id in { "mesa/esconder", "mesa/dissonancia", "mesa/marcha", "mesa/insulto", "mesa/apontar",
			"ability/bardo-e-interacao/Principiante/inspiracao", "ability/furtividade-e-armadilhas/Principiante/primeiro-golpe" } do
			local r = { casterId = "a", habilidadeId = id, alvos = if id == "mesa/esconder" or id == "mesa/dissonancia" or id == "mesa/marcha" then {} else { { id = "b", acertou = true } } }
			R.check(id .. " aceita animacao", api.tocar(r))
			task.wait(.1)
			R.check(id .. " anima o corpo", Corpo.ativos() > 0)
			R.check(id .. " respeita limite de pecas", api.estado().pecas <= 170)
			task.wait(1.6)
			R.check(id .. " limpa e devolve corpo", Corpo.ativos() == 0 and Corpo.escondidos() == 0 and #pasta:GetChildren() == 0)
		end
		api.tocar({ casterId = "a", habilidadeId = "mesa/dissonancia", alvos = {} })
		task.wait(.1); api.limpar()
		R.check("cancelamento restaura corpo", Corpo.ativos() == 0 and Corpo.escondidos() == 0)
		FX.reduzir(true)
		R.check("modo reduzido evita cena nova", not api.tocar({ casterId = "a", habilidadeId = "mesa/apontar", alvos = {} }))
		FX.reduzir(false)
	end)
	if not ok then R.check("erro de gestos: " .. tostring(erro), false) end
	api.destruir(); pasta:Destroy()
	R.pronto = true
end)
return "gestos G1 iniciados"
