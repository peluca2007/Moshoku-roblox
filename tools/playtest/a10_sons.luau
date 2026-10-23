-- Testa ganchos no cliente real; espionagem de tocar, sem fingir escuta/asset aprovado.
local cliente = game:GetService("Players").LocalPlayer.PlayerScripts.Client
local Som = require(cliente.Sonorizacao)
local Sons = require(game:GetService("ReplicatedStorage").Shared.Sons)
local Coreografia = require(cliente.Coreografia)
local Magias = require(cliente.Magias)
local original = Som.tocar
local linhas, falhas = {}, 0
local function check(nome, ok)
	table.insert(linhas, (if ok then "OK " else "FALHA ") .. nome)
	if not ok then falhas += 1 end
end
local idCorte = Sons.IDS["espada-corte"]
Sons.IDS["espada-corte"] = nil
check("efeito sem ID permanece mudo", Som.tocar("espada-corte") == nil)
Sons.IDS["espada-corte"] = idCorte
-- Mesmo se alguém injetar ID de voz, a lista permitida impede reprodução.
Sons.IDS["grito-masculino-1"] = "rbxassetid://1"
check("voz fora da lista recusada", Som.tocar("grito-masculino-1") == nil)
Sons.IDS["grito-masculino-1"] = nil
local tocados, parados = {}, 0
Som.tocar = function(chave)
	table.insert(tocados, chave)
	return function() parados += 1 end
end
local pasta = Instance.new("Folder")
pasta.Name, pasta.Parent = "A10TesteSons", workspace
local tokens = {
	A10a = { id = "A10a", x = 2, z = 2 },
	A10b = { id = "A10b", x = 3, z = 2 },
}
local snapshot, efeito
local state = {
	findToken = function(id) return tokens[id] end,
	onSnapshot = function(fn) snapshot = fn end,
	onEncontro = function() end,
	onEfeito = function(fn) efeito = fn end,
}
local api = Coreografia.start(state, pasta, function(_, id)
	local t = tokens[id]
	return Vector3.new(t.x * 8, 3, t.z * 8)
end)
local function recibo(id, acerto)
	return { habilidadeId = id, casterId = "A10a", origem = { 2, 2 }, alvos = {
		{ id = "A10b", casa = { 3, 2 }, acertou = acerto, dano = 3 },
	} }
end
shared.A10 = { pronto = false }
task.spawn(function()
	local ok, err = pcall(function()
		api.tocar(recibo("mesa/ataque-basico", true))
		task.wait(1.3)
		check("corte sincronizado", table.find(tocados, "espada-corte") ~= nil)
		check("impacto sincronizado", table.find(tocados, "espada-metal") ~= nil)
		check("limpeza da cena interrompe sons", parados >= 2)
		table.clear(tocados)
		api.tocar(recibo("mesa/ataque-basico", false))
		task.wait(1.3)
		check("erro sem impacto", table.find(tocados, "espada-metal") == nil)
		api.destruir()
		Magias.start(state)
		snapshot({ combat = { active = true } })
		table.clear(tocados)
		efeito(recibo("ability/fogo/Principiante/bola-de-fogo", true))
		task.wait(1.5)
		check("bola de fogo lancamento", table.find(tocados, "fogo") ~= nil)
		check("bola de fogo explosao", table.find(tocados, "fogo-impacto") ~= nil)
		table.clear(tocados)
		efeito(recibo("ability/fogo/Principiante/brasa", true))
		snapshot({ combat = { active = false } })
		task.wait(1.2)
		check("fim do combate cancela sons atrasados", #tocados == 0)
	end)
	if not ok then check(tostring(err), false) end
	api.destruir()
	pasta:Destroy()
	Som.tocar = original
	Som.limpar()
	shared.A10 = { pronto = true, linhas = linhas, falhas = falhas }
end)
return "A10 iniciado; aguarde 6 segundos. Não testa escuta ou carregamento de áudio."
