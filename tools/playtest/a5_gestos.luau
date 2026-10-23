-- A5: gestos de corpo no cliente real. Roda em segundo plano e grava em shared.A5.
-- Cada gesto: aceita o recibo, usa fantasma quando o corpo é personagem, devolve o
-- corpo real ao fim e não deixa peças. Não altera a campanha.
local Players = game:GetService("Players")
local Client = Players.LocalPlayer.PlayerScripts.Client
local Coreografia = require(Client.Coreografia)
local Corpo = require(Client.Corpo)
local Protocol = require(game.ReplicatedStorage.Shared.MesaProtocol)
local eu = Players.LocalPlayer
local pasta = Instance.new("Folder"); pasta.Name = "A5TesteGestos"; pasta.Parent = workspace
local estado = { findToken = function(id)
	if id == "a" then return { avatar = true, ownerUserId = eu.UserId, x = 8, z = 10 } end
	return { x = 11, z = 10 }
end }
local function posicaoDe(_, id, casa)
	if id == "a" then
		local raiz = eu.Character and eu.Character:FindFirstChild("HumanoidRootPart")
		return (raiz and raiz.Position or Vector3.zero) + Vector3.yAxis
	end
	local c = Protocol.cellCenter(11, 10)
	return c + Vector3.yAxis * 3
end
local api = Coreografia.start(estado, pasta, posicaoDe)
local R = { linhas = {}, falhas = 0, pronto = false }
shared.A5 = R
local function check(nome, ok)
	table.insert(R.linhas, (if ok then "OK " else "FALHA ") .. nome)
	if not ok then R.falhas += 1 end
end
local function limpo()
	for _, p in pasta:GetDescendants() do
		if p:IsA("BasePart") then
			for _, n in { p.CFrame:GetComponents() } do
				if n ~= n or math.abs(n) == math.huge then return false end
			end
		end
	end
	return true
end
local function recibo(id, extra)
	local r = { habilidadeId = id, casterId = "a", origem = { 8, 10 }, arma = "Espada longa", alvos = { { id = "b", acertou = true, dano = 7 } } }
	for k, v in extra or {} do r[k] = v end
	return r
end
local GESTOS = {
	{ "mesa/ataque-basico", true },
	{ "mesa/ataque-a-distancia", true },
	{ "mesa/lamina-de-gelo-forca", true },
	{ "invocado/ataque", true },
	{ "criatura/ataque", true },
	{ "ability/deus-da-espada/Principiante/corte-de-braco", true },
	{ "ability/deus-da-espada/Principiante/golpe-continuo", true },
	{ "ability/deus-do-norte/Principiante/golpe-baixo", true },
	{ "ability/armas-pesadas/Principiante/golpe-circular", true },
	{ "ability/armas-pesadas/Principiante/cabecada", true },
	{ "ability/cavalaria-e-escudos/Principiante/golpe-de-escudo", true },
	{ "ability/deus-da-espada/Principiante/investida-espada", true, { trajeto = { { 8, 10 }, { 10, 10 } } } },
	{ "ability/deus-do-norte/Principiante/forma-quadrupede", true, { trajeto = { { 8, 10 }, { 10, 10 } } } },
	{ "ability/armas-pesadas/Principiante/investida-devastadora", true, { trajeto = { { 8, 10 }, { 10, 10 } } } },
	{ "ability/deus-da-agua-corpo/Principiante/provocar", true },
	{ "ability/cavalaria-e-escudos/Principiante/provocar-odio-soberano", true },
	{ "ability/cavalaria-e-escudos/Principiante/puxar", true },
	{ "ability/arquearia/Principiante/disparo-duplo", true },
	{ "ability/arquearia/Principiante/tiro-de-contencao", true },
	{ "ability/deus-do-norte/Principiante/arremesso-de-espada", true },
	{ "ability/agua/Principiante/lamina-de-gelo", true },
	{ "ability/agua/Principiante/bola-de-agua", true },
	{ "ability/cura/Principiante/cura", true },
	{ "ability/terra/Principiante/bala-de-pedra", true },
	{ "ability/vento/Principiante/lamina-de-vento", true },
}
task.spawn(function()
	local ok, erro = pcall(function()
		local personagem = eu.Character
		check("personagem presente", personagem ~= nil)
		for _, g in GESTOS do
			local id = g[1]
			api.limpar()
			local usouFantasma = false
			local r = recibo(id, g[3])
			if string.find(id, "cura") and not string.find(id, "arvore") then r.alvos[1].dano = nil; r.alvos[1].cura = 6 end
			check(id .. " aceita o recibo", api.tocar(r))
			for _ = 1, 8 do
				task.wait(0.1)
				if Corpo.ativos() > 0 then usouFantasma = true end
			end
			check(id .. " usa fantasma do corpo", usouFantasma)
			check(id .. " peças finitas", limpo())
			task.wait(if g[3] and g[3].trajeto then 4.6 else 2.3)
			check(id .. " devolve o corpo e limpa", Corpo.ativos() == 0 and Corpo.escondidos() == 0 and api.estado().cenas == 0 and #pasta:GetChildren() == 0)
		end
		-- cancelar no meio devolve o corpo
		api.tocar(recibo("ability/deus-da-espada/Principiante/golpe-continuo"))
		task.wait(0.15)
		local escondido = Corpo.escondidos() > 0
		api.limpar()
		check("cancelar no meio: estava escondido", escondido)
		check("cancelar no meio: corpo volta", Corpo.escondidos() == 0 and Corpo.ativos() == 0)
		local cabeca = personagem and personagem:FindFirstChild("Head")
		check("cabeça visível de novo", cabeca and cabeca.LocalTransparencyModifier == 0)
		-- rajada respeita o orçamento de fantasmas
		for _ = 1, 12 do api.tocar(recibo("mesa/ataque-basico")) end
		task.wait(0.2)
		check("rajada respeita orçamento de fantasmas", Corpo.ativos() <= 6)
		api.limpar()
		check("rajada cancelada limpa tudo", Corpo.ativos() == 0 and Corpo.escondidos() == 0)
	end)
	if not ok then check("sem erro de execução: " .. tostring(erro), false) end
	api.destruir(); pasta:Destroy()
	table.insert(R.linhas, string.format("A5 gestos: %d verificações, %d falhas", #R.linhas, R.falhas))
	R.pronto = true
end)
return "iniciado"
